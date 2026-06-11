require "TrueNPC/TN_Core"
require "TrueNPC/TN_Registry"
require "TrueNPC/TN_Save"

local TN = TrueNPC

TN.Behaviors = TN.Behaviors or {}
TN.Behaviors.types = TN.Behaviors.types or {}

function TN.Behaviors.register(typeId, behavior)
    if not typeId or type(behavior) ~= "table" then
        TN.warn("Cannot register behavior without id and handler")
        return false
    end

    TN.Behaviors.types[tostring(typeId)] = behavior
    return true
end

function TN.Behaviors.get(typeId)
    if not typeId then
        return nil
    end
    return TN.Behaviors.types[tostring(typeId)]
end

function TN.Behaviors.setState(npcId, stateId, reason, extra)
    local state = TN.Save.ensureNPCState(npcId)
    if not state then
        return nil
    end

    state.behaviorState = tostring(stateId or "idle")
    state.behaviorReason = reason and tostring(reason) or nil
    state.behaviorChangedAt = TN.getWorldAgeHours()

    if type(extra) == "table" then
        for key, value in pairs(extra) do
            state[key] = value
        end
    end

    TN.Save.record("behavior", npcId, {
        state = state.behaviorState,
        reason = state.behaviorReason,
    })
    TN.Save.transmit()
    return state
end

function TN.Behaviors.update(npcOrId, zombie, context)
    local npc = type(npcOrId) == "table" and npcOrId or TN.getNPC(npcOrId)
    if not npc then
        return false
    end

    local behaviorId = tostring((npc.behavior and npc.behavior.type) or "static")
    local behavior = TN.Behaviors.get(behaviorId)
    if not behavior or type(behavior.update) ~= "function" then
        return false
    end

    return behavior.update(npc, zombie, context or {})
end

local function callIfExists(object, method, ...)
    if object and object[method] then
        object[method](object, ...)
    end
end

local staticPrepared = {}

local function getZombieSessionKey(zombie, npc)
    local uid = TN.getZombieUID(zombie)
    if uid then
        return "uid:" .. tostring(uid)
    end

    local onlineId = TN.getZombieOnlineId(zombie)
    if onlineId then
        return "online:" .. tostring(onlineId)
    end

    local x = zombie and zombie.getX and zombie:getX() or 0
    local y = zombie and zombie.getY and zombie:getY() or 0
    local z = zombie and zombie.getZ and zombie:getZ() or 0
    return "pos:" .. tostring(npc and npc.id or "unknown") .. ":" .. tostring(math.floor(x * 10)) .. ":" .. tostring(math.floor(y * 10)) .. ":" .. tostring(math.floor(z))
end

local function normalizeZombieState(zombie)
    if not zombie then
        return
    end

    local action = nil
    if zombie.getActionStateName then
        local ok, result = pcall(function()
            return zombie:getActionStateName()
        end)
        if ok and result then
            action = tostring(result)
        end
    end

    if action and (action == "sitonground"
        or action == "onground"
        or action == "getup"
        or action == "getup-fromsitting"
        or action == "getup-fromonback"
        or action == "getup-fromonfront") then
        if zombie.changeState and ZombieIdleState and ZombieIdleState.instance then
            pcall(function()
                zombie:changeState(ZombieIdleState.instance())
            end)
        end
    end

    callIfExists(zombie, "setCrawler", false)
    callIfExists(zombie, "setFakeDead", false)
    callIfExists(zombie, "setFallOnFront", false)
    callIfExists(zombie, "setPrimaryHandItem", nil)
    callIfExists(zombie, "setSecondaryHandItem", nil)
    callIfExists(zombie, "resetEquippedHandsModels")
end

local function freezeZombie(zombie, npc)
    if not zombie then
        return
    end

    local modData = zombie.getModData and zombie:getModData() or nil
    if modData then
        modData.TrueNPCStaticPrepared = nil
    end

    local sessionKey = getZombieSessionKey(zombie, npc)
    local prepared = staticPrepared[sessionKey] == true

    normalizeZombieState(zombie)

    callIfExists(zombie, "setUseless", true)
    callIfExists(zombie, "setNoTeeth", true)
    callIfExists(zombie, "setIgnoreMovement", true)
    callIfExists(zombie, "setTarget", nil)
    callIfExists(zombie, "clearAggroList")
    callIfExists(zombie, "setTurnAlertedValues", -5, 5)
    callIfExists(zombie, "setWalkType", "Walk")

    if zombie.setVariable then
        zombie:setVariable("TrueNPC", true)
        zombie:setVariable("TrueNPCId", tostring(npc.id))
        zombie:setVariable("TrueNPCHuman", true)
        zombie:setVariable("LimpSpeed", 0.8)
        zombie:setVariable("RunSpeed", 0.65)
        zombie:setVariable("WalkSpeed", 1.0)
        zombie:setVariable("MovementSpeed", 0.7)
        zombie:setVariable("ZombieHitReaction", "Chainsaw")
    end

    if not prepared and zombie.setVariable then
        zombie:setVariable("NoLungeTarget", true)
        zombie:setVariable("NoLungeAttack", true)
        zombie:setVariable("ZombieBiteDone", true)
        staticPrepared[sessionKey] = true
    end
end

local function returnToSpawn(zombie, npc, spawn, maxDrift, allowTeleport)
    if not zombie or not spawn then
        return
    end
    if allowTeleport ~= true then
        return
    end

    local zx = zombie.getX and zombie:getX() or spawn.x
    local zy = zombie.getY and zombie:getY() or spawn.y
    local zz = zombie.getZ and zombie:getZ() or spawn.z
    if math.floor(zz or 0) ~= math.floor(tonumber(spawn.z) or 0) then
        return
    end

    if TN.distanceSq(zx, zy, spawn.x, spawn.y) > maxDrift * maxDrift and zombie.teleportTo then
        zombie:teleportTo((tonumber(spawn.x) or 0) + 0.5, (tonumber(spawn.y) or 0) + 0.5, tonumber(spawn.z) or 0)
    end
end

local staticBehavior = {}

function staticBehavior.update(npc, zombie, context)
    if not zombie then
        return false
    end

    freezeZombie(zombie, npc)

    local spawn = TN.getNPCSpawn(npc)
    local maxDrift = tonumber(npc.behavior and npc.behavior.maxDrift) or tonumber(npc.maxDrift) or 3
    local allowTeleport = npc.behavior and npc.behavior.teleportBack == true
    returnToSpawn(zombie, npc, spawn, maxDrift, allowTeleport)

    local facePlayer = npc.behavior and npc.behavior.facePlayer
    if facePlayer ~= false and context.player and zombie.faceThisObject then
        zombie:faceThisObject(context.player)
    end

    return true
end

TN.Behaviors.register("static", staticBehavior)
