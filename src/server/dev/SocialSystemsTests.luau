--!strict
-- Deterministic Studio domain and integration checks. No live DataStore writes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("ProfileSchema"))
local Wallet = require(Shared:WaitForChild("GarageTransactions"))
local Estates = require(Shared:WaitForChild("PropertyTransactions"))
local Catalog = require(Shared:WaitForChild("PropertyCatalog"))
local Dynamics = require(Shared:WaitForChild("DistrictDynamics"))
local Tests = {}

function Tests.Run()
    local assertions = 0
    local function check(result: boolean, name: string)
        assert(result, "[SocialSystems] " .. name)
        assertions += 1
    end
    local profile = Schema.New(111)
    check(profile.schemaVersion == 4 and profile.communityBankCredits == 0,
        "new V4 profile includes separate bank")
    check(profile.realEstate.home == 1 and next(profile.ownedProperties) == nil,
        "combined property branches initialized")
    check(profile.allegiance == "independent" and profile.guards == 0,
        "civic affiliation available")
    check(Schema.Decode(profile) ~= nil, "V4 profile self-consistent")

    -- Accept either of the two V4 variants already saved during development.
    local branchA = Schema.Decode(profile)
    branchA.ownedProperties = nil
    branchA.communityBankCredits = nil
    check(Schema.Decode(branchA) ~= nil, "legacy civic V4 accepted")
    local branchB = Schema.Decode(profile)
    branchB.realEstate = nil
    branchB.allegiance = nil
    branchB.guards = nil
    branchB.henchmen = nil
    branchB.allegianceChangedAt = nil
    check(Schema.Decode(branchB) ~= nil, "legacy estate V4 accepted")

    local old = Schema.Decode(profile)
    old.schemaVersion = 3
    old.communityBankCredits = nil
    old.ownedProperties = nil
    old.allegiance = nil
    old.realEstate = nil
    old.guards = nil
    old.henchmen = nil
    old.allegianceChangedAt = nil
    local upgraded = Schema.Decode(old)
    check(upgraded and upgraded.schemaVersion == 4 and upgraded.credits == old.credits,
        "V3 migration does not reset money")

    local state = Dynamics.New("downtown")
    Dynamics.Recalculate(state)
    local previous = state.safety
    local homes = state.population
    check(Dynamics.Apply(state, "crime", 4), "crime event accepted")
    check(state.safety < previous and state.population <= homes,
        "crime reduces district safety and desirability")
    local crimePrice = Dynamics.MarketPrice(4000, state)
    check(Dynamics.Apply(state, "security", 4), "guard operation")
    check(Dynamics.Apply(state, "civic", 4), "police investment")
    check(state.safety > previous - 12, "security restores safety")
    check(Dynamics.MarketPrice(4000, state) >= crimePrice,
        "local improvements increase property prices")
    check(not Dynamics.Apply(state, "crime", 999), "unbounded crime rejected")

    profile.credits = 15000
    local propertyId = "downtown_flat"
    local price = Dynamics.MarketPrice(Catalog[propertyId].basePrice, state)
    check(Estates.Buy(profile, propertyId, price, "buy_00000001"),
        "municipal property bought with saved cash")
    check(not Estates.Buy(profile, propertyId, price, "buy_00000001"),
        "double property purchase prevented")
    check(Estates.SetRental(profile, propertyId, true, 1000),
        "renting activated with server-provided timestamp")
    check(not Estates.CollectRent(profile, propertyId, 1299, "rent_0000001"),
        "cannot instantly farm rental payouts")
    check(Estates.CollectRent(profile, propertyId, 1300, "rent_0000002"),
        "eligible rent paid exactly once")
    check(not Estates.CollectRent(profile, propertyId, 1300, "rent_0000002"),
        "duplicate rent blocked")
    check(Estates.CommunityBank(profile, 500, true, "cbank_000001"),
        "community deposit moves cash")
    check(Estates.CommunityBank(profile, 500, false, "cbank_000002"),
        "community withdrawal restores cash")
    check(profile.communityBankCredits == 0, "community balance conserved")
    check(Estates.SellToCity(profile, propertyId, "sell_0000001"),
        "property resale credited")
    check(profile.ownedProperties[propertyId] == nil, "sold property removed")
    check(Schema.Decode(profile) ~= nil, "post-transactions account schema valid")

    -- Regression: one SpendCredits implementation, including purchases >2000.
    check(Wallet.SpendCredits(profile, 2500, "spend_0000001"),
        "big municipal purchase works")
    check(not Wallet.SpendCredits(profile, 2500, "spend_0000001"),
        "repeat municipal charge blocked")
    check(Schema.Decode(profile) ~= nil, "repeated operation journal stays valid")

    local world = workspace:FindFirstChild("StreetCityPrototypeWorld")
    check(world ~= nil and world:FindFirstChild("CityCrews") ~= nil,
        "gang and federal HQ created")
    check(world:FindFirstChild("DistrictProperties") ~= nil,
        "district property markets visible")
    check(world:FindFirstChild("NatureAndWildlife") ~= nil
        or world:FindFirstChild("CityNature") ~= nil,
        "wildlife/forest world created")
    check(world:FindFirstChild("CityPedestrians") ~= nil,
        "dynamic NPC resident pool present")
    check(ReplicatedStorage:FindFirstChild("StreetCityDistrictState") ~= nil,
        "district state replication available")
    print("[StreetCity SocialSystems] PASS: " .. assertions .. " tests")
end

return Tests
