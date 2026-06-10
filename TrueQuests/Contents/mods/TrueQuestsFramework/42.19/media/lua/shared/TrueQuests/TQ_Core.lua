TrueQuests = TrueQuests or {}

local TQ = TrueQuests

if not TQ._coreLoaded then
    TQ._coreLoaded = true

    TQ.VERSION = "0.1.0"
    TQ.API_VERSION = 1
    TQ.DATA_VERSION = 3
    TQ.MOD_ID = "TrueQuestsFramework"
    TQ.DEBUG = false

    function TQ.log(message)
        print("[TrueQuests] " .. tostring(message))
    end

    function TQ.debug(message)
        if TQ.DEBUG then
            TQ.log(message)
        end
    end

    function TQ.warn(message)
        print("[TrueQuests:WARN] " .. tostring(message))
    end

    function TQ.deepcopy(value, seen)
        if type(value) ~= "table" then
            return value
        end

        seen = seen or {}
        if seen[value] then
            return seen[value]
        end

        local copy = {}
        seen[value] = copy
        for key, child in pairs(value) do
            copy[TQ.deepcopy(key, seen)] = TQ.deepcopy(child, seen)
        end
        return copy
    end

    function TQ.ensureTable(parent, key)
        if type(parent[key]) ~= "table" then
            parent[key] = {}
        end
        return parent[key]
    end

    function TQ.randomInt(minValue, maxValue)
        minValue = tonumber(minValue) or 0
        maxValue = tonumber(maxValue) or minValue
        if maxValue < minValue then
            minValue, maxValue = maxValue, minValue
        end

        if ZombRand then
            return ZombRand(minValue, maxValue + 1)
        end

        return math.random(minValue, maxValue)
    end

    function TQ.numberFromRange(value, fallback)
        fallback = fallback or 1

        if type(value) == "table" then
            local minValue = value.min or value[1] or fallback
            local maxValue = value.max or value[2] or minValue
            return TQ.randomInt(minValue, maxValue)
        end

        return tonumber(value) or fallback
    end

    function TQ.weightedPick(entries)
        if type(entries) ~= "table" or #entries == 0 then
            return nil
        end

        local total = 0
        for _, entry in ipairs(entries) do
            total = total + math.max(0, tonumber(entry.weight) or 1)
        end

        if total <= 0 then
            return entries[TQ.randomInt(1, #entries)]
        end

        local roll = TQ.randomInt(1, total)
        local cursor = 0
        for _, entry in ipairs(entries) do
            cursor = cursor + math.max(0, tonumber(entry.weight) or 1)
            if roll <= cursor then
                return entry
            end
        end

        return entries[#entries]
    end

    function TQ.getWorldAgeHours()
        if getGameTime then
            local time = getGameTime()
            if time and time.getWorldAgeHours then
                return time:getWorldAgeHours()
            end
        end
        return 0
    end

    function TQ.findScriptItem(fullType)
        if not fullType or not getScriptManager then
            return nil
        end

        local manager = getScriptManager()
        if not manager or not manager.FindItem then
            return nil
        end

        local ok, item = pcall(function()
            return manager:FindItem(tostring(fullType))
        end)

        if ok then
            return item
        end
        return nil
    end

    function TQ.getItemDisplayName(fullType)
        local scriptItem = TQ.findScriptItem(fullType)
        if scriptItem and scriptItem.getDisplayName then
            return scriptItem:getDisplayName()
        end
        return tostring(fullType or "Unknown item")
    end

    function TQ.getItemTexture(fullType)
        local scriptItem = TQ.findScriptItem(fullType)
        if scriptItem and scriptItem.getIcon and getTexture then
            local icon = scriptItem:getIcon()
            if icon and tostring(icon) ~= "" then
                return getTexture("Item_" .. tostring(icon))
            end
        end
        return nil
    end

    function TQ.say(player, text)
        if player and player.Say then
            player:Say(tostring(text))
        else
            TQ.log(text)
        end
    end

    function TQ.isPlayerNearTurnIn(player, turnIn)
        if not player or type(turnIn) ~= "table" then
            return false
        end

        local radius = tonumber(turnIn.radius) or 8
        local x = tonumber(turnIn.x)
        local y = tonumber(turnIn.y)
        local z = tonumber(turnIn.z) or 0

        if not x or not y then
            return false
        end

        local px = player.getX and player:getX() or 0
        local py = player.getY and player:getY() or 0
        local pz = player.getZ and player:getZ() or 0

        if math.floor(pz) ~= math.floor(z) then
            return false
        end

        local dx = px - x
        local dy = py - y
        return (dx * dx + dy * dy) <= (radius * radius)
    end

    function TQ.turnInToText(turnIn)
        if type(turnIn) ~= "table" then
            return "Unknown location"
        end

        if turnIn.label then
            return tostring(turnIn.label)
        end

        if turnIn.x and turnIn.y then
            return tostring(math.floor(turnIn.x)) .. ", " .. tostring(math.floor(turnIn.y))
        end

        return "Unknown location"
    end
end
