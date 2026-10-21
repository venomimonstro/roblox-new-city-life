--!strict
-- Each game server maintains its own city simulation. Do not present these
-- values as a global persistent economy until cross-server reconciliation exists.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Dynamics = require(ReplicatedStorage.Shared:WaitForChild("DistrictDynamics"))
local Wanted = require(script.Parent:WaitForChild("WantedService"))
local Society = {}
local stateById: {[string]: any} = {}
local changed = Instance.new("BindableEvent")
local remote: RemoteEvent? = nil
local requestThrottle: {[number]: number} = {}

function Society.Resolve(position: Vector3): string
    local nearest = "downtown"
    local distance = math.huge
    for _, district in Districts do
        local delta = Vector3.new(position.X - district.x, 0, position.Z - district.z)
        if delta.Magnitude < distance then
            distance = delta.Magnitude
            nearest = district.id
        end
    end
    return nearest
end

function Society.GetState(districtId: string): any?
    local state = stateById[districtId]
    if not state then return nil end
    return table.clone(state)
end

function Society.StateFor(position: Vector3): any?
    return Society.GetState(Society.Resolve(position))
end

function Society.Changed(): RBXScriptSignal
    return changed.Event
end

function Society.ApplyAt(position: Vector3, kind: string, strength: number): boolean
    local id = Society.Resolve(position)
    local state = stateById[id]
    if not state or not Dynamics.Apply(state, kind, strength) then return false end
    changed:Fire(id, table.clone(state))
    return true
end

function Society.EffectForPlayer(player: Player, kind: string, strength: number): boolean
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then return false end
    return Society.ApplyAt(root.Position, kind, strength)
end

function Society.Start()
    assert(next(stateById) == nil, "District society started twice")
    for _, district in Districts do
        local state = Dynamics.New(district.id)
        Dynamics.Recalculate(state)
        stateById[district.id] = state
    end
    remote = Instance.new("RemoteEvent")
    remote.Name = "StreetCityDistrictState"
    remote.Parent = ReplicatedStorage
    Wanted.SetIncidentHandler(function(player, amount, _reason)
        Society.EffectForPlayer(player, "crime", math.min(amount, 5))
    end)
    remote.OnServerEvent:Connect(function(player: Player)
        local now = os.clock()
        if now - (requestThrottle[player.UserId] or -100) < 3 then return end
        requestThrottle[player.UserId] = now
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root and root:IsA("BasePart") and remote then
            local state = Society.StateFor(root.Position)
            if state then remote:FireClient(player, state.id, state.safety,
                state.prosperity, state.population, state.propertyIndex, state.bankTrust) end
        end
    end)
    changed.Event:Connect(function(districtId, state)
        for _, player in Players:GetPlayers() do
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") and Society.Resolve(root.Position) == districtId then
                if remote then remote:FireClient(player, districtId, state.safety,
                    state.prosperity, state.population, state.propertyIndex, state.bankTrust) end
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        requestThrottle[player.UserId] = nil
    end)
    print("[StreetCity] Seven dynamic district societies initialized (server-local)")
end

return Society
