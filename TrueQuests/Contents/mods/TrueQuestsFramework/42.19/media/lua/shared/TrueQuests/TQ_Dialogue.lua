require "TrueQuests/TQ_Core"
require "TrueQuests/TQ_Registry"

local TQ = TrueQuests

TQ.Dialogue = TQ.Dialogue or {}
TQ.Dialogue.banks = TQ.Dialogue.banks or {}

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
