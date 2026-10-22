import hashlib
import io
import os
import tarfile
import tempfile
import unittest
import zipfile

# Helper validator logic mirroring bootstrap.sh and update.sh
def is_safe_relpath(p):
    if not p:
        return False
    if p.startswith("/") or (len(p) > 1 and p[1] == ":"):
        return False
    norm = p.replace("\\", "/")
    parts = norm.split("/")
    if ".." in parts:
        return False
    return True

def validate_zip(archive_path):
    if not os.path.isfile(archive_path) or os.path.getsize(archive_path) == 0:
        return False, "Empty or non-existent file"
    try:
        with zipfile.ZipFile(archive_path, "r") as zf:
            infolist = zf.infolist()
            if not infolist:
                return False, "Empty archive"
            for info in infolist:
                if not is_safe_relpath(info.filename):
                    return False, f"Unsafe path: {info.filename}"
                mode = info.external_attr >> 16
                if (mode & 0o170000) == 0o120000:
                    return False, f"Symlink entry: {info.filename}"
    except Exception as e:
        return False, f"Archive parse error: {e}"
    return True, "OK"

def validate_tar(archive_path):
    if not os.path.isfile(archive_path) or os.path.getsize(archive_path) == 0:
        return False, "Empty or non-existent file"
    try:
        with tarfile.open(archive_path, "r:*") as tf:
            members = tf.getmembers()
            if not members:
                return False, "Empty archive"
            for m in members:
                if not is_safe_relpath(m.name):
                    return False, f"Unsafe path: {m.name}"
                if m.isdev() or m.ischr() or m.isblk() or m.isfifo():
                    return False, f"Special device: {m.name}"
                if m.issym() or m.islnk():
                    target = m.linkname
                    if target.startswith("/") or (len(target) > 1 and target[1] == ":"):
                        return False, f"Unsafe link target: {target}"
                    if ".." in target.replace("\\", "/").split("/"):
                        return False, f"Unsafe traversal link: {target}"
    except Exception as e:
        return False, f"Archive parse error: {e}"
    return True, "OK"


class ArchiveValidationTests(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_valid_zip(self):
        zip_path = os.path.join(self.tmpdir.name, "valid.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("test/safe.txt", b"hello world")
            zf.writestr("test/nested/file.sh", b"echo safe")
        valid, msg = validate_zip(zip_path)
        self.assertTrue(valid, f"Expected valid zip: {msg}")

    def test_zip_path_traversal(self):
        zip_path = os.path.join(self.tmpdir.name, "traversal.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("../escape.txt", b"malicious content")
        valid, msg = validate_zip(zip_path)
        self.assertFalse(valid, "Should reject zip with path traversal")

    def test_zip_backslash_traversal(self):
        zip_path = os.path.join(self.tmpdir.name, "win_traversal.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("..\\escape.txt", b"malicious content")
        valid, msg = validate_zip(zip_path)
        self.assertFalse(valid, "Should reject zip with backslash traversal")

    def test_zip_absolute_path(self):
        zip_path = os.path.join(self.tmpdir.name, "absolute.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            zf.writestr("/etc/passwd", b"root:x:0:0:root")
        valid, msg = validate_zip(zip_path)
        self.assertFalse(valid, "Should reject zip with absolute path")

    def test_zip_symlink(self):
        zip_path = os.path.join(self.tmpdir.name, "symlink.zip")
        with zipfile.ZipFile(zip_path, "w") as zf:
            info = zipfile.ZipInfo("link_to_etc")
            info.create_system = 3  # Unix
            info.external_attr = 0o120777 << 16  # Symlink mode
            zf.writestr(info, b"/etc/shadow")
        valid, msg = validate_zip(zip_path)
        self.assertFalse(valid, "Should reject zip containing symlink")

    def test_empty_or_corrupt_zip(self):
        empty_path = os.path.join(self.tmpdir.name, "empty.zip")
        with open(empty_path, "wb") as f:
            pass
        valid, _ = validate_zip(empty_path)
        self.assertFalse(valid, "Should reject 0-byte zip file")

        corrupt_path = os.path.join(self.tmpdir.name, "corrupt.zip")
        with open(corrupt_path, "wb") as f:
            f.write(b"PK\x03\x04corrupted garbled data")
        valid, _ = validate_zip(corrupt_path)
        self.assertFalse(valid, "Should reject corrupted zip file")

    def test_valid_tar(self):
        tar_path = os.path.join(self.tmpdir.name, "valid.tar.gz")
        with tarfile.open(tar_path, "w:gz") as tf:
            data = b"hello tar"
            ti = tarfile.TarInfo("safe_dir/file.txt")
            ti.size = len(data)
            tf.addfile(ti, io.BytesIO(data))
        valid, msg = validate_tar(tar_path)
        self.assertTrue(valid, f"Expected valid tar: {msg}")

    def test_tar_path_traversal(self):
        tar_path = os.path.join(self.tmpdir.name, "traversal.tar.gz")
        with tarfile.open(tar_path, "w:gz") as tf:
            data = b"bad tar"
            ti = tarfile.TarInfo("../escape.txt")
            ti.size = len(data)
            tf.addfile(ti, io.BytesIO(data))
        valid, msg = validate_tar(tar_path)
        self.assertFalse(valid, "Should reject tar with traversal")

    def test_tar_symlink_escape(self):
        tar_path = os.path.join(self.tmpdir.name, "symlink_tar.tar.gz")
        with tarfile.open(tar_path, "w:gz") as tf:
            ti = tarfile.TarInfo("escape_symlink")
            ti.type = tarfile.SYMTYPE
            ti.linkname = "../../etc/shadow"
            tf.addfile(ti)
        valid, msg = validate_tar(tar_path)
        self.assertFalse(valid, "Should reject tar with escaping symlink")

    def test_tar_device_node(self):
        tar_path = os.path.join(self.tmpdir.name, "dev_tar.tar.gz")
        with tarfile.open(tar_path, "w:gz") as tf:
            ti = tarfile.TarInfo("dev_null")
            ti.type = tarfile.CHRTYPE
            tf.addfile(ti)
        valid, msg = validate_tar(tar_path)
        self.assertFalse(valid, "Should reject tar with special device node")

    def test_checksum_verification(self):
        test_file = os.path.join(self.tmpdir.name, "check.bin")
        content = b"testing sha256 checksum integrity"
        with open(test_file, "wb") as f:
            f.write(content)
        expected_hash = hashlib.sha256(content).hexdigest()
        wrong_hash = hashlib.sha256(b"wrong content").hexdigest()

        # Compute hash
        h = hashlib.sha256()
        with open(test_file, "rb") as f:
            while chunk := f.read(4096):
                h.update(chunk)
        self.assertEqual(h.hexdigest(), expected_hash)
        self.assertNotEqual(h.hexdigest(), wrong_hash)


if __name__ == "__main__":
    unittest.main()
