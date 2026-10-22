--!strict
-- Stylized boxing career: bags -> skill levels -> NPC bouts.
-- The client selects a punch style only; targets, distance, scoring, and
-- payout are wholly checked on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Wallet = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Progress = require(ReplicatedStorage.Shared:WaitForChild("SkillProgression"))
local Boxing = {}
local sessions: {[number]: any} = {}
local cooldowns: {[number]: number} = {}
local bagCooldown: {[number]: number} = {}
local remote: RemoteEvent
local notice: RemoteEvent
local ROUNDS = 3
local ROUND_SECONDS = 18
local STYLES: {[string]: any} = {
    jab = {points=1, cooldown=0.45, xp=8},
    hook = {points=2, cooldown=1.1, xp=11},
    uppercut = {points=3, cooldown=1.6, xp=13},
}
local ARENA = Vector3.new(260, 2, -440)
local function tell(player: Player, value: string)
    if player.Parent == Players then notice:FireClient(player, value) end
end
local function rootFor(player: Player): BasePart?
    local char = player.Character
    local human = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not human or human.Health <= 0 or human.SeatPart
        or not root or not root:IsA("BasePart") then return nil end
    return root
end
local function object(parent: Instance, name: string, size: Vector3,
    pos: Vector3, color: Color3, collide: boolean): Part
    local p = Instance.new("Part")
    p.Name, p.Size, p.Position = name, size, pos
    p.Anchored = true
    p.CanCollide = collide
    p.CanQuery = collide
    p.CanTouch = false
    p.Color, p.Material = color, Enum.Material.SmoothPlastic
    p.Parent = parent
    return p
end
local function prompt(part: Part, label: string, action: string, callback: (Player)->())
    local p = Instance.new("ProximityPrompt")
    p.ObjectText, p.ActionText = label, action
    p.MaxActivationDistance = 10
    p.RequiresLineOfSight = false
    p.Parent = part
    p.Triggered:Connect(function(player: Player)
        local root = rootFor(player)
        if not root or (root.Position - part.Position).Magnitude > 12
            or not Profile.IsLoaded(player) then return end
        local safe, err = pcall(callback, player)
        if not safe then warn("[StreetCity] Boxing prompt: " .. tostring(err)) end
    end)
end
local function clear(player: Player, reason: string)
    sessions[player.UserId] = nil
    remote:FireClient(player, false)
    if reason ~= "" then tell(player, reason) end
end
local function bagTraining(player: Player, style: string)
    local now = os.clock()
    if now - (bagCooldown[player.UserId] or -100) < 1.2 then return end
    local root = rootFor(player)
    if not root or (root.Position - (ARENA + Vector3.new(-35,0,0))).Magnitude > 12 then return end
    bagCooldown[player.UserId] = now
    -- Training awards XP without money; a second server call cannot mint cash.
    local success = Profile.Mutate(player, function(profile)
        return Progress.Earn(profile, "boxing", STYLES[style].xp)
    end)
    if success then
        local data = Profile.Read(player)
        local level = data and Progress.Level(Progress.Xp(data, "boxing")) or 1
        remote:FireClient(player, "bag", level, 0, 0)
    end
end
local function conclude(player: Player, match: any)
    if sessions[player.UserId] ~= match or match.settling then return end
    match.settling = true
    local won = match.total >= 27 and match.wonRounds == ROUNDS
    if not won then
        clear(player, "Boxing bout lost. Train punches at the bag and try again.")
        cooldowns[player.UserId] = os.clock() + 12
        return
    end
    local amount = 260
    local operation = match.operation
    task.spawn(function()
        local paid = Profile.Mutate(player, function(profile)
            local skill = Progress.Xp(profile, "boxing")
            local wage = Progress.Wage(amount, skill)
            if not Wallet.AwardCredits(profile, wage, operation) then return false end
            Progress.Earn(profile, "boxing", 110)
            Progress.Conduct(profile, 1)
            match.reward = wage
            return true
        end)
        if sessions[player.UserId] ~= match then return end
        clear(player, if paid then ("Boxing win: +" .. tostring(match.reward or amount)
            .. " cash. Professional experience gained!")
            else "Boxing payout unconfirmed; verify your balance.")
        cooldowns[player.UserId] = os.clock() + 40
    end)
end
local function punch(player: Player, style: string)
    local def = STYLES[style]
    if not def then return end
    local match = sessions[player.UserId]
    if not match then
        bagTraining(player, style)
        return
    end
    if match.settling then return end
    local root = rootFor(player)
    if not root or (root.Position - ARENA).Magnitude > 17 then
        clear(player, "You left the boxing ring; bout ended.")
        return
    end
    local now = os.clock()
    if now - (match.lastPunch or -100) < def.cooldown then return end
    match.lastPunch = now
    local round = math.floor((now - match.started) / ROUND_SECONDS) + 1
    if round > ROUNDS then conclude(player, match) return end
    if round ~= match.round then
        if match.roundScore >= 9 and match.distinct >= 2 then
            match.wonRounds += 1
        end
        match.round, match.roundScore, match.distinct = round, 0, 0
        match.used = {}
    end
    -- NPC counters periodically. No real violence/knockout animation.
    local block = math.floor((now - match.started) / 4) % 3
    local styleIndex = if style == "jab" then 0 elseif style == "hook" then 1 else 2
    if block == styleIndex then
        tell(player, "NPC blocked " .. style .. "! Mix your punches.")
        return
    end
    if not match.used[style] then match.distinct += 1 end
    match.used[style] = true
    match.roundScore += def.points
    match.total += def.points
    remote:FireClient(player, "bout", round, match.roundScore, match.total)
end
function Boxing.Start()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local folder = Instance.new("Folder")
    folder.Name = "BoxingAcademy"
    folder.Parent = world
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    remote = Instance.new("RemoteEvent")
    remote.Name = "StreetCityBoxingAction"
    remote.Parent = ReplicatedStorage
    local floor = object(folder, "TrainingRing", Vector3.new(32,0.5,32),
        ARENA + Vector3.new(0,-1.1,0), Color3.fromRGB(52,88,133), true)
    floor.Material = Enum.Material.Fabric
    local coach = object(folder, "BoxingCoach", Vector3.new(2,5,2),
        ARENA + Vector3.new(0,2,0), Color3.fromRGB(156,88,65), false)
    object(folder, "RingOpponent", Vector3.new(2,4,1),
        ARENA + Vector3.new(0,1,5), Color3.fromRGB(190,120,87), false)
    local bag = object(folder, "PunchingBag", Vector3.new(2,4,2),
        ARENA + Vector3.new(-35,2,0), Color3.fromRGB(167,57,62), false)
    prompt(coach, "Boxing League", "Challenge NPC", function(player)
        if sessions[player.UserId] or os.clock() < (cooldowns[player.UserId] or 0) then return end
        local data = Profile.Read(player)
        if not data or Progress.Level(Progress.Xp(data, "boxing")) < 3 then
            tell(player, "Train boxing to level 3 on the punching bag first.")
            return
        end
        sessions[player.UserId] = {
            started=os.clock(), round=1, roundScore=0,
            wonRounds=0, distinct=0, used={}, total=0,
            operation="boxing_" .. HttpService:GenerateGUID(false):gsub("-", ""),
        }
        remote:FireClient(player, "bout", 1, 0, 0)
        tell(player, "NPC fight started: 3 rounds, 18 seconds each. Mix jab, hook, uppercut.")
    end)
    prompt(bag, "Boxing Practice", "Train punches", function(player)
        local data = Profile.Read(player)
        if data then
            tell(player, "Train with J (jab), K (hook), U (uppercut), or mobile buttons. Boxing level "
                .. Progress.Level(Progress.Xp(data,"boxing")))
        end
    end)
    remote.OnServerEvent:Connect(function(player: Player, style: any)
        if type(style) ~= "string" or not STYLES[style]
            or not Profile.IsLoaded(player) then return end
        punch(player, style)
    end)
    task.spawn(function()
        while true do
            task.wait(1)
            local now = os.clock()
            for userId, match in pairs(sessions) do
                if now - match.started >= ROUNDS * ROUND_SECONDS then
                    local player = Players:GetPlayerByUserId(userId)
                    if player then
                        if match.roundScore >= 9 and match.distinct >= 2 then
                            match.wonRounds += 1
                        end
                        conclude(player, match)
                    else sessions[userId] = nil end
                end
            end
        end
    end)
    local function onPlayer(player: Player)
        player.CharacterAdded:Connect(function(char)
            local human = char:WaitForChild("Humanoid", 10)
            if human and human:IsA("Humanoid") then
                human.Died:Connect(function()
                    if sessions[player.UserId] then clear(player, "") end
                end)
            end
        end)
    end
    Players.PlayerAdded:Connect(onPlayer)
    for _, p in Players:GetPlayers() do onPlayer(p) end
    Players.PlayerRemoving:Connect(function(player)
        sessions[player.UserId] = nil
        cooldowns[player.UserId] = nil
        bagCooldown[player.UserId] = nil
    end)
    print("[StreetCity] NPC boxing league, bag training and three punch styles ready")
end
return Boxing
