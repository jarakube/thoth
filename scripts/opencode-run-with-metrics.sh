#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/opencode-run-with-metrics.sh [--metrics-dir DIR] [--title-prefix PREFIX] [--] [opencode run args...]

Runs `opencode run` with a unique title, captures the session ID from the JSON event stream,
exports that exact session, and writes per-run metrics into a dedicated directory.

Environment variables:
  OPENCODE_RUN_METRICS_DIR   Default metrics directory (default: share/opencode-runs)
  OPENCODE_RUN_TITLE_PREFIX  Default title prefix (default: ci-opencode-run)
EOF
}

metrics_dir="${OPENCODE_RUN_METRICS_DIR:-share/opencode-runs}"
title_prefix="${OPENCODE_RUN_TITLE_PREFIX:-ci-opencode-run}"

while (($# > 0)); do
  case "$1" in
    --metrics-dir)
      metrics_dir="$2"
      shift 2
      ;;
    --title-prefix)
      title_prefix="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    --title|--format)
      printf 'This wrapper manages %s automatically.\n' "$1" >&2
      exit 2
      ;;
    --title=*|--format=*)
      printf 'This wrapper manages %s automatically.\n' "${1%%=*}" >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

mkdir -p "$metrics_dir"

run_stamp="$(date -u +%Y%m%dT%H%M%SZ)-$$"
run_title="${title_prefix}-${run_stamp}"
run_dir="$metrics_dir/$run_title"
events_file="$run_dir/opencode-events.jsonl"
log_file="$run_dir/opencode.log"
export_file="$run_dir/session-export.json"
metrics_file="$run_dir/run-metrics.json"
session_id_file="$run_dir/session-id.txt"

mkdir -p "$run_dir"

opencode_cmd=(opencode run --format json --title "$run_title")
if (($# > 0)); then
  opencode_cmd+=("$@")
fi

printf -v opencode_cmd_string '%q ' "${opencode_cmd[@]}"
opencode_cmd_string="${opencode_cmd_string% }"

printf 'Run title: %s\n' "$run_title" >&2
printf 'Metrics directory: %s\n' "$run_dir" >&2

set +e
"${opencode_cmd[@]}" 2> >(tee "$log_file" >&2) \
  | tee "$events_file" \
  | jq -r 'select(.type == "text" and (.part.text? != null)) | .part.text'
opencode_status=${PIPESTATUS[0]}
set -e

session_id="$(jq -sr 'map(select(.sessionID? != null) | .sessionID) | first // empty' "$events_file")"
if [[ -z "$session_id" ]]; then
  printf 'Failed to capture session ID from %s\n' "$events_file" >&2
  exit 1
fi

printf '%s\n' "$session_id" > "$session_id_file"
printf 'Session ID: %s\n' "$session_id" >&2

opencode export "$session_id" > "$export_file"

jq \
  --arg run_title "$run_title" \
  --arg session_id "$session_id" \
  --arg opencode_cmd "$opencode_cmd_string" \
  --arg metrics_dir "$run_dir" \
  --arg events_file "$events_file" \
  --arg log_file "$log_file" \
  --arg export_file "$export_file" \
  --arg session_id_file "$session_id_file" \
  --arg captured_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '
  def step_parts:
    [.messages[].parts[] | select(.type == "step-finish")];

  def token_sum(field):
    [step_parts[] | field // 0] | add // 0;

  def cache_sum(field):
    [step_parts[] | .tokens.cache[field] // 0] | add // 0;

  def cost_sum:
    [step_parts[] | .cost // 0] | add // 0;

  {
    run_title: $run_title,
    session_id: $session_id,
    opencode_cmd: $opencode_cmd,
    captured_at: $captured_at,
    metrics_dir: $metrics_dir,
    session_id_file: $session_id_file,
    events_file: $events_file,
    log_file: $log_file,
    export_file: $export_file,
    session: {
      id: .info.id,
      slug: .info.slug,
      title: .info.title,
      agent: .info.agent,
      directory: .info.directory,
      path: .info.path,
      project_id: .info.projectID,
      model_id: .info.model.id,
      provider_id: .info.model.providerID,
      version: .info.version,
      created_ms: .info.time.created,
      updated_ms: .info.time.updated,
      summary: .info.summary
    },
    messages: {
      count: (.messages | length),
      user_count: ([.messages[] | select(.info.role == "user")] | length),
      assistant_count: ([.messages[] | select(.info.role == "assistant")] | length)
    },
    tokens: {
      total: token_sum(.tokens.total),
      input: token_sum(.tokens.input),
      output: token_sum(.tokens.output),
      reasoning: token_sum(.tokens.reasoning),
      cache_read: cache_sum("read"),
      cache_write: cache_sum("write")
    },
    cost: {
      reported_total: cost_sum,
      currency: "usd"
    }
  }
  ' "$export_file" > "$metrics_file"

jq '{run_title, session_id, tokens, cost, export_file, events_file, log_file}' "$metrics_file"

exit "$opencode_status"
