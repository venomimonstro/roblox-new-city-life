--!strict
-- Real-world acceptance for procedural neighborhoods, not a model-only test.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Districts = require(Shared:WaitForChild("DistrictConfig"))
local Tests = {}

function Tests.Run()
    local world = workspace:WaitForChild("StreetCityPrototypeWorld")
    local root = world:FindFirstChild("CityInfill")
    assert(root and root:IsA("Folder"),
        "[City Infill] Generator did not populate its world container")
    local count = 0
    local occupied: {[string]: boolean} = {}
    local perRegion: {[string]: number} = {}
    for _, district in Districts do
        local zone = root:FindFirstChild(district.id)
        assert(zone and zone:IsA("Folder"),
            "[City Infill] Missing neighborhood " .. district.id)
        local regionCount = 0
        for _, model in zone:GetChildren() do
            assert(model:IsA("Model") and model:GetAttribute("CityInfill") == true,
                "[City Infill] Unauthorized object in generated district")
            local core = model:FindFirstChild("CollisionShell")
            assert(core and core:IsA("BasePart") and core.CanCollide and core.CanQuery,
                "[City Infill] One solid collision shell is required per structure")
            local pos = core.Position
            local widthX = core.Size.X
            local widthZ = core.Size.Z
            local left = math.abs(pos.X - math.round(pos.X / 100) * 100)
            local front = math.abs(pos.Z - math.round(pos.Z / 100) * 100)
            assert(left >= widthX / 2 + 12.5
                and front >= widthZ / 2 + 12.5,
                "[City Infill] New building occupies a driving lane")
            local key = tostring(math.floor(pos.X + 0.5)) .. ":"
                .. tostring(math.floor(pos.Z + 0.5))
            assert(not occupied[key], "[City Infill] Duplicate occupied parcel " .. key)
            occupied[key] = true
            local solids = 0
            for _, child in model:GetDescendants() do
                if child:IsA("BasePart") then
                    if child.CanCollide then
                        solids += 1
                        assert(child == core, "[City Infill] Façade creates an unnecessary blocker")
                    else
                        assert(not child.CanQuery and not child.CanTouch,
                            "[City Infill] Decorative detail changes physics or suspension")
                    end
                end
            end
            assert(solids == 1,
                "[City Infill] Every structure must have exactly one physics hull")
            regionCount += 1
            count += 1
        end
        assert(regionCount >= 6,
            "[City Infill] District has fewer than six additional buildings: " .. district.id)
        perRegion[district.id] = regionCount
    end
    assert(count >= 70 and count <= 140,
        "[City Infill] City under-populated or over budget")
    assert(root:GetAttribute("GeneratedBuildings") == count,
        "[City Infill] Generator count does not match actual geometry")
    local roads = world:FindFirstChild("Roads")
    assert(roads, "[City Infill] No traversable street network")
    local ray = RaycastParams.new()
    ray.IgnoreWater = true
    ray.FilterType = Enum.RaycastFilterType.Include
    ray.FilterDescendantsInstances = {roads}
    for _, district in Districts do
        local centerX = math.round(district.x / 100) * 100
        local centerZ = math.round(district.z / 100) * 100
        for _, delta in {-200, -100, 0, 100, 200} do
            for _, p in {
                Vector3.new(centerX + delta, 20, centerZ),
                Vector3.new(centerX, 20, centerZ + delta),
            } do
                local hit = workspace:Raycast(p, Vector3.new(0, -40, 0), ray)
                assert(hit and hit.Material == Enum.Material.Asphalt,
                    "[City Infill] A regional approach lost its road")
            end
        end
    end
    print("[StreetCity] PASS: " .. count
        .. " extra low-physics buildings, seven districts and live road surface samples")
end

return Tests
