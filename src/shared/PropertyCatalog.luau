--!strict
-- Personal instanced property rights. This is not a global real-estate title registry:
-- player-to-player deeds require an atomic cross-account transaction coordinator.
local catalog = {
    downtown_flat = {district="downtown", kind="apartment", basePrice=3600, rent=160},
    luxury_penthouse = {district="luxury", kind="apartment", basePrice=7200, rent=330},
    oldtown_shop = {district="oldtown", kind="shop", basePrice=4600, rent=210},
    port_warehouse = {district="port", kind="warehouse", basePrice=5400, rent=240},
    village_home = {district="village", kind="house", basePrice=3100, rent=140},
    mountain_cabin = {district="mountains", kind="house", basePrice=4200, rent=190},
    coast_kiosk = {district="coast", kind="shop", basePrice=3800, rent=175},
}
for _, item in pairs(catalog) do table.freeze(item) end
return table.freeze(catalog)
