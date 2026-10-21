--!strict
-- Safe in-game credit shop. No Robux or developer products.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ProfileService = require(script.Parent:WaitForChild("ProfileService"))
local PersonalGarage = require(script.Parent:WaitForChild("PersonalGarage"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Offers = require(ReplicatedStorage.Shared:WaitForChild("ShopCatalog"))
local Shop = {}

local lastAction: {[number]: number} = {}
local notice: RemoteEvent

local function notify(player: Player, message: string)
    if player.Parent == Players and notice then
        notice:FireClient(player, message)
    end
end

local function station(parent: Instance, label: string, pos: Vector3, action: (Player) -> ())
    local pad = Instance.new("Part")
    pad.Name = "Shop_" .. label
    pad.Size = Vector3.new(6, 2, 6)
    pad.Anchored = true
    -- The shop is beside a driving route; stands must not block vehicle chassis
    -- or become false-positive suspension ground contacts.
    pad.CanCollide = false
    pad.CanQuery = false
    pad.CanTouch = false
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
        local success, err = pcall(action, player)
        if not success then
            warn("[StreetCity] Shop interaction failed for " .. tostring(player.UserId)
                .. ": " .. tostring(err))
            notify(player, "Shop temporarily unavailable. Your balance was not manually changed.")
        end
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
                local operation = opId()
                local success = ProfileService.Mutate(player, function(profile)
                    return Rules.PurchasePart(profile, offerId, operation)
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
    -- Explicit installation stands avoid silently selecting a different purchased
    -- part when a player owns multiple SKUs. All validation stays on the server.
    for index, offerId in keys do
        local offer = Offers[offerId]
        station(world, "Install " .. offerId,
            Vector3.new(-20 + (index - 1) * 10, 0, -83), function(player)
                local car = PersonalGarage.GetActive(player)
                if not car or not car.Model.Parent then
                    notify(player, "Your vehicle is not ready; use Find My Car")
                    return
                end
                if car.Seat.Occupant or car.Chassis.AssemblyLinearVelocity.Magnitude > 2 then
                    notify(player, "Park and exit your car before installing")
                    return
                end
                local snapshot = ProfileService.Read(player)
                local selected = snapshot and snapshot.garage[snapshot.selectedVehicleId]
                if not selected or (snapshot.inventory[offerId] or 0) <= 0 then
                    notify(player, "You do not own this part: " .. offerId)
                    return
                end
                if selected[offer.slot] == offer.partId then
                    notify(player, "This part is already installed")
                    return
                end
                local operation = opId()
                local changed = ProfileService.Mutate(player, function(profile)
                    return Rules.InstallPart(profile, profile.selectedVehicleId, offerId, operation)
                end)
                if changed then
                    local refreshed = PersonalGarage.Refresh(player)
                    PersonalGarage.EnsureSynced(player)
                    notify(player, if refreshed then "Installed: " .. offerId
                        else "Saved; car will synchronize when parked")
                else
                    notify(player, "Installation denied; check profile and inventory")
                end
            end)
    end

    if RunService:IsStudio() and game.GameId == 0 then
        -- Explicitly unpublished Studio only. This is NOT part of the public
        -- economy; the sandbox profile itself is memory-only.
        station(world, "DEV sandbox +25000 credits",
            Vector3.new(-10, 0, -101), function(player)
                local ok = ProfileService.Mutate(player, function(profile)
                    if profile.credits > 9999975000 then return false end
                    profile.credits += 25000
                    return true
                end)
                notify(player, if ok then "Sandbox credits granted (+25000)"
                    else "Sandbox grant unavailable")
            end)
    end

    Players.PlayerRemoving:Connect(function(player)
        lastAction[player.UserId] = nil
    end)
end

return Shop
