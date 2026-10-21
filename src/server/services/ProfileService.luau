--!strict
-- Server-owned, fail-closed profile persistence. All edits execute INSIDE UpdateAsync.
-- Edit callbacks must be pure, synchronous and safe to re-execute on retries.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("ProfileSchema"))
local MutationOutcome = require(Shared:WaitForChild("ProfileMutationOutcome"))

local ProfileService = {}
local store: any = nil
local token = HttpService:GenerateGUID(false)
local LEASE = 180
local profiles: {[number]: any} = {}
local loading: {[number]: boolean} = {}
local busy: {[number]: boolean} = {}
local quarantined: {[number]: boolean} = {}
local closing = false
local sandbox = RunService:IsStudio() and game.GameId == 0

local function activeStore(): any
    -- GetDataStore may be unavailable in an unpublished Studio place.
    -- Never open it during module loading; sandbox profiles stay in memory.
    if sandbox then error("Persistent DataStore is disabled in Studio sandbox") end
    if not store then
        store = DataStoreService:GetDataStore("StreetCityProfiles_v1")
    end
    return store
end
local stateRemote: RemoteEvent? = nil
local summaryThrottle: {[number]: number} = {}

local function emitSummary(player: Player)
    local profile = profiles[player.UserId]
    if not stateRemote or not profile or player.Parent ~= Players then return end
    local cars = 0
    for _ in pairs(profile.garage) do cars += 1 end
    stateRemote:FireClient(player, profile.credits, cars, profile.selectedVehicleId)
end

local function key(player: Player): string
    return "user_" .. tostring(player.UserId)
end

local function owned(old: any): boolean
    return type(old) == "table" and old.owner == token
end

local function acquire(player: Player)
    local id = player.UserId
    if loading[id] or profiles[id] then return end
    loading[id] = true
    if sandbox then
        profiles[id] = Schema.New()
        loading[id] = nil
        emitSummary(player)
        return
    end
    local ok, output = pcall(function()
        return activeStore():UpdateAsync(key(player), function(old)
            if old ~= nil and type(old) ~= "table" then return nil end
            if old and old.owner ~= nil and old.owner ~= token then
                if type(old.leaseUntil) ~= "number" or old.leaseUntil > os.time() then return nil end
            end
            local data = if old == nil then Schema.New() else Schema.Decode(old.data)
            if not data then return nil end
            return {owner = token, leaseUntil = os.time() + LEASE, data = data}
        end)
    end)
    loading[id] = nil
    if not ok or not owned(output) or not Schema.Decode(output.data) then
        if player.Parent == Players then player:Kick("Profile temporarily unavailable.") end
        return
    end
    profiles[id] = Schema.Decode(output.data)
    quarantined[id] = nil
    emitSummary(player)
    if player.Parent ~= Players or closing then
        ProfileService.Save(player, true)
    end
end

function ProfileService.IsLoaded(player: Player): boolean
    return profiles[player.UserId] ~= nil and not quarantined[player.UserId] and not closing
end

function ProfileService.Read(player: Player): any?
    if quarantined[player.UserId] then return nil end
    local data = profiles[player.UserId]
    return if data then Schema.Decode(data) else nil
end

-- A failed/ambiguous write must not be re-applied to a stale cached profile.
-- Run validation/operation-id checks inside the transform using the freshest value.
function ProfileService.Mutate(player: Player, edit: (any) -> boolean): boolean
    local id = player.UserId
    if closing or player.Parent ~= Players or not profiles[id] or quarantined[id] or busy[id] then return false end
    busy[id] = true
    if sandbox then
        local candidate = Schema.Decode(profiles[id])
        local safe, accepted = pcall(edit, candidate)
        local valid = safe and accepted == true and candidate ~= nil and Schema.Decode(candidate) ~= nil
        if valid then profiles[id] = Schema.Decode(candidate) end
        busy[id] = nil
        if valid then emitSummary(player) end
        return valid
    end
    local acceptedInTransform = false
    local rejectedByRule = false
    local invalidOrLost = false
    local ok, output = pcall(function()
        return activeStore():UpdateAsync(key(player), function(old)
            -- UpdateAsync can invoke this callback repeatedly on write conflicts.
            acceptedInTransform = false
            rejectedByRule = false
            invalidOrLost = false
            if not owned(old) then
                invalidOrLost = true
                return nil
            end
            local candidate = Schema.Decode(old.data)
            if not candidate then
                invalidOrLost = true
                return nil
            end
            local safe, accepted = pcall(edit, candidate)
            if not safe then
                invalidOrLost = true
                return nil
            end
            if accepted ~= true then
                -- A normal business-rule rejection cancels UpdateAsync.
                -- Roblox returns nil for that cancellation, NOT the old record.
                rejectedByRule = true
                return nil
            end
            if not Schema.Decode(candidate) then
                invalidOrLost = true
                return nil
            end
            acceptedInTransform = true
            return {owner = token, leaseUntil = os.time() + LEASE, data = candidate}
        end)
    end)
    local outputValid = type(output) == "table" and Schema.Decode(output.data) ~= nil
    local outcome = MutationOutcome.Classify(
        ok, acceptedInTransform, rejectedByRule, invalidOrLost, output, token, outputValid
    )
    if outcome == "committed" then
        profiles[id] = Schema.Decode(output.data)
        emitSummary(player)
    elseif outcome == "rejected" then
        -- Ordinary insufficient-funds / duplicate-ID rejection. Keep player online.
    else
        -- Missing ownership proof, transform error or indeterminate write status.
        -- Do not allow further player mutations until a fresh session is loaded.
        -- Preserve the last validated snapshot only so PlayerRemoving can
        -- release our lease after the account has been quarantined.
        quarantined[id] = true
        if player.Parent == Players then
            task.defer(function()
                if player.Parent == Players then
                    player:Kick("Profile lock unconfirmed. Please reconnect.")
                end
            end)
        end
    end
    busy[id] = nil
    if not ok then warn("[StreetCity] Profile mutation failed for user " .. tostring(id)) end
    return outcome == "committed"
end

-- Renew/release only the most recently committed DataStore data; never overwrite
-- it with a potentially stale memory snapshot after an uncertain network failure.
function ProfileService.Save(player: Player, release: boolean): boolean
    local id = player.UserId
    if not profiles[id] or busy[id] then return false end
    busy[id] = true
    if sandbox then
        if release then profiles[id] = nil end
        busy[id] = nil
        return true
    end
    local confirmed = false
    local confirmedData: any = nil
    local lastError: any = nil
    -- Lease renewal is safe to retry: each attempt reads the newest record
    -- and never overwrites persisted gameplay data with an in-memory snapshot.
    for attempt = 1, 3 do
        local ok, output = pcall(function()
            return activeStore():UpdateAsync(key(player), function(old)
                if not owned(old) or not Schema.Decode(old.data) then return nil end
                return {
                    owner = if release then nil else token,
                    leaseUntil = if release then 0 else os.time() + LEASE,
                    data = old.data,
                }
            end)
        end)
        confirmed = ok and type(output) == "table"
            and output.owner == (if release then nil else token)
            and Schema.Decode(output.data) ~= nil
        if confirmed then
            confirmedData = Schema.Decode(output.data)
            break
        end
        lastError = if ok then "lease ownership not confirmed" else tostring(output)
        -- Do not retry after a clean ownership conflict; only transient API errors.
        if ok or attempt == 3 then break end
        task.wait(0.35 * attempt)
    end
    if confirmed then
        profiles[id] = if release then nil else confirmedData
        if release then quarantined[id] = nil end
    end
    busy[id] = nil
    if not confirmed then warn("[StreetCity] Profile lease/save not confirmed for " .. tostring(id) .. ": " .. tostring(lastError)) end
    return confirmed
end

function ProfileService.Start()
    if sandbox then warn("[StreetCity] LOCAL SANDBOX: profile is temporary, not persisted") end
    stateRemote = Instance.new("RemoteEvent")
    stateRemote.Name = "StreetCityProfileState"
    stateRemote.Parent = game:GetService("ReplicatedStorage")
    stateRemote.OnServerEvent:Connect(function(player: Player)
        local now = os.clock()
        if now - (summaryThrottle[player.UserId] or 0) < 2 then return end
        summaryThrottle[player.UserId] = now
        emitSummary(player)
    end)
    Players.PlayerAdded:Connect(function(player) task.spawn(acquire, player) end)
    Players.PlayerRemoving:Connect(function(player)
        summaryThrottle[player.UserId] = nil
        local deadline = os.clock() + 10
        while busy[player.UserId] and os.clock() < deadline do task.wait(0.1) end
        if profiles[player.UserId] then ProfileService.Save(player, true) end
        quarantined[player.UserId] = nil
        profiles[player.UserId] = nil
    end)
    for _, player in Players:GetPlayers() do task.spawn(acquire, player) end
    task.spawn(function()
        while not closing do
            task.wait(55)
            for _, player in Players:GetPlayers() do
                if profiles[player.UserId] and not busy[player.UserId] then
                    if not ProfileService.Save(player, false) then
                        profiles[player.UserId] = nil
                        player:Kick("Profile storage lost. Reconnect later.")
                    end
                end
            end
        end
    end)
    game:BindToClose(function()
        closing = true
        for _, player in Players:GetPlayers() do
            local deadline = os.clock() + 10
            while busy[player.UserId] and os.clock() < deadline do task.wait(0.1) end
            if profiles[player.UserId] then ProfileService.Save(player, true) end
        end
    end)
end

return ProfileService
