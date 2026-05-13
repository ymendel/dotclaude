"""Tests for scripts/_common.py helpers."""

import unittest
from pathlib import Path

from _common import infer_project_root, run_cmd


class InferProjectRootTest(unittest.TestCase):
    def test_standard_layout_climbs_three_levels(self):
        handoff = Path("/projects/foo/.claude/handoffs/2026-01-01-x.md")
        self.assertEqual(infer_project_root(handoff), Path("/projects/foo"))

    def test_non_standard_layout_falls_back_to_parent(self):
        handoff = Path("/tmp/foo.md")
        self.assertEqual(infer_project_root(handoff), Path("/tmp"))

    def test_deep_layout_outside_dotclaude_uses_parent(self):
        handoff = Path("/a/b/c/d/handoff.md")
        self.assertEqual(infer_project_root(handoff), Path("/a/b/c/d"))


class RunCmdTest(unittest.TestCase):
    def test_successful_command_returns_zero_and_stdout(self):
        rc, stdout, stderr = run_cmd(["echo", "hello"])
        self.assertEqual(rc, 0)
        self.assertEqual(stdout, "hello")
        self.assertEqual(stderr, "")

    def test_missing_binary_returns_minus_one(self):
        rc, stdout, stderr = run_cmd(["__definitely_not_a_real_command__"])
        self.assertEqual(rc, -1)
        self.assertEqual(stdout, "")
        self.assertTrue(stderr)  # has an error description

    def test_non_zero_exit_preserves_stderr(self):
        rc, stdout, stderr = run_cmd(["sh", "-c", "echo oops >&2; exit 7"])
        self.assertEqual(rc, 7)
        self.assertEqual(stdout, "")
        self.assertEqual(stderr, "oops")


if __name__ == "__main__":
    unittest.main()
