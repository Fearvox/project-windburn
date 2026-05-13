#!/usr/bin/env node

import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptPath = fileURLToPath(import.meta.url);
const repoCwd = process.env.WINDBURN_CWD || path.resolve(path.dirname(scriptPath), "..");
const effort = process.env.CODEX_APP_SERVER_EFFORT || "low";
const timeoutMs = Number(process.env.CODEX_APP_SERVER_TIMEOUT_MS || 120_000);
const smokeToken = `WINDBURN_MODEL_VISIBLE_${Date.now()}`;

const child = spawn("codex", ["app-server", "--listen", "stdio://"], {
  cwd: repoCwd,
  stdio: ["pipe", "pipe", "pipe"],
});

const pending = new Map();
const notifications = [];
let stdoutBuffer = "";
let stderrBuffer = "";

function writeJsonLine(payload) {
  child.stdin.write(`${JSON.stringify(payload)}\n`);
}

function request(method, params, requestTimeoutMs = timeoutMs) {
  const id = randomUUID();
  writeJsonLine({ id, method, params });

  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`timeout waiting for ${method}`));
    }, requestTimeoutMs);

    pending.set(id, {
      method,
      resolve(value) {
        clearTimeout(timer);
        resolve(value);
      },
      reject(error) {
        clearTimeout(timer);
        reject(error);
      },
    });
  });
}

function notify(method, params) {
  writeJsonLine(params === undefined ? { method } : { method, params });
}

function waitForNotification(predicate, waitTimeoutMs = timeoutMs) {
  return new Promise((resolve, reject) => {
    const startedAt = Date.now();
    const interval = setInterval(() => {
      const match = notifications.find(predicate);
      if (match) {
        clearInterval(interval);
        resolve(match);
        return;
      }

      if (Date.now() - startedAt > waitTimeoutMs) {
        clearInterval(interval);
        reject(new Error("timeout waiting for matching notification"));
      }
    }, 100);
  });
}

function ingestLine(line) {
  if (!line.trim()) return;

  let message;
  try {
    message = JSON.parse(line);
  } catch {
    notifications.push({ parseError: line.slice(0, 300) });
    return;
  }

  if (message.id && pending.has(message.id)) {
    const pendingRequest = pending.get(message.id);
    pending.delete(message.id);

    if (message.error) {
      pendingRequest.reject(
        new Error(`${pendingRequest.method}: ${JSON.stringify(message.error)}`),
      );
    } else {
      pendingRequest.resolve(message.result);
    }
    return;
  }

  notifications.push(message);
}

child.stdout.on("data", (chunk) => {
  stdoutBuffer += chunk.toString("utf8");
  let newlineIndex;

  while ((newlineIndex = stdoutBuffer.indexOf("\n")) >= 0) {
    const line = stdoutBuffer.slice(0, newlineIndex);
    stdoutBuffer = stdoutBuffer.slice(newlineIndex + 1);
    ingestLine(line);
  }
});

child.stderr.on("data", (chunk) => {
  stderrBuffer += chunk.toString("utf8");
});

child.on("exit", (code, signal) => {
  if (pending.size === 0) return;
  const error = new Error(
    `codex app-server exited before completing requests: code=${code} signal=${signal}`,
  );
  for (const pendingRequest of pending.values()) {
    pendingRequest.reject(error);
  }
  pending.clear();
});

function collectAgentTexts(threadReadResponse) {
  return (threadReadResponse.thread?.turns || []).flatMap((turn) =>
    (turn.items || [])
      .filter((item) => item.type === "agentMessage")
      .map((item) => item.text),
  );
}

function countNotificationMethods() {
  const counts = {};
  for (const message of notifications) {
    const key = message.method || message.type || Object.keys(message)[0];
    counts[key] = (counts[key] || 0) + 1;
  }
  return counts;
}

async function main() {
  await new Promise((resolve) => setTimeout(resolve, 300));

  await request("initialize", {
    clientInfo: {
      name: "windburn-app-server-relay-smoke",
      title: "Windburn App Server Relay Smoke",
      version: "0.1.0",
    },
    capabilities: { experimentalApi: true },
  });
  notify("initialized");

  const startResult = await request("thread/start", {
    cwd: repoCwd,
    approvalPolicy: "never",
    sandbox: "read-only",
  });
  const threadId = startResult.thread.id;

  await request("thread/inject_items", {
    threadId,
    items: [
      {
        type: "message",
        role: "user",
        content: [
          {
            type: "input_text",
            text: `PARKING_NOTE: ${smokeToken} app-server injected memory anchor.`,
          },
        ],
      },
    ],
  });

  const directRead = await request("thread/read", {
    threadId,
    includeTurns: true,
  });
  const directReadContainsToken = JSON.stringify(directRead).includes(smokeToken);

  await request("turn/start", {
    threadId,
    effort,
    summary: "none",
    input: [
      {
        type: "text",
        text:
          "Read the injected model-visible history. If there is a PARKING_NOTE " +
          "token beginning WINDBURN_MODEL_VISIBLE_, reply with ONLY that exact " +
          "token. If not, reply MISSING.",
        text_elements: [],
      },
    ],
  });

  const completed = await waitForNotification(
    (message) =>
      message.method === "turn/completed" &&
      message.params?.threadId === threadId,
  );

  if (completed.params.turn.status !== "completed") {
    throw new Error(
      `turn completed with status=${completed.params.turn.status}: ${JSON.stringify(
        completed.params.turn.error,
      )}`,
    );
  }

  const readAfterTurn = await request("thread/read", {
    threadId,
    includeTurns: true,
  });
  const agentTexts = collectAgentTexts(readAfterTurn);
  const modelVisibleReadContainsToken =
    JSON.stringify(readAfterTurn).includes(smokeToken);

  const verdict =
    !directReadContainsToken &&
    modelVisibleReadContainsToken &&
    agentTexts.some((text) => text.includes(smokeToken))
      ? "PASS"
      : "FAIL";

  const stderrLines = stderrBuffer.split("\n").filter(Boolean);
  const summary = {
    verdict,
    threadId,
    smokeToken,
    directReadContainsToken,
    modelVisibleReadContainsToken,
    agentTexts,
    turnCount: readAfterTurn.thread?.turns?.length ?? 0,
    notificationMethodCounts: countNotificationMethods(),
    stderrLineCount: stderrLines.length,
    stderrHasMcpStartupNoise:
      stderrBuffer.includes("AuthRequired") ||
      stderrBuffer.includes("TokenRefreshFailed") ||
      stderrBuffer.includes("Deserialize("),
    note:
      "thread/inject_items appends model-visible Responses items; thread/read only materializes proof after a turn consumes that injected history.",
  };

  console.log(JSON.stringify(summary, null, 2));

  if (verdict !== "PASS") {
    process.exitCode = 1;
  }
}

main()
  .catch((error) => {
    console.error(error.stack || error.message || String(error));
    if (stderrBuffer) {
      console.error(stderrBuffer.slice(0, 4_000));
    }
    process.exitCode = 1;
  })
  .finally(() => {
    child.stdin.end();
    child.kill("SIGTERM");
  });
