import { openapi } from "./openapi.mjs";
import { authContractSummary, guardRoute, publicAuthContext } from "./auth-contract.mjs";
import { assertStreamSafe, redact } from "./redaction.mjs";
import {
  buildEmptySuperruntimePayload,
  buildRunnerEvidenceSuperruntimePayload,
  buildSuperruntimePayload,
  inspectRunnerEvidenceSafety,
} from "./superruntime.mjs";

const apiHeaders = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
  "x-windburn-api-mode": "read-only",
};

function jsonResponse(payload, options = {}) {
  const status = options.status ?? 200;
  const method = options.method ?? "GET";
  return new Response(method === "HEAD" ? null : JSON.stringify(payload, null, 2), {
    status,
    headers: apiHeaders,
  });
}

function methodNotAllowed(method) {
  return jsonResponse({
    error: "method_not_allowed",
    allowed_methods: ["GET", "HEAD"],
    mutation_bridge_enabled: false,
  }, { status: 405, method });
}

export function createFusionBridgeApi(options = {}) {
  const serviceVersion = options.serviceVersion ?? "0.1.0";
  const now = options.now ?? (() => new Date().toISOString());
  let startedAt = null;

  function startedAtUtc() {
    startedAt ??= now();
    return startedAt;
  }

  async function loadFixture() {
    if (Object.hasOwn(options, "superruntimeFixture")) return options.superruntimeFixture;
    if (options.loadSuperruntimeFixture) return options.loadSuperruntimeFixture();
    return null;
  }

  async function loadRunnerEvidence() {
    if (Object.hasOwn(options, "runnerEvidence")) return options.runnerEvidence;
    if (options.loadRunnerEvidence) return options.loadRunnerEvidence();
    return null;
  }

  async function superruntime(method) {
    const runnerEvidence = await loadRunnerEvidence();
    const hasRunnerEvidence = runnerEvidence !== null && runnerEvidence !== undefined;
    if (hasRunnerEvidence) {
      const safety = inspectRunnerEvidenceSafety(runnerEvidence);
      if (!safety.safe) {
        return jsonResponse({
          schema_version: 1,
          generated_at_utc: now(),
          mode: "read-only",
          source: options.runnerEvidenceSource ?? "runner-evidence",
          error: "unsafe_runner_evidence",
          unsafe_reasons: safety.reasons,
          runner_evidence_checks: safety.checks,
          redacted_public_safe: true,
          mutation_bridge_enabled: false,
          secret_values_recorded: false,
        }, { status: 409, method });
      }
    }
    const fixture = hasRunnerEvidence ? null : await loadFixture();
    const payload = hasRunnerEvidence
      ? buildRunnerEvidenceSuperruntimePayload(runnerEvidence, {
        generatedAt: now(),
        source: options.runnerEvidenceSource ?? "runner-evidence",
      })
      : fixture
        ? buildSuperruntimePayload(fixture, {
          generatedAt: now(),
          source: options.superruntimeSource ?? "superruntime-fixture",
        })
        : buildEmptySuperruntimePayload("fixture_absent", { generatedAt: now() });
    const findings = assertStreamSafe(payload);
    if (findings.length > 0) {
      return jsonResponse({
        error: "stream_safety_violation",
        findings,
        mutation_bridge_enabled: false,
        secret_values_recorded: false,
      }, { status: 500, method });
    }
    return jsonResponse(payload, { method });
  }

  function status(method) {
    const authContext = publicAuthContext();
    return jsonResponse({
      schema_version: 1,
      generated_at_utc: now(),
      service: "windburn-fusion-bridge-api",
      version: serviceVersion,
      mode: "read-only",
      deployment_target: options.deploymentTarget ?? "cloudflare-worker-compatible",
      started_at_utc: startedAtUtc(),
      mutation_bridge_enabled: false,
      provider_webhooks_enabled: false,
      runtime_channel_enabled: false,
      secret_values_recorded: false,
      auth: authContractSummary(authContext.role),
    }, { method });
  }

  async function fetch(request) {
    const url = new URL(request.url);
    const method = request.method.toUpperCase();

    if (!["GET", "HEAD"].includes(method)) {
      return methodNotAllowed(method);
    }

    try {
      const guard = guardRoute({
        pathname: url.pathname,
        method,
        role: publicAuthContext().role,
      });
      if (!guard.allowed) {
        return jsonResponse({
          error: guard.reason,
          route_id: guard.route.id,
          required_role: guard.route.minRole,
          mutation_bridge_enabled: false,
          secret_values_recorded: false,
        }, { status: guard.status ?? 403, method });
      }

      if (url.pathname === "/healthz" || url.pathname === "/api/status") {
        return status(method);
      }
      if (url.pathname === "/api/superruntime") {
        return superruntime(method);
      }
      if (url.pathname === "/openapi.json") {
        return jsonResponse(openapi, { method });
      }
      if (url.pathname.startsWith("/api/")) {
        return jsonResponse({
          error: "unknown_api_route",
          mutation_bridge_enabled: false,
        }, { status: 404, method });
      }
      return jsonResponse({
        service: "windburn-fusion-bridge-api",
        endpoints: ["/healthz", "/api/status", "/api/superruntime", "/openapi.json"],
        mutation_bridge_enabled: false,
      }, { method });
    } catch (error) {
      return jsonResponse({
        error: "bridge_api_internal_error",
        message: redact(error.message),
        mutation_bridge_enabled: false,
        secret_values_recorded: false,
      }, { status: 500, method });
    }
  }

  return { fetch };
}
