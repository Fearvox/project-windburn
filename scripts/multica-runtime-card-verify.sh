#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CARD_PATH="${1:-"$ROOT_DIR/docs/remote-workhorse/fixtures/multica-runtime-card-v0.json"}"

case "$CARD_PATH" in
  /*) ;;
  *) CARD_PATH="$ROOT_DIR/$CARD_PATH" ;;
esac

node - "$CARD_PATH" <<'NODE'
const fs = require("fs");

const cardPath = process.argv[2];
const ALLOWED_ACTIONS = new Set(["status", "verify-card", "superruntime-status"]);
const ALLOWED_PRIVACY_SCOPES = new Set(["private", "team"]);
const ALLOWED_NETWORK = new Set(["none", "local-only"]);
const ALLOWED_SIGNATURE = "stub:v0-ssh-runtime-card-not-cryptographic";
const allowedSensitiveKeys = new Set(["secret_access", "signature_stub"]);
const failures = [];

function fail(message) {
  failures.push(message);
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function requireObject(value, label) {
  if (!isObject(value)) {
    fail(`${label} must be an object`);
    return false;
  }
  return true;
}

function requireString(value, label, { prefix, nonEmpty = true } = {}) {
  if (typeof value !== "string") {
    fail(`${label} must be a string`);
    return false;
  }
  if (nonEmpty && value.trim().length === 0) {
    fail(`${label} must be a non-empty string`);
    return false;
  }
  if (prefix && !value.startsWith(prefix)) {
    fail(`${label} must start with ${prefix}`);
    return false;
  }
  return true;
}

function requireBoolean(value, label) {
  if (typeof value !== "boolean") {
    fail(`${label} must be boolean`);
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
  console.log(`BLOCK multica_runtime_card_verify: invalid JSON (${error.message})`);
  process.exit(1);
}

if (requireObject(card, "card")) {
  if (card.schema_version !== 1) {
    fail("card.schema_version must be 1");
  }
  requireString(card.card_id, "card.card_id", { prefix: "mrc_" });
  if (card.source !== "multica") {
    fail('card.source must be "multica"');
  }
  requireString(card.runtime_id, "card.runtime_id", { prefix: "rt_" });
  if (card.repo !== "Fearvox/project-windburn") {
    fail('card.repo must be "Fearvox/project-windburn"');
  }
  requireString(card.branch, "card.branch");
  if (!ALLOWED_ACTIONS.has(card.requested_action)) {
    fail("card.requested_action must be one of status, verify-card, superruntime-status");
  }
  if (requireArray(card.allowed_actions, "card.allowed_actions")) {
    for (const [index, action] of card.allowed_actions.entries()) {
      if (typeof action !== "string" || !ALLOWED_ACTIONS.has(action)) {
        fail(`card.allowed_actions[${index}] must be one of status, verify-card, superruntime-status`);
      }
    }
    if (typeof card.requested_action === "string" && !card.allowed_actions.includes(card.requested_action)) {
      fail("card.requested_action must be included in card.allowed_actions");
    }
  }
  if (!ALLOWED_PRIVACY_SCOPES.has(card.privacy_scope)) {
    fail("card.privacy_scope must be one of private, team");
  }
  if (requireObject(card.permissions, "card.permissions")) {
    if (card.permissions.shell !== "forced-command") {
      fail('card.permissions.shell must be "forced-command"');
    }
    if (!requireBoolean(card.permissions.remote_mutation, "card.permissions.remote_mutation") || card.permissions.remote_mutation !== false) {
      fail("card.permissions.remote_mutation must be false");
    }
    if (!requireBoolean(card.permissions.secret_access, "card.permissions.secret_access") || card.permissions.secret_access !== false) {
      fail("card.permissions.secret_access must be false");
    }
    if (!requireBoolean(card.permissions.provider_writeback, "card.permissions.provider_writeback") || card.permissions.provider_writeback !== false) {
      fail("card.permissions.provider_writeback must be false");
    }
    if (!ALLOWED_NETWORK.has(card.permissions.network)) {
      fail("card.permissions.network must be one of none, local-only");
    }
  }
  requireArray(card.evidence_requirements, "card.evidence_requirements");
  requireArray(card.operator_call_conditions, "card.operator_call_conditions");
  requireString(card.expected_output, "card.expected_output");
  if (card.stream_policy !== "redacted") {
    fail('card.stream_policy must be "redacted"');
  }
  if (requireString(card.expires_at, "card.expires_at")) {
    const expiresAt = Date.parse(card.expires_at);
    if (Number.isNaN(expiresAt)) {
      fail("card.expires_at must be a valid timestamp");
    } else if (expiresAt <= Date.now()) {
      fail("card.expires_at must not be expired");
    }
  }
  if (card.signature_stub !== ALLOWED_SIGNATURE) {
    fail(`card.signature_stub must be ${ALLOWED_SIGNATURE}`);
  }
}

const sensitivePatterns = [
  { name: "raw IPv4 address", pattern: /\b(?:\d{1,3}\.){3}\d{1,3}\b/ },
  { name: "raw IPv6 address", pattern: /\b(?:[A-Fa-f0-9]{1,4}:){2,}[A-Fa-f0-9:]{1,}\b/ },
  { name: "macOS local user path", pattern: /\/Users\// },
  { name: "server local path", pattern: /\/srv(?:\/|\b)/ },
  { name: "home user path", pattern: /\/home\/[A-Za-z0-9._-]+(?:\/|\b)/ },
  { name: "ssh target", pattern: /\bssh\s+[^\n]*[A-Za-z0-9._-]+@[A-Za-z0-9.-]+/i },
  { name: "root target", pattern: /\broot@[A-Za-z0-9.-]+\b/i },
  { name: "bearer token", pattern: /\bBearer\s+[A-Za-z0-9._-]+\b/i },
  { name: "OpenAI-style key", pattern: /\bsk-[A-Za-z0-9_-]{16,}\b/ },
  { name: "xAI-style key", pattern: /\bxai-[A-Za-z0-9_-]{16,}\b/i },
  { name: "GitHub token", pattern: /\b(?:ghp|github_pat)_[A-Za-z0-9_]{16,}\b/ },
  { name: "AWS access key", pattern: /\bAKIA[0-9A-Z]{16}\b/ },
  { name: "private key block", pattern: /-----BEGIN [A-Z ]*PRIVATE KEY-----/ }
];

for (const { path, value } of collectStrings(card)) {
  if (path.endsWith("#key")) {
    const keyName = value.toLowerCase();
    const isSensitiveKey = /(?:password|passwd|token|credential|credential[_-]?path|oauth|private[_-]?key|api[_-]?key|provider[_-]?(?:account|profile|id))/i.test(value);
    if (isSensitiveKey && !allowedSensitiveKeys.has(keyName)) {
      fail(`sensitive-looking key at ${path}: ${value}`);
    }
  }
  for (const entry of sensitivePatterns) {
    if (entry.pattern.test(value)) {
      fail(`${entry.name} found at ${path}`);
    }
  }
}

if (failures.length > 0) {
  console.log(`BLOCK multica_runtime_card_verify: ${failures.length} failure(s)`);
  for (const message of failures) {
    console.log(`- ${message}`);
  }
  process.exit(1);
}

console.log(`PASS multica_runtime_card_verify: ${card.card_id}`);
NODE
