#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CARD_PATH=""
ACTION_OVERRIDE=""

usage() {
  cat <<'EOF'
Usage:
  scripts/windburn-captain-runtime.sh --card <path>
  scripts/windburn-captain-runtime.sh --card <path> --action status
  scripts/windburn-captain-runtime.sh --card <path> --action verify-card
  scripts/windburn-captain-runtime.sh --card <path> --action superruntime-status
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --card)
      [ "$#" -ge 2 ] || {
        echo "BLOCK windburn_captain_runtime: missing value for --card"
        exit 1
      }
      CARD_PATH="$2"
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

[ -n "$CARD_PATH" ] || {
  echo "BLOCK windburn_captain_runtime: missing --card"
  exit 1
}

case "$CARD_PATH" in
  /*) ;;
  *) CARD_PATH="$ROOT_DIR/$CARD_PATH" ;;
esac

VERIFY_OUTPUT="$("$ROOT_DIR/scripts/multica-runtime-card-verify.sh" "$CARD_PATH" 2>&1)" || {
  printf '%s\n' "$VERIFY_OUTPUT"
  exit 1
}

ROOT_DIR="$ROOT_DIR" CARD_PATH="$CARD_PATH" ACTION_OVERRIDE="$ACTION_OVERRIDE" VERIFY_OUTPUT="$VERIFY_OUTPUT" node - <<'NODE'
const fs = require("fs");
const { execFileSync, spawnSync } = require("child_process");
const path = require("path");

const rootDir = process.env.ROOT_DIR;
const cardPath = process.env.CARD_PATH;
const actionOverride = process.env.ACTION_OVERRIDE;
const verifyOutput = process.env.VERIFY_OUTPUT;
const allowedActions = new Set(["status", "verify-card", "superruntime-status"]);

function loadJson(filePath, label) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    console.log(`BLOCK windburn_captain_runtime: invalid ${label} (${error.message})`);
    process.exit(1);
  }
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
