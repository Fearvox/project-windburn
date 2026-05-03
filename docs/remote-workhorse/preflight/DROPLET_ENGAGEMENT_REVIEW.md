# Droplet Engagement Review

Generated: `2026-05-03T17:12:49Z`

Target repo: `/Users/0xvox/Windburn`

VERDICT: `FLAG`

## Contract

This is a read-only droplet engagement review. It does not restart services,
change firewall rules, edit cloud resources, sync secrets, or mutate remote
runtime state. It uses temporary SSH host-key files and prints sanitized process
counts/listeners instead of raw task transcripts.

## Summary

| Surface | Status | Evidence |
| --- | --- | --- |
| DigitalOcean control plane | `PASS` | account_status=active |
| DigitalOcean uptime checks | `FLAG` | no uptime checks returned |
| DigitalOcean monitoring alerts | `FLAG` | no monitoring alerts returned |
| CCR public route | `FLAG` | curl: (7) Failed to connect to 165.232.146.188 port 8888 after 75 ms: Couldn't connect to server |
| `ccr-droplet` internal embedding route | `PASS_INTERNAL` | SSH + `http://100.65.234.77:8080/v1/models` + embeddings smoke |
| `hermes-nyc1` task/MCP engagement | `ENGAGED_FLAG_HEALTH_GATE` | Hermes gateway/process/MCP counts over SSH |
| `windburn-workhorse-nyc1` foundation health | `FOUNDATION_ONLY` | health timer + current health JSON over SSH |
| code-review-graph freshness | `FLAG` | proof_commit=227a3a66d124; head=e0153b0876af; dirty_files=10 |

## Droplets

| Name | Host | Expected role | Current review |
| --- | --- | --- | --- |
| `ccr-droplet` | `165.232.146.188` | CCR/RV embedding node | Internal embedding API is the trusted route; public `:8888` is only a legacy canary unless restored. |
| `hermes-nyc1` | `137.184.104.26` | Hermes/Multica/RV task lane | Engaged when gateway plus Hermes, Multica, or Research Vault MCP process counts are non-zero; still needs a dedicated health gate. |
| `windburn-workhorse-nyc1` | `24.144.113.25` | NixOS workhorse foundation | Healthy foundation when timer and health JSON are fresh; not counted as task-engaged until a runner/MCP process appears. |

## DigitalOcean Evidence

```text
status=PASS
account_status=active
```

### Droplet Inventory

```text
ccr-droplet                165.232.146.188    sfo3    active    CCR,DS,Evensong,Research-Vault-MCP
hermes-nyc1                137.184.104.26     nyc1    active    hermes
windburn-workhorse-nyc1    24.144.113.25      nyc1    active    nixos-candidate,remote-workhorse,windburn
```

### Uptime Checks

```text
no uptime checks returned
```

### Monitoring Alerts

```text
UUID    Type    Description    Compare    Value    Window    Entities    Tags    Emails    Slack Channels    Enabled
```

## CCR Evidence

Public canary:

```text
endpoint=http://165.232.146.188:8888/v1/models
status=FLAG
curl: (7) Failed to connect to 165.232.146.188 port 8888 after 75 ms: Couldn't connect to server
```

Internal SSH/Tailscale canary:

```text
host=ccr-droplet
uptime=up 1 week, 2 days, 10 hours, 34 minutes
bge_m3_embed_service=active
llama_server_service=inactive
llama_server_process_count=1
listener=LISTEN 0      512                  100.65.234.77:8080       0.0.0.0:*    users:[redacted]
models_status=pass
models_sample={"models":[{"name":"bge-m3-Q4_K_M.gguf","model":"bge-m3-Q4_K_M.gguf","modified_at":"","size":"","digest":"","type":"model","description":"","tags":[""],"capabilities":["completion"],"parameters":"","details":{"parent_mod
embeddings_status=pass
embedding_len=1024
```

## Hermes Evidence

```text
host=hermes-nyc1
uptime=up 1 week, 4 days, 10 hours, 54 minutes
hermes_gateway_service=active
multica_service=inactive
do_agent_service=active
droplet_agent_service=active
tailscaled_service=active
hermes_chat_count=5
research_vault_mcp_count=26
multica_daemon_count=1
recent_gateway_warning_count=0
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

## Windburn Workhorse Evidence

```text
host=windburn-workhorse-nyc1
uptime= 17:12:58  up   6:17,  0 users,  load average: 0.02, 0.01, 0.00
os=NixOS 25.11 (Xantusia)
windburn_health_service=inactive
windburn_health_timer=active
failed_units=0
health_file_mtime=2026-05-03 17:10:23.053404637 +0000
health_generated_at_utc=2026-05-03T17:10:22Z
health_system_state=running
health_failed_units=0
hermes_chat_count=0
research_vault_mcp_count=0
listener=LISTEN 0      128          0.0.0.0:22        0.0.0.0:*    users:[redacted]
listener=LISTEN 0      128             [::]:22           [::]:*    users:[redacted]
```

## code-review-graph Evidence

```text
proof_commit=227a3a66d124; head=e0153b0876af; dirty_files=10

Nodes: 41
Edges: 441
Files: 3
Languages: rust, bash
Last updated: 2026-05-03T00:28:22
Built on branch: main
Built at commit: b6a350262f38
```

## Closeout Rule

- `PASS`: cloud control plane works, CCR smoke passes, Hermes has a health
  gate plus task/MCP engagement, Windburn has task-level engagement, uptime
  checks cover the active route, and code-review-graph proof is fresh for the
  current clean HEAD.
- `FLAG`: one or more probes are usable but incomplete, stale, or on a
  fallback route. `FOUNDATION_ONLY` is a FLAG for "every droplet engaged"
  unless the task explicitly accepts foundation-only evidence.
- `BLOCK`: SSH/API access is unavailable for the target lane or a required
  service smoke fails on the only trusted route.

## Rerun

```sh
scripts/droplet-engagement-review.sh --out docs/remote-workhorse/preflight/DROPLET_ENGAGEMENT_REVIEW.md
```
