require "TrueQuests/UI/TQ_DebugWindow"

local DebugContext = {}

local function getContextPlayer(playerNum)
    if getSpecificPlayer then
        return getSpecificPlayer(playerNum)
    end
    return getPlayer()
end

function DebugContext.onWorldContext(playerNum, context, worldObjects, test)
    if test then
        return
    end

    local player = getContextPlayer(playerNum)
    context:addOption("True Quests Debug", player, function(selectedPlayer)
        TQ_DebugWindow.Toggle(selectedPlayer)
    end)
end

Events.OnFillWorldObjectContextMenu.Add(DebugContext.onWorldContext)
