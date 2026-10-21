--!strict
-- In-game credits only. No Robux products or random loot.
local offers = {
    engine_sport_new = {slot = "engineId", partId = "sport_i4", price = 4500, quality = "new"},
    engine_v6_used = {slot = "engineId", partId = "v6", price = 6800, quality = "used"},
    gearbox_sport_new = {slot = "gearboxId", partId = "sport_6", price = 2200, quality = "new"},
    tire_sport_new = {slot = "tireId", partId = "sport", price = 900, quality = "new"},
    tire_worn_used = {slot = "tireId", partId = "worn", price = 100, quality = "used"},
    weapon_foam_baton = {slot = "gear", partId = "foam_baton", price = 500, quality = "equipment"},
    weapon_paint_blaster = {slot = "gear", partId = "paint_blaster", price = 1800, quality = "equipment"},
    weapon_training_gloves = {slot = "gear", partId = "training_gloves", price = 180, quality = "equipment"},
    weapon_stun_wand = {slot = "gear", partId = "stun_wand", price = 1000, quality = "equipment"},
    weapon_arcade_pistol = {slot = "gear", partId = "arcade_pistol", price = 2600, quality = "equipment"},
    weapon_arcade_shotgun = {slot = "gear", partId = "arcade_shotgun", price = 4100, quality = "equipment"},
    weapon_arcade_smg = {slot = "gear", partId = "arcade_smg", price = 5400, quality = "equipment"},
    weapon_arcade_rifle = {slot = "gear", partId = "arcade_rifle", price = 7300, quality = "equipment"},
}
for _, offer in pairs(offers) do table.freeze(offer) end
return table.freeze(offers)
