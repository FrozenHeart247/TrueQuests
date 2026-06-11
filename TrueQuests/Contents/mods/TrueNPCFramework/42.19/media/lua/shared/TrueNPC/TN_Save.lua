require "TrueNPC/TN_Core"

local TN = TrueNPC

TN.Save = TN.Save or {}
TN.Save.KEY = "TrueNPCFramework"

local cachedData = nil

function TN.Save.createDefaultData()
    return {
        version = TN.DATA_VERSION,
        npcs = {},
        history = {},
    }
end

function TN.Save.migrate(data)
    if type(data) ~= "table" then
        return TN.Save.createDefaultData()
    end

    data.version = tonumber(data.version) or 1
    data.npcs = type(data.npcs) == "table" and data.npcs or {}
    data.history = type(data.history) == "table" and data.history or {}

    if data.version < TN.DATA_VERSION then
        data.version = TN.DATA_VERSION
    end

    return data
end

function TN.Save.getData()
    if ModData and ModData.getOrCreate then
        cachedData = TN.Save.migrate(ModData.getOrCreate(TN.Save.KEY))
        return cachedData
    end

    cachedData = TN.Save.migrate(cachedData)
    return cachedData
end

function TN.Save.setData(data)
    cachedData = TN.Save.migrate(data)
    return cachedData
end

function TN.Save.request()
    if isClient and isClient() and ModData and ModData.request then
        ModData.request(TN.Save.KEY)
    end
end

function TN.Save.transmit()
    if ModData and ModData.transmit then
        ModData.transmit(TN.Save.KEY)
    end
end

function TN.Save.ensureNPCState(npcId)
    local data = TN.Save.getData()
    local id = tostring(npcId or "")
    if id == "" then
        return nil
    end

    data.npcs[id] = type(data.npcs[id]) == "table" and data.npcs[id] or {}
    local state = data.npcs[id]
    state.npcId = id
    state.status = tostring(state.status or "inactive")
    state.behaviorState = tostring(state.behaviorState or "idle")
    return state
end

function TN.Save.getNPCState(npcId)
    local data = TN.Save.getData()
    return data.npcs[tostring(npcId or "")]
end

function TN.Save.record(event, npcId, extra)
    local data = TN.Save.getData()
    local entry = type(extra) == "table" and TN.deepcopy(extra) or {}
    entry.event = tostring(event or "event")
    entry.npcId = tostring(npcId or "")
    entry.at = TN.getWorldAgeHours()
    table.insert(data.history, entry)
    return entry
end

local function onInitGlobalModData()
    TN.Save.getData()
    TN.Save.request()
end

local function onReceiveGlobalModData(key, data)
    if tostring(key or "") == TN.Save.KEY then
        TN.Save.setData(data)
    end
end

if Events and Events.OnInitGlobalModData then
    Events.OnInitGlobalModData.Add(onInitGlobalModData)
end

if Events and Events.OnReceiveGlobalModData then
    Events.OnReceiveGlobalModData.Add(onReceiveGlobalModData)
end
