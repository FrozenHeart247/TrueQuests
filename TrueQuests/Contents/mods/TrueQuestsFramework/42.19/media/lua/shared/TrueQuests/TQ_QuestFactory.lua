require "TrueQuests/TQ_Core"
require "TrueQuests/TQ_Registry"
require "TrueQuests/TQ_Objectives"
require "TrueQuests/TQ_Rewards"
require "TrueQuests/TQ_Factions"

local TQ = TrueQuests

TQ.QuestFactory = TQ.QuestFactory or {}

local function resolveTurnInValue(value, context)
    if type(value) == "function" then
        local ok, result = pcall(value, context)
        if ok and type(result) == "table" then
            return TQ.deepcopy(result)
        end

        if not ok then
            TQ.warn(result)
        end
        return nil
    end

    if type(value) == "table" then
        return TQ.deepcopy(value)
    end

    return nil
end

local function resolveTurnIn(template, context)
    local templateTurnIn = resolveTurnInValue(template.turnIn, context)
    if templateTurnIn then
        return templateTurnIn
    end

    if type(template.turnIn) == "table" then
        return TQ.deepcopy(template.turnIn)
    end

    local contact = TQ.getContact(template.contact or template.contactId)
    local contactTurnIn = contact and resolveTurnInValue(contact.turnIn, context) or nil
    if contactTurnIn then
        return contactTurnIn
    end

    return nil
end

local function resolveTimeLimit(template)
    if type(template) ~= "table" then
        return nil
    end

    local value = template.timeLimitHours or template.deadlineHours or template.durationHours
    value = tonumber(value)
    if value and value > 0 then
        return value
    end

    return nil
end

function TQ.QuestFactory.build(templateId, questId, player, options)
    local template = TQ.getQuestTemplate(templateId)
    if not template then
        TQ.warn("Cannot build quest from missing template " .. tostring(templateId))
        return nil
    end

    options = type(options) == "table" and options or {}

    local contactId = tostring(options.contactId or template.contact or template.contactId or "")
    local contact = TQ.getContact(contactId)
    local factionId = tostring(template.factionId or (TQ.Factions and TQ.Factions.getFactionIdForContact(contact)) or "independent")
    local faction = TQ.getFaction(factionId)
    local difficulty = options.difficulty or template.difficulty or "easy"
    local context = {
        template = template,
        player = player,
        difficulty = difficulty,
        contact = contact,
        faction = faction,
    }

    local objectives = {}
    for _, objectiveTemplate in ipairs(template.objectives or {}) do
        local objective = TQ.Objectives.build(objectiveTemplate, context)
        if objective then
            table.insert(objectives, objective)
        end
    end

    local rewardSpec = TQ.Rewards.resolveSpec(template.rewards or template.reward or {}, context)

    local createdAt = TQ.getWorldAgeHours()
    local timeLimitHours = resolveTimeLimit(template)
    local quest = {
        id = questId,
        templateId = tostring(template.id),
        title = tostring(template.title or template.name or template.id),
        description = tostring(template.description or ""),
        difficulty = tostring(difficulty),
        contactId = contactId,
        contactName = tostring((contact and contact.name) or contactId or ""),
        factionId = factionId,
        factionName = tostring((faction and faction.name) or factionId or ""),
        status = "accepted",
        createdAt = createdAt,
        objectives = objectives,
        turnIn = resolveTurnIn(template, context),
        reputation = template.reputation,
        failureReputation = template.failureReputation or template.reputationPenalty or template.reputationOnFailure,
        rewardSpec = TQ.deepcopy(rewardSpec),
        rewardChoices = TQ.Rewards.buildChoices(rewardSpec, context),
        dialogue = TQ.deepcopy(template.dialogue or {}),
        tags = TQ.deepcopy(template.tags or {}),
        unique = template.unique ~= false,
    }

    if timeLimitHours then
        quest.timeLimitHours = timeLimitHours
        quest.expiresAt = createdAt + timeLimitHours
    end

    return quest
end
