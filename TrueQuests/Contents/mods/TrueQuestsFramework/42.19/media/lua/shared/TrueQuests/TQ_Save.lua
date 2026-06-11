require "TrueQuests/TQ_Core"

local TQ = TrueQuests

TQ.Save = TQ.Save or {}
TQ.Save.KEY = "TrueQuests"

function TQ.Save.createDefaultData()
    return {
        version = TQ.DATA_VERSION,
        nextQuestId = 1,
        active = {},
        completed = {},
        failed = {},
        contacts = {
            active = nil,
            discoveredFactions = {},
            failedByFaction = {},
        },
        reputation = {
            factions = {},
            contacts = {},
        },
        offers = {
            refreshAt = 0,
            generatedAt = 0,
            generation = 0,
            byContact = {},
        },
        history = {},
    }
end

function TQ.Save.migrate(data)
    if type(data) ~= "table" then
        return TQ.Save.createDefaultData()
    end

    data.version = tonumber(data.version) or 1
    data.nextQuestId = tonumber(data.nextQuestId) or 1
    data.active = type(data.active) == "table" and data.active or {}
    data.completed = type(data.completed) == "table" and data.completed or {}
    data.failed = type(data.failed) == "table" and data.failed or {}
    data.contacts = type(data.contacts) == "table" and data.contacts or {}
    data.contacts.discoveredFactions = type(data.contacts.discoveredFactions) == "table" and data.contacts.discoveredFactions or {}
    data.contacts.failedByFaction = type(data.contacts.failedByFaction) == "table" and data.contacts.failedByFaction or {}
    data.reputation = type(data.reputation) == "table" and data.reputation or {}
    data.reputation.factions = type(data.reputation.factions) == "table" and data.reputation.factions or {}
    data.reputation.contacts = type(data.reputation.contacts) == "table" and data.reputation.contacts or {}
    data.offers = type(data.offers) == "table" and data.offers or {}
    data.offers.refreshAt = tonumber(data.offers.refreshAt) or 0
    data.offers.generatedAt = tonumber(data.offers.generatedAt) or math.max(0, data.offers.refreshAt - 6)
    data.offers.generation = tonumber(data.offers.generation) or 0
    data.offers.byContact = type(data.offers.byContact) == "table" and data.offers.byContact or {}
    data.history = type(data.history) == "table" and data.history or {}

    if data.version < TQ.DATA_VERSION then
        data.version = TQ.DATA_VERSION
    end

    return data
end

function TQ.Save.getData(player)
    if not player or not player.getModData then
        return TQ.Save.createDefaultData()
    end

    local modData = player:getModData()
    modData[TQ.Save.KEY] = TQ.Save.migrate(modData[TQ.Save.KEY])
    return modData[TQ.Save.KEY]
end

function TQ.Save.touch(player)
    if player and player.transmitModData then
        player:transmitModData()
    end

    if TQ.Events and TQ.Events.trigger then
        TQ.Events.trigger("changed", player)
    end
end

function TQ.Save.allocateQuestId(data)
    data.nextQuestId = tonumber(data.nextQuestId) or 1
    local id = "tq_" .. tostring(data.nextQuestId)
    data.nextQuestId = data.nextQuestId + 1
    return id
end
