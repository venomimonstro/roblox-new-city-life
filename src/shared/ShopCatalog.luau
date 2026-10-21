--!strict
-- In-game credits only. No Robux products or random loot.
local offers = {
    engine_sport_new = {slot = "engineId", partId = "sport_i4", price = 4500, quality = "new"},
    engine_v6_used = {slot = "engineId", partId = "v6", price = 6800, quality = "used"},
    gearbox_sport_new = {slot = "gearboxId", partId = "sport_6", price = 2200, quality = "new"},
    tire_sport_new = {slot = "tireId", partId = "sport", price = 900, quality = "new"},
    tire_worn_used = {slot = "tireId", partId = "worn", price = 100, quality = "used"},
}
for _, offer in pairs(offers) do table.freeze(offer) end
return table.freeze(offers)
