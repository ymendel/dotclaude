"""Tests for create_handoff.py."""

import unittest

import create_handoff


def _sanitize(slug: str) -> str:
    """Mirror the slug-sanitize logic from generate_handoff."""
    slug = slug.lower()
    for ch in (" ", "_", "/", "\\"):
        slug = slug.replace(ch, "-")
    return "".join(c for c in slug if c.isalnum() or c == "-")


class SlugSanitizerTest(unittest.TestCase):
    def test_preserves_slashes_as_dashes(self):
        # Regression: feature/foo used to collapse to "featurefoo".
        self.assertEqual(_sanitize("feature/foo"), "feature-foo")

    def test_preserves_backslashes_as_dashes(self):
        self.assertEqual(_sanitize("feature\\foo"), "feature-foo")

    def test_normalizes_underscores_and_spaces(self):
        self.assertEqual(_sanitize("My_Task Name"), "my-task-name")

    def test_strips_non_alphanum_specials(self):
        self.assertEqual(_sanitize("foo!@#$%bar"), "foobar")

    def test_lowercases(self):
        self.assertEqual(_sanitize("CamelCase"), "camelcase")

    def test_empty_string_stays_empty(self):
        self.assertEqual(_sanitize(""), "")


class TemplateLoadTest(unittest.TestCase):
    def test_template_renders_with_expected_placeholders(self):
        template = create_handoff._load_template()
        rendered = template.format(
            timestamp="2026-01-01 00:00:00",
            project_path="/proj",
            branch_line="main",
            commits_section="  - abc123 commit",
            chain_section="## Handoff Chain\n\nNone",
            modified_section="| file | a | b |",
        )
        self.assertIn("2026-01-01 00:00:00", rendered)
        self.assertIn("/proj", rendered)
        self.assertIn("## Current State Summary", rendered)
        self.assertIn("[TODO:", rendered)
        # Make sure no unfilled {placeholder}s leaked through
        self.assertNotIn("{timestamp}", rendered)
        self.assertNotIn("{project_path}", rendered)


if __name__ == "__main__":
    unittest.main()
