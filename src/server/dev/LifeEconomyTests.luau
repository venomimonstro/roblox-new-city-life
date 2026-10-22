--!strict
-- Studio-only deterministic economy regression tests. No external DataStore writes.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("ProfileSchema"))
local Life = require(Shared:WaitForChild("LifeEconomy"))
local Tests = {}

function Tests.Run()
    local p = Schema.New(10001)
    assert(p.homeCredits == 0 and p.medicalDebt == 0 and p.deathCount == 0
        and next(p.securityBonds) == nil, "New account medical/home defaults")
    assert(Schema.Decode(p) ~= nil, "New extended V4 account must deserialize")

    p.credits, p.bankCredits, p.homeCredits = 10000, 3000, 2500
    local before = p.credits + p.bankCredits + p.homeCredits
    assert(Life.DeathSettlement(p, 0, "death_test_0001"), "Regular death settles")
    assert(p.credits == 8150 and p.bankCredits == 3000 and p.homeCredits == 2500,
        "Only carried cash and treatment fee are affected")
    assert(p.deathCount == 1, "Death counted once")
    assert(not Life.DeathSettlement(p, 0, "death_test_0001"),
        "Repeated humanoid death cannot charge again")
    assert(p.credits + p.bankCredits + p.homeCredits < before,
        "Death should carry an actual financial penalty")

    local saturated = Schema.New(10005)
    saturated.credits, saturated.bankCredits = 2500, 1000
    saturated.medicalDebt = 1000000
    saturated.deathCount = 100000000
    assert(Life.DeathSettlement(saturated, 5, "death_saturated_0001"),
        "Maxed hospital debt must never suppress the next death settlement")
    assert(saturated.medicalDebt == 1000000
        and saturated.deathCount == 100000000
        and Schema.Decode(saturated) ~= nil,
        "Death ledger must saturate while keeping the account valid")
    assert(not Life.DeathSettlement(saturated, 5, "death_saturated_0001"),
        "Saturated debt cannot bypass receipt idempotency")
    local poor = Schema.New(10002)
    assert(Life.DeathSettlement(poor, 5, "death_test_0002"),
        "Broke wanted player still receives treatment")
    assert(poor.medicalDebt == 800 and poor.deathCount == 1,
        "Unpaid clinic fee becomes debt instead of mandatory Robux purchase")
    assert(poor.credits == 0 and poor.bankCredits == 0
        and Schema.Decode(poor) ~= nil, "Poor player may continue earning")
    poor.credits = 400
    assert(Life.PayMedicalDebt(poor, 250, "clinic_paid_0001"),
        "Medical debt can be repaid with gameplay credits")
    assert(poor.medicalDebt == 550 and poor.credits == 150)
    assert(not Life.PayMedicalDebt(poor, 250, "clinic_paid_0001"),
        "Same clinic receipt never pays twice")

    assert(Life.TransferHome(p, 500, true, "home_deposit_0001"),
        "Store cash at owned home")
    assert(p.homeCredits == 3000 and p.credits == 7650)
    assert(not Life.TransferHome(p, 500, true, "home_deposit_0001"),
        "Home deposit operation is idempotent")
    assert(Life.TransferHome(p, 500, false, "home_withdraw_0001"),
        "Withdraw from home safe")
    assert(p.homeCredits == 2500 and p.credits == 8150)
    assert(not Life.TransferHome(p, 9999, false, "home_overflow_0001"),
        "Home safe rejects unsupported amount")

    assert(Life.InvestSafety(p, "downtown", "safety_stake_0001"),
        "Player can fund district safety")
    assert(p.securityBonds.downtown == 1 and p.credits == 6900)
    assert(not Life.InvestSafety(p, "downtown", "safety_stake_0001"),
        "Same bond purchase cannot be replayed")
    local bankBefore = p.bankCredits
    assert(Life.SecurityDividend(p, "downtown", "safety_income_0001"),
        "Only a holder receives safety dividends")
    assert(p.bankCredits == bankBefore + 30)
    assert(not Life.SecurityDividend(p, "downtown", "safety_income_0001"),
        "Same safety dividend cannot be claimed twice")
    assert(not Life.InvestSafety(p, "not_a_district", "bad_stake_0001"),
        "Server never accepts arbitrary investment target")

    assert(Life.BountyReward(p, 5, "bounty_award_0001"),
        "Confirmed five-star bounty amount is payable")
    assert(not Life.BountyReward(p, 5, "bounty_award_0001"),
        "Repeated bounty is not a second payment")
    assert(not Life.BountyReward(p, 2, "bounty_low_0001"),
        "Low-star opponents cannot pay police bounty")

    local migrated = Schema.New(10003)
    migrated.homeCredits = nil
    migrated.medicalDebt = nil
    migrated.deathCount = nil
    migrated.securityBonds = nil
    local valid = Schema.Decode(migrated)
    assert(valid and valid.homeCredits == 0 and valid.medicalDebt == 0
        and next(valid.securityBonds) == nil,
        "Older V4 account must migrate without losing cars or money")
    assert(Schema.Decode(p) ~= nil, "Rich account persists without profile schema failure")
    print("[StreetCity] PASS: medical debt, no-paywall respawn, protected cash, bounty and security ledger")
end

return Tests
