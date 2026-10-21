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
    "src/server/services/TerritoryService.luau",
    "src/server/dev/SocialSystemsTests.luau",
    "src/shared/ProfileMutationOutcome.luau",
    "src/shared/ParkingLayout.luau",
    "src/shared/GarageTransactions.luau",
    "src/shared/RaceValidation.luau",
    "src/shared/RaceCourse.luau",
    "src/shared/DistrictDynamics.luau",
    "src/shared/PropertyCatalog.luau",
    "src/shared/PropertyTransactions.luau",
    "src/shared/HomeLayout.luau",
    "src/server/services/DistrictSocietyService.luau",
    "src/server/services/PropertyService.luau",
    "src/server/services/PropertyMarketService.luau",
    "src/server/services/CrewService.luau",
    "src/server/services/BankNetworkService.luau",
    "src/server/services/NatureService.luau",
    "src/server/services/HousingService.luau",
    "src/server/services/WeatherService.luau",
    "src/server/services/TrafficService.luau",
    "src/server/services/LifestyleService.luau",
    "src/server/services/CityJobsService.luau",
    "src/server/services/CitizenService.luau",
    "src/server/services/WantedService.luau",
    "src/server/services/CrimeEconomyService.luau",
    "src/server/services/ArmoryService.luau",
    "src/server/dev/CityLifeTests.luau",
    "src/server/dev/DistrictEconomyTests.luau",
    "src/server/dev/SocialSystemsTests.luau",
    "src/server/services/TerritoryService.luau",
    "src/server/dev/ScenarioTests.luau",
    "src/server/dev/SimulationTests.luau",
    "src/server/services/PersonalGarage.luau",
    "src/server/services/GarageMarketplaceService.luau",
    "src/server/services/RaceService.luau",
    "src/server/services/ProfileService.luau",
    "src/server/services/StartupContract.luau",
    "tools/release_gate.py",
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

    if 'WaitForChild("SimulationTests")).Run()' not in bootstrap:
        raise SystemExit("Missing Studio fake-DataStore simulation startup")

    dev_garage = (ROOT / "src/server/services/GarageService.luau").read_text(encoding="utf-8")
    if "ProfileService.Mutate" in dev_garage:
        raise SystemExit("Unpublished shared test car cannot modify saved player garage")

    factory = (ROOT / "src/server/services/VehicleFactory.luau").read_text(encoding="utf-8")
    if "heading or 0" not in factory or "math.pi / 2" not in vehicle:
        raise SystemExit("Personal vehicles must face along parking road")

    garage = (ROOT / "src/server/services/PersonalGarage.luau").read_text(encoding="utf-8")
    shop = (ROOT / "src/server/services/GarageMarketplaceService.luau").read_text(encoding="utf-8")
    hud = (ROOT / "src/client/bootstrap.client.luau").read_text(encoding="utf-8")
    smoke = (ROOT / "src/server/dev/SmokeTests.luau").read_text(encoding="utf-8")
    if ('FindMyCarTerminal' not in garage or 'ground.Normal.Y < 0.72' not in garage
            or 'car.Model:GetAttribute("OwnerUserId") ~= id' not in garage):
        raise SystemExit("User journey regression: safe owned-car locator missing")
    if ('"Install " .. offerId' not in shop
            or "Rules.InstallPart(profile, profile.selectedVehicleId, offerId, operation)" not in shop):
        raise SystemExit("User journey regression: install must target player's chosen SKU")
    if ('if RunService:IsStudio() and game.GameId == 0 then' not in shop
            or 'DEV sandbox +25000 credits' not in shop):
        raise SystemExit("Studio regression: isolated non-production credit grant missing")
    if 'NextActionHint' not in hud or 'Shop_Install ' not in smoke:
        raise SystemExit("User journey regression: HUD guidance or install smoke checks missing")

    production_gate = (ROOT / "src/server/services/StartupContract.luau").read_text(encoding="utf-8")
    if 'StartupContract.Validate()' not in bootstrap:
        raise SystemExit("P0: critical runtime gameplay services not validated at startup")
    for name in ("FindMyCarTerminal", "PersonalGarageTerminal", "TimeTrialStart",
                 "VehicleInput", "StreetCityProfileState", "ActiveVehicles"):
        if name not in production_gate:
            raise SystemExit("P0: startup contract missing " + name)

    race_source = (ROOT / "src/server/services/RaceService.luau").read_text(encoding="utf-8")
    if "tryStart(player)" not in race_source or "startArmed[id] = false" not in race_source:
        raise SystemExit("P0: automatic race start or rearm guard missing")

    factory_source = (ROOT / "src/server/services/VehicleFactory.luau").read_text(encoding="utf-8")
    if 'model:SetAttribute("OwnerUserId", ownerUserId)' not in factory_source:
        raise SystemExit("P0: vehicle owner not assigned before public parenting")
    if 'Factory.Create(folder, position, heading or math.pi / 2, player.UserId)' not in vehicle:
        raise SystemExit("P0: personal vehicle creation lacks ownership")

    if "local function activeStore()" not in profile_source or "for attempt = 1, 8 do" not in profile_source:
        raise SystemExit("P1: rejoin must allow bounded lease acquisition retry")

    district = (ROOT / "src/server/services/DistrictService.luau").read_text(encoding="utf-8")
    smoke = (ROOT / "src/server/dev/SmokeTests.luau").read_text(encoding="utf-8")
    if "Building_" not in district or "math.round(part.Position.X / 100)" not in smoke:
        raise SystemExit("P0: city traffic lanes must be checked for building overlap")
    if "+ ((n - 1) % 4 - 1.5) * 100 + 25" in district:
        raise SystemExit("P0: old city building offsets obstruct the road grid")

    legacy_world = (ROOT / "src/server/services/WorldService.luau").read_text(encoding="utf-8")
    if "for x = -2, 1 do" in legacy_world:
        raise SystemExit("P0: duplicate downtown building generator reintroduced")

    profile_schema = (ROOT / "src/shared/ProfileSchema.luau").read_text(encoding="utf-8")
    if "raw.schemaVersion == 4 then" in profile_schema.split("function Schema.New")[1].split("function Schema.Decode")[0]:
        raise SystemExit("P0: constructor references nonexistent raw saved data")
    for field in ("communityBankCredits", "ownedProperties", "realEstate",
                  "allegiance", "guards", "henchmen"):
        if field not in profile_schema:
            raise SystemExit("P0: profile V4 missing persistent field " + field)
    for module in ("DistrictSocietyService", "CrewService", "PropertyService",
                   "BankNetworkService", "NatureService"):
        if module + ".Start()" not in bootstrap:
            raise SystemExit("P0: gameplay service not initialized: " + module)
    if 'WaitForChild("DistrictEconomyTests")).Run()' not in bootstrap:
        raise SystemExit("New economy migrations and land-price tests not wired")
    properties = (ROOT / "src/shared/PropertyTransactions.luau").read_text(encoding="utf-8")
    if 'profile.credits -= quotedPrice' not in properties:
        raise SystemExit("P0: property purchases cannot pay more than 2000 credits")

    # New contested-territory invariants and replay-safe wallet validation.
    territory = (ROOT / "src/server/services/TerritoryService.luau").read_text(encoding="utf-8")
    if "TerritoryService.Start()" not in bootstrap or "TerritoryControl" not in territory:
        raise SystemExit("P0: district influence control absent from published server")
    if "SocialSystemsTests" not in bootstrap:
        raise SystemExit("P0: Studio civic economy assertions are disconnected")
    wallet_source = (ROOT / "src/shared/GarageTransactions.luau").read_text(encoding="utf-8")
    if wallet_source.count("function Rules.SpendCredits(") != 1:
        raise SystemExit("P0: conflicting wallet-spend function definitions")
    if 'realEstate = propertyInfo' not in profile_schema or 'ownedProperties = deeds' not in profile_schema:
        raise SystemExit("P0: mixed V4 player account state would be truncated")

    for service in ("TerritoryService", "CrewService", "PropertyService",
                    "BankNetworkService", "NatureService", "DistrictSocietyService"):
        if service + ".Start()" not in bootstrap:
            raise SystemExit("P0: incomplete civic city bootstrap: " + service)
    if "FactionService.Start()" in bootstrap:
        raise SystemExit("P0: duplicate faction registries produce diverging player teams")
    if 'WaitForChild("SocialSystemsTests")).Run()' not in bootstrap:
        raise SystemExit("Social systems Studio acceptance suite not wired")
    if "Rules.SetAllegiance" not in (
        ROOT / "src/server/services/CrewService.luau").read_text(encoding="utf-8"):
        raise SystemExit("P0: gang and federal teams cannot claim their territory")

    workflows = ROOT / ".github" / "workflows"
    if workflows.exists() and any(workflows.iterdir()):
        raise SystemExit("GitHub Actions workflows are explicitly disabled")
    print(f"PASS: {len(REQUIRED)} required files, valid Rojo paths, no CI")


if __name__ == "__main__":
    main()
