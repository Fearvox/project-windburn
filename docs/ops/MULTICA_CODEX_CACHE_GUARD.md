# Multica Codex Cache Guard

Multica Workbench runs create isolated `codex-home` directories under:

```text
~/multica_workspaces_desktop-api.multica.ai/<workspace-id>/<run-id>/codex-home
```

The current desktop runtime can generate a full Codex plugin profile for each
run. When that happens, Codex syncs plugin marketplaces into
`codex-home/.tmp`, even when the Workbench agent only needs the `multica` CLI.
This is cache bloat, not task evidence.

## Guardrail

Use the janitor in dry-run mode first:

```sh
scripts/multica-codex-cache-janitor.sh
```

Apply cleanup only after the dry-run list looks right:

```sh
scripts/multica-codex-cache-janitor.sh --apply
```

The script deletes only `*/codex-home/.tmp` for runs whose `.gc_meta.json`
contains `completed_at`. It does not touch `workdir`, `logs`, `output`,
Codex config, auth, or session files.

## Recurring macOS Guard

Copy the launchd template and load it after reviewing the path:

```sh
mkdir -p ~/Library/LaunchAgents
cp ops/launchd/com.windburn.multica-codex-cache-janitor.plist.example \
  ~/Library/LaunchAgents/com.windburn.multica-codex-cache-janitor.plist
launchctl load ~/Library/LaunchAgents/com.windburn.multica-codex-cache-janitor.plist
```

The template runs every 15 minutes and only prunes completed Multica runs.

## Better Upstream Fix

The stronger fix is a lean Workbench Codex profile at run creation time:

1. Do not copy the full user `~/.codex/config.toml` into per-run `codex-home`.
2. Generate a Workbench-only profile with no plugin marketplace entries unless
   the agent explicitly needs one. See
   `config/multica-workbench-codex-profile.example.toml`.
3. Keep provider/model/context settings, `multica` CLI access, and required
   environment only.
4. Verify a new run leaves `codex-home/.tmp` empty or absent after completion.

If the run launcher can pass Codex CLI flags, prefer this shape for normal
Workbench agents:

```sh
codex exec \
  --ignore-user-config \
  --skip-git-repo-check \
  --ephemeral \
  --config model='"gpt-5.5"' \
  --config model_context_window=1000000 \
  --config model_auto_compact_token_limit=220000 \
  --config model_reasoning_effort='"xhigh"'
```

`--ignore-user-config` is the important bit: it prevents the global plugin and
marketplace tables from entering the per-run home.

That upstream profile change prevents the bytes from being written at all. The
janitor is the local reliability guard until Multica exposes that profile hook.
