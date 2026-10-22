--!strict
-- Bounded, deterministic social lives for abstracted city residents. The event
-- generator never touches DataStore, physics, or real player cash.
local Life = {}
local moods = {"content", "cheerful", "tired", "lonely", "worried"}
local careers = {"driver", "cashier", "builder", "nurse", "clerk",
    "mechanic", "teacher", "unemployed"}

function Life.New(id: number, district: string): any
    local occupation = careers[id % #careers + 1]
    return {
        id = id, district = district,
        age = 18 + id % 53,
        employed = occupation ~= "unemployed",
        occupation = occupation,
        married = id % 5 == 0,
        hasCar = id % 3 ~= 0,
        mood = moods[id % #moods + 1],
        drunk = false,
        alive = true,
        relationships = 0,
        incidents = 0,
        trips = 0,
        minute = 0,
        event = "idle",
    }
end

function Life.Advance(state: any, minute: number, safety: number): string
    if type(minute) ~= "number" or minute % 1 ~= 0 or minute <= state.minute
        or minute < 0 or minute > 2000000
        or type(safety) ~= "number" then return state.event end
    state.minute = minute
    if not state.alive then
        -- A deceased abstract NPC is replaced by a new resident only after a
        -- bounded offscreen cycle; never constantly respawn at the player.
        if minute % 9 == 0 then
            state.alive = true
            state.age = 18 + (state.id + minute) % 52
            state.married = false
            state.relationships = 0
            state.event = "new_resident"
        end
        return state.event
    end
    local roll = (state.id * 31 + minute * 17) % 31
    if safety < 22 and roll == 0 then
        state.alive = false
        state.event = "passed_away"
    elseif safety < 42 and roll <= 2 then
        state.incidents = math.min(99, state.incidents + 1)
        state.mood = "worried"
        state.event = "argument"
    elseif roll == 4 then
        state.drunk = true
        state.mood = "tired"
        state.event = "social_drinking"
    elseif state.drunk and roll >= 7 then
        state.drunk = false
        state.event = "sober"
    elseif roll == 8 and not state.married then
        state.relationships += 1
        state.event = "met_someone"
    elseif roll == 9 and state.relationships >= 2 and not state.married then
        state.married = true
        state.event = "wedding"
    elseif roll == 10 and not state.employed then
        state.employed = true
        state.occupation = careers[(state.id + minute) % (#careers - 1) + 1]
        state.event = "new_job"
    elseif roll == 11 and state.employed and safety < 45 then
        state.employed = false
        state.occupation = "unemployed"
        state.event = "lost_job"
    elseif roll == 12 and state.hasCar then
        state.trips += 1
        state.event = "commute"
    elseif roll == 13 then
        state.event = "shopping"
    elseif roll == 14 then
        state.event = "hobby"
    else
        state.event = if state.employed then "work" else "free_time"
    end
    return state.event
end

return table.freeze(Life)
