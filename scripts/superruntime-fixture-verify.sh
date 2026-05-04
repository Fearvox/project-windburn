#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_PATH="${1:-"$ROOT_DIR/docs/remote-workhorse/fixtures/superruntime-v0.json"}"

node - "$FIXTURE_PATH" <<'NODE'
const fs = require("fs");

const fixturePath = process.argv[2];
const STUB = "stub:v0-fixture-not-cryptographic";
const failures = [];
const warnings = [];

function fail(message) {
  failures.push(message);
}

function hasOwn(value, key) {
  return Object.prototype.hasOwnProperty.call(value, key);
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

function requireArray(value, label) {
  if (!Array.isArray(value) || value.length === 0) {
    fail(`${label} must be a non-empty array`);
    return false;
  }
  return true;
}

function requireString(value, label, prefix) {
  if (typeof value !== "string" || value.length === 0) {
    fail(`${label} must be a non-empty string`);
    return;
  }
  if (prefix && !value.startsWith(prefix)) {
    fail(`${label} must start with ${prefix}`);
  }
}

function requireBool(value, label) {
  if (typeof value !== "boolean") {
    fail(`${label} must be boolean`);
  }
}

function requireOneOf(value, label, allowed) {
  if (!allowed.includes(value)) {
    fail(`${label} must be one of ${allowed.join(", ")}`);
  }
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

function assertUniqueIds(records, idKey, label) {
  const seen = new Set();
  for (const record of records) {
    const id = record[idKey];
    if (seen.has(id)) {
      fail(`${label} duplicate ${idKey}: ${id}`);
    }
    seen.add(id);
  }
  return seen;
}

let fixture;
try {
  fixture = JSON.parse(fs.readFileSync(fixturePath, "utf8"));
} catch (error) {
  console.log(`BLOCK superruntime_fixture_verify: invalid JSON (${error.message})`);
  process.exit(1);
}

if (requireObject(fixture, "fixture")) {
  if (fixture.schema_version !== 1) fail("fixture.schema_version must be 1");
  requireString(fixture.fixture_id, "fixture.fixture_id");
  if (fixture.signature_stub !== STUB) fail(`fixture.signature_stub must be ${STUB}`);
}

const workIntents = fixture.work_intents;
const runtimeRegistrations = fixture.runtime_registrations;
const taskEnvelopes = fixture.task_envelopes;
const harnessDispatches = fixture.harness_dispatches;
const statusEvents = fixture.status_events;

requireArray(workIntents, "work_intents");
requireArray(runtimeRegistrations, "runtime_registrations");
requireArray(taskEnvelopes, "task_envelopes");
requireArray(harnessDispatches, "harness_dispatches");
requireArray(statusEvents, "status_events");

if (failures.length === 0) {
  for (const [index, intent] of workIntents.entries()) {
    if (!requireObject(intent, `work_intents[${index}]`)) continue;
    if (intent.schema_version !== 1) fail(`work_intents[${index}].schema_version must be 1`);
    requireString(intent.intent_id, `work_intents[${index}].intent_id`, "wi_");
    requireOneOf(intent.provider, `work_intents[${index}].provider`, ["linear", "github", "slack", "discord", "manual"]);
    requireString(intent.provider_event_id, `work_intents[${index}].provider_event_id`);
    requireString(intent.project_hint, `work_intents[${index}].project_hint`);
    requireString(intent.repo_hint, `work_intents[${index}].repo_hint`);
    requireOneOf(intent.requested_action, `work_intents[${index}].requested_action`, ["review", "implement", "verify", "triage", "comment"]);
    requireString(intent.human_text, `work_intents[${index}].human_text`);
    requireOneOf(intent.source_visibility, `work_intents[${index}].source_visibility`, ["private", "team", "public"]);
    requireString(intent.created_at, `work_intents[${index}].created_at`);
  }

  for (const [index, registration] of runtimeRegistrations.entries()) {
    if (!requireObject(registration, `runtime_registrations[${index}]`)) continue;
    if (registration.schema_version !== 1) fail(`runtime_registrations[${index}].schema_version must be 1`);
    requireString(registration.runtime_id, `runtime_registrations[${index}].runtime_id`, "rt_");
    requireOneOf(registration.runtime_kind, `runtime_registrations[${index}].runtime_kind`, ["superconductor"]);
    requireString(registration.display_name, `runtime_registrations[${index}].display_name`);
    requireArray(registration.capabilities, `runtime_registrations[${index}].capabilities`);
    requireArray(registration.workspace_roots, `runtime_registrations[${index}].workspace_roots`);
    requireBool(registration.stream_safe, `runtime_registrations[${index}].stream_safe`);
    if (registration.stream_safe !== true) fail(`runtime_registrations[${index}].stream_safe must be true`);
    requireString(registration.mutation_policy, `runtime_registrations[${index}].mutation_policy`);
    requireString(registration.heartbeat_at, `runtime_registrations[${index}].heartbeat_at`);
  }

  for (const [index, envelope] of taskEnvelopes.entries()) {
    if (!requireObject(envelope, `task_envelopes[${index}]`)) continue;
    if (envelope.schema_version !== 1) fail(`task_envelopes[${index}].schema_version must be 1`);
    requireString(envelope.task_id, `task_envelopes[${index}].task_id`, "task_");
    requireString(envelope.intent_id, `task_envelopes[${index}].intent_id`, "wi_");
    requireString(envelope.runtime_id, `task_envelopes[${index}].runtime_id`, "rt_");
    requireString(envelope.lease_id, `task_envelopes[${index}].lease_id`, "lease_");
    requireString(envelope.allowed_repo, `task_envelopes[${index}].allowed_repo`);
    requireString(envelope.worktree_policy, `task_envelopes[${index}].worktree_policy`);
    requireString(envelope.requested_harness, `task_envelopes[${index}].requested_harness`);
    requireString(envelope.task_prompt, `task_envelopes[${index}].task_prompt`);
    requireObject(envelope.permissions, `task_envelopes[${index}].permissions`);
    requireArray(envelope.evidence_requirements, `task_envelopes[${index}].evidence_requirements`);
    requireString(envelope.expires_at, `task_envelopes[${index}].expires_at`);
    if (envelope.signature !== STUB) fail(`task_envelopes[${index}].signature must be ${STUB}`);
  }

  for (const [index, dispatch] of harnessDispatches.entries()) {
    if (!requireObject(dispatch, `harness_dispatches[${index}]`)) continue;
    if (dispatch.schema_version !== 1) fail(`harness_dispatches[${index}].schema_version must be 1`);
    requireString(dispatch.dispatch_id, `harness_dispatches[${index}].dispatch_id`, "dispatch_");
    requireString(dispatch.task_id, `harness_dispatches[${index}].task_id`, "task_");
    requireOneOf(dispatch.harness, `harness_dispatches[${index}].harness`, ["codex", "claude-code", "hermes", "pi"]);
    requireString(dispatch.workdir, `harness_dispatches[${index}].workdir`);
    requireString(dispatch.prompt, `harness_dispatches[${index}].prompt`);
    requireString(dispatch.expected_output, `harness_dispatches[${index}].expected_output`);
    requireOneOf(dispatch.stream_policy, `harness_dispatches[${index}].stream_policy`, ["redacted"]);
    if (dispatch.signature !== STUB) fail(`harness_dispatches[${index}].signature must be ${STUB}`);
  }

  for (const [index, event] of statusEvents.entries()) {
    if (!requireObject(event, `status_events[${index}]`)) continue;
    if (event.schema_version !== 1) fail(`status_events[${index}].schema_version must be 1`);
    requireString(event.task_id, `status_events[${index}].task_id`, "task_");
    requireString(event.runtime_id, `status_events[${index}].runtime_id`, "rt_");
    requireOneOf(event.phase, `status_events[${index}].phase`, ["queued", "leased", "worktree-prep", "running", "verifying", "done"]);
    requireOneOf(event.level, `status_events[${index}].level`, ["info", "flag", "block", "pass"]);
    requireString(event.message, `status_events[${index}].message`);
    requireArray(event.artifact_refs, `status_events[${index}].artifact_refs`);
    requireBool(event.secret_values_recorded, `status_events[${index}].secret_values_recorded`);
    if (event.secret_values_recorded !== false) fail(`status_events[${index}].secret_values_recorded must be false`);
    requireString(event.emitted_at, `status_events[${index}].emitted_at`);
  }
}

if (failures.length === 0) {
  const intentIds = assertUniqueIds(workIntents, "intent_id", "work_intents");
  const runtimeIds = assertUniqueIds(runtimeRegistrations, "runtime_id", "runtime_registrations");
  const taskIds = assertUniqueIds(taskEnvelopes, "task_id", "task_envelopes");
  assertUniqueIds(harnessDispatches, "dispatch_id", "harness_dispatches");

  for (const envelope of taskEnvelopes) {
    if (!intentIds.has(envelope.intent_id)) fail(`task ${envelope.task_id} references missing intent ${envelope.intent_id}`);
    if (!runtimeIds.has(envelope.runtime_id)) fail(`task ${envelope.task_id} references missing runtime ${envelope.runtime_id}`);
  }

  for (const dispatch of harnessDispatches) {
    if (!taskIds.has(dispatch.task_id)) fail(`dispatch ${dispatch.dispatch_id} references missing task ${dispatch.task_id}`);
    const envelope = taskEnvelopes.find((candidate) => candidate.task_id === dispatch.task_id);
    if (envelope && dispatch.harness !== envelope.requested_harness) {
      fail(`dispatch ${dispatch.dispatch_id} harness does not match task ${dispatch.task_id}`);
    }
  }

  for (const event of statusEvents) {
    if (!taskIds.has(event.task_id)) fail(`status event ${event.phase} references missing task ${event.task_id}`);
    if (!runtimeIds.has(event.runtime_id)) fail(`status event ${event.phase} references missing runtime ${event.runtime_id}`);
  }

  if (!statusEvents.some((event) => event.phase === "done" && event.level === "pass")) {
    warnings.push("no final pass status event found");
  }
}

const sensitivePatterns = [
  { name: "raw IPv4 address", pattern: /\b(?:\d{1,3}\.){3}\d{1,3}\b/ },
  { name: "macOS local user path", pattern: /\/Users\// },
  { name: "server local path", pattern: /\/srv(?:\/|\b)/ },
  { name: "ssh root target", pattern: /\bssh\s+root@|\broot@[\w.-]+/i },
  { name: "OpenAI-style key", pattern: /\bsk-[A-Za-z0-9_-]{16,}\b/ },
  { name: "GitHub token", pattern: /\b(?:ghp|github_pat)_[A-Za-z0-9_]{16,}\b/ },
  { name: "AWS access key", pattern: /\bAKIA[0-9A-Z]{16}\b/ },
  { name: "private key block", pattern: /-----BEGIN [A-Z ]*PRIVATE KEY-----/ }
];

for (const { path, value } of collectStrings(fixture)) {
  if (path.endsWith("#key")) {
    const allowedSecretKeys = new Set(["$.task_envelopes[0].permissions.secret_access#key"]);
    const allowedStatusSecretKeys = /^\.status_events\[\d+\]\.secret_values_recorded#key$/;
    const keyTail = path.replace("$", "");
    const disallowedKey = /(?:api[_-]?key|access[_-]?key|private[_-]?key|password|passwd|token|credential)/i.test(value);
    const allowed = allowedSecretKeys.has(path) || allowedStatusSecretKeys.test(keyTail);
    if (disallowedKey && !allowed) fail(`sensitive-looking key at ${path}: ${value}`);
  }
  for (const entry of sensitivePatterns) {
    if (entry.pattern.test(value)) {
      fail(`${entry.name} found at ${path}`);
    }
  }
}

if (failures.length > 0) {
  console.log(`BLOCK superruntime_fixture_verify: ${failures.length} failure(s)`);
  for (const message of failures) console.log(`- ${message}`);
  process.exit(1);
}

if (warnings.length > 0) {
  console.log(`FLAG superruntime_fixture_verify: ${warnings.length} warning(s)`);
  for (const message of warnings) console.log(`- ${message}`);
  process.exit(1);
}

console.log(`PASS superruntime_fixture_verify: ${fixturePath}`);
NODE
