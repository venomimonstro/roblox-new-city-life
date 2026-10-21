#!/usr/bin/env python3
"""Local structural checks. Deliberately no network access or CI dependency."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = (
    "README.md",
    "default.project.json",
    "src/server/bootstrap.server.luau",
    "src/server/services/WorldService.luau",
    "src/server/services/VehicleService.luau",
    "src/server/services/VehicleFactory.luau",
    "src/server/dev/SmokeTests.luau",
    "src/client/bootstrap.client.luau",
    "src/shared/Config.luau",
    "src/shared/VehicleMath.luau",
    "src/shared/VehicleCatalog.luau",
    "src/shared/ShopCatalog.luau",
    "src/shared/ProfileSchema.luau",
    "src/shared/GarageTransactions.luau",
    "src/shared/RaceValidation.luau",
    "src/server/services/PersonalGarage.luau",
    "src/server/services/GarageMarketplaceService.luau",
    "src/server/services/RaceService.luau",
    "src/server/services/ProfileService.luau",
    "docs/architecture.md",
    "docs/roadmap.md",
    "docs/quality.md",
)


def main() -> None:
    missing = [path for path in REQUIRED if not (ROOT / path).is_file()]
    if missing:
        raise SystemExit("MISSING: " + ", ".join(missing))

    data = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
    tree = data["tree"]
    mappings = (
        ("ReplicatedStorage", "Shared", "src/shared"),
        ("ServerScriptService", "Server", "src/server"),
    )
    for service, name, target in mappings:
        assert tree[service][name]["$path"] == target, (service, name)
    assert (
        tree["StarterPlayer"]["StarterPlayerScripts"]["Client"]["$path"]
        == "src/client"
    )
    assert tree["$className"] == "DataModel"
    assert tree["Workspace"]["$properties"]["StreamingEnabled"] is True

    workflows = ROOT / ".github" / "workflows"
    if workflows.exists() and any(workflows.iterdir()):
        raise SystemExit("GitHub Actions workflows are explicitly disabled")
    print(f"PASS: {len(REQUIRED)} required files, valid Rojo paths, no CI")


if __name__ == "__main__":
    main()
