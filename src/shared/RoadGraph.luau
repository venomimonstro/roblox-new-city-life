--!strict
local RoadGraph = {}
export type Node = { id: string, x: number, z: number, neighbors: { string } }
export type Graph = { [string]: Node }

function RoadGraph.Grid(radius: number, spacing: number): Graph
    assert(radius >= 1 and radius <= 30 and radius % 1 == 0, "Invalid grid radius")
    assert(spacing >= 30 and spacing <= 500, "Invalid road spacing")
    local graph: Graph = {}
    for x = -radius, radius do
        for z = -radius, radius do
            local id = tostring(x) .. ":" .. tostring(z)
            graph[id] = { id = id, x = x * spacing, z = z * spacing, neighbors = {} }
        end
    end
    for x = -radius, radius do
        for z = -radius, radius do
            local node = graph[tostring(x) .. ":" .. tostring(z)]
            for _, offset in {{1, 0}, {-1, 0}, {0, 1}, {0, -1}} do
                local nextId = tostring(x + offset[1]) .. ":" .. tostring(z + offset[2])
                if graph[nextId] then table.insert(node.neighbors, nextId) end
            end
            table.sort(node.neighbors)
        end
    end
    return graph
end

function RoadGraph.Connected(graph: Graph, start: string): boolean
    if not graph[start] then return false end
    local seen: { [string]: boolean } = { [start] = true }
    local queue = { start }
    local cursor = 1
    while cursor <= #queue do
        local node = graph[queue[cursor]]
        cursor += 1
        if not node then return false end
        for _, target in node.neighbors do
            if not graph[target] then return false end
            if not seen[target] then
                seen[target] = true
                table.insert(queue, target)
            end
        end
    end
    for id in graph do
        if not seen[id] then return false end
    end
    return true
end

return table.freeze(RoadGraph)
