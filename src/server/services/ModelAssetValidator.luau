--!strict
-- Review gate for imported creator assets. Never execute or trust imported behavior.
local Validator = {}
export type Result = {ok: boolean, reason: string, parts: number}

local function allowed(node: Instance): boolean
    return node:IsA("Model") or node:IsA("BasePart") or node:IsA("Attachment")
        or node:IsA("WeldConstraint") or node:IsA("Motor6D")
        or node:IsA("SpecialMesh") or node:IsA("Decal")
        or node:IsA("Texture") or node:IsA("SurfaceAppearance")
end

local function reasonable(n: number, max: number): boolean
    return n == n and n > 0 and n <= max
end

function Validator.Validate(model: Instance): Result
    if not model:IsA("Model") then
        return {ok = false, reason = "Expected Model", parts = 0}
    end

    local count = 0
    local meshes = 0
    local descendants = model:GetDescendants()
    if #descendants > 260 then
        return {ok = false, reason = "Too many descendants", parts = 0}
    end
    for _, node in descendants do
        -- Strict allowlist blocks scripts, remotes, prompts, sounds, physics actuators,
        -- arbitrary values, embedded nested services and other active content.
        if not allowed(node) then
            return {ok = false, reason = "Disallowed class: " .. node.ClassName, parts = count}
        end
        if node:IsA("BasePart") then
            count += 1
            if count > 120 then
                return {ok = false, reason = "Part limit exceeded", parts = count}
            end
            local size = node.Size
            if not reasonable(size.X, 40) or not reasonable(size.Y, 25)
                or not reasonable(size.Z, 60) then
                return {ok = false, reason = "Invalid part size", parts = count}
            end
            if node:IsA("MeshPart") then
                meshes += 1
                if meshes > 40 then
                    return {ok = false, reason = "Mesh limit exceeded", parts = count}
                end
            end
        end
    end
    if count == 0 then
        return {ok = false, reason = "Empty model", parts = 0}
    end
    local ok, size = pcall(function()
        return model:GetExtentsSize()
    end)
    if not ok or not reasonable(size.X, 45) or not reasonable(size.Y, 25)
        or not reasonable(size.Z, 70) then
        return {ok = false, reason = "Invalid bounding box", parts = count}
    end
    return {ok = true, reason = "Requires manual mesh/texture review", parts = count}
end

return table.freeze(Validator)
