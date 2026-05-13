"""Tests for evals/setup_test_env.py safety helpers."""

import unittest
from pathlib import Path

from setup_test_env import _is_safe_rmtree_path


class IsSafeRmtreePathTest(unittest.TestCase):
    """Regression guard for the /var/log false-accept caught in review."""

    def test_tmp_subdir_is_safe(self):
        self.assertTrue(_is_safe_rmtree_path(Path("/tmp/foo")))

    def test_private_tmp_is_safe_for_macos(self):
        self.assertTrue(_is_safe_rmtree_path(Path("/private/tmp/foo")))

    def test_var_folders_is_safe_for_macos_tmpdir(self):
        self.assertTrue(_is_safe_rmtree_path(Path("/var/folders/x/y/T/pytest")))

    def test_private_var_folders_is_safe(self):
        self.assertTrue(_is_safe_rmtree_path(Path("/private/var/folders/x/y/T/pytest")))

    def test_path_with_test_in_name_is_safe(self):
        self.assertTrue(_is_safe_rmtree_path(Path("/Users/x/some-test-dir")))

    def test_var_log_is_not_safe(self):
        # The reason this whole helper got tightened.
        self.assertFalse(_is_safe_rmtree_path(Path("/var/log")))

    def test_var_run_is_not_safe(self):
        self.assertFalse(_is_safe_rmtree_path(Path("/var/run")))

    def test_var_root_is_not_safe(self):
        self.assertFalse(_is_safe_rmtree_path(Path("/var")))

    def test_home_dir_is_not_safe(self):
        self.assertFalse(_is_safe_rmtree_path(Path("/Users/yossef")))
        self.assertFalse(_is_safe_rmtree_path(Path("/home/user")))


if __name__ == "__main__":
    unittest.main()
