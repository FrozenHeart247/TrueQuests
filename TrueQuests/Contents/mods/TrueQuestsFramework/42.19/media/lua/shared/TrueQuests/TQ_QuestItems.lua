require "TrueQuests/TQ_Core"

local TQ = TrueQuests

TQ.QuestItems = TQ.QuestItems or {}

local QUEST_ITEM_KEY = "TrueQuests"
local SPAWN_VERSION = 2

local function resolveSourceValue(value, context)
    if type(value) == "function" then
        local ok, result = pcall(value, context or {})
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

local function normalizeSource(source)
    if type(source) ~= "table" then
        return nil
    end

    local location = type(source.location) == "table" and source.location or source
    local result = TQ.deepcopy(source)
    result.x = tonumber(location.x or source.x)
    result.y = tonumber(location.y or source.y)
    result.z = tonumber(location.z or source.z) or 0
    result.radius = tonumber(source.radius or location.radius) or 12
    result.activationRange = tonumber(source.activationRange or location.activationRange) or 180

    if not result.x or not result.y then
        return nil
    end

    local mode = tostring(source.mode or source.sourceType or source.type or "world")
    if mode == "ground" or mode == "location" or mode == "zone" then
        mode = "world"
    elseif mode == "carrier" or mode == "corpse" then
        mode = "zombie"
    end
    result.mode = mode

    if not result.label or result.label == "" then
        result.label = "Search area (" .. tostring(math.floor(result.x)) .. ", " .. tostring(math.floor(result.y)) .. ")"
    end

    return result
end

local function makeObjectiveId(templateObjective, context)
    local explicit = templateObjective.id or templateObjective.objectiveId
    if explicit and tostring(explicit) ~= "" then
        return tostring(explicit)
    end

    return "objective_" .. tostring(context and context.objectiveIndex or 1)
end

function TQ.QuestItems.resolveSource(templateObjective, context)
    if type(templateObjective) ~= "table" then
        return nil
    end

    local source = resolveSourceValue(templateObjective.source or templateObjective.spawn or templateObjective.questSource, context)
    return normalizeSource(source)
end

function TQ.QuestItems.prepareObjective(instance, templateObjective, context)
    if type(instance) ~= "table" or type(templateObjective) ~= "table" then
        return instance
    end

    local source = TQ.QuestItems.resolveSource(templateObjective, context)
    local isQuestItem = templateObjective.questItem == true or templateObjective.uniqueItem == true or source ~= nil
    if not isQuestItem then
        return instance
    end

    local objectiveId = makeObjectiveId(templateObjective, context)
    local questId = tostring(context and context.questId or "quest")
    local item = tostring(templateObjective.item or instance.item or "item")
    local questItemId = tostring(templateObjective.questItemId or templateObjective.uniqueItemId or (questId .. ":" .. objectiveId .. ":" .. item))

    instance.objectiveId = objectiveId
    instance.questItemId = questItemId
    instance.questItemName = templateObjective.questItemName or templateObjective.customName or templateObjective.label
    instance.questItemTooltip = templateObjective.questItemTooltip or templateObjective.tooltip
    instance.source = source
    instance.sourceHint = templateObjective.sourceHint
    instance.spawned = false
    instance.spawnedOn = nil

    if source and source.marker ~= false and templateObjective.marker ~= false then
        instance.marker = {
            x = source.x,
            y = source.y,
            z = source.z,
            label = source.markerLabel or source.label,
            sourceMode = source.mode,
        }
    end

    return instance
end

local function getQuestItemData(item)
    if not item or not item.getModData then
        return nil
    end

    local modData = item:getModData()
    modData[QUEST_ITEM_KEY] = type(modData[QUEST_ITEM_KEY]) == "table" and modData[QUEST_ITEM_KEY] or {}
    return modData[QUEST_ITEM_KEY]
end

function TQ.QuestItems.itemMatches(item, questItemId)
    if not questItemId or tostring(questItemId) == "" then
        return true
    end

    if not item or not item.getModData then
        return false
    end

    local modData = item:getModData()
    local data = type(modData[QUEST_ITEM_KEY]) == "table" and modData[QUEST_ITEM_KEY] or nil
    return data and tostring(data.questItemId or "") == tostring(questItemId)
end

function TQ.QuestItems.markItem(item, objective, quest)
    if not item or type(objective) ~= "table" or not objective.questItemId then
        return item
    end

    local data = getQuestItemData(item)
    if not data then
        return item
    end

    data.questItemId = tostring(objective.questItemId)
    data.questId = tostring(quest and quest.id or "")
    data.templateId = tostring(quest and quest.templateId or "")
    data.objectiveId = tostring(objective.objectiveId or "")
    data.contactId = tostring(quest and quest.contactId or "")
    data.factionId = tostring(quest and quest.factionId or "")

    if objective.questItemName and item.setName then
        item:setName(tostring(objective.questItemName))
        if item.setCustomName then
            item:setCustomName(true)
        end
    end

    if objective.questItemTooltip and item.setTooltip then
        item:setTooltip(tostring(objective.questItemTooltip))
    end

    return item
end

local function playerDistanceTo(player, x, y)
    if not player or not player.getX or not x or not y then
        return 999999
    end

    if IsoUtils and IsoUtils.DistanceTo then
        return IsoUtils.DistanceTo(player:getX(), player:getY(), x, y)
    end

    local dx = player:getX() - x
    local dy = player:getY() - y
    return math.sqrt(dx * dx + dy * dy)
end

local function getCellSafe()
    if not getCell then
        return nil
    end

    local cell = getCell()
    if not cell or not cell.getGridSquare then
        return nil
    end

    return cell
end

local function getSquareAt(x, y, z)
    local cell = getCellSafe()
    if not cell or not x or not y then
        return nil
    end

    return cell:getGridSquare(math.floor(x), math.floor(y), math.floor(z or 0))
end

local function addUniqueNumber(list, value)
    value = math.floor(tonumber(value) or 0)
    for _, existing in ipairs(list) do
        if existing == value then
            return
        end
    end
    table.insert(list, value)
end

local function getZCandidates(z)
    local base = math.floor(tonumber(z) or 0)
    local candidates = {}
    addUniqueNumber(candidates, base)
    addUniqueNumber(candidates, 0)
    if base > 0 then
        addUniqueNumber(candidates, base - 1)
    end
    addUniqueNumber(candidates, base + 1)
    return candidates
end

local function getSquare(source)
    if not source then
        return nil
    end

    return getSquareAt(source.x, source.y, source.z)
end

local function getSquareCoord(square, methodName, fallback)
    if square and square[methodName] then
        local ok, value = pcall(function()
            return square[methodName](square)
        end)
        if ok and value ~= nil then
            return tonumber(value) or fallback
        end
    end
    return fallback
end

local function findLoadedSquareNear(source, radius)
    local exact = getSquare(source)
    if exact then
        return exact
    end

    local cell = getCellSafe()
    if not cell or not source or not source.x or not source.y then
        return nil
    end

    local centerX = math.floor(source.x)
    local centerY = math.floor(source.y)
    local searchRadius = math.max(0, math.floor(tonumber(radius or source.spawnRadius or source.radius) or 0))
    local best = nil
    local bestDistance = nil

    for _, z in ipairs(getZCandidates(source.z)) do
        for x = centerX - searchRadius, centerX + searchRadius do
            for y = centerY - searchRadius, centerY + searchRadius do
                local square = cell:getGridSquare(x, y, z)
                if square then
                    local dx = x - centerX
                    local dy = y - centerY
                    local distance = (dx * dx) + (dy * dy)
                    if distance <= (searchRadius * searchRadius) and (not bestDistance or distance < bestDistance) then
                        best = square
                        bestDistance = distance
                    end
                end
            end
        end

        if best then
            return best
        end
    end

    return best
end

local function updateSpawnLocation(objective, source, square, label)
    if type(objective) ~= "table" or not square then
        return
    end

    local x = getSquareCoord(square, "getX", source and source.x or 0)
    local y = getSquareCoord(square, "getY", source and source.y or 0)
    local z = getSquareCoord(square, "getZ", source and source.z or 0)

    objective.spawnX = x + 0.5
    objective.spawnY = y + 0.5
    objective.spawnZ = z

    if type(objective.marker) == "table" then
        objective.marker.x = objective.spawnX
        objective.marker.y = objective.spawnY
        objective.marker.z = objective.spawnZ
        if label and tostring(label) ~= "" then
            objective.marker.label = tostring(label)
        end
    end
end

local function createQuestItem(objective, quest)
    if type(objective) ~= "table" or not objective.item then
        return nil
    end

    local item = nil
    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        local ok, result = pcall(function()
            return InventoryItemFactory.CreateItem(tostring(objective.item))
        end)
        if ok then
            item = result
        end
    end

    if item then
        TQ.QuestItems.markItem(item, objective, quest)
    end
    return item
end

local function transmitInventoryItem(item)
    if item and item.transmitModData then
        pcall(function()
            item:transmitModData()
        end)
    end
end

local function transmitWorldItem(item)
    transmitInventoryItem(item)

    if not item or not item.getWorldItem then
        return
    end

    local worldItem = item:getWorldItem()
    if worldItem then
        if worldItem.setIgnoreRemoveSandbox then
            worldItem:setIgnoreRemoveSandbox(true)
        end
        if worldItem.transmitCompleteItemToClients then
            worldItem:transmitCompleteItemToClients()
        end
        if worldItem.transmitModData then
            worldItem:transmitModData()
        end
    end
end

local function findQuestItemInContainer(container, questItemId)
    if not container or not container.getItems then
        return nil
    end

    local items = container:getItems()
    if not items or not items.size then
        return nil
    end

    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if TQ.QuestItems.itemMatches(item, questItemId) then
            return item
        end
    end

    return nil
end

local function addQuestItemToContainer(container, carrierData)
    if not container or not container.AddItem or type(carrierData) ~= "table" or not carrierData.item then
        return nil
    end

    if findQuestItemInContainer(container, carrierData.questItemId) then
        return true
    end

    local objective = {
        item = carrierData.item,
        questItemId = carrierData.questItemId,
        objectiveId = carrierData.objectiveId,
        questItemName = carrierData.questItemName,
        questItemTooltip = carrierData.questItemTooltip,
    }
    local quest = {
        id = carrierData.questId,
        templateId = carrierData.templateId,
        contactId = carrierData.contactId,
        factionId = carrierData.factionId,
    }

    local item = createQuestItem(objective, quest)
    if item then
        local ok, result = pcall(function()
            return container:AddItem(item)
        end)
        if ok then
            transmitInventoryItem(result or item)
            return result or item
        end
    end

    local ok, result = pcall(function()
        return container:AddItem(tostring(carrierData.item))
    end)
    if ok and result then
        TQ.QuestItems.markItem(result, objective, quest)
        transmitInventoryItem(result)
        return result
    end

    return nil
end

local function addQuestItemToSquare(square, carrierData)
    if not square or not square.AddWorldInventoryItem or type(carrierData) ~= "table" or not carrierData.item then
        return nil
    end

    local objective = {
        item = carrierData.item,
        questItemId = carrierData.questItemId,
        objectiveId = carrierData.objectiveId,
        questItemName = carrierData.questItemName,
        questItemTooltip = carrierData.questItemTooltip,
    }
    local quest = {
        id = carrierData.questId,
        templateId = carrierData.templateId,
        contactId = carrierData.contactId,
        factionId = carrierData.factionId,
    }

    local item = createQuestItem(objective, quest)
    if item then
        local ok, result = pcall(function()
            return square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
        end)
        if ok and result then
            transmitWorldItem(result)
            return result
        end
    end

    local ok, result = pcall(function()
        return square:AddWorldInventoryItem(tostring(carrierData.item), 0.5, 0.5, 0)
    end)
    if ok and result then
        TQ.QuestItems.markItem(result, objective, quest)
        transmitWorldItem(result)
        return result
    end

    return nil
end

local function spawnWorldItem(player, quest, objective, source)
    if playerDistanceTo(player, source.x, source.y) > (tonumber(source.activationRange) or 180) then
        return false
    end

    local square = findLoadedSquareNear(source, source.spawnRadius or source.radius or 8)
    if not square or not square.AddWorldInventoryItem then
        return false
    end

    local offsetX = tonumber(source.offsetX) or 0.5
    local offsetY = tonumber(source.offsetY) or 0.5
    local offsetZ = tonumber(source.offsetZ) or 0

    local item = createQuestItem(objective, quest)
    if item then
        local ok, result = pcall(function()
            return square:AddWorldInventoryItem(item, offsetX, offsetY, offsetZ)
        end)
        if ok then
            item = result
        else
            item = nil
        end
    end

    if not item then
        local ok, result = pcall(function()
            return square:AddWorldInventoryItem(tostring(objective.item), offsetX, offsetY, offsetZ)
        end)
        if ok then
            item = result
        end
    end

    if not item then
        return false
    end

    TQ.QuestItems.markItem(item, objective, quest)
    transmitWorldItem(item)
    updateSpawnLocation(objective, source, square, source.markerLabel or source.label)
    objective.spawned = true
    objective.spawnedOn = "world"
    objective.spawnVersion = SPAWN_VERSION
    objective.spawnedAt = TQ.getWorldAgeHours()
    return true
end

local function isZombieCandidate(object)
    if not object then
        return false
    end

    if object.isZombie and object:isZombie() then
        return not (object.isDead and object:isDead())
    end

    if instanceof then
        local ok, result = pcall(instanceof, object, "IsoZombie")
        if ok and result then
            return not (object.isDead and object:isDead())
        end
    end

    return false
end

local function getCarrierData(zombie)
    if not zombie or not zombie.getModData then
        return nil
    end

    local modData = zombie:getModData()
    local carrierData = type(modData.TrueQuestsCarrier) == "table" and TQ.deepcopy(modData.TrueQuestsCarrier) or {}
    carrierData.questItemId = carrierData.questItemId or modData.TrueQuestsCarrierItemId
    carrierData.questId = carrierData.questId or modData.TrueQuestsCarrierQuestId
    carrierData.item = carrierData.item or modData.TrueQuestsCarrierItemType

    if not carrierData.questItemId then
        return nil
    end

    return carrierData
end

local function makeCarrierData(objective, quest)
    return {
        questItemId = tostring(objective and objective.questItemId or ""),
        questId = tostring(quest and quest.id or ""),
        templateId = tostring(quest and quest.templateId or ""),
        objectiveId = tostring(objective and objective.objectiveId or ""),
        item = tostring(objective and objective.item or ""),
        questItemName = objective and objective.questItemName or nil,
        questItemTooltip = objective and objective.questItemTooltip or nil,
        contactId = tostring(quest and quest.contactId or ""),
        factionId = tostring(quest and quest.factionId or ""),
    }
end

local function findZombieNear(source, questItemId)
    local best = nil
    local bestDistance = nil
    local radius = math.max(1, math.floor(tonumber(source.radius) or 12))

    for _, z in ipairs(getZCandidates(source.z)) do
        for x = math.floor(source.x) - radius, math.floor(source.x) + radius do
            for y = math.floor(source.y) - radius, math.floor(source.y) + radius do
                local square = getCell() and getCell():getGridSquare(x, y, z) or nil
                local objects = square and square.getMovingObjects and square:getMovingObjects() or nil
                if objects and objects.size then
                    for index = 0, objects:size() - 1 do
                        local object = objects:get(index)
                        if isZombieCandidate(object) then
                            local carrierData = questItemId and getCarrierData(object) or nil
                            if not questItemId or (carrierData and tostring(carrierData.questItemId or "") == tostring(questItemId)) then
                                local distance = playerDistanceTo(object, source.x, source.y)
                                if (not bestDistance or distance < bestDistance) and distance <= radius then
                                    best = object
                                    bestDistance = distance
                                end
                            end
                        end
                    end
                end
            end
        end

        if best then
            return best
        end
    end

    return best
end

local function spawnCarrierZombie(source, square)
    if source.spawnZombie == false or not addZombiesInOutfit then
        return nil
    end

    local outfit = source.outfit
    local femaleChance = tonumber(source.femaleChance) or 50
    local x = getSquareCoord(square, "getX", source.x)
    local y = getSquareCoord(square, "getY", source.y)
    local z = getSquareCoord(square, "getZ", source.z)
    local ok, zombies = pcall(addZombiesInOutfit, math.floor(x), math.floor(y), math.floor(z or 0), 1, outfit, femaleChance)
    if not ok or not zombies or not zombies.size or zombies:size() <= 0 then
        return nil
    end

    return zombies:get(0)
end

local function queueZombieDeathLoot(zombie, item)
    if not zombie or not item then
        return false
    end

    if item.getModData then
        item:getModData().preserve = true
    end

    if zombie.addItemToSpawnAtDeath then
        local ok = pcall(function()
            zombie:addItemToSpawnAtDeath(item)
        end)
        return ok
    end

    return false
end

local function registerCarrierZombie(zombie, objective, quest)
    if not zombie or not zombie.getModData then
        return
    end

    local data = zombie:getModData()
    local carrierData = makeCarrierData(objective, quest)
    data.TrueQuestsCarrier = carrierData
    data.TrueQuestsCarrierItemId = carrierData.questItemId
    data.TrueQuestsCarrierQuestId = carrierData.questId
    data.TrueQuestsCarrierItemType = carrierData.item

    if zombie.transmitModData then
        zombie:transmitModData()
    end
end

local function addItemToCarrier(zombie, quest, objective)
    if not zombie or not zombie.getInventory then
        return nil
    end

    local inventory = zombie:getInventory()
    if not inventory or not inventory.AddItem then
        return nil
    end

    local item = findQuestItemInContainer(inventory, objective.questItemId)
    if not item then
        item = createQuestItem(objective, quest)
        if item then
            local ok, result = pcall(function()
                return inventory:AddItem(item)
            end)
            if ok and result then
                item = result
            elseif not ok then
                item = nil
            end
        end
    end

    if not item then
        local ok, result = pcall(function()
            return inventory:AddItem(tostring(objective.item))
        end)
        if ok then
            item = result
        end
    end

    if not item then
        return nil
    end

    TQ.QuestItems.markItem(item, objective, quest)
    transmitInventoryItem(item)
    queueZombieDeathLoot(zombie, item)
    registerCarrierZombie(zombie, objective, quest)

    local square = zombie.getSquare and zombie:getSquare() or zombie.getCurrentSquare and zombie:getCurrentSquare() or nil
    if square then
        updateSpawnLocation(objective, objective.source or {}, square, objective.marker and objective.marker.label or nil)
    end

    return item
end

local function spawnZombieItem(player, quest, objective, source)
    if playerDistanceTo(player, source.x, source.y) > (tonumber(source.activationRange) or 180) then
        return false
    end

    local sourceSquare = findLoadedSquareNear(source, source.spawnRadius or source.radius or 8)
    if not sourceSquare then
        return false
    end

    local zombie = findZombieNear(source, objective.questItemId) or findZombieNear(source) or spawnCarrierZombie(source, sourceSquare)
    if not zombie or not zombie.getInventory then
        return false
    end

    local item = addItemToCarrier(zombie, quest, objective)
    if not item then
        return false
    end

    objective.spawned = true
    objective.spawnedOn = "zombie"
    objective.spawnVersion = SPAWN_VERSION
    objective.spawnedAt = TQ.getWorldAgeHours()
    return true
end

local function getObjectSquare(object)
    if not object then
        return nil
    end

    if object.getSquare then
        local square = object:getSquare()
        if square then
            return square
        end
    end

    if object.getCurrentSquare then
        return object:getCurrentSquare()
    end

    return nil
end

local function getObjectCoordinate(object, square, axis)
    local methodName = axis == "x" and "getX" or axis == "y" and "getY" or "getZ"
    if object and object[methodName] then
        local ok, value = pcall(function()
            return object[methodName](object)
        end)
        if ok and value ~= nil then
            return tonumber(value) or 0
        end
    end

    return getSquareCoord(square, methodName, 0)
end

local function getWorldQuestItemOnSquare(square, questItemId)
    if not square or not questItemId then
        return nil
    end

    local worldObjects = square.getWorldObjects and square:getWorldObjects() or nil
    if not worldObjects or not worldObjects.size then
        return nil
    end

    for index = 0, worldObjects:size() - 1 do
        local object = worldObjects:get(index)
        local item = object and object.getItem and object:getItem() or object
        if TQ.QuestItems.itemMatches(item, questItemId) then
            return item
        end
    end

    return nil
end

local function worldQuestItemExistsNear(source, objective)
    if type(source) ~= "table" or type(objective) ~= "table" or not objective.questItemId then
        return false
    end

    local radius = math.max(1, math.floor(tonumber(source.radius) or 12))
    local centerX = math.floor(tonumber(source.x) or 0)
    local centerY = math.floor(tonumber(source.y) or 0)

    for _, z in ipairs(getZCandidates(source.z)) do
        for x = centerX - radius, centerX + radius do
            for y = centerY - radius, centerY + radius do
                local dx = x - centerX
                local dy = y - centerY
                if (dx * dx) + (dy * dy) <= (radius * radius) then
                    local item = getWorldQuestItemOnSquare(getSquareAt(x, y, z), objective.questItemId)
                    if item then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function queuePendingCarrierDrop(zombie, carrierData)
    if type(carrierData) ~= "table" or not carrierData.questItemId or not carrierData.item or tostring(carrierData.item) == "" then
        return
    end

    TQ.QuestItems._pendingCarrierDrops = TQ.QuestItems._pendingCarrierDrops or {}

    local square = getObjectSquare(zombie)
    carrierData.x = getObjectCoordinate(zombie, square, "x")
    carrierData.y = getObjectCoordinate(zombie, square, "y")
    carrierData.z = getObjectCoordinate(zombie, square, "z")
    carrierData.queuedAt = TQ.getWorldAgeHours()

    table.insert(TQ.QuestItems._pendingCarrierDrops, carrierData)
end

local function findPendingCarrierDrop(body)
    local pending = TQ.QuestItems._pendingCarrierDrops
    if type(pending) ~= "table" or #pending == 0 then
        return nil, nil
    end

    local square = getObjectSquare(body)
    local x = getObjectCoordinate(body, square, "x")
    local y = getObjectCoordinate(body, square, "y")
    local z = math.floor(getObjectCoordinate(body, square, "z"))
    local bestIndex = nil
    local bestDistance = nil

    for index = #pending, 1, -1 do
        local drop = pending[index]
        local age = TQ.getWorldAgeHours() - (tonumber(drop.queuedAt) or TQ.getWorldAgeHours())
        if age > 6 then
            table.remove(pending, index)
        elseif math.floor(tonumber(drop.z) or 0) == z then
            local dx = x - (tonumber(drop.x) or x)
            local dy = y - (tonumber(drop.y) or y)
            local distance = (dx * dx) + (dy * dy)
            if distance <= 9 and (not bestDistance or distance < bestDistance) then
                bestIndex = index
                bestDistance = distance
            end
        end
    end

    if bestIndex then
        return bestIndex, pending[bestIndex]
    end

    return nil, nil
end

function TQ.QuestItems.onZombieDead(zombie)
    local carrierData = getCarrierData(zombie)
    if carrierData then
        queuePendingCarrierDrop(zombie, carrierData)
    end
end

function TQ.QuestItems.onDeadBodySpawn(body)
    local index, carrierData = findPendingCarrierDrop(body)
    if not index or not carrierData then
        return
    end

    local added = false
    local container = body and body.getContainer and body:getContainer() or nil
    if container then
        added = addQuestItemToContainer(container, carrierData) ~= nil
    end

    if not added then
        local square = getObjectSquare(body)
        added = addQuestItemToSquare(square, carrierData) ~= nil
    end

    if added and TQ.QuestItems._pendingCarrierDrops then
        table.remove(TQ.QuestItems._pendingCarrierDrops, index)
    end
end

function TQ.QuestItems.ensureForQuest(player, quest)
    if not player or not quest or quest.status == "completed" or quest.status == "failed" then
        return false
    end

    local changed = false
    for _, objective in ipairs(quest.objectives or {}) do
        if objective and objective.questItemId and not objective.completed then
            local collected = TQ.Objectives and TQ.Objectives.collectPlayerItems and TQ.Objectives.collectPlayerItems(player, objective.item, objective.required or 1, objective) or {}
            if #collected >= (tonumber(objective.required) or 1) then
                objective.spawned = true
                objective.spawnVersion = SPAWN_VERSION
            elseif type(objective.source) == "table" then
                local source = objective.source
                local needsSpawn = objective.spawned ~= true

                if not needsSpawn and (tonumber(objective.spawnVersion) or 0) < SPAWN_VERSION then
                    if source.mode ~= "zombie" and worldQuestItemExistsNear(source, objective) then
                        objective.spawnVersion = SPAWN_VERSION
                        changed = true
                    else
                        objective.spawned = false
                        objective.spawnedOn = nil
                        needsSpawn = true
                        changed = true
                    end
                end

                if needsSpawn then
                    local ok = false
                    if source.mode == "zombie" then
                        ok = spawnZombieItem(player, quest, objective, source)
                    else
                        ok = spawnWorldItem(player, quest, objective, source)
                    end
                    changed = changed or ok
                end
            end
        end
    end

    return changed
end

function TQ.QuestItems.ensureForPlayer(player)
    if not player or not TQ.Save or not TQ.Save.getData then
        return false
    end

    local data = TQ.Save.getData(player)
    local changed = false
    for _, quest in ipairs(data.active or {}) do
        changed = TQ.QuestItems.ensureForQuest(player, quest) or changed
    end

    if changed and TQ.Save.touch then
        TQ.Save.touch(player)
    end

    return changed
end

function TQ.QuestItems.getQuestMarker(quest)
    if not quest or quest.status == "completed" or quest.status == "failed" or quest.status == "rewardPending" then
        return nil
    end

    for _, objective in ipairs(quest.objectives or {}) do
        if objective and objective.marker and objective.completed ~= true then
            return objective.marker, objective
        end
    end

    return nil
end

local function registerQuestItemEvents()
    if TQ.QuestItems._eventsRegistered or not Events then
        return
    end

    if Events.OnZombieDead then
        Events.OnZombieDead.Add(TQ.QuestItems.onZombieDead)
    end

    if Events.OnDeadBodySpawn then
        Events.OnDeadBodySpawn.Add(TQ.QuestItems.onDeadBodySpawn)
    end

    TQ.QuestItems._eventsRegistered = true
end

registerQuestItemEvents()
