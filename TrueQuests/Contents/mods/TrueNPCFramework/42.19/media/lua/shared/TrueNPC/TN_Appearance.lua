require "TrueNPC/TN_Core"
require "TrueNPC/TN_Save"

local TN = TrueNPC

TN.Appearance = TN.Appearance or {}

local HAIR_COLORS = {
    { r = 0.10, g = 0.08, b = 0.06 },
    { r = 0.24, g = 0.16, b = 0.09 },
    { r = 0.42, g = 0.30, b = 0.18 },
    { r = 0.55, g = 0.48, b = 0.35 },
    { r = 0.78, g = 0.70, b = 0.52 },
}

local function callIfExists(object, method, ...)
    if object and object[method] then
        return pcall(object[method], object, ...)
    end
    return false, nil
end

local function seedFromString(value)
    local text = tostring(value or "")
    local seed = 0
    for index = 1, #text do
        seed = (seed * 33 + string.byte(text, index)) % 2147483647
    end
    return seed
end

local function getAppearanceDefinition(npc)
    return type(npc and npc.appearance) == "table" and npc.appearance or {}
end

local function copyTable(value)
    return TN.deepcopy(value or {})
end

local function firstNonNil(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if value ~= nil then
            return value
        end
    end
    return nil
end

local function resolveFemale(appearance, profile)
    local explicit = firstNonNil(profile and profile.female, appearance.female)
    if explicit ~= nil then
        return explicit == true
    end

    local femaleChance = tonumber(firstNonNil(profile and profile.femaleChance, appearance.femaleChance))
    if femaleChance ~= nil then
        return femaleChance >= 50
    end

    return false
end

local function resolveSkinTexture(profile)
    if profile.skinTexture and tostring(profile.skinTexture) ~= "" then
        return tostring(profile.skinTexture)
    end

    local skin = tonumber(profile.skin)
    if not skin then
        return nil
    end

    skin = math.max(1, math.min(3, math.floor(skin)))
    if profile.female then
        return "FemaleBody0" .. tostring(skin)
    end
    return "MaleBody0" .. tostring(skin) .. "a"
end

local function resolveHairStyle(profile)
    local hair = profile.hair or profile.hairStyle
    if type(hair) == "string" and hair ~= "" then
        return hair
    end

    local hairIndex = tonumber(profile.hairIndex)
    if not hairIndex or not getAllHairStyles then
        return nil
    end

    local styles = getAllHairStyles(profile.female == true)
    if not styles or not styles.size or styles:size() <= 0 then
        return nil
    end

    local available = {}
    for index = 0, styles:size() - 1 do
        local styleId = styles:get(index)
        local style = nil
        if getHairStylesInstance then
            style = profile.female
                and getHairStylesInstance():FindFemaleStyle(styleId)
                or getHairStylesInstance():FindMaleStyle(styleId)
        end

        if not style or not style.isNoChoose or not style:isNoChoose() then
            table.insert(available, tostring(styleId))
        end
    end

    if #available <= 0 then
        return nil
    end

    local resolvedIndex = ((math.floor(hairIndex) - 1) % #available) + 1
    return available[resolvedIndex]
end

local function resolveBeardStyle(profile)
    if profile.female then
        return nil
    end

    local beard = profile.beard or profile.beardStyle
    if type(beard) == "string" and beard ~= "" then
        return beard
    end

    local beardIndex = tonumber(profile.beardIndex)
    if not beardIndex or not getAllBeardStyles then
        return nil
    end

    local styles = getAllBeardStyles()
    if not styles or not styles.size or styles:size() <= 0 then
        return nil
    end

    local resolvedIndex = ((math.floor(beardIndex) - 1) % styles:size())
    return tostring(styles:get(resolvedIndex))
end

local function resolveColor(color, fallbackIndex)
    if type(color) == "table" then
        return {
            r = tonumber(color.r or color[1]) or 0,
            g = tonumber(color.g or color[2]) or 0,
            b = tonumber(color.b or color[3]) or 0,
            a = tonumber(color.a or color[4]) or 1,
        }
    end

    local index = tonumber(color or fallbackIndex)
    if index then
        return HAIR_COLORS[((math.floor(index) - 1) % #HAIR_COLORS) + 1]
    end

    return nil
end

local function getProfileSeed(npc, appearance)
    return tonumber(appearance.seed) or seedFromString(npc and npc.id or "npc")
end

function TN.Appearance.buildProfile(npc, state)
    if not npc then
        return nil
    end

    local appearance = getAppearanceDefinition(npc)
    local definitionProfile = copyTable(appearance.profile)
    local profile = definitionProfile
    local seed = getProfileSeed(npc, appearance)

    state = state or TN.Save.ensureNPCState(npc.id)
    if state then
        state.visualProfile = type(state.visualProfile) == "table" and state.visualProfile or {}
    end

    profile.female = resolveFemale(appearance, profile)
    profile.skin = tonumber(firstNonNil(profile.skin, appearance.skin)) or ((seed % 3) + 1)
    profile.skinTexture = resolveSkinTexture(profile)
    profile.hairIndex = tonumber(firstNonNil(profile.hairIndex, appearance.hairIndex)) or ((math.floor(seed / 3) % 8) + 1)
    profile.hair = resolveHairStyle(profile)
    profile.beardIndex = tonumber(firstNonNil(profile.beardIndex, appearance.beardIndex)) or ((math.floor(seed / 17) % 6) + 1)
    profile.beard = resolveBeardStyle(profile)
    profile.hairColor = resolveColor(firstNonNil(profile.hairColor, appearance.hairColor), (math.floor(seed / 11) % #HAIR_COLORS) + 1)
    profile.clothing = copyTable(firstNonNil(profile.clothing, appearance.clothing))
    profile.tints = copyTable(firstNonNil(profile.tints, appearance.tints))
    profile.voicePrefix = tostring(firstNonNil(profile.voicePrefix, appearance.voicePrefix, "Bandit"))
    profile.carrierOutfit = tostring(firstNonNil(profile.carrierOutfit, appearance.carrierOutfit, "Naked1"))
    profile.health = tonumber(firstNonNil(profile.health, appearance.health)) or 5

    if state then
        state.visualProfile = copyTable(profile)
    end

    return profile
end

function TN.Appearance.ensureProfile(npc, state)
    return TN.Appearance.buildProfile(npc, state)
end

local function immutableColor(color)
    if type(color) ~= "table" or not ImmutableColor then
        return nil
    end

    return ImmutableColor.new(
        tonumber(color.r or color[1]) or 0,
        tonumber(color.g or color[2]) or 0,
        tonumber(color.b or color[3]) or 0,
        tonumber(color.a or color[4]) or 1
    )
end

local function applyFemale(character, female)
    if female == nil then
        return
    end

    if character.setFemaleEtc then
        character:setFemaleEtc(female == true)
    elseif character.setFemale then
        character:setFemale(female == true)
    end

    if character.getDescriptor then
        local descriptor = character:getDescriptor()
        if descriptor and descriptor.setFemale then
            descriptor:setFemale(female == true)
        end
    end
end

local function applyHumanVisual(character, profile)
    if not character or not character.getHumanVisual then
        return false
    end

    local visual = character:getHumanVisual()
    if not visual then
        return false
    end

    if profile.skinTexture and visual.setSkinTextureName then
        pcall(function()
            visual:setSkinTextureName(profile.skinTexture)
        end)
    end

    if profile.hair and visual.setHairModel then
        pcall(function()
            visual:setHairModel(profile.hair)
        end)
    end

    if profile.beard and visual.setBeardModel then
        pcall(function()
            visual:setBeardModel(profile.beard)
        end)
    end

    local hairColor = immutableColor(profile.hairColor)
    if hairColor then
        if visual.setHairColor then
            pcall(function()
                visual:setHairColor(hairColor)
            end)
        end
        if visual.setBeardColor then
            pcall(function()
                visual:setBeardColor(hairColor)
            end)
        end
    end

    if visual.removeBlood then
        pcall(function()
            visual:removeBlood()
        end)
    end

    if BloodBodyPartType and BloodBodyPartType.MAX and BloodBodyPartType.FromIndex then
        local maxIndex = BloodBodyPartType.MAX:index()
        for index = 0, maxIndex - 1 do
            local part = BloodBodyPartType.FromIndex(index)
            if visual.setBlood then
                pcall(function()
                    visual:setBlood(part, 0)
                end)
            end
            if visual.setDirt then
                pcall(function()
                    visual:setDirt(part, 0)
                end)
            end
        end
    end

    if character.getDescriptor then
        local descriptor = character:getDescriptor()
        if descriptor and descriptor.getHumanVisual and descriptor:getHumanVisual() and descriptor:getHumanVisual().copyFrom then
            pcall(function()
                descriptor:getHumanVisual():copyFrom(visual)
            end)
        end
    end

    return true
end

local function clearExistingClothing(character)
    if character and character.clearAttachedItems then
        pcall(function()
            character:clearAttachedItems()
        end)
    end

    if character and character.getWornItems then
        local worn = character:getWornItems()
        if worn and worn.clear then
            pcall(function()
                worn:clear()
            end)
        end
    end

    if character and character.getItemVisuals then
        local ok, visuals = pcall(function()
            return character:getItemVisuals()
        end)
        if ok and visuals and visuals.clear then
            pcall(function()
                visuals:clear()
            end)
        end
    end
end

local function instanceClothingItem(itemType)
    if not itemType or tostring(itemType) == "" then
        return nil
    end

    local fullType = tostring(itemType)
    if instanceItem then
        local ok, item = pcall(function()
            return instanceItem(fullType)
        end)
        if ok and item then
            return item
        end
    end

    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        local ok, item = pcall(function()
            return InventoryItemFactory.CreateItem(fullType)
        end)
        if ok and item then
            return item
        end
    end

    return nil
end

local function normalizeItemType(itemType)
    local fullType = tostring(itemType or "")
    if fullType == "" then
        return nil
    end
    if not string.find(fullType, "%.") then
        fullType = "Base." .. fullType
    end
    return fullType
end

local function getItemTint(profile, itemType, entry)
    if type(entry) == "table" and entry.tint then
        return resolveColor(entry.tint)
    end

    if type(profile.tints) == "table" then
        return resolveColor(profile.tints[itemType])
    end

    return nil
end

local function addItemVisual(character, visuals, profile, entry)
    local itemType = entry
    if type(entry) == "table" then
        itemType = entry.type or entry.item or entry.itemType
    end

    itemType = normalizeItemType(itemType)
    if not itemType or not visuals or not ItemVisual then
        return false
    end

    local item = instanceClothingItem(itemType)
    if not item then
        TN.warn("Cannot create NPC clothing item " .. tostring(itemType))
        return false
    end

    local itemVisual = nil
    local fromItemVisual = false
    if item.getVisual then
        local ok, visual = pcall(function()
            return item:getVisual()
        end)
        if ok and visual then
            itemVisual = visual
            fromItemVisual = true
        end
    end

    if not itemVisual and ItemVisual.new then
        itemVisual = ItemVisual.new()
    end

    if not itemVisual then
        return false
    end

    if itemVisual.setItemType then
        pcall(function()
            itemVisual:setItemType(itemType)
        end)
    end
    if itemVisual.setClothingItemName and not fromItemVisual then
        pcall(function()
            itemVisual:setClothingItemName(itemType)
        end)
    end

    local tint = immutableColor(getItemTint(profile, itemType, entry))
    if tint and itemVisual.setTint then
        pcall(function()
            itemVisual:setTint(tint)
        end)
    end

    if BloodBodyPartType and BloodBodyPartType.MAX and BloodBodyPartType.FromIndex then
        local maxIndex = BloodBodyPartType.MAX:index()
        for index = 0, maxIndex - 1 do
            local part = BloodBodyPartType.FromIndex(index)
            if itemVisual.removeHole then
                pcall(function()
                    itemVisual:removeHole(index)
                end)
            end
            if itemVisual.setBlood then
                pcall(function()
                    itemVisual:setBlood(part, 0)
                end)
            end
            if itemVisual.setDirt then
                pcall(function()
                    itemVisual:setDirt(part, 0)
                end)
            end
        end
    end

    if itemVisual.setInventoryItem then
        pcall(function()
            itemVisual:setInventoryItem(nil)
        end)
    end

    visuals:add(itemVisual)
    return true
end

local function applyClothingProfile(character, profile)
    if not character or not character.getItemVisuals or type(profile.clothing) ~= "table" then
        return false
    end

    local ok, visuals = pcall(function()
        return character:getItemVisuals()
    end)
    if not ok or not visuals or not visuals.add then
        return false
    end

    clearExistingClothing(character)

    local applied = false
    for _, entry in ipairs(profile.clothing) do
        applied = addItemVisual(character, visuals, profile, entry) or applied
    end

    return applied
end

local function applyVoice(character, profile)
    if not character or not character.getDescriptor or not profile.voicePrefix then
        return
    end

    local descriptor = character:getDescriptor()
    if descriptor and descriptor.setVoicePrefix then
        pcall(function()
            descriptor:setVoicePrefix(profile.voicePrefix)
        end)
    end
end

local function resetModel(character)
    callIfExists(character, "resetModelNextFrame")
    callIfExists(character, "resetModel")
    callIfExists(character, "resetEquippedHandsModels")
end

function TN.Appearance.apply(character, npc, options)
    if not character or not npc then
        return false
    end

    options = type(options) == "table" and options or {}
    local state = options.state or TN.Save.ensureNPCState(npc.id)
    local profile = TN.Appearance.buildProfile(npc, state)
    if not profile then
        return false
    end

    applyFemale(character, profile.female)
    applyHumanVisual(character, profile)
    applyClothingProfile(character, profile)
    applyVoice(character, profile)

    if character.getModData then
        local modData = character:getModData()
        modData.TrueNPCAppearance = {
            female = profile.female == true,
            skinTexture = profile.skinTexture,
            hair = profile.hair,
            beard = profile.beard,
            clothing = copyTable(profile.clothing),
            locked = true,
        }
    end

    resetModel(character)
    return true
end
