"""Tests for validate_handoff.py — focused on secret-pattern coverage."""

import unittest

from validate_handoff import scan_for_secrets


class BearerTokenRegexTest(unittest.TestCase):
    """The Bearer pattern is the highest-noise one. Length floor = 20."""

    def test_prose_mention_of_bearer_does_not_match(self):
        self.assertEqual(scan_for_secrets("use the Bearer token here"), [])

    def test_short_bearer_does_not_match(self):
        self.assertEqual(scan_for_secrets("Bearer abc123"), [])

    def test_real_length_bearer_matches(self):
        jwt_ish = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload"
        findings = scan_for_secrets(jwt_ish)
        self.assertTrue(any("Bearer token" == name for name, _ in findings))


class SlackTokenRegexTest(unittest.TestCase):
    def test_short_tag_does_not_match(self):
        self.assertEqual(scan_for_secrets("see xoxb-1"), [])

    def test_realistic_slack_token_matches(self):
        token = "xoxb-1234567890-abcdefghij"
        findings = scan_for_secrets(token)
        self.assertTrue(any("Slack token" == name for name, _ in findings))


class StrictKeyPatternsTest(unittest.TestCase):
    def test_openai_key_with_48_chars_matches(self):
        key = "sk-" + "A" * 48
        findings = scan_for_secrets(key)
        self.assertTrue(any("OpenAI API key" == name for name, _ in findings))

    def test_short_openai_prefix_does_not_match(self):
        self.assertEqual(scan_for_secrets("sk-short"), [])

    def test_github_pat_matches(self):
        pat = "ghp_" + "x" * 36
        findings = scan_for_secrets(pat)
        self.assertTrue(any("GitHub personal access token" == name for name, _ in findings))


class KeyValuePatternsTest(unittest.TestCase):
    def test_api_key_assignment_matches(self):
        findings = scan_for_secrets('api_key="abcdef1234567890"')
        self.assertTrue(findings)

    def test_password_assignment_matches(self):
        findings = scan_for_secrets('PASSWORD="hunter2-xyz"')
        self.assertTrue(findings)

    def test_password_prose_does_not_match(self):
        # "password is X" lacks the colon/equals separator the regex requires.
        self.assertEqual(scan_for_secrets("the password is hunter2"), [])


class ConnectionStringPatternsTest(unittest.TestCase):
    def test_mongodb_uri_with_password_matches(self):
        findings = scan_for_secrets("mongodb://user:secretpass@host/db")
        self.assertTrue(any("MongoDB" in name for name, _ in findings))

    def test_postgres_uri_with_password_matches(self):
        findings = scan_for_secrets("postgres://user:secretpass@host/db")
        self.assertTrue(any("PostgreSQL" in name for name, _ in findings))


if __name__ == "__main__":
    unittest.main()
