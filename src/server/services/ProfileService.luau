--!strict
-- Profile storage: fail closed, single in-server mutation lane per account.
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
local saving: { [number]: boolean } = {}
local closing = false
local function key(player: Player): string return "user_" .. tostring(player.UserId) end

local function persist(player: Player, data: any, release: boolean): boolean
    if not Schema.Decode(data) then return false end
    -- DataStore transforms may run more than once. No external effects inside callback.
    local ok, output = pcall(function()
        return store:UpdateAsync(key(player), function(old)
            if type(old) ~= "table" or old.owner ~= token then return nil end
            return {
                owner = if release then nil else token,
                leaseUntil = if release then 0 else os.time() + LEASE,
                data = data,
            }
        end)
    end)
    if not ok then
        warn("[StreetCity] Save failed for user " .. player.UserId .. ": " .. tostring(output))
        return false
    end
    return type(output) == "table" and output.owner == (if release then nil else token)
        and output.data ~= nil
end

local function acquire(player: Player)
    local id = player.UserId
    if loading[id] or profiles[id] then return end
    loading[id] = true
    local ok, output = pcall(function()
        return store:UpdateAsync(key(player), function(old)
            if old ~= nil and type(old) ~= "table" then return nil end
            if old and old.owner ~= nil and old.owner ~= token then
                if type(old.leaseUntil) ~= "number" or old.leaseUntil > os.time() then return nil end
            end
            local data = if old == nil then Schema.New() else Schema.Decode(old.data)
            if not data then return nil end
            return { owner = token, leaseUntil = os.time() + LEASE, data = data }
        end)
    end)
    loading[id] = nil
    if not ok or type(output) ~= "table" or output.owner ~= token
        or not Schema.Decode(output.data) then
        if player.Parent == Players then player:Kick("Player profile unavailable; reconnect later.") end
        return
    end
    profiles[id] = output.data
    if player.Parent ~= Players or closing then ProfileService.Save(player, true) end
end

function ProfileService.IsLoaded(player: Player): boolean
    return profiles[player.UserId] ~= nil
end

-- Explicit mutation API. This call yields during DataStore save; no direct profile references escape.
function ProfileService.Mutate(player: Player, edit: (any) -> boolean): boolean
    local id = player.UserId
    if closing or not profiles[id] or saving[id] then return false end
    saving[id] = true
    local original = profiles[id]
    local candidate = Schema.Decode(original)
    local edited, accepted = pcall(edit, candidate)
    local valid = edited and accepted == true and candidate ~= nil and Schema.Decode(candidate) ~= nil
    local saved = false
    if valid then saved = persist(player, candidate, false) end
    if saved then profiles[id] = candidate end
    saving[id] = nil
    return saved
end

function ProfileService.Read(player: Player): any?
    local p = profiles[player.UserId]
    return if p then Schema.Decode(p) else nil
end

function ProfileService.Save(player: Player, release: boolean): boolean
    local id = player.UserId
    if saving[id] or not profiles[id] then return false end
    saving[id] = true
    local saved = persist(player, profiles[id], release)
    if saved and release then profiles[id] = nil end
    saving[id] = nil
    return saved
end

function ProfileService.Start()
    Players.PlayerAdded:Connect(function(player) task.spawn(acquire, player) end)
    Players.PlayerRemoving:Connect(function(player)
        -- Pending mutation must complete before best-effort release.
        local deadline = os.clock() + 8
        while saving[player.UserId] and os.clock() < deadline do task.wait(0.1) end
        if profiles[player.UserId] then ProfileService.Save(player, true) end
    end)
    for _, player in Players:GetPlayers() do task.spawn(acquire, player) end
    task.spawn(function()
        while not closing do
            task.wait(60)
            for _, player in Players:GetPlayers() do
                if profiles[player.UserId] and not saving[player.UserId] then
                    if not ProfileService.Save(player, false) then
                        -- Disable further mutations when lease renewal cannot be proven.
                        profiles[player.UserId] = nil
                        player:Kick("Profile save unavailable. Reconnect later.")
                    end
                end
            end
        end
    end)
    game:BindToClose(function()
        closing = true
        for _, player in Players:GetPlayers() do
            local deadline = os.clock() + 8
            while saving[player.UserId] and os.clock() < deadline do task.wait(0.1) end
            if profiles[player.UserId] then ProfileService.Save(player, true) end
        end
    end)
end

return ProfileService
