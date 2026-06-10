require "TrueQuests/TQ_Core"
require "TrueQuests/TQ_Events"
require "TrueQuests/TQ_Save"
require "TrueQuests/TQ_Registry"
require "TrueQuests/TQ_Conditions"
require "TrueQuests/TQ_Objectives"
require "TrueQuests/TQ_Rewards"
require "TrueQuests/TQ_Factions"
require "TrueQuests/TQ_QuestFactory"

local TQ = TrueQuests

TQ.QuestManager = TQ.QuestManager or {}

local function findIndexById(list, id)
    if type(list) ~= "table" then
        return nil
    end

    for index, quest in ipairs(list) do
        if quest.id == id then
            return index
        end
    end
    return nil
end

local function hasActiveTemplate(data, templateId)
    for _, quest in ipairs(data.active or {}) do
        if quest.templateId == templateId and quest.status ~= "completed" and quest.status ~= "failed" then
            return true
        end
    end
    return false
end

function TQ.QuestManager.getActiveQuests(player)
    local data = TQ.Save.getData(player)
    return data.active
end

function TQ.QuestManager.findActiveQuest(player, questId)
    local data = TQ.Save.getData(player)
    local index = findIndexById(data.active, questId)
    if index then
        return data.active[index], index, data
    end
    return nil, nil, data
end

function TQ.QuestManager.updateQuestProgress(quest, player)
    if not quest or quest.status == "rewardPending" or quest.status == "completed" or quest.status == "failed" then
        return quest
    end

    local allComplete = #quest.objectives > 0
    for _, objective in ipairs(quest.objectives or {}) do
        TQ.Objectives.update(objective, quest, player)
        if objective.completed ~= true then
            allComplete = false
        end
    end

    if allComplete then
        if quest.status == "accepted" then
            quest.status = "readyToTurnIn"
        end
    elseif quest.status == "readyToTurnIn" then
        quest.status = "accepted"
    end

    return quest
end

function TQ.QuestManager.updateAll(player)
    local data = TQ.Save.getData(player)
    for _, quest in ipairs(data.active or {}) do
        TQ.QuestManager.updateQuestProgress(quest, player)
    end
    return data.active
end

function TQ.QuestManager.getOffers(player, contactId, limit)
    local data = TQ.Save.getData(player)
    local offers = {}
    local activeContacts = TQ.Factions and TQ.Factions.getActiveContactMap(player) or nil

    for _, template in ipairs(TQ.getQuestTemplates()) do
        local templateContact = tostring(template.contact or template.contactId or "")
        local matchesContact = not contactId or tostring(contactId) == "" or templateContact == tostring(contactId)
        local contactIsActive = not activeContacts or activeContacts[templateContact] == true
        local uniqueBlocked = template.unique ~= false and hasActiveTemplate(data, tostring(template.id))

        if matchesContact and contactIsActive and not uniqueBlocked and TQ.Conditions.evaluate(template.condition, player, { template = template }) then
            local contact = TQ.getContact(templateContact)
            local factionId = tostring(template.factionId or (TQ.Factions and TQ.Factions.getFactionIdForContact(contact)) or "independent")
            local faction = TQ.getFaction(factionId)
            table.insert(offers, {
                type = "offer",
                templateId = tostring(template.id),
                title = tostring(template.title or template.name or template.id),
                description = tostring(template.description or ""),
                difficulty = tostring(template.difficulty or "easy"),
                contactId = templateContact,
                contactName = tostring((contact and contact.name) or templateContact),
                factionId = factionId,
                factionName = tostring((faction and faction.name) or factionId),
                template = template,
            })
        end
    end

    table.sort(offers, function(a, b)
        return tostring(a.title) < tostring(b.title)
    end)

    if limit and #offers > limit then
        local trimmed = {}
        while #trimmed < limit and #offers > 0 do
            local index = TQ.randomInt(1, #offers)
            table.insert(trimmed, table.remove(offers, index))
        end
        return trimmed
    end

    return offers
end

function TQ.QuestManager.acceptQuest(player, templateId, options)
    local data = TQ.Save.getData(player)
    local template = TQ.getQuestTemplate(templateId)
    if not template then
        return nil, "missing_template"
    end

    if template.unique ~= false and hasActiveTemplate(data, tostring(templateId)) then
        return nil, "already_active"
    end

    local contactId = tostring(template.contact or template.contactId or "")
    if contactId ~= "" and TQ.Factions and not TQ.Factions.isContactActive(player, contactId) then
        return nil, "contact_inactive"
    end

    local questId = TQ.Save.allocateQuestId(data)
    local quest = TQ.QuestFactory.build(templateId, questId, player, options)
    if not quest then
        return nil, "build_failed"
    end

    TQ.QuestManager.updateQuestProgress(quest, player)
    table.insert(data.active, quest)
    table.insert(data.history, {
        event = "accepted",
        questId = quest.id,
        templateId = quest.templateId,
        contactId = quest.contactId,
        factionId = quest.factionId,
        at = TQ.getWorldAgeHours(),
    })
    TQ.Save.touch(player)
    return quest
end

function TQ.QuestManager.canTurnIn(player, quest)
    if not quest then
        return false, "missing_quest"
    end

    TQ.QuestManager.updateQuestProgress(quest, player)

    if quest.status ~= "readyToTurnIn" then
        return false, "objectives_incomplete"
    end

    if quest.turnIn and not TQ.isPlayerNearTurnIn(player, quest.turnIn) then
        return false, "wrong_location"
    end

    return true
end

function TQ.QuestManager.turnInQuest(player, questId)
    local quest = TQ.QuestManager.findActiveQuest(player, questId)
    if not quest then
        return nil, "missing_quest"
    end

    local canTurnIn, reason = TQ.QuestManager.canTurnIn(player, quest)
    if not canTurnIn then
        return nil, reason
    end

    for _, objective in ipairs(quest.objectives or {}) do
        if not TQ.Objectives.consume(objective, quest, player) then
            return nil, "consume_failed"
        end
    end

    if type(quest.rewardChoices) ~= "table" or #quest.rewardChoices == 0 then
        quest.rewardChoices = TQ.Rewards.buildChoices(quest.rewardSpec, {
            contact = TQ.getContact(quest.contactId),
            faction = TQ.getFaction(quest.factionId),
            difficulty = quest.difficulty,
        })
    end

    quest.status = "rewardPending"
    quest.turnedInAt = TQ.getWorldAgeHours()
    TQ.Save.touch(player)
    return quest
end

function TQ.QuestManager.chooseReward(player, questId, rewardIndex)
    local quest, index, data = TQ.QuestManager.findActiveQuest(player, questId)
    if not quest then
        return nil, "missing_quest"
    end

    if quest.status ~= "rewardPending" then
        return nil, "not_reward_pending"
    end

    local reward = quest.rewardChoices and quest.rewardChoices[tonumber(rewardIndex) or 1]
    if not reward then
        return nil, "missing_reward"
    end

    if not TQ.Rewards.grant(player, reward) then
        return nil, "grant_failed"
    end

    quest.status = "completed"
    quest.completedAt = TQ.getWorldAgeHours()
    quest.selectedReward = TQ.deepcopy(reward)

    if TQ.Factions and TQ.Factions.awardQuestReputation then
        TQ.Factions.awardQuestReputation(player, quest)
    end

    table.remove(data.active, index)
    table.insert(data.completed, quest)
    table.insert(data.history, {
        event = "completed",
        questId = quest.id,
        templateId = quest.templateId,
        contactId = quest.contactId,
        factionId = quest.factionId,
        reputation = quest.reputationAwarded,
        at = quest.completedAt,
    })

    TQ.Save.touch(player)
    return reward, quest
end

function TQ.QuestManager.failQuest(player, questId, reason)
    local quest, index, data = TQ.QuestManager.findActiveQuest(player, questId)
    if not quest then
        return false
    end

    quest.status = "failed"
    quest.failedAt = TQ.getWorldAgeHours()
    quest.failedReason = reason
    table.remove(data.active, index)
    table.insert(data.failed, quest)
    TQ.Save.touch(player)
    return true
end
