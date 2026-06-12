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

local function getContactNPCSpawn(contactId)
    local contact = TQ.getContact(contactId)
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
    return spawn or (npc and TN and TN.getNPCSpawn and TN.getNPCSpawn(npc) or nil), contact
end

local function npcSearchSource(contactId, fallback, options)
    options = type(options) == "table" and options or {}
    return function(ctx)
        local spawn, contact = getContactNPCSpawn(contactId)
        local base = type(spawn) == "table" and spawn or fallback
        local x = tonumber(base and base.x) or tonumber(fallback and fallback.x) or 0
        local y = tonumber(base and base.y) or tonumber(fallback and fallback.y) or 0
        local z = tonumber(base and base.z) or tonumber(fallback and fallback.z) or 0
        x = x + (tonumber(options.dx) or 0)
        y = y + (tonumber(options.dy) or 0)
        z = z + (tonumber(options.dz) or 0)

        local owner = tostring(contact and contact.name or "Survivor")
        return {
            mode = options.mode or "world",
            label = options.label or (owner .. "'s search area (" .. tostring(math.floor(x)) .. ", " .. tostring(math.floor(y)) .. ")"),
            markerLabel = options.markerLabel,
            x = x,
            y = y,
            z = z,
            radius = options.radius or 14,
            activationRange = options.activationRange or 180,
            spawnZombie = options.spawnZombie,
            outfit = options.outfit,
            femaleChance = options.femaleChance,
        }
    end
end

-- Dialogue layout:
-- dialogueBank = random reusable lines for greeting/about/work/accept/complete.
-- registerDialogueTopic = actual RPG-style conversation buttons and branches.
TQ.registerDialogueBank("tq_medics_generic", {
    greeting = {
        "Keep your hands clean and your voice low.",
        "You are for doc examination? Waint in line. Ha ha.. ha... Anyway you need something? We are short on time",
        "Welcome to Last Prescription clinic. Speak what you need",
    },
    about = {
        "We patch people up, move them before the dead gather, and hope the next call is not worse.",
        "Medicine is thin. Clean cloth, disinfectant, needles, pills. Everything matters now.",
    },
    work = {
        "We need supplies more than heroics.",
        "If you can carry medical stock to the drop, we can keep people alive. Anything else is useful too",
    },
    accept = {
        "Great. First of all stay alive and healthy. We dont need another dead body walking around",
        "Good. Please don't take it too long but don't rush it either. Most of the current death caused by stupid decisions",
    },
    complete = {
        "That buys us another day. Choose from the clinic cache.",
        "Clean delivery. Take what you need.",
    },
})

TQ.registerDialogueBank("tq_amelie_crowe", {
    greeting = {
        "If you are healthy enough to walk, you are healthy enough to help.",
        "Ugh... what do you need? If this is about a scratch, try surviving it dramatically somewhere else.",
        "The Last Prescription clinic is still standing, somehow. So, what do you want? Spit it out.",
        "*Yawn* Mmm... waking up remains a medical tragedy. What do you need?",
        "If you came here to complain, take a number. If you came to help, congratulations, you are already more useful than most.",
        "I am busy keeping people alive against their best efforts. Make this quick.",
        "Welcome to The Last Prescription. We are low on supplies, patience, and miracles. What do you want?.",
        "Ugh... what now? Please tell me this is important and not another heroic little paper cut.",
        "Talk fast. I have patients, corpses, and a headache, and only two of those are negotiable.",
         
    },
    about = {
        "Fine. Ask one precise thing.",
        "You want my story? Pick a subject.",
        "If this is small talk, I am billing you in disinfectant.",
    },
    work = {
        "I do not hand out errands. I mark problems and hope someone useful answers.",
        "If you can move without bleeding, I can give you something worth doing.",
        "There is always work. The dead are tireless, the sick are impatient, and supplies keep disappearing like they have legs.",       
        "Pick something from the list. Preferably something you can finish without turning it into my problem.",
        "These are not heroic quests. They are ugly little necessities. Welcome to survival, try not to look disappointed.",
        "I have patients, shortages, broken equipment, and people with the survival instincts of wet paper. Choose where you want to be useful.",    
        "Do not ask me which task is safest. If it were safe, I would have sent one of the idiots already.",
        "Take a job if you can handle it. Leave it if you cannot. I prefer honest cowardice over confident incompetence.",
        "If you fail, try to fail far away from the clinic. I have enough messes indoors.",
    },
    accept = {
        "Good. If it gets ugly, adapt. If it gets stupid, leave. I prefer survivors over martyrs.",
        "Try to finish it without bleeding on anything important. Including yourself.",
        "Good. Bring results, not excuses. I already have enough of those lying around.",
        "All right. Handle it properly, and I might even pretend I expected that.",
        "Good. If you get bitten, do not come back expecting a touching speech.",
        "Good. I will mark it as taken. You try to make sure I do not have to mark you as missing.",
        "Task is yours. Do not improvise unless the plan is already dead. Which, admittedly, happens often.",
    },
    complete = {
        "That helps. Choose something from the clinic cache before I change my mind.",
        "Good. You did the job and came back in one piece. I am almost impressed. Truly.",
        "That will keep this place breathing a little longer. Choose your payment.",
        "You brought results. I like results. They make fewer noises than excuses.",
        "That solves one problem. Unfortunately, the world has excellent production speed. Pick something and move along.",
        "The clinic can use this. You can use a reward. Look at us, pretending this is a functioning economy.",
        "That was handled properly. I will file this under rare pleasant surprises.",
        "Fine, you earned it. The cache is open. Do not grab like a raccoon with a medical license.",
        "You did well. There, I said it. Do not make it weird.",
    },
})

local AMELIE_ABOUT_TOPICS = {
    {
        id = "amelie_about_identity",
        text = "Who are you?",
        npc = "Name's Amelie Crowe. I was a surgeon before all this. Cleaner rooms, better tools, fewer patients trying to bite me. I almost miss it.",
        priority = 10,
    },
    {
        id = "amelie_about_clinic",
        text = "What is The Last Prescription?",
        npc = "I used to run a clinic. A real one. Appointments, paperwork, sterilized instruments, people complaining about waiting ten minutes. Adorable times. Now I run The Last Prescription. Small clinic, loud patients, bad lighting, worse coffee. Still alive, which makes it a luxury resort by current standards.",
        priority = 20,
    },
    {
        id = "amelie_about_leadership",
        text = "Are you the leader here?",
        npc = "Some people call me the leader of these emptyheads. I am not. I just happen to be the only one here with actual medical experience and a functioning brain. Leadership is mostly telling people not to do stupid things, then treating them when they do the stupid thing anyway.",
        priority = 30,
    },
    {
        id = "amelie_about_why",
        text = "Why keep the clinic running?",
        npc = "I do not keep this place running because I am nice. I keep it running because infection, blood loss, and fever do not care about your charming personality.",
        priority = 40,
    },
    {
        id = "amelie_about_before",
        text = "What did you do before this?",
        npc = "Before the outbreak, I fixed people with scalpels, sutures, and expensive machines. Now I use boiled water, dirty tables, and language strong enough to disinfect wounds.",
        priority = 50,
    },
    {
        id = "amelie_about_cure",
        text = "Do you know anything about a cure?",
        npc = "No, I do not have a miracle cure. If I did, I would not be standing here explaining basic hygiene to armed cave people.",
        priority = 60,
    },
    {
        id = "amelie_about_losses",
        text = "Have you lost many patients?",
        npc = "I have lost patients. Before and after. The difference is that before, people at least had the decency to stay dead.",
        priority = 70,
    },
    {
        id = "amelie_about_goal",
        text = "What are you trying to do here?",
        npc = "I am trying to keep this little corner of the world breathing for one more day. Modest goal. Still apparently too advanced for most people.",
        priority = 80,
    },
    {
        id = "amelie_about_supplies",
        text = "What does the clinic need most?",
        npc = "Sterile supplies first. Alcohol wipes, sutures, painkillers, clean bandages. Food keeps people walking, but infection decides who gets to keep walking.",
        priority = 90,
    },
    {
        id = "amelie_about_people",
        text = "How are your people holding up?",
        npc = "Badly, professionally, and with too much caffeine. That is not a joke, just the current triage note.",
        priority = 100,
    },
}

TQ.registerDialogueBank("tq_independent_generic", {
    greeting = {
        "Anyone alive on this frequency? Sometimes it seems like I'm talking to ghosts...",
        "I can hear ya. Keep it short. I am not staying on the air long.",
        "You hear this? Good. I might have a job if you are interested.",
        "Whoa! There's actually someone alive. Could you help me?",
        "I heard people make umbushes and killing each other just for fun. I hope you're not one of them",
        "Keep it short. I don't have time talking all day.",
    },
    about = {
        "No faction, no banner. Just people trying to get through one more day.",
        "We are simple people just trying to survive.",
        "If I can make it through another day I call it a win. ",
        "I trade favors, not promises.",
        "Better alone and in motion. No connections no responsibilities. If something goes wrong I know who's fault it is.",
    },
    work = {
        "Could be salvage, could be delivery. Depends what the dead are blocking today.",
        "If you can haul it, I can pay.",
        "I badly need those from the that list. Interested to share?",
        "Might be risky. And I'm not asking you to die for me. But would be great if you could help",
        "A simple job that can turn into not that simple one.. Still interested?",
    },
    accept = {
        "Good. I will remember this. Don't take too long and be careful",
        "Copy that. Watch the roads.",
        "Alright. Hope you words mean something.And do not bring a tail.",
    },
    complete = {
        "You did it! Thanks so much!. I can share with you one of my findings. Pick something.",
        "That is better than I expected. Take your pay.",
        "You actually made it. I guess humanity is not dead yet. Here's your reward",
        "Thanks. Perhaps I can help you another time.",
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
    system = true,
    priority = 1,
    condition = hasPendingFailureNotice,
    npc = failureNoticeLine,
    onEnter = acknowledgeFailureNotice,
})

TQ.registerDialogueTopic({
    id = "amelie_about",
    contactId = "dr_amelie_crowe",
    text = "Tell me about yourself.",
    lineKey = "about",
    priority = 10,
})

for _, topic in ipairs(AMELIE_ABOUT_TOPICS) do
    TQ.registerDialogueTopic({
        id = topic.id,
        contactId = "dr_amelie_crowe",
        parent = "amelie_about",
        text = topic.text,
        npc = topic.npc,
        priority = topic.priority,
    })
end

TQ.registerDialogueTopic({
    id = "amelie_rumors",
    contactId = "dr_amelie_crowe",
    text = "Is there anything happening lately?",
    npc = {
        "I have three reports of smoke east of the highway and no clean way to verify them.",
        "Someone is moving medical stock without knowing how to store it. That bothers me more than the theft.",
        "The dead are bunching near the clinic road again. If you cross it, do not stop to count them.",
    },
    priority = 20,
    children = {
        {
            id = "amelie_rumors_more",
            contactId = "dr_amelie_crowe",
            text = "Anything else?",
            npc = {
                "A patient swore they heard an engine after midnight. Could be rescue. Could be another idiot with fuel.",
                "One of our runners saw fresh blood on a clinic door and no body. I dislike unfinished stories.",
            },
        },
    },
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
            npc = "Clean cloth, bandages, disinfectant, painkillers and pretty much all medicine you can find. Everything else is comfort.",
            priority = 10,
        },
        {
            id = "medics_people",
            factionId = "medics",
            text = "How are your people holding up?",
            npc = "We holding up. Mostly. Trying to help others more than ourselves. Always low on supply",
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
    dialogueBank = "tq_amelie_crowe",
    dialogueExclusive = true,
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
})

TQ.registerQuestTemplate({
    id = "medics_clean_bandages",
    title = "Clean Bandages",
    description = "Dr. Crowe is running through clean dressings faster than the clinic can wash them. Bring bandages to the field clinic drop.",
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

TQ.registerQuestTemplate({
    id = "marlow_lost_acoustic_guitar",
    title = "Lost Acoustic",
    description = "Marlow left a marked acoustic guitar in a small stash before moving camp. Recover Marlow's guitar and bring it back to his current spot.",
    difficulty = "easy",
    contact = "marlow_relay",
    factionId = "independent",
    unique = true,
    timeLimitHours = 48,
    tags = { "salvage", "memento", "quest-item" },
    objectives = {
        {
            id = "guitar",
            type = "item",
            item = "Base.GuitarAcoustic",
            count = 1,
            label = "Marlow's acoustic guitar",
            questItem = true,
            questItemName = "Marlow's Acoustic Guitar",
            questItemTooltip = "A scratched acoustic guitar marked with Marlow's initials.",
            sourceHint = "Search the marked stash near Marlow's current route.",
            source = npcSearchSource("marlow_relay", MULDRAUGH_RELAY, {
                mode = "world",
                dx = 18,
                dy = 10,
                radius = 10,
                label = "Marlow's old music stash",
                markerLabel = "Marlow's guitar stash",
            }),
        },
    },
    rewards = {
        table = "$contact",
        choices = 3,
    },
})

TQ.registerQuestTemplate({
    id = "tess_happy_face_pillow",
    title = "Happy Face",
    description = "Tess is looking for a specific happy face pillow from an old safehouse. One of the dead near the place carried it off.",
    difficulty = "easy",
    contact = "tess_roofline",
    factionId = "independent",
    unique = true,
    timeLimitHours = 48,
    tags = { "salvage", "memento", "quest-item" },
    objectives = {
        {
            id = "pillow",
            type = "item",
            item = "Base.Pillow_Happyface",
            count = 1,
            label = "Tess's happy face pillow",
            questItem = true,
            questItemName = "Tess's Happy Face Pillow",
            questItemTooltip = "A faded happy face pillow Tess asked you to recover.",
            sourceHint = "Search the carrier zombie near Tess's old safehouse route.",
            source = npcSearchSource("tess_roofline", MULDRAUGH_RELAY, {
                mode = "zombie",
                dx = -16,
                dy = 14,
                radius = 16,
                activationRange = 190,
                spawnZombie = true,
                label = "Tess's old safehouse route",
                markerLabel = "Carrier zombie search area",
            }),
        },
    },
    rewards = {
        table = "$contact",
        choices = 3,
    },
})

TQ.log("Vanilla faction content loaded")
