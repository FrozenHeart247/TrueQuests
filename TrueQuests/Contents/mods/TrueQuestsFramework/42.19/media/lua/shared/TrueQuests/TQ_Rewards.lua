require "TrueQuests/TQ_Core"
require "TrueQuests/TQ_Registry"

local TQ = TrueQuests

TQ.Rewards = TQ.Rewards or {}

local function normalizeSpec(spec)
    if type(spec) ~= "table" then
        return {
            table = tostring(spec or ""),
            choices = 3,
        }
    end
    return spec
end

local function rewardTableFromHolder(holder, difficulty)
    if type(holder) ~= "table" then
        return nil
    end

    difficulty = tostring(difficulty or "easy")

    if type(holder.rewardTables) == "table" then
        return holder.rewardTables[difficulty] or holder.rewardTables.default or holder.rewardTables.easy
    end

    return holder.rewardTable or holder.rewardsTable
end

function TQ.Rewards.resolveSpec(spec, context)
    context = type(context) == "table" and context or {}

    local resolved = {}
    if type(spec) == "table" then
        resolved = TQ.deepcopy(spec)
    elseif spec and tostring(spec) ~= "" then
        resolved.table = tostring(spec)
    end

    local contact = context.contact
    local faction = context.faction
    local difficulty = context.difficulty or (context.template and context.template.difficulty) or "easy"
    local tableId = resolved.table or resolved.tableId or resolved.id

    if tableId == "$contact" or tableId == "contact" then
        tableId = rewardTableFromHolder(contact, difficulty) or rewardTableFromHolder(faction, difficulty)
    elseif tableId == "$faction" or tableId == "faction" then
        tableId = rewardTableFromHolder(faction, difficulty)
    elseif not tableId or tostring(tableId) == "" then
        tableId = rewardTableFromHolder(contact, difficulty) or rewardTableFromHolder(faction, difficulty)
    end

    resolved.table = tableId
    resolved.choices = tonumber(resolved.choices) or tonumber(contact and contact.rewardChoices) or tonumber(faction and faction.rewardChoices) or 3
    return resolved
end

function TQ.Rewards.buildReward(entry)
    if type(entry) ~= "table" or not entry.item then
        return nil
    end

    local reward = {
        item = tostring(entry.item),
        count = TQ.numberFromRange(entry.count or 1, 1),
        rarity = tostring(entry.rarity or "common"),
        label = entry.label,
    }

    reward.displayName = reward.label or TQ.getItemDisplayName(reward.item)
    return reward
end

function TQ.Rewards.buildChoices(spec, context)
    spec = normalizeSpec(TQ.Rewards.resolveSpec(spec, context))

    local tableId = spec.table or spec.tableId or spec.id
    local entries = TQ.getRewardTable(tableId)
    local choices = {}
    local desired = tonumber(spec.choices) or 3

    if type(entries) ~= "table" or #entries == 0 then
        return choices
    end

    local used = {}
    local guard = 0
    while #choices < desired and guard < desired * 8 do
        guard = guard + 1
        local entry = TQ.weightedPick(entries)
        local reward = TQ.Rewards.buildReward(entry)
        if reward then
            local key = reward.item
            if spec.allowDuplicates == true or not used[key] or #entries < desired then
                used[key] = true
                table.insert(choices, reward)
            end
        end
    end

    return choices
end

function TQ.Rewards.grant(player, reward)
    if not player or not reward or not reward.item then
        return false
    end

    local inventory = player.getInventory and player:getInventory() or nil
    if not inventory or not inventory.AddItem then
        return false
    end

    local count = math.max(1, tonumber(reward.count) or 1)
    for _ = 1, count do
        inventory:AddItem(tostring(reward.item))
    end

    return true
end
