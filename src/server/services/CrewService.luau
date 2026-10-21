--!strict
-- Session-only player crews. Invitation acceptance is explicit and server-only.
-- Persistent, cross-server federations require a separate title/membership ledger.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Society = require(script.Parent:WaitForChild("DistrictSocietyService"))
local Rules = require(ReplicatedStorage.Shared:WaitForChild("GarageTransactions"))
local Crew = {}
local groups: {[string]: any} = {}
local membership: {[number]: string} = {}
local applicants: {[string]: {number}} = {}
local lastAction: {[number]: number} = {}
local notice: RemoteEvent
local root: Folder
local slots = 0
local anchors = {
    gang = Vector3.new(-260, 2, -260),
    federal = Vector3.new(260, 2, -260),
}

local function say(player: Player, value: string)
    if player.Parent == Players then notice:FireClient(player, value) end
end

local function eligible(player: Player, part: BasePart): boolean
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart
        or player:DistanceFromCharacter(part.Position) > 14
        or not Profile.IsLoaded(player) then return false end
    local t = os.clock()
    if t - (lastAction[player.UserId] or 0) < 1.7 then return false end
    lastAction[player.UserId] = t
    return true
end

local function pad(parent: Instance, name: string, pos: Vector3, action: string,
    color: Color3, callback: (Player, BasePart) -> ())
    local item = Instance.new("Part")
    item.Name = name
    item.Anchored = true
    item.Size = Vector3.new(6, 1, 6)
    item.Position = pos
    item.CanCollide = false
    item.CanQuery = false
    item.CanTouch = false
    item.Material = Enum.Material.Neon
    item.Color = color
    item.Parent = parent
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = name
    prompt.ActionText = action
    prompt.MaxActivationDistance = 11
    prompt.RequiresLineOfSight = false
    prompt.Parent = item
    prompt.Triggered:Connect(function(player: Player)
        if not eligible(player, item) then return end
        local ok, err = pcall(callback, player, item)
        if not ok then warn("[StreetCity] Crew interaction failed: " .. tostring(err)) end
    end)
end

local function groupFor(typeId: string): any?
    local best = nil
    for _, group in pairs(groups) do
        if group.typeId == typeId and #group.members < 8 then
            if not best or #group.members < #best.members then best = group end
        end
    end
    return best
end

local function memberCount(group: any): number
    return #group.members
end

local function removeMember(userId: number)
    local id = membership[userId]
    if not id then return end
    local group = groups[id]
    membership[userId] = nil
    if not group then return end
    for index = #group.members, 1, -1 do
        if group.members[index] == userId then table.remove(group.members, index) end
    end
    if group.owner == userId or memberCount(group) == 0 then
        for _, memberId in group.members do
            membership[memberId] = nil
            local other = Players:GetPlayerByUserId(memberId)
            if other then say(other, "Your crew has been dissolved") end
        end
        if group.hired then group.hired:Destroy() end
        groups[id] = nil
        applicants[id] = nil
    end
end

local function hireNpc(group: any, player: Player)
    if group.owner ~= player.UserId or group.hires >= 3 then
        say(player, "Only the leader may hire up to 3 escorts")
        return
    end
    local operation = "crew_" .. HttpService:GenerateGUID(false):gsub("-", "")
    local paid = Profile.Mutate(player, function(data)
        return Rules.SpendCredits(data, 650, operation)
    end)
    if not paid then
        say(player, "Not enough cash or account unavailable")
        return
    end
    group.hires += 1
    local base = group.anchor
    if not group.hired then
        group.hired = Instance.new("Folder")
        group.hired.Name = "CrewNPC_" .. group.id
        group.hired.Parent = root
    end
    local model = Instance.new("Model")
    model.Name = group.typeId == "federal" and "Guard" or "OutlawEscort"
    model:SetAttribute("GroupId", group.id)
    model:SetAttribute("ContractStatus", "on-duty")
    local block = Instance.new("Part")
    block.Name = "Body"
    block.Size = Vector3.new(2, 4, 1.5)
    block.Anchored = true
    block.CanCollide = false
    block.CanQuery = false
    block.Position = base + Vector3.new(group.hires * 5, 2, 9)
    block.Color = if group.typeId == "federal"
        then Color3.fromRGB(52, 84, 165) else Color3.fromRGB(112, 65, 84)
    block.Parent = model
    model.PrimaryPart = block
    model.Parent = group.hired
    Society.ApplyAt(group.anchor, if group.typeId == "federal" then "security" else "crime", 2)
    say(player, "Contractor hired. Local influence updated.")
end

function Crew.Start()
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    root = Instance.new("Folder")
    root.Name = "CityCrews"
    root.Parent = workspace:WaitForChild("StreetCityPrototypeWorld")
    for _, typeId in {"gang", "federal"} do
        local point = anchors[typeId]
        local color = if typeId == "federal"
            then Color3.fromRGB(52, 115, 183) else Color3.fromRGB(174, 70, 110)
        pad(root, "Form_" .. typeId, point, "Form crew", color, function(player)
            local snapshot = Profile.Read(player)
            local side = if typeId == "gang" then "outlaw" else "law"
            if not snapshot or snapshot.allegiance ~= side then
                say(player, "Choose the matching faction at its registry before forming a crew")
                return
            end
            if membership[player.UserId] then say(player, "Leave your current crew first") return end
            local targetSide = if typeId == "federal" then "law" else "outlaw"
            local snapshot = Profile.Read(player)
            if not snapshot then return end
            if snapshot.allegiance ~= targetSide then
                local chosenAt = os.time()
                local changed = Profile.Mutate(player, function(data)
                    return Rules.SetAllegiance(data, targetSide, chosenAt)
                end)
                if not changed then
                    say(player, "Faction change denied; wait 15 minutes or dismiss conflicting companions")
                    return
                end
            end
            slots += 1
            local id = typeId .. "_" .. tostring(slots)
            groups[id] = {id=id, typeId=typeId, owner=player.UserId,
                anchor=point, members={player.UserId}, hires=0}
            membership[player.UserId] = id
            applicants[id] = {}
            say(player, "Created " .. typeId .. " crew. Players can request membership here.")
        end)
        pad(root, "Apply_" .. typeId, point + Vector3.new(9, 0, 0),
            "Apply to join", color, function(player)
                local snapshot = Profile.Read(player)
                if not snapshot or snapshot.allegiance ~= (if typeId == "gang" then "outlaw" else "law") then
                    say(player, "Your saved faction must match this crew")
                    return
                end
                if membership[player.UserId] then return end
                local group = groupFor(typeId)
                if not group then say(player, "No crew recruiting in this city") return end
                for _, applicant in applicants[group.id] do
                    if applicant == player.UserId then return end
                end
                table.insert(applicants[group.id], player.UserId)
                say(player, "Application submitted; leader must accept")
                local leader = Players:GetPlayerByUserId(group.owner)
                if leader then say(leader, "Applicant waiting at your crew HQ") end
            end)
        pad(root, "Approve_" .. typeId, point + Vector3.new(18, 0, 0),
            "Approve applicant", color, function(player)
                local groupId = membership[player.UserId]
                local group = groupId and groups[groupId]
                if not group or group.owner ~= player.UserId or group.typeId ~= typeId then return end
                if #group.members >= 8 then say(player, "Crew at capacity") return end
                local queue = applicants[groupId]
                while queue and #queue > 0 do
                    local applicantId = table.remove(queue, 1)
                    local target = Players:GetPlayerByUserId(applicantId)
                    if target and not membership[applicantId] then
                        local desired = if typeId == "federal" then "law" else "outlaw"
                        local profile = Profile.Read(target)
                        if not profile then continue end
                        if profile.allegiance ~= desired then
                            local chosenAt = os.time()
                            local changed = Profile.Mutate(target, function(data)
                                return Rules.SetAllegiance(data, desired, chosenAt)
                            end)
                            if not changed then
                                say(target, "Faction cooldown or companion conflict; cannot join")
                                continue
                            end
                        end
                        table.insert(group.members, applicantId)
                        membership[applicantId] = groupId
                        say(target, "Accepted into " .. typeId .. " crew")
                        say(player, "New member accepted")
                        return
                    end
                end
                say(player, "No pending applicants")
            end)
        pad(root, "Hire_" .. typeId, point + Vector3.new(27, 0, 0),
            "Hire NPC escort · 650 cash", color, function(player)
                local groupId = membership[player.UserId]
                local group = groupId and groups[groupId]
                if group and group.typeId == typeId then hireNpc(group, player) end
            end)
        pad(root, "Leave_" .. typeId, point + Vector3.new(36, 0, 0),
            "Leave / disband crew", color, function(player)
                removeMember(player.UserId)
            end)
    end
    Players.PlayerRemoving:Connect(function(player)
        removeMember(player.UserId)
        lastAction[player.UserId] = nil
        for _, queue in pairs(applicants) do
            for n = #queue, 1, -1 do
                if queue[n] == player.UserId then table.remove(queue, n) end
            end
        end
    end)
    print("[StreetCity] Player-driven session crews and NPC escorts initialized")
end

return Crew
