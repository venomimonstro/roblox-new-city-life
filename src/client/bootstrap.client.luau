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

task.spawn(function()
    local remote = ReplicatedStorage:WaitForChild("StreetCityProfileState", 8)
    if not remote or not remote:IsA("RemoteEvent") then return end
    remote.OnClientEvent:Connect(function(credits: any, cars: any, selected: any)
        if type(credits) ~= "number" or type(cars) ~= "number" or type(selected) ~= "string" then return end
        wallet.Text = string.format("Credits: %d  |  Cars: %d  |  %s", credits, cars, string.sub(selected, 1, 24))
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

local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.1 then
        return
    end
    elapsed = 0
    local seat = currentSeat()
    panel.Visible = seat ~= nil
    if seat then
        vehicleInput:FireServer(seat.ThrottleFloat, seat.SteerFloat)
        local kmh = seat.AssemblyLinearVelocity.Magnitude * 0.28 * 3.6
        speed.Text = string.format("%03d km/h", math.floor(kmh + 0.5))
    end
end)
