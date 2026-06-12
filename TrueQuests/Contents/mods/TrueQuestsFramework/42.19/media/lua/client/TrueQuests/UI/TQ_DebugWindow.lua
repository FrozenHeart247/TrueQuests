require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "TrueQuests/TQ_API"
require "TrueQuests/UI/TQ_UITheme"

TQ_DebugWindow = ISPanel:derive("TQ_DebugWindow")
TQ_DebugWindow.instance = nil

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

local function makeButton(parent, x, y, width, height, title, callback, kind)
    local button = ISButton:new(x, y, width, height, title, parent, callback)
    button:initialise()
    TQ_UITheme.styleButton(button, kind)
    parent:addChild(button)
    return button
end

local function npcApi()
    return TrueNPC or TN or nil
end

local function formatSpawn(spawn)
    if not spawn then
        return "no spawn"
    end

    local name = tostring(spawn.name or spawn.id or "spawn")
    local x = math.floor(tonumber(spawn.x) or 0)
    local y = math.floor(tonumber(spawn.y) or 0)
    local z = math.floor(tonumber(spawn.z) or 0)
    return name .. " (" .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z) .. ")"
end

local function factionNameFor(id)
    local faction = TrueQuests.getFaction and TrueQuests.getFaction(id) or nil
    return tostring(faction and faction.name or id or "No faction")
end

local function teleportPlayer(player, spawn)
    if not player or not spawn then
        return false
    end

    local x = (tonumber(spawn.x) or 0) + 0.5
    local y = (tonumber(spawn.y) or 0) + 0.5
    local z = tonumber(spawn.z) or 0

    if player.teleportTo then
        player:teleportTo(x, y, z)
        return true
    end

    if player.setX then player:setX(x) end
    if player.setY then player:setY(y) end
    if player.setZ then player:setZ(z) end
    if player.setLx then player:setLx(x) end
    if player.setLy then player:setLy(y) end
    if player.setLz then player:setLz(z) end
    return true
end

local function selectedRow(list)
    if not list or not list.items then
        return nil
    end

    local row = list.items[list.selected]
    return row and row.item or nil
end

function TQ_DebugWindow:initialise()
    ISPanel.initialise(self)
end

function TQ_DebugWindow:createChildren()
    ISPanel.createChildren(self)
    self:applyLayout()

    self.npcList = ISScrollingListBox:new(self.npcListX, self.npcListY, self.npcListW, self.npcListH)
    self.npcList:initialise()
    self.npcList:instantiate()
    self.npcList.itemheight = 58
    self.npcList.doDrawItem = TQ_DebugWindow.drawNPCItem
    self.npcList.drawBorder = false
    self.npcList.parentWindow = self
    self:addChild(self.npcList)

    self.factionList = ISScrollingListBox:new(self.factionListX, self.factionListY, self.factionListW, self.factionListH)
    self.factionList:initialise()
    self.factionList:instantiate()
    self.factionList.itemheight = 50
    self.factionList.doDrawItem = TQ_DebugWindow.drawFactionItem
    self.factionList.drawBorder = false
    self.factionList.parentWindow = self
    self:addChild(self.factionList)

    self.teleportButton = makeButton(self, 0, 0, 1, 1, "Teleport", TQ_DebugWindow.onTeleportNPC, "primary")
    self.rerollSpawnButton = makeButton(self, 0, 0, 1, 1, "Reroll Spawn", TQ_DebugWindow.onRerollNPCSpawn, "warning")
    self.refreshNPCButton = makeButton(self, 0, 0, 1, 1, "Refresh NPC", TQ_DebugWindow.refreshNPCs, "default")

    self.repMinusFiveButton = makeButton(self, 0, 0, 1, 1, "-5", function(target) target:onChangeReputation(-5) end, "danger")
    self.repMinusOneButton = makeButton(self, 0, 0, 1, 1, "-1", function(target) target:onChangeReputation(-1) end, "warning")
    self.repPlusOneButton = makeButton(self, 0, 0, 1, 1, "+1", function(target) target:onChangeReputation(1) end, "primary")
    self.repPlusFiveButton = makeButton(self, 0, 0, 1, 1, "+5", function(target) target:onChangeReputation(5) end, "primary")
    self.discoverFactionButton = makeButton(self, 0, 0, 1, 1, "Discover", TQ_DebugWindow.onDiscoverFaction, "info")
    self.refreshContactsButton = makeButton(self, 0, 0, 1, 1, "Refresh Contacts", TQ_DebugWindow.onRefreshContacts, "default")
    self.refreshOffersButton = makeButton(self, 0, 0, 1, 1, "Refresh Offers", TQ_DebugWindow.onRefreshOffers, "warning")

    self.refreshAllButton = makeButton(self, 16, self.height - 40, 94, 26, "Refresh All", TQ_DebugWindow.refreshData, "default")
    self.repairQuestItemsButton = makeButton(self, 118, self.height - 40, 118, 26, "Repair Items", TQ_DebugWindow.onRepairQuestItems, "info")
    self.closeButton = makeButton(self, self.width - 108, self.height - 40, 92, 26, "Close", TQ_DebugWindow.close, "muted")
    self.topCloseButton = makeButton(self, self.width - 27, 3, 21, 18, "X", TQ_DebugWindow.close, "danger")

    self:applyLayout()
    self:refreshData()
end

function TQ_DebugWindow:applyLayout()
    self.minimumWidth = self.minimumWidth or 760
    self.minimumHeight = self.minimumHeight or 520
    self.width = math.max(self.minimumWidth, self.width)
    self.height = math.max(self.minimumHeight, self.height)

    self.bodyX = 16
    self.bodyY = 36
    self.bodyW = self.width - 32
    self.bodyH = self.height - 88

    self.leftW = math.max(320, math.floor((self.bodyW - 14) * 0.50))
    self.rightW = self.bodyW - self.leftW - 14
    self.leftX = self.bodyX
    self.rightX = self.leftX + self.leftW + 14

    self.listTop = self.bodyY + 48
    self.npcListX = self.leftX
    self.npcListY = self.listTop
    self.npcListW = self.leftW
    self.npcListH = self.bodyH - 104

    self.factionListX = self.rightX
    self.factionListY = self.listTop
    self.factionListW = self.rightW
    self.factionListH = math.max(180, self.bodyH - 186)

    local buttonY = self.npcListY + self.npcListH + 10
    setChildBounds(self.npcList, self.npcListX, self.npcListY, self.npcListW, self.npcListH)
    setChildBounds(self.teleportButton, self.leftX, buttonY, 94, 26)
    setChildBounds(self.rerollSpawnButton, self.leftX + 102, buttonY, 116, 26)
    setChildBounds(self.refreshNPCButton, self.leftX + 226, buttonY, 104, 26)

    local repButtonY = self.factionListY + self.factionListH + 10
    local smallW = 42
    setChildBounds(self.factionList, self.factionListX, self.factionListY, self.factionListW, self.factionListH)
    setChildBounds(self.repMinusFiveButton, self.rightX, repButtonY, smallW, 26)
    setChildBounds(self.repMinusOneButton, self.rightX + 48, repButtonY, smallW, 26)
    setChildBounds(self.repPlusOneButton, self.rightX + 96, repButtonY, smallW, 26)
    setChildBounds(self.repPlusFiveButton, self.rightX + 144, repButtonY, smallW, 26)
    setChildBounds(self.discoverFactionButton, self.rightX + 200, repButtonY, 88, 26)
    setChildBounds(self.refreshContactsButton, self.rightX, repButtonY + 36, math.min(152, self.rightW), 26)
    setChildBounds(self.refreshOffersButton, self.rightX + 160, repButtonY + 36, math.min(140, self.rightW - 160), 26)

    setChildBounds(self.refreshAllButton, 16, self.height - 40, 94, 26)
    setChildBounds(self.repairQuestItemsButton, 118, self.height - 40, 118, 26)
    setChildBounds(self.closeButton, self.width - 108, self.height - 40, 92, 26)
    setChildBounds(self.topCloseButton, self.width - 27, 3, 21, 18)
end

function TQ_DebugWindow:setStatus(text)
    self.statusText = tostring(text or "")
end

function TQ_DebugWindow:getSelectedNPC()
    local row = selectedRow(self.npcList)
    return row and row.npc or nil
end

function TQ_DebugWindow:getSelectedFaction()
    local row = selectedRow(self.factionList)
    return row and row.faction or nil
end

function TQ_DebugWindow:refreshData()
    self:refreshNPCs()
    self:refreshFactions()
end

function TQ_DebugWindow:refreshNPCs()
    if not self.npcList then
        return
    end

    local selectedId = nil
    local selected = self:getSelectedNPC()
    if selected then
        selectedId = tostring(selected.id or "")
    end

    self.npcList:clear()
    self.npcEntries = {}

    local api = npcApi()
    if api and api.getNPCs then
        for _, npc in ipairs(api.getNPCs() or {}) do
            local spawn = api.getNPCSpawn and api.getNPCSpawn(npc) or npc.spawn
            local entry = { npc = npc, spawn = spawn }
            table.insert(self.npcEntries, entry)
            self.npcList:addItem(tostring(npc.name or npc.id or "NPC"), entry)
        end
    end

    if #self.npcEntries == 0 then
        self.npcList:addItem("No NPCs registered", { empty = true })
    end

    self.npcList.selected = 1
    for index, row in ipairs(self.npcList.items or {}) do
        if row.item and row.item.npc and tostring(row.item.npc.id or "") == selectedId then
            self.npcList.selected = index
            break
        end
    end
end

function TQ_DebugWindow:refreshFactions()
    if not self.factionList then
        return
    end

    local selectedId = nil
    local selected = self:getSelectedFaction()
    if selected then
        selectedId = tostring(selected.id or "")
    end

    self.factionList:clear()
    self.factionEntries = {}

    for _, faction in ipairs(TrueQuests.getFactions and TrueQuests.getFactions() or {}) do
        local rep = TrueQuests.Factions and TrueQuests.Factions.getReputation and TrueQuests.Factions.getReputation(self.player, faction.id) or 0
        local discovered = TrueQuests.Factions and TrueQuests.Factions.isFactionDiscovered and TrueQuests.Factions.isFactionDiscovered(self.player, faction.id) or false
        local entry = { faction = faction, reputation = rep, discovered = discovered }
        table.insert(self.factionEntries, entry)
        self.factionList:addItem(tostring(faction.name or faction.id or "Faction"), entry)
    end

    if #self.factionEntries == 0 then
        self.factionList:addItem("No factions registered", { empty = true })
    end

    self.factionList.selected = 1
    for index, row in ipairs(self.factionList.items or {}) do
        if row.item and row.item.faction and tostring(row.item.faction.id or "") == selectedId then
            self.factionList.selected = index
            break
        end
    end
end

function TQ_DebugWindow:onTeleportNPC()
    local npc = self:getSelectedNPC()
    if not npc then
        self:setStatus("Select an NPC first.")
        return
    end

    local api = npcApi()
    local spawn = api and api.getNPCSpawn and api.getNPCSpawn(npc) or npc.spawn
    if not spawn then
        self:setStatus("NPC has no spawn point.")
        return
    end

    if teleportPlayer(self.player, spawn) then
        self:setStatus("Teleported to " .. tostring(npc.name or npc.id) .. " at " .. formatSpawn(spawn) .. ".")
    else
        self:setStatus("Teleport failed.")
    end
end

function TQ_DebugWindow:onRerollNPCSpawn()
    local npc = self:getSelectedNPC()
    local api = npcApi()
    if not npc or not api or not api.Registry or not api.Registry.clearNPCSpawnSelection or not api.Registry.selectNPCSpawn then
        self:setStatus("Random spawn API is not available.")
        return
    end

    api.Registry.clearNPCSpawnSelection(npc)
    local spawn = api.Registry.selectNPCSpawn(npc)
    if api.Save and api.Save.transmit then
        api.Save.transmit()
    end

    self:refreshNPCs()
    self:setStatus("Spawn rerolled for " .. tostring(npc.name or npc.id) .. ": " .. formatSpawn(spawn) .. ".")
end

function TQ_DebugWindow:onChangeReputation(amount)
    local faction = self:getSelectedFaction()
    if not faction or not TrueQuests.Factions or not TrueQuests.Factions.addReputation then
        self:setStatus("Select a faction first.")
        return
    end

    local delta = tonumber(amount) or 0
    TrueQuests.Factions.addReputation(self.player, faction.id, delta)
    self:refreshFactions()
    self:setStatus("Reputation " .. tostring(faction.name or faction.id) .. ": " .. (delta >= 0 and "+" or "") .. tostring(delta) .. ".")
end

function TQ_DebugWindow:onDiscoverFaction()
    local faction = self:getSelectedFaction()
    if not faction or not TrueQuests.Factions or not TrueQuests.Factions.discoverFaction then
        self:setStatus("Select a faction first.")
        return
    end

    local changed = TrueQuests.Factions.discoverFaction(self.player, faction.id)
    self:refreshFactions()
    self:setStatus(tostring(faction.name or faction.id) .. (changed and " discovered." or " was already discovered."))
end

function TQ_DebugWindow:onRefreshContacts()
    if TrueQuests.Factions and TrueQuests.Factions.ensureActiveContacts then
        TrueQuests.Factions.ensureActiveContacts(self.player, true)
        self:setStatus("Active contacts refreshed.")
    else
        self:setStatus("Faction contact API is not available.")
    end
end

function TQ_DebugWindow:onRefreshOffers()
    if TrueQuests.QuestManager and TrueQuests.QuestManager.resetOfferCache then
        TrueQuests.QuestManager.resetOfferCache(self.player)
        self:setStatus("Offer cache refreshed.")
    else
        self:setStatus("Quest offer API is not available.")
    end
end

function TQ_DebugWindow:onRepairQuestItems()
    if TrueQuests.QuestItems and TrueQuests.QuestItems.ensureForPlayer then
        local changed = TrueQuests.QuestItems.ensureForPlayer(self.player)
        self:setStatus(changed and "Quest items repaired or respawn queued." or "No quest item repair needed nearby.")
    else
        self:setStatus("Quest item API is not available.")
    end
end

function TQ_DebugWindow.drawNPCItem(list, y, item, alt)
    local entry = item and item.item or {}
    local rowX = 0
    local rowW = list.width - 6
    local rowH = list.itemheight - 2

    if list.selected == item.index then
        list:drawRect(rowX, y, rowW, rowH, TQ_UITheme.argb("selected", 0.84))
    elseif alt then
        list:drawRect(rowX, y, rowW, rowH, TQ_UITheme.argb("rowAlt", 0.52))
    else
        list:drawRect(rowX, y, rowW, rowH, TQ_UITheme.argb("listBg", 0.76))
    end
    list:drawRectBorder(rowX, y, rowW, rowH, TQ_UITheme.argb("borderSoft", 0.86))

    if entry.empty then
        local label = npcApi() and "No NPCs registered." or "TrueNPCFramework is not loaded."
        list:drawText(label, rowX + 12, y + 20, 0.70, 0.75, 0.76, 1, UIFont.Small)
        return y + list.itemheight
    end

    local npc = entry.npc or {}
    local title = tostring(npc.name or npc.id or "NPC")
    local faction = factionNameFor(npc.factionId)
    local spawn = formatSpawn(entry.spawn)

    list:drawText(TQ_UITheme.truncate(title, rowW - 24, UIFont.Small), rowX + 12, y + 7, 0.96, 0.91, 0.79, 1, UIFont.Small)
    list:drawText(TQ_UITheme.truncate(faction, rowW - 24, UIFont.Small), rowX + 12, y + 25, 0.58, 0.63, 0.65, 1, UIFont.Small)
    list:drawText(TQ_UITheme.truncate(spawn, rowW - 24, UIFont.Small), rowX + 12, y + 42, 0.86, 0.88, 0.84, 1, UIFont.Small)

    return y + list.itemheight
end

function TQ_DebugWindow.drawFactionItem(list, y, item, alt)
    local entry = item and item.item or {}
    local rowX = 0
    local rowW = list.width - 6
    local rowH = list.itemheight - 2

    if list.selected == item.index then
        list:drawRect(rowX, y, rowW, rowH, TQ_UITheme.argb("selected", 0.84))
    elseif alt then
        list:drawRect(rowX, y, rowW, rowH, TQ_UITheme.argb("rowAlt", 0.52))
    else
        list:drawRect(rowX, y, rowW, rowH, TQ_UITheme.argb("listBg", 0.76))
    end
    list:drawRectBorder(rowX, y, rowW, rowH, TQ_UITheme.argb("borderSoft", 0.86))

    if entry.empty then
        list:drawText("No factions registered.", rowX + 12, y + 16, 0.70, 0.75, 0.76, 1, UIFont.Small)
        return y + list.itemheight
    end

    local faction = entry.faction or {}
    local title = tostring(faction.name or faction.id or "Faction")
    local id = tostring(faction.id or "")
    local rep = tostring(entry.reputation or 0)
    local state = entry.discovered and "discovered" or "unknown"

    list:drawText(TQ_UITheme.truncate(title, rowW - 88, UIFont.Small), rowX + 12, y + 8, 0.96, 0.91, 0.79, 1, UIFont.Small)
    list:drawText(TQ_UITheme.truncate(id .. " / " .. state, rowW - 88, UIFont.Small), rowX + 12, y + 28, 0.58, 0.63, 0.65, 1, UIFont.Small)
    TQ_UITheme.drawPill(list, rowX + rowW - 72, y + 14, 58, 22, rep, "blue")

    return y + list.itemheight
end

function TQ_DebugWindow:drawChrome()
    TQ_UITheme.drawPanel(self, 0, 0, self.width, self.height, "windowBg", "border")
    self:drawRect(1, 1, self.width - 2, 23, 0.96, 0.095, 0.105, 0.125)
    self:drawRect(1, 24, self.width - 2, 1, 0.92, 0.30, 0.36, 0.42)
    self:drawText("TRUE QUESTS DEBUG", 10, 6, 0.96, 0.91, 0.79, 1, UIFont.Small)
    self:drawRect(self.width - 18, self.height - 5, 13, 1, 0.80, 0.36, 0.41, 0.46)
    self:drawRect(self.width - 13, self.height - 10, 8, 1, 0.80, 0.36, 0.41, 0.46)
    self:drawRect(self.width - 8, self.height - 15, 3, 1, 0.80, 0.36, 0.41, 0.46)
end

function TQ_DebugWindow:prerender()
    self:applyLayout()
    self:drawChrome()

    TQ_UITheme.drawPanel(self, self.bodyX, self.bodyY, self.leftW, self.bodyH, "panelBg", "border")
    TQ_UITheme.drawAccent(self, self.bodyX, self.bodyY, 4, self.bodyH, "blue")
    self:drawText("NPC TELEPORT", self.bodyX + 16, self.bodyY + 10, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    self:drawText("Select a registered NPC and jump to its current spawn.", self.bodyX + 16, self.bodyY + 31, 0.58, 0.63, 0.65, 1, UIFont.Small)

    TQ_UITheme.drawPanel(self, self.rightX, self.bodyY, self.rightW, self.bodyH, "panelBg", "border")
    TQ_UITheme.drawAccent(self, self.rightX, self.bodyY, 4, self.bodyH, "green")
    self:drawText("FACTION STATE", self.rightX + 16, self.bodyY + 10, 0.96, 0.91, 0.79, 1, UIFont.Medium)
    self:drawText("Adjust reputation and reveal factions for UI testing.", self.rightX + 16, self.bodyY + 31, 0.58, 0.63, 0.65, 1, UIFont.Small)

    if self.statusText and self.statusText ~= "" then
        self:drawText(TQ_UITheme.truncate(self.statusText, self.width - 360, UIFont.Small), 246, self.height - 34, 0.70, 0.75, 0.76, 1, UIFont.Small)
    end
end

function TQ_DebugWindow:close()
    self:removeFromUIManager()
    if TQ_DebugWindow.instance == self then
        TQ_DebugWindow.instance = nil
    end
end

function TQ_DebugWindow:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.resizable = true
    o.moveWithMouse = true
    o.statusText = "Ready."
    TQ_UITheme.applyWindow(o)
    return o
end

function TQ_DebugWindow.Open(player)
    if not player then
        return nil
    end

    if TQ_DebugWindow.instance then
        if TQ_DebugWindow.instance.bringToTop then
            TQ_DebugWindow.instance:bringToTop()
        end
        return TQ_DebugWindow.instance
    end

    local width = 820
    local height = 560
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2

    local window = TQ_DebugWindow:new(x, y, width, height, player)
    window:initialise()
    window:addToUIManager()
    TQ_DebugWindow.instance = window
    return window
end

function TQ_DebugWindow.Toggle(player)
    if TQ_DebugWindow.instance then
        TQ_DebugWindow.instance:close()
        return nil
    end

    return TQ_DebugWindow.Open(player)
end
