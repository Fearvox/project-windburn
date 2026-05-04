import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createFusionBridgeApi } from "../src/api.mjs";
import { assertStreamSafe } from "../src/redaction.mjs";

const packageDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const root = path.resolve(packageDir, "../..");
const fixturePath = path.join(root, "docs/remote-workhorse/fixtures/superruntime-v0.json");
const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
const api = createFusionBridgeApi({
  deploymentTarget: "smoke",
  superruntimeFixture: fixture,
  superruntimeSource: "docs/remote-workhorse/fixtures/superruntime-v0.json",
  now: () => "2026-05-04T00:00:00.000Z",
});

async function get(pathname, method = "GET") {
  const response = await api.fetch(new Request(`https://windburn.test${pathname}`, { method }));
  const body = response.status === 204 ? null : await response.json();
  return { response, body };
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

const health = await get("/healthz");
assert(health.response.status === 200, "healthz must return 200");
assert(health.body.mutation_bridge_enabled === false, "healthz must be read-only");

const superruntime = await get("/api/superruntime");
assert(superruntime.response.status === 200, "superruntime must return 200");
assert(superruntime.body.registered_runtime_count === 1, "expected one registered runtime");
assert(superruntime.body.current_lease.status === "leased", "expected leased current lease");
assert(superruntime.body.secret_values_recorded === false, "must not record secrets");

const findings = assertStreamSafe(superruntime.body);
assert(findings.length === 0, `superruntime response not stream-safe: ${findings.join(", ")}`);

const openapi = await get("/openapi.json");
assert(openapi.response.status === 200, "openapi must return 200");
assert(openapi.body.paths["/api/superruntime"], "openapi must include superruntime path");

const mutation = await get("/api/superruntime", "POST");
assert(mutation.response.status === 405, "mutating requests must be rejected");

console.log("PASS fusion_bridge_api_smoke");
