require "TrueNPC/TN_Core"

local TN = TrueNPC

TN.Registry = TN.Registry or {
    npcs = {},
}

TN.Registry.npcs = TN.Registry.npcs or {}

local DEFAULT_SPAWN_RADIUS = 90
local DEFAULT_DESPAWN_RADIUS = 120

local function randomInt(minValue, maxValue)
    minValue = tonumber(minValue) or 0
    maxValue = tonumber(maxValue) or minValue
    if maxValue < minValue then
        minValue, maxValue = maxValue, minValue
    end

    if ZombRand then
        return ZombRand(minValue, maxValue + 1)
    end

    return math.random(minValue, maxValue)
end

local function usesRandomSpawn(npc)
    if not npc then
        return false
    end

    local mode = tostring(npc.spawnSelection or npc.spawnMode or "")
    return npc.randomSpawn == true or mode == "random"
end

local function requireId(definition, kind)
    if type(definition) ~= "table" or not definition.id or tostring(definition.id) == "" then
        TN.warn("Cannot register " .. tostring(kind) .. " without id")
        return nil
    end
    return tostring(definition.id)
end

local function normalizeSpawnTable(definition, spawn, index)
    if type(spawn) ~= "table" then
        return nil
    end

    local normalized = TN.deepcopy(spawn)
    normalized.x = tonumber(normalized.x)
    normalized.y = tonumber(normalized.y)
    normalized.z = tonumber(normalized.z) or 0
    if not normalized.x or not normalized.y then
        return nil
    end

    normalized.id = tostring(normalized.id or normalized.key or ("spawn_" .. tostring(index or 1)))
    normalized.radius = tonumber(normalized.radius) or tonumber(definition.interactionRadius) or 3
    normalized.spawnRadius = tonumber(normalized.spawnRadius) or tonumber(definition.spawnRadius) or DEFAULT_SPAWN_RADIUS
    normalized.despawnRadius = tonumber(normalized.despawnRadius) or tonumber(definition.despawnRadius) or DEFAULT_DESPAWN_RADIUS
    normalized.index = tonumber(index) or tonumber(normalized.index)
    return normalized
end

local function normalizeSpawn(definition)
    local spawnPoints = type(definition.spawnPoints) == "table" and definition.spawnPoints
        or type(definition.spawns) == "table" and definition.spawns
        or nil

    if spawnPoints then
        definition.spawnPoints = {}
        for index, spawn in ipairs(spawnPoints) do
            local normalized = normalizeSpawnTable(definition, spawn, index)
            if normalized then
                table.insert(definition.spawnPoints, normalized)
            end
        end

        if #definition.spawnPoints > 0 and type(definition.spawn) ~= "table" then
            definition.spawn = TN.deepcopy(definition.spawnPoints[1])
        end
    end

    if type(definition.spawn) == "table" then
        definition.spawn = normalizeSpawnTable(definition, definition.spawn, 1) or definition.spawn
        return
    end

    if definition.x and definition.y then
        definition.spawn = normalizeSpawnTable(definition, {
            x = definition.x,
            y = definition.y,
            z = definition.z or 0,
        }, 1)
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

function TN.getNPCSpawnCandidates(npcOrId)
    local npc = type(npcOrId) == "table" and npcOrId or TN.getNPC(npcOrId)
    local result = {}
    if not npc then
        return result
    end

    if type(npc.spawnPoints) == "table" and #npc.spawnPoints > 0 then
        for _, spawn in ipairs(npc.spawnPoints) do
            table.insert(result, spawn)
        end
        return result
    end

    if type(npc.spawn) == "table" then
        table.insert(result, npc.spawn)
    end

    return result
end

function TN.getNPCSpawnSearchCandidates(npcOrId)
    local npc = type(npcOrId) == "table" and npcOrId or TN.getNPC(npcOrId)
    if not npc then
        return {}
    end

    local state = TN.Save and TN.Save.getNPCState and TN.Save.getNPCState(npc.id) or nil
    if state and state.spawnPointId then
        local selected = TN.Registry.findSpawnPoint(npc, state.spawnPointId)
        if selected then
            return { selected }
        end
    end

    return TN.getNPCSpawnCandidates(npc)
end

function TN.Registry.usesRandomSpawn(npcOrId)
    local npc = type(npcOrId) == "table" and npcOrId or TN.getNPC(npcOrId)
    return usesRandomSpawn(npc)
end

function TN.Registry.findSpawnPoint(npcOrId, spawnId)
    local id = tostring(spawnId or "")
    if id == "" then
        return nil
    end

    for _, spawn in ipairs(TN.getNPCSpawnCandidates(npcOrId)) do
        if tostring(spawn.id or spawn.index or "") == id then
            return spawn
        end
    end

    return nil
end

function TN.getNPCSpawn(npcOrId)
    local npc = type(npcOrId) == "table" and npcOrId or TN.getNPC(npcOrId)
    if not npc then
        return nil
    end

    local state = TN.Save and TN.Save.getNPCState and TN.Save.getNPCState(npc.id) or nil
    if state and state.spawnPointId then
        local selected = TN.Registry.findSpawnPoint(npc, state.spawnPointId)
        if selected then
            return selected
        end
    end

    if type(npc.spawn) == "table" then
        return npc.spawn
    end

    local candidates = TN.getNPCSpawnCandidates(npc)
    return candidates[1]
end

function TN.Registry.selectNPCSpawn(npcOrId, spawnId)
    local npc = type(npcOrId) == "table" and npcOrId or TN.getNPC(npcOrId)
    if not npc then
        return nil
    end

    local state = TN.Save and TN.Save.getNPCState and TN.Save.getNPCState(npc.id) or nil
    if state and state.spawnPointId then
        local selected = TN.Registry.findSpawnPoint(npc, state.spawnPointId)
        if selected then
            return selected
        end
    end

    local candidates = TN.getNPCSpawnCandidates(npc)
    local spawn = nil
    if usesRandomSpawn(npc) and #candidates > 0 then
        spawn = candidates[randomInt(1, #candidates)]
    else
        spawn = TN.Registry.findSpawnPoint(npc, spawnId) or TN.getNPCSpawn(npc)
    end

    if not spawn then
        return nil
    end

    if TN.Save and TN.Save.ensureNPCState then
        local state = TN.Save.ensureNPCState(npc.id)
        state.spawnPointId = tostring(spawn.id or spawn.index or "spawn_1")
        state.spawnPointIndex = tonumber(spawn.index) or nil
        state.spawnPointName = spawn.name and tostring(spawn.name) or nil
    end

    return spawn
end

function TN.Registry.clearNPCSpawnSelection(npcOrId)
    local npc = type(npcOrId) == "table" and npcOrId or TN.getNPC(npcOrId)
    if not npc or not TN.Save or not TN.Save.ensureNPCState then
        return
    end

    local state = TN.Save.ensureNPCState(npc.id)
    state.spawnPointId = nil
    state.spawnPointIndex = nil
    state.spawnPointName = nil
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
