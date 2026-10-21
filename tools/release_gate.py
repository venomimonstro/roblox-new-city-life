#!/usr/bin/env python3
"""One-command local source/build release gate. Never triggers GitHub Actions.

Exit 0 means only structural validation + Rojo build passed, NOT live Studio QA.
Exit 2 means the build tool is unavailable; this is a BLOCKED release, not PASS.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run(args: list[str]) -> None:
    print("+", " ".join(args), flush=True)
    p = subprocess.run(args, cwd=ROOT, check=False, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"Command failed (exit {p.returncode}): {args[0]}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--static-only", action="store_true",
                        help="Check only file/project structure; not sufficient for release")
    args = parser.parse_args()

    try:
        run([sys.executable, "tools/validate_project.py"])
    except (RuntimeError, OSError) as exc:
        print(f"BLOCKED: {exc}", file=sys.stderr)
        return 1

    if args.static_only:
        print("STATIC PASS; BUILD NOT CHECKED; PRODUCTION RELEASE BLOCKED")
        return 0

    rojo = shutil.which("rojo")
    if rojo is None:
        print("BLOCKED: Rojo not installed; actual Roblox place cannot be built here.",
              file=sys.stderr)
        return 2

    try:
        with tempfile.TemporaryDirectory(prefix="streetcity_gate_") as tmp:
            output = Path(tmp) / "StreetCity.rbxlx"
            run([rojo, "build", "default.project.json", "-o", str(output)])
            if not output.is_file() or output.stat().st_size < 5000:
                raise RuntimeError("Rojo produced missing or implausibly small place file")
            print(f"ROJO BUILD PASS: {output.stat().st_size} bytes")
    except (RuntimeError, OSError) as exc:
        print(f"BLOCKED: {exc}", file=sys.stderr)
        return 1

    print("SOURCE + BUILD PASS; STUDIO GAMEPLAY, DATASTORE AND DEVICE QA STILL REQUIRED.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
