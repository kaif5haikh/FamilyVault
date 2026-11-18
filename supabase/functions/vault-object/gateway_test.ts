import { createGateway } from "./gateway.ts";

const device = "00000000-0000-4000-8000-000000000011";
const family = "00000000-0000-4000-8000-000000000012";
const operation = "00000000-0000-4000-8000-000000000013";
const object = `${family}/${operation}.fvdoc`;
const proof = "a".repeat(64);
const bytes = Uint8Array.from({ length: 112 }, (_, i) => i);
const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
const checksum = [...hash].map((byte) => byte.toString(16).padStart(2, "0"))
  .join("");

function require(condition: unknown, label: string): asserts condition {
  if (!condition) throw new Error(label);
}

function fixture({ denied = false, openBucket = false, stored = bytes } = {}) {
  const requests: string[] = [];
  let receipt: Record<string, unknown> | undefined;
  const gateway = createGateway({
    url: "http://127.0.0.1:32150",
    publicKey: "synthetic-public",
    workerKey: "synthetic-worker",
  }, async (url, init) => {
    const source = new Request(url, init);
    const path = new URL(source.url).pathname;
    requests.push(path);
    if (path.endsWith("_plan")) {
      require(
        source.headers.get("authorization") === "Bearer synthetic-auth",
        "client authentication reached Data API",
      );
      require(
        (await source.json()).p_proof === proof,
        "device proof reached Data API",
      );
      if (denied) return new Response(null, { status: 403 });
      return Response.json({
        family_id: family,
        reservation_id: operation,
        object_path: object,
        ciphertext_bytes: bytes.length,
        ciphertext_digest: checksum,
        verified: false,
        finalized: false,
      });
    }
    require(
      source.headers.get("apikey") === "synthetic-worker",
      "private service uses worker credential",
    );
    if (path.includes("/bucket/")) return Response.json({ public: openBucket });
    if (path.includes("/upload/sign/")) {
      return Response.json({
        url:
          `/object/upload/sign/familyvault-ciphertext/${object}?token=synthetic-ticket`,
      });
    }
    if (path.endsWith("document_mark_bytes")) {
      receipt = await source.json();
      return new Response(null, { status: 204 });
    }
    if (path.endsWith(object)) return new Response(stored);
    throw new Error("Unexpected upstream request");
  });
  const send = (action: string) =>
    gateway(
      new Request("http://localhost/vault-object", {
        method: "POST",
        headers: {
          authorization: "Bearer synthetic-auth",
          "x-fv-device": device,
          "x-fv-proof": proof,
        },
        body: JSON.stringify({ action, id: operation }),
      }),
    );
  return { requests, send, receipt: () => receipt };
}

Deno.test("unapproved access never reaches the private Storage service", async () => {
  const no = fixture({ denied: true });
  require(
    (await no.send("download")).status === 403,
    "revoked client is denied",
  );
  require(no.requests.length === 1, "only the authorization call was made");
});

Deno.test("an accidentally public bucket cannot issue an upload ticket", async () => {
  const no = fixture({ openBucket: true });
  require((await no.send("ticket")).status === 503, "public bucket refused");
  require(
    no.requests.length === 2,
    "only authorization and bucket inspection were made",
  );
});

Deno.test("only a matching full object produces trusted server verification", async () => {
  const altered = bytes.slice();
  altered[9] ^= 1;
  for (
    const wrong of [
      altered,
      bytes.slice(0, 10),
      new Uint8Array(bytes.length + 1),
    ]
  ) {
    const broken = fixture({ stored: wrong });
    require(
      (await broken.send("verify")).status === 422,
      "wrong stored object rejected",
    );
    require(!broken.receipt(), "verification receipt was withheld");
  }
  const good = fixture();
  const issued = await good.send("ticket");
  require(
    issued.ok && typeof (await issued.json()).token === "string",
    "write-only upload ticket issued",
  );
  require(!good.receipt(), "ticket issuance does not acknowledge upload");
  const confirmed = await good.send("verify");
  require(
    confirmed.ok && (await confirmed.json()).verified === true,
    "matching bytes verified",
  );
  require(
    good.receipt()?.p_size === bytes.length &&
      good.receipt()?.p_digest === checksum,
    "trusted database receipt includes measured length and digest",
  );
});

Deno.test("approved download streams ciphertext without reusable public access", async () => {
  const good = fixture();
  const reply = await good.send("download");
  require(
    reply.ok && reply.headers.get("cache-control")?.includes("no-store"),
    "private response",
  );
  require(
    reply.headers.get("content-type") === "application/octet-stream",
    "ciphertext content type",
  );
  const received = new Uint8Array(await reply.arrayBuffer());
  require(
    received.length === bytes.length &&
      received.every((value, i) => value === bytes[i]),
    "exact ciphertext returned",
  );
});
