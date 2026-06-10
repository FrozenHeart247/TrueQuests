require "TrueQuests/TQ_Core"
require "TrueQuests/TQ_Registry"
require "TrueQuests/TQ_Save"

local TQ = TrueQuests

TQ.Factions = TQ.Factions or {}

local DEFAULT_FACTION_ID = "independent"
local ACTIVE_CONTACTS_VERSION = 1
local DEFAULT_REPUTATION = {
    easy = 5,
    medium = 10,
    normal = 10,
    hard = 20,
    deadly = 30,
}

local function requireId(definition, kind)
    if type(definition) ~= "table" or not definition.id or tostring(definition.id) == "" then
        TQ.warn("Cannot register " .. tostring(kind) .. " without id")
        return nil
    end
    return tostring(definition.id)
end

local function currentDay()
    return math.floor((TQ.getWorldAgeHours() or 0) / 24)
end

local function currentHour()
    return math.floor((TQ.getWorldAgeHours() or 0) % 24)
end

local function contains(list, value)
    if type(list) ~= "table" then
        return false
    end

    for _, item in ipairs(list) do
        if tostring(item) == tostring(value) then
            return true
        end
    end
    return false
end

local function addUnique(list, seen, value)
    value = tostring(value or "")
    if value == "" or seen[value] then
        return false
    end

    seen[value] = true
    table.insert(list, value)
    return true
end

local function tableIsEmpty(value)
    if type(value) ~= "table" then
        return true
    end

    for _ in pairs(value) do
        return false
    end

    return true
end

function TQ.registerFaction(definition)
    local id = requireId(definition, "faction")
    if not id then
        return nil
    end

    local faction = TQ.deepcopy(definition)
    faction.id = id
    faction.maxActiveMembers = tonumber(faction.maxActiveMembers) or 3
    faction.reputation = type(faction.reputation) == "table" and faction.reputation or {}
    TQ.Registry.factions[id] = faction
    TQ.debug("Registered faction " .. id)
    return faction
end

function TQ.getFaction(id)
    if not id then
        return nil
    end
    return TQ.Registry.factions[tostring(id)]
end

function TQ.getFactions()
    local result = {}
    for _, faction in pairs(TQ.Registry.factions) do
        table.insert(result, faction)
    end
    table.sort(result, function(a, b)
        return tostring(a.name or a.id) < tostring(b.name or b.id)
    end)
    return result
end

function TQ.Factions.getFactionIdForContact(contactOrId)
    local contact = type(contactOrId) == "table" and contactOrId or TQ.getContact(contactOrId)
    if not contact then
        return DEFAULT_FACTION_ID
    end

    if contact.factionId and tostring(contact.factionId) ~= "" then
        return tostring(contact.factionId)
    end

    if contact.faction and TQ.getFaction(contact.faction) then
        return tostring(contact.faction)
    end

    return DEFAULT_FACTION_ID
end

function TQ.Factions.getFactionForContact(contactOrId)
    return TQ.getFaction(TQ.Factions.getFactionIdForContact(contactOrId))
end

function TQ.Factions.getContactsForFaction(factionId)
    factionId = tostring(factionId or DEFAULT_FACTION_ID)
    local contacts = {}

    for _, contact in ipairs(TQ.getContacts()) do
        if TQ.Factions.getFactionIdForContact(contact) == factionId then
            table.insert(contacts, contact)
        end
    end

    table.sort(contacts, function(a, b)
        return tostring(a.name or a.id) < tostring(b.name or b.id)
    end)
    return contacts
end

local function ruleAllowsContact(contact, day, hour)
    local rule = contact and contact.activeRule or nil
    if rule == false then
        return false
    end

    if type(rule) ~= "table" then
        return true
    end

    if rule.enabled == false or rule.mode == "never" then
        return false
    end

    if rule.days and not contains(rule.days, (day % 7) + 1) then
        return false
    end

    if rule.fromHour and hour < tonumber(rule.fromHour) then
        return false
    end

    if rule.toHour and hour >= tonumber(rule.toHour) then
        return false
    end

    return true
end

local function isAlwaysActive(contact)
    local rule = contact and contact.activeRule or nil
    return contact and (contact.alwaysActive == true
        or contact.role == "leader"
        or (type(rule) == "table" and rule.mode == "always"))
end

local function pickRandomContacts(pool, count, out, seen)
    while count > 0 and #pool > 0 do
        local index = TQ.randomInt(1, #pool)
        local contact = table.remove(pool, index)
        if contact and addUnique(out, seen, contact.id) then
            count = count - 1
        end
    end
end

local function rollFactionContacts(faction, contacts, day, hour)
    local selected = {}
    local seen = {}
    local pool = {}
    local maxActive = tonumber(faction and faction.maxActiveMembers) or #contacts

    table.sort(contacts, function(a, b)
        return tostring(a.name or a.id) < tostring(b.name or b.id)
    end)

    for _, contact in ipairs(contacts) do
        if ruleAllowsContact(contact, day, hour) then
            if isAlwaysActive(contact) then
                addUnique(selected, seen, contact.id)
            else
                table.insert(pool, contact)
            end
        end
    end

    local remaining = math.max(0, maxActive - #selected)
    pickRandomContacts(pool, remaining, selected, seen)
    return selected
end

local function collectFactionIds()
    local ids = {}
    local seen = {}

    for _, faction in ipairs(TQ.getFactions()) do
        addUnique(ids, seen, faction.id)
    end

    for _, contact in ipairs(TQ.getContacts()) do
        addUnique(ids, seen, TQ.Factions.getFactionIdForContact(contact))
    end

    return ids
end

function TQ.Factions.ensureActiveContacts(player, force)
    local data = TQ.Save.getData(player)
    local day = currentDay()
    local active = data.contacts and data.contacts.active or nil

    if not force and type(active) == "table"
        and tonumber(active.version) == ACTIVE_CONTACTS_VERSION
        and tonumber(active.day) == day
        and not tableIsEmpty(active.byFaction) then
        return active
    end

    active = {
        version = ACTIVE_CONTACTS_VERSION,
        day = day,
        generatedAt = TQ.getWorldAgeHours(),
        byFaction = {},
        all = {},
    }

    local allSeen = {}
    local hour = currentHour()
    for _, factionId in ipairs(collectFactionIds()) do
        local faction = TQ.getFaction(factionId) or {
            id = factionId,
            name = factionId,
            maxActiveMembers = 3,
        }
        local contacts = TQ.Factions.getContactsForFaction(factionId)
        local selected = rollFactionContacts(faction, contacts, day, hour)
        active.byFaction[factionId] = selected

        for _, contactId in ipairs(selected) do
            addUnique(active.all, allSeen, contactId)
        end
    end

    data.contacts.active = active
    TQ.Save.touch(player)
    return active
end

function TQ.Factions.getActiveContactIds(player, factionId)
    local active = TQ.Factions.ensureActiveContacts(player)
    local source = factionId and active.byFaction[tostring(factionId)] or active.all
    local result = {}
    for _, contactId in ipairs(source or {}) do
        table.insert(result, contactId)
    end
    return result
end

function TQ.Factions.getActiveContactMap(player)
    local result = {}
    for _, contactId in ipairs(TQ.Factions.getActiveContactIds(player)) do
        result[contactId] = true
    end
    return result
end

function TQ.Factions.getActiveContacts(player, factionId)
    local result = {}
    for _, contactId in ipairs(TQ.Factions.getActiveContactIds(player, factionId)) do
        local contact = TQ.getContact(contactId)
        if contact then
            table.insert(result, contact)
        end
    end
    return result
end

function TQ.Factions.isContactActive(player, contactId)
    if not contactId or tostring(contactId) == "" then
        return false
    end

    local map = TQ.Factions.getActiveContactMap(player)
    return map[tostring(contactId)] == true
end

local function ensureReputation(data)
    data.reputation = type(data.reputation) == "table" and data.reputation or {}
    data.reputation.factions = type(data.reputation.factions) == "table" and data.reputation.factions or {}
    data.reputation.contacts = type(data.reputation.contacts) == "table" and data.reputation.contacts or {}
    return data.reputation
end

function TQ.Factions.getReputation(player, id, scope)
    local data = TQ.Save.getData(player)
    local reputation = ensureReputation(data)
    id = tostring(id or "")

    if scope == "contact" then
        return tonumber(reputation.contacts[id]) or 0
    end

    return tonumber(reputation.factions[id]) or 0
end

function TQ.Factions.addReputation(player, factionId, amount, contactId, options)
    amount = tonumber(amount) or 0
    if amount == 0 then
        return 0
    end

    local data = TQ.Save.getData(player)
    local reputation = ensureReputation(data)
    factionId = tostring(factionId or DEFAULT_FACTION_ID)
    contactId = contactId and tostring(contactId) or nil

    reputation.factions[factionId] = (tonumber(reputation.factions[factionId]) or 0) + amount
    if contactId and contactId ~= "" then
        reputation.contacts[contactId] = (tonumber(reputation.contacts[contactId]) or 0) + amount
    end

    table.insert(data.history, {
        event = "reputation",
        factionId = factionId,
        contactId = contactId,
        amount = amount,
        at = TQ.getWorldAgeHours(),
    })

    if not options or options.deferTouch ~= true then
        TQ.Save.touch(player)
    end

    return amount
end

function TQ.Factions.getQuestReputationGain(quest)
    if not quest then
        return 0
    end

    if quest.reputation ~= nil then
        return tonumber(quest.reputation) or 0
    end

    local faction = TQ.getFaction(quest.factionId)
    local difficulty = tostring(quest.difficulty or "easy")
    if faction and type(faction.reputation) == "table" then
        return tonumber(faction.reputation[difficulty] or faction.reputation.default) or DEFAULT_REPUTATION[difficulty] or 5
    end

    return DEFAULT_REPUTATION[difficulty] or 5
end

function TQ.Factions.awardQuestReputation(player, quest)
    if not quest or quest.reputationAwarded then
        return 0
    end

    local amount = TQ.Factions.getQuestReputationGain(quest)
    local factionId = quest.factionId or DEFAULT_FACTION_ID
    TQ.Factions.addReputation(player, factionId, amount, quest.contactId, { deferTouch = true })
    quest.reputationAwarded = {
        factionId = factionId,
        contactId = quest.contactId,
        amount = amount,
    }
    return amount
end
