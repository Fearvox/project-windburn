# Hermes Yolo Loop Proof

Generated: `2026-05-04T04:27:25Z`

Target: `137.184.104.26`

Fixed tmux session: `windburn-hermes-runtime`

Yolo window: `hermes-yolo`

Mode: ensure=`1`, restart=`1`, smoke=`1`

VERDICT: `PASS`

## Flags

- none

## Evidence

```text
host=hermes-nyc1
generated_at_utc=2026-05-04T04:27:29Z
ensure=1
restart=1
smoke=1
session=windburn-hermes-runtime
window=hermes-yolo
repo=/root/.hermes/hermes-agent
provider=openai-codex
model=gpt-5.5
hermes_bin=/usr/local/bin/hermes
hermes_version=Hermes Agent v0.12.0 (2026.4.30)
hermes_version=Project: /root/.hermes/hermes-agent
hermes_version=Python: 3.11.15
hermes_version=OpenAI SDK: 2.32.0
hermes_version=Up to date
tmux=tmux 3.4
session_action=already_present
window_action=already_present
before_pane_pid=117133
before_pane_args=/root/.hermes/hermes-agent/venv/bin/python3 /usr/local/bin/hermes --yolo
yolo_action=respawned_restart
fixed_tmux_session=present
yolo_window=present
pane_pid=120878
pane_dead=0
pane_current_command=python3
pane_args=/root/.hermes/hermes-agent/venv/bin/python3 /usr/local/bin/hermes --yolo
pane=│      gpt-5.5 · Nous Research      creative: architecture-diagram,            │
pane=│    /root/.hermes/hermes-agent     ascii-art, ascii-video, b...               │
pane=│  Session: 20260504_042244_5f23a9  data-science: jupyter-live-kernel          │
pane=│                                   devops: kanban-orchestrator,               │
pane=│                                   kanban-worker, webhook-sub...              │
pane=│                                   email: himalaya                            │
pane=│                                   gaming: minecraft-modpack-server,          │
pane=│                                   pokemon-player                             │
pane=│                                   general: dogfood, yuanbao                  │
pane=│                                   github: codebase-inspection, github-auth,  │
pane=│                                   github-code-r...                           │
pane=│                                   mcp: native-mcp,                           │
pane=│                                   research-vault-mcp-preflight               │
pane=│                                   media: gif-search, heartmula, songsee,     │
pane=│                                   spotify, youtub...                         │
pane=│                                   mlops: audiocraft-audio-generation,        │
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
pane=
yolo_process= 120878   36706 Rsl+ /root/.hermes/hermes-agent/venv/bin/python3 /usr/local/bin/hermes --yolo
yolo_process_count=1
smoke_artifact_dir=/root/.hermes/runs/windburn-yolo-loop/20260504T042735Z
oneshot_exit=0
oneshot_stdout_bytes=29
oneshot_stderr_bytes=0
oneshot_output_match=yes
oneshot_observed=WINDBURN_HERMES_YOLO_LOOP_OK
runtime_window=tmux_window=0:shell:bash:dead=0
runtime_window=tmux_window=1:gateway-log:journalctl:dead=0
runtime_window=tmux_window=2:health:bash:dead=0
runtime_window=tmux_window=3:hermes-yolo:python3:dead=0
```

## Rerun

```sh
scripts/hermes-yolo-loop.sh --out docs/remote-workhorse/preflight/HERMES_YOLO_LOOP_PROOF.md
scripts/hermes-yolo-loop.sh --ensure --restart --smoke --confirm-hermes-yolo-loop --out docs/remote-workhorse/preflight/HERMES_YOLO_LOOP_PROOF.md
```
