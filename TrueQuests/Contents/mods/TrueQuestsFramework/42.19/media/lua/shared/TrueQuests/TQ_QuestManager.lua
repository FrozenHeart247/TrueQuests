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

local OFFER_REFRESH_HOURS = 6
local DEFAULT_CONTACT_OFFER_LIMIT = 3

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
        if tostring(quest.templateId or "") == templateId and quest.status ~= "completed" and quest.status ~= "failed" then
            return true
        end
    end
    return false
end

local function hasCompletedTemplate(data, templateId)
    for _, quest in ipairs(data.completed or {}) do
        if tostring(quest.templateId or "") == templateId and quest.status ~= "failed" then
            return true
        end
    end
    return false
end

local function hasCompletedTemplateSince(data, templateId, since)
    since = tonumber(since) or 0
    for _, quest in ipairs(data.completed or {}) do
        if tostring(quest.templateId or "") == templateId and quest.status ~= "failed" then
            if (tonumber(quest.completedAt) or 0) >= since then
                return true
            end
        end
    end
    return false
end

local function getOfferState(data)
    data.offers = type(data.offers) == "table" and data.offers or {}
    data.offers.refreshAt = tonumber(data.offers.refreshAt) or 0
    data.offers.generatedAt = tonumber(data.offers.generatedAt) or math.max(0, data.offers.refreshAt - OFFER_REFRESH_HOURS)
    data.offers.generation = tonumber(data.offers.generation) or 0
    data.offers.byContact = type(data.offers.byContact) == "table" and data.offers.byContact or {}
    return data.offers
end

local function ensureOfferWindow(data)
    local state = getOfferState(data)
    local now = TQ.getWorldAgeHours()

    if state.refreshAt <= 0 or now >= state.refreshAt then
        state.refreshAt = now + OFFER_REFRESH_HOURS
        state.generatedAt = now
        state.generation = (tonumber(state.generation) or 0) + 1
        state.byContact = {}
        return state, true
    end

    return state, false
end

local function ensureFailureNotices(data)
    data.contacts = type(data.contacts) == "table" and data.contacts or {}
    data.contacts.failedByFaction = type(data.contacts.failedByFaction) == "table" and data.contacts.failedByFaction or {}
    return data.contacts.failedByFaction
end

local function failurePenaltyForQuest(quest)
    if not quest then
        return 0
    end

    local explicit = quest.failureReputation or quest.reputationPenalty or quest.reputationOnFailure
    if explicit ~= nil then
        local amount = tonumber(explicit) or 0
        if amount > 0 then
            amount = -amount
        end
        return amount
    end

    local gain = 0
    if TQ.Factions and TQ.Factions.getQuestReputationGain then
        gain = tonumber(TQ.Factions.getQuestReputationGain(quest)) or 0
    end

    if gain <= 0 then
        return -1
    end

    return -math.max(1, math.floor(gain / 2))
end

local function applyFailureReputation(player, quest)
    if not quest or quest.reputationFailed then
        return 0
    end

    local amount = failurePenaltyForQuest(quest)
    local factionId = tostring(quest.factionId or "independent")
    local contactId = quest.contactId and tostring(quest.contactId) or nil

    if amount ~= 0 and TQ.Factions and TQ.Factions.addReputation then
        TQ.Factions.addReputation(player, factionId, amount, contactId, { deferTouch = true })
    end

    quest.reputationFailed = {
        factionId = factionId,
        contactId = contactId,
        amount = amount,
    }

    return amount
end

local function recordFailureNotice(data, quest, reason, penalty)
    if not quest then
        return
    end

    local factionId = tostring(quest.factionId or "independent")
    local notices = ensureFailureNotices(data)
    local notice = notices[factionId]
    if type(notice) ~= "table" then
        notice = { count = 0 }
    end

    notice.count = (tonumber(notice.count) or 0) + 1
    notice.questId = tostring(quest.id or "")
    notice.templateId = tostring(quest.templateId or "")
    notice.questTitle = tostring(quest.title or quest.templateId or "request")
    notice.contactId = tostring(quest.contactId or "")
    notice.reason = tostring(reason or "failed")
    notice.penalty = tonumber(penalty) or 0
    notice.lastAt = tonumber(quest.failedAt) or TQ.getWorldAgeHours()
    notice.acknowledged = false
    notices[factionId] = notice
end

local function failActiveQuestAtIndex(player, data, index, reason)
    if type(data) ~= "table" or type(data.active) ~= "table" then
        return false
    end

    local quest = data.active[index]
    if not quest then
        return false
    end

    quest.status = "failed"
    quest.failedAt = TQ.getWorldAgeHours()
    quest.failedReason = tostring(reason or "failed")
    local penalty = applyFailureReputation(player, quest)
    recordFailureNotice(data, quest, reason, penalty)

    table.remove(data.active, index)
    data.failed = type(data.failed) == "table" and data.failed or {}
    table.insert(data.failed, quest)

    data.history = type(data.history) == "table" and data.history or {}
    table.insert(data.history, {
        event = "failed",
        questId = quest.id,
        templateId = quest.templateId,
        contactId = quest.contactId,
        factionId = quest.factionId,
        reason = quest.failedReason,
        reputation = quest.reputationFailed,
        at = quest.failedAt,
    })

    return true
end

local function isCompletedBlocked(data, template, offerState)
    if not template or template.unique == false then
        return false
    end

    local templateId = tostring(template.id)
    if template.repeatable == true then
        return hasCompletedTemplateSince(data, templateId, offerState and offerState.generatedAt)
    end

    return hasCompletedTemplate(data, templateId)
end

local function getContactOfferLimit(contactId, limit)
    local explicit = tonumber(limit)
    if explicit and explicit > 0 then
        return math.floor(explicit)
    end

    local contact = TQ.getContact(contactId)
    local contactLimit = tonumber(contact and (contact.maxOffers or contact.maxJobs))
    if contactLimit and contactLimit > 0 then
        return math.floor(contactLimit)
    end

    local factionId = TQ.Factions and TQ.Factions.getFactionIdForContact(contact) or nil
    local faction = TQ.getFaction(factionId)
    local factionLimit = tonumber(faction and (faction.maxOffers or faction.maxJobs))
    if factionLimit and factionLimit > 0 then
        return math.floor(factionLimit)
    end

    return DEFAULT_CONTACT_OFFER_LIMIT
end

local function makeOfferMap(offers)
    local byTemplateId = {}
    for _, offer in ipairs(offers or {}) do
        byTemplateId[tostring(offer.templateId or "")] = offer
    end
    return byTemplateId
end

local function pickCachedTemplateIds(offers, desired, previousIds)
    local selected = {}
    local seen = {}
    local byTemplateId = makeOfferMap(offers)

    for _, templateId in ipairs(previousIds or {}) do
        templateId = tostring(templateId or "")
        if byTemplateId[templateId] and not seen[templateId] and #selected < desired then
            seen[templateId] = true
            table.insert(selected, templateId)
        end
    end

    local pool = {}
    for _, offer in ipairs(offers or {}) do
        local templateId = tostring(offer.templateId or "")
        if not seen[templateId] then
            table.insert(pool, offer)
        end
    end

    while #selected < desired and #pool > 0 do
        local index = TQ.randomInt(1, #pool)
        local offer = table.remove(pool, index)
        local templateId = tostring(offer.templateId or "")
        seen[templateId] = true
        table.insert(selected, templateId)
    end

    return selected
end

local function offersForTemplateIds(offers, templateIds)
    local byTemplateId = makeOfferMap(offers)
    local result = {}

    for _, templateId in ipairs(templateIds or {}) do
        local offer = byTemplateId[tostring(templateId or "")]
        if offer then
            table.insert(result, offer)
        end
    end

    return result
end

local function sameIds(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then
        return false
    end

    if #a ~= #b then
        return false
    end

    for index, value in ipairs(a) do
        if tostring(value or "") ~= tostring(b[index] or "") then
            return false
        end
    end

    return true
end

local function cacheContactOffers(player, data, contactId, offers, limit)
    local desired = getContactOfferLimit(contactId, limit)
    if desired <= 0 or #offers == 0 then
        return {}
    end

    local state, changed = ensureOfferWindow(data)
    local contactKey = tostring(contactId or "")
    local contactState = state.byContact[contactKey]
    local previousIds = contactState and contactState.templateIds or nil
    local selectedIds = nil

    if desired >= #offers then
        selectedIds = {}
        for _, offer in ipairs(offers) do
            table.insert(selectedIds, tostring(offer.templateId or ""))
        end
    else
        selectedIds = pickCachedTemplateIds(offers, desired, previousIds)
    end

    if not contactState or not sameIds(previousIds, selectedIds) then
        state.byContact[contactKey] = {
            templateIds = selectedIds,
            generatedAt = state.generatedAt or TQ.getWorldAgeHours(),
            refreshAt = state.refreshAt,
        }
        changed = true
    end

    if changed then
        TQ.Save.touch(player)
    end

    return offersForTemplateIds(offers, selectedIds)
end

function TQ.QuestManager.getActiveQuests(player)
    local data = TQ.Save.getData(player)
    return data.active
end

function TQ.QuestManager.isQuestExpired(quest)
    if not quest then
        return false
    end

    if quest.status == "rewardPending" or quest.status == "completed" or quest.status == "failed" then
        return false
    end

    local expiresAt = tonumber(quest.expiresAt)
    return expiresAt ~= nil and expiresAt > 0 and TQ.getWorldAgeHours() >= expiresAt
end

function TQ.QuestManager.getQuestTimeRemaining(quest)
    local expiresAt = tonumber(quest and quest.expiresAt)
    if not expiresAt or expiresAt <= 0 then
        return nil
    end

    return math.max(0, expiresAt - TQ.getWorldAgeHours())
end

function TQ.QuestManager.formatTimeRemaining(quest)
    local remaining = TQ.QuestManager.getQuestTimeRemaining(quest)
    if remaining == nil then
        return "No deadline"
    end
    if remaining <= 0 then
        return "Expired"
    end

    local hours = math.ceil(remaining)
    if hours >= 24 then
        local days = math.floor(hours / 24)
        local rest = hours - (days * 24)
        if rest > 0 then
            return tostring(days) .. "d " .. tostring(rest) .. "h"
        end
        return tostring(days) .. "d"
    end

    return tostring(hours) .. "h"
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
    local changed = false
    for index = #(data.active or {}), 1, -1 do
        local quest = data.active[index]
        if TQ.QuestManager.isQuestExpired(quest) then
            if failActiveQuestAtIndex(player, data, index, "expired") then
                changed = true
            end
        else
            TQ.QuestManager.updateQuestProgress(quest, player)
        end
    end

    if changed then
        TQ.Save.touch(player)
    end
    return data.active
end

function TQ.QuestManager.getOffers(player, contactId, limit)
    local data = TQ.Save.getData(player)
    local offerState, offerStateChanged = ensureOfferWindow(data)
    if offerStateChanged then
        TQ.Save.touch(player)
    end

    local offers = {}
    local activeContacts = TQ.Factions and TQ.Factions.getActiveContactMap(player) or nil

    for _, template in ipairs(TQ.getQuestTemplates()) do
        local templateContact = tostring(template.contact or template.contactId or "")
        local matchesContact = not contactId or tostring(contactId) == "" or templateContact == tostring(contactId)
        local contactIsActive = not activeContacts or activeContacts[templateContact] == true
        local templateId = tostring(template.id)
        local uniqueBlocked = template.unique ~= false and hasActiveTemplate(data, templateId)
        local completedBlocked = isCompletedBlocked(data, template, offerState)

        if matchesContact and contactIsActive and not uniqueBlocked and not completedBlocked and TQ.Conditions.evaluate(template.condition, player, { template = template }) then
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

    if contactId and tostring(contactId) ~= "" then
        return cacheContactOffers(player, data, tostring(contactId), offers, limit)
    end

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
    local offerState, offerStateChanged = ensureOfferWindow(data)
    if offerStateChanged then
        TQ.Save.touch(player)
    end

    local template = TQ.getQuestTemplate(templateId)
    if not template then
        return nil, "missing_template"
    end

    if template.unique ~= false then
        if hasActiveTemplate(data, tostring(templateId)) then
            return nil, "already_active"
        end
        if isCompletedBlocked(data, template, offerState) then
            return nil, "already_completed"
        end
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

    if TQ.QuestManager.isQuestExpired(quest) then
        TQ.QuestManager.failQuest(player, quest.id, "expired")
        return false, "expired"
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

    local failed = failActiveQuestAtIndex(player, data, index, reason)
    if failed then
        TQ.Save.touch(player)
    end
    return failed
end

function TQ.QuestManager.getPendingFailureNotice(player, factionId)
    local data = TQ.Save.getData(player)
    local notices = ensureFailureNotices(data)
    local notice = notices[tostring(factionId or "independent")]
    if type(notice) == "table" and notice.acknowledged ~= true then
        return notice
    end
    return nil
end

function TQ.QuestManager.acknowledgeFailureNotice(player, factionId)
    local data = TQ.Save.getData(player)
    local notices = ensureFailureNotices(data)
    local notice = notices[tostring(factionId or "independent")]
    if type(notice) ~= "table" or notice.acknowledged == true then
        return false
    end

    notice.acknowledged = true
    notice.acknowledgedAt = TQ.getWorldAgeHours()
    TQ.Save.touch(player)
    return true
end
