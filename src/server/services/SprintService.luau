--!strict
-- Server-driven sprint/stamina: mobile, desktop and gamepad. No speed or stamina
-- values are accepted from the client. Respects persisted nutrition/fitness.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Sprint = {}

local sessions: {[number]: {stamina: number, wants: boolean, lastRequest: number,
    lastReplicated: number, exhaustedUntil: number}} = {}

local function baseSpeed(profile: any): number
    return math.clamp(15 + profile.fitness / 35 - profile.bodyFat / 45
        + (profile.nutrition - 50) / 100, 12, 20)
end

function Sprint.Start()
    local remote = Instance.new("RemoteEvent")
    remote.Name = "StreetCitySprintRequest"
    remote.Parent = ReplicatedStorage
    local function init(player: Player)
        sessions[player.UserId] = {
            stamina = 100, wants = false, lastRequest = 0,
            lastReplicated = -1, exhaustedUntil = 0,
        }
        player:SetAttribute("StreetCityStamina", 100)
        player.CharacterAdded:Connect(function()
            local state = sessions[player.UserId]
            if state then state.wants = false end
        end)
    end
    Players.PlayerAdded:Connect(init)
    for _, player in Players:GetPlayers() do init(player) end
    Players.PlayerRemoving:Connect(function(player)
        sessions[player.UserId] = nil
    end)
    remote.OnServerEvent:Connect(function(player: Player, wants: any)
        if type(wants) ~= "boolean" or player.Parent ~= Players then return end
        local state = sessions[player.UserId]
        if not state then return end
        local now = os.clock()
        if now - state.lastRequest < 0.09 then return end
        state.lastRequest = now
        state.wants = wants
    end)
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt)
        accumulator += dt
        if accumulator < 0.25 then return end
        local step = math.min(accumulator, 0.5)
        accumulator = 0
        for _, player in Players:GetPlayers() do
            local state = sessions[player.UserId]
            if not state then continue end
            local character = player.Character
            local human = character and character:FindFirstChildOfClass("Humanoid")
            if not human or human.Health <= 0 then continue end
            local account = Profile.Read(player)
            if not account then continue end
            local walking = human.MoveDirection.Magnitude > 0.12
            local sprinting = state.wants and walking and not human.SeatPart
                and os.clock() >= state.exhaustedUntil and state.stamina > 1
                and human:GetState() ~= Enum.HumanoidStateType.Swimming
            if sprinting then
                state.stamina = math.max(0, state.stamina
                    - step * (9 - account.fitness / 30))
                if state.stamina <= 1 then
                    state.wants = false
                    state.exhaustedUntil = os.clock() + 3
                end
            else
                state.stamina = math.min(100, state.stamina
                    + step * (5 + account.fitness / 45))
            end
            local base = baseSpeed(account)
            local speed = if sprinting then math.min(25, base + 5.0)
                else base
            if not human.SeatPart and math.abs(human.WalkSpeed - speed) > 0.1 then
                human.WalkSpeed = speed
            end
            local stamina = math.floor(state.stamina + 0.5)
            if stamina ~= state.lastReplicated then
                player:SetAttribute("StreetCityStamina", stamina)
                state.lastReplicated = stamina
            end
        end
    end)
    print("[StreetCity] Server-enforced sprint stamina ready")
end

return Sprint
