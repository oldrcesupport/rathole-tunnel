import os
import zipfile

def package_bundle():
    zip_path = "rathole-manager.zip"
    temp_zip = "rathole-manager.zip.tmp"
    source_dir = "rathole-manager"

    print(f"Building {zip_path} from {source_dir}...")
    with zipfile.ZipFile(temp_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(source_dir):
            dirs[:] = [d for d in dirs if d != "__pycache__" and not d.startswith(".harness")]
            for file in sorted(files):
                if file.endswith(".pyc") or file.endswith(".tmp"):
                    continue
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, ".")
                arcname = rel_path.replace("\\", "/")
                zf.write(full_path, arcname)

    os.replace(temp_zip, zip_path)
    size_mb = os.path.getsize(zip_path) / (1024 * 1024)
    print(f"Success! {zip_path} created ({size_mb:.2f} MB).")

if __name__ == "__main__":
    package_bundle()
