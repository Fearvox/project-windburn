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
  hermes_yolo: {
    status: "PASS",
    reason: "hermes_yolo_lane_ready",
    fixed_session_present: true,
    yolo_window_present: true,
    pane_alive: true,
    yolo_process_count: 1,
    command_redacted: true,
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

function makeRunnerEvidence(overrides = {}) {
  return JSON.parse(JSON.stringify({
    ...runnerEvidence,
    ...overrides,
  }));
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
assert(runnerSuperruntime.body.hermes_yolo.status === "PASS", "hermes_yolo status must be top-level");
assert(runnerSuperruntime.body.hermes_yolo.pane_alive === true, "hermes_yolo pane liveness must be boolean-only");
assert(runnerSuperruntime.body.hermes_yolo.process_count === 1, "hermes_yolo process count must be numeric");
assert(runnerSuperruntime.body.hermes_yolo.timer_status === "unknown", "missing yolo timer must be explicit unknown");
assert(runnerSuperruntime.body.hermes_yolo.operator_surface === "tmux", "operator surface must be summarized without attach target");
assert(runnerSuperruntime.body.hermes_yolo.command === "redacted", "hermes_yolo command must stay redacted");
assert(runnerSuperruntime.body.hermes_yolo.command_redacted === true, "hermes_yolo command redaction flag must be true");
assert(runnerSuperruntime.body.hermes_yolo.stream.status === "stubbed", "hermes_yolo stream must be a bounded redacted stub");
assert(runnerSuperruntime.body.status_events.some((event) => event.type === "hermes-yolo-status"), "hermes_yolo status event must be present");
assert(runnerSuperruntime.body.secret_values_recorded === false, "runner superruntime must not record secrets");

const runnerFindings = assertStreamSafe(runnerSuperruntime.body);
assert(runnerFindings.length === 0, `runner superruntime response not stream-safe: ${runnerFindings.join(", ")}`);

const noYoloApi = createFusionBridgeApi({
  deploymentTarget: "no-yolo-runner-evidence-smoke",
  runnerEvidence: makeRunnerEvidence({ hermes_yolo: undefined }),
  superruntimeFixture: fixture,
  superruntimeSource: "docs/remote-workhorse/fixtures/superruntime-v0.json",
  now: () => "2026-05-05T06:00:00.000Z",
});
const noYoloSuperruntime = await getFrom(noYoloApi, "/api/superruntime");
assert(noYoloSuperruntime.response.status === 200, "missing hermes_yolo must use clean fallback");
assert(noYoloSuperruntime.body.source === "runner-evidence", "missing hermes_yolo must not fall back to fixture");
assert(noYoloSuperruntime.body.hermes_yolo.status === "UNAVAILABLE", "missing hermes_yolo status must be UNAVAILABLE");
assert(noYoloSuperruntime.body.hermes_yolo.operator_surface === "unavailable", "missing hermes_yolo operator surface must be unavailable");
assert(noYoloSuperruntime.body.hermes_yolo.command === "redacted", "missing hermes_yolo command must still be redacted");
const noYoloFindings = assertStreamSafe(noYoloSuperruntime.body);
assert(noYoloFindings.length === 0, `missing yolo fallback not stream-safe: ${noYoloFindings.join(", ")}`);

for (const unsafeCase of [
  {
    label: "secret values recorded",
    evidence: makeRunnerEvidence({ secret_values_recorded: true }),
    reasons: ["secret_values_recorded_true"],
  },
  {
    label: "redaction flag missing",
    evidence: makeRunnerEvidence({ redacted_public_safe: false }),
    reasons: ["redacted_public_safe_not_true"],
  },
  {
    label: "remote mutation enabled",
    evidence: makeRunnerEvidence({ remote_mutation: true }),
    reasons: ["remote_mutation_true"],
  },
  {
    label: "hermes yolo command not redacted",
    evidence: makeRunnerEvidence({
      hermes_yolo: {
        ...runnerEvidence.hermes_yolo,
        command_redacted: false,
      },
    }),
    reasons: ["hermes_yolo_command_not_redacted"],
  },
]) {
  const unsafeApi = createFusionBridgeApi({
    deploymentTarget: `unsafe-${unsafeCase.label}`,
    runnerEvidence: unsafeCase.evidence,
    superruntimeFixture: fixture,
    superruntimeSource: "docs/remote-workhorse/fixtures/superruntime-v0.json",
    now: () => "2026-05-05T06:00:00.000Z",
  });
  const unsafeSuperruntime = await getFrom(unsafeApi, "/api/superruntime");
  assert(unsafeSuperruntime.response.status === 409, `${unsafeCase.label} must return 409`);
  assert(unsafeSuperruntime.body.error === "unsafe_runner_evidence", `${unsafeCase.label} must use unsafe_runner_evidence`);
  assert(unsafeSuperruntime.body.source === "runner-evidence", `${unsafeCase.label} must not fall back to fixture`);
  assert(unsafeSuperruntime.body.redacted_public_safe === true, `${unsafeCase.label} response must stay public-safe`);
  assert(unsafeSuperruntime.body.secret_values_recorded === false, `${unsafeCase.label} response must not record secrets`);
  assert(unsafeSuperruntime.body.mutation_bridge_enabled === false, `${unsafeCase.label} must keep mutation bridge disabled`);
  assert(JSON.stringify(unsafeSuperruntime.body.unsafe_reasons) === JSON.stringify(unsafeCase.reasons), `${unsafeCase.label} must report stable reason labels`);
  assert(!("runner_evidence" in unsafeSuperruntime.body), `${unsafeCase.label} must not echo runner evidence`);
  const unsafeFindings = assertStreamSafe(unsafeSuperruntime.body);
  assert(unsafeFindings.length === 0, `${unsafeCase.label} error response not stream-safe: ${unsafeFindings.join(", ")}`);
}

const unsafeSourceApi = createFusionBridgeApi({
  deploymentTarget: "unsafe-source",
  runnerEvidence: makeRunnerEvidence({ secret_values_recorded: true }),
  runnerEvidenceSource: "/srv/windburn/evidence/runner/current.json",
  now: () => "2026-05-05T06:00:00.000Z",
});
const unsafeSourceSuperruntime = await getFrom(unsafeSourceApi, "/api/superruntime");
assert(unsafeSourceSuperruntime.response.status === 409, "unsafe runner evidence with unsafe source must return 409");
assert(unsafeSourceSuperruntime.body.error === "unsafe_runner_evidence", "unsafe source response must stay on unsafe evidence error");
assert(unsafeSourceSuperruntime.body.source === "[redacted:remote-path]", "unsafe runner evidence source must be redacted");
const unsafeSourceFindings = assertStreamSafe(unsafeSourceSuperruntime.body);
assert(unsafeSourceFindings.length === 0, `unsafe source error response not stream-safe: ${unsafeSourceFindings.join(", ")}`);

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

  await writeFile(runnerEvidencePath, JSON.stringify(makeRunnerEvidence({
    secret_values_recorded: true,
    redacted_public_safe: false,
    remote_mutation: true,
  }), null, 2));
  const nodeUnsafeSuperruntime = await getFrom(nodeApi, "/api/superruntime");
  assert(nodeUnsafeSuperruntime.response.status === 409, "node bridge unsafe runner evidence must return 409");
  assert(nodeUnsafeSuperruntime.body.error === "unsafe_runner_evidence", "node bridge unsafe runner evidence must be rejected");
  assert(nodeUnsafeSuperruntime.body.source === "runner-evidence", "node bridge unsafe runner evidence must not fall back to fixture");
  assert(nodeUnsafeSuperruntime.body.redacted_public_safe === true, "node bridge unsafe error must stay public-safe");
  assert(nodeUnsafeSuperruntime.body.secret_values_recorded === false, "node bridge unsafe error must not record secrets");
  assert(nodeUnsafeSuperruntime.body.runner_evidence_checks.secret_values_recorded === true, "node bridge must expose secret flag as boolean-only");
  assert(nodeUnsafeSuperruntime.body.runner_evidence_checks.redacted_public_safe === false, "node bridge must expose redaction flag as boolean-only");
  assert(nodeUnsafeSuperruntime.body.runner_evidence_checks.remote_mutation === true, "node bridge must expose mutation flag as boolean-only");
  assert(JSON.stringify(nodeUnsafeSuperruntime.body.unsafe_reasons) === JSON.stringify([
    "secret_values_recorded_true",
    "redacted_public_safe_not_true",
    "remote_mutation_true",
  ]), "node bridge must expose stable unsafe reason labels");
  const nodeUnsafeFindings = assertStreamSafe(nodeUnsafeSuperruntime.body);
  assert(nodeUnsafeFindings.length === 0, `node unsafe runner evidence response not stream-safe: ${nodeUnsafeFindings.join(", ")}`);
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
