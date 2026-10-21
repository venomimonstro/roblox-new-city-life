--!strict
-- Stylized GTA-like robbery economy. All prices, cooldowns, vehicle titles
-- and profile mutations are server-owned. No cash can be minted by RemoteEvent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))
local Wanted = require(script.Parent:WaitForChild("WantedService"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Dynamics = require(ReplicatedStorage.Shared:WaitForChild("DistrictDynamics"))
local Crime = {}
local notice: RemoteEvent
local cooldowns: {[string]: number} = {}
local processing: {[Model]: boolean} = {}

local function notify(player: Player, text: string)
    if player.Parent == Players then notice:FireClient(player, text) end
end

local function actionId(prefix: string): string
    return prefix .. "_" .. HttpService:GenerateGUID(false):gsub("-", "")
end

local function stand(parent: Instance, name: string, position: Vector3,
    label: string, verb: string, color: Color3, callback: (Player) -> ())
    local part = Instance.new("Part")
    part.Name = name
    part.Size = Vector3.new(7, 2, 7)
    part.Position = position
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Color = color
    part.Material = Enum.Material.Neon
    part.Parent = parent
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = verb
    prompt.ObjectText = label
    prompt.HoldDuration = 1
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = part
    prompt.Triggered:Connect(function(player)
        local char = player.Character
        local human = char and char:FindFirstChildOfClass("Humanoid")
        if not human or human.Health <= 0 or human.SeatPart
            or player:DistanceFromCharacter(part.Position) > 13
            or not Profile.IsLoaded(player) then return end
        local ok, err = pcall(callback, player)
        if not ok then
            warn("[StreetCity Crime] " .. name .. " failed: " .. tostring(err))
            notify(player, "Operation unavailable. Check your saved balances.")
        end
    end)
end

local function payout(player: Player, units: number, operation: string): boolean
    return Profile.Mutate(player, function(account)
        return Rules.FenceGoods(account, units, operation)
    end)
end

function Crime.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    local root = Instance.new("Folder")
    root.Name = "CrimeAndBank"
    root.Parent = world

    for _, offer in {
        {id="CornerStore", x=130, z=65, units=1, stars=1, time=100},
        {id="MiniMarket", x=-270, z=65, units=2, stars=2, time=160},
        {id="JewelryStore", x=630, z=-165, units=3, stars=3, time=240},
        {id="BankVault", x=-130, z=165, units=4, stars=4, time=320},
    } do
        stand(root, "Rob_" .. offer.id, Vector3.new(offer.x, 2, offer.z),
            offer.id, "Rob (non-graphic)", Color3.fromRGB(168, 65, 83), function(player)
                local key = tostring(player.UserId) .. ":" .. offer.id
                local now = os.clock()
                if now < (cooldowns[key] or 0) then
                    notify(player, "Security is alert; return later")
                    return
                end
                -- Reserve the cooldown BEFORE yielding inside DataStore.UpdateAsync.
                cooldowns[key] = now + offer.time
                local operation = actionId("rob")
                local succeeded = Profile.Mutate(player, function(account)
                    return Rules.StealGoods(account, offer.units, operation)
                end)
                if succeeded then
                    Wanted.AddHeat(player, offer.stars, "shop robbery")
                    notify(player, "Stolen goods +" .. offer.units .. ". Take to a fence.")
                else
                    notify(player, "Bag full or transaction unavailable; check your inventory")
                end
            end)
    end

    for _, bank in {
        {id="deposit500", amount=500, deposit=true, pos=Vector3.new(-92, 2, 45)},
        {id="deposit2000", amount=2000, deposit=true, pos=Vector3.new(-82, 2, 45)},
        {id="withdraw500", amount=500, deposit=false, pos=Vector3.new(-72, 2, 45)},
        {id="withdraw2000", amount=2000, deposit=false, pos=Vector3.new(-62, 2, 45)},
    } do
        stand(root, "Bank_" .. bank.id, bank.pos, "Street City Bank",
            (if bank.deposit then "Deposit " else "Withdraw ") .. bank.amount,
            Color3.fromRGB(55, 123, 184), function(player)
                local key = tostring(player.UserId) .. ":bank"
                if os.clock() - (cooldowns[key] or 0) < 1.5 then return end
                cooldowns[key] = os.clock()
                local economy = Society.StateFor(bank.pos)
                if bank.deposit and economy and not Dynamics.BankOperating(economy) then
                    notify(player, "Branch under financial administration; deposits paused")
                    return
                end
                local op = actionId("bank")
                local ok = Profile.Mutate(player, function(account)
                    return Rules.TransferBank(account, bank.amount, bank.deposit, op)
                end)
                notify(player, if ok then "Bank transaction confirmed"
                    else "Insufficient cash/bank balance or unavailable")
            end)
    end

    -- Separate branded branches share a protected customer escrow ledger.
    -- A bankrupt *branch* temporarily stops accepting deposits, but cannot
    -- erase a player's insured bankCredits. Withdrawals stay possible elsewhere.
    for _, branch in {
        {id="Civic", pos=Vector3.new(920, 2, -310), amount=500},
        {id="Industrial", pos=Vector3.new(-820, 2, 810), amount=1000},
        {id="Private", pos=Vector3.new(520, 2, -1250), amount=2000},
    } do
        for _, deposit in {true, false} do
            stand(root, "Bank_" .. branch.id .. (if deposit then "_Deposit" else "_Withdraw"),
                branch.pos + Vector3.new(if deposit then -6 else 6, 0, 0),
                branch.id .. " District Bank",
                (if deposit then "Deposit " else "Withdraw ") .. branch.amount,
                Color3.fromRGB(52, 122, 176), function(player)
                    local economy = Society.StateFor(branch.pos)
                    if deposit and economy and not Dynamics.BankOperating(economy) then
                        notify(player, "Branch closed from district financial instability")
                        return
                    end
                    local operation = actionId("bank")
                    local ok = Profile.Mutate(player, function(account)
                        return Rules.TransferBank(account, branch.amount, deposit, operation)
                    end)
                    notify(player, if ok then "Insured account transfer confirmed"
                        else "Insufficient balance or service unavailable")
                end)
        end
    end

    stand(root, "FenceGoods", Vector3.new(-165, 2, -155), "Backstreet Fence",
        "Sell stolen goods", Color3.fromRGB(130, 98, 160), function(player)
            local current = Profile.Read(player)
            if not current or current.stolenGoods < 1 then
                notify(player, "You have no stolen goods")
                return
            end
            local units = math.min(10, current.stolenGoods)
            local ok = payout(player, units, actionId("goods"))
            notify(player, if ok then "Goods sold +" .. (units * 180) .. " cash"
                else "Fence rejected transaction; verify inventory")
        end)

    stand(root, "FenceVehicles", Vector3.new(-180, 2, -155), "Vehicle Fence",
        "Sell stolen parked car", Color3.fromRGB(102, 81, 134), function(player)
            local vehicles = workspace:FindFirstChild("ActiveVehicles")
            if not vehicles then return end
            local best: Model? = nil
            local distance = 34
            for _, model in vehicles:GetChildren() do
                if model:IsA("Model")
                    and model:GetAttribute("StolenVehicle") == true
                    and model:GetAttribute("IsPolice") ~= true
                    and model:GetAttribute("ThiefUserId") == player.UserId
                    and not model:GetAttribute("FenceSold")
                    and model.PrimaryPart then
                    local current = (model.PrimaryPart.Position
                        - Vector3.new(-180, 2, -155)).Magnitude
                    local seat = model:FindFirstChild("DriverSeat")
                    if current < distance and seat and seat:IsA("VehicleSeat")
                        and seat.Occupant == nil
                        and model.PrimaryPart.AssemblyLinearVelocity.Magnitude < 3 then
                        best = model
                        distance = current
                    end
                end
            end
            if not best then
                notify(player, "Park an unoccupied stolen civilian car next to the fence")
                return
            end
            if processing[best] then return end
            processing[best] = true
            local op = best:GetAttribute("FenceOperationId")
            if type(op) ~= "string" then
                op = actionId("stolencar")
                best:SetAttribute("FenceOperationId", op)
            end
            local payoutAmount = 1150
            if best:GetAttribute("VehicleCatalogId") == "sport_sedan" then
                payoutAmount = 1750
            elseif best:GetAttribute("VehicleCatalogId") == "street_coupe" then
                payoutAmount = 1450
            end
            local confirmed = Profile.Mutate(player, function(account)
                return Rules.AwardCredits(account, payoutAmount, op)
            end)
            if confirmed then
                best:SetAttribute("FenceSold", true)
                VehicleService.DespawnByModel(best)
                notify(player, "Stolen car sold: +" .. payoutAmount .. " cash")
            else
                notify(player, "Sale unresolved; do not leave until balance is verified")
            end
            processing[best] = nil
        end)
    Players.PlayerRemoving:Connect(function(player)
        local prefix = tostring(player.UserId) .. ":"
        for key in pairs(cooldowns) do
            if string.sub(key, 1, #prefix) == prefix then cooldowns[key] = nil end
        end
    end)
    print("[StreetCity] Bank, stores, robberies, stolen goods and vehicle fences active")
end

return Crime
