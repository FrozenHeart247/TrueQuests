require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_UITheme"
require "TrueQuests/UI/TQ_QuestMarker"

TQ_QuestJournalWindow = ISPanel:derive("TQ_QuestJournalWindow")
TQ_QuestJournalWindow.instance = nil

local TABS = {
    { id = "main", label = "Main Quest", empty = "No main quests tracked yet." },
    { id = "side", label = "Side Quest", empty = "No side quests tracked yet." },
    { id = "faction", label = "Faction Quests", empty = "No faction quests accepted." },
}

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

local function setVisible(element, visible)
    if not element then
        return
    end

    if element.setVisible then
        element:setVisible(visible)
    else
        element.visible = visible
    end
end

local function makeButton(parent, x, y, width, height, title, callback, kind)
    local button = ISButton:new(x, y, width, height, title, parent, callback)
    button:initialise()
    TQ_UITheme.styleButton(button, kind)
    parent:addChild(button)
    return button
end

local function setButtonTitle(button, title)
    if not button then
        return
    end
    if button.setTitle then
        button:setTitle(tostring(title or ""))
    else
        button.title = tostring(title or "")
    end
end

local function statusLabel(status)
    if status == "readyToTurnIn" then return "Ready" end
    if status == "rewardPending" then return "Reward" end
    if status == "accepted" then return "Active" end
    return tostring(status or "Active")
end

local function statusColor(status)
    if status == "readyToTurnIn" then return "green" end
    if status == "rewardPending" then return "amber" end
    return "blue"
end

local function questMeta(quest)
    local faction = tostring(quest and quest.factionName or quest and quest.factionId or "Unknown faction")
    local contact = tostring(quest and quest.contactName or quest and quest.contactId or "Unknown contact")
    return faction .. " / " .. contact
end

local function objectiveText(quest)
    local parts = {}
    for _, objective in ipairs(quest and quest.objectives or {}) do
        local text = TrueQuests.Objectives and TrueQuests.Objectives.describe and TrueQuests.Objectives.describe(objective) or tostring(objective.label or objective.type or "Objective")
        table.insert(parts, text)
        if #parts >= 2 then
            break
        end
    end

    if #parts == 0 then
        return tostring(quest and quest.description or "Quest in progress.")
    end

    return table.concat(parts, "; ")
end

local function turnInText(quest)
    if TrueQuests.turnInToText then
        return TrueQuests.turnInToText(quest and quest.turnIn)
    end
    return "Unknown location"
end

local function timerText(quest)
    if TrueQuests.QuestManager and TrueQuests.QuestManager.formatTimeRemaining then
        return TrueQuests.QuestManager.formatTimeRemaining(quest)
    end
    return "No deadline"
end

function TQ_QuestJournalWindow:getSelectedQuest()
    if not self.questList or not self.questList.items then
        return nil
    end

    local row = self.questList.items[self.questList.selected]
    return row and row.item and row.item.quest or nil
end

function TQ_QuestJournalWindow:initialise()
    ISPanel.initialise(self)
end

function TQ_QuestJournalWindow:createChildren()
    ISPanel.createChildren(self)
    self:applyLayout()

    self.tabButtons = {}
    for _, tab in ipairs(TABS) do
        local tabId = tab.id
        local button = ISButton:new(0, 0, 1, 1, tab.label, self, function(target)
            target:setTab(tabId)
        end)
        button:initialise()
        self:addChild(button)
        table.insert(self.tabButtons, { tab = tab, button = button })
    end

    self.questList = ISScrollingListBox:new(self.listX, self.listY, self.listW, self.listH)
    self.questList:initialise()
    self.questList:instantiate()
    self.questList.itemheight = 78
    self.questList.doDrawItem = TQ_QuestJournalWindow.drawQuestItem
    self.questList.drawBorder = false
    self.questList.parentWindow = self
    self:addChild(self.questList)

    self.refreshButton = makeButton(self, 16, self.height - 38, 92, 24, "Refresh", TQ_QuestJournalWindow.refreshData, "default")
    self.markerButton = makeButton(self, 116, self.height - 38, 104, 24, "Marker On", TQ_QuestJournalWindow.onToggleMarker, "info")
    self.closeButton = makeButton(self, self.width - 104, self.height - 38, 88, 24, "Close", TQ_QuestJournalWindow.close, "muted")
    self.topCloseButton = makeButton(self, self.width - 27, 3, 21, 18, "X", TQ_QuestJournalWindow.close, "danger")

    self:applyLayout()
    self:refreshData()
end

function TQ_QuestJournalWindow:applyLayout()
    self.minimumWidth = self.minimumWidth or 660
    self.minimumHeight = self.minimumHeight or 460
    self.width = math.max(self.minimumWidth, self.width)
    self.height = math.max(self.minimumHeight, self.height)

    self.bodyX = 16
    self.bodyY = 36
    self.bodyW = self.width - 32
    self.bodyH = self.height - 84
    self.tabY = self.bodyY + 54
    self.tabH = 28
    self.listX = self.bodyX
    self.listY = self.tabY + self.tabH + 10
    if self.activeTab == "faction" then
        self.detailW = math.max(260, math.floor(self.bodyW * 0.42))
        self.listW = math.max(260, self.bodyW - self.detailW - 12)
        self.detailX = self.listX + self.listW + 12
    else
        self.detailW = 0
        self.listW = self.bodyW
        self.detailX = self.bodyX + self.bodyW
    end
    self.listH = self.height - self.listY - 54

    local tabW = math.floor((self.bodyW - 12) / 3)
    for index, entry in ipairs(self.tabButtons or {}) do
        setChildBounds(entry.button, self.bodyX + (index - 1) * (tabW + 6), self.tabY, tabW, self.tabH)
        TQ_UITheme.styleButton(entry.button, entry.tab.id == self.activeTab and "primary" or "muted")
    end

    setChildBounds(self.questList, self.listX, self.listY, self.listW, self.listH)
    setChildBounds(self.refreshButton, 16, self.height - 38, 92, 24)
    setChildBounds(self.markerButton, 116, self.height - 38, 104, 24)
    setChildBounds(self.closeButton, self.width - 104, self.height - 38, 88, 24)
    setChildBounds(self.topCloseButton, self.width - 27, 3, 21, 18)
end

function TQ_QuestJournalWindow:setTab(tabId)
    self.activeTab = tostring(tabId or "faction")
    self:refreshData()
end

function TQ_QuestJournalWindow:getActiveTab()
    for _, tab in ipairs(TABS) do
        if tab.id == self.activeTab then
            return tab
        end
    end
    return TABS[3]
end

function TQ_QuestJournalWindow:refreshData()
    if TrueQuests.QuestManager and TrueQuests.QuestManager.updateAll then
        TrueQuests.QuestManager.updateAll(self.player)
    end

    local selectedId = nil
    if self.questList and self.questList.items then
        local row = self.questList.items[self.questList.selected]
        selectedId = row and row.item and row.item.quest and row.item.quest.id or nil
    end

    self.questList:clear()
    self.entries = {}

    if self.activeTab == "faction" then
        for _, quest in ipairs(TrueQuests.QuestManager.getActiveQuests(self.player) or {}) do
            local entry = { quest = quest }
            table.insert(self.entries, entry)
            self.questList:addItem(tostring(quest.title or "Quest"), entry)
        end
    end

    local selected = 1
    for index, row in ipairs(self.questList.items or {}) do
        if row.item and row.item.quest and row.item.quest.id == selectedId then
            selected = index
            break
        end
    end
    if self.questList.items and #self.questList.items > 0 then
        self.questList.selected = selected
    end
    setVisible(self.questList, self.questList.items and #self.questList.items > 0)

    self:applyLayout()
    self:updateMarkerButton()
end

function TQ_QuestJournalWindow:updateMarkerButton()
    local quest = self:getSelectedQuest()
    local marker = TrueQuests.QuestItems and TrueQuests.QuestItems.getQuestMarker and TrueQuests.QuestItems.getQuestMarker(quest) or nil
    local enabled = marker ~= nil

    if self.markerButton then
        self.markerButton:setEnable(enabled)
        setButtonTitle(self.markerButton, TQ_QuestMarker and TQ_QuestMarker.isTracking and TQ_QuestMarker.isTracking(quest) and "Marker Off" or "Marker On")
        TQ_UITheme.styleButton(self.markerButton, enabled and (TQ_QuestMarker and TQ_QuestMarker.isTracking and TQ_QuestMarker.isTracking(quest) and "warning" or "info") or "muted")
    end
end

function TQ_QuestJournalWindow:onToggleMarker()
    local quest = self:getSelectedQuest()
    if not quest or not TrueQuests.QuestItems or not TrueQuests.QuestItems.getQuestMarker or not TrueQuests.QuestItems.getQuestMarker(quest) then
        return
    end

    if TQ_QuestMarker and TQ_QuestMarker.Toggle then
        TQ_QuestMarker.Toggle(self.player, quest)
    end
    self:updateMarkerButton()
end

function TQ_QuestJournalWindow:drawQuestDetails(quest)
    if not quest then
        return
    end

    TQ_UITheme.drawPanel(self, self.detailX, self.listY, self.detailW, self.listH, "panelBg", "borderSoft")
    TQ_UITheme.drawAccent(self, self.detailX, self.listY, 4, self.listH, statusColor(quest.status))

    local x = self.detailX + 16
    local y = self.listY + 12
    local w = self.detailW - 30

    self:drawText(TQ_UITheme.truncate(tostring(quest.title or "Quest"), w, UIFont.Medium), x, y, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    y = y + 25
    self:drawText(TQ_UITheme.truncate(questMeta(quest), w, UIFont.Small), x, y, 0.58, 0.63, 0.65, 1, UIFont.Small)
    y = y + 26

    local description = tostring(quest.description or "")
    if description == "" then
        description = "No additional description."
    end
    y = TQ_UITheme.drawWrapped(self, description, x, y, w, 4, "text", UIFont.Small) + 12

    self:drawText("OBJECTIVES", x, y, 0.68, 0.74, 0.78, 1, UIFont.Small)
    y = y + 20
    local objectiveCount = 0
    for _, objective in ipairs(quest.objectives or {}) do
        objectiveCount = objectiveCount + 1
        local line = TrueQuests.Objectives and TrueQuests.Objectives.describe and TrueQuests.Objectives.describe(objective) or tostring(objective.label or objective.type or "Objective")
        y = TQ_UITheme.drawWrapped(self, "- " .. tostring(line), x, y, w, 2, "text", UIFont.Small) + 4
        if objectiveCount >= 4 then
            break
        end
    end
    if objectiveCount == 0 then
        self:drawText("- No objectives tracked.", x, y, 0.86, 0.88, 0.84, 1, UIFont.Small)
        y = y + 20
    end

    y = y + 8
    self:drawText("TURN IN", x, y, 0.68, 0.74, 0.78, 1, UIFont.Small)
    y = y + 18
    y = TQ_UITheme.drawWrapped(self, turnInText(quest), x, y, w, 2, "text", UIFont.Small) + 10

    self:drawText("DEADLINE", x, y, 0.68, 0.74, 0.78, 1, UIFont.Small)
    y = y + 18
    local timer = timerText(quest)
    local color = timer == "Expired" and "red" or "amber"
    TQ_UITheme.drawPill(self, x, y, math.max(82, TQ_UITheme.measure(UIFont.Small, timer) + 18), 22, timer, color)
end

function TQ_QuestJournalWindow.drawQuestItem(list, y, item, alt)
    local entry = item.item or {}
    local quest = entry.quest or {}
    local selected = list.selected == item.index
    local rowX = 3
    local rowY = y + 3
    local rowW = list.width - 6
    local rowH = list.itemheight - 6
    local timer = timerText(quest)
    local accent = timer == "Expired" and "red" or statusColor(quest.status)
    local fill = selected and "selected" or (alt and "rowAlt" or "panelBg")

    TQ_UITheme.drawPanel(list, rowX, rowY, rowW, rowH, fill, selected and accent or "borderSoft")
    TQ_UITheme.drawAccent(list, rowX, rowY, 4, rowH, accent)

    local timerW = math.max(76, TQ_UITheme.measure(UIFont.Small, timer) + 18)
    local titleW = rowW - timerW - 26
    list:drawText(TQ_UITheme.truncate(tostring(item.text or quest.title or "Quest"), titleW, UIFont.Small), rowX + 12, rowY + 8, 0.96, 0.91, 0.79, 1, UIFont.Small)
    list:drawText(TQ_UITheme.truncate(questMeta(quest), titleW, UIFont.Small), rowX + 12, rowY + 28, 0.58, 0.63, 0.65, 1, UIFont.Small)
    list:drawText(TQ_UITheme.truncate(objectiveText(quest), rowW - 24, UIFont.Small), rowX + 12, rowY + 50, 0.86, 0.88, 0.84, 1, UIFont.Small)

    TQ_UITheme.drawPill(list, rowX + rowW - timerW - 8, rowY + 8, timerW, 20, timer, accent)
    TQ_UITheme.drawTextRight(list, statusLabel(quest.status), rowX + rowW - 12, rowY + 35, accent, UIFont.Small)

    return y + list.itemheight
end

function TQ_QuestJournalWindow:drawChrome()
    TQ_UITheme.drawPanel(self, 0, 0, self.width, self.height, "windowBg", "border")
    self:drawRect(1, 1, self.width - 2, 23, 0.96, 0.095, 0.105, 0.125)
    self:drawRect(1, 24, self.width - 2, 1, 0.92, 0.30, 0.36, 0.42)
    self:drawText("TRUE QUESTS JOURNAL", 10, 6, 0.96, 0.91, 0.79, 1, UIFont.Small)
    self:drawRect(self.width - 18, self.height - 5, 13, 1, 0.80, 0.36, 0.41, 0.46)
    self:drawRect(self.width - 13, self.height - 10, 8, 1, 0.80, 0.36, 0.41, 0.46)
    self:drawRect(self.width - 8, self.height - 15, 3, 1, 0.80, 0.36, 0.41, 0.46)
end

function TQ_QuestJournalWindow:prerender()
    self:applyLayout()
    self:updateMarkerButton()
    self:drawChrome()

    TQ_UITheme.drawPanel(self, self.bodyX, self.bodyY, self.bodyW, 44, "panelBg", "border")
    TQ_UITheme.drawAccent(self, self.bodyX, self.bodyY, 4, 44, "blue")
    self:drawText("QUEST LOG", self.bodyX + 16, self.bodyY + 8, 0.96, 0.91, 0.79, 1, UIFont.Medium)

    local count = tostring(#(self.entries or {})) .. " tracked"
    TQ_UITheme.drawTextRight(self, count, self.bodyX + self.bodyW - 16, self.bodyY + 15, "text", UIFont.Small)

    if self.questList and self.questList.items and #self.questList.items == 0 then
        local tab = self:getActiveTab()
        self:drawText(tostring(tab.empty), self.bodyX + 16, self.listY + 18, 0.70, 0.75, 0.76, 1, UIFont.Small)
    elseif self.activeTab == "faction" then
        self:drawQuestDetails(self:getSelectedQuest())
    end
end

function TQ_QuestJournalWindow:update()
    if ISPanel.update then
        ISPanel.update(self)
    end

    self.refreshCounter = (tonumber(self.refreshCounter) or 0) + 1
    if self.refreshCounter >= 60 then
        self.refreshCounter = 0
        self:refreshData()
    end
end

function TQ_QuestJournalWindow:close()
    self:removeFromUIManager()
    if TQ_QuestJournalWindow.instance == self then
        TQ_QuestJournalWindow.instance = nil
    end
end

function TQ_QuestJournalWindow:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.activeTab = "faction"
    o.resizable = true
    o.moveWithMouse = true
    TQ_UITheme.applyWindow(o)
    return o
end

function TQ_QuestJournalWindow.Open(player)
    if not player then
        return nil
    end

    if TQ_QuestJournalWindow.instance then
        if TQ_QuestJournalWindow.instance.bringToTop then
            TQ_QuestJournalWindow.instance:bringToTop()
        end
        return TQ_QuestJournalWindow.instance
    end

    local width = 720
    local height = 520
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2

    local window = TQ_QuestJournalWindow:new(x, y, width, height, player)
    window:initialise()
    window:addToUIManager()
    TQ_QuestJournalWindow.instance = window
    return window
end

function TQ_QuestJournalWindow.Toggle(player)
    if TQ_QuestJournalWindow.instance then
        TQ_QuestJournalWindow.instance:close()
        return nil
    end

    return TQ_QuestJournalWindow.Open(player)
end
