require "TrueNPC/TN_API"

local TN = TrueNPC

TN.Server = TN.Server or {}
TN.Server.Commands = TN.Server.Commands or {}

local function getCellSafe()
    if getCell then
        return getCell()
    end
    return nil
end

local function getZombieList()
    local cell = getCellSafe()
    if cell and cell.getZombieList then
        return cell:getZombieList()
    end
    return nil
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

local function markZombieAsNPC(zombie, npc, spawn)
    if not zombie or not npc or not zombie.getModData then
        return
    end

    spawn = spawn or TN.getNPCSpawn(npc)
    local modData = zombie:getModData()
    modData.TrueNPC = {
        npcId = tostring(npc.id),
        provider = tostring(npc.provider or "static"),
        spawnX = spawn and spawn.x or nil,
        spawnY = spawn and spawn.y or nil,
        spawnZ = spawn and spawn.z or nil,
    }
    modData.TrueNPCId = tostring(npc.id)

    if zombie.setVariable then
        zombie:setVariable("TrueNPC", true)
        zombie:setVariable("TrueNPCId", tostring(npc.id))
    end
end

local function restoreNPCMarker(zombie, expectedNpcId)
    local npcId = TN.getZombieNPCId(zombie)
    if npcId then
        return npcId
    end

    local data = TN.Save.getData()
    local expected = expectedNpcId and tostring(expectedNpcId) or nil

    for savedNpcId, state in pairs(data.npcs or {}) do
        if (not expected or tostring(savedNpcId) == expected)
            and state.status == "spawned"
            and markerMatchesZombie(state, zombie) then
            local npc = TN.getNPC(savedNpcId)
            if npc then
                markZombieAsNPC(zombie, npc)
                TN.Appearance.apply(zombie, npc)
                TN.Behaviors.update(npc, zombie, { source = "server_restore" })
                return tostring(savedNpcId)
            end
        end
    end

    return nil
end

local function findZombieByNPCId(npcId)
    local zombies = getZombieList()
    if not zombies then
        return nil
    end

    local target = tostring(npcId or "")
    for index = 0, zombies:size() - 1 do
        local zombie = zombies:get(index)
        if zombie and restoreNPCMarker(zombie, target) == target then
            return zombie
        end
    end
    return nil
end

local function findZombieByUID(uid)
    if not uid then
        return nil
    end

    local zombies = getZombieList()
    if not zombies then
        return nil
    end

    for index = 0, zombies:size() - 1 do
        local zombie = zombies:get(index)
        if zombie and zombie.getUID and zombie:getUID() == uid then
            return zombie
        end
    end
    return nil
end

local function removeZombieObject(zombie)
    if not zombie then
        return
    end

    if zombie.removeFromWorld then
        zombie:removeFromWorld()
    end
    if zombie.removeFromSquare then
        zombie:removeFromSquare()
    end
end

local function getZombieIdentity(zombie)
    local uid = TN.getZombieUID(zombie)
    if uid then
        return "uid:" .. tostring(uid)
    end

    local onlineId = TN.getZombieOnlineId(zombie)
    if onlineId then
        return "online:" .. tostring(onlineId)
    end

    return tostring(zombie)
end

local function distanceToSpawnSq(zombie, spawn)
    local zx = zombie and zombie.getX and zombie:getX() or spawn.x
    local zy = zombie and zombie.getY and zombie:getY() or spawn.y
    return TN.distanceSq(zx, zy, spawn.x, spawn.y)
end

local function collectNPCZombiesNearSpawn(npc)
    local spawn = TN.getNPCSpawn(npc)
    local cell = getCellSafe()
    local result = {}
    local seen = {}
    if not spawn or not cell or not cell.getGridSquare then
        return result
    end

    local sx = tonumber(spawn.x)
    local sy = tonumber(spawn.y)
    local sz = tonumber(spawn.z) or 0
    if not sx or not sy then
        return result
    end

    local function addIfMatches(object)
        if not object then
            return
        end

        local npcId = restoreNPCMarker(object, npc.id)
        if npcId ~= npc.id then
            return
        end

        local key = getZombieIdentity(object)
        if seen[key] then
            return
        end

        seen[key] = true
        table.insert(result, object)
    end

    local radius = math.ceil(math.max((tonumber(spawn.radius) or 3) + 8, 10))
    for dx = -radius, radius do
        for dy = -radius, radius do
            local square = cell:getGridSquare(math.floor(sx + dx), math.floor(sy + dy), math.floor(sz))
            if square then
                if square.getMovingObjects then
                    local objects = square:getMovingObjects()
                    if objects then
                        for index = 0, objects:size() - 1 do
                            addIfMatches(objects:get(index))
                        end
                    end
                end

                if square.getZombie then
                    addIfMatches(square:getZombie())
                end
            end
        end
    end

    table.sort(result, function(a, b)
        return distanceToSpawnSq(a, spawn) < distanceToSpawnSq(b, spawn)
    end)

    return result
end

local function cleanupDuplicateNPCs(npc)
    local zombies = collectNPCZombiesNearSpawn(npc)
    if #zombies <= 0 then
        return nil, 0
    end

    local keeper = zombies[1]
    local removed = 0
    for index = 2, #zombies do
        removeZombieObject(zombies[index])
        removed = removed + 1
    end

    return keeper, removed
end

local function prepareZombie(zombie, npc, spawn, options)
    if not zombie or not npc then
        return
    end

    options = type(options) == "table" and options or {}
    local shouldPlace = options.place ~= false

    if shouldPlace and zombie.setPosition and spawn then
        zombie:setPosition((tonumber(spawn.x) or 0) + 0.5, (tonumber(spawn.y) or 0) + 0.5, tonumber(spawn.z) or 0)
    end

    markZombieAsNPC(zombie, npc, spawn)
    TN.Appearance.apply(zombie, npc)

    if zombie.setHealth then
        zombie:setHealth(tonumber(npc.appearance and npc.appearance.health) or 5)
    end

    TN.Behaviors.update(npc, zombie, { source = "server_spawn" })
end

local function markSpawned(npc, zombie, spawn)
    local state = TN.Save.ensureNPCState(npc.id)
    state.status = "spawned"
    state.behaviorState = tostring(state.behaviorState or "idle")
    state.uid = TN.getZombieUID(zombie)
    state.onlineId = TN.getZombieOnlineId(zombie)
    state.x = spawn and spawn.x or nil
    state.y = spawn and spawn.y or nil
    state.z = spawn and spawn.z or nil
    state.spawnedAt = TN.getWorldAgeHours()
    state.lastSeenAt = state.spawnedAt

    TN.Save.record("spawned", npc.id, {
        uid = state.uid,
        onlineId = state.onlineId,
    })
    TN.Save.transmit()
    return state
end

local function markSeen(npc, zombie, spawn)
    local state = TN.Save.ensureNPCState(npc.id)
    local now = TN.getWorldAgeHours()
    state.status = "spawned"
    state.behaviorState = tostring(state.behaviorState or "idle")
    state.uid = TN.getZombieUID(zombie)
    state.onlineId = TN.getZombieOnlineId(zombie)
    state.x = spawn and spawn.x or nil
    state.y = spawn and spawn.y or nil
    state.z = spawn and spawn.z or nil
    state.spawnedAt = tonumber(state.spawnedAt) or now
    state.lastSeenAt = now
    TN.Save.transmit()
    return state
end

local function spawnZombieForNPC(player, npc)
    local spawn = TN.getNPCSpawn(npc)
    if not spawn then
        return nil, "missing_spawn"
    end

    local appearance = npc.appearance or {}
    local profile = TN.Appearance.buildProfile(npc, TN.Save.ensureNPCState(npc.id)) or {}
    local existing = cleanupDuplicateNPCs(npc)
    if not existing then
        existing = findZombieByNPCId(npc.id)
    end

    if existing and existing.isFemale and profile.female ~= nil and existing:isFemale() ~= (profile.female == true) then
        removeZombieObject(existing)
        existing = nil
    end

    if existing then
        prepareZombie(existing, npc, spawn, { place = false })
        markSeen(npc, existing, spawn)
        return existing, "already_spawned"
    end

    local cell = getCellSafe()
    local square = cell and cell:getGridSquare(tonumber(spawn.x), tonumber(spawn.y), tonumber(spawn.z) or 0) or nil
    if not square then
        return nil, "square_unloaded"
    end

    if not addZombiesInOutfit then
        return nil, "missing_spawn_api"
    end

    local outfit = tostring(profile.carrierOutfit or appearance.carrierOutfit or "Naked1")
    local femaleChance = profile.female and 100 or 0

    local ok, zombieList = pcall(addZombiesInOutfit,
        tonumber(spawn.x), tonumber(spawn.y), tonumber(spawn.z) or 0,
        1, outfit, femaleChance,
        false, false, false, false, true, false,
        tonumber(profile.health or appearance.health) or 5
    )

    if not ok or not zombieList or not zombieList.size or zombieList:size() <= 0 then
        ok, zombieList = pcall(addZombiesInOutfit, tonumber(spawn.x), tonumber(spawn.y), tonumber(spawn.z) or 0, 1, outfit, femaleChance)
    end

    if not ok or not zombieList or not zombieList.size or zombieList:size() <= 0 then
        return nil, "spawn_failed"
    end

    local zombie = zombieList:get(0)
    prepareZombie(zombie, npc, spawn, { place = true })
    markSpawned(npc, zombie, spawn)
    return zombie, "spawned"
end

function TN.Server.Commands.RequestSpawn(player, args)
    args = type(args) == "table" and args or {}
    local npc = TN.getNPC(args.npcId)
    if not npc then
        return
    end

    local spawn = TN.getNPCSpawn(npc)
    if spawn and player then
        local allowedRadius = (tonumber(spawn.spawnRadius) or 90) + 40
        if not TN.isPlayerNear(player, spawn, allowedRadius) then
            return
        end
    end

    if not TN.Registry.isNPCEnabled(npc, { player = player, source = "server_spawn" }) then
        local state = TN.Save.ensureNPCState(npc.id)
        state.status = "inactive"
        TN.Save.transmit()
        return
    end

    local zombie, reason = spawnZombieForNPC(player, npc)
    if not zombie then
        TN.debug("NPC spawn skipped for " .. tostring(npc.id) .. ": " .. tostring(reason))
    end
end

local function removeZombie(zombie)
    removeZombieObject(zombie)
end

function TN.Server.Commands.RequestDespawn(player, args)
    args = type(args) == "table" and args or {}
    local npcId = tostring(args.npcId or "")
    if npcId == "" then
        return
    end

    local zombie = findZombieByNPCId(npcId)
    removeZombie(zombie)

    local state = TN.Save.ensureNPCState(npcId)
    state.status = "despawned"
    state.uid = nil
    state.onlineId = nil
    state.despawnedAt = TN.getWorldAgeHours()
    TN.Save.record("despawned", npcId)
    TN.Save.transmit()
end

function TN.Server.Commands.SetState(player, args)
    args = type(args) == "table" and args or {}
    if not args.npcId then
        return
    end

    TN.Behaviors.setState(args.npcId, args.state or "idle", args.reason, args.extra)
end

local function checkNPCExistence()
    local data = TN.Save.getData()
    local changed = false

    for _, npc in ipairs(TN.getNPCs()) do
        local keeper, removed = cleanupDuplicateNPCs(npc)
        if keeper then
            markZombieAsNPC(keeper, npc)
            TN.Appearance.apply(keeper, npc)
            TN.Behaviors.update(npc, keeper, { source = "server_cleanup" })
            markSeen(npc, keeper, TN.getNPCSpawn(npc))
            changed = changed or removed > 0
        end
    end

    for npcId, state in pairs(data.npcs or {}) do
        if state.status == "spawned" and state.uid and findZombieByUID(state.uid) then
            state.lastSeenAt = TN.getWorldAgeHours()
            changed = true
        end
    end

    if changed then
        TN.Save.transmit()
    end
end

local function onClientCommand(module, command, player, args)
    if module == "TrueNPC" and TN.Server.Commands[command] then
        TN.Server.Commands[command](player, args)
    end
end

if Events and Events.OnClientCommand then
    Events.OnClientCommand.Add(onClientCommand)
end

if Events and Events.EveryOneMinute then
    Events.EveryOneMinute.Add(checkNPCExistence)
end

TN.log("Server loaded v" .. tostring(TN.VERSION))
