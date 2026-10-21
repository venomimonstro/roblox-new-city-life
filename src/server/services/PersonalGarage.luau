--!strict
-- One owned car active per account; garage holds multiple saved cars.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))
local Rules = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("GarageTransactions"))
local PersonalGarage = {}

local active: {[number]: any} = {}
local slotByUser: {[number]: number} = {}
local working: {[number]: boolean} = {}

local function reserveSlot(userId: number): number?
    if slotByUser[userId] ~= nil then return slotByUser[userId] end
    for slot = 0, 47 do
        local used = false
        for _, existing in pairs(slotByUser) do
            if existing == slot then used = true break end
        end
        if not used then
            slotByUser[userId] = slot
            return slot
        end
    end
    return nil
end

local function positionFor(slot: number): Vector3
    -- 48 slots on the existing z=-200 / z=200 streets, away from race routes.
    local row = math.floor(slot / 24)
    local index = slot % 24
    local side = if index % 2 == 0 then 1 else -1
    local x = (math.floor(index / 2) + 1) * 18 * side
    return Vector3.new(x, 4, if row == 0 then -200 else 200)
end

local function spawnSelected(player: Player): boolean
    if player.Parent ~= Players then return false end
    local data = ProfileService.Read(player)
    if not data or not data.garage[data.selectedVehicleId] then return false end
    local slot = reserveSlot(player.UserId)
    if slot == nil then
        warn("[StreetCity] Parking capacity exceeded (48 slots)")
        return false
    end
    local existing = active[player.UserId]
    if existing and existing.Model.Parent and existing.Seat.Occupant then return false end
    -- Create before removing prior vehicle so failed creation does not remove it.
    local car = VehicleService.SpawnForPlayer(player, data.garage[data.selectedVehicleId], positionFor(slot))
    if not car then return false end
    car.Model:SetAttribute("OwnedVehicleId", data.selectedVehicleId)
    active[player.UserId] = car
    if existing then VehicleService.Despawn(existing) end
    return true
end

function PersonalGarage.GetActive(player: Player): any?
    return active[player.UserId]
end

function PersonalGarage.Refresh(player: Player): boolean
    local id = player.UserId
    if working[id] then return false end
    working[id] = true
    local ok = spawnSelected(player)
    working[id] = nil
    return ok
end

local function createTerminal()
    local root = workspace:WaitForChild("StreetCityPrototypeWorld")
    local station = Instance.new("Part")
    station.Name = "PersonalGarageTerminal"
    station.Size = Vector3.new(5, 2, 5)
    station.Position = Vector3.new(17, 0, -61)
    station.Anchored = true
    station.Material = Enum.Material.Neon
    station.Color = Color3.fromRGB(54, 116, 213)
    station.Parent = root

    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Select next owned car"
    prompt.ObjectText = "Personal Garage"
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = station
    prompt.Triggered:Connect(function(player: Player)
        local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 then return end
        if player:DistanceFromCharacter(station.Position) > 12 then return end
        local current = active[player.UserId]
        if current and (current.Seat.Occupant or current.Chassis.AssemblyLinearVelocity.Magnitude > 2) then return end
        if working[player.UserId] or not ProfileService.IsLoaded(player) then return end
        working[player.UserId] = true
        local selected = ProfileService.Mutate(player, function(profile)
            local ids = {}
            for id in pairs(profile.garage) do table.insert(ids, id) end
            table.sort(ids)
            if #ids < 2 then return false end
            local index = table.find(ids, profile.selectedVehicleId)
            if not index then return false end
            return Rules.SelectVehicle(profile, ids[index % #ids + 1])
        end)
        if selected and player.Parent == Players then
            spawnSelected(player)
        end
        working[player.UserId] = nil
    end)
end

function PersonalGarage.Start()
    if RunService:IsStudio() and game.GameId == 0 then
        warn("[StreetCity] Personal garage uses ephemeral Studio profile; no progress saved")
    end
    createTerminal()
    local function awaitProfile(player: Player)
        task.spawn(function()
            for _ = 1, 100 do
                if player.Parent ~= Players then return end
                if ProfileService.IsLoaded(player) then
                    PersonalGarage.Refresh(player)
                    return
                end
                task.wait(0.5)
            end
        end)
    end
    Players.PlayerAdded:Connect(awaitProfile)
    for _, player in Players:GetPlayers() do awaitProfile(player) end
    Players.PlayerRemoving:Connect(function(player)
        local id = player.UserId
        local car = active[id]
        active[id] = nil
        slotByUser[id] = nil
        working[id] = nil
        if car then VehicleService.Despawn(car) end
    end)
end

return PersonalGarage
