# Hermes Health Gate

Generated: `2026-05-03T23:41:28Z`

Target: `137.184.104.26`

Fixed tmux session: `windburn-hermes-runtime`

VERDICT: `PASS`

## Flags

- none

## Evidence

```text
host=hermes-nyc1
uptime=up 1 week, 4 days, 17 hours, 23 minutes
hermes_bin=/usr/local/bin/hermes
hermes_version=Hermes Agent v0.12.0 (2026.4.30)
hermes_version=Project: /root/.hermes/hermes-agent
hermes_version=Python: 3.11.15
hermes_version=OpenAI SDK: 2.32.0
hermes_version=Up to date
hermes_update_check=→ Fetching from origin...
hermes_update_check=✓ Already up to date.
hermes_git_status=## main...origin/main [ahead 1]
hermes_git_head=aedb51c9272b
hermes_origin_main=86e64c1d3bc0
hermes_gateway_service=active
do_agent_service=active
droplet_agent_service=active
tailscaled_service=active
hermes_chat_count=5
research_vault_mcp_count=29
multica_daemon_count=1
recent_gateway_warning_count=1
recent_gateway_error_count=0
tmux_version=tmux 3.4
fixed_tmux_session=present
tmux_session=12: 1 windows (created Tue Apr 28 12:23:01 2026)
tmux_session=hermes-ccr-full-debug-20260501: 2 windows (created Fri May  1 08:33:36 2026)
tmux_session=hermes-ccr-full-debug-max-20260501: 2 windows (created Fri May  1 11:18:02 2026)
tmux_session=hermes-ccr-goal-20260501: 2 windows (created Fri May  1 12:18:41 2026)
tmux_session=hermes-evo-health-20260426: 5 windows (created Sun Apr 26 11:22:04 2026)
tmux_session=hermes-evo-rv-20260426: 1 windows (created Sun Apr 26 08:48:57 2026)
tmux_session=hermes-evo-rv-20260426-mcp: 2 windows (created Sun Apr 26 08:56:20 2026)
tmux_session=hermes-goal-canary-20260501: 1 windows (created Fri May  1 12:04:50 2026)
tmux_session=hermes-goal-canary2-20260501: 1 windows (created Fri May  1 12:14:57 2026)
tmux_session=hermes-harness: 6 windows (created Wed Apr 22 20:41:18 2026)
tmux_session=hermes-hudui-zonic: 1 windows (created Wed Apr 22 13:36:48 2026)
tmux_session=hermes-operator: 1 windows (created Wed Apr 22 10:40:28 2026)
tmux_session=hermes-sixpack-20260429T074445Z: 7 windows (created Wed Apr 29 07:46:00 2026)
tmux_session=windburn-hermes-runtime: 3 windows (created Sun May  3 23:39:29 2026)
listener=LISTEN 0      128                        0.0.0.0:8644       0.0.0.0:*    users:[redacted]
listener=LISTEN 0      512                        0.0.0.0:18765      0.0.0.0:*    users:[redacted]
listener=LISTEN 0      512                        0.0.0.0:18766      0.0.0.0:*    users:[redacted]
listener=LISTEN 0      512                        0.0.0.0:18767      0.0.0.0:*    users:[redacted]
listener=LISTEN 0      512                        0.0.0.0:18768      0.0.0.0:*    users:[redacted]
listener=LISTEN 0      4096                     127.0.0.1:19514      0.0.0.0:*    users:[redacted]
listener=LISTEN 0      4096                       0.0.0.0:22         0.0.0.0:*    users:[redacted]
listener=LISTEN 0      2048                     127.0.0.1:3001       0.0.0.0:*    users:[redacted]
listener=LISTEN 0      4096                          [::]:22            [::]:*    users:[redacted]
```

## Rerun

```sh
scripts/hermes-health-gate.sh --out docs/remote-workhorse/preflight/HERMES_HEALTH_GATE.md
```
