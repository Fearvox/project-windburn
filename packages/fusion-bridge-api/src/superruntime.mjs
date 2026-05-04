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

function safeCount(value, fallback) {
  const count = Number(firstPresent(value, fallback));
  return Number.isFinite(count) && count >= 0 ? count : fallback;
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
