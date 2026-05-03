# Combined Repository Index

- [modelcontextprotocol/rust-sdk](https://github.com/modelcontextprotocol/rust-sdk)
- [nix-community/nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
- [nix-community/disko](https://github.com/nix-community/disko)
- [Mic92/sops-nix](https://github.com/Mic92/sops-nix)
- [oxalica/rust-overlay](https://github.com/oxalica/rust-overlay)
- [ipetkov/crane](https://github.com/ipetkov/crane)

## Retrieval Method

```bash
curl -s "https://api.github.com/repos/OWNER/REPO/contents/PATH?ref=BRANCH" \
  -H "Accept: application/vnd.github+json" | \
  python3 -c "import sys,json,base64; print(base64.b64decode(json.load(sys.stdin)['content']).decode())"
```
---

## modelcontextprotocol/rust-sdk

### Conformance

| Description | Path |
|-------------|------|
| 2026 02 25 rust sdk assessment | `conformance/results/2026-02-25-rust-sdk-assessment.md` |
| 2026 02 25 rust sdk remediation | `conformance/results/2026-02-25-rust-sdk-remediation.md` |

### Crates

| Description | Path |
|-------------|------|
| CHANGELOG | `crates/rmcp-macros/CHANGELOG.md` |
| Rmcp Macros | `crates/rmcp-macros/README.md` |
| CHANGELOG | `crates/rmcp/CHANGELOG.md` |
| Rmcp | `crates/rmcp/README.md` |

### Documentation

| Description | Path |
|-------------|------|
| CONTRIBUTE | `docs/CONTRIBUTE.MD` |
| DEVCONTAINER | `docs/DEVCONTAINER.md` |
| OAUTH SUPPORT | `docs/OAUTH_SUPPORT.md` |
| README.zh cn | `docs/readme/README.zh-cn.md` |

### Examples

| Description | Path |
|-------------|------|
| Examples | `examples/README.md` |
| Clients | `examples/clients/README.md` |
| Servers | `examples/servers/README.md` |
| Simple Chat Client | `examples/simple-chat-client/README.md` |
| Wasi | `examples/wasi/README.md` |

### Other

| Description | Path |
|-------------|------|
| — | `README.md` |
| ROADMAP | `ROADMAP.md` |
| SECURITY | `SECURITY.md` |

## nix-community/nixos-anywhere

### Documentation

| Description | Path |
|-------------|------|
| Docs | `docs/INDEX.md` |
| SUMMARY | `docs/SUMMARY.md` |
| cli | `docs/cli.md` |
| howtos | `docs/howtos.md` |
| Howtos | `docs/howtos/INDEX.md` |
| custom kexec | `docs/howtos/custom-kexec.md` |
| disko modes | `docs/howtos/disko-modes.md` |
| extra files | `docs/howtos/extra-files.md` |
| ipv6 | `docs/howtos/ipv6.md` |
| limited ram | `docs/howtos/limited-ram.md` |
| nix path | `docs/howtos/nix-path.md` |
| no os | `docs/howtos/no-os.md` |
| secrets | `docs/howtos/secrets.md` |
| terraform | `docs/howtos/terraform.md` |
| use without flakes | `docs/howtos/use-without-flakes.md` |
| quickstart | `docs/quickstart.md` |
| reference | `docs/reference.md` |
| requirements | `docs/requirements.md` |

### Other

| Description | Path |
|-------------|------|
| CONTRIBUTING | `CONTRIBUTING.md` |
| — | `README.md` |

### Terraform

| Description | Path |
|-------------|------|
| Terraform | `terraform/README.md` |
| all in one | `terraform/all-in-one.md` |
| install | `terraform/install.md` |
| nix build | `terraform/nix-build.md` |
| nixos rebuild | `terraform/nixos-rebuild.md` |

## nix-community/disko

### Documentation

| Description | Path |
|-------------|------|
| HowTo | `docs/HowTo.md` |
| Docs | `docs/INDEX.md` |
| disko images | `docs/disko-images.md` |
| disko install | `docs/disko-install.md` |
| interactive vm | `docs/interactive-vm.md` |
| quickstart | `docs/quickstart.md` |
| reference | `docs/reference.md` |
| requirements | `docs/requirements.md` |
| supportmatrix | `docs/supportmatrix.md` |
| table to gpt | `docs/table-to-gpt.md` |
| testing | `docs/testing.md` |
| upgrade guide | `docs/upgrade-guide.md` |

### Other

| Description | Path |
|-------------|------|
| CONTRIBUTING | `CONTRIBUTING.md` |
| — | `README.md` |

## Mic92/sops-nix

### Other

| Description | Path |
|-------------|------|
| — | `README.md` |

## oxalica/rust-overlay

### Documentation

| Description | Path |
|-------------|------|
| cross compilation | `docs/cross_compilation.md` |
| reference | `docs/reference.md` |

### Other

| Description | Path |
|-------------|------|
| — | `README.md` |

## ipetkov/crane

### Checks

| Description | Path |
|-------------|------|
| Workspace Not At Root | `checks/workspace-not-at-root/README.md` |

### Documentation

| Description | Path |
|-------------|------|
| API | `docs/API.md` |
| CHANGELOG | `docs/CHANGELOG.md` |
| Docs | `docs/README.md` |
| SUMMARY | `docs/SUMMARY.md` |
| advanced | `docs/advanced/advanced.md` |
| overriding function behavior | `docs/advanced/overriding-function-behavior.md` |
| custom cargo commands | `docs/custom_cargo_commands.md` |
| customizing builds | `docs/customizing_builds.md` |
| alt registry | `docs/examples/alt-registry.md` |
| build std | `docs/examples/build-std.md` |
| cross musl | `docs/examples/cross-musl.md` |
| cross rust overlay | `docs/examples/cross-rust-overlay.md` |
| cross windows | `docs/examples/cross-windows.md` |
| custom toolchain | `docs/examples/custom-toolchain.md` |
| end to end testing | `docs/examples/end-to-end-testing.md` |
| quick start simple | `docs/examples/quick-start-simple.md` |
| quick start workspace | `docs/examples/quick-start-workspace.md` |
| quick start | `docs/examples/quick-start.md` |
| sqlx | `docs/examples/sqlx.md` |
| trunk workspace | `docs/examples/trunk-workspace.md` |
| trunk | `docs/examples/trunk.md` |
| build workspace subset | `docs/faq/build-workspace-subset.md` |
| building with non rust includes | `docs/faq/building-with-non-rust-includes.md` |
| constant rebuilds | `docs/faq/constant-rebuilds.md` |
| control when hooks run | `docs/faq/control-when-hooks-run.md` |
| cross compiling aws lc sys | `docs/faq/cross-compiling-aws-lc-sys.md` |
| custom nixpkgs | `docs/faq/custom-nixpkgs.md` |
| faq | `docs/faq/faq.md` |
| git dep cannot find relative path | `docs/faq/git-dep-cannot-find-relative-path.md` |
| ifd error | `docs/faq/ifd-error.md` |
| invalid metadata files for crate | `docs/faq/invalid-metadata-files-for-crate.md` |
| missing files during checks | `docs/faq/missing-files-during-checks.md` |
| no cargo lock | `docs/faq/no-cargo-lock.md` |
| patching cargo lock | `docs/faq/patching-cargo-lock.md` |
| rebuilds bindgen | `docs/faq/rebuilds-bindgen.md` |
| rebuilds pyo3 | `docs/faq/rebuilds-pyo3.md` |
| rebuilds with different toolchains | `docs/faq/rebuilds-with-different-toolchains.md` |
| rebuilds with proc macros | `docs/faq/rebuilds-with-proc-macros.md` |
| sandbox unfriendly build scripts | `docs/faq/sandbox-unfriendly-build-scripts.md` |
| workspace not at source root | `docs/faq/workspace-not-at-source-root.md` |
| getting started | `docs/getting-started.md` |
| introduction | `docs/introduction.md` |
| artifact reuse | `docs/introduction/artifact-reuse.md` |
| sequential builds | `docs/introduction/sequential-builds.md` |
| local development | `docs/local_development.md` |
| manifest filtering | `docs/manifest-filtering.md` |
| overriding stdenv | `docs/overriding-stdenv.md` |
| overriding derivations | `docs/overriding_derivations.md` |
| patching dependency sources | `docs/patching_dependency_sources.md` |
| source filtering | `docs/source-filtering.md` |

### Examples

| Description | Path |
|-------------|------|
| Examples | `examples/README.md` |

### Other

| Description | Path |
|-------------|------|
| CHANGELOG | `CHANGELOG.md` |
| — | `README.md` |

---
*Generated by building-github-index*