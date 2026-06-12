require "TrueQuests/TQ_Core"
require "TrueQuests/TQ_Registry"

local TQ = TrueQuests

TQ.Dialogue = TQ.Dialogue or {}
TQ.Dialogue.banks = TQ.Dialogue.banks or {}
TQ.Dialogue.treeBanks = TQ.Dialogue.treeBanks or {}
TQ.Dialogue.topics = TQ.Dialogue.topics or {}

local function pickLine(value, context)
    if type(value) == "function" then
        local ok, result = pcall(value, context or {})
        if ok then
            return pickLine(result, context)
        end
        return nil
    end

    if type(value) == "table" then
        if #value == 0 then
            return nil
        end
        return pickLine(value[TQ.randomInt(1, #value)], context)
    end

    if value ~= nil then
        return tostring(value)
    end

    return nil
end

local function getSourceLine(source, key)
    if type(source) ~= "table" or not key then
        return nil
    end

    local dialogue = source.dialogue or source
    if type(dialogue) == "table" then
        return pickLine(dialogue[key])
    end

    return nil
end

local function containsString(list, value)
    if type(list) ~= "table" then
        return false
    end

    value = tostring(value or "")
    for _, item in ipairs(list) do
        if tostring(item or "") == value then
            return true
        end
    end
    return false
end

local function usesExclusiveDialogue(contact)
    if type(contact) ~= "table" then
        return false
    end

    return contact.dialogueExclusive == true
        or contact.exclusiveDialogue == true
        or tostring(contact.dialogueMode or "") == "exclusive"
        or tostring(contact.dialogueTopics or "") == "exclusive"
end

local function topicHasContactScope(topic)
    return type(topic) == "table" and (topic.contactId ~= nil or type(topic.contactIds) == "table")
end

local function topicIsSystem(topic)
    return type(topic) == "table" and (topic.system == true or topic.always == true)
end

function TQ.registerDialogueBank(id, lines)
    if not id or tostring(id) == "" or type(lines) ~= "table" then
        TQ.warn("Cannot register dialogue bank without id and lines")
        return nil
    end

    local bankId = tostring(id)
    TQ.Dialogue.banks[bankId] = TQ.deepcopy(lines)
    return TQ.Dialogue.banks[bankId]
end

function TQ.registerDialogueTreeBank(id, tree)
    if not id or tostring(id) == "" or type(tree) ~= "table" then
        TQ.warn("Cannot register dialogue tree bank without id and tree")
        return nil
    end

    local bankId = tostring(id)
    TQ.Dialogue.treeBanks[bankId] = TQ.deepcopy(tree)
    return TQ.Dialogue.treeBanks[bankId]
end

local function registerDialogueTopicInternal(definition, parentId)
    local topic = TQ.deepcopy(definition)
    topic.id = tostring(topic.id)
    topic.parent = tostring(parentId or topic.parent or "start")
    topic.priority = tonumber(topic.priority) or 100
    topic._order = #TQ.Dialogue.topics + 1
    topic.children = nil

    table.insert(TQ.Dialogue.topics, topic)

    for index, child in ipairs(definition.children or {}) do
        if type(child) == "table" then
            local childDefinition = TQ.deepcopy(child)
            childDefinition.id = tostring(childDefinition.id or (topic.id .. "_" .. tostring(index)))
            childDefinition.parent = tostring(childDefinition.parent or topic.id)
            registerDialogueTopicInternal(childDefinition, childDefinition.parent)
        end
    end

    return topic
end

function TQ.registerDialogueTopic(definition)
    if type(definition) ~= "table" or not definition.id or tostring(definition.id) == "" then
        TQ.warn("Cannot register dialogue topic without id")
        return nil
    end

    return registerDialogueTopicInternal(definition, definition.parent or "start")
end

function TQ.Dialogue.getBankLine(bankId, key)
    local bank = bankId and TQ.Dialogue.banks[tostring(bankId)] or nil
    return getSourceLine(bank, key)
end

local function getBankedLine(source, key)
    if type(source) ~= "table" then
        return nil
    end

    if source.dialogueBank then
        local line = TQ.Dialogue.getBankLine(source.dialogueBank, key)
        if line then
            return line
        end
    end

    if type(source.dialogueBanks) == "table" then
        for _, bankId in ipairs(source.dialogueBanks) do
            local line = TQ.Dialogue.getBankLine(bankId, key)
            if line then
                return line
            end
        end
    end

    return nil
end

function TQ.Dialogue.getContactLine(contactOrId, key, fallback)
    local contact = type(contactOrId) == "table" and contactOrId or TQ.getContact(contactOrId)
    local line = getSourceLine(contact, key) or getBankedLine(contact, key)

    if not line and not usesExclusiveDialogue(contact) and TQ.Factions and contact then
        local faction = TQ.Factions.getFactionForContact(contact)
        line = getSourceLine(faction, key) or getBankedLine(faction, key)
    end

    return tostring(line or fallback or "")
end

local function findTreeNodeInTree(tree, nodeId)
    if type(tree) ~= "table" or not nodeId then
        return nil
    end

    return tree[tostring(nodeId)]
end

local function findTreeNodeInSource(source, nodeId)
    if type(source) ~= "table" then
        return nil
    end

    local node = findTreeNodeInTree(source.dialogueTree, nodeId)
    if node then
        return node
    end

    if source.dialogueTreeBank then
        local bank = TQ.Dialogue.treeBanks[tostring(source.dialogueTreeBank)]
        node = findTreeNodeInTree(bank, nodeId)
        if node then
            return node
        end
    end

    if type(source.dialogueTreeBanks) == "table" then
        for _, bankId in ipairs(source.dialogueTreeBanks) do
            local bank = TQ.Dialogue.treeBanks[tostring(bankId)]
            node = findTreeNodeInTree(bank, nodeId)
            if node then
                return node
            end
        end
    end

    return nil
end

local function fallbackTreeNode(contact, nodeId)
    nodeId = tostring(nodeId or "start")

    if usesExclusiveDialogue(contact) then
        if nodeId ~= "start" then
            return nil
        end

        return {
            npc = TQ.Dialogue.getContactLine(contact, "greeting", "The signal clears."),
            options = {
                { text = "Anything you need done?", action = "show_jobs" },
                { text = "Goodbye.", action = "close" },
            },
        }
    end

    if nodeId == "start" then
        return {
            npc = TQ.Dialogue.getContactLine(contact, "greeting", "The signal clears."),
            options = {
                { text = "Tell me about yourself.", next = "about" },
                { text = "Is there anything happening lately?", next = "rumors" },
                { text = "Anything you need done?", action = "show_jobs" },
                { text = "Goodbye.", action = "close" },
            },
        }
    end

    if nodeId == "about" then
        return {
            npc = TQ.Dialogue.getContactLine(contact, "about", "There is not much to say over an open channel."),
            options = {
                { text = "Back.", next = "start" },
            },
        }
    end

    if nodeId == "rumors" then
        return {
            npc = TQ.Dialogue.getContactLine(contact, "rumor", "Nothing solid. Just static and bad roads."),
            options = {
                { text = "Back.", next = "start" },
            },
        }
    end

    return nil
end

local function getContactFactionId(contact)
    if TQ.Factions and TQ.Factions.getFactionIdForContact then
        return TQ.Factions.getFactionIdForContact(contact)
    end

    return tostring(contact and (contact.factionId or contact.faction) or "independent")
end

local function topicContext(topic, contact, context)
    context = type(context) == "table" and context or {}
    contact = type(contact) == "table" and contact or nil

    local contactId = tostring(contact and contact.id or "")
    local factionId = getContactFactionId(contact)
    return {
        contact = contact,
        contactId = contactId,
        factionId = factionId,
        player = context.player,
        topic = topic,
        source = context,
    }
end

local function topicSpecificity(topic)
    local score = 0
    if topic.contactId or type(topic.contactIds) == "table" then
        score = score + 100
    end
    if topic.factionId or type(topic.factionIds) == "table" then
        score = score + 50
    end
    return score
end

local function topicSort(a, b)
    local aPriority = tonumber(a.priority) or 100
    local bPriority = tonumber(b.priority) or 100
    if aPriority ~= bPriority then
        return aPriority < bPriority
    end

    return (tonumber(a._order) or 0) < (tonumber(b._order) or 0)
end

local function topicApplies(topic, contact, context)
    if type(topic) ~= "table" or topic.enabled == false then
        return false
    end

    contact = type(contact) == "table" and contact or nil
    context = type(context) == "table" and context or {}
    local contactId = tostring(contact and contact.id or "")
    local factionId = getContactFactionId(contact)

    if topic.contactId and tostring(topic.contactId) ~= contactId then
        return false
    end
    if type(topic.contactIds) == "table" and not containsString(topic.contactIds, contactId) then
        return false
    end

    if usesExclusiveDialogue(contact) and not topicIsSystem(topic) and not topicHasContactScope(topic) then
        return false
    end

    if topic.factionId and tostring(topic.factionId) ~= factionId then
        return false
    end
    if type(topic.factionIds) == "table" and not containsString(topic.factionIds, factionId) then
        return false
    end

    if type(topic.condition) == "function" then
        local ok, result = pcall(topic.condition, topicContext(topic, contact, context))
        if not ok or result == false then
            return false
        end
    end

    return true
end

local function getTopicsForParent(contact, parentId, context)
    local result = {}
    parentId = tostring(parentId or "start")

    for _, topic in ipairs(TQ.Dialogue.topics or {}) do
        if tostring(topic.parent or "start") == parentId and topicApplies(topic, contact, context) then
            table.insert(result, topic)
        end
    end

    table.sort(result, topicSort)
    return result
end

local function getTopicById(contact, topicId, context)
    local matches = {}
    topicId = tostring(topicId or "")

    for _, topic in ipairs(TQ.Dialogue.topics or {}) do
        if tostring(topic.id or "") == topicId and topicApplies(topic, contact, context) then
            table.insert(matches, topic)
        end
    end

    table.sort(matches, function(a, b)
        local aSpecificity = topicSpecificity(a)
        local bSpecificity = topicSpecificity(b)
        if aSpecificity ~= bSpecificity then
            return aSpecificity > bSpecificity
        end
        return topicSort(a, b)
    end)

    return matches[1]
end

local function topicPrompt(topic)
    return tostring(topic.prompt or topic.text or topic.title or topic.id)
end

local function topicOption(topic)
    local option = {
        text = topicPrompt(topic),
        topicId = tostring(topic.id),
    }

    if topic.action then
        option.action = topic.action
    else
        option.next = tostring(topic.node or topic.id)
    end

    return option
end

local function optionKey(option)
    if type(option) ~= "table" then
        return ""
    end

    return string.lower(tostring(option.text or ""))
end

local function addUniqueOption(options, seen, option)
    local key = optionKey(option)
    if key == "" or seen[key] then
        return false
    end

    seen[key] = true
    table.insert(options, option)
    return true
end

local function topicLine(topic, contact, context)
    local line = pickLine(topic.npc or topic.response or topic.line or topic.lines, topicContext(topic, contact, context))
    if line then
        return line
    end

    if topic.lineKey then
        line = TQ.Dialogue.getContactLine(contact, topic.lineKey)
        if line and line ~= "" then
            return line
        end
    end

    return TQ.Dialogue.getContactLine(contact, topic.id, "The signal crackles for a moment.")
end

local function dynamicTopicNode(contact, nodeId, context)
    nodeId = tostring(nodeId or "start")

    if nodeId == "start" then
        local topics = getTopicsForParent(contact, "start", context)
        if #topics == 0 then
            return nil
        end

        local options = {}
        local seenOptions = {}
        for _, topic in ipairs(topics) do
            addUniqueOption(options, seenOptions, topicOption(topic))
        end
        addUniqueOption(options, seenOptions, { text = "Anything you need done?", action = "show_jobs" })
        addUniqueOption(options, seenOptions, { text = "Goodbye.", action = "close" })

        return {
            npc = TQ.Dialogue.getContactLine(contact, "greeting", "The signal clears."),
            options = options,
        }
    end

    local topic = getTopicById(contact, nodeId, context)
    if not topic then
        return nil
    end

    local options = {}
    local seenOptions = {}
    for _, childTopic in ipairs(getTopicsForParent(contact, topic.id, context)) do
        addUniqueOption(options, seenOptions, topicOption(childTopic))
    end
    if topic.includeJobs == true then
        addUniqueOption(options, seenOptions, { text = "Anything you need done?", action = "show_jobs" })
    end

    local backTarget = tostring(topic.back or topic.parent or "start")
    if backTarget == "" or backTarget == topic.id then
        backTarget = "start"
    end
    addUniqueOption(options, seenOptions, { text = tostring(topic.backText or "Back."), next = backTarget })

    local npcLine = topicLine(topic, contact, context)
    if type(topic.onEnter) == "function" then
        pcall(topic.onEnter, topicContext(topic, contact, context))
    end

    return {
        npc = npcLine,
        options = options,
    }
end

function TQ.Dialogue.getTreeNode(contactOrId, nodeId, context)
    local contact = type(contactOrId) == "table" and contactOrId or TQ.getContact(contactOrId)
    nodeId = tostring(nodeId or "start")

    local node = dynamicTopicNode(contact, nodeId, context)
    if not node then
        node = findTreeNodeInSource(contact, nodeId)
    end
    if not node and TQ.Factions and contact and not usesExclusiveDialogue(contact) then
        node = findTreeNodeInSource(TQ.Factions.getFactionForContact(contact), nodeId)
    end
    if not node then
        node = fallbackTreeNode(contact, nodeId)
    end
    if not node then
        return nil
    end

    local result = TQ.deepcopy(node)
    result.id = nodeId
    result.npcLine = pickLine(result.npc or result.text or result.line)
    result.options = type(result.options) == "table" and result.options or {}
    return result
end

function TQ.Dialogue.getLine(quest, key, fallback)
    local line = getSourceLine(quest and quest.dialogue or nil, key)
    if line then
        return line
    end

    if quest and quest.dialogueBank then
        line = TQ.Dialogue.getBankLine(quest.dialogueBank, key)
    end

    if not line and quest and quest.contactId then
        line = TQ.Dialogue.getContactLine(quest.contactId, key)
    end

    return tostring(line or fallback or "")
end
