require "TrueQuests/TQ_Core"

local TQ = TrueQuests

TQ.Registry = TQ.Registry or {
    factions = {},
    contacts = {},
    questTemplates = {},
    rewardTables = {},
}

TQ.Registry.factions = TQ.Registry.factions or {}
TQ.Registry.contacts = TQ.Registry.contacts or {}
TQ.Registry.questTemplates = TQ.Registry.questTemplates or {}
TQ.Registry.rewardTables = TQ.Registry.rewardTables or {}

local function requireId(definition, kind)
    if type(definition) ~= "table" or not definition.id or tostring(definition.id) == "" then
        TQ.warn("Cannot register " .. tostring(kind) .. " without id")
        return nil
    end
    return tostring(definition.id)
end

function TQ.registerContact(definition)
    local id = requireId(definition, "contact")
    if not id then
        return nil
    end

    local contact = TQ.deepcopy(definition)
    contact.id = id
    TQ.Registry.contacts[id] = contact
    TQ.debug("Registered contact " .. id)
    return contact
end

function TQ.getContact(id)
    if not id then
        return nil
    end
    return TQ.Registry.contacts[tostring(id)]
end

function TQ.getContacts()
    local result = {}
    for _, contact in pairs(TQ.Registry.contacts) do
        table.insert(result, contact)
    end
    table.sort(result, function(a, b)
        return tostring(a.name or a.id) < tostring(b.name or b.id)
    end)
    return result
end

function TQ.registerQuestTemplate(definition)
    local id = requireId(definition, "quest template")
    if not id then
        return nil
    end

    local template = TQ.deepcopy(definition)
    template.id = id
    template.unique = template.unique ~= false
    TQ.Registry.questTemplates[id] = template
    TQ.debug("Registered quest template " .. id)
    return template
end

function TQ.getQuestTemplate(id)
    if not id then
        return nil
    end
    return TQ.Registry.questTemplates[tostring(id)]
end

function TQ.getQuestTemplates()
    local result = {}
    for _, template in pairs(TQ.Registry.questTemplates) do
        table.insert(result, template)
    end
    table.sort(result, function(a, b)
        return tostring(a.title or a.id) < tostring(b.title or b.id)
    end)
    return result
end

function TQ.registerRewardTable(id, entries)
    if not id or tostring(id) == "" or type(entries) ~= "table" then
        TQ.warn("Cannot register reward table without id and entries")
        return nil
    end

    local tableId = tostring(id)
    TQ.Registry.rewardTables[tableId] = TQ.deepcopy(entries)
    TQ.debug("Registered reward table " .. tableId)
    return TQ.Registry.rewardTables[tableId]
end

function TQ.getRewardTable(id)
    if not id then
        return nil
    end
    return TQ.Registry.rewardTables[tostring(id)]
end
