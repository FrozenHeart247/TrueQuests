require "TrueQuests/TQ_API"

local TQ = TrueQuests

local MULDRAUGH_RELAY = {
    type = "zone",
    label = "Muldraugh relay cache (10620, 9520)",
    x = 10620,
    y = 9520,
    z = 0,
    radius = 12,
}

local FIELD_CLINIC = {
    type = "zone",
    label = "Field clinic drop (10628, 9514)",
    x = 10628,
    y = 9514,
    z = 0,
    radius = 12,
}

local CONTACT_NPC_IDS = {
    marlow_relay = "tq_marlow_relay",
    tess_roofline = "tq_tess_roofline",
    bradley_static = "tq_bradley_static",
}

local function npcTurnIn(contactId, fallback)
    return function(ctx)
        local contact = ctx and ctx.contact or TQ.getContact(contactId)
        local npcId = contact and contact.npcId or CONTACT_NPC_IDS[tostring(contactId or "")]
        local TN = TrueNPC
        local npc = TN and TN.getNPC and TN.getNPC(npcId) or nil
        local spawn = nil
        if npc and TN and TN.Registry and TN.Registry.selectNPCSpawn then
            spawn = TN.Registry.selectNPCSpawn(npc)
            if TN.Save and TN.Save.transmit then
                TN.Save.transmit()
            end
        end
        spawn = spawn or (npc and TN.getNPCSpawn and TN.getNPCSpawn(npc) or nil)

        if type(spawn) == "table" and spawn.x and spawn.y then
            local x = tonumber(spawn.x) or 0
            local y = tonumber(spawn.y) or 0
            local z = tonumber(spawn.z) or 0
            local name = tostring(contact and contact.name or "Survivor")
            return {
                type = "zone",
                label = name .. "'s current spot (" .. tostring(math.floor(x)) .. ", " .. tostring(math.floor(y)) .. ")",
                x = x + 0.5,
                y = y + 0.5,
                z = z,
                radius = tonumber(spawn.radius) or 10,
            }
        end

        return TQ.deepcopy(fallback)
    end
end

TQ.registerDialogueBank("tq_medics_generic", {
    greeting = {
        "Field clinic listening. Keep your hands clean and your voice low.",
        "You are on the clinic band. Report injuries or useful supplies.",
        "Clinic relay is live. Make it quick.",
    },
    about = {
        "We patch people up, move them before the dead gather, and hope the next call is not worse.",
        "Medicine is thin. Clean cloth, disinfectant, needles, pills. Everything matters now.",
    },
    work = {
        "We need supplies more than heroics.",
        "If you can carry medical stock to the drop, we can keep people alive.",
    },
    accept = {
        "Copy. Bring it sealed if you can.",
        "Good. The clinic will mark the drop.",
    },
    complete = {
        "That buys us another day. Choose from the clinic cache.",
        "Clean delivery. Take what you need.",
    },
})

TQ.registerDialogueBank("tq_independent_generic", {
    greeting = {
        "Anyone alive on this frequency?",
        "Keep it short. I am not staying on the air long.",
        "You hear this? Good. I have a job if you are moving.",
    },
    about = {
        "No faction, no banner. Just people trying to get through one more day.",
        "I trade favors, not promises.",
    },
    work = {
        "Could be salvage, could be delivery. Depends what the dead are blocking today.",
        "If you can haul it, I can pay.",
    },
    accept = {
        "Good. I will remember this.",
        "Copy that. Watch the roads.",
        "Fair deal. Do not bring a tail.",
    },
    complete = {
        "You came through. Pick something.",
        "That is better than I expected. Take your pay.",
    },
})

local function hasPendingFailureNotice(ctx)
    return TQ.QuestManager
        and TQ.QuestManager.getPendingFailureNotice
        and TQ.QuestManager.getPendingFailureNotice(ctx and ctx.player, ctx and ctx.factionId) ~= nil
end

local function failureNoticeLine(ctx)
    local notice = TQ.QuestManager and TQ.QuestManager.getPendingFailureNotice and TQ.QuestManager.getPendingFailureNotice(ctx and ctx.player, ctx and ctx.factionId) or nil
    local title = tostring((notice and notice.questTitle) or "that request")

    if ctx and ctx.factionId == "medics" then
        return "You missed the window on " .. title .. ". Patients do not stop needing help because the roads are bad. The clinic's trust took a hit."
    end

    return "You let " .. title .. " go cold. Favors matter out here, and that one cost you trust."
end

local function acknowledgeFailureNotice(ctx)
    if TQ.QuestManager and TQ.QuestManager.acknowledgeFailureNotice then
        TQ.QuestManager.acknowledgeFailureNotice(ctx and ctx.player, ctx and ctx.factionId)
    end
end

TQ.registerDialogueTopic({
    id = "failure_notice",
    text = "About the job I missed.",
    priority = 1,
    condition = hasPendingFailureNotice,
    npc = failureNoticeLine,
    onEnter = acknowledgeFailureNotice,
})

TQ.registerDialogueTopic({
    id = "about",
    text = "Tell me about yourself.",
    lineKey = "about",
    priority = 10,
    children = {
        {
            id = "medics_needs",
            factionId = "medics",
            text = "What does the clinic need most?",
            npc = "Clean cloth, disinfectant, painkillers. In that order. Everything else is comfort.",
            priority = 10,
        },
        {
            id = "medics_people",
            factionId = "medics",
            text = "How are your people holding up?",
            npc = "Tired. Too tired to waste supplies, not tired enough to stop answering calls.",
            priority = 20,
        },
        {
            id = "independent_trust",
            factionId = "independent",
            text = "You trust anyone out there?",
            npc = "Trust? No. But I keep a list of people who did not make things worse.",
            priority = 10,
        },
    },
})

TQ.registerDialogueTopic({
    id = "medics_rumors",
    factionId = "medics",
    text = "Is there anything happening lately?",
    npc = {
        "Someone came in talking about smoke north of the highway. Could be survivors, could be trouble.",
        "We heard gunfire after midnight. Short bursts. Organized, or scared. Hard to tell.",
        "A runner said the clinic road was clear this morning. I would not trust that by dusk.",
    },
    priority = 20,
    children = {
        {
            id = "medics_rumors_more",
            text = "Anything else?",
            npc = {
                "A scavenger mentioned fresh tire tracks near the old service road.",
                "Two patients swear they heard a helicopter. I would not build a plan around it.",
            },
        },
    },
})

TQ.registerDialogueTopic({
    id = "independent_rumors",
    factionId = "independent",
    text = "Is there anything happening lately?",
    npc = {
        "There is a dead crowd moving west. Slow, but too many to ignore.",
        "Someone is stripping cars near the old road. If you hear engines, keep low.",
        "I heard a generator last night. Then screaming. Then nothing.",
    },
    priority = 20,
    children = {
        {
            id = "independent_rumors_more",
            text = "Anything else?",
            npc = {
                "A few people are marking doors with chalk. Could be warnings, could be claims.",
                "Somebody keeps broadcasting numbers after midnight. No names, no context.",
            },
        },
    },
})

TQ.registerDialogueTopic({
    id = "amelie_before",
    contactId = "dr_amelie_crowe",
    parent = "about",
    text = "What did you do before this?",
    npc = "Hospital doctor. These days I mostly count bandages, argue with radios, and decide who can be moved.",
    priority = 30,
})

TQ.registerDialogueTopic({
    id = "mara_before",
    contactId = "nurse_mara_voss",
    parent = "about",
    text = "How did you end up with the clinic?",
    npc = "I followed a patient here and never found a better reason to leave.",
    priority = 30,
})

TQ.registerDialogueTopic({
    id = "owen_before",
    contactId = "owen_hale",
    parent = "about",
    text = "You were a paramedic?",
    npc = "Ambulance crew. The roads are worse now, but people still need someone willing to run toward noise.",
    priority = 30,
})

TQ.registerDialogueTopic({
    id = "marlow_angle",
    contactId = "marlow_relay",
    parent = "about",
    text = "What do you actually trade?",
    npc = "Routes, warnings, names of people who pay back favors. Sometimes nails. Depends on the day.",
    priority = 30,
})

TQ.registerDialogueTopic({
    id = "tess_angle",
    contactId = "tess_roofline",
    parent = "about",
    text = "Why stay on the roofline?",
    npc = "Height buys time. Time buys choices. Choices are about the only currency left.",
    priority = 30,
})

TQ.registerDialogueTopic({
    id = "bradley_angle",
    contactId = "bradley_static",
    parent = "about",
    text = "Are you alone out there?",
    npc = "Alone enough to answer for myself. Not alone enough to stop listening.",
    priority = 30,
})

TQ.registerDialogueTreeBank("tq_medics_tree", {
    start = {
        npc = {
            "Clinic band is open. Tell me what you need.",
            "You reached the field clinic. Keep the channel clear.",
        },
        options = {
            { text = "Tell me about yourself.", next = "about" },
            { text = "Is there anything happening lately?", next = "rumors" },
            { text = "Anything you need done?", action = "show_jobs" },
            { text = "Goodbye.", action = "close" },
        },
    },
    about = {
        npc = {
            "We were medical staff, volunteers, and whoever could still hold pressure on a wound.",
            "The clinic is not much. A few cots, a few shelves, and a radio that still reaches people.",
        },
        options = {
            { text = "What does the clinic need most?", next = "needs" },
            { text = "How are your people holding up?", next = "people" },
            { text = "Back.", next = "start" },
        },
    },
    needs = {
        npc = "Clean cloth, disinfectant, painkillers. In that order. Everything else is comfort.",
        options = {
            { text = "Back.", next = "about" },
        },
    },
    people = {
        npc = "Tired. Too tired to waste supplies, not tired enough to stop answering calls.",
        options = {
            { text = "Back.", next = "about" },
        },
    },
    rumors = {
        npc = {
            "Someone came in talking about smoke north of the highway. Could be survivors, could be trouble.",
            "We heard gunfire after midnight. Short bursts. Organized, or scared. Hard to tell.",
            "A runner said the clinic road was clear this morning. I would not trust that by dusk.",
        },
        options = {
            { text = "Anything else?", next = "rumors" },
            { text = "Back.", next = "start" },
        },
    },
})

TQ.registerDialogueTreeBank("tq_independent_tree", {
    start = {
        npc = {
            "You got me. Say what you need to say.",
            "Line is bad, but I hear you.",
            "Make it quick. I do not like talking from one place too long.",
        },
        options = {
            { text = "Tell me about yourself.", next = "about" },
            { text = "Is there anything happening lately?", next = "rumors" },
            { text = "Anything you need done?", action = "show_jobs" },
            { text = "Goodbye.", action = "close" },
        },
    },
    about = {
        npc = {
            "No badge, no crew, no speeches. I stay alive and pay back favors.",
            "I used to know what my days were for. Now I count exits and canned food.",
        },
        options = {
            { text = "You trust anyone out there?", next = "trust" },
            { text = "Back.", next = "start" },
        },
    },
    trust = {
        npc = "Trust? No. But I keep a list of people who did not make things worse.",
        options = {
            { text = "Back.", next = "about" },
        },
    },
    rumors = {
        npc = {
            "There is a dead crowd moving west. Slow, but too many to ignore.",
            "Someone is stripping cars near the old road. If you hear engines, keep low.",
            "I heard a generator last night. Then screaming. Then nothing.",
        },
        options = {
            { text = "Anything else?", next = "rumors" },
            { text = "Back.", next = "start" },
        },
    },
})

TQ.registerFaction({
    id = "medics",
    name = "Field Medics",
    icon = "media/textures/TrueQuests/Factions/medics.png",
    fullImage = "media/textures/TrueQuests/Factions/medicsFull.png",
    unknownImage = "media/textures/TrueQuests/Factions/Unknown.png",
    maxActiveMembers = 2,
    rewardTables = {
        easy = "tq_medics_easy",
        default = "tq_medics_easy",
    },
    reputation = {
        easy = 6,
        medium = 12,
        hard = 20,
    },
    dialogueBank = "tq_medics_generic",
    dialogueTreeBank = "tq_medics_tree",
})

TQ.registerFaction({
    id = "independent",
    name = "Unaffiliated Survivors",
    icon = "media/textures/TrueQuests/Factions/independent.png",
    fullImage = "media/textures/TrueQuests/Factions/independentFull.png",
    unknownImage = "media/textures/TrueQuests/Factions/Unknown.png",
    maxActiveMembers = 2,
    rewardTables = {
        easy = "tq_independent_easy",
        default = "tq_independent_easy",
    },
    reputation = {
        easy = 3,
        medium = 6,
        hard = 10,
    },
    dialogueBank = "tq_independent_generic",
    dialogueTreeBank = "tq_independent_tree",
})

TQ.registerRewardTable("tq_medics_easy", {
    { item = "Base.Bandage", count = { min = 2, max = 5 }, weight = 10, rarity = "common" },
    { item = "Base.AlcoholWipes", count = { min = 2, max = 4 }, weight = 8, rarity = "common" },
    { item = "Base.Pills", count = 1, weight = 4, rarity = "uncommon" },
    { item = "Base.SutureNeedle", count = 1, weight = 2, rarity = "rare" },
})

TQ.registerRewardTable("tq_medics_doctor_easy", {
    { item = "Base.AlcoholWipes", count = { min = 3, max = 6 }, weight = 9, rarity = "common" },
    { item = "Base.Pills", count = { min = 1, max = 2 }, weight = 5, rarity = "uncommon" },
    { item = "Base.SutureNeedle", count = 1, weight = 3, rarity = "rare" },
})

TQ.registerRewardTable("tq_medics_nurse_easy", {
    { item = "Base.Bandage", count = { min = 3, max = 6 }, weight = 10, rarity = "common" },
    { item = "Base.AlcoholWipes", count = { min = 2, max = 5 }, weight = 8, rarity = "common" },
    { item = "Base.Pills", count = 1, weight = 3, rarity = "uncommon" },
})

TQ.registerRewardTable("tq_medics_paramedic_easy", {
    { item = "Base.Bandage", count = { min = 2, max = 5 }, weight = 9, rarity = "common" },
    { item = "Base.Pills", count = 1, weight = 5, rarity = "uncommon" },
    { item = "Base.SutureNeedle", count = 1, weight = 2, rarity = "rare" },
})

TQ.registerRewardTable("tq_independent_easy", {
    { item = "Base.Nails", count = { min = 20, max = 45 }, weight = 10, rarity = "common" },
    { item = "Base.DuctTape", count = 1, weight = 7, rarity = "common" },
    { item = "Base.Twine", count = 1, weight = 5, rarity = "common" },
    { item = "Base.Woodglue", count = 1, weight = 3, rarity = "uncommon" },
    { item = "Base.WaterBottle", count = 1, weight = 4, rarity = "uncommon" },
    { item = "Base.Hammer", count = 1, weight = 2, rarity = "rare" },
    { item = "Base.HuntingKnife", count = 1, weight = 1, rarity = "rare" },
})

TQ.registerContact({
    id = "dr_amelie_crowe",
    name = "Amelie Crowe",
    role = "leader",
    factionId = "medics",
    contactType = "radio",
    frequency = 92100,
    icon = "media/textures/TrueQuests/NPC/dr_amelie_crowe_icon.png",
    portrait = "media/textures/TrueQuests/NPC/dr_amelie_crowe.png",
    turnIn = FIELD_CLINIC,
    rewardTables = {
        easy = "tq_medics_doctor_easy",
    },
    dialogueBank = "tq_medics_generic",
    dialogueTreeBank = "tq_medics_tree",
    dialogue = {
        greeting = "This is Crowe. If you are healthy enough to walk, you are healthy enough to help.",
        about = "The clinic is small, loud, and still alive. That is enough for now.",
    },
    dialogueTree = {
        about = {
            npc = "Amelie Crowe. Doctor before, coordinator now. I miss when those were different jobs.",
            options = {
                { text = "What does the clinic need most?", next = "needs" },
                { text = "How are your people holding up?", next = "people" },
                { text = "Back.", next = "start" },
            },
        },
    },
})

TQ.registerContact({
    id = "nurse_mara_voss",
    name = "Mara Voss",
    role = "member",
    factionId = "medics",
    contactType = "radio",
    frequency = 92100,
    icon = "media/textures/TrueQuests/NPC/nurse_mara_voss_icon.png",
    portrait = "media/textures/TrueQuests/NPC/nurse_mara_voss.png",
    turnIn = FIELD_CLINIC,
    rewardTables = {
        easy = "tq_medics_nurse_easy",
    },
    dialogueBank = "tq_medics_generic",
    dialogueTreeBank = "tq_medics_tree",
    dialogue = {
        greeting = "Mara here. If you found clean cloth, I am interested.",
        work = "Bandages, wipes, anything that keeps a wound from turning ugly.",
    },
})

TQ.registerContact({
    id = "owen_hale",
    name = "Owen Hale",
    role = "member",
    factionId = "medics",
    contactType = "radio",
    frequency = 92100,
    icon = "media/textures/TrueQuests/NPC/owen_hale_icon.png",
    portrait = "media/textures/TrueQuests/NPC/owen_hale.png",
    turnIn = FIELD_CLINIC,
    rewardTables = {
        easy = "tq_medics_paramedic_easy",
    },
    dialogueBank = "tq_medics_generic",
    dialogueTreeBank = "tq_medics_tree",
    dialogue = {
        greeting = "Hale on the ambulance set. No ambulance left, but the radio still works.",
        about = "I used to drive people out of trouble. Now I mostly ask strangers for supplies.",
    },
})

TQ.registerContact({
    id = "marlow_relay",
    name = "Marlow",
    role = "independent",
    factionId = "independent",
    npcId = "tq_marlow_relay",
    contactType = "radio",
    frequency = 92100,
    icon = "media/textures/TrueQuests/NPC/independent_icon.png",
    portrait = "media/textures/TrueQuests/NPC/independent.png",
    turnIn = npcTurnIn("marlow_relay", MULDRAUGH_RELAY),
    rewardTables = {
        easy = "tq_independent_easy",
    },
    dialogueBank = "tq_independent_generic",
    dialogueTreeBank = "tq_independent_tree",
})

TQ.registerContact({
    id = "tess_roofline",
    name = "Tess",
    role = "independent",
    factionId = "independent",
    npcId = "tq_tess_roofline",
    contactType = "radio",
    frequency = 92100,
    icon = "media/textures/TrueQuests/NPC/independent_icon.png",
    portrait = "media/textures/TrueQuests/NPC/independent.png",
    turnIn = npcTurnIn("tess_roofline", MULDRAUGH_RELAY),
    rewardTables = {
        easy = "tq_independent_easy",
    },
    dialogueBank = "tq_independent_generic",
    dialogueTreeBank = "tq_independent_tree",
})

TQ.registerContact({
    id = "bradley_static",
    name = "Bradley",
    role = "independent",
    factionId = "independent",
    npcId = "tq_bradley_static",
    contactType = "radio",
    frequency = 92100,
    icon = "media/textures/TrueQuests/NPC/independent_icon.png",
    portrait = "media/textures/TrueQuests/NPC/independent.png",
    turnIn = npcTurnIn("bradley_static", MULDRAUGH_RELAY),
    rewardTables = {
        easy = "tq_independent_easy",
    },
    dialogueBank = "tq_independent_generic",
    dialogueTreeBank = "tq_independent_tree",
})

TQ.registerQuestTemplate({
    id = "medics_clean_bandages",
    title = "Clean Bandages",
    description = "Dr. Cross is running through clean dressings faster than the clinic can wash them. Bring bandages to the field clinic drop.",
    difficulty = "easy",
    contact = "dr_amelie_crowe",
    factionId = "medics",
    unique = true,
    repeatable = true,
    timeLimitHours = 24,
    tags = { "medical", "delivery" },
    objectives = {
        { type = "item", item = "Base.Bandage", count = { min = 4, max = 7 }, label = "Clean bandages" },
    },
    rewards = {
        table = "$contact",
        choices = 3,
    },
})

TQ.registerQuestTemplate({
    id = "medics_sterile_hands",
    title = "Sterile Hands",
    description = "Mara needs disinfectant for field dressings. Bring alcohol wipes to the field clinic drop.",
    difficulty = "easy",
    contact = "nurse_mara_voss",
    factionId = "medics",
    unique = true,
    repeatable = true,
    timeLimitHours = 24,
    tags = { "medical", "delivery" },
    objectives = {
        { type = "item", item = "Base.AlcoholWipes", count = { min = 2, max = 5 }, label = "Alcohol wipes" },
    },
    rewards = {
        table = "$contact",
        choices = 3,
    },
})

TQ.registerQuestTemplate({
    id = "medics_pain_control",
    title = "Pain Control",
    description = "Owen is rationing pills for people who cannot sleep through the pain. Bring spare medication to the field clinic drop.",
    difficulty = "easy",
    contact = "owen_hale",
    factionId = "medics",
    unique = true,
    repeatable = true,
    timeLimitHours = 24,
    tags = { "medical", "delivery" },
    objectives = {
        { type = "item", item = "Base.Pills", count = { min = 1, max = 2 }, label = "Pain medication" },
    },
    rewards = {
        table = "$contact",
        choices = 3,
    },
})

TQ.registerQuestTemplate({
    id = "marlow_barricade_nails",
    title = "Barricade Work",
    description = "A safehouse crew is boarding windows before nightfall. Bring nails back to Marlow's current spot.",
    difficulty = "easy",
    contact = "marlow_relay",
    factionId = "independent",
    unique = true,
    repeatable = true,
    timeLimitHours = 24,
    tags = { "supplies", "delivery" },
    objectives = {
        { type = "item", item = "Base.Nails", count = { min = 20, max = 40 }, label = "Nails" },
    },
    rewards = {
        table = "$contact",
        choices = 3,
    },
})

TQ.registerQuestTemplate({
    id = "tess_spare_sheets",
    title = "Spare Sheets",
    description = "Tess is cutting sheets into bandages and window covers. Bring spare sheets back to her current spot.",
    difficulty = "easy",
    contact = "tess_roofline",
    factionId = "independent",
    unique = true,
    repeatable = true,
    timeLimitHours = 24,
    tags = { "survival", "delivery" },
    objectives = {
        { type = "item", item = "Base.Sheet", count = { min = 2, max = 4 }, label = "Spare sheets" },
    },
    rewards = {
        table = "$contact",
        choices = 3,
    },
})

TQ.registerQuestTemplate({
    id = "bradley_water_run",
    title = "Water Run",
    description = "Bradley is trying to stock a small hideout before the taps go dry. Bring a sealed water bottle back to his current spot.",
    difficulty = "easy",
    contact = "bradley_static",
    factionId = "independent",
    unique = true,
    repeatable = true,
    timeLimitHours = 24,
    tags = { "survival", "delivery" },
    objectives = {
        { type = "item", item = "Base.WaterBottle", count = 1, label = "Sealed water bottle" },
    },
    rewards = {
        table = "$contact",
        choices = 3,
    },
})

TQ.log("Vanilla faction content loaded")
