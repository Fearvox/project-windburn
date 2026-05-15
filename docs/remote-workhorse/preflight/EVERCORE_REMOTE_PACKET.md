# EverCore Remote Workhorse Packet

## Verdict

FLAG: EverCore is staged in local Windburn configuration, but the remote service
must not be called deployed until payload staging, `nixos-rebuild test`, and the
remote full smoke pass.

## What Changed

- Added a workhorse NixOS module for the EverCore loopback memory backend.
- Imported the module into the workhorse host config with loopback-only binding.
- Added a guarded staging script for the EverOS repo and remote compose file.
- Added `just` targets for dry-run and explicit apply staging.

## Guardrails

- The API binds to `127.0.0.1` by default.
- The firewall port stays closed.
- Public bind requires an explicit module option.
- The real env file is operator-owned and not committed.
- The staging script refuses apply if the remote secret env file is absent.
- `nixos-rebuild test` remains the first NixOS mutation gate; `switch` is not
  part of this packet.

## Commands

Local validation:

```bash
just evercore-stage-dry-run
bash -n scripts/evercore-remote-stage.sh scripts/nixos-remote-rebuild.sh
git diff --check -- nixos/hosts/windburn-workhorse-nyc1 scripts justfile docs/remote-workhorse/preflight/EVERCORE_REMOTE_PACKET.md
```

Remote sequence after the private env file is present:

```bash
just evercore-stage-apply
just nixos-rebuild-test
```

EverOS smoke after the test rebuild:

```bash
cd ../EverOS/use-cases/hermes-everos-memory
scripts/dogfood-smoke.sh --mode full
deploy/nixos/scripts/evercore-remote-smoke.sh --mode full
```

## Remaining Risk

- The remote secret env file is not proven in this packet.
- The remote Docker build has not been run from the workhorse.
- The full smoke is still local-loopback only until the NixOS test deploy runs.
