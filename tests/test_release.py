import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location(
    "release", Path(__file__).resolve().parents[1] / "tools" / "release.py"
)
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "repo"
        self.root.mkdir()
        (self.root / "ItemFYI.toc").write_text("## Version: 0.2.40\n", encoding="utf-8")
        (self.root / "CHANGELOG.md").write_text("# Changelog\n\n## 0.2.40\n", encoding="utf-8")

    def init_repo(self):
        release.git(self.root, "init", "-b", "main")
        release.git(self.root, "config", "user.name", "Release Test")
        release.git(self.root, "config", "user.email", "test@example.invalid")
        release.git(self.root, "add", ".")
        release.git(self.root, "commit", "-m", "Fixture")
        remote = Path(self.temp.name) / "remote.git"
        subprocess.check_call(["git", "init", "--bare", str(remote)], stdout=subprocess.DEVNULL)
        release.git(self.root, "remote", "add", "origin", str(remote))
        release.git(self.root, "push", "-u", "origin", "main")

    def test_matching_metadata(self):
        self.assertEqual(release.validate(self.root, "v0.2.40"), "v0.2.40")

    def test_mismatched_tag(self):
        with self.assertRaises(ValueError):
            release.validate(self.root, "v0.2.39")

    def test_ci_tag_environment_is_checked(self):
        script = Path(__file__).resolve().parents[1] / "tools" / "release.py"
        result = subprocess.run(
            [sys.executable, str(script)], capture_output=True, text=True,
            env={**os.environ, "GITHUB_REF_TYPE": "tag", "GITHUB_REF_NAME": "v999.0.0"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match TOC version", result.stderr)

    def test_mismatched_changelog(self):
        (self.root / "CHANGELOG.md").write_text("## 0.2.39\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            release.validate(self.root)

    def test_placeholder_version(self):
        (self.root / "ItemFYI.toc").write_text("## Version: @project-version@\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            release.validate(self.root)

    def test_tag_is_derived_from_committed_version(self):
        self.init_repo()
        self.assertEqual(release.create_tag(self.root), "v0.2.40")
        self.assertEqual(release.git(self.root, "rev-parse", "v0.2.40^{}"),
                         release.git(self.root, "rev-parse", "HEAD"))
        with self.assertRaises(subprocess.CalledProcessError):
            release.create_tag(self.root)  # Existing tags must never be moved.

    def test_dirty_checkout_cannot_tag(self):
        self.init_repo()
        (self.root / "ItemFYI.toc").write_text("## Version: 0.2.41\n", encoding="utf-8")
        (self.root / "CHANGELOG.md").write_text("## 0.2.41\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Commit or stash"):
            release.create_tag(self.root)
        self.assertEqual(release.git(self.root, "tag"), "")

    def test_feature_branch_cannot_tag(self):
        self.init_repo()
        release.git(self.root, "checkout", "-b", "feature")
        with self.assertRaisesRegex(ValueError, "main after merge"):
            release.create_tag(self.root)

    def test_unpushed_main_cannot_tag(self):
        self.init_repo()
        release.git(self.root, "commit", "--allow-empty", "-m", "Unpushed")
        with self.assertRaisesRegex(ValueError, "match origin/main"):
            release.create_tag(self.root)


if __name__ == "__main__":
    unittest.main()
