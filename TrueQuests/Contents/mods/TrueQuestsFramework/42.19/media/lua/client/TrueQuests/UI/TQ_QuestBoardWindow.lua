require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_UITheme"
require "TrueQuests/UI/TQ_RewardChoiceWindow"

TQ_QuestBoardWindow = ISPanel:derive("TQ_QuestBoardWindow")
TQ_QuestBoardWindow.instance = nil

local UNKNOWN_FACTION_IMAGE = "media/textures/TrueQuests/Factions/Unknown.png"

local function setVisible(element, visible)
    if not element then
        return
    end

    if element.setVisible then
        element:setVisible(visible)
    else
        element.visible = visible
    end

    if element.setEnable then
        element:setEnable(visible == true)
    end
end

local function setButtonTitle(button, title)
    if not button then
        return
    end

    if button.setTitle then
        button:setTitle(title)
    else
        button.title = title
    end
end

local function setChildBounds(child, x, y, width, height)
    if not child then
        return
    end

    child.x = x
    child.y = y
    child.width = width
    child.height = height

    if child.setX then child:setX(x) end
    if child.setY then child:setY(y) end
    if child.setWidth then child:setWidth(width) end
    if child.setHeight then child:setHeight(height) end
end

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function statusLabel(status)
    if status == "readyToTurnIn" then return "Ready" end
    if status == "rewardPending" then return "Reward" end
    if status == "accepted" then return "Active" end
    return tostring(status or "")
end

local function statusColor(status)
    if status == "readyToTurnIn" then return "green" end
    if status == "rewardPending" then return "amber" end
    return "blue"
end

local function difficultyColor(difficulty)
    difficulty = string.lower(tostring(difficulty or ""))
    if difficulty == "hard" or difficulty == "deadly" then return "red" end
    if difficulty == "medium" or difficulty == "normal" then return "amber" end
    if difficulty == "easy" then return "green" end
    return "blue"
end

local function factionAccent(factionId)
    factionId = tostring(factionId or "")
    if factionId == "medics" then return "green" end
    if factionId == "independent" then return "amber" end
    return "blue"
end

local function reasonText(reason, quest)
    if reason == "wrong_location" then
        return "Bring this to " .. TrueQuests.turnInToText(quest and quest.turnIn)
    end
    if reason == "objectives_incomplete" then
        return "Objectives are not complete yet."
    end
    if reason == "consume_failed" then
        return "Required items are missing."
    end
    if reason == "expired" then
        return "That request has already expired."
    end
    if reason == "contact_inactive" then
        return "That contact is not answering right now."
    end
    return "Cannot turn this in yet."
end

local function factionName(factionId)
    local faction = TrueQuests.getFaction and TrueQuests.getFaction(factionId)
    return tostring((faction and faction.name) or factionId or "Unknown")
end

local function contactName(contactId)
    local contact = TrueQuests.getContact and TrueQuests.getContact(contactId)
    return tostring((contact and contact.name) or contactId or "Unknown")
end

local function contactFactionId(contact)
    if TrueQuests.Factions and TrueQuests.Factions.getFactionIdForContact then
        return TrueQuests.Factions.getFactionIdForContact(contact)
    end

    return tostring(contact and (contact.factionId or contact.faction) or "independent")
end

local function reputationText(player, factionId)
    if not TrueQuests.Factions or not TrueQuests.Factions.getReputation then
        return "Rep: 0"
    end

    return "Rep: " .. tostring(TrueQuests.Factions.getReputation(player, factionId or "independent"))
end

local function getTextureSafe(path)
    if not path or not getTexture then
        return nil
    end

    local ok, texture = pcall(function()
        return getTexture(tostring(path))
    end)

    if ok then
        return texture
    end
    return nil
end

local function drawTextureFit(panel, texture, x, y, width, height, alpha)
    if not texture then
        return false
    end

    local tw = texture:getWidth()
    local th = texture:getHeight()
    if not tw or not th or tw <= 0 or th <= 0 then
        return false
    end

    local scale = math.min(width / tw, height / th)
    local drawW = tw * scale
    local drawH = th * scale
    panel:drawTextureScaled(texture, x + (width - drawW) / 2, y + (height - drawH) / 2, drawW, drawH, alpha or 1, 1, 1, 1)
    return true
end

local function makeButton(parent, x, y, width, height, title, callback, kind)
    local button = ISButton:new(x, y, width, height, title, parent, callback)
    button:initialise()
    TQ_UITheme.styleButton(button, kind)
    parent:addChild(button)
    return button
end

local function tableCount(list)
    return type(list) == "table" and #list or 0
end

local function getActiveContactsForFaction(player, factionId, forceIfEmpty)
    if not TrueQuests.Factions or not TrueQuests.Factions.getActiveContacts then
        return {}
    end

    local contacts = TrueQuests.Factions.getActiveContacts(player, factionId) or {}
    if forceIfEmpty and #contacts == 0 and TrueQuests.Factions.ensureActiveContacts then
        TrueQuests.Factions.ensureActiveContacts(player, true)
        contacts = TrueQuests.Factions.getActiveContacts(player, factionId) or {}
    end

    return contacts
end

local function ensureFactionSummary(summaries, factionId)
    factionId = tostring(factionId or "independent")
    local summary = summaries[factionId]
    if summary then
        return summary
    end

    local faction = TrueQuests.getFaction and TrueQuests.getFaction(factionId) or nil
    summary = {
        factionId = factionId,
        faction = faction,
        name = tostring((faction and faction.name) or factionId),
        activeContacts = 0,
        activeQuests = 0,
        offers = 0,
    }
    summaries[factionId] = summary
    return summary
end

local function entryKey(entry)
    if not entry then return nil end
    if entry.kind == "active" and entry.quest then return "active:" .. tostring(entry.quest.id) end
    if entry.kind == "offer" and entry.offer then return "offer:" .. tostring(entry.offer.templateId) end
    return nil
end

local function objectiveCountText(value)
    if type(value) == "table" then
        local minValue = tonumber(value.min or value[1]) or 1
        local maxValue = tonumber(value.max or value[2]) or minValue
        if minValue == maxValue then
            return tostring(minValue)
        end
        return tostring(minValue) .. "-" .. tostring(maxValue)
    end

    return tostring(tonumber(value) or 1)
end

local function describeObjectiveTemplate(objective)
    if type(objective) ~= "table" then
        return ""
    end

    if objective.type == "item" then
        local name = objective.label or TrueQuests.getItemDisplayName(objective.item)
        local verb = (objective.questItem == true or objective.uniqueItem == true or objective.source or objective.spawn) and "Recover " or "Bring "
        local text = verb .. tostring(name) .. " x" .. objectiveCountText(objective.count or objective.required or 1)
        if objective.sourceHint then
            text = text .. " - " .. tostring(objective.sourceHint)
        end
        return text
    end

    if objective.description then
        return tostring(objective.description)
    end

    return "Complete " .. tostring(objective.type or "objective")
end

local function resolveOfferTurnIn(offer)
    local template = offer and offer.template or nil
    if template and type(template.turnIn) == "table" then
        return template.turnIn
    end

    local contact = offer and TrueQuests.getContact and TrueQuests.getContact(offer.contactId) or nil
    if contact and type(contact.turnIn) == "table" then
        return contact.turnIn
    end

    return nil
end

local function appendTurnIn(text, turnIn)
    local location = TrueQuests.turnInToText and TrueQuests.turnInToText(turnIn) or ""
    if location ~= "" and location ~= "Unknown location" then
        return tostring(text or "") .. ". Turn in: " .. tostring(location)
    end
    return tostring(text or "")
end

local function offerMetaText(offer)
    local template = offer and offer.template or nil
    local objectives = template and template.objectives or nil
    local text = ""

    if type(objectives) == "table" and #objectives > 0 then
        text = describeObjectiveTemplate(objectives[1])
        if #objectives > 1 then
            text = text .. " +" .. tostring(#objectives - 1) .. " more"
        end
    elseif offer and offer.description and tostring(offer.description) ~= "" then
        text = tostring(offer.description)
    else
        text = "Ask for details."
    end

    return appendTurnIn(text, resolveOfferTurnIn(offer))
end

local function questMetaText(quest)
    local parts = {}
    for _, objective in ipairs(quest and quest.objectives or {}) do
        table.insert(parts, TrueQuests.Objectives.describe(objective))
        if #parts >= 2 then
            break
        end
    end

    local text = #parts > 0 and table.concat(parts, "; ") or tostring((quest and quest.description) or "")
    if text == "" then
        text = "Quest in progress."
    end

    text = appendTurnIn(text, quest and quest.turnIn)
    if TrueQuests.QuestManager and TrueQuests.QuestManager.formatTimeRemaining then
        local timer = TrueQuests.QuestManager.formatTimeRemaining(quest)
        if timer and timer ~= "No deadline" then
            text = text .. ". Time: " .. tostring(timer)
        end
    end

    return text
end

local function offerRefreshDue(player)
    if not TrueQuests.Save or not TrueQuests.Save.getData or not TrueQuests.getWorldAgeHours then
        return false
    end

    local data = TrueQuests.Save.getData(player)
    local refreshAt = tonumber(data and data.offers and data.offers.refreshAt) or 0
    return refreshAt > 0 and TrueQuests.getWorldAgeHours() >= refreshAt
end

local function offerRefreshText(player)
    if not TrueQuests.Save or not TrueQuests.Save.getData or not TrueQuests.getWorldAgeHours then
        return ""
    end

    local data = TrueQuests.Save.getData(player)
    local refreshAt = tonumber(data and data.offers and data.offers.refreshAt) or 0
    if refreshAt <= 0 then
        return ""
    end

    local remaining = math.max(0, refreshAt - TrueQuests.getWorldAgeHours())
    if remaining <= 0 then
        return "refreshing"
    end

    return "refresh in " .. tostring(math.ceil(remaining)) .. "h"
end

local function dialogueOptionKind(option)
    option = type(option) == "table" and option or {}
    if option.action == "show_jobs" then return "info" end
    if option.action == "close" then return "muted" end
    if option.action == "back_dialogue" then return "muted" end
    if tostring(option.text or "") == "Back." then return "muted" end
    return "default"
end

local function dialogueOptionsSignature(options)
    if type(options) ~= "table" then
        return ""
    end

    local parts = {}
    for index, option in ipairs(options) do
        parts[index] = tostring(option.text or "")
            .. "|" .. tostring(option.action or "")
            .. "|" .. tostring(option.next or "")
            .. "|" .. tostring(option.topicId or "")
    end
    return table.concat(parts, "\n")
end

function TQ_QuestBoardWindow:isRadioBoard()
    return self.device ~= nil
end

function TQ_QuestBoardWindow:initialise()
    ISPanel.initialise(self)
end

function TQ_QuestBoardWindow:createChildren()
    ISPanel.createChildren(self)
    self:applyLayout()

    self.questList = ISScrollingListBox:new(self.jobsX, self.jobsY, self.jobsW, self.jobsH)
    self.questList:initialise()
    self.questList:instantiate()
    self.questList.itemheight = 58
    self.questList.doDrawItem = TQ_QuestBoardWindow.drawJobItem
    self.questList.drawBorder = false
    self:addChild(self.questList)

    self.optionList = ISScrollingListBox:new(self.optionsListX, self.optionsListY, self.optionsListW, self.optionsListH)
    self.optionList:initialise()
    self.optionList:instantiate()
    self.optionList.itemheight = 34
    self.optionList.doDrawItem = TQ_QuestBoardWindow.drawDialogueOptionItem
    self.optionList.drawBorder = false
    self.optionList.parentWindow = self
    self.optionList:setOnMouseDownFunction(self, TQ_QuestBoardWindow.onDialogueOptionSelected)
    self:addChild(self.optionList)

    self.backButton = makeButton(self, 16, self.height - 40, 88, 26, "Back", TQ_QuestBoardWindow.onBack, "muted")
    self.refreshButton = makeButton(self, 112, self.height - 40, 92, 26, "Refresh", TQ_QuestBoardWindow.refreshData, "default")
    self.acceptButton = makeButton(self, 214, self.height - 40, 92, 26, "Accept", TQ_QuestBoardWindow.onAccept, "primary")
    self.turnInButton = makeButton(self, 314, self.height - 40, 102, 26, "Turn In", TQ_QuestBoardWindow.onTurnIn, "warning")
    self.closeButton = makeButton(self, self.width - 108, self.height - 40, 92, 26, "Close", TQ_QuestBoardWindow.close, "muted")
    self.topCloseButton = makeButton(self, self.width - 27, 3, 21, 18, "X", TQ_QuestBoardWindow.close, "danger")

    self.optionButtons = {}
    for index = 1, 6 do
        self:createOptionButton(index)
    end

    self:applyLayout()
    self:refreshData()
end

function TQ_QuestBoardWindow:createOptionButton(index)
    local optionIndex = index
    local button = ISButton:new(self.optionsX, self.optionsY, 260, 28, "", self, function(target)
        target:onDialogueOption(optionIndex)
    end)
    button:initialise()
    TQ_UITheme.styleButton(button, "default")
    self:addChild(button)
    table.insert(self.optionButtons, button)
    return button
end

function TQ_QuestBoardWindow:ensureOptionButtons(count)
    count = tonumber(count) or 0
    while #self.optionButtons < count do
        self:createOptionButton(#self.optionButtons + 1)
    end
end

function TQ_QuestBoardWindow:applyLayout()
    self.minimumWidth = self.minimumWidth or 820
    self.minimumHeight = self.minimumHeight or 560
    self.width = math.max(self.minimumWidth, self.width)
    self.height = math.max(self.minimumHeight, self.height)

    self.bodyX = 16
    self.bodyY = 34
    self.bodyW = self.width - 32
    self.bodyH = self.height - 88
    self.headerH = 74
    self.contentX = self.bodyX
    self.contentY = self.bodyY + self.headerH + 12
    self.contentW = self.bodyW
    self.contentH = self.bodyH - self.headerH - 12

    self.dialoguePortraitW = clamp(math.floor(self.contentW * 0.30), 220, 280)
    self.dialogueX = self.contentX + self.dialoguePortraitW + 14
    self.dialogueY = self.contentY
    self.dialogueW = self.contentX + self.contentW - self.dialogueX
    self.dialogueH = self.contentH

    self.optionsX = self.dialogueX + 12
    self.optionsY = self.dialogueY + 132
    self.optionsListX = self.optionsX
    self.optionsListY = self.optionsY
    self.optionsListW = self.dialogueW - 24
    self.optionsListH = self.jobsRevealed and 38 or math.max(82, self.dialogueH - 150)
    self.jobsX = self.dialogueX + 12
    self.jobsY = self.optionsListY + self.optionsListH + 28
    self.jobsW = self.dialogueW - 24
    self.jobsH = math.max(90, self.dialogueY + self.dialogueH - self.jobsY - 16)

    setChildBounds(self.questList, self.jobsX, self.jobsY, self.jobsW, self.jobsH)
    setChildBounds(self.optionList, self.optionsListX, self.optionsListY, self.optionsListW, self.optionsListH)
    setChildBounds(self.backButton, 16, self.height - 40, 88, 26)
    setChildBounds(self.refreshButton, 112, self.height - 40, 92, 26)
    setChildBounds(self.acceptButton, 214, self.height - 40, 92, 26)
    setChildBounds(self.turnInButton, 314, self.height - 40, 102, 26)
    setChildBounds(self.closeButton, self.width - 108, self.height - 40, 92, 26)
    setChildBounds(self.topCloseButton, self.width - 27, 3, 21, 18)
    for index, button in ipairs(self.optionButtons or {}) do
        setChildBounds(button, self.optionsX, self.optionsY + (index - 1) * 36, math.min(420, self.dialogueW - 24), 28)
    end
end

function TQ_QuestBoardWindow:refreshData()
    local selectedKey = entryKey(self:getSelectedJobEntry())
    TrueQuests.QuestManager.updateAll(self.player)

    self.factionCards = {}
    self.contactCards = {}
    self.cardHitboxes = {}
    self.activeCount = 0
    self.offerCount = 0
    self.activeContactCount = 0

    self.activeContacts = TrueQuests.Factions and TrueQuests.Factions.getActiveContacts(self.player) or TrueQuests.getContacts()
    self.activeQuests = TrueQuests.QuestManager.getActiveQuests(self.player) or {}
    self.offers = TrueQuests.QuestManager.getOffers(self.player, nil, nil) or {}

    if self.mode == "factions" then
        self:buildFactionCards()
    elseif self.mode == "contacts" then
        self:buildContactCards()
    elseif self.mode == "dialogue" then
        self:refreshJobList(selectedKey)
    end

    self:updateControls()
end

function TQ_QuestBoardWindow:buildFactionCards()
    local summaries = {}

    for _, faction in ipairs(TrueQuests.getFactions and TrueQuests.getFactions() or {}) do
        ensureFactionSummary(summaries, faction.id)
    end

    for _, contact in ipairs(self.activeContacts or {}) do
        local summary = ensureFactionSummary(summaries, contactFactionId(contact))
        summary.activeContacts = summary.activeContacts + 1
        self.activeContactCount = self.activeContactCount + 1
    end

    for _, quest in ipairs(self.activeQuests or {}) do
        local summary = ensureFactionSummary(summaries, quest.factionId or contactFactionId(TrueQuests.getContact(quest.contactId)))
        summary.activeQuests = summary.activeQuests + 1
        self.activeCount = self.activeCount + 1
    end

    for _, offer in ipairs(self.offers or {}) do
        local summary = ensureFactionSummary(summaries, offer.factionId or contactFactionId(TrueQuests.getContact(offer.contactId)))
        summary.offers = summary.offers + 1
        self.offerCount = self.offerCount + 1
    end

    for _, summary in pairs(summaries) do
        if summary.activeContacts > 0 or summary.activeQuests > 0 or summary.offers > 0 then
            table.insert(self.factionCards, summary)
        end
    end

    table.sort(self.factionCards, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)
end

function TQ_QuestBoardWindow:buildContactCards()
    self.contactCards = {}
    local contacts = getActiveContactsForFaction(self.player, self.selectedFactionId, true)
    for _, contact in ipairs(contacts or {}) do
        table.insert(self.contactCards, contact)
        self.activeContactCount = self.activeContactCount + 1
    end

    table.sort(self.contactCards, function(a, b)
        local ar = tostring(a.role or "")
        local br = tostring(b.role or "")
        if ar ~= br then
            return ar < br
        end
        return tostring(a.name or a.id) < tostring(b.name or b.id)
    end)

    for _, quest in ipairs(self.activeQuests or {}) do
        if tostring(quest.factionId or "") == tostring(self.selectedFactionId) then
            self.activeCount = self.activeCount + 1
        end
    end

    for _, offer in ipairs(self.offers or {}) do
        if tostring(offer.factionId or "") == tostring(self.selectedFactionId) then
            self.offerCount = self.offerCount + 1
        end
    end
end

function TQ_QuestBoardWindow:refreshJobList(selectedKey)
    self.questList:clear()
    self.entries = {}

    if not self.jobsRevealed or not self.selectedContactId then
        return
    end

    for _, quest in ipairs(self.activeQuests or {}) do
        if tostring(quest.contactId or "") == tostring(self.selectedContactId) then
            self.activeCount = self.activeCount + 1
            local entry = {
                kind = "active",
                quest = quest,
                contactId = quest.contactId,
                factionId = quest.factionId or self.selectedFactionId,
                badge = statusLabel(quest.status),
                accent = statusColor(quest.status),
                meta = questMetaText(quest),
            }
            table.insert(self.entries, entry)
            self.questList:addItem(tostring(quest.title), entry)
        end
    end

    local contactOffers = TrueQuests.QuestManager.getOffers(self.player, self.selectedContactId, nil) or {}
    for _, offer in ipairs(contactOffers) do
        self.offerCount = self.offerCount + 1
        local entry = {
            kind = "offer",
            offer = offer,
            contactId = offer.contactId,
            factionId = offer.factionId or self.selectedFactionId,
            badge = tostring(offer.difficulty),
            accent = difficultyColor(offer.difficulty),
            meta = offerMetaText(offer),
        }
        table.insert(self.entries, entry)
        self.questList:addItem(tostring(offer.title), entry)
    end

    local fallbackSelected = 1
    for index, row in ipairs(self.questList.items or {}) do
        if entryKey(row.item) == selectedKey then
            fallbackSelected = index
            break
        end
    end

    if self.questList.items and #self.questList.items > 0 then
        self.questList.selected = fallbackSelected
    end
end

function TQ_QuestBoardWindow:updateControls()
    self:applyLayout()

    local inDialogue = self.mode == "dialogue"
    local showJobs = inDialogue and self.jobsRevealed == true
    local selected = self:getSelectedJobEntry()

    setVisible(self.questList, showJobs)
    setVisible(self.acceptButton, showJobs)
    setVisible(self.turnInButton, showJobs)
    self:updateDialogueOptions()

    self.backButton:setEnable(self.mode ~= "factions")
    self.refreshButton:setEnable(true)
    self.closeButton:setEnable(true)

    local canAccept = showJobs and selected and selected.kind == "offer"
    local canTurnIn = showJobs and not self:isRadioBoard() and selected and selected.kind == "active"
    self.acceptButton:setEnable(canAccept == true)
    self.turnInButton:setEnable(canTurnIn == true)

    if self:isRadioBoard() then
        setButtonTitle(self.turnInButton, "In Person")
    elseif selected and selected.kind == "active" and selected.quest and selected.quest.status == "rewardPending" then
        setButtonTitle(self.turnInButton, "Rewards")
    else
        setButtonTitle(self.turnInButton, "Turn In")
    end
end

function TQ_QuestBoardWindow.drawJobItem(list, y, item, alt)
    local entry = item.item
    local selected = list.selected == item.index
    local rowX = 3
    local rowY = y + 3
    local rowW = list.width - 6
    local rowH = list.itemheight - 6
    local fill = selected and "selected" or (alt and "rowAlt" or "panelBg")
    local accent = (entry and entry.accent) or "blue"

    TQ_UITheme.drawPanel(list, rowX, rowY, rowW, rowH, fill, selected and accent or "borderSoft")
    TQ_UITheme.drawAccent(list, rowX, rowY, 4, rowH, accent)

    local badge = tostring((entry and entry.badge) or "")
    local badgeW = math.max(52, TQ_UITheme.measure(UIFont.Small, badge) + 14)
    local titleW = rowW - badgeW - 24
    list:drawText(TQ_UITheme.truncate(item.text, titleW, UIFont.Small), rowX + 12, rowY + 8, 0.92, 0.91, 0.86, 1, UIFont.Small)
    list:drawText(TQ_UITheme.truncate((entry and entry.meta) or "", rowW - 24, UIFont.Small), rowX + 12, rowY + 31, 0.58, 0.63, 0.65, 1, UIFont.Small)

    if badge ~= "" then
        TQ_UITheme.drawPill(list, rowX + rowW - badgeW - 7, rowY + 8, badgeW, 20, badge, accent)
    end

    return y + list.itemheight
end

function TQ_QuestBoardWindow:getSelectedJobEntry()
    if not self.questList or not self.questList.items then
        return nil
    end

    local row = self.questList.items[self.questList.selected]
    return row and row.item or nil
end

function TQ_QuestBoardWindow:getSelectedContact()
    return self.selectedContactId and TrueQuests.getContact(self.selectedContactId) or nil
end

function TQ_QuestBoardWindow:hasPendingFailureNotice()
    return TrueQuests.QuestManager
        and TrueQuests.QuestManager.getPendingFailureNotice
        and TrueQuests.QuestManager.getPendingFailureNotice(self.player, self.selectedFactionId) ~= nil
end

function TQ_QuestBoardWindow:onBack()
    if self.mode == "dialogue" then
        self.mode = "contacts"
        self.selectedContactId = nil
        self.jobsRevealed = false
        self.currentLine = nil
        self.currentDialogueNode = nil
        self.currentDialogueNodeData = nil
        self.dialogueOptions = nil
    elseif self.mode == "contacts" then
        self.mode = "factions"
        self.selectedFactionId = nil
        self.factionGreetingLine = nil
    end

    self:refreshData()
end

function TQ_QuestBoardWindow:loadDialogueNode(nodeId)
    local contact = self:getSelectedContact()
    if not contact then
        return
    end

    local node = TrueQuests.Dialogue and TrueQuests.Dialogue.getTreeNode and TrueQuests.Dialogue.getTreeNode(contact, nodeId, { player = self.player }) or nil
    self.currentDialogueNode = tostring(nodeId or "start")
    self.currentDialogueNodeData = node
    self.currentLine = tostring((node and node.npcLine) or TrueQuests.Dialogue.getContactLine(contact, "greeting", "The signal clears."))
    self.dialogueOptions = type(node and node.options) == "table" and node.options or {}
    self.jobsRevealed = false
end

function TQ_QuestBoardWindow:setDialogueNode(nodeId)
    self:loadDialogueNode(nodeId)
    self:refreshData()
end

function TQ_QuestBoardWindow:showJobsFromDialogue()
    local contact = self:getSelectedContact()
    if not contact then
        return
    end

    if self:hasPendingFailureNotice() then
        self:setDialogueNode("failure_notice")
        return
    end

    self.jobsRevealed = true
    self.currentLine = TrueQuests.Dialogue.getContactLine(contact, "work", "Check the board. If anything is marked, it is yours to take.")
    self.dialogueOptions = {
        { text = "Back to conversation.", action = "back_dialogue" },
    }
    self:refreshData()
end

function TQ_QuestBoardWindow:updateDialogueOptions()
    local inDialogue = self.mode == "dialogue"
    local options = inDialogue and self.dialogueOptions or {}
    local optionRows = type(options) == "table" and options or {}
    local optionCount = #optionRows
    local signature = inDialogue and dialogueOptionsSignature(optionRows) or ""

    setVisible(self.optionList, inDialogue and optionCount > 0)
    if self.optionList and self.optionListSignature ~= signature then
        self.optionList:clear()
        if self.optionList.setScrollHeight then
            self.optionList:setScrollHeight(0)
        end
        for index, option in ipairs(optionRows) do
            self.optionList:addItem(tostring(option.text or "..."), {
                index = index,
                option = option,
            })
        end
        self.optionList.selected = optionCount > 0 and 1 or 0
        self.optionListSignature = signature
    end

    for index, button in ipairs(self.optionButtons or {}) do
        setVisible(button, false)
    end
end

function TQ_QuestBoardWindow.drawDialogueOptionItem(list, y, item, alt)
    local entry = item and item.item or {}
    local option = entry.option or {}
    local selected = list.selected == item.index
    local hovered = list.mouseoverselected == item.index and list:isMouseOver() and not list:isMouseOverScrollBar()
    local kind = dialogueOptionKind(option)
    local rowX = 3
    local rowY = y + 3
    local rowW = list.width - 10
    if list.vscroll and list.getScrollHeight and list:getScrollHeight() > list.height then
        rowW = rowW - 14
    end
    local rowH = list.itemheight - 6
    local fill = selected and "selected" or (hovered and "hover" or "button")
    local border = "border"
    local accent = "blue"
    local textColor = "text"

    if kind == "info" then
        accent = "blue"
    elseif kind == "muted" then
        fill = selected and "hover" or (hovered and "button" or "panelAlt")
        border = "borderSoft"
        accent = "borderSoft"
        textColor = "dim"
    end

    TQ_UITheme.drawPanel(list, rowX, rowY, rowW, rowH, fill, border)
    TQ_UITheme.drawAccent(list, rowX, rowY, 4, rowH, accent)

    local c = TQ_UITheme.Colors[textColor] or TQ_UITheme.Colors.text
    local label = TQ_UITheme.truncate(tostring(item.text or option.text or "..."), rowW - 24, UIFont.Small)
    list:drawText(label, rowX + 14, rowY + 8, c.r, c.g, c.b, c.a, UIFont.Small)

    return y + list.itemheight
end

function TQ_QuestBoardWindow:onDialogueOptionSelected(entry)
    if not entry or not entry.index then
        return
    end

    self:onDialogueOption(entry.index)
end

function TQ_QuestBoardWindow:onDialogueOption(index)
    local option = self.dialogueOptions and self.dialogueOptions[index] or nil
    if not option then
        return
    end

    if option.next then
        self:setDialogueNode(option.next)
        return
    end

    if option.action == "show_jobs" then
        self:showJobsFromDialogue()
        return
    end

    if option.action == "back_dialogue" then
        self:setDialogueNode(self.currentDialogueNode or "start")
        return
    end

    if option.action == "close" then
        self:close()
    end
end

function TQ_QuestBoardWindow:onAccept()
    local entry = self:getSelectedJobEntry()
    if not entry or entry.kind ~= "offer" then
        return
    end

    if self:hasPendingFailureNotice() then
        self:setDialogueNode("failure_notice")
        return
    end

    local quest, reason = TrueQuests.QuestManager.acceptQuest(self.player, entry.offer.templateId)
    if quest then
        self.currentLine = TrueQuests.Dialogue.getLine(quest, "accept", "Request accepted.")
        TrueQuests.say(self.player, self.currentLine)
    else
        TrueQuests.say(self.player, "Could not accept request: " .. tostring(reason))
    end

    self.jobsRevealed = true
    self:refreshData()
end

function TQ_QuestBoardWindow:onTurnIn()
    if self:isRadioBoard() then
        TrueQuests.say(self.player, "You need to meet them in person.")
        return
    end

    local entry = self:getSelectedJobEntry()
    if not entry or entry.kind ~= "active" then
        return
    end

    local quest = entry.quest
    if quest.status == "rewardPending" then
        TQ_RewardChoiceWindow.Open(self.player, quest)
        return
    end

    local turnedIn, reason = TrueQuests.QuestManager.turnInQuest(self.player, quest.id)
    if turnedIn then
        self.currentLine = TrueQuests.Dialogue.getLine(turnedIn, "complete", "Good work. Choose something from the cache.")
        TrueQuests.say(self.player, self.currentLine)
        TQ_RewardChoiceWindow.Open(self.player, turnedIn)
    else
        TrueQuests.say(self.player, reasonText(reason, quest))
    end

    self.jobsRevealed = true
    self:refreshData()
end

function TQ_QuestBoardWindow:openFaction(factionId)
    self.selectedFactionId = tostring(factionId)
    self.mode = "contacts"
    self.selectedContactId = nil
    self.jobsRevealed = false

    local discovered = TrueQuests.Factions and TrueQuests.Factions.isFactionDiscovered(self.player, factionId)
    if TrueQuests.Factions then
        TrueQuests.Factions.discoverFaction(self.player, factionId)
    end

    local contacts = getActiveContactsForFaction(self.player, factionId, true)
    local contact = nil
    if #contacts > 0 then
        contact = contacts[TrueQuests.randomInt(1, #contacts)]
    end

    if contact then
        local fallback = discovered and "The frequency is open." or "A new voice answers through the static."
        self.factionGreetingLine = TrueQuests.Dialogue.getContactLine(contact, "greeting", fallback)
        self.factionGreetingName = tostring(contact.name or contact.id)
    else
        self.factionGreetingLine = "Only static answers for a moment, then the signal steadies."
        self.factionGreetingName = factionName(factionId)
    end

    self:refreshData()
end

function TQ_QuestBoardWindow:openContact(contactId)
    local contact = TrueQuests.getContact(contactId)
    if not contact then
        return
    end

    self.mode = "dialogue"
    self.selectedContactId = tostring(contactId)
    self.selectedFactionId = contactFactionId(contact)
    self.jobsRevealed = false

    local nodeId = "start"
    if self:hasPendingFailureNotice() then
        nodeId = "failure_notice"
    end

    self:loadDialogueNode(nodeId)
    self:refreshData()
end

function TQ_QuestBoardWindow:drawChrome()
    TQ_UITheme.drawPanel(self, 0, 0, self.width, self.height, "windowBg", "border")
    self:drawRect(1, 1, self.width - 2, 23, 0.96, 0.095, 0.105, 0.125)
    self:drawRect(1, 24, self.width - 2, 1, 0.92, 0.30, 0.36, 0.42)
    self:drawText("TRUE QUESTS", 10, 6, 0.96, 0.91, 0.79, 1, UIFont.Small)
    self:drawRect(self.width - 18, self.height - 5, 13, 1, 0.80, 0.36, 0.41, 0.46)
    self:drawRect(self.width - 13, self.height - 10, 8, 1, 0.80, 0.36, 0.41, 0.46)
    self:drawRect(self.width - 8, self.height - 15, 3, 1, 0.80, 0.36, 0.41, 0.46)
end

function TQ_QuestBoardWindow:drawHeader()
    local title = "AVAILABLE SIGNALS"
    local subtitle = "Choose a frequency group"

    if self.mode == "contacts" and self.selectedFactionId then
        title = string.upper(factionName(self.selectedFactionId))
        subtitle = "Active voices on this frequency"
    elseif self.mode == "dialogue" then
        local contact = self:getSelectedContact()
        title = string.upper(tostring(contact and contact.name or "CONTACT"))
        subtitle = factionName(self.selectedFactionId)
    end

    TQ_UITheme.drawPanel(self, self.bodyX, self.bodyY, self.bodyW, self.headerH, "panelBg", "border")
    TQ_UITheme.drawAccent(self, self.bodyX, self.bodyY, 4, self.headerH, "amber")
    self:drawText(title, self.bodyX + 16, self.bodyY + 10, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    self:drawText(subtitle, self.bodyX + 16, self.bodyY + 39, 0.58, 0.63, 0.65, 1, UIFont.Small)

    local summary = tostring(self.activeContactCount or 0) .. " voices / "
        .. tostring(self.activeCount or 0) .. " active / "
        .. tostring(self.offerCount or 0) .. " available"
    TQ_UITheme.drawTextRight(self, summary, self.bodyX + self.bodyW - 16, self.bodyY + 28, "text", UIFont.Small)
end

function TQ_QuestBoardWindow:prerender()
    self:applyLayout()
    self:updateControls()
    self:drawChrome()
    self:drawHeader()
    TQ_UITheme.drawPanel(self, self.contentX, self.contentY, self.contentW, self.contentH, "listBg", "borderSoft")

    if self.mode == "factions" then
        self:drawFactionCards()
    elseif self.mode == "contacts" then
        self:drawContactCards()
    elseif self.mode == "dialogue" then
        self:drawDialogue()
    end
end

function TQ_QuestBoardWindow:drawImagePlaceholder(x, y, width, height, label)
    TQ_UITheme.drawPanel(self, x, y, width, height, "panelBg", "borderSoft")
    self:drawTextCentre(tostring(label or "?"), x + width / 2, y + height / 2 - 10, 0.68, 0.72, 0.74, 1, UIFont.Large)
end

function TQ_QuestBoardWindow:drawFactionCard(card, x, y, size)
    local discovered = TrueQuests.Factions and TrueQuests.Factions.isFactionDiscovered(self.player, card.factionId)
    local faction = card.faction or {}
    local imagePath = discovered and (faction.fullImage or faction.icon) or (faction.unknownImage or UNKNOWN_FACTION_IMAGE)
    local texture = getTextureSafe(imagePath)
    local accent = discovered and factionAccent(card.factionId) or "border"

    TQ_UITheme.drawPanel(self, x, y, size, size, "panelBg", accent)
    TQ_UITheme.drawAccent(self, x, y, 5, size, discovered and factionAccent(card.factionId) or "borderSoft")

    local imagePad = 12
    local imageH = size - 72
    if not drawTextureFit(self, texture, x + imagePad, y + imagePad, size - imagePad * 2, imageH, discovered and 1 or 0.72) then
        self:drawImagePlaceholder(x + imagePad, y + imagePad, size - imagePad * 2, imageH, discovered and string.sub(card.name, 1, 1) or "?")
    end

    if discovered then
        self:drawTextCentre(TQ_UITheme.truncate(card.name, size - 18, UIFont.Medium), x + size / 2, y + size - 50, 0.96, 0.91, 0.79, 1, UIFont.Medium)
        local meta = tostring(card.activeContacts or 0) .. " voices / " .. tostring((card.activeQuests or 0) + (card.offers or 0)) .. " jobs"
        self:drawTextCentre(meta, x + size / 2, y + size - 25, 0.58, 0.63, 0.65, 1, UIFont.Small)
    else
        self:drawTextCentre("UNKNOWN SIGNAL", x + size / 2, y + size - 43, 0.70, 0.75, 0.76, 1, UIFont.Small)
    end

    table.insert(self.cardHitboxes, {
        kind = "faction",
        factionId = card.factionId,
        x = x,
        y = y,
        width = size,
        height = size,
    })
end

function TQ_QuestBoardWindow:drawFactionCards()
    self.cardHitboxes = {}
    local count = tableCount(self.factionCards)
    if count == 0 then
        self:drawText("No active signals on this frequency.", self.contentX + 18, self.contentY + 18, 0.70, 0.75, 0.76, 1, UIFont.Small)
        return
    end

    local gap = 18
    local maxColumns = math.max(1, math.floor((self.contentW + gap) / (180 + gap)))
    local columns = math.min(count, maxColumns)
    local cardSize = clamp(math.floor((self.contentW - gap * (columns - 1) - 36) / columns), 160, 256)
    columns = math.max(1, math.floor((self.contentW + gap) / (cardSize + gap)))

    local totalW = math.min(count, columns) * cardSize + math.max(0, math.min(count, columns) - 1) * gap
    local startX = self.contentX + (self.contentW - totalW) / 2
    local startY = self.contentY + 26

    for index, card in ipairs(self.factionCards or {}) do
        local col = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        self:drawFactionCard(card, startX + col * (cardSize + gap), startY + row * (cardSize + gap), cardSize)
    end
end

function TQ_QuestBoardWindow:drawContactCard(contact, x, y, width, height)
    local texture = getTextureSafe(contact.portrait or contact.icon)
    TQ_UITheme.drawPanel(self, x, y, width, height, "panelBg", "borderSoft")
    TQ_UITheme.drawAccent(self, x, y, 5, height, factionAccent(self.selectedFactionId))

    local imageSize = math.min(width - 24, height - 80)
    local imageX = x + (width - imageSize) / 2
    local imageY = y + 14
    if not drawTextureFit(self, texture, imageX, imageY, imageSize, imageSize, 1) then
        self:drawImagePlaceholder(imageX, imageY, imageSize, imageSize, string.sub(tostring(contact.name or "?"), 1, 1))
    end

    self:drawTextCentre(TQ_UITheme.truncate(tostring(contact.name or contact.id), width - 18, UIFont.Medium), x + width / 2, y + height - 54, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    self:drawTextCentre(tostring(contact.role or "contact"), x + width / 2, y + height - 27, 0.58, 0.63, 0.65, 1, UIFont.Small)

    table.insert(self.cardHitboxes, {
        kind = "contact",
        contactId = contact.id,
        x = x,
        y = y,
        width = width,
        height = height,
    })
end

function TQ_QuestBoardWindow:drawContactCards()
    self.cardHitboxes = {}
    local contacts = self.contactCards or {}
    local x = self.contentX + 18
    local y = self.contentY + 18

    if self.factionGreetingLine and self.factionGreetingLine ~= "" then
        TQ_UITheme.drawPanel(self, x, y, self.contentW - 36, 64, "panelBg", "borderSoft")
        TQ_UITheme.drawAccent(self, x, y, 4, 64, factionAccent(self.selectedFactionId))
        self:drawText(tostring(self.factionGreetingName or factionName(self.selectedFactionId)), x + 14, y + 9, 0.96, 0.91, 0.79, 1, UIFont.Small)
        TQ_UITheme.drawWrapped(self, self.factionGreetingLine, x + 14, y + 30, self.contentW - 64, 2, "text", UIFont.Small)
        y = y + 82
    end

    if #contacts == 0 then
        self:drawText("No one is answering from this faction right now.", x, y, 0.70, 0.75, 0.76, 1, UIFont.Small)
        return
    end

    local gap = 16
    local cardW = clamp(math.floor((self.contentW - 36 - gap * 2) / 3), 150, 210)
    local cardH = cardW + 70
    local columns = math.max(1, math.floor((self.contentW - 36 + gap) / (cardW + gap)))

    for index, contact in ipairs(contacts) do
        local col = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        self:drawContactCard(contact, x + col * (cardW + gap), y + row * (cardH + gap), cardW, cardH)
    end
end

function TQ_QuestBoardWindow:drawDialogue()
    local contact = self:getSelectedContact()
    if not contact then
        return
    end

    local leftX = self.contentX + 14
    local leftY = self.contentY + 14
    local leftW = self.dialoguePortraitW - 28
    local leftH = self.contentH - 28
    TQ_UITheme.drawPanel(self, leftX, leftY, leftW, leftH, "panelBg", "borderSoft")
    TQ_UITheme.drawAccent(self, leftX, leftY, 5, leftH, factionAccent(self.selectedFactionId))

    local portraitSize = math.min(leftW - 28, 210)
    local portraitX = leftX + (leftW - portraitSize) / 2
    local portraitY = leftY + 16
    local texture = getTextureSafe(contact.portrait or contact.icon)
    if not drawTextureFit(self, texture, portraitX, portraitY, portraitSize, portraitSize, 1) then
        self:drawImagePlaceholder(portraitX, portraitY, portraitSize, portraitSize, string.sub(tostring(contact.name or "?"), 1, 1))
    end

    self:drawTextCentre(TQ_UITheme.truncate(tostring(contact.name or contact.id), leftW - 18, UIFont.Medium), leftX + leftW / 2, portraitY + portraitSize + 16, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    self:drawTextCentre(tostring(contact.role or "contact"), leftX + leftW / 2, portraitY + portraitSize + 43, 0.58, 0.63, 0.65, 1, UIFont.Small)
    self:drawTextCentre(reputationText(self.player, self.selectedFactionId), leftX + leftW / 2, portraitY + portraitSize + 67, 0.78, 0.82, 0.80, 1, UIFont.Small)

    TQ_UITheme.drawPanel(self, self.dialogueX, self.dialogueY, self.dialogueW, self.dialogueH, "panelBg", "borderSoft")
    TQ_UITheme.drawPanel(self, self.dialogueX + 12, self.dialogueY + 14, self.dialogueW - 24, 104, "listBg", "borderSoft")
    TQ_UITheme.drawWrapped(self, self.currentLine or "", self.dialogueX + 28, self.dialogueY + 30, self.dialogueW - 56, 4, "text", UIFont.Small)

    self:drawText(self.jobsRevealed and "Conversation" or "Choose a response", self.optionsX, self.optionsY - 20, 0.78, 0.82, 0.80, 1, UIFont.Small)
    if self.optionList and self.optionList.visible then
        TQ_UITheme.drawPanel(self, self.optionsListX, self.optionsListY, self.optionsListW, self.optionsListH, "listBg", "borderSoft")
    end

    if self.jobsRevealed then
        local refreshText = offerRefreshText(self.player)
        local label = "Available work"
        if refreshText ~= "" then
            label = label .. " (" .. refreshText .. ")"
        end
        self:drawText(label, self.jobsX, self.jobsY - 20, 0.78, 0.82, 0.80, 1, UIFont.Small)
        if not self.questList.items or #self.questList.items == 0 then
            self:drawText("No requests from this contact right now.", self.jobsX, self.jobsY + 8, 0.54, 0.58, 0.60, 1, UIFont.Small)
        end
    end
end

function TQ_QuestBoardWindow:render()
    ISPanel.render(self)
end

function TQ_QuestBoardWindow:isRadioStillAccessible()
    if not self.device then
        return true
    end

    local radioContext = TrueQuests and TrueQuests.RadioContext
    if radioContext and radioContext.isDeviceAccessible then
        return radioContext.isDeviceAccessible(self.player, self.device)
    end

    return true
end

function TQ_QuestBoardWindow:update()
    ISPanel.update(self)

    self.radioCheckTicks = (self.radioCheckTicks or 0) + 1
    if self.radioCheckTicks >= 30 then
        self.radioCheckTicks = 0
        if not self:isRadioStillAccessible() then
            TrueQuests.say(self.player, "The radio signal falls out of range.")
            self:close()
        end
    end

    if self.mode == "dialogue" and self.jobsRevealed == true and self.selectedContactId then
        self.offerRefreshCheckTicks = (self.offerRefreshCheckTicks or 0) + 1
        if self.offerRefreshCheckTicks >= 60 then
            self.offerRefreshCheckTicks = 0
            if offerRefreshDue(self.player) then
                self:refreshData()
            end
        end
    else
        self.offerRefreshCheckTicks = 0
    end
end

function TQ_QuestBoardWindow:isInResizeHandle(x, y)
    return self.resizable == true and x >= self.width - 18 and y >= self.height - 18
end

function TQ_QuestBoardWindow:resizeBy(dx, dy)
    local newWidth = math.max(self.minimumWidth or 820, self.width + dx)
    local newHeight = math.max(self.minimumHeight or 560, self.height + dy)

    if self.setWidth then self:setWidth(newWidth) else self.width = newWidth end
    if self.setHeight then self:setHeight(newHeight) else self.height = newHeight end
    self.width = newWidth
    self.height = newHeight
    self:applyLayout()
end

function TQ_QuestBoardWindow:handleCardClick(x, y)
    for _, hitbox in ipairs(self.cardHitboxes or {}) do
        if x >= hitbox.x and y >= hitbox.y and x <= hitbox.x + hitbox.width and y <= hitbox.y + hitbox.height then
            if hitbox.kind == "faction" then
                self:openFaction(hitbox.factionId)
                return true
            elseif hitbox.kind == "contact" then
                self:openContact(hitbox.contactId)
                return true
            end
        end
    end
    return false
end

function TQ_QuestBoardWindow:onMouseDown(x, y)
    if self:isInResizeHandle(x, y) then
        self.isResizing = true
        return true
    end

    if self:handleCardClick(x, y) then
        return true
    end

    if ISPanel.onMouseDown then
        return ISPanel.onMouseDown(self, x, y)
    end
    return false
end

function TQ_QuestBoardWindow:onMouseMove(dx, dy)
    if self.isResizing then
        self:resizeBy(dx, dy)
        return
    end

    if ISPanel.onMouseMove then
        ISPanel.onMouseMove(self, dx, dy)
    end
end

function TQ_QuestBoardWindow:onMouseMoveOutside(dx, dy)
    if self.isResizing then
        self:resizeBy(dx, dy)
        return
    end

    if ISPanel.onMouseMoveOutside then
        ISPanel.onMouseMoveOutside(self, dx, dy)
    end
end

function TQ_QuestBoardWindow:onMouseUp(x, y)
    self.isResizing = false
    if ISPanel.onMouseUp then
        return ISPanel.onMouseUp(self, x, y)
    end
    return true
end

function TQ_QuestBoardWindow:onMouseUpOutside(x, y)
    self.isResizing = false
    if ISPanel.onMouseUpOutside then
        return ISPanel.onMouseUpOutside(self, x, y)
    end
    return true
end

function TQ_QuestBoardWindow:close()
    self:removeFromUIManager()
    if TQ_QuestBoardWindow.instance == self then
        TQ_QuestBoardWindow.instance = nil
    end
end

function TQ_QuestBoardWindow:new(x, y, width, height, player, device)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.device = device
    o.resizable = true
    o.minimumWidth = 820
    o.minimumHeight = 560
    o.moveWithMouse = true
    o.mode = "factions"
    o.selectedFactionId = nil
    o.selectedContactId = nil
    o.jobsRevealed = false
    o.radioCheckTicks = 0
    TQ_UITheme.applyWindow(o)
    return o
end

function TQ_QuestBoardWindow.Open(player, device)
    if not player then
        player = getSpecificPlayer and getSpecificPlayer(0) or getPlayer()
    end

    if not player then
        return nil
    end

    if TQ_QuestBoardWindow.instance then
        TQ_QuestBoardWindow.instance:close()
    end

    local width = 960
    local height = 640
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    local window = TQ_QuestBoardWindow:new(x, y, width, height, player, device)
    window:initialise()
    window:addToUIManager()
    TQ_QuestBoardWindow.instance = window
    return window
end

function TQ_QuestBoardWindow.Toggle(player, device)
    if TQ_QuestBoardWindow.instance then
        TQ_QuestBoardWindow.instance:close()
        return nil
    end
    return TQ_QuestBoardWindow.Open(player, device)
end
