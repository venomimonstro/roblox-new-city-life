--!strict
-- Local road-grid minimap: no server remote, no terrain scan and no image assets.
-- A readable city map even when streamed 3D neighborhoods have not loaded.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Districts = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DistrictConfig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "StreetCityMapAndQuality"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 9
gui.Parent = player:WaitForChild("PlayerGui")

local touch = UserInputService.TouchEnabled
local size = if touch then 136 else 178
local panel = Instance.new("Frame")
panel.Name = "CityMinimap"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -12, 0, if touch then 155 else 198)
panel.Size = UDim2.fromOffset(size + 12, size + 52)
panel.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
panel.BackgroundTransparency = 0.09
panel.Parent = gui
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 12)
round.Parent = panel

local field = Instance.new("Frame")
field.Name = "RoadGrid"
field.Position = UDim2.fromOffset(6, 6)
field.Size = UDim2.fromOffset(size, size)
field.ClipsDescendants = true
field.BackgroundColor3 = Color3.fromRGB(42, 64, 60)
field.BorderSizePixel = 0
field.Parent = panel
local fieldCorner = Instance.new("UICorner")
fieldCorner.CornerRadius = UDim.new(0, 8)
fieldCorner.Parent = field
local scale = if touch then 0.26 else 0.31
local roadLines = {}
for index = 1, 15 do
    for orientation = 1, 2 do
        local line = Instance.new("Frame")
        line.Name = if orientation == 1 then "RoadVertical" else "RoadHorizontal"
        line.BackgroundColor3 = Color3.fromRGB(70, 80, 87)
        line.BorderSizePixel = 0
        line.Parent = field
        line.Size = if orientation == 1 then UDim2.fromOffset(9, size)
            else UDim2.fromOffset(size, 9)
        table.insert(roadLines, {object = line, axis = orientation, offset = index - 8})
    end
end
local function marker(name: string, color: Color3, label: string): TextLabel
    local item = Instance.new("TextLabel")
    item.Name = name
    item.Size = UDim2.fromOffset(18, 18)
    item.AnchorPoint = Vector2.new(0.5, 0.5)
    item.BackgroundColor3 = color
    item.BackgroundTransparency = 0.12
    item.TextColor3 = Color3.new(1, 1, 1)
    item.Font = Enum.Font.GothamBold
    item.TextSize = 12
    item.Text = label
    item.Visible = false
    item.Parent = field
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = item
    return item
end
local me = marker("YouAreHere", Color3.fromRGB(249, 205, 78), "▲")
local home = marker("YourHome", Color3.fromRGB(64, 185, 138), "H")
local waypoint = marker("NextWorkplace", Color3.fromRGB(105, 194, 239), "!")
local region = Instance.new("TextLabel")
region.Name = "NearestDistrict"
region.Position = UDim2.new(0, 8, 1, -42)
region.Size = UDim2.new(1, -16, 0, 17)
region.BackgroundTransparency = 1
region.TextColor3 = Color3.fromRGB(218, 232, 232)
region.Font = Enum.Font.GothamMedium
region.TextSize = 12
region.Text = "STREET CITY"
region.TextXAlignment = Enum.TextXAlignment.Left
region.Parent = panel

local settings = {"Balanced", "Performance", "Visual"}
local mode = if touch then 2 else 1
local button = Instance.new("TextButton")
button.Name = "QualityMode"
button.Position = UDim2.new(0, 8, 1, -24)
button.Size = UDim2.new(1, -16, 0, 18)
button.BackgroundColor3 = Color3.fromRGB(37, 64, 76)
button.TextColor3 = Color3.fromRGB(221, 241, 247)
button.Font = Enum.Font.GothamMedium
button.TextSize = 11
button.Parent = panel
local function applyQuality()
    local selected = settings[mode]
    button.Text = "Graphics: " .. selected .. "  ↻"
    player:SetAttribute("StreetCityVisualQuality", selected)
    -- Client-local quality preference; never mutate world collision or physics.
    pcall(function()
        Lighting.GlobalShadows = selected ~= "Performance"
        for _, effect in Lighting:GetChildren() do
            if effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect")
                or effect:IsA("DepthOfFieldEffect") then
                effect.Enabled = selected == "Visual"
            end
        end
    end)
end
button.MouseButton1Click:Connect(function()
    mode = mode % #settings + 1
    applyQuality()
end)
applyQuality()

local function position(item: TextLabel, offsetX: number, offsetZ: number)
    local x = size / 2 + offsetX * scale
    local y = size / 2 + offsetZ * scale
    item.Visible = x >= 8 and x <= size - 8 and y >= 8 and y <= size - 8
    item.Position = UDim2.fromOffset(x, y)
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.3 then return end
    elapsed = 0
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        me.Visible = false
        return
    end
    local x, z = root.Position.X, root.Position.Z
    for _, segment in roadLines do
        local axisCenter = if segment.axis == 1 then x else z
        local axis = (math.floor(axisCenter / Config.World.RoadSpacing)
            + segment.offset) * Config.World.RoadSpacing
        local shifted = size / 2 + (axis - axisCenter) * scale
        segment.object.Visible = shifted >= -8 and shifted <= size + 8
        if segment.axis == 1 then
            segment.object.Position = UDim2.fromOffset(shifted - 4, 0)
        else
            segment.object.Position = UDim2.fromOffset(0, shifted - 4)
        end
    end
    me.Visible = true
    me.Position = UDim2.fromOffset(size / 2, size / 2)
    me.Rotation = -math.deg(math.atan2(root.CFrame.LookVector.X,
        -root.CFrame.LookVector.Z))
    local homePoint = player:GetAttribute("StreetCityHomePosition")
    if typeof(homePoint) == "Vector3" then
        position(home, homePoint.X - x, homePoint.Z - z)
    else
        home.Visible = false
    end
    local target = player:GetAttribute("StreetCityWorkWaypoint")
    if typeof(target) == "Vector3" then
        position(waypoint, target.X - x, target.Z - z)
    else
        waypoint.Visible = false
    end
    local best, bestDistance = "OPEN CITY", math.huge
    for _, district in Districts do
        local dx, dz = x - district.x, z - district.z
        local distance = dx * dx + dz * dz
        if distance < bestDistance then
            bestDistance = distance
            best = string.upper(district.id)
        end
    end
    region.Text = best .. " • N ↑"
end)
