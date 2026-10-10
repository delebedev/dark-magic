#!/usr/bin/env python3
"""Extract original Mac shareware UI assets. StormLib is a host tool only."""
import argparse
import ctypes as c
import json
from pathlib import Path
import re
import subprocess


def asset_path(name):
    name = name.replace("\\", "/").lower()
    if not name.startswith("data/") or any(part in ("", ".", "..") for part in name.split("/")):
        raise ValueError(f"unsafe asset path: {name}")
    return name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="directory containing the demo MPQ symlinks")
    parser.add_argument("output", type=Path, help="new output directory outside Git, or ignored ios/Assets")
    parser.add_argument("--library", default="/opt/homebrew/opt/stormlib/lib/libstorm.dylib")
    args = parser.parse_args()
    if args.output.exists():
        parser.error("output must be a new directory; existing assets are never overwritten")
    root = Path(__file__).resolve().parent.parent
    output = args.output.resolve()
    parent = output.parent
    while not parent.exists():
        parent = parent.parent
    in_git = subprocess.run(["git", "-C", str(parent), "rev-parse", "--is-inside-work-tree"],
                            capture_output=True, text=True).returncode == 0
    if in_git and output != root / "ios/Assets":
        parser.error("assets must be outside Git, or in ignored ios/Assets")
    legacy = root / "internal/content/d2legacy"
    presentation = json.loads((legacy / "manifests/presentation.v1.json").read_text())
    paths = {"data/global/ui/frontend/trademark.dc6"}
    pattern = re.compile(r'["\'](data/[^"\']+\.(?:dc6|dcc|tbl|dat|pl2|txt|ds1|dt1|cof|wav))["\']', re.I)
    for source in [*legacy.rglob("*.json"), *legacy.rglob("*.lua")]:
        paths.update(asset_path(name) for name in pattern.findall(source.read_text()))

    lib = c.CDLL(args.library)
    handle, dword = c.c_void_p, c.c_uint32
    lib.SFileOpenArchive.argtypes = [c.c_char_p, dword, dword, c.POINTER(handle)]
    lib.SFileOpenArchive.restype = c.c_bool
    lib.SFileOpenFileEx.argtypes = [handle, c.c_char_p, dword, c.POINTER(handle)]
    lib.SFileOpenFileEx.restype = c.c_bool
    lib.SFileGetFileSize.argtypes = [handle, c.POINTER(dword)]
    lib.SFileGetFileSize.restype = dword
    lib.SFileReadFile.argtypes = [handle, c.c_void_p, dword, c.POINTER(dword), c.c_void_p]
    lib.SFileReadFile.restype = c.c_bool
    lib.SFileCloseFile.argtypes = [handle]
    lib.SFileCloseArchive.argtypes = [handle]
    archives = []
    extracted, missing = [], []
    try:
        for name in ("patch_d2.mpq", "d2data.mpq", "d2char.mpq"):
            archive = handle()
            if not lib.SFileOpenArchive(str(args.source / name).encode(), 0, 0x100, c.byref(archive)):
                raise RuntimeError(f"cannot open {name}")
            archives.append(archive)
        args.output.mkdir(parents=True)
        for name in sorted(paths):
            for archive in archives:
                file = handle()
                if not lib.SFileOpenFileEx(archive, name.replace("/", "\\").encode(), 0, c.byref(file)):
                    continue
                try:
                    size = lib.SFileGetFileSize(file, None)
                    if size > 64 << 20:
                        raise RuntimeError(f"invalid or excessive asset size: {name}")
                    buffer, read = c.create_string_buffer(size), dword()
                    if not lib.SFileReadFile(file, buffer, size, c.byref(read), None) or read.value != size:
                        raise RuntimeError(f"cannot read {name}")
                    target = args.output / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(buffer.raw)
                    extracted.append(name)
                finally:
                    lib.SFileCloseFile(file)
                break
            else:
                missing.append(name)
    finally:
        for archive in archives:
            lib.SFileCloseArchive(archive)

    # ui_lab never draws the title, but startup validates its manifest path.
    title = "data/global/ui/frontend/trademark.dc6"
    if title not in extracted:
        raise RuntimeError("the original demo title is missing")
    presentation["screens"]["title"]["background"] = title
    profile = args.output / "demo-profile"
    (profile / "manifests").mkdir(parents=True)
    (profile / "manifests/presentation.v1.json").write_text(json.dumps(presentation, indent=2) + "\n")
    (profile / "mod.json").write_text(json.dumps({
        "schema": "dark-magic.mod/v1", "id": "d2demo_profile", "name": "Mac shareware UI experiment",
        "version": "0.1.0", "kind": "extension", "engine_api": "v1", "redistributable": True,
        "content_roots": ["manifests"],
        "entrypoints": {"client_components": [], "authority_components": []},
        "dependencies": [{"id": "d2legacy", "version": "0.1.0"}],
    }, indent=2) + "\n")
    (args.output / "extraction-report.json").write_text(json.dumps({"extracted": extracted, "missing": missing}, indent=2) + "\n")
    print(f"Extracted {len(extracted)} original assets. {len(missing)} referenced assets absent from demo.")
    print("The generated profile changes only the unused title path. ui_lab and gameplay code are unchanged.")


if __name__ == "__main__":
    main()
