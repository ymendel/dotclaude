"""Tests for list_handoffs.py helpers."""

import unittest

from list_handoffs import (
    check_completion_status,
    extract_title,
    parse_date_from_filename,
)


class ExtractTitleTest(unittest.TestCase):
    def test_extracts_handoff_colon_title(self):
        self.assertEqual(extract_title("# Handoff: My Task\n\n"), "My Task")

    def test_extracts_plain_h1(self):
        self.assertEqual(extract_title("# Just A Title\n\n"), "Just A Title")

    def test_placeholder_title_returns_untitled_marker(self):
        self.assertEqual(
            extract_title("# [TASK_TITLE - replace this]\n"),
            "[Untitled - needs completion]",
        )

    def test_truncates_long_title(self):
        long = "A" * 100
        result = extract_title(f"# {long}\n")
        self.assertTrue(result.endswith("..."))
        self.assertLessEqual(len(result), 53)

    def test_no_h1_returns_unreadable_marker(self):
        self.assertEqual(extract_title("no heading here"), "[Unable to read title]")


class CheckCompletionStatusTest(unittest.TestCase):
    def test_no_todos_is_complete(self):
        self.assertEqual(check_completion_status("all done"), "Complete")

    def test_few_todos_is_in_progress(self):
        content = "[TODO: a] [TODO: b]"
        self.assertEqual(check_completion_status(content), "In Progress (2 TODOs)")

    def test_many_todos_is_needs_work(self):
        content = "[TODO: x]" * 10
        self.assertEqual(check_completion_status(content), "Needs Work (10 TODOs)")


class ParseDateFromFilenameTest(unittest.TestCase):
    def test_parses_well_formed_filename(self):
        result = parse_date_from_filename("2026-05-13-143022-slug.md")
        self.assertIsNotNone(result)
        self.assertEqual(result.year, 2026)
        self.assertEqual(result.hour, 14)
        self.assertEqual(result.minute, 30)

    def test_returns_none_for_malformed(self):
        self.assertIsNone(parse_date_from_filename("not-a-date.md"))
        self.assertIsNone(parse_date_from_filename("2026-13-99-XXXXXX-foo.md"))

    def test_returns_none_for_partial_match(self):
        self.assertIsNone(parse_date_from_filename("2026-05-13-foo.md"))


if __name__ == "__main__":
    unittest.main()
