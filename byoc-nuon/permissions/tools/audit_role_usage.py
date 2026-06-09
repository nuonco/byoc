#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["boto3>=1.34"]
# ///
"""
Audit the real AWS API activity of an install's provision/deprovision/maintenance
roles via CloudTrail LookupEvents, so we can scope those roles down from
AdministratorAccess.

Data source: `cloudtrail:LookupEvents` (management events only, ~90d retention,
50/page, region-scoped). The org trail only ships to an S3 bucket we cannot read,
so this is the one path that works with current creds.

Everything is resumable: each paginated query is a "unit of work" with a sidecar
state file under <out>/.state. Completed units are skipped; interrupted units
resume from their checkpoint without duplicating jsonl lines. The `synthesize`
phase is pure/offline and re-runnable.

Usage (run via uv, which provisions boto3):
  uv run audit_role_usage.py collect-workflows [--types T...] [--exclude-types T...] [--statuses S... | any]
  uv run audit_role_usage.py collect-events [--workflow ID] [--max-window-min N]
  uv run audit_role_usage.py sweep [--max-pages N] [--no-skip]
  uv run audit_role_usage.py synthesize [--exclude-types T...]
  uv run audit_role_usage.py collect       # workflows + events + sweep

All commands take --install-id/--account/--profile/--regions/--since/--until/--out/--refresh.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import boto3
from botocore.config import Config

# ---- defaults ---------------------------------------------------------------
INSTALL_ID = "inlxk2hkgyfdekqlj48lwz298l"
ACCOUNT = "873976612236"
PROFILE = "sandbox-byoc.NuonAdmin"
REGIONS = ["us-west-2", "us-east-1"]
ROLE_SUFFIXES = ["provision", "deprovision", "maintenance"]
PAGE_SLEEP = 0.35  # gentle on LookupEvents' ~2 TPS limit

# Per-workflow lookup is unfiltered (no server-side EventSource filter), so it pages through
# ALL account events in the window. For pathologically long windows (e.g. adhoc actions left
# open for ~28h, or multi-hour deploys) that drown in background noise, attribution isn't worth
# tens of thousands of pages — those roles' activity is still captured by the aggregate `sweep`.
MAX_WINDOW_MIN = 180

# eventSource domains for the aggregate sweep (union of observed + boundary services).
# These are the CloudTrail eventSource values (NOT the IAM action prefix; see SERVICE_PREFIX).
BOUNDARY_EVENT_SOURCES = [
    "ec2.amazonaws.com",
    "eks.amazonaws.com",
    "iam.amazonaws.com",
    "rds.amazonaws.com",
    "s3.amazonaws.com",
    "kms.amazonaws.com",
    "route53.amazonaws.com",
    "acm.amazonaws.com",
    "secretsmanager.amazonaws.com",
    "sqs.amazonaws.com",
    "ecs.amazonaws.com",
    "ecr.amazonaws.com",
    "ecr-public.amazonaws.com",
    "elasticloadbalancing.amazonaws.com",
    "autoscaling.amazonaws.com",
    "application-autoscaling.amazonaws.com",
    "logs.amazonaws.com",
    "monitoring.amazonaws.com",  # cloudwatch
    "pi.amazonaws.com",
    "organizations.amazonaws.com",
    "sts.amazonaws.com",
    "events.amazonaws.com",
]

# eventSource -> IAM action prefix, where it differs from the first label.
SERVICE_PREFIX_OVERRIDE = {
    "monitoring.amazonaws.com": "cloudwatch",
}

# High-volume / low-signal eventSources to skip in the aggregate sweep: in this account they
# generate tens of thousands of background events (Karpenter/EKS/ASG/ELB) over 90 days while our
# roles barely touch them, and per-workflow collection already captured the roles' usage of
# them. Sweeping them would run for hours and change nothing.
SWEEP_SKIP_SOURCES = {
    "ec2.amazonaws.com",
    "autoscaling.amazonaws.com",
    "application-autoscaling.amazonaws.com",
    "elasticloadbalancing.amazonaws.com",
    "monitoring.amazonaws.com",
    "logs.amazonaws.com",
    "sts.amazonaws.com",
}
# Backstop so a surprise high-volume service can't run away silently. Truncation is logged.
SWEEP_MAX_PAGES = 600


def log(msg: str) -> None:
    ts = dt.datetime.now(dt.timezone.utc).strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", file=sys.stderr, flush=True)


def now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def parse_dt(s: str) -> dt.datetime:
    """Parse an RFC3339 timestamp (optionally with Z / fractional seconds)."""
    s = s.strip().replace("Z", "+00:00")
    d = dt.datetime.fromisoformat(s)
    if d.tzinfo is None:
        d = d.replace(tzinfo=dt.timezone.utc)
    return d


def iso(d: dt.datetime) -> str:
    return d.astimezone(dt.timezone.utc).isoformat()


def service_prefix(event_source: str) -> str:
    if event_source in SERVICE_PREFIX_OVERRIDE:
        return SERVICE_PREFIX_OVERRIDE[event_source]
    return event_source.split(".")[0]


# ---- state / paths ----------------------------------------------------------
class Ctx:
    def __init__(self, args):
        self.out = Path(args.out)
        self.install_id = args.install_id
        self.account = args.account
        self.profile = args.profile
        self.regions = args.regions
        self.roles = {
            suf: f"arn:aws:iam::{args.account}:role/{args.install_id}-{suf}"
            for suf in ROLE_SUFFIXES
        }
        if args.roles:  # explicit override: name=arn name=arn
            self.roles = dict(p.split("=", 1) for p in args.roles)
        self.since = parse_dt(args.since) if args.since else (now_utc() - dt.timedelta(days=90))
        self.until = parse_dt(args.until) if args.until else now_utc()
        self.refresh = getattr(args, "refresh", False)
        self.max_window_min = getattr(args, "max_window_min", None) or MAX_WINDOW_MIN
        self.max_pages = getattr(args, "max_pages", None) or SWEEP_MAX_PAGES
        self.sweep_skip = (set() if getattr(args, "no_skip", False)
                           else set(SWEEP_SKIP_SOURCES))
        self.types = set(getattr(args, "types", None) or [])
        self.exclude_types = set(getattr(args, "exclude_types", None) or [])
        self.statuses = set(getattr(args, "statuses", None) or ["success"])
        self._clients: dict[str, object] = {}
        (self.out / ".state" / "events").mkdir(parents=True, exist_ok=True)
        (self.out / ".state" / "sweep").mkdir(parents=True, exist_ok=True)

    def client(self, region: str):
        if region not in self._clients:
            session = boto3.Session(profile_name=self.profile)
            cfg = Config(retries={"max_attempts": 10, "mode": "adaptive"})
            self._clients[region] = session.client(
                "cloudtrail", region_name=region, config=cfg
            )
        return self._clients[region]


def load_state(p: Path) -> dict:
    if p.exists():
        return json.loads(p.read_text())
    return {}


def save_state(p: Path, state: dict) -> None:
    tmp = p.with_suffix(p.suffix + ".tmp")
    tmp.write_text(json.dumps(state, indent=2))
    tmp.replace(p)


def parse_event(ev: dict, roles: dict[str, str]) -> dict | None:
    """Return a compact record iff the event was made by one of our roles."""
    cte = json.loads(ev["CloudTrailEvent"])
    ui = cte.get("userIdentity", {}) or {}
    issuer = (ui.get("sessionContext", {}) or {}).get("sessionIssuer", {}) or {}
    arn = issuer.get("arn") or ui.get("arn") or ""
    matched = next((name for name, rarn in roles.items() if rarn == arn), None)
    if not matched:
        return None
    return {
        "role": matched,
        "eventTime": cte.get("eventTime"),
        "eventSource": cte.get("eventSource"),
        "eventName": cte.get("eventName"),
        "awsRegion": cte.get("awsRegion"),
        "readOnly": cte.get("readOnly"),
        "errorCode": cte.get("errorCode"),
        "resources": [r.get("ARN") for r in (ev.get("Resources") or []) if r.get("ARN")],
        "eventId": cte.get("eventID"),
    }


def run_lookup_unit(client, label, state_path: Path, jsonl_path: Path,
                    lookup_kwargs: dict, roles: dict[str, str], refresh: bool,
                    max_pages: int | None = None) -> dict:
    """Run one resumable, paginated lookup-events query. Idempotent."""
    state = load_state(state_path)
    if refresh:
        state = {}
    if state.get("status") in ("complete", "deferred", "capped"):
        log(f"skip {label} ({state.get('status')}, {state.get('count', 0)} role events)")
        return state

    jsonl_path.parent.mkdir(parents=True, exist_ok=True)
    if state.get("status") == "in-progress" and jsonl_path.exists():
        # Truncate any partially-written tail back to the last checkpointed boundary.
        with open(jsonl_path, "r+b") as f:
            f.truncate(state.get("bytes", 0))
        next_token = state.get("next_token")
        pages = state.get("pages", 0)
        count = state.get("count", 0)
        log(f"resume {label} (page {pages}, {count} role events so far)")
    else:
        open(jsonl_path, "w").close()
        next_token, pages, count = None, 0, 0
        state = {"status": "in-progress", "pages": 0, "count": 0, "bytes": 0,
                 "started": iso(now_utc())}
        save_state(state_path, state)

    f = open(jsonl_path, "ab")
    try:
        while True:
            kwargs = dict(lookup_kwargs)
            if next_token:
                kwargs["NextToken"] = next_token
            resp = client.lookup_events(**kwargs)
            for ev in resp.get("Events", []):
                rec = parse_event(ev, roles)
                if rec:
                    f.write((json.dumps(rec, separators=(",", ":")) + "\n").encode())
                    count += 1
            f.flush()
            os.fsync(f.fileno())
            pages += 1
            next_token = resp.get("NextToken")
            state.update({"status": "in-progress", "pages": pages, "count": count,
                          "bytes": f.tell(), "next_token": next_token})
            save_state(state_path, state)
            if not next_token:
                break
            if max_pages and pages >= max_pages:
                state["status"] = "capped"
                state["finished"] = iso(now_utc())
                save_state(state_path, state)
                log(f"CAPPED {label} at {pages} pages ({count} role events) — "
                    f"raise --max-pages to scan further")
                return state
            time.sleep(PAGE_SLEEP)
    finally:
        f.close()

    state["status"] = "complete"
    state["finished"] = iso(now_utc())
    state.pop("next_token", None)
    save_state(state_path, state)
    log(f"done {label}: {count} role events / {pages} pages")
    return state


# ---- nuon api ---------------------------------------------------------------
def nuon_api(path: str, q: dict | None = None) -> list:
    cmd = ["nuon", "api", path]
    for k, v in (q or {}).items():
        cmd += ["-q", f"{k}={v}"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"nuon api {path} failed: {res.stderr.strip()}")
    return json.loads(res.stdout)


# ---- phase A: workflows -----------------------------------------------------
def cmd_collect_workflows(ctx: Ctx) -> None:
    manifest = ctx.out / "workflows.json"
    # Merge into any existing manifest (union by id) so repeated runs with different
    # --types/--statuses accumulate rather than overwrite.
    existing = {w["id"]: w for w in json.loads(manifest.read_text())} if manifest.exists() else {}
    want_any_status = "any" in ctx.statuses
    added = 0
    offset, limit, stop = 0, 50, False
    while not stop:
        batch = nuon_api(f"/v1/installs/{ctx.install_id}/workflows",
                         {"planonly": "false", "limit": limit, "offset": offset})
        if not batch:
            break
        for w in batch:
            st = (w.get("status") or {}).get("status")
            sa, fa = w.get("started_at"), w.get("finished_at")
            if sa and parse_dt(sa) < ctx.since:
                stop = True  # newest-first; older than window from here on
                continue
            if ctx.types and w.get("type") not in ctx.types:
                continue
            if ctx.exclude_types and w.get("type") in ctx.exclude_types:
                continue
            if not want_any_status and st not in ctx.statuses:
                continue
            if not (sa and fa):
                continue  # need a bounded [start,end] window to query CloudTrail
            if w["id"] not in existing:
                added += 1
            existing[w["id"]] = {"id": w["id"], "type": w.get("type"), "status": st,
                                 "started_at": sa, "finished_at": fa}
        if len(batch) < limit:
            break
        offset += limit

    kept = sorted(existing.values(), key=lambda w: w["started_at"] or "")
    manifest.write_text(json.dumps(kept, indent=2))
    log(f"manifest {manifest}: {len(kept)} workflows (+{added} new) "
        f"[types={ctx.types or 'all'} exclude={ctx.exclude_types or 'none'} "
        f"statuses={ctx.statuses}] since {iso(ctx.since)}")

    for w in kept:
        (ctx.out / w["id"] / "logs").mkdir(parents=True, exist_ok=True)
        (ctx.out / w["id"] / "permissions").mkdir(parents=True, exist_ok=True)


# ---- phase B: per-workflow events ------------------------------------------
def _write_workflow_actions(ctx: Ctx, wf_id: str) -> None:
    by_role: dict[str, dict[str, set]] = {}
    for region in ctx.regions:
        p = ctx.out / wf_id / "logs" / f"{region}.jsonl"
        if not p.exists():
            continue
        for line in p.read_text().splitlines():
            if not line:
                continue
            rec = json.loads(line)
            by_role.setdefault(rec["role"], {}).setdefault(rec["eventSource"], set()).add(
                rec["eventName"])
    out = {role: {src: sorted(names) for src, names in srcs.items()}
           for role, srcs in by_role.items()}
    (ctx.out / wf_id / "permissions" / "actions.json").write_text(json.dumps(out, indent=2))


def cmd_collect_events(ctx: Ctx, only: str | None = None) -> None:
    manifest = ctx.out / "workflows.json"
    if not manifest.exists():
        sys.exit("workflows.json missing; run collect-workflows first")
    wfs = json.loads(manifest.read_text())
    if only:
        wfs = [w for w in wfs if w["id"] == only]
        if not wfs:
            sys.exit(f"workflow {only} not in manifest")
    log(f"collect-events for {len(wfs)} workflow(s) x {len(ctx.regions)} region(s)")
    for w in wfs:
        start = parse_dt(w["started_at"]) - dt.timedelta(minutes=1)
        end = parse_dt(w["finished_at"]) + dt.timedelta(minutes=1)
        window_min = (end - start).total_seconds() / 60
        if window_min > ctx.max_window_min:
            log(f"defer {w['id'][:10]}/{w['type']} ({window_min:.0f}m > "
                f"{ctx.max_window_min}m window) → covered by sweep")
            for region in ctx.regions:
                sp = ctx.out / ".state" / "events" / f"{w['id']}__{region}.json"
                jp = ctx.out / w["id"] / "logs" / f"{region}.jsonl"
                jp.unlink(missing_ok=True)  # drop any partial capture from an interrupted run
                save_state(sp, {"status": "deferred", "count": 0,
                                "window_min": round(window_min, 1),
                                "reason": "window exceeds max; covered by sweep"})
            continue
        for region in ctx.regions:
            run_lookup_unit(
                ctx.client(region),
                label=f"{w['id'][:10]}/{w['type']}/{region}",
                state_path=ctx.out / ".state" / "events" / f"{w['id']}__{region}.json",
                jsonl_path=ctx.out / w["id"] / "logs" / f"{region}.jsonl",
                lookup_kwargs={"StartTime": start, "EndTime": end},
                roles=ctx.roles,
                refresh=ctx.refresh,
            )
        _write_workflow_actions(ctx, w["id"])


# ---- phase C: aggregate sweep ----------------------------------------------
def _observed_event_sources(ctx: Ctx) -> set[str]:
    found: set[str] = set()
    for sub in ctx.out.glob("*/logs/*.jsonl"):
        for line in sub.read_text().splitlines():
            if line:
                found.add(json.loads(line)["eventSource"])
    return found


def cmd_sweep(ctx: Ctx) -> None:
    all_sources = set(BOUNDARY_EVENT_SOURCES) | _observed_event_sources(ctx)
    skipped = sorted(all_sources & ctx.sweep_skip)
    sources = sorted(all_sources - ctx.sweep_skip)
    log(f"sweep {len(sources)} eventSources x {len(ctx.regions)} regions, "
        f"{iso(ctx.since)} .. {iso(ctx.until)} (max {ctx.max_pages} pages/unit)")
    if skipped:
        log(f"sweep SKIPS high-volume/low-signal sources (covered per-workflow): "
            f"{', '.join(s.split('.')[0] for s in skipped)}")
    for region in ctx.regions:
        for src in sources:
            run_lookup_unit(
                ctx.client(region),
                label=f"sweep/{region}/{src}",
                state_path=ctx.out / ".state" / "sweep" / f"{region}__{src}.json",
                jsonl_path=ctx.out / "_aggregate" / region / f"{src}.jsonl",
                lookup_kwargs={
                    "StartTime": ctx.since,
                    "EndTime": ctx.until,
                    "LookupAttributes": [
                        {"AttributeKey": "EventSource", "AttributeValue": src}
                    ],
                },
                roles=ctx.roles,
                refresh=ctx.refresh,
                max_pages=ctx.max_pages,
            )


# ---- phase D: synthesize ----------------------------------------------------
def _iter_all_records(ctx: Ctx):
    # Skip per-workflow logs whose workflow type is excluded (e.g. adhoc actions —
    # arbitrary user commands that shouldn't define the role baseline). The aggregate
    # sweep is not workflow-bound, so it is always included.
    manifest = ctx.out / "workflows.json"
    wf_type = ({w["id"]: w.get("type") for w in json.loads(manifest.read_text())}
               if manifest.exists() else {})
    skipped = 0
    for sub in ctx.out.glob("*/logs/*.jsonl"):
        wid = sub.parent.parent.name
        if ctx.exclude_types and wf_type.get(wid) in ctx.exclude_types:
            skipped += 1
            continue
        for line in sub.read_text().splitlines():
            if line:
                yield json.loads(line)
    if skipped:
        log(f"synthesize excluded {skipped} log files of types {sorted(ctx.exclude_types)}")
    for sub in ctx.out.glob("_aggregate/*/*.jsonl"):
        for line in sub.read_text().splitlines():
            if line:
                yield json.loads(line)


def cmd_synthesize(ctx: Ctx) -> None:
    agg = ctx.out / "_aggregate"
    agg.mkdir(parents=True, exist_ok=True)
    per_role: dict[str, dict[str, dict]] = {r: {} for r in ctx.roles}
    for rec in _iter_all_records(ctx):
        role = rec["role"]
        prefix = service_prefix(rec["eventSource"])
        action = f"{prefix}:{rec['eventName']}"
        slot = per_role.setdefault(role, {}).setdefault(
            action, {"count": 0, "denied": 0, "service": prefix})
        slot["count"] += 1
        if rec.get("errorCode"):
            slot["denied"] += 1

    summary = ["# Role usage synthesis", "",
               f"Install `{ctx.install_id}` · account `{ctx.account}` · "
               f"window `{iso(ctx.since)}` .. `{iso(ctx.until)}`", "",
               "Source: CloudTrail LookupEvents (management events only — object-level / "
               "data-plane actions are NOT captured and must be added by hand from component "
               "Terraform).", ""]

    for role, actions in per_role.items():
        names = sorted(actions)
        (agg / f"{role}.actions.txt").write_text("\n".join(names) + ("\n" if names else ""))
        by_service: dict[str, list[str]] = {}
        for a in names:
            by_service.setdefault(actions[a]["service"], []).append(a)
        statements = [
            {"Sid": svc.replace("-", ""), "Effect": "Allow",
             "Action": sorted(acts), "Resource": "*"}
            for svc, acts in sorted(by_service.items())
        ]
        (agg / f"{role}.policy.json").write_text(
            json.dumps({"Version": "2012-10-17", "Statement": statements}, indent=2))

        summary.append(f"## {role}  ({len(names)} distinct actions, "
                       f"{len(by_service)} services)")
        if not names:
            summary.append("_no role activity observed in window_\n")
            continue
        for svc in sorted(by_service):
            acts = by_service[svc]
            denied = sum(1 for a in acts if actions[a]["denied"])
            note = f"  ⚠️ {denied} denied" if denied else ""
            summary.append(f"- **{svc}** ({len(acts)}){note}: "
                           + ", ".join(a.split(":", 1)[1] for a in acts))
        summary.append("")

    summary += [
        "## Gaps / caveats",
        "- Data-plane actions (e.g. `s3:GetObject/PutObject`, KMS data-plane) are invisible to "
        "LookupEvents — fold in from `src/components/s3_buckets/*.tf` and existing "
        "`permissions/policies/*.json`.",
        "- Only the captured workflow windows + the (optional) full-window sweep are covered; "
        "actions from before CloudTrail's ~90d retention are not visible.",
        "- `service:Action` mapping is first-pass (eventSource→prefix); hand-verify IAM action "
        "names that differ from API names.",
        "- All statements use `Resource: \"*\"`; tighten with the install-tag / install-id scoping "
        "pattern from `maintenance_boundary.json` and `policies/rds-secret.json`.",
    ]
    (agg / "SUMMARY.md").write_text("\n".join(summary) + "\n")
    log(f"wrote {agg}/SUMMARY.md and per-role actions/policy files")


# ---- cli --------------------------------------------------------------------
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--install-id", default=INSTALL_ID)
    p.add_argument("--account", default=ACCOUNT)
    p.add_argument("--profile", default=PROFILE)
    p.add_argument("--regions", nargs="+", default=REGIONS)
    p.add_argument("--roles", nargs="+", help="override role list as name=arn name=arn")
    p.add_argument("--since", help="RFC3339; default now-90d")
    p.add_argument("--until", help="RFC3339; default now")
    p.add_argument("--out", default="./tmp")
    p.add_argument("--refresh", action="store_true",
                   help="force re-fetch units instead of skipping completed ones")
    sub = p.add_subparsers(dest="cmd", required=True)

    pw = sub.add_parser("collect-workflows")
    pw.add_argument("--types", nargs="+",
                    help="only these workflow types (e.g. reprovision reprovision_sandbox)")
    pw.add_argument("--statuses", nargs="+",
                    help="workflow statuses to keep, or 'any' (default: success)")
    pw.add_argument("--exclude-types", nargs="+",
                    help="workflow types to drop (e.g. action_workflow_run sync_secrets)")

    pe = sub.add_parser("collect-events")
    pe.add_argument("--workflow", help="limit to one workflow id")
    pe.add_argument("--max-window-min", type=int, default=MAX_WINDOW_MIN,
                    help="defer per-workflow windows longer than this (covered by sweep)")

    ps = sub.add_parser("sweep")
    ps.add_argument("--max-pages", type=int, default=SWEEP_MAX_PAGES,
                    help="page cap per (region,service) unit; capped units are logged")
    ps.add_argument("--no-skip", action="store_true",
                    help="do not skip high-volume sources (ec2, autoscaling, logs, ...)")

    psy = sub.add_parser("synthesize")
    psy.add_argument("--exclude-types", nargs="+",
                     help="exclude per-workflow logs of these types (e.g. action_workflow_run)")

    sub.add_parser("collect")  # workflows + events + sweep
    return p


def main() -> None:
    args = build_parser().parse_args()
    os.environ.setdefault("AWS_PROFILE", args.profile)
    ctx = Ctx(args)
    if args.cmd == "collect-workflows":
        cmd_collect_workflows(ctx)
    elif args.cmd == "collect-events":
        cmd_collect_events(ctx, only=args.workflow)
    elif args.cmd == "sweep":
        cmd_sweep(ctx)
    elif args.cmd == "synthesize":
        cmd_synthesize(ctx)
    elif args.cmd == "collect":
        cmd_collect_workflows(ctx)
        cmd_collect_events(ctx)
        cmd_sweep(ctx)


if __name__ == "__main__":
    main()
