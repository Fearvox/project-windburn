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

  if [ -n "${MCP_SESSION_ID:-}" ]; then
    curl_args+=(-H "mcp-session-id: $MCP_SESSION_ID")
  fi

  curl_args+=(--data "$body" "$MCP_URL")
  curl "${curl_args[@]}"
  json_from_stream "$body_file" "$json_file"
  printf '%s\n' "$json_file"
}

extract_session_id() {
  local header_file="$1"
  awk -F': *' 'tolower($1) == "mcp-session-id" { gsub(/\r/, "", $2); print $2; exit }' "$header_file"
}

mkdir -p "$(dirname "$OUT")"

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
  --slurpfile initialize "$initialize_json" \
  --slurpfile tools "$tools_json" \
  --slurpfile search "$search_json" \
  --slurpfile blocked "$blocked_json" '
  def tool_names:
    ($tools[0].result.tools // []) | map(.name);
  def blocked_is_error:
    (($blocked[0].result.isError // false) == true) or ($blocked[0].error != null);

  {
    as_of: $as_of,
    verdict: (
      if ((tool_names | index("vault_delete") | not)
        and (tool_names | index("vault_search") != null)
        and blocked_is_error)
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
      isError: blocked_is_error,
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
