--!strict
local Catalog = {}
Catalog.Engines = table.freeze({
    stock_i4 = table.freeze({ idleRpm = 850, redlineRpm = 6400, peakRpm = 4100, peakTorqueNm = 190 }),
    sport_i4 = table.freeze({ idleRpm = 950, redlineRpm = 7500, peakRpm = 5200, peakTorqueNm = 300 }),
    v6 = table.freeze({ idleRpm = 850, redlineRpm = 7000, peakRpm = 4800, peakTorqueNm = 400 }),
})
Catalog.Gearboxes = table.freeze({
    street_5 = table.freeze({ ratios = table.freeze({3.5, 2.1, 1.43, 1.03, 0.81}), finalDrive = 3.9 }),
    sport_6 = table.freeze({ ratios = table.freeze({3.2, 2.1, 1.58, 1.24, 1.0, 0.82}), finalDrive = 4.1 }),
})
Catalog.Tires = table.freeze({
    street = table.freeze({ grip = 1, radiusM = 0.32 }),
    sport = table.freeze({ grip = 1.2, radiusM = 0.33 }),
    worn = table.freeze({ grip = 0.63, radiusM = 0.32 }),
})

function Catalog.CreateSpec(engineId: string, gearboxId: string, tireId: string)
    local engine = Catalog.Engines[engineId]
    local transmission = Catalog.Gearboxes[gearboxId]
    local tire = Catalog.Tires[tireId]
    if not engine or not transmission or not tire then return nil end
    return {
        idleRpm = engine.idleRpm, redlineRpm = engine.redlineRpm,
        peakRpm = engine.peakRpm, peakTorqueNm = engine.peakTorqueNm,
        ratios = transmission.ratios, finalDrive = transmission.finalDrive,
        tireRadiusM = tire.radiusM, efficiency = 0.86,
    }
end

return table.freeze(Catalog)
