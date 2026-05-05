import { openapi } from "./openapi.mjs";
import { authContractSummary, guardRoute, publicAuthContext } from "./auth-contract.mjs";
import { assertStreamSafe, redact } from "./redaction.mjs";
import {
  buildEmptySuperruntimePayload,
  buildSuperruntimePayload,
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

function websocketUpgradeRequired(method) {
  return jsonResponse({
    error: "websocket_upgrade_required",
    endpoint: "/api/superruntime/stream",
    channel: "superruntime.readonly.v0",
    runtime_channel_enabled: true,
    mutation_bridge_enabled: false,
    secret_values_recorded: false,
  }, { status: 426, method });
}

export function createFusionBridgeApi(options = {}) {
  const serviceVersion = options.serviceVersion ?? "0.2.0";
  const now = options.now ?? (() => new Date().toISOString());
  let startedAt = null;

  function startedAtUtc() {
    startedAt ??= now();
    return startedAt;
  }

  async function loadFixture() {
    if (options.superruntimeFixture) return options.superruntimeFixture;
    if (options.loadSuperruntimeFixture) return options.loadSuperruntimeFixture();
    return null;
  }

  async function superruntime(method) {
    const { payload, status } = await buildSafeSuperruntimePayload();
    return jsonResponse(payload, { status, method });
  }

  async function buildSafeSuperruntimePayload() {
    const fixture = await loadFixture();
    const payload = fixture
      ? buildSuperruntimePayload(fixture, {
        generatedAt: now(),
        source: options.superruntimeSource ?? "superruntime-fixture",
      })
      : buildEmptySuperruntimePayload("fixture_absent", { generatedAt: now() });
    const findings = assertStreamSafe(payload);
    if (findings.length > 0) {
      return {
        status: 500,
        payload: {
          error: "stream_safety_violation",
          findings,
          mutation_bridge_enabled: false,
          secret_values_recorded: false,
        },
      };
    }
    return { status: 200, payload };
  }

  function safeSocketSend(server, event) {
    server.send(JSON.stringify({
      schema_version: 1,
      generated_at_utc: now(),
      mutation_bridge_enabled: false,
      secret_values_recorded: false,
      ...event,
    }));
  }

  async function superruntimeStream(request, method) {
    if (method !== "GET") {
      return methodNotAllowed(method);
    }

    if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return websocketUpgradeRequired(method);
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    let heartbeat = 0;
    let timer = null;

    server.accept();

    function sendHeartbeat() {
      heartbeat += 1;
      safeSocketSend(server, {
        type: "bridge.heartbeat",
        channel: "superruntime.readonly.v0",
        sequence: heartbeat,
        runtime_channel_enabled: true,
      });
    }

    function closeTimer() {
      if (timer) clearInterval(timer);
      timer = null;
    }

    server.addEventListener("close", closeTimer);
    server.addEventListener("error", closeTimer);
    server.addEventListener("message", (event) => {
      const text = typeof event.data === "string" ? event.data.trim() : "";
      if (text === "ping" || text === "{\"type\":\"ping\"}") {
        sendHeartbeat();
        return;
      }

      safeSocketSend(server, {
        type: "bridge.policy",
        channel: "superruntime.readonly.v0",
        policy: "read-only-status-stream",
      });
    });

    safeSocketSend(server, {
      type: "bridge.hello",
      channel: "superruntime.readonly.v0",
      runtime_channel_enabled: true,
      provider_webhooks_enabled: false,
    });

    const { payload, status } = await buildSafeSuperruntimePayload();
    if (status >= 400 || payload.error) {
      safeSocketSend(server, {
        type: "bridge.error",
        channel: "superruntime.readonly.v0",
        payload,
      });
      server.close(1011, "stream safety violation");
    } else {
      safeSocketSend(server, {
        type: "superruntime.snapshot",
        channel: "superruntime.readonly.v0",
        payload,
      });
      sendHeartbeat();
      timer = setInterval(sendHeartbeat, 15000);
    }

    return new Response(null, {
      status: 101,
      webSocket: client,
    });
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
      runtime_channel_enabled: true,
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
      if (url.pathname === "/api/superruntime/stream") {
        return superruntimeStream(request, method);
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
        endpoints: ["/healthz", "/api/status", "/api/superruntime", "/api/superruntime/stream", "/openapi.json"],
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
