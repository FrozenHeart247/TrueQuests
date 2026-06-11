require "TrueNPC/TN_Core"

local TN = TrueNPC

TN.Registry = TN.Registry or {
    npcs = {},
}

TN.Registry.npcs = TN.Registry.npcs or {}

local DEFAULT_SPAWN_RADIUS = 90
local DEFAULT_DESPAWN_RADIUS = 120

local function requireId(definition, kind)
    if type(definition) ~= "table" or not definition.id or tostring(definition.id) == "" then
        TN.warn("Cannot register " .. tostring(kind) .. " without id")
        return nil
    end
    return tostring(definition.id)
end

local function normalizeSpawn(definition)
    if type(definition.spawn) == "table" then
        definition.spawn.radius = tonumber(definition.spawn.radius) or tonumber(definition.interactionRadius) or 3
        definition.spawn.spawnRadius = tonumber(definition.spawn.spawnRadius) or tonumber(definition.spawnRadius) or DEFAULT_SPAWN_RADIUS
        definition.spawn.despawnRadius = tonumber(definition.spawn.despawnRadius) or tonumber(definition.despawnRadius) or DEFAULT_DESPAWN_RADIUS
        return
    end

    if definition.x and definition.y then
        definition.spawn = {
            x = definition.x,
            y = definition.y,
            z = definition.z or 0,
            radius = tonumber(definition.interactionRadius) or 3,
            spawnRadius = tonumber(definition.spawnRadius) or DEFAULT_SPAWN_RADIUS,
            despawnRadius = tonumber(definition.despawnRadius) or DEFAULT_DESPAWN_RADIUS,
        }
    end
end

local function normalizeBehavior(definition)
    if type(definition.behavior) ~= "table" then
        definition.behavior = {
            type = tostring(definition.behavior or definition.behaviorType or "static"),
        }
    end

    if not definition.behavior.type or tostring(definition.behavior.type) == "" then
        definition.behavior.type = "static"
    end
end

function TN.registerNPC(definition)
    local id = requireId(definition, "npc")
    if not id then
        return nil
    end

    local npc = TN.deepcopy(definition)
    npc.id = id
    npc.name = tostring(npc.name or npc.fullname or npc.id)
    npc.provider = tostring(npc.provider or "static")
    npc.appearance = type(npc.appearance) == "table" and npc.appearance or {}
    npc.interaction = type(npc.interaction) == "table" and npc.interaction or {}
    normalizeSpawn(npc)
    normalizeBehavior(npc)

    TN.Registry.npcs[id] = npc
    TN.debug("Registered NPC " .. id)
    return npc
end

function TN.getNPC(id)
    if not id then
        return nil
    end
    return TN.Registry.npcs[tostring(id)]
end

function TN.getNPCs()
    local result = {}
    for _, npc in pairs(TN.Registry.npcs) do
        table.insert(result, npc)
    end
    table.sort(result, function(a, b)
        return tostring(a.name or a.id) < tostring(b.name or b.id)
    end)
    return result
end

function TN.getNPCSpawn(npcOrId)
    local npc = type(npcOrId) == "table" and npcOrId or TN.getNPC(npcOrId)
    if not npc or type(npc.spawn) ~= "table" then
        return nil
    end
    return npc.spawn
end

function TN.Registry.isNPCEnabled(npcOrId, context)
    local npc = type(npcOrId) == "table" and npcOrId or TN.getNPC(npcOrId)
    if not npc or npc.enabled == false then
        return false
    end

    context = type(context) == "table" and context or {}
    context.npc = npc
    context.npcId = npc.id

    if type(npc.condition) == "function" then
        local ok, result = TN.safeCall(npc.condition, context)
        if not ok or result == false then
            return false
        end
    end

    local rule = npc.activeRule
    if type(rule) == "table" then
        if rule.enabled == false or rule.mode == "never" then
            return false
        end

        local hour = math.floor((TN.getWorldAgeHours() or 0) % 24)
        if rule.fromHour and hour < tonumber(rule.fromHour) then
            return false
        end
        if rule.toHour and hour >= tonumber(rule.toHour) then
            return false
        end
    end

    return true
end
