require "TrueQuests/TQ_Core"
require "TrueQuests/TQ_Registry"

local TQ = TrueQuests

TQ.Dialogue = TQ.Dialogue or {}
TQ.Dialogue.banks = TQ.Dialogue.banks or {}
TQ.Dialogue.treeBanks = TQ.Dialogue.treeBanks or {}

local function pickLine(value)
    if type(value) == "table" then
        if #value == 0 then
            return nil
        end
        return tostring(value[TQ.randomInt(1, #value)])
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

    if not line and TQ.Factions and contact then
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

function TQ.Dialogue.getTreeNode(contactOrId, nodeId)
    local contact = type(contactOrId) == "table" and contactOrId or TQ.getContact(contactOrId)
    nodeId = tostring(nodeId or "start")

    local node = findTreeNodeInSource(contact, nodeId)
    if not node and TQ.Factions and contact then
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
