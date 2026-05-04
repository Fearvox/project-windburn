# Hermes Maintenance

Generated: `2026-05-04T04:19:03Z`

Target: `137.184.104.26`

Mode: update=`1`, ensure_tmux=`1`

VERDICT: `PASS`

## Flags

- none

## Evidence

```text
host=hermes-nyc1
generated_at_utc=2026-05-04T04:19:06Z
repo=/root/.hermes/hermes-agent
apply_update=1
ensure_tmux=1
fixed_session=windburn-hermes-runtime
hermes_bin=/usr/local/bin/hermes
before_hermes_version=Hermes Agent v0.12.0 (2026.4.30)
before_hermes_version=Project: /root/.hermes/hermes-agent
before_hermes_version=Python: 3.11.15
before_hermes_version=OpenAI SDK: 2.32.0
before_hermes_version=Up to date
before_update_check=→ Fetching from origin...
before_update_check=⚕ Update available: 12 commits behind origin/main.
before_update_check=  Run 'hermes update' to install.
before_head=aedb51c9272b
before_origin_main=363cc936746c
before_ahead_count=1
before_behind_count=12
before_git_status=## main...origin/main [ahead 1, behind 12]
delta_log=> 363cc9367 (origin/main, origin/HEAD) fix(cron): bump skill usage when cron jobs load skills
delta_log=> 808fee151 fix(auxiliary): propagate explicit_api_key to _try_anthropic()
delta_log=> 74636f9c4 fix(gateway): clear queued reload-skills notes on new/resume/branch
delta_log=> 222767e5e fix: sanitize Telegram help command mentions
delta_log=> 6fda92aa7 fix(gateway): bridge top-level require_mention to Telegram config
delta_log=> 1bd975c0b fix(gateway): suppress duplicate voice transcripts
delta_log=> b58db237e fix(kanban): drop worker identity claim from KANBAN_GUIDANCE (#19427)
delta_log=> 6713274a4 fix(file): strip leaked terminal fences from reads
delta_log=> 2d7543c61 fix(windows): enforce UTF-8 stdout/stderr to prevent UnicodeEncodeError crash
delta_log=> 2ababfe6e chore(release): map 0xKingBack noreply email
delta_log=> 3c4202453 fix(curator): pass auxiliary curator api_key/base_url into runtime resolution
delta_log=> 3792b77bd fix(send_message): support QQBot C2C and group chats
delta_log=< aedb51c92 (HEAD -> main) fix: preserve high context on vague overflow
backup_branch_seen=windburn/pre-update-20260503T233651Z
backup_tag_seen=windburn-pre-update-20260503T233651Z
backup_zip_seen= /root/.hermes/backups/pre-update-2026-05-03-233656.zip  bytes=190090510
backup_branch=windburn/pre-update-20260504T041906Z
backup_tag=windburn-pre-update-20260504T041906Z
hermes_update=
hermes_update=[notice] A new release of pip is available: 24.0 -> 26.1
hermes_update=[notice] To update, run: /root/.hermes/hermes-agent/venv/bin/python3 -m pip install --upgrade pip
hermes_update=⚕ Updating Hermes Agent...
hermes_update=
hermes_update=◆ Creating pre-update backup...
hermes_update=  Saved:    ~/.hermes/backups/pre-update-2026-05-04-041910.zip (209.2 MB, 54.0s)
hermes_update=  Restore:  hermes import /root/.hermes/backups/pre-update-2026-05-04-041910.zip
hermes_update=  Disable:  omit --backup (backups are off by default)
hermes_update=            set updates.pre_update_backup: false in config.yaml
hermes_update=
hermes_update=→ Fetching updates...
hermes_update=→ Found 12 new commit(s)
hermes_update=  ✓ Pre-update snapshot: 20260504-042005-pre-update
hermes_update=→ Pulling updates...
hermes_update=  ⚠ Fast-forward not possible (history diverged), resetting to match remote...
hermes_update=  ✓ Cleared 20 stale __pycache__ directories
hermes_update=→ Updating Python dependencies...
hermes_update=
hermes_update=✓ Code updated!
hermes_update=
hermes_update=→ Syncing bundled skills...
hermes_update=  ~ 3 user-modified (kept)
hermes_update=  ✓ Skills are up to date
hermes_update=
hermes_update=→ Checking configuration for new options...
hermes_update=  ✓ Configuration is up to date
hermes_update=
hermes_update=✓ Update complete!
hermes_update=  → hermes-gateway: draining (up to 75s)...
hermes_update=
hermes_update=  ✓ Restarted hermes-gateway
hermes_update=
hermes_update=Tip: You can now select a provider and model:
hermes_update=  hermes model              # Select provider and model
update_exit=0
cherry_pick_aedb51c9272be5ec53d8e1666f5215fe5c248c25=[main f5b8484c0] fix: preserve high context on vague overflow
cherry_pick_aedb51c9272be5ec53d8e1666f5215fe5c248c25= Author: 0xvox Hermes Ops <0xvox@local>
cherry_pick_aedb51c9272be5ec53d8e1666f5215fe5c248c25= Date: Sun Apr 26 12:02:41 2026 +0000
cherry_pick_aedb51c9272be5ec53d8e1666f5215fe5c248c25= 2 files changed, 87 insertions(+)
tmux_entry=already_present
after_hermes_version=Hermes Agent v0.12.0 (2026.4.30)
after_hermes_version=Project: /root/.hermes/hermes-agent
after_hermes_version=Python: 3.11.15
after_hermes_version=OpenAI SDK: 2.32.0
after_hermes_version=Up to date
after_update_check=→ Fetching from origin...
after_update_check=✓ Already up to date.
after_git_status=## main...origin/main [ahead 1]
after_head=f5b8484c0cba
hermes_gateway_service=active
do_agent_service=active
droplet_agent_service=active
tailscaled_service=active
hermes_chat_count=5
research_vault_mcp_count=32
multica_daemon_count=1
recent_gateway_warning_count=5
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
tmux_session=windburn-hermes-runtime: 4 windows (created Sun May  3 23:39:29 2026)
cherry_pick_status=clean
```

## Rerun

```sh
scripts/hermes-maintenance.sh --out docs/remote-workhorse/preflight/HERMES_MAINTENANCE.md
scripts/hermes-maintenance.sh --apply-update --ensure-tmux --confirm-hermes-maintenance --out docs/remote-workhorse/preflight/HERMES_MAINTENANCE.md
```
