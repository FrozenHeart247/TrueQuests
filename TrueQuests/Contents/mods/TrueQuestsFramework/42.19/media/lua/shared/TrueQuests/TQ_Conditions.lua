require "TrueQuests/TQ_Core"
require "TrueQuests/TQ_Save"

local TQ = TrueQuests

TQ.Conditions = TQ.Conditions or {}

local function evalOne(condition, player, context)
    if condition == nil then
        return true
    end

    if type(condition) == "function" then
        local ok, result = pcall(condition, player, context)
        return ok and result == true
    end

    if type(condition) ~= "table" then
        return condition == true
    end

    if condition.all then
        for _, child in ipairs(condition.all) do
            if not evalOne(child, player, context) then
                return false
            end
        end
        return true
    end

    if condition.any then
        for _, child in ipairs(condition.any) do
            if evalOne(child, player, context) then
                return true
            end
        end
        return false
    end

    if condition.notCondition then
        return not evalOne(condition.notCondition, player, context)
    end

    local conditionType = tostring(condition.type or "")

    if conditionType == "trait" then
        return player and player.HasTrait and player:HasTrait(tostring(condition.trait))
    end

    if conditionType == "reputationAtLeast" then
        local data = TQ.Save.getData(player)
        local faction = tostring(condition.faction or "")
        local value = tonumber(data.reputation[faction]) or 0
        return value >= (tonumber(condition.amount) or 0)
    end

    if conditionType == "custom" and type(condition.fn) == "function" then
        local ok, result = pcall(condition.fn, player, context)
        return ok and result == true
    end

    return true
end

function TQ.Conditions.evaluate(condition, player, context)
    return evalOne(condition, player, context or {})
end

