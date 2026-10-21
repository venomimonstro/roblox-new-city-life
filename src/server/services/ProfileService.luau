--!strict
-- Fail-closed session storage. No gameplay grants may rely on unloaded profiles.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Schema = require(ReplicatedStorage.Shared:WaitForChild("ProfileSchema"))

local ProfileService = {}
local store = DataStoreService:GetDataStore("StreetCityProfiles_v1")
local token = HttpService:GenerateGUID(false)
local LEASE = 180
local profiles: { [number]: any } = {}
local loading: { [number]: boolean } = {}
local closing = false

local function key(player: Player): string
    return "user_" .. tostring(player.UserId)
end

local function acquire(player: Player)
    if profiles[player.UserId] or loading[player.UserId] then return end
    loading[player.UserId] = true
    local accepted = false
    local outcome: any = nil
    local ok, err = pcall(function()
        outcome = store:UpdateAsync(key(player), function(old)
            if type(old) == "table" and old.owner and old.owner ~= token
                and type(old.leaseUntil) == "number" and old.leaseUntil > os.time() then
                return nil
            end
            local data = if old == nil then Schema.New() else Schema.Decode(old.data)
            if not data then return nil end
            accepted = true
            return { owner = token, leaseUntil = os.time() + LEASE, data = data }
        end)
    end)
    loading[player.UserId] = nil
    if not ok or not accepted or type(outcome) ~= "table" or outcome.owner ~= token then
        warn("[StreetCity] Profile unavailable: " .. tostring(err))
        if player.Parent == Players then
            player:Kick("Player data is temporarily unavailable. Please reconnect.")
        end
        return
    end
    if player.Parent ~= Players or closing then
        -- Disconnect during load: best-effort lease release.
        pcall(function()
            store:UpdateAsync(key(player), function(old)
                if type(old) == "table" and old.owner == token then
                    return { owner = nil, leaseUntil = 0, data = old.data }
                end
                return nil
            end)
        end)
        return
    end
    profiles[player.UserId] = outcome.data
end

function ProfileService.Get(player: Player): any?
    return profiles[player.UserId]
end

function ProfileService.Save(player: Player, release: boolean): boolean
    local profile = profiles[player.UserId]
    if not profile or not Schema.Decode(profile) then return false end
    local wrote = false
    local ok, err = pcall(function()
        store:UpdateAsync(key(player), function(old)
            if type(old) ~= "table" or old.owner ~= token then return nil end
            wrote = true
            return {
                owner = if release then nil else token,
                leaseUntil = if release then 0 else os.time() + LEASE,
                data = profile,
            }
        end)
    end)
    if not ok then warn("[StreetCity] Save failed: " .. tostring(err)) end
    if ok and wrote and release then profiles[player.UserId] = nil end
    return ok and wrote
end

function ProfileService.Start()
    Players.PlayerAdded:Connect(function(player)
        task.spawn(acquire, player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        if profiles[player.UserId] then ProfileService.Save(player, true) end
    end)
    for _, player in Players:GetPlayers() do task.spawn(acquire, player) end
    task.spawn(function()
        while not closing do
            task.wait(60)
            for _, player in Players:GetPlayers() do
                if profiles[player.UserId] then
                    if not ProfileService.Save(player, false) then
                        -- An old or stolen lease must never keep handling state mutations.
                        profiles[player.UserId] = nil
                        player:Kick("Profile lock lost. Please reconnect.")
                    end
                end
            end
        end
    end)
    game:BindToClose(function()
        closing = true
        for _, player in Players:GetPlayers() do
            if profiles[player.UserId] then ProfileService.Save(player, true) end
        end
    end)
end

return ProfileService
