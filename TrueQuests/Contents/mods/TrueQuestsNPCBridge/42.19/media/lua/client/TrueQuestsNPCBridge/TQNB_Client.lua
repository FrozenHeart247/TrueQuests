require "TrueNPC/TN_API"
require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_QuestBoardWindow"

local TN = TrueNPC
local TQ = TrueQuests

TN.Client.registerInteractionHandler("truequests_contact", function(player, npc, zombie, interaction)
    local contactId = tostring((interaction and interaction.contactId) or npc.contactId or "")
    if contactId == "" or not TQ.getContact(contactId) then
        return false
    end

    if TQ.Factions and npc.factionId then
        TQ.Factions.discoverFaction(player, npc.factionId)
    end

    local window = TQ_QuestBoardWindow.Open(player, nil)
    if window and window.openContact then
        window:openContact(contactId)
    end
    return true
end)

TN.log("True Quests NPC bridge client loaded")
