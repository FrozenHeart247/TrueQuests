require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_UITheme"
require "TrueQuests/UI/TQ_DialogueWindow"
require "TrueQuests/UI/TQ_RewardChoiceWindow"

TQ_QuestBoardWindow = ISPanel:derive("TQ_QuestBoardWindow")
TQ_QuestBoardWindow.instance = nil

local function statusLabel(status)
    if status == "readyToTurnIn" then
        return "Ready"
    end
    if status == "rewardPending" then
        return "Reward"
    end
    if status == "accepted" then
        return "Active"
    end
    return tostring(status or "")
end

local function statusColor(status)
    if status == "readyToTurnIn" then
        return "green"
    end
    if status == "rewardPending" then
        return "amber"
    end
    return "blue"
end

local function difficultyColor(difficulty)
    difficulty = string.lower(tostring(difficulty or ""))
    if difficulty == "hard" or difficulty == "deadly" then
        return "red"
    end
    if difficulty == "medium" or difficulty == "normal" then
        return "amber"
    end
    if difficulty == "easy" then
        return "green"
    end
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
    return "Cannot turn this in yet."
end

local function contactName(contactId)
    local contact = TrueQuests.getContact and TrueQuests.getContact(contactId)
    return tostring((contact and contact.name) or contactId or "Unknown")
end

local function factionName(factionId)
    local faction = TrueQuests.getFaction and TrueQuests.getFaction(factionId)
    return tostring((faction and faction.name) or factionId or "Unaffiliated")
end

local function reputationText(player, factionId)
    if not TrueQuests.Factions or not TrueQuests.Factions.getReputation then
        return "Rep: 0"
    end

    return "Rep: " .. tostring(TrueQuests.Factions.getReputation(player, factionId or "independent"))
end

local function entryKey(entry)
    if not entry then
        return nil
    end

    if entry.kind == "active" and entry.quest then
        return "active:" .. tostring(entry.quest.id)
    end

    if entry.kind == "offer" and entry.offer then
        return "offer:" .. tostring(entry.offer.templateId)
    end

    return nil
end

local function makeButton(parent, x, y, width, height, title, callback, kind)
    local button = ISButton:new(x, y, width, height, title, parent, callback)
    button:initialise()
    TQ_UITheme.styleButton(button, kind)
    parent:addChild(button)
    return button
end

function TQ_QuestBoardWindow:initialise()
    ISPanel.initialise(self)
end

function TQ_QuestBoardWindow:createChildren()
    ISPanel.createChildren(self)

    self.contentX = 12
    self.contentY = 34
    self.headerH = 56
    self.listX = 12
    self.listY = 100
    self.listW = 278
    self.panelBottom = self.height - 54
    self.listH = self.panelBottom - self.listY
    self.detailX = self.listX + self.listW + 12
    self.detailY = self.listY
    self.detailW = self.width - self.detailX - 12
    self.detailH = self.listH

    self.filterAllButton = makeButton(self, self.listX + 8, self.listY + 8, 74, 22, "All", TQ_QuestBoardWindow.onFilterAll, "info")
    self.filterActiveButton = makeButton(self, self.listX + 88, self.listY + 8, 82, 22, "Active", TQ_QuestBoardWindow.onFilterActive, "muted")
    self.filterOfferButton = makeButton(self, self.listX + 176, self.listY + 8, 94, 22, "Available", TQ_QuestBoardWindow.onFilterOffers, "muted")

    self.questList = ISScrollingListBox:new(self.listX + 7, self.listY + 38, self.listW - 14, self.listH - 45)
    self.questList:initialise()
    self.questList:instantiate()
    self.questList.itemheight = 54
    self.questList.doDrawItem = TQ_QuestBoardWindow.drawListItem
    self.questList.drawBorder = false
    self:addChild(self.questList)

    local buttonY = self.height - 40
    self.acceptButton = makeButton(self, 12, buttonY, 92, 26, "Accept", TQ_QuestBoardWindow.onAccept, "primary")
    self.turnInButton = makeButton(self, 112, buttonY, 102, 26, "Turn In", TQ_QuestBoardWindow.onTurnIn, "warning")
    self.refreshButton = makeButton(self, 222, buttonY, 92, 26, "Refresh", TQ_QuestBoardWindow.refreshData, "default")
    self.talkButton = makeButton(self, 322, buttonY, 82, 26, "Talk", TQ_QuestBoardWindow.onTalk, "info")
    self.closeButton = makeButton(self, self.width - 104, buttonY, 92, 26, "Close", TQ_QuestBoardWindow.close, "muted")
    self.topCloseButton = makeButton(self, self.width - 27, 3, 21, 18, "X", TQ_QuestBoardWindow.close, "danger")

    self:refreshData()
end

function TQ_QuestBoardWindow:onFilterAll()
    self.filter = "all"
    self:refreshData()
end

function TQ_QuestBoardWindow:onFilterActive()
    self.filter = "active"
    self:refreshData()
end

function TQ_QuestBoardWindow:onFilterOffers()
    self.filter = "offer"
    self:refreshData()
end

function TQ_QuestBoardWindow:updateFilterButtons()
    TQ_UITheme.styleButton(self.filterAllButton, self.filter == "all" and "info" or "muted")
    TQ_UITheme.styleButton(self.filterActiveButton, self.filter == "active" and "info" or "muted")
    TQ_UITheme.styleButton(self.filterOfferButton, self.filter == "offer" and "info" or "muted")
end

function TQ_QuestBoardWindow.drawListItem(list, y, item, alt)
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
    local badgeW = math.max(48, TQ_UITheme.measure(UIFont.Small, badge) + 14)
    local titleW = rowW - badgeW - 24
    local title = TQ_UITheme.truncate(item.text, titleW, UIFont.Small)
    local meta = TQ_UITheme.truncate((entry and entry.meta) or "", rowW - 24, UIFont.Small)

    list:drawText(title, rowX + 12, rowY + 8, 0.92, 0.91, 0.86, 1, UIFont.Small)
    list:drawText(meta, rowX + 12, rowY + 29, 0.58, 0.63, 0.65, 1, UIFont.Small)

    if badge ~= "" then
        TQ_UITheme.drawPill(list, rowX + rowW - badgeW - 7, rowY + 7, badgeW, 20, badge, accent)
    end

    return y + list.itemheight
end

function TQ_QuestBoardWindow:getSelectedEntry()
    if not self.questList or not self.questList.items then
        return nil
    end

    local row = self.questList.items[self.questList.selected]
    return row and row.item or nil
end

function TQ_QuestBoardWindow:getSelectedContact()
    local entry = self:getSelectedEntry()
    if not entry then
        return nil
    end

    local contactId = entry.contactId
    if not contactId and entry.quest then
        contactId = entry.quest.contactId
    elseif not contactId and entry.offer then
        contactId = entry.offer.contactId
    end

    return contactId and TrueQuests.getContact(contactId) or nil
end

function TQ_QuestBoardWindow:addEntry(title, entry)
    table.insert(self.entries, entry)
    self.questList:addItem(title, entry)
end

function TQ_QuestBoardWindow:refreshData()
    local selectedKey = entryKey(self:getSelectedEntry())
    TrueQuests.QuestManager.updateAll(self.player)

    self.questList:clear()
    self.entries = {}
    self.activeCount = 0
    self.offerCount = 0
    self.activeContactCount = #(TrueQuests.Factions and TrueQuests.Factions.getActiveContacts(self.player) or {})

    local active = TrueQuests.QuestManager.getActiveQuests(self.player)
    for _, quest in ipairs(active or {}) do
        self.activeCount = self.activeCount + 1
        if self.filter == "all" or self.filter == "active" then
            local factionId = quest.factionId or "independent"
            self:addEntry(tostring(quest.title), {
                kind = "active",
                quest = quest,
                contactId = quest.contactId,
                factionId = factionId,
                badge = statusLabel(quest.status),
                accent = statusColor(quest.status),
                meta = factionName(factionId) .. " / " .. contactName(quest.contactId),
            })
        end
    end

    local offers = TrueQuests.QuestManager.getOffers(self.player, nil, 4)
    for _, offer in ipairs(offers or {}) do
        self.offerCount = self.offerCount + 1
        if self.filter == "all" or self.filter == "offer" then
            local factionId = offer.factionId or "independent"
            self:addEntry(tostring(offer.title), {
                kind = "offer",
                offer = offer,
                contactId = offer.contactId,
                factionId = factionId,
                badge = tostring(offer.difficulty),
                accent = difficultyColor(offer.difficulty),
                meta = factionName(factionId) .. " / " .. contactName(offer.contactId),
            })
        end
    end

    local fallbackSelected = 1
    for index, row in ipairs(self.questList.items or {}) do
        if entryKey(row.item) == selectedKey then
            fallbackSelected = index
            break
        end
    end

    local itemCount = self.questList.items and #self.questList.items or 0
    if itemCount > 0 then
        self.questList.selected = fallbackSelected
    end

    self:updateFilterButtons()
    self:updateButtons()
end

function TQ_QuestBoardWindow:updateButtons()
    local entry = self:getSelectedEntry()
    local canAccept = entry and entry.kind == "offer"
    local canTurnIn = entry and entry.kind == "active"
    local canTalk = self:getSelectedContact() ~= nil

    self.acceptButton:setEnable(canAccept == true)
    self.turnInButton:setEnable(canTurnIn == true)
    self.talkButton:setEnable(canTalk == true)

    if entry and entry.kind == "active" and entry.quest and entry.quest.status == "rewardPending" then
        if self.turnInButton.setTitle then
            self.turnInButton:setTitle("Rewards")
        else
            self.turnInButton.title = "Rewards"
        end
    else
        if self.turnInButton.setTitle then
            self.turnInButton:setTitle("Turn In")
        else
            self.turnInButton.title = "Turn In"
        end
    end
end

function TQ_QuestBoardWindow:onTalk()
    local contact = self:getSelectedContact()
    if contact then
        TQ_DialogueWindow.Open(self.player, contact)
    end
end

function TQ_QuestBoardWindow:onAccept()
    local entry = self:getSelectedEntry()
    if not entry or entry.kind ~= "offer" then
        return
    end

    local quest, reason = TrueQuests.QuestManager.acceptQuest(self.player, entry.offer.templateId)
    if quest then
        local line = TrueQuests.Dialogue.getLine(quest, "accept", "Request accepted.")
        TrueQuests.say(self.player, line)
    else
        TrueQuests.say(self.player, "Could not accept request: " .. tostring(reason))
    end

    self:refreshData()
end

function TQ_QuestBoardWindow:onTurnIn()
    local entry = self:getSelectedEntry()
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
        local line = TrueQuests.Dialogue.getLine(turnedIn, "complete", "Good work. Choose something from the cache.")
        TrueQuests.say(self.player, line)
        TQ_RewardChoiceWindow.Open(self.player, turnedIn)
    else
        TrueQuests.say(self.player, reasonText(reason, quest))
    end

    self:refreshData()
end

function TQ_QuestBoardWindow:drawHeader()
    local x = self.contentX
    local y = self.contentY
    local width = self.width - self.contentX * 2

    TQ_UITheme.drawPanel(self, x, y, width, self.headerH, "panelBg", "border")
    TQ_UITheme.drawAccent(self, x, y, 4, self.headerH, "amber")
    self:drawText("SURVIVOR REQUESTS", x + 14, y + 9, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    self:drawText("Radio relay board", x + 14, y + 33, 0.58, 0.63, 0.65, 1, UIFont.Small)

    local summary = tostring(self.activeContactCount or 0) .. " contacts  /  "
        .. tostring(self.activeCount or 0) .. " active  /  "
        .. tostring(self.offerCount or 0) .. " available"
    TQ_UITheme.drawTextRight(self, summary, x + width - 14, y + 18, "text", UIFont.Small)
end

function TQ_QuestBoardWindow:drawChrome()
    TQ_UITheme.drawPanel(self, 0, 0, self.width, self.height, "windowBg", "border")
    self:drawRect(1, 1, self.width - 2, 23, 0.96, 0.095, 0.105, 0.125)
    self:drawRect(1, 24, self.width - 2, 1, 0.92, 0.30, 0.36, 0.42)
    self:drawText("TRUE QUESTS", 10, 6, 0.96, 0.91, 0.79, 1, UIFont.Small)
end

function TQ_QuestBoardWindow:prerender()
    self:drawChrome()
    self:drawHeader()
    TQ_UITheme.drawPanel(self, self.listX, self.listY, self.listW, self.listH, "listBg", "borderSoft")
    TQ_UITheme.drawPanel(self, self.detailX, self.detailY, self.detailW, self.detailH, "panelBg", "borderSoft")
end

function TQ_QuestBoardWindow:drawOfferDetails(entry, x, y, width)
    local offer = entry.offer
    local title = TQ_UITheme.truncate(offer.title, width - 8, UIFont.Medium)
    local factionId = offer.factionId or entry.factionId or "independent"

    self:drawText(title, x, y, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    y = y + 30
    TQ_UITheme.drawPill(self, x, y, 78, 21, tostring(offer.difficulty), difficultyColor(offer.difficulty))
    self:drawText("Contact: " .. contactName(offer.contactId), x + 92, y + 4, 0.70, 0.75, 0.76, 1, UIFont.Small)
    y = y + 27
    self:drawText("Faction: " .. factionName(factionId), x, y, 0.70, 0.75, 0.76, 1, UIFont.Small)
    TQ_UITheme.drawTextRight(self, reputationText(self.player, factionId), x + width, y, "text", UIFont.Small)
    y = y + 30

    self:drawText("Request", x, y, 0.78, 0.82, 0.80, 1, UIFont.Small)
    y = y + 20
    y = TQ_UITheme.drawWrapped(self, offer.description, x, y, width, 7, "text", UIFont.Small)

    local template = offer.template or {}
    if template.objectives and #template.objectives > 0 then
        y = y + 18
        self:drawText("Expected work", x, y, 0.78, 0.82, 0.80, 1, UIFont.Small)
        y = y + 20
        for _, objective in ipairs(template.objectives or {}) do
            local label = tostring(objective.label or objective.item or objective.type or "Objective")
            self:drawText("- " .. label, x, y, 0.88, 0.89, 0.87, 1, UIFont.Small)
            y = y + 18
        end
    end
end

function TQ_QuestBoardWindow:drawQuestDetails(entry, x, y, width)
    local quest = entry.quest
    local title = TQ_UITheme.truncate(quest.title, width - 8, UIFont.Medium)
    local factionId = quest.factionId or entry.factionId or "independent"

    self:drawText(title, x, y, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    y = y + 30
    TQ_UITheme.drawPill(self, x, y, 84, 21, statusLabel(quest.status), statusColor(quest.status))
    self:drawText("Contact: " .. contactName(quest.contactId), x + 98, y + 4, 0.70, 0.75, 0.76, 1, UIFont.Small)
    y = y + 27
    self:drawText("Faction: " .. factionName(factionId), x, y, 0.70, 0.75, 0.76, 1, UIFont.Small)
    TQ_UITheme.drawTextRight(self, reputationText(self.player, factionId), x + width, y, "text", UIFont.Small)
    y = y + 28

    self:drawText("Turn in: " .. TrueQuests.turnInToText(quest.turnIn), x, y, 0.70, 0.75, 0.76, 1, UIFont.Small)
    y = y + 28

    self:drawText("Objectives", x, y, 0.78, 0.82, 0.80, 1, UIFont.Small)
    y = y + 20
    for _, objective in ipairs(quest.objectives or {}) do
        local mark = objective.completed and "[x]" or "[ ]"
        local line = mark .. " " .. TrueQuests.Objectives.describe(objective)
        self:drawText(TQ_UITheme.truncate(line, width, UIFont.Small), x, y, 0.88, 0.89, 0.87, 1, UIFont.Small)
        y = y + 18
    end

    if quest.status == "rewardPending" then
        y = y + 10
        self:drawText("Reward cache is ready.", x, y, 0.91, 0.74, 0.40, 1, UIFont.Small)
        y = y + 20
    end

    y = y + 12
    self:drawText("Notes", x, y, 0.78, 0.82, 0.80, 1, UIFont.Small)
    y = y + 20
    TQ_UITheme.drawWrapped(self, quest.description, x, y, width, 6, "dim", UIFont.Small)
end

function TQ_QuestBoardWindow:render()
    ISPanel.render(self)

    local x = self.detailX + 14
    local y = self.detailY + 14
    local width = self.detailW - 28
    local entry = self:getSelectedEntry()

    if not entry then
        self:drawText("No requests on this frequency.", x, y, 0.70, 0.75, 0.76, 1, UIFont.Small)
        self:drawText("Refresh the board or check back after accepting work.", x, y + 21, 0.54, 0.58, 0.60, 1, UIFont.Small)
        return
    end

    if entry.kind == "offer" then
        self:drawOfferDetails(entry, x, y, width)
    elseif entry.kind == "active" then
        self:drawQuestDetails(entry, x, y, width)
    end
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
    self:updateButtons()

    self.radioCheckTicks = (self.radioCheckTicks or 0) + 1
    if self.radioCheckTicks >= 30 then
        self.radioCheckTicks = 0
        if not self:isRadioStillAccessible() then
            TrueQuests.say(self.player, "The radio signal falls out of range.")
            self:close()
        end
    end
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
    o.resizable = false
    o.moveWithMouse = true
    o.filter = "all"
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

    local width = 690
    local height = 450
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
