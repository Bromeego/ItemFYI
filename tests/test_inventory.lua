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
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end }
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
itemData[101] = { name = "Test Mount" }
tooltipByItem[101] = "Summons and dismisses a rideable test mount."
tooltipByItem[100] = "Use: Open the satchel."
tooltipByItem[200] = "Use: Open the crate."
tooltipByItem[268650] = "Use: Combine 5 shards."
tooltipByItem[789] = "Use: Add this appearance to your Warband collection."
tooltipByItem[107] = {
    { leftText = "Use: Teaches you how to craft a test item.", leftColor = { r = 0, g = 1, b = 0 } },
    { leftText = "Requires Northrend Leatherworking (75)", leftColor = { r = 1, g = 0.125, b = 0.125 } },
}

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
FireTimers()

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

-- Incomplete tooltips are not permanently cached, and retries are targeted and bounded.
SetSlot(0, 1, 100, 1, { hasLoot = true })
tooltipComplete[100] = false
addon.workPerTick = 1
addon:ResetMetrics()
addon:ScanBags("login")
assert(Metrics().tooltipSnapshots >= 1, "the incomplete slot should be read")
local firstIncomplete = Metrics().tooltipSnapshots
assert(addon.retryQueue[1], "incomplete tooltips should queue a targeted retry")
local incompleteBeforeRebuild = Metrics().tooltipSnapshots
addon:ScanBags("settings changed")
assert(Metrics().tooltipSnapshots > incompleteBeforeRebuild,
    "filter-only work must still promote pending tooltip retries")
FireOneTimer()
assert(Metrics().tooltipSnapshots > firstIncomplete, "retries should reread only the waiting slot")
assert(Metrics().tooltipSnapshots <= 4, "tooltip retries must be bounded")
tooltipComplete[100] = nil
while addon:HasInventoryWork() and #timers > 0 do
    FireOneTimer()
end
assert(addon.current and addon.current.itemID == 100, "a later complete tooltip should become a candidate")
addon.workPerTick = nil

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
addon:ScanBags("login")
assert(Metrics().workTicks == 1, "login classification should start with one tick")
assert(Metrics().itemsClassified == 1, "a tick budget of one should classify one item")
assert(addon:HasInventoryWork(), "remaining slots should stay queued")
assert(addon.current, "the first valid candidate may appear before the scan finishes")
FireOneTimer()
assert(Metrics().workTicks == 2, "queued work should continue on a later tick")
assert(Metrics().maxWorkPerTick == 1, "no tick should exceed the expensive-work budget")
while addon:HasInventoryWork() and #timers > 0 do
    FireOneTimer()
end
assert(addon.current, "the yielded scan should finish with a candidate")
addon.workPerTick = nil

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

print("inventory processing tests passed")
