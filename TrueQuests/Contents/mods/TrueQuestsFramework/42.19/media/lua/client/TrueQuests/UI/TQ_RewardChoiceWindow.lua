require "ISUI/ISPanel"
require "ISUI/ISButton"
require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_UITheme"

TQ_RewardCard = ISPanel:derive("TQ_RewardCard")

local rarityStyles = {
    common = { r = 0.58, g = 0.64, b = 0.66, label = "COMMON" },
    uncommon = { r = 0.34, g = 0.72, b = 0.42, label = "UNCOMMON" },
    rare = { r = 0.34, g = 0.54, b = 0.86, label = "RARE" },
    special = { r = 0.58, g = 0.42, b = 0.82, label = "SPECIAL" },
    unique = { r = 0.88, g = 0.66, b = 0.30, label = "UNIQUE" },
}

local function rarityStyle(rarity)
    return rarityStyles[tostring(rarity or "common")] or rarityStyles.common
end

function TQ_RewardCard:initialise()
    ISPanel.initialise(self)
end

function TQ_RewardCard:createChildren()
    local buttonY = self.height - 34
    self.chooseButton = ISButton:new(10, buttonY, self.width - 20, 24, "Choose", self, TQ_RewardCard.onChoose)
    self.chooseButton:initialise()
    TQ_UITheme.styleButton(self.chooseButton, "primary")
    self:addChild(self.chooseButton)
end

function TQ_RewardCard:onChoose()
    if self.parentWindow and self.parentWindow.onChooseReward then
        self.parentWindow:onChooseReward(self.index)
    end
end

function TQ_RewardCard:drawItemTexture()
    local texture = TrueQuests.getItemTexture(self.reward.item)
    if not texture then
        TQ_UITheme.drawPanel(self, (self.width - 54) / 2, 54, 54, 54, "listBg", "borderSoft")
        self:drawTextCentre("?", self.width / 2, 72, 0.62, 0.66, 0.68, 1, UIFont.Medium)
        return
    end

    local target = 58
    local tw = texture:getWidth()
    local th = texture:getHeight()
    local scale = target / math.max(tw, th)
    local drawW = tw * scale
    local drawH = th * scale
    self:drawTextureScaled(texture, (self.width - drawW) / 2, 52 + (target - drawH) / 2, drawW, drawH, 1, 1, 1, 1)
end

function TQ_RewardCard:prerender()
    ISPanel.prerender(self)

    local reward = self.reward or {}
    local rarity = tostring(reward.rarity or "common")
    local style = rarityStyle(rarity)

    self:drawRect(0, 0, self.width, self.height, 0.94, 0.08, 0.085, 0.10)
    self:drawRectBorder(0, 0, self.width, self.height, 1, style.r, style.g, style.b)
    self:drawRect(0, 0, self.width, 4, 0.95, style.r, style.g, style.b)
    self:drawRect(8, 10, self.width - 16, 24, 0.36, style.r, style.g, style.b)
    self:drawRectBorder(8, 10, self.width - 16, 24, 0.95, style.r, style.g, style.b)
    self:drawTextCentre(style.label, self.width / 2, 15, 0.96, 0.94, 0.88, 1, UIFont.Small)

    self:drawItemTexture()

    local display = tostring(reward.displayName or reward.item or "Reward")
    display = TQ_UITheme.truncate(display, self.width - 20, UIFont.Small)
    self:drawTextCentre(display, self.width / 2, 120, 0.91, 0.91, 0.87, 1, UIFont.Small)

    local itemType = tostring(reward.item or "")
    itemType = TQ_UITheme.truncate(itemType, self.width - 22, UIFont.Small)
    self:drawTextCentre(itemType, self.width / 2, 139, 0.54, 0.58, 0.60, 1, UIFont.Small)

    local count = "x" .. tostring(reward.count or 1)
    local countW = math.max(42, TQ_UITheme.measure(UIFont.Small, count) + 16)
    TQ_UITheme.drawPill(self, (self.width - countW) / 2, 158, countW, 21, count, "amber")
end

function TQ_RewardCard:new(x, y, width, height, reward, index, parentWindow)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.reward = reward
    o.index = index
    o.parentWindow = parentWindow
    o.background = false
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

TQ_RewardChoiceWindow = ISPanel:derive("TQ_RewardChoiceWindow")
TQ_RewardChoiceWindow.instance = nil

function TQ_RewardChoiceWindow:initialise()
    ISPanel.initialise(self)
end

function TQ_RewardChoiceWindow:createChildren()
    ISPanel.createChildren(self)

    local choices = self.quest.rewardChoices or {}
    self.cards = {}

    local cardWidth = 152
    local cardHeight = 214
    local gap = 12
    local totalWidth = (#choices * cardWidth) + math.max(0, #choices - 1) * gap
    local startX = math.max(18, (self.width - totalWidth) / 2)
    local y = 92

    for index, reward in ipairs(choices) do
        local card = TQ_RewardCard:new(startX + (index - 1) * (cardWidth + gap), y, cardWidth, cardHeight, reward, index, self)
        card:initialise()
        card:instantiate()
        self:addChild(card)
        table.insert(self.cards, card)
    end

    self.closeButton = ISButton:new(self.width - 104, self.height - 38, 88, 24, "Close", self, TQ_RewardChoiceWindow.close)
    self.closeButton:initialise()
    TQ_UITheme.styleButton(self.closeButton, "muted")
    self:addChild(self.closeButton)

    self.topCloseButton = ISButton:new(self.width - 27, 3, 21, 18, "X", self, TQ_RewardChoiceWindow.close)
    self.topCloseButton:initialise()
    TQ_UITheme.styleButton(self.topCloseButton, "danger")
    self:addChild(self.topCloseButton)
end

function TQ_RewardChoiceWindow:drawChrome()
    TQ_UITheme.drawPanel(self, 0, 0, self.width, self.height, "windowBg", "border")
    self:drawRect(1, 1, self.width - 2, 23, 0.96, 0.095, 0.105, 0.125)
    self:drawRect(1, 24, self.width - 2, 1, 0.92, 0.30, 0.36, 0.42)
    self:drawText("TRUE QUESTS", 10, 6, 0.96, 0.91, 0.79, 1, UIFont.Small)
end

function TQ_RewardChoiceWindow:prerender()
    self:drawChrome()

    TQ_UITheme.drawPanel(self, 16, 36, self.width - 32, 48, "panelBg", "border")
    TQ_UITheme.drawAccent(self, 16, 36, 4, 48, "green")
    self:drawText("REWARD CACHE", 30, 43, 0.96, 0.91, 0.79, 1, UIFont.Medium)

    local questTitle = TQ_UITheme.truncate(tostring(self.quest.title or "Completed request"), self.width - 220, UIFont.Small)
    self:drawText(questTitle, 30, 67, 0.58, 0.63, 0.65, 1, UIFont.Small)

    local count = tostring(#(self.quest.rewardChoices or {})) .. " choices"
    TQ_UITheme.drawTextRight(self, count, self.width - 28, 56, "text", UIFont.Small)
end

function TQ_RewardChoiceWindow:onChooseReward(index)
    local reward = TrueQuests.QuestManager.chooseReward(self.player, self.quest.id, index)
    if reward then
        TrueQuests.say(self.player, "Reward received: " .. tostring(reward.displayName or reward.item))
        self:close()
        if TQ_QuestBoardWindow and TQ_QuestBoardWindow.instance then
            TQ_QuestBoardWindow.instance:refreshData()
        end
    else
        TrueQuests.say(self.player, "Could not claim that reward.")
    end
end

function TQ_RewardChoiceWindow:close()
    self:removeFromUIManager()
    if TQ_RewardChoiceWindow.instance == self then
        TQ_RewardChoiceWindow.instance = nil
    end
end

function TQ_RewardChoiceWindow:new(x, y, width, height, player, quest)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.quest = quest
    o.resizable = false
    o.moveWithMouse = true
    TQ_UITheme.applyWindow(o)
    return o
end

function TQ_RewardChoiceWindow.Open(player, quest)
    if not player or not quest then
        return nil
    end

    if TQ_RewardChoiceWindow.instance then
        TQ_RewardChoiceWindow.instance:close()
    end

    local choices = quest.rewardChoices or {}
    local cardWidth = 152
    local gap = 12
    local width = math.max(430, 36 + (#choices * cardWidth) + math.max(0, #choices - 1) * gap)
    local height = 340
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2

    local window = TQ_RewardChoiceWindow:new(x, y, width, height, player, quest)
    window:initialise()
    window:addToUIManager()
    TQ_RewardChoiceWindow.instance = window
    return window
end
