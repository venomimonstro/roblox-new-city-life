--!strict
-- Studio-only end-to-end readiness probe for REAL connected test players.
-- Does not manufacture a passing game session from fake services or profiles.
-- Prints an actionable failure and never modifies the saved wallet.
local Players = game:GetService("Players")
local Profile = require(script.Parent.Parent:WaitForChild("services"):WaitForChild("ProfileService"))
local Housing = require(script.Parent.Parent:WaitForChild("services"):WaitForChild("HousingService"))
local Garage = require(script.Parent.Parent:WaitForChild("services"):WaitForChild("PersonalGarage"))

local Probe = {}
local started: {[number]: boolean} = {}

local function awaitPlayable(player: Player)
    local errors: {string} = {}
    local function fail(message: string)
        table.insert(errors, message)
    end

    -- Profiles, homes and server-side car instances may arrive after spawn.
    for attempt = 1, 30 do
        if player.Parent ~= Players then return end
        local home = Housing.GetGarageSpawn(player)
        local car = Garage.GetActive(player)
        if Profile.IsLoaded(player) and home and car and car.Model.Parent
            and car.Model:GetAttribute("OwnerUserId") == player.UserId then
            break
        end
        task.wait(1)
    end
    if player.Parent ~= Players then return end

    local snapshot = Profile.Read(player)
    local plot = Housing.GetGarageSpawn(player)
    local car = Garage.GetActive(player)
    if not snapshot then fail("Profile not loaded or account quarantined") end
    if not plot then fail("No assigned residential home and garage") end
    if not car or not car.Model.Parent then
        fail("Personal car did not spawn within 30 seconds")
    else
        if car.Model:GetAttribute("OwnerUserId") ~= player.UserId then
            fail("Spawned car does not belong to this player")
        end
        if not snapshot or car.Model:GetAttribute("OwnedVehicleId") ~= snapshot.selectedVehicleId then
            fail("Physical car does not match saved selection")
        end
        if car.Model:GetAttribute("VehicleHealth") == 0 then
            fail("Garage spawned a destroyed zero-health car")
        end
        if car.Seat == nil or car.Chassis == nil then
            fail("Car is missing driver seat or physical chassis")
        end
    end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not root or not humanoid or humanoid.Health <= 0 then
        fail("Player has no living playable character")
    elseif root:IsA("BasePart") then
        local home = Housing.GetHomePosition(player)
        if home and (root.Position - home).Magnitude > 75 then
            fail("Player did not appear at the assigned home")
        end
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        local exclusions = {char}
        local vehicles = workspace:FindFirstChild("ActiveVehicles")
        if vehicles then table.insert(exclusions, vehicles) end
        ray.FilterDescendantsInstances = exclusions
        local floor = workspace:Raycast(root.Position + Vector3.new(0, 3, 0),
            Vector3.new(0, -30, 0), ray)
        if not floor or not floor.Instance.CanCollide then
            fail("No physical ground beneath initial home spawn")
        end
    end
    local world = workspace:FindFirstChild("StreetCityPrototypeWorld")
    if not world then fail("City world did not initialize") end
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("StreetCityRemotes")
    if not remotes or not remotes:FindFirstChild("VehicleInput") then
        fail("Client cannot send driving commands")
    end
    if not game:GetService("ReplicatedStorage"):FindFirstChild("StreetCityCareerStatus") then
        fail("Legal career navigator remote is missing")
    end

    if #errors == 0 then
        print("[StreetCity Playability] PASS: user " .. tostring(player.UserId)
            .. " joined, has valid home/character, saved owned car, ground, driving"
            .. " and career communications. Manual controls still require playtest.")
    else
        warn("[StreetCity Playability] FAIL: user " .. tostring(player.UserId)
            .. "\n- " .. table.concat(errors, "\n- "))
    end
end

function Probe.Start()
    local function watch(player: Player)
        if started[player.UserId] then return end
        started[player.UserId] = true
        task.spawn(awaitPlayable, player)
    end
    Players.PlayerAdded:Connect(watch)
    for _, player in Players:GetPlayers() do watch(player) end
    Players.PlayerRemoving:Connect(function(player)
        started[player.UserId] = nil
    end)
    print("[StreetCity Playability] Real-player spawn/home/car probe armed (Studio only)")
end

return Probe
