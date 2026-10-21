--!strict
-- Server-side validation for creator-imported 3D models (e.g. Cube 4D).
-- Validate clones before they are admitted to an approved asset library.
local Validator = {}
export type Result = {ok: boolean, reason: string, parts: number}

function Validator.Validate(model: Instance): Result
    if not model:IsA("Model") then return {ok = false, reason = "Not a Model", parts = 0} end
    local count = 0
    local meshCount = 0
    for _, node in model:GetDescendants() do
        if node:IsA("LuaSourceContainer") or node:IsA("RemoteEvent") or node:IsA("RemoteFunction")
            or node:IsA("BindableEvent") or node:IsA("BindableFunction") then
            return {ok = false, reason = "Executable or event object", parts = count}
        end
        if node:IsA("BasePart") then
            count += 1
            if count > 120 then return {ok = false, reason = "Part limit", parts = count} end
            if node:IsA("MeshPart") then meshCount += 1 end
            if node.Size.X <= 0 or node.Size.Y <= 0 or node.Size.Z <= 0
                or node.Size.X > 40 or node.Size.Y > 25 or node.Size.Z > 60 then
                return {ok = false, reason = "Invalid part dimensions", parts = count}
            end
        end
    end
    if count == 0 then return {ok = false, reason = "Empty asset", parts = count} end
    if meshCount > 40 then return {ok = false, reason = "Mesh limit", parts = count} end
    local size = model:GetExtentsSize()
    if size.X > 45 or size.Y > 25 or size.Z > 70 then
        return {ok = false, reason = "Bounding box limit", parts = count}
    end
    return {ok = true, reason = "Accepted for manual review", parts = count}
end

return table.freeze(Validator)
