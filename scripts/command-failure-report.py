#!/usr/bin/env python3
"""Split the Bash errors /insights calls "Command Failed" into what produced them.

    ./scripts/command-failure-report.py [projects-dir]

session-meta records only a count per error category, and that count mixes a red
test run, a grep that found nothing, a guard hook's block and a genuine mistake.
This reads the transcripts instead, pairs each errored Bash result with the
command that produced it, and prints per ISO week:

  guard     a PreToolUse hook blocked it, tallied by hook script
  rejected  the user or a permission rule refused it
  exit      it ran and exited non-zero, tallied by command and exit code
  other     anything else, with the first 60 characters tallied

Read-only, and it prints counts and command heads rather than transcript text.
Transcripts rotate on the same schedule as session-meta, so it covers the same
month and is run in the same step of the synthesis procedure (scripts/README.md).
"""

import collections
import dataclasses
import datetime
import json
import pathlib
import re
import sys

DEFAULT_DIR = pathlib.Path.home() / ".claude" / "projects"

# The start of the period being read. Match session-meta-report.py's RETENTION_EDGE so the two
# reports describe the same sessions.
WINDOW_START = datetime.datetime(2026, 10, 20, tzinfo=datetime.timezone.utc)

HOOK_NAME = re.compile(r"hooks/([A-Za-z0-9_.-]+)")
EXIT_CODE = re.compile(r"^(?:Error: )?Exit code (\d+)")
REJECTION_MARKERS = ("doesn't want to proceed", "user rejected", "was rejected")
WRAPPERS = ("rtk", "proxy", "test", "err")
SUBCOMMAND_TOOLS = ("git", "gh", "bin/rails", "heroku")


@dataclasses.dataclass
class Result:
    files: int = 0
    tool_calls: collections.Counter = dataclasses.field(default_factory=collections.Counter)
    classes: dict = dataclasses.field(default_factory=lambda: collections.defaultdict(collections.Counter))
    hooks: dict = dataclasses.field(default_factory=lambda: collections.defaultdict(collections.Counter))
    exit_codes: collections.Counter = dataclasses.field(default_factory=collections.Counter)
    other: collections.Counter = dataclasses.field(default_factory=collections.Counter)


def classify(text, denial_kind):
    """Return (kind, detail) for an errored Bash result's text.

    A guard is checked first because a hook block also carries a permission-rule denial kind.
    """
    text = text.strip()
    if text.startswith("PreToolUse:"):
        match = HOOK_NAME.search(text)
        return "guard", match.group(1) if match else "?"
    if denial_kind or any(marker in text.lower() for marker in REJECTION_MARKERS):
        return "rejected", None
    match = EXIT_CODE.match(text)
    if match:
        return "exit", match.group(1)
    return "other", text[:60]


def command_head(command):
    words = command.strip().split()
    while words and words[0] in WRAPPERS:
        words = words[1:]
    if not words:
        return "?"
    if words[0] in SUBCOMMAND_TOOLS and len(words) > 1:
        return f"{words[0]} {words[1]}"
    return words[0]


def iso_week(moment):
    year, week, _ = moment.isocalendar()
    return f"{year}-W{week:02d}"


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(part.get("text", "") for part in content if isinstance(part, dict))
    return ""


def records(path):
    with path.open(errors="replace") as handle:
        for line in handle:
            if '"tool_use"' not in line and '"tool_result"' not in line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


def scan(paths, window_start):
    result = Result()
    for path in paths:
        result.files += 1
        commands = {}
        for record in records(path):
            if record.get("isSidechain") or "timestamp" not in record:
                continue
            moment = datetime.datetime.fromisoformat(record["timestamp"].replace("Z", "+00:00"))
            if moment < window_start:
                continue
            content = (record.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            week = iso_week(moment)
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_use":
                    result.tool_calls[week] += 1
                    if block.get("name") == "Bash":
                        commands[block.get("id")] = (block.get("input") or {}).get("command", "")
                elif block.get("type") == "tool_result" and block.get("is_error"):
                    command = commands.get(block.get("tool_use_id"))
                    if command is None:
                        continue
                    kind, detail = classify(text_of(block.get("content")), record.get("toolDenialKind"))
                    result.classes[week][kind] += 1
                    if kind == "guard":
                        result.hooks[week][detail] += 1
                    elif kind == "exit":
                        result.exit_codes[(command_head(command), detail)] += 1
                    elif kind == "other":
                        result.other[detail] += 1
    return result


def print_report(result):
    print(f"transcripts scanned: {result.files} (top-level, touched since {WINDOW_START.date()})")
    print()
    print("week       tools  guard  rejected   exit  other   guard/1k  exit/1k")
    for week in sorted(result.tool_calls):
        row = result.classes[week]
        calls = result.tool_calls[week]
        print(f"{week}  {calls:6d}  {row['guard']:5d}  {row['rejected']:8d}  {row['exit']:5d}  {row['other']:5d}"
              f"   {1000 * row['guard'] / calls:8.1f}  {1000 * row['exit'] / calls:7.1f}")
    print()
    print("guard blocks by hook, per week")
    for week in sorted(result.hooks):
        print(f"  {week}: " + ", ".join(f"{name} {n}" for name, n in result.hooks[week].most_common()))
    print()
    print("non-zero exits by command and code (top 20; grep's 1 is no match, a test runner's 1 is a red run)")
    for (head, code), n in result.exit_codes.most_common(20):
        print(f"  {n:5d}  {head}  exit {code}")
    if result.other:
        print()
        print("other errors, first 60 characters (top 10)")
        for sample, n in result.other.most_common(10):
            print(f"  {n:5d}  {sample!r}")


def main(argv):
    directory = pathlib.Path(argv[1]) if len(argv) > 1 else DEFAULT_DIR
    cutoff = WINDOW_START.timestamp()
    paths = [p for p in directory.glob("*/*.jsonl") if p.stat().st_mtime >= cutoff]
    if not paths:
        sys.exit(f"no transcripts touched since {WINDOW_START.date()} under {directory}")
    print_report(scan(paths, WINDOW_START))


if __name__ == "__main__":
    main(sys.argv)
