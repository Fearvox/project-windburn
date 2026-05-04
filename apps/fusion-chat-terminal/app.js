const fallbackRemotes = [
  {
    id: "hermes",
    name: "Hermes Yolo",
    host: "remote tmux lane",
    kind: "tmux",
    status: "PASS",
    latency: "tmux live",
    transport: "operator-gated ssh -> tmux windburn-hermes-runtime:hermes-yolo",
    command: "scripts/hermes-yolo-loop.sh --out docs/remote-workhorse/preflight/HERMES_YOLO_LOOP_PROOF.md",
    taste: "primary high-context chat lane",
  },
  {
    id: "workhorse",
    name: "NixOS Workhorse",
    host: "remote build lane",
    kind: "nixos",
    status: "FLAG",
    latency: "foundation",
    transport: "operator-gated ssh -> scripts/nixos-remote-rebuild.sh",
    command: "scripts/nixos-remote-rebuild.sh",
    taste: "remote build and runner cell",
  },
  {
    id: "ccr",
    name: "CCR Embed",
    host: "internal embedding lane",
    kind: "internal",
    status: "FLAG",
    latency: "tailnet ok",
    transport: "operator-gated internal embedding route",
    command: "scripts/droplet-engagement-review.sh",
    taste: "embedding and review substrate",
  },
  {
    id: "codex",
    name: "Local Codex",
    host: "local worktree",
    kind: "local",
    status: "PASS",
    latency: "local",
    transport: "workspace shell -> scripts/check.sh",
    command: "scripts/superconductor-codex-intake.sh && scripts/check.sh",
    taste: "operator control plane",
  },
  {
    id: "superconductor",
    name: "Superconductor",
    host: "linked workspace",
    kind: "shell",
    status: "PASS",
    latency: "linked",
    transport: "linked repo anchor",
    command: "scripts/superconductor-codex-intake.sh",
    taste: "multi-workspace dispatch surface",
  },
  {
    id: "propfirm",
    name: "Propfirm ATA",
    host: "localhost panel",
    kind: "local-tab",
    status: "FLAG",
    latency: "panel optional",
    transport: "iframe -> local read-only propfirm panel",
    command: "python3 -m propfirm_engine.fusion_stack",
    taste: "TradingView alerts, discipline feed, no-trade display lane",
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

const bridgeState = {
  connected: false,
  mode: "local mock",
  status: null,
};

const propfirmPanel = {
  url: new URLSearchParams(window.location.search).get("propfirmUrl") || "http://127.0.0.1:5556/fusion-panel",
  loaded: false,
};

let activeSurface = "chat";

const actions = [
  ["/status", "Status"],
  ["/route hermes", "Hermes"],
  ["/route workhorse", "NixOS"],
  ["/propfirm", "Propfirm"],
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
    command: "/propfirm",
    label: "Propfirm alert tab",
    instruction: "Open the local read-only Propfirm ATA panel iframe. Start FinceptTerminal fusion_stack first.",
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
const matrixDisplay = document.querySelector("#matrixDisplay");
const surfaceTabs = document.querySelector("#surfaceTabs");
const propfirmSurface = document.querySelector("#propfirmSurface");
const propfirmFrame = document.querySelector("#propfirmFrame");
const propfirmUrl = document.querySelector("#propfirmUrl");
const propfirmOpenLink = document.querySelector("#propfirmOpenLink");
const form = document.querySelector("#chatForm");
const input = document.querySelector("#promptInput");
const commandHints = document.querySelector("#commandHints");
const poolCapacity = document.querySelector("#poolCapacity");
const poolMeter = document.querySelector("#poolMeter");
const poolActive = document.querySelector("#poolActive");
const globalStats = document.querySelector("#globalStats");
const runLedger = document.querySelector("#runLedger");
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

const setupWindows = {
  font: "https://commitmono.com/",
  dash: "https://docs.zonicdesign.art/pages/getting-started.html",
  agentPipeline: "https://docs.zonicdesign.art/pages/guides/agent-pipeline.html",
  configuration: "https://docs.zonicdesign.art/pages/reference/config.html",
  xai: "scripts/xai-setup-agent.sh --call --confirm-xai-setup-agent",
};

function boot() {
  setBridgeLabels();
  renderRoutes();
  renderQuickActions();
  renderSurfaceTabs();
  renderInstructionTabs();
  renderInstructionList("slash");
  renderPreflight();
  renderOperationalSummary();
  renderRunLedger();
  wireSetupAssistant();
  checkOnboardingReadiness();
  selectRemote("hermes");
  addMessage("system", "Fusion router online. Active lane: Hermes yolo. No secrets are loaded in this browser surface.");
  addMessage("remote", "Jcode direction imported: multi-session harness, side panels, swarm-minded route control. Windburn ownership layer active.");
  addMessage("alert", "Remaining global flags are intentionally visible: DO observability, CCR public route, and workhorse runner engagement.");
  void hydrateBridgeState();
}

function setBridgeLabels() {
  modeLabel.textContent = bridgeState.connected ? "read-only" : "read-only";
  bridgeLabel.textContent = bridgeState.connected ? "live bridge" : "local mock";
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
      ? remotesPayload.remotes
      : remotes;
    preflight = Array.isArray(preflightPayload.preflight) && preflightPayload.preflight.length
      ? preflightPayload.preflight
      : preflight;

    setBridgeLabels();
    renderRoutes();
    renderPreflight();
    renderOperationalSummary();
    renderRunLedger();
    selectRemote(activeRemote.id);

    const repo = statusPayload.repo ?? {};
    addMessage(
      "system",
      `Fusion Bridge v0 connected. Read-only API: ${repo.branch ?? "unknown"} @ ${repo.head ?? "unknown"}; dirty=${String(repo.dirty ?? "unknown")}.`,
    );
  } catch {
    bridgeState.connected = false;
    bridgeState.status = null;
    setBridgeLabels();
    addMessage("system", "Bridge API unavailable; static fallback remains active. Use scripts/fusion-chat-bridge.sh for live read-only state.");
  }
}

function renderSurfaceTabs() {
  surfaceTabs.innerHTML = "";
  [
    ["chat", "Fusion Chat"],
    ["propfirm", "Propfirm ATA"],
  ].forEach(([kind, label]) => {
    const button = document.createElement("button");
    button.type = "button";
    button.role = "tab";
    button.textContent = label;
    button.setAttribute("aria-selected", String(kind === activeSurface));
    button.addEventListener("click", () => setActiveSurface(kind));
    surfaceTabs.appendChild(button);
  });
}

function setActiveSurface(kind) {
  activeSurface = kind === "propfirm" ? "propfirm" : "chat";
  renderSurfaceTabs();
  const showPropfirm = activeSurface === "propfirm";
  matrixDisplay.hidden = showPropfirm;
  form.hidden = showPropfirm;
  propfirmSurface.hidden = !showPropfirm;
  if (showPropfirm) {
    if (!propfirmPanel.loaded) {
      propfirmFrame.src = propfirmPanel.url;
      propfirmPanel.loaded = true;
    }
    propfirmUrl.textContent = propfirmPanel.url;
    propfirmOpenLink.href = propfirmPanel.url;
  }
}

function openPropfirmSurface() {
  const next = remotes.find((remote) => remote.id === "propfirm");
  if (next) selectRemote(next.id);
  setActiveSurface("propfirm");
  addMessage("system", "Propfirm ATA tab opened. Start FinceptTerminal fusion_stack if the iframe is empty; browser remains display-only.");
}

function renderRoutes() {
  routeList.innerHTML = "";
  remotes.forEach((remote) => {
    const button = document.createElement("button");
    button.className = "route-button";
    button.type = "button";
    button.dataset.route = remote.id;
    button.innerHTML = `
      <span class="route-dot" style="color: ${statusColor(remote.status)}"></span>
      <span>
        <span class="route-name">${remote.name}</span>
        <span class="route-host">${remote.host}</span>
      </span>
      <span class="route-kind">${remote.kind}</span>
    `;
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
  if (activeRemote.id === "propfirm") {
    setActiveSurface("propfirm");
  } else if (activeSurface === "propfirm") {
    setActiveSurface("chat");
  }
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
    row.innerHTML = `<dt>${key}</dt><dd>${value}</dd>`;
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
      addMessage("system", `Route switched to ${next.name}. Transport: ${next.transport}.`);
    } else {
      addMessage("alert", `Unknown route: ${id}. Available: ${remotes.map((remote) => remote.id).join(", ")}.`);
    }
    return;
  }

  if (text === "/propfirm") {
    openPropfirmSurface();
    return;
  }

  if (text === "/status") {
    const lines = remotes.map((remote) => `${remote.status.padEnd(5)} ${remote.id.padEnd(14)} ${remote.latency}`);
    const repo = bridgeState.status?.repo;
    const bridgeLine = bridgeState.connected
      ? `BRIDGE read-only-live ${repo?.branch ?? "unknown"}@${repo?.head ?? "unknown"} dirty=${String(repo?.dirty ?? "unknown")}`
      : "BRIDGE local-mock static fallback";
    addMessage("remote", [bridgeLine, ...lines].join("\n"));
    return;
  }

  if (text === "/attach tmux") {
    addMessage("remote", "Next backend bridge target: operator-gated tmux attach for windburn-hermes-runtime; exact SSH endpoint stays outside the browser surface.");
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

  transcript.push({ role, body });
  const li = document.createElement("li");
  li.className = `message ${role}`;
  li.innerHTML = `<span class="message-role">${role}</span><span class="message-body"></span>`;
  li.querySelector(".message-body").textContent = body;
  transcriptEl.appendChild(li);
  transcriptEl.scrollTop = transcriptEl.scrollHeight;
}

function addStreamLine(raw) {
  const event = classifyStreamLine(raw);
  const previous = transcript[transcript.length - 1];
  const previousEl = transcriptEl.lastElementChild;

  if (
    previous?.role === "stream" &&
    previous.fingerprint === event.fingerprint &&
    previousEl?.dataset.fingerprint === event.fingerprint
  ) {
    previous.count += 1;
    previous.body = raw;
    previousEl.querySelector(".stream-count").textContent = `×${previous.count}`;
    previousEl.querySelector(".stream-raw").textContent = raw;
    transcriptEl.scrollTop = transcriptEl.scrollHeight;
    return;
  }

  transcript.push({
    role: "stream",
    body: raw,
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
  li.querySelector(".stream-raw").textContent = raw;
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
  const prompt = buildPolishedSetupPrompt(text);
  polishedSetupPrompt.textContent = prompt;
  setSetupAssistantOpen(true);
  addMessage("system", `Setup agent staged ${topic}. Correct target: ${route}`);

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
    "correct_window: docs.zonicdesign.art / CommitMono / local Windburn preview / scripts/xai-setup-agent.sh",
    "steps: detect current state -> open exact target -> apply smallest change -> verify -> report PASS/FLAG/BLOCK",
    "guardrails: no secrets in browser, no remote mutation without explicit operator gate",
  ].join("\n");
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const value = input.value;
  input.value = "";
  resizeInput();
  hideCommandHints();
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
    return;
  }

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
    `;
    button.querySelector(".hint-command").textContent = item.command;
    button.querySelector(".hint-label").textContent = item.label;
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

input.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    hideCommandHints();
    return;
  }
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    form.requestSubmit();
  }
});

window.FusionChatStream = Object.freeze({
  addLine: addStreamLine,
  addLines(lines) {
    lines.forEach((line) => addStreamLine(line));
  },
  classify: classifyStreamLine,
});

boot();
