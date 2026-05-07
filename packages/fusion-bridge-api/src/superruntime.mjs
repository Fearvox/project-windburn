import { redact } from "./redaction.mjs";

export function safeString(value) {
  return redact(String(value)).slice(0, 240);
}

export function safeScalar(value) {
  if (value === null || typeof value === "boolean" || typeof value === "number") {
    return value;
  }
  if (typeof value === "string") {
    return safeString(value);
  }
  return null;
}

export function firstPresent(...values) {
  return values.find((value) => value !== undefined && value !== null);
}

export function asArray(value) {
  if (Array.isArray(value)) return value;
  if (value && typeof value === "object") return Object.values(value);
  return [];
}

function safeStringArray(value) {
  return asArray(value)
    .map((entry) => (typeof entry === "string" ? safeString(entry) : null))
    .filter(Boolean)
    .slice(0, 12);
}

function safeBoolean(value) {
  return value === true;
}

function safeCount(value, fallback) {
  const count = Number(firstPresent(value, fallback));
  return Number.isFinite(count) && count >= 0 ? count : fallback;
}

function safeHermesYoloStatus(value) {
  const status = safeString(firstPresent(value, "UNAVAILABLE")).toUpperCase();
  return ["PASS", "FLAG", "BLOCK"].includes(status) ? status : "UNAVAILABLE";
}

function safeTimerStatus(value) {
  const status = safeString(firstPresent(value, "unknown")).toLowerCase();
  return ["active", "inactive"].includes(status) ? status : "unknown";
}

function hermesYoloSource(evidence) {
  const yolo = evidence?.hermes_yolo;
  return yolo && typeof yolo === "object" && !Array.isArray(yolo) ? yolo : null;
}

function codexCliSource(evidence) {
  const cli = evidence?.codex_cli;
  return cli && typeof cli === "object" && !Array.isArray(cli) ? cli : null;
}

function codexTuiSource(evidence) {
  const tui = evidence?.codex_tui;
  return tui && typeof tui === "object" && !Array.isArray(tui) ? tui : null;
}

function buildHermesYoloStatus(evidence, generatedAt) {
  const yolo = hermesYoloSource(evidence);
  const status = safeHermesYoloStatus(firstPresent(yolo?.status, yolo?.verdict));
  const paneAlive = safeBoolean(firstPresent(yolo?.pane_alive, yolo?.lane?.pane_alive));
  const processCount = safeCount(firstPresent(
    yolo?.process_count,
    yolo?.yolo_process_count,
    yolo?.lane?.process_count,
    yolo?.lane?.yolo_process_count,
  ), 0);
  const timerStatus = safeTimerStatus(firstPresent(
    yolo?.timer_status,
    yolo?.timer?.status,
    yolo?.timer_active === true ? "active" : null,
    yolo?.timer_active === false ? "inactive" : null,
  ));
  const operatorSurface = status === "UNAVAILABLE"
    ? "unavailable"
    : yolo?.operator_surface === "tmux" || paneAlive || processCount > 0
      ? "tmux"
      : "unavailable";
  const updatedAt = safeScalar(firstPresent(
    yolo?.updated_at,
    yolo?.generated_at_utc,
    evidence?.generated_at_utc,
    evidence?.generatedAt,
    generatedAt,
  ));

  return {
    status,
    pane_alive: paneAlive,
    process_count: processCount,
    timer_status: timerStatus,
    operator_surface: operatorSurface,
    command: "redacted",
    command_redacted: true,
    updated_at: updatedAt,
    receipt: yolo ? "runner-evidence:hermes_yolo" : "runner-evidence:hermes_yolo:unavailable",
    stream: {
      status: "stubbed",
      redacted: true,
      bounded: true,
      reason: "raw_pane_content_not_exposed",
    },
  };
}

function buildCodexCliStatus(evidence) {
  const cli = codexCliSource(evidence);
  const status = safeHermesYoloStatus(firstPresent(cli?.status, cli?.verdict));
  return {
    status,
    command_present: safeBoolean(firstPresent(cli?.codex_command_present, cli?.command_present)),
    version_status: safeScalar(firstPresent(cli?.version_status, cli?.version_probe?.status, "unknown")),
    command: "redacted",
    command_redacted: true,
    receipt: cli ? "runner-evidence:codex_cli" : "runner-evidence:codex_cli:unavailable",
  };
}

function buildCodexTuiStatus(evidence, generatedAt) {
  const tui = codexTuiSource(evidence);
  const status = safeHermesYoloStatus(firstPresent(tui?.status, tui?.verdict));
  const paneAlive = safeBoolean(firstPresent(tui?.pane_alive, tui?.lane?.pane_alive));
  const processCount = safeCount(firstPresent(
    tui?.process_count,
    tui?.codex_process_count,
    tui?.lane?.process_count,
    tui?.lane?.codex_process_count,
  ), 0);
  const operatorSurface = status === "UNAVAILABLE"
    ? "unavailable"
    : paneAlive || processCount > 0
      ? "tmux"
      : "unavailable";
  const updatedAt = safeScalar(firstPresent(
    tui?.updated_at,
    tui?.generated_at_utc,
    evidence?.generated_at_utc,
    evidence?.generatedAt,
    generatedAt,
  ));

  return {
    status,
    pane_alive: paneAlive,
    process_count: processCount,
    operator_surface: operatorSurface,
    command: "redacted",
    command_redacted: true,
    updated_at: updatedAt,
    receipt: tui ? "runner-evidence:codex_tui" : "runner-evidence:codex_tui:unavailable",
    stream: {
      status: "stubbed",
      redacted: true,
      bounded: true,
      reason: "raw_codex_pane_content_not_exposed",
    },
  };
}

function statusLevel(status) {
  if (status === "PASS") return "pass";
  if (status === "BLOCK") return "block";
  return "flag";
}

function safeRuntime(runtime, index) {
  if (!runtime || typeof runtime !== "object") {
    return {
      id: `runtime-${index + 1}`,
      status: "unknown",
    };
  }

  return {
    id: safeString(firstPresent(runtime.id, runtime.runtime_id, `runtime-${index + 1}`)),
    name: safeScalar(firstPresent(runtime.name, runtime.label, runtime.display_name)),
    kind: safeScalar(firstPresent(runtime.kind, runtime.type, runtime.runtime_type, runtime.runtime_kind)),
    status: safeScalar(firstPresent(runtime.status, runtime.state, runtime.health)),
    lease_state: safeScalar(firstPresent(runtime.lease_state, runtime.leaseStatus)),
    dispatch_state: safeScalar(firstPresent(runtime.dispatch_state, runtime.dispatchState)),
    mutation_policy: safeScalar(runtime.mutation_policy),
    heartbeat_at: safeScalar(runtime.heartbeat_at),
    stream_safe: safeScalar(runtime.stream_safe),
    capabilities: safeStringArray(runtime.capabilities),
  };
}

function safeTask(task, index, latestStatusByTask) {
  if (!task || typeof task !== "object") {
    return {
      id: `task-${index + 1}`,
      status: "unknown",
    };
  }

  const taskId = firstPresent(task.id, task.task_id, `task-${index + 1}`);
  const latestStatus = latestStatusByTask.get(String(taskId));

  return {
    id: safeString(taskId),
    intent_id: safeScalar(task.intent_id),
    title: safeScalar(firstPresent(task.title, task.name, task.summary, task.task_prompt)),
    status: safeScalar(firstPresent(task.status, task.state, latestStatus?.phase, "unknown")),
    level: safeScalar(latestStatus?.level),
    queue: safeScalar(firstPresent(task.queue, task.lane)),
    runtime_id: safeScalar(firstPresent(task.runtime_id, task.runtimeId)),
    requested_harness: safeScalar(task.requested_harness),
    created_at: safeScalar(firstPresent(task.created_at, task.createdAt)),
    updated_at: safeScalar(firstPresent(task.updated_at, task.updatedAt)),
  };
}

function safeLease(lease) {
  if (!lease || typeof lease !== "object") return null;
  return {
    id: safeScalar(firstPresent(lease.id, lease.lease_id)),
    runtime_id: safeScalar(firstPresent(lease.runtime_id, lease.runtimeId)),
    task_id: safeScalar(firstPresent(lease.task_id, lease.taskId)),
    status: safeScalar(firstPresent(
      lease.status,
      lease.state,
      firstPresent(lease.lease_id, lease.leaseId) ? "leased" : null,
    )),
    holder: safeScalar(firstPresent(lease.holder, lease.owner, lease.worker)),
    acquired_at: safeScalar(firstPresent(lease.acquired_at, lease.acquiredAt)),
    expires_at: safeScalar(firstPresent(lease.expires_at, lease.expiresAt)),
  };
}

function safeStatusEvent(event, index) {
  if (!event || typeof event !== "object") {
    return {
      id: `event-${index + 1}`,
      status: "unknown",
    };
  }

  return {
    id: safeString(firstPresent(event.id, event.event_id, `event-${index + 1}`)),
    type: safeScalar(firstPresent(event.type, event.kind, event.phase)),
    status: safeScalar(firstPresent(event.status, event.state, event.phase)),
    level: safeScalar(event.level),
    runtime_id: safeScalar(firstPresent(event.runtime_id, event.runtimeId)),
    task_id: safeScalar(firstPresent(event.task_id, event.taskId)),
    message: safeScalar(firstPresent(event.message, event.summary)),
    at: safeScalar(firstPresent(event.at, event.created_at, event.timestamp, event.emitted_at)),
  };
}

function isQueuedTask(task) {
  const status = String(firstPresent(task?.status, task?.state, "")).toLowerCase();
  return ["queued", "pending", "waiting", "ready"].includes(status);
}

function latestStatusEventsByTask(events) {
  const byTask = new Map();
  events.forEach((event, index) => {
    const taskId = firstPresent(event?.task_id, event?.taskId);
    if (!taskId) return;
    byTask.set(String(taskId), {
      phase: firstPresent(event.phase, event.status, event.state),
      level: event.level,
      index,
    });
  });
  return byTask;
}

export function buildEmptySuperruntimePayload(reason = "fixture_absent", options = {}) {
  return {
    schema_version: 1,
    generated_at_utc: options.generatedAt ?? new Date().toISOString(),
    mode: "read-only",
    source: reason,
    redacted_public_safe: true,
    registered_runtime_count: 0,
    queued_task_count: 0,
    current_lease: null,
    harness_dispatch_state: "unknown",
    runtimes: [],
    tasks: [],
    status_events: [],
    secret_values_recorded: false,
  };
}

export function inspectRunnerEvidenceSafety(evidence) {
  if (!evidence || typeof evidence !== "object" || Array.isArray(evidence)) {
    return {
      safe: false,
      reasons: ["invalid_shape"],
      checks: {
        invalid_shape: true,
        secret_values_recorded: false,
        redacted_public_safe: false,
        remote_mutation: false,
      },
    };
  }

  const checks = {
    invalid_shape: false,
    secret_values_recorded: safeBoolean(evidence.secret_values_recorded),
    redacted_public_safe: evidence.redacted_public_safe === true,
    remote_mutation: safeBoolean(evidence.remote_mutation),
    hermes_yolo_command_redacted: hermesYoloSource(evidence)?.command_redacted !== false,
    codex_tui_command_redacted: codexTuiSource(evidence)?.command_redacted !== false,
  };
  const reasons = [];

  if (checks.secret_values_recorded) reasons.push("secret_values_recorded_true");
  if (!checks.redacted_public_safe) reasons.push("redacted_public_safe_not_true");
  if (checks.remote_mutation) reasons.push("remote_mutation_true");
  if (!checks.hermes_yolo_command_redacted) reasons.push("hermes_yolo_command_not_redacted");
  if (!checks.codex_tui_command_redacted) reasons.push("codex_tui_command_not_redacted");

  return {
    safe: reasons.length === 0,
    reasons,
    checks,
  };
}

export function buildRunnerEvidenceSuperruntimePayload(evidence, options = {}) {
  if (!evidence || typeof evidence !== "object" || Array.isArray(evidence)) {
    return buildEmptySuperruntimePayload("runner_evidence_invalid_shape", options);
  }

  const status = safeString(firstPresent(evidence.status, "FLAG")).toUpperCase();
  const runnerId = safeString(firstPresent(
    evidence.runner_id,
    evidence.id,
    "windburn-workhorse-runner-status-v0",
  ));
  const reason = safeString(firstPresent(evidence.reason, status === "PASS" ? "runner_ready" : "runner_not_ready"));
  const tmux = evidence.tmux && typeof evidence.tmux === "object" ? evidence.tmux : {};
  const credentials = evidence.credentials && typeof evidence.credentials === "object" ? evidence.credentials : {};
  const latestSmoke = evidence.latest_hermes_codex_smoke && typeof evidence.latest_hermes_codex_smoke === "object"
    ? evidence.latest_hermes_codex_smoke
    : {};
  const tmuxSessionPresent = safeBoolean(tmux.session_present);
  const latestSmokeVerdict = safeString(firstPresent(latestSmoke.verdict, "UNKNOWN")).toUpperCase();
  const latestSmokeReason = safeString(firstPresent(latestSmoke.reason, latestSmokeVerdict));
  const harnessDispatchState = latestSmokeVerdict === "PASS"
    ? "codex-provider-ok"
    : latestSmokeVerdict === "UNKNOWN"
      ? "provider-smoke-unknown"
      : `provider-smoke-${latestSmokeVerdict.toLowerCase()}`;
  const leaseStatus = status === "PASS" && tmuxSessionPresent
    ? "runner-ready"
    : status === "BLOCK"
      ? "runner-blocked"
      : "runner-flagged";
  const generatedAt = safeScalar(firstPresent(evidence.generated_at_utc, evidence.generatedAt));
  const hermesYolo = buildHermesYoloStatus(evidence, generatedAt);
  const codexCli = buildCodexCliStatus(evidence);
  const codexTui = buildCodexTuiStatus(evidence, generatedAt);

  return {
    schema_version: 1,
    generated_at_utc: options.generatedAt ?? new Date().toISOString(),
    mode: "read-only",
    source: options.source ?? "runner-evidence",
    redacted_public_safe: true,
    registered_runtime_count: 1,
    queued_task_count: 0,
    current_lease: {
      id: null,
      runtime_id: "windburn-workhorse-runner",
      task_id: null,
      status: leaseStatus,
      holder: null,
      acquired_at: generatedAt,
      expires_at: null,
    },
    harness_dispatch_state: harnessDispatchState,
    runtimes: [{
      id: "windburn-workhorse-runner",
      name: "NixOS Workhorse",
      kind: safeScalar(firstPresent(evidence.runner_kind, "read-only-evidence")),
      status,
      lease_state: leaseStatus,
      dispatch_state: harnessDispatchState,
      mutation_policy: "read-only",
      heartbeat_at: generatedAt,
      stream_safe: true,
      capabilities: [
        "read-only-evidence",
        tmuxSessionPresent ? "tmux-observed" : "tmux-not-observed",
        safeBoolean(credentials.codex_auth_present) ? "codex-auth-present" : "codex-auth-missing",
        codexCli.command_present ? "codex-cli-present" : "codex-cli-missing",
        codexTui.status === "PASS" ? "codex-tmux-lane-ready" : "codex-tmux-lane-not-ready",
        safeBoolean(credentials.hermes_auth_present) ? "hermes-auth-present" : "hermes-auth-missing",
        hermesYolo.status === "UNAVAILABLE" ? "hermes-yolo-unavailable" : "hermes-yolo-status",
      ],
    }],
    tasks: [],
    status_events: [
      {
        id: "runner-evidence-current",
        type: "runner-evidence",
        status,
        level: statusLevel(status),
        runtime_id: "windburn-workhorse-runner",
        task_id: null,
        message: reason,
        at: generatedAt,
      },
      {
        id: "runner-evidence-hermes-yolo",
        type: "hermes-yolo-status",
        status: hermesYolo.status,
        level: statusLevel(hermesYolo.status),
        runtime_id: "windburn-workhorse-runner",
        task_id: null,
        message: hermesYolo.status === "UNAVAILABLE"
          ? "hermes_yolo unavailable"
          : `hermes_yolo ${hermesYolo.status.toLowerCase()}`,
        at: hermesYolo.updated_at,
      },
      {
        id: "runner-evidence-codex-tui",
        type: "codex-tui-status",
        status: codexTui.status,
        level: statusLevel(codexTui.status),
        runtime_id: "windburn-workhorse-runner",
        task_id: null,
        message: codexTui.status === "UNAVAILABLE"
          ? "codex_tui unavailable"
          : `codex_tui ${codexTui.status.toLowerCase()}`,
        at: codexTui.updated_at,
      },
    ],
    codex_cli: codexCli,
    codex_tui: codexTui,
    hermes_yolo: hermesYolo,
    runner_evidence: {
      runner_id: runnerId,
      runner_kind: safeScalar(firstPresent(evidence.runner_kind, "read-only-evidence")),
      status,
      reason,
      system_state: safeScalar(evidence.system_state),
      failed_units: safeCount(evidence.failed_units, 0),
      tmux_session_present: tmuxSessionPresent,
      tmux_session_count: safeCount(tmux.session_count, 0),
      codex_auth_present: safeBoolean(credentials.codex_auth_present),
      codex_cli_present: codexCli.command_present,
      codex_tui_status: codexTui.status,
      hermes_auth_present: safeBoolean(credentials.hermes_auth_present),
      provider_env_present: safeBoolean(credentials.provider_env_present),
      latest_hermes_codex_smoke_verdict: latestSmokeVerdict,
      latest_hermes_codex_smoke_reason: latestSmokeReason,
      remote_mutation: safeBoolean(evidence.remote_mutation),
      generated_at_utc: generatedAt,
    },
    secret_values_recorded: false,
  };
}

export function buildSuperruntimePayload(fixture, options = {}) {
  if (!fixture || typeof fixture !== "object" || Array.isArray(fixture)) {
    return buildEmptySuperruntimePayload("fixture_invalid_shape", options);
  }

  const rawRuntimes = asArray(firstPresent(
    fixture.runtimes,
    fixture.runtime_registrations,
    fixture.registered_runtimes,
    fixture.registeredRuntimes,
  ));
  const rawTasks = asArray(firstPresent(
    fixture.tasks,
    fixture.task_envelopes,
    fixture.task_queue,
    fixture.queue,
  ));
  const rawDispatches = asArray(firstPresent(
    fixture.harness_dispatches,
    fixture.harnessDispatches,
    fixture.dispatches,
  ));
  const rawEvents = asArray(firstPresent(
    fixture.status_events,
    fixture.statusEvents,
    fixture.events,
  ));
  const harness = fixture.harness && typeof fixture.harness === "object" ? fixture.harness : {};
  const latestStatusByTask = latestStatusEventsByTask(rawEvents);
  const currentLease = firstPresent(
    fixture.current_lease,
    fixture.currentLease,
    fixture.lease,
    harness.current_lease,
    harness.currentLease,
    rawTasks.find((task) => task?.lease_id || task?.leaseId),
  );
  const queuedTaskCount = rawTasks.filter((task) => {
    const taskId = firstPresent(task?.id, task?.task_id);
    const latestStatus = taskId ? latestStatusByTask.get(String(taskId)) : null;
    return isQueuedTask({ ...task, status: firstPresent(task?.status, task?.state, latestStatus?.phase) });
  }).length;

  return {
    schema_version: 1,
    generated_at_utc: options.generatedAt ?? new Date().toISOString(),
    mode: "read-only",
    source: options.source ?? "superruntime-fixture",
    redacted_public_safe: true,
    registered_runtime_count: safeCount(firstPresent(
      fixture.registered_runtime_count,
      fixture.registeredRuntimeCount,
    ), rawRuntimes.length),
    queued_task_count: safeCount(firstPresent(
      fixture.queued_task_count,
      fixture.queuedTaskCount,
    ), queuedTaskCount),
    current_lease: safeLease(currentLease),
    harness_dispatch_state: safeScalar(firstPresent(
      fixture.harness_dispatch_state,
      fixture.harnessDispatchState,
      harness.dispatch_state,
      harness.dispatchState,
      rawDispatches.length > 0 ? `dispatches_recorded:${rawDispatches.length}` : null,
      "unknown",
    )),
    runtimes: rawRuntimes.map(safeRuntime),
    tasks: rawTasks.map((task, index) => safeTask(task, index, latestStatusByTask)),
    status_events: rawEvents.map(safeStatusEvent),
    secret_values_recorded: false,
  };
}
