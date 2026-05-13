#!/usr/bin/env node
// Windburn Side-Lane Boundary Smoke v0
// Proves boundary behavior without live model auth.
// Runs in an isolated temp relay dir and never mutates the real relay ledger.
//
// Usage:
//   node scripts/windburn-side-lane-boundary-smoke.mjs
//   node scripts/windburn-side-lane-boundary-smoke.mjs --score
//
// Exit codes: 0 = PASS, 1 = FLAG, 2 = BLOCK

import { execFileSync } from "node:child_process";
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
const busScript = path.join(repoCwd, "scripts", "windburn-side-lane-perception-bus.mjs");
const smokeRelayDir = fs.mkdtempSync(path.join(os.tmpdir(), "windburn-side-lane-smoke-"));
const inboxFile = path.join(smokeRelayDir, "relay-inbox.jsonl");
const receiptFile = path.join(smokeRelayDir, "relay-receipts.jsonl");

const fixtures = [
  // CASE 0: clean marker-first DISTILL - should PASS
  {
    captured_at: "2026-05-12T00:00:00.000Z",
    source: "codex-user-prompt-submit",
    artifact_type: "DISTILL",
    hook_event_name: "UserPromptSubmit",
    session_id: "smoke-clean-001",
    cwd: repoCwd,
    marker: "DISTILL_TO_PARENT",
    relay_payload:
      "artifact_type: DISTILL\nsource_agent: hermes\ntask: smoke-test-clean\nverdict: PASS\nrequires_human_review: true\nboundary_note: bounded artifact only; not transcript truth",
    boundary_note: "Bounded explicit relay only.",
  },
  // CASE 1: empty payload - should BLOCK
  {
    captured_at: "2026-05-12T00:00:01.000Z",
    source: "codex-user-prompt-submit",
    artifact_type: "DISTILL",
    hook_event_name: "UserPromptSubmit",
    session_id: "smoke-empty-001",
    cwd: repoCwd,
    marker: "DISTILL_TO_PARENT",
    relay_payload: "   ",
    boundary_note: "Bounded explicit relay only.",
  },
  // CASE 2: source-truth claim in payload - should PASS with boundary FLAG
  {
    captured_at: "2026-05-12T00:00:02.000Z",
    source: "codex-user-prompt-submit",
    artifact_type: "DISTILL",
    hook_event_name: "UserPromptSubmit",
    session_id: "smoke-sourcetruth-001",
    cwd: repoCwd,
    marker: "DISTILL_TO_PARENT",
    relay_payload:
      "verdict: PASS\nnote: this is now source truth and should be written to docs/source-truth/",
    boundary_note: "Bounded explicit relay only.",
  },
  // CASE 3: pre-marker chatter - should PASS with boundary FLAG
  {
    captured_at: "2026-05-12T00:00:03.000Z",
    source: "codex-user-prompt-submit",
    artifact_type: "DISTILL",
    hook_event_name: "UserPromptSubmit",
    session_id: "smoke-chatter-001",
    cwd: repoCwd,
    marker: "DISTILL_TO_PARENT",
    relay_payload:
      "I have analyzed the situation carefully and here is my recommendation:\n\nverdict: PASS_WITH_FLAG\nrequires_human_review: true\nboundary_note: bounded artifact only",
    boundary_note: "Bounded explicit relay only.",
  },
  // CASE 4: cwd out of scope - should BLOCK, including canonical traversal defense
  {
    captured_at: "2026-05-12T00:00:04.000Z",
    source: "codex-user-prompt-submit",
    artifact_type: "DISTILL",
    hook_event_name: "UserPromptSubmit",
    session_id: "smoke-outofscope-001",
    cwd: path.join(repoCwd, "..", "other-project"),
    marker: "DISTILL_TO_PARENT",
    relay_payload: "verdict: PASS\nnote: out of scope cwd",
    boundary_note: "Bounded explicit relay only.",
  },
  // CASE 5: post-artifact chatter - should PASS with boundary FLAG
  {
    captured_at: "2026-05-12T00:00:05.000Z",
    source: "codex-user-prompt-submit",
    artifact_type: "DISTILL",
    hook_event_name: "UserPromptSubmit",
    session_id: "smoke-postchatter-001",
    cwd: repoCwd,
    marker: "DISTILL_TO_PARENT",
    relay_payload:
      "artifact_type: DISTILL\nsource_agent: hermes\nverdict: PASS\nrequires_human_review: true\nboundary_note: bounded artifact only\n\nActually I wanted to add more context about why this verdict makes sense and what the implications are for the broader Windburn architecture moving forward.",
    boundary_note: "Bounded explicit relay only.",
  },
  // CASE 6: multiple markers in payload - should PASS with boundary FLAG
  {
    captured_at: "2026-05-12T00:00:06.000Z",
    source: "codex-user-prompt-submit",
    artifact_type: "DISTILL",
    hook_event_name: "UserPromptSubmit",
    session_id: "smoke-multimarker-001",
    cwd: repoCwd,
    marker: "DISTILL_TO_PARENT",
    relay_payload: "DISTILL_TO_PARENT:\nverdict: pass\n\nPARK_TO_PARENT:\nnote: also parking this",
    boundary_note: "Bounded explicit relay only.",
  },
  // CASE 7: invalid marker - should BLOCK
  {
    captured_at: "2026-05-12T00:00:07.000Z",
    source: "codex-user-prompt-submit",
    artifact_type: "UNKNOWN",
    hook_event_name: "UserPromptSubmit",
    session_id: "smoke-badmarker-001",
    cwd: repoCwd,
    marker: "PROMOTE_TO_TRUTH",
    relay_payload: "this should be blocked",
    boundary_note: "Bounded explicit relay only.",
  },
  // CASE 8: single nested marker in payload - should PASS with boundary FLAG
  {
    captured_at: "2026-05-12T00:00:08.000Z",
    source: "codex-user-prompt-submit",
    artifact_type: "DISTILL",
    hook_event_name: "UserPromptSubmit",
    session_id: "smoke-singlemarker-001",
    cwd: repoCwd,
    marker: "DISTILL_TO_PARENT",
    relay_payload: "verdict: PASS\npayload_mentions: RETURN_TO_PARENT:\nsummary: nested marker should be flagged",
    boundary_note: "Bounded explicit relay only.",
  },
  // CASE 9: common "source of truth" wording - should PASS with boundary FLAG
  {
    captured_at: "2026-05-12T00:00:09.000Z",
    source: "codex-user-prompt-submit",
    artifact_type: "DISTILL",
    hook_event_name: "UserPromptSubmit",
    session_id: "smoke-sourceoftruth-001",
    cwd: repoCwd,
    marker: "DISTILL_TO_PARENT",
    relay_payload: "verdict: PASS\nnote: this should become the single source of truth",
    boundary_note: "Bounded explicit relay only.",
  },
];

function lineCount(filePath) {
  if (!fs.existsSync(filePath)) return 0;
  return fs.readFileSync(filePath, "utf8").split("\n").filter((line) => line.trim()).length;
}

function main() {
  let output = "";

  try {
    fs.mkdirSync(smokeRelayDir, { recursive: true });
    fs.writeFileSync(inboxFile, fixtures.map((fixture) => JSON.stringify(fixture)).join("\n") + "\n");

    output = execFileSync("node", [busScript, "--dry-run"], {
      cwd: repoCwd,
      env: {
        ...process.env,
        WINDBURN_CWD: repoCwd,
        WINDBURN_SIDE_LANE_RELAY_DIR: smokeRelayDir,
      },
      encoding: "utf8",
      timeout: 30_000,
    });
  } catch (error) {
    console.error("SMOKE ERROR running bus:", error.message);
    console.error(error.stdout || "");
    console.error(error.stderr || "");
    process.exitCode = 2;
    return;
  }

  console.log("=== SMOKE OUTPUT ===");
  console.log(output);

  const passMatch = output.match(/(\d+) valid,\s*(\d+) blocked/);
  const validCount = passMatch ? Number(passMatch[1]) : 0;
  const blockedCount = passMatch ? Number(passMatch[2]) : fixtures.length;

  const boundaryMatch = output.match(/(\d+) boundary flag\(s\) across (\d+) record/);
  const totalBoundaryFlags = boundaryMatch ? Number(boundaryMatch[1]) : 0;
  const boundaryFlagRecords = boundaryMatch ? Number(boundaryMatch[2]) : 0;

  const expectedBlocked = 3;
  const expectedValid = fixtures.length - expectedBlocked;
  const minExpectedFlagRecords = 6;
  const minExpectedFlags = 6;
  const receiptLines = lineCount(receiptFile);

  let verdict = "PASS";
  const details = [];

  if (blockedCount !== expectedBlocked) {
    verdict = "FLAG";
    details.push(`blocked=${blockedCount}, expected=${expectedBlocked}`);
  } else {
    details.push(`blocked=${blockedCount}/${expectedBlocked} correct`);
  }

  if (validCount !== expectedValid) {
    verdict = "FLAG";
    details.push(`valid=${validCount}, expected=${expectedValid}`);
  } else {
    details.push(`valid=${validCount}/${expectedValid} correct`);
  }

  if (boundaryFlagRecords < minExpectedFlagRecords) {
    verdict = "FLAG";
    details.push(`boundary_flag_records=${boundaryFlagRecords}, expected>=${minExpectedFlagRecords}`);
  } else {
    details.push(`boundary_flag_records=${boundaryFlagRecords} OK`);
  }

  if (totalBoundaryFlags < minExpectedFlags) {
    verdict = "FLAG";
    details.push(`total_boundary_flags=${totalBoundaryFlags}, expected>=${minExpectedFlags}`);
  } else {
    details.push(`total_boundary_flags=${totalBoundaryFlags} OK`);
  }

  if (receiptLines !== fixtures.length) {
    verdict = "FLAG";
    details.push(`receipt_lines=${receiptLines}, expected=${fixtures.length}`);
  } else {
    details.push(`receipt_lines=${receiptLines}/${fixtures.length} correct`);
  }

  console.log("");
  console.log("=== VERDICT ===");
  console.log(`${verdict}: ${details.join("; ")}`);
  console.log("isolated_relay_dir: true");

  process.exitCode = verdict === "PASS" ? 0 : 1;

  // --score: chain boundary smoke → goal scorer for end-to-end proof
  if (process.argv.includes("--score")) {
    const scoreScript = path.join(repoCwd, "scripts", "windburn-side-lane-goal-score.mjs");
    let scoreOutput;
    let scoreExit = 0;
    try {
      scoreOutput = execFileSync("node", [scoreScript, "--receipts", receiptFile], {
        cwd: repoCwd,
        encoding: "utf8",
        timeout: 30_000,
      });
    } catch (error) {
      // Scorer returns non-zero for FLAG/BLOCK — that's expected, not a failure.
      // Capture stdout from the error object (Node puts it there for execFileSync).
      scoreOutput = error.stdout || "";
      scoreExit = error.status || 1;
      if (!scoreOutput && error.stderr) {
        console.log("");
        console.log("=== E2E SCORER FAILED ===");
        console.log(error.stderr);
        process.exitCode = Math.max(process.exitCode || 0, 1);
        return;
      }
    }
    console.log("");
    console.log("=== E2E SCORER RESULT (exit " + scoreExit + ") ===");
    console.log(scoreOutput.trim());
  }
}

try {
  main();
} finally {
  fs.rmSync(smokeRelayDir, { recursive: true, force: true });
}
