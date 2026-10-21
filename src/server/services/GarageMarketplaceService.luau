--!strict
-- Safe in-game credit shop. No Robux or developer products.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))
local PersonalGarage = require(script.Parent:WaitForChild("PersonalGarage"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Offers = require(ReplicatedStorage.Shared:WaitForChild("ShopCatalog"))
local Shop = {}

local lastAction: {[number]: number} = {}
local notice: RemoteEvent

local function notify(player: Player, message: string)
    notice:FireClient(player, message)
end

local function station(parent: Instance, label: string, pos: Vector3, action: (Player) -> ())
    local pad = Instance.new("Part")
    pad.Name = "Shop_" .. label
    pad.Size = Vector3.new(6, 2, 6)
    pad.Anchored = true
    pad.Material = Enum.Material.Neon
    pad.Color = Color3.fromRGB(188, 133, 75)
    pad.Position = pos
    pad.Parent = parent
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = label
    prompt.ActionText = "Interact"
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = pad
    prompt.Triggered:Connect(function(player: Player)
        local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 then return end
        if player:DistanceFromCharacter(pad.Position) > 12 then return end
        if not ProfileService.IsLoaded(player) then
            notify(player, "Profile unavailable")
            return
        end
        local now = os.clock()
        if now - (lastAction[player.UserId] or 0) < 1.2 then return end
        lastAction[player.UserId] = now
        action(player)
    end)
end

local function opId(): string
    return "buy_" .. HttpService:GenerateGUID(false):gsub("-", "")
end

function Shop.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local remotes = ReplicatedStorage:WaitForChild("StreetCityRemotes")
    notice = Instance.new("RemoteEvent")
    notice.Name = "GarageNotice"
    notice.Parent = remotes

    local keys = {"tire_worn_used", "tire_sport_new", "gearbox_sport_new", "engine_sport_new", "engine_v6_used"}
    for index, offerId in keys do
        local item = Offers[offerId]
        station(world, offerId .. " " .. tostring(item.price) .. " cr",
            Vector3.new(-20 + (index - 1) * 10, 0, -65), function(player)
                local success = ProfileService.Mutate(player, function(profile)
                    return Rules.PurchasePart(profile, offerId, opId())
                end)
                notify(player, if success then "Part purchased: " .. offerId else "Purchase denied / insufficient credits")
            end)
    end
    station(world, "Buy Street Coupe: 12000 cr", Vector3.new(0, 0, -45), function(player)
        local vehicleId = "car_" .. HttpService:GenerateGUID(false):gsub("-", "")
        local operation = opId()
        local success = ProfileService.Mutate(player, function(profile)
            return Rules.PurchaseVehicle(profile, "street_coupe", vehicleId, operation)
        end)
        notify(player, if success then "Street Coupe added to garage" else "Car purchase denied")
    end)
    station(world, "Install owned part", Vector3.new(0, 0, -83), function(player)
        local car = PersonalGarage.GetActive(player)
        if car and (car.Seat.Occupant or car.Chassis.AssemblyLinearVelocity.Magnitude > 2) then
            notify(player, "Park and exit the car first")
            return
        end
        local snapshot = ProfileService.Read(player)
        if not snapshot then return end
        local chosen: string? = nil
        local keys = {}
        for offerId, count in pairs(snapshot.inventory) do
            if count > 0 then table.insert(keys, offerId) end
        end
        table.sort(keys)
        for _, offerId in keys do
            local offer = Offers[offerId]
            local current = snapshot.garage[snapshot.selectedVehicleId]
            if current and current[offer.slot] ~= offer.partId then
                chosen = offerId
                break
            end
        end
        if not chosen then
            notify(player, "No compatible uninstalled parts")
            return
        end
        local operation = opId()
        local changed = ProfileService.Mutate(player, function(profile)
            return Rules.InstallPart(profile, profile.selectedVehicleId, chosen :: string, operation)
        end)
        if changed then
            PersonalGarage.Refresh(player)
        end
        notify(player, if changed then "Part installed: " .. chosen else "Installation denied")
    end)

    Players.PlayerRemoving:Connect(function(player)
        lastAction[player.UserId] = nil
    end)
end

return Shop
