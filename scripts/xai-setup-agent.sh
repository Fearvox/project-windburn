#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CALL=0
CONFIRM=0
OUT=""
PROMPT="Set up the missing Windburn operator prerequisites without widening scope."
MODEL_OVERRIDE=""
CREDENTIAL_FILE="${WINDBURN_XAI_CREDENTIAL_FILE:-}"

usage() {
  cat <<'USAGE'
Usage: scripts/xai-setup-agent.sh [--call --confirm-xai-setup-agent] [--prompt TEXT] [--model MODEL] [--credential-file PATH] [--out PATH]

Default mode inspects local xAI credential shape without printing secret values.
Call mode performs a minimal xAI Chat Completions request and records a redacted
smoke artifact. Secret values are never written to the repository or browser.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --call)
      CALL=1
      shift
      ;;
    --confirm-xai-setup-agent)
      CONFIRM=1
      shift
      ;;
    --prompt)
      PROMPT="${2:?missing --prompt value}"
      shift 2
      ;;
    --model)
      MODEL_OVERRIDE="${2:?missing --model value}"
      shift 2
      ;;
    --credential-file)
      CREDENTIAL_FILE="${2:?missing --credential-file value}"
      shift 2
      ;;
    --out)
      OUT="${2:?missing --out value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$CALL" -eq 1 ] && [ "$CONFIRM" -ne 1 ]; then
  echo "refusing xAI call: missing --confirm-xai-setup-agent" >&2
  exit 2
fi

credential_candidates=()
if [ -n "$CREDENTIAL_FILE" ]; then
  credential_candidates+=("$CREDENTIAL_FILE")
fi
credential_candidates+=(
  "$HOME/.openclaw/credentials/xai-windburn_actual.rtf"
  "/Users/0xvox/Windburn/_local-cred/xai-windburn_local.rtf"
  "$ROOT/_local-cred/xai-windburn_local.rtf"
  "$HOME/.openclaw/credentials/xai-windburn.rtf"
)

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

credential_text() {
  local path="$1"
  case "$path" in
    *.rtf)
      if ! command -v textutil >/dev/null 2>&1; then
        echo "textutil required to read RTF credential file: $path" >&2
        return 2
      fi
      textutil -convert txt -stdout "$path"
      ;;
    *)
      sed -n '1,80p' "$path"
      ;;
  esac
}

normalize_key() {
  local key="$1"
  key="$(printf '%s' "$key" | tr '[:lower:] -' '[:upper:]__')"
  key="${key//[^A-Z0-9_]/}"
  printf '%s' "$key"
}

selected_credential=""
api_key=""
base_url=""
model=""

for path in "${credential_candidates[@]}"; do
  [ -f "$path" ] || continue

  selected_credential="$path"
  while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    line="$(trim "${raw_line%$'\r'}")"
    [ -n "$line" ] || continue

    key=""
    value=""
    if [[ "$line" == *"="* ]]; then
      key="$(normalize_key "${line%%=*}")"
      value="$(trim "${line#*=}")"
    elif [[ "$line" == *":"* ]]; then
      key="$(normalize_key "${line%%:*}")"
      value="$(trim "${line#*:}")"
    elif [ -z "$api_key" ] && [ "${#line}" -ge 20 ]; then
      api_key="$line"
      continue
    fi

    value="$(trim "$value")"
    value="${value%,}"
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    value="${value%,}"
    value="$(trim "$value")"
    [ -n "$value" ] || continue

    case "$key" in
      XAI_API_KEY|API_KEY|KEY|TOKEN|XAI_TOKEN)
        [ -z "$api_key" ] && api_key="$value"
        ;;
      XAI_BASE_URL|BASE_URL|OPENAI_BASE_URL|ENDPOINT|API_BASE|URL)
        [ -z "$base_url" ] && base_url="$value"
        ;;
      XAI_MODEL|MODEL|DEFAULT_MODEL)
        [ -z "$model" ] && model="$value"
        ;;
    esac
  done < <(credential_text "$path")

  [ -n "$api_key" ] && break
done

base_url="${base_url:-https://api.x.ai}"
model="${MODEL_OVERRIDE:-${model:-grok-4.3}}"

if [ -z "$selected_credential" ]; then
  echo "verdict=FLAG"
  echo "reason=XAI_CREDENTIAL_FILE_MISSING"
  echo "checked_paths=${credential_candidates[*]}"
  exit 1
fi

if [ -z "$api_key" ]; then
  echo "verdict=FLAG"
  echo "reason=XAI_API_KEY_MISSING"
  echo "credential_file=$selected_credential"
  exit 1
fi

case "${base_url%/}" in
  https://api.x.ai|https://api.x.ai/v1)
    base_url_kind="xai_public"
    ;;
  *)
    base_url_kind="custom"
    ;;
esac

echo "mode=$([ "$CALL" -eq 1 ] && echo call || echo inspect)"
echo "credential_file=$selected_credential"
echo "xai_api_key_present=true"
echo "xai_api_key_length=${#api_key}"
echo "base_url_kind=$base_url_kind"
echo "model=$model"

if [ "$CALL" -ne 1 ]; then
  echo "verdict=PASS"
  echo "reason=XAI_CREDENTIAL_SHAPE_OK"
  exit 0
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT
curl_stderr="$tmpdir/curl.stderr"

trimmed_base="${base_url%/}"
case "$trimmed_base" in
  */v1)
    chat_url="$trimmed_base/chat/completions"
    models_url="$trimmed_base/models"
    ;;
  *)
    chat_url="$trimmed_base/v1/chat/completions"
    models_url="$trimmed_base/v1/models"
    ;;
esac

models_json="$tmpdir/xai-models.json"
models_code="$(curl -sS -m 60 -o "$models_json" -w "%{http_code}" \
  -H "Authorization: Bearer $api_key" \
  "$models_url" 2>"$curl_stderr" || true)"

expected="XAI_SETUP_AGENT_OK"
payload="$(jq -n \
  --arg model "$model" \
  --arg expected "$expected" \
  --arg prompt "$PROMPT" \
  '{
    model: $model,
    stream: false,
    temperature: 0,
    messages: [
      {
        role: "system",
        content: "You are Windburn xAI setup lane. Return bounded operator setup cards. Never request secrets in chat."
      },
      {
        role: "user",
        content: ("Smoke check first. Reply exactly " + $expected + ". Context: " + $prompt)
      }
    ]
  }')"

response_json="$tmpdir/xai-response.json"
http_code="$(curl -sS -m 180 -o "$response_json" -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $api_key" \
  -d "$payload" \
  "$chat_url" 2>"$curl_stderr" || true)"

content="$(jq -r '.choices[0].message.content // ""' "$response_json" 2>/dev/null || true)"
error_text="$(jq -r '.error.message // .message // .detail // .error // "" | tostring' "$response_json" 2>/dev/null || true)"
if [ "$http_code" = "200" ] && [ "$content" = "$expected" ]; then
  verdict="PASS"
  reason="XAI_SETUP_AGENT_SMOKE_OK"
else
  verdict="FLAG"
  reason="XAI_SETUP_AGENT_HTTP_${http_code}"
fi

artifact_json="$(jq -n \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg verdict "$verdict" \
  --arg reason "$reason" \
  --arg credential_file "$selected_credential" \
  --arg base_url_kind "$base_url_kind" \
  --arg model "$model" \
  --arg http_code "$http_code" \
  --arg models_http_code "$models_code" \
  --arg response_text "$content" \
  --arg error_text "$error_text" \
  '{
    schema_version: 1,
    generated_at_utc: $generated_at,
    verdict: $verdict,
    reason: $reason,
    credential_file: $credential_file,
    xai_api_key_present: true,
    base_url_kind: $base_url_kind,
    model: $model,
    models_http_code: $models_http_code,
    http_code: $http_code,
    response_text: $response_text,
    error_text: $error_text,
    secret_values_recorded: false
  }')"

if [ -n "$OUT" ]; then
  mkdir -p "$(dirname "$OUT")"
  {
    echo "# xAI Setup Agent Smoke"
    echo
    echo "Generated: \`$(date -u +%Y-%m-%dT%H:%M:%SZ)\`"
    echo
    echo "VERDICT: \`$verdict\`"
    echo
    echo "Reason: \`$reason\`"
    echo
    echo "Credential file: \`$selected_credential\`"
    echo
    echo "Model: \`$model\`"
    echo
    echo "Base URL kind: \`$base_url_kind\`"
    echo
    echo "HTTP code: \`$http_code\`"
    echo
    echo "Models HTTP code: \`$models_code\`"
    echo
    echo "Secret values recorded: \`false\`"
    echo
    echo "Response text:"
    echo
    echo '```text'
    printf '%s\n' "$content"
    echo '```'
    if [ -n "$error_text" ]; then
      echo
      echo "Error text:"
      echo
      echo '```text'
      printf '%s\n' "$error_text"
      echo '```'
    fi
    echo
    echo "Raw redacted evidence:"
    echo
    echo '```json'
    printf '%s\n' "$artifact_json"
    echo '```'
  } > "$OUT"
  echo "artifact=$OUT"
fi

echo "verdict=$verdict"
echo "reason=$reason"
echo "models_http_code=$models_code"
echo "http_code=$http_code"
echo "response_text=$content"
if [ -n "$error_text" ]; then
  echo "error_text=$error_text"
fi

[ "$verdict" = "PASS" ]
