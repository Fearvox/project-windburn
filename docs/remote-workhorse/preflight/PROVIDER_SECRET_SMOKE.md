# Provider Secret Smoke Proof

Date: 2026-05-03
Target: `windburn-workhorse-nyc1` (`568689911`, `24.144.113.25`)

## Verdict

`FLAG`: remote provider credentials are not installed yet.

The NixOS foundation is healthy, but `/srv/windburn/secrets/provider.env` is
absent. This is expected until an allowlisted OpenAI-compatible or Hermes
provider credential is synced from the trusted local machine.

## Safety Contract

- `scripts/remote-secret-sync.sh` is dry-run by default.
- Apply requires `--apply --confirm-remote-secret-sync`.
- Only allowlisted provider variables are copied.
- Secret values are never printed and never written to this repository.
- Remote destination is root-only: `/srv/windburn/secrets/provider.env`.
- `scripts/remote-provider-smoke.sh` is read-only by default.
- Provider smoke supports `OPENAI_API_KEY` plus optional `OPENAI_BASE_URL`, or
  `HERMES_API_KEY` plus `HERMES_PROVIDER_BASE_URL`.
- Apply requires `--apply --confirm-provider-smoke` and writes a remote run
  artifact under `/srv/windburn/runs/provider-smoke/`.

## Local Secret Probe

Command:

```sh
scripts/remote-secret-sync.sh
```

Observed proof:

```text
mode=dry-run
host=24.144.113.25
remote_secret_path=/srv/windburn/secrets/provider.env
allowlisted_present_count=6
allowlisted_present_names=ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL ANTHROPIC_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL

remote_secret_probe:
drwx------ 2 root root 4096 May  3 10:54 /srv/windburn/secrets
provider_env=absent

dry-run complete; no secrets were copied
```

## Remote Smoke Probe

Command:

```sh
scripts/remote-provider-smoke.sh
```

Observed proof:

```json
{
  "schema_version": 1,
  "generated_at_utc": "2026-05-03T11:06:14Z",
  "run_id": "20260503T110614Z-provider-smoke",
  "hostname": "windburn-workhorse-nyc1",
  "verdict": "FLAG",
  "reason": "REMOTE_PROVIDER_SECRET_MISSING",
  "provider_type": null,
  "present_secret_names": [],
  "secret_path": "/srv/windburn/secrets/provider.env",
  "repair_card": {
    "id": "REMOTE_PROVIDER_SECRET_REPAIR",
    "action": "Run scripts/remote-secret-sync.sh with allowlisted OpenAI or Hermes provider variables, then rerun provider smoke."
  }
}
```

## Remote Repair Artifact

Command:

```sh
scripts/remote-provider-smoke.sh --apply --confirm-provider-smoke
```

Remote artifact:

```text
/srv/windburn/runs/provider-smoke/20260503T110623Z-provider-smoke/result.json
```

Artifact verdict:

```json
{
  "schema_version": 1,
  "generated_at_utc": "2026-05-03T11:06:23Z",
  "run_id": "20260503T110623Z-provider-smoke",
  "hostname": "windburn-workhorse-nyc1",
  "verdict": "FLAG",
  "reason": "REMOTE_PROVIDER_SECRET_MISSING",
  "provider_type": null,
  "present_secret_names": [],
  "secret_path": "/srv/windburn/secrets/provider.env",
  "repair_card": {
    "id": "REMOTE_PROVIDER_SECRET_REPAIR",
    "action": "Run scripts/remote-secret-sync.sh with allowlisted OpenAI or Hermes provider variables, then rerun provider smoke."
  }
}
```

Post-artifact remote health:

```text
system_state=running
0 loaded units listed.
```

## Next Action

Install an OpenAI-compatible or Hermes provider credential on the trusted local
machine, then run:

```sh
scripts/remote-secret-sync.sh --apply --confirm-remote-secret-sync
scripts/remote-provider-smoke.sh --apply --confirm-provider-smoke
```

The smoke gate should remain `FLAG` until at least one usable provider
credential exists in `/srv/windburn/secrets/provider.env`.
