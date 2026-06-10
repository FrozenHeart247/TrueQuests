require "TrueQuests/TQ_Core"

local TQ = TrueQuests

TQ.Objectives = TQ.Objectives or {}
TQ.Objectives.types = TQ.Objectives.types or {}

function TQ.Objectives.register(typeId, handler)
    if not typeId or type(handler) ~= "table" then
        TQ.warn("Cannot register objective type without id and handler")
        return false
    end

    TQ.Objectives.types[tostring(typeId)] = handler
    return true
end

function TQ.Objectives.get(typeId)
    if not typeId then
        return nil
    end
    return TQ.Objectives.types[tostring(typeId)]
end

function TQ.Objectives.build(templateObjective, context)
    if type(templateObjective) ~= "table" then
        return nil
    end

    local handler = TQ.Objectives.get(templateObjective.type)
    if not handler or type(handler.build) ~= "function" then
        TQ.warn("Unknown objective type " .. tostring(templateObjective.type))
        return nil
    end

    return handler.build(templateObjective, context or {})
end

function TQ.Objectives.update(instance, quest, player)
    local handler = instance and TQ.Objectives.get(instance.type) or nil
    if handler and type(handler.update) == "function" then
        return handler.update(instance, quest, player)
    end
    return false
end

function TQ.Objectives.consume(instance, quest, player)
    local handler = instance and TQ.Objectives.get(instance.type) or nil
    if handler and type(handler.consume) == "function" then
        return handler.consume(instance, quest, player)
    end
    return true
end

function TQ.Objectives.describe(instance)
    local handler = instance and TQ.Objectives.get(instance.type) or nil
    if handler and type(handler.describe) == "function" then
        return handler.describe(instance)
    end
    return tostring(instance and instance.type or "Objective")
end

local function collectFromContainer(container, fullType, out, limit)
    if not container or not container.getItems then
        return out
    end

    local items = container:getItems()
    if not items or not items.size then
        return out
    end

    for i = 0, items:size() - 1 do
        if limit and #out >= limit then
            return out
        end

        local item = items:get(i)
        if item then
            if item.getFullType and item:getFullType() == fullType then
                table.insert(out, item)
            end

            if item.getInventory then
                local nested = item:getInventory()
                if nested then
                    collectFromContainer(nested, fullType, out, limit)
                end
            end
        end
    end

    return out
end

function TQ.Objectives.collectPlayerItems(player, fullType, limit)
    local out = {}
    if not player or not player.getInventory then
        return out
    end
    return collectFromContainer(player:getInventory(), tostring(fullType), out, limit)
end

local itemObjective = {}

function itemObjective.build(templateObjective)
    local fullType = tostring(templateObjective.item or "")
    local required = TQ.numberFromRange(templateObjective.count or templateObjective.required or 1, 1)

    return {
        type = "item",
        item = fullType,
        required = required,
        current = 0,
        completed = false,
        consume = templateObjective.consume ~= false,
        label = templateObjective.label,
    }
end

function itemObjective.update(instance, quest, player)
    local items = TQ.Objectives.collectPlayerItems(player, instance.item)
    instance.current = math.min(#items, tonumber(instance.required) or 1)
    instance.completed = #items >= (tonumber(instance.required) or 1)
    return instance.completed
end

function itemObjective.consume(instance, quest, player)
    if instance.consume == false then
        return true
    end

    local required = tonumber(instance.required) or 1
    local items = TQ.Objectives.collectPlayerItems(player, instance.item, required)
    if #items < required then
        return false
    end

    for _, item in ipairs(items) do
        local container = item.getContainer and item:getContainer() or nil
        if container and container.Remove then
            if sendRemoveItemFromContainer then
                sendRemoveItemFromContainer(container, item)
            end
            container:Remove(item)
        elseif player and player.getInventory then
            local inv = player:getInventory()
            if inv and inv.Remove then
                inv:Remove(item)
                if sendRemoveItemFromContainer then
                    sendRemoveItemFromContainer(inv, item)
                end
            end
        end
    end

    instance.current = 0
    instance.completed = true
    return true
end

function itemObjective.describe(instance)
    local name = instance.label or TQ.getItemDisplayName(instance.item)
    return tostring(name) .. ": " .. tostring(instance.current or 0) .. "/" .. tostring(instance.required or 1)
end

TQ.Objectives.register("item", itemObjective)

