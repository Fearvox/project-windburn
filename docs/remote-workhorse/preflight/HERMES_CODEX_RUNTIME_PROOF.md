# Hermes Codex Runtime Proof

Date: 2026-05-03
Target: `windburn-workhorse-nyc1` (`568689911`, `24.144.113.25`)

## Verdict

`PASS`: the remote NixOS workhorse can run pinned Hermes through the
`openai-codex` provider and receive an exact `gpt-5.5` response.

This is separate from `/srv/windburn/secrets/provider.env`. The generic provider
secret smoke still reports `REMOTE_PROVIDER_SECRET_MISSING` until an
OpenAI-compatible API key is installed. The Codex EDU route uses Hermes's own
OAuth auth store instead.

## Safety Contract

- `scripts/remote-codex-auth-sync.sh` is dry-run by default.
- Apply requires `--apply --confirm-remote-codex-auth-sync`.
- Secret values are never printed and never written to this repository.
- The remote Codex CLI copy is root-only:
  `/srv/windburn/secrets/codex-auth.json` and `/root/.codex/auth.json`.
- The remote Hermes auth store is root-only: `/root/.hermes/auth.json`.
- The Hermes auth payload contains only `providers.openai-codex`; local
  `~/.hermes/auth.json` is preferred over local `~/.codex/auth.json` because
  upstream Hermes keeps a separate auth store.
- `scripts/remote-hermes-codex-smoke.sh` is dry-run by default.
- Apply requires `--apply --confirm-remote-hermes-codex-smoke`.
- Smoke artifacts land under `/srv/windburn/runs/hermes-codex-smoke/`.

## Root Cause Captured

The first smoke attempt failed even after `/root/.codex/auth.json` existed:

```text
reason=HERMES_CODEX_SMOKE_EXIT_1
```

Redacted stderr showed upstream Hermes was reading `~/.hermes/auth.json`, not
`~/.codex/auth.json`:

```text
hermes_cli.auth.AuthError: No Codex credentials stored. Run `hermes auth` to authenticate.
```

The sync script now writes the minimal Hermes auth store that upstream Hermes
expects.

## Auth Sync Proof

Command:

```sh
scripts/remote-codex-auth-sync.sh --apply --confirm-remote-codex-auth-sync
```

Observed safe proof:

```text
mode=apply
host=24.144.113.25
remote_secret_path=/srv/windburn/secrets/codex-auth.json
remote_root_auth_path=/root/.codex/auth.json
remote_hermes_auth_path=/root/.hermes/auth.json
hermes_auth_payload_source=local_hermes_auth

local_codex_auth_summary:
codex_cli:
auth_mode=chatgpt
top_level_keys=auth_mode,OPENAI_API_KEY,tokens,last_refresh
openai_api_key_length=0
has_tokens_access_token=true
tokens_access_token_length=2087
has_tokens_refresh_token=true

hermes:
active_provider=openai-codex
has_openai_codex_provider=true
openai_codex_keys=tokens,last_refresh,auth_mode
openai_codex_has_access_token=true
openai_codex_access_token_length=2087
openai_codex_has_refresh_token=true

post_sync_remote_codex_auth_probe:
windburn_codex_auth=present mode=600 owner=root group=root bytes=4601
root_codex_auth=present mode=600 owner=root group=root bytes=4601
root_hermes_auth=present mode=600 owner=root group=root bytes=4750
```

## Runtime Smoke Proof

Command:

```sh
scripts/remote-hermes-codex-smoke.sh --apply --confirm-remote-hermes-codex-smoke
```

Remote artifact:

```text
/srv/windburn/runs/hermes-codex-smoke/20260503T124810Z-hermes-codex-smoke/result.json
```

Artifact verdict:

```json
{
  "schema_version": 1,
  "generated_at_utc": "2026-05-03T12:48:21Z",
  "run_id": "20260503T124810Z-hermes-codex-smoke",
  "hostname": "windburn-workhorse-nyc1",
  "verdict": "PASS",
  "reason": "HERMES_CODEX_PROVIDER_OK",
  "remote_health": {
    "system_state": "running",
    "failed_units": 0,
    "nix_path": "/run/current-system/sw/bin/nix"
  },
  "hermes": {
    "source": "github:NousResearch/hermes-agent",
    "rev": "6f2dab248a6cc8591af46e5deb2dc939c2b43146",
    "model": "gpt-5.5",
    "version_exit_code": 0,
    "smoke_exit_code": 0,
    "output_match": true,
    "expected_text": "WINDBURN_REMOTE_CODEX_PROVIDER_OK",
    "observed_text": "WINDBURN_REMOTE_CODEX_PROVIDER_OK",
    "stdout_bytes": 34,
    "stderr_bytes": 0
  },
  "codex_auth": {
    "root": {
      "path": "/root/.codex/auth.json",
      "status": "present"
    },
    "secret_copy": {
      "path": "/srv/windburn/secrets/codex-auth.json",
      "status": "present"
    }
  },
  "hermes_auth": {
    "path": "/root/.hermes/auth.json",
    "status": "present",
    "has_openai_codex_provider": true,
    "openai_codex_access_token_length": 2087,
    "has_openai_codex_refresh_token": true
  },
  "artifact_path": "/srv/windburn/runs/hermes-codex-smoke/20260503T124810Z-hermes-codex-smoke/result.json",
  "repair_card": null
}
```

## Rerun Path

```sh
scripts/remote-codex-auth-sync.sh
scripts/remote-codex-auth-sync.sh --apply --confirm-remote-codex-auth-sync
scripts/remote-hermes-codex-smoke.sh
scripts/remote-hermes-codex-smoke.sh --apply --confirm-remote-hermes-codex-smoke
```

Use this gate before starting heavier remote Hermes sessions. A `PASS` here
means the remote can spend Codex-side tokens through Hermes without needing a
manual browser login on the droplet.
