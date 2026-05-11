#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPEC_DIR="${1:-"$ROOT_DIR/docs/anthropic-bounty"}"

case "$SPEC_DIR" in
  /*) ;;
  *) SPEC_DIR="$ROOT_DIR/$SPEC_DIR" ;;
esac

node - "$SPEC_DIR" <<'NODE'
const fs = require("fs");
const path = require("path");

const specDir = process.argv[2];
const failures = [];
const warnings = [];

const requiredFiles = [
  "SCOPE.md",
  "HARNESS_SPEC.md",
  "CANDIDATE_TAXONOMY.md",
  "REPORT_TEMPLATE.md",
];

function fail(message) {
  failures.push(message);
}

function flag(message) {
  warnings.push(message);
}

function readText(fileName) {
  const filePath = path.join(specDir, fileName);
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch (error) {
    fail(`${fileName} missing or unreadable (${error.message})`);
    return "";
  }
}

function requireText(text, fileName, pattern, label) {
  if (!pattern.test(text)) {
    fail(`${fileName} missing ${label}`);
  }
}

function assertNoRawPublicSurface(text, fileName) {
  const checks = [
    [/\b(?:\d{1,3}\.){3}\d{1,3}\b/, "raw IPv4-like text"],
    [/\b(?:[A-Fa-f0-9]{1,4}:){2,}[A-Fa-f0-9:]{1,}\b/, "raw IPv6-like text"],
    [/\/Users\/|\/root\/\.|\/srv\//, "private path-like text"],
    [/\bssh\s+(?:-[A-Za-z]\s+)*(?:[A-Za-z0-9._-]+@|\[[A-Fa-f0-9:]+\]|(?:\d{1,3}\.){3}\d{1,3})/i, "SSH target text"],
    [/(?:Bearer\s+[A-Za-z0-9._-]+|sk-[A-Za-z0-9_-]{12,}|xai-[A-Za-z0-9_-]{12,}|gh[op]_[A-Za-z0-9_]{16,}|github_pat_[A-Za-z0-9_]{16,})/, "token-like text"],
  ];

  for (const [pattern, label] of checks) {
    if (pattern.test(text)) {
      fail(`${fileName} contains ${label}`);
    }
  }
}

function assertNoUnsafeArtifactShape(text, fileName) {
  const blockPatterns = [
    [/^#{1,6}\s*(actual|raw)\s+(jailbreak\s+)?prompt\b/im, "raw prompt section"],
    [/^#{1,6}\s*(actual|raw)\s+completion\b/im, "raw completion section"],
    [/^#{1,6}\s*(harmful|private)\s+question\s+set\b/im, "question-set section"],
    [/^#{1,6}\s*reproduction\s+steps\b/im, "raw reproduction section"],
    [/^#{1,6}\s*exploit\s+reproduction\b/im, "exploit reproduction section"],
    [/\bBEGIN[_ -]?(JAILBREAK|EXPLOIT|PAYLOAD)\b/i, "payload marker"],
    [/\b(successful|working)\s+exploit\s+reproduction\s*:/i, "successful exploit reproduction"],
  ];

  for (const [pattern, label] of blockPatterns) {
    if (pattern.test(text)) {
      fail(`${fileName} contains ${label}`);
    }
  }
}

function assertNoPerAttemptOutputSchema(text, fileName) {
  const blockedFields = [
    [/\b"run_id"\s*:/, "per-attempt run_id field"],
    [/\b"prompt_hash"\s*:/, "per-attempt prompt_hash field"],
    [/\b"completion_hash"\s*:/, "per-attempt completion_hash field"],
    [/\b"transcript_hash"\s*:/, "per-attempt transcript_hash field"],
    [/\bPrompt Hash\b/i, "per-attempt Prompt Hash column"],
    [/\bCompletion Hash\b/i, "per-attempt Completion Hash column"],
    [/\bRun ID\b/i, "per-attempt Run ID column"],
  ];

  for (const [pattern, label] of blockedFields) {
    if (pattern.test(text)) {
      fail(`${fileName} contains ${label}`);
    }
  }
}

function assertPublicSourceDiscipline(scopeText) {
  requireText(
    scopeText,
    "SCOPE.md",
    /support\.claude\.com\/en\/articles\/12119250-model-safety-bug-bounty-program/,
    "Anthropic Help Center source",
  );
  if (/15,?000/.test(scopeText)) {
    flag("SCOPE.md references older $15,000 figure; current public spec should prefer $35,000");
  }
  requireText(scopeText, "SCOPE.md", /\$35,000/, "$35,000 public maximum");
  requireText(scopeText, "SCOPE.md", /Reward function is not workflow/i, "reward-function/workflow boundary");
  requireText(scopeText, "SCOPE.md", /measurement\s+system/i, "measurement-system framing");
}

function assertAuthorizationGates(scopeText, reportText) {
  requireText(scopeText, "SCOPE.md", /## Authorization Gates/, "Authorization Gates section");
  requireText(scopeText, "SCOPE.md", /HackerOne program/i, "HackerOne acceptance gate");
  requireText(scopeText, "SCOPE.md", /non-disclosure|NDA/i, "NDA gate");
  requireText(scopeText, "SCOPE.md", /authorized model/i, "authorized model gate");
  requireText(scopeText, "SCOPE.md", /private storage/i, "private storage gate");
  requireText(reportText, "REPORT_TEMPLATE.md", /## Authorization Evidence/, "Authorization Evidence section");
  requireText(reportText, "REPORT_TEMPLATE.md", /Private storage proof verified outside repo/, "private storage report field");
  requireText(reportText, "REPORT_TEMPLATE.md", /Harness redaction mode verified/, "redaction report field");
}

function assertHarnessGates(harnessText) {
  requireText(harnessText, "HARNESS_SPEC.md", /## K-Anonymity Storage Guard/, "K-Anonymity Storage Guard section");
  requireText(harnessText, "HARNESS_SPEC.md", /k>=5/, "k>=5 bucket guard");
  requireText(harnessText, "HARNESS_SPEC.md", /Per-attempt hashes are forbidden/i, "per-attempt hash ban");
  requireText(harnessText, "HARNESS_SPEC.md", /Never persist.*hash\s*\+\s*timestamp/i, "hash+timestamp re-identification ban");
  requireText(harnessText, "HARNESS_SPEC.md", /Never persist successful exploit reproductions/i, "successful exploit reproduction ban");
  requireText(harnessText, "HARNESS_SPEC.md", /"raw_prompt_stored": false/, "raw_prompt_stored=false flag");
  requireText(harnessText, "HARNESS_SPEC.md", /"raw_completion_stored": false/, "raw_completion_stored=false flag");
  requireText(harnessText, "HARNESS_SPEC.md", /"harmful_content_recorded": false/, "harmful_content_recorded=false flag");
  requireText(harnessText, "HARNESS_SPEC.md", /"bucket_eligible": true/, "bucket_eligible output field");
  requireText(harnessText, "HARNESS_SPEC.md", /"created_day_utc": "2026-05-08"/, "day-bucket timestamp field");
  requireText(harnessText, "HARNESS_SPEC.md", /"per_attempt_hashes_stored": false/, "per-attempt hash storage flag");
  requireText(harnessText, "HARNESS_SPEC.md", /aggregate bucket-level scores and counts/i, "aggregate-only scoring");
}

function assertMethodologyFraming(taxonomyText) {
  requireText(taxonomyText, "CANDIDATE_TAXONOMY.md", /abstract public-safe taxonomy/i, "public-safe taxonomy status");
  requireText(taxonomyText, "CANDIDATE_TAXONOMY.md", /research lens/i, "research lens framing");
  requireText(taxonomyText, "CANDIDATE_TAXONOMY.md", /not valid until it is\s+tested in the authorized program environment/i, "authorized environment caveat");
  requireText(taxonomyText, "CANDIDATE_TAXONOMY.md", /Do not|no concrete|no public prompt|Public artifact limit/i, "public artifact limits");
  requireText(taxonomyText, "CANDIDATE_TAXONOMY.md", /## Hypothesis Registry Rules/, "Hypothesis Registry Rules section");
  requireText(taxonomyText, "CANDIDATE_TAXONOMY.md", /stores hypotheses, not workflows/i, "hypothesis-not-workflow wording");
  requireText(taxonomyText, "CANDIDATE_TAXONOMY.md", /must not contain candidate prompt bodies/i, "candidate prompt storage ban");
}

if (!fs.existsSync(specDir) || !fs.statSync(specDir).isDirectory()) {
  fail(`spec directory missing: ${specDir}`);
}

const texts = new Map();
for (const fileName of requiredFiles) {
  const text = readText(fileName);
  texts.set(fileName, text);
  if (text.length > 0) {
    assertNoRawPublicSurface(text, fileName);
    assertNoUnsafeArtifactShape(text, fileName);
    assertNoPerAttemptOutputSchema(text, fileName);
  }
}

const scopeText = texts.get("SCOPE.md") || "";
const harnessText = texts.get("HARNESS_SPEC.md") || "";
const taxonomyText = texts.get("CANDIDATE_TAXONOMY.md") || "";
const reportText = texts.get("REPORT_TEMPLATE.md") || "";

assertPublicSourceDiscipline(scopeText);
assertAuthorizationGates(scopeText, reportText);
assertHarnessGates(harnessText);
assertMethodologyFraming(taxonomyText);

if (failures.length > 0) {
  console.log("BLOCK anthropic_bounty_spec_verify");
  for (const failure of failures) {
    console.log(`- ${failure}`);
  }
  process.exit(1);
}

if (warnings.length > 0) {
  console.log("FLAG anthropic_bounty_spec_verify");
  for (const warning of warnings) {
    console.log(`- ${warning}`);
  }
  process.exit(0);
}

console.log("PASS anthropic_bounty_spec_verify");
console.log(`spec_dir=${path.relative(process.cwd(), specDir) || "."}`);
console.log(`files=${requiredFiles.join(",")}`);
console.log("authorization_gates=present");
console.log("k_anonymity_guard=present");
console.log("methodology_not_target_framing=true");
console.log("secret_values_recorded=false");
console.log("redacted_public_safe=true");
NODE
