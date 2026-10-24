--!strict
-- Launch with Roblox Studio: --task RunScript --localPlaceFile <rbxlx>
-- --runScriptFile <this file> --outputFile <log> --quitAfterExecution
-- Not Roblox CLI code; this script executes INSIDE Roblox Studio.
local StudioTestService = game:GetService("StudioTestService")
local HttpService = game:GetService("HttpService")
local token = "STREET_CITY_RELEASE_AUTOMATION_V1"
print("[StreetCity Automation] Starting two real Studio clients")
local receipt = StudioTestService:ExecuteMultiplayerTestAsync(2, token)
assert(type(receipt) == "string", "StudioTestService did not return receipt")
local parsed = HttpService:JSONDecode(receipt)
assert(type(parsed) == "table" and parsed.status == "PASS"
    and parsed.players == 2 and type(parsed.checks) == "table",
    "Studio multiplayer acceptance FAIL: " .. receipt)
local expected = {
    two_real_clients_connected = true,
    both_profiles_homes_and_cars_ready = true,
    private_plot_slots_unique = true,
    private_vehicle_ownership_unique = true,
    two_client_HUD_receipts = true,
    actual_death_and_free_home_respawn = true,
    medical_accounting_after_death = true,
    owned_vehicle_replaced_after_death = true,
    other_account_untouched = true,
}
for _, check in parsed.checks do
    if check.status == "PASS" then expected[check.name] = nil end
end
assert(next(expected) == nil, "Missing mandatory live multiplayer assertions")
print("STREET_CITY_AUTOMATED_ACCEPTANCE_PASS " .. receipt)
