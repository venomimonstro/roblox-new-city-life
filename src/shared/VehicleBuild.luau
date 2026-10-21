--!strict
local Shared = script.Parent
local Catalog = require(Shared:WaitForChild("PartsCatalog"))
local Powertrain = require(Shared:WaitForChild("Powertrain"))
local VehicleBuild = {}

export type Build = { engineId: string, gearboxId: string, tireId: string, finalDrive: number? }

function VehicleBuild.Resolve(build: Build)
    if type(build) ~= "table" then return nil end
    if type(build.engineId) ~= "string" or type(build.gearboxId) ~= "string"
        or type(build.tireId) ~= "string" then return nil end
    local spec = Catalog.CreateSpec(build.engineId, build.gearboxId, build.tireId)
    if not spec then return nil end
    local finalDrive = build.finalDrive
    if finalDrive ~= nil then
        if type(finalDrive) ~= "number" or finalDrive ~= finalDrive
            or finalDrive < 2.5 or finalDrive > 5.5 then return nil end
    else
        finalDrive = spec.finalDrive
    end
    local resolved = {
        idleRpm = spec.idleRpm, redlineRpm = spec.redlineRpm,
        peakRpm = spec.peakRpm, peakTorqueNm = spec.peakTorqueNm,
        ratios = spec.ratios, finalDrive = finalDrive,
        tireRadiusM = spec.tireRadiusM, efficiency = spec.efficiency,
    }
    if not Powertrain.Validate(resolved) then return nil end
    return table.freeze(resolved)
end

return table.freeze(VehicleBuild)
