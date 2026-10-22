import hashlib
import os
import zipfile

REQUIRED_FILES = [
    "rathole-manager/rathole-manager/common.sh",
    "rathole-manager/rathole-manager/ratholectl",
    "rathole-manager/rathole-manager/ratholenode",
    "rathole-manager/rathole-manager/install-panel.sh",
    "rathole-manager/rathole-manager/install-node.sh",
    "rathole-manager/rathole-manager/update.sh",
    "rathole-manager/rathole-manager/ratholehub/hub.py",
    "rathole-manager/rathole-manager/ratholehub/hubcmds.py",
]

SENSITIVE_EXTENSIONS = (
    ".pyc", ".tmp", ".bak", ".backup", ".swp", ".log",
    ".key", ".pem", ".crt", ".env", ".toml"
)

SENSITIVE_BASENAMES = {
    "state.json", "watchdog.env", "services.conf", "adaptive.env"
}

def calculate_sha256(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def package_bundle():
    zip_path = "rathole-manager.zip"
    temp_zip = "rathole-manager.zip.tmp"
    source_dir = "rathole-manager"

    print(f"Building {zip_path} from {source_dir}...")
    packed_files = set()
    with zipfile.ZipFile(temp_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(source_dir):
            # Exclude hidden directories, pycache, and harness artifacts
            dirs[:] = [d for d in sorted(dirs) if not d.startswith(".") and d != "__pycache__" and not os.path.islink(os.path.join(root, d))]
            for file in sorted(files):
                if file.startswith("."):
                    continue
                if file in SENSITIVE_BASENAMES:
                    continue
                if any(file.endswith(ext) for ext in SENSITIVE_EXTENSIONS):
                    continue
                full_path = os.path.join(root, file)
                # Reject symbolic links
                if os.path.islink(full_path):
                    print(f"Skipping symlink: {full_path}")
                    continue
                rel_path = os.path.relpath(full_path, ".")
                arcname = rel_path.replace("\\", "/")
                zf.write(full_path, arcname)
                packed_files.add(arcname)

    # Verify that all required files are present
    for req in REQUIRED_FILES:
        if req not in packed_files:
            if os.path.exists(temp_zip):
                os.remove(temp_zip)
            raise RuntimeError(f"Package bundle missing required file: {req}")

    os.replace(temp_zip, zip_path)
    size_mb = os.path.getsize(zip_path) / (1024 * 1024)
    sha256_sum = calculate_sha256(zip_path)
    print(f"Success! {zip_path} created ({size_mb:.2f} MB, {len(packed_files)} files).")
    print(f"SHA256: {sha256_sum}")
    return sha256_sum

if __name__ == "__main__":
    package_bundle()

