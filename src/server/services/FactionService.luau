--!strict
-- Server-session crews, faction choice and NPC bodyguards. These groups do
-- not persist across servers yet; this prevents ghost memberships on reconnect.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Wanted = require(script.Parent:WaitForChild("WantedService"))
local Factions = {}
local sideByPlayer: {[number]: string} = {}
local crews: {[number]: any} = {}
local crewFor: {[number]: number} = {}
local allies: {[number]: any} = {}
local cooldown: {[number]: number} = {}
local notice: RemoteEvent

local function send(player: Player, message: string)
    if player.Parent == Players then notice:FireClient(player, message) end
end

local function root(player: Player): BasePart?
    local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local part = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return if human and human.Health > 0 and part and part:IsA("BasePart")
        then part else nil
end

local function station(parent: Instance, name: string, position: Vector3,
    action: string, cb: (Player) -> ())
    local p = Instance.new("Part")
    p.Name = name
    p.Size = Vector3.new(5, 2, 5)
    p.Position = position
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(106, 112, 168)
    p.Parent = parent
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = action
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = p
    prompt.Triggered:Connect(function(player)
        local pos = root(player)
        if not pos or (pos.Position - p.Position).Magnitude > 13
            or not Profile.IsLoaded(player) then return end
        local id = player.UserId
        if os.clock() - (cooldown[id] or 0) < 2 then return end
        cooldown[id] = os.clock()
        local ok, err = pcall(cb, player)
        if not ok then warn("[StreetCity] Faction action error: " .. tostring(err)) end
    end)
end

local function choose(player: Player, side: string)
    if crewFor[player.UserId] then
        send(player, "Leave your current crew before switching sides")
        return
    end
    sideByPlayer[player.UserId] = side
    player:SetAttribute("CityFaction", side)
    send(player, "Faction selected: " .. side)
end

local function form(player: Player)
    local id = player.UserId
    local side = sideByPlayer[id] or "civilian"
    if side == "civilian" then
        send(player, "Choose Federal or Outlaw before forming a crew")
        return
    end
    if crewFor[id] then
        send(player, "Already part of a crew")
        return
    end
    crews[id] = {leader = id, side = side, members = {[id] = true}}
    crewFor[id] = id
    player:SetAttribute("CityCrewLeader", id)
    send(player, "Created your " .. side .. " crew. Invite nearby teammates.")
end

local function joinNearby(player: Player)
    if crewFor[player.UserId] then return end
    local rp = root(player)
    if not rp then return end
    local nearest: Player? = nil
    local distance = 30
    for _, target in Players:GetPlayers() do
        local team = crews[target.UserId]
        if team and team.leader == target.UserId then
            local p = root(target)
            if p and (p.Position - rp.Position).Magnitude < distance then
                distance = (p.Position - rp.Position).Magnitude
                nearest = target
            end
        end
    end
    if not nearest then
        send(player, "No nearby crew leader. Find a leader in the same district.")
        return
    end
    local crew = crews[nearest.UserId]
    local count = 0
    for _ in pairs(crew.members) do count += 1 end
    if count >= 8 then
        send(player, "This crew is full")
        return
    end
    if sideByPlayer[player.UserId] ~= crew.side then
        send(player, "Both players must belong to the same faction")
        return
    end
    crew.members[player.UserId] = true
    crewFor[player.UserId] = nearest.UserId
    player:SetAttribute("CityCrewLeader", nearest.UserId)
    send(player, "Joined " .. nearest.DisplayName .. "'s " .. crew.side .. " crew")
end

local function helperModel(player: Player, side: string): Model?
    local rp = root(player)
    if not rp then return nil end
    local m = Instance.new("Model")
    m.Name = if side == "federal" then "HiredBodyguard" else "HiredOutlaw"
    m:SetAttribute("OwnerUserId", player.UserId)
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(1.5, 2.4, 0.85)
    torso.Anchored = true
    torso.CanCollide = false
    torso.CanQuery = false
    torso.CanTouch = false
    torso.Color = if side == "federal" then Color3.fromRGB(65, 93, 142)
        else Color3.fromRGB(131, 76, 82)
    torso.Position = rp.Position + Vector3.new(4, 0, 3)
    torso.Parent = m
    m.PrimaryPart = torso
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(0.85, 0.85, 0.85)
    head.Shape = Enum.PartType.Ball
    head.Anchored = true
    head.CanCollide = false
    head.CanQuery = false
    head.CanTouch = false
    head.Position = torso.Position + Vector3.new(0, 1.8, 0)
    head.Color = Color3.fromRGB(185, 142, 111)
    head.Parent = m
    m.Parent = workspace:WaitForChild("StreetCityPrototypeWorld")
        :WaitForChild("CityFactionAllies")
    return m
end

local function hire(player: Player)
    local side = sideByPlayer[player.UserId] or "civilian"
    if side == "civilian" then
        send(player, "Choose a side to recruit an NPC ally")
        return
    end
    local existing = allies[player.UserId]
    if existing and existing.model.Parent and os.clock() < existing.expires then
        send(player, "You already have an active NPC ally")
        return
    end
    local operation = "guard_" .. HttpService:GenerateGUID(false):gsub("-", "")
    local paid = Profile.Mutate(player, function(profile)
        return Rules.SpendCredits(profile, 650, operation)
    end)
    if not paid then
        send(player, "An ally costs 650 cash; verify wallet")
        return
    end
    local model = helperModel(player, side)
    if not model then
        -- The credit spend is confirmed, so don't pretend it was rolled back.
        send(player, "Ally delayed. Contact support if this persists.")
        return
    end
    if existing and existing.model then existing.model:Destroy() end
    allies[player.UserId] = {
        model = model, side = side, expires = os.clock() + 480,
        lastEffect = os.clock(),
    }
    send(player, "NPC ally hired for 8 minutes. They influence local security.")
end

local function civic(player: Player, kind: string)
    local amount = if kind == "security" then 850 else 550
    local operation = "civic_" .. HttpService:GenerateGUID(false):gsub("-", "")
    local paid = Profile.Mutate(player, function(profile)
        return Rules.SpendCredits(profile, amount, operation)
    end)
    if paid then
        Society.EffectForPlayer(player, kind, 4)
        send(player, "Your actions changed district influence and public wellbeing")
    else
        send(player, "Not enough cash to fund this action")
    end
end

function Factions.Start()
    local folder = Instance.new("Folder")
    folder.Name = "CityFactionAllies"
    folder.Parent = workspace:WaitForChild("StreetCityPrototypeWorld")
    local rootFolder = Instance.new("Folder")
    rootFolder.Name = "FactionRegistry"
    rootFolder.Parent = folder.Parent
    station(rootFolder, "ChooseFederal", Vector3.new(70, 2, 70),
        "Join Federal", function(player) choose(player, "federal") end)
    station(rootFolder, "ChooseOutlaw", Vector3.new(-70, 2, 70),
        "Join Outlaw", function(player) choose(player, "outlaw") end)
    station(rootFolder, "ChooseCivilian", Vector3.new(0, 2, 70),
        "Live as civilian", function(player) choose(player, "civilian") end)
    station(rootFolder, "CreateCrew", Vector3.new(25, 2, 70),
        "Form crew", form)
    station(rootFolder, "JoinNearbyCrew", Vector3.new(-25, 2, 70),
        "Join nearby crew", joinNearby)
    station(rootFolder, "HireFollower", Vector3.new(90, 2, 70),
        "Hire allied NPC — 650", hire)
    station(rootFolder, "SponsorPolice", Vector3.new(105, 2, 70),
        "Sponsor district police — 850", function(player) civic(player, "security") end)
    station(rootFolder, "SupportLocalBusiness", Vector3.new(-105, 2, 70),
        "Sponsor local economy — 550", function(player) civic(player, "business") end)

    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < 0.4 then return end
        local step = math.min(accumulator, 0.5)
        accumulator = 0
        local now = os.clock()
        for id, ally in pairs(allies) do
            local player = Players:GetPlayerByUserId(id)
            local rp = player and root(player)
            if not player or not rp or not ally.model.Parent or now >= ally.expires then
                if ally.model then ally.model:Destroy() end
                allies[id] = nil
            else
                if ally.side == "outlaw" and Wanted.GetLevel(player) >= 4 then
                    -- A high-profile gang associate can be arrested by patrols.
                    if now - ally.lastEffect > 60 then
                        ally.model:Destroy()
                        allies[id] = nil
                        send(player, "Your gang associate was arrested")
                    end
                else
                    local target = rp.Position + rp.CFrame.RightVector * 4 - rp.CFrame.LookVector * 5
                    local current = ally.model:GetPivot().Position
                    local delta = target - current
                    if delta.Magnitude > 1 then
                        local nextPos = current + delta.Unit * math.min(delta.Magnitude, step * 18)
                        ally.model:PivotTo(CFrame.new(nextPos))
                    end
                    if now - ally.lastEffect >= 65 then
                        ally.lastEffect = now
                        Society.EffectForPlayer(player, if ally.side == "federal" then "security" else "crime", 1)
                    end
                end
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        local id = player.UserId
        local leader = crewFor[id]
        if leader and crews[leader] then
            crews[leader].members[id] = nil
            if leader == id then
                for member in pairs(crews[leader].members) do
                    crewFor[member] = nil
                    local user = Players:GetPlayerByUserId(member)
                    if user then user:SetAttribute("CityCrewLeader", nil) end
                end
                crews[leader] = nil
            end
        end
        crewFor[id] = nil
        sideByPlayer[id] = nil
        cooldown[id] = nil
        if allies[id] then
            allies[id].model:Destroy()
            allies[id] = nil
        end
    end)
    print("[StreetCity] Federal/outlaw factions, player crews and hired allies ready")
end

return Factions
