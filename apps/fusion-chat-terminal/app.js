const remotes = [
  {
    id: "hermes",
    name: "Hermes Yolo",
    host: "137.184.104.26",
    kind: "tmux",
    status: "PASS",
    latency: "tmux live",
    transport: "ssh -> tmux windburn-hermes-runtime:hermes-yolo",
    command: "scripts/hermes-yolo-loop.sh --out docs/remote-workhorse/preflight/HERMES_YOLO_LOOP_PROOF.md",
    taste: "primary high-context chat lane",
  },
  {
    id: "workhorse",
    name: "NixOS Workhorse",
    host: "24.144.113.25",
    kind: "nixos",
    status: "FLAG",
    latency: "foundation",
    transport: "ssh -> scripts/nixos-remote-rebuild.sh",
    command: "scripts/nixos-remote-rebuild.sh",
    taste: "remote build and runner cell",
  },
  {
    id: "ccr",
    name: "CCR Embed",
    host: "165.232.146.188",
    kind: "internal",
    status: "FLAG",
    latency: "tailnet ok",
    transport: "ssh -> 100.65.234.77:8080/v1",
    command: "scripts/droplet-engagement-review.sh",
    taste: "embedding and review substrate",
  },
  {
    id: "codex",
    name: "Local Codex",
    host: "/Users/0xvox/Windburn",
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
    host: "/Users/0xvox/superconductor/projects/Windburn",
    kind: "shell",
    status: "PASS",
    latency: "linked",
    transport: "linked repo anchor",
    command: "scripts/superconductor-codex-intake.sh",
    taste: "multi-workspace dispatch surface",
  },
];

const preflight = [
  { label: "Hermes yolo tmux loop", status: "pass" },
  { label: "Hermes health gate", status: "pass" },
  { label: "DO uptime and alerts", status: "flag" },
  { label: "Windburn workhorse runner", status: "flag" },
  { label: "CCR public route", status: "flag" },
];

const actions = [
  ["/status", "Status"],
  ["/route hermes", "Hermes"],
  ["/route workhorse", "NixOS"],
  ["/broadcast preflight", "Broadcast"],
  ["/attach tmux", "Attach"],
  ["/explain flags", "Flags"],
];

let activeRemote = remotes[0];
const transcript = [];

const routeList = document.querySelector("#routeList");
const activeTitle = document.querySelector("#activeTitle");
const activeStatus = document.querySelector("#activeStatus");
const activeLatency = document.querySelector("#activeLatency");
const contractBadge = document.querySelector("#contractBadge");
const routeFacts = document.querySelector("#routeFacts");
const quickActions = document.querySelector("#quickActions");
const preflightList = document.querySelector("#preflightList");
const transcriptEl = document.querySelector("#transcript");
const form = document.querySelector("#chatForm");
const input = document.querySelector("#promptInput");
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

const setupWindows = {
  font: "https://commitmono.com/",
  dash: "https://docs.zonicdesign.art/pages/getting-started.html",
  agentPipeline: "https://docs.zonicdesign.art/pages/guides/agent-pipeline.html",
  configuration: "https://docs.zonicdesign.art/pages/reference/config.html",
};

function boot() {
  renderRoutes();
  renderQuickActions();
  renderPreflight();
  renderOperationalSummary();
  renderRunLedger();
  wireSetupAssistant();
  checkOnboardingReadiness();
  selectRemote("hermes");
  addMessage("system", "Fusion router online. Active lane: Hermes yolo. No secrets are loaded in this browser surface.");
  addMessage("remote", "Jcode direction imported: multi-session harness, side panels, swarm-minded route control. Windburn ownership layer active.");
  addMessage("alert", "Remaining global flags are intentionally visible: DO observability, CCR public route, and workhorse runner engagement.");
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
    row.innerHTML = `<dt>${key}</dt><dd>${value}</dd>`;
    routeFacts.appendChild(row);
  });
}

function runCommand(command) {
  input.value = command;
  resizeInput();
  dispatch(command);
  input.value = "";
  resizeInput();
}

function dispatch(raw) {
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

  if (text === "/status") {
    const lines = remotes.map((remote) => `${remote.status.padEnd(5)} ${remote.id.padEnd(14)} ${remote.latency}`);
    addMessage("remote", lines.join("\n"));
    return;
  }

  if (text === "/attach tmux") {
    addMessage("remote", "Next backend bridge target: ssh root@137.184.104.26 -t 'tmux attach -t windburn-hermes-runtime'.");
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

  if (text.startsWith("/setup")) {
    handleSetupCommand(text);
    return;
  }

  addMessage("remote", `${activeRemote.name} queued: ${text}\nBridge mode is local mock until the signed SSH/websocket adapter is enabled.`);
}

function addMessage(role, body) {
  transcript.push({ role, body });
  const li = document.createElement("li");
  li.className = `message ${role}`;
  li.innerHTML = `<span class="message-role">${role}</span><span class="message-body"></span>`;
  li.querySelector(".message-body").textContent = body;
  transcriptEl.appendChild(li);
  transcriptEl.scrollTop = transcriptEl.scrollHeight;
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

function handleSetupCommand(text) {
  const [, topic = "status"] = text.split(/\s+/);
  const route = setupWindows[topic] ?? setupWindows.dash;
  const prompt = buildPolishedSetupPrompt(text);
  polishedSetupPrompt.textContent = prompt;
  setSetupAssistantOpen(true);
  addMessage("system", `Setup agent staged ${topic}. Correct window: ${route}`);
}

function buildPolishedSetupPrompt(raw) {
  const source = raw || "Set up the missing Windburn operator prerequisites.";
  return [
    "SETUP_AGENT_TASK",
    `raw_request: ${source}`,
    "objective: finish the dull prerequisite without widening scope",
    "correct_window: docs.zonicdesign.art / CommitMono / local Windburn preview",
    "steps: detect current state -> open exact target -> apply smallest change -> verify -> report PASS/FLAG/BLOCK",
    "guardrails: no secrets in browser, no remote mutation without explicit operator gate",
  ].join("\n");
}

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const value = input.value;
  input.value = "";
  resizeInput();
  dispatch(value);
});

function resizeInput() {
  input.style.height = "auto";
  input.style.height = `${Math.min(input.scrollHeight, 128)}px`;
}

input.addEventListener("input", resizeInput);

input.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    form.requestSubmit();
  }
});

boot();
