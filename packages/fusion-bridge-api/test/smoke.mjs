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
assert(health.body.auth.active_role === "viewer", "public health must be viewer scoped");
assert(health.body.auth.mutation_routes_enabled === false, "auth contract must keep mutation routes disabled");

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
assert(openapi.body.paths["/api/superruntime/stream"], "openapi must include superruntime stream path");

const streamNoUpgrade = await get("/api/superruntime/stream");
assert(streamNoUpgrade.response.status === 426, "stream endpoint must require websocket upgrade");
assert(streamNoUpgrade.body.runtime_channel_enabled === true, "stream endpoint must advertise runtime channel");
assert(streamNoUpgrade.body.mutation_bridge_enabled === false, "stream endpoint must keep mutation disabled");

const mutation = await get("/api/superruntime", "POST");
assert(mutation.response.status === 405, "mutating requests must be rejected");

const admin = await get("/api/admin/provider-config");
assert(admin.response.status === 404, "admin routes must stay disabled before auth wiring");
assert(admin.body.required_role === "admin", "admin routes must declare admin requirement");

console.log("PASS fusion_bridge_api_smoke");
