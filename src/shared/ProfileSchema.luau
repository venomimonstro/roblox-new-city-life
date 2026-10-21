--!strict
-- Profile schema and migration logic. Pure functions: no DataStore calls.
local ProfileSchema = {}
export type Profile = {
    schemaVersion: number,
    credits: number,
    garage: { [string]: { engineId: string, gearboxId: string, tireId: string } },
}
local DEFAULT = {
    schemaVersion = 1,
    credits = 0,
    garage = {
        starter = { engineId = "stock_i4", gearboxId = "street_5", tireId = "street" },
    },
}
local function clone(value: any): any
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do copy[k] = clone(v) end
    return copy
end
function ProfileSchema.New(): Profile
    return clone(DEFAULT) :: Profile
end
function ProfileSchema.Decode(raw: any): Profile?
    if type(raw) ~= "table" or raw.schemaVersion ~= 1 then return nil end
    if type(raw.credits) ~= "number" or raw.credits ~= raw.credits
        or raw.credits < 0 or raw.credits > 1e10 then return nil end
    if type(raw.garage) ~= "table" then return nil end
    local VehicleBuild = require(script.Parent:WaitForChild("VehicleBuild"))
    local result: Profile = { schemaVersion = 1, credits = math.floor(raw.credits), garage = {} }
    local count = 0
    for id, build in pairs(raw.garage) do
        count += 1
        if count > 20 or type(id) ~= "string" or #id > 48 then return nil end
        if type(build) ~= "table" or not VehicleBuild.Resolve(build) then return nil end
        result.garage[id] = {
            engineId = build.engineId, gearboxId = build.gearboxId, tireId = build.tireId,
        }
    end
    if not result.garage.starter then return nil end
    return result
end
return table.freeze(ProfileSchema)
