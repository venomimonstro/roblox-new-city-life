--!strict
-- Contestable influence points (server-session scope). Influence changes arise
-- from explicit player presence and persisted alignment, not client-side scores.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Territory = {}
local cooldown: {[string]: number} = {}
local controls: {[string]: BasePart} = {}
local colors = {
    law = Color3.fromRGB(60, 137, 210),
    outlaw = Color3.fromRGB(189, 65, 93),
    contested = Color3.fromRGB(204, 177, 73),
}

local function ownership(state: any): string
    if state.lawInfluence >= state.outlawInfluence + 20 then return "law" end
    if state.outlawInfluence >= state.lawInfluence + 20 then return "outlaw" end
    return "contested"
end

function Territory.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local root = Instance.new("Folder")
    root.Name = "TerritoryControl"
    root.Parent = world
    for _, district in Districts do
        local pos = Vector3.new(math.floor(district.x / 100) * 100 + 65, 1.5,
            math.floor(district.z / 100) * 100 + 65)
        local p = Instance.new("Part")
        p.Name = "Territory_" .. district.id
        p.Anchored = true
        p.CanCollide = false
        p.CanTouch = false
        p.CanQuery = false
        p.Size = Vector3.new(8, 2, 8)
        p.Position = pos
        p.Material = Enum.Material.Neon
        p.Parent = root
        controls[district.id] = p
        local sign = Instance.new("BillboardGui")
        sign.Name = "OwnershipBillboard"
        sign.Size = UDim2.fromOffset(180, 54)
        sign.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
        sign.AlwaysOnTop = true
        sign.Parent = p
        local label = Instance.new("TextLabel")
        label.Name = "Text"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 0.3
        label.BackgroundColor3 = Color3.fromRGB(20, 25, 36)
        label.TextScaled = true
        label.TextColor3 = Color3.fromRGB(244, 245, 245)
        label.Parent = sign
        local prompt = Instance.new("ProximityPrompt")
        prompt.ObjectText = "District " .. district.id
        prompt.ActionText = "Defend / claim influence"
        prompt.HoldDuration = 3
        prompt.MaxActivationDistance = 11
        prompt.RequiresLineOfSight = false
        prompt.Parent = p
        local function render()
            local state = Society.GetState(district.id)
            if not state then return end
            local controller = ownership(state)
            label.Text = district.id .. "\n" .. controller .. " control"
            p:SetAttribute("Control", controller)
            p:SetAttribute("LawInfluence", state.lawInfluence)
            p:SetAttribute("OutlawInfluence", state.outlawInfluence)
            p.Color = colors[controller]
        end
        render()
        Society.Changed():Connect(function(changed: string)
            if changed == district.id then render() end
        end)
        prompt.Triggered:Connect(function(player: Player)
            local char = player.Character
            local human = char and char:FindFirstChildOfClass("Humanoid")
            if not human or human.Health <= 0 or human.SeatPart
                or player:DistanceFromCharacter(pos) > 14 then return end
            local profile = Profile.Read(player)
            if not profile then return end
            local side = profile.allegiance
            if side ~= "law" and side ~= "outlaw" then return end
            local key = tostring(player.UserId) .. ":" .. district.id
            local now = os.clock()
            if now - (cooldown[key] or 0) < 60 then return end
            cooldown[key] = now
            Society.ApplyAt(pos, if side == "law" then "security" else "crime", 2)
        end)
    end
    Players.PlayerRemoving:Connect(function(player)
        local prefix = tostring(player.UserId) .. ":"
        for key in pairs(cooldown) do
            if string.sub(key, 1, #prefix) == prefix then cooldown[key] = nil end
        end
    end)
    print("[StreetCity] Seven contested law/outlaw influence territories active")
end

return Territory
