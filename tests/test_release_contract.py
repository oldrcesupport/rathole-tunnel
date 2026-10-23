#!/usr/bin/env python3
"""
Unit tests for release contract, version alignment, and manifest validation.
"""
import hashlib
import os
import re
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

class ReleaseContractTests(unittest.TestCase):
    def test_manager_version_format(self):
        common_sh = os.path.join(REPO_ROOT, "rathole-manager", "rathole-manager", "common.sh")
        self.assertTrue(os.path.isfile(common_sh), "common.sh must exist")
        with open(common_sh, "r", encoding="utf-8") as f:
            content = f.read()
        m = re.search(r'MANAGER_VERSION=["\']?([0-9]+\.[0-9]+\.[0-9]+)["\']?', content)
        self.assertIsNotNone(m, "MANAGER_VERSION must be defined as semantic version in common.sh")
        version = m.group(1)
        self.assertTrue(re.match(r"^\d+\.\d+\.\d+$", version), f"Invalid version string: {version}")

    def test_sha256sums_integrity(self):
        sums_file = os.path.join(REPO_ROOT, "SHA256SUMS")
        self.assertTrue(os.path.isfile(sums_file), "SHA256SUMS must exist")
        with open(sums_file, "r", encoding="utf-8") as f:
            lines = [line.strip() for line in f if line.strip() and not line.startswith("#")]
        
        manifest = {}
        for line in lines:
            parts = line.split(maxsplit=1)
            self.assertEqual(len(parts), 2, f"Invalid SHA256SUMS entry: {line}")
            sha, filename = parts[0], parts[1].lstrip("*").strip()
            manifest[filename] = sha

        # Required files in manifest
        required_files = ["bootstrap.sh", "rathole-manager.zip", "install.sh"]
        for rf in required_files:
            self.assertIn(rf, manifest, f"{rf} must be listed in SHA256SUMS")
            target_path = os.path.join(REPO_ROOT, rf)
            self.assertTrue(os.path.isfile(target_path), f"File {rf} must physically exist in repo")
            
            with open(target_path, "rb") as f:
                actual_sha = hashlib.sha256(f.read()).hexdigest()
            self.assertEqual(
                actual_sha,
                manifest[rf],
                f"Checksum mismatch for {rf}: expected {manifest[rf]}, got {actual_sha}"
            )

    def test_release_workflow_contains_pinned_release_guards(self):
        workflow_file = os.path.join(REPO_ROOT, ".github", "workflows", "release.yml")
        self.assertTrue(os.path.isfile(workflow_file), "release.yml must exist")
        with open(workflow_file, "r", encoding="utf-8") as f:
            content = f.read()
        
        # Verify guard against overwriting existing release
        self.assertIn("gh release view", content, "release.yml must verify whether release already exists")
        self.assertIn("already exists on GitHub", content, "release.yml must fail closed on existing release")
        
        # Verify commit SHA checking against checked out HEAD
        self.assertIn("target_sha", content, "release.yml must determine and output target_sha")
        self.assertIn("target_commitish:", content, "release.yml must pin target_commitish")

    def test_install_script_contains_sha_flags(self):
        install_sh = os.path.join(REPO_ROOT, "install.sh")
        with open(install_sh, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("--sha256", content, "install.sh must support --sha256")
        self.assertIn("--sha256sums-file", content, "install.sh must support --sha256sums-file")
        self.assertIn("same-origin", content, "install.sh must include same-origin security note")

if __name__ == "__main__":
    unittest.main()
