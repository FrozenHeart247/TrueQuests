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

TQ.registerFaction({
    id = "medics",
    name = "Field Medics",
    icon = "media/textures/TrueQuests/Factions/medics.png",
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
})

TQ.registerFaction({
    id = "independent",
    name = "Unaffiliated Survivors",
    icon = "media/textures/TrueQuests/Factions/independent.png",
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
    id = "dr_ella_cross",
    name = "Dr. Ella Cross",
    role = "leader",
    factionId = "medics",
    contactType = "radio",
    frequency = 92100,
    icon = "media/textures/TrueQuests/NPC/dr_ella_cross_icon.png",
    portrait = "media/textures/TrueQuests/NPC/dr_ella_cross.png",
    turnIn = FIELD_CLINIC,
    rewardTables = {
        easy = "tq_medics_doctor_easy",
    },
    dialogueBank = "tq_medics_generic",
    dialogue = {
        greeting = "This is Cross. If you are healthy enough to walk, you are healthy enough to help.",
        about = "The clinic is small, loud, and still alive. That is enough for now.",
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
    contactType = "radio",
    frequency = 92100,
    icon = "media/textures/TrueQuests/NPC/independent_icon.png",
    portrait = "media/textures/TrueQuests/NPC/independent.png",
    turnIn = MULDRAUGH_RELAY,
    rewardTables = {
        easy = "tq_independent_easy",
    },
    dialogueBank = "tq_independent_generic",
})

TQ.registerContact({
    id = "tess_roofline",
    name = "Tess",
    role = "independent",
    factionId = "independent",
    contactType = "radio",
    frequency = 92100,
    icon = "media/textures/TrueQuests/NPC/independent_icon.png",
    portrait = "media/textures/TrueQuests/NPC/independent.png",
    turnIn = MULDRAUGH_RELAY,
    rewardTables = {
        easy = "tq_independent_easy",
    },
    dialogueBank = "tq_independent_generic",
})

TQ.registerContact({
    id = "bradley_static",
    name = "Bradley",
    role = "independent",
    factionId = "independent",
    contactType = "radio",
    frequency = 92100,
    icon = "media/textures/TrueQuests/NPC/independent_icon.png",
    portrait = "media/textures/TrueQuests/NPC/independent.png",
    turnIn = MULDRAUGH_RELAY,
    rewardTables = {
        easy = "tq_independent_easy",
    },
    dialogueBank = "tq_independent_generic",
})

TQ.registerQuestTemplate({
    id = "medics_clean_bandages",
    title = "Clean Bandages",
    description = "Dr. Cross is running through clean dressings faster than the clinic can wash them. Bring bandages to the field clinic drop.",
    difficulty = "easy",
    contact = "dr_ella_cross",
    factionId = "medics",
    unique = true,
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
    description = "A safehouse crew is boarding windows before nightfall. Bring nails to the Muldraugh relay cache.",
    difficulty = "easy",
    contact = "marlow_relay",
    factionId = "independent",
    unique = true,
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
    description = "Tess is cutting sheets into bandages and window covers. Bring spare sheets to the Muldraugh relay cache.",
    difficulty = "easy",
    contact = "tess_roofline",
    factionId = "independent",
    unique = true,
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
    description = "Bradley is trying to stock a small hideout before the taps go dry. Bring a sealed water bottle to the relay cache.",
    difficulty = "easy",
    contact = "bradley_static",
    factionId = "independent",
    unique = true,
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
