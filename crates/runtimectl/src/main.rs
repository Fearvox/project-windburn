use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use serde::Serialize;
use serde_json::Value;
use std::ffi::OsStr;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;
use time::OffsetDateTime;
use time::format_description::well_known::Rfc3339;

#[derive(Parser, Debug)]
#[command(name = "runtimectl")]
#[command(about = "Remote Workhorse local evidence and canary runner")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Capture local host, git, runtime, and MCP evidence.
    Doctor {
        #[arg(long, default_value = ".")]
        target: PathBuf,
        #[arg(long, default_value = "docs/remote-workhorse/phase1/evidence/current")]
        evidence_dir: PathBuf,
    },
    /// Run the Phase 1 read-only repo/review health canary.
    Canary {
        #[arg(long, default_value = ".")]
        target: PathBuf,
        #[arg(long, default_value = "docs/remote-workhorse/phase1/evidence/current")]
        evidence_dir: PathBuf,
        #[arg(
            long,
            default_value = "docs/remote-workhorse/phase1/CANARY-read-only-repo-review-health.md"
        )]
        report: PathBuf,
    },
    /// Run local gates required before touching a remote NixOS workhorse.
    Preflight {
        #[arg(long, default_value = ".")]
        target: PathBuf,
        #[arg(
            long,
            default_value = "docs/remote-workhorse/preflight/evidence/current"
        )]
        evidence_dir: PathBuf,
        #[arg(
            long,
            default_value = "docs/remote-workhorse/preflight/REMOTE_NIXOS_PREFLIGHT.md"
        )]
        report: PathBuf,
        #[arg(long)]
        remote_host: Option<String>,
    },
}

#[derive(Serialize, Debug, Clone)]
struct DoctorEvidence {
    schema_version: u8,
    generated_at_utc: String,
    host: String,
    invocation_cwd: String,
    target: String,
    git: GitEvidence,
    probes: Vec<CommandProbe>,
    verdict: Verdict,
}

#[derive(Serialize, Debug, Clone)]
struct GitEvidence {
    is_repo: bool,
    top_level: Option<String>,
    branch: Option<String>,
    head: Option<String>,
    status_short: Option<String>,
    error: Option<String>,
}

#[derive(Serialize, Debug, Clone)]
struct CommandProbe {
    id: String,
    command: Vec<String>,
    status: String,
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
}

#[derive(Serialize, Debug, Clone, PartialEq, Eq)]
struct Verdict {
    status: String,
    reasons: Vec<String>,
}

#[derive(Serialize, Debug, Clone)]
struct FileCheck {
    label: String,
    path: String,
    exists: bool,
}

#[derive(Serialize, Debug, Clone)]
struct RemotePreflightEvidence {
    schema_version: u8,
    generated_at_utc: String,
    target: String,
    remote_host: Option<String>,
    doctor: DoctorEvidence,
    files: Vec<FileCheck>,
    probes: Vec<CommandProbe>,
    verdict: Verdict,
}

const DOCTL_READ_INVENTORY_PROBE_IDS: &[&str] = &[
    "doctl_account_ratelimit",
    "doctl_regions",
    "doctl_sizes",
    "doctl_droplets",
    "doctl_gpu_droplets",
    "doctl_ssh_keys",
    "doctl_snapshots",
    "doctl_images_private",
    "doctl_images_public",
    "doctl_firewalls",
    "doctl_volumes",
];

const DOCTL_MANAGED_SERVICE_PROBE_IDS: &[&str] = &[
    "doctl_projects",
    "doctl_apps",
    "doctl_databases",
    "doctl_vpcs",
    "doctl_load_balancers",
    "doctl_reserved_ips",
    "doctl_tags",
    "doctl_registries",
    "doctl_monitoring_alerts",
    "doctl_uptime_checks",
    "doctl_gradient_regions",
    "doctl_gradient_models",
    "doctl_gradient_agents",
    "doctl_gradient_knowledge_bases",
    "doctl_dedicated_inference_endpoints",
    "doctl_dedicated_inference_sizes",
    "doctl_dedicated_inference_model_config",
    "doctl_serverless_namespaces",
    "doctl_nfs_atl1",
    "doctl_nfs_nyc2",
    "doctl_nfs_ams3",
];

fn main() -> Result<()> {
    let cli = Cli::parse();
    match cli.command {
        Commands::Doctor {
            target,
            evidence_dir,
        } => {
            let evidence = run_doctor(&target, &evidence_dir)?;
            print_verdict("doctor", &evidence.verdict);
        }
        Commands::Canary {
            target,
            evidence_dir,
            report,
        } => {
            let verdict = run_canary(&target, &evidence_dir, &report)?;
            print_verdict("canary", &verdict);
        }
        Commands::Preflight {
            target,
            evidence_dir,
            report,
            remote_host,
        } => {
            let evidence = run_preflight(
                &target,
                &evidence_dir,
                &report,
                remote_host.or_else(|| std::env::var("WINDBURN_REMOTE_HOST").ok()),
            )?;
            print_verdict("preflight", &evidence.verdict);
        }
    }
    Ok(())
}

fn print_verdict(label: &str, verdict: &Verdict) {
    println!("{label}: {}", verdict.status);
    for reason in &verdict.reasons {
        println!("- {reason}");
    }
}

fn run_doctor(target_arg: &Path, evidence_dir_arg: &Path) -> Result<DoctorEvidence> {
    let target = absolutize(target_arg)?;
    let evidence_dir = absolutize(evidence_dir_arg)?;
    fs::create_dir_all(&evidence_dir)
        .with_context(|| format!("create evidence dir {}", evidence_dir.display()))?;

    let git = collect_git(&target);
    let probes = vec![
        run_probe("codex_version", "codex", ["--version"], &target),
        run_probe("codex_mcp_list", "codex", ["mcp", "list"], &target),
        run_probe("cargo_version", "cargo", ["--version"], &target),
        run_probe("rustc_version", "rustc", ["--version"], &target),
        run_probe("bun_version", "bun", ["--version"], &target),
        run_probe("node_version", "node", ["--version"], &target),
        run_probe("gh_version", "gh", ["--version"], &target),
        run_probe("hermes_version", "hermes", ["--version"], &target),
        run_probe("nix_version", "nix", ["--version"], &target),
        run_probe("nix_root_mount", "test", ["-d", "/nix/store"], &target),
        run_probe(
            "nix_store_volume",
            "test",
            ["-d", "/Volumes/Nix Store/store"],
            &target,
        ),
        run_probe(
            "nix_profile_volume",
            "test",
            ["-d", "/Volumes/Nix Store/var/nix"],
            &target,
        ),
        run_probe("colima_list", "colima", ["list"], &target),
        run_probe("colima_status", "colima", ["status"], &target),
        run_probe("just_version", "just", ["--version"], &target),
        run_probe("doctl_version", "doctl", ["version"], &target),
    ];

    let evidence = DoctorEvidence {
        schema_version: 1,
        generated_at_utc: now_utc(),
        host: command_text("hostname", std::iter::empty::<&str>(), &target)
            .unwrap_or_else(|| "unknown".to_string()),
        invocation_cwd: std::env::current_dir()
            .unwrap_or_else(|_| PathBuf::from("."))
            .display()
            .to_string(),
        target: target.display().to_string(),
        verdict: classify_doctor(&git, &probes),
        git,
        probes,
    };

    write_json(&evidence_dir.join("doctor.json"), &evidence)?;
    Ok(evidence)
}

fn run_canary(target_arg: &Path, evidence_dir_arg: &Path, report_arg: &Path) -> Result<Verdict> {
    let target = absolutize(target_arg)?;
    let evidence_dir = absolutize(evidence_dir_arg)?;
    let report = absolutize(report_arg)?;
    let doctor = run_doctor(&target, &evidence_dir)?;

    let phase_dir = target.join("docs/remote-workhorse/phase1");
    let inventory_path = phase_dir.join("TOOL_INVENTORY.json");
    let rv_path = phase_dir.join("RESEARCH_VAULT_PROOF.json");
    let graph_path = phase_dir.join("CODE_REVIEW_GRAPH_PROOF.json");

    let mut blockers = Vec::new();
    let mut flags = Vec::new();
    let mut notes = Vec::new();

    if doctor.verdict.status == "BLOCK" {
        blockers.extend(doctor.verdict.reasons.clone());
    } else if doctor.verdict.status == "FLAG" {
        flags.extend(doctor.verdict.reasons.clone());
    }

    require_file(&inventory_path, "tool inventory", &mut blockers, &mut notes);

    match read_json_value(&rv_path)? {
        Some(value) if json_str(&value, "/status") == Some("reachable_by_mcp") => {
            if json_bool(&value, "/durable_note_required") == Some(true) {
                flags.push("Research Vault is reachable, but exact remote-workhorse query has no durable note yet".to_string());
            }
            notes.push(format!("Research Vault proof: {}", rv_path.display()));
        }
        Some(_) => {
            blockers.push("Research Vault proof exists but is not reachable_by_mcp".to_string())
        }
        None => blockers.push(format!(
            "missing Research Vault proof: {}",
            rv_path.display()
        )),
    }

    match read_json_value(&graph_path)? {
        Some(value) if json_str(&value, "/status") == Some("ok") => {
            if json_u64(&value, "/registered_repository_count").unwrap_or(0) == 0 {
                flags.push(
                    "code-review-graph is enabled but has zero registered repositories".to_string(),
                );
            }
            notes.push(format!("code-review-graph proof: {}", graph_path.display()));
        }
        Some(_) => blockers.push("code-review-graph proof exists but status is not ok".to_string()),
        None => blockers.push(format!(
            "missing code-review-graph proof: {}",
            graph_path.display()
        )),
    }

    let verdict = canary_verdict(blockers, flags);
    let body = render_canary_report(&doctor, &verdict, &notes);
    if let Some(parent) = report.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("create report dir {}", parent.display()))?;
    }
    fs::write(&report, body)
        .with_context(|| format!("write canary report {}", report.display()))?;
    Ok(verdict)
}

fn run_preflight(
    target_arg: &Path,
    evidence_dir_arg: &Path,
    report_arg: &Path,
    remote_host: Option<String>,
) -> Result<RemotePreflightEvidence> {
    let target = absolutize(target_arg)?;
    let evidence_dir = absolutize(evidence_dir_arg)?;
    let report = absolutize(report_arg)?;
    let remote_host = remote_host
        .map(|host| host.trim().to_string())
        .filter(|host| !host.is_empty());
    fs::create_dir_all(&evidence_dir)
        .with_context(|| format!("create preflight evidence dir {}", evidence_dir.display()))?;

    let doctor = run_doctor(&target, &evidence_dir)?;
    let files = vec![
        file_check(
            &target,
            "approved design",
            "docs/remote-workhorse/0xvox-unknown-design-20260502-222759.md",
        ),
        file_check(
            &target,
            "context summary",
            "docs/remote-workhorse/CONTEXT-2026-05-02-evening.md",
        ),
        file_check(&target, "tool registry", "config/tool-registry.toml"),
        file_check(&target, "flake scaffold", "flake.nix"),
        file_check(
            &target,
            "Research Vault proof",
            "docs/remote-workhorse/phase1/RESEARCH_VAULT_PROOF.json",
        ),
        file_check(
            &target,
            "code-review-graph proof",
            "docs/remote-workhorse/phase1/CODE_REVIEW_GRAPH_PROOF.json",
        ),
        file_check(
            &target,
            "external index",
            "docs/external-indexes/frontier-runtime-repos.md",
        ),
        file_check(
            &target,
            "DigitalOcean capability map",
            "docs/remote-workhorse/preflight/DIGITALOCEAN_CAPABILITY_MAP.md",
        ),
    ];
    let mut probes = vec![
        run_probe("just_list", "just", ["--list"], &target),
        run_probe("doctl_auth_list", "doctl", ["auth", "list"], &target),
        run_doctl_probe(
            "doctl_account_status",
            &["account", "get", "--format", "Status", "--no-header"],
            &target,
        ),
        run_doctl_probe(
            "doctl_account_ratelimit",
            &[
                "account",
                "ratelimit",
                "--format",
                "Remaining,Reset",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_regions",
            &[
                "compute",
                "region",
                "list",
                "--format",
                "Slug,Available",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_sizes",
            &[
                "compute",
                "size",
                "list",
                "--format",
                "Slug,Memory,VCPUs,Disk,PriceMonthly",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_droplets",
            &[
                "compute",
                "droplet",
                "list",
                "--format",
                "ID,Name,PublicIPv4,PrivateIPv4,Region,Image,Status,Tags,Features,Volumes",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_gpu_droplets",
            &[
                "compute",
                "droplet",
                "list",
                "--gpus",
                "--format",
                "ID,Name,PublicIPv4,Region,Image,Status,Features",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_ssh_keys",
            &[
                "compute",
                "ssh-key",
                "list",
                "--format",
                "ID,Name,FingerPrint",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_snapshots",
            &[
                "compute",
                "snapshot",
                "list",
                "--format",
                "ID,Name,CreatedAt,Regions,ResourceId,ResourceType,MinDiskSize,Size,Tags",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_images_private",
            &[
                "compute",
                "image",
                "list",
                "--format",
                "ID,Name,Type,Distribution,Slug,Public,MinDisk",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_images_public",
            &[
                "compute",
                "image",
                "list",
                "--public",
                "--format",
                "ID,Name,Distribution,Slug,Public,MinDisk",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_firewalls",
            &[
                "compute",
                "firewall",
                "list",
                "--format",
                "ID,Name,Status,DropletIDs,Tags,PendingChanges",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_volumes",
            &[
                "compute",
                "volume",
                "list",
                "--format",
                "ID,Name,Size,Region,DropletIDs,Tags",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_projects",
            &[
                "projects",
                "list",
                "--format",
                "ID,Name,Purpose,Environment,IsDefault",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_apps",
            &[
                "apps",
                "list",
                "--format",
                "ID,Spec.Name,DefaultIngress,ActiveDeployment.ID,Updated",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_databases",
            &[
                "databases",
                "list",
                "--format",
                "ID,Name,Engine,Version,Region,Status,Size,StorageMib",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_vpcs",
            &[
                "vpcs",
                "list",
                "--format",
                "ID,Name,IPRange,Region,Default",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_load_balancers",
            &[
                "compute",
                "load-balancer",
                "list",
                "--format",
                "ID,Name,IP,IPv6,Status,Region,VPCUUID,DropletIDs,HealthCheck",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_reserved_ips",
            &[
                "compute",
                "reserved-ip",
                "list",
                "--format",
                "IP,Region,DropletID,DropletName,ProjectID",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_tags",
            &[
                "compute",
                "tag",
                "list",
                "--format",
                "Name,DropletCount",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_registries",
            &[
                "registries",
                "list",
                "--format",
                "Name,Endpoint,Region",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_monitoring_alerts",
            &[
                "monitoring",
                "alert",
                "list",
                "--format",
                "UUID,Type,Description,Entities,Tags,Emails,Enabled",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_uptime_checks",
            &[
                "monitoring",
                "uptime",
                "list",
                "--format",
                "ID,Name,Type,Target,Regions,Enabled",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_gradient_regions",
            &[
                "gradient",
                "list-regions",
                "--format",
                "Region,ServesInference,ServesBatch",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_gradient_models",
            &[
                "gradient",
                "list-models",
                "--format",
                "Id,Name,isFoundational,Version",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_gradient_agents",
            &[
                "gradient",
                "agent",
                "list",
                "--format",
                "Id,Name,Region,Model-id,Project-id",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_gradient_knowledge_bases",
            &[
                "gradient",
                "knowledge-base",
                "list",
                "--format",
                "UUID,Name,Region,ProjectId,DatabaseId,IsPublic,LastIndexingJob",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_dedicated_inference_endpoints",
            &[
                "dedicated-inference",
                "list",
                "--format",
                "ID,Name,Region,Status,VPCUUID,PublicEndpoint,PrivateEndpoint",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_dedicated_inference_sizes",
            &[
                "dedicated-inference",
                "get-sizes",
                "--format",
                "GPUSlug,PricePerHour,CPU,Memory,GPUCount,GPUVramGB,GPUModel,Regions",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_dedicated_inference_model_config",
            &[
                "dedicated-inference",
                "get-gpu-model-config",
                "--format",
                "ModelSlug,ModelName,IsModelGated,GPUSlugs",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_serverless_namespaces",
            &[
                "serverless",
                "namespaces",
                "list",
                "--format",
                "Label,Region,ID,Host",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_nfs_atl1",
            &[
                "nfs",
                "list",
                "--region",
                "atl1",
                "--format",
                "ID,Name,Size,Region,Status,VpcIDs",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_nfs_nyc2",
            &[
                "nfs",
                "list",
                "--region",
                "nyc2",
                "--format",
                "ID,Name,Size,Region,Status,VpcIDs",
                "--no-header",
            ],
            &target,
        ),
        run_doctl_probe(
            "doctl_nfs_ams3",
            &[
                "nfs",
                "list",
                "--region",
                "ams3",
                "--format",
                "ID,Name,Size,Region,Status,VpcIDs",
                "--no-header",
            ],
            &target,
        ),
    ];
    if let Some(host) = remote_host.as_deref() {
        probes.push(run_probe(
            "ssh_known_host_lookup",
            "ssh-keygen",
            ["-F", host],
            &target,
        ));
        probes.push(run_probe(
            "ssh_host_keyscan",
            "ssh-keyscan",
            ["-T", "5", host],
            &target,
        ));
    }

    let mut blockers = Vec::new();
    let mut flags = Vec::new();

    if doctor.verdict.status == "BLOCK" {
        blockers.extend(doctor.verdict.reasons.clone());
    } else if doctor.verdict.status == "FLAG" {
        flags.extend(doctor.verdict.reasons.clone());
    }

    for file in &files {
        if !file.exists {
            blockers.push(format!("missing required preflight file: {}", file.path));
        }
    }

    if remote_host.is_none() {
        flags.push(
            "remote host not selected; set WINDBURN_REMOTE_HOST or pass --remote-host before Computer Use"
                .to_string(),
        );
    }

    if probe_status(&probes, "doctl_account_status") != Some("pass") {
        flags.push(
            "DigitalOcean account read probe failed; refresh doctl auth before cloud snapshot/firewall checks"
                .to_string(),
        );
    } else {
        for probe_id in DOCTL_READ_INVENTORY_PROBE_IDS {
            if probe_status(&probes, probe_id) != Some("pass") {
                blockers.push(format!(
                    "DigitalOcean read-only inventory probe failed: {probe_id}"
                ));
            }
        }
    }

    if remote_host.is_some() {
        if probe_status(&probes, "ssh_host_keyscan") != Some("pass") {
            flags.push("remote host identity probe did not pass yet: ssh_host_keyscan".to_string());
        }
    }

    let verdict = canary_verdict(blockers, flags);
    let evidence = RemotePreflightEvidence {
        schema_version: 1,
        generated_at_utc: now_utc(),
        target: target.display().to_string(),
        remote_host,
        doctor,
        files,
        probes,
        verdict,
    };

    write_json(&evidence_dir.join("preflight.json"), &evidence)?;
    if let Some(parent) = report.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("create preflight report dir {}", parent.display()))?;
    }
    fs::write(&report, render_preflight_report(&evidence))
        .with_context(|| format!("write preflight report {}", report.display()))?;
    Ok(evidence)
}

fn file_check(target: &Path, label: &str, relative_path: &str) -> FileCheck {
    let path = target.join(relative_path);
    FileCheck {
        label: label.to_string(),
        path: relative_path.to_string(),
        exists: path.is_file(),
    }
}

fn collect_git(target: &Path) -> GitEvidence {
    let top_level = command_text("git", ["rev-parse", "--show-toplevel"], target);
    if top_level.is_none() {
        return GitEvidence {
            is_repo: false,
            top_level: None,
            branch: None,
            head: None,
            status_short: None,
            error: Some("git rev-parse --show-toplevel failed".to_string()),
        };
    }

    GitEvidence {
        is_repo: true,
        top_level,
        branch: command_text("git", ["branch", "--show-current"], target),
        head: command_text("git", ["rev-parse", "--short", "HEAD"], target),
        status_short: command_text("git", ["status", "--short", "--branch"], target),
        error: None,
    }
}

fn classify_doctor(git: &GitEvidence, probes: &[CommandProbe]) -> Verdict {
    let mut blockers = Vec::new();
    let mut flags = Vec::new();

    if !git.is_repo {
        blockers.push("target is not a git repository".to_string());
    }

    for required in [
        "codex_version",
        "codex_mcp_list",
        "cargo_version",
        "rustc_version",
    ] {
        if probe_status(probes, required) != Some("pass") {
            blockers.push(format!("required probe failed: {required}"));
        }
    }

    for optional in ["just_version", "doctl_version"] {
        if probe_status(probes, optional) != Some("pass") {
            flags.push(format!(
                "frontier/runtime tool not installed locally yet: {optional}"
            ));
        }
    }

    canary_verdict(blockers, flags)
}

fn canary_verdict(blockers: Vec<String>, flags: Vec<String>) -> Verdict {
    if !blockers.is_empty() {
        Verdict {
            status: "BLOCK".to_string(),
            reasons: blockers,
        }
    } else if !flags.is_empty() {
        Verdict {
            status: "FLAG".to_string(),
            reasons: flags,
        }
    } else {
        Verdict {
            status: "PASS".to_string(),
            reasons: vec!["all Phase 1 canary checks passed".to_string()],
        }
    }
}

fn probe_status<'a>(probes: &'a [CommandProbe], id: &str) -> Option<&'a str> {
    probes
        .iter()
        .find(|probe| probe.id == id)
        .map(|probe| probe.status.as_str())
}

fn run_probe<I, S>(id: &str, program: &str, args: I, cwd: &Path) -> CommandProbe
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let args_vec: Vec<String> = args
        .into_iter()
        .map(|arg| arg.as_ref().to_string_lossy().into_owned())
        .collect();
    let mut command = Command::new(program);
    command.args(&args_vec).current_dir(cwd);

    match command.output() {
        Ok(output) => CommandProbe {
            id: id.to_string(),
            command: std::iter::once(program.to_string())
                .chain(args_vec)
                .collect(),
            status: if output.status.success() {
                "pass".to_string()
            } else {
                "fail".to_string()
            },
            exit_code: output.status.code(),
            stdout: clean_text(&output.stdout),
            stderr: clean_text(&output.stderr),
        },
        Err(error) if error.kind() == io::ErrorKind::NotFound => CommandProbe {
            id: id.to_string(),
            command: std::iter::once(program.to_string())
                .chain(args_vec)
                .collect(),
            status: "missing".to_string(),
            exit_code: None,
            stdout: String::new(),
            stderr: error.to_string(),
        },
        Err(error) => CommandProbe {
            id: id.to_string(),
            command: std::iter::once(program.to_string())
                .chain(args_vec)
                .collect(),
            status: "error".to_string(),
            exit_code: None,
            stdout: String::new(),
            stderr: error.to_string(),
        },
    }
}

fn run_doctl_probe(id: &str, args: &[&str], cwd: &Path) -> CommandProbe {
    let token = doctl_access_token_from_env();
    let token_ref = token.as_ref().map(|(name, value)| (*name, value.as_str()));
    let (actual_args, display_command) = doctl_args_with_optional_token(args, token_ref);

    let mut command = Command::new("doctl");
    command.args(&actual_args).current_dir(cwd);

    match command.output() {
        Ok(output) => {
            let mut status = if output.status.success() {
                "pass".to_string()
            } else {
                "fail".to_string()
            };
            let mut stderr = clean_text(&output.stderr);
            if !output.status.success() && is_known_doctl_tool_bug(id, &stderr) {
                status = "tool_bug".to_string();
                stderr = "doctl 1.155.0 Gradient pagination bug: command panicked while listing an empty or inaccessible collection; keep this advisory and use the DigitalOcean API/MCP or a newer doctl before depending on this inventory.".to_string();
            }
            CommandProbe {
                id: id.to_string(),
                command: display_command,
                status,
                exit_code: output.status.code(),
                stdout: clean_text(&output.stdout),
                stderr,
            }
        }
        Err(error) if error.kind() == io::ErrorKind::NotFound => CommandProbe {
            id: id.to_string(),
            command: display_command,
            status: "missing".to_string(),
            exit_code: None,
            stdout: String::new(),
            stderr: error.to_string(),
        },
        Err(error) => CommandProbe {
            id: id.to_string(),
            command: display_command,
            status: "error".to_string(),
            exit_code: None,
            stdout: String::new(),
            stderr: error.to_string(),
        },
    }
}

fn is_known_doctl_tool_bug(id: &str, stderr: &str) -> bool {
    matches!(
        id,
        "doctl_gradient_agents" | "doctl_gradient_knowledge_bases"
    ) && stderr.contains("panic: runtime error: index out of range")
        && stderr.contains("github.com/digitalocean/doctl/do.PaginateResp")
}

fn doctl_access_token_from_env() -> Option<(&'static str, String)> {
    [
        "DIGITALOCEAN_ACCESS_TOKEN",
        "DIGITALOCEAN_TOKEN",
        "DOCTL_ACCESS_TOKEN",
    ]
    .into_iter()
    .find_map(|name| {
        std::env::var(name)
            .ok()
            .filter(|value| !value.trim().is_empty())
            .map(|value| (name, value))
    })
}

fn doctl_args_with_optional_token(
    args: &[&str],
    token_env: Option<(&str, &str)>,
) -> (Vec<String>, Vec<String>) {
    let mut actual_args = Vec::new();
    let mut display_command = vec!["doctl".to_string()];

    if let Some((name, token)) = token_env.filter(|(_, token)| !token.trim().is_empty()) {
        actual_args.push("--access-token".to_string());
        actual_args.push(token.to_string());
        display_command.push("--access-token".to_string());
        display_command.push(format!("${name}"));
    }

    actual_args.extend(args.iter().map(|arg| (*arg).to_string()));
    display_command.extend(args.iter().map(|arg| (*arg).to_string()));

    (actual_args, display_command)
}

fn command_text<I, S>(program: &str, args: I, cwd: &Path) -> Option<String>
where
    I: IntoIterator<Item = S>,
    S: AsRef<OsStr>,
{
    let output = Command::new(program)
        .args(args)
        .current_dir(cwd)
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let text = clean_text(&output.stdout);
    (!text.is_empty()).then_some(text)
}

fn clean_text(bytes: &[u8]) -> String {
    let text = String::from_utf8_lossy(bytes).trim().to_string();
    if text.len() > 12_000 {
        format!("{}...[truncated]", &text[..12_000])
    } else {
        text
    }
}

fn require_file(path: &Path, label: &str, blockers: &mut Vec<String>, notes: &mut Vec<String>) {
    if path.is_file() {
        notes.push(format!("{label}: {}", path.display()));
    } else {
        blockers.push(format!("missing {label}: {}", path.display()));
    }
}

fn read_json_value(path: &Path) -> Result<Option<Value>> {
    if !path.is_file() {
        return Ok(None);
    }
    let data = fs::read_to_string(path).with_context(|| format!("read {}", path.display()))?;
    let value = serde_json::from_str(&data).with_context(|| format!("parse {}", path.display()))?;
    Ok(Some(value))
}

fn json_str<'a>(value: &'a Value, pointer: &str) -> Option<&'a str> {
    value.pointer(pointer).and_then(Value::as_str)
}

fn json_bool(value: &Value, pointer: &str) -> Option<bool> {
    value.pointer(pointer).and_then(Value::as_bool)
}

fn json_u64(value: &Value, pointer: &str) -> Option<u64> {
    value.pointer(pointer).and_then(Value::as_u64)
}

fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).with_context(|| format!("create {}", parent.display()))?;
    }
    let mut data = serde_json::to_vec_pretty(value)?;
    data.push(b'\n');
    fs::write(path, data).with_context(|| format!("write {}", path.display()))
}

fn absolutize(path: &Path) -> Result<PathBuf> {
    if path.is_absolute() {
        Ok(path.to_path_buf())
    } else {
        Ok(std::env::current_dir()
            .context("read current dir")?
            .join(path))
    }
}

fn now_utc() -> String {
    OffsetDateTime::now_utc()
        .format(&Rfc3339)
        .unwrap_or_else(|_| "unknown".to_string())
}

fn render_canary_report(doctor: &DoctorEvidence, verdict: &Verdict, notes: &[String]) -> String {
    let mut body = String::new();
    body.push_str("# CANARY-read-only-repo-review-health\n\n");
    body.push_str(&format!("Generated: `{}`\n\n", doctor.generated_at_utc));
    body.push_str(&format!("Target: `{}`\n\n", doctor.target));
    body.push_str(&format!("Host: `{}`\n\n", doctor.host));
    body.push_str(&format!("VERDICT: `{}`\n\n", verdict.status));
    body.push_str("## Verdict Reasons\n\n");
    for reason in &verdict.reasons {
        body.push_str(&format!("- {reason}\n"));
    }
    body.push_str("\n## Evidence\n\n");
    body.push_str(&format!(
        "- Git repo: `{}` branch `{}` run-time head `{}`\n",
        doctor.git.top_level.as_deref().unwrap_or("missing"),
        doctor.git.branch.as_deref().unwrap_or("unknown"),
        doctor.git.head.as_deref().unwrap_or("unknown")
    ));
    for note in notes {
        body.push_str(&format!("- {note}\n"));
    }
    body.push_str(
        "- Generated doctor JSON: `docs/remote-workhorse/phase1/evidence/current/doctor.json`\n",
    );
    body.push_str("\n## Probe Summary\n\n");
    for probe in &doctor.probes {
        body.push_str(&format!(
            "- `{}`: `{}` exit `{:?}`\n",
            probe.id, probe.status, probe.exit_code
        ));
    }
    body.push_str("\n## Next Repair Cards\n\n");
    if verdict.status == "PASS" {
        body.push_str("- None.\n");
    } else {
        let mut wrote_repair = false;
        if verdict
            .reasons
            .iter()
            .any(|reason| reason.contains("code-review-graph"))
        {
            body.push_str("- Register this repository in code-review-graph before making graph-dependent review claims.\n");
            wrote_repair = true;
        }
        if verdict
            .reasons
            .iter()
            .any(|reason| reason.contains("Research Vault"))
        {
            body.push_str(
                "- Add a durable Research Vault note for the accepted Remote Workhorse design.\n",
            );
            wrote_repair = true;
        }
        if verdict.reasons.iter().any(|reason| {
            reason.contains("nix_version")
                || reason.contains("Nix Store")
                || reason.contains("/nix")
                || reason.contains("just_version")
                || reason.contains("doctl_version")
        }) {
            body.push_str("- Activate or repair local Nix, and install just/doctl before claiming full remote workhorse readiness.\n");
            wrote_repair = true;
        }
        if !wrote_repair {
            body.push_str("- Inspect verdict reasons and add a concrete owner/action repair card before continuing.\n");
        }
    }
    body
}

fn render_preflight_report(evidence: &RemotePreflightEvidence) -> String {
    let mut body = String::new();
    let cloud_inventory_passes = DOCTL_READ_INVENTORY_PROBE_IDS
        .iter()
        .filter(|probe_id| probe_status(&evidence.probes, probe_id) == Some("pass"))
        .count();
    let managed_service_passes = DOCTL_MANAGED_SERVICE_PROBE_IDS
        .iter()
        .filter(|probe_id| probe_status(&evidence.probes, probe_id) == Some("pass"))
        .count();

    body.push_str("# REMOTE_NIXOS_PREFLIGHT\n\n");
    body.push_str(&format!("Generated: `{}`\n\n", evidence.generated_at_utc));
    body.push_str(&format!("Target: `{}`\n\n", evidence.target));
    body.push_str(&format!(
        "Remote Host: `{}`\n\n",
        evidence.remote_host.as_deref().unwrap_or("unset")
    ));
    body.push_str(&format!("VERDICT: `{}`\n\n", evidence.verdict.status));

    body.push_str("## Verdict Reasons\n\n");
    for reason in &evidence.verdict.reasons {
        body.push_str(&format!("- {reason}\n"));
    }

    body.push_str("\n## Gates\n\n");
    body.push_str("| Gate | Status | Evidence |\n");
    body.push_str("| --- | --- | --- |\n");
    body.push_str(&format!(
        "| Local conductor doctor | `{}` | `docs/remote-workhorse/preflight/evidence/current/doctor.json` |\n",
        evidence.doctor.verdict.status
    ));
    body.push_str(&format!(
        "| Required files | `{}` | `{}/{} present` |\n",
        if evidence.files.iter().all(|file| file.exists) {
            "PASS"
        } else {
            "BLOCK"
        },
        evidence.files.iter().filter(|file| file.exists).count(),
        evidence.files.len()
    ));
    body.push_str(&format!(
        "| DigitalOcean read auth | `{}` | `doctl_account_status` |\n",
        probe_status(&evidence.probes, "doctl_account_status").unwrap_or("missing")
    ));
    body.push_str(&format!(
        "| DigitalOcean read-only inventory | `{}` | `{}/{} probes passed` |\n",
        if cloud_inventory_passes == DOCTL_READ_INVENTORY_PROBE_IDS.len() {
            "PASS"
        } else if probe_status(&evidence.probes, "doctl_account_status") == Some("pass") {
            "BLOCK"
        } else {
            "PENDING"
        },
        cloud_inventory_passes,
        DOCTL_READ_INVENTORY_PROBE_IDS.len()
    ));
    body.push_str(&format!(
        "| DigitalOcean managed-service reconnaissance | `{}` | `{}/{} advisory probes passed` |\n",
        if managed_service_passes == DOCTL_MANAGED_SERVICE_PROBE_IDS.len() {
            "PASS"
        } else if probe_status(&evidence.probes, "doctl_account_status") == Some("pass") {
            "PARTIAL"
        } else {
            "PENDING"
        },
        managed_service_passes,
        DOCTL_MANAGED_SERVICE_PROBE_IDS.len()
    ));
    body.push_str(&format!(
        "| Remote host selected | `{}` | `{}` |\n",
        if evidence.remote_host.is_some() {
            "PASS"
        } else {
            "FLAG"
        },
        evidence.remote_host.as_deref().unwrap_or("unset")
    ));
    if evidence.remote_host.is_some() {
        body.push_str(&format!(
            "| SSH host key scan | `{}` | `ssh_host_keyscan` |\n",
            probe_status(&evidence.probes, "ssh_host_keyscan").unwrap_or("missing")
        ));
    }
    body.push_str("| Computer Use mutation gate | `PENDING` | Run only after this preflight is PASS or consciously accepted. |\n");
    body.push_str("| Remote NixOS mutation gate | `PENDING` | First remote command must be read-only host/OS/Nix proof. |\n");

    body.push_str("\n## Local Probe Summary\n\n");
    for probe in &evidence.doctor.probes {
        body.push_str(&format!(
            "- `{}`: `{}` exit `{:?}`\n",
            probe.id, probe.status, probe.exit_code
        ));
    }

    body.push_str("\n## Cloud Probe Summary\n\n");
    for probe in &evidence.probes {
        body.push_str(&format!(
            "- `{}`: `{}` exit `{:?}`\n",
            probe.id, probe.status, probe.exit_code
        ));
    }

    body.push_str("\n## DigitalOcean Read-Only Command Set\n\n");
    body.push_str("These commands are intentionally non-mutating and were cross-checked against the local `doctl 1.155.0` help output after consulting DigitalOcean Ask Docs.\n\n");
    body.push_str("- Auth context list: `doctl auth list`\n");
    body.push_str("- Account status: `doctl account get --format Status --no-header`\n");
    body.push_str(
        "- API rate limit: `doctl account ratelimit --format Remaining,Reset --no-header`\n",
    );
    body.push_str("- Regions: `doctl compute region list --format Slug,Available --no-header`\n");
    body.push_str("- Sizes: `doctl compute size list --format Slug,Memory,VCPUs,Disk,PriceMonthly --no-header`\n");
    body.push_str("- Droplets: `doctl compute droplet list --format ID,Name,PublicIPv4,PrivateIPv4,Region,Image,Status,Tags,Features,Volumes --no-header`\n");
    body.push_str("- GPU Droplets: `doctl compute droplet list --gpus --format ID,Name,PublicIPv4,Region,Image,Status,Features --no-header`\n");
    body.push_str(
        "- SSH keys: `doctl compute ssh-key list --format ID,Name,FingerPrint --no-header`\n",
    );
    body.push_str("- Snapshots: `doctl compute snapshot list --format ID,Name,CreatedAt,Regions,ResourceId,ResourceType,MinDiskSize,Size,Tags --no-header`\n");
    body.push_str("- Private images: `doctl compute image list --format ID,Name,Type,Distribution,Slug,Public,MinDisk --no-header`\n");
    body.push_str("- Public images: `doctl compute image list --public --format ID,Name,Distribution,Slug,Public,MinDisk --no-header`\n");
    body.push_str("- Firewalls: `doctl compute firewall list --format ID,Name,Status,DropletIDs,Tags,PendingChanges --no-header`\n");
    body.push_str("- Volumes: `doctl compute volume list --format ID,Name,Size,Region,DropletIDs,Tags --no-header`\n");
    body.push_str("- Host key proof, after a host is selected: `ssh-keyscan -T 5 <host>` and optional `ssh-keygen -F <host>` lookup.\n");

    body.push_str("\n## DigitalOcean Managed-Service Reconnaissance\n\n");
    body.push_str("These probes are read-only and advisory. They map DigitalOcean's managed services into the workhorse plan without creating, updating, or deleting resources.\n\n");
    body.push_str("- Projects: `doctl projects list --format ID,Name,Purpose,Environment,IsDefault --no-header`\n");
    body.push_str("- App Platform: `doctl apps list --format ID,Spec.Name,DefaultIngress,ActiveDeployment.ID,Updated --no-header`\n");
    body.push_str("- Managed Databases: `doctl databases list --format ID,Name,Engine,Version,Region,Status,Size,StorageMib --no-header`\n");
    body.push_str(
        "- VPCs: `doctl vpcs list --format ID,Name,IPRange,Region,Default --no-header`\n",
    );
    body.push_str("- Load Balancers: `doctl compute load-balancer list --format ID,Name,IP,IPv6,Status,Region,VPCUUID,DropletIDs,HealthCheck --no-header`\n");
    body.push_str("- Reserved IPs: `doctl compute reserved-ip list --format IP,Region,DropletID,DropletName,ProjectID --no-header`\n");
    body.push_str("- Tags: `doctl compute tag list --format Name,DropletCount --no-header`\n");
    body.push_str(
        "- Container Registry: `doctl registries list --format Name,Endpoint,Region --no-header`\n",
    );
    body.push_str("- Monitoring alerts: `doctl monitoring alert list --format UUID,Type,Description,Entities,Tags,Emails,Enabled --no-header`\n");
    body.push_str("- Uptime checks: `doctl monitoring uptime list --format ID,Name,Type,Target,Regions,Enabled --no-header`\n");
    body.push_str("- Gradient regions: `doctl gradient list-regions --format Region,ServesInference,ServesBatch --no-header`\n");
    body.push_str("- Gradient models: `doctl gradient list-models --format Id,Name,isFoundational,Version --no-header`\n");
    body.push_str("- Gradient agents: `doctl gradient agent list --format Id,Name,Region,Model-id,Project-id --no-header`\n");
    body.push_str("- Gradient knowledge bases: `doctl gradient knowledge-base list --format UUID,Name,Region,ProjectId,DatabaseId,IsPublic,LastIndexingJob --no-header`\n");
    body.push_str("- Dedicated inference endpoints: `doctl dedicated-inference list --format ID,Name,Region,Status,VPCUUID,PublicEndpoint,PrivateEndpoint --no-header`\n");
    body.push_str("- Dedicated inference sizes: `doctl dedicated-inference get-sizes --format GPUSlug,PricePerHour,CPU,Memory,GPUCount,GPUVramGB,GPUModel,Regions --no-header`\n");
    body.push_str("- Dedicated inference model fit: `doctl dedicated-inference get-gpu-model-config --format ModelSlug,ModelName,IsModelGated,GPUSlugs --no-header`\n");
    body.push_str("- Serverless namespaces: `doctl serverless namespaces list --format Label,Region,ID,Host --no-header`\n");
    body.push_str("- Network File Storage by candidate region: `doctl nfs list --region <region> --format ID,Name,Size,Region,Status,VpcIDs --no-header`\n");
    body.push_str("- Spaces bucket inventory is not covered by this `doctl 1.155.0` gate because the local CLI only exposes Spaces access-key commands; use S3-compatible tooling or MCP/API after explicit scope selection.\n");

    body.push_str("\n## Auth Boundary\n\n");
    body.push_str("- `runtimectl preflight` uses the first non-empty token from `DIGITALOCEAN_ACCESS_TOKEN`, `DIGITALOCEAN_TOKEN`, or `DOCTL_ACCESS_TOKEN` for read-only `doctl` probes, and records only the variable name in evidence.\n");
    body.push_str("- `doctl auth init --context <name>` stores a persistent local context and requires action-time confirmation before we run it.\n");
    body.push_str("- `doctl --access-token <token> ...` can run one command without initializing a context, but the token must never be pasted into chat or evidence.\n");
    body.push_str("- Current preflight artifacts may contain cloud inventory such as Droplet IDs and IPs once auth works; keep them local unless explicitly redacted for sharing.\n");

    body.push_str("\n## DigitalOcean Rollback Gotchas\n\n");
    body.push_str("- Rebuilds can change SSH host keys; capture the new key with `ssh-keyscan`, and only clean stale `known_hosts` entries deliberately.\n");
    body.push_str("- Firewall rules must preserve SSH and outbound HTTPS for Nix downloads before attaching them to the host.\n");
    body.push_str("- Snapshot/image/volume evidence must exist before persistent NixOS mutation; never delete snapshot candidates during preflight.\n");
    body.push_str("- Size, region, GPU image, backups, monitoring agent, private networking, and volume limits should be checked from read-only inventory before create/update operations.\n");

    body.push_str("\n## Computer Use Entry Rules\n\n");
    body.push_str("- Start read-only: host identity, OS release, kernel, uptime, disk, memory, users, services.\n");
    body.push_str("- Capture command, exit status, and artifact path for every step.\n");
    body.push_str("- Take cloud snapshot/backout evidence before any persistent NixOS mutation.\n");
    body.push_str("- Use `nixos-rebuild test` before `switch`; preserve rollback path.\n");
    body.push_str(
        "- Stop on unknown credentials, missing target host, dirty repo, or absent backout plan.\n",
    );
    body
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canary_blocks_before_flags() {
        let verdict = canary_verdict(vec!["missing proof".into()], vec!["optional".into()]);
        assert_eq!(verdict.status, "BLOCK");
        assert_eq!(verdict.reasons, vec!["missing proof"]);
    }

    #[test]
    fn canary_flags_when_no_blockers() {
        let verdict = canary_verdict(Vec::new(), vec!["graph empty".into()]);
        assert_eq!(verdict.status, "FLAG");
    }

    #[test]
    fn doctor_blocks_without_git_repo() {
        let git = GitEvidence {
            is_repo: false,
            top_level: None,
            branch: None,
            head: None,
            status_short: None,
            error: Some("no repo".into()),
        };
        let probes = required_probe_set("pass");
        let verdict = classify_doctor(&git, &probes);
        assert_eq!(verdict.status, "BLOCK");
    }

    #[test]
    fn doctor_flags_missing_optional_tools() {
        let git = GitEvidence {
            is_repo: true,
            top_level: Some("/tmp/repo".into()),
            branch: Some("main".into()),
            head: Some("abc123".into()),
            status_short: Some("## main".into()),
            error: None,
        };
        let mut probes = vec![
            fake_probe("codex_version", "pass"),
            fake_probe("codex_mcp_list", "pass"),
            fake_probe("cargo_version", "pass"),
            fake_probe("rustc_version", "pass"),
        ];
        probes.push(fake_probe("nix_version", "missing"));
        probes.push(fake_probe("nix_store_volume", "missing"));
        probes.push(fake_probe("nix_profile_volume", "missing"));
        probes.push(fake_probe("nix_root_mount", "missing"));
        probes.push(fake_probe("just_version", "missing"));
        probes.push(fake_probe("doctl_version", "missing"));
        let verdict = classify_doctor(&git, &probes);
        assert_eq!(verdict.status, "FLAG");
    }

    #[test]
    fn doctor_treats_local_nix_as_optional_accelerator() {
        let git = GitEvidence {
            is_repo: true,
            top_level: Some("/tmp/repo".into()),
            branch: Some("main".into()),
            head: Some("abc123".into()),
            status_short: Some("## main".into()),
            error: None,
        };
        let probes = vec![
            fake_probe("codex_version", "pass"),
            fake_probe("codex_mcp_list", "pass"),
            fake_probe("cargo_version", "pass"),
            fake_probe("rustc_version", "pass"),
            fake_probe("nix_version", "missing"),
            fake_probe("nix_store_volume", "pass"),
            fake_probe("nix_profile_volume", "pass"),
            fake_probe("nix_root_mount", "missing"),
            fake_probe("just_version", "pass"),
            fake_probe("doctl_version", "pass"),
        ];
        let verdict = classify_doctor(&git, &probes);
        assert_eq!(verdict.status, "PASS");
        assert!(
            !verdict
                .reasons
                .iter()
                .any(|reason| reason.contains("Nix Store volume"))
        );
        assert!(
            !verdict
                .reasons
                .iter()
                .any(|reason| reason.contains("not installed locally yet: nix_version"))
        );
    }

    #[test]
    fn doctl_token_command_redacts_secret_in_evidence() {
        let (actual_args, display_command) = doctl_args_with_optional_token(
            &["account", "get"],
            Some(("DIGITALOCEAN_ACCESS_TOKEN", "dop_v1_secret")),
        );

        assert_eq!(
            actual_args,
            vec!["--access-token", "dop_v1_secret", "account", "get"]
        );
        assert_eq!(
            display_command,
            vec![
                "doctl",
                "--access-token",
                "$DIGITALOCEAN_ACCESS_TOKEN",
                "account",
                "get",
            ]
        );
        assert!(
            !display_command
                .iter()
                .any(|part| part.contains("dop_v1_secret"))
        );
    }

    #[test]
    fn doctl_token_command_uses_ambient_context_when_env_missing() {
        let (actual_args, display_command) =
            doctl_args_with_optional_token(&["account", "get"], None);

        assert_eq!(actual_args, vec!["account", "get"]);
        assert_eq!(display_command, vec!["doctl", "account", "get"]);
    }

    #[test]
    fn doctl_gradient_pagination_panic_is_known_tool_bug() {
        let stderr = "panic: runtime error: index out of range [0] with length 0\n\
github.com/digitalocean/doctl/do.PaginateResp(...)";

        assert!(is_known_doctl_tool_bug("doctl_gradient_agents", stderr));
        assert!(is_known_doctl_tool_bug(
            "doctl_gradient_knowledge_bases",
            stderr
        ));
        assert!(!is_known_doctl_tool_bug("doctl_regions", stderr));
        assert!(!is_known_doctl_tool_bug(
            "doctl_gradient_agents",
            "Error: access token is required"
        ));
    }

    fn required_probe_set(status: &str) -> Vec<CommandProbe> {
        vec![
            fake_probe("codex_version", status),
            fake_probe("codex_mcp_list", status),
            fake_probe("cargo_version", status),
            fake_probe("rustc_version", status),
            fake_probe("nix_version", status),
            fake_probe("nix_store_volume", status),
            fake_probe("nix_profile_volume", status),
            fake_probe("nix_root_mount", status),
            fake_probe("just_version", status),
            fake_probe("doctl_version", status),
        ]
    }

    fn fake_probe(id: &str, status: &str) -> CommandProbe {
        CommandProbe {
            id: id.to_string(),
            command: vec![id.to_string()],
            status: status.to_string(),
            exit_code: Some(0),
            stdout: String::new(),
            stderr: String::new(),
        }
    }
}
