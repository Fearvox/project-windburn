# Hermes Maintenance

Generated: `2026-05-03T23:44:41Z`

Target: `137.184.104.26`

Mode: update=`0`, ensure_tmux=`0`

VERDICT: `PASS`

## Flags

- none

## Evidence

```text
host=hermes-nyc1
generated_at_utc=2026-05-03T23:44:44Z
repo=/root/.hermes/hermes-agent
apply_update=0
ensure_tmux=0
fixed_session=windburn-hermes-runtime
hermes_bin=/usr/local/bin/hermes
before_hermes_version=Hermes Agent v0.12.0 (2026.4.30)
before_hermes_version=Project: /root/.hermes/hermes-agent
before_hermes_version=Python: 3.11.15
before_hermes_version=OpenAI SDK: 2.32.0
before_hermes_version=Up to date
before_update_check=→ Fetching from origin...
before_update_check=✓ Already up to date.
before_head=aedb51c9272b
before_origin_main=86e64c1d3bc0
before_ahead_count=1
before_behind_count=0
before_git_status=## main...origin/main [ahead 1]
delta_log=< aedb51c92 (HEAD -> main) fix: preserve high context on vague overflow
backup_branch_seen=windburn/pre-update-20260503T233651Z
backup_tag_seen=windburn-pre-update-20260503T233651Z
backup_zip_seen= /root/.hermes/backups/pre-update-2026-05-03-233656.zip  bytes=190090510
after_hermes_version=Hermes Agent v0.12.0 (2026.4.30)
after_hermes_version=Project: /root/.hermes/hermes-agent
after_hermes_version=Python: 3.11.15
after_hermes_version=OpenAI SDK: 2.32.0
after_hermes_version=Up to date
after_update_check=→ Fetching from origin...
after_update_check=✓ Already up to date.
after_git_status=## main...origin/main [ahead 1]
after_head=aedb51c9272b
hermes_gateway_service=active
do_agent_service=active
droplet_agent_service=active
tailscaled_service=active
hermes_chat_count=5
research_vault_mcp_count=29
multica_daemon_count=1
recent_gateway_warning_count=1
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
cherry_pick_status=not_attempted
```

## Rerun

```sh
scripts/hermes-maintenance.sh --out docs/remote-workhorse/preflight/HERMES_MAINTENANCE.md
scripts/hermes-maintenance.sh --apply-update --ensure-tmux --confirm-hermes-maintenance --out docs/remote-workhorse/preflight/HERMES_MAINTENANCE.md
```
