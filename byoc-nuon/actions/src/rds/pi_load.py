#!/usr/bin/env python3
"""Fetch RDS Performance Insights db.load.avg and render an ASCII graph."""

import json
import os
import sys
from datetime import datetime, timedelta, timezone

import boto3

DB_RESOURCE_ID = os.environ["DB_RESOURCE_ID"]
OUTPUT_FILE = os.environ.get("NUON_ACTIONS_OUTPUT_FILEPATH")

PERIOD = 60  # seconds
LOOKBACK_MINUTES = 60
GRAPH_HEIGHT = 15
GRAPH_WIDTH = 60


def fetch_load(pi_client, resource_id, start, end):
    resp = pi_client.get_resource_metrics(
        ServiceType="RDS",
        Identifier=resource_id,
        MetricQueries=[{"Metric": "db.load.avg"}],
        StartTime=start,
        EndTime=end,
        PeriodInSeconds=PERIOD,
    )
    points = []
    for result in resp.get("MetricList", []):
        for dp in result.get("DataPoints", []):
            ts = dp["Timestamp"]
            if isinstance(ts, datetime):
                t = ts
            else:
                t = datetime.fromisoformat(str(ts))
            points.append((t, dp.get("Value", 0.0)))
    points.sort(key=lambda x: x[0])
    return points


def ascii_graph(points, height=GRAPH_HEIGHT, width=GRAPH_WIDTH):
    if not points:
        return "  (no data)\n"

    # downsample if needed
    if len(points) > width:
        step = len(points) / width
        sampled = []
        for i in range(width):
            idx = int(i * step)
            sampled.append(points[idx])
        points = sampled

    values = [v for _, v in points]
    max_val = max(values) if values else 1
    min_val = min(values) if values else 0
    if max_val == min_val:
        max_val = min_val + 1

    lines = []

    # y-axis labels width
    y_fmt = lambda v: f"{v:6.2f}"
    label_w = 6

    for row in range(height, -1, -1):
        threshold = min_val + (max_val - min_val) * row / height
        label = y_fmt(threshold) if row % 3 == 0 else " " * label_w
        chars = []
        for v in values:
            level = (v - min_val) / (max_val - min_val) * height
            if level >= row:
                chars.append("\u2588")
            else:
                chars.append(" ")
        lines.append(f"{label} \u2502{''.join(chars)}")

    # x-axis
    lines.append(" " * label_w + " \u2514" + "\u2500" * len(values))

    # time labels
    t_start = points[0][0].strftime("%H:%M")
    t_end = points[-1][0].strftime("%H:%M")
    pad = len(values) - len(t_start) - len(t_end)
    if pad < 1:
        pad = 1
    lines.append(" " * (label_w + 2) + t_start + " " * pad + t_end)

    return "\n".join(lines) + "\n"


def main():
    now = datetime.now(timezone.utc)
    start = now - timedelta(minutes=LOOKBACK_MINUTES)

    pi = boto3.client("pi")
    points = fetch_load(pi, DB_RESOURCE_ID, start, now)

    if not points:
        print("No Performance Insights data returned.", file=sys.stderr)
        result = {"resource_id": DB_RESOURCE_ID, "points": 0, "graph": "(no data)"}
    else:
        values = [v for _, v in points]
        graph = ascii_graph(points)
        print(f"\n  db.load.avg  —  last {LOOKBACK_MINUTES}m  —  {DB_RESOURCE_ID}\n", file=sys.stderr)
        print(graph, file=sys.stderr)

        result = {
            "resource_id": DB_RESOURCE_ID,
            "points": len(points),
            "min": round(min(values), 3),
            "max": round(max(values), 3),
            "avg": round(sum(values) / len(values), 3),
            "latest": round(values[-1], 3),
            "graph": graph,
        }

    output = json.dumps(result)
    print(output)
    if OUTPUT_FILE:
        with open(OUTPUT_FILE, "a") as f:
            f.write(output + "\n")


if __name__ == "__main__":
    main()
