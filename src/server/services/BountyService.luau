--!strict
-- Server-only bounty resolution. Posters publish public in-game username, avatar
-- id and stars. NO client request can submit a kill or claim a reward.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Wanted = require(script.Parent:WaitForChild("WantedService"))
local Crew = require(script.Parent:WaitForChild("CrewService"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Economy = require(ReplicatedStorage.Shared:WaitForChild("LifeEconomy"))
local Bounties = {}
local posterRemote: RemoteEvent
local notice: RemoteEvent
local spawnedAt: {[number]: number} = {}
local victimCooldown: {[number]: number} = {}
local pairCooldown: {[string]: number} = {}
local dividendCooldown: {[number]: number} = {}
local settling: {[number]: boolean} = {}

local function reward(stars: number): number
    return 320 + stars * 200
end

local function posterList(): {any}
    local results = {}
    for _, player in Players:GetPlayers() do
        if Wanted.IsBountyEligible(player) then
            local stars = Wanted.GetLevel(player)
            table.insert(results, {
                userId = player.UserId, username = player.Name,
                displayName = player.DisplayName,
                stars = stars, credits = reward(stars),
            })
        end
    end
    table.sort(results, function(a, b)
        return a.stars > b.stars
    end)
    while #results > 10 do table.remove(results) end
    return results
end

function Bounties.ResolveDeath(victim: Player, human: Humanoid,
    stars: number, eligibleAtDeath: boolean)
    local id = victim.UserId
    if settling[id] or not eligibleAtDeath or stars < 3 or stars > 5 then return end
    local now = os.clock()
    if now - (spawnedAt[id] or now) < 120
        or now - (victimCooldown[id] or -10000) < 1200 then return end
    local attackerId = human:GetAttribute("StreetCityBountyAttacker")
    local taggedAt = human:GetAttribute("StreetCityBountyHitAt")
    if type(attackerId) ~= "number" or type(taggedAt) ~= "number"
        or now - taggedAt > 12 then return end
    local hunter = Players:GetPlayerByUserId(attackerId)
    if not hunter or hunter == victim or Crew.SameCrew(hunter, victim)
        or not Profile.IsLoaded(hunter) then return end
    local hunterHumanoid = hunter.Character and hunter.Character:FindFirstChildOfClass("Humanoid")
    if not hunterHumanoid or hunterHumanoid.Health <= 0 then return end
    if Wanted.GetLevel(hunter) > 1 then return end
    local pairKey = tostring(attackerId) .. ":" .. tostring(id)
    if now - (pairCooldown[pairKey] or -10000) < 1800 then return end
    settling[id] = true
    pairCooldown[pairKey] = now
    victimCooldown[id] = now
    -- Stable window key helps the profile journal reject repeated payouts
    -- after reconnecting to another server within the same half-hour.
    local op = "bounty_" .. tostring(id) .. "_" .. tostring(math.floor(os.time() / 1800))
    local paidAt = os.time()
    local success = Profile.Mutate(hunter, function(profile)
        return Economy.BountyReward(profile, stars, op, id, paidAt)
    end)
    if success then
        if hunter.Parent == Players then
            notice:FireClient(hunter,
                "Bounty confirmed on " .. victim.DisplayName .. ": +"
                .. tostring(reward(stars)) .. " BANK credits")
        end
        local root = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
        local district = root and root:IsA("BasePart") and Society.Resolve(root.Position) or "downtown"
        if root and root:IsA("BasePart") then
            Society.ApplyAt(root.Position, "security", 2)
        end
        -- Passive investors only profit from a real, verified bounty; capped
        -- to one payment per investor per 10 minutes, only while online.
        for _, investor in Players:GetPlayers() do
            if investor ~= victim and investor ~= hunter
                and not Crew.SameCrew(investor, victim)
                and Profile.IsLoaded(investor)
                and now - (dividendCooldown[investor.UserId] or -10000) >= 600 then
                local portfolio = Profile.Read(investor)
                if portfolio and (portfolio.securityBonds[district] or 0) > 0 then
                    dividendCooldown[investor.UserId] = now
                    local dividendOp = "security_" .. district
                        .. "_" .. tostring(math.floor(os.time() / 600))
                    local dividendAt = os.time()
                    local paid = Profile.Mutate(investor, function(profile)
                        return Economy.SecurityDividend(profile, district, dividendOp, dividendAt)
                    end)
                    if paid then
                        notice:FireClient(investor, "District safety dividend credited to your bank")
                    end
                end
            end
        end
    else
        warn("[StreetCity] Bounty settlement not confirmed for " .. tostring(hunter.UserId))
    end
    settling[id] = nil
end

function Bounties.Start()
    posterRemote = Instance.new("RemoteEvent")
    posterRemote.Name = "StreetCityWantedPosters"
    posterRemote.Parent = ReplicatedStorage
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local board = Instance.new("Part")
    board.Name = "PoliceBountyBoard"
    board.Anchored = true
    board.CanCollide = false
    board.CanTouch = false
    board.CanQuery = false
    board.Material = Enum.Material.Neon
    board.Color = Color3.fromRGB(45, 113, 189)
    board.Size = Vector3.new(8, 4, 1)
    board.Position = Vector3.new(155, 4, 28)
    board.Parent = world
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "View wanted residents"
    prompt.ObjectText = "Street City Police — Bounties"
    prompt.RequiresLineOfSight = false
    prompt.MaxActivationDistance = 11
    prompt.Parent = board
    prompt.Triggered:Connect(function(player)
        local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if human and human.Health > 0 and not human.SeatPart
            and player:DistanceFromCharacter(board.Position) <= 14 then
            posterRemote:FireClient(player, posterList())
        end
    end)
    local function joined(player: Player)
        spawnedAt[player.UserId] = os.clock()
    end
    Players.PlayerAdded:Connect(joined)
    for _, player in Players:GetPlayers() do joined(player) end
    local funding = Instance.new("Part")
    funding.Name = "DistrictSecurityShares"
    funding.Anchored = true
    funding.CanCollide = false
    funding.CanQuery = false
    funding.CanTouch = false
    funding.Size = Vector3.new(6, 2, 4)
    funding.Material = Enum.Material.Neon
    funding.Color = Color3.fromRGB(56, 163, 110)
    funding.Position = Vector3.new(164, 2, 28)
    funding.Parent = world
    local finance = Instance.new("ProximityPrompt")
    finance.ObjectText = "City Security Fund"
    finance.ActionText = "Invest 1250 credits"
    finance.MaxActivationDistance = 10
    finance.RequiresLineOfSight = false
    finance.Parent = funding
    finance.Triggered:Connect(function(player: Player)
        local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not human or human.Health <= 0 or human.SeatPart or not root
            or not root:IsA("BasePart") or not Profile.IsLoaded(player)
            or (root.Position - funding.Position).Magnitude > 13 then return end
        local district = Society.Resolve(root.Position)
        local operation = "safety_" .. HttpService:GenerateGUID(false):gsub("-", "")
        local ok = Profile.Mutate(player, function(profile)
            return Economy.InvestSafety(profile, district, operation)
        end)
        if ok then
            Society.EffectForPlayer(player, "security", 3)
            notice:FireClient(player,
                "District safety stake purchased. Eligible confirmed arrests may earn BANK dividends.")
        else
            notice:FireClient(player, "Insufficient cash or safety stake limit reached (3 per district)")
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        spawnedAt[player.UserId] = nil
        victimCooldown[player.UserId] = nil
        settling[player.UserId] = nil
        dividendCooldown[player.UserId] = nil
        -- Pair cooldowns intentionally survive reconnects in the same server.
    end)
    print("[StreetCity] Wanted posters and verified on-defeat bounties active")
end

return Bounties
