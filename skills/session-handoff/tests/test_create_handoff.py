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


class GetPreviousHandoffInfoTest(unittest.TestCase):
    HANDOFFS = [
        {"filename": "2026-05-21-120000-recent.md", "title": "Recent thing"},
        {"filename": "2026-05-20-100000-older.md", "title": "Older thing"},
    ]

    def test_continues_from_resolves_target(self):
        info = create_handoff.get_previous_handoff_info(
            self.HANDOFFS, continues_from="2026-05-20-100000-older.md"
        )
        self.assertTrue(info["exists"])
        self.assertEqual(info["relationship"], "continues")
        self.assertEqual(info["filename"], "2026-05-20-100000-older.md")

    def test_branches_from_resolves_target(self):
        info = create_handoff.get_previous_handoff_info(
            self.HANDOFFS, branches_from="2026-05-20-100000-older.md"
        )
        self.assertTrue(info["exists"])
        self.assertEqual(info["relationship"], "branches")

    def test_no_flag_suggests_most_recent(self):
        info = create_handoff.get_previous_handoff_info(self.HANDOFFS)
        self.assertTrue(info["exists"])
        self.assertIsNone(info["relationship"])
        self.assertTrue(info["suggested"])
        self.assertEqual(info["filename"], "2026-05-21-120000-recent.md")

    def test_empty_handoffs_returns_not_exists(self):
        info = create_handoff.get_previous_handoff_info([])
        self.assertFalse(info["exists"])


class RenderChainSectionTest(unittest.TestCase):
    def test_continues_from_renders_continues_label(self):
        section = create_handoff.render_chain_section(
            {"exists": True, "relationship": "continues",
             "filename": "prior.md", "title": "Prior work"}
        )
        self.assertIn("**Continues from**", section)
        self.assertIn("prior.md", section)
        self.assertNotIn("Branches from", section)

    def test_branches_from_renders_branches_label_and_note(self):
        section = create_handoff.render_chain_section(
            {"exists": True, "relationship": "branches",
             "filename": "prior.md", "title": "Prior work"}
        )
        self.assertIn("**Branches from**", section)
        self.assertIn("not resumed", section)
        self.assertNotIn("**Continues from**", section)

    def test_auto_suggested_includes_override_hint(self):
        section = create_handoff.render_chain_section(
            {"exists": True, "relationship": None, "suggested": True,
             "filename": "prior.md", "title": "Prior"}
        )
        self.assertIn("**Continues from**", section)
        self.assertIn("--branches-from", section)
        self.assertIn("--no-chain", section)

    def test_no_chain_renders_independent_work(self):
        section = create_handoff.render_chain_section(
            {"exists": True, "relationship": "continues",
             "filename": "prior.md", "title": "Prior"},
            no_chain=True,
        )
        self.assertIn("independent work", section)
        self.assertNotIn("prior.md", section)

    def test_no_prior_renders_fresh_start(self):
        section = create_handoff.render_chain_section({"exists": False, "relationship": None})
        self.assertIn("fresh start", section)


if __name__ == "__main__":
    unittest.main()
