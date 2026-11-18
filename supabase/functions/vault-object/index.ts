import { createGateway } from "./gateway.ts";

function key(group: string, legacy: string): string {
  const stored = Deno.env.get(group);
  if (stored) {
    const selected = JSON.parse(stored).default;
    if (typeof selected === "string" && selected.length) return selected;
  }
  const value = Deno.env.get(legacy);
  if (!value) {
    throw new Error("Vault object gateway needs configured server keys");
  }
  return value;
}

Deno.serve(createGateway({
  url: Deno.env.get("SUPABASE_URL")!,
  publicKey: key("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY"),
  workerKey: key("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY"),
}));
