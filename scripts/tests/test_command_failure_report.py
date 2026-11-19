"""Tests for scripts/command-failure-report.py.

Loaded as `command_failure_report` by the package __init__. Covers the three
functions that decide what a failure *is* — `classify`, `command_head`, and
`scan` — and leaves the printing alone, for the reason test_session_meta_report
gives.
"""

import datetime
import json
import tempfile
import unittest
from pathlib import Path

import command_failure_report as report

WINDOW = datetime.datetime(2026, 10, 20, tzinfo=datetime.timezone.utc)


def bash_call(tool_id, command, timestamp="2026-11-03T10:00:00Z", **extra):
    return {
        "type": "assistant",
        "timestamp": timestamp,
        "message": {"content": [
            {"type": "tool_use", "id": tool_id, "name": "Bash", "input": {"command": command}},
        ]},
        **extra,
    }


def other_call(tool_id, name, timestamp="2026-11-03T10:00:00Z"):
    return {
        "type": "assistant",
        "timestamp": timestamp,
        "message": {"content": [{"type": "tool_use", "id": tool_id, "name": name, "input": {}}]},
    }


def error_result(tool_id, text, timestamp="2026-11-03T10:00:01Z", **extra):
    return {
        "type": "user",
        "timestamp": timestamp,
        "message": {"content": [
            {"type": "tool_result", "tool_use_id": tool_id, "is_error": True, "content": text},
        ]},
        **extra,
    }


class ClassifyTest(unittest.TestCase):
    def test_a_hook_block_is_a_guard_named_by_its_script(self):
        text = "PreToolUse:Bash hook error: [${CLAUDE_PROJECT_DIR}/hooks/commit-ratchet-guard.sh]: blocked"
        self.assertEqual(report.classify(text, None), ("guard", "commit-ratchet-guard.sh"))

    def test_a_denial_kind_is_a_rejection(self):
        self.assertEqual(report.classify("anything", "user-rejected"), ("rejected", None))

    def test_the_harness_rejection_text_is_a_rejection(self):
        text = "The user doesn't want to proceed with this tool use."
        self.assertEqual(report.classify(text, None), ("rejected", None))

    def test_an_exit_code_is_a_failure_carrying_the_code(self):
        self.assertEqual(report.classify("Exit code 1\nFAIL", None), ("exit", "1"))

    def test_an_exit_code_behind_an_error_prefix_still_counts(self):
        self.assertEqual(report.classify("Error: Exit code 2", None), ("exit", "2"))

    def test_a_guard_outranks_its_denial_kind(self):
        """A hook block carries a permission-rule denial kind as well. Counting it as a
        rejection would hide every guard inside the user-rejection figure."""
        text = "PreToolUse:Bash hook error: [hooks/shell-machinery-guard.sh]: no"
        self.assertEqual(report.classify(text, "permission-rule"), ("guard", "shell-machinery-guard.sh"))

    def test_anything_else_is_other_with_a_short_sample(self):
        kind, sample = report.classify("Command timed out after 120s and was killed", None)
        self.assertEqual(kind, "other")
        self.assertLessEqual(len(sample), 60)


class CommandHeadTest(unittest.TestCase):
    def test_strips_the_rtk_wrappers(self):
        self.assertEqual(report.command_head("rtk test bin/ci"), "bin/ci")
        self.assertEqual(report.command_head("rtk proxy curl -sL x"), "curl")

    def test_keeps_the_subcommand_for_multi_command_tools(self):
        self.assertEqual(report.command_head("rtk git grep -n foo"), "git grep")
        self.assertEqual(report.command_head("bin/rails test test/models"), "bin/rails test")

    def test_an_empty_command_is_a_question_mark(self):
        self.assertEqual(report.command_head("   "), "?")


class ScanTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def transcript(self, *records, name="session.jsonl"):
        path = Path(self.tmp.name) / name
        path.write_text("\n".join(r if isinstance(r, str) else json.dumps(r) for r in records) + "\n")
        return path

    def test_pairs_a_bash_error_with_its_command(self):
        path = self.transcript(bash_call("t1", "rtk grep foo src"), error_result("t1", "Exit code 1"))
        result = report.scan([path], WINDOW)
        self.assertEqual(result.classes["2026-W45"]["exit"], 1)
        self.assertEqual(result.exit_codes[("grep", "1")], 1)

    def test_counts_every_tool_call_toward_the_rate(self):
        path = self.transcript(bash_call("t1", "ls"), other_call("t2", "Read"), other_call("t3", "Edit"))
        self.assertEqual(report.scan([path], WINDOW).tool_calls["2026-W45"], 3)

    def test_an_error_from_another_tool_is_not_a_command_failure(self):
        path = self.transcript(other_call("t1", "Edit"), error_result("t1", "String not found"))
        self.assertEqual(sum(report.scan([path], WINDOW).classes["2026-W45"].values()), 0)

    def test_a_sidechain_record_is_skipped(self):
        """Sub-agent records would count a delegated agent's failures as this session's."""
        path = self.transcript(bash_call("t1", "ls", isSidechain=True),
                               error_result("t1", "Exit code 1", isSidechain=True))
        result = report.scan([path], WINDOW)
        self.assertEqual(result.tool_calls["2026-W45"], 0)
        self.assertEqual(sum(result.classes["2026-W45"].values()), 0)

    def test_a_record_before_the_window_is_skipped(self):
        path = self.transcript(bash_call("t1", "ls", timestamp="2026-10-01T00:00:00Z"),
                               error_result("t1", "Exit code 1", timestamp="2026-10-01T00:00:01Z"))
        self.assertEqual(report.scan([path], WINDOW).tool_calls, {})

    def test_a_malformed_line_is_skipped(self):
        path = self.transcript('{"type":"assistant","message":{"content":[',
                               bash_call("t1", "ls"), error_result("t1", "Exit code 2"))
        self.assertEqual(report.scan([path], WINDOW).classes["2026-W45"]["exit"], 1)

    def test_a_guard_block_is_tallied_by_hook_and_week(self):
        path = self.transcript(bash_call("t1", "cd /tmp && ls"),
                               error_result("t1", "PreToolUse:Bash hook error: [hooks/reflexive-cd-guard.sh]: no"))
        result = report.scan([path], WINDOW)
        self.assertEqual(result.hooks["2026-W45"]["reflexive-cd-guard.sh"], 1)
        self.assertEqual(result.classes["2026-W45"]["exit"], 0)


if __name__ == "__main__":
    unittest.main()
