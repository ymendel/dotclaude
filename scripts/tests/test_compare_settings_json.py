"""Tests for scripts/compare-settings-json.py.

Loaded as `compare_settings_json` by the package __init__; the file's own name
carries a hyphen and cannot be imported.

Covers the two functions that decide what the report says. `main()` is left
alone — it shells out to git and reads the repo's real settings.json, so a test
over it would assert print formatting while depending on the very file the
script exists to compare.

The case this script is for is the last one in CompareTest: an external tool
rewrites settings.json, producing a diff of tens of lines, and the question is
whether any of it is a real setting. A reordered permission array has to report
nothing, or the tool answers the wrong question.
"""

import unittest

import compare_settings_json as subject


class FlattenTest(unittest.TestCase):
    """`flatten` reduces a parsed document to leaf paths."""

    def test_nested_keys_become_a_dotted_path(self):
        self.assertEqual(
            subject.flatten({"statusLine": {"type": "command"}}),
            {"statusLine.type": ("VALUE", "command")})

    def test_a_list_of_scalars_becomes_one_set_leaf(self):
        """Permission arrays are order-insensitive, so the whole list is one leaf."""
        self.assertEqual(
            subject.flatten({"permissions": {"allow": ["Bash(wc:*)", "Bash(which:*)"]}}),
            {"permissions.allow": ("SET", frozenset(["Bash(wc:*)", "Bash(which:*)"]))})

    def test_a_list_holding_dicts_is_indexed_instead(self):
        """Position carries meaning there — hook matchers are the live case."""
        document = {"hooks": {"PreToolUse": [{"matcher": "Bash"}, {"matcher": "Edit"}]}}
        self.assertEqual(
            subject.flatten(document),
            {"hooks.PreToolUse[0].matcher": ("VALUE", "Bash"),
             "hooks.PreToolUse[1].matcher": ("VALUE", "Edit")})

    def test_a_scalar_at_the_root_keeps_its_own_key(self):
        self.assertEqual(subject.flatten({"effortLevel": "high"}),
                         {"effortLevel": ("VALUE", "high")})

    def test_an_empty_list_is_an_empty_set_leaf(self):
        """Pinned because `all()` is true of an empty list, so it takes the SET branch."""
        self.assertEqual(subject.flatten({"permissions": {"deny": []}}),
                         {"permissions.deny": ("SET", frozenset())})

    def test_an_empty_dict_produces_no_leaf_at_all(self):
        """A real limit rather than an intention: an object emptied of its keys is
        invisible to the comparison, because a leaf is only ever a scalar or a
        scalar list. Emptying `permissions` of every key would report nothing."""
        self.assertEqual(subject.flatten({"permissions": {}}), {})


class CompareTest(unittest.TestCase):
    """`compare` reports what moved between two parsed documents."""

    def test_identical_documents_report_nothing(self):
        document = {"effortLevel": "high", "permissions": {"allow": ["Bash(wc:*)"]}}
        self.assertEqual(subject.compare(document, dict(document)), ([], [], []))

    def test_a_key_only_in_the_working_copy_is_added(self):
        added, dropped, changed = subject.compare({}, {"tui": "fullscreen"})
        self.assertEqual(added, ["tui"])
        self.assertEqual(dropped, [])
        self.assertEqual(changed, [])

    def test_a_key_only_in_head_is_dropped(self):
        added, dropped, changed = subject.compare({"tui": "fullscreen"}, {})
        self.assertEqual(added, [])
        self.assertEqual(dropped, ["tui"])
        self.assertEqual(changed, [])

    def test_a_changed_scalar_reports_both_values(self):
        _, _, changed = subject.compare({"effortLevel": "high"},
                                        {"effortLevel": "medium"})
        self.assertEqual(changed, [("effortLevel", "VALUE", "high", "medium")])

    def test_an_array_gaining_a_member_reports_only_that_member(self):
        head = {"permissions": {"allow": ["Bash(wc:*)"]}}
        work = {"permissions": {"allow": ["Bash(wc:*)", "Bash(which:*)"]}}
        _, _, changed = subject.compare(head, work)
        self.assertEqual(changed,
                         [("permissions.allow", "SET", [], ["Bash(which:*)"])])

    def test_an_array_losing_a_member_reports_only_that_member(self):
        head = {"permissions": {"allow": ["Bash(wc:*)", "Bash(which:*)"]}}
        work = {"permissions": {"allow": ["Bash(wc:*)"]}}
        _, _, changed = subject.compare(head, work)
        self.assertEqual(changed,
                         [("permissions.allow", "SET", ["Bash(which:*)"], [])])

    def test_a_reordered_document_reports_nothing(self):
        """The whole point. An external rewrite reorders keys and reorders the
        permission arrays, and none of that is a change to a setting."""
        head = {
            "effortLevel": "high",
            "permissions": {"allow": ["Bash(wc:*)", "Bash(which:*)"]},
            "tui": "fullscreen",
        }
        work = {
            "tui": "fullscreen",
            "permissions": {"allow": ["Bash(which:*)", "Bash(wc:*)"]},
            "effortLevel": "high",
        }
        self.assertEqual(subject.compare(head, work), ([], [], []))

    def test_one_real_addition_survives_a_wholesale_reorder(self):
        """The shape that motivated the script: a rewrite that moves everything
        and also enables a plugin. Only the plugin should be reported."""
        head = {
            "effortLevel": "high",
            "permissions": {"allow": ["Bash(wc:*)", "Bash(which:*)"]},
        }
        work = {
            "permissions": {"allow": ["Bash(which:*)", "Bash(wc:*)"]},
            "enabledPlugins": {"diagrams@example-marketplace": True},
            "effortLevel": "high",
        }
        added, dropped, changed = subject.compare(head, work)
        self.assertEqual(added, ["enabledPlugins.diagrams@example-marketplace"])
        self.assertEqual(dropped, [])
        self.assertEqual(changed, [])


if __name__ == "__main__":
    unittest.main()
