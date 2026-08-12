#!/bin/bash
# Test runner for shunt evals: hook routing decisions + token savings benchmarks
#
# Usage:
#   bash evals/run.sh              # hooks only (no Portal access needed)
#   bash evals/run.sh --benchmark  # hooks + token savings (requires portal-cli auth)
#   bash evals/run.sh --all        # every eval suite

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES="$SCRIPT_DIR/.fixtures"
BENCHMARKS="$SCRIPT_DIR/benchmarks.json"
PASSED=0
FAILED=0
TOTAL=0
RUN_HOOKS=true
RUN_BENCHMARK=false

for arg in "$@"; do
  case "$arg" in
    --benchmark) RUN_BENCHMARK=true ;;
    --all)       RUN_BENCHMARK=true ;;
  esac
done

generate_fixture() {
  local path="$1" lines="$2"
  if [ "$lines" -eq 0 ]; then
    touch "$path"
  else
    seq 1 "$lines" | awk '{print "line "NR}' > "$path"
  fi
}

setup_fixtures() {
  local evals_file="$1"
  rm -rf "$FIXTURES"
  mkdir -p "$FIXTURES"

  local count
  count=$(jq '.evals | length' "$evals_file")

  for ((i = 0; i < count; i++)); do
    local fixture
    fixture=$(jq -r ".evals[$i].fixture" "$evals_file")
    [ "$fixture" = "null" ] && continue

    local lines
    lines=$(jq -r ".evals[$i].fixture.lines" "$evals_file")

    local input_path
    input_path=$(jq -r ".evals[$i].input.tool_input.file_path // empty" "$evals_file")
    if [ -z "$input_path" ]; then
      input_path=$(jq -r ".evals[$i].input.tool_input.command // empty" "$evals_file" | sed -E 's/^(cat|head|tail|less|more) +(-[^ ]+ +)*//' | sed 's/ .*//' | tr -d '"'"'")
    fi
    input_path=$(echo "$input_path" | sed "s|{{FIXTURES}}|$FIXTURES|")

    # Commands the parser is not meant to extract a path from (grep, git, …)
    # reduce to the command name itself. Generating that would drop a junk file
    # in the working directory; the fixtures those evals rely on are created by
    # their siblings anyway.
    case "$input_path" in
      "$FIXTURES"/*) generate_fixture "$input_path" "$lines" ;;
    esac
  done
}

run_eval() {
  local hook="$1" name="$2" input="$3" expected="$4" reason="$5" env_json="$6"
  TOTAL=$((TOTAL + 1))

  local result actual
  if [ -n "$env_json" ] && [ "$env_json" != "null" ]; then
    local env_cmd=""
    while IFS='=' read -r key val; do
      env_cmd="$env_cmd $key=$val"
    done < <(echo "$env_json" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
    result=$(echo "$input" | env $env_cmd bash "$hook" 2>/dev/null)
  else
    result=$(echo "$input" | bash "$hook" 2>/dev/null)
  fi
  actual=$(echo "$result" | jq -r '.decision')

  if [ "$actual" = "$expected" ]; then
    printf "  \033[32mPASS\033[0m  %-30s %s\n" "$name" "$reason"
    PASSED=$((PASSED + 1))
  else
    printf "  \033[31mFAIL\033[0m  %-30s expected=%s got=%s\n" "$name" "$expected" "$actual"
    FAILED=$((FAILED + 1))
  fi
}

run_suite() {
  local hook="$1" evals_file="$2" label="$3"

  setup_fixtures "$evals_file"

  echo ""
  echo "$label"
  echo "────────────────────────────────────────────────────────────────"

  local count
  count=$(jq '.evals | length' "$evals_file")

  for ((i = 0; i < count; i++)); do
    local name expected reason input
    name=$(jq -r ".evals[$i].name" "$evals_file")
    expected=$(jq -r ".evals[$i].expected_decision" "$evals_file")
    reason=$(jq -r ".evals[$i].reason" "$evals_file")
    input=$(jq -c ".evals[$i].input" "$evals_file" | sed "s|{{FIXTURES}}|$FIXTURES|g")

    local env_json
    env_json=$(jq -r ".evals[$i].env // empty" "$evals_file")
    run_eval "$hook" "$name" "$input" "$expected" "$reason" "$env_json"
  done

  rm -rf "$FIXTURES"
}

# ── Transport suite ──

# Runs as a child process: the suite stubs portal-cli, and that stub must not
# leak into the benchmarks below, which need the real one.
run_transport_suite() {
  echo ""
  echo "Transport (scripts/lib/aika.sh, stubbed portal-cli)"
  echo "────────────────────────────────────────────────────────────────"

  local output counts p f
  output=$(bash "$SCRIPT_DIR/transport-evals.sh" 2>&1) || true

  printf '%s\n' "$output" | grep -v '^## ' || true
  # `|| true` so a missing trailer reaches the fallback below instead of
  # tripping set -e on the failed grep.
  counts=$(printf '%s\n' "$output" | grep '^## ' | tail -1 || true)
  p=$(printf '%s' "$counts" | awk '{print $2}')
  f=$(printf '%s' "$counts" | awk '{print $3}')

  if [ -z "$p" ]; then
    printf "  \033[31mFAIL\033[0m  %-32s suite did not report results\n" "transport-evals"
    FAILED=$((FAILED + 1))
    TOTAL=$((TOTAL + 1))
    return
  fi

  PASSED=$((PASSED + p))
  FAILED=$((FAILED + f))
  TOTAL=$((TOTAL + p + f))
}

# ── Benchmark helpers ──

token_estimate() {
  echo $(( (${#1} + 3) / 4 ))
}

run_benchmark_bulk_read() {
  local idx="$1"
  local question corpus

  question=$(jq -r ".benchmarks[$idx].question" "$BENCHMARKS")
  corpus=""
  local paths_args=()

  while IFS= read -r p; do
    local full="$SCRIPT_DIR/$p"
    paths_args+=("$full")
    corpus="$corpus$(cat "$full")"
  done < <(jq -r ".benchmarks[$idx].paths[]" "$BENCHMARKS")

  local without_tokens
  without_tokens=$(token_estimate "$corpus")

  local response
  response=$("$PLUGIN_DIR/scripts/bulk-read" --question "$question" --paths "${paths_args[@]}" 2>/dev/null) || true

  local with_tokens
  with_tokens=$(token_estimate "$response")

  local total_lines=0
  while IFS= read -r p; do
    local lines
    lines=$(wc -l < "$SCRIPT_DIR/$p" | tr -d ' ')
    total_lines=$(( total_lines + lines ))
  done < <(jq -r ".benchmarks[$idx].paths[]" "$BENCHMARKS")

  echo "$total_lines $without_tokens $with_tokens"
}

run_benchmark_code_write() {
  local idx="$1"
  local spec reference context_corpus

  spec=$(jq -r ".benchmarks[$idx].spec" "$BENCHMARKS")
  reference="$SCRIPT_DIR/$(jq -r ".benchmarks[$idx].reference" "$BENCHMARKS")"

  context_corpus=""
  while IFS= read -r p; do
    context_corpus="$context_corpus$(cat "$SCRIPT_DIR/$p")"
  done < <(jq -r ".benchmarks[$idx].context_files[]" "$BENCHMARKS")

  # Run code-write with --target so output goes to disk
  local target_file="${TMPDIR:-/tmp}/shunt-codegen-output.ts"
  "$PLUGIN_DIR/scripts/code-write" --spec "$spec" --reference "$reference" --target "$target_file" 2>/dev/null || true

  local generated=""
  [ -f "$target_file" ] && generated=$(cat "$target_file")

  # Without shunt: Claude reads context files + generates code as output tokens
  # Output tokens cost ~5x input tokens, so we weight them accordingly
  local input_tokens output_tokens without_tokens
  input_tokens=$(token_estimate "$context_corpus")
  output_tokens=$(token_estimate "$generated")
  without_tokens=$(( input_tokens + output_tokens * 5 ))

  # With shunt: Claude sends a short spec, code goes to disk, Claude sees nothing
  local with_tokens=0

  rm -f "$target_file"
  echo "0 $without_tokens $with_tokens"
}

run_benchmarks() {
  # shellcheck source=../scripts/lib/aika.sh
  . "$PLUGIN_DIR/scripts/lib/aika.sh"
  if ! shunt_preflight; then
    printf "\n\033[33mSkipping benchmarks: portal-cli or jq not available\033[0m\n"
    return
  fi

  local count
  count=$(jq '.benchmarks | length' "$BENCHMARKS")

  echo ""
  echo "Token savings benchmark"
  echo "────────────────────────────────────────────────────────────────────────────────"

  local total_without=0 total_with=0
  declare -a rows

  for ((i = 0; i < count; i++)); do
    local name btype
    name=$(jq -r ".benchmarks[$i].name" "$BENCHMARKS")
    btype=$(jq -r ".benchmarks[$i].type" "$BENCHMARKS")

    printf "  \033[2mRunning [%s] %s...\033[0m\n" "$btype" "$name"

    local total_lines without_tokens with_tokens
    if [ "$btype" = "bulk-read" ]; then
      read -r total_lines without_tokens with_tokens <<< "$(run_benchmark_bulk_read "$i")"
    elif [ "$btype" = "code-write" ]; then
      read -r total_lines without_tokens with_tokens <<< "$(run_benchmark_code_write "$i")"
    else
      continue
    fi

    local pct=0
    if [ "$without_tokens" -gt 0 ]; then
      pct=$(( (without_tokens - with_tokens) * 100 / without_tokens ))
    fi

    total_without=$(( total_without + without_tokens ))
    total_with=$(( total_with + with_tokens ))

    local file_info
    if [ "$total_lines" -gt 0 ]; then
      file_info="${total_lines} lines"
    else
      file_info="codegen"
    fi

    rows+=("$name|$file_info|$without_tokens|$with_tokens|$pct")
  done

  echo ""
  printf "  %-25s  %10s  %14s  %14s  %8s\n" "Scenario" "Input" "Without shunt" "With shunt" "Savings"
  printf "  %-25s  %10s  %14s  %14s  %8s\n" "─────────────────────────" "──────────" "──────────────" "──────────────" "────────"

  for r in "${rows[@]}"; do
    IFS='|' read -r name file_info without_tokens with_tokens pct <<< "$r"
    local color='\033[32m'
    [ "$pct" -lt 80 ] && color='\033[36m'
    [ "$pct" -lt 50 ] && color='\033[31m'
    printf "  %-25s  %10s  %11s tk  %11s tk  ${color}%5s%%\033[0m\n" \
      "$name" "$file_info" "$without_tokens" "$with_tokens" "$pct"
  done

  printf "  %-25s  %10s  %14s  %14s  %8s\n" "─────────────────────────" "──────────" "──────────────" "──────────────" "────────"

  local total_pct=0
  if [ "$total_without" -gt 0 ]; then
    total_pct=$(( (total_without - total_with) * 100 / total_without ))
  fi

  printf "  \033[1m%-25s  %10s  %11s tk  %11s tk  \033[32m%5s%%\033[0m\n" \
    "Total" "" "$total_without" "$total_with" "$total_pct"
  echo ""
  printf "  \033[2mToken estimate: chars / 4. Output tokens weighted 5x (Opus pricing).\033[0m\n"
  printf "  \033[2mBulk-read: without = file content in context, with = AiKA summary in context.\033[0m\n"
  printf "  \033[2mCode-write: without = read files + generate code, with = code written to disk.\033[0m\n"
}

# ── Main ──

run_suite "$SCRIPT_DIR/../hooks/check-file-size" "$SCRIPT_DIR/hook-evals.json" "Read hook (check-file-size)"
run_suite "$SCRIPT_DIR/../hooks/check-bash-read" "$SCRIPT_DIR/bash-hook-evals.json" "Bash hook (check-bash-read)"
run_transport_suite

echo ""
echo "════════════════════════════════════════════════════════════════"
printf "Total: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASSED" "$FAILED" "$TOTAL"

if [ "$RUN_BENCHMARK" = true ]; then
  run_benchmarks
fi

echo ""
[ "$FAILED" -gt 0 ] && exit 1
exit 0
