# Zonic Windburn Console Entry Plan

Status: `draft plan`

This is the public-safe entry plan for a future Windburn console link from
zonicdesign.art. It does not publish a route, bind a Worker, or expose operator
connection details.

## Public Entry Shape

- Label: `Windburn Console`
- Destination: a future docs or console route after the Account Gate is live.
- First screen: redacted viewer status from Fusion Bridge.
- Visible capabilities: viewer reads status and OpenAPI, operator can stage
  intent after auth, admin config is disabled until real auth exists.
- Public promise: route health and capability model, not private runtime
  location.

## Safety Boundary

- No raw host, IP, SSH target, tmux target, credential path, or operator command
  in the page, screenshots, OpenGraph image, or docs copy.
- No webhook, queue, provider config, or remote mutation route until signed
  operator/admin auth exists.
- No Cloudflare Worker or zonicdesign.art route mutation from this slice.

## Readiness Gate

Only publish a visible zonicdesign.art link after all are true:

1. `/api/status` returns `viewer`, `read-only`, and mutation routes disabled.
2. Fusion Chat DOM shows the Account Gate without public-surface leaks.
3. Operator staging is local-only and clearly not live dispatch.
4. Admin/provider config is displayed as disabled.
5. A separate rollout issue approves the actual zonicdesign.art route.

## Current Next Action

Keep this plan as the handoff surface. The implementation slice may wire the
local Fusion Chat UI, but must not publish or advertise a broken console route.
