#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import time
from collections import defaultdict
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Dict, Iterable, Iterator, Tuple


INFO_LINE_RE = re.compile(r"^INFO\s+(?P<timestamp>\S+)\s+\+(?P<elapsed_ms>\d+)ms(?:\s+(?P<rest>.*))?$")
KV_RE = re.compile(r"(?P<key>[A-Za-z0-9_.-]+)=(?P<value>[^\s]+)")
TOOL_FAILURE_RE = re.compile(r"^✗\s+(?P<tool>[A-Za-z0-9_.-]+)\b.*\bfailed\b")


@dataclass(frozen=True)
class MetricDef:
    name: str
    metric_type: str
    help_text: str


METRICS = {
    "opencode_exporter_up": MetricDef(
        "opencode_exporter_up", "gauge", "Whether the OpenCode Prometheus exporter is running."
    ),
    "opencode_runs_stored": MetricDef(
        "opencode_runs_stored", "gauge", "Number of exported OpenCode runs found on disk."
    ),
    "opencode_runs_total": MetricDef(
        "opencode_runs_total", "counter", "Total exported OpenCode runs grouped by provider, model, and agent."
    ),
    "opencode_run_duration_seconds_total": MetricDef(
        "opencode_run_duration_seconds_total", "counter", "Total OpenCode run duration in seconds."
    ),
    "opencode_tokens_total": MetricDef(
        "opencode_tokens_total", "counter", "Total OpenCode tokens grouped by token kind."
    ),
    "opencode_cost_usd_total": MetricDef(
        "opencode_cost_usd_total", "counter", "Total reported OpenCode cost in USD from exported sessions."
    ),
    "opencode_messages_total": MetricDef(
        "opencode_messages_total", "counter", "Total exported OpenCode messages grouped by role."
    ),
    "opencode_tool_calls_total": MetricDef(
        "opencode_tool_calls_total", "counter", "Total exported OpenCode tool calls grouped by tool and status."
    ),
    "opencode_step_finishes_total": MetricDef(
        "opencode_step_finishes_total", "counter", "Total exported OpenCode step finishes grouped by reason."
    ),
    "opencode_session_file_changes_total": MetricDef(
        "opencode_session_file_changes_total", "counter", "Total exported file change summary values grouped by change kind."
    ),
    "opencode_latest_run_timestamp_seconds": MetricDef(
        "opencode_latest_run_timestamp_seconds", "gauge", "Unix timestamp of the latest exported OpenCode run."
    ),
    "opencode_latest_run_duration_seconds": MetricDef(
        "opencode_latest_run_duration_seconds", "gauge", "Duration in seconds of the latest exported OpenCode run."
    ),
    "opencode_latest_run_tokens": MetricDef(
        "opencode_latest_run_tokens", "gauge", "Token totals for the latest exported OpenCode run grouped by token kind."
    ),
    "opencode_log_events_total": MetricDef(
        "opencode_log_events_total", "counter", "Total OpenCode INFO log events grouped by service, status, and event type."
    ),
    "opencode_log_duration_seconds_total": MetricDef(
        "opencode_log_duration_seconds_total", "counter", "Total duration in seconds reported in OpenCode INFO log lines."
    ),
    "opencode_log_tool_failures_total": MetricDef(
        "opencode_log_tool_failures_total", "counter", "Total OpenCode tool failures parsed from stderr logs."
    ),
    "opencode_log_errors_total": MetricDef(
        "opencode_log_errors_total", "counter", "Total OpenCode error lines parsed from stderr logs."
    ),
}


class MetricStore:
    def __init__(self) -> None:
        self.samples: Dict[str, Dict[Tuple[Tuple[str, str], ...], float]] = defaultdict(lambda: defaultdict(float))

    def add(self, name: str, value: float, **labels: str) -> None:
        normalized = tuple(sorted((key, str(val)) for key, val in labels.items()))
        self.samples[name][normalized] += float(value)

    def set(self, name: str, value: float, **labels: str) -> None:
        normalized = tuple(sorted((key, str(val)) for key, val in labels.items()))
        self.samples[name][normalized] = float(value)

    def render(self) -> str:
        lines = []
        for name in sorted(METRICS):
            metric = METRICS[name]
            lines.append(f"# HELP {metric.name} {metric.help_text}")
            lines.append(f"# TYPE {metric.name} {metric.metric_type}")
            for labels, value in sorted(self.samples.get(name, {}).items()):
                if labels:
                    rendered = ",".join(f'{key}="{escape_label(value_)}"' for key, value_ in labels)
                    lines.append(f"{metric.name}{{{rendered}}} {format_float(value)}")
                else:
                    lines.append(f"{metric.name} {format_float(value)}")
        return "\n".join(lines) + "\n"


def escape_label(value: str) -> str:
    return value.replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def format_float(value: float) -> str:
    if value.is_integer():
        return str(int(value))
    return f"{value:.12g}"


def read_json(path: Path) -> dict | None:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return None


def iter_run_dirs(metrics_dir: Path) -> Iterator[Path]:
    if not metrics_dir.exists():
        return iter(())
    return (path for path in sorted(metrics_dir.iterdir()) if path.is_dir() and (path / "run-metrics.json").exists())


def parse_log_line(line: str) -> tuple[str, dict[str, str], float | None] | None:
    match = INFO_LINE_RE.match(line)
    if not match:
        return None
    rest = match.group("rest") or ""
    labels = {item.group("key"): item.group("value") for item in KV_RE.finditer(rest)}
    try:
        duration_seconds = float(labels["duration"]) / 1000.0 if "duration" in labels else None
    except ValueError:
        duration_seconds = None
    return rest, labels, duration_seconds


def classify_error(line: str) -> str:
    lowered = line.lower()
    if "file not found" in lowered:
        return "file_not_found"
    if "$work_dir" in line:
        return "unexpanded_work_dir"
    return "generic"


def build_metrics(metrics_dir: Path) -> MetricStore:
    store = MetricStore()
    store.set("opencode_exporter_up", 1)

    latest_by_identity: Dict[Tuple[str, str, str], dict] = {}
    run_count = 0

    for run_dir in iter_run_dirs(metrics_dir):
        run_count += 1
        run_metrics_path = run_dir / "run-metrics.json"
        run_metrics = read_json(run_metrics_path)
        if not run_metrics:
            continue

        session = run_metrics.get("session", {})
        provider_id = session.get("provider_id", "unknown")
        model_id = session.get("model_id", "unknown")
        agent = session.get("agent", "unknown")
        identity = {
            "provider_id": provider_id,
            "model_id": model_id,
            "agent": agent,
        }

        store.add("opencode_runs_total", 1, **identity)

        created_ms = session.get("created_ms")
        updated_ms = session.get("updated_ms")
        duration_seconds = 0.0
        if isinstance(created_ms, (int, float)) and isinstance(updated_ms, (int, float)) and updated_ms >= created_ms:
            duration_seconds = (updated_ms - created_ms) / 1000.0
            store.add("opencode_run_duration_seconds_total", duration_seconds, **identity)

        for token_kind, value in (run_metrics.get("tokens") or {}).items():
            if isinstance(value, (int, float)):
                store.add("opencode_tokens_total", value, token_kind=token_kind, **identity)

        reported_cost = ((run_metrics.get("cost") or {}).get("reported_total"))
        if isinstance(reported_cost, (int, float)):
            store.add("opencode_cost_usd_total", reported_cost, **identity)

        messages = run_metrics.get("messages") or {}
        role_mappings = {
            "count": "all",
            "user_count": "user",
            "assistant_count": "assistant",
        }
        for key, role in role_mappings.items():
            value = messages.get(key)
            if isinstance(value, (int, float)):
                store.add("opencode_messages_total", value, role=role, **identity)

        summary = session.get("summary") or {}
        for change_kind in ("files", "additions", "deletions"):
            value = summary.get(change_kind)
            if isinstance(value, (int, float)):
                store.add("opencode_session_file_changes_total", value, change_kind=change_kind, **identity)

        latest_key = (provider_id, model_id, agent)
        latest_current = latest_by_identity.get(latest_key)
        current_timestamp = float(created_ms or 0)
        if latest_current is None or current_timestamp >= latest_current["created_ms"]:
            latest_by_identity[latest_key] = {
                "created_ms": current_timestamp,
                "duration_seconds": duration_seconds,
                "tokens": run_metrics.get("tokens") or {},
            }

        export_file = run_metrics.get("export_file")
        export_payload = read_json(Path(export_file)) if export_file else None
        if export_payload:
            for message in export_payload.get("messages", []):
                for part in message.get("parts", []):
                    if part.get("type") == "tool":
                        store.add(
                            "opencode_tool_calls_total",
                            1,
                            tool=part.get("tool", "unknown"),
                            status=((part.get("state") or {}).get("status", "unknown")),
                            **identity,
                        )
                    elif part.get("type") == "step-finish":
                        store.add(
                            "opencode_step_finishes_total",
                            1,
                            reason=part.get("reason", "unknown"),
                            **identity,
                        )

        log_file = run_metrics.get("log_file")
        if log_file:
            log_path = Path(log_file)
            if log_path.exists():
                try:
                    with log_path.open("r", encoding="utf-8", errors="replace") as handle:
                        for raw_line in handle:
                            line = raw_line.strip()
                            if not line:
                                continue
                            parsed = parse_log_line(line)
                            if parsed:
                                _, labels, duration_seconds_from_log = parsed
                                store.add(
                                    "opencode_log_events_total",
                                    1,
                                    service=labels.get("service", "unknown"),
                                    status=labels.get("status", "unknown"),
                                    event_type=labels.get("type", "none"),
                                )
                                if duration_seconds_from_log is not None:
                                    store.add(
                                        "opencode_log_duration_seconds_total",
                                        duration_seconds_from_log,
                                        service=labels.get("service", "unknown"),
                                        status=labels.get("status", "unknown"),
                                    )
                                continue

                            tool_failure = TOOL_FAILURE_RE.match(line)
                            if tool_failure:
                                store.add(
                                    "opencode_log_tool_failures_total",
                                    1,
                                    tool=tool_failure.group("tool"),
                                    kind=classify_error(line),
                                )
                                continue

                            if line.startswith("Error:"):
                                store.add(
                                    "opencode_log_errors_total",
                                    1,
                                    kind=classify_error(line),
                                )
                except OSError:
                    pass

    store.set("opencode_runs_stored", run_count)

    for (provider_id, model_id, agent), latest in latest_by_identity.items():
        labels = {
            "provider_id": provider_id,
            "model_id": model_id,
            "agent": agent,
        }
        store.set(
            "opencode_latest_run_timestamp_seconds",
            latest["created_ms"] / 1000.0,
            **labels,
        )
        store.set(
            "opencode_latest_run_duration_seconds",
            latest["duration_seconds"],
            **labels,
        )
        for token_kind, value in latest["tokens"].items():
            if isinstance(value, (int, float)):
                store.set("opencode_latest_run_tokens", value, token_kind=token_kind, **labels)

    return store


class MetricsHandler(BaseHTTPRequestHandler):
    metrics_dir = Path("/app/share/opencode-runs")

    def do_GET(self) -> None:  # noqa: N802
        if self.path not in ("/metrics", "/metrics/"):
            self.send_response(404)
            self.end_headers()
            return

        body = build_metrics(self.metrics_dir).render().encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_HEAD(self) -> None:  # noqa: N802
        if self.path not in ("/metrics", "/metrics/"):
            self.send_response(404)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.end_headers()

    def log_message(self, format: str, *args: object) -> None:
        return


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Expose OpenCode run metrics for Prometheus.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=9464)
    parser.add_argument("--metrics-dir", default="/app/share/opencode-runs")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    MetricsHandler.metrics_dir = Path(args.metrics_dir)
    server = ThreadingHTTPServer((args.host, args.port), MetricsHandler)
    print(
        f"OpenCode metrics exporter listening on http://{args.host}:{args.port}/metrics ",
        f"(metrics dir: {args.metrics_dir})",
        flush=True,
    )
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
