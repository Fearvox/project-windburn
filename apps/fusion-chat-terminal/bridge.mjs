#!/usr/bin/env node
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { readFile, realpath, stat } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  buildEmptySuperruntimePayload,
  buildRunnerEvidenceSuperruntimePayload,
  buildSuperruntimePayload,
  inspectRunnerEvidenceSafety,
} from "../../packages/fusion-bridge-api/src/superruntime.mjs";

const appDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(appDir, "../..");
const host = process.env.WINDBURN_FUSION_CHAT_HOST ?? "127.0.0.1";
const port = Number(process.env.WINDBURN_FUSION_CHAT_PORT ?? "5178");
const superconductorBinding =
  process.env.WINDBURN_SUPERCONDUCTOR_BINDING ??
  path.resolve(root, "../superconductor/projects/Windburn");
const superruntimeFixturePath = path.join(
  root,
  "docs/remote-workhorse/fixtures/superruntime-v0.json",
);
const runnerEvidencePath =
  process.env.WINDBURN_RUNNER_EVIDENCE_PATH ??
  "/srv/windburn/evidence/runner/current.json";

const contentTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".woff2", "font/woff2"],
  [".txt", "text/plain; charset=utf-8"],
  [".md", "text/markdown; charset=utf-8"],
]);

const routeBlueprints = [
  {
    id: "hermes",
    name: "Hermes Yolo",
    host: "public host hidden",
    kind: "tmux",
    transport: "tmux attach target hidden",
    command: "operator command hidden",
    taste: "primary high-context chat lane",
    proof: "docs/remote-workhorse/preflight/WORKHORSE_HERMES_YOLO_LANE_PROOF.md",
    runnerEvidence: "hermes_yolo",
  },
  {
    id: "workhorse",
    name: "NixOS Workhorse",
    host: "public host hidden",
    kind: "nixos",
    transport: "NixOS rebuild target hidden",
    command: "operator command hidden",
    taste: "remote build and runner cell",
    proof: "docs/remote-workhorse/preflight/NIXOS_FOUNDATION_PROOF.md",
    runnerEvidence: true,
  },
  {
    id: "ccr",
    name: "CCR Embed",
    host: "internal host hidden",
    kind: "internal",
    transport: "embedding route hidden",
    command: "operator command hidden",
    taste: "embedding and review substrate",
    proof: "docs/remote-workhorse/preflight/DROPLET_ENGAGEMENT_REVIEW.md",
  },
  {
    id: "codex",
    name: "Local Codex",
    host: "local workspace hidden",
    kind: "local",
    transport: "workspace shell hidden",
    command: "operator command hidden",
    taste: "operator control plane",
    proof: "docs/remote-workhorse/phase1/CANARY-read-only-repo-review-health.md",
  },
  {
    id: "superconductor",
    name: "Superconductor",
    host: "workspace binding hidden",
    kind: "shell",
    transport: "repo anchor hidden",
    command: "operator command hidden",
    taste: "multi-workspace dispatch surface",
    proof: null,
  },
];

const preflightProofs = [
  ["Hermes yolo tmux lane", "docs/remote-workhorse/preflight/WORKHORSE_HERMES_YOLO_LANE_PROOF.md"],
  ["xAI setup lane", "docs/remote-workhorse/preflight/XAI_SETUP_AGENT_SMOKE.md"],
  ["NixOS foundation", "docs/remote-workhorse/preflight/NIXOS_FOUNDATION_PROOF.md"],
  ["DO uptime and alerts", "docs/remote-workhorse/preflight/DIGITALOCEAN_OBSERVABILITY_GATE.md"],
  ["CCR public route", "docs/remote-workhorse/preflight/DROPLET_ENGAGEMENT_REVIEW.md"],
  ["Local canary", "docs/remote-workhorse/phase1/CANARY-read-only-repo-review-health.md"],
];

function redact(text) {
  return String(text)
    .replace(/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, "[redacted:host]")
    .replace(/\b(?:[A-Fa-f0-9]{1,4}:){2,}[A-Fa-f0-9:]{1,}\b/g, "[redacted:host]")
    .replace(/\/Users\/[^\s"'`),]+/g, "[redacted:local-path]")
    .replace(/\/srv\/[^\s"'`),]+/g, "[redacted:remote-path]")
    .replace(/\bssh\s+[^\n]+/gi, "ssh [redacted:target]")
    .replace(/([A-Za-z0-9._%+-]+)@([A-Za-z0-9.-]+\.[A-Za-z]{2,})/g, "[redacted:email]")
    .replace(/Bearer\s+[A-Za-z0-9._-]+/g, "Bearer [redacted]")
    .replace(/(?<=[?&](?:token|key|secret|password)=)[^&\s]+/gi, "[redacted]")
    .replace(/(xai-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]{32,}/g, "$1[redacted]")
    .replace(/(sk-[A-Za-z0-9_-]{8})[A-Za-z0-9_-]{32,}/g, "$1[redacted]");
}

function streamSafeRoute(route) {
  const hostLabel =
    route.kind === "local"
      ? "local workspace hidden"
      : route.kind === "shell"
        ? "workspace binding hidden"
        : route.kind === "internal"
          ? "internal host hidden"
          : "public host hidden";
  const transportLabel =
    route.kind === "tmux"
      ? "tmux attach target hidden"
      : route.kind === "nixos"
        ? "NixOS rebuild target hidden"
        : route.kind === "internal"
          ? "embedding route hidden"
          : route.kind === "local"
            ? "workspace shell hidden"
            : "repo anchor hidden";

  return {
    host: hostLabel,
    transport: transportLabel,
    command: "operator command hidden",
    redacted_fields: ["host", "transport", "command"],
  };
}

function run(command, args, options = {}) {
  const timeoutMs = options.timeoutMs ?? 4000;
  const maxOutput = options.maxOutput ?? 20000;

  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd: options.cwd ?? root,
      env: process.env,
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    let settled = false;

    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({
        ...result,
        stdout: redact(stdout.slice(0, maxOutput)),
        stderr: redact(stderr.slice(0, maxOutput)),
      });
    };

    const timer = setTimeout(() => {
      child.kill("SIGTERM");
      finish({ ok: false, code: null, signal: "timeout" });
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", (error) => {
      finish({ ok: false, code: null, error: error.message });
    });
    child.on("close", (code, signal) => {
      finish({ ok: code === 0, code, signal });
    });
  });
}

async function git(args, fallback = "") {
  const result = await run("git", args, { timeoutMs: 2500, maxOutput: 12000 });
  return result.ok ? result.stdout.trim() : fallback;
}

async function repoStatus() {
  const [branch, head, statusShort, origin, aheadMain, binding] = await Promise.all([
    git(["rev-parse", "--abbrev-ref", "HEAD"], "unknown"),
    git(["rev-parse", "--short", "HEAD"], "unknown"),
    git(["status", "--short", "--branch"], ""),
    git(["remote", "get-url", "origin"], "missing"),
    git(["rev-list", "--count", "main..HEAD"], "unknown"),
    superconductorBindingStatus(),
  ]);

  const statusLines = statusShort.split(/\r?\n/).filter(Boolean);
  const worktreeLines = statusLines.slice(1);
  const untrackedCount = worktreeLines.filter((line) => line.startsWith("?? ")).length;
  const trackedDirty = worktreeLines.some((line) => !line.startsWith("?? "));
  return {
    root: "local workspace hidden",
    branch,
    head,
    origin,
    ahead_of_main: Number.isNaN(Number(aheadMain)) ? aheadMain : Number(aheadMain),
    dirty: trackedDirty,
    tracked_dirty: trackedDirty,
    untracked_count: untrackedCount,
    status_short: `tracked_dirty=${String(trackedDirty)} untracked_count=${untrackedCount}`,
    superconductor_binding: binding.status,
    superconductor_binding_path: binding.path ? "workspace binding hidden" : null,
  };
}

async function superconductorBindingStatus() {
  if (!existsSync(superconductorBinding)) {
    return { status: "missing", path: null };
  }

  try {
    const [bindingRealpath, rootRealpath] = await Promise.all([
      realpath(superconductorBinding),
      realpath(root),
    ]);
    return {
      status: bindingRealpath === rootRealpath ? "present" : "points_elsewhere",
      path: bindingRealpath,
    };
  } catch {
    return { status: "unreadable", path: null };
  }
}

async function readProof(relativePath) {
  const absolutePath = path.join(root, relativePath);
  if (!existsSync(absolutePath)) {
    return {
      status: "FLAG",
      reason: "proof_missing",
      source: relativePath,
      modified_at: null,
    };
  }

  const [text, fileStat] = await Promise.all([
    readFile(absolutePath, "utf8"),
    stat(absolutePath),
  ]);
  const verdict =
    text.match(/VERDICT:\s*`?(PASS|FLAG|BLOCK)`?/i)?.[1] ??
    text.match(/\bverdict=(PASS|FLAG|BLOCK)\b/i)?.[1] ??
    text.match(/"verdict":\s*"(PASS|FLAG|BLOCK)"/i)?.[1] ??
    "FLAG";
  const reason =
    text.match(/Reason:\s*`?([^`\n]+)`?/i)?.[1]?.trim() ??
    text.match(/\breason=([A-Z0-9_-]+)/i)?.[1]?.trim() ??
    text.match(/"reason":\s*"([^"]+)"/i)?.[1]?.trim() ??
    "proof_read";

  return {
    status: verdict.toUpperCase(),
    reason: redact(reason),
    source: relativePath,
    modified_at: fileStat.mtime.toISOString(),
  };
}

async function buildRemotes() {
  const binding = await superconductorBindingStatus();
  const runnerEvidence = await readRunnerEvidence();
  const runnerEvidenceSafe = runnerEvidence ? inspectRunnerEvidenceSafety(runnerEvidence).safe : false;
  const remotes = await Promise.all(
    routeBlueprints.map(async (route) => {
      const proof = route.proof ? await readProof(route.proof) : null;
      const runnerProof = route.runnerEvidence && runnerEvidenceSafe
        ? route.runnerEvidence === "hermes_yolo"
          ? hermesYoloRouteProof(runnerEvidence)
          : runnerEvidenceRouteProof(runnerEvidence)
        : null;
      const superconductorRoute = route.id === "superconductor";
      const superconductorMissing =
        superconductorRoute && binding.status !== "present";
      const status = superconductorMissing
        ? "FLAG"
        : runnerProof
          ? runnerProof.status
          : superconductorRoute
            ? "PASS"
            : proof?.status ?? "FLAG";
      const latency = superconductorMissing
        ? binding.status
        : superconductorRoute
          ? "binding present"
          : runnerProof?.reason ?? proof?.reason ?? "live proof";

      return {
        ...streamSafeRoute(route),
        id: route.id,
        name: route.name,
        kind: route.kind,
        status,
        latency,
        taste: route.taste,
        bridge: "read-only-live",
        proof: runnerProof ?? proof ?? (superconductorRoute ? {
          status,
          reason: latency,
          source: "workspace binding hidden",
          modified_at: null,
        } : null),
      };
    }),
  );

  return {
    schema_version: 1,
    generated_at_utc: new Date().toISOString(),
    bridge: "read-only-live",
    remotes,
  };
}

async function readRunnerEvidence() {
  if (!existsSync(runnerEvidencePath)) return null;
  return JSON.parse(await readFile(runnerEvidencePath, "utf8"));
}

function runnerEvidenceRouteProof(evidence) {
  const latestSmoke = evidence?.latest_hermes_codex_smoke && typeof evidence.latest_hermes_codex_smoke === "object"
    ? evidence.latest_hermes_codex_smoke
    : {};
  const status = String(evidence?.status ?? "FLAG").toUpperCase();
  const smokeVerdict = String(latestSmoke.verdict ?? "UNKNOWN").toUpperCase();
  const tmuxPresent = evidence?.tmux?.session_present === true;
  return {
    status: ["PASS", "FLAG", "BLOCK"].includes(status) ? status : "FLAG",
    reason: status === "PASS" && smokeVerdict === "PASS" && tmuxPresent
      ? "runner ready"
      : redact(evidence?.reason ?? "runner evidence read"),
    source: "runner evidence current",
    modified_at: evidence?.generated_at_utc ?? null,
  };
}

function hermesYoloRouteProof(evidence) {
  const payload = buildRunnerEvidenceSuperruntimePayload(evidence, {
    source: "runner-evidence",
  });
  const yolo = payload.hermes_yolo ?? {};
  const status = yolo.status === "UNAVAILABLE" ? "FLAG" : yolo.status;
  const paneLabel = yolo.pane_alive ? "pane alive" : "pane unavailable";
  const processCount = Number.isFinite(Number(yolo.process_count)) ? Number(yolo.process_count) : 0;

  return {
    status: ["PASS", "FLAG", "BLOCK"].includes(status) ? status : "FLAG",
    reason: yolo.status === "PASS"
      ? `${paneLabel}; processes=${processCount}`
      : `hermes_yolo ${String(yolo.status ?? "UNAVAILABLE").toLowerCase()}`,
    source: "runner evidence hermes_yolo",
    modified_at: yolo.updated_at ?? evidence?.generated_at_utc ?? null,
  };
}

async function buildPreflight() {
  const preflight = await Promise.all(
    preflightProofs.map(async ([label, source]) => {
      const proof = await readProof(source);
      return {
        label,
        status: proof.status.toLowerCase(),
        reason: proof.reason,
        source,
        modified_at: proof.modified_at,
      };
    }),
  );

  return {
    schema_version: 1,
    generated_at_utc: new Date().toISOString(),
    preflight,
  };
}

async function buildSuperruntimeFixture() {
  try {
    const evidence = await readRunnerEvidence();
    if (evidence) {
      const safety = inspectRunnerEvidenceSafety(evidence);
      if (!safety.safe) {
        return {
          ...buildEmptySuperruntimePayload("unsafe_runner_evidence"),
          unsafe_reasons: safety.reasons,
          runner_evidence_checks: safety.checks,
        };
      }
      return buildRunnerEvidenceSuperruntimePayload(evidence, {
        source: "runner-evidence",
      });
    }
  } catch (error) {
    return {
      ...buildEmptySuperruntimePayload("runner_evidence_unreadable"),
      error: redact(error.message),
    };
  }

  if (!existsSync(superruntimeFixturePath)) {
    return buildEmptySuperruntimePayload("fixture_absent");
  }

  try {
    const fixture = JSON.parse(await readFile(superruntimeFixturePath, "utf8"));
    return buildSuperruntimePayload(fixture, {
      source: "docs/remote-workhorse/fixtures/superruntime-v0.json",
    });
  } catch (error) {
    return {
      ...buildEmptySuperruntimePayload("fixture_unreadable"),
      error: redact(error.message),
    };
  }
}

function parseKeyValueOutput(stdout) {
  const fields = {};
  stdout.split(/\r?\n/).forEach((line) => {
    const index = line.indexOf("=");
    if (index <= 0) return;
    fields[line.slice(0, index)] = line.slice(index + 1);
  });
  return fields;
}

async function inspectXaiSetup() {
  const result = await run("scripts/xai-setup-agent.sh", [], {
    timeoutMs: 15000,
    maxOutput: 12000,
  });
  const fields = parseKeyValueOutput(result.stdout);
  return {
    schema_version: 1,
    generated_at_utc: new Date().toISOString(),
    ok: result.ok,
    exit_code: result.code,
    verdict: fields.verdict ?? (result.ok ? "PASS" : "FLAG"),
    reason: fields.reason ?? (result.ok ? "XAI_CREDENTIAL_SHAPE_OK" : "XAI_SETUP_INSPECT_FAILED"),
    credential_file: fields.credential_file ? "operator credential path hidden" : null,
    base_url_kind: fields.base_url_kind ?? null,
    model: fields.model ?? null,
    secret_values_recorded: false,
    stdout: result.stdout ? "redacted inspect transcript" : "",
    stderr: result.stderr ? "redacted inspect errors" : "",
  };
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
  });
  response.end(JSON.stringify(payload, null, 2));
}

async function sendStatic(requestUrl, response) {
  const rawPath = requestUrl.pathname === "/" ? "/index.html" : requestUrl.pathname;
  const decodedPath = decodeURIComponent(rawPath);
  const absolutePath = path.resolve(appDir, `.${decodedPath}`);

  if (!absolutePath.startsWith(appDir) || path.basename(absolutePath) === "bridge.mjs") {
    response.writeHead(403, { "content-type": "text/plain; charset=utf-8" });
    response.end("forbidden");
    return;
  }

  try {
    const bytes = await readFile(absolutePath);
    response.writeHead(200, {
      "content-type": contentTypes.get(path.extname(absolutePath)) ?? "application/octet-stream",
      "cache-control": "no-store",
    });
    response.end(bytes);
  } catch {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("not found");
  }
}

const server = createServer(async (request, response) => {
  const requestUrl = new URL(request.url ?? "/", `http://${host}:${port}`);

  try {
    if (requestUrl.pathname === "/api/status" && request.method === "GET") {
      const repo = await repoStatus();
      sendJson(response, 200, {
        schema_version: 1,
        generated_at_utc: new Date().toISOString(),
        mode: "read-only",
        bridge: "read-only-live",
        repo,
        server: {
          pid: process.pid,
          host,
          port,
          app_dir: "local app path hidden",
        },
        pipeline: {
          superconductor_cli: "pending",
          note: "When Superconductor CLI pipeline mode lands, this bridge should consume it as another read-only intake source first.",
        },
        secret_values_recorded: false,
      });
      return;
    }

    if (requestUrl.pathname === "/api/remotes" && request.method === "GET") {
      sendJson(response, 200, await buildRemotes());
      return;
    }

    if (requestUrl.pathname === "/api/preflight" && request.method === "GET") {
      sendJson(response, 200, await buildPreflight());
      return;
    }

    if (requestUrl.pathname === "/api/superruntime" && request.method === "GET") {
      sendJson(response, 200, await buildSuperruntimeFixture());
      return;
    }

    if (requestUrl.pathname === "/api/setup/xai/inspect" && request.method === "POST") {
      const payload = await inspectXaiSetup();
      sendJson(response, payload.ok ? 200 : 500, payload);
      return;
    }

    if (requestUrl.pathname.startsWith("/api/")) {
      sendJson(response, 404, {
        error: "unknown_api_route",
        mutation_bridge_enabled: false,
      });
      return;
    }

    if (request.method !== "GET" && request.method !== "HEAD") {
      response.writeHead(405, { "content-type": "text/plain; charset=utf-8" });
      response.end("method not allowed");
      return;
    }

    await sendStatic(requestUrl, response);
  } catch (error) {
    sendJson(response, 500, {
      error: "bridge_internal_error",
      message: redact(error.message),
      mutation_bridge_enabled: false,
    });
  }
});

server.listen(port, host, () => {
  console.log(`fusion_chat_url=http://${host}:${port}`);
  console.log("serving=apps/fusion-chat-terminal");
  console.log("mode=read-only-bridge");
  console.log("mutation_bridge_enabled=false");
});
