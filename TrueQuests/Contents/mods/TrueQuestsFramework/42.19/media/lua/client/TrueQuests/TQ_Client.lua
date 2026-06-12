require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_RewardChoiceWindow"
require "TrueQuests/UI/TQ_QuestMarker"
require "TrueQuests/UI/TQ_QuestBoardWindow"
require "TrueQuests/UI/TQ_QuestJournalWindow"
require "TrueQuests/TQ_QuestJournalButton"
require "TrueQuests/TQ_RadioContext"

TrueQuests.Client = TrueQuests.Client or {}

function TrueQuests.Client.updatePlayerQuestTimers(player)
    if player and TrueQuests.QuestManager and TrueQuests.QuestManager.updateAll then
        TrueQuests.QuestManager.updateAll(player)
    end
    if player and TrueQuests.QuestItems and TrueQuests.QuestItems.ensureForPlayer then
        TrueQuests.QuestItems.ensureForPlayer(player)
    end
end

function TrueQuests.Client.updateAllPlayerQuestTimers()
    if not getSpecificPlayer then
        return
    end

    for playerNum = 0, 3 do
        TrueQuests.Client.updatePlayerQuestTimers(getSpecificPlayer(playerNum))
    end
end

function TrueQuests.Client.updateAllPlayerQuestItems()
    if not getSpecificPlayer or not TrueQuests.QuestItems or not TrueQuests.QuestItems.ensureForPlayer then
        return
    end

    for playerNum = 0, 3 do
        TrueQuests.QuestItems.ensureForPlayer(getSpecificPlayer(playerNum))
    end
end

if Events and Events.EveryTenMinutes then
    Events.EveryTenMinutes.Add(TrueQuests.Client.updateAllPlayerQuestTimers)
end

if Events and Events.EveryOneMinute then
    Events.EveryOneMinute.Add(TrueQuests.Client.updateAllPlayerQuestItems)
end

TrueQuests.log("Client loaded v" .. tostring(TrueQuests.VERSION))
