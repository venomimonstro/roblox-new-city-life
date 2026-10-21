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
    "src/shared/ProfileMutationOutcome.luau",
    "src/shared/ParkingLayout.luau",
    "src/shared/GarageTransactions.luau",
    "src/shared/RaceValidation.luau",
    "src/shared/RaceCourse.luau",
    "src/server/dev/ScenarioTests.luau",
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

    bootstrap = (ROOT / "src/server/bootstrap.server.luau").read_text(encoding="utf-8")
    shop_position = bootstrap.find("GarageMarketplaceService.Start()")
    race_position = bootstrap.find("RaceService.Start()")
    if shop_position == -1 or race_position == -1 or shop_position > race_position:
        raise SystemExit("Invalid bootstrap order: shop must initialize before races")

    profile_source = (ROOT / "src/server/services/ProfileService.luau").read_text(encoding="utf-8")
    if "MutationOutcome.Classify(" not in profile_source or "activeStore()" not in profile_source:
        raise SystemExit("Profile safety regression: missing cancellation or lazy-store guard")
    if "confirmedData = Schema.Decode(output.data)" not in profile_source:
        raise SystemExit("Profile safety regression: lease retry must capture committed data")
    if "quarantined[player.UserId] = true" not in profile_source:
        raise SystemExit("Profile safety regression: failed renewals must quarantine accounts")
    if "quarantined[id] = true" not in profile_source:
        raise SystemExit("Profile safety regression: uncertain writes must quarantine accounts")

    race = (ROOT / "src/server/services/RaceService.luau").read_text(encoding="utf-8")
    if "settling[id] = true" not in race or "or settling[player.UserId]" not in race:
        raise SystemExit("Race safety regression: block races during credit settlement")

    vehicle = (ROOT / "src/server/services/VehicleService.luau").read_text(encoding="utf-8")
    if "physicsAccumulator < 1 / 30" not in vehicle:
        raise SystemExit("Vehicle performance regression: missing 30Hz server simulation cap")

    world_source = (ROOT / "src/server/services/WorldService.luau").read_text(encoding="utf-8")
    race_source = (ROOT / "src/server/services/RaceService.luau").read_text(encoding="utf-8")
    if "p.CanQuery = p.CanCollide" not in world_source or "marker.CanQuery = false" not in race_source:
        raise SystemExit("Suspension safety regression: noncollidable decoration is queryable")

    scenario = (ROOT / "src/server/dev/ScenarioTests.luau").read_text(encoding="utf-8")
    if 'WaitForChild("ScenarioTests")).Run()' not in bootstrap:
        raise SystemExit("Scenario simulation is not connected to Studio bootstrap")
    for rule in ("Rules.AwardCredits", "Rules.PurchaseVehicle", "Rules.PurchasePart",
                 "Rules.InstallPart", "Outcome.Classify", "Parking.Position"):
        if rule not in scenario:
            raise SystemExit("Scenario simulation missing coverage: " + rule)

    course = (ROOT / "src/shared/RaceCourse.luau").read_text(encoding="utf-8")
    race = (ROOT / "src/server/services/RaceService.luau").read_text(encoding="utf-8")
    if 'WaitForChild("RaceCourse")' not in race or "CheckpointRadius = 16" not in course:
        raise SystemExit("Race must use shared validated checkpoint geometry")

    workflows = ROOT / ".github" / "workflows"
    if workflows.exists() and any(workflows.iterdir()):
        raise SystemExit("GitHub Actions workflows are explicitly disabled")
    print(f"PASS: {len(REQUIRED)} required files, valid Rojo paths, no CI")


if __name__ == "__main__":
    main()
