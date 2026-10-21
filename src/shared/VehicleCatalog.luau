--!strict
-- Catalog IDs are persistent; do not rename entries without profile migrations.
local catalog = {
    starter_hatch = {
        name = "Starter Hatchback", price = 0,
        engineId = "stock_i4", gearboxId = "street_5", tireId = "street",
    },
    -- Fictional American-style starters: distinct silhouette/theme, identical
    -- drivetrain and handling (no paid or random advantage at game entry).
    starter_american_sedan = {
        name = "Liberty Four-Door", price = 0,
        engineId = "stock_i4", gearboxId = "street_5", tireId = "street",
    },
    starter_american_pickup = {
        name = "Mesa Work Truck", price = 0,
        engineId = "stock_i4", gearboxId = "street_5", tireId = "street",
    },
    starter_american_muscle = {
        name = "Canyon Classic", price = 0,
        engineId = "stock_i4", gearboxId = "street_5", tireId = "street",
    },
    street_coupe = {
        name = "Street Coupe", price = 12000,
        engineId = "sport_i4", gearboxId = "street_5", tireId = "street",
    },
    sport_sedan = {
        name = "Sport Sedan", price = 24000,
        engineId = "v6", gearboxId = "sport_6", tireId = "sport",
    },
}
for _, v in pairs(catalog) do table.freeze(v) end
return table.freeze(catalog)
