--!strict
-- Private player deeds: upgrade home, own shops/rental units, resell to city
-- authority, collect bounded rent. Not a global land registry or P2P exchange.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Districts = require(ReplicatedStorage.Shared:WaitForChild("DistrictConfig"))
local Dynamics = require(ReplicatedStorage.Shared:WaitForChild("DistrictDynamics"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Properties = {}
local cooldown: {[number]: number} = {}
local notice: RemoteEvent

local PRICES = {home = 6500, rental = 12000, shop = 26000}

local function pad(root: Instance, id: string, place: Vector3,
    action: string, callback: (Player) -> ())
    local p = Instance.new("Part")
    p.Name = id
    p.Size = Vector3.new(4.5, 2, 4.5)
    p.Position = place
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(71, 138, 164)
    p.Parent = root
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = action
    prompt.ObjectText = "City Property Agency"
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = p
    prompt.Triggered:Connect(function(player)
        local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 or human.SeatPart
            or player:DistanceFromCharacter(p.Position) > 13
            or not Profile.IsLoaded(player) then return end
        local idNumber = player.UserId
        if os.clock() - (cooldown[idNumber] or 0) < 2 then return end
        cooldown[idNumber] = os.clock()
        local ok, err = pcall(callback, player)
        if not ok then
            warn("[StreetCity] Property interaction failed: " .. tostring(err))
            if player.Parent == Players then
                notice:FireClient(player, "Property status uncertain. Check saved wallet.")
            end
        end
    end)
end

local function tell(player: Player, value: string)
    if player.Parent == Players then notice:FireClient(player, value) end
end

local function id(): string
    return "deed_" .. HttpService:GenerateGUID(false):gsub("-", "")
end

function Properties.Start()
    local root = Instance.new("Folder")
    root.Name = "CityRealEstate"
    root.Parent = workspace:WaitForChild("StreetCityPrototypeWorld")
    notice = ReplicatedStorage.StreetCityRemotes:WaitForChild("GarageNotice") :: RemoteEvent
    for _, district in Districts do
        local base = Vector3.new(math.floor(district.x / 100) * 100,
            2, math.floor(district.z / 100) * 100)
        local name = district.id
        for index, kind in {"home", "rental", "shop"} do
            local location = base + Vector3.new(5 + 8 * index, 0, -10)
            pad(root, name .. "_Buy_" .. kind, location,
                "Buy " .. kind .. " deed", function(player)
                    local economy = Society.GetState(name)
                    if not economy then return end
                    local cost = Dynamics.MarketPrice(PRICES[kind], economy)
                    local operation = id()
                    local success = Profile.Mutate(player, function(profile)
                        return Rules.BuyDeed(profile, kind, cost, operation)
                    end)
                    if success then
                        Society.ApplyAt(base, "business", 1)
                        tell(player, "Bought " .. kind .. " in " .. name
                            .. " for " .. cost .. " credits")
                    else
                        tell(player, "Insufficient funds or property limit reached")
                    end
                end)
        end
        pad(root, name .. "_Sell_Rental", base + Vector3.new(12, 0, 11),
            "Sell rental deed", function(player)
                local data = Society.GetState(name)
                if not data then return end
                local price = math.floor(Dynamics.MarketPrice(PRICES.rental, data) * 0.7)
                local operation = id()
                local success = Profile.Mutate(player, function(account)
                    return Rules.SellDeed(account, "rental", price, operation)
                end)
                tell(player, if success then "Rental sold for " .. price
                    else "No rentable property to sell")
            end)
        pad(root, name .. "_Sell_Shop", base + Vector3.new(20, 0, 11),
            "Sell commercial deed", function(player)
                local data = Society.GetState(name)
                if not data then return end
                local price = math.floor(Dynamics.MarketPrice(PRICES.shop, data) * 0.7)
                local operation = id()
                local success = Profile.Mutate(player, function(account)
                    return Rules.SellDeed(account, "shop", price, operation)
                end)
                tell(player, if success then "Store deed sold for " .. price
                    else "No storefront to sell")
            end)
        pad(root, name .. "_Claim_Rent", base + Vector3.new(29, 0, 11),
            "Collect rent (15m interval)", function(player)
                local data = Profile.Read(player)
                local economy = Society.GetState(name)
                if not data or not economy then return end
                local units = data.realEstate.rental + data.realEstate.shop
                if units < 1 then
                    tell(player, "Own a rental or storefront first")
                    return
                end
                local amount = math.clamp(math.floor(
                    (data.realEstate.rental * 105 + data.realEstate.shop * 170)
                    * economy.propertyIndex / 100), 1, 2000)
                local when = os.time()
                local operation = id()
                local success = Profile.Mutate(player, function(account)
                    return Rules.CollectRent(account, when, amount, operation)
                end)
                tell(player, if success then "Rental income +" .. amount .. " to bank"
                    else "Rent not yet available; one claim per 15 minutes")
            end)
    end
    Players.PlayerRemoving:Connect(function(player) cooldown[player.UserId] = nil end)
    print("[StreetCity] 7 property agencies: player deeds, upgrades and rent")
end

return Properties
