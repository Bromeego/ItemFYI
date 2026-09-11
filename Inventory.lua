local _, addon = ...

local wipe = wipe or function(target)
    for key in pairs(target) do
        target[key] = nil
    end
end

local EXPENSIVE_WORK_PER_TICK = 4
local TIME_BUDGET_MS = 3
local MAX_TOOLTIP_RETRIES = 3
local WORK_TICK_DELAY = 0

local forceRefreshReasons = {
    login = true,
    manual = true,
    ["manual settings scan"] = true,
}

local rebuildOnlyReasons = {
    dismissed = true,
    unignored = true,
    ["ignore list cleared"] = true,
    ["skip list cleared"] = true,
    ["session skips cleared"] = true,
    ["category changed"] = true,
    ["settings changed"] = true,
    ["unsafe item interaction opened"] = true,
    ["unsafe item interaction closed"] = true,
    ["merchant opened"] = true,
    ["merchant closed"] = true,
}

local restrictionReasons = {
    ["character state"] = true,
    PLAYER_LOOT_SPEC_UPDATED = true,
}

local collectionCategories = {
    ["collection:mount"] = "mount",
    ["collection:toy"] = "toy",
    ["collection:pet"] = "pet",
    ["collection:transmog"] = "transmog",
    ["collection:companion"] = "pet",
}

local function SlotKey(bag, slot)
    return tostring(bag) .. ":" .. tostring(slot)
end

local function EquippedBagCount()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5
end

local function TimeNow()
    if debugprofilestop then
        return debugprofilestop()
    end
end

local function EnsureState(self)
    if not self.slotIndex then
        self.slotIndex = {}
    end
    if not self.itemTotals then
        self.itemTotals = {}
    end
    if not self.dirtyBags then
        self.dirtyBags = {}
    end
    if not self.pendingItemIDs then
        self.pendingItemIDs = {}
    end
    if not self.classifyQueue then
        self.classifyQueue = {}
    end
    if not self.classifyQueued then
        self.classifyQueued = {}
    end
    if not self.retryQueue then
        self.retryQueue = {}
    end
    if not self.retryQueued then
        self.retryQueued = {}
    end
    if not self.tooltipRetries then
        self.tooltipRetries = {}
    end
    if not self.changedTotals then
        self.changedTotals = {}
    end
    if not self.eligibilityKinds then
        self.eligibilityKinds = {}
    end
    if not self.metrics then
        self:ResetMetrics()
    end
end

local function GetEntry(self, bag, slot)
    local bagSlots = self.slotIndex and self.slotIndex[bag]
    return bagSlots and bagSlots[slot]
end

local function SetEntry(self, bag, slot, entry)
    self.slotIndex[bag] = self.slotIndex[bag] or {}
    self.slotIndex[bag][slot] = entry
end

local function AdjustTotal(self, itemID, delta)
    if not itemID or delta == 0 then
        return
    end
    local before = self.itemTotals[itemID] or 0
    local after = before + delta
    if after <= 0 then
        self.itemTotals[itemID] = nil
        after = 0
    else
        self.itemTotals[itemID] = after
    end
    if before ~= after then
        self.changedTotals[itemID] = true
    end
end

local function Fingerprint(info, bag, slot)
    if not info or info.isLocked then
        return nil
    end
    local itemID = info.itemID or (C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot))
    if not itemID then
        return nil
    end
    return {
        itemID = itemID,
        link = info.hyperlink or (C_Container.GetContainerItemLink and C_Container.GetContainerItemLink(bag, slot)),
        stackCount = tonumber(info.stackCount) or 1,
        hasLoot = info.hasLoot == true,
    }
end

local function FingerprintsEqual(left, right)
    return left and right
        and left.itemID == right.itemID
        and left.link == right.link
        and left.stackCount == right.stackCount
        and left.hasLoot == right.hasLoot
end

local function UnqueueClassify(self, bag, slot)
    local key = SlotKey(bag, slot)
    self.classifyQueued[key] = nil
end

local function QueueClassify(self, bag, slot)
    local key = SlotKey(bag, slot)
    if self.classifyQueued[key] then
        return
    end
    self.classifyQueued[key] = true
    self.classifyQueue[#self.classifyQueue + 1] = { bag = bag, slot = slot }
end

local function QueueRetry(self, bag, slot)
    local key = SlotKey(bag, slot)
    if self.retryQueued[key] then
        return
    end
    self.retryQueued[key] = true
    self.retryQueue[#self.retryQueue + 1] = { bag = bag, slot = slot }
end

local function PromoteRetries(self)
    if not self.retryQueue[1] then
        return
    end
    for index = 1, #self.retryQueue do
        local job = self.retryQueue[index]
        self.retryQueued[SlotKey(job.bag, job.slot)] = nil
        if GetEntry(self, job.bag, job.slot) then
            QueueClassify(self, job.bag, job.slot)
        end
    end
    wipe(self.retryQueue)
end

local function QueueItemSlots(self, itemID)
    if not itemID or not self.slotIndex then
        return
    end
    for bag, bagSlots in pairs(self.slotIndex) do
        for slot, entry in pairs(bagSlots) do
            if entry.itemID == itemID then
                QueueClassify(self, bag, slot)
            end
        end
    end
end

local function RemoveSlot(self, bag, slot)
    local entry = GetEntry(self, bag, slot)
    if not entry then
        return
    end
    AdjustTotal(self, entry.itemID, -(entry.stackCount or 0))
    self.slotIndex[bag][slot] = nil
    UnqueueClassify(self, bag, slot)
    self.tooltipRetries[SlotKey(bag, slot)] = nil
    self.retryQueued[SlotKey(bag, slot)] = nil
    if self.scanCache then
        self.scanCache[SlotKey(bag, slot)] = nil
    end
    self.rebuildNeeded = true
    self:NoteMetric("slotsChanged")
end

function addon:ClearInventoryState()
    self.slotIndex = {}
    self.itemTotals = {}
    self.dirtyBags = {}
    self.allBagsDirty = false
    self.forceRefresh = false
    self.rebuildOnly = false
    self.eligibilityKinds = {}
    self.pendingItemIDs = {}
    self.classifyQueue = {}
    self.classifyQueued = {}
    self.retryQueue = {}
    self.retryQueued = {}
    self.tooltipRetries = {}
    self.changedTotals = {}
    self.workActive = false
    self.rebuildNeeded = false
    self.scanCache = {}
    self.pendingItemLoads = {}
    self.candidates = {}
    if self.SetCandidate then
        self:SetCandidate(nil, 0)
    else
        self.current = nil
    end
end

function addon:NoteDirtyBag(bagID)
    EnsureState(self)
    if bagID == nil then
        self.allBagsDirty = true
        return
    end
    self.dirtyBags[bagID] = true
end

function addon:InvalidateSecureActionForBag(bagID)
    local current = self.current
    if current and current.secureBySlot and current.bag == bagID and not self:IsInCombat() then
        self:SetCandidate(nil, 0)
    end
end

function addon:NoteItemRefresh(itemID, keepTooltip)
    if itemID == nil then
        return
    end
    EnsureState(self)
    self.pendingItemIDs[itemID] = true
    if keepTooltip then
        return
    end
    self:InvalidateScanCacheForItem(itemID)
    for _, bagSlots in pairs(self.slotIndex) do
        for _, entry in pairs(bagSlots) do
            if entry.itemID == itemID then
                entry.snapshot = nil
                entry.classified = false
            end
        end
    end
end

function addon:HasInventoryWork()
    if self.allBagsDirty or (self.dirtyBags and next(self.dirtyBags)) then
        return true
    end
    if self.forceRefresh or self.rebuildOnly
        or (self.eligibilityKinds and next(self.eligibilityKinds)) then
        return true
    end
    if self.pendingItemIDs and next(self.pendingItemIDs) then
        return true
    end
    if self.classifyQueue and self.classifyQueue[1] then
        return true
    end
    if self.retryQueue and self.retryQueue[1] then
        return true
    end
    if self.rebuildNeeded then
        return true
    end
    return false
end

function addon:NoteScanIntent(reason)
    EnsureState(self)
    reason = reason or ""

    if forceRefreshReasons[reason] then
        self.forceRefresh = true
        self.allBagsDirty = true
        self.rebuildOnly = false
        return
    end

    if restrictionReasons[reason] then
        self.eligibilityKinds.restriction = true
        self.rebuildOnly = false
        return
    end

    local collectionCategory = collectionCategories[reason]
    if collectionCategory then
        self.eligibilityKinds[collectionCategory] = true
        self.rebuildOnly = false
        return
    end

    if reason == "quest completion" then
        self.rebuildOnly = false
        return
    end

    if reason == "item used" or reason == "GET_ITEM_INFO_RECEIVED"
        or reason == "ITEM_DATA_LOAD_RESULT" then
        self.rebuildOnly = false
        return
    end

    if rebuildOnlyReasons[reason] then
        if reason == "settings changed" and self.db and self.db.enabled
            and not next(self.slotIndex) then
            self.forceRefresh = true
            self.allBagsDirty = true
            self.rebuildOnly = false
            return
        end
        if not self.forceRefresh and not self.allBagsDirty and not next(self.dirtyBags)
            and not next(self.pendingItemIDs) and not next(self.eligibilityKinds) then
            self.rebuildOnly = true
        end
        return
    end

    if reason == "BAG_UPDATE" or reason == "BAG_UPDATE_DELAYED" or reason == "combat ended" then
        self.rebuildOnly = false
    end
end

local function ClearSnapshots(self)
    self:InvalidateScanCache()
    for bag, bagSlots in pairs(self.slotIndex) do
        for slot, entry in pairs(bagSlots) do
            entry.snapshot = nil
            entry.classified = false
            entry.category = nil
            entry.reason = nil
            entry.uniqueKey = nil
            self.tooltipRetries[SlotKey(bag, slot)] = nil
        end
    end
end

local function QueueEligibility(self, kind)
    if not kind then
        return
    end
    for bag, bagSlots in pairs(self.slotIndex) do
        for slot, entry in pairs(bagSlots) do
            local shouldQueue = false
            if kind == "restriction" then
                if entry.sawRestrictionText then
                    entry.snapshot = nil
                    if self.scanCache then
                        self.scanCache[SlotKey(bag, slot)] = nil
                    end
                    shouldQueue = true
                elseif entry.category == "profession" then
                    shouldQueue = true
                end
            elseif entry.category == kind then
                shouldQueue = true
            end
            if shouldQueue then
                QueueClassify(self, bag, slot)
            end
        end
    end
end

local function QueuePendingItemIDs(self)
    if not next(self.pendingItemIDs) then
        return
    end
    for itemID in pairs(self.pendingItemIDs) do
        QueueItemSlots(self, itemID)
    end
    self.pendingItemIDs = {}
end

local function ReconcileBag(self, bag)
    local slotCount = C_Container.GetContainerNumSlots(bag) or 0
    local seen = {}
    for slot = 1, slotCount do
        self:NoteMetric("slotsInspected")
        local info = C_Container.GetContainerItemInfo(bag, slot)
        local fingerprint = Fingerprint(info, bag, slot)
        local existing = GetEntry(self, bag, slot)
        if not fingerprint then
            if existing then
                RemoveSlot(self, bag, slot)
            end
        else
            seen[slot] = true
            local changed = not existing or not FingerprintsEqual(existing, fingerprint)
            if changed then
                if existing then
                    AdjustTotal(self, existing.itemID, -(existing.stackCount or 0))
                else
                    existing = {}
                    SetEntry(self, bag, slot, existing)
                end
                existing.itemID = fingerprint.itemID
                existing.link = fingerprint.link
                existing.stackCount = fingerprint.stackCount
                existing.hasLoot = fingerprint.hasLoot
                existing.snapshot = nil
                existing.classified = false
                existing.category = nil
                existing.reason = nil
                existing.uniqueKey = nil
                existing.sawRestrictionText = nil
                existing.awaitingItemInfo = nil
                existing.bag = bag
                existing.slot = slot
                AdjustTotal(self, fingerprint.itemID, fingerprint.stackCount)
                self.tooltipRetries[SlotKey(bag, slot)] = nil
                self:NoteMetric("slotsChanged")
                QueueClassify(self, bag, slot)
            elseif not existing.classified then
                QueueClassify(self, bag, slot)
            end
        end
    end

    local bagSlots = self.slotIndex[bag]
    if bagSlots then
        for slot in pairs(bagSlots) do
            if not seen[slot] then
                RemoveSlot(self, bag, slot)
            end
        end
    end
end

local function ReconcileDirtyBags(self)
    local lastBag = EquippedBagCount()
    if self.allBagsDirty then
        for bag = 0, lastBag do
            ReconcileBag(self, bag)
        end
        self.allBagsDirty = false
        wipe(self.dirtyBags)
    else
        for bag in pairs(self.dirtyBags) do
            ReconcileBag(self, bag)
        end
        wipe(self.dirtyBags)
    end

    if next(self.changedTotals) then
        for itemID in pairs(self.changedTotals) do
            QueueItemSlots(self, itemID)
        end
        wipe(self.changedTotals)
    end
end

local function CompactClassifyQueue(self)
    local source = self.classifyQueue
    local compact = {}
    local queued = {}
    for index = 1, #source do
        local job = source[index]
        local key = SlotKey(job.bag, job.slot)
        if self.classifyQueued[key] and not queued[key] and GetEntry(self, job.bag, job.slot) then
            queued[key] = true
            compact[#compact + 1] = job
        end
    end
    self.classifyQueue = compact
    self.classifyQueued = queued
end

function addon:RebuildCandidates()
    local candidates = {}
    local seen = {}
    if self.db and self.db.enabled and self.slotIndex then
        for bag, bagSlots in pairs(self.slotIndex) do
            for slot, entry in pairs(bagSlots) do
                local category = entry.category
                local key = entry.uniqueKey or (entry.itemID and tostring(entry.itemID))
                if category and key and self:IsCategoryEnabled(category) and not seen[key]
                    and not (self.db.ignored and self.db.ignored[key])
                    and not (self.sessionSkipped and self.sessionSkipped[key]) then
                    local context = entry.context
                    if context then
                        local secureMacro, secureBySlot = self:BuildSecureUse(context, category)
                        if not (secureBySlot and self:IsSlotActionBlocked()) then
                            seen[key] = true
                            candidates[#candidates + 1] = {
                                key = key,
                                itemID = entry.itemID,
                                name = context.name,
                                link = context.link,
                                icon = context.icon,
                                count = self.itemTotals[entry.itemID] or entry.stackCount,
                                bag = bag,
                                slot = slot,
                                category = category,
                                reason = entry.reason,
                                priority = self.CategoryPriority[category] or 100,
                                secureMacro = secureMacro,
                                secureBySlot = secureBySlot,
                            }
                        end
                    end
                end
            end
        end
    end

    table.sort(candidates, function(left, right)
        if left.priority ~= right.priority then
            return left.priority < right.priority
        end
        if left.itemID ~= right.itemID then
            return left.itemID < right.itemID
        end
        return left.slot < right.slot
    end)

    self.candidates = candidates
    self.rebuildNeeded = false
    self:SetCandidate(candidates[1], #candidates)
end

local function ClassifySlot(self, bag, slot)
    local entry = GetEntry(self, bag, slot)
    if not entry then
        return
    end

    local info = {
        itemID = entry.itemID,
        hyperlink = entry.link,
        iconFileID = entry.context and entry.context.icon,
        stackCount = entry.stackCount,
        hasLoot = entry.hasLoot,
        isLocked = false,
    }
    local context = self:BuildContext(bag, slot, info)
    if not context then
        entry.awaitingItemInfo = true
        entry.classified = false
        entry.category = nil
        entry.reason = nil
        entry.context = nil
        self.rebuildNeeded = true
        return
    end

    context.hasLoot = entry.hasLoot
    context.stackCount = entry.stackCount
    context.totalCount = self.itemTotals[entry.itemID] or entry.stackCount
    entry.context = context
    entry.awaitingItemInfo = nil
    if entry.snapshot and entry.snapshot.complete ~= false then
        context.tooltipSnapshot = entry.snapshot
    end

    self.useScanCache = true
    local category, itemReason = self:ClassifyItem(context)
    local snapshot = context.tooltipSnapshot
    self.useScanCache = nil

    entry.snapshot = snapshot
    entry.sawRestrictionText = snapshot and snapshot.sawRestrictionText
    entry.uniqueKey = context.uniqueKey
    entry.classified = true
    entry.category = category
    entry.reason = itemReason
    self.rebuildNeeded = true

    local key = SlotKey(bag, slot)
    if snapshot and snapshot.complete == false then
        local retries = (self.tooltipRetries[key] or 0) + 1
        if retries <= MAX_TOOLTIP_RETRIES then
            self.tooltipRetries[key] = retries
            entry.classified = false
            QueueRetry(self, bag, slot)
        else
            self.tooltipRetries[key] = retries
        end
    else
        self.tooltipRetries[key] = nil
    end
end

local function DequeueClassify(self)
    while true do
        local job = table.remove(self.classifyQueue, 1)
        if not job then
            return
        end
        local key = SlotKey(job.bag, job.slot)
        self.classifyQueued[key] = nil
        if GetEntry(self, job.bag, job.slot) then
            return job
        end
    end
end

function addon:ProcessInventoryTick(maxExpensive)
    EnsureState(self)
    self:NoteMetric("workTicks")
    if self:IsInCombat() then
        self.scanPending = true
        self.workActive = false
        return false
    end
    if not self.db or not self.db.enabled then
        self:ClearInventoryState()
        self.workActive = false
        return false
    end

    local expensiveLimit = maxExpensive or self.workPerTick or EXPENSIVE_WORK_PER_TICK
    local started = TimeNow()
    local expensive = 0

    if self.forceRefresh then
        self.forceRefresh = false
        self.allBagsDirty = true
        ClearSnapshots(self)
    end

    if self.allBagsDirty or next(self.dirtyBags) then
        ReconcileDirtyBags(self)
    end

    PromoteRetries(self)

    if next(self.eligibilityKinds) then
        for kind in pairs(self.eligibilityKinds) do
            QueueEligibility(self, kind)
        end
        wipe(self.eligibilityKinds)
    end
    QueuePendingItemIDs(self)
    CompactClassifyQueue(self)

    while expensive < expensiveLimit do
        if started and (TimeNow() - started) >= TIME_BUDGET_MS then
            break
        end
        local job = DequeueClassify(self)
        if not job then
            break
        end
        ClassifySlot(self, job.bag, job.slot)
        expensive = expensive + 1
    end

    if expensive > (self.metrics.maxWorkPerTick or 0) then
        self.metrics.maxWorkPerTick = expensive
    end

    if self.rebuildNeeded or self.rebuildOnly then
        self:RebuildCandidates()
        self.rebuildOnly = false
    end

    local remaining = self:HasInventoryWork()
    self.workActive = remaining
    return remaining
end

function addon:FlushInventoryWork()
    while self:ProcessInventoryTick(self.workPerTick or EXPENSIVE_WORK_PER_TICK) do
    end
end

local function ContinueInventoryWork()
    if addon:IsInCombat() then
        addon.scanPending = true
        addon.workActive = false
        return
    end
    local remaining = addon:ProcessInventoryTick()
    if remaining then
        C_Timer.After(WORK_TICK_DELAY, ContinueInventoryWork)
    end
end

function addon:RunScheduledInventory()
    EnsureState(self)
    if self:IsInCombat() then
        self.scanPending = true
        return
    end
    if not self.db or not self.db.enabled then
        self:ClearInventoryState()
        return
    end

    if self.rebuildOnly and not self.forceRefresh and not self.allBagsDirty
        and not next(self.dirtyBags) and not next(self.pendingItemIDs)
        and not next(self.eligibilityKinds) and not self.classifyQueue[1]
        and not (self.retryQueue and self.retryQueue[1]) then
        self:RebuildCandidates()
        self.rebuildOnly = false
        self.workActive = false
        return
    end

    self.workActive = true
    local remaining = self:ProcessInventoryTick()
    if remaining then
        C_Timer.After(WORK_TICK_DELAY, ContinueInventoryWork)
    end
end

function addon:ScanBags(reason)
    EnsureState(self)
    if reason then
        self:NoteScanIntent(reason)
    end
    if not self.forceRefresh and not self.rebuildOnly
        and not next(self.eligibilityKinds)
        and not self.allBagsDirty and not next(self.dirtyBags)
        and not next(self.pendingItemIDs) and not self.classifyQueue[1]
        and not (self.retryQueue and self.retryQueue[1]) then
        self.allBagsDirty = true
    end
    self:RunScheduledInventory()
end
