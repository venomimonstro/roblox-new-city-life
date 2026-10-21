--!strict
-- One owned car active per account; garage holds multiple saved cars.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))
local Rules = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("GarageTransactions"))
local ParkingLayout = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("ParkingLayout"))
local PersonalGarage = {}

local active: {[number]: any} = {}
local slotByUser: {[number]: number} = {}
local working: {[number]: boolean} = {}

local function reserveSlot(userId: number): number?
    if slotByUser[userId] ~= nil then return slotByUser[userId] end
    for slot = 0, ParkingLayout.Capacity - 1 do
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

local function spawnSelected(player: Player): boolean
    if player.Parent ~= Players then return false end
    local data = ProfileService.Read(player)
    if not data or not data.garage[data.selectedVehicleId] then return false end
    local slot = reserveSlot(player.UserId)
    if slot == nil then
        warn("[StreetCity] Parking capacity exceeded (" .. tostring(ParkingLayout.Capacity) .. " slots)")
        return false
    end
    local existing = active[player.UserId]
    if existing and existing.Model.Parent then
        -- Reconfigure the parked chassis in-place. Spawning a second physical car
        -- at the same coordinates before deleting the old one causes collisions.
        if existing.Seat.Occupant
            or existing.Chassis.AssemblyLinearVelocity.Magnitude > 2 then return false end
        local build = data.garage[data.selectedVehicleId]
        existing.Model:SetAttribute("EngineId", build.engineId)
        existing.Model:SetAttribute("GearboxId", build.gearboxId)
        existing.Model:SetAttribute("TireId", build.tireId)
        existing.Model:SetAttribute("OwnedVehicleId", data.selectedVehicleId)
        return true
    end
    local spawnPosition = ParkingLayout.Position(slot)
    if not spawnPosition then return false end
    local car = VehicleService.SpawnForPlayer(player, data.garage[data.selectedVehicleId], spawnPosition)
    if not car then
        if not existing then slotByUser[player.UserId] = nil end
        return false
    end
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
    local safe, result = pcall(spawnSelected, player)
    working[id] = nil
    if not safe then
        warn("[StreetCity] Personal garage refresh failed: " .. tostring(result))
        return false
    end
    return result == true
end

local function createTerminal()
    local root = workspace:WaitForChild("StreetCityPrototypeWorld")
    local station = Instance.new("Part")
    station.Name = "PersonalGarageTerminal"
    station.Size = Vector3.new(5, 2, 5)
    station.Position = Vector3.new(17, 0, -61)
    station.Anchored = true
    station.CanCollide = false
    station.CanQuery = false
    station.CanTouch = false
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
        local safe, result = pcall(function()
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
                if not spawnSelected(player) then
                    warn("[StreetCity] Garage selection saved but active car not updated")
                end
            end
        end)
        working[player.UserId] = nil
        if not safe then
            warn("[StreetCity] Personal garage terminal failed: " .. tostring(result))
        end
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
