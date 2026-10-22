--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "StreetCityHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "VehiclePanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.fromScale(0.5, 0.965)
panel.Size = UDim2.fromOffset(260, 72)
panel.BackgroundColor3 = Color3.fromRGB(18, 25, 35)
panel.BackgroundTransparency = 0.2
panel.Visible = false
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local speed = Instance.new("TextLabel")
speed.Name = "Speed"
speed.Size = UDim2.fromScale(1, 0.62)
speed.Position = UDim2.fromScale(0, 0)
speed.BackgroundTransparency = 1
speed.TextColor3 = Color3.new(1, 1, 1)
speed.TextSize = 27
speed.Font = Enum.Font.GothamBold
speed.Parent = panel

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.fromScale(1, 0.34)
hint.Position = UDim2.fromScale(0, 0.63)
hint.BackgroundTransparency = 1
hint.TextColor3 = Color3.fromRGB(195, 203, 211)
hint.TextSize = 12
hint.Text = "WASD / arrows  |  L - headlights"
hint.Font = Enum.Font.Gotham
hint.Parent = panel

local remotes = ReplicatedStorage:WaitForChild("StreetCityRemotes")
local wallet = Instance.new("TextLabel")
wallet.Name = "PlayerSummary"
wallet.Position = UDim2.fromOffset(14, 18)
wallet.Size = UDim2.new(0.75, 0, 0, 28)
wallet.BackgroundTransparency = 1
wallet.TextXAlignment = Enum.TextXAlignment.Left
wallet.Font = Enum.Font.GothamSemibold
wallet.TextSize = 15
wallet.TextColor3 = Color3.fromRGB(240, 240, 240)
wallet.Text = "Street City Online"
wallet.Parent = gui

local guide = Instance.new("TextLabel")
guide.Name = "NextActionHint"
guide.Position = UDim2.fromOffset(14, 46)
guide.Size = UDim2.new(0.92, 0, 0, 38)
guide.BackgroundTransparency = 0.32
guide.BackgroundColor3 = Color3.fromRGB(18, 25, 35)
guide.TextColor3 = Color3.fromRGB(238, 241, 242)
guide.TextSize = 13
guide.TextWrapped = true
guide.TextXAlignment = Enum.TextXAlignment.Left
guide.Font = Enum.Font.Gotham
guide.Text = "Ваш дом и гараж рядом. Верните личную машину у стойки гаража; работа и гонки — по всему городу."
guide.Parent = gui

local wanted = Instance.new("TextLabel")
wanted.Name = "WantedStars"
wanted.AnchorPoint = Vector2.new(1, 0)
wanted.Position = UDim2.new(1, -14, 0, 20)
wanted.Size = UDim2.fromOffset(190, 32)
wanted.BackgroundTransparency = 1
wanted.TextColor3 = Color3.fromRGB(249, 198, 84)
wanted.TextXAlignment = Enum.TextXAlignment.Right
wanted.Font = Enum.Font.GothamBold
wanted.TextSize = 22
wanted.Text = ""
wanted.Parent = gui

local safetyNet = Instance.new("TextLabel")
safetyNet.Name = "HomeSavingsAndClinic"
safetyNet.Position = UDim2.fromOffset(14, 183)
safetyNet.Size = UDim2.new(0.86, 0, 0, 22)
safetyNet.BackgroundTransparency = 0.2
safetyNet.BackgroundColor3 = Color3.fromRGB(18, 25, 35)
safetyNet.Font = Enum.Font.Gotham
safetyNet.TextColor3 = Color3.fromRGB(221, 229, 219)
safetyNet.TextSize = 12
safetyNet.TextXAlignment = Enum.TextXAlignment.Left
safetyNet.Text = "Home cash 0 | Hospital debt 0"
safetyNet.Parent = gui

local bodyStats = Instance.new("TextLabel")
bodyStats.Name = "BodyStats"
bodyStats.Position = UDim2.fromOffset(14, 88)
bodyStats.Size = UDim2.fromOffset(320, 24)
bodyStats.BackgroundTransparency = 1
bodyStats.TextXAlignment = Enum.TextXAlignment.Left
bodyStats.Font = Enum.Font.Gotham
bodyStats.TextSize = 13
bodyStats.TextColor3 = Color3.fromRGB(210, 220, 220)
bodyStats.Text = ""
bodyStats.Parent = gui

task.spawn(function()
    local remote = ReplicatedStorage:WaitForChild("StreetCityWantedState", 15)
    if not remote or not remote:IsA("RemoteEvent") then return end
    remote.OnClientEvent:Connect(function(level: any)
        if type(level) ~= "number" or level % 1 ~= 0
            or level < 0 or level > 5 then return end
        wanted.Text = string.rep("★", level)
    end)
    remote:FireServer()
end)

task.spawn(function()
    local remote = ReplicatedStorage:WaitForChild("StreetCityProfileState", 8)
    if not remote or not remote:IsA("RemoteEvent") then return end
    remote.OnClientEvent:Connect(function(credits: any, cars: any, selected: any,
        bank: any, goods: any, fitness: any, bodyFat: any,
        communityBank: any, deeds: any, allegiance: any,
        homeCash: any, medicalDebt: any, deathCount: any)
        if type(credits) ~= "number" or type(cars) ~= "number"
            or type(selected) ~= "string" then return end
        safetyNet.Text = string.format("Home safe %d | Medical debt %d | Deaths %d",
            if type(homeCash) == "number" then homeCash else 0,
            if type(medicalDebt) == "number" then medicalDebt else 0,
            if type(deathCount) == "number" then deathCount else 0)
        local safeBank = if type(bank) == "number" then bank else 0
        local loot = if type(goods) == "number" then goods else 0
        local localBank = if type(communityBank) == "number" then communityBank else 0
        local propertyCount = if type(deeds) == "number" then deeds else 0
        wallet.Text = string.format("Cash %d | Secure %d | Local %d | Cars %d | Deeds %d",
            credits, safeBank, localBank, cars, propertyCount)
        if type(allegiance) == "string" then
            bodyStats.Text = string.format("Faction %s | Fitness %d | Fat %d | Loot %d",
                allegiance,
                if type(fitness) == "number" then fitness else 15,
                if type(bodyFat) == "number" then bodyFat else 25, loot)
        end
        if type(fitness) == "number" and type(bodyFat) == "number"
            and type(allegiance) ~= "string" then
            bodyStats.Text = string.format("Fitness %d | Body fat %d", fitness, bodyFat)
        end
    end)
    remote:FireServer()
end)

local lightsRemote = remotes:WaitForChild("ToggleHeadlights") :: RemoteEvent
local vehicleInput = remotes:WaitForChild("VehicleInput") :: RemoteEvent
local messageRemote = remotes:WaitForChild("GarageNotice") :: RemoteEvent

local toast = Instance.new("TextLabel")
toast.Name = "StatusToast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.fromScale(0.5, 0.11)
toast.Size = UDim2.new(0.85, 0, 0, 46)
toast.BackgroundColor3 = Color3.fromRGB(18, 25, 35)
toast.BackgroundTransparency = 0.14
toast.TextColor3 = Color3.fromRGB(249, 249, 249)
toast.TextScaled = false
toast.TextSize = 17
toast.TextWrapped = true
toast.Font = Enum.Font.GothamMedium
toast.Visible = false
toast.Parent = gui
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 10)
toastCorner.Parent = toast

local notificationId = 0
messageRemote.OnClientEvent:Connect(function(value: any)
    if type(value) ~= "string" then return end
    notificationId += 1
    local current = notificationId
    toast.Text = string.sub(value, 1, 120)
    toast.Visible = true
    task.delay(4, function()
        if notificationId == current then toast.Visible = false end
    end)
end)

local function currentSeat(): VehicleSeat?
    local char = player.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    local seatPart = humanoid and humanoid.SeatPart
    if seatPart and seatPart:IsA("VehicleSeat") then
        local model = seatPart:FindFirstAncestorOfClass("Model")
        if model and model:GetAttribute("StreetCityVehicle") == true then
            return seatPart
        end
    end
    return nil
end

local function toggleLights(_actionName: string, state: Enum.UserInputState)
    if state == Enum.UserInputState.Begin and currentSeat() then
        lightsRemote:FireServer()
    end
    return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("StreetCityLights", toggleLights, true, Enum.KeyCode.L)
ContextActionService:SetTitle("StreetCityLights", "Lights")
ContextActionService:SetPosition("StreetCityLights", UDim2.fromScale(0.8, 0.63))

local districtState = Instance.new("TextLabel")
districtState.Name = "DistrictWellbeing"
districtState.Position = UDim2.fromOffset(14, 141)
districtState.Size = UDim2.new(0.86, 0, 0, 34)
districtState.BackgroundTransparency = 0.3
districtState.BackgroundColor3 = Color3.fromRGB(19, 27, 37)
districtState.TextColor3 = Color3.fromRGB(216, 231, 222)
districtState.TextSize = 12
districtState.Font = Enum.Font.Gotham
districtState.TextXAlignment = Enum.TextXAlignment.Left
districtState.TextWrapped = true
districtState.Text = "District statistics loading..."
districtState.Parent = gui

task.spawn(function()
    local remote = ReplicatedStorage:WaitForChild("StreetCityDistrictState", 20)
    if not remote or not remote:IsA("RemoteEvent") then return end
    remote.OnClientEvent:Connect(function(id: any, safety: any, prosperity: any,
        population: any, propertyPrice: any, trust: any)
        if type(id) ~= "string" or #id > 40
            or type(safety) ~= "number" or type(prosperity) ~= "number"
            or type(population) ~= "number" or type(propertyPrice) ~= "number"
            or type(trust) ~= "number" then return end
        districtState.Text = string.format(
            "%s | Safety %d | Welfare %d | Residents %d | Real estate %d%% | Banks %d",
            id, safety, prosperity, population, propertyPrice, trust)
    end)
    while player.Parent == Players do
        remote:FireServer()
        task.wait(12)
    end
end)

local weatherName = Instance.new("TextLabel")
weatherName.Name = "WeatherIndicator"
weatherName.Position = UDim2.fromOffset(14, 112)
weatherName.Size = UDim2.fromOffset(280, 22)
weatherName.BackgroundTransparency = 1
weatherName.Font = Enum.Font.Gotham
weatherName.TextColor3 = Color3.fromRGB(215, 226, 235)
weatherName.TextSize = 13
weatherName.TextXAlignment = Enum.TextXAlignment.Left
weatherName.Parent = gui

local rainPart = Instance.new("Part")
rainPart.Name = "LocalWeatherRain"
rainPart.Size = Vector3.new(60, 0.1, 60)
rainPart.Transparency = 1
rainPart.Anchored = true
rainPart.CanCollide = false
rainPart.CanQuery = false
rainPart.CanTouch = false
rainPart.Parent = workspace.CurrentCamera or workspace

local drops = Instance.new("ParticleEmitter")
drops.Name = "RainDrops"
drops.Enabled = false
drops.EmissionDirection = Enum.NormalId.Bottom
drops.Rate = 140
drops.Lifetime = NumberRange.new(0.35, 0.6)
drops.Speed = NumberRange.new(55, 75)
drops.Acceleration = Vector3.new(0, -40, 0)
drops.SpreadAngle = Vector2.new(6, 6)
drops.Size = NumberSequence.new(0.09)
drops.Transparency = NumberSequence.new(0.3)
drops.Color = ColorSequence.new(Color3.fromRGB(170, 200, 225))
drops.Parent = rainPart

local function updateWeather()
    local condition = ReplicatedStorage:GetAttribute("StreetCityWeather")
    if type(condition) ~= "string" then condition = "Clear" end
    weatherName.Text = "Weather: " .. condition
    drops.Enabled = condition == "Rain" or condition == "Storm"
    drops.Rate = if condition == "Storm" then 240 else 140
end
ReplicatedStorage:GetAttributeChangedSignal("StreetCityWeather"):Connect(updateWeather)
updateWeather()

local equipmentRemote = ReplicatedStorage:WaitForChild("StreetCityEquipmentAction", 20)
local function useEquipment(_action: string, state: Enum.UserInputState)
    if state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
    local character = player.Character
    if not character then return Enum.ContextActionResult.Pass end
    for _, child in character:GetChildren() do
        if child:IsA("Tool") and child:GetAttribute("StreetCityEquipment") then
            if equipmentRemote and equipmentRemote:IsA("RemoteEvent") then
                equipmentRemote:FireServer()
            end
            return Enum.ContextActionResult.Sink
        end
    end
    return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction("CityEquipmentUse", useEquipment, true,
    Enum.KeyCode.F, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:SetTitle("CityEquipmentUse", "Use")
ContextActionService:SetPosition("CityEquipmentUse", UDim2.fromScale(0.82, 0.77))

-- The route comes only from the authoritative server, never from a client
-- request. It remains visible while driving, walking or using mobile buttons.
local careerTarget: Vector3? = nil
local careerName = ""
local careerStage = 0
local careerStops = 0
local careerReward = 0
local careerRoute = Instance.new("TextLabel")
careerRoute.Name = "CareerNavigator"
careerRoute.AnchorPoint = Vector2.new(1, 0)
careerRoute.Position = UDim2.new(1, -14, 0, 65)
careerRoute.Size = UDim2.fromOffset(304, 82)
careerRoute.BackgroundColor3 = Color3.fromRGB(18, 29, 39)
careerRoute.BackgroundTransparency = 0.09
careerRoute.TextColor3 = Color3.fromRGB(218, 245, 230)
careerRoute.TextSize = 14
careerRoute.TextWrapped = true
careerRoute.Font = Enum.Font.GothamSemibold
careerRoute.Visible = false
careerRoute.Parent = gui
local careerCorner = Instance.new("UICorner")
careerCorner.CornerRadius = UDim.new(0, 10)
careerCorner.Parent = careerRoute

task.spawn(function()
    local careersRemote = ReplicatedStorage:WaitForChild("StreetCityCareerStatus", 20)
    if not careersRemote or not careersRemote:IsA("RemoteEvent") then return end
    careersRemote.OnClientEvent:Connect(function(title: any, stage: any,
        stops: any, target: any, reward: any, _mode: any, _description: any)
        if title == nil then
            careerTarget = nil
            careerRoute.Visible = false
            return
        end
        if type(title) ~= "string" or #title > 60
            or type(stage) ~= "number" or stage % 1 ~= 0 or stage < 1
            or type(stops) ~= "number" or stops < stage or stops > 5
            or typeof(target) ~= "Vector3" or type(reward) ~= "number" then return end
        careerName = title
        careerStage, careerStops = stage, stops
        careerReward = reward
        careerTarget = target
        careerRoute.Visible = true
    end)
end)

-- Public, server-curated in-game wanted board. Never accept client
-- requests to choose a victim or define a credit payout.
local board = Instance.new("Frame")
board.Name = "WantedBoard"
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.Position = UDim2.fromScale(0.5, 0.5)
board.Size = UDim2.new(0.9, 0, 0.66, 0)
board.BackgroundColor3 = Color3.fromRGB(19, 28, 39)
board.Visible = false
board.Parent = gui
local boardSize = Instance.new("UISizeConstraint")
boardSize.MaxSize = Vector2.new(410, 520)
boardSize.MinSize = Vector2.new(255, 200)
boardSize.Parent = board
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 48)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Text = "WANTED — CITY POLICE"
title.TextSize = 19
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(241, 224, 186)
title.Parent = board
local closeBoard = Instance.new("TextButton")
closeBoard.Name = "CloseWanted"
closeBoard.Position = UDim2.new(1, -44, 0, 8)
closeBoard.Size = UDim2.fromOffset(32, 32)
closeBoard.Text = "X"
closeBoard.TextSize = 18
closeBoard.Font = Enum.Font.GothamBold
closeBoard.TextColor3 = Color3.new(1, 1, 1)
closeBoard.BackgroundColor3 = Color3.fromRGB(122, 46, 51)
closeBoard.Parent = board
closeBoard.MouseButton1Click:Connect(function()
    board.Visible = false
end)
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "WantedResidents"
scroll.Position = UDim2.fromOffset(10, 51)
scroll.Size = UDim2.new(1, -20, 1, -61)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 6
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = board
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 7)
layout.Parent = scroll

task.spawn(function()
    local wantedBoardRemote = ReplicatedStorage:WaitForChild("StreetCityWantedPosters", 25)
    if not wantedBoardRemote or not wantedBoardRemote:IsA("RemoteEvent") then return end
    wantedBoardRemote.OnClientEvent:Connect(function(entries: any)
        if type(entries) ~= "table" then return end
        for _, row in scroll:GetChildren() do
            if row:IsA("Frame") or row:IsA("TextLabel") then row:Destroy() end
        end
        local shown = 0
        for _, entry in entries do
            if shown >= 10 then break end
            if type(entry) ~= "table"
                or type(entry.userId) ~= "number"
                or type(entry.username) ~= "string"
                or type(entry.displayName) ~= "string"
                or type(entry.stars) ~= "number"
                or type(entry.credits) ~= "number"
                or entry.stars < 3 or entry.stars > 5 then continue end
            shown += 1
            local card = Instance.new("Frame")
            card.Name = "Wanted_" .. tostring(shown)
            card.Size = UDim2.new(1, -10, 0, 65)
            card.LayoutOrder = shown
            card.BackgroundColor3 = Color3.fromRGB(42, 55, 67)
            card.Parent = scroll
            local avatar = Instance.new("ImageLabel")
            avatar.Name = "Avatar"
            avatar.Size = UDim2.fromOffset(55, 55)
            avatar.Position = UDim2.fromOffset(5, 5)
            avatar.BackgroundTransparency = 1
            avatar.Image = "rbxthumb://type=AvatarHeadShot&id="
                .. tostring(math.floor(entry.userId)) .. "&w=150&h=150"
            avatar.Parent = card
            local name = Instance.new("TextLabel")
            name.Size = UDim2.new(1, -72, 1, -5)
            name.Position = UDim2.fromOffset(68, 2)
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.TextWrapped = true
            name.TextSize = 13
            name.Font = Enum.Font.GothamMedium
            name.BackgroundTransparency = 1
            name.TextColor3 = Color3.fromRGB(245, 246, 246)
            name.Text = string.sub(entry.displayName, 1, 25)
                .. " (@" .. string.sub(entry.username, 1, 22) .. ")"
                .. "\n" .. string.rep("★", math.floor(entry.stars))
                .. "  •  " .. tostring(math.floor(entry.credits)) .. " bank credits"
            name.Parent = card
        end
        if shown == 0 then
            local empty = Instance.new("TextLabel")
            empty.Size = UDim2.new(1, -10, 0, 70)
            empty.BackgroundTransparency = 1
            empty.TextWrapped = true
            empty.TextColor3 = Color3.fromRGB(212, 226, 229)
            empty.Text = "No eligible wanted residents in this server."
            empty.Parent = scroll
        end
        board.Visible = true
    end)
end)

-- Boxing controls work on keyboard, gamepad and touch. The remote sends
-- only an enum style; the server checks range, cooldowns and NPC bout state.
local boxingPanel=Instance.new("TextLabel")
boxingPanel.Name="BoxingStatus"
boxingPanel.Position=UDim2.new(0.5,-150,0,212)
boxingPanel.Size=UDim2.fromOffset(300,48)
boxingPanel.BackgroundColor3=Color3.fromRGB(29,39,51)
boxingPanel.BackgroundTransparency=0.12
boxingPanel.TextColor3=Color3.fromRGB(249,224,199)
boxingPanel.TextSize=14
boxingPanel.Font=Enum.Font.GothamSemibold
boxingPanel.TextWrapped=true
boxingPanel.Visible=false
boxingPanel.Parent=gui
local boxingRemote: RemoteEvent?=nil
local boxingMode=""
task.spawn(function()
    local remote=ReplicatedStorage:WaitForChild("StreetCityBoxingAction",25)
    if not remote or not remote:IsA("RemoteEvent") then return end
    boxingRemote=remote
    remote.OnClientEvent:Connect(function(mode: any, number: any,
        roundScore: any, totalScore: any)
        if mode==false then
            boxingPanel.Visible=false
            boxingMode=""
            return
        end
        if mode~="bag" and mode~="bout" then return end
        boxingMode=mode
        boxingPanel.Visible=true
        if mode=="bag" then
            boxingPanel.Text="Boxing practice | level "..tostring(number)
                .."\nJ Jab  K Hook  U Uppercut"
        else
            boxingPanel.Text="NPC BOXING: round "..tostring(number).."/3"
                .." | points "..tostring(roundScore).." | total "..tostring(totalScore)
                .."\nJ Jab  K Hook  U Uppercut"
        end
    end)
end)
local function boxingAction(style: string, state: Enum.UserInputState)
    if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
    local character=player.Character
    local root=character and character:FindFirstChild("HumanoidRootPart")
    local nearby=root and root:IsA("BasePart")
        and (root.Position-Vector3.new(260,2,-440)).Magnitude<55
    if nearby and boxingRemote then
        boxingRemote:FireServer(style)
        return Enum.ContextActionResult.Sink
    end
    return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction("BoxingJab",function(_,state)
    return boxingAction("jab",state)
end,true,Enum.KeyCode.J,Enum.KeyCode.ButtonX)
ContextActionService:BindAction("BoxingHook",function(_,state)
    return boxingAction("hook",state)
end,true,Enum.KeyCode.K,Enum.KeyCode.ButtonY)
ContextActionService:BindAction("BoxingUppercut",function(_,state)
    return boxingAction("uppercut",state)
end,true,Enum.KeyCode.U,Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("BoxingJab","Jab")
ContextActionService:SetTitle("BoxingHook","Hook")
ContextActionService:SetTitle("BoxingUppercut","Upper")
ContextActionService:SetPosition("BoxingJab",UDim2.fromScale(0.67,0.69))
ContextActionService:SetPosition("BoxingHook",UDim2.fromScale(0.77,0.69))
ContextActionService:SetPosition("BoxingUppercut",UDim2.fromScale(0.87,0.69))

local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
    if workspace.CurrentCamera then
        rainPart.CFrame = workspace.CurrentCamera.CFrame * CFrame.new(0, 18, -6)
    end
    elapsed += dt
    if elapsed < 0.1 then
        return
    end
    elapsed = 0
    if careerTarget then
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") then
            local offset = Vector3.new(careerTarget.X - root.Position.X, 0,
                careerTarget.Z - root.Position.Z)
            local meters = math.floor(offset.Magnitude + 0.5)
            local aim = if offset.Magnitude > 0.1 then offset.Unit else Vector3.zero
            local cross = root.CFrame.LookVector:Cross(aim).Y
            local forward = root.CFrame.LookVector:Dot(aim)
            local arrow = if forward < -0.3 then "↓"
                elseif cross > 0.25 then "←"
                elseif cross < -0.25 then "→"
                else "↑"
            careerRoute.Text = string.format(
                "%s  %d/%d  •  +%d credits\n%s   %d studs to next stop",
                careerName, careerStage, careerStops, careerReward, arrow, meters)
        else
            careerRoute.Text = careerName .. " — waiting for character"
        end
    end
    local seat = currentSeat()
    panel.Visible = seat ~= nil
    guide.Text = if seat
        then "Гонка: зелёная площадка на центральной дороге. Затем магазин и гараж."
        else "Вы дома: машина в гараже. Есть работа, рыбалка, NPC, угон и полиция."
    if seat then
        vehicleInput:FireServer(seat.ThrottleFloat, seat.SteerFloat)
        local kmh = seat.AssemblyLinearVelocity.Magnitude * 0.28 * 3.6
        speed.Text = string.format("%03d km/h", math.floor(kmh + 0.5))
    end
end)
