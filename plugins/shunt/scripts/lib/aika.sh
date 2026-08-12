#!/bin/bash
# Shared AiKA plumbing for shunt's delegation scripts.
#
# Everything goes through the Portal CLI actions registry (aika:invoke-chat),
# so the plugin works anywhere Portal does rather than depending on
# internal-only tooling.
#
# Modes are addressed by name; the backend resolves it case-insensitively,
# preferring the caller's own mode, then their groups', then public ones, and
# fails the request on no match or a genuine tie (listing the candidate ids).
# Pin a specific mode past an ambiguity with SHUNT_<NAME>_MODE_ID.
#
# Every delegation is one shot. invoke-chat is ephemeral — nothing is kept
# server-side — and the only way to carry context across calls would be to
# replay it from this side, which for a file corpus is the very cost the
# plugin exists to avoid. Ask again with the files instead.

# invoke-chat input travels through argv. The whole request has to fit in
# ARG_MAX alongside the environment, and on Linux a single argument is
# additionally capped at MAX_ARG_STRLEN (128 KiB); macOS has no per-argument
# cap below its 1 MiB ARG_MAX.
if [ -z "${SHUNT_MAX_PAYLOAD_BYTES:-}" ]; then
  case "$(uname -s)" in
    Linux) SHUNT_MAX_PAYLOAD_BYTES=120000 ;;
    *)     SHUNT_MAX_PAYLOAD_BYTES=400000 ;;
  esac
fi

# Ceiling for one action invocation; large generations can take a while.
SHUNT_TIMEOUT_SECONDS="${SHUNT_TIMEOUT_SECONDS:-180}"

if [ -n "${PORTAL_CLI_BIN:-}" ]; then
  read -ra SHUNT_PORTAL_CMD <<< "$PORTAL_CLI_BIN"
elif command -v portal-cli >/dev/null 2>&1; then
  SHUNT_PORTAL_CMD=(portal-cli)
else
  SHUNT_PORTAL_CMD=(npx --yes @spotify/portal-cli)
fi

# --instance goes after the action's own args — that is the placement
# portal-cli documents for action invocations.
shunt_portal() {
  "${SHUNT_PORTAL_CMD[@]}" "$@" ${SHUNT_PORTAL_INSTANCE:+--instance "$SHUNT_PORTAL_INSTANCE"}
}

# mktemp with cleanup on script exit. Usage: shunt_tmpfile <varname>
SHUNT_TMPFILES=()
shunt_tmpfile() {
  local f
  f=$(mktemp) || return 1
  SHUNT_TMPFILES+=("$f")
  trap 'rm -f "${SHUNT_TMPFILES[@]}"' EXIT
  printf -v "$1" '%s' "$f"
}

shunt_preflight() {
  local missing=""
  command -v jq >/dev/null 2>&1 || missing=" jq"
  if ! command -v "${SHUNT_PORTAL_CMD[0]}" >/dev/null 2>&1; then
    missing="$missing ${SHUNT_PORTAL_CMD[0]}"
  fi

  if [ -n "$missing" ]; then
    echo "Error: missing required command(s):$missing" >&2
    echo "  jq         — brew install jq" >&2
    echo "  portal-cli — npm i -g @spotify/portal-cli, or set PORTAL_CLI_BIN" >&2
    return 1
  fi
  return 0
}

# Surfaces a failed action call. portal-cli --json already reports an error
# and a remediation, so unwrap those rather than dumping the raw envelope.
shunt_report_error() {
  local label="$1" response="$2"
  local message remediation

  message=$(printf '%s' "$response" | jq -r '.error // empty' 2>/dev/null)
  remediation=$(printf '%s' "$response" | jq -r '.remediation // empty' 2>/dev/null)

  if [ -n "$message" ]; then
    echo "Error: $label: $message" >&2
    [ -n "$remediation" ] && echo "  $remediation" >&2
  else
    echo "Error: $label" >&2
    printf '%s\n' "$response" >&2
  fi
}

# Runs one ephemeral chat turn against a mode and prints the answer.
#   $1 mode name
#   $2 file holding the message
#
# The backend resolves the name; SHUNT_<NAME>_MODE_ID pins a specific mode
# by id instead (the two inputs are mutually exclusive).
shunt_invoke() {
  local mode_name="$1" message_file="$2"
  local override_var mode_id mode_key payload bytes stderr_file response rc err text mode

  override_var="SHUNT_$(printf '%s' "$mode_name" | tr '[:lower:]-' '[:upper:]_')_MODE_ID"
  mode_id="${!override_var:-}"

  if [ -n "$mode_id" ]; then mode_key="mode_id"; else mode_key="mode_name"; fi
  payload=$(jq -n \
    --arg key "$mode_key" \
    --arg ref "${mode_id:-$mode_name}" \
    --rawfile message "$message_file" \
    '{($key): $ref, message: $message}')

  bytes=$(printf '%s' "$payload" | wc -c | tr -d ' ')
  if [ "$bytes" -gt "$SHUNT_MAX_PAYLOAD_BYTES" ]; then
    echo "Error: request is $bytes bytes, over the $SHUNT_MAX_PAYLOAD_BYTES byte limit." >&2
    echo "invoke-chat input is passed on the command line, so it must fit in ARG_MAX." >&2
    echo "Send fewer or smaller files, or raise SHUNT_MAX_PAYLOAD_BYTES if there is headroom." >&2
    return 1
  fi

  # Keep stderr out of the capture: on a successful call, npx install notices
  # or CLI warnings would otherwise corrupt the JSON envelope.
  stderr_file=$(mktemp)
  response=$(shunt_portal actions aika:invoke-chat --json \
    --timeout-seconds "$SHUNT_TIMEOUT_SECONDS" \
    --input "$payload" 2>"$stderr_file")
  rc=$?
  err=$(cat "$stderr_file"; rm -f "$stderr_file")

  if [ "$rc" -ne 0 ]; then
    shunt_report_error "aika:invoke-chat failed" "${response:-$err}"
    # portal-cli exposes no structured error code, so the wording of its
    # message is the only signal the timeout hint can key on.
    case "$response $err" in
      *"timed out"*)
        echo "The invocation exceeded ${SHUNT_TIMEOUT_SECONDS}s. Raise SHUNT_TIMEOUT_SECONDS or split the work into smaller calls." >&2
        ;;
    esac
    return 1
  fi

  # rc 0 with garbled stdout is a transport problem, not a mode problem —
  # report it as such instead of falling through to the mode guard below.
  if ! printf '%s' "$response" | jq -e . >/dev/null 2>&1; then
    shunt_report_error "aika:invoke-chat returned unparseable output" "$response"
    return 1
  fi

  # A name that resolves to nothing fails the request, but a stale mode_id
  # only logs a warning server-side and the turn runs mode-less — a generic
  # answer under the wrong instructions. The output names the mode that
  # actually ran, so treat "none" as a failure rather than passing it off.
  mode=$(printf '%s' "$response" | jq -r '.mode.name // empty' 2>/dev/null)
  if [ -z "$mode" ]; then
    echo "Error: the \"$mode_name\" mode was not applied; the answer was discarded." >&2
    if [ -n "$mode_id" ]; then
      echo "$override_var=$mode_id may be stale — unset it to resolve by name instead." >&2
    fi
    return 1
  fi

  text=$(printf '%s' "$response" | jq -r '.text // empty' 2>/dev/null)
  if [ -z "$text" ]; then
    shunt_report_error "aika:invoke-chat returned no text" "$response"
    return 1
  fi

  printf '%s\n' "$text"
}
