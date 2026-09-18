"""Tests for scripts/rules-sections.py.

Loaded as `rules_sections` by the package __init__; the file's own name carries a
hyphen and cannot be imported.

Covers the two functions that decide what the report says. `main()` is left alone
— it prints and reads the repo's real `rules/` directory, so a test over it would
assert formatting while depending on the very files the script exists to measure.
"""

import tempfile
import unittest
from pathlib import Path

import rules_sections


def write(directory, name, text):
    path = Path(directory) / name
    path.write_text(text)
    return path


class AlwaysLoadedTest(unittest.TestCase):
    """`always_loaded` decides which rule files a general session would load."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_an_ordinary_rule_file_counts(self):
        path = write(self.tmp.name, "honesty.md", "# Honesty\n\nSome guidance.\n")
        self.assertTrue(rules_sections.always_loaded(path))

    def test_readme_never_counts(self):
        path = write(self.tmp.name, "README.md", "# Index\n\nA list.\n")
        self.assertFalse(rules_sections.always_loaded(path))

    def test_paths_frontmatter_excludes_the_file(self):
        path = write(self.tmp.name, "settings.md",
                     "---\npaths:\n  - settings.json\n---\n\n# Settings\n")
        self.assertFalse(rules_sections.always_loaded(path))

    def test_paths_must_start_a_line(self):
        """A mention mid-line is prose, not frontmatter, and must not exclude the file."""
        path = write(self.tmp.name, "searching.md",
                     "# Searching\n\nScope paths: to the known location.\n")
        self.assertTrue(rules_sections.always_loaded(path))

    def test_only_the_first_ten_lines_are_examined(self):
        """The check reads a head, so `paths:` below it does not exclude the file.

        Pinned because it is a real limit of the implementation rather than an
        intention — a file that grew a `paths:` key on line 11 would silently start
        being counted.
        """
        body = "\n".join(f"line {n}" for n in range(1, 12))
        path = write(self.tmp.name, "late.md", f"# Late\n\n{body}\npaths:\n")
        self.assertTrue(rules_sections.always_loaded(path))


class SectionsTest(unittest.TestCase):
    """`sections` yields (heading, bytes) per `## ` block, preamble first."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def test_preamble_then_each_section_in_order(self):
        path = write(self.tmp.name, "rule.md",
                     "intro\n## First\nbody one\n## Second\nbody two\n")
        self.assertEqual([heading for heading, _ in rules_sections.sections(path)],
                         ["(preamble)", "First", "Second"])

    def test_a_section_size_includes_its_own_heading_line(self):
        path = write(self.tmp.name, "rule.md", "## Only\nbody\n")
        sizes = dict(rules_sections.sections(path))
        self.assertEqual(sizes["Only"], len("## Only\nbody\n".encode()))

    def test_a_file_opening_with_a_heading_has_an_empty_preamble(self):
        path = write(self.tmp.name, "rule.md", "## Only\nbody\n")
        sizes = dict(rules_sections.sections(path))
        self.assertEqual(sizes["(preamble)"], 0)

    def test_a_file_with_no_headings_is_all_preamble(self):
        text = "just prose, no headings at all\n"
        path = write(self.tmp.name, "rule.md", text)
        self.assertEqual(list(rules_sections.sections(path)),
                         [("(preamble)", len(text.encode()))])

    def test_deeper_headings_stay_inside_their_section(self):
        """Only `## ` splits. A `###` belongs to the section above it."""
        path = write(self.tmp.name, "rule.md", "## Top\n### Nested\nbody\n")
        self.assertEqual([heading for heading, _ in rules_sections.sections(path)],
                         ["(preamble)", "Top"])

    def test_size_is_bytes_not_characters(self):
        """Rule prose carries em-dashes and curly quotes, so the two differ in practice."""
        path = write(self.tmp.name, "rule.md", "## Wide\nem — dash\n")
        sizes = dict(rules_sections.sections(path))
        self.assertEqual(sizes["Wide"], len("## Wide\nem — dash\n".encode("utf-8")))
        self.assertGreater(sizes["Wide"], len("## Wide\nem — dash\n"))


if __name__ == "__main__":
    unittest.main()
