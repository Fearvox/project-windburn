This directory stores repo-local runtime registry cards for Windburn.

Public-surface rule:

- do not commit raw public hosts/IPs;
- do not commit SSH targets or tmux session targets;
- do not commit provider credentials, OAuth material, or credential paths.

Registry cards may use env or redacted references instead:

- `host_env` for an operator-owned host variable;
- `tmux_session_ref` for an operator-owned tmux session variable;
- `route_label` for a browser-safe routing label.

`requested_action` in this directory is registry metadata, not an executable
runtime-card action unless a separate verifier/runner explicitly supports it.
