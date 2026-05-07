#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CARD_PATH_INPUT="${1:-"$ROOT_DIR/docs/remote-workhorse/fixtures/research-run-card-v0.json"}"
CARD_PATH="$CARD_PATH_INPUT"
TMP_CARD_PATH=""

cleanup() {
  if [ -n "$TMP_CARD_PATH" ] && [ -f "$TMP_CARD_PATH" ]; then
    rm -f "$TMP_CARD_PATH"
  fi
}

trap cleanup EXIT INT TERM

if [ "$CARD_PATH_INPUT" = "-" ]; then
  umask 077
  TMP_CARD_PATH="$(mktemp "${TMPDIR:-/tmp}/windburn-research-run-card.XXXXXX.json")"
  cat >"$TMP_CARD_PATH"
  CARD_PATH="$TMP_CARD_PATH"
else
  case "$CARD_PATH" in
    /*) ;;
    *) CARD_PATH="$ROOT_DIR/$CARD_PATH" ;;
  esac
fi

node - "$CARD_PATH" <<'NODE'
const fs = require("fs");

const cardPath = process.argv[2];
const failures = [];
const ALLOWED_ACTIONS = new Set(["verify-card", "stage-run", "status"]);
const ALLOWED_MEMORY = new Set(["M0", "M1", "M2", "M3"]);
const ALLOWED_PRESSURE = new Set(["P0", "P1", "P2"]);
const ALLOWED_TASKS = new Set([
  "code-review-decision",
  "implementation-routing",
  "public-surface-safety",
  "recovery-after-failure",
]);
const ALLOWED_NETWORK = new Set(["none", "local-only"]);
const ALLOWED_EXPORT_FORMATS = new Set(["jsonl", "markdown", "parquet"]);
const REQUIRED_EVIDENCE = [
  "run_card",
  "memory_state_hash",
  "prompt_text",
  "decision_output",
  "verification_result",
  "causal_trace_notes",
  "counterfactual_pair_pointer",
];

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function fail(message) {
  failures.push(message);
}

function requireObject(value, label) {
  if (!isObject(value)) {
    fail(`${label} must be an object`);
    return false;
  }
  return true;
}

function requireString(value, label, { prefix, pattern, maxLength = 240 } = {}) {
  if (typeof value !== "string") {
    fail(`${label} must be a string`);
    return false;
  }
  if (value.trim().length === 0) {
    fail(`${label} must be non-empty`);
    return false;
  }
  if (value.length > maxLength) {
    fail(`${label} must be <= ${maxLength} chars`);
    return false;
  }
  if (prefix && !value.startsWith(prefix)) {
    fail(`${label} must start with ${prefix}`);
    return false;
  }
  if (pattern && !pattern.test(value)) {
    fail(`${label} has invalid format`);
    return false;
  }
  return true;
}

function requireBoolean(value, label, expected) {
  if (typeof value !== "boolean") {
    fail(`${label} must be boolean`);
    return false;
  }
  if (typeof expected === "boolean" && value !== expected) {
    fail(`${label} must be ${expected}`);
    return false;
  }
  return true;
}

function requireArray(value, label) {
  if (!Array.isArray(value) || value.length === 0) {
    fail(`${label} must be a non-empty array`);
    return false;
  }
  return true;
}

function collectStrings(value, path = "$", out = []) {
  if (typeof value === "string") {
    out.push({ path, value });
    return out;
  }
  if (Array.isArray(value)) {
    value.forEach((item, index) => collectStrings(item, `${path}[${index}]`, out));
    return out;
  }
  if (isObject(value)) {
    Object.entries(value).forEach(([key, item]) => {
      out.push({ path: `${path}.${key}#key`, value: key });
      collectStrings(item, `${path}.${key}`, out);
    });
  }
  return out;
}

let card;
try {
  card = JSON.parse(fs.readFileSync(cardPath, "utf8"));
} catch (error) {
  console.log(`BLOCK research_run_card_verify: invalid JSON (${error.message})`);
  process.exit(1);
}

if (requireObject(card, "card")) {
  if (card.schema_version !== 1) fail("card.schema_version must be 1");
  requireString(card.card_id, "card.card_id", {
    prefix: "rrc_",
    pattern: /^rrc_[a-z0-9_:-]+$/,
  });
  if (card.source !== "windburn-research-appliance") {
    fail('card.source must be "windburn-research-appliance"');
  }
  if (card.research_program !== "agent-memory-causality") {
    fail('card.research_program must be "agent-memory-causality" for v0');
  }
  requireString(card.research_question, "card.research_question", { maxLength: 320 });
  if (card.repo !== "Fearvox/project-windburn") {
    fail('card.repo must be "Fearvox/project-windburn"');
  }
  requireString(card.rv_target, "card.rv_target", {
    prefix: "research-programs/agent-memory-causality/evidence/",
    maxLength: 160,
  });
  if (!ALLOWED_ACTIONS.has(card.requested_action)) {
    fail("card.requested_action must be verify-card, stage-run, or status");
  }
  if (requireArray(card.allowed_actions, "card.allowed_actions")) {
    for (const [index, action] of card.allowed_actions.entries()) {
      if (typeof action !== "string" || !ALLOWED_ACTIONS.has(action)) {
        fail(`card.allowed_actions[${index}] is not allowed`);
      }
    }
    if (typeof card.requested_action === "string" && !card.allowed_actions.includes(card.requested_action)) {
      fail("card.requested_action must be included in card.allowed_actions");
    }
  }
  if (!["dry-run", "stage-only"].includes(card.runner_mode)) {
    fail("card.runner_mode must be dry-run or stage-only in v0");
  }
  if (!ALLOWED_TASKS.has(card.task_family)) {
    fail("card.task_family is not allowed for v0");
  }
  if (!ALLOWED_MEMORY.has(card.memory_condition)) {
    fail("card.memory_condition must be M0, M1, M2, or M3");
  }
  if (!ALLOWED_PRESSURE.has(card.pressure_condition)) {
    fail("card.pressure_condition must be P0, P1, or P2");
  }
  requireString(card.counterfactual_pair, "card.counterfactual_pair", {
    pattern: /^[A-Za-z0-9._:-]+$/,
    maxLength: 80,
  });
  requireString(card.prompt_ref, "card.prompt_ref", {
    prefix: "rv:research-programs/agent-memory-causality/",
    maxLength: 180,
  });
  requireString(card.memory_state_hash, "card.memory_state_hash", {
    pattern: /^sha256:[a-f0-9]{64}$/,
    maxLength: 71,
  });
  if (requireArray(card.evidence_requirements, "card.evidence_requirements")) {
    for (const requirement of REQUIRED_EVIDENCE) {
      if (!card.evidence_requirements.includes(requirement)) {
        fail(`card.evidence_requirements missing ${requirement}`);
      }
    }
  }
  if (requireObject(card.safety, "card.safety")) {
    requireBoolean(card.safety.remote_mutation, "card.safety.remote_mutation", false);
    requireBoolean(card.safety.secret_access, "card.safety.secret_access", false);
    requireBoolean(card.safety.provider_writeback, "card.safety.provider_writeback", false);
    requireBoolean(card.safety.public_safe, "card.safety.public_safe", true);
    if (!ALLOWED_NETWORK.has(card.safety.network)) {
      fail("card.safety.network must be none or local-only");
    }
    if (card.safety.stream_policy !== "redacted") {
      fail('card.safety.stream_policy must be "redacted"');
    }
  }
  if (requireObject(card.huggingface, "card.huggingface")) {
    requireBoolean(card.huggingface.publish_dataset, "card.huggingface.publish_dataset", false);
    requireBoolean(card.huggingface.gated_until_review, "card.huggingface.gated_until_review", true);
    if (card.huggingface.dataset_repo !== null) {
      fail("card.huggingface.dataset_repo must be null until publication review");
    }
    if (requireArray(card.huggingface.export_formats, "card.huggingface.export_formats")) {
      for (const [index, format] of card.huggingface.export_formats.entries()) {
        if (typeof format !== "string" || !ALLOWED_EXPORT_FORMATS.has(format)) {
          fail(`card.huggingface.export_formats[${index}] is not allowed`);
        }
      }
    }
  }
  requireString(card.expected_output, "card.expected_output", { maxLength: 240 });
}

for (const { path, value } of collectStrings(card)) {
  if (/hf_[A-Za-z0-9]{12,}/.test(value) || /sk-[A-Za-z0-9]{12,}/.test(value)) {
    fail(`${path} contains token-like text`);
  }
  if (/\b(?:\d{1,3}\.){3}\d{1,3}\b/.test(value)) {
    fail(`${path} contains raw IPv4-like text`);
  }
  if (/\/Users\/|\/root\/\.|\.rtf\b|auth\.json\b|provider\.env\b/.test(value)) {
    fail(`${path} contains private path-like text`);
  }
}

if (failures.length > 0) {
  console.log("BLOCK research_run_card_verify");
  for (const failure of failures) {
    console.log(`- ${failure}`);
  }
  process.exit(1);
}

console.log("PASS research_run_card_verify");
console.log(`card_id=${card.card_id}`);
console.log(`research_program=${card.research_program}`);
console.log(`requested_action=${card.requested_action}`);
console.log(`memory_condition=${card.memory_condition}`);
console.log(`pressure_condition=${card.pressure_condition}`);
console.log("secret_values_recorded=false");
console.log("redacted_public_safe=true");
NODE
