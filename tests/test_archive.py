import hashlib
import io
import os
import shutil
import subprocess
import tarfile
import tempfile
import unittest
import zipfile

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BOOTSTRAP_SH = os.path.join(REPO_ROOT, "bootstrap.sh")
UPDATE_SH = os.path.join(REPO_ROOT, "rathole-manager", "rathole-manager", "update.sh")

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
    # Convert windows path to posix path for bash
    if not p:
        return ""
    p = os.path.abspath(p).replace("\\", "/")
    if len(p) >= 2 and p[1] == ":":
        p = "/" + p[0].lower() + p[2:]
    return p

def run_bash_cmd(cmd_str, env=None):
    if not BASH_BIN:
        raise unittest.SkipTest("Bash not found on current environment")
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    return subprocess.run([BASH_BIN, "-c", cmd_str], capture_output=True, text=True, env=merged_env)


class RealArchiveValidationTests(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bootstrap_posix = to_posix_path(BOOTSTRAP_SH)
        self.update_posix = to_posix_path(UPDATE_SH)

    def tearDown(self):
        self.tmpdir.cleanup()

    def run_bootstrap_zip(self, archive_path, env=None):
        arch_posix = to_posix_path(archive_path)
        cmd = f'BOOTSTRAP_LIB_ONLY=1 source "{self.bootstrap_posix}" && validate_zip_archive "{arch_posix}"'
        return run_bash_cmd(cmd, env=env)

    def run_bootstrap_tar(self, archive_path, env=None):
        arch_posix = to_posix_path(archive_path)
        cmd = f'BOOTSTRAP_LIB_ONLY=1 source "{self.bootstrap_posix}" && validate_tar_archive "{arch_posix}"'
        return run_bash_cmd(cmd, env=env)

    def run_update_tar(self, archive_path, env=None):
        arch_posix = to_posix_path(archive_path)
        cmd = f'UPDATE_LIB_ONLY=1 source "{self.update_posix}" && validate_tar_archive "{arch_posix}"'
        return run_bash_cmd(cmd, env=env)

    def run_bootstrap_sha(self, file_path, expected_sha, env=None):
        file_posix = to_posix_path(file_path)
        cmd = f'BOOTSTRAP_LIB_ONLY=1 source "{self.bootstrap_posix}" && verify_sha256 "{file_posix}" "{expected_sha}"'
        return run_bash_cmd(cmd, env=env)

    # ------------------ ZIP TESTS (REAL BOOTSTRAP.SH) ------------------

    def test_real_valid_zip(self):
        zip_path = os.path.join(self.tmpdir.name, "valid.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("test/safe.txt", b"hello world")
            zf.writestr("test/nested/file.sh", b"echo safe")
        res = self.run_bootstrap_zip(zip_path)
        self.assertEqual(res.returncode, 0, f"Valid zip failed in real validator: {res.stderr}")

    def test_real_zip_path_traversal(self):
        zip_path = os.path.join(self.tmpdir.name, "traversal.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("../escape.txt", b"malicious content")
        res = self.run_bootstrap_zip(zip_path)
        self.assertNotEqual(res.returncode, 0, "Real validator must reject zip with ../ traversal")

    def test_real_zip_nested_traversal(self):
        zip_path = os.path.join(self.tmpdir.name, "nested_traversal.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("safe_dir/../../escape.txt", b"malicious content")
        res = self.run_bootstrap_zip(zip_path)
        self.assertNotEqual(res.returncode, 0, "Real validator must reject zip with nested traversal")

    def test_real_zip_backslash_traversal(self):
        zip_path = os.path.join(self.tmpdir.name, "win_traversal.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("..\\escape.txt", b"malicious content")
        res = self.run_bootstrap_zip(zip_path)
        self.assertNotEqual(res.returncode, 0, "Real validator must reject zip with backslash traversal")

    def test_real_zip_absolute_path(self):
        zip_path = os.path.join(self.tmpdir.name, "absolute.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("/etc/passwd", b"root:x:0:0:root")
        res = self.run_bootstrap_zip(zip_path)
        self.assertNotEqual(res.returncode, 0, "Real validator must reject zip with absolute path")

    def test_real_zip_drive_letter_absolute_path(self):
        zip_path = os.path.join(self.tmpdir.name, "drive_absolute.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("C:/windows/system.ini", b"evil")
        res = self.run_bootstrap_zip(zip_path)
        self.assertNotEqual(res.returncode, 0, "Real validator must reject zip with drive letter absolute path")

    def test_real_zip_symlink(self):
        zip_path = os.path.join(self.tmpdir.name, "symlink.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            info = zipfile.ZipInfo("link_to_etc")
            info.create_system = 3  # Unix
            info.external_attr = 0o120777 << 16  # Symlink mode
            zf.writestr(info, b"/etc/shadow")
        res = self.run_bootstrap_zip(zip_path)
        self.assertNotEqual(res.returncode, 0, "Real validator must reject zip containing symlink")

    def test_real_zip_empty_and_corrupt(self):
        empty_path = os.path.join(self.tmpdir.name, "empty.zip")
        with open(empty_path, "wb") as f:
            pass
        res = self.run_bootstrap_zip(empty_path)
        self.assertNotEqual(res.returncode, 0, "Real validator must reject 0-byte zip")

        corrupt_path = os.path.join(self.tmpdir.name, "corrupt.zip")
        with open(corrupt_path, "wb") as f:
            f.write(b"PK\x03\x04garbage data not real zip")
        res = self.run_bootstrap_zip(corrupt_path)
        self.assertNotEqual(res.returncode, 0, "Real validator must reject corrupt zip")

    def test_real_zip_missing_tools_fail_closed(self):
        zip_path = os.path.join(self.tmpdir.name, "valid_for_tool_check.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("test/safe.txt", b"hello world")
        # Empty PATH so python and unzip cannot be found
        res = self.run_bootstrap_zip(zip_path, env={"PATH": "/nonexistent"})
        self.assertNotEqual(res.returncode, 0, "Missing tools must fail closed, returning non-zero")

    # ------------------ TAR TESTS (BOOTSTRAP.SH & UPDATE.SH) ------------------

    def test_real_valid_tar(self):
        for script_name, runner in [("bootstrap.sh", self.run_bootstrap_tar), ("update.sh", self.run_update_tar)]:
            tar_path = os.path.join(self.tmpdir.name, f"valid_{script_name}.tar.gz")
            with tarfile.open(tar_path, "w:gz") as tf:
                data = b"hello tar content"
                ti = tarfile.TarInfo("safe_dir/file.txt")
                ti.size = len(data)
                tf.addfile(ti, io.BytesIO(data))
            res = runner(tar_path)
            self.assertEqual(res.returncode, 0, f"Valid tar failed in real {script_name} validator: {res.stderr}")

    def test_real_tar_path_traversal(self):
        for script_name, runner in [("bootstrap.sh", self.run_bootstrap_tar), ("update.sh", self.run_update_tar)]:
            tar_path = os.path.join(self.tmpdir.name, f"traversal_{script_name}.tar.gz")
            with tarfile.open(tar_path, "w:gz") as tf:
                data = b"bad tar"
                ti = tarfile.TarInfo("../escape.txt")
                ti.size = len(data)
                tf.addfile(ti, io.BytesIO(data))
            res = runner(tar_path)
            self.assertNotEqual(res.returncode, 0, f"{script_name} validator must reject tar with ../ traversal")

    def test_real_tar_absolute_path(self):
        for script_name, runner in [("bootstrap.sh", self.run_bootstrap_tar), ("update.sh", self.run_update_tar)]:
            tar_path = os.path.join(self.tmpdir.name, f"abs_{script_name}.tar.gz")
            with tarfile.open(tar_path, "w:gz") as tf:
                data = b"root:x:0:0"
                ti = tarfile.TarInfo("/etc/passwd")
                ti.size = len(data)
                tf.addfile(ti, io.BytesIO(data))
            res = runner(tar_path)
            self.assertNotEqual(res.returncode, 0, f"{script_name} validator must reject tar with absolute path")

    def test_real_tar_symlink_escape(self):
        for script_name, runner in [("bootstrap.sh", self.run_bootstrap_tar), ("update.sh", self.run_update_tar)]:
            tar_path = os.path.join(self.tmpdir.name, f"symlink_{script_name}.tar.gz")
            with tarfile.open(tar_path, "w:gz") as tf:
                ti = tarfile.TarInfo("escape_symlink")
                ti.type = tarfile.SYMTYPE
                ti.linkname = "../../etc/shadow"
                tf.addfile(ti)
            res = runner(tar_path)
            self.assertNotEqual(res.returncode, 0, f"{script_name} validator must reject tar with escaping symlink")

    def test_real_tar_symlink_absolute(self):
        for script_name, runner in [("bootstrap.sh", self.run_bootstrap_tar), ("update.sh", self.run_update_tar)]:
            tar_path = os.path.join(self.tmpdir.name, f"abs_sym_{script_name}.tar.gz")
            with tarfile.open(tar_path, "w:gz") as tf:
                ti = tarfile.TarInfo("abs_symlink")
                ti.type = tarfile.SYMTYPE
                ti.linkname = "/etc/shadow"
                tf.addfile(ti)
            res = runner(tar_path)
            self.assertNotEqual(res.returncode, 0, f"{script_name} validator must reject tar with absolute symlink")

    def test_real_tar_hardlink(self):
        for script_name, runner in [("bootstrap.sh", self.run_bootstrap_tar), ("update.sh", self.run_update_tar)]:
            tar_path = os.path.join(self.tmpdir.name, f"hardlink_{script_name}.tar.gz")
            with tarfile.open(tar_path, "w:gz") as tf:
                ti = tarfile.TarInfo("hardlink_entry")
                ti.type = tarfile.LNKTYPE
                ti.linkname = "/etc/passwd"
                tf.addfile(ti)
            res = runner(tar_path)
            self.assertNotEqual(res.returncode, 0, f"{script_name} validator must reject tar with hardlink")

    def test_real_tar_special_devices(self):
        for script_name, runner in [("bootstrap.sh", self.run_bootstrap_tar), ("update.sh", self.run_update_tar)]:
            # Character device
            tar_path = os.path.join(self.tmpdir.name, f"chr_{script_name}.tar.gz")
            with tarfile.open(tar_path, "w:gz") as tf:
                ti = tarfile.TarInfo("dev_null")
                ti.type = tarfile.CHRTYPE
                tf.addfile(ti)
            res = runner(tar_path)
            self.assertNotEqual(res.returncode, 0, f"{script_name} validator must reject char device")

            # FIFO device
            tar_path_fifo = os.path.join(self.tmpdir.name, f"fifo_{script_name}.tar.gz")
            with tarfile.open(tar_path_fifo, "w:gz") as tf:
                ti = tarfile.TarInfo("named_pipe")
                ti.type = tarfile.FIFOTYPE
                tf.addfile(ti)
            res = runner(tar_path_fifo)
            self.assertNotEqual(res.returncode, 0, f"{script_name} validator must reject fifo pipe")

    def test_real_tar_empty_and_corrupt(self):
        for script_name, runner in [("bootstrap.sh", self.run_bootstrap_tar), ("update.sh", self.run_update_tar)]:
            empty_path = os.path.join(self.tmpdir.name, f"empty_{script_name}.tar.gz")
            with open(empty_path, "wb") as f:
                pass
            res = runner(empty_path)
            self.assertNotEqual(res.returncode, 0, f"{script_name} validator must reject 0-byte tar")

            corrupt_path = os.path.join(self.tmpdir.name, f"corrupt_{script_name}.tar.gz")
            with open(corrupt_path, "wb") as f:
                f.write(b"\x1f\x8b\x08corrupted gzip stream header")
            res = runner(corrupt_path)
            self.assertNotEqual(res.returncode, 0, f"{script_name} validator must reject corrupt tar")

    def test_real_tar_missing_tools_fail_closed(self):
        for script_name, runner in [("bootstrap.sh", self.run_bootstrap_tar), ("update.sh", self.run_update_tar)]:
            tar_path = os.path.join(self.tmpdir.name, f"valid_{script_name}.tar.gz")
            with tarfile.open(tar_path, "w:gz") as tf:
                data = b"hello tar content"
                ti = tarfile.TarInfo("safe_dir/file.txt")
                ti.size = len(data)
                tf.addfile(ti, io.BytesIO(data))
            res = runner(tar_path, env={"PATH": "/nonexistent"})
            self.assertNotEqual(res.returncode, 0, f"{script_name} missing tools must fail closed")

    # ------------------ CHECKSUM TESTS (REAL BOOTSTRAP.SH) ------------------

    def test_real_checksum_verification_success(self):
        test_file = os.path.join(self.tmpdir.name, "check_ok.bin")
        content = b"testing sha256 checksum integrity verification in bootstrap.sh"
        with open(test_file, "wb") as f:
            f.write(content)
        expected_hash = hashlib.sha256(content).hexdigest()
        res = self.run_bootstrap_sha(test_file, expected_hash)
        self.assertEqual(res.returncode, 0, f"Expected matching checksum to pass: {res.stderr}")

    def test_real_checksum_verification_mismatch_fails_closed(self):
        test_file = os.path.join(self.tmpdir.name, "check_bad.bin")
        content = b"original file content"
        with open(test_file, "wb") as f:
            f.write(content)
        wrong_hash = hashlib.sha256(b"tampered content").hexdigest()
        res = self.run_bootstrap_sha(test_file, wrong_hash)
        self.assertNotEqual(res.returncode, 0, "Expected mismatched checksum to fail closed")

    def test_real_checksum_missing_file_fails_closed(self):
        missing_file = os.path.join(self.tmpdir.name, "missing.bin")
        res = self.run_bootstrap_sha(missing_file, "0" * 64)
        self.assertNotEqual(res.returncode, 0, "Missing file must fail closed")

    def test_real_checksum_missing_tools_fails_closed(self):
        test_file = os.path.join(self.tmpdir.name, "check_tool.bin")
        with open(test_file, "wb") as f:
            f.write(b"data")
        res = self.run_bootstrap_sha(test_file, "0" * 64, env={"PATH": "/nonexistent"})
        self.assertNotEqual(res.returncode, 0, "Missing sha256 tools must fail closed")


if __name__ == "__main__":
    unittest.main()
