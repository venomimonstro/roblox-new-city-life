#!/usr/bin/env python3
"""Fail-closed local release acceptance for Street City Online, no CI.

Runs source checks, a Rojo build and Roblox Studio two-client acceptance.
A PASS is valid only when Studio returns 16/16 suite results and all
nine real-player lifecycle checks. This is not a guarantee of production FPS.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PASSED = "STREET_CITY_AUTOMATED_ACCEPTANCE_PASS "
NEEDED = {
    "two_real_clients_connected", "both_profiles_homes_and_cars_ready",
    "private_plot_slots_unique", "private_vehicle_ownership_unique",
    "two_client_HUD_receipts", "actual_death_and_free_home_respawn",
    "medical_accounting_after_death", "owned_vehicle_replaced_after_death",
    "other_account_untouched",
}


def studio_executable(explicit: str | None) -> str | None:
    if explicit:
        return explicit if Path(explicit).is_file() else None
    env = os.environ.get("ROBLOX_STUDIO_PATH")
    if env and Path(env).is_file():
        return env
    if sys.platform == "darwin":
        p = "/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio"
        return p if Path(p).is_file() else None
    if os.name == "nt":
        root = Path(os.environ.get("LOCALAPPDATA", "")) / "Roblox" / "Versions"
        found = sorted(root.glob("*/RobloxStudioBeta.exe"), key=lambda p: p.stat().st_mtime, reverse=True)
        return str(found[0]) if found else None
    return None


def validated_receipt(log: str) -> dict:
    candidates = [line.split(PASSED, 1)[1].strip()
                  for line in log.splitlines() if PASSED in line]
    if not candidates:
        raise ValueError("No success marker from Roblox Studio test driver")
    report = json.loads(candidates[-1])
    if report.get("status") != "PASS" or report.get("players") != 2:
        raise ValueError("Two real Studio clients not confirmed")
    suites = report.get("suites", {})
    if (suites.get("status") != "PASS"
            or suites.get("totalSuites") != 16
            or suites.get("passedSuites") != 16
            or suites.get("failedSuites") != 0):
        raise ValueError("Missing 16/16 executed Luau tests")
    results = suites.get("results", [])
    if len(results) != 16 or any(v.get("status") != "PASS" for v in results):
        raise ValueError("Incomplete or failed Studio suite results")
    checks = report.get("checks", [])
    passed = {x.get("name") for x in checks if x.get("status") == "PASS"}
    missing = sorted(NEEDED - passed)
    if missing:
        raise ValueError("Missing real-player checks: " + ", ".join(missing))
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--studio", help="Path to installed Roblox Studio executable")
    parser.add_argument("--timeout", type=int, default=420)
    parser.add_argument("--receipt", default="street-city-acceptance.json")
    args = parser.parse_args()
    try:
        output_path = Path(args.receipt).resolve()
        rojo = shutil.which("rojo")
        studio = studio_executable(args.studio)
        if not rojo:
            raise RuntimeError("Rojo missing; Studio acceptance cannot be performed")
        if not studio:
            raise RuntimeError("Roblox Studio missing; pass --studio or ROBLOX_STUDIO_PATH")
        validator = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "validate_project.py")],
            cwd=ROOT, capture_output=True, text=True, timeout=90)
        if validator.returncode:
            raise RuntimeError("Source validation failed:\n" + validator.stdout + validator.stderr)
        with tempfile.TemporaryDirectory(prefix="streetcity_acceptance_") as d:
            place = Path(d) / "StreetCity.rbxlx"
            build = subprocess.run([rojo, "build", "default.project.json", "-o", str(place)],
                                   cwd=ROOT, capture_output=True, text=True, timeout=120)
            if build.returncode or not place.exists() or place.stat().st_size < 5000:
                raise RuntimeError("Rojo build failed:\n" + build.stdout + build.stderr)
            output = Path(d) / "studio.log"
            command = [
                studio, "--task", "RunScript", "--localPlaceFile", str(place),
                "--runScriptFile", str(ROOT / "tools/studio/launch_release_acceptance.luau"),
                "--outputFile", str(output), "--quitAfterExecution",
            ]
            try:
                process = subprocess.run(command, cwd=ROOT, capture_output=True,
                                         text=True, timeout=args.timeout, errors="replace")
            except subprocess.TimeoutExpired as exc:
                raise RuntimeError("Roblox Studio exceeded test timeout") from exc
            log = process.stdout + "\n" + process.stderr
            if output.exists():
                log += "\n" + output.read_text(encoding="utf-8", errors="replace")
            if process.returncode != 0:
                raise RuntimeError(f"Studio returned {process.returncode}: {log[-5000:]}")
            receipt = validated_receipt(log)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2),
                                   encoding="utf-8")
            print(f"PASS: all 16 Studio suites plus {len(NEEDED)} real multiplayer checks")
            print("Receipt:", output_path)
            print("Remaining: published DataStore, Android FPS and real-money receipts")
        return 0
    except (ValueError, OSError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print("RELEASE BLOCKED:", exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
