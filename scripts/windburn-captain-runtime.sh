#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CARD_INPUT=""
ACTION_OVERRIDE=""
SPOOL_DIR="${WINDBURN_RUNTIME_SPOOL_DIR:-"$ROOT_DIR/.windburn/runtime-spool"}"
MAX_PARALLEL="${WINDBURN_RUNTIME_MAX_PARALLEL:-10}"
SPOOL_CARD_DIR=""
SPOOL_RUN_DIR=""
SPOOL_STATUS_DIR=""
SPOOL_LOCK_DIR=""
SPOOL_TMP_DIR=""
TMP_CARD_PATH=""
CARD_PATH=""
VERIFY_OUTPUT=""
CARD_ID=""
RUNTIME_ID=""
REPO_NAME=""
TARGET_ACTION=""
REQUESTED_ACTION=""
RUN_ID=""
CARD_COPY_PATH=""
RUN_OUTPUT_PATH=""
STATUS_PATH=""
STATUS_REF=""
CARD_REF=""
RUN_OUTPUT_REF=""
SLOT_LABEL="none"
SLOT_LOCK_PATH=""

usage() {
  cat <<'EOF'
Usage:
  scripts/windburn-captain-runtime.sh --card <path>
  scripts/windburn-captain-runtime.sh --card <path> --action status
  scripts/windburn-captain-runtime.sh --card <path> --action verify-card
  scripts/windburn-captain-runtime.sh --card <path> --action superruntime-status
  scripts/windburn-captain-runtime.sh --card <path> --action hermes-autoresearch
  scripts/windburn-captain-runtime.sh --card <path> --action run-card
EOF
}

cleanup() {
  if [ -n "$SLOT_LOCK_PATH" ] && [ -d "$SLOT_LOCK_PATH" ]; then
    rm -f "$SLOT_LOCK_PATH/pid"
    rmdir "$SLOT_LOCK_PATH" 2>/dev/null || true
    SLOT_LOCK_PATH=""
  fi
  if [ -n "$TMP_CARD_PATH" ] && [ -f "$TMP_CARD_PATH" ]; then
    rm -f "$TMP_CARD_PATH"
  fi
}

trap cleanup EXIT INT TERM

while [ "$#" -gt 0 ]; do
  case "$1" in
    --card)
      [ "$#" -ge 2 ] || {
        echo "BLOCK windburn_captain_runtime: missing value for --card"
        exit 1
      }
      CARD_INPUT="$2"
      shift 2
      ;;
    --action)
      [ "$#" -ge 2 ] || {
        echo "BLOCK windburn_captain_runtime: missing value for --action"
        exit 1
      }
      ACTION_OVERRIDE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "BLOCK windburn_captain_runtime: unknown argument $1"
      exit 1
      ;;
  esac
done

[ -n "$CARD_INPUT" ] || {
  echo "BLOCK windburn_captain_runtime: missing --card"
  exit 1
}

case "$MAX_PARALLEL" in
  ''|*[!0-9]*)
    echo "BLOCK windburn_captain_runtime: invalid WINDBURN_RUNTIME_MAX_PARALLEL"
    exit 1
    ;;
esac

[ "$MAX_PARALLEL" -gt 0 ] || {
  echo "BLOCK windburn_captain_runtime: invalid WINDBURN_RUNTIME_MAX_PARALLEL"
  exit 1
}

init_spool() {
  SPOOL_CARD_DIR="$SPOOL_DIR/cards"
  SPOOL_RUN_DIR="$SPOOL_DIR/runs"
  SPOOL_STATUS_DIR="$SPOOL_DIR/status"
  SPOOL_LOCK_DIR="$SPOOL_DIR/locks"
  SPOOL_TMP_DIR="$SPOOL_DIR/tmp"
  mkdir -p "$SPOOL_CARD_DIR" "$SPOOL_RUN_DIR" "$SPOOL_STATUS_DIR" "$SPOOL_LOCK_DIR" "$SPOOL_TMP_DIR" || {
    echo "BLOCK windburn_captain_runtime: runtime_spool_unavailable"
    exit 1
  }
}

resolve_card_path() {
  if [ "$CARD_INPUT" = "-" ]; then
    umask 077
    TMP_CARD_PATH="$(mktemp "$SPOOL_TMP_DIR/stdin-card.XXXXXX.json")" || {
      echo "BLOCK windburn_captain_runtime: runtime_spool_temp_unavailable"
      exit 1
    }
    cat >"$TMP_CARD_PATH"
    CARD_PATH="$TMP_CARD_PATH"
    return
  fi

  CARD_PATH="$CARD_INPUT"
  case "$CARD_PATH" in
    /*) ;;
    *) CARD_PATH="$ROOT_DIR/$CARD_PATH" ;;
  esac
}

verify_card() {
  VERIFY_OUTPUT="$("$ROOT_DIR/scripts/multica-runtime-card-verify.sh" "$CARD_PATH" 2>&1)" || {
    printf '%s\n' "$VERIFY_OUTPUT"
    exit 1
  }
}

load_card_meta() {
  META_OUTPUT="$(
    CARD_PATH="$CARD_PATH" ACTION_OVERRIDE="$ACTION_OVERRIDE" node - <<'NODE'
const fs = require("fs");
const card = JSON.parse(fs.readFileSync(process.env.CARD_PATH, "utf8"));
const targetAction = process.env.ACTION_OVERRIDE || card.requested_action;
console.log(card.card_id);
console.log(card.runtime_id);
console.log(card.repo);
console.log(targetAction);
console.log(card.requested_action);
NODE
  )"
  CARD_ID="$(printf '%s\n' "$META_OUTPUT" | sed -n '1p')"
  RUNTIME_ID="$(printf '%s\n' "$META_OUTPUT" | sed -n '2p')"
  REPO_NAME="$(printf '%s\n' "$META_OUTPUT" | sed -n '3p')"
  TARGET_ACTION="$(printf '%s\n' "$META_OUTPUT" | sed -n '4p')"
  REQUESTED_ACTION="$(printf '%s\n' "$META_OUTPUT" | sed -n '5p')"
}

dispatch_safe_action() {
  ROOT_DIR="$ROOT_DIR" CARD_PATH="$CARD_PATH" ACTION_OVERRIDE="$1" VERIFY_OUTPUT="$VERIFY_OUTPUT" WINDBURN_RUNTIME_MAX_PARALLEL="$MAX_PARALLEL" node - <<'NODE'
const fs = require("fs");
const { execFileSync, spawnSync } = require("child_process");
const path = require("path");

const rootDir = process.env.ROOT_DIR;
const cardPath = process.env.CARD_PATH;
const actionOverride = process.env.ACTION_OVERRIDE;
const verifyOutput = process.env.VERIFY_OUTPUT;
const allowedActions = new Set(["status", "verify-card", "superruntime-status", "hermes-autoresearch"]);

function loadJson(filePath, label) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    console.log(`BLOCK windburn_captain_runtime: invalid ${label} (${error.message})`);
    process.exit(1);
  }
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function git(args, fallback) {
  try {
    return execFileSync("git", args, {
      cwd: rootDir,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    }).trim();
  } catch {
    return fallback;
  }
}

function runScript(scriptPath, args = []) {
  const result = spawnSync(scriptPath, args, {
    cwd: rootDir,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`.trim();
  return {
    ok: result.status === 0,
    output,
    level: output.match(/\b(PASS|FLAG|BLOCK)\b/)?.[1] ?? "BLOCK",
  };
}

function parsePositiveInt(value, fallback) {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
}

function boolEnv(name) {
  return ["1", "true", "yes", "on"].includes(String(process.env[name] || "").toLowerCase());
}

function extractVerdict(output, fallback = "BLOCK") {
  const matches = String(output || "").match(/\b(PASS|FLAG|BLOCK)\b/g);
  return matches?.at(-1) ?? fallback;
}

function isRateLimited(output) {
  return /\b429\b|rate[_ -]?limit(?:ed)?\b/i.test(String(output || ""));
}

function computeEffectiveParallel(topicCount, requestedMaxParallel) {
  const runtimeCap = parsePositiveInt(
    process.env.WINDBURN_HERMES_AUTORESEARCH_MAX_PARALLEL,
    parsePositiveInt(process.env.WINDBURN_RUNTIME_MAX_PARALLEL, 10),
  );
  const requestedCap = Number.isInteger(requestedMaxParallel) ? requestedMaxParallel : topicCount || 1;
  return Math.max(1, Math.min(10, runtimeCap, requestedCap, topicCount || 1));
}

function latestStatusByTask(events) {
  const order = new Map([
    ["queued", 0],
    ["leased", 1],
    ["worktree-prep", 2],
    ["running", 3],
    ["verifying", 4],
    ["done", 5],
  ]);
  const latest = new Map();
  for (const event of events) {
    const current = latest.get(event.task_id);
    if (!current) {
      latest.set(event.task_id, event);
      continue;
    }
    const currentOrder = order.get(current.phase) ?? -1;
    const nextOrder = order.get(event.phase) ?? -1;
    if (nextOrder >= currentOrder) {
      latest.set(event.task_id, event);
    }
  }
  return [...latest.values()];
}

function severity(level) {
  return { PASS: 0, FLAG: 1, BLOCK: 2 }[level] ?? 2;
}

const card = loadJson(cardPath, "runtime card");
const action = actionOverride || card.requested_action;

if (!allowedActions.has(action)) {
  console.log("BLOCK windburn_captain_runtime: unknown action");
  process.exit(1);
}

if (!Array.isArray(card.allowed_actions) || !card.allowed_actions.includes(action)) {
  console.log("BLOCK windburn_captain_runtime: action not allowed");
  process.exit(1);
}

if (action === "verify-card") {
  console.log(verifyOutput);
  console.log("WINDBURN_CAPTAIN_RUNTIME_VERIFY");
  console.log(`generated_utc=${new Date().toISOString()}`);
  console.log(`card_id=${card.card_id}`);
  console.log(`runtime_id=${card.runtime_id}`);
  console.log(`repo=${card.repo}`);
  console.log(`requested_action=${action}`);
  console.log(`stream_policy=${card.stream_policy}`);
  console.log("verdict=PASS");
  process.exit(0);
}

if (action === "status") {
  const branch = git(["rev-parse", "--abbrev-ref", "HEAD"], card.branch || "unknown");
  const statusShort = git(["status", "--porcelain"], "");
  const gitStatus = statusShort.length === 0 ? "clean" : "dirty";
  const fixtureResult = runScript(path.join(rootDir, "scripts/superruntime-fixture-verify.sh"));
  let verdict = fixtureResult.level;
  if (verdict === "PASS" && gitStatus === "dirty") {
    verdict = "FLAG";
  }
  const nextAction =
    fixtureResult.level === "BLOCK"
      ? "repair_superruntime_fixture"
      : gitStatus === "dirty"
        ? "review_dirty_repo"
        : "superruntime-status";

  console.log("WINDBURN_CAPTAIN_RUNTIME");
  console.log(`generated_utc=${new Date().toISOString()}`);
  console.log(`card_id=${card.card_id}`);
  console.log(`runtime_id=${card.runtime_id}`);
  console.log(`repo=${card.repo}`);
  console.log(`branch=${branch}`);
  console.log(`git_status=${gitStatus}`);
  console.log(`requested_action=${action}`);
  console.log(`remote_mutation_allowed=${String(card.permissions?.remote_mutation === true)}`);
  console.log(`secret_access_allowed=${String(card.permissions?.secret_access === true)}`);
  console.log(`provider_writeback_allowed=${String(card.permissions?.provider_writeback === true)}`);
  console.log(`stream_policy=${card.stream_policy}`);
  console.log(`superruntime_fixture=${fixtureResult.level}`);
  console.log(`next_action=${nextAction}`);
  console.log(`verdict=${verdict}`);
  process.exit(verdict === "BLOCK" ? 1 : 0);
}

if (action === "hermes-autoresearch") {
  const actionPayload = isObject(card.action_payload) ? card.action_payload : {};
  const topics = Array.isArray(actionPayload.topics)
    ? actionPayload.topics.filter((topic) => typeof topic === "string" && topic.trim().length > 0)
    : [];
  const topicCount = topics.length;
  const maxParallelEffective = computeEffectiveParallel(topicCount, actionPayload.max_parallel);
  const configured = boolEnv("WINDBURN_HERMES_AUTORESEARCH_ENABLED");
  const healthPreflightEnabled = boolEnv("WINDBURN_HERMES_AUTORESEARCH_HEALTH_PREFLIGHT");
  const executeEnabled = boolEnv("WINDBURN_HERMES_AUTORESEARCH_EXECUTE");
  const artifactRefs = ["local:hermes-autoresearch"];
  let verdict = "PASS";
  let phase = "ready";
  let reason = "hermes_autoresearch_ready_safe_default";
  let providerRateLimited = false;
  let healthPreflight = "SKIP";

  if (!configured) {
    verdict = "FLAG";
    phase = "not-configured";
    reason = "hermes_autoresearch_not_configured";
  } else {
    if (healthPreflightEnabled) {
      const healthResult = runScript(path.join(rootDir, "scripts/hermes-health-gate.sh"));
      healthPreflight = healthResult.level;
      artifactRefs.push("local:hermes-health-gate");
      if (healthResult.level === "BLOCK") {
        verdict = "BLOCK";
        phase = "health-preflight";
        reason = "hermes_health_gate_blocked";
      } else if (healthResult.level === "FLAG") {
        verdict = "FLAG";
        phase = "health-preflight";
        reason = "hermes_health_gate_flagged";
      }
    }

    if (executeEnabled && verdict !== "BLOCK") {
      const runnerPath = String(process.env.WINDBURN_HERMES_AUTORESEARCH_RUNNER || "");
      if (!runnerPath) {
        verdict = "FLAG";
        phase = "execution-gate";
        reason = "hermes_autoresearch_runner_missing";
      } else {
        const runnerPayload = {
          schema_version: 1,
          action: "hermes-autoresearch",
          card_id: card.card_id,
          runtime_id: card.runtime_id,
          repo: card.repo,
          topic_count: topicCount,
          topics,
          scope: actionPayload.scope ?? null,
          max_parallel_effective: maxParallelEffective,
          evidence_target: actionPayload.evidence_target ?? null,
          stream_policy: "redacted",
        };
        const runnerResult = spawnSync(runnerPath, [], {
          cwd: rootDir,
          encoding: "utf8",
          input: `${JSON.stringify(runnerPayload)}\n`,
          stdio: ["pipe", "pipe", "pipe"],
        });
        const runnerOutput = `${runnerResult.stdout ?? ""}${runnerResult.stderr ?? ""}`.trim();
        artifactRefs.push("local:hermes-autoresearch-runner");
        providerRateLimited = isRateLimited(runnerOutput);
        phase = "provider-call";
        if (providerRateLimited) {
          verdict = "FLAG";
          reason = "provider_rate_limited";
        } else {
          verdict = extractVerdict(runnerOutput, runnerResult.status === 0 ? "PASS" : "BLOCK");
          reason =
            verdict === "PASS"
              ? "hermes_autoresearch_runner_pass"
              : verdict === "FLAG"
                ? "hermes_autoresearch_runner_flagged"
                : "hermes_autoresearch_runner_blocked";
        }
      }
    }
  }

  console.log("WINDBURN_HERMES_AUTORESEARCH");
  console.log(`generated_utc=${new Date().toISOString()}`);
  console.log(`card_id=${card.card_id}`);
  console.log(`runtime_id=${card.runtime_id}`);
  console.log(`repo=${card.repo}`);
  console.log("action=hermes-autoresearch");
  console.log(`requested_action=${action}`);
  console.log(`topic_count=${topicCount}`);
  console.log(`max_parallel_effective=${maxParallelEffective}`);
  console.log(`phase=${phase}`);
  console.log(`level=${verdict.toLowerCase()}`);
  console.log(`health_preflight=${healthPreflight}`);
  console.log(`provider_rate_limited=${String(providerRateLimited)}`);
  console.log("secret_values_recorded=false");
  console.log(`artifact_refs=${artifactRefs.join(",")}`);
  console.log(`reason=${reason}`);
  console.log(`verdict=${verdict}`);
  process.exit(verdict === "BLOCK" ? 1 : 0);
}

if (action === "superruntime-status") {
  const fixturePath = path.join(rootDir, "docs/remote-workhorse/fixtures/superruntime-v0.json");
  const fixture = loadJson(fixturePath, "superruntime fixture");
  const latestEvents = Array.isArray(fixture.status_events) ? latestStatusByTask(fixture.status_events) : [];
  const queuedTaskCount = latestEvents.filter((event) => event.phase !== "done").length;
  const currentLeaseStatus =
    latestEvents.some((event) => event.phase === "leased" || event.phase === "worktree-prep" || event.phase === "running" || event.phase === "verifying")
      ? "active"
      : latestEvents.some((event) => event.phase === "done")
        ? "released"
        : "absent";
  const harnessDispatchCount = Array.isArray(fixture.harness_dispatches) ? fixture.harness_dispatches.length : 0;
  const latestPhases = latestEvents.map((event) => event.phase);
  const harnessDispatchState = latestPhases.includes("verifying")
    ? "verifying"
    : latestPhases.includes("running")
      ? "running"
      : latestPhases.includes("worktree-prep")
        ? "worktree-prep"
        : latestPhases.includes("leased")
          ? "leased"
          : latestPhases.includes("done")
            ? "done"
            : latestPhases.includes("queued")
              ? "queued"
              : "absent";
  const finalStatusLevel = latestEvents.reduce((highest, event) => {
    const normalized = String(event.level || "").toUpperCase();
    if (severity(normalized) > severity(highest)) {
      return normalized;
    }
    return highest;
  }, "PASS").toLowerCase();
  const secretValuesRecorded = Array.isArray(fixture.status_events)
    ? fixture.status_events.some((event) => event.secret_values_recorded === true)
    : false;
  const verdict = secretValuesRecorded ? "BLOCK" : "PASS";

  console.log("WINDBURN_SUPERRUNTIME_STATUS");
  console.log(`generated_utc=${new Date().toISOString()}`);
  console.log(`card_id=${card.card_id}`);
  console.log(`schema_version=${fixture.schema_version ?? "unknown"}`);
  console.log(`runtime_count=${Array.isArray(fixture.runtime_registrations) ? fixture.runtime_registrations.length : 0}`);
  console.log(`queued_task_count=${queuedTaskCount}`);
  console.log(`current_lease_status=${currentLeaseStatus}`);
  console.log(`harness_dispatch_state=${harnessDispatchState}`);
  console.log(`harness_dispatch_count=${harnessDispatchCount}`);
  console.log(`final_status_level=${finalStatusLevel}`);
  console.log(`secret_values_recorded=${String(secretValuesRecorded)}`);
  console.log(`verdict=${verdict}`);
  process.exit(verdict === "BLOCK" ? 1 : 0);
}

console.log("BLOCK windburn_captain_runtime: unknown action");
process.exit(1);
NODE
}

level_from_verdict() {
  case "$1" in
    PASS) printf '%s' "pass" ;;
    FLAG) printf '%s' "flag" ;;
    BLOCK) printf '%s' "block" ;;
    *) printf '%s' "block" ;;
  esac
}

extract_field() {
  printf '%s\n' "$1" | sed -n "s/^$2=//p" | tail -n 1
}

append_artifact_refs() {
  base_refs="${1:-}"
  extra_refs="${2:-}"
  if [ -z "$extra_refs" ]; then
    printf '%s' "$base_refs"
    return
  fi
  if [ -z "$base_refs" ]; then
    printf '%s' "$extra_refs"
    return
  fi
  printf '%s,%s' "$base_refs" "$extra_refs"
}

write_status_json() {
  STATUS_PHASE="$1"
  STATUS_LEVEL="$2"
  STATUS_VERDICT="$3"
  STATUS_SLOT="$4"
  STATUS_GIT_STATUS="${5:-}"
  STATUS_SUPERRUNTIME_FIXTURE="${6:-}"
  STATUS_ARTIFACT_REFS="${7:-local:status-json}"
  STATUS_PROVIDER_RATE_LIMITED="${8:-false}"
  STATUS_TOPIC_COUNT="${9:-}"
  STATUS_MAX_PARALLEL_EFFECTIVE="${10:-}"
  STATUS_PATH="$STATUS_PATH" RUN_ID="$RUN_ID" CARD_ID="$CARD_ID" RUNTIME_ID="$RUNTIME_ID" REPO_NAME="$REPO_NAME" REQUESTED_ACTION="$REQUESTED_ACTION" \
  STATUS_PHASE="$STATUS_PHASE" STATUS_LEVEL="$STATUS_LEVEL" STATUS_VERDICT="$STATUS_VERDICT" STATUS_SLOT="$STATUS_SLOT" STATUS_GIT_STATUS="$STATUS_GIT_STATUS" \
  STATUS_SUPERRUNTIME_FIXTURE="$STATUS_SUPERRUNTIME_FIXTURE" STATUS_ARTIFACT_REFS="$STATUS_ARTIFACT_REFS" STATUS_PROVIDER_RATE_LIMITED="$STATUS_PROVIDER_RATE_LIMITED" \
  STATUS_TOPIC_COUNT="$STATUS_TOPIC_COUNT" STATUS_MAX_PARALLEL_EFFECTIVE="$STATUS_MAX_PARALLEL_EFFECTIVE" node - <<'NODE'
const fs = require("fs");
const artifactRefs = String(process.env.STATUS_ARTIFACT_REFS || "")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean);
const requestedAction = process.env.REQUESTED_ACTION;
const topicCountRaw = process.env.STATUS_TOPIC_COUNT || "";
const maxParallelRaw = process.env.STATUS_MAX_PARALLEL_EFFECTIVE || "";
const status = {
  schema_version: 1,
  run_id: process.env.RUN_ID,
  card_id: process.env.CARD_ID,
  runtime_id: process.env.RUNTIME_ID,
  repo: process.env.REPO_NAME,
  requested_action: process.env.REQUESTED_ACTION,
  phase: process.env.STATUS_PHASE,
  level: process.env.STATUS_LEVEL,
  verdict: process.env.STATUS_VERDICT,
  slot: process.env.STATUS_SLOT,
  git_status: process.env.STATUS_GIT_STATUS || null,
  superruntime_fixture: process.env.STATUS_SUPERRUNTIME_FIXTURE || null,
  secret_values_recorded: false,
  provider_rate_limited: String(process.env.STATUS_PROVIDER_RATE_LIMITED || "false") === "true",
  artifact_refs: artifactRefs,
  generated_at_utc: new Date().toISOString(),
};
if (requestedAction === "hermes-autoresearch") {
  status.action = "hermes-autoresearch";
  status.topic_count = topicCountRaw === "" ? null : Number.parseInt(topicCountRaw, 10);
  status.max_parallel_effective = maxParallelRaw === "" ? null : Number.parseInt(maxParallelRaw, 10);
}
fs.writeFileSync(process.env.STATUS_PATH, `${JSON.stringify(status)}\n`);
NODE
}

persist_verified_card() {
  CARD_COPY_PATH="$SPOOL_CARD_DIR/${RUN_ID}-${CARD_ID}.json"
  cp "$CARD_PATH" "$CARD_COPY_PATH" || {
    echo "BLOCK windburn_captain_runtime: runtime_card_copy_failed"
    exit 1
  }
  CARD_REF="local:card-copy"
}

prepare_run_artifacts() {
  RUN_ID="run_$(date -u +%Y%m%dT%H%M%SZ)_$$"
  STATUS_PATH="$SPOOL_STATUS_DIR/${RUN_ID}.json"
  RUN_OUTPUT_PATH="$SPOOL_RUN_DIR/${RUN_ID}.txt"
  STATUS_REF="local:status-json"
  RUN_OUTPUT_REF="local:run-output"
  persist_verified_card
}

acquire_slot() {
  slot_index=1
  while [ "$slot_index" -le "$MAX_PARALLEL" ]; do
    candidate_slot="$(printf 'slot-%02d' "$slot_index")"
    candidate_lock_path="$SPOOL_LOCK_DIR/${candidate_slot}.lock"
    if mkdir "$candidate_lock_path" 2>/dev/null; then
      SLOT_LABEL="$candidate_slot"
      SLOT_LOCK_PATH="$candidate_lock_path"
      printf '%s\n' "$$" >"$SLOT_LOCK_PATH/pid"
      return 0
    fi
    slot_index=$((slot_index + 1))
  done
  return 1
}

run_card_action() {
  if [ "$TARGET_ACTION" != "run-card" ]; then
    echo "BLOCK windburn_captain_runtime: unknown action"
    exit 1
  fi

  case "$REQUESTED_ACTION" in
    status|verify-card|superruntime-status|hermes-autoresearch) ;;
    *)
      prepare_run_artifacts
      write_status_json "block" "block" "BLOCK" "none" "" "" "$STATUS_REF,$CARD_REF"
      echo "BLOCK windburn_captain_runtime: unsafe_requested_action"
      echo "run_id=$RUN_ID"
      echo "card_id=$CARD_ID"
      echo "runtime_id=$RUNTIME_ID"
      echo "requested_action=$REQUESTED_ACTION"
      echo "verdict=BLOCK"
      exit 1
      ;;
  esac

  prepare_run_artifacts
  write_status_json "queued" "info" "PASS" "pending" "" "" "$STATUS_REF,$CARD_REF"

  if ! acquire_slot; then
    write_status_json "flag" "flag" "FLAG" "none" "" "" "$STATUS_REF,$CARD_REF"
    echo "FLAG windburn_captain_runtime: runtime_queue_full"
    echo "run_id=$RUN_ID"
    echo "card_id=$CARD_ID"
    echo "runtime_id=$RUNTIME_ID"
    echo "requested_action=$REQUESTED_ACTION"
    echo "status_ref=$STATUS_REF"
    echo "card_ref=$CARD_REF"
    echo "verdict=FLAG"
    exit 0
  fi

  write_status_json "leased" "info" "PASS" "$SLOT_LABEL" "" "" "$STATUS_REF,$CARD_REF"
  write_status_json "running" "info" "PASS" "$SLOT_LABEL" "" "" "$STATUS_REF,$CARD_REF,$RUN_OUTPUT_REF"

  handler_rc=0
  HANDLER_OUTPUT="$(dispatch_safe_action "$REQUESTED_ACTION" 2>&1)" || handler_rc=$?
  printf '%s\n' "$HANDLER_OUTPUT" >"$RUN_OUTPUT_PATH"

  HANDLER_VERDICT="$(printf '%s\n' "$HANDLER_OUTPUT" | grep -Eo '\b(PASS|FLAG|BLOCK)\b' | tail -n 1 || true)"
  if [ -z "$HANDLER_VERDICT" ]; then
    if [ "$handler_rc" -eq 0 ]; then
      HANDLER_VERDICT="PASS"
    else
      HANDLER_VERDICT="BLOCK"
    fi
  fi
  HANDLER_LEVEL="$(level_from_verdict "$HANDLER_VERDICT")"
  HANDLER_GIT_STATUS="$(extract_field "$HANDLER_OUTPUT" git_status)"
  HANDLER_SUPERRUNTIME_FIXTURE="$(extract_field "$HANDLER_OUTPUT" superruntime_fixture)"
  HANDLER_PROVIDER_RATE_LIMITED="$(extract_field "$HANDLER_OUTPUT" provider_rate_limited)"
  HANDLER_TOPIC_COUNT="$(extract_field "$HANDLER_OUTPUT" topic_count)"
  HANDLER_MAX_PARALLEL_EFFECTIVE="$(extract_field "$HANDLER_OUTPUT" max_parallel_effective)"
  HANDLER_ARTIFACT_REFS="$(extract_field "$HANDLER_OUTPUT" artifact_refs)"
  artifact_refs="$STATUS_REF,$CARD_REF,$RUN_OUTPUT_REF"
  if [ "$REQUESTED_ACTION" = "status" ] || [ "$REQUESTED_ACTION" = "superruntime-status" ]; then
    artifact_refs="$artifact_refs,local:superruntime-fixture"
  fi
  artifact_refs="$(append_artifact_refs "$artifact_refs" "$HANDLER_ARTIFACT_REFS")"
  final_phase="done"
  if [ "$HANDLER_VERDICT" = "FLAG" ]; then
    final_phase="flag"
  fi
  if [ "$HANDLER_VERDICT" = "BLOCK" ]; then
    final_phase="block"
  fi
  write_status_json "$final_phase" "$HANDLER_LEVEL" "$HANDLER_VERDICT" "$SLOT_LABEL" "$HANDLER_GIT_STATUS" "$HANDLER_SUPERRUNTIME_FIXTURE" "$artifact_refs" "${HANDLER_PROVIDER_RATE_LIMITED:-false}" "${HANDLER_TOPIC_COUNT:-}" "${HANDLER_MAX_PARALLEL_EFFECTIVE:-}"

  echo "$HANDLER_VERDICT windburn_captain_runtime: run-card"
  echo "run_id=$RUN_ID"
  echo "card_id=$CARD_ID"
  echo "runtime_id=$RUNTIME_ID"
  echo "requested_action=$REQUESTED_ACTION"
  echo "slot=$SLOT_LABEL"
  [ -n "$HANDLER_GIT_STATUS" ] && echo "git_status=$HANDLER_GIT_STATUS"
  [ -n "$HANDLER_SUPERRUNTIME_FIXTURE" ] && echo "superruntime_fixture=$HANDLER_SUPERRUNTIME_FIXTURE"
  echo "status_ref=$STATUS_REF"
  echo "card_ref=$CARD_REF"
  echo "output_ref=$RUN_OUTPUT_REF"
  echo "verdict=$HANDLER_VERDICT"
  exit "$handler_rc"
}

init_spool
resolve_card_path
verify_card
load_card_meta

if [ "$TARGET_ACTION" = "run-card" ]; then
  run_card_action
fi

dispatch_safe_action "$TARGET_ACTION"
