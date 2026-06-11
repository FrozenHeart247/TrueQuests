require "TrueNPC/TN_API"

local TN = TrueNPC

TN.Client = TN.Client or {}
TN.Client.interactionHandlers = TN.Client.interactionHandlers or {}

local SPAWN_CHECK_INTERVAL = 300
local FORCED_SPAWN_CHECK_DELAY = 15
local BEHAVIOR_INTERVAL = 5
local CACHE_TTL = 30
local SPAWN_REQUEST_COOLDOWN = 300
local RESTORE_ANCHOR_TOLERANCE = 1.35

local frameTick = 0
local behaviorTick = 0
local lastSpawnCheckTick = -SPAWN_CHECK_INTERVAL
local pendingSpawnCheck = true
local spawnRequestTicks = {}

local npcZombieCache = {
    tick = -CACHE_TTL,
    byNpcId = {},
    list = {},
}

local isZombieInteractableFrom

function TN.Client.registerInteractionHandler(typeId, handler)
    if not typeId or type(handler) ~= "function" then
        return false
    end

    TN.Client.interactionHandlers[tostring(typeId)] = handler
    return true
end

local function getCellSafe()
    local cell = getCell and getCell() or nil
    return cell
end

local function markerMatchesZombie(state, zombie)
    if type(state) ~= "table" or not zombie then
        return false
    end

    local uid = TN.getZombieUID(zombie)
    if uid and state.uid and tostring(uid) == tostring(state.uid) then
        return true
    end

    local onlineId = TN.getZombieOnlineId(zombie)
    if onlineId and state.onlineId and tostring(onlineId) == tostring(state.onlineId) then
        return true
    end

    return false
end

local function getSpawnKey(spawn)
    if type(spawn) ~= "table" then
        return nil
    end

    return tostring(math.floor(tonumber(spawn.x) or 0))
        .. ":" .. tostring(math.floor(tonumber(spawn.y) or 0))
        .. ":" .. tostring(math.floor(tonumber(spawn.z) or 0))
end

local function getSpawnCenter(spawn)
    if type(spawn) ~= "table" then
        return nil, nil, nil
    end

    local x = tonumber(spawn.x)
    local y = tonumber(spawn.y)
    local z = tonumber(spawn.z) or 0
    if not x or not y then
        return nil, nil, nil
    end

    return x + 0.5, y + 0.5, z
end

local function isZombieNearSpawnAnchor(zombie, spawn, tolerance)
    local sx, sy, sz = getSpawnCenter(spawn)
    if not zombie or not sx or not sy then
        return false
    end

    local zz = zombie.getZ and zombie:getZ() or sz
    if math.floor(zz or 0) ~= math.floor(sz or 0) then
        return false
    end

    local zx = zombie.getX and zombie:getX() or sx
    local zy = zombie.getY and zombie:getY() or sy
    tolerance = tonumber(tolerance) or RESTORE_ANCHOR_TOLERANCE
    return TN.distanceSq(zx, zy, sx, sy) <= tolerance * tolerance
end

local function markZombieAsNPC(zombie, npc)
    if not zombie or not npc or not zombie.getModData then
        return
    end

    local spawn = TN.getNPCSpawn(npc)
    local modData = zombie:getModData()
    modData.TrueNPC = {
        npcId = tostring(npc.id),
        provider = tostring(npc.provider or "static"),
        spawnX = spawn and spawn.x or nil,
        spawnY = spawn and spawn.y or nil,
        spawnZ = spawn and spawn.z or nil,
        spawnKey = getSpawnKey(spawn),
    }
    modData.TrueNPCId = tostring(npc.id)

    if zombie.setVariable then
        zombie:setVariable("TrueNPC", true)
        zombie:setVariable("TrueNPCId", tostring(npc.id))
    end
end

local function restoreNPCMarker(zombie)
    local npcId = TN.getZombieNPCId(zombie)
    if npcId then
        return npcId
    end

    local data = TN.Save.getData()
    for savedNpcId, state in pairs(data.npcs or {}) do
        if state.status == "spawned" and markerMatchesZombie(state, zombie) then
            local npc = TN.getNPC(savedNpcId)
            if npc and isZombieNearSpawnAnchor(zombie, TN.getNPCSpawn(npc), RESTORE_ANCHOR_TOLERANCE) then
                markZombieAsNPC(zombie, npc)
                TN.Appearance.apply(zombie, npc, { capture = false })
                TN.Behaviors.update(npc, zombie, {
                    source = "client_restore",
                })
                return tostring(savedNpcId)
            end
        end
    end

    return nil
end

local function inspectSquareForNPC(square, expectedNpc)
    if not square then
        return nil, nil
    end

    local function checkObject(object)
        if not object then
            return nil, nil
        end

        local npcId = restoreNPCMarker(object)
        local npc = npcId and TN.getNPC(npcId) or nil
        if npc and (not expectedNpc or npc.id == expectedNpc.id) then
            return object, npc
        end
        return nil, nil
    end

    if square.getMovingObjects then
        local objects = square:getMovingObjects()
        if objects then
            for index = 0, objects:size() - 1 do
                local zombie, npc = checkObject(objects:get(index))
                if zombie then
                    return zombie, npc
                end
            end
        end
    end

    if square.getZombie then
        return checkObject(square:getZombie())
    end

    return nil, nil
end

local function findZombieNearSpawn(npc)
    local spawn = TN.getNPCSpawn(npc)
    if not spawn then
        return nil
    end

    local cell = getCellSafe()
    if not cell or not cell.getGridSquare then
        return nil
    end

    local sx = tonumber(spawn.x)
    local sy = tonumber(spawn.y)
    local sz = tonumber(spawn.z) or 0
    if not sx or not sy then
        return nil
    end

    local radius = math.ceil(math.max(tonumber(spawn.radius) or 3, 2))
    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(math.floor(sx + dx), math.floor(sy + dy), math.floor(sz))
            local zombie = inspectSquareForNPC(square, npc)
            if zombie then
                return zombie
            end
        end
    end

    return nil
end

local function addCacheEntry(npc, zombie)
    if not npc or not zombie or npcZombieCache.byNpcId[npc.id] then
        return
    end

    npcZombieCache.byNpcId[npc.id] = zombie
    table.insert(npcZombieCache.list, {
        npc = npc,
        zombie = zombie,
    })
    TN.Appearance.apply(zombie, npc, { capture = false })
    TN.Behaviors.update(npc, zombie, {
        source = "client_cache",
    })
end

local function rebuildNPCZombieCache(force)
    if not force and frameTick - npcZombieCache.tick < CACHE_TTL then
        return npcZombieCache
    end

    npcZombieCache = {
        tick = frameTick,
        byNpcId = {},
        list = {},
    }

    for _, npc in ipairs(TN.getNPCs()) do
        local zombie = findZombieNearSpawn(npc)
        if zombie then
            addCacheEntry(npc, zombie)
        end
    end

    return npcZombieCache
end

local function scanSquareForNearbyNPCs(player, square, result, seen)
    local zombie, npc = inspectSquareForNPC(square, nil)
    if zombie and npc and not seen[npc.id] then
        local ok, dist = isZombieInteractableFrom(player, square, zombie, npc)
        if ok then
            seen[npc.id] = true
            table.insert(result, {
                npc = npc,
                zombie = zombie,
                dist = dist or 0,
            })
        end
    end
end

local function findNPCsNearPlayerSquares(player, square, result, seen)
    local cell = getCellSafe()
    if not player or not cell or not cell.getGridSquare then
        return
    end

    local px = player.getX and player:getX() or nil
    local py = player.getY and player:getY() or nil
    local pz = player.getZ and player:getZ() or 0
    if not px or not py then
        return
    end

    local baseX = math.floor(px)
    local baseY = math.floor(py)
    local baseZ = math.floor(pz)
    for dx = -4, 4 do
        for dy = -4, 4 do
            local checkSquare = cell:getGridSquare(baseX + dx, baseY + dy, baseZ)
            scanSquareForNearbyNPCs(player, checkSquare, result, seen)
        end
    end

    scanSquareForNearbyNPCs(player, square, result, seen)
end

function TN.Client.findZombieByNPCId(npcId)
    local cache = rebuildNPCZombieCache(false)
    return cache.byNpcId[tostring(npcId or "")]
end

local function requestSpawn(player, npc)
    if not player or not npc then
        return
    end

    local lastRequestTick = spawnRequestTicks[npc.id] or -SPAWN_REQUEST_COOLDOWN
    if frameTick - lastRequestTick < SPAWN_REQUEST_COOLDOWN then
        return
    end

    spawnRequestTicks[npc.id] = frameTick
    sendClientCommand(player, "TrueNPC", "RequestSpawn", { npcId = npc.id })
end

local function requestDespawn(player, npc)
    if not player or not npc then
        return
    end

    sendClientCommand(player, "TrueNPC", "RequestDespawn", { npcId = npc.id })
end

function TN.Client.updateNearbyNPCs(player)
    if not player then
        return
    end

    local cache = rebuildNPCZombieCache(true)
    for _, npc in ipairs(TN.getNPCs()) do
        local spawn = TN.getNPCSpawn(npc)
        if spawn then
            local zombie = cache.byNpcId[npc.id]
            local enabled = TN.Registry.isNPCEnabled(npc, { player = player, source = "client_update" })
            local nearSpawn = TN.isPlayerNear(player, spawn, tonumber(spawn.spawnRadius) or 90)
            local farFromSpawn = not TN.isPlayerNear(player, spawn, tonumber(spawn.despawnRadius) or 120)

            if enabled and nearSpawn then
                requestSpawn(player, npc)
            end

            if (not enabled or farFromSpawn) and zombie then
                requestDespawn(player, npc)
            end
        end
    end
end

local function updateKnownNPCBehaviors(player)
    local cache = rebuildNPCZombieCache(false)
    for _, entry in ipairs(cache.list or {}) do
        if entry.npc and entry.zombie then
            TN.Behaviors.update(entry.npc, entry.zombie, {
                player = player,
                source = "client_static_tick",
            })
        end
    end
end

local function onPlayerUpdate(player)
    frameTick = frameTick + 1
    behaviorTick = behaviorTick + 1

    if behaviorTick >= BEHAVIOR_INTERVAL then
        behaviorTick = 0
        updateKnownNPCBehaviors(player)
    end

    local due = frameTick - lastSpawnCheckTick >= SPAWN_CHECK_INTERVAL
    local forcedDue = pendingSpawnCheck and frameTick - lastSpawnCheckTick >= FORCED_SPAWN_CHECK_DELAY
    if due or forcedDue then
        pendingSpawnCheck = false
        lastSpawnCheckTick = frameTick
        TN.Client.updateNearbyNPCs(player)
    end
end

local function onLoadGridSquare()
    pendingSpawnCheck = true
end

local function getSquareFromWorldObjects(worldObjects)
    if type(worldObjects) ~= "table" then
        return nil
    end

    for _, object in ipairs(worldObjects) do
        if object then
            if object.getSquare then
                local square = object:getSquare()
                if square then
                    return square
                end
            end
            if object.getWorldItem then
                local worldItem = object:getWorldItem()
                if worldItem and worldItem.getSquare then
                    return worldItem:getSquare()
                end
            end
        end
    end
    return nil
end

local function getSquareCoords(square)
    if not square then
        return nil, nil, nil
    end
    local x = square.getX and square:getX() or nil
    local y = square.getY and square:getY() or nil
    local z = square.getZ and square:getZ() or 0
    return x, y, z
end

local function getNPCInteractionRadius(npc)
    local interaction = npc and npc.interaction or {}
    local spawn = npc and npc.spawn or {}
    local radius = tonumber(interaction.radius) or tonumber(npc and npc.interactionRadius) or tonumber(spawn.radius) or 3.5
    return math.max(radius, 4)
end

function isZombieInteractableFrom(player, square, zombie, npc)
    if not player or not zombie or not npc then
        return false
    end

    local zx = zombie.getX and zombie:getX() or nil
    local zy = zombie.getY and zombie:getY() or nil
    local zz = zombie.getZ and zombie:getZ() or 0
    if not zx or not zy then
        return false
    end

    local px = player.getX and player:getX() or nil
    local py = player.getY and player:getY() or nil
    local pz = player.getZ and player:getZ() or 0
    if not px or not py or math.floor(pz) ~= math.floor(zz) then
        return false
    end

    local radius = getNPCInteractionRadius(npc)
    local distToPlayer = TN.distanceSq(px, py, zx, zy)
    if distToPlayer <= radius * radius then
        return true, distToPlayer
    end

    local sx, sy, sz = getSquareCoords(square)
    if sx and sy and math.floor(sz or 0) == math.floor(zz) then
        local clickRadius = 2.25
        local maxPlayerRadius = radius + 4
        if TN.distanceSq(sx + 0.5, sy + 0.5, zx, zy) <= clickRadius * clickRadius
            and distToPlayer <= maxPlayerRadius * maxPlayerRadius then
            return true, distToPlayer
        end
    end

    return false, distToPlayer
end

local function collectNearbyNPCZombies(player, square)
    local cache = rebuildNPCZombieCache(true)
    local result = {}
    local seen = {}
    if not cache.list then
        return result
    end

    for _, cached in ipairs(cache.list) do
        local zombie = cached.zombie
        local npc = cached.npc
        if npc and not seen[npc.id] then
            local ok, dist = isZombieInteractableFrom(player, square, zombie, npc)
            if ok then
                seen[npc.id] = true
                table.insert(result, {
                    npc = npc,
                    zombie = zombie,
                    dist = dist or 0,
                })
            end
        end
    end

    findNPCsNearPlayerSquares(player, square, result, seen)

    table.sort(result, function(a, b)
        if a.dist == b.dist then
            return tostring(a.npc.name or a.npc.id) < tostring(b.npc.name or b.npc.id)
        end
        return a.dist < b.dist
    end)

    return result
end

function TN.Client.talkToNPC(player, zombie)
    local npcId = TN.getZombieNPCId(zombie)
    local npc = TN.getNPC(npcId)
    if not player or not npc then
        return
    end

    sendClientCommand(player, "TrueNPC", "SetState", {
        npcId = npc.id,
        state = "talking",
        reason = "player_interaction",
    })

    TN.Brain.tick(npc, zombie, {
        player = player,
        source = "client_talk_start",
        actionId = "talking",
    })

    local interaction = npc.interaction or {}
    local interactionType = tostring(interaction.type or npc.interactionType or "default")
    local handler = TN.Client.interactionHandlers[interactionType]
    if handler then
        local ok, handled = TN.safeCall(handler, player, npc, zombie, interaction)
        if ok and handled ~= false then
            return
        end
    end

    local line = interaction.line or (npc.dialogue and npc.dialogue.greeting) or "They nod without saying much."
    if player.Say then
        player:Say(tostring(line))
    end
end

local function onPreFillWorldObjectContextMenu(playerNum, context, worldObjects)
    local player = getSpecificPlayer and getSpecificPlayer(playerNum) or getPlayer and getPlayer() or nil
    local square = getSquareFromWorldObjects(worldObjects)
    local candidates = collectNearbyNPCZombies(player, square)
    if not player or #candidates <= 0 then
        return
    end

    for _, entry in ipairs(candidates) do
        local npc = entry.npc
        local zombie = entry.zombie
        local label = "Talk to " .. tostring(npc.name or npc.id)
        context:addOption(label, player, function(selectedPlayer)
            TN.Client.talkToNPC(selectedPlayer, zombie)
        end)
    end
end

local function onZombieUpdate(zombie)
    local npcId = TN.getZombieNPCId(zombie)
    if not npcId then
        return
    end

    local npc = TN.getNPC(npcId)
    if not npc then
        return
    end

    local player = getSpecificPlayer and getSpecificPlayer(0) or getPlayer and getPlayer() or nil
    TN.Brain.tick(npc, zombie, {
        player = player,
        source = "client_zombie_update",
    })
end

if Events and Events.OnPlayerUpdate then
    Events.OnPlayerUpdate.Add(onPlayerUpdate)
end

if Events and Events.OnZombieUpdate then
    Events.OnZombieUpdate.Add(onZombieUpdate)
end

if Events and Events.LoadGridsquare then
    Events.LoadGridsquare.Add(onLoadGridSquare)
end

if Events and Events.OnPreFillWorldObjectContextMenu then
    Events.OnPreFillWorldObjectContextMenu.Add(onPreFillWorldObjectContextMenu)
end

TN.Save.request()
TN.log("Client loaded v" .. tostring(TN.VERSION))
