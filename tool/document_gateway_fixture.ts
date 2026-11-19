import { createGateway } from "../supabase/functions/vault-object/gateway.ts";

function loopback(name: string): URL {
  const url = new URL(Deno.env.get(name)!);
  if (url.protocol !== "http:" || url.hostname !== "127.0.0.1" || !url.port) {
    throw new Error("Provider fixture must use a loopback port");
  }
  return url;
}

const database = loopback("FAMILYVAULT_FIXTURE_REST");
const storage = loopback("FAMILYVAULT_FIXTURE_STORAGE");
const handler = createGateway({
  url: database.origin,
  publicKey: Deno.env.get("FAMILYVAULT_FIXTURE_ANON")!,
  workerKey: Deno.env.get("FAMILYVAULT_FIXTURE_WORKER")!,
}, (target, init) => {
  const url = new URL(String(target));
  const prefix = url.pathname.startsWith("/rest/v1/")
    ? "/rest/v1/"
    : "/storage/v1/";
  if (!url.pathname.startsWith(prefix)) {
    return Promise.resolve(new Response(null, { status: 404 }));
  }
  const host = prefix === "/rest/v1/" ? database : storage;
  return fetch(
    new URL(`/${url.pathname.slice(prefix.length)}${url.search}`, host),
    init,
  );
});

Deno.serve({
  hostname: "127.0.0.1",
  port: 0,
  onListen: ({ port }) => console.log(port),
}, handler);
