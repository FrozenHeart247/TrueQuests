require "ISUI/ISPanel"
require "ISUI/ISButton"
require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_UITheme"

TQ_DialogueWindow = ISPanel:derive("TQ_DialogueWindow")
TQ_DialogueWindow.instance = nil

local function factionName(contact)
    local faction = TrueQuests.Factions and TrueQuests.Factions.getFactionForContact(contact) or nil
    return tostring((faction and faction.name) or "Unaffiliated")
end

local function contactRole(contact)
    local role = tostring(contact and contact.role or "contact")
    return string.upper(string.sub(role, 1, 1)) .. string.sub(role, 2)
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

local function makeButton(parent, x, y, width, height, title, callback, kind)
    local button = ISButton:new(x, y, width, height, title, parent, callback)
    button:initialise()
    TQ_UITheme.styleButton(button, kind)
    parent:addChild(button)
    return button
end

function TQ_DialogueWindow:initialise()
    ISPanel.initialise(self)
end

function TQ_DialogueWindow:createChildren()
    ISPanel.createChildren(self)

    local buttonY = self.height - 38
    self.workButton = makeButton(self, 16, buttonY, 92, 24, "Work", TQ_DialogueWindow.onWork, "info")
    self.aboutButton = makeButton(self, 116, buttonY, 92, 24, "About", TQ_DialogueWindow.onAbout, "default")
    self.rumorButton = makeButton(self, 216, buttonY, 92, 24, "Rumor", TQ_DialogueWindow.onRumor, "muted")
    self.closeButton = makeButton(self, self.width - 104, buttonY, 88, 24, "Close", TQ_DialogueWindow.close, "muted")
    self.topCloseButton = makeButton(self, self.width - 27, 3, 21, 18, "X", TQ_DialogueWindow.close, "danger")

    self:setDialogueKey("greeting")
end

function TQ_DialogueWindow:setDialogueKey(key)
    self.dialogueKey = key
    self.currentLine = TrueQuests.Dialogue.getContactLine(self.contact, key, "Only static answers.")
end

function TQ_DialogueWindow:onWork()
    self:setDialogueKey("work")
end

function TQ_DialogueWindow:onAbout()
    self:setDialogueKey("about")
end

function TQ_DialogueWindow:onRumor()
    self:setDialogueKey("rumor")
end

function TQ_DialogueWindow:drawChrome()
    TQ_UITheme.drawPanel(self, 0, 0, self.width, self.height, "windowBg", "border")
    self:drawRect(1, 1, self.width - 2, 23, 0.96, 0.095, 0.105, 0.125)
    self:drawRect(1, 24, self.width - 2, 1, 0.92, 0.30, 0.36, 0.42)
    self:drawText("TRUE QUESTS", 10, 6, 0.96, 0.91, 0.79, 1, UIFont.Small)
end

function TQ_DialogueWindow:drawPortrait(x, y, size)
    local texture = getTextureSafe(self.contact and (self.contact.portrait or self.contact.icon))
    TQ_UITheme.drawPanel(self, x, y, size, size, "listBg", "borderSoft")

    if texture then
        local tw = texture:getWidth()
        local th = texture:getHeight()
        local scale = size / math.max(tw, th)
        local drawW = tw * scale
        local drawH = th * scale
        self:drawTextureScaled(texture, x + (size - drawW) / 2, y + (size - drawH) / 2, drawW, drawH, 1, 1, 1, 1)
    else
        local initial = string.sub(tostring(self.contact and self.contact.name or "?"), 1, 1)
        self:drawTextCentre(initial, x + size / 2, y + size / 2 - 10, 0.70, 0.75, 0.76, 1, UIFont.Large)
    end
end

function TQ_DialogueWindow:prerender()
    self:drawChrome()

    local contact = self.contact or {}
    TQ_UITheme.drawPanel(self, 16, 36, self.width - 32, 82, "panelBg", "border")
    TQ_UITheme.drawAccent(self, 16, 36, 4, 82, "blue")
    self:drawPortrait(30, 48, 54)

    self:drawText(tostring(contact.name or "Unknown"), 96, 47, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    self:drawText(contactRole(contact) .. " / " .. factionName(contact), 96, 72, 0.58, 0.63, 0.65, 1, UIFont.Small)

    local factionId = TrueQuests.Factions and TrueQuests.Factions.getFactionIdForContact(contact) or "independent"
    local rep = TrueQuests.Factions and TrueQuests.Factions.getReputation(self.player, factionId) or 0
    TQ_UITheme.drawTextRight(self, "Rep: " .. tostring(rep), self.width - 30, 72, "text", UIFont.Small)

    TQ_UITheme.drawPanel(self, 16, 130, self.width - 32, self.height - 184, "listBg", "borderSoft")
    TQ_UITheme.drawWrapped(self, self.currentLine, 30, 146, self.width - 60, 7, "text", UIFont.Small)
end

function TQ_DialogueWindow:close()
    self:removeFromUIManager()
    if TQ_DialogueWindow.instance == self then
        TQ_DialogueWindow.instance = nil
    end
end

function TQ_DialogueWindow:new(x, y, width, height, player, contact)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.contact = contact
    o.resizable = false
    o.moveWithMouse = true
    TQ_UITheme.applyWindow(o)
    return o
end

function TQ_DialogueWindow.Open(player, contactOrId)
    local contact = type(contactOrId) == "table" and contactOrId or TrueQuests.getContact(contactOrId)
    if not player or not contact then
        return nil
    end

    if TQ_DialogueWindow.instance then
        TQ_DialogueWindow.instance:close()
    end

    local width = 500
    local height = 300
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    local window = TQ_DialogueWindow:new(x, y, width, height, player, contact)
    window:initialise()
    window:addToUIManager()
    TQ_DialogueWindow.instance = window
    return window
end

