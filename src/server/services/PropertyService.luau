--!strict
-- Instanced deeds and two banking models. Existing insured bank is unchanged.
-- Community bank may suspend NEW deposits as district trust falls, but never
-- deletes player balances; withdrawals stay available.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Properties = require(ReplicatedStorage.Shared:WaitForChild("PropertyCatalog"))
local Dynamics = require(ReplicatedStorage.Shared:WaitForChild("DistrictDynamics"))
local Transactions = require(ReplicatedStorage.Shared:WaitForChild("PropertyTransactions"))
local Money = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local PropertyService = {}
local notice: RemoteEvent
local lastAction: {[number]: number} = {}

local function tell(player: Player, msg: string)
    if player.Parent == Players then notice:FireClient(player, msg) end
end

local function operation(): string
    return "estate_" .. HttpService:GenerateGUID(false):gsub("-", "")
end

local function site(parent: Instance, name: string, pos: Vector3,
    label: string, action: string, color: Color3, callback: (Player) -> ())
    local pad = Instance.new("Part")
    pad.Name = name
    pad.Anchored = true
    pad.CanCollide = false
    pad.CanQuery = false
    pad.CanTouch = false
    pad.Size = Vector3.new(6, 0.9, 6)
    pad.Position = pos
    pad.Material = Enum.Material.Neon
    pad.Color = color
    pad.Parent = parent
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = label
    prompt.ActionText = action
    prompt.MaxActivationDistance = 11
    prompt.RequiresLineOfSight = false
    prompt.Parent = pad
    prompt.Triggered:Connect(function(player: Player)
        local character = player.Character
        local human = character and character:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 or human.SeatPart
            or player:DistanceFromCharacter(pad.Position) > 13
            or not Profile.IsLoaded(player) then return end
        local now = os.clock()
        if now - (lastAction[player.UserId] or 0) < 1.3 then return end
        lastAction[player.UserId] = now
        local ok, err = pcall(callback, player)
        if not ok then
            warn("[StreetCity] Property interaction failed: " .. tostring(err))
            tell(player, "Property service unavailable; check your balances")
        end
    end)
    return prompt
end

local propertiesByDistrict = {
    {id="downtown_flat", pos=Vector3.new(25, 2, 450)},
    {id="luxury_penthouse", pos=Vector3.new(850, 2, -420)},
    {id="oldtown_shop", pos=Vector3.new(-850, 2, 250)},
    {id="port_warehouse", pos=Vector3.new(-850, 2, 680)},
    {id="village_home", pos=Vector3.new(1050, 2, 920)},
    {id="mountain_cabin", pos=Vector3.new(550, 2, -1170)},
    {id="coast_kiosk", pos=Vector3.new(25, 2, 1090)},
}

function PropertyService.Start()
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    local root = Instance.new("Folder")
    root.Name = "DistrictProperties"
    root.Parent = workspace:WaitForChild("StreetCityPrototypeWorld")
    for _, location in propertiesByDistrict do
        local id = location.id
        local offer = Properties[id]
        local origin = location.pos
        local state = Society.GetState(offer.district)
        if not state then error("Missing property district " .. offer.district) end
        local buyPrompt = site(root, "Buy_" .. id, origin, id,
            "Buy from municipality", Color3.fromRGB(85, 165, 140), function(player)
                local current = Society.GetState(offer.district)
                if not current then return end
                local price = Dynamics.MarketPrice(offer.basePrice, current)
                local op = operation()
                local ok = Profile.Mutate(player, function(data)
                    return Transactions.Buy(data, id, price, op)
                end)
                if ok then
                    Society.ApplyAt(origin, "business", 1)
                    tell(player, id .. " purchased for " .. price .. " cash")
                else
                    tell(player, "Purchase rejected: deed owned or cash insufficient")
                end
            end)
        buyPrompt.ObjectText = id .. " (market from " .. offer.basePrice .. ")"
        site(root, "Lease_" .. id, origin + Vector3.new(8, 0, 0), id,
            "Toggle tenant", Color3.fromRGB(81, 139, 201), function(player)
                local current = Profile.Read(player)
                local deed = current and current.ownedProperties[id]
                if not deed then tell(player, "Buy this deed first") return end
                local desired = not deed.rented
                local stamp = os.time()
                local ok = Profile.Mutate(player, function(data)
                    return Transactions.SetRental(data, id, desired, stamp)
                end)
                tell(player, if ok then (if desired then "Rented out" else "Lease ended")
                    else "Lease state was not changed")
            end)
        site(root, "RentCollect_" .. id, origin + Vector3.new(16, 0, 0),
            id, "Collect rent", Color3.fromRGB(101, 185, 111), function(player)
                local op = operation()
                local stamp = os.time()
                local ok = Profile.Mutate(player, function(data)
                    return Transactions.CollectRent(data, id, stamp, op)
                end)
                tell(player, if ok then "+" .. offer.rent .. " rent collected"
                    else "Rent not yet due / tenancy inactive")
            end)
        site(root, "Sell_" .. id, origin + Vector3.new(24, 0, 0), id,
            "Sell deed to city", Color3.fromRGB(163, 126, 98), function(player)
                local op = operation()
                local ok = Profile.Mutate(player, function(data)
                    return Transactions.SellToCity(data, id, op)
                end)
                tell(player, if ok then "Deed sold; cash credited"
                    else "You do not own this property")
            end)
        site(root, "Invest_" .. id, origin + Vector3.new(32, 0, 0), id,
            "Sponsor district · 500 cash", Color3.fromRGB(83, 191, 159),
            function(player)
                local op = operation()
                local ok = Profile.Mutate(player, function(data)
                    return Money.SpendCredits(data, 500, op)
                end)
                if ok then
                    Society.ApplyAt(origin, "civic", 2)
                    tell(player, "District prosperity and safety improved")
                else
                    tell(player, "Investment denied; check cash")
                end
            end)
        site(root, "Police_" .. id, origin + Vector3.new(40, 0, 0), id,
            "Fund local police · 650 cash", Color3.fromRGB(72, 130, 208),
            function(player)
                local op = operation()
                local ok = Profile.Mutate(player, function(data)
                    return Money.SpendCredits(data, 650, op)
                end)
                if ok then
                    Society.ApplyAt(origin, "security", 3)
                    tell(player, "Patrol funding increased local safety")
                else
                    tell(player, "Funding unavailable; check cash")
                end
            end)
        site(root, "BankSave_" .. id, origin + Vector3.new(48, 0, 0), id,
            "Community bank deposit · 500", Color3.fromRGB(108, 134, 190),
            function(player)
                local stateNow = Society.GetState(offer.district)
                if not stateNow or not Dynamics.BankOperating(stateNow) then
                    tell(player, "Local bank under resolution: deposits temporarily suspended")
                    return
                end
                local op = operation()
                local ok = Profile.Mutate(player, function(data)
                    return Transactions.CommunityBank(data, 500, true, op)
                end)
                tell(player, if ok then "Deposited 500 in community bank"
                    else "Bank deposit failed; check wallet")
            end)
        site(root, "BankWithdraw_" .. id, origin + Vector3.new(56, 0, 0), id,
            "Community bank withdrawal · 500", Color3.fromRGB(162, 148, 210),
            function(player)
                -- Even when a branch fails, insured player money remains accessible.
                local op = operation()
                local ok = Profile.Mutate(player, function(data)
                    return Transactions.CommunityBank(data, 500, false, op)
                end)
                tell(player, if ok then "500 returned from community account"
                    else "Withdrawal unavailable; check account")
            end)
    end
    Players.PlayerRemoving:Connect(function(player)
        lastAction[player.UserId] = nil
    end)
    print("[StreetCity] 7 district property markets, local banks and civic financing active")
end

return PropertyService
