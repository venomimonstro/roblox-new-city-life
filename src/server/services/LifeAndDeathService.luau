--!strict
-- Persistent death settlement; cash stored at home is always safe.
-- A free public clinic is permanently available: never gate respawn on Robux.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Profile = require(script.Parent:WaitForChild("ProfileService"))
local Housing = require(script.Parent:WaitForChild("HousingService"))
local Wanted = require(script.Parent:WaitForChild("WantedService"))
local Economy = require(ReplicatedStorage.Shared:WaitForChild("LifeEconomy"))
local Bounty = require(script.Parent:WaitForChild("BountyService"))
local Life = {}
local notice: RemoteEvent

local function tell(player: Player, message: string)
    if player.Parent == Players then notice:FireClient(player, message) end
end

local function id(prefix: string)
    return prefix .. "_" .. HttpService:GenerateGUID(false):gsub("-", "")
end

local function pad(parent: Instance, name: string, pos: Vector3,
    verb: string, role: string, callback: (Player) -> ())
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Material = Enum.Material.Neon
    part.Color = if role == "home" then Color3.fromRGB(73, 170, 131)
        else Color3.fromRGB(75, 164, 204)
    part.Size = Vector3.new(3, 2, 3)
    part.Position = pos
    part.Parent = parent
    local prompt = Instance.new("ProximityPrompt")
    prompt.ObjectText = role == "home" and "Home cash safe" or "Free public clinic"
    prompt.ActionText = verb
    prompt.MaxActivationDistance = 9
    prompt.RequiresLineOfSight = false
    prompt.Parent = part
    prompt.Triggered:Connect(function(player: Player)
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart
            or not root or not root:IsA("BasePart")
            or (root.Position - pos).Magnitude > 12
            or not Profile.IsLoaded(player) then return end
        local ok, err = pcall(callback, player)
        if not ok then warn("[StreetCity] Home/clinic action: " .. tostring(err)) end
    end)
end

local function bindCharacter(player: Player, character: Model)
    local human = character:WaitForChild("Humanoid", 10)
    if not human or not human:IsA("Humanoid") then return end
    local deathOperation = id("death")
    local settled = false
    human.Died:Connect(function()
        if settled then return end
        settled = true
        local stars = Wanted.GetLevel(player)
        local bountyEligible = Wanted.IsBountyEligible(player)
        -- Only a confirmed server combat hit can collect a bounty.
        Bounty.ResolveDeath(player, human, stars, bountyEligible)
        Wanted.ResetAfterDeath(player)
        if not Profile.IsLoaded(player) then return end
        local success = Profile.Mutate(player, function(profile)
            return Economy.DeathSettlement(profile, stars, deathOperation)
        end)
        if success then
            local result = Profile.Read(player)
            tell(player, "Hospital treated you. Cash loss + care fee applied. Medical debt: "
                .. tostring(result and result.medicalDebt or 0)
                .. ". Free respawn at your own home is always available.")
        else
            warn("[StreetCity] Death settlement not confirmed for " .. player.UserId)
            tell(player, "Hospital record pending. Your free home respawn is available.")
        end
    end)
end

function Life.Start()
    notice = ReplicatedStorage:WaitForChild("StreetCityRemotes"):WaitForChild("GarageNotice") :: RemoteEvent
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local clinic = Instance.new("Folder")
    clinic.Name = "StreetCityHospital"
    clinic.Parent = world
    pad(clinic, "RepayMedicalDebt", Vector3.new(-40, 2, 75),
        "Pay 250 medical debt", "clinic", function(player)
            local before = Profile.Read(player)
            if not before or before.medicalDebt <= 0 then
                tell(player, "No outstanding medical debt. Treatment is always free if you cannot pay.")
                return
            end
            local amount = math.min(250, before.medicalDebt)
            local operation = id("clinic")
            local ok = Profile.Mutate(player, function(profile)
                return Economy.PayMedicalDebt(profile, amount, operation)
            end)
            tell(player, if ok then ("Paid " .. amount .. " of medical debt")
                else "Insufficient cash or medical payment unavailable")
        end)
    local root = world:WaitForChild("ResidentialHomes")
    for slot = 0, 47 do
        local house = root:FindFirstChild("Home_" .. (slot + 1))
        if not house then error("Missing home " .. slot) end
        local origin = house:FindFirstChild("House")
        if not origin or not origin:IsA("BasePart") then error("Missing house structure") end
        for _, action in {
            {name="Deposit", deposit=true, dx=-3},
            {name="Withdraw", deposit=false, dx=3},
        } do
            local actionData = action
            local pos = origin.Position + Vector3.new(action.dx, -2,
                if slot < 24 then 9 else -9)
            pad(house, "HomeCash_" .. action.name, pos,
                action.name .. " 500 cash", "home", function(player)
                    local assignment = Housing.GetGarageSpawn(player)
                    if not assignment or assignment.slot ~= slot then return end
                    local operation = id("safe")
                    local ok = Profile.Mutate(player, function(profile)
                        return Economy.TransferHome(profile, 500, actionData.deposit, operation)
                    end)
                    tell(player, if ok then "Home cash safe transaction completed"
                        else "Not enough cash or safe funds")
                end)
        end
    end
    local function onPlayer(player: Player)
        player.CharacterAdded:Connect(function(character)
            task.spawn(bindCharacter, player, character)
        end)
        if player.Character then task.spawn(bindCharacter, player, player.Character) end
    end
    Players.PlayerAdded:Connect(onPlayer)
    for _, player in Players:GetPlayers() do onPlayer(player) end
    print("[StreetCity] Home safes, hospital expenses and free recovery enabled")
end

return Life
