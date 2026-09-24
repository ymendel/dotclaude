"""Tests for scripts/session-meta-report.py.

Loaded as `session_meta_report` by the package __init__; the file's own name
carries a hyphen and cannot be imported.

Covers `load`, `tool_calls` and `iso_week` — the three functions that read or
derive rather than print. The reporting functions are left alone: they emit
formatted text to stdout and asserting on their layout would pin column widths
rather than behavior.
"""

import datetime
import json
import tempfile
import unittest
from pathlib import Path

import session_meta_report


def write_session(directory, name, **fields):
    path = Path(directory) / name
    path.write_text(json.dumps(fields))
    return path


class LoadTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_reads_every_json_file_in_name_order(self):
        write_session(self.tmp.name, "b.json", session_id="second")
        write_session(self.tmp.name, "a.json", session_id="first")
        loaded = session_meta_report.load(Path(self.tmp.name))
        self.assertEqual([s["session_id"] for s in loaded], ["first", "second"])

    def test_ignores_files_that_are_not_json(self):
        write_session(self.tmp.name, "a.json", session_id="kept")
        (Path(self.tmp.name) / "report.html").write_text("<html></html>")
        loaded = session_meta_report.load(Path(self.tmp.name))
        self.assertEqual([s["session_id"] for s in loaded], ["kept"])

    def test_an_empty_directory_exits_rather_than_returning_nothing(self):
        """An empty list would flow into main() and divide by zero several sections
        later, naming the wrong culprit. The script exits at the source instead."""
        with self.assertRaises(SystemExit) as caught:
            session_meta_report.load(Path(self.tmp.name))
        self.assertIn(self.tmp.name, str(caught.exception))


class ToolCallsTest(unittest.TestCase):
    def test_sums_every_tool_count(self):
        session = {"tool_counts": {"Bash": 10, "Edit": 4, "Read": 1}}
        self.assertEqual(session_meta_report.tool_calls(session), 15)

    def test_a_session_with_no_tool_counts_is_zero(self):
        """Several rate calculations divide by this, so the absent case has to be a
        number rather than a KeyError."""
        self.assertEqual(session_meta_report.tool_calls({}), 0)

    def test_an_empty_tool_counts_map_is_zero(self):
        self.assertEqual(session_meta_report.tool_calls({"tool_counts": {}}), 0)


class IsoWeekTest(unittest.TestCase):
    """The bucketing key for every trend section.

    Asserted against `date.isocalendar()` rather than against hand-computed week
    numbers: the logic under test is the formatting, and hard-coding a calendar
    fact would pin my arithmetic rather than the script's behavior.
    """

    def test_formats_as_isoyear_and_week(self):
        for day in ("2026-01-01", "2026-06-15", "2026-12-31"):
            year, week, _ = datetime.date.fromisoformat(day).isocalendar()
            self.assertEqual(session_meta_report.iso_week({"start_time": day}),
                             f"{year}-W{week:02d}")

    def test_the_week_is_always_two_digits(self):
        """Unpadded, "2026-W9" sorts after "2026-W10", and every trend section
        prints in sorted order."""
        for day in ("2026-01-05", "2026-03-02", "2026-11-09"):
            self.assertRegex(session_meta_report.iso_week({"start_time": day}),
                             r"^\d{4}-W\d{2}$")

    def test_only_the_date_prefix_of_start_time_is_read(self):
        """Real files carry a full timestamp; the slice is what makes that work."""
        self.assertEqual(
            session_meta_report.iso_week({"start_time": "2026-06-15T23:59:59.123Z"}),
            session_meta_report.iso_week({"start_time": "2026-06-15"}))

    def test_the_iso_year_can_differ_from_the_calendar_year(self):
        """Late December can fall in the next ISO year, which is why the year comes
        from isocalendar() rather than from the string's first four characters."""
        day = "2025-12-29"
        iso_year, _, _ = datetime.date.fromisoformat(day).isocalendar()
        self.assertEqual(session_meta_report.iso_week({"start_time": day}),
                         f"{iso_year}-W{datetime.date.fromisoformat(day).isocalendar()[1]:02d}")
        self.assertNotEqual(str(iso_year), day[:4])


class RetentionEdgeTest(unittest.TestCase):
    def test_the_edge_is_a_date_the_string_comparison_in_main_can_use(self):
        """main() filters with `s["start_time"][:10] >= RETENTION_EDGE`, which is a
        string comparison. It only orders correctly while the constant stays
        zero-padded ISO."""
        self.assertRegex(session_meta_report.RETENTION_EDGE, r"^\d{4}-\d{2}-\d{2}$")
        datetime.date.fromisoformat(session_meta_report.RETENTION_EDGE)


if __name__ == "__main__":
    unittest.main()
