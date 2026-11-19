type Settings = { url: string; publicKey: string; workerKey: string };
type UploadPlan = {
  family_id: string;
  reservation_id: string;
  object_path: string;
  ciphertext_bytes: number;
  ciphertext_digest: string;
  verified: boolean;
  finalized: boolean;
};

const bucket = "familyvault-ciphertext";
const maximum = 25_167_392;
const uuid = "[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}";
const identifier = new RegExp(`^${uuid}$`);
const objectPath = new RegExp(`^${uuid}/${uuid}\\.fvdoc$`);
const digest = /^[0-9a-f]{64}$/;
const responseHeaders = {
  "cache-control": "private, no-store",
  "x-content-type-options": "nosniff",
};

class GatewayError extends Error {
  constructor(readonly status: number, readonly code: string) {
    super(code);
  }
}

function response(value: unknown, status = 200): Response {
  return Response.json(value, { status, headers: responseHeaders });
}

async function readLimited(
  stream: ReadableStream<Uint8Array> | null,
  limit: number,
) {
  if (!stream) throw new GatewayError(400, "empty_body");
  const reader = stream.getReader();
  const data = new Uint8Array(limit);
  let length = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) return data.subarray(0, length);
      if (value.length + length > limit) {
        await reader.cancel();
        throw new GatewayError(422, "size_mismatch");
      }
      data.set(value, length);
      length += value.length;
    }
  } finally {
    reader.releaseLock();
  }
}

function verifyPlan(plan: UploadPlan) {
  if (
    !plan || !objectPath.test(plan.object_path) ||
    !Number.isSafeInteger(plan.ciphertext_bytes) ||
    plan.ciphertext_bytes < 56 || plan.ciphertext_bytes > maximum ||
    !digest.test(plan.ciphertext_digest)
  ) {
    throw new GatewayError(502, "invalid_storage_plan");
  }
}

export function createGateway(
  settings: Settings,
  transport: typeof fetch = fetch,
) {
  const endpoint = new URL(settings.url);
  const service = {
    apikey: settings.workerKey,
    // The self-hosted legacy worker JWT needs Authorization as well as apikey.
    ...(settings.workerKey.startsWith("sb_")
      ? {}
      : { authorization: `Bearer ${settings.workerKey}` }),
  };
  const request = (path: string, init: RequestInit = {}) =>
    transport(new URL(path, endpoint), {
      ...init,
      redirect: "error",
      signal: AbortSignal.timeout(45_000),
    });
  const post = (path: string, body: unknown, headers: Record<string, string>) =>
    request(path, {
      method: "POST",
      body: JSON.stringify(body),
      headers: { ...headers, "content-type": "application/json" },
    });

  return async (input: Request): Promise<Response> => {
    try {
      if (input.method !== "POST") {
        return response({ code: "method_not_allowed" }, 405);
      }
      const authorization = input.headers.get("authorization") ?? "";
      const device = input.headers.get("x-fv-device") ?? "";
      const proof = input.headers.get("x-fv-proof") ?? "";
      if (
        !/^Bearer [A-Za-z0-9_.-]{1,12000}$/.test(authorization) ||
        !identifier.test(device) || !digest.test(proof)
      ) {
        throw new GatewayError(403, "access_denied");
      }
      const command = JSON.parse(
        new TextDecoder("utf-8", { fatal: true }).decode(
          await readLimited(input.body, 4096),
        ),
      );
      if (
        !command ||
        !["ticket", "verify", "download"].includes(command.action) ||
        !identifier.test(command.id)
      ) {
        throw new GatewayError(400, "invalid_request");
      }
      const download = command.action === "download";
      const args = {
        p_device: device,
        p_proof: proof,
        [download ? "p_version" : "p_reservation"]: command.id,
      };
      // A signed Auth session and matching device proof must pass the Data API before any privileged request.
      const authorized = await post(
        `/rest/v1/rpc/fv_document_${download ? "download" : "upload"}_plan`,
        args,
        {
          apikey: settings.publicKey,
          authorization,
        },
      );
      if (!authorized.ok) {
        if (authorized.status === 409) {
          throw new GatewayError(409, "reservation_changed");
        }
        if (authorized.status >= 500) {
          throw new GatewayError(502, "family_service_unavailable");
        }
        throw new GatewayError(403, "access_denied");
      }
      const plan: UploadPlan = await authorized.json();
      verifyPlan(plan);
      const info = await request(`/storage/v1/bucket/${bucket}`, {
        headers: service,
      });
      if (!info.ok || (await info.json()).public !== false) {
        throw new GatewayError(503, "private_bucket_required");
      }
      const path = `${bucket}/${plan.object_path}`;
      switch (command.action) {
        case "ticket": {
          if (plan.finalized || plan.verified) {
            return response({ verified: true });
          }
          const created = await post(
            `/storage/v1/object/upload/sign/${path}`,
            {},
            service,
          );
          if (created.status === 409) return response({ object_present: true });
          if (!created.ok) {
            throw new GatewayError(502, "upload_ticket_unavailable");
          }
          const signed = new URL(
            (await created.json()).url,
            "https://familyvault.invalid",
          );
          const token = signed.searchParams.get("token");
          if (
            signed.origin !== "https://familyvault.invalid" ||
            signed.pathname !== `/object/upload/sign/${path}` || !token
          ) {
            throw new GatewayError(502, "invalid_upload_ticket");
          }
          return response({ object_path: plan.object_path, token });
        }
        case "verify": {
          if (plan.verified) return response({ verified: true });
          if (
            !identifier.test(plan.family_id) ||
            plan.reservation_id !== command.id ||
            plan.object_path !==
              `${plan.family_id}/${plan.reservation_id}.fvdoc`
          ) {
            throw new GatewayError(502, "invalid_storage_plan");
          }
          const stored = await request(`/storage/v1/object/${path}`, {
            headers: service,
          });
          if (!stored.ok) {
            throw new GatewayError(
              stored.status === 404 ? 409 : 502,
              "stored_bytes_unavailable",
            );
          }
          const actual = await readLimited(stored.body, plan.ciphertext_bytes);
          const checksum = new Uint8Array(
            await crypto.subtle.digest("SHA-256", actual),
          );
          const hex = Array.from(
            checksum,
            (byte) => byte.toString(16).padStart(2, "0"),
          ).join("");
          if (
            actual.length !== plan.ciphertext_bytes ||
            hex !== plan.ciphertext_digest
          ) {
            throw new GatewayError(422, "byte_verification_failed");
          }
          const receipt = await post("/rest/v1/rpc/fv_document_mark_bytes", {
            p_family: plan.family_id,
            p_reservation: plan.reservation_id,
            p_size: actual.length,
            p_digest: hex,
          }, service);
          if (!receipt.ok) {
            throw new GatewayError(502, "verification_receipt_unavailable");
          }
          return response({ verified: true });
        }
        case "download": {
          const stored = await request(`/storage/v1/object/${path}`, {
            headers: service,
          });
          const length = stored.headers.get("content-length");
          if (
            !stored.ok || !stored.body ||
            (length !== null && Number(length) !== plan.ciphertext_bytes)
          ) {
            await stored.body?.cancel();
            throw new GatewayError(502, "stored_bytes_unavailable");
          }
          let remaining = plan.ciphertext_bytes;
          const body = stored.body.pipeThrough(
            new TransformStream<Uint8Array>({
              transform(chunk, controller) {
                remaining -= chunk.byteLength;
                if (remaining < 0) {
                  throw new Error("Invalid stored object size");
                }
                controller.enqueue(chunk);
              },
              flush() {
                if (remaining !== 0) {
                  throw new Error("Invalid stored object size");
                }
              },
            }),
          );
          return new Response(body, {
            headers: {
              ...responseHeaders,
              "content-type": "application/octet-stream",
              "content-length": String(plan.ciphertext_bytes),
            },
          });
        }
        default:
          return response({ code: "invalid_request" }, 400);
      }
    } catch (error) {
      if (error instanceof GatewayError) {
        return response({ code: error.code }, error.status);
      }
      if (error instanceof SyntaxError) {
        return response({ code: "invalid_request" }, 400);
      }
      return response({ code: "family_service_unavailable" }, 502);
    }
  };
}
