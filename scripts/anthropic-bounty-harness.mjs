#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT_DIR = path.resolve(SCRIPT_DIR, "..");
const SPEC_DIR = path.join(ROOT_DIR, "docs", "anthropic-bounty");
const FIXTURE_DIR = path.join(SPEC_DIR, "fixtures");
const MINIMUM_K = 5;

const REQUIRED_DOCS = [
  "SCOPE.md",
  "HARNESS_SPEC.md",
  "CANDIDATE_TAXONOMY.md",
  "REPORT_TEMPLATE.md",
];

const HARMLESS_FIXTURES = {
  runRecord: "harmless-run-record-v0.json",
  bucket: "k-anonymous-bucket-v0.json",
  reportPack: "report-pack-summary-v0.json",
};

const BLOCKED_KEYS = new Set([
  "raw_prompt",
  "raw_completion",
  "raw_transcript",
  "prompt_text",
  "completion_text",
  "question_text",
  "target_question",
  "jailbreak_prompt",
  "transcript",
  "payload",
]);

const BLOCKED_STRING_PATTERNS = [
  [/\b(?:\d{1,3}\.){3}\d{1,3}\b/, "IPv4-like value"],
  [/\b(?:[A-Fa-f0-9]{1,4}:){2,}[A-Fa-f0-9:]{1,}\b/, "IPv6-like value"],
  [/\/Users\/|\/root\/\.|\/srv\//, "private path-like value"],
  [/\bssh\s+(?:-[A-Za-z]\s+)*(?:[A-Za-z0-9._-]+@|\[[A-Fa-f0-9:]+\]|(?:\d{1,3}\.){3}\d{1,3})/i, "SSH target value"],
  [/(?:Bearer\s+[A-Za-z0-9._-]+|sk-[A-Za-z0-9_-]{12,}|xai-[A-Za-z0-9_-]{12,}|gh[op]_[A-Za-z0-9_]{16,}|github_pat_[A-Za-z0-9_]{16,})/, "token-like value"],
  [/\bBEGIN[_ -]?(JAILBREAK|EXPLOIT|PAYLOAD)\b/i, "payload marker"],
  [/\b(successful|working)\s+exploit\s+reproduction\s*:/i, "exploit reproduction marker"],
];

function usage() {
  console.log("Usage:");
  console.log("  scripts/anthropic-bounty-harness.mjs preflight");
  console.log("  scripts/anthropic-bounty-harness.mjs dry-run --fixture harmless");
  console.log("  scripts/anthropic-bounty-harness.mjs report-pack --fixture harmless");
  console.log("  scripts/anthropic-bounty-harness.mjs authorized-run");
}

function printVerdict(verdict, label, fields = []) {
  console.log(`${verdict} ${label}`);
  for (const [key, value] of fields) {
    console.log(`${key}=${value}`);
  }
}

function block(label, failures) {
  printVerdict("BLOCK", label);
  for (const failure of failures) {
    console.log(`- ${failure}`);
  }
  process.exit(1);
}

function readJson(filePath, failures) {
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (error) {
    failures.push(`${path.relative(ROOT_DIR, filePath)} unreadable JSON: ${error.message}`);
    return null;
  }
}

function optionValue(args, name, fallback = undefined) {
  const index = args.indexOf(name);
  if (index === -1) return fallback;
  return args[index + 1] || fallback;
}

function walk(value, visit, trail = []) {
  if (Array.isArray(value)) {
    value.forEach((item, index) => walk(item, visit, trail.concat(String(index))));
    return;
  }

  if (value && typeof value === "object") {
    for (const [key, child] of Object.entries(value)) {
      visit(key, child, trail.concat(key));
      walk(child, visit, trail.concat(key));
    }
  }
}

function assertPublicSafeObject(object, label, failures) {
  walk(object, (key, value, trail) => {
    if (BLOCKED_KEYS.has(key)) {
      failures.push(`${label} contains forbidden key ${trail.join(".")}`);
    }

    if (typeof value !== "string") return;

    for (const [pattern, patternLabel] of BLOCKED_STRING_PATTERNS) {
      if (pattern.test(value)) {
        failures.push(`${label} contains ${patternLabel} at ${trail.join(".")}`);
      }
    }
  });
}

function assertDayBucket(record, label, failures) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(record.created_day_utc || "")) {
    failures.push(`${label} missing calendar-day created_day_utc`);
  }

  if (Object.hasOwn(record, "created_at_utc")) {
    failures.push(`${label} uses timestamp finer than day bucket`);
  }
}

function assertKAnonymous(record, label, failures) {
  if (record.bucket_count < MINIMUM_K) {
    failures.push(`${label} bucket_count ${record.bucket_count} below minimum ${MINIMUM_K}`);
  }

  if (record.bucket_eligible !== true) {
    failures.push(`${label} bucket_eligible must be true`);
  }

  const expectedBucket = `day:${record.created_day_utc}|candidate:${record.candidate_id}`;
  const actualBucket = record.k_anonymity_bucket || record.bucket_id;
  if (actualBucket !== expectedBucket) {
    failures.push(`${label} bucket id mismatch: expected ${expectedBucket}`);
  }
}

function assertSafetyFlags(record, label, failures) {
  const flags = record.safety_flags || {};
  const requiredFalseFlags = [
    "raw_prompt_stored",
    "raw_completion_stored",
    "harmful_content_recorded",
    "secret_values_recorded",
    "per_attempt_hashes_stored",
    "authorized_model_called",
  ];

  for (const key of requiredFalseFlags) {
    if (flags[key] !== false) {
      failures.push(`${label} safety_flags.${key} must be false`);
    }
  }

  if (flags.redacted_public_safe !== true) {
    failures.push(`${label} safety_flags.redacted_public_safe must be true`);
  }
}

function assertRunRecord(record, failures) {
  assertPublicSafeObject(record, "harmless-run-record-v0.json", failures);
  assertDayBucket(record, "harmless-run-record-v0.json", failures);
  assertKAnonymous(record, "harmless-run-record-v0.json", failures);
  assertSafetyFlags(record, "harmless-run-record-v0.json", failures);

  if (record.record_kind !== "aggregate_result") {
    failures.push("harmless-run-record-v0.json record_kind must be aggregate_result");
  }
}

function assertBucket(bucket, failures) {
  assertPublicSafeObject(bucket, "k-anonymous-bucket-v0.json", failures);
  assertDayBucket(bucket, "k-anonymous-bucket-v0.json", failures);
  assertKAnonymous(bucket, "k-anonymous-bucket-v0.json", failures);

  if (bucket.minimum_k !== MINIMUM_K) {
    failures.push("k-anonymous-bucket-v0.json minimum_k must be 5");
  }

  const requiredFalseFlags = [
    "contains_per_attempt_hashes",
    "contains_raw_transcripts",
    "contains_successful_exploit_reproduction",
  ];

  for (const key of requiredFalseFlags) {
    if (bucket[key] !== false) {
      failures.push(`k-anonymous-bucket-v0.json ${key} must be false`);
    }
  }
}

function assertReportPack(reportPack, failures) {
  assertPublicSafeObject(reportPack, "report-pack-summary-v0.json", failures);
  assertDayBucket(reportPack, "report-pack-summary-v0.json", failures);

  if (reportPack.record_kind !== "report_pack_summary") {
    failures.push("report-pack-summary-v0.json record_kind must be report_pack_summary");
  }

  const flags = reportPack.public_safe_flags || {};
  for (const [key, value] of Object.entries(flags)) {
    if (value !== false) {
      failures.push(`report-pack-summary-v0.json public_safe_flags.${key} must be false`);
    }
  }

  for (const summary of reportPack.candidate_summaries || []) {
    assertKAnonymous(
      {
        created_day_utc: reportPack.created_day_utc,
        candidate_id: summary.candidate_id,
        bucket_count: summary.bucket_count,
        bucket_eligible: summary.bucket_eligible,
        bucket_id: summary.bucket_id,
      },
      `report-pack-summary-v0.json candidate ${summary.candidate_id}`,
      failures,
    );
  }
}

function loadHarmlessFixtures(failures) {
  const files = Object.fromEntries(
    Object.entries(HARMLESS_FIXTURES).map(([key, fileName]) => [
      key,
      path.join(FIXTURE_DIR, fileName),
    ]),
  );

  return {
    runRecord: readJson(files.runRecord, failures),
    bucket: readJson(files.bucket, failures),
    reportPack: readJson(files.reportPack, failures),
  };
}

function assertFixtureName(args, failures) {
  const fixture = optionValue(args, "--fixture", "harmless");
  if (fixture !== "harmless") {
    failures.push(`unsupported fixture ${fixture}`);
  }
  return fixture;
}

function runPreflight() {
  const failures = [];

  for (const fileName of REQUIRED_DOCS) {
    const filePath = path.join(SPEC_DIR, fileName);
    if (!fs.existsSync(filePath)) {
      failures.push(`${path.relative(ROOT_DIR, filePath)} missing`);
    }
  }

  for (const fileName of Object.values(HARMLESS_FIXTURES)) {
    const filePath = path.join(FIXTURE_DIR, fileName);
    if (!fs.existsSync(filePath)) {
      failures.push(`${path.relative(ROOT_DIR, filePath)} missing`);
    }
  }

  if (process.env.ANTHROPIC_BOUNTY_AUTHORIZED === "1") {
    failures.push("authorized mode env is set, but this skeleton intentionally does not enable live testing");
  }

  if (failures.length > 0) {
    block("anthropic_bounty_preflight", failures);
  }

  printVerdict("PASS", "anthropic_bounty_preflight", [
    ["mode", "public-safe"],
    ["authorization_gate", "blocked_without_operator_approval"],
    ["authorized_run_enabled", "false"],
    ["raw_prompt_storage", "false"],
    ["raw_completion_storage", "false"],
    ["repo_safe", "true"],
  ]);
}

function runDryRun(args) {
  const failures = [];
  const fixture = assertFixtureName(args, failures);
  const fixtures = loadHarmlessFixtures(failures);

  if (fixtures.runRecord) assertRunRecord(fixtures.runRecord, failures);
  if (fixtures.bucket) assertBucket(fixtures.bucket, failures);

  if (failures.length > 0) {
    block("anthropic_bounty_dry_run", failures);
  }

  printVerdict("PASS", "anthropic_bounty_dry_run", [
    ["fixture", fixture],
    ["candidate_id", fixtures.runRecord.candidate_id],
    ["k_anonymity_bucket", fixtures.runRecord.k_anonymity_bucket],
    ["bucket_count", fixtures.runRecord.bucket_count],
    ["bucket_eligible", fixtures.runRecord.bucket_eligible],
    ["authorized_model_called", "false"],
    ["raw_prompt_stored", "false"],
    ["raw_completion_stored", "false"],
  ]);
}

function runReportPack(args) {
  const failures = [];
  const fixture = assertFixtureName(args, failures);
  const fixtures = loadHarmlessFixtures(failures);

  if (fixtures.reportPack) assertReportPack(fixtures.reportPack, failures);

  if (failures.length > 0) {
    block("anthropic_bounty_report_pack", failures);
  }

  printVerdict("PASS", "anthropic_bounty_report_pack", [
    ["fixture", fixture],
    ["report_pack_id", fixtures.reportPack.report_pack_id],
    ["candidate_count", fixtures.reportPack.candidate_summaries.length],
    ["contains_raw_candidate", "false"],
    ["contains_harmful_question", "false"],
    ["contains_completion_text", "false"],
  ]);
}

function runAuthorizedRun() {
  printVerdict("BLOCK", "anthropic_bounty_authorized_run", [
    ["reason", "missing_authorization"],
    ["required", "hackerone_acceptance_nda_authorized_alias_private_storage_operator_approval"],
    ["live_red_team_action", "blocked"],
  ]);
  process.exit(2);
}

const [command, ...args] = process.argv.slice(2);

switch (command) {
  case "preflight":
    runPreflight();
    break;
  case "dry-run":
    runDryRun(args);
    break;
  case "report-pack":
    runReportPack(args);
    break;
  case "authorized-run":
    runAuthorizedRun();
    break;
  case undefined:
  case "--help":
  case "-h":
    usage();
    process.exit(command ? 0 : 1);
    break;
  default:
    usage();
    block("anthropic_bounty_harness", [`unknown command ${command}`]);
}
