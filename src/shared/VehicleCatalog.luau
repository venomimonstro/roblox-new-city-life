--!strict
-- Catalog IDs are persistent; do not rename entries without profile migrations.
local catalog = {
    starter_hatch = {
        name = "Starter Hatchback", price = 0,
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
