require "TrueNPC/TN_API"
require "TrueQuests/TQ_API"

local TN = TrueNPC
local TQ = TrueQuests

local function contactActive(contactId)
    return function(ctx)
        if not TQ or not TQ.Factions or not ctx or not ctx.player then
            return true
        end
        return TQ.Factions.isContactActive(ctx.player, contactId)
    end
end

local function tqInteraction(contactId)
    return {
        type = "truequests_contact",
        contactId = contactId,
    }
end

local function staticBehavior(maxDrift)
    return {
        type = "static",
        brain = {
            stationary = true,
            walkType = "Walk",
            movementSpeed = 0.7,
        },
        facePlayer = false,
        maxDrift = maxDrift or 2,
        teleportBack = false,
    }
end

local function npcAppearance(profile)
    profile = type(profile) == "table" and profile or {}
    profile.carrierOutfit = profile.carrierOutfit or "Naked1"
    profile.health = profile.health or 5
    profile.voicePrefix = profile.voicePrefix or "Bandit"
    return {
        female = profile.female == true,
        health = profile.health,
        carrierOutfit = profile.carrierOutfit,
        profile = profile,
    }
end

local function registerQuestNPC(definition)
    definition.provider = definition.provider or "static"
    definition.behavior = definition.behavior or staticBehavior()
    definition.interaction = definition.interaction or tqInteraction(definition.contactId)
    definition.condition = definition.condition or contactActive(definition.contactId)
    TN.registerNPC(definition)
end

registerQuestNPC({
    id = "tq_dr_amelie_crowe",
    contactId = "dr_amelie_crowe",
    factionId = "medics",
    name = "Amelie Crowe",
    spawn = { x = 10881, y = 10026, z = 1, radius = 3, spawnRadius = 85, despawnRadius = 120 },
    appearance = npcAppearance({
        female = true,
        skin = 2,
        hairIndex = 5,
        hairColor = 3,
        clothing = {
            "Base.Shirt_FormalWhite",
            "Base.Trousers_WhiteTINT",
            "Base.JacketLong_Doctor",
            "Base.Gloves_Surgical",
            "Base.Shoes_Black",
        },
        tints = {
            ["Base.Trousers_WhiteTINT"] = { r = 0.92, g = 0.92, b = 0.86 },
        },
        textureChoices = {
            ["Base.Trousers_WhiteTINT"] = 0,
        },
    }),
})

registerQuestNPC({
    id = "tq_nurse_mara_voss",
    contactId = "nurse_mara_voss",
    factionId = "medics",
    name = "Mara Voss",
    spawn = { x = 10865, y = 10035, z = 0, radius = 3, spawnRadius = 85, despawnRadius = 120 },
    appearance = npcAppearance({
        female = true,
        skin = 1,
        hairIndex = 8,
        hairColor = 2,
        clothing = {
            "Base.Shirt_Scrubs",
            "Base.Trousers_Scrubs",
            "Base.Hat_SurgicalCap",
            "Base.Gloves_Surgical",
            "Base.Shoes_TrainerTINT",
        },
        tints = {
            ["Base.Shirt_Scrubs"] = { r = 0.22, g = 0.52, b = 0.58 },
            ["Base.Trousers_Scrubs"] = { r = 0.22, g = 0.52, b = 0.58 },
            ["Base.Shoes_TrainerTINT"] = { r = 0.08, g = 0.10, b = 0.12 },
        },
        textureChoices = {
            ["Base.Shirt_Scrubs"] = 0,
            ["Base.Trousers_Scrubs"] = 0,
            ["Base.Hat_SurgicalCap"] = 0,
            ["Base.Shoes_TrainerTINT"] = 0,
        },
    }),
})

registerQuestNPC({
    id = "tq_owen_hale",
    contactId = "owen_hale",
    factionId = "medics",
    name = "Owen Hale",
    spawn = { x = 10862, y = 10038, z = 0, radius = 3, spawnRadius = 85, despawnRadius = 120 },
    appearance = npcAppearance({
        female = false,
        skin = 3,
        hairIndex = 4,
        beardIndex = 3,
        hairColor = 2,
        clothing = {
            "Base.Tshirt_WhiteTINT",
            "Base.Shirt_Denim",
            "Base.Trousers_Denim",
            "Base.Vest_HighViz",
            "Base.Shoes_BlackBoots",
        },
        tints = {
            ["Base.Tshirt_WhiteTINT"] = { r = 0.88, g = 0.88, b = 0.82 },
        },
        textureChoices = {
            ["Base.Tshirt_WhiteTINT"] = 0,
        },
    }),
})

registerQuestNPC({
    id = "tq_marlow_relay",
    contactId = "marlow_relay",
    factionId = "independent",
    name = "Marlow",
    spawn = { x = 10620, y = 9520, z = 0, radius = 3, spawnRadius = 85, despawnRadius = 120 },
    appearance = npcAppearance({
        female = false,
        skin = 2,
        hairIndex = 2,
        beardIndex = 5,
        hairColor = 1,
        clothing = {
            "Base.Tshirt_DefaultTEXTURE_TINT",
            "Base.Jacket_LeatherBrown",
            "Base.Trousers_Denim",
            "Base.Shoes_Black",
        },
        tints = {
            ["Base.Tshirt_DefaultTEXTURE_TINT"] = { r = 0.55, g = 0.50, b = 0.42 },
        },
        textureChoices = {
            ["Base.Tshirt_DefaultTEXTURE_TINT"] = 0,
        },
    }),
})

registerQuestNPC({
    id = "tq_tess_roofline",
    contactId = "tess_roofline",
    factionId = "independent",
    name = "Tess",
    spawn = { x = 10623, y = 9522, z = 0, radius = 3, spawnRadius = 85, despawnRadius = 120 },
    appearance = npcAppearance({
        female = true,
        skin = 3,
        hairIndex = 11,
        hairColor = 4,
        clothing = {
            "Base.Tshirt_WhiteTINT",
            "Base.HoodieDOWN_WhiteTINT",
            "Base.TrousersMesh_DenimLight",
            "Base.Shoes_TrainerTINT",
        },
        tints = {
            ["Base.Tshirt_WhiteTINT"] = { r = 0.72, g = 0.70, b = 0.63 },
            ["Base.HoodieDOWN_WhiteTINT"] = { r = 0.24, g = 0.31, b = 0.36 },
            ["Base.Shoes_TrainerTINT"] = { r = 0.16, g = 0.14, b = 0.14 },
        },
        textureChoices = {
            ["Base.Tshirt_WhiteTINT"] = 0,
            ["Base.HoodieDOWN_WhiteTINT"] = 0,
            ["Base.Shoes_TrainerTINT"] = 0,
        },
    }),
})

registerQuestNPC({
    id = "tq_bradley_static",
    contactId = "bradley_static",
    factionId = "independent",
    name = "Bradley",
    spawn = { x = 10618, y = 9523, z = 0, radius = 3, spawnRadius = 85, despawnRadius = 120 },
    appearance = npcAppearance({
        female = false,
        skin = 1,
        hairIndex = 6,
        beardIndex = 2,
        hairColor = 5,
        clothing = {
            "Base.Shirt_Lumberjack",
            "Base.Jacket_Black",
            "Base.Trousers",
            "Base.Shoes_Black",
        },
    }),
})

TN.log("True Quests NPC bridge content loaded")
