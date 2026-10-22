--!strict
-- Conservative humanoid fall impact, using Roblox's normal R6/R15 motors.
-- Unlike unverified client fall-damage remotes, the server observes velocity
-- and landing state directly. Respawn grace prevents teleport false positives.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Physics = {}

local function bind(player: Player, character: Model)
    local human = character:WaitForChild("Humanoid", 12)
    local root = character:WaitForChild("HumanoidRootPart", 12)
    if not human or not human:IsA("Humanoid")
        or not root or not root:IsA("BasePart") then return end
    local created = os.clock()
    local airborneAt = 0
    local maxDown = 0
    local lastLand = 0
    local listener: RBXScriptConnection?
    listener = RunService.Heartbeat:Connect(function()
        if not character.Parent or human.Health <= 0 or player.Parent ~= Players then
            if listener then listener:Disconnect() end
            return
        end
        local state = human:GetState()
        local airborne = state == Enum.HumanoidStateType.Freefall
            or state == Enum.HumanoidStateType.FallingDown
        if airborne then
            if airborneAt == 0 then airborneAt = os.clock() end
            maxDown = math.max(maxDown, -root.AssemblyLinearVelocity.Y)
        elseif airborneAt ~= 0 then
            local duration = os.clock() - airborneAt
            local speed = maxDown
            airborneAt = 0
            maxDown = 0
            -- No damage from swimming, sitting, first spawn, short hops or
            -- character teleports; only true substantial descents count.
            local validLanding = state == Enum.HumanoidStateType.Landed
                or state == Enum.HumanoidStateType.Running
            if not validLanding or os.clock() - created < 4
                or os.clock() - lastLand < 2
                or duration < 0.65 or speed < 85
                or human.SeatPart ~= nil then return end
            lastLand = os.clock()
            local damage = math.clamp(math.floor((speed - 75) * 0.52), 0, 70)
            if damage > 0 then
                human:TakeDamage(damage)
                character:SetAttribute("LastFallImpact", math.floor(speed))
            end
        end
    end)
end

function Physics.Start()
    local function joined(player: Player)
        player.CharacterAdded:Connect(function(character)
            task.spawn(bind, player, character)
        end)
        if player.Character then task.spawn(bind, player, player.Character) end
    end
    Players.PlayerAdded:Connect(joined)
    for _, player in Players:GetPlayers() do joined(player) end
    print("[StreetCity] Server humanoid fall/landing physics enabled")
end

return Physics
