--!strict
-- Server-authored public transport map. All stops sit on the existing road grid.
local Transit = {}
Transit.Metro = {
    {id="oldtown", label="Old Town", x=-1000},
    {id="downtown", label="Central", x=0},
    {id="luxury", label="Uptown", x=1000},
}
Transit.Bus = {
    {id="harbor", label="Harbor", pos=Vector3.new(-800, 2, 800)},
    {id="west", label="West City", pos=Vector3.new(-800, 2, 0)},
    {id="central", label="Central", pos=Vector3.new(0, 2, 0)},
    {id="east", label="East City", pos=Vector3.new(800, 2, -300)},
    {id="beach", label="Coast", pos=Vector3.new(0, 2, 1100)},
}
Transit.MetroDepth = -26
Transit.MaxFare = 75
return table.freeze(Transit)
