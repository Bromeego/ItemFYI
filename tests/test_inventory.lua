_G = _G or _ENV

local function Noop() end

local function NewRegion()
    return {
        SetAllPoints = Noop,
        SetColorTexture = Noop,
        SetPoint = Noop,
        SetTexture = Noop,
        SetBlendMode = Noop,
        SetTexCoord = Noop,
        SetTextColor = Noop,
        SetText = function(self, value) self.text = value end,
        GetText = function(self) return self.text end,
        SetWidth = Noop,
        SetJustifyH = Noop,
        SetWordWrap = Noop,
    }
end

local eventFrame
local createdFrames = {}
local function NewFrame(name)
    local frame = {
        name = name,
        scripts = {},
        attributes = {},
        shown = false,
        width = 42,
        height = 42,
        registeredEvents = {},
    }
    function frame:RegisterEvent(event) self.registeredEvents[event] = true end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:HookScript() end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:GetSize() return self.width, self.height end
    function frame:SetFrameLevel(level) self.frameLevel = level end
    function frame:GetFrameLevel() return self.frameLevel or 1 end
    function frame:SetClipsChildren() end
    function frame:SetWidth(width) self.width = width end
    function frame:SetOrientation() end
    function frame:SetClampedToScreen() end
    function frame:SetMovable() end
    function frame:EnableMouse() end
    function frame:RegisterForClicks(...) self.registeredClicks = { ... } end
    function frame:RegisterForDrag() end
    function frame:Hide() self.shown = false end
    function frame:Show() self.shown = true end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown end
    function frame:SetAlpha(value) self.alpha = value end
    function frame:CreateTexture() return NewRegion() end
    function frame:CreateFontString() return NewRegion() end
    function frame:SetAttribute(key, value) self.attributes[key] = value end
    function frame:SetText(value) self.text = value end
    function frame:SetChecked(value) self.checked = value end
    function frame:GetChecked() return self.checked end
    function frame:SetEnabled(value) self.enabled = value end
    function frame:SetMinMaxValues() end
    function frame:SetValueStep() end
    function frame:SetObeyStepOnDrag() end
    function frame:SetValue() end
    function frame:ClearAllPoints() end
    function frame:SetAllPoints() end
    function frame:SetPoint(point, _, relativePoint, x, y)
        self.point = { point, relativePoint, x, y }
    end
    function frame:GetPoint()
        local point = self.point or { "CENTER", "CENTER", 0, -120 }
        return point[1], UIParent, point[2], point[3], point[4]
    end
    function frame:GetRect() return 100, 200, self.width, self.height end
    function frame:GetName() return self.name end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    function frame:SetOwner() end
    function frame:ClearLines() end
    function frame:NumLines() return 0 end
    function frame:SetBagItem() end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

UIParent = { GetRect = function() return 0, 0, 1920, 1080 end }
CreateFrame = function(_, name)
    return NewFrame(name)
end

local inCombat = false
InCombatLockdown = function() return inCombat end
IsAltKeyDown = function() return false end
IsControlKeyDown = function() return false end
wipe = function(target) for key in pairs(target) do target[key] = nil end end

local timers = {}
local timerImmediate = false
C_Timer = {
    After = function(delay, callback)
        if timerImmediate then
            callback()
            return
        end
        timers[#timers + 1] = { delay = delay, callback = callback }
    end,
}

local function FireTimers()
    local pending = timers
    timers = {}
    for index = 1, #pending do
        pending[index].callback()
    end
end

local function FireOneTimer()
    local timer = table.remove(timers, 1)
    if timer then
        timer.callback()
    end
end

local bags = {}
local bagSlotCounts = {}
local itemData = {}
local tooltipByItem = {}
local tooltipComplete = {}
local appearanceCollected = false
local mountCollected = false
local itemUsable = true
local activeQuests = {}

local function SetSlot(bag, slot, itemID, stackCount, extra)
    bags[bag] = bags[bag] or {}
    if itemID then
        extra = extra or {}
        bags[bag][slot] = {
            itemID = itemID,
            hyperlink = extra.hyperlink or ("item:" .. itemID),
            iconFileID = extra.icon or 1,
            stackCount = stackCount or 1,
            hasLoot = extra.hasLoot == true,
            isLocked = extra.isLocked == true,
        }
        bagSlotCounts[bag] = math.max(bagSlotCounts[bag] or slot, slot)
    else
        bags[bag][slot] = nil
    end
end

C_Item = {
    GetItemInfo = function(itemID)
        local data = itemData[itemID]
        if not data then
            return nil
        end
        return data.name, "item:" .. itemID, 1, 1, 1, data.itemType or "Miscellaneous",
            data.itemSubType or "Other", 1, data.equipLocation or "", data.icon or 1, 0,
            data.classID, data.subclassID
    end,
    IsUsableItem = function() return itemUsable end,
    RequestLoadItemDataByID = Noop,
}
C_Container = {
    GetContainerNumSlots = function(bag)
        return bagSlotCounts[bag] or 0
    end,
    GetContainerItemInfo = function(bag, slot)
        return bags[bag] and bags[bag][slot]
    end,
    GetContainerItemID = function(bag, slot)
        local info = bags[bag] and bags[bag][slot]
        return info and info.itemID
    end,
    GetContainerItemLink = function(bag, slot)
        local info = bags[bag] and bags[bag][slot]
        return info and info.hyperlink
    end,
    GetContainerItemQuestInfo = function(bag, slot)
        local info = bags[bag] and bags[bag][slot]
        if info and info.itemID == 142210 then
            return { questID = 44767, isActive = activeQuests[44767] == true }
        end
        return nil
    end,
}
C_TooltipInfo = {
    GetBagItem = function(bag, slot)
        local info = bags[bag] and bags[bag][slot]
        if not info then
            return { lines = {} }
        end
        if tooltipComplete[info.itemID] == false then
            return { lines = {} }
        end
        local tooltip = tooltipByItem[info.itemID]
        if type(tooltip) == "table" then
            return { lines = tooltip }
        end
        return { lines = { { leftText = tooltip or "" } } }
    end,
}
C_MountJournal = {
    GetMountFromItem = function(itemID)
        return itemID == 101 and 9001 or nil
    end,
    GetMountInfoByID = function()
        return "Test Mount", 1, 1, false, true, 1, false, false, nil, false, mountCollected
    end,
}
C_ToyBox = {}
C_PetJournal = {}
C_QuestLog = {
    IsQuestFlaggedCompleted = function() return false end,
    IsOnQuest = function(questID) return activeQuests[questID] == true end,
}
C_TransmogCollection = {
    PlayerHasTransmogByItemInfo = function()
        return appearanceCollected
    end,
}
Enum = {
    ItemClass = { Recipe = 9 },
    PlayerInteractionType = {
        TradePartner = 1,
        Banker = 8,
        MailInfo = 17,
    },
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
GameTooltip = {
    SetOwner = Noop,
    GetOwner = function() return nil end,
    SetBagItem = Noop,
    AddLine = Noop,
    Show = Noop,
    Hide = Noop,
}
BattlePetTooltip = { Hide = Noop, IsShown = function() return false end }
BattlePetToolTip_Hide = Noop
ActionButtonSpellAlertManager = { ShowAlert = Noop, HideAlert = Noop }
SlashCmdList = {}
LibStub = function()
    return {
        RegisterFrame = Noop,
        SetDontResize = Noop,
        RegisterCoordinates = Noop,
        RepositionFrame = Noop,
        framesDB = {},
    }
end
EditModeManagerFrame = NewFrame("EditModeManagerFrame")
Settings = {
    RegisterCanvasLayoutCategory = function()
        return { ID = "ItemFYI", GetID = function(self) return self.ID end }
    end,
    RegisterAddOnCategory = Noop,
    OpenToCategory = Noop,
}

itemData[100] = { name = "Satchel" }
itemData[200] = { name = "Other Satchel" }
itemData[268650] = { name = "Ascendant Voidshard" }
itemData[789] = { name = "Warband Appearance", itemType = "Armor", itemSubType = "Cosmetic",
    equipLocation = "INVTYPE_WEAPON", classID = 4 }
itemData[107] = { name = "Test Recipe", itemType = "Recipe", classID = 9 }
itemData[113] = { name = "Test Curio" }
itemData[1200] = { name = "Plain Crafting Reagent" }
itemData[6600] = { name = "Unknown Legacy Turn-in" }
itemData[18945] = { name = "Dark Iron Residue", itemType = "Quest", classID = 12 }
itemData[142210] = { name = "Celestial Invitation", itemType = "Quest", classID = 12 }
itemData[101] = { name = "Test Mount" }
tooltipByItem[101] = "Use: Teaches you how to summon this mount."
tooltipByItem[100] = "Use: Open the satchel."
tooltipByItem[200] = "Use: Open the crate."
tooltipByItem[268650] = "Use: Combine 5 shards."
tooltipByItem[789] = "Use: Add this appearance to your Warband collection."
tooltipByItem[107] = {
    { leftText = "Use: Teaches you how to craft a test item.", leftColor = { r = 0, g = 1, b = 0 } },
    { leftText = "Requires Northrend Leatherworking (75)", leftColor = { r = 1, g = 0.125, b = 0.125 } },
}
tooltipByItem[113] = "Rank 2/4\nUse: Add this Curio to your companion's collection."
tooltipByItem[1200] = "Plain Crafting Reagent\nCrafting Reagent"
tooltipByItem[6600] = "Unknown Legacy Turn-in"
tooltipByItem[18945] = "Dark Iron Residue"
tooltipByItem[142210] = "Celestial Invitation\nThis Item Begins a Quest"

local addon = {}
assert(loadfile("Core.lua"))("ItemFYI", addon)
assert(loadfile("Rules.lua"))("ItemFYI", addon)
assert(loadfile("Detection.lua"))("ItemFYI", addon)
assert(loadfile("Inventory.lua"))("ItemFYI", addon)
assert(loadfile("UI.lua"))("ItemFYI", addon)
assert(loadfile("Skinning.lua"))("ItemFYI", addon)
assert(loadfile("EditMode.lua"))("ItemFYI", addon)
assert(loadfile("Settings.lua"))("ItemFYI", addon)

eventFrame = addon.eventFrame
eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "ItemFYI")
timerImmediate = true
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
timerImmediate = false
timers = {}

local function Metrics()
    return addon:GetMetrics()
end

local function ScanNow(reason)
    local previous = timerImmediate
    timerImmediate = true
    addon:ScanBags(reason or "login")
    timerImmediate = false
    timers = {}
end

-- Startup bag events must respect the login grace instead of starting early.
addon.startupScanPending = true
addon:ScheduleScan("login", 2.5)
assert(timers[#timers].delay >= 2.5, "login scan should be deferred")
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 0)
assert(timers[#timers].delay >= 2.5,
    "startup BAG_UPDATE must not bypass the loading grace")
FireTimers()
assert(not addon.startupScanPending, "starting the scan must clear the grace flag")
timers = {}

-- Burst of bag events produces one reconciliation.
SetSlot(0, 1, 100, 1, { hasLoot = true })
addon:ResetMetrics()
timers = {}
for _ = 1, 8 do
    eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 0)
    eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
end
assert(#timers > 1, "bag bursts schedule delayed work rather than scanning immediately")
local burstGeneration = addon.scanGeneration
FireTimers()
assert(addon.scanGeneration == burstGeneration, "the coalesced burst should keep the latest intent")
assert(Metrics().workTicks == 1, "a coalesced bag burst should process in one work tick")
assert(addon.current and addon.current.itemID == 100, "the coalesced burst should still find the item")

-- Unrelated bag update performs no tooltip work for unchanged slots.
SetSlot(1, 1, 200, 1, { hasLoot = true })
bagSlotCounts[1] = 1
ScanNow("login")
addon:ResetMetrics()
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 1)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
FireTimers()
assert(Metrics().tooltipSnapshots == 0, "unchanged slots must not reread tooltips")
assert(Metrics().itemsClassified == 0, "unchanged slots must not be reclassified")
assert(Metrics().slotsChanged == 0, "identical fingerprints are not slot changes")

-- Only dirty bags are reconciled.
local inspected = Metrics().slotsInspected
assert(inspected > 0, "the dirty bag should still be inspected")
assert(inspected <= (bagSlotCounts[1] or 0), "clean bags must not be reconciled")

-- One changed slot reclassifies only that slot and directly dependent items.
SetSlot(0, 1, 268650, 3)
SetSlot(1, 1, 268650, 2)
ScanNow("login")
assert(addon.current and addon.current.itemID == 268650, "split stacks at threshold should appear")
addon:ResetMetrics()
SetSlot(0, 1, 268650, 2)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 0)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
FireTimers()
assert(Metrics().tooltipSnapshots == 1, "only the changed stack should reread its tooltip")
assert(Metrics().itemsClassified == 2, "threshold dependents in other bags must be rechecked")
assert(addon.current == nil, "dropping below the split-stack threshold should hide the item")

-- Split-stack thresholds update in both directions.
addon:ResetMetrics()
SetSlot(0, 1, 268650, 3)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 0)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
FireTimers()
assert(addon.current and addon.current.itemID == 268650, "returning to the threshold should restore the item")
assert(Metrics().tooltipSnapshots == 1, "raising a split stack should not rebuild unrelated tooltips")

-- Moving or sorting items cannot leave stale slot state.
SetSlot(0, 1, 100, 1, { hasLoot = true })
SetSlot(0, 2, nil)
SetSlot(1, 1, 200, 1, { hasLoot = true })
ScanNow("login")
assert(addon.current and addon.current.bag == 0 and addon.current.slot == 1,
    "the openable should start in bag 0 slot 1")
SetSlot(0, 2, 100, 1, { hasLoot = true })
SetSlot(0, 1, nil)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 0)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
FireTimers()
assert(addon.current and addon.current.itemID == 100
    and addon.current.bag == 0 and addon.current.slot == 2,
    "a moved item must update its stored slot")
assert(not (addon.slotIndex[0] and addon.slotIndex[0][1]),
    "the vacated slot must leave the inventory index")

-- Opening a cache in-place must not keep the previous item's icon.
itemData[100].icon = 111
itemData[200].icon = 222
SetSlot(0, 1, 100, 1, { hasLoot = true, icon = 111 })
SetSlot(0, 2, nil)
SetSlot(1, 1, nil)
ScanNow("login")
assert(addon.current and addon.current.itemID == 100 and addon.current.icon == 111,
    "the cache icon should appear before it is opened")
SetSlot(0, 1, 200, 1, { hasLoot = true, icon = 222 })
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 0)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
FireTimers()
assert(addon.current and addon.current.itemID == 200 and addon.current.icon == 222,
    "loot that replaces a cache in the same slot must update the button icon")
itemData[100].icon = nil
itemData[200].icon = nil

-- Secure slot actions are invalidated immediately.
appearanceCollected = false
SetSlot(0, 1, nil)
SetSlot(0, 2, nil)
SetSlot(1, 1, nil)
SetSlot(2, 7, 789, 1)
bagSlotCounts[2] = 7
ScanNow("login")
assert(addon.current and addon.current.secureBySlot and addon.current.bag == 2,
    "equippable appearances use a slot-targeted action")
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 2)
assert(addon.current == nil and not addon.button.shown,
    "a changed bag must invalidate a slot-targeted action before reconciliation")
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(addon.current and addon.current.bag == 2,
    "a bag event that left the slot unchanged must restore the slot action")

-- A bag change during combat clears the slot action as soon as combat ends.
ScanNow("login")
assert(addon.current and addon.current.secureBySlot and addon.current.bag == 2,
    "the slot-targeted appearance should be displayed before combat")
inCombat = true
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 3)
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(addon.current and addon.current.bag == 2,
    "an unrelated bag change in combat must keep the slot action")
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
inCombat = true
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 2)
assert(addon.current and addon.current.bag == 2,
    "combat cannot clear the protected slot action")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(addon.current == nil and not addon.button.shown,
    "leaving combat must clear a slot action whose bag changed in combat")
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(addon.current and addon.current.bag == 2,
    "the rescan after combat should restore the slot action")

-- Learning a collectible removes relevant candidates without rebuilding unrelated tooltips.
SetSlot(2, 7, 789, 1)
SetSlot(0, 1, 100, 1, { hasLoot = true })
ScanNow("login")
appearanceCollected = true
addon:ResetMetrics()
eventFrame.scripts.OnEvent(eventFrame, "TRANSMOG_COLLECTION_UPDATED")
FireTimers()
assert(Metrics().tooltipSnapshots == 0, "collection updates must not rebuild unrelated tooltips")
assert(addon.current and addon.current.itemID == 100,
    "learning an appearance should leave unrelated candidates in place")
appearanceCollected = false

-- Mixed collection updates must refresh each affected category.
SetSlot(0, 2, 101, 1)
ScanNow("login")
assert(addon.current and addon.current.itemID == 101, "an uncollected mount should outrank the satchel")
mountCollected = true
appearanceCollected = true
addon:ResetMetrics()
eventFrame.scripts.OnEvent(eventFrame, "NEW_MOUNT_ADDED", 9001)
eventFrame.scripts.OnEvent(eventFrame, "TRANSMOG_COLLECTION_UPDATED")
FireTimers()
assert(Metrics().tooltipSnapshots == 0, "mixed collection updates must not refetch tooltips")
assert(addon.current and addon.current.itemID == 100,
    "learning a mount and an appearance together should drop both collectibles")
mountCollected = false
appearanceCollected = false
SetSlot(0, 2, nil)

-- Accepting a quest updates an FYI even when the quest starter remains
-- in the same bag slot. Refresh only the affected tooltip, not every bag.
addon:ClearInventoryState()
SetSlot(0, 1, 142210, 1)
SetSlot(0, 2, nil)
SetSlot(1, 1, nil)
SetSlot(2, 7, nil)
ScanNow("login")
assert(addon.current and addon.current.itemID == 142210,
    "an available quest starter should initially appear")
assert(addon.slotIndex[0][1].snapshot.questStarter == true,
    "the initial tooltip must retain quest-starter detection")
addon:ResetMetrics()
activeQuests[44767] = true
eventFrame.scripts.OnEvent(eventFrame, "QUEST_ACCEPTED", 44767)
FireTimers()
assert(addon.current == nil,
    "accepting the quest must clear the FYI without using the item a second time")
assert(Metrics().tooltipSnapshots == 1 and Metrics().slotsInspected == 0,
    "quest acceptance must only reread the quest item's tooltip, not scan bags")
assert(addon.slotIndex[0][1].questStarterKnown == true,
    "a hidden quest starter must remain eligible for a later abandonment")
addon:ResetMetrics()
activeQuests[44767] = nil
eventFrame.scripts.OnEvent(eventFrame, "QUEST_REMOVED", 44767)
FireTimers()
assert(addon.current and addon.current.itemID == 142210,
    "abandoning an accepted quest must restore the still-held quest starter")
assert(Metrics().tooltipSnapshots == 1 and Metrics().slotsInspected == 0,
    "quest abandonment must refresh just the starter tooltip, not inventory")

-- Some active-quest tooltips lose their quest-starter line entirely. The
-- remembered starter must still be reconsidered after the quest is abandoned.
tooltipByItem[142210] = "Celestial Invitation\nQuest already accepted"
activeQuests[44767] = true
addon:ResetMetrics()
eventFrame.scripts.OnEvent(eventFrame, "QUEST_ACCEPTED", 44767)
FireTimers()
assert(addon.current == nil and addon.slotIndex[0][1].questStarterKnown == true
    and addon.slotIndex[0][1].snapshot.questStarter == false,
    "a changed active-quest tooltip must not lose the original starter identity")
tooltipByItem[142210] = "Celestial Invitation\nThis Item Begins a Quest"
activeQuests[44767] = nil
addon:ResetMetrics()
eventFrame.scripts.OnEvent(eventFrame, "QUEST_REMOVED", 44767)
FireTimers()
assert(addon.current and addon.current.itemID == 142210,
    "abandoning a quest must restore a starter whose tooltip changed while active")
assert(Metrics().slotsInspected == 0 and Metrics().tooltipSnapshots == 1,
    "restoring after a changed tooltip must remain targeted")

SetSlot(0, 1, 100, 1, { hasLoot = true })
addon:ClearInventoryState()
timers = {}
ScanNow("login")

-- Dynamic unmet requirements can become satisfied without changing the item.
SetSlot(0, 1, 107, 1)
SetSlot(2, 7, nil)
ScanNow("login")
assert(addon.current == nil, "a recipe with an unmet requirement should stay hidden")
tooltipByItem[107][2].leftColor = { r = 1, g = 1, b = 1 }
addon:ResetMetrics()
eventFrame.scripts.OnEvent(eventFrame, "SKILL_LINES_CHANGED")
FireTimers()
assert(addon.current and addon.current.itemID == 107,
    "character-state changes must recheck restriction tooltips")
assert(Metrics().tooltipSnapshots == 1, "only restriction items should refetch tooltips")

-- A fully populated non-actionable tooltip with no Use: line must not retry.
SetSlot(0, 1, 1200, 1)
SetSlot(0, 2, nil)
SetSlot(1, 1, nil)
SetSlot(2, 7, nil)
addon:ClearInventoryState()
timers = {}
addon:ResetMetrics()
addon:ScanBags("login")
local reagentGuard = 0
while (addon:HasInventoryWork() or #timers > 0) and reagentGuard < 50 do
    FireOneTimer()
    reagentGuard = reagentGuard + 1
end
assert(reagentGuard < 50, "normal reagent scan should finish quickly")
assert(Metrics().tooltipSnapshots == 1,
    "complete non-actionable reagents must not repeatedly request tooltip info")
assert(Metrics().incompleteTooltipReads == 0 and Metrics().tooltipRetriesScheduled == 0,
    "a normal no-Use tooltip must be cached as complete")
assert(#addon:GetIncompleteTooltipRows() == 0,
    "regular reagents must not appear in unresolved tooltip diagnostics")

-- AQ scarabs are deliberately name-only: they are turn-in materials, not
-- bag-use items. All eight should get exactly one tooltip read at login
-- without weakening the Curio retry path that follows this test.
local scarabs = {
    [20858] = "Stone Scarab", [20859] = "Gold Scarab",
    [20860] = "Silver Scarab", [20861] = "Bronze Scarab",
    [20862] = "Crystal Scarab", [20863] = "Clay Scarab",
    [20864] = "Bone Scarab", [20865] = "Ivory Scarab",
}
addon:ClearInventoryState()
timers = {}
local scarabSlot = 0
for itemID, name in pairs(scarabs) do
    scarabSlot = scarabSlot + 1
    itemData[itemID] = { name = name }
    tooltipByItem[itemID] = name
    SetSlot(0, scarabSlot, itemID, 1)
end
addon:ResetMetrics()
addon:ScanBags("login")
local scarabGuard = 0
while (addon:HasInventoryWork() or #timers > 0) and scarabGuard < 100 do
    FireOneTimer()
    scarabGuard = scarabGuard + 1
end
assert(scarabGuard < 100, "eight name-only scarabs must complete the scan")
assert(Metrics().tooltipSnapshots == 8,
    "the eight scarabs should each require exactly one tooltip request")
assert(Metrics().incompleteTooltipReads == 0 and Metrics().tooltipRetriesScheduled == 0,
    "name-only AQ scarabs must not be treated as delayed tooltips")
assert(#addon:GetIncompleteTooltipRows() == 0 and addon.current == nil,
    "AQ scarabs must be absent from incomplete diagnostics and actionable FYIs")
for slot = 1, 8 do
    SetSlot(0, slot, nil)
end
-- Restore the smaller bag size expected by the following single-tick
-- incomplete-tooltip test; otherwise the empty test slots require two ticks.
bagSlotCounts[0] = 2
addon:ClearInventoryState()
timers = {}

-- Quest turn-in material Dark Iron Residue (18945) is name-only too.
-- No Use: line is expected; no duplicate classification or retries.
addon:ClearInventoryState()
timers = {}
SetSlot(0, 1, 18945, 10)
bagSlotCounts[0] = 1
addon:ResetMetrics()
addon:ScanBags("login")
local residueGuard = 0
while (addon:HasInventoryWork() or #timers > 0) and residueGuard < 50 do
    FireOneTimer()
    residueGuard = residueGuard + 1
end
assert(residueGuard < 50, "name-only quest material scan should finish promptly")
assert(Metrics().tooltipSnapshots == 1 and Metrics().itemsClassified == 1,
    "Dark Iron Residue should only be read and classified once")
assert(Metrics().incompleteTooltipReads == 0 and Metrics().tooltipRetriesScheduled == 0,
    "Dark Iron Residue must not cause false missing-tooltip retries")
assert(#addon:GetIncompleteTooltipRows() == 0 and addon.current == nil,
    "Dark Iron Residue must be neither unresolved nor an actionable FYI")
SetSlot(0, 1, nil)
bagSlotCounts[0] = 2
addon:ClearInventoryState()
timers = {}

-- A previously unknown name-only legacy item must stop retrying after
-- two follow-ups. This is generic: no item ID was added to the exemption list.
addon:ClearInventoryState()
timers = {}
SetSlot(0, 1, 6600, 1)
addon:ResetMetrics()
addon:ScanBags("login")
local unknownGuard = 0
while (addon:HasInventoryWork() or #timers > 0) and unknownGuard < 50 do
    FireOneTimer()
    unknownGuard = unknownGuard + 1
end
assert(unknownGuard < 50, "a stable name-only item should finish its bounded scan")
assert(Metrics().tooltipSnapshots == 3 and Metrics().tooltipRetriesScheduled == 2,
    "new name-only items should get two follow-ups, not four")
assert(Metrics().incompleteTooltipReads == 3,
    "a still-name-only item must remain marked incomplete")
assert(addon.current == nil and #addon:GetIncompleteTooltipRows() == 1,
    "a name-only item must not be classified actionable without evidence")
SetSlot(0, 1, nil)
addon:ClearInventoryState()
timers = {}

-- Incomplete tooltips are not permanently cached, and retries are targeted and bounded.
SetSlot(0, 1, 113, 1)
SetSlot(0, 2, nil)
SetSlot(1, 1, nil)
SetSlot(2, 7, nil)
tooltipComplete[113] = false
addon.workPerTick = 1
addon:ResetMetrics()
addon:ScanBags("login")
assert(Metrics().tooltipSnapshots >= 1, "the incomplete slot should be read")
local firstIncomplete = Metrics().tooltipSnapshots
assert(#timers >= 1, "incomplete tooltips should queue a targeted retry")
local incompleteRows = addon:GetIncompleteTooltipRows()
assert(#incompleteRows == 1 and incompleteRows[1].itemID == 113
    and incompleteRows[1].reads == 1,
    "performance diagnostics should identify the actual incomplete item and read count")
SlashCmdList.ITEMFYI("perfitems")
addon:ScanBags("settings changed")
assert(#timers >= 1, "filter-only work must not drop tooltip retries")
FireOneTimer()
assert(Metrics().tooltipSnapshots > firstIncomplete, "retries should reread only the waiting slot")
assert(Metrics().tooltipSnapshots <= 5, "tooltip retries must be bounded")
tooltipComplete[113] = nil
while #timers > 0 do
    FireOneTimer()
end
assert(addon.current and addon.current.itemID == 113, "a later complete tooltip should become a candidate")
assert(#addon:GetIncompleteTooltipRows() == 0,
    "resolved item tooltips must disappear from the diagnostics")
addon.workPerTick = nil

-- Looted curios whose Use: line arrives late must still appear.
SetSlot(0, 1, nil)
SetSlot(0, 2, nil)
SetSlot(1, 1, nil)
SetSlot(2, 7, nil)
ScanNow("login")
tooltipByItem[113] = "Test Curio"
SetSlot(0, 1, 113, 1)
addon.pendingItemLoads = {}
local loadRequests = 0
C_Item.RequestLoadItemDataByID = function(itemID)
    loadRequests = loadRequests + 1
end
addon:ResetMetrics()
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 0)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
FireTimers()
assert(not addon.current or addon.current.itemID ~= 113,
    "a curio without its Use: line must not be cached as a finished miss")
assert(#timers >= 1, "a name-only curio tooltip should retry the same slot")
assert(not addon.pendingItemLoads[113],
    "a name-only curio must not wait on item-data events that restart the slot")
assert(loadRequests == 1, "item data should be requested once as a tooltip hint")
assert(addon.slotIndex[0][1].snapshot.nameOnly == true,
    "a name-only Curio must use the generic bounded retry path")
local curioGeneration = addon.scanGeneration
eventFrame.scripts.OnEvent(eventFrame, "ITEM_DATA_LOAD_RESULT", 113, true)
assert(addon.scanGeneration == curioGeneration,
    "item-data completion for a name-only curio must not restart inventory work")
FireOneTimer()
assert(addon.current == nil and #timers >= 1,
    "a name-only Curio should still get its second delayed check")
tooltipByItem[113] = "Rank 2/4\nUse: Add this Curio to your companion's collection."
FireTimers()
assert(addon.current and addon.current.itemID == 113 and addon.current.category == "curio",
    "a looted curio should appear once its Use: text is available")
C_Item.RequestLoadItemDataByID = Noop

-- Unrelated item-data events do nothing.
local generation = addon.scanGeneration
local snapshots = Metrics().tooltipSnapshots
eventFrame.scripts.OnEvent(eventFrame, "GET_ITEM_INFO_RECEIVED", 19019, true)
eventFrame.scripts.OnEvent(eventFrame, "ITEM_DATA_LOAD_RESULT", 19019, true)
assert(addon.scanGeneration == generation, "unrelated item-data events must not schedule work")
assert(Metrics().tooltipSnapshots == snapshots, "unrelated item-data events must not read tooltips")

-- Manual force-refresh survives later coalesced events.
addon:ResetMetrics()
SlashCmdList.ITEMFYI("scan")
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 1)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE_DELAYED")
assert(addon.forceRefresh, "a later bag event must not drop a manual refresh")
FireTimers()
assert(Metrics().tooltipSnapshots >= 1, "the surviving manual refresh should refetch tooltips")

-- A force refresh that arrives while work is already active must still rebuild.
SetSlot(0, 1, 100, 1, { hasLoot = true })
SetSlot(0, 2, 200, 1, { hasLoot = true })
SetSlot(1, 1, 268650, 5)
addon.workPerTick = 1
addon:ResetMetrics()
addon:ScanBags("login")
assert(addon.workActive, "the sliced login scan should still be running")
local snapshotsBeforeManual = Metrics().tooltipSnapshots
SlashCmdList.ITEMFYI("scan")
assert(addon.forceRefresh, "manual scan during active work must keep force-refresh intent")
local guard = 0
while (addon:HasInventoryWork() or #timers > 0) and guard < 25 do
    FireOneTimer()
    guard = guard + 1
end
assert(guard < 25, "force refresh during active work must not loop")
assert(not addon.forceRefresh, "the mid-scan refresh must be consumed")
assert(not addon:HasInventoryWork(), "queued work must finish after the mid-scan refresh")
assert(Metrics().tooltipSnapshots > snapshotsBeforeManual,
    "a mid-scan manual refresh should refetch tooltips")
addon.workPerTick = nil

-- Full reconciliation yields across multiple processing ticks.
SetSlot(0, 1, 100, 1, { hasLoot = true })
SetSlot(0, 2, 200, 1, { hasLoot = true })
SetSlot(1, 1, 268650, 5)
addon.workPerTick = 1
addon:ResetMetrics()
local rebuilds = 0
local originalRebuild = addon.RebuildCandidates
addon.RebuildCandidates = function(self, ...)
    rebuilds = rebuilds + 1
    return originalRebuild(self, ...)
end
addon:ScanBags("login")
assert(Metrics().workTicks == 1, "login classification should start with one tick")
assert(Metrics().itemsClassified == 1, "a tick budget of one should classify one item")
assert(addon:HasInventoryWork(), "remaining slots should stay queued")
assert(rebuilds == 0, "a partial login scan should not rebuild the entire candidate UI")
FireOneTimer()
assert(Metrics().workTicks == 2, "queued work should continue on a later tick")
assert(Metrics().maxWorkPerTick == 1, "no tick should exceed the expensive-work budget")
while addon:HasInventoryWork() and #timers > 0 do
    FireOneTimer()
end
assert(addon.current, "the yielded scan should finish with a candidate")
assert(rebuilds == 1, "a multi-tick login scan should rebuild candidates only once")
addon.RebuildCandidates = originalRebuild
addon.workPerTick = nil

-- Automatic login classification runs at one item per paced work tick.
addon:ClearInventoryState()
SetSlot(0, 1, 100, 1, { hasLoot = true })
SetSlot(0, 2, 200, 1, { hasLoot = true })
SetSlot(1, 1, 268650, 5)
timers = {}
addon:ResetMetrics()
addon:ScanBags("login")
assert(addon.initialScanActive, "login scan must use low-impact startup pacing")
assert(#timers > 0 and timers[#timers].delay == 0.04,
    "login scan should space continuation work rather than running every frame")
assert(Metrics().itemsClassified <= 1,
    "the first login tick should classify at most one expensive item")
local pacedGuard = 0
while (addon:HasInventoryWork() or #timers > 0) and pacedGuard < 100 do
    FireOneTimer()
    pacedGuard = pacedGuard + 1
end
assert(pacedGuard < 100 and addon.current,
    "a paced initial scan should still discover actionable items")
assert(not addon.initialScanActive,
    "startup throttling must stop once the scan finishes")
addon:ClearInventoryState()
timers = {}

-- A large inventory must yield during slot indexing, before tooltip work.
-- A bag event during an in-progress reconciliation must not leave stale slots.
addon:ClearInventoryState()
for slot = 1, 25 do
    SetSlot(4, slot, 100, 1, { hasLoot = true })
end
addon.reconcileSlotsPerTick = 3
addon.workPerTick = 1
addon:ResetMetrics()
addon:ScanBags("login")
assert(Metrics().slotsInspected == 3,
    "login bag indexing must stop at its per-tick slot budget")
assert(Metrics().itemsClassified == 0,
    "classification must wait until all dirty bag totals are reconciled")
assert(addon:HasInventoryWork(), "unfinished bag indexing must remain scheduled")

local reconcileGuard = 0
while addon.reconcileBag ~= 4 and reconcileGuard < 50 do
    FireOneTimer()
    reconcileGuard = reconcileGuard + 1
end
assert(addon.reconcileBag == 4, "the large bag must be reconciled across frames")
SetSlot(4, 1, 200, 1, { hasLoot = true })
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 4)
while (addon:HasInventoryWork() or #timers > 0) and reconcileGuard < 250 do
    FireOneTimer()
    reconcileGuard = reconcileGuard + 1
end
assert(reconcileGuard < 250, "mid-reconciliation bag updates must not loop indefinitely")
assert(addon.slotIndex[4][1].itemID == 200,
    "a mid-reconciliation bag update must be revisited before classification")
assert(Metrics().maxWorkPerTick <= 1,
    "bag indexing must not violate the later tooltip budget")
addon.reconcileSlotsPerTick = nil
addon.workPerTick = nil
for slot = 1, 25 do
    SetSlot(4, slot, nil)
end
bagSlotCounts[4] = 0
addon:ClearInventoryState()
ScanNow("login")

-- Entering combat pauses appropriate work safely.
SetSlot(0, 1, 100, 1, { hasLoot = true })
SetSlot(0, 2, 200, 1, { hasLoot = true })
SetSlot(1, 1, 268650, 5)
addon.workPerTick = 1
addon:ResetMetrics()
addon:ScanBags("login")
local classifiedBeforeCombat = Metrics().itemsClassified
inCombat = true
FireOneTimer()
assert(addon.scanPending, "combat should pause queued inventory work")
assert(Metrics().itemsClassified == classifiedBeforeCombat,
    "combat must not continue expensive classification")

-- Leaving combat resumes work without a synchronous hitch.
local classifiedInCombat = Metrics().itemsClassified
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(Metrics().itemsClassified == classifiedInCombat,
    "PLAYER_REGEN_ENABLED must not classify synchronously")
FireTimers()
assert(Metrics().itemsClassified > classifiedInCombat,
    "work paused in combat should resume after a delay")
addon.workPerTick = nil
while addon:HasInventoryWork() or #timers > 0 do
    FireTimers()
end

-- Disabling and re-enabling does not reuse invalid state.
ScanNow("login")
assert(addon.current and addon.slotIndex[0] and addon.slotIndex[0][1],
    "inventory state should exist while enabled")
addon.db.enabled = false
ScanNow("settings changed")
assert(addon.current == nil, "disabling ItemFYI should clear the displayed candidate")
assert(not (addon.slotIndex and addon.slotIndex[0] and addon.slotIndex[0][1]),
    "disabling ItemFYI should drop cached slot eligibility")
SetSlot(0, 1, nil)
SetSlot(0, 2, nil)
SetSlot(1, 1, nil)
addon.db.enabled = true
ScanNow("settings changed")
assert(addon.current == nil, "re-enabling must not revive stale candidates")

local function PetCage(species, name, slot, stack)
    return {
        itemID = 82800,
        uniqueKey = "pet:" .. species,
        category = "pet",
        stackCount = stack or 1,
        link = ("|Hbattlepet:%d|h[%s]|h"):format(species, name),
        icon = species,
        reason = "Collectible battle pet — click to learn",
        context = {
            itemID = 82800,
            name = name,
            link = ("|Hbattlepet:%d|h[%s]|h"):format(species, name),
            icon = species,
            bag = 0,
            slot = slot,
        },
    }
end
addon.slotIndex = {
    [0] = {
        [1] = PetCage(1, "Lumpy", 1, 1),
        [2] = PetCage(2, "Sea Pony", 2, 1),
        [3] = PetCage(1, "Lumpy", 3, 1),
        [4] = PetCage(3, "Spring Rabbit", 4, 2),
    },
}
addon.itemTotals = { [82800] = 8 }
addon.db.enabled = true
addon:RebuildCandidates()
local countsByName = {}
for _, candidate in ipairs(addon.candidates) do
    countsByName[candidate.name] = candidate.count
    if candidate.name == "Lumpy" then
        assert(candidate.slot == 1, "duplicate keys should keep their first bag slot")
    end
    assert(candidate.secureBySlot and candidate.secureMacro ==
        ("/stopmacro [combat]\n/use %d %d"):format(candidate.bag, candidate.slot),
        "each pet species must target its own cage slot")
end
assert(countsByName["Lumpy"] == 2, "duplicate pet cages should count that species only")
assert(countsByName["Sea Pony"] == 1, "one caged pet should not inherit the shared cage total")
assert(countsByName["Spring Rabbit"] == 2, "a stacked pet cage should keep its own stack count")
assert(countsByName["Lumpy"] ~= 8 and countsByName["Sea Pony"] ~= 8,
    "pet cage totals must not be copied onto every species")

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
    Enum.PlayerInteractionType.Banker)
addon:RebuildCandidates()
assert(#addon.candidates == 0, "pet cage slot actions must be suppressed at a bank")
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    Enum.PlayerInteractionType.Banker)
addon:RebuildCandidates()
assert(#addon.candidates == 3, "pet cage reminders must return after closing the bank")
local previousCloseMerchant = CloseMerchant
CloseMerchant = function()
    eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_CLOSED")
end
eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_SHOW")
addon.button.scripts.PreClick(addon.button, "LeftButton", true)
assert(not addon.merchantOpen and addon.current and addon.current.secureBySlot,
    "the vendor must close before using a displayed pet cage")
CloseMerchant = previousCloseMerchant
local petBag = addon.current.bag
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", petBag)
assert(addon.current == nil, "moving cages must immediately invalidate the displayed slot action")

-- Bank contents must not enter carried-item thresholds, even after a bank event.
addon:ClearInventoryState()
bags = {}
bagSlotCounts = {}
timers = {}
SetSlot(0, 1, 268650, 4)
SetSlot(6, 1, 268650, 1)
SetSlot(13, 1, 200, 1, { hasLoot = true })
ScanNow("login")
addon:ResetMetrics()
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 6)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 13)
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(addon.itemTotals[268650] == 4 and #addon.candidates == 0,
    "outside containers must not contribute to reminders or thresholds")
assert(Metrics().slotsInspected == 0, "bank events must not inspect bank slots")
-- A forced refresh must also evict an outside slot left in an old index.
addon.slotIndex[6] = { [1] = { itemID = 268650, stackCount = 1 } }
addon.itemTotals[268650] = 5
ScanNow("manual")
assert(addon.itemTotals[268650] == 4 and #addon.candidates == 0,
    "manual refresh must remove outside slots left in the index")
SetSlot(5, 1, 268650, 1)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 5)
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(addon.itemTotals[268650] == 5 and #addon.candidates == 1,
    "the carried reagent bag must still contribute to thresholds")

-- Restricted mounts and Curios should recover through targeted level refreshes.
for _, fixture in ipairs({
    { id = 101, action = "Use: Teaches you how to summon this mount.", category = "mount" },
    { id = 113, action = "Use: Add this Curio to your companion's collection.", category = "curio" },
}) do
    addon:ClearInventoryState()
    bags = {}
    bagSlotCounts = {}
    timers = {}
    mountCollected = false
    SetSlot(0, 1, fixture.id, 1)
    tooltipByItem[fixture.id] = {
        { leftText = fixture.action },
        { leftText = "Requires Level 80", leftColor = { r = 1, g = 0.125, b = 0.125 } },
    }
    ScanNow("login")
    assert(addon.current == nil, "red level requirements must hide collectibles")
    tooltipByItem[fixture.id][2].leftColor = { r = 1, g = 1, b = 1 }
    addon:ResetMetrics()
    eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LEVEL_CHANGED")
    while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
    assert(addon.current and addon.current.category == fixture.category,
        "meeting a requirement must restore the collectible")
    assert(Metrics().slotsInspected == 0 and Metrics().tooltipSnapshots == 1,
        "level changes must only refresh the affected tooltip")
end

-- Learning a recipe elsewhere refreshes only recipe tooltips, because the
-- "Already known" state is not available from a collection API.
addon:ClearInventoryState()
bags = {}
bagSlotCounts = {}
timers = {}
tooltipByItem[107] = {
    { leftText = "Use: Teaches you how to craft a test item." },
}
SetSlot(0, 1, 107, 1)
SetSlot(0, 2, 100, 1, { hasLoot = true })
ScanNow("login")
assert(addon.current and addon.current.itemID == 107, "an unlearned recipe should appear")
tooltipByItem[107][2] = { leftText = "Already known" }
addon:ResetMetrics()
eventFrame.scripts.OnEvent(eventFrame, "NEW_RECIPE_LEARNED", 5555)
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(addon.current and addon.current.itemID == 100,
    "a recipe learned elsewhere must drop from the queue")
assert(Metrics().tooltipSnapshots == 1 and Metrics().slotsInspected == 0,
    "learning a recipe must only refetch recipe tooltips")

-- A scan timer queued before a tick chain started must not start a second chain.
addon:ClearInventoryState()
bags = {}
bagSlotCounts = {}
timers = {}
SetSlot(0, 1, 100, 1, { hasLoot = true })
SetSlot(0, 2, 200, 1, { hasLoot = true })
SetSlot(1, 1, 268650, 5)
addon.workPerTick = 1
addon:ScheduleScan("BAG_UPDATE", 0.3)
addon:ScanBags("login")
assert(addon.workActive and #timers == 2, "the chain and the earlier scan timer are both queued")
FireOneTimer()
assert(#timers == 1, "an earlier scan timer must defer to the running tick chain")
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(addon.current, "the single tick chain should still finish the scan")
addon.workPerTick = nil

-- The pet ownership filter hides owned species, and turning it off restores
-- them from cached tooltips without rescanning bags.
addon:ClearInventoryState()
bags = {}
bagSlotCounts = {}
timers = {}
C_PetJournal.GetNumCollectedInfo = function() return 1, 3 end
itemData[82800] = { name = "Pet Cage" }
tooltipByItem[82800] = "Lumpy\nBattle Pet"
SetSlot(0, 1, 82800, 1, { hyperlink = "|Hbattlepet:321:1:3|h[Lumpy]|h" })
ScanNow("login")
assert(addon.current and addon.current.category == "pet"
    and addon.current.reason == "Battle pet (1/3 owned) — click to learn",
    "an owned-but-not-maxed pet should appear by default")
local petOption = addon.settingsPanel.petUncollectedOnly
addon:ResetMetrics()
petOption.checked = true
petOption.scripts.OnClick(petOption)
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(addon.current == nil, "the ownership filter should hide owned species")
petOption.checked = false
petOption.scripts.OnClick(petOption)
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(addon.current and addon.current.category == "pet",
    "turning the ownership filter off should restore the hidden pet")
assert(Metrics().tooltipSnapshots == 0 and Metrics().slotsInspected == 0,
    "toggling the pet filter must reuse cached tooltips")
C_PetJournal.GetNumCollectedInfo = nil
SetSlot(0, 1, 100, 1, { hasLoot = true })
SetSlot(0, 2, 200, 1, { hasLoot = true })
SetSlot(1, 1, 268650, 5)

-- An error inside one work tick must not leave scanning permanently stalled.
addon:ClearInventoryState()
timers = {}
local reportedErrors = {}
geterrorhandler = function()
    return function(message) reportedErrors[#reportedErrors + 1] = message end
end
local originalClassify = addon.ClassifyItem
-- Combat pausing a bag partway through must not let a rebuild-only event
-- (here, opening a vendor) finish the scan and strand the rest of the bag.
for slot = 1, 10 do SetSlot(2, slot, 100, 1, { hasLoot = true }) end
addon.startupScanPending = false
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 2)
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
SetSlot(2, 10, 200, 1, { hasLoot = true })
addon.reconcileSlotsPerTick = 1
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 2)
FireOneTimer()
inCombat = true
FireTimers()
assert(addon.reconcileBag == 2 and not addon.workActive,
    "combat should pause reconciliation partway through the bag")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_SHOW")
local stallGuard = 0
while #timers > 0 and stallGuard < 100 do
    FireTimers()
    stallGuard = stallGuard + 1
end
assert(addon.reconcileBag == nil and addon.slotIndex[2][10].itemID == 200,
    "a rebuild-only event after combat must finish the paused bag")
eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_CLOSED")
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
addon.reconcileSlotsPerTick = nil

-- A picked-up item keeps its classification and is only hidden while locked.
local function HasCandidateAt(bag, slot)
    for _, candidate in ipairs(addon.candidates) do
        if candidate.bag == bag and candidate.slot == slot then
            return true
        end
    end
    return false
end
assert(HasCandidateAt(2, 10), "the unlocked container should be a candidate")
local lockedEntry = addon.slotIndex[2][10]
local classifiedBeforeLock = Metrics().itemsClassified
bags[2][10].isLocked = true
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 2)
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(addon.slotIndex[2][10] == lockedEntry and lockedEntry.locked,
    "a locked slot must keep its indexed entry")
assert(not HasCandidateAt(2, 10), "a locked item must not be offered")
bags[2][10].isLocked = false
eventFrame.scripts.OnEvent(eventFrame, "ITEM_LOCK_CHANGED", 2, 10)
assert(#timers > 0, "unlocking a held item must schedule a recheck")
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(not lockedEntry.locked and HasCandidateAt(2, 10),
    "an unlocked item must be offered again")
assert(Metrics().itemsClassified == classifiedBeforeLock,
    "picking up and putting back an item must not reclassify it")
eventFrame.scripts.OnEvent(eventFrame, "ITEM_LOCK_CHANGED", 2, 9)
assert(#timers == 0, "lock changes on unlocked indexed slots must not rescan")
for slot = 1, 10 do SetSlot(2, slot, nil) end
bagSlotCounts[2] = 0
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 2)
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end

local failNextClassify = true
addon.ClassifyItem = function(self, context)
    if failNextClassify then
        failNextClassify = false
        error("simulated classification failure")
    end
    return originalClassify(self, context)
end
addon:ScanBags("login")
assert(#reportedErrors == 1, "a tick error should reach the error handler")
assert(not addon.workActive, "a tick error must release the work-active flag")
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 0)
assert(#timers > 0, "new bag events must schedule work after a tick error")
SlashCmdList.ITEMFYI("scan")
while #timers > 0 or addon:HasInventoryWork() do FireTimers() end
assert(addon.current, "a later scan should recover after a tick error")
addon.ClassifyItem = originalClassify
geterrorhandler = nil

print("inventory processing tests passed")
