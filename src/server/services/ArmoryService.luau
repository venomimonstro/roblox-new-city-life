--!strict
-- Purchasable and discoverable arcade equipment, server-side ownership checks.
-- No graphic injury or real-world weapon simulation; targets are NPC reactions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Citizens = require(script.Parent:WaitForChild("CitizenService"))
local Armory = {}

local ITEMS = {
    {id="weapon_training_gloves", name="Training Gloves", range=7, delay=0.7, x=100, z=320},
    {id="weapon_foam_baton", name="Foam Baton", range=10, delay=0.8, x=350, z=130},
    {id="weapon_stun_wand", name="Arcade Stun Wand", range=11, delay=1.2, x=-450, z=130},
    {id="weapon_paint_blaster", name="Paint Blaster", range=40, delay=0.65, x=-650, z=-230},
    {id="weapon_arcade_pistol", name="Arcade Sidearm", range=55, delay=0.5, x=650, z=-230},
    {id="weapon_arcade_shotgun", name="Arcade Scatter", range=30, delay=1.2, x=850, z=-530},
    {id="weapon_arcade_smg", name="Arcade SMG", range=65, delay=0.26, x=-850, z=630},
    {id="weapon_arcade_rifle", name="Arcade Rifle", range=80, delay=0.5, x=1050, z=730},
}
local byId: {[string]: any} = {}
local lastAction: {[number]: number} = {}
local pickupCooldown: {[string]: number} = {}
local remote: RemoteEvent
local notice: RemoteEvent

local function tell(player: Player, text: string)
    if player.Parent == Players then notice:FireClient(player, text) end
end

local function hasTool(player: Player, offerId: string): boolean
    local char = player.Character
    local backpack = player:FindFirstChildOfClass("Backpack")
    return (char and char:FindFirstChild(offerId) ~= nil)
        or (backpack and backpack:FindFirstChild(offerId) ~= nil)
end

local function equipAvailable(player: Player)
    local profile = Profile.Read(player)
    if not profile then return end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then return end
    for _, def in ITEMS do
        if (profile.inventory[def.id] or 0) > 0 and not hasTool(player, def.id) then
            local tool = Instance.new("Tool")
            tool.Name = def.id
            tool.ToolTip = def.name .. " — F / tap action"
            tool.RequiresHandle = false
            tool.CanBeDropped = false
            tool:SetAttribute("StreetCityEquipment", def.id)
            tool.Parent = backpack
        end
    end
end

local function stand(parent: Instance, def: any, position: Vector3, isFree: boolean)
    local pad = Instance.new("Part")
    pad.Name = (if isFree then "WeaponPickup_" else "Armory_") .. def.id
    pad.Size = Vector3.new(5, 1, 5)
    pad.Position = position
    pad.Anchored = true
    pad.CanCollide = false
    pad.CanQuery = false
    pad.CanTouch = false
    pad.Material = Enum.Material.Neon
    pad.Color = if isFree then Color3.fromRGB(67, 168, 118)
        else Color3.fromRGB(128, 111, 178)
    pad.Parent = parent
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = def.name
    prompt.ActionText = if isFree then "Collect item" else "Buy equipment"
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = pad
    prompt.Triggered:Connect(function(player: Player)
        local character = player.Character
        local human = character and character:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 or human.SeatPart
            or player:DistanceFromCharacter(pad.Position) > 12
            or not Profile.IsLoaded(player) then return end
        local key = tostring(player.UserId) .. ":" .. pad.Name
        if os.clock() - (pickupCooldown[key] or 0) < 4 then return end
        pickupCooldown[key] = os.clock()
        local operation = "equip_" .. HttpService:GenerateGUID(false):gsub("-", "")
        local ok = Profile.Mutate(player, function(profile)
            if isFree then
                return Rules.CollectEquipment(profile, def.id, operation)
            end
            return Rules.PurchasePart(profile, def.id, operation)
        end)
        if ok then
            equipAvailable(player)
            tell(player, def.name .. " added to backpack")
        else
            tell(player, "Already collected, not enough cash or equipment unavailable")
        end
    end)
end

function Armory.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local root = Instance.new("Folder")
    root.Name = "CityArmory"
    root.Parent = world
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    remote = Instance.new("RemoteEvent")
    remote.Name = "StreetCityEquipmentAction"
    remote.Parent = ReplicatedStorage
    for index, def in ITEMS do
        byId[def.id] = def
        stand(root, def, Vector3.new(-430 + index * 14, 2, 370), false)
        stand(root, def, Vector3.new(def.x, 2, def.z), true)
    end
    remote.OnServerEvent:Connect(function(player: Player)
        if player.Parent ~= Players or not Profile.IsLoaded(player) then return end
        local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 or human.SeatPart then return end
        local equipped: Tool? = nil
        for _, child in player.Character:GetChildren() do
            if child:IsA("Tool") and child:GetAttribute("StreetCityEquipment") then
                equipped = child
                break
            end
        end
        if not equipped then return end
        local id = equipped:GetAttribute("StreetCityEquipment")
        local def = if type(id) == "string" then byId[id] else nil
        if not def then return end
        local profile = Profile.Read(player)
        if not profile or (profile.inventory[id] or 0) < 1 then return end
        local now = os.clock()
        if now - (lastAction[player.UserId] or 0) < def.delay then return end
        lastAction[player.UserId] = now
        local connected = Citizens.HitNearest(player, def.range)
        if connected then tell(player, def.name .. ": NPC reacted; police alerted") end
    end)
    local function initPlayer(player: Player)
        player.CharacterAdded:Connect(function()
            task.spawn(function()
                for _ = 1, 35 do
                    if player.Parent ~= Players then return end
                    if Profile.IsLoaded(player) then
                        task.wait(0.5)
                        equipAvailable(player)
                        return
                    end
                    task.wait(1)
                end
            end)
        end)
        if player.Character then task.defer(equipAvailable, player) end
    end
    Players.PlayerAdded:Connect(initPlayer)
    for _, player in Players:GetPlayers() do initPlayer(player) end
    Players.PlayerRemoving:Connect(function(player)
        lastAction[player.UserId] = nil
        local prefix = tostring(player.UserId) .. ":"
        for key in pairs(pickupCooldown) do
            if string.sub(key, 1, #prefix) == prefix then pickupCooldown[key] = nil end
        end
    end)
    print("[StreetCity] Armory active: " .. #ITEMS .. " equipment types")
end

return Armory
