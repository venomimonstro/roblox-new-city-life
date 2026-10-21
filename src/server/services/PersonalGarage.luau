--!strict
-- One owned car active per account; garage holds multiple saved cars.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))
local VehicleFactory = require(script.Parent:WaitForChild("VehicleFactory"))
local Rules = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("GarageTransactions"))
local ParkingLayout = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("ParkingLayout"))
local Housing = require(script.Parent:WaitForChild("HousingService"))
local PersonalGarage = {}

local active: {[number]: any} = {}
local slotByUser: {[number]: number} = {}
local working: {[number]: boolean} = {}
local locateCooldown: {[number]: number} = {}
local pendingSync: {[number]: boolean} = {}

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
    local home = Housing.GetGarageSpawn(player)
    if not home then
        warn("[StreetCity] Residential garage not available for " .. tostring(player.UserId))
        return false
    end
    local existing = active[player.UserId]
    if existing and existing.Model.Parent then
        -- Reconfigure the parked chassis in-place. Spawning a second physical car
        -- at the same coordinates before deleting the old one causes collisions.
        if existing.Seat.Occupant
            or existing.Chassis.AssemblyLinearVelocity.Magnitude > 2 then return false end
        local build = data.garage[data.selectedVehicleId]
        VehicleFactory.ApplyCatalog(existing, build.catalogId)
        existing.Model:SetAttribute("EngineId", build.engineId)
        existing.Model:SetAttribute("GearboxId", build.gearboxId)
        existing.Model:SetAttribute("TireId", build.tireId)
        existing.Model:SetAttribute("OwnedVehicleId", data.selectedVehicleId)
        return true
    end
    local car = VehicleService.SpawnForPlayer(
        player, data.garage[data.selectedVehicleId], home.position, home.heading
    )
    if not car then
        return false
    end
    car.Model:SetAttribute("OwnedVehicleId", data.selectedVehicleId)
    active[player.UserId] = car
    if existing then VehicleService.Despawn(existing) end
    return true
end

function PersonalGarage.ReturnOnRespawn(player: Player)
    local id = player.UserId
    local car = active[id]
    if car and car.Model.Parent then
        local occupant = car.Seat.Occupant
        local seatedPlayer = occupant and game:GetService("Players"):GetPlayerFromCharacter(occupant.Parent)
        if occupant and seatedPlayer ~= player then return end
        if occupant then occupant.Sit = false end
        car.Chassis.AssemblyLinearVelocity = Vector3.zero
        car.Chassis.AssemblyAngularVelocity = Vector3.zero
        -- On death we intentionally recall an abandoned owned car, even if it
        -- would otherwise still be moving elsewhere in the world.
    end
    if not car or not car.Model.Parent then
        PersonalGarage.Refresh(player)
    else
        PersonalGarage.Recall(player)
    end
end

-- Server-side recovery for cars that fell through the map or were left far
-- from the onboarding area. It never recalls a car with a seated occupant.
function PersonalGarage.Recall(player: Player): boolean
    if not ProfileService.IsLoaded(player) then return false end
    local id = player.UserId
    local car = active[id]
    if not car or not car.Model.Parent then return PersonalGarage.Refresh(player) end
    if car.Model:GetAttribute("OwnerUserId") ~= id or car.Seat.Occupant then return false end
    local lostBelowWorld = car.Chassis.Position.Y < -10
    if not lostBelowWorld and car.Chassis.AssemblyLinearVelocity.Magnitude > 3 then
        return false
    end
    local home = Housing.GetGarageSpawn(player)
    local pos = home and home.position
    if not pos then return false end
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.FilterDescendantsInstances = {car.Model}
    ray.IgnoreWater = true
    local ground = workspace:Raycast(pos + Vector3.new(0, 15, 0), Vector3.new(0, -45, 0), ray)
    if not ground or not ground.Instance.CanCollide or ground.Normal.Y < 0.72 then
        return false
    end
    local parked = ground.Position + Vector3.new(0, 4.2, 0)
    car.Model:PivotTo(CFrame.new(parked) * CFrame.Angles(0, home.heading, 0))
    car.Chassis.AssemblyLinearVelocity = Vector3.zero
    car.Chassis.AssemblyAngularVelocity = Vector3.zero
    PersonalGarage.EnsureSynced(player)
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

-- Retry a persisted selection/tune after the player parks and exits.
-- A concurrent seat transition must not make the saved car permanently stale.
function PersonalGarage.EnsureSynced(player: Player)
    local id = player.UserId
    if pendingSync[id] then return end
    pendingSync[id] = true
    task.spawn(function()
        for _ = 1, 40 do
            if player.Parent ~= Players or not ProfileService.IsLoaded(player) then break end
            local profile = ProfileService.Read(player)
            local car = active[id]
            if not profile then break end
            local selected = profile.garage[profile.selectedVehicleId]
            if not selected then break end
            if car and car.Model.Parent
                and car.Model:GetAttribute("OwnedVehicleId") == profile.selectedVehicleId
                and car.Model:GetAttribute("EngineId") == selected.engineId
                and car.Model:GetAttribute("GearboxId") == selected.gearboxId
                and car.Model:GetAttribute("TireId") == selected.tireId then
                break
            end
            if not working[id] and PersonalGarage.Refresh(player) then break end
            task.wait(0.5)
        end
        pendingSync[id] = nil
    end)
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
                    warn("[StreetCity] Garage selection saved; deferred car sync until parked")
                end
                PersonalGarage.EnsureSynced(player)
            end
        end)
        working[player.UserId] = nil
        if not safe then
            warn("[StreetCity] Personal garage terminal failed: " .. tostring(result))
        end
    end)
end

local function createCarLocator()
    local root = workspace:WaitForChild("StreetCityPrototypeWorld")
    local stand = Instance.new("Part")
    stand.Name = "FindMyCarTerminal"
    stand.Size = Vector3.new(5, 2, 5)
    stand.Position = Vector3.new(17, 0.1, 7)
    stand.Anchored = true
    stand.CanCollide = false
    stand.CanQuery = false
    stand.Material = Enum.Material.Neon
    stand.Color = Color3.fromRGB(28, 180, 166)
    stand.Parent = root
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = "My vehicle"
    prompt.ActionText = "Find my car"
    prompt.MaxActivationDistance = 13
    prompt.RequiresLineOfSight = false
    prompt.Parent = stand
    prompt.Triggered:Connect(function(player: Player)
        local now = os.clock()
        local id = player.UserId
        if now - (locateCooldown[id] or 0) < 3 then return end
        local character = player.Character
        local human = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not human or human.Health <= 0 or human.SeatPart or not rootPart then return end
        if player:DistanceFromCharacter(stand.Position) > 16 then return end
        if not ProfileService.IsLoaded(player) then return end
        locateCooldown[id] = now
        local car = active[id]
        if not car or not car.Model.Parent or car.Chassis.Position.Y < -10 then
            if not PersonalGarage.Recall(player) then return end
            car = active[id]
        end
        if not car or not car.Model.Parent
            or car.Model:GetAttribute("OwnerUserId") ~= id then return end
        if car.Seat.Occupant or car.Chassis.AssemblyLinearVelocity.Magnitude > 3 then return end
        -- A fixed offset from the server-owned chassis cannot be trusted as
        -- safe floor: the car may have fallen from the road or parked on a ledge.
        local intended = car.Chassis.Position + Vector3.new(0, 0, 8)
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances = {car.Model, character}
        ray.IgnoreWater = true
        local ground = workspace:Raycast(intended + Vector3.new(0, 12, 0),
            Vector3.new(0, -55, 0), ray)
        if not ground or not ground.Instance.CanCollide
            or ground.Normal.Y < 0.72 then return end
        local landing = ground.Position + Vector3.new(0, 3.5, 0)
        character:PivotTo(CFrame.new(landing))
    end)
end

function PersonalGarage.Start()
    if RunService:IsStudio() and game.GameId == 0 then
        warn("[StreetCity] Personal garage uses ephemeral Studio profile; no progress saved")
    end
    Housing.SetGarageHandler(function(player)
        PersonalGarage.Recall(player)
        PersonalGarage.EnsureSynced(player)
    end)
    Housing.SetRespawnHandler(function(player)
        -- Return the player's OWN property on death/respawn. Abandoned cars
        -- must not permanently deprive the account of its paid vehicle.
        PersonalGarage.ReturnOnRespawn(player)
    end)
    createTerminal()
    createCarLocator()
    local function awaitProfile(player: Player)
        task.spawn(function()
            -- DataStore acquisition can exceed the former fixed 50-second poll
            -- window. Keep waiting until this player leaves or the profile loads.
            while player.Parent == Players do
                if ProfileService.IsLoaded(player) then
                    if PersonalGarage.Refresh(player) then return end
                end
                task.wait(2)
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
        pendingSync[id] = nil
        if car then VehicleService.Despawn(car) end
    end)
end

return PersonalGarage
