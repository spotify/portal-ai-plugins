#!/bin/bash
# Transport evals for scripts/lib/aika.sh.
#
# Runs against a stubbed portal-cli, so these need no Portal instance, no auth
# and no tokens — the benchmark suite covers the real round trip.
#
# Prints one PASS/FAIL line per check plus a machine-readable "## <pass> <fail>"
# trailer for run.sh. Runs as its own process so the stub cannot leak into the
# benchmark suite.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKDIR="$(mktemp -d)"
CAPTURED_PAYLOAD="$WORKDIR/captured-payload.json"

# shellcheck source=../scripts/lib/aika.sh
. "$PLUGIN_DIR/scripts/lib/aika.sh"

# Stub the transport: record the payload it was given, return canned output in
# the same shape `portal-cli actions ... --json` prints (the action's output).
shunt_portal() {
  local input="" want_input=false arg
  printf '%s\n' "$@" > "$WORKDIR/captured-args"
  for arg in "$@"; do
    if [ "$want_input" = true ]; then input="$arg"; want_input=false; continue; fi
    case "$arg" in
      --input) want_input=true ;;
    esac
  done
  printf '%s' "$input" > "$CAPTURED_PAYLOAD"

  echo '{"text":"- first line\n- second line","mode":{"id":"id-bulk","name":"bulk-reader"}}'
}

PASSED=0
FAILED=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf "  \033[32mPASS\033[0m  %-32s %s\n" "$name" "$4"
    PASSED=$((PASSED + 1))
  else
    printf "  \033[31mFAIL\033[0m  %-32s expected=[%s] got=[%s]\n" "$name" "$expected" "$actual"
    FAILED=$((FAILED + 1))
  fi
}

payload_field() { jq -r "$1" "$CAPTURED_PAYLOAD" 2>/dev/null; }

# ── Invocation ──

message_file="$WORKDIR/message.txt"
printf 'line one\nline two\n' > "$message_file"

check "answer-text-extracted" "- first line
- second line" "$(shunt_invoke bulk-reader "$message_file")" \
  "reads .text instead of scraping stdout"
check "message-sent" "line one
line two" "$(payload_field '.message')" \
  "message survives the round trip verbatim"
check "mode-name-sent" "bulk-reader" "$(payload_field '.mode_name')" \
  "the backend resolves the name"
check "no-mode-id-sent" "false" "$(payload_field 'has("mode_id")')" \
  "mode_name and mode_id are mutually exclusive"
check "no-history-sent" "false" "$(payload_field 'has("history")')" \
  "every delegation is one shot"
check "timeout-flag-sent" "180" "$(grep -x -A1 -- '--timeout-seconds' "$WORKDIR/captured-args" | tail -1)" \
  "the invocation carries an explicit timeout"

# ── Mode pinning ──

SHUNT_BULK_READER_MODE_ID="id-pinned"
shunt_invoke bulk-reader "$message_file" >/dev/null
check "pinned-mode-id-sent" "id-pinned" "$(payload_field '.mode_id')" \
  "the override pins a mode past an ambiguity"
check "no-mode-name-sent" "false" "$(payload_field 'has("mode_name")')" \
  "mode_name and mode_id are mutually exclusive"
unset SHUNT_BULK_READER_MODE_ID

# ── Mode-less fallback ──

# A stale mode_id only warns server-side and the turn runs without the mode;
# the output's .mode says what actually ran, and "none" must not pass as an
# answer.
( shunt_portal() { echo '{"text":"generic answer","mode":null}'; }
  shunt_invoke bulk-reader "$message_file" >/dev/null 2>&1 ) && rc=0 || rc=$?
check "modeless-answer-fails" "1" "$rc" "an answer the mode never saw is an error"

( shunt_portal() { echo '{"text":"generic answer","mode":null}'; }
  SHUNT_BULK_READER_MODE_ID="id-stale"
  guard=$(shunt_invoke bulk-reader "$message_file" 2>&1 >/dev/null)
  case "$guard" in *"SHUNT_BULK_READER_MODE_ID"*"stale"*) exit 0 ;; *) exit 1 ;; esac ) \
  && rc=0 || rc=$?
check "stale-pin-named" "0" "$rc" "the error points at the stale override"

( shunt_portal() { echo '{"mode":{"id":"id-bulk","name":"bulk-reader"}}'; }
  shunt_invoke bulk-reader "$message_file" >/dev/null 2>&1 ) && rc=0 || rc=$?
check "empty-answer-fails" "1" "$rc" "an answer with no text is an error"

# rc 0 with garbled stdout must fail and be reported as a transport problem,
# not blamed on mode resolution.
( shunt_portal() { echo 'not json at all'; }
  guard=$(shunt_invoke bulk-reader "$message_file" 2>&1 >/dev/null) && exit 1
  case "$guard" in *"unparseable"*) exit 0 ;; *) exit 1 ;; esac ) && rc=0 || rc=$?
check "garbled-response-fails" "0" "$rc" "unparseable rc-0 output is a transport error"

# ── Stderr separation ──

# npx install notices and CLI warnings go to stderr on successful calls; they
# must not corrupt the JSON envelope on stdout.
check "stderr-noise-ignored" "answer" "$(
  shunt_portal() {
    echo 'npm warn deprecated something@1.0.0' >&2
    echo '{"text":"answer","mode":{"id":"id-bulk","name":"bulk-reader"}}'
  }
  shunt_invoke bulk-reader "$message_file" 2>/dev/null
)" "stderr noise must not corrupt the response"

# ── Payload ceiling ──

saved_payload_bytes="$SHUNT_MAX_PAYLOAD_BYTES"
SHUNT_MAX_PAYLOAD_BYTES=10
guard_output=$(shunt_invoke bulk-reader "$message_file" 2>&1 >/dev/null) && rc=0 || rc=$?
check "oversized-payload-fails" "1" "$rc" "input must fit in ARG_MAX"
case "$guard_output" in
  *"over the 10 byte limit"*) check "oversized-payload-explained" "y" "y" "error names the limit" ;;
  *)                          check "oversized-payload-explained" "y" "n" "error names the limit" ;;
esac
SHUNT_MAX_PAYLOAD_BYTES="$saved_payload_bytes"

# ── Error reporting ──

report=$(shunt_report_error "could not invoke chat" \
  '{"error":"Not authenticated.","remediation":"Run `portal-cli auth login` to sign in."}' 2>&1)
case "$report" in
  *"could not invoke chat: Not authenticated."*"portal-cli auth login"*)
    check "error-unwrapped" "y" "y" "portal-cli's message and remediation surface" ;;
  *)
    check "error-unwrapped" "y" "n" "portal-cli's message and remediation surface" ;;
esac

report=$(shunt_report_error "invoke failed" 'plain text failure' 2>&1)
case "$report" in
  *"invoke failed"*"plain text failure"*)
    check "non-json-error-passed-through" "y" "y" "unparseable output is not swallowed" ;;
  *)
    check "non-json-error-passed-through" "y" "n" "unparseable output is not swallowed" ;;
esac

rm -rf "$WORKDIR"

echo "## $PASSED $FAILED"
[ "$FAILED" -gt 0 ] && exit 1
exit 0
