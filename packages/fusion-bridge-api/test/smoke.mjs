import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createNodeFusionBridgeApi } from "../src/node-server.mjs";
import { createFusionBridgeApi } from "../src/api.mjs";
import { assertStreamSafe } from "../src/redaction.mjs";

const packageDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const root = path.resolve(packageDir, "../..");
const fixturePath = path.join(root, "docs/remote-workhorse/fixtures/superruntime-v0.json");
const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
const runnerEvidence = {
  schema_version: 1,
  generated_at_utc: "2026-05-05T04:54:25Z",
  runner_id: "windburn-workhorse-runner-status-v0",
  runner_kind: "read-only-evidence",
  status: "PASS",
  reason: "runner_foundation_ready",
  system_state: "running",
  failed_units: 0,
  tmux: {
    session_present: true,
    session_count: 1,
  },
  credentials: {
    codex_auth_present: true,
    hermes_auth_present: true,
    provider_env_present: false,
  },
  latest_hermes_codex_smoke: {
    verdict: "PASS",
    reason: "HERMES_CODEX_PROVIDER_OK",
  },
  remote_mutation: false,
  secret_values_recorded: false,
  redacted_public_safe: true,
};
const api = createFusionBridgeApi({
  deploymentTarget: "smoke",
  superruntimeFixture: fixture,
  superruntimeSource: "docs/remote-workhorse/fixtures/superruntime-v0.json",
  now: () => "2026-05-04T00:00:00.000Z",
});

const runnerEvidenceApi = createFusionBridgeApi({
  deploymentTarget: "runner-evidence-smoke",
  runnerEvidence,
  superruntimeFixture: fixture,
  superruntimeSource: "docs/remote-workhorse/fixtures/superruntime-v0.json",
  now: () => "2026-05-05T06:00:00.000Z",
});

async function get(pathname, method = "GET") {
  const response = await api.fetch(new Request(`https://windburn.test${pathname}`, { method }));
  const body = response.status === 204 ? null : await response.json();
  return { response, body };
}

async function runnerGet(pathname, method = "GET") {
  const response = await runnerEvidenceApi.fetch(new Request(`https://windburn.test${pathname}`, { method }));
  const body = response.status === 204 ? null : await response.json();
  return { response, body };
}

async function getFrom(apiInstance, pathname, method = "GET") {
  const response = await apiInstance.fetch(new Request(`https://windburn.test${pathname}`, { method }));
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

const runnerSuperruntime = await runnerGet("/api/superruntime");
assert(runnerSuperruntime.response.status === 200, "runner superruntime must return 200");
assert(runnerSuperruntime.body.source === "runner-evidence", "runner evidence must replace fixture source");
assert(runnerSuperruntime.body.registered_runtime_count === 1, "runner evidence must register the workhorse runtime");
assert(runnerSuperruntime.body.current_lease.status === "runner-ready", "runner evidence must expose runner readiness as lease status");
assert(runnerSuperruntime.body.harness_dispatch_state === "codex-provider-ok", "runner evidence must expose provider smoke state");
assert(runnerSuperruntime.body.runner_evidence.status === "PASS", "runner evidence status must be preserved");
assert(runnerSuperruntime.body.runner_evidence.tmux_session_present === true, "runner tmux presence must be summarized");
assert(runnerSuperruntime.body.runner_evidence.codex_auth_present === true, "credential presence must be boolean-only");
assert(runnerSuperruntime.body.runner_evidence.provider_env_present === false, "missing provider env must stay visible as a boolean");
assert(runnerSuperruntime.body.secret_values_recorded === false, "runner superruntime must not record secrets");

const runnerFindings = assertStreamSafe(runnerSuperruntime.body);
assert(runnerFindings.length === 0, `runner superruntime response not stream-safe: ${runnerFindings.join(", ")}`);

const tmpDir = await mkdtemp(path.join(os.tmpdir(), "windburn-runner-evidence-"));
try {
  const runnerEvidencePath = path.join(tmpDir, "current.json");
  await writeFile(runnerEvidencePath, JSON.stringify(runnerEvidence, null, 2));
  const nodeApi = createNodeFusionBridgeApi({
    root,
    runnerEvidencePath,
    serviceVersion: "smoke",
  });
  const nodeSuperruntime = await getFrom(nodeApi, "/api/superruntime");
  assert(nodeSuperruntime.response.status === 200, "node bridge runner evidence must return 200");
  assert(nodeSuperruntime.body.source === "runner-evidence", "node bridge must prefer runner evidence file over fixture");
  assert(nodeSuperruntime.body.runner_evidence.status === "PASS", "node bridge must summarize runner evidence");
  const nodeFindings = assertStreamSafe(nodeSuperruntime.body);
  assert(nodeFindings.length === 0, `node runner evidence response not stream-safe: ${nodeFindings.join(", ")}`);
} finally {
  await rm(tmpDir, { recursive: true, force: true });
}

const openapi = await get("/openapi.json");
assert(openapi.response.status === 200, "openapi must return 200");
assert(openapi.body.paths["/api/superruntime"], "openapi must include superruntime path");

const mutation = await get("/api/superruntime", "POST");
assert(mutation.response.status === 405, "mutating requests must be rejected");

const admin = await get("/api/admin/provider-config");
assert(admin.response.status === 404, "admin routes must stay disabled before auth wiring");
assert(admin.body.required_role === "admin", "admin routes must declare admin requirement");

console.log("PASS fusion_bridge_api_smoke");
