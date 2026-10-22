#!/usr/bin/env python3
"""Local structural checks. Deliberately no network access or CI dependency."""

from __future__ import annotations

import json
import re
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
    "src/shared/VehicleDamageRules.luau",
    "src/server/dev/VehicleDamageTests.luau",
    "docs/GLOBAL_ACCEPTANCE_MATRIX_2026-10-22.md",
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
    "src/shared/TransportSpecs.luau",
    "src/server/services/TransportPhysicsService.luau",
    "src/server/dev/TransportPhysicsTests.luau",
    "src/shared/LegalCareerCatalog.luau",
    "src/shared/TransitMap.luau",
    "src/shared/NpcLifeRules.luau",
    "src/shared/CareerRules.luau",
    "src/shared/LifeEconomy.luau",
    "src/server/services/DistrictSocietyService.luau",
    "src/server/services/PropertyService.luau",
    "src/server/services/PropertyMarketService.luau",
    "src/server/services/CrewService.luau",
    "src/server/services/BankNetworkService.luau",
    "src/server/services/NatureService.luau",
    "src/server/services/HousingService.luau",
    "src/server/services/CityArchitecture.luau",
    "src/server/services/CityInfillService.luau",
    "src/server/dev/CityInfillTests.luau",
    "src/client/MapHUD.client.luau",
    "src/server/services/StreetDetailService.luau",
    "src/server/services/SprintService.luau",
    "src/server/dev/WorldTraversalTests.luau",
    "src/server/dev/TrafficSafetyTests.luau",
    "src/server/dev/CityTraversalTests.luau",
    "src/server/services/WeatherService.luau",
    "src/server/services/TrafficService.luau",
    "src/server/services/LifestyleService.luau",
    "src/server/services/CityJobsService.luau",
    "src/server/services/LegalCareerService.luau",
    "src/server/services/PublicTransitService.luau",
    "src/server/services/NpcLifeService.luau",
    "src/server/services/WorkShiftRegistry.luau",
    "src/server/services/LifeAndDeathService.luau",
    "src/server/services/BountyService.luau",
    "src/server/services/CitizenService.luau",
    "src/server/services/WantedService.luau",
    "src/server/services/CrimeEconomyService.luau",
    "src/server/services/ArmoryService.luau",
    "src/server/dev/CityLifeTests.luau",
    "src/server/dev/LegalCareerTests.luau",
    "src/server/dev/CareerWorldTests.luau",
    "src/server/dev/TransitAndNpcTests.luau",
    "src/server/dev/LifeEconomyTests.luau",
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
    "src/server/services/WorldSurfaceAudit.luau",
    "tools/release_gate.py",
    "docs/architecture.md",
    "docs/roadmap.md",
    "docs/quality.md",
)


def main() -> None:
    missing = [path for path in REQUIRED if not (ROOT / path).is_file()]
    if missing:
        raise SystemExit("MISSING: " + ", ".join(missing))

    # Studio test-suite parse regression: an assert message must be separated
    # from its preceding boolean condition with a comma. This catches the
    # previously committed TransitAndNpcTests missing-comma failure.
    missing_assert_comma = re.compile(
        r"(?:~=|==)\s*(?:nil|true|false)\s*\n\s*\"[^\"\n]+\"\s*\)"
    )
    for source in (ROOT / "src").rglob("*.luau"):
        code = source.read_text(encoding="utf-8")
        if missing_assert_comma.search(code):
            raise SystemExit("Luau assertion parse regression (missing comma): "
                             + str(source.relative_to(ROOT)))

    transit = (ROOT / "src/server/services/PublicTransitService.luau").read_text(
        encoding="utf-8"
    )
    before_fare = transit.split("local function ride(", 1)[-1].split(
        "Wallet.SpendCredits(profile, fare, operation)", 1)[0]
    if "safeArrival(destination, character)" not in before_fare:
        raise SystemExit("Transit charges fare before checking destination ground")
    if "task.delay(waitSeconds" not in before_fare or "(currentRoot.Position - origin).Magnitude > 17" not in before_fare:
        raise SystemExit("Transit charges before departure or lets riders leave the station")
    if 'pending[id] = operation' not in transit or 'pending[id] ~= operation' not in transit:
        raise SystemExit("Old transit reservation can interfere with a reconnected player")
    if "refundOperation" not in transit or "Wallet.AwardCredits" not in transit:
        raise SystemExit("Transit cannot idempotently compensate failed trips")
    if "GetPartBoundsInBox" not in transit or "StreetCity Transit" not in transit:
        raise SystemExit("Transit has no safe avatar-volume landing validation")
    transit_tests = (
        ROOT / "src/server/dev/TransitAndNpcTests.luau"
    ).read_text(encoding="utf-8")
    if "Transit.CheckArrivalForTests" not in transit_tests:
        raise SystemExit("Transit landing geometry has no Studio acceptance test")

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

    # Career/clinic release contract: a source-only check, not a Roblox Studio run.
    career_source = (ROOT / "src/server/services/LegalCareerService.luau").read_text(encoding="utf-8")
    career_catalog = (ROOT / "src/shared/LegalCareerCatalog.luau").read_text(encoding="utf-8")
    mission_rules = (ROOT / "src/shared/CareerRules.luau").read_text(encoding="utf-8")
    legacy_jobs = (ROOT / "src/server/services/CityJobsService.luau").read_text(encoding="utf-8")
    payout_source = (ROOT / "src/server/services/BountyService.luau").read_text(encoding="utf-8")
    life_source = (ROOT / "src/server/services/LifeAndDeathService.luau").read_text(encoding="utf-8")
    for module in ("LegalCareerService", "LifeAndDeathService", "BountyService"):
        if module + ".Start()" not in bootstrap:
            raise SystemExit("P0: critical careers/death system not started: " + module)
    for fixture in ("LegalCareerTests", "LifeEconomyTests"):
        if 'WaitForChild("' + fixture + '")).Run()' not in bootstrap:
            raise SystemExit("P0: Studio life or career regression tests not wired: " + fixture)
    if career_catalog.count('id="') < 16:
        raise SystemExit("P0: missing promised variety of legal careers")
    if "ShiftRegistry.Claim" not in career_source or "ShiftRegistry.Claim" not in legacy_jobs:
        raise SystemExit("P0: two concurrent jobs can print credits for one trip")
    if "ShiftRegistry.Release" not in career_source or "ShiftRegistry.Release" not in legacy_jobs:
        raise SystemExit("P0: shift locks cannot be released")
    if "CareerRules.CanFinishLeg" not in career_source or "CareerRules.CanFinishLeg" not in legacy_jobs:
        raise SystemExit("P0: jobs may pay for standing still or teleporting")
    if "if not matchesRequiredMode then return false end" not in mission_rules:
        raise SystemExit("P0: foot and driving mission modes are inverted")
    if "pendingFishSale[id] = true" not in legacy_jobs:
        raise SystemExit("P0: asynchronous fish sale can pay twice")
    if "StreetCityCareerStatus" not in career_source:
        raise SystemExit("P0: route instructions not sent to players")
    if "StreetCityCareerStatus" not in (ROOT / "src/client/bootstrap.client.luau").read_text(encoding="utf-8"):
        raise SystemExit("P0: mobile player cannot see mission waypoints")
    if "Economy.DeathSettlement" not in life_source or "Bounty.ResolveDeath" not in life_source:
        raise SystemExit("P0: death misses hospital bill or verified bounty settlement")
    if "securityBonds" not in profile_schema or "homeCredits" not in profile_schema:
        raise SystemExit("P0: safety investments or home cash not persisted")
    if "math.floor(os.time() / 1800)" not in payout_source:
        raise SystemExit("P0: wanted bounty operations lack replay window")
    if "StreetCityWantedPosters" not in (ROOT / "src/client/bootstrap.client.luau").read_text(encoding="utf-8"):
        raise SystemExit("P1: wanted posters not rendered to bounty hunters")

    # World, home and traversal release gates. Each is a static source
    # invariant; only Roblox Studio can execute the geometry/raycast tests.
    world = (ROOT / "src/server/services/WorldService.luau").read_text(encoding="utf-8")
    housing = (ROOT / "src/server/services/HousingService.luau").read_text(encoding="utf-8")
    detail = (ROOT / "src/server/services/StreetDetailService.luau").read_text(encoding="utf-8")
    architecture = (ROOT / "src/server/services/CityArchitecture.luau").read_text(encoding="utf-8")
    sprint = (ROOT / "src/server/services/SprintService.luau").read_text(encoding="utf-8")
    district_cosmetics = (ROOT / "src/server/services/DistrictDetailService.luau").read_text(encoding="utf-8")
    traversal = (ROOT / "src/server/dev/WorldTraversalTests.luau").read_text(encoding="utf-8")
    for service in ("StreetDetailService", "SprintService"):
        if service + ".Start()" not in bootstrap:
            raise SystemExit("P0: walking/driving world service not started: " + service)
    if 'WaitForChild("WorldTraversalTests")).Run()' not in bootstrap:
        raise SystemExit("P0: actual Studio road seams and residential access tests missing")
    if "WorldPerimeter" not in world and "local extent = 2304" not in world:
        raise SystemExit("P0: terrain must extend beyond the end of every road")
    if 'StreetEnvironment' not in detail or 'Sidewalks' not in detail or 'Crosswalks' not in detail:
        raise SystemExit("P0: pedestrian roads or crossing generation missing")
    if '"StreetEnvironment"' not in production_gate:
        raise SystemExit("P0: world should not report ready with missing sidewalks")
    if '"StreetCitySprintRequest"' not in production_gate:
        raise SystemExit("P0: running remote not included in startup gate")
    if "lastVoidRescue" not in housing or "rootPart.Position.Y < -45" not in housing:
        raise SystemExit("P0: prevent death from world streaming fall-through")
    if 'anchor.Transparency = 1' not in housing or '"HouseFrontWing"' not in housing:
        raise SystemExit("P0: home reverted to an impenetrable box")
    if "PitchedRoof" not in architecture or "HomeWindow" not in architecture:
        raise SystemExit("P1: residential facades lost architectural details")
    if "buildingFacade(sector" in district_cosmetics or '"RoadMarkings"' in district_cosmetics:
        raise SystemExit("P1: duplicate facades or lane paint cause visual flicker")
    if "state.wants = false" not in sprint or "StreetCityStamina" not in sprint:
        raise SystemExit("P0: sprint release or authoritative stamina absent")
    if "StreetCitySprint" not in hud or "StreetCityHomePosition" not in hud:
        raise SystemExit("P0: controls or residential navigation missing from player HUD")
    if "Road sample hit wrong material" not in traversal or "House door is blocked" not in traversal:
        raise SystemExit("P0: Studio world tests must cover asphalt and accessible homes")

    # City streets now have ONE collision owner. Weather graphics and
    # decorations are not allowed to provide fake suspension ground.
    city_test = (ROOT / "src/server/dev/CityTraversalTests.luau").read_text(encoding="utf-8")
    if 'WaitForChild("CityTraversalTests")).Run()' not in bootstrap:
        raise SystemExit("P0: full road/garage/ocean collision tests not wired")
    for invariant in ("Road collision missing", "House must have a real opening door",
                      "Car spawn is not above its OWN physical garage floor",
                      "Coastline must be swim-capable Terrain water"):
        if invariant not in city_test:
            raise SystemExit("P0: Studio traversal fixture lacks " + invariant)
    if '"WorldLimits"' not in world or 'Enum.Material.Water' not in world:
        raise SystemExit("P0: world edge rescue or real water is missing")
    if "local rescueAccumulator = 0" not in housing or housing.count(
            "RunService.Heartbeat:Connect(function(dt)") != 1:
        raise SystemExit("P0: duplicate or missing player world recovery listener")
    vehicle = (ROOT / "src/server/services/VehicleService.luau").read_text(encoding="utf-8")
    if 'Housing.GetGarageSpawn(ownerPlayer)' not in vehicle:
        raise SystemExit("P0: fallen personal vehicle cannot recover at owner home")
    if '"FrontDoorPrompt"' not in housing or '"HouseCeiling"' not in architecture:
        raise SystemExit("P0: home entrance or solid roof regressed")
    if '"WalkwayNorthSouth"' in district_cosmetics or '"ZebraCrossing"' in district_cosmetics:
        raise SystemExit("P0: second street system added duplicate physical sidewalks")
    if '"StreetEnvironment"' not in detail:
        raise SystemExit("P0: missing sole global sidewalk generator")

    traffic_source = (ROOT / "src/server/services/TrafficService.luau").read_text(encoding="utf-8")
    world_test = (ROOT / "src/server/dev/WorldTraversalTests.luau").read_text(encoding="utf-8")
    if "for regionIndex, center in neighborhoods do" not in traffic_source:
        raise SystemExit("Traffic regression: all NPC cars must populate seven districts")
    if "civilian >= 14 and police >= 3" not in world_test:
        raise SystemExit("Traversal test missing population/road validation")
    if "Traffic agent failed" not in traffic_source or "createAgent(agent.points" not in traffic_source:
        raise SystemExit("Traffic regression: NPC recovery not enabled")

    surface = (ROOT / "src/server/services/WorldSurfaceAudit.luau").read_text(encoding="utf-8")
    if "WorldSurfaceAudit.Validate()" not in bootstrap:
        raise SystemExit("P0: world collision surface audit not activated before server-ready")
    for invariant in ("Enum.Material.Asphalt", "Homes.Capacity", "Districts",
                      "workspace:Raycast", "road, neighborhood, garage"):
        if invariant not in surface:
            raise SystemExit("P0: world surface audit missing " + invariant)
    if bootstrap.index("WorldSurfaceAudit.Validate()") > bootstrap.index("StartupContract.Validate()"):
        raise SystemExit("P0: road collision audit must run before ready contract")

    # Ensure repaired traffic never repeatedly spawns onto active players/vehicles.
    traffic_safety = (ROOT / "src/server/dev/TrafficSafetyTests.luau").read_text(encoding="utf-8")
    traffic_source = (ROOT / "src/server/services/TrafficService.luau").read_text(encoding="utf-8")
    if 'WaitForChild("TrafficSafetyTests")).Run()' not in bootstrap:
        raise SystemExit("P0: NPC traffic and seam checks not in Studio startup")
    for condition in ("agent.respawnAt = os.clock() + 8",
                      "rootPart.Position - midpoint", "model.PrimaryPart.Position - midpoint",
                      "npc.PrimaryPart.Position - position"):
        if condition not in traffic_source:
            raise SystemExit("P0: traffic safety regression: " + condition)
    if "Enum.Material.Asphalt" not in traffic_safety or "npc.PrimaryPart" not in traffic_safety:
        raise SystemExit("P0: traffic road probes or NPC checks removed")

    # Gameplay end-to-end anti-exploit regressions found by avatar journey audit.
    armory = (ROOT / "src/server/services/ArmoryService.luau").read_text(encoding="utf-8")
    old_jobs = (ROOT / "src/server/services/CityJobsService.luau").read_text(encoding="utf-8")
    if "targetHumanoid.Health <= damage" not in armory:
        raise SystemExit("P0: bounty can be paid by a fall after a non-lethal attack")
    if "(shift.drivenDistance or 0)" not in old_jobs or "shift.drivenDistance = 0" not in old_jobs:
        raise SystemExit("P0: taxi can be completed on foot or by teleporting")
    if "ShiftRegistry.Release" not in old_jobs:
        raise SystemExit("P0: paid jobs may block subsequent shifts forever")
    if 'route(player, def)' not in legacy_jobs or 'route(player, nil)' not in legacy_jobs:
        raise SystemExit("P1: original city jobs have no shared HUD navigation or cleanup")
    if 'ShiftRegistry.Release(id, "legacy_" .. def.id)' not in legacy_jobs:
        raise SystemExit("P0: old job cancellation fails to release shared shift")
    if 'delta > 0 and delta < 55 and validMode' not in legacy_jobs:
        raise SystemExit("P0: legacy job tracks implausible movement spikes")
    if 'local isOnFoot = humanoid ~= nil and humanoid.SeatPart == nil' not in career_source:
        raise SystemExit("P0: pedestrian transport classification missing")

    # Procedural neighborhoods and streaming-safe navigation.
    infill = (ROOT / "src/server/services/CityInfillService.luau").read_text(encoding="utf-8")
    infill_test = (ROOT / "src/server/dev/CityInfillTests.luau").read_text(encoding="utf-8")
    minimap = (ROOT / "src/client/MapHUD.client.luau").read_text(encoding="utf-8")
    if "CityInfillService.Start()" not in bootstrap:
        raise SystemExit("P0: procedural city infill service not started")
    if 'WaitForChild("CityInfillTests")).Run()' not in bootstrap:
        raise SystemExit("P0: Studio city infill collision acceptance not connected")
    if '"CityInfill"' not in infill or "GetPartBoundsInBox" not in infill:
        raise SystemExit("P0: generator lacks reserved-lot occupancy collision checks")
    if "Enum.ModelLevelOfDetail.SLIM" not in infill:
        raise SystemExit("P1: distant generated city geometry not optimized for streaming")
    for invariant in ("solids == 1", "New building occupies a driving lane",
                      "City under-populated", "Enum.Material.Asphalt"):
        if invariant not in infill_test:
            raise SystemExit("P0: procedural city Studio acceptance missing " + invariant)
    if '"StreetCityMapAndQuality"' not in minimap or "StreetCityHomePosition" not in minimap:
        raise SystemExit("P1: local minimap and home navigation not connected")
    if "StreetCityVisualQuality" not in minimap or "StreetCityVisualQuality" not in hud:
        raise SystemExit("P1: per-device rain/lighting quality mode broken")
    if "RequestStreamAroundAsync" not in housing:
        raise SystemExit("P0: personal home spawn must prefetch streaming terrain")
    if '"CityInfill"' not in (ROOT / "src/server/services/StartupContract.luau").read_text(encoding="utf-8"):
        raise SystemExit("P0: startup contract does not verify the populated new city")

    vehicle_damage = (ROOT / "src/shared/VehicleDamageRules.luau").read_text(encoding="utf-8")
    vehicle_service = (ROOT / "src/server/services/VehicleService.luau").read_text(encoding="utf-8")
    boot = (ROOT / "src/server/bootstrap.server.luau").read_text(encoding="utf-8")
    if "Damage.Impact(" not in vehicle_service or "Damage.DriveFactor(" not in vehicle_service:
        raise SystemExit("P0: impact/crash model not connected to live server vehicle physics")
    if 'WaitForChild("VehicleDamageTests")).Run()' not in boot:
        raise SystemExit("P0: vehicle damage Studio tests not hooked up")
    if "if not grounded or deltaSpeed < 15" not in vehicle_damage:
        raise SystemExit("P0: impact from airborne fall could damage before landing")

    for service in ("PublicTransitService", "NpcLifeService"):
        if service + ".Start()" not in bootstrap:
            raise SystemExit("Transit or NPC-life simulation omitted from game startup: " + service)
    if 'WaitForChild("TransitAndNpcTests")).Run()' not in bootstrap:
        raise SystemExit("Transit and NPC life suite not linked to Studio")
    transit = (ROOT / "src/server/services/PublicTransitService.luau").read_text(encoding="utf-8")
    for token in ("MetroEntrance_", "PlatformAccess_", "MetroExit_", "BusStop_",
                  "MetroTrain", "CityBusNPC", "Profile.Mutate(player"):
        if token not in transit:
            raise SystemExit("Transit user-journey contract missing " + token)
    life = (ROOT / "src/server/services/NpcLifeService.luau").read_text(encoding="utf-8")
    if "task.wait(12)" not in life or "nearPlayer(" not in life:
        raise SystemExit("NPC life regression: missing scheduled updates or proximity LOD")

    transport_source = (ROOT / "src/server/services/TransportPhysicsService.luau").read_text(encoding="utf-8")
    transport_specs = (ROOT / "src/shared/TransportSpecs.luau").read_text(encoding="utf-8")
    client_source = (ROOT / "src/client/bootstrap.client.luau").read_text(encoding="utf-8")
    for name in ("bicycle", "motorcycle", "dirtbike", "truck", "tractor", "bus",
                 "speedboat", "fishingboat", "propplane"):
        if name not in transport_specs or 'id="' + name + '"' not in transport_source:
            raise SystemExit("Transport class missing from specs or active fleet: " + name)
    if "TransportPhysicsService.Start()" not in bootstrap:
        raise SystemExit("New transport physics service not started")
    if 'WaitForChild("TransportPhysicsTests")).Run()' not in bootstrap:
        raise SystemExit("New transport studio simulation not connected")
    if 'TransportInput' not in client_source or 'TransportInput' not in transport_source:
        raise SystemExit("New vehicle controller has no client/server input link")
    if 'ReadVoxels(' in transport_source:
        raise SystemExit("Water force loop may misuse ReadVoxels multi-return or stress physics")
    if "seat.Occupant ~= humanoid" not in transport_source:
        raise SystemExit("Transport controls can be spoofed by remote clients")

    # P0 user-journey regression: salaries cannot be paid for foot microteleports,
    # missing owned-car driving, or an active job in another career system.
    career_rules = (ROOT / "src/shared/CareerRules.luau").read_text(encoding="utf-8")
    career_run = (ROOT / "src/server/services/LegalCareerService.luau").read_text(encoding="utf-8")
    legacy_run = (ROOT / "src/server/services/CityJobsService.luau").read_text(encoding="utf-8")
    economy = (ROOT / "src/shared/LifeEconomy.luau").read_text(encoding="utf-8")
    for marker in ("MaximumMovementForSample", "CanDeliverAfterParking",
                   "CanFinishLeg"):
        if marker not in career_rules or marker not in career_run:
            raise SystemExit("P0: mission completion bypasses server route checks: " + marker)
    if "lastDrivenPosition = nil" not in career_run or "lastSampleAt = now" not in career_run:
        raise SystemExit("P0: driving and travel checks survive unrelated legs")
    if "MaximumMovementForSample" not in legacy_run or "ShiftRegistry.Claim" not in legacy_run:
        raise SystemExit("P0: legacy jobs can be farmed via microteleports or double shifts")
    if "profile.deathCount = math.min(100000000" not in economy:
        raise SystemExit("P0: medical respawn breaks after bounded account counters fill")
    if 'WaitForChild("LegalCareerTests")).Run()' not in bootstrap:
        raise SystemExit("P0: Studio career simulations disconnected")
    if 'WaitForChild("LifeEconomyTests")).Run()' not in bootstrap:
        raise SystemExit("P0: Studio debt and free resurrection tests disconnected")

    # A teleport must invalidate a mission rather than silently relocate
    # its trusted origin to an attacker-controlled position.
    career = (ROOT / "src/server/services/LegalCareerService.luau").read_text(encoding="utf-8")
    legacy = (ROOT / "src/server/services/CityJobsService.luau").read_text(encoding="utf-8")
    if 'job.status = "invalidated"' not in career:
        raise SystemExit("P0: career teleport does not invalidate mission")
    if 'ShiftRegistry.Release(id, "legacy_" .. shift.id)' not in legacy:
        raise SystemExit("P0: legacy job teleport does not release shift lock")
    if 'shift.origin = pos' in legacy.split("if delta > CareerRules.MaximumMovementForSample")[1].split("elseif delta > 0")[0]:
        raise SystemExit("P0: legacy job re-bases origin after teleport")

    if 'WaitForChild("CareerWorldTests")).Run()' not in bootstrap:
        raise SystemExit("P0: playable career routes lack Studio ground-collision acceptance")
    world_jobs = (ROOT / "src/server/dev/CareerWorldTests.luau").read_text(encoding="utf-8")
    if "workspace:Raycast" not in world_jobs or "Fish_Sell" not in world_jobs:
        raise SystemExit("P0: not all career and fishing destinations are ground-checked")

    workflows = ROOT / ".github" / "workflows"
    if workflows.exists() and any(workflows.iterdir()):
        raise SystemExit("GitHub Actions workflows are explicitly disabled")
    print(f"PASS: {len(REQUIRED)} required files, valid Rojo paths, no CI")


if __name__ == "__main__":
    main()
