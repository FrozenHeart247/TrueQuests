require "ISUI/ISPanel"
require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_UITheme"
require "TrueQuests/UI/TQ_QuestJournalWindow"

TQ_QuestJournalButton = ISPanel:derive("TQ_QuestJournalButton")
TQ_QuestJournalButton.instances = TQ_QuestJournalButton.instances or {}

local ICON_PATH = "media/textures/TrueQuests/UI/QuestJournal.png"
local FALLBACK_ICON_PATH = "media/textures/QuestJournal.png"
local BUTTON_SIZE = 42

local function getTextureSafe(path)
    if not getTexture or not path then
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

local function screenSize()
    if getCore then
        local core = getCore()
        if core then
            return core:getScreenWidth(), core:getScreenHeight()
        end
    end
    return 1280, 720
end

local function clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function clampPosition(x, y)
    local sw, sh = screenSize()
    return clamp(x, 4, sw - BUTTON_SIZE - 4), clamp(y, 4, sh - BUTTON_SIZE - 4)
end

local function getUIData(player)
    if not player or not player.getModData then
        return {}
    end

    local modData = player:getModData()
    modData.TrueQuestsUI = type(modData.TrueQuestsUI) == "table" and modData.TrueQuestsUI or {}
    return modData.TrueQuestsUI
end

local function loadPosition(player)
    local ui = getUIData(player)
    local saved = type(ui.journalButton) == "table" and ui.journalButton or nil
    if saved then
        return clampPosition(tonumber(saved.x) or 72, tonumber(saved.y) or 96)
    end
    return clampPosition(72, 96)
end

local function savePosition(player, x, y)
    local ui = getUIData(player)
    ui.journalButton = {
        x = math.floor(tonumber(x) or 72),
        y = math.floor(tonumber(y) or 96),
    }

    if player and player.transmitModData then
        player:transmitModData()
    end
end

function TQ_QuestJournalButton:initialise()
    ISPanel.initialise(self)
    self.texture = getTextureSafe(ICON_PATH) or getTextureSafe(FALLBACK_ICON_PATH)
end

function TQ_QuestJournalButton:setPositionClamped(x, y)
    x, y = clampPosition(x, y)
    self.x = x
    self.y = y
    if self.setX then self:setX(x) end
    if self.setY then self:setY(y) end
end

function TQ_QuestJournalButton:onActivate()
    local player = self.player or (getSpecificPlayer and getSpecificPlayer(self.playerNum or 0)) or nil
    if TQ_QuestJournalWindow and TQ_QuestJournalWindow.Toggle then
        TQ_QuestJournalWindow.Toggle(player)
    end
end

function TQ_QuestJournalButton:onMouseDown(x, y)
    self.dragging = true
    self.dragDistance = 0
    self.wasDragged = false
    if self.bringToTop then
        self:bringToTop()
    end
    if self.setCapture then
        self:setCapture(true)
    end
    return true
end

function TQ_QuestJournalButton:onMouseMove(dx, dy)
    if not self.dragging then
        return
    end

    dx = tonumber(dx) or 0
    dy = tonumber(dy) or 0
    self.dragDistance = (tonumber(self.dragDistance) or 0) + math.abs(dx) + math.abs(dy)
    if self.dragDistance > 4 then
        self.wasDragged = true
    end

    self:setPositionClamped((tonumber(self.x) or 0) + dx, (tonumber(self.y) or 0) + dy)
end

function TQ_QuestJournalButton:onMouseMoveOutside(dx, dy)
    self:onMouseMove(dx, dy)
end

function TQ_QuestJournalButton:onMouseUp(x, y)
    if self.setCapture then
        self:setCapture(false)
    end

    local wasDragged = self.wasDragged == true
    self.dragging = false
    self.wasDragged = false
    savePosition(self.player, self.x, self.y)

    if not wasDragged then
        self:onActivate()
    end
    return true
end

function TQ_QuestJournalButton:onMouseUpOutside(x, y)
    if self.setCapture then
        self:setCapture(false)
    end
    self.dragging = false
    self.wasDragged = false
    savePosition(self.player, self.x, self.y)
    return true
end

function TQ_QuestJournalButton:prerender()
    local hovered = self.isMouseOver and self:isMouseOver()
    local border = hovered and "amber" or "borderSoft"

    TQ_UITheme.drawPanel(self, 0, 0, self.width, self.height, "windowBg", border)
    self:drawRect(2, 2, self.width - 4, self.height - 4, hovered and 0.24 or 0.16, 0.30, 0.36, 0.42)

    if self.texture then
        self:drawTextureScaled(self.texture, 7, 7, self.width - 14, self.height - 14, 1, 1, 1, 1)
    else
        self:drawTextCentre("Q", self.width / 2, 11, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    end
end

function TQ_QuestJournalButton:new(x, y, playerNum, player)
    local o = ISPanel:new(x, y, BUTTON_SIZE, BUTTON_SIZE)
    setmetatable(o, self)
    self.__index = self
    o.playerNum = tonumber(playerNum) or 0
    o.player = player
    o.background = false
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    o.moveWithMouse = false
    o.tooltip = "Quest Journal"
    return o
end

function TQ_QuestJournalButton.ensureForPlayer(playerNum, player)
    playerNum = tonumber(playerNum) or 0
    player = player or (getSpecificPlayer and getSpecificPlayer(playerNum)) or nil
    if not player then
        return nil
    end

    local existing = TQ_QuestJournalButton.instances[playerNum]
    if existing then
        existing.player = player
        existing:setPositionClamped(existing.x, existing.y)
        return existing
    end

    local x, y = loadPosition(player)
    local button = TQ_QuestJournalButton:new(x, y, playerNum, player)
    button:initialise()
    button:addToUIManager()
    if button.setAlwaysOnTop then
        button:setAlwaysOnTop(true)
    end

    TQ_QuestJournalButton.instances[playerNum] = button
    return button
end

function TQ_QuestJournalButton.ensureAll()
    if not getSpecificPlayer then
        return
    end

    for playerNum = 0, 3 do
        local player = getSpecificPlayer(playerNum)
        if player then
            TQ_QuestJournalButton.ensureForPlayer(playerNum, player)
        end
    end
end

function TQ_QuestJournalButton.onCreatePlayer(playerNum, player)
    TQ_QuestJournalButton.ensureForPlayer(playerNum, player)
end

function TQ_QuestJournalButton.onResolutionChange()
    for _, button in pairs(TQ_QuestJournalButton.instances or {}) do
        if button and button.setPositionClamped then
            button:setPositionClamped(button.x, button.y)
        end
    end
end

function TQ_QuestJournalButton.onPlayerDeath(player)
    local targetNum = nil
    if type(player) == "number" then
        targetNum = player
    elseif getSpecificPlayer then
        for playerNum = 0, 3 do
            if getSpecificPlayer(playerNum) == player then
                targetNum = playerNum
                break
            end
        end
    end

    if targetNum == nil then
        return
    end

    local button = TQ_QuestJournalButton.instances[targetNum]
    if button then
        button:removeFromUIManager()
        TQ_QuestJournalButton.instances[targetNum] = nil
    end
end

if Events then
    if Events.OnCreatePlayer then
        Events.OnCreatePlayer.Add(TQ_QuestJournalButton.onCreatePlayer)
    end
    if Events.OnGameStart then
        Events.OnGameStart.Add(TQ_QuestJournalButton.ensureAll)
    end
    if Events.OnResolutionChange then
        Events.OnResolutionChange.Add(TQ_QuestJournalButton.onResolutionChange)
    end
    if Events.OnPlayerDeath then
        Events.OnPlayerDeath.Add(TQ_QuestJournalButton.onPlayerDeath)
    end
end
