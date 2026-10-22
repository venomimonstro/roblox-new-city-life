--!strict
-- Pure progression and conduct. No server calls, no client-selected payouts.
local Catalog = require(script.Parent:WaitForChild("LegalCareerCatalog"))
local Progress = {}
local valid: {[string]: boolean} = {}
for _, job in Catalog do valid[job.id] = true end
for _, hobby in {"boxing", "gym", "tennis", "dancing", "jogging", "fishing", "nature"} do
    valid[hobby] = true
end
function Progress.ValidSkill(id: any): boolean
    return type(id) == "string" and valid[id] == true
end
function Progress.Level(xp: number): number
    if type(xp) ~= "number" or xp ~= xp or xp < 0 then return 1 end
    return math.clamp(1 + math.floor(math.sqrt(xp / 120)), 1, 20)
end
function Progress.Wage(base: number, xp: number): number
    assert(type(base) == "number" and base >= 0 and base <= 1000)
    -- Up to +57% at level 20; no multiplier supplied by a client.
    local level = Progress.Level(xp)
    return math.floor(base * (1 + (level - 1) * 0.03) + 0.5)
end
function Progress.Xp(profile: any, skillId: string): number
    if not Progress.ValidSkill(skillId) or type(profile.skills) ~= "table" then return 0 end
    return profile.skills[skillId] or 0
end
function Progress.Earn(profile: any, skillId: string, amount: number): boolean
    if not Progress.ValidSkill(skillId) or type(profile.skills) ~= "table"
        or type(amount) ~= "number" or amount % 1 ~= 0
        or amount < 1 or amount > 200 then return false end
    profile.skills[skillId] = math.min(1000000, (profile.skills[skillId] or 0) + amount)
    return true
end
function Progress.Conduct(profile: any, change: number): boolean
    if type(profile.morality) ~= "number" or type(change) ~= "number"
        or change % 1 ~= 0 or change < -10 or change > 10 then return false end
    profile.morality = math.clamp(profile.morality + change, -100, 100)
    return true
end
function Progress.Title(profile: any): string
    local moral = if type(profile.morality) == "number" then profile.morality else 0
    if moral >= 60 then return "Trusted citizen" end
    if moral >= 20 then return "Helpful resident" end
    if moral <= -60 then return "Notorious outlaw" end
    if moral <= -20 then return "Troublemaker" end
    return "Independent"
end
return table.freeze(Progress)
