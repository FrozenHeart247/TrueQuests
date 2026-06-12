require "ISUI/ISUIElement"
require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_UITheme"

TQ_QuestMarker = ISUIElement:derive("TQ_QuestMarker")
TQ_QuestMarker.instance = nil

local DIRECTIONS = {
    { label = "E", min = 337.5, max = 360 },
    { label = "E", min = 0, max = 22.5 },
    { label = "SE", min = 22.5, max = 67.5 },
    { label = "S", min = 67.5, max = 112.5 },
    { label = "SW", min = 112.5, max = 157.5 },
    { label = "W", min = 157.5, max = 202.5 },
    { label = "NW", min = 202.5, max = 247.5 },
    { label = "N", min = 247.5, max = 292.5 },
    { label = "NE", min = 292.5, max = 337.5 },
}

local function setChildPosition(element, x, y)
    if not element then
        return
    end
    element.x = x
    element.y = y
    if element.setX then element:setX(x) end
    if element.setY then element:setY(y) end
end

local function markerTarget(quest)
    if not TrueQuests.QuestItems or not TrueQuests.QuestItems.getQuestMarker then
        return nil
    end
    return TrueQuests.QuestItems.getQuestMarker(quest)
end

local function distance(player, target)
    if not player or not target then
        return nil
    end

    local px = player.getX and player:getX() or 0
    local py = player.getY and player:getY() or 0
    if IsoUtils and IsoUtils.DistanceTo then
        return IsoUtils.DistanceTo(px, py, target.x, target.y)
    end

    local dx = px - target.x
    local dy = py - target.y
    return math.sqrt(dx * dx + dy * dy)
end

local function directionLabel(player, target)
    if not player or not target then
        return "?"
    end

    local dx = target.x - (player.getX and player:getX() or 0)
    local dy = target.y - (player.getY and player:getY() or 0)
    local angle = math.atan2 and math.atan2(dy, dx) or math.atan(dy, dx)
    local degrees = (math.deg(angle) + 360) % 360
    for _, entry in ipairs(DIRECTIONS) do
        if degrees >= entry.min and degrees < entry.max then
            return entry.label
        end
    end

    return "?"
end

function TQ_QuestMarker:initialise()
    ISUIElement.initialise(self)
end

function TQ_QuestMarker:setQuest(quest)
    self.questId = quest and quest.id or nil
    self.questTitle = tostring(quest and quest.title or "Quest marker")
end

function TQ_QuestMarker:getQuest()
    if not self.player or not self.questId or not TrueQuests.QuestManager or not TrueQuests.QuestManager.findActiveQuest then
        return nil
    end

    local quest = TrueQuests.QuestManager.findActiveQuest(self.player, self.questId)
    return quest
end

function TQ_QuestMarker:update()
    if ISUIElement.update then
        ISUIElement.update(self)
    end

    local quest = self:getQuest()
    local target = markerTarget(quest)
    if not quest or not target then
        self:close()
        return
    end

    self.target = target
    self.distance = distance(self.player, target)
    self.direction = directionLabel(self.player, target)
end

function TQ_QuestMarker:render()
    local quest = self:getQuest()
    local target = markerTarget(quest)
    if not quest or not target then
        return
    end

    self.target = target
    self.distance = distance(self.player, target)
    self.direction = directionLabel(self.player, target)

    TQ_UITheme.drawPanel(self, 0, 0, self.width, self.height, "windowBg", "border")
    TQ_UITheme.drawAccent(self, 0, 0, 4, self.height, "amber")

    self:drawTextCentre(tostring(self.direction or "?"), 26, 9, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    self:drawText(TQ_UITheme.truncate(tostring(quest.title or self.questTitle), self.width - 58, UIFont.Small), 48, 8, 0.92, 0.91, 0.86, 1, UIFont.Small)

    local dist = self.distance and (tostring(math.floor(self.distance + 0.5)) .. " tiles") or "unknown"
    self:drawText(TQ_UITheme.truncate(dist, self.width - 58, UIFont.Small), 48, 28, 0.68, 0.74, 0.78, 1, UIFont.Small)

    if self.mouseOver then
        local label = tostring(target.label or "Search area")
        local text = label .. " - " .. dist
        local tooltipW = math.min(360, math.max(180, TQ_UITheme.measure(UIFont.Small, text) + 22))
        TQ_UITheme.drawPanel(self, 0, self.height + 6, tooltipW, 28, "panelBg", "border")
        self:drawText(TQ_UITheme.truncate(text, tooltipW - 16, UIFont.Small), 8, self.height + 13, 0.86, 0.88, 0.84, 1, UIFont.Small)
    end

    ISUIElement.render(self)
end

function TQ_QuestMarker:onMouseDown(x, y)
    self.downX = x
    self.downY = y
    self.moving = true
    self:bringToTop()
    return true
end

function TQ_QuestMarker:onMouseMoveOutside(dx, dy)
    self.mouseOver = false
    if self.moving then
        setChildPosition(self, self.x + dx, self.y + dy)
        self:bringToTop()
    end
end

function TQ_QuestMarker:onMouseMove(dx, dy)
    self.mouseOver = true
    if self.moving then
        setChildPosition(self, self.x + dx, self.y + dy)
        self:bringToTop()
    end
end

function TQ_QuestMarker:onMouseUp(x, y)
    self.moving = false
    if ISMouseDrag then
        ISMouseDrag.dragView = nil
    end
end

function TQ_QuestMarker:onMouseUpOutside(x, y)
    self.moving = false
    if ISMouseDrag then
        ISMouseDrag.dragView = nil
    end
end

function TQ_QuestMarker:onMouseDoubleClick(x, y)
    self:close()
end

function TQ_QuestMarker:close()
    self:removeFromUIManager()
    if TQ_QuestMarker.instance == self then
        TQ_QuestMarker.instance = nil
    end
end

function TQ_QuestMarker:new(x, y, width, height, player, quest)
    local o = ISUIElement:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.mouseOver = false
    o.moving = false
    o:setQuest(quest)
    return o
end

function TQ_QuestMarker.Open(player, quest)
    if not player or not quest or not markerTarget(quest) then
        return nil
    end

    if TQ_QuestMarker.instance then
        TQ_QuestMarker.instance:setQuest(quest)
        if TQ_QuestMarker.instance.bringToTop then
            TQ_QuestMarker.instance:bringToTop()
        end
        return TQ_QuestMarker.instance
    end

    local width = 210
    local height = 52
    local x = math.floor((getCore():getScreenWidth() - width) / 2)
    local y = 72
    local marker = TQ_QuestMarker:new(x, y, width, height, player, quest)
    marker:initialise()
    marker:addToUIManager()
    TQ_QuestMarker.instance = marker
    return marker
end

function TQ_QuestMarker.Toggle(player, quest)
    if TQ_QuestMarker.instance and quest and TQ_QuestMarker.instance.questId == quest.id then
        TQ_QuestMarker.instance:close()
        return nil
    end

    return TQ_QuestMarker.Open(player, quest)
end

function TQ_QuestMarker.isTracking(quest)
    return TQ_QuestMarker.instance ~= nil and quest ~= nil and TQ_QuestMarker.instance.questId == quest.id
end
