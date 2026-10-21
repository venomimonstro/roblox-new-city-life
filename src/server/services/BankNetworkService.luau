--!strict
-- Three bank branches react to local district confidence. Customer deposits
-- remain in insured player profile; a branch failure closes this branch, not
-- confiscates the player's saved credit balance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Dynamics = require(ReplicatedStorage.Shared:WaitForChild("DistrictDynamics"))
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Banks = {}
local notice: RemoteEvent

local branches = {
    {id="CivicBank", district="downtown", center=Vector3.new(130, 2, 130)},
    {id="HarborSavings", district="port", center=Vector3.new(-800, 2, 850)},
    {id="HighlandCredit", district="luxury", center=Vector3.new(900, 2, -250)},
}

local function tell(player: Player, info: string)
    if player.Parent == Players then notice:FireClient(player, info) end
end

local function stand(parent: Instance, id: string, position: Vector3,
    verb: string, callback: (Player) -> ())
    local p = Instance.new("Part")
    p.Name = id
    p.Size = Vector3.new(7, 2, 7)
    p.Position = position
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(49, 126, 180)
    p.Parent = parent
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = "Insured bank account"
    prompt.ActionText = verb
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.Parent = p
    prompt.Triggered:Connect(function(player)
        local character = player.Character
        local human = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not human or human.Health <= 0 or human.SeatPart or not root
            or not root:IsA("BasePart")
            or (root.Position - position).Magnitude > 13
            or not Profile.IsLoaded(player) then return end
        local ok, err = pcall(callback, player)
        if not ok then warn("[StreetCity] Bank " .. id .. ": " .. tostring(err)) end
    end)
    return p
end

local function operate(player: Player, district: string,
    deposit: boolean, amount: number)
    local state = Society.GetState(district)
    if not state or not Dynamics.BankOperating(state) then
        tell(player, "This branch is closed due to local crime. Try another bank.")
        return
    end
    -- The operation ID is created BEFORE the UpdateAsync transformer.
    local operation = "branch_" .. HttpService:GenerateGUID(false):gsub("-", "")
    local confirmed = Profile.Mutate(player, function(account)
        return Rules.TransferBank(account, amount, deposit, operation)
    end)
    tell(player, if confirmed then (if deposit then "Deposited " else "Withdrawn ")
        .. tostring(amount) .. " credits"
        else "Transaction declined or pending. Check your bank and cash balances.")
end

function Banks.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local root = Instance.new("Folder")
    root.Name = "BankBranches"
    root.Parent = world
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    for _, branch in branches do
        local def = branch
        local account = stand(root, def.id .. "_Balance", def.center, "Check branch", function(player)
            local state = Society.GetState(def.district)
            local profile = Profile.Read(player)
            if not state or not profile then return end
            local status = if Dynamics.BankOperating(state) then "open" else "temporarily closed"
            tell(player, def.id .. " is " .. status .. " | trust " .. state.bankTrust
                .. "/100 | insured balance " .. profile.bankCredits)
        end)
        for _, choice in {
            {action="Deposit", deposit=true, z=-12},
            {action="Withdraw", deposit=false, z=12},
        } do
            stand(root, def.id .. "_" .. choice.action, def.center + Vector3.new(0, 0, choice.z),
                choice.action .. " 500 credits", function(player)
                    operate(player, def.district, choice.deposit, 500)
                end)
        end
        local function recolor()
            local state = Society.GetState(def.district)
            local open = state and Dynamics.BankOperating(state)
            account.Color = if open then Color3.fromRGB(49, 126, 180)
                else Color3.fromRGB(188, 74, 79)
        end
        recolor()
        Society.Changed():Connect(function(id: string)
            if id == def.district then recolor() end
        end)
    end
    print("[StreetCity] Three simulated local bank branches active; deposits remain insured")
end

return Banks
