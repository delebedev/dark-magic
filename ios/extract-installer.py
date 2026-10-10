#!/usr/bin/env python3
"""Extract game MPQs from full classic Blizzard installer tomes without running them."""
import argparse
import ctypes as c
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", type=Path, help="Diablo II Installer Tome.mpq")
    parser.add_argument("expansion", type=Path, help="LoD Installer Tome.mpq")
    parser.add_argument("output", type=Path, help="new directory outside Git")
    parser.add_argument("--library", default="/opt/homebrew/opt/stormlib/lib/libstorm.dylib")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error("output must be new; existing assets are never overwritten")
    parent = output.parent
    while not parent.exists():
        parent = parent.parent
    if subprocess.run(["git", "-C", str(parent), "rev-parse", "--is-inside-work-tree"],
                      capture_output=True).returncode == 0:
        parser.error("keep copyrighted assets outside Git")

    lib = c.CDLL(args.library)
    handle, dword = c.c_void_p, c.c_uint32
    lib.SFileOpenArchive.argtypes = [c.c_char_p, dword, dword, c.POINTER(handle)]
    lib.SFileOpenArchive.restype = c.c_bool
    lib.SFileOpenFileEx.argtypes = [handle, c.c_char_p, dword, c.POINTER(handle)]
    lib.SFileOpenFileEx.restype = c.c_bool
    lib.SFileGetFileSize.argtypes = [handle, c.POINTER(dword)]
    lib.SFileGetFileSize.restype = dword
    lib.SFileCloseFile.argtypes = [handle]
    lib.SFileCloseArchive.argtypes = [handle]
    lib.SFileExtractFile.argtypes = [handle, c.c_char_p, c.c_char_p, dword]
    lib.SFileExtractFile.restype = c.c_bool

    # The expansion patch takes precedence; the base patch is not installed.
    sources = [
        (args.base, ("d2char.mpq", "d2data.mpq", "d2music.mpq", "d2sfx.mpq", "d2speech.mpq", "d2video.mpq")),
        (args.expansion, ("d2exp.mpq", "d2xmusic.mpq", "d2xtalk.mpq", "d2xvideo.mpq", "patch_d2.mpq")),
    ]
    output.mkdir(parents=True)
    report = []
    for source, names in sources:
        archive = handle()
        if not lib.SFileOpenArchive(str(source).encode(), 0, 0x100, c.byref(archive)):
            raise RuntimeError(f"cannot open installer tome: {source}")
        try:
            for name in names:
                entry = f"Common\\{name}".encode()
                file = handle()
                if not lib.SFileOpenFileEx(archive, entry, 0, c.byref(file)):
                    raise RuntimeError(f"installer lacks {name}")
                try:
                    high = dword()
                    size = lib.SFileGetFileSize(file, c.byref(high))
                    if high.value or not 0 < size < (2 << 30):
                        raise RuntimeError(f"invalid MPQ size: {name}")
                finally:
                    lib.SFileCloseFile(file)
                target = output / name
                if not lib.SFileExtractFile(archive, entry, str(target).encode(), 0):
                    raise RuntimeError(f"cannot extract {name}")
                if target.stat().st_size != size:
                    raise RuntimeError(f"truncated extraction: {name}")
                nested = handle()
                if not lib.SFileOpenArchive(str(target).encode(), 0, 0x100, c.byref(nested)):
                    raise RuntimeError(f"extracted file is not a readable MPQ: {name}")
                lib.SFileCloseArchive(nested)
                with target.open("rb") as stream:
                    digest = hashlib.file_digest(stream, "sha256").hexdigest()
                report.append({"name": name, "size": size, "sha256": digest})
                print(f"Extracted and checked {name}: {size} bytes", flush=True)
        finally:
            lib.SFileCloseArchive(archive)
    (output / "extraction-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("MPQs retain the installer asset version. No patch executable was run.")


if __name__ == "__main__":
    main()
