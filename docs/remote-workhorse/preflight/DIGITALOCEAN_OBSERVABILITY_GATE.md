# DigitalOcean Observability Gate

Generated: `2026-05-03T23:41:50Z`

Mode: `dry-run`

VERDICT: `FLAG`

## Contract

This gate is dry-run by default. Apply mode requires `--apply` plus
`--confirm-do-observability`. It never prints token values or Slack webhook
URLs.

## Desired Uptime Checks

| Name | Droplet ID | Target | Regions |
| --- | --- | --- | --- |
| `windburn-workhorse-nyc1-ping` | `568689911` | `24.144.113.25` | `us_east,us_west,eu_west` |
| `hermes-nyc1-ping` | `566402244` | `137.184.104.26` | `us_east,us_west,eu_west` |
| `ccr-droplet-ping` | `565803713` | `165.232.146.188` | `us_east,us_west,eu_west` |

## Recipient Gate

- email recipients: `absent`
- slack recipients: `absent`

## Current DigitalOcean State

```text
account_status=active

droplets:
565803713    ccr-droplet                165.232.146.188    active    CCR,DS,Evensong,Research-Vault-MCP
566402244    hermes-nyc1                137.184.104.26     active    hermes
568689911    windburn-workhorse-nyc1    24.144.113.25      active    nixos-candidate,remote-workhorse,windburn

uptime_checks:
none

metric_alerts:
UUID    Type    Description    Compare    Value    Window    Entities    Tags    Emails    Slack Channels    Enabled
```

## Flags

- missing uptime check windburn-workhorse-nyc1-ping
- missing alert recipient env for windburn-workhorse-nyc1-ping-down-global
- missing uptime check hermes-nyc1-ping
- missing alert recipient env for hermes-nyc1-ping-down-global
- missing uptime check ccr-droplet-ping
- missing alert recipient env for ccr-droplet-ping-down-global

## Planned Actions

- doctl monitoring uptime create windburn-workhorse-nyc1-ping --target 24.144.113.25 --type ping --regions us_east,us_west,eu_west --enabled true
- set WINDBURN_DO_ALERT_EMAILS or WINDBURN_DO_ALERT_SLACK_CHANNELS + WINDBURN_DO_ALERT_SLACK_URLS
- doctl monitoring uptime create hermes-nyc1-ping --target 137.184.104.26 --type ping --regions us_east,us_west,eu_west --enabled true
- set WINDBURN_DO_ALERT_EMAILS or WINDBURN_DO_ALERT_SLACK_CHANNELS + WINDBURN_DO_ALERT_SLACK_URLS
- doctl monitoring uptime create ccr-droplet-ping --target 165.232.146.188 --type ping --regions us_east,us_west,eu_west --enabled true
- set WINDBURN_DO_ALERT_EMAILS or WINDBURN_DO_ALERT_SLACK_CHANNELS + WINDBURN_DO_ALERT_SLACK_URLS

## Rerun

```sh
scripts/digitalocean-observability.sh --out docs/remote-workhorse/preflight/DIGITALOCEAN_OBSERVABILITY_GATE.md
```
