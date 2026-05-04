const fallbackRemotes = [
  {
    id: "hermes",
    name: "Hermes Yolo",
    host: "public host hidden",
    kind: "tmux",
    status: "PASS",
    latency: "tmux live",
    transport: "tmux attach target hidden",
    command: "operator script hidden",
    taste: "primary high-context chat lane",
  },
  {
    id: "workhorse",
    name: "NixOS Workhorse",
    host: "public host hidden",
    kind: "nixos",
    status: "FLAG",
    latency: "foundation",
    transport: "NixOS rebuild target hidden",
    command: "operator script hidden",
    taste: "remote build and runner cell",
  },
  {
    id: "ccr",
    name: "CCR Embed",
    host: "internal host hidden",
    kind: "internal",
    status: "FLAG",
    latency: "tailnet ok",
    transport: "embedding route hidden",
    command: "operator script hidden",
    taste: "embedding and review substrate",
  },
  {
    id: "codex",
    name: "Local Codex",
    host: "local workspace hidden",
    kind: "local",
    status: "PASS",
    latency: "local",
    transport: "workspace shell hidden",
    command: "local check script hidden",
    taste: "operator control plane",
  },
  {
    id: "superconductor",
    name: "Superconductor",
    host: "workspace binding hidden",
    kind: "shell",
    status: "PASS",
    latency: "linked",
    transport: "linked repo anchor",
    command: "intake script hidden",
    taste: "multi-workspace dispatch surface",
  },
];

let remotes = fallbackRemotes.map((remote) => ({ ...remote }));

const fallbackPreflight = [
  { label: "Hermes yolo tmux loop", status: "pass" },
  { label: "Hermes health gate", status: "pass" },
  { label: "DO uptime and alerts", status: "flag" },
  { label: "Windburn workhorse runner", status: "flag" },
  { label: "CCR public route", status: "flag" },
];

let preflight = fallbackPreflight.map((item) => ({ ...item }));

const fallbackSuperruntimeStatus = {
  source: "fixture",
  registeredRuntimeCount: 1,
  queuedTaskCount: 0,
  currentLease: "leased",
  harnessDispatchState: "dispatches recorded 1",
};

let superruntimeStatus = { ...fallbackSuperruntimeStatus };

const bridgeState = {
  connected: false,
  mode: "local mock",
  status: null,
};

const sensitiveFactKeys = new Set(["host", "transport", "command"]);

const sensitivityPatterns = [
  {
    pattern: /\b(?:\d{1,3}\.){3}\d{1,3}\b/g,
    replacement: "[redacted:host]",
  },
  {
    pattern: /(?:^|[\s"'`(])\/Users\/[^\s"'`),]+/g,
    replacement: (match) => `${match[0] === "/" ? "" : match[0]}[redacted:local-path]`,
  },
  {
    pattern: /(?:^|[\s"'`(])\/srv\/[^\s"'`),]+/g,
    replacement: (match) => `${match[0] === "/" ? "" : match[0]}[redacted:remote-path]`,
  },
  {
    pattern: /\bssh\s+[^\n]+/gi,
    replacement: "ssh [redacted:target]",
  },
  {
    pattern: /\b(?:sk|xai)-[A-Za-z0-9_-]{12,}\b/g,
    replacement: "[redacted:key]",
  },
  {
    pattern: /\b(?:bearer|token|secret|password|api[_-]?key)\s*[:=]\s*[^\s,;]+/gi,
    replacement: "[redacted:secret]",
  },
  {
    pattern: /\b(?:prj|dpl)_[A-Za-z0-9]+\b/g,
    replacement: "[redacted:id]",
  },
];

const actions = [
  ["/status", "Status"],
  ["/route hermes", "Hermes"],
  ["/route workhorse", "NixOS"],
  ["/broadcast preflight", "Broadcast"],
  ["/attach tmux", "Attach"],
  ["/explain flags", "Flags"],
  ["/mcp", "MCP"],
  ["$goal", "$ Goal"],
  ["/stream sample", "Stream"],
];

const slashCommands = [
  {
    command: "/status",
    label: "Route status",
    instruction: "Print the PASS/FLAG/BLOCK ledger for every remote route.",
  },
  {
    command: "/route hermes",
    label: "Switch route",
    instruction: "Focus the transcript and inspector on a specific route id.",
  },
  {
    command: "/attach tmux",
    label: "Attach handoff",
    instruction: "Show the next human-approved tmux attach target without running it.",
  },
  {
    command: "/broadcast preflight",
    label: "Broadcast intent",
    instruction: "Stage a read-only broadcast plan across routes; no mutation bridge.",
  },
  {
    command: "/setup xai",
    label: "Setup lane",
    instruction: "Open the setup assistant and convert vague prerequisite work into a bounded operator task.",
  },
  {
    command: "/mcp",
    label: "MCP connections",
    instruction: "List browser-safe MCP connection contracts and their policy boundaries.",
  },
  {
    command: "/stream sample",
    label: "Stream display",
    instruction: "Render noisy hook/thinking/tool lines as human-readable stream cards.",
  },
];

const skillCommands = [
  {
    command: "$goal",
    label: "Goal Mode",
    instruction: "Lock the objective, keep working until verified completion or a real BLOCK.",
  },
  {
    command: "$review",
    label: "Evidence review",
    instruction: "Find bugs, missing proof, unsafe claims, and residual risk before closeout.",
  },
  {
    command: "$playwright",
    label: "Browser proofshot",
    instruction: "Use a local browser to inspect UI state, interactions, screenshots, and accessibility snapshots.",
  },
  {
    command: "$ship",
    label: "Ship lane",
    instruction: "Commit, push, open PR, and report exact validation without hiding dirty state.",
  },
  {
    command: "$setup",
    label: "Setup assistant",
    instruction: "Turn dull prerequisite configuration into a narrow operator checklist.",
  },
  {
    command: "$mcp",
    label: "MCP audit",
    instruction: "Read available tool connections and separate local-only tools from cloud-safe surfaces.",
  },
];

const mcpConnections = [
  {
    command: "mcp:filesystem",
    label: "Filesystem local",
    status: "local-only",
    instruction: "Repo read/write stays in the local Windburn worktree; browser sees summaries only.",
  },
  {
    command: "mcp:playwright",
    label: "Playwright",
    status: "browser",
    instruction: "Local UI verification, snapshots, and screenshots. Do not inherit into cloud-safe agents.",
  },
  {
    command: "mcp:github",
    label: "GitHub",
    status: "repo",
    instruction: "PR, issue, and branch truth via GitHub/gh; no tokens or raw private payloads in UI.",
  },
  {
    command: "mcp:research-vault",
    label: "Research Vault",
    status: "read-only",
    instruction: "Grounding/search only by default. Writes require explicit operator approval.",
  },
  {
    command: "mcp:superconductor",
    label: "Superconductor",
    status: "control room",
    instruction: "Workspace routing and observation surface. Repo and CI evidence remain source of truth.",
  },
];

const streamSample = [
  "∴ Thinking…",
  "Let me continue reading the app.js to see the setup assistant, slash commands, and render logic.",
  "PostToolUse:Read hook error",
  "PostToolUse:Read hook error",
  "Async hook PostToolUse completed",
  "Async hook PostToolUse completed",
  "✻ Embellishing… (1m 28s · ↓ 1.2k tokens · thinking with high effort)",
];

let activeRemote = remotes[0];
let activeInstructionKind = "slash";
const transcript = [];

const routeList = document.querySelector("#routeList");
const activeTitle = document.querySelector("#activeTitle");
const activeStatus = document.querySelector("#activeStatus");
const activeLatency = document.querySelector("#activeLatency");
const contractBadge = document.querySelector("#contractBadge");
const routeFacts = document.querySelector("#routeFacts");
const quickActions = document.querySelector("#quickActions");
const instructionTabs = document.querySelector("#instructionTabs");
const instructionList = document.querySelector("#instructionList");
const preflightList = document.querySelector("#preflightList");
const transcriptEl = document.querySelector("#transcript");
const form = document.querySelector("#chatForm");
const input = document.querySelector("#promptInput");
const provenanceSuggestions = document.querySelector("#provenanceSuggestions");
const commandHints = document.querySelector("#commandHints");
const poolCapacity = document.querySelector("#poolCapacity");
const poolMeter = document.querySelector("#poolMeter");
const poolActive = document.querySelector("#poolActive");
const globalStats = document.querySelector("#globalStats");
const runLedger = document.querySelector("#runLedger");
const superruntimeStatusEl = document.querySelector("#superruntimeStatus");
const superruntimeBadge = document.querySelector("#superruntimeBadge");
const setupAssistant = document.querySelector("#setupAssistant");
const setupAssistantToggle = document.querySelector("#setupAssistantToggle");
const setupAssistantBody = document.querySelector("#setupAssistantBody");
const setupState = document.querySelector("#setupState");
const setupCopy = document.querySelector("#setupCopy");
const rawSetupPrompt = document.querySelector("#rawSetupPrompt");
const polishedSetupPrompt = document.querySelector("#polishedSetupPrompt");
const promptPolishButton = document.querySelector("#promptPolishButton");
const modeLabel = document.querySelector("#modeLabel");
const bridgeLabel = document.querySelector("#bridgeLabel");
const dismissedPromptSuggestionIds = new Set();
let activePromptSuggestions = [];

const setupWindows = {
  font: "https://commitmono.com/",
  dash: "https://docs.zonicdesign.art/pages/getting-started.html",
  agentPipeline: "https://docs.zonicdesign.art/pages/guides/agent-pipeline.html",
  configuration: "https://docs.zonicdesign.art/pages/reference/config.html",
  xai: "local setup script hidden",
};

function boot() {
  setBridgeLabels();
  renderRoutes();
  renderQuickActions();
  renderInstructionTabs();
  renderInstructionList("slash");
  renderPreflight();
  renderOperationalSummary();
  renderRunLedger();
  renderSuperruntimeStatus();
  wireSetupAssistant();
  checkOnboardingReadiness();
  selectRemote("hermes");
  addMessage("system", "Fusion router online. Active lane: Hermes yolo. Stream-safe privacy is locked for this browser surface.");
  addMessage("remote", "Jcode direction imported: multi-session harness, side panels, swarm-minded route control. Windburn ownership layer active.");
  addMessage("alert", "Remaining global flags are intentionally visible: DO observability, CCR public route, and workhorse runner engagement.");
  void hydrateBridgeState();
}

function setBridgeLabels() {
  modeLabel.textContent = bridgeState.connected ? "read-only" : "read-only";
  bridgeLabel.textContent = bridgeState.connected ? "live bridge" : "local mock";
}

function redactText(value) {
  return sensitivityPatterns.reduce(
    (text, { pattern, replacement }) => text.replace(pattern, replacement),
    String(value ?? ""),
  );
}

function isSensitiveValue(key, value) {
  const text = String(value ?? "");
  return (
    sensitiveFactKeys.has(key) ||
    /\b(?:\d{1,3}\.){3}\d{1,3}\b/.test(text) ||
    /\/Users\/|\/srv\/|ssh\s+|root@|tmux\s+attach/i.test(text)
  );
}

function sensitivityLabel(key, value) {
  const text = String(value ?? "").toLowerCase();
  if (key === "host" || /\b(?:\d{1,3}\.){3}\d{1,3}\b/.test(text)) return "host";
  if (/\/users\/|\/srv\//i.test(text)) return "path";
  if (/ssh\s+|tmux\s+attach|scripts\//i.test(text)) return "command";
  return key;
}

function makeSpoiler(label) {
  const span = document.createElement("span");
  span.className = "spoiler";
  span.textContent = `spoiler:${label}`;
  return span;
}

function appendSafeValue(parent, key, value) {
  if (isSensitiveValue(key, value)) {
    parent.appendChild(makeSpoiler(sensitivityLabel(key, value)));
    return;
  }
  parent.textContent = redactText(value);
}

function safeRemote(remote) {
  return {
    ...remote,
    host: isSensitiveValue("host", remote.host)
      ? `${remote.kind ?? "remote"} host hidden`
      : redactText(remote.host),
    transport: isSensitiveValue("transport", remote.transport)
      ? `${remote.kind ?? "remote"} transport hidden`
      : redactText(remote.transport),
    command: isSensitiveValue("command", remote.command)
      ? "operator command hidden"
      : redactText(remote.command),
  };
}

async function hydrateBridgeState() {
  try {
    const [statusResponse, remotesResponse, preflightResponse] = await Promise.all([
      fetch("/api/status", { cache: "no-store" }),
      fetch("/api/remotes", { cache: "no-store" }),
      fetch("/api/preflight", { cache: "no-store" }),
    ]);

    if (!statusResponse.ok || !remotesResponse.ok || !preflightResponse.ok) {
      throw new Error("bridge endpoints unavailable");
    }

    const [statusPayload, remotesPayload, preflightPayload] = await Promise.all([
      statusResponse.json(),
      remotesResponse.json(),
      preflightResponse.json(),
    ]);

    bridgeState.connected = true;
    bridgeState.mode = statusPayload.mode ?? "read-only";
    bridgeState.status = statusPayload;
    remotes = Array.isArray(remotesPayload.remotes) && remotesPayload.remotes.length
      ? remotesPayload.remotes.map(safeRemote)
      : remotes;
    preflight = Array.isArray(preflightPayload.preflight) && preflightPayload.preflight.length
      ? preflightPayload.preflight
      : preflight;

    setBridgeLabels();
    renderRoutes();
    renderPreflight();
    renderOperationalSummary();
    renderRunLedger();
    await hydrateSuperruntimeState();
    selectRemote(activeRemote.id);

    const repo = statusPayload.repo ?? {};
    addMessage(
      "system",
      `Fusion Bridge v0 connected. Read-only API: repo proof available; dirty=${String(repo.dirty ?? "unknown")}.`,
    );
  } catch {
    bridgeState.connected = false;
    bridgeState.status = null;
    setBridgeLabels();
    addMessage("system", "Bridge API unavailable; static fallback remains active. Start the local read-only bridge for live state.");
  }
}

async function hydrateSuperruntimeState() {
  try {
    const response = await fetch("/api/superruntime", { cache: "no-store" });
    if (!response.ok) {
      throw new Error("superruntime endpoint unavailable");
    }
    const payload = await response.json();
    superruntimeStatus = normalizeSuperruntimeStatus(payload, "bridge");
  } catch {
    superruntimeStatus = { ...fallbackSuperruntimeStatus };
  }
  renderSuperruntimeStatus();
}

function normalizeSuperruntimeStatus(payload, source) {
  const runtimes = Array.isArray(payload?.runtimes) ? payload.runtimes : [];
  const queuedTasks = Array.isArray(payload?.queued_tasks)
    ? payload.queued_tasks
    : Array.isArray(payload?.queuedTasks)
      ? payload.queuedTasks
      : [];
  const registeredRuntimeCount =
    numberOrFallback(payload?.registered_runtime_count, payload?.registeredRuntimeCount, runtimes.length);
  const queuedTaskCount =
    numberOrFallback(payload?.queued_task_count, payload?.queuedTaskCount, queuedTasks.length);
  const leasePayload = payload?.current_lease ?? payload?.currentLease ?? payload?.lease;
  const harnessPayload = payload?.harness ?? payload?.harness_dispatch ?? payload?.harnessDispatch;

  return {
    source,
    registeredRuntimeCount,
    queuedTaskCount,
    currentLease: safeSuperruntimeLabel(
      leasePayload?.state ??
        leasePayload?.status ??
        leasePayload?.label ??
        leasePayload ??
        "none",
    ),
    harnessDispatchState: safeSuperruntimeLabel(
      harnessPayload?.dispatch_state ??
        harnessPayload?.dispatchState ??
        harnessPayload?.state ??
        harnessPayload?.status ??
        payload?.harness_dispatch_state ??
        payload?.harnessDispatchState ??
        "unknown",
    ),
  };
}

function numberOrFallback(...values) {
  const value = values.find((candidate) => Number.isFinite(Number(candidate)));
  return Math.max(0, Number(value ?? 0));
}

function safeSuperruntimeLabel(value) {
  const text = redactText(value)
    .replace(/\b[a-z]{2,}_[A-Za-z0-9_-]{10,}\b/g, "[redacted:id]")
    .trim();
  if (!text || isSensitiveValue("superruntime", text) || /\[redacted:/.test(text)) {
    return "redacted";
  }
  return text
    .toLowerCase()
    .replace(/[_:]+/g, " ")
    .replace(/[^a-z0-9 .:_/-]+/g, "")
    .slice(0, 34) || "unknown";
}

function renderSuperruntimeStatus() {
  superruntimeBadge.textContent = bridgeState.connected && superruntimeStatus.source === "bridge"
    ? "live"
    : "fixture";
  superruntimeStatusEl.innerHTML = "";
  [
    ["registered", superruntimeStatus.registeredRuntimeCount],
    ["queued", superruntimeStatus.queuedTaskCount],
    ["lease", superruntimeStatus.currentLease],
    ["harness", superruntimeStatus.harnessDispatchState],
  ].forEach(([label, value]) => {
    const row = document.createElement("div");
    const term = document.createElement("span");
    const data = document.createElement("strong");
    term.textContent = label;
    data.textContent = String(value);
    row.append(term, data);
    superruntimeStatusEl.appendChild(row);
  });
}

function renderRoutes() {
  routeList.innerHTML = "";
  remotes.forEach((remote) => {
    const button = document.createElement("button");
    button.className = "route-button";
    button.type = "button";
    button.dataset.route = remote.id;
    const dot = document.createElement("span");
    dot.className = "route-dot";
    dot.style.color = statusColor(remote.status);
    dot.setAttribute("aria-hidden", "true");

    const body = document.createElement("span");
    const name = document.createElement("span");
    name.className = "route-name";
    name.textContent = remote.name;
    const host = document.createElement("span");
    host.className = "route-host";
    appendSafeValue(host, "host", remote.host);
    body.append(name, host);

    const kind = document.createElement("span");
    kind.className = "route-kind";
    kind.textContent = remote.kind;

    button.append(dot, body, kind);
    button.addEventListener("click", () => selectRemote(remote.id));
    routeList.appendChild(button);
  });
}

function renderQuickActions() {
  quickActions.innerHTML = "";
  actions.forEach(([command, label]) => {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.title = command;
    button.addEventListener("click", () => runCommand(command));
    quickActions.appendChild(button);
  });
}

function renderInstructionTabs() {
  instructionTabs.innerHTML = "";
  [
    ["slash", "/ slash"],
    ["skills", "$ skills"],
    ["mcp", "MCP"],
  ].forEach(([kind, label]) => {
    const button = document.createElement("button");
    button.type = "button";
    button.role = "tab";
    button.textContent = label;
    button.setAttribute("aria-selected", String(kind === activeInstructionKind));
    button.addEventListener("click", () => {
      activeInstructionKind = kind;
      renderInstructionTabs();
      renderInstructionList(kind);
    });
    instructionTabs.appendChild(button);
  });
}

function renderInstructionList(kind, query = "") {
  const rows = getInstructionRows(kind, query);
  instructionList.innerHTML = "";
  rows.forEach((item) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "instruction-item";
    button.innerHTML = `
      <span class="instruction-command"></span>
      <span class="instruction-meta"></span>
      <span class="instruction-copy"></span>
    `;
    button.querySelector(".instruction-command").textContent = item.command;
    button.querySelector(".instruction-meta").textContent = `${item.label}${item.status ? ` / ${item.status}` : ""}`;
    button.querySelector(".instruction-copy").textContent = item.instruction;
    button.addEventListener("click", () => applyInstruction(item));
    instructionList.appendChild(button);
  });
}

function getInstructionRows(kind, query = "") {
  const source =
    kind === "skills" ? skillCommands : kind === "mcp" ? mcpConnections : slashCommands;
  const needle = query.trim().toLowerCase();
  if (!needle) return source;
  return source.filter((item) =>
    [item.command, item.label, item.status, item.instruction]
      .filter(Boolean)
      .join(" ")
      .toLowerCase()
      .includes(needle),
  );
}

function applyInstruction(item) {
  const value = item.command.startsWith("mcp:")
    ? `/mcp ${item.command.slice(4)}`
    : item.command;
  input.value = value;
  resizeInput();
  updateCommandHints();
  input.focus();
}

function normalizeClipboardText(value) {
  return String(value ?? "")
    .trim()
    .replace(/^['"]|['"]$/g, "")
    .trim();
}

function basenameFromPath(value) {
  const clean = normalizeClipboardText(value);
  return clean.split(/[\\/]/).filter(Boolean).pop() || clean;
}

function shortStableId(value) {
  const text = String(value ?? "");
  let hash = 5381;
  for (let index = 0; index < text.length; index += 1) {
    hash = (hash * 33) ^ text.charCodeAt(index);
  }
  return (hash >>> 0).toString(36);
}

function suggestionId(kind, value) {
  return `${kind}:${shortStableId(value)}`;
}

function looksSecretLike(value) {
  const text = String(value ?? "");
  return /(?:sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9_]{16,}|Authorization:\s*Bearer|api[_-]?key\s*[=:]|password\s*[=:]|token\s*[=:]|BEGIN (?:RSA |OPENSSH |PRIVATE )?KEY)/i.test(
    text,
  );
}

function looksSensitivePathLike(value) {
  const text = normalizeClipboardText(value).toLowerCase();
  return /(?:^|[\\/])(?:_local-cred|credentials?|secrets?|\.ssh)(?:[\\/]|$)/.test(text)
    || /(?:^|[\\/])\.env(?:[\\/.\w-]*|$)/.test(text)
    || /(?:^|[\\/])id_(?:rsa|ed25519|ecdsa|dsa)(?:\.pub)?$/.test(text)
    || /\.(?:pem|key|p12|pfx)$/i.test(text);
}

function classifyClipboardSuggestion(raw) {
  const value = normalizeClipboardText(raw);
  if (!value || looksSecretLike(value)) return null;

  const isLocalPath = /^(?:~|\/Users\/|\/Volumes\/|\.{0,2}\/)/.test(value);
  const isImage = /\.(?:png|jpe?g|gif|webp|svg)$/i.test(value);
  const isMarkdown = /\.(?:md|markdown)$/i.test(value);
  const isUrl = /^https?:\/\//i.test(value);
  const isCommand = /^(?:git|pnpm|npm|bun|node|cargo|just|scripts\/|\.\/scripts\/|npx)\b/.test(value);

  if (isLocalPath && looksSensitivePathLike(value)) return null;

  if (isLocalPath && isImage) {
    return {
      id: suggestionId("clipboard:image", value),
      source: "Clipboard",
      title: "Attach recent screenshot path?",
      preview: basenameFromPath(value),
      value,
      action: "Use path",
      note: "local only · not sent until accepted",
    };
  }
  if (isLocalPath && isMarkdown) {
    return {
      id: suggestionId("clipboard:markdown", value),
      source: "Clipboard",
      title: "Use markdown artifact path?",
      preview: basenameFromPath(value),
      value,
      action: "Use path",
      note: "local artifact · accepted text only",
    };
  }
  if (isUrl) {
    return {
      id: suggestionId("clipboard:url", value),
      source: "Clipboard",
      title: "Use copied URL?",
      preview: value.length > 88 ? `${value.slice(0, 85)}...` : value,
      value,
      action: "Use URL",
      note: "clipboard URL",
    };
  }
  if (isCommand) {
    return {
      id: suggestionId("clipboard:command", value),
      source: "Clipboard",
      title: "Use copied command?",
      preview: value.length > 88 ? `${value.slice(0, 85)}...` : value,
      value,
      action: "Use command",
      note: "review before send",
    };
  }

  return null;
}

function contextPromptSuggestion() {
  return {
    id: `context:${activeRemote.id}`,
    source: "Context",
    title: `Ask ${activeRemote.name} for next action`,
    preview: `${activeRemote.name}: summarize status, blocker, and one safe next step`,
    value: `Summarize ${activeRemote.name} status, blocker, and one safe next action.`,
    action: "Use prompt",
    note: "current route",
  };
}

async function refreshPromptSuggestions(reason = "focus") {
  if (document.hidden || document.activeElement !== input || input.value.trim()) {
    hidePromptSuggestions();
    return;
  }

  const suggestions = [contextPromptSuggestion()];
  if (navigator.clipboard?.readText && (reason === "focus" || reason === "pointer" || reason === "manual")) {
    try {
      const clipboard = await navigator.clipboard.readText();
      const clipboardSuggestion = classifyClipboardSuggestion(clipboard);
      if (clipboardSuggestion) suggestions.unshift(clipboardSuggestion);
    } catch {
      // Browser permissions differ. Silent fallback keeps the composer usable.
    }
  }

  activePromptSuggestions = suggestions.filter((item) => !dismissedPromptSuggestionIds.has(item.id)).slice(0, 3);
  renderPromptSuggestions();
}

function renderPromptSuggestions() {
  if (!activePromptSuggestions.length) {
    hidePromptSuggestions();
    return;
  }

  provenanceSuggestions.hidden = false;
  provenanceSuggestions.innerHTML = "";

  activePromptSuggestions.forEach((item, index) => {
    const card = document.createElement("div");
    card.className = "provenance-card";
    card.dataset.suggestionId = item.id;
    card.innerHTML = `
      <button class="provenance-main" type="button">
        <span class="provenance-title"></span>
        <span class="provenance-preview"></span>
      </button>
      <span class="provenance-source"></span>
      <button class="provenance-action" type="button"></button>
      <button class="provenance-dismiss" type="button" aria-label="Dismiss suggestion">×</button>
    `;
    card.querySelector(".provenance-title").textContent = item.title;
    card.querySelector(".provenance-preview").textContent = item.preview;
    card.querySelector(".provenance-source").textContent = `${item.source} · ${item.note}`;
    card.querySelector(".provenance-action").textContent = item.action;
    card.querySelector(".provenance-main").addEventListener("click", () => acceptPromptSuggestion(item));
    card.querySelector(".provenance-action").addEventListener("click", () => acceptPromptSuggestion(item));
    card.querySelector(".provenance-dismiss").addEventListener("click", () => dismissPromptSuggestion(item.id));
    if (index === 0) card.dataset.primary = "true";
    provenanceSuggestions.appendChild(card);
  });
}

function acceptPromptSuggestion(item) {
  input.value = item.value;
  input.dataset.provenance = item.source;
  resizeInput();
  hidePromptSuggestions();
  updateCommandHints();
  input.focus();
}

function dismissPromptSuggestion(id) {
  dismissedPromptSuggestionIds.add(id);
  activePromptSuggestions = activePromptSuggestions.filter((item) => item.id !== id);
  renderPromptSuggestions();
  input.focus();
}

function hidePromptSuggestions() {
  provenanceSuggestions.hidden = true;
  provenanceSuggestions.innerHTML = "";
}

function renderPreflight() {
  preflightList.innerHTML = "";
  preflight.forEach((item) => {
    const li = document.createElement("li");
    li.className = item.status;
    li.textContent = `${item.status.toUpperCase()} ${item.label}`;
    preflightList.appendChild(li);
  });
}

function renderOperationalSummary() {
  const passCount = remotes.filter((remote) => remote.status === "PASS").length;
  const flagCount = remotes.filter((remote) => remote.status === "FLAG").length;
  const blockCount = remotes.filter((remote) => remote.status === "BLOCK").length;
  const readyPercent = Math.round((passCount / remotes.length) * 100);

  poolCapacity.textContent = `${passCount}/${remotes.length}`;
  poolMeter.innerHTML = "";
  remotes.forEach((remote) => {
    const cell = document.createElement("span");
    cell.className = statusClass(remote.status);
    cell.title = `${remote.name}: ${remote.status}`;
    poolMeter.appendChild(cell);
  });

  globalStats.innerHTML = "";
  [
    ["ready", `${readyPercent}%`],
    ["pass", passCount],
    ["flag", flagCount],
    ["block", blockCount],
    ["remote writes", "locked"],
  ].forEach(([label, value]) => {
    const item = document.createElement("div");
    item.className = "stat-cell";
    item.innerHTML = `<span>${label}</span><strong>${value}</strong>`;
    globalStats.appendChild(item);
  });
}

function renderRunLedger() {
  runLedger.innerHTML = "";
  remotes.forEach((remote) => {
    const button = document.createElement("button");
    button.type = "button";
    button.dataset.route = remote.id;
    button.innerHTML = `
      <span class="ledger-status ${statusClass(remote.status)}">${remote.status}</span>
      <span>
        <strong>${remote.name}</strong>
        <small>${remote.latency} / ${remote.kind}</small>
      </span>
    `;
    button.addEventListener("click", () => selectRemote(remote.id));
    runLedger.appendChild(button);
  });
}

function selectRemote(id) {
  activeRemote = remotes.find((remote) => remote.id === id) ?? activeRemote;
  activeTitle.textContent = activeRemote.name;
  activeStatus.textContent = activeRemote.status;
  activeStatus.className = `status ${statusClass(activeRemote.status)}`;
  activeLatency.textContent = activeRemote.latency;
  contractBadge.textContent = activeRemote.kind;
  poolActive.textContent = activeRemote.name;
  document.querySelectorAll(".route-button").forEach((button) => {
    button.setAttribute("aria-current", String(button.dataset.route === activeRemote.id));
  });
  document.querySelectorAll(".run-ledger button").forEach((button) => {
    button.setAttribute("aria-current", String(button.dataset.route === activeRemote.id));
  });
  renderFacts();
}

function renderFacts() {
  const facts = {
    host: activeRemote.host,
    status: activeRemote.status,
    transport: activeRemote.transport,
    command: activeRemote.command,
    role: activeRemote.taste,
  };
  routeFacts.innerHTML = "";
  Object.entries(facts).forEach(([key, value]) => {
    const row = document.createElement("div");
    const term = document.createElement("dt");
    term.textContent = key;
    const description = document.createElement("dd");
    appendSafeValue(description, key, value);
    row.append(term, description);
    routeFacts.appendChild(row);
  });
}

function runCommand(command) {
  input.value = command;
  resizeInput();
  void dispatch(command);
  input.value = "";
  resizeInput();
}

async function dispatch(raw) {
  const text = raw.trim();
  if (!text) return;
  addMessage("operator", text);

  if (text.startsWith("/route ")) {
    const id = text.split(/\s+/)[1];
    const next = remotes.find((remote) => remote.id === id);
    if (next) {
      selectRemote(next.id);
      addMessage("system", `Route switched to ${next.name}. Transport is spoiler-protected in Route Contract.`);
    } else {
      addMessage("alert", `Unknown route: ${id}. Available: ${remotes.map((remote) => remote.id).join(", ")}.`);
    }
    return;
  }

  if (text === "/status") {
    const lines = remotes.map((remote) => `${remote.status.padEnd(5)} ${remote.id.padEnd(14)} ${remote.latency}`);
    const repo = bridgeState.status?.repo;
    const bridgeLine = bridgeState.connected
      ? `BRIDGE read-only-live repo-proof dirty=${String(repo?.dirty ?? "unknown")}`
      : "BRIDGE local-mock static fallback";
    addMessage("remote", [bridgeLine, ...lines].join("\n"));
    return;
  }

  if (text === "/attach tmux") {
    addMessage("remote", "Next backend bridge target is staged, but host and attach command stay spoiler-protected in the browser.");
    return;
  }

  if (text.startsWith("/broadcast")) {
    addMessage("remote", "Broadcast plan staged for all routes. Current MVP records intent only; mutation bridge remains disabled.");
    return;
  }

  if (text === "/explain flags") {
    addMessage("alert", "Global FLAG is not a Hermes loop failure. Outstanding: DO alert recipients, DO uptime checks, CCR legacy public port, workhorse task runner.");
    return;
  }

  if (text === "/stream sample") {
    addMessage("system", "Rendering a noisy agent stream sample with human-readable status cards.");
    streamSample.forEach((line) => addStreamLine(line));
    return;
  }

  if (text.startsWith("/setup")) {
    await handleSetupCommand(text);
    return;
  }

  if (text.startsWith("/mcp")) {
    handleMcpCommand(text);
    return;
  }

  if (text.startsWith("$")) {
    handleSkillCommand(text);
    return;
  }

  addMessage("remote", `${activeRemote.name} queued: ${text}\nBridge mode is local mock until the signed SSH/websocket adapter is enabled.`);
}

function addMessage(role, body) {
  if (role === "stream") {
    body.split(/\r?\n/).filter(Boolean).forEach((line) => addStreamLine(line));
    return;
  }

  const safeBody = redactText(body);
  transcript.push({ role, body: safeBody });
  const li = document.createElement("li");
  li.className = `message ${role}`;
  li.innerHTML = `<span class="message-role">${role}</span><span class="message-body"></span>`;
  li.querySelector(".message-body").textContent = safeBody;
  transcriptEl.appendChild(li);
  transcriptEl.scrollTop = transcriptEl.scrollHeight;
}

function addStreamLine(raw) {
  const safeRaw = redactText(raw);
  const event = classifyStreamLine(safeRaw);
  const previous = transcript[transcript.length - 1];
  const previousEl = transcriptEl.lastElementChild;

  if (
    previous?.role === "stream" &&
    previous.fingerprint === event.fingerprint &&
    previousEl?.dataset.fingerprint === event.fingerprint
  ) {
    previous.count += 1;
    previous.body = safeRaw;
    previousEl.querySelector(".stream-count").textContent = `×${previous.count}`;
    previousEl.querySelector(".stream-raw").textContent = safeRaw;
    transcriptEl.scrollTop = transcriptEl.scrollHeight;
    return;
  }

  transcript.push({
    role: "stream",
    body: safeRaw,
    count: 1,
    fingerprint: event.fingerprint,
  });

  const li = document.createElement("li");
  li.className = `message stream ${event.kind} ${event.severity}`;
  li.dataset.fingerprint = event.fingerprint;
  li.innerHTML = `
    <span class="message-role"></span>
    <span class="stream-card">
      <span class="stream-card-head">
        <strong class="stream-title"></strong>
        <span class="stream-count">×1</span>
      </span>
      <span class="stream-human"></span>
      <code class="stream-raw"></code>
    </span>
  `;
  li.querySelector(".message-role").textContent = event.label;
  li.querySelector(".stream-title").textContent = event.title;
  li.querySelector(".stream-human").textContent = event.human;
  li.querySelector(".stream-raw").textContent = safeRaw;
  transcriptEl.appendChild(li);
  transcriptEl.scrollTop = transcriptEl.scrollHeight;
}

function classifyStreamLine(raw) {
  const text = raw.trim();

  if (/PostToolUse:.*hook error/i.test(text)) {
    return {
      kind: "hook-error",
      severity: "severity-error",
      label: "hook error",
      title: "Post-tool hook failed",
      human: "The tool may have finished, but its after-hook failed. Treat hook side effects as unverified until the hook log is checked.",
      fingerprint: "hook-error:posttooluse",
    };
  }

  if (/Async hook .* completed/i.test(text)) {
    return {
      kind: "hook-ok",
      severity: "severity-ok",
      label: "hook ok",
      title: "Async hook completed",
      human: "Background hook finished. No operator action unless paired with a preceding hook error.",
      fingerprint: "hook-ok:async",
    };
  }

  if (/(Thinking|Cogitated|Embellishing|Beaming|Flambéing)/i.test(text)) {
    return {
      kind: "model-state",
      severity: "severity-thinking",
      label: "model state",
      title: "Agent is reasoning",
      human: "Progress signal only. This is not proof that a file changed or a command passed.",
      fingerprint: `model-state:${text.replace(/\(.+\)/, "").toLowerCase()}`,
    };
  }

  if (/^(Read|Bash|Write|Edit|MultiEdit|Grep|Glob)\(/.test(text)) {
    return {
      kind: "tool-call",
      severity: "severity-info",
      label: "tool call",
      title: "Tool call observed",
      human: "Tool activity entered the stream. Verify command output or file diff before calling it complete.",
      fingerprint: `tool-call:${text.split("(")[0].toLowerCase()}`,
    };
  }

  return {
    kind: "stream-text",
    severity: "severity-info",
    label: "stream",
    title: "Stream text",
    human: "Unclassified stream line. Keep it visible, but do not treat it as success evidence by itself.",
    fingerprint: `stream:${text.slice(0, 48).toLowerCase()}`,
  };
}

function statusClass(status) {
  if (status === "PASS") return "status-pass";
  if (status === "BLOCK") return "status-block";
  return "status-flag";
}

function statusColor(status) {
  if (status === "PASS") return "var(--green)";
  if (status === "BLOCK") return "var(--rose)";
  return "var(--amber)";
}

function wireSetupAssistant() {
  setupAssistantToggle.addEventListener("click", () => {
    const isOpen = setupAssistant.dataset.open === "true";
    setSetupAssistantOpen(!isOpen);
  });

  promptPolishButton.addEventListener("click", () => {
    const raw = rawSetupPrompt.value.trim();
    polishedSetupPrompt.textContent = buildPolishedSetupPrompt(raw);
  });
}

async function checkOnboardingReadiness() {
  setSetupAssistantOpen(true);
  setupState.textContent = "checking";
  setupState.className = "";

  let fontReady = false;
  if ("fonts" in document) {
    try {
      await document.fonts.load("14px CommitMonoVox");
      fontReady = document.fonts.check("14px CommitMonoVox");
    } catch {
      fontReady = false;
    }
  }

  if (fontReady) {
    setupState.textContent = "ready";
    setupState.className = "ready";
    setupCopy.textContent = "CommitMono is loaded. Setup agent stays here for routing dull configuration work without crowding the terminal.";
    return;
  }

  setupState.textContent = "needs font";
  setupState.className = "flag";
  setupCopy.textContent = "CommitMono did not load. Use Get CommitMono, then keep this card open while the setup agent turns the install steps into a clean task.";
}

function setSetupAssistantOpen(isOpen) {
  setupAssistant.dataset.open = String(isOpen);
  setupAssistantToggle.setAttribute("aria-expanded", String(isOpen));
  setupAssistantBody.hidden = !isOpen;
}

async function handleSetupCommand(text) {
  const [, topic = "status"] = text.split(/\s+/);
  const route = setupWindows[topic] ?? setupWindows.dash;
  const routeLabel = route.startsWith("scripts/") ? "local setup script hidden" : route;
  const prompt = buildPolishedSetupPrompt(text);
  polishedSetupPrompt.textContent = prompt;
  setSetupAssistantOpen(true);
  addMessage("system", `Setup agent staged ${topic}. Correct target: ${routeLabel}`);

  if (topic === "xai" && bridgeState.connected) {
    await inspectXaiSetupViaBridge();
  }
}

async function inspectXaiSetupViaBridge() {
  try {
    const response = await fetch("/api/setup/xai/inspect", {
      method: "POST",
      cache: "no-store",
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.reason ?? "xAI setup inspect failed");
    }
    addMessage(
      "remote",
      [
        `xAI setup inspect via bridge: ${payload.verdict ?? "UNKNOWN"}`,
        `reason: ${payload.reason ?? "not provided"}`,
        `credential: ${payload.credential_file ?? "not selected"}`,
        `base_url_kind: ${payload.base_url_kind ?? "unknown"}`,
        "secret_values_recorded: false",
      ].join("\n"),
    );
  } catch (error) {
    addMessage("alert", `xAI setup inspect bridge failed: ${error.message}`);
  }
}

function handleSkillCommand(text) {
  const [command] = text.split(/\s+/);
  const skill = skillCommands.find((item) => item.command === command);
  if (!skill) {
    addMessage("alert", `Unknown skill command: ${command}. Available: ${skillCommands.map((item) => item.command).join(", ")}.`);
    return;
  }
  activeInstructionKind = "skills";
  renderInstructionTabs();
  renderInstructionList("skills", command);
  addMessage(
    "system",
    [
      `Skill instruction loaded: ${skill.command} — ${skill.label}`,
      skill.instruction,
      "Runtime note: this browser surface displays the contract only. The local agent runtime still owns tool execution and evidence.",
    ].join("\n"),
  );
}

function handleMcpCommand(text) {
  const [, rawId = ""] = text.split(/\s+/);
  activeInstructionKind = "mcp";
  renderInstructionTabs();
  renderInstructionList("mcp", rawId);

  if (!rawId) {
    const summary = mcpConnections
      .map((item) => `${item.status.padEnd(12)} ${item.command.padEnd(20)} ${item.label}`)
      .join("\n");
    addMessage("remote", `MCP connection contracts:\n${summary}`);
    return;
  }

  const id = rawId.startsWith("mcp:") ? rawId : `mcp:${rawId}`;
  const mcp = mcpConnections.find((item) => item.command === id);
  if (!mcp) {
    addMessage("alert", `Unknown MCP connection: ${rawId}. Try /mcp.`);
    return;
  }
  addMessage(
    "remote",
    [
      `${mcp.command} / ${mcp.status}`,
      mcp.instruction,
      "Policy: no secrets, OAuth material, stdio handles, or raw payloads are exposed to the browser.",
    ].join("\n"),
  );
}

function buildPolishedSetupPrompt(raw) {
  const source = raw || "Set up the missing Windburn operator prerequisites.";
  return [
    "SETUP_AGENT_TASK",
    `raw_request: ${source}`,
    "objective: finish the dull prerequisite without widening scope",
    "correct_window: docs.zonicdesign.art / CommitMono / local Windburn preview / local setup script",
    "steps: detect current state -> open exact target -> apply smallest change -> verify -> report PASS/FLAG/BLOCK",
    "guardrails: no secrets in browser, no remote mutation without explicit operator gate",
  ].join("\n");
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const value = input.value;
  input.value = "";
  delete input.dataset.provenance;
  resizeInput();
  hideCommandHints();
  hidePromptSuggestions();
  void dispatch(value);
});

function resizeInput() {
  input.style.height = "auto";
  input.style.height = `${Math.min(input.scrollHeight, 128)}px`;
}

function updateCommandHints() {
  const value = input.value.trimStart();
  let kind = "";
  let query = "";
  if (value.startsWith("/")) {
    kind = value.startsWith("/mcp") ? "mcp" : "slash";
    query = value.replace(/^\/mcp\s*/, "").replace(/^\//, "");
  } else if (value.startsWith("$")) {
    kind = "skills";
    query = value.slice(1);
  } else if (value.toLowerCase().startsWith("mcp")) {
    kind = "mcp";
    query = value.replace(/^mcp:?\s*/i, "");
  }

  if (!kind) {
    hideCommandHints();
    void refreshPromptSuggestions("input");
    return;
  }

  hidePromptSuggestions();
  const rows = getInstructionRows(kind, query).slice(0, 6);
  if (rows.length === 0) {
    hideCommandHints();
    return;
  }

  commandHints.hidden = false;
  commandHints.innerHTML = "";
  rows.forEach((item) => {
    const button = document.createElement("button");
    button.type = "button";
    button.role = "option";
    button.className = "hint-item";
    button.innerHTML = `
      <span class="hint-command"></span>
      <span class="hint-label"></span>
      <span class="hint-source"></span>
    `;
    button.querySelector(".hint-command").textContent = item.command;
    button.querySelector(".hint-label").textContent = item.label;
    button.querySelector(".hint-source").textContent =
      kind === "skills" ? "Skill" : kind === "mcp" ? "MCP" : "Template";
    button.addEventListener("click", () => {
      applyInstruction(item);
      hideCommandHints();
    });
    commandHints.appendChild(button);
  });
}

function hideCommandHints() {
  commandHints.hidden = true;
  commandHints.innerHTML = "";
}

input.addEventListener("input", () => {
  resizeInput();
  updateCommandHints();
});

input.addEventListener("focus", () => {
  void refreshPromptSuggestions("focus");
});

input.addEventListener("pointerdown", () => {
  void refreshPromptSuggestions("pointer");
});

input.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    hideCommandHints();
    hidePromptSuggestions();
    return;
  }
  if (event.key === "Tab" && !provenanceSuggestions.hidden && activePromptSuggestions[0]) {
    event.preventDefault();
    acceptPromptSuggestion(activePromptSuggestions[0]);
    return;
  }
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    form.requestSubmit();
  }
});

document.addEventListener("visibilitychange", () => {
  if (document.hidden) hidePromptSuggestions();
});

window.FusionChatStream = Object.freeze({
  addLine: addStreamLine,
  addLines(lines) {
    lines.forEach((line) => addStreamLine(line));
  },
  classify: classifyStreamLine,
});

boot();
