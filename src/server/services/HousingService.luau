--!strict
-- Shared physical homes per server; distinct active residences and respawns.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Layout = require(ReplicatedStorage.Shared:WaitForChild("HomeLayout"))
local Architecture = require(script.Parent:WaitForChild("CityArchitecture"))

local Housing = {}
local occupied: {[number]: number} = {}
local assigned: {[number]: number} = {}
local markers: {[number]: BasePart} = {}
local spawned: {[number]: number} = {}
local lastGarage: {[number]: number} = {}
local garageHandler: ((Player) -> ())? = nil
local respawnHandler: ((Player) -> ())? = nil

local function part(parent: Instance, name: string, size: Vector3, position: Vector3,
    color: Color3, canCollide: boolean): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.Position = position
    p.Anchored = true
    p.CanCollide = canCollide
    p.CanQuery = canCollide
    p.Color = color
    p.Material = Enum.Material.Concrete
    p.Parent = parent
    return p
end

function Housing.Assign(player: Player): number?
    local id = player.UserId
    if assigned[id] ~= nil then return assigned[id] end
    local preferred = Layout.Preferred(id)
    for shift = 0, Layout.Capacity - 1 do
        local slot = (preferred + shift) % Layout.Capacity
        if occupied[slot] == nil then
            occupied[slot] = id
            assigned[id] = slot
            local marker = markers[slot]
            if marker then marker:SetAttribute("OwnerUserId", id) end
            return slot
        end
    end
    warn("[StreetCity] No home plot available for player " .. tostring(id))
    if player.Parent == Players then
        player:Kick("This city server is full. Please join another server.")
    end
    return nil
end

function Housing.GetGarageSpawn(player: Player): any?
    local slot = Housing.Assign(player)
    local plot = slot and Layout.Plot(slot)
    if not plot then return nil end
    return {position = plot.car, heading = plot.heading, slot = slot}
end

function Housing.GetHomePosition(player: Player): Vector3?
    local slot = Housing.Assign(player)
    local plot = slot and Layout.Plot(slot)
    return if plot then plot.respawn else nil
end

function Housing.SetGarageHandler(callback: (Player) -> ())
    garageHandler = callback
end

function Housing.SetRespawnHandler(callback: (Player) -> ())
    respawnHandler = callback
end

local function relocate(player: Player, character: Model)
    local root = character:WaitForChild("HumanoidRootPart", 12)
    local human = character:FindFirstChildOfClass("Humanoid")
    if not root or not human or human.Health <= 0 then return end
    if player.Parent ~= Players or player.Character ~= character then return end
    local position = Housing.GetHomePosition(player)
    if not position then return end
    -- Wait for Roblox's own SpawnLocation positioning to settle first.
    task.wait(0.2)
    if player.Character ~= character or human.Health <= 0 then return end
    character:PivotTo(CFrame.new(position))
    local id = player.UserId
    spawned[id] = (spawned[id] or 0) + 1
    if spawned[id] > 1 and respawnHandler then
        task.delay(0.5, function()
            if player.Parent == Players then
                local ok, err = pcall(respawnHandler :: (Player) -> (), player)
                if not ok then warn("[StreetCity] Home respawn car recall failed: " .. tostring(err)) end
            end
        end)
    end
end

local function buildPlot(root: Instance, slot: number)
    local plot = Layout.Plot(slot)
    if not plot then return end
    local estate = Instance.new("Model")
    estate.Name = "Home_" .. tostring(slot + 1)
    estate:SetAttribute("HomeSlot", slot)
    estate.Parent = root
    local shade = if slot % 3 == 0 then Color3.fromRGB(174, 159, 140)
        elseif slot % 3 == 1 then Color3.fromRGB(133, 157, 170)
        else Color3.fromRGB(174, 161, 179)
    -- Preserve the canonical House anchor for property and safe services,
    -- but replace its solid cube with an accessible four-wall structure.
    local anchor = part(estate, "House", Vector3.new(13, 12, 16),
        plot.house + Vector3.new(0, 5, 0), shade, false)
    anchor.Transparency = 1
    anchor.CanQuery = false
    local facing = if slot < 24 then 1 else -1
    local wallMaterial = if slot % 3 == 0 then Enum.Material.Brick
        else Enum.Material.Plaster
    local floor = part(estate, "HouseFloor", Vector3.new(13.6, 0.3, 16.6),
        plot.house + Vector3.new(0, -0.78, 0),
        Color3.fromRGB(177, 156, 132), true)
    floor.Material = Enum.Material.WoodPlanks
    for _, side in {-1, 1} do
        local sideWall = part(estate, "HouseSideWall", Vector3.new(0.55, 11.5, 16.3),
            plot.house + Vector3.new(side * 6.5, 4.8, 0), shade, true)
        sideWall.Material = wallMaterial
        local frontWing = part(estate, "HouseFrontWing", Vector3.new(5.05, 11.5, 0.6),
            plot.house + Vector3.new(side * 4.0, 4.8, facing * 8.12),
            shade, true)
        frontWing.Material = wallMaterial
    end
    local rearWall = part(estate, "HouseBackWall", Vector3.new(13.4, 11.5, 0.6),
        plot.house + Vector3.new(0, 4.8, -facing * 8.12), shade, true)
    rearWall.Material = wallMaterial
    part(estate, "HouseDoorLintel", Vector3.new(2.95, 4.3, 0.62),
        plot.house + Vector3.new(0, 8.4, facing * 8.12), shade, true)
    -- Door trim is non-colliding. An actual walking passage now exists.

    part(estate, "Porch", Vector3.new(8, 0.5, 9),
        plot.house + Vector3.new(0, 0, if slot < 24 then 12 else -12),
        Color3.fromRGB(138, 125, 106), true)
    part(estate, "GarageFloor", Vector3.new(13, 0.5, 26),
        plot.garage + Vector3.new(0, -0.45, 0),
        Color3.fromRGB(75, 78, 81), true)
    part(estate, "GarageRoof", Vector3.new(14, 0.6, 27),
        plot.garage + Vector3.new(0, 12, 0),
        Color3.fromRGB(65, 69, 74), true)
    for _, x in {-6.7, 6.7} do
        part(estate, "GarageWall", Vector3.new(0.7, 11.5, 27),
            plot.garage + Vector3.new(x, 5.5, 0),
            Color3.fromRGB(116, 118, 118), true)
    end
    local sign = part(estate, "GarageTerminal", Vector3.new(2.5, 3, 2.5),
        plot.garage + Vector3.new(7.5, 1.5,
            if slot < 24 then 15 else -15),
        Color3.fromRGB(51, 156, 188), false)
    sign.Material = Enum.Material.Neon
    markers[slot] = sign
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "GaragePrompt"
    prompt.ActionText = "Return my car"
    prompt.ObjectText = "Home " .. tostring(slot + 1)
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = sign
    prompt.Triggered:Connect(function(player: Player)
        local id = player.UserId
        if assigned[id] ~= slot then return end
        local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 or human.SeatPart then return end
        if player:DistanceFromCharacter(sign.Position) > 13 then return end
        local now = os.clock()
        if now - (lastGarage[id] or 0) < 2.5 then return end
        lastGarage[id] = now
        if garageHandler then
            local ok, err = pcall(garageHandler :: (Player) -> (), player)
            if not ok then warn("[StreetCity] Home garage interaction failed: " .. tostring(err)) end
        end
    end)
    local door = Architecture.DecorateHome(estate, plot, slot)
    if door and door:IsA("BasePart") then
        local closed = door.CFrame
        local hinge = closed.Position - Vector3.new(door.Size.X / 2, 0, 0)
        local opened = CFrame.new(hinge)
            * CFrame.Angles(0, math.rad(if slot < 24 then 95 else -95), 0)
            * CFrame.new(door.Size.X / 2, 0, 0)
        local isOpen = false
        local moving = false
        local entry = Instance.new("ProximityPrompt")
        entry.Name = "FrontDoorPrompt"
        entry.ActionText = "Open home door"
        entry.ObjectText = "Residence " .. tostring(slot + 1)
        entry.RequiresLineOfSight = false
        entry.MaxActivationDistance = 10
        entry.Parent = door
        entry.Triggered:Connect(function(player: Player)
            if assigned[player.UserId] ~= slot or moving then return end
            local humanoid = player.Character
                and player.Character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart
                or player:DistanceFromCharacter(door.Position) > 12 then return end
            if isOpen then
                -- Never swing a solid door into the player standing in its arc.
                for _, other in Players:GetPlayers() do
                    local rootPart = other.Character
                        and other.Character:FindFirstChild("HumanoidRootPart")
                    if rootPart and rootPart:IsA("BasePart")
                        and (rootPart.Position - hinge).Magnitude < 5 then return end
                end
            end
            moving = true
            local opening = not isOpen
            if opening then
                door.CanCollide = false
                door.CanQuery = false
            end
            local tween = TweenService:Create(door,
                TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {CFrame = if opening then opened else closed})
            tween:Play()
            tween.Completed:Wait()
            if not opening then
                door.CanCollide = true
                door.CanQuery = true
            end
            isOpen = opening
            moving = false
            entry.ActionText = if isOpen then "Close home door" else "Open home door"
        end)
    end
end

function Housing.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    assert(world:FindFirstChild("ResidentialHomes") == nil, "Housing already started")
    local root = Instance.new("Folder")
    root.Name = "ResidentialHomes"
    root.Parent = world
    for slot = 0, Layout.Capacity - 1 do buildPlot(root, slot) end

    local function playerJoined(player: Player)
        Housing.Assign(player)
        player.CharacterAdded:Connect(function(character)
            task.spawn(relocate, player, character)
        end)
        if player.Character then task.spawn(relocate, player, player.Character) end
    end
    Players.PlayerAdded:Connect(playerJoined)
    for _, player in Players:GetPlayers() do playerJoined(player) end
    Players.PlayerRemoving:Connect(function(player)
        local id = player.UserId
        local slot = assigned[id]
        if slot ~= nil and occupied[slot] == id then
            occupied[slot] = nil
            if markers[slot] then markers[slot]:SetAttribute("OwnerUserId", nil) end
        end
        assigned[id] = nil
        spawned[id] = nil
        lastGarage[id] = nil
    end)
    print("[StreetCity] Residential plots ready: " .. tostring(Layout.Capacity))
end

return Housing
