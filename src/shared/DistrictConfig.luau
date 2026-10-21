--!strict
local districts = {
    {id="downtown", x=0, z=0, buildingCount=10},
    {id="luxury", x=850, z=-300, buildingCount=8},
    {id="oldtown", x=-850, z=50, buildingCount=10},
    {id="port", x=-850, z=800, buildingCount=8},
    {id="village", x=1050, z=1050, buildingCount=8},
    {id="mountains", x=550, z=-1300, buildingCount=5},
    {id="coast", x=0, z=1100, buildingCount=6},
}
for _, district in districts do table.freeze(district) end
return table.freeze(districts)
