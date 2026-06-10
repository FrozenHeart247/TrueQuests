require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_QuestBoardWindow"

TrueQuests.RadioContext = TrueQuests.RadioContext or {}

local RadioContext = TrueQuests.RadioContext

local function getDeviceData(device)
    if device and device.getDeviceData then
        return device:getDeviceData()
    end
    return nil
end

local function isRadioDevice(device)
    local data = getDeviceData(device)
    if data then
        return true
    end

    if device and device.getFullType then
        local fullType = tostring(device:getFullType())
        return string.find(string.lower(fullType), "radio", 1, true) ~= nil
            or string.find(string.lower(fullType), "walkietalkie", 1, true) ~= nil
    end

    return false
end

local function isOperational(device)
    local data = getDeviceData(device)
    if not data then
        return true
    end

    if data.getIsTurnedOn and not data:getIsTurnedOn() then
        return false
    end

    if data.getPower and data:getPower() <= 0 then
        return false
    end

    return true
end

local function containerHasItem(container, target)
    if not container or not target or not container.getItems then
        return false
    end

    local items = container:getItems()
    if not items then
        return false
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item == target then
            return true
        end

        if item and item.getInventory and containerHasItem(item:getInventory(), target) then
            return true
        end
    end

    return false
end

local function playerHasItem(player, item)
    if not player or not item or not player.getInventory then
        return false
    end

    return containerHasItem(player:getInventory(), item)
end

local function getObjectSquare(device)
    if not device then
        return nil
    end

    if device.getSquare then
        local square = device:getSquare()
        if square then
            return square
        end
    end

    if device.getWorldItem then
        local worldItem = device:getWorldItem()
        if worldItem and worldItem.getSquare then
            return worldItem:getSquare()
        end
    end

    return nil
end

local function isCloseToSquare(player, square, maxDistance)
    if not player or not square or not player.getSquare then
        return false
    end

    local playerSquare = player:getSquare()
    if not playerSquare then
        return false
    end

    if playerSquare.getZ and square.getZ and playerSquare:getZ() ~= square:getZ() then
        return false
    end

    local dx = 0
    local dy = 0

    if playerSquare.getX and square.getX then
        dx = playerSquare:getX() - square:getX()
    elseif player.getX and square.getX then
        dx = player:getX() - square:getX()
    end

    if playerSquare.getY and square.getY then
        dy = playerSquare:getY() - square:getY()
    elseif player.getY and square.getY then
        dy = player:getY() - square:getY()
    end

    maxDistance = maxDistance or 3
    return (dx * dx + dy * dy) <= (maxDistance * maxDistance)
end

local function isDeviceAccessible(player, device)
    if not device then
        return true
    end

    if not isOperational(device) then
        return false
    end

    if playerHasItem(player, device) then
        return true
    end

    local square = getObjectSquare(device)
    if square then
        return isCloseToSquare(player, square, 3)
    end

    return true
end

local function normalizeInventoryEntry(entry)
    if isRadioDevice(entry) then
        return entry
    end

    if type(entry) == "table" then
        if entry.items and entry.items[1] and isRadioDevice(entry.items[1]) then
            return entry.items[1]
        end
        if entry.item and isRadioDevice(entry.item) then
            return entry.item
        end
    end

    return nil
end

local function findInventoryRadio(items)
    if type(items) ~= "table" then
        return nil
    end

    for _, entry in ipairs(items) do
        local device = normalizeInventoryEntry(entry)
        if device then
            return device
        end
    end
    return nil
end

local function findWorldRadio(worldObjects)
    if type(worldObjects) ~= "table" then
        return nil
    end

    for _, object in ipairs(worldObjects) do
        if isRadioDevice(object) then
            return object
        end

        if object and object.getItem then
            local item = object:getItem()
            if isRadioDevice(item) then
                return item
            end
        end
    end
    return nil
end

local function addOption(playerNum, context, device)
    if not device or not context then
        return
    end

    local player = getSpecificPlayer and getSpecificPlayer(playerNum) or getPlayer()
    local option = context:addOption("Look for survivor requests", device, function(selectedDevice)
        TQ_QuestBoardWindow.Toggle(player, selectedDevice)
    end)

    if not isOperational(device) then
        option.notAvailable = true
        if ISWorldObjectContextMenu and ISWorldObjectContextMenu.addToolTip then
            option.toolTip = ISWorldObjectContextMenu.addToolTip()
            option.toolTip.description = "Radio must be turned on and have power."
        end
    end
end

RadioContext.getDeviceData = getDeviceData
RadioContext.isRadioDevice = isRadioDevice
RadioContext.isOperational = isOperational
RadioContext.isDeviceAccessible = isDeviceAccessible

function RadioContext.onInventoryContext(playerNum, context, items)
    addOption(playerNum, context, findInventoryRadio(items))
end

function RadioContext.onWorldContext(playerNum, context, worldObjects, test)
    if test then
        return
    end
    addOption(playerNum, context, findWorldRadio(worldObjects))
end

Events.OnFillInventoryObjectContextMenu.Add(RadioContext.onInventoryContext)
Events.OnFillWorldObjectContextMenu.Add(RadioContext.onWorldContext)
