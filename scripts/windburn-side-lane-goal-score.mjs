#!/usr/bin/env node
// Windburn Side-Lane Goal Score v0.1
// Reads receipts JSONL and scores artifacts across 8 goal-metric dimensions.
//
// Usage:
//   node scripts/windburn-side-lane-goal-score.mjs
//   node scripts/windburn-side-lane-goal-score.mjs --receipts path/to/receipts.jsonl
//   node scripts/windburn-side-lane-goal-score.mjs --fixture smoke
//
// Exit codes: 0 = PASS, 1 = FLAG, 2 = BLOCK

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

function canonicalizePath(candidatePath) {
  const resolved = path.resolve(candidatePath);
  try {
    return fs.realpathSync.native(resolved);
  } catch {
    return resolved;
  }
}

const scriptPath = fileURLToPath(import.meta.url);
const defaultRepoCwd = path.resolve(path.dirname(scriptPath), "..");
const repoCwd = canonicalizePath(process.env.WINDBURN_CWD || defaultRepoCwd);
const relayDir =
  process.env.WINDBURN_SIDE_LANE_RELAY_DIR ||
  path.join(repoCwd, "var", "side-lane-relay");
const defaultReceiptFile = path.join(relayDir, "relay-receipts.jsonl");

const SOURCE_TRUTH_PATTERNS = [
  /\bsource[-_.\s]?truth\b/i,
  /\bsource\s+of\s+truth\b/i,
  /\bsingle\s+source\s+of\s+truth\b/i,
  /\bpromote\b.*\b(?:truth|source)\b/i,
  /\bwrite\b.*\b(?:truth|source)\b/i,
  /\bthis is (?:now |the )?(?:truth|source truth)\b/i,
  /\bclaim(?:s|ing)?\s+(?:source|ground)\s+truth\b/i,
  /\bpromot(?:e|ing|ed)\s+to\s+(?:source|ground)\s+truth\b/i,
  /\bcanonical\s+(?:truth|record)\b/i,
];

function detectSourceTruthClaims(payload) {
  for (const pattern of SOURCE_TRUTH_PATTERNS) {
    if (pattern.test(payload)) return true;
  }
  return false;
}

function loadReceipts(filePath) {
  if (!fs.existsSync(filePath)) return { receipts: [], parseErrors: 0, totalLines: 0 };
  const raw = fs.readFileSync(filePath, "utf8");
  if (!raw.trim()) return { receipts: [], parseErrors: 0, totalLines: 0 };
  const lines = raw.split("\n");
  const receipts = [];
  let parseErrors = 0;
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    try {
      receipts.push(JSON.parse(trimmed));
    } catch {
      parseErrors++;
    }
  }
  return { receipts, parseErrors, totalLines: lines.length };
}

function scoreBoundaryIntegrity(receipts) {
  let flags = 0, blocks = 0;
  for (const r of receipts) {
    if (!r.valid) {
      if (r.errors?.some((e) => /empty or missing/i.test(e))) {
        blocks++;
      }
      continue;
    }
    if ((r.boundary_flags?.length || 0) > 0) flags++;
  }
  if (blocks > 0) return "BLOCK";
  if (flags > 0) return "FLAG";
  return "PASS";
}

function scoreScopeIntegrity(receipts) {
  for (const r of receipts) {
    if (r.errors?.some((e) => /cwd out of Windburn scope/i.test(e))) return "BLOCK";
  }
  return "PASS";
}

function scoreSourceTruthSafety(receipts) {
  for (const r of receipts) {
    if (r.errors?.some((e) => /source.?truth/i.test(e))) return "BLOCK";
  }
  for (const r of receipts) {
    if (r.boundary_flags?.some((f) => /source.?truth/i.test(f))) return "FLAG";
  }
  return "PASS";
}

function scoreTraceability(receipts) {
  let flags = 0;
  for (const r of receipts) {
    if (!r.relay_id) return "BLOCK";
    if (r.inbox_record_index === undefined || r.inbox_record_index === null) return "BLOCK";
    if (r.marker === undefined || r.marker === null) flags++;
    if (r.captured_at === undefined || r.captured_at === null) flags++;
  }
  if (flags > 0) return "FLAG";
  return "PASS";
}

function scoreLedgerHygiene(receiptFile) {
  // Verify receipts were produced in an isolated temp dir, not the real relay ledger.
  // Scorer checks the file path: receipts under system temp dirs are isolated;
  // receipts under the canonical relay dir (var/side-lane-relay/) are live and
  // should NOT be mutated by test smoke.
  if (!receiptFile) return "PASS";

  const normalized = path.resolve(receiptFile);
  const tmpRoots = [
    path.resolve(os.tmpdir()),
    "/tmp",
  ];

  const isIsolated = tmpRoots.some((root) => {
    try {
      return normalized === root || normalized.startsWith(root + path.sep);
    } catch {
      return false;
    }
  });

  if (isIsolated) return "PASS";

  // Receipt file is under the real relay dir (or unknown location).
  // FLAG: we can't prove the real inbox wasn't mutated during this run.
  // The boundary smoke contract requires isolated temp dirs for test fixtures.
  return "FLAG";
}

function scorePublicSurfaceSafety(repoRoot) {
  // Scan public-facing docs and HTML files for private operator material.
  // BLOCK: absolute home dir paths, credential-shaped strings, private hook paths
  // FLAG: queue filenames, socket paths, local state paths
  // PASS: no violations found in public surfaces

  if (!repoRoot) return "PASS";

  const publicDirs = [
    path.join(repoRoot, "docs"),
    path.join(repoRoot, "hermes-distributions"),
  ];
  const htmlFiles = [];

  for (const dir of publicDirs) {
    if (!fs.existsSync(dir)) continue;
    const entries = walkDir(dir);
    for (const entry of entries) {
      if (entry.endsWith(".html") || entry.endsWith(".md")) {
        htmlFiles.push(entry);
      }
    }
  }

  // Also scan root-level .html files
  try {
    const rootEntries = fs.readdirSync(repoRoot);
    for (const entry of rootEntries) {
      if (entry.endsWith(".html")) {
        htmlFiles.push(path.join(repoRoot, entry));
      }
    }
  } catch {
    // If we can't read root dir, don't penalize — this is a scorer, not a scanner
  }

  if (htmlFiles.length === 0) return "PASS";

  // Patterns that indicate private operator material in public docs
  const BLOCK_PATTERNS = [
    /\/Users\/[^/\s]{3,}/,           // absolute home dir paths (macOS)
    /\/home\/[^/\s]{3,}/,             // absolute home dir paths (Linux)
    /sk-[a-zA-Z0-9_-]{20,}/,          // credential-shaped strings (OpenAI/Anthropic key pattern)
    /api[_-]?key[=:]\s*[a-zA-Z0-9_-]{20,}/i,  // API key assignment
    /private[_-]?key[=:]\s*[a-zA-Z0-9/+=]{20,}/i,  // private key assignment
    /\/\.ssh\//,                       // SSH private paths
  ];

  const FLAG_PATTERNS = [
    /var\/side-lane-relay/,            // queue filenames
    /relay-inbox\.jsonl/,             // inbox filenames
    /relay-receipts\.jsonl/,          // receipt filenames
    /\.sock\b/,                        // socket paths
    /\/tmp\/[a-zA-Z0-9_-]{8,}/,       // temp dir paths with random suffixes
  ];

  let hasBlock = false;
  let hasFlag = false;

  for (const file of htmlFiles) {
    try {
      const content = fs.readFileSync(file, "utf8");
      for (const pattern of BLOCK_PATTERNS) {
        if (pattern.test(content)) {
          hasBlock = true;
          break;
        }
      }
      if (!hasBlock) {
        for (const pattern of FLAG_PATTERNS) {
          if (pattern.test(content)) {
            hasFlag = true;
            break;
          }
        }
      }
    } catch {
      // Skip unreadable files — don't penalize scorer for file system issues
    }
    if (hasBlock) break;
  }

  if (hasBlock) return "BLOCK";
  if (hasFlag) return "FLAG";
  return "PASS";
}

function walkDir(dir) {
  const results = [];
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isDirectory() && !entry.name.startsWith(".")) {
        results.push(...walkDir(fullPath));
      } else if (entry.isFile()) {
        results.push(fullPath);
      }
    }
  } catch {
    // Skip unreadable dirs
  }
  return results;
}

function scoreModelVisibility(receipts) {
  let hasVerification = false;
  let hasPass = false;
  let hasFail = false;

  for (const r of receipts) {
    if (!r.verification) continue;
    hasVerification = true;
    if (r.verification.status === "PASS" && r.verification.model_visible === true) {
      hasPass = true;
    } else if (r.verification.status !== "PASS" || r.verification.model_visible === false) {
      hasFail = true;
    }
  }

  if (!hasVerification) return "OPTIONAL/BLOCKED_BY_AUTH";
  if (hasFail && !hasPass) return "BLOCK";
  if (hasFail) return "FLAG";
  return "PASS";
}

function scoreFailureQuality(receipts, parseErrors) {
  let genericErrors = 0, silentDrops = parseErrors || 0;
  for (const r of receipts) {
    if (!r.valid) {
      if (!r.errors || r.errors.length === 0) {
        silentDrops++;
      } else if (r.errors.some((e) => e.length < 10 || e === "validation failed")) {
        genericErrors++;
      }
    }
  }
  if (silentDrops > 0) return "BLOCK";
  if (genericErrors > 0) return "FLAG";
  return "PASS";
}

// ── Cross-receipt analysis ──────────────────────────────────────────────

function detectRepeatedFailures(receipts) {
  // Detects when the same error pattern appears on the same relay_id
  // across multiple receipts. This indicates the agent retried a failed
  // action without modification — a behavior pattern we want to catch.
  // Returns { found: boolean, details: string[] }
  const seen = new Map();
  const repeats = [];

  for (const r of receipts) {
    if (!r.relay_id) continue;
    if (!r.errors || r.errors.length === 0) continue;

    const errorKey = r.relay_id + "::" + r.errors.sort().join("||");
    if (seen.has(errorKey)) {
      repeats.push(
        `repeated failure on relay_id=${r.relay_id}: ${r.errors.join("; ")} ` +
        `(indices ${seen.get(errorKey)} and ${r.inbox_record_index})`
      );
    } else {
      seen.set(errorKey, r.inbox_record_index);
    }
  }

  return { found: repeats.length > 0, details: repeats };
}

function aggregateVerdict(scores) {
  if (scores.source_truth_safety === "BLOCK") return "BLOCK";
  if (scores.scope_integrity === "BLOCK") return "BLOCK";
  if (scores.source_truth_safety === "FLAG") return "FLAG";
  if (scores.scope_integrity === "FLAG") return "FLAG";

  const nonHard = ["boundary_integrity", "traceability", "ledger_hygiene",
                    "public_surface_safety", "model_visibility", "failure_quality"];
  for (const dim of nonHard) {
    if (scores[dim] === "BLOCK") return "FLAG";
  }
  for (const dim of nonHard) {
    if (scores[dim] === "FLAG") return "FLAG";
  }
  return "PASS";
}

function runSmoke() {
  // Synthetic receipts covering all dimensions
  const fixtures = [
    // PASS on all dimensions except model_visibility (no verification data)
    {
      receipt_at: "2026-05-12T00:00:00.000Z", mode: "dry-run",
      inbox_record_index: 0, relay_id: "windburn-relay-0-clean000000",
      marker: "DISTILL_TO_PARENT", artifact_type: "DISTILL",
      captured_at: "2026-05-12T00:00:00.000Z",
      valid: true, injected: false, errors: [], boundary_flags: []
    },
    // FLAG on boundary_integrity (pre-marker chatter)
    {
      receipt_at: "2026-05-12T00:00:01.000Z", mode: "dry-run",
      inbox_record_index: 1, relay_id: "windburn-relay-1-chatter001",
      marker: "DISTILL_TO_PARENT", artifact_type: "DISTILL",
      captured_at: "2026-05-12T00:00:01.000Z",
      valid: true, injected: false, errors: [],
      boundary_flags: ["pre_marker_chatter: payload opens with prose/narrative"]
    },
    // FLAG on source_truth_safety
    {
      receipt_at: "2026-05-12T00:00:02.000Z", mode: "dry-run",
      inbox_record_index: 2, relay_id: "windburn-relay-2-struth001",
      marker: "DISTILL_TO_PARENT", artifact_type: "DISTILL",
      captured_at: "2026-05-12T00:00:02.000Z",
      valid: true, injected: false, errors: [],
      boundary_flags: ['source-truth claim detected near: "this is now source truth"']
    },
    // BLOCK on scope_integrity
    {
      receipt_at: "2026-05-12T00:00:03.000Z", mode: "dry-run",
      inbox_record_index: 3, relay_id: "windburn-relay-3-ooscope001",
      marker: "DISTILL_TO_PARENT", artifact_type: "DISTILL",
      captured_at: "2026-05-12T00:00:03.000Z",
      valid: false, injected: false,
      errors: ["cwd out of Windburn scope: outside-scope-project"]
    },
    // BLOCK on boundary_integrity (empty payload)
    {
      receipt_at: "2026-05-12T00:00:04.000Z", mode: "dry-run",
      inbox_record_index: 4, relay_id: "windburn-relay-4-empty001",
      marker: "DISTILL_TO_PARENT", artifact_type: "DISTILL",
      captured_at: "2026-05-12T00:00:04.000Z",
      valid: false, injected: false,
      errors: ["relay_payload is empty or missing"]
    },
    // FLAG on traceability (missing captured_at)
    {
      receipt_at: "2026-05-12T00:00:05.000Z", mode: "dry-run",
      inbox_record_index: 5, relay_id: "windburn-relay-5-notime001",
      marker: "DISTILL_TO_PARENT", artifact_type: "DISTILL",
      captured_at: null,
      valid: true, injected: false, errors: [], boundary_flags: []
    },
    // BLOCKED_BY_AUTH on model_visibility
    {
      receipt_at: "2026-05-12T00:00:06.000Z", mode: "dry-run",
      inbox_record_index: 6, relay_id: "windburn-relay-6-noverif01",
      marker: "DISTILL_TO_PARENT", artifact_type: "DISTILL",
      captured_at: "2026-05-12T00:00:06.000Z",
      valid: true, injected: false, errors: [], boundary_flags: []
    },
    // BLOCK on failure_quality (silent drop — no errors on invalid record)
    {
      receipt_at: "2026-05-12T00:00:07.000Z", mode: "dry-run",
      inbox_record_index: 7, relay_id: "windburn-relay-7-silent001",
      marker: "INVALID_MARKER", artifact_type: "UNKNOWN",
      captured_at: "2026-05-12T00:00:07.000Z",
      valid: false, injected: false, errors: []
    }
  ];

  return scoreFixtures(fixtures, "smoke", null, null, 0);
}

function scoreFixtures(fixtures, mode, receiptFile, repoRoot, parseErrors) {
  const scores = {
    boundary_integrity: scoreBoundaryIntegrity(fixtures),
    scope_integrity: scoreScopeIntegrity(fixtures),
    source_truth_safety: scoreSourceTruthSafety(fixtures),
    traceability: scoreTraceability(fixtures),
    ledger_hygiene: scoreLedgerHygiene(receiptFile),
    public_surface_safety: scorePublicSurfaceSafety(repoRoot),
    model_visibility: scoreModelVisibility(fixtures),
    failure_quality: scoreFailureQuality(fixtures, parseErrors),
  };

  const verdict = aggregateVerdict(scores);
  const repeats = detectRepeatedFailures(fixtures);

  console.log("=== GOAL METRICS SCORE ===");
  console.log(`mode: ${mode}`);
  console.log(`records: ${fixtures.length}`);
  console.log("");
  for (const [dim, score] of Object.entries(scores)) {
    const hard = ["scope_integrity", "source_truth_safety"].includes(dim) ? " [HARD GATE]" : "";
    console.log(`  ${dim}: ${score}${hard}`);
  }
  if (repeats.found) {
    console.log("");
    console.log("  ⚠  REPEATED FAILURES DETECTED:");
    for (const detail of repeats.details) {
      console.log(`     ${detail}`);
    }
  }
  console.log("");
  console.log(`AGGREGATE VERDICT: ${verdict}`);

  // Smoke expects specific scores
  if (mode === "smoke") {
    const expected = {
      boundary_integrity: "BLOCK",
      scope_integrity: "BLOCK",
      source_truth_safety: "FLAG",
      traceability: "FLAG",
      ledger_hygiene: "PASS",
      public_surface_safety: "PASS",
      model_visibility: "OPTIONAL/BLOCKED_BY_AUTH",
      failure_quality: "BLOCK",
    };
    const expectedVerdict = "BLOCK";

    let match = true;
    for (const [dim, exp] of Object.entries(expected)) {
      if (scores[dim] !== exp) {
        console.log(`  MISMATCH ${dim}: expected ${exp}, got ${scores[dim]}`);
        match = false;
      }
    }
    if (verdict !== expectedVerdict) {
      console.log(`  MISMATCH aggregate: expected ${expectedVerdict}, got ${verdict}`);
      match = false;
    }

    if (match) {
      console.log("");
      console.log("SMOKE VERDICT: PASS — all scores match expected");
    } else {
      console.log("");
      console.log("SMOKE VERDICT: FLAG — score mismatch detected");
    }
    console.log("isolated_fixture: true");
    return match ? 0 : 1;
  }

  return verdict === "PASS" ? 0 : verdict === "FLAG" ? 1 : 2;
}

function main() {
  const args = process.argv.slice(2);

  if (args.includes("--fixture")) {
    const fixtureIdx = args.indexOf("--fixture");
    const mode = args[fixtureIdx + 1] || "smoke";
    if (mode === "smoke") {
      process.exitCode = runSmoke();
      return;
    }
    console.log(`Unknown fixture mode: ${mode}`);
    process.exitCode = 2;
    return;
  }

  const receiptIdx = args.indexOf("--receipts");
  const receiptPath = receiptIdx >= 0 ? args[receiptIdx + 1] : defaultReceiptFile;

  if (!fs.existsSync(receiptPath)) {
    console.log(`No receipts found at: ${receiptPath}`);
    console.log("VERDICT: OPTIONAL/BLOCKED_BY_AUTH — no receipt data available");
    process.exitCode = 0;
    return;
  }

  const { receipts, parseErrors } = loadReceipts(receiptPath);
  if (receipts.length === 0 && parseErrors === 0) {
    console.log("Receipt file empty");
    console.log("VERDICT: FLAG — no receipts to score");
    process.exitCode = 1;
    return;
  }
  if (parseErrors > 0) {
    console.log(`⚠  ${parseErrors} parse error(s) in receipt file — scorer will treat these as failure_quality silent drops`);
  }

  process.exitCode = scoreFixtures(receipts, "live", receiptPath, repoCwd, parseErrors);
}

main();
