"""Regression tests for common.sh rth_redact (audit: noise_privkey + kcp key leak in `logs`).

rtholectl/ratholenode `logs`/`logs --bundle` output is explicitly advertised as safe to
paste into chat/issues; the redactor must cover every live secret key, including
state.json's `noise_privkey`, the kcptun `key` field, and env forms.
"""
import os
import shutil
import subprocess
import tempfile
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
COMMON_SH = os.path.join(REPO_ROOT, "rathole-manager", "rathole-manager", "common.sh")


def get_bash_executable():
    candidates = [
        shutil.which("bash"),
        r"C:\Program Files\Git\bin\bash.exe",
        r"C:\Program Files\Git\usr\bin\bash.exe",
        "/bin/bash",
        "/usr/bin/bash",
    ]
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    return None


BASH_BIN = get_bash_executable()


def to_posix_path(p):
    if not p:
        return ""
    p = os.path.abspath(p).replace("\\", "/")
    if len(p) >= 2 and p[1] == ":":
        p = "/" + p[0].lower() + p[2:]
    return p


def run_redact(text):
    if not BASH_BIN:
        raise unittest.SkipTest("Bash not found on current environment")
    common_posix = to_posix_path(COMMON_SH)
    cmd = f'source "{common_posix}" && printf \'%s\\n\' "$(cat)" | rth_redact'
    return subprocess.run([BASH_BIN, "-c", cmd], input=text,
                          capture_output=True, text=True, timeout=60)


class TestShellRedaction(unittest.TestCase):
    def test_noise_privkey_json_redacted(self):
        # audit: state.json noise keypair — `noise_privkey` matched NONE of the old rules
        out = run_redact('{"noise_privkey":"SECRETNOISEPRIVKEY123","noise_pubkey":"pub"}')
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertNotIn("SECRETNOISEPRIVKEY123", out.stdout)
        self.assertIn("***REDACTED***", out.stdout)

    def test_kcp_key_json_redacted(self):
        # audit: ratholectl kcp on stores .kcp.key — `"key"` was not in the pattern
        out = run_redact('{"kcp":{"enabled":true,"port":29900,"key":"KCPSHAREDSECRET"}}')
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertNotIn("KCPSHAREDSECRET", out.stdout)
        self.assertIn("***REDACTED***", out.stdout)

    def test_privkey_variant_json_redacted(self):
        out = run_redact('{"privkey":"PRIVATEPART"}')
        self.assertNotIn("PRIVATEPART", out.stdout)

    def test_legacy_keys_still_redacted(self):
        for blob, secret in [
            ('{"token":"TOK123"}', "TOK123"),
            ('{"backhaul_token":"BHTOK99"}', "BHTOK99"),
            ('{"noise_private_key":"LEGACYNAME"}', "LEGACYNAME"),
            ('{"password":"PWS3cret"}', "PWS3cret"),
        ]:
            out = run_redact(blob)
            self.assertNotIn(secret, out.stdout, f"{secret} leaked: {out.stdout}")

    def test_env_and_toml_line_forms_redacted(self):
        out = run_redact("TOKEN=envtok123\nNOISE_PRIVKEY=noiseenvtok\nprivkey = \"tomlpriv\"")
        self.assertNotIn("envtok123", out.stdout)
        self.assertNotIn("noiseenvtok", out.stdout)
        self.assertNotIn("tomlpriv", out.stdout)

    def test_non_secret_content_preserved(self):
        blob = ('{"domain":"example.com","control_port":2333,'
                '"nodes":[{"name":"trk01","port":2087}]}')
        out = run_redact(blob)
        self.assertIn("example.com", out.stdout)
        self.assertIn("trk01", out.stdout)
        self.assertIn("2333", out.stdout)
        self.assertIn("2087", out.stdout)

    def test_control_path_hint_redacted(self):
        out = run_redact("location = /_rh/abcdef1234567890 {")
        self.assertNotIn("abcdef1234567890", out.stdout)
        self.assertIn("/_rh/***REDACTED***", out.stdout)


if __name__ == "__main__":
    unittest.main()
