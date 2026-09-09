#!/usr/bin/env python3
"""Aggregate the per-session JSON that `/insights` leaves in usage-data/session-meta/.

`/insights` writes one JSON file per session plus a rendered HTML report. The HTML
carries whole-range totals; a synthesis needs the trend, which means bucketing the
per-session files by week and by project. This script does only that. It applies no
thresholds and makes no judgements, so every figure it prints is a count or a straight
ratio over counts — the reading is the synthesis author's job.

Two traps this script exists to make visible, both of which mislead in the report:

  Coverage. session-meta is an incremental cache, not a rebuild: /insights adds a file the
  first time it sees a transcript and rewrites only the ones that changed since. Observed
  on 2026-09-09, where a second run 36 minutes after the first left 142 of 145 files
  untouched and refreshed the three whose sessions were still live. So the report's date
  range is the span of session *start* times, which a few long-lived resumed sessions
  stretch months past the period the bulk of the data describes. The retention-check
  section prints where start dates actually become continuous.

  Duration. Sessions are left open rather than worked continuously, so total hours is
  dominated by a few held-open sessions. The duration-skew section prints what share the
  top few hold, which is the number that decides whether the total means anything.

The model-analysed fields (goal achievement, satisfaction, friction type) are NOT in these
files — they live only in the report's LLM pass. When that pass fails it does so silently:
the run reports a session count as normal and every model-derived section renders "No data",
which reads like a finding rather than a failure. Re-run before concluding anything from it.
The field-presence section prints what is actually available for the run at hand.

Usage: scripts/session-meta-report.py [session-meta-dir]
"""

import datetime
import json
import pathlib
import sys
from collections import Counter, defaultdict

DEFAULT_DIR = pathlib.Path.home() / ".claude" / "usage-data" / "session-meta"

# Where start dates become continuous. Sessions before this point are in the data only
# because they were resumed later, so they describe the tail of an old session rather than
# the period they date from, and the trend sections drop them. Recompute when the window
# moves.
#
# UNTESTED: whether a captured session survives its own transcript rotating out. The cache
# updates incrementally, but nothing observed so far says whether a stale entry is kept or
# pruned — and the answer decides whether coverage accumulates across runs or only ever
# reaches back one rotation. The three 2026-05 sessions here were last written to between
# 2026-08-10 and 2026-08-20, so they rotate around 2026-09-09 to 2026-09-19; if their files
# are still present after that, the cache accumulates.
RETENTION_EDGE = "2026-08-10"


def load(directory):
    sessions = []
    for path in sorted(directory.glob("*.json")):
        with path.open() as handle:
            sessions.append(json.load(handle))
    if not sessions:
        sys.exit(f"no session JSON found under {directory}")
    return sessions


def tool_calls(session):
    return sum(session.get("tool_counts", {}).values())


def iso_week(session):
    day = datetime.date.fromisoformat(session["start_time"][:10])
    year, week, _ = day.isocalendar()
    return f"{year}-W{week:02d}"


def field_presence(sessions):
    print("\n== field presence (sessions carrying each key) ==")
    print("   Check for goal/sentiment fields before assuming a qualitative read is possible.")
    keys = Counter()
    for session in sessions:
        keys.update(session.keys())
    for key, count in sorted(keys.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"  {count:4d}  {key}")


def retention_check(sessions):
    print("\n== retention check ==")
    print(f"   Trend sections below drop sessions starting before {RETENTION_EDGE}.")
    for session in sorted(sessions, key=lambda s: s["start_time"])[:6]:
        touched = datetime.datetime.fromtimestamp(
            session.get("transcript_mtime", 0) / 1000, datetime.timezone.utc)
        print(f"  start {session['start_time'][:10]}  last-touched {touched:%Y-%m-%d}  "
              f"{session.get('duration_minutes', 0):>6}m  "
              f"{session.get('project_path', '?').split('/')[-1]}")
    days = sorted({s["start_time"][:10] for s in sessions})
    print(f"  {len(days)} distinct start days, {days[0]} .. {days[-1]}")


def weekly_trend(retained):
    by_week = defaultdict(list)
    for session in retained:
        by_week[iso_week(session)].append(session)

    print("\n== per ISO week (retained window) ==")
    print("   Calendar months mis-bucket a window that opens and closes mid-month.")
    header = ("week", "sess", "commits", "interrupt", "errors", "tools", "err/1k",
              "cmdfail/1k", "int/sess")
    print("  {:<10}{:>6}{:>9}{:>11}{:>8}{:>8}{:>8}{:>12}{:>10}".format(*header))
    for week in sorted(by_week):
        group = by_week[week]
        calls = sum(tool_calls(s) for s in group)
        errors = sum(s.get("tool_errors", 0) for s in group)
        interrupts = sum(s.get("user_interruptions", 0) for s in group)
        commits = sum(s.get("git_commits", 0) for s in group)
        failures = sum(s.get("tool_error_categories", {}).get("Command Failed", 0)
                       for s in group)
        print(f"  {week:<10}{len(group):>6}{commits:>9}{interrupts:>11}{errors:>8}"
              f"{calls:>8}{errors / calls * 1000:>8.1f}"
              f"{failures / calls * 1000:>12.1f}{interrupts / len(group):>10.2f}")

    print("\n== error categories per week ==")
    for week in sorted(by_week):
        cats = Counter()
        for session in by_week[week]:
            cats.update(session.get("tool_error_categories", {}))
        print(f"  {week}: " + ", ".join(f"{name} {count}"
                                        for name, count in cats.most_common()))

    print("\n== project mix per week (share of tool calls) ==")
    print("   Read alongside per-project error rates: a rate change can be mix moving.")
    for week in sorted(by_week):
        mix = Counter()
        for session in by_week[week]:
            mix[session.get("project_path", "?").split("/")[-1]] += tool_calls(session)
        total = sum(mix.values()) or 1
        print(f"  {week}: " + ", ".join(f"{name} {count / total * 100:.0f}%"
                                        for name, count in mix.most_common(5)))


def per_project(retained):
    print("\n== error rate by project (retained window) ==")
    stats = defaultdict(lambda: [0, 0, 0])
    for session in retained:
        row = stats[session.get("project_path", "?").split("/")[-1]]
        row[0] += 1
        row[1] += session.get("tool_errors", 0)
        row[2] += tool_calls(session)
    print("  {:<18}{:>6}{:>8}{:>8}{:>8}".format("project", "sess", "errors", "tools",
                                                "err/1k"))
    for name, (count, errors, calls) in sorted(stats.items(), key=lambda kv: -kv[1][2]):
        rate = (errors / calls * 1000) if calls else 0
        print(f"  {name:<18}{count:>6}{errors:>8}{calls:>8}{rate:>8.1f}")


def duration_skew(sessions):
    print("\n== duration skew (whether the hours total means anything) ==")
    durations = sorted((s.get("duration_minutes", 0) for s in sessions), reverse=True)
    total = sum(durations)
    print(f"  total {total / 60:.0f}h across {len(durations)} sessions")
    for cut in (1, 5, 10):
        print(f"  top {cut:>2} sessions hold {sum(durations[:cut]) / total * 100:>4.1f}%"
              " of all recorded minutes")
    print(f"  median {durations[len(durations) // 2]}m, mean {total / len(durations):.0f}m")


def adoption(sessions, retained):
    print("\n== capability adoption (sessions using it, retained window) ==")
    by_week = defaultdict(list)
    for session in retained:
        by_week[iso_week(session)].append(session)
    for flag in ("uses_task_agent", "uses_mcp", "uses_web_search", "uses_web_fetch"):
        cells = [f"{week} {sum(1 for s in by_week[week] if s.get(flag))}"
                 f"/{len(by_week[week])}" for week in sorted(by_week)]
        print(f"  {flag}: " + "  ".join(cells))

    resumed = sum(1 for s in sessions
                  if (s.get("first_prompt") or "").strip().lower().startswith("resume"))
    print(f"\n  sessions opening with 'resume': {resumed}/{len(sessions)}")

    print("\n== tool mix (retained window, top 10) ==")
    tools = Counter()
    for session in retained:
        tools.update(session.get("tool_counts", {}))
    for name, count in tools.most_common(10):
        print(f"  {count:6d}  {name}")


def outliers(sessions):
    print("\n== longest sessions ==")
    for session in sorted(sessions, key=lambda s: -s.get("duration_minutes", 0))[:10]:
        prompt = (session.get("first_prompt") or "")[:60].replace("\n", " ")
        print(f"  {session.get('duration_minutes', 0):5d}m  "
              f"{session.get('project_path', '?').split('/')[-1]:<18} {prompt}")

    print("\n== most-interrupted sessions ==")
    for session in sorted(sessions, key=lambda s: -s.get("user_interruptions", 0))[:10]:
        prompt = (session.get("first_prompt") or "")[:60].replace("\n", " ")
        print(f"  {session.get('user_interruptions', 0):3d}x  "
              f"{session.get('project_path', '?').split('/')[-1]:<18} {prompt}")


def main(directory):
    sessions = load(directory)
    retained = [s for s in sessions if s["start_time"][:10] >= RETENTION_EDGE]
    print(f"sessions: {len(sessions)} ({len(retained)} at or after {RETENTION_EDGE})")
    print(f"range: {min(s['start_time'] for s in sessions)[:10]}"
          f" .. {max(s['start_time'] for s in sessions)[:10]}")
    field_presence(sessions)
    retention_check(sessions)
    weekly_trend(retained)
    per_project(retained)
    duration_skew(sessions)
    adoption(sessions, retained)
    outliers(sessions)


if __name__ == "__main__":
    main(pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_DIR)
