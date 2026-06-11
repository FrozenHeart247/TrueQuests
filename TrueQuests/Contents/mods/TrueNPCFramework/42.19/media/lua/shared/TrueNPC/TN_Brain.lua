require "TrueNPC/TN_Core"
require "TrueNPC/TN_Registry"
require "TrueNPC/TN_Save"

local TN = TrueNPC

TN.Brain = TN.Brain or {}
TN.Brain.actions = TN.Brain.actions or {}
TN.Brain.VERSION = 1
TN.Brain.DEBUG = true

local sessionBrains = {}
local BUMP_RECOVERY_TICKS = 55

local unsafeActions = {
    ["attack"] = true,
    ["attack-network"] = true,
    ["attackvehicle"] = true,
    ["attackvehicle-network"] = true,
    ["bumped"] = true,
    ["climbdownrope"] = true,
    ["climbfence"] = true,
    ["climbrope"] = true,
    ["climbwindow"] = true,
    ["falldown"] = true,
    ["falldown-headleft"] = true,
    ["falldown-headright"] = true,
    ["falldown-onknees"] = true,
    ["falldown-ragdoll"] = true,
    ["getup"] = true,
    ["getup-fromonback"] = true,
    ["getup-fromonfront"] = true,
    ["getup-fromsitting"] = true,
    ["hitreaction"] = true,
    ["hitreaction-gettingup"] = true,
    ["hitreaction-hit"] = true,
    ["hitreaction-onfloor"] = true,
    ["lunge"] = true,
    ["lunge-network"] = true,
    ["onground"] = true,
    ["onground-breathing"] = true,
    ["onground-ragdoll"] = true,
    ["pathfind"] = true,
    ["staggerback"] = true,
    ["staggerback-knockeddown"] = true,
    ["thump"] = true,
    ["turnalerted"] = true,
    ["vehiclecollision-bumped"] = true,
    ["vehiclecollision-falldown"] = true,
    ["vehiclecollision-onground"] = true,
    ["walktoward"] = true,
    ["walktoward-network"] = true,
}

local function callIfExists(object, method, ...)
    if object and object[method] then
        local ok, result = pcall(object[method], object, ...)
        if ok then
            return result
        end
    end
    return nil
end

local function setVariable(object, key, value)
    callIfExists(object, "setVariable", key, value)
end

local function getSessionKey(zombie, npc)
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
    return "pos:" .. tostring(npc and npc.id or "unknown")
        .. ":" .. tostring(math.floor(x * 10))
        .. ":" .. tostring(math.floor(y * 10))
        .. ":" .. tostring(math.floor(z))
end

local function ensureBrain(npc, zombie)
    if not npc or not zombie then
        return nil
    end

    local key = getSessionKey(zombie, npc)
    local brain = sessionBrains[key]
    if type(brain) ~= "table" or brain.npcId ~= tostring(npc.id) then
        brain = {
            key = key,
            npcId = tostring(npc.id),
            version = TN.Brain.VERSION,
            initialized = false,
            ticks = 0,
        }
        sessionBrains[key] = brain
    end

    local modData = zombie.getModData and zombie:getModData() or nil
    if modData then
        if type(modData.TrueNPCBrain) ~= "table" or modData.TrueNPCBrain.npcId ~= tostring(npc.id) then
            modData.TrueNPCBrain = {
                npcId = tostring(npc.id),
                version = TN.Brain.VERSION,
            }
        end
        modData.TrueNPCBrain.key = key
        modData.TrueNPCBrain.version = TN.Brain.VERSION
        modData.TrueNPCBrain.updatedAt = TN.getWorldAgeHours()
    end

    brain.ticks = (tonumber(brain.ticks) or 0) + 1
    return brain
end

function TN.Brain.registerAction(actionId, action)
    if not actionId or type(action) ~= "table" then
        return false
    end

    TN.Brain.actions[tostring(actionId)] = action
    return true
end

function TN.Brain.getAction(actionId)
    if not actionId then
        return nil
    end
    return TN.Brain.actions[tostring(actionId)]
end

function TN.Brain.getActionStateName(zombie)
    if zombie and zombie.getActionStateName then
        local ok, result = pcall(function()
            return zombie:getActionStateName()
        end)
        if ok and result then
            return tostring(result)
        end
    end
    return nil
end

function TN.Brain.isUnsafeAction(action)
    return unsafeActions[tostring(action or "")] == true
end

function TN.Brain.forceIdleAction(zombie)
    if not zombie then
        return false
    end

    callIfExists(zombie, "setBumpDone", true)
    callIfExists(zombie, "setBumpType", "")
    callIfExists(zombie, "setBumpFall", false)
    callIfExists(zombie, "setBumpFallType", "")
    callIfExists(zombie, "clearVariable", "BumpFallType")
    callIfExists(zombie, "setVariable", "BumpAnimFinished", true)

    if zombie.changeState and ZombieIdleState and ZombieIdleState.instance then
        pcall(function()
            zombie:changeState(ZombieIdleState.instance())
        end)
    end

    callIfExists(zombie, "setActionStateName", "idle")
    callIfExists(zombie, "setTurnDelta", 0)
    callIfExists(zombie, "setFallOnFront", false)
    callIfExists(zombie, "setFakeDead", false)
    callIfExists(zombie, "setCrawler", false)
    callIfExists(zombie, "resetModelNextFrame")
    return true
end

function TN.Brain.getBumpType(zombie)
    local bumpType = callIfExists(zombie, "getBumpType")
    if bumpType == nil then
        return ""
    end
    return tostring(bumpType)
end

local function getVariableBoolean(object, key)
    if object and object.getVariableBoolean then
        local ok, result = pcall(function()
            return object:getVariableBoolean(key)
        end)
        if ok then
            return result == true
        end
    end
    return false
end

local function toTrueNPCBumpType(bumpType)
    bumpType = tostring(bumpType or "")
    if bumpType == "TrueNPCBumpLeft"
        or bumpType == "TrueNPCBumpRight"
        or bumpType == "TrueNPCBumpForward"
        or bumpType == "TrueNPCBumpBack"
        or bumpType == "TrueNPCBumpSoft" then
        return bumpType
    end

    if bumpType == "right" then
        return "TrueNPCBumpRight"
    end
    if bumpType == "left" then
        return "TrueNPCBumpLeft"
    end
    if bumpType == "stagger" then
        return "TrueNPCBumpBack"
    end
    return "TrueNPCBumpSoft"
end

function TN.Brain.updateBumpRecovery(zombie, brain)
    if not zombie or not brain then
        return false
    end

    if brain.bumpActive ~= true then
        brain.bumpActive = true
        brain.bumpTicks = 0
        brain.bumpOriginalType = TN.Brain.getBumpType(zombie)
        brain.bumpStartedAt = TN.getWorldAgeHours()
        setVariable(zombie, "BumpAnimFinished", false)
        setVariable(zombie, "BumpDone", false)
    end

    brain.bumpTicks = (tonumber(brain.bumpTicks) or 0) + 1
    local desiredBumpType = toTrueNPCBumpType(TN.Brain.getBumpType(zombie))
    brain.bumpType = desiredBumpType
    callIfExists(zombie, "setBumpType", desiredBumpType)

    if getVariableBoolean(zombie, "BumpAnimFinished")
        or getVariableBoolean(zombie, "BumpDone")
        or brain.bumpTicks >= BUMP_RECOVERY_TICKS then
        return true
    end

    return false
end

function TN.Brain.finishBumpRecovery(zombie, brain)
    if brain then
        brain.bumpActive = false
        brain.bumpTicks = 0
        brain.bumpType = nil
    end
    return TN.Brain.forceIdleAction(zombie)
end

function TN.Brain.clearPath(zombie)
    if not zombie then
        return
    end

    local pathFind = callIfExists(zombie, "getPathFindBehavior2")
    callIfExists(pathFind, "cancel")
    callIfExists(pathFind, "reset")
    callIfExists(zombie, "setPath2", nil)
end

function TN.Brain.clearIntent(zombie, hard)
    if not zombie then
        return
    end

    callIfExists(zombie, "setUseless", true)
    callIfExists(zombie, "setIgnoreMovement", true)
    callIfExists(zombie, "setCanWalk", false)
    callIfExists(zombie, "setInvulnerable", true)
    callIfExists(zombie, "setTarget", nil)
    callIfExists(zombie, "setTargetSeenTime", 0)
    callIfExists(zombie, "clearAggroList")
    callIfExists(zombie, "setEatBodyTarget", nil, false)
    callIfExists(zombie, "setTurnDelta", 0)

    setVariable(zombie, "TrueNPCMoving", false)
    setVariable(zombie, "TrueNPCAttacking", false)
    setVariable(zombie, "TrueNPCPathfind", false)

    if hard == true then
        TN.Brain.clearPath(zombie)
        callIfExists(zombie, "setPrimaryHandItem", nil)
        callIfExists(zombie, "setSecondaryHandItem", nil)
        callIfExists(zombie, "resetEquippedHandsModels")
        callIfExists(zombie, "clearAttachedItems")

        local emitter = callIfExists(zombie, "getEmitter")
        callIfExists(emitter, "stopAll")
    end
end

function TN.Brain.holdPosition(npc, zombie)
    local spawn = TN.getNPCSpawn(npc)
    if not spawn or not zombie then
        return false
    end

    local sx = (tonumber(spawn.x) or 0) + 0.5
    local sy = (tonumber(spawn.y) or 0) + 0.5
    local sz = tonumber(spawn.z) or 0
    local zx = zombie.getX and zombie:getX() or sx
    local zy = zombie.getY and zombie:getY() or sy
    local zz = zombie.getZ and zombie:getZ() or sz

    if math.floor(zz or 0) ~= math.floor(sz)
        or TN.distanceSq(zx, zy, sx, sy) > 0.0025 then
        if zombie.setPosition then
            callIfExists(zombie, "setPosition", sx, sy, sz)
        else
            callIfExists(zombie, "setX", sx)
            callIfExists(zombie, "setY", sy)
            callIfExists(zombie, "setZ", sz)
        end
        return true
    end

    return false
end

function TN.Brain.applyCarrierProfile(npc, zombie, brain, context)
    if not npc or not zombie then
        return
    end

    context = type(context) == "table" and context or {}
    local behavior = type(npc.behavior) == "table" and npc.behavior or {}
    local brainDef = type(behavior.brain) == "table" and behavior.brain or {}
    local walkType = tostring(brainDef.walkType or behavior.walkType or "Walk")
    local movementSpeed = tonumber(brainDef.movementSpeed or behavior.movementSpeed) or 0.7

    callIfExists(zombie, "setNoTeeth", true)
    callIfExists(zombie, "setCanWalk", false)
    callIfExists(zombie, "setInvulnerable", true)
    callIfExists(zombie, "setWalkType", walkType)
    callIfExists(zombie, "setSpeedMod", tonumber(brainDef.speedMod) or 1)

    setVariable(zombie, "TrueNPC", true)
    setVariable(zombie, "TrueNPCId", tostring(npc.id))
    setVariable(zombie, "TrueNPCHuman", true)
    setVariable(zombie, "TrueNPCBrain", true)
    setVariable(zombie, "trueNPCIdle", true)
    setVariable(zombie, "npcQuestIdle", true)
    setVariable(zombie, "TrueNPCBrainVersion", tostring(TN.Brain.VERSION))
    setVariable(zombie, "TrueNPCWalkType", walkType)
    setVariable(zombie, "TrueNPCStationary", brainDef.stationary ~= false)

    setVariable(zombie, "BanditWalkType", walkType)
    setVariable(zombie, "BanditPrimary", "")
    setVariable(zombie, "BanditSecondary", "")
    setVariable(zombie, "BanditPrimaryType", "")
    setVariable(zombie, "BanditSecondaryType", "")

    setVariable(zombie, "LimpSpeed", tonumber(brainDef.limpSpeed) or 0.8)
    setVariable(zombie, "RunSpeed", tonumber(brainDef.runSpeed) or 0.65)
    setVariable(zombie, "WalkSpeed", tonumber(brainDef.walkSpeed) or 1.04)
    setVariable(zombie, "MovementSpeed", movementSpeed)
    setVariable(zombie, "CharacterMovementSpeed", walkType)
    setVariable(zombie, "ZombieHitReaction", "Chainsaw")
    setVariable(zombie, "NoLungeTarget", true)
    setVariable(zombie, "NoLungeAttack", true)
    setVariable(zombie, "ZombieBiteDone", true)

    if brain then
        brain.walkType = walkType
        brain.movementSpeed = movementSpeed
    end
end

function TN.Brain.debugState(npc, zombie, brain, actionId, engineBefore, engineAfter)
    if TN.Brain.DEBUG ~= true or not npc or not zombie or not brain then
        return
    end

    local ticks = tonumber(brain.ticks) or 0
    if ticks ~= 1 and ticks % 300 ~= 0 then
        return
    end

    local function boolVar(key)
        if zombie.getVariableBoolean then
            local ok, value = pcall(function()
                return zombie:getVariableBoolean(key)
            end)
            if ok then
                return tostring(value == true)
            end
        end
        return "?"
    end

    local x = zombie.getX and zombie:getX() or 0
    local y = zombie.getY and zombie:getY() or 0
    TN.log("Brain "
        .. tostring(npc.id)
        .. " tick=" .. tostring(ticks)
        .. " action=" .. tostring(actionId)
        .. " engineBefore=" .. tostring(engineBefore)
        .. " engineAfter=" .. tostring(engineAfter)
        .. " trueNPCIdle=" .. boolVar("trueNPCIdle")
        .. " npcQuestIdle=" .. boolVar("npcQuestIdle")
        .. " canWalk=" .. boolVar("CanWalk")
        .. " bumpType=" .. tostring(TN.Brain.getBumpType(zombie))
        .. " bumpTicks=" .. tostring(brain.bumpTicks or 0)
        .. " x=" .. tostring(math.floor(x * 1000) / 1000)
        .. " y=" .. tostring(math.floor(y * 1000) / 1000))
end

local function updateBrainModData(zombie, brain, actionId, engineAction)
    local modData = zombie and zombie.getModData and zombie:getModData() or nil
    if modData and type(modData.TrueNPCBrain) == "table" then
        modData.TrueNPCBrain.action = actionId
        modData.TrueNPCBrain.engineAction = engineAction
        modData.TrueNPCBrain.updatedAt = TN.getWorldAgeHours()
    end
end

local stationaryAction = {}

function stationaryAction.update(npc, zombie, brain, context)
    local state = TN.Save.ensureNPCState(npc.id)
    local actionId = tostring(context.actionId or (state and state.behaviorState) or "idle")
    local engineBefore = TN.Brain.getActionStateName(zombie)
    local unsafe = TN.Brain.isUnsafeAction(engineBefore)
    local hard = unsafe or not brain.initialized

    TN.Brain.applyCarrierProfile(npc, zombie, brain, context)
    TN.Brain.clearIntent(zombie, true)
    TN.Brain.holdPosition(npc, zombie)

    if engineBefore == "bumped" then
        if TN.Brain.updateBumpRecovery(zombie, brain) then
            TN.Brain.finishBumpRecovery(zombie, brain)
        end
        brain.lastUnsafeAction = engineBefore
        brain.lastUnsafeAt = TN.getWorldAgeHours()
    elseif unsafe or not brain.initialized then
        brain.bumpActive = false
        brain.bumpTicks = 0
        TN.Brain.forceIdleAction(zombie)
        if unsafe then
            brain.lastUnsafeAction = engineBefore
            brain.lastUnsafeAt = TN.getWorldAgeHours()
        end
    else
        brain.bumpActive = false
        brain.bumpTicks = 0
    end
    TN.Brain.holdPosition(npc, zombie)

    setVariable(zombie, "TrueNPCBrainAction", actionId)
    setVariable(zombie, "TrueNPCTalking", actionId == "talking")

    local behavior = type(npc.behavior) == "table" and npc.behavior or {}
    local shouldFacePlayer = behavior.facePlayer == true
    if shouldFacePlayer and context and context.player and zombie.faceThisObject then
        callIfExists(zombie, "faceThisObject", context.player)
    end

    brain.initialized = true
    brain.action = actionId
    brain.engineAction = TN.Brain.getActionStateName(zombie)
    TN.Brain.debugState(npc, zombie, brain, actionId, engineBefore, brain.engineAction)
    updateBrainModData(zombie, brain, actionId, brain.engineAction)
    return true
end

TN.Brain.registerAction("idle", stationaryAction)
TN.Brain.registerAction("talking", stationaryAction)
TN.Brain.registerAction("stationary", stationaryAction)

function TN.Brain.tick(npcOrId, zombie, context)
    local npc = type(npcOrId) == "table" and npcOrId or TN.getNPC(npcOrId)
    if not npc or not zombie then
        return false
    end

    context = type(context) == "table" and context or {}
    local state = TN.Save.ensureNPCState(npc.id)
    local actionId = tostring(context.actionId or (state and state.behaviorState) or "idle")
    local action = TN.Brain.getAction(actionId) or TN.Brain.getAction("idle")
    local brain = ensureBrain(npc, zombie)
    if not brain or not action or type(action.update) ~= "function" then
        return false
    end

    brain.source = context.source
    return action.update(npc, zombie, brain, context)
end
