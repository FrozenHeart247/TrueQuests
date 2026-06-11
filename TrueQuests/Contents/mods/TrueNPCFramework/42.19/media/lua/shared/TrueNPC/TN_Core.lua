TrueNPC = TrueNPC or {}

local TN = TrueNPC

if not TN._coreLoaded then
    TN._coreLoaded = true

    TN.VERSION = "0.1.0"
    TN.API_VERSION = 1
    TN.DATA_VERSION = 1
    TN.MOD_ID = "TrueNPCFramework"
    TN.DEBUG = false

    function TN.log(message)
        print("[TrueNPC] " .. tostring(message))
    end

    function TN.debug(message)
        if TN.DEBUG then
            TN.log(message)
        end
    end

    function TN.warn(message)
        print("[TrueNPC:WARN] " .. tostring(message))
    end

    function TN.deepcopy(value, seen)
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
            copy[TN.deepcopy(key, seen)] = TN.deepcopy(child, seen)
        end
        return copy
    end

    function TN.ensureTable(parent, key)
        if type(parent[key]) ~= "table" then
            parent[key] = {}
        end
        return parent[key]
    end

    function TN.getWorldAgeHours()
        if getGameTime then
            local time = getGameTime()
            if time and time.getWorldAgeHours then
                return time:getWorldAgeHours()
            end
        end
        return 0
    end

    function TN.distanceSq(ax, ay, bx, by)
        local dx = (tonumber(ax) or 0) - (tonumber(bx) or 0)
        local dy = (tonumber(ay) or 0) - (tonumber(by) or 0)
        return dx * dx + dy * dy
    end

    function TN.isPlayerNear(player, point, radius)
        if not player or type(point) ~= "table" then
            return false
        end

        radius = tonumber(radius or point.radius) or 10
        local x = tonumber(point.x)
        local y = tonumber(point.y)
        local z = tonumber(point.z) or 0
        if not x or not y then
            return false
        end

        local px = player.getX and player:getX() or 0
        local py = player.getY and player:getY() or 0
        local pz = player.getZ and player:getZ() or 0
        if math.floor(pz) ~= math.floor(z) then
            return false
        end

        return TN.distanceSq(px, py, x, y) <= radius * radius
    end

    function TN.safeCall(fn, ...)
        if type(fn) ~= "function" then
            return true, nil
        end

        local ok, result = pcall(fn, ...)
        if not ok then
            TN.warn(result)
            return false, nil
        end
        return true, result
    end

    function TN.getZombieUID(zombie)
        if zombie and zombie.getUID then
            return zombie:getUID()
        end
        return nil
    end

    function TN.getZombieOnlineId(zombie)
        if zombie and zombie.getOnlineID then
            return zombie:getOnlineID()
        end
        return nil
    end

    function TN.getZombieNPCId(zombie)
        if not zombie or not zombie.getModData then
            return nil
        end

        local modData = zombie:getModData()
        local data = modData and modData.TrueNPC
        if type(data) == "table" and data.npcId then
            return tostring(data.npcId)
        end

        if modData and modData.TrueNPCId then
            return tostring(modData.TrueNPCId)
        end

        return nil
    end
end
