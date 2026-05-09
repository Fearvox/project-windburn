#!/usr/bin/env bash
set -euo pipefail

MCP_URL="${MCP_URL:-http://localhost:8787/mcp}"
OUT="${OUT:-docs/remote-workhorse/phase1/RESEARCH_VAULT_MCP_PUBLIC_SAFE_PROOF.json}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "BLOCK: missing required tool: $1" >&2
    exit 1
  fi
}

require_tool curl
require_tool jq

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/windburn-rv-mcp-dogfood.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

json_from_stream() {
  local input="$1"
  local output="$2"

  if jq -e . "$input" > "$output" 2>/dev/null; then
    return 0
  fi

  awk '
    /^data:[[:space:]]*/ {
      sub(/^data:[[:space:]]*/, "")
      if ($0 != "[DONE]") {
        print
      }
    }
  ' "$input" | jq -s 'if length == 1 then .[0] else . end' > "$output"
}

mcp_post() {
  local body="$1"
  local name="$2"
  local session_id="${MCP_SESSION_ID:-}"

  mcp_post_url "$MCP_URL" "$body" "$name" "$session_id"
}

mcp_post_url() {
  local url="$1"
  local body="$2"
  local name="$3"
  local session_id="${4:-}"
  local header_file="$tmp_dir/$name.headers"
  local body_file="$tmp_dir/$name.body"
  local json_file="$tmp_dir/$name.json"

  local curl_args=(
    -sS
    -D "$header_file"
    -o "$body_file"
    -X POST
    -H "content-type: application/json"
    -H "accept: application/json, text/event-stream"
  )

  if [ -n "$session_id" ]; then
    curl_args+=(-H "mcp-session-id: $session_id")
  fi

  curl_args+=(--data "$body" "$url")
  curl "${curl_args[@]}"
  json_from_stream "$body_file" "$json_file"
  printf '%s\n' "$json_file"
}

extract_session_id() {
  local header_file="$1"
  awk -F': *' 'tolower($1) == "mcp-session-id" { gsub(/\r/, "", $2); print $2; exit }' "$header_file"
}

endpoint_ref_for_url() {
  local url="$1"
  local host_port
  local port

  host_port="${url#http://}"
  host_port="${host_port#https://}"
  host_port="${host_port%%/*}"

  case "$host_port" in
    localhost|localhost:8787|127.0.0.1|127.0.0.1:8787)
      printf '%s\n' "localhost-default"
      ;;
    localhost:*)
      port="${host_port##*:}"
      printf 'localhost-alt-%s\n' "$port"
      ;;
    127.0.0.1:*)
      port="${host_port##*:}"
      printf 'localhost-alt-%s\n' "$port"
      ;;
    *)
      printf '%s\n' "nonlocal-redacted"
      ;;
  esac
}

health_url_for_mcp_url() {
  local url="$1"
  case "$url" in
    */mcp)
      printf '%s/health\n' "${url%/mcp}"
      ;;
    *)
      printf '%s\n' ""
      ;;
  esac
}

fetch_health_summary() {
  local health_url="$1"
  local label="${2:-health}"
  local raw_file="$tmp_dir/$label.raw"
  local json_file="$tmp_dir/$label.json"

  if [ -z "$health_url" ]; then
    jq -n '{available: false, profile: "unknown"}' > "$json_file"
    printf '%s\n' "$json_file"
    return 0
  fi

  if ! curl -fsS "$health_url" > "$raw_file" 2>/dev/null; then
    jq -n '{available: false, profile: "unknown"}' > "$json_file"
    printf '%s\n' "$json_file"
    return 0
  fi

  jq '{
    available: true,
    status: (.status // null),
    profile: (.profile // .active_profile // .runtime_profile // "unknown"),
    public_safe_default: (.public_safe_default // null),
    visible_tools: (.visible_tools // null),
    tools: (.tools // null),
    vault_tools: (.vault_tools // null),
    amplify_tools: (.amplify_tools // null),
    streamable_sessions: (.streamable_sessions // null)
  }' "$raw_file" > "$json_file"
  printf '%s\n' "$json_file"
}

ambient_default_probe() {
  local selected_ref="$1"
  local default_url="http://localhost:8787/mcp"
  local default_ref="localhost-default"
  local output_file="$tmp_dir/ambient_default.json"
  local default_health_json
  local init_body
  local init_json
  local session_id
  local initialized_body
  local tools_body
  local tools_json

  if [ "$selected_ref" = "$default_ref" ]; then
    jq -n --arg endpoint_ref "$default_ref" '{
      endpoint_ref: $endpoint_ref,
      checked: false,
      reason: "selected_endpoint_is_default"
    }' > "$output_file"
    printf '%s\n' "$output_file"
    return 0
  fi

  default_health_json="$(fetch_health_summary "$(health_url_for_mcp_url "$default_url")" ambient_default_health)"
  init_body="$(jq -n --arg id "windburn-rv-ambient-default-init" '{
    jsonrpc: "2.0",
    id: $id,
    method: "initialize",
    params: {
      protocolVersion: "2025-03-26",
      capabilities: {},
      clientInfo: {
        name: "windburn-research-vault-mcp-dogfood-ambient-default-probe",
        version: "1.0.0"
      }
    }
  }')"

  if ! init_json="$(mcp_post_url "$default_url" "$init_body" ambient_default_initialize "")"; then
    jq -n \
      --arg endpoint_ref "$default_ref" \
      --slurpfile health "$default_health_json" '{
        endpoint_ref: $endpoint_ref,
        checked: true,
        reachable: false,
        runtime_profile: ($health[0].profile // "unknown"),
        health: $health[0],
        tools: {
          count: 0,
          names: []
        },
        mutators_visible: false,
        visible_mutators: [],
        verdict: "PASS",
        reason: "ambient_default_not_reachable"
      }' > "$output_file"
    printf '%s\n' "$output_file"
    return 0
  fi

  session_id="$(extract_session_id "$tmp_dir/ambient_default_initialize.headers")"
  if [ -n "$session_id" ]; then
    initialized_body="$(jq -n '{
      jsonrpc: "2.0",
      method: "notifications/initialized",
      params: {}
    }')"
    mcp_post_url "$default_url" "$initialized_body" ambient_default_initialized "$session_id" >/dev/null || true
  fi

  tools_body="$(jq -n --arg id "windburn-rv-ambient-default-tools" '{
    jsonrpc: "2.0",
    id: $id,
    method: "tools/list",
    params: {}
  }')"

  if ! tools_json="$(mcp_post_url "$default_url" "$tools_body" ambient_default_tools "$session_id")"; then
    jq -n \
      --arg endpoint_ref "$default_ref" \
      --slurpfile health "$default_health_json" '{
        endpoint_ref: $endpoint_ref,
        checked: true,
        reachable: true,
        runtime_profile: ($health[0].profile // "unknown"),
        health: $health[0],
        tools: {
          count: null,
          names: []
        },
        mutators_visible: null,
        visible_mutators: [],
        verdict: "FLAG",
        reason: "ambient_default_tools_list_unavailable"
      }' > "$output_file"
    printf '%s\n' "$output_file"
    return 0
  fi

  jq -n \
    --arg endpoint_ref "$default_ref" \
    --slurpfile health "$default_health_json" \
    --slurpfile tools "$tools_json" '
    def tool_names:
      ($tools[0].result.tools // []) | map(.name);
    def visible_mutators:
      tool_names
      | map(select(
          . == "vault_delete"
          or . == "vault_raw_ingest"
          or . == "vault_note_save"
          or contains("_delete")
          or contains("_admin")
          or startswith("admin_")
        ));
    def mutators_visible:
      (visible_mutators | length) > 0;
    {
      endpoint_ref: $endpoint_ref,
      checked: true,
      reachable: true,
      runtime_profile: ($health[0].profile // "unknown"),
      health: $health[0],
      tools: {
        count: (tool_names | length),
        names: tool_names
      },
      mutators_visible: mutators_visible,
      visible_mutators: visible_mutators,
      verdict: (if mutators_visible then "FLAG" else "PASS" end),
      reason: (if mutators_visible then "ambient_default_mutators_visible" else "ambient_default_readonly_safe" end)
    }
  ' > "$output_file"
  printf '%s\n' "$output_file"
}

mkdir -p "$(dirname "$OUT")"
MCP_ENDPOINT_REF="$(endpoint_ref_for_url "$MCP_URL")"
MCP_HEALTH_URL="$(health_url_for_mcp_url "$MCP_URL")"
health_json="$(fetch_health_summary "$MCP_HEALTH_URL" selected_health)"
ambient_default_json="$(ambient_default_probe "$MCP_ENDPOINT_REF")"

initialize_body="$(jq -n --arg id "windburn-rv-init" '{
  jsonrpc: "2.0",
  id: $id,
  method: "initialize",
  params: {
    protocolVersion: "2025-03-26",
    capabilities: {},
    clientInfo: {
      name: "windburn-research-vault-mcp-dogfood",
      version: "1.0.0"
    }
  }
}')"

initialize_json="$(mcp_post "$initialize_body" initialize)"
MCP_SESSION_ID="$(extract_session_id "$tmp_dir/initialize.headers")"
export MCP_SESSION_ID

if [ -n "$MCP_SESSION_ID" ]; then
  initialized_body="$(jq -n '{
    jsonrpc: "2.0",
    method: "notifications/initialized",
    params: {}
  }')"
  mcp_post "$initialized_body" initialized >/dev/null || true
fi

tools_body="$(jq -n --arg id "windburn-rv-tools" '{
  jsonrpc: "2.0",
  id: $id,
  method: "tools/list",
  params: {}
}')"
tools_json="$(mcp_post "$tools_body" tools)"

search_body="$(jq -n --arg id "windburn-rv-search" '{
  jsonrpc: "2.0",
  id: $id,
  method: "tools/call",
  params: {
    name: "vault_search",
    arguments: {
      query: "Windburn Research Vault evidence",
      limit: 3
    }
  }
}')"
search_json="$(mcp_post "$search_body" search)"

blocked_body="$(jq -n --arg id "windburn-rv-blocked-mutation" '{
  jsonrpc: "2.0",
  id: $id,
  method: "tools/call",
  params: {
    name: "vault_delete",
    arguments: {
      id: "windburn-dogfood-harmless-nonexistent-id"
    }
  }
}')"
blocked_json="$(mcp_post "$blocked_body" blocked_mutation)"

jq -n \
  --arg as_of "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg endpoint_ref "$MCP_ENDPOINT_REF" \
  --slurpfile initialize "$initialize_json" \
  --slurpfile health "$health_json" \
  --slurpfile ambient_default "$ambient_default_json" \
  --slurpfile tools "$tools_json" \
  --slurpfile search "$search_json" \
  --slurpfile blocked "$blocked_json" '
  def tool_names:
    ($tools[0].result.tools // []) | map(.name);
  def parse_json_text:
    try fromjson catch null;
  def blocked_result_is_error:
    ($blocked[0].result != null) and (($blocked[0].result.isError // false) == true);
  def blocked_guidance:
    ($blocked[0].result.content // [])
    | map(select(.type == "text") | .text | parse_json_text | select(type == "object"))
    | map(.agent_guidance // empty)
    | .[0] // null;
  def blocked_guidance_is_block:
    (blocked_guidance != null) and ((blocked_guidance.verdict // "") == "BLOCK");
  def blocked_status:
    if ($blocked[0].error != null) then "jsonrpc_error"
    elif blocked_result_is_error and blocked_guidance_is_block then "blocked_with_guidance"
    elif blocked_result_is_error then "blocked_without_parseable_block_guidance"
    else "not_blocked"
    end;
  def runtime_profile:
    ($health[0].profile // "unknown");

  {
    as_of: $as_of,
    mcp_endpoint_ref: $endpoint_ref,
    runtime_profile: runtime_profile,
    health: $health[0],
    ambient_default_endpoint: $ambient_default[0],
    verdict: (
      if ((tool_names | index("vault_delete") | not)
        and (tool_names | index("vault_search") != null)
        and blocked_result_is_error
        and blocked_guidance_is_block)
      then "PASS"
      else "FLAG"
      end
    ),
    tools: {
      names: tool_names,
      response: $tools[0]
    },
    search: {
      query: "Windburn Research Vault evidence",
      limit: 3,
      response: $search[0]
    },
    blocked_mutation: {
      attempted_tool: "vault_delete",
      harmless_id: "windburn-dogfood-harmless-nonexistent-id",
      isError: blocked_result_is_error,
      status: blocked_status,
      agent_guidance: blocked_guidance,
      response: $blocked[0]
    },
    protocol: {
      initialize_status: (if $initialize[0].error then "FLAG" else "PASS" end),
      session_header_present: (env.MCP_SESSION_ID != null and env.MCP_SESSION_ID != "")
    }
  }
' > "$OUT"

if LC_ALL=C grep -E '(/Users/|(^|[^A-Za-z0-9_-])ssh[[:space:]]+|sk-[A-Za-z0-9_-]{12,}|ghp_[A-Za-z0-9_]{12,}|xox[abprs]-[A-Za-z0-9-]{12,}|([0-9]{1,3}\.){3}[0-9]{1,3})' "$OUT" >/dev/null; then
  echo "BLOCK: proof JSON contains public-surface leak candidate" >&2
  exit 1
fi

cat "$OUT"
