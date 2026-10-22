--!strict
-- Underground train corridor and economical public transit. The carriages are
-- animated displays; riders use server-authorized scheduled station transfers.
-- Transit never trusts a client-provided destination or price.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Wallet = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Map = require(ReplicatedStorage.Shared:WaitForChild("TransitMap"))
local Transit = {}
local pending: {[number]: boolean} = {}
local notice: RemoteEvent

local function create(parent: Instance, name: string, pos: Vector3,
    size: Vector3, color: Color3, solid: boolean): Part
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.CanCollide = solid
    p.CanQuery = solid
    p.CanTouch = false
    p.Size = size
    p.Position = pos
    p.Color = color
    p.Material = Enum.Material.Concrete
    p.Parent = parent
    return p
end

local function rootOf(player: Player): (Humanoid?, BasePart?)
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0
        or humanoid.SeatPart then return nil, nil end
    return humanoid, root
end

local function message(player: Player, msg: string)
    if player.Parent == Players then notice:FireClient(player, msg) end
end

-- Verify physical station arrival before collecting any fare, and verify
-- again after a delayed departure. Never rely on an untrusted client position.
local function safeArrival(destination: Vector3, character: Model?): Vector3?
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    local excluded = {}
    if character then table.insert(excluded, character) end
    local vehicles = workspace:FindFirstChild("ActiveVehicles")
    if vehicles then table.insert(excluded, vehicles) end
    ray.FilterDescendantsInstances = excluded
    ray.IgnoreWater = true
    local hit = workspace:Raycast(destination + Vector3.new(0, 7, 0),
        Vector3.new(0, -18, 0), ray)
    if not hit or not hit.Instance.CanCollide
        or hit.Normal.Y < 0.78
        or math.abs(hit.Position.Y - destination.Y) > 7 then return nil end
    return hit.Position + Vector3.new(0, 3.5, 0)
end

local function ride(player: Player, origin: Vector3, destination: Vector3,
    fare: number, waitSeconds: number, title: string)
    if pending[player.UserId] or player.Parent ~= Players
        or not Profile.IsLoaded(player) then return end
    local human, root = rootOf(player)
    if not human or not root or (root.Position - origin).Magnitude > 14 then return end
    local character = player.Character
    if not safeArrival(destination, character) then
        message(player, "Destination station is unsafe. No ticket was charged.")
        warn("[StreetCity Transit] Station floor preflight failed: " .. tostring(destination))
        return
    end
    pending[player.UserId] = true
    local operation = "transit_" .. HttpService:GenerateGUID(false):gsub("-", "")
    local refundOperation = "refund_" .. operation
    local charged = Profile.Mutate(player, function(profile)
        return Wallet.SpendCredits(profile, fare, operation)
    end)
    if not charged then
        pending[player.UserId] = nil
        message(player, "Fare declined or transaction uncertain; check your wallet")
        return
    end
    local function refund(reason: string)
        -- Refund is a separate idempotent transaction. Repeated callbacks use
        -- the SAME ID; never mint multiple refunds for a single ticket.
        local refunded = false
        if player.Parent == Players and Profile.IsLoaded(player) then
            refunded = Profile.Mutate(player, function(profile)
                return Wallet.AwardCredits(profile, fare, refundOperation)
            end)
        end
        if refunded then
            message(player, reason .. " The ticket was refunded.")
        else
            message(player, reason .. " Refund not confirmed; check your wallet.")
            warn("[StreetCity Transit] Ticket refund unconfirmed for " .. tostring(player.UserId)
                .. " (" .. operation .. ")")
        end
    end
    message(player, title .. " ticket purchased. Departure in "
        .. tostring(waitSeconds) .. " seconds.")
    task.delay(waitSeconds, function()
        local ok, err = pcall(function()
            if player.Parent ~= Players then return end
            if player.Character ~= character then
                refund("Departure cancelled by character respawn.")
                return
            end
            local h, r = rootOf(player)
            if not h or not r then
                refund("Departure cancelled because the character cannot travel.")
                return
            end
            local landing = safeArrival(destination, character)
            if not landing then
                refund("Destination station became unsafe.")
                return
            end
            character:PivotTo(CFrame.new(landing))
            message(player, title .. ": arrived")
        end)
        if not ok then
            warn("[StreetCity Transit] Transfer failed: " .. tostring(err))
            refund("Transit transfer failed.")
        end
        pending[player.UserId] = nil
    end)
end

local function prompt(part: Part, label: string, action: string,
    callback: (Player) -> ())
    local p = Instance.new("ProximityPrompt")
    p.ObjectText = label
    p.ActionText = action
    p.RequiresLineOfSight = false
    p.MaxActivationDistance = 10
    p.Parent = part
    p.Triggered:Connect(function(player)
        local ok, err = pcall(callback, player)
        if not ok then
            warn("[StreetCity Transit] Action failed: " .. tostring(err))
            message(player, "Transit unavailable, please try a different station")
        end
    end)
end

local function metro(root: Instance)
    local corridor = Instance.new("Folder")
    corridor.Name = "UndergroundLine"
    corridor.Parent = root
    local depth = Map.MetroDepth
    local line = create(corridor, "MetroTunnelFloor",
        Vector3.new(0, depth - 3, 0), Vector3.new(2240, 2, 26),
        Color3.fromRGB(53, 59, 65), true)
    line.Material = Enum.Material.Slate
    create(corridor, "LeftTunnelWall", Vector3.new(0, depth + 6, -13),
        Vector3.new(2240, 19, 1), Color3.fromRGB(70, 73, 80), true)
    create(corridor, "RightTunnelWall", Vector3.new(0, depth + 6, 13),
        Vector3.new(2240, 19, 1), Color3.fromRGB(70, 73, 80), true)
    create(corridor, "TunnelCeiling", Vector3.new(0, depth + 15, 0),
        Vector3.new(2240, 2, 27), Color3.fromRGB(52, 55, 61), true)
    for _, sign in {-1, 1} do
        create(corridor, "Track_" .. sign, Vector3.new(0, depth - 1.4, sign * 2),
            Vector3.new(2220, 0.4, 0.6), Color3.fromRGB(149, 151, 157), true)
    end
    for index, station in Map.Metro do
        local platform = create(corridor, "Platform_" .. station.id,
            Vector3.new(station.x, depth - 0.8, 9),
            Vector3.new(70, 1.3, 8), Color3.fromRGB(112, 118, 128), true)
        platform:SetAttribute("Station", station.id)
        -- Player-accessible street entrance, with automatic direct platform
        -- access. No underground teleport is used as a valid driving shortcut.
        local entrance = create(root, "MetroEntrance_" .. station.id,
            Vector3.new(station.x + 15, 2, 36),
            Vector3.new(6, 3, 6), Color3.fromRGB(78, 125, 188), false)
        local nextIndex = index % #Map.Metro + 1
        local destination = Map.Metro[nextIndex]
        local platformAccess = create(corridor, "PlatformAccess_" .. station.id,
            Vector3.new(station.x + 15, depth + 2, 9),
            Vector3.new(4, 3, 4), Color3.fromRGB(85, 172, 180), false)
        prompt(entrance, "Metro: " .. station.label,
            "Enter underground station", function(player)
                local human, rootPart = rootOf(player)
                if not human or not rootPart
                    or (rootPart.Position - entrance.Position).Magnitude > 14 then return end
                -- Surface -> station platforms does not charge a ticket.
                player.Character:PivotTo(CFrame.new(platformAccess.Position
                    + Vector3.new(0, 3, 0)))
            end)
        prompt(platformAccess, "Metro: " .. station.label,
            "Ride to " .. destination.label .. " (40 credits)", function(player)
                ride(player, platformAccess.Position,
                    Vector3.new(destination.x + 15, depth + 2, 9), 40, 12, "Metro")
            end)
        local stairs = create(corridor, "MetroExit_" .. station.id,
            Vector3.new(station.x - 14, depth + 2, 9),
            Vector3.new(4, 3, 4), Color3.fromRGB(69, 167, 105), false)
        prompt(stairs, station.label, "Exit to street", function(player)
            local human, rootPart = rootOf(player)
            if not human or not rootPart or pending[player.UserId]
                or (rootPart.Position - stairs.Position).Magnitude > 14 then return end
            -- Exit next to entrance, always on the road-side pavement.
            player.Character:PivotTo(CFrame.new(entrance.Position
                + Vector3.new(7, 2, 0)))
        end)
    end
    local train = Instance.new("Model")
    train.Name = "MetroTrain"
    train:SetAttribute("NPCPassengers", 11)
    train.Parent = corridor
    local carriage = create(train, "Carriage", Vector3.new(-1000, depth + 2, 0),
        Vector3.new(32, 5, 7), Color3.fromRGB(159, 180, 198), false)
    train.PrimaryPart = carriage
    for offset = -1, 1 do
        local window = create(train, "Window_" .. offset,
            carriage.Position + Vector3.new(offset * 8, 1, -3.6),
            Vector3.new(5, 1.4, 0.15), Color3.fromRGB(66, 133, 173), false)
        window.Material = Enum.Material.Glass
    end
    local t = 0
    local acc = 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.1 then return end
        local step = math.min(acc, 0.3)
        acc = 0
        t = (t + step / 140) % 2
        local progress = if t <= 1 then t else 2 - t
        train:PivotTo(CFrame.new(-1000 + progress * 2000, depth + 2, 0))
    end)
end

local function bus(root: Instance)
    for i, stop in Map.Bus do
        local pad = create(root, "BusStop_" .. stop.id,
            stop.pos + Vector3.new(19, 0, 26),
            Vector3.new(5, 3, 5), Color3.fromRGB(213, 169, 78), false)
        local destination = Map.Bus[i % #Map.Bus + 1]
        prompt(pad, "Bus: " .. stop.label,
            "Route to " .. destination.label .. " (25 credits)", function(player)
                ride(player, pad.Position,
                    destination.pos + Vector3.new(19, 0, 26), 25, 9, "City bus")
            end)
    end
    -- Display vehicle operates on an ultra-cheap fixed loop and never owns
    -- authoritative driver physics. Visible but not stealable as it has no seat.
    local busModel = Instance.new("Model")
    busModel.Name = "CityBusNPC"
    busModel:SetAttribute("NPCPassengers", 7)
    busModel.Parent = root
    local body = create(busModel, "BusBody", Vector3.new(0, 4, 100),
        Vector3.new(8, 5, 20), Color3.fromRGB(225, 175, 75), false)
    busModel.PrimaryPart = body
    local route = {
        Vector3.new(-800, 4, 100), Vector3.new(-800, 4, -300),
        Vector3.new(0, 4, -300), Vector3.new(0, 4, 100),
    }
    local leg, progress, acc = 1, 0, 0
    RunService.Heartbeat:Connect(function(dt)
        acc += dt
        if acc < 0.1 then return end
        local step = math.min(acc, 0.3)
        acc = 0
        local a = route[leg]
        local b = route[leg % #route + 1]
        local length = (b - a).Magnitude
        progress += step * 20 / length
        if progress >= 1 then
            progress = 0
            leg = leg % #route + 1
            return
        end
        local target = a:Lerp(b, progress)
        busModel:PivotTo(CFrame.lookAt(target, target + (b - a)))
    end)
end

function Transit.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local root = Instance.new("Folder")
    root.Name = "PublicTransit"
    root.Parent = world
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    metro(root)
    bus(root)
    Players.PlayerRemoving:Connect(function(player)
        pending[player.UserId] = nil
    end)
    print("[StreetCity] Transit ready: 3 metro stations, 5 bus stops and 2 animated vehicles")
end

return Transit
