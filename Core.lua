local ADDON_NAME, addon = ...

_G.ItemFYI = addon

addon.name = ADDON_NAME
local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
addon.version = GetMetadata and GetMetadata(ADDON_NAME, "Version") or "unknown"
addon.sessionSkipped = {}
addon.current = nil
addon.candidates = {}
addon.scanPending = false
addon.scanGeneration = 0
addon.pendingItemLoads = {}
addon.scanCache = {}
addon.layoutPending = false
addon.slotActionBlocks = {}
addon.merchantOpen = false

-- Bindings.xml clicks the secure button, so keyboard use keeps the same
-- combat, merchant, and inventory-interaction guards as a mouse click.
addon.USE_BINDING = "CLICK ItemFYIActionButton:LeftButton"
BINDING_HEADER_ITEMFYI = "ItemFYI"
-- Keybinding search results omit the section name, so the label carries it.
_G["BINDING_NAME_" .. addon.USE_BINDING] = "ItemFYI: Use current item"

-- Bag-slot use actions inherit the behaviour of whichever inventory-routing
-- window is active. In these interactions, the same click can sell, deposit,
-- attach, trade, scrap, or select the item instead of using it.
local unsafeSlotInteractionTypes = {}
local unsafeSlotInteractionNames = {
    "TradePartner",
    "Banker",
    "GuildBanker",
    "MailInfo",
    "Auctioneer",
    "Transmogrifier",
    "VoidStorageBanker",
    "BlackMarketAuctioneer",
    "ScrappingMachine",
    "ItemInteraction",
    "LegendaryCrafting",
    "ItemUpgrade",
    "ForgeMaster",
    "CharacterBanker",
    "AccountBanker",
}

for _, name in ipairs(unsafeSlotInteractionNames) do
    local interactionType = Enum and Enum.PlayerInteractionType
        and Enum.PlayerInteractionType[name]
    if interactionType ~= nil then
        unsafeSlotInteractionTypes[interactionType] = true
    end
end

local defaults = {
    enabled = true,
    ignored = {},
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = -120,
    },
    size = 42,
    showGlow = true,
    petUncollectedOnly = false,
    editMode = {},
    editModeMigration = 0,
    categories = {
        container = true,
        transmog = true,
        decor = true,
        mount = true,
        toy = true,
        pet = true,
        curio = true,
        profession = true,
        recipe = true,
        progress = true,
        quest = true,
    },
}

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function addon:Print(message)
    print(("|cff56c8ffItemFYI|r: %s"):format(tostring(message)))
end

function addon:IsInCombat()
    return InCombatLockdown and InCombatLockdown()
end

function addon:HideCompanionTooltips()
    if BattlePetToolTip_Hide then
        BattlePetToolTip_Hide()
    elseif BattlePetTooltip and BattlePetTooltip.Hide then
        BattlePetTooltip:Hide()
    end
    if FloatingBattlePet_Hide then
        FloatingBattlePet_Hide()
    elseif FloatingBattlePetTooltip and FloatingBattlePetTooltip.Hide then
        FloatingBattlePetTooltip:Hide()
    end
end

function addon:IsCategoryEnabled(category)
    return not self.db or not self.db.categories or self.db.categories[category] ~= false
end

function addon:IsSlotActionBlocked()
    return next(self.slotActionBlocks) ~= nil
end

function addon:CanCloseMerchantSafely()
    return type(CloseMerchant) == "function"
end

local BAG_SCAN_DELAY = 0.3
local BUSY_BAG_SCAN_DELAY = 0.45
-- Defer automatic login scans until UI/item loading has settled.
local INITIAL_SCAN_GRACE = 2.5

local function GetBagScanDelay()
    -- Mail take-all, vendor auto-sell, and similar bursts fire many bag events.
    -- Wait until they settle so we classify once instead of after every item.
    if addon:IsSlotActionBlocked() then
        return BUSY_BAG_SCAN_DELAY
    end
    return BAG_SCAN_DELAY
end

function addon:SetSlotActionBlock(key, blocked)
    if key == nil then
        return
    end

    local wasBlocked = self.slotActionBlocks[key] == true
    if blocked then
        self.slotActionBlocks[key] = true
    else
        self.slotActionBlocks[key] = nil
    end

    if wasBlocked == blocked then
        return
    end

    if blocked and self.current and self.current.secureBySlot and not self:IsInCombat() then
        -- Remove the protected action synchronously. Leaving it clickable until
        -- the delayed scan could allow a merchant or bank to consume the click.
        self:SetCandidate(nil, 0)
    end
    self:ScheduleScan(blocked and "unsafe item interaction opened"
        or "unsafe item interaction closed", GetBagScanDelay())
end

function addon:IsWatchedCompletionQuest(questID)
    return questID ~= nil and self.WatchedQuestIDs and self.WatchedQuestIDs[questID] == true
end

function addon:SnapshotWatchedQuests()
    local snapshot = {}
    if self.WatchedQuestIDs and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        for questID in pairs(self.WatchedQuestIDs) do
            snapshot[questID] = C_QuestLog.IsQuestFlaggedCompleted(questID) == true
        end
    end
    self.watchedQuestState = snapshot
end

function addon:NoteWatchedQuestCompleted(questID)
    if not self.watchedQuestState then
        self:SnapshotWatchedQuests()
    end
    if questID then
        self.watchedQuestState[questID] = true
    end
end

function addon:ShouldRescanForQuestLog()
    if not self.watchedQuestState then
        self:SnapshotWatchedQuests()
        return false
    end
    if not (self.WatchedQuestIDs and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then
        return false
    end

    local previous = self.watchedQuestState
    local changed = false
    for questID in pairs(self.WatchedQuestIDs) do
        local isDone = C_QuestLog.IsQuestFlaggedCompleted(questID) == true
        if previous[questID] ~= isDone then
            previous[questID] = isDone
            changed = true
        end
    end
    return changed
end

function addon:ScheduleScan(reason, delay)
    if self.NoteScanIntent then
        self:NoteScanIntent(reason)
    end
    local manual = reason == "manual" or reason == "manual settings scan"
    if self.startupScanPending and not manual then
        -- Startup BAG_UPDATE bursts must not bypass the initial delay.
        delay = math.max(delay or 0.15, INITIAL_SCAN_GRACE)
    elseif manual then
        self.startupScanPending = false
    end
    self.scanGeneration = self.scanGeneration + 1
    local generation = self.scanGeneration

    if self:IsInCombat() then
        self.scanPending = true
        return
    end

    if self.workActive then
        return
    end

    C_Timer.After(delay or 0.15, function()
        if generation ~= addon.scanGeneration then
            return
        end
        if addon:IsInCombat() then
            addon.scanPending = true
            return
        end
        addon.scanPending = false
        addon.startupScanPending = false
        -- A tooltip retry may have started a tick chain since this timer was
        -- queued. That chain consumes the recorded intent; a second chain
        -- would double the per-frame work.
        if addon.workActive then
            return
        end
        addon:RunScheduledInventory()
    end)
end

function addon:SkipCurrent(permanent)
    local candidate = self.current
    if not candidate then
        return
    end

    if permanent then
        self.db.ignored[candidate.key] = {
            name = candidate.name,
            link = candidate.link,
        }
        self:Print(("Ignoring %s. Use /ifyi unignore %s to restore it."):format(candidate.name, candidate.key))
        self:RefreshSettingsPanel()
    else
        self.sessionSkipped[candidate.key] = true
        self:Print(("Skipped %s for this session."):format(candidate.name))
    end

    self:ScheduleScan("dismissed", 0)
end

function addon:GetIgnoredEntries()
    local entries = {}
    for key, value in pairs(self.db and self.db.ignored or {}) do
        local name
        if type(value) == "table" then
            name = value.name or value.link
        end
        entries[#entries + 1] = {
            key = tostring(key),
            name = (name and name ~= "" and name) or tostring(key),
        }
    end
    table.sort(entries, function(left, right)
        if left.name ~= right.name then
            return left.name < right.name
        end
        return left.key < right.key
    end)
    return entries
end

function addon:FormatIgnoredSummary()
    local entries = self:GetIgnoredEntries()
    local count = #entries
    if count == 0 then
        return "Permanently ignored items: 0"
    end

    local shown = math.min(count, 8)
    local names = {}
    for index = 1, shown do
        names[index] = entries[index].name
    end
    local extra = count > shown and (" (+%d more)"):format(count - shown) or ""
    return ("Permanently ignored items: %d\n%s%s"):format(count, table.concat(names, ", "), extra)
end

function addon:ListIgnored()
    local entries = self:GetIgnoredEntries()
    if #entries == 0 then
        self:Print("No permanently ignored items.")
        return
    end

    self:Print(("%d permanently ignored item%s:"):format(#entries, #entries == 1 and "" or "s"))
    for _, entry in ipairs(entries) do
        print(("  %s [%s]"):format(entry.name, entry.key))
    end
    self:Print("Use /ifyi unignore <key> to restore an item.")
end

function addon:ListCandidates()
    if #self.candidates == 0 then
        self:Print("No actionable bag items found.")
        return
    end

    self:Print(("%d actionable item%s:"):format(#self.candidates, #self.candidates == 1 and "" or "s"))
    for index, candidate in ipairs(self.candidates) do
        print(("  %d. %s — %s [%s]"):format(index, candidate.link or candidate.name, candidate.reason, candidate.key))
    end
end

function addon:ResetPosition()
    self.db.position.point = defaults.position.point
    self.db.position.relativePoint = defaults.position.relativePoint
    self.db.position.x = defaults.position.x
    self.db.position.y = defaults.position.y
    self:ApplyButtonLayout(true)
    self:Print("Button position reset.")
end

-- Report unresolved tooltips without requiring an expensive new inventory scan.
-- The last incomplete snapshots persist after the bounded retry attempts end.
function addon:GetIncompleteTooltipRows()
    local rows = {}
    for bag, bagSlots in pairs(self.slotIndex or {}) do
        for slot, entry in pairs(bagSlots) do
            local snapshot = entry.snapshot
            if snapshot and snapshot.complete == false then
                local retryKey = tostring(bag) .. ":" .. tostring(slot)
                rows[#rows + 1] = {
                    bag = bag,
                    slot = slot,
                    itemID = entry.itemID,
                    name = (entry.context and entry.context.name) or "Unknown item",
                    reads = self.tooltipRetries and self.tooltipRetries[retryKey] or 0,
                    text = (snapshot.text or ""):gsub("[\r\n]+", " / "):sub(1, 80),
                }
            end
        end
    end
    table.sort(rows, function(left, right)
        if left.reads ~= right.reads then
            return left.reads > right.reads
        end
        if left.bag ~= right.bag then
            return left.bag < right.bag
        end
        return left.slot < right.slot
    end)
    return rows
end

function addon:PrintIncompleteTooltips()
    local rows = self:GetIncompleteTooltipRows()
    self:Print(("Unresolved item tooltips: %d"):format(#rows))
    for index = 1, math.min(#rows, 15) do
        local row = rows[index]
        self:Print(("%s (%s) bag %d slot %d | reads %d | text: %s"):format(
            row.name, tostring(row.itemID or "?"), row.bag, row.slot,
            row.reads, row.text ~= "" and row.text or "(empty)"))
    end
    if #rows > 15 then
        self:Print(("...and %d more unresolved tooltips"):format(#rows - 15))
    end
end

function addon:HandleSlash(input)
    local command, argument = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")

    if command == "" then
        self:OpenSettings()
    elseif command == "help" then
        self:Print("/ifyi opens settings. Commands: scan, perf, perfitems, list, skip, ignore, ignored, unignore <key>, clearignored, clearskips, reset")
    elseif command == "scan" then
        self.sessionSkipped = {}
        self:ScheduleScan("manual", 0)
    elseif command == "list" then
        self:ListCandidates()
    elseif command == "perf" then
        local m = self:GetMetrics()
        local state = (self.startupScanPending and "waiting")
            or (self.workActive and "scanning") or "idle"
        self:Print(("Scan %s | slots %d | classified %d | tooltips %d (fallback %d, incomplete %d, retries %d) | ticks %d | max tick %.2fms, total %.1fms"):format(
            state, m.slotsInspected or 0, m.itemsClassified or 0,
            m.tooltipSnapshots or 0, m.fallbackTooltips or 0,
            m.incompleteTooltipReads or 0, m.tooltipRetriesScheduled or 0,
            m.workTicks or 0, m.maxTickMs or 0, m.totalTickMs or 0))
    elseif command == "perfitems" then
        self:PrintIncompleteTooltips()
    elseif command == "skip" then
        self:SkipCurrent(false)
    elseif command == "ignore" then
        self:SkipCurrent(true)
    elseif command == "ignored" then
        self:ListIgnored()
    elseif command == "unignore" and argument ~= "" then
        local numericKey = tonumber(argument)
        if self.db.ignored[argument] == nil
            and not (numericKey and self.db.ignored[numericKey] ~= nil) then
            self:Print(("%s is not on the ignore list. Use /ifyi ignored to see keys."):format(argument))
            return
        end
        self.db.ignored[argument] = nil
        if numericKey then
            self.db.ignored[numericKey] = nil
        end
        self:Print(("Restored %s."):format(argument))
        self:RefreshSettingsPanel()
        self:ScheduleScan("unignored", 0)
    elseif command == "clearignored" then
        wipe(self.db.ignored)
        self:Print("Permanent ignore list cleared.")
        self:RefreshSettingsPanel()
        self:ScheduleScan("ignore list cleared", 0)
    elseif command == "clearskips" then
        wipe(self.sessionSkipped)
        self:Print("Session skips cleared.")
        self:ScheduleScan("skip list cleared", 0)
    elseif command == "reset" then
        self:ResetPosition()
    else
        self:Print("Unknown command. Use /ifyi help.")
    end
end

local events = CreateFrame("Frame")
addon.eventFrame = events

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("BAG_UPDATE")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:RegisterEvent("ITEM_DATA_LOAD_RESULT")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_CLOSED")
events:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
events:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
events:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_REMOVED")
events:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_CHANGED")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("CHAT_MSG_SKILL")
events:RegisterEvent("NEW_MOUNT_ADDED")
events:RegisterEvent("NEW_TOY_ADDED")
events:RegisterEvent("NEW_PET_ADDED")
events:RegisterEvent("COMPANION_LEARNED")
events:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
events:RegisterEvent("NEW_RECIPE_LEARNED")
events:RegisterEvent("UPDATE_BINDINGS")

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon ~= ADDON_NAME then
            return
        end

        if type(_G.ItemFYIDB) ~= "table" then
            _G.ItemFYIDB = {}
        end
        addon.db = _G.ItemFYIDB
        ApplyDefaults(addon.db, defaults)
        addon:CreateUI()
        addon:RegisterSettings()

        SLASH_ITEMFYI1 = "/ifyi"
        SlashCmdList.ITEMFYI = function(text)
            addon:HandleSlash(text)
        end
        _G.ItemFYI_OnAddonCompartmentClick = function()
            addon:OpenSettings()
        end
    elseif event == "PLAYER_LOGIN" then
        addon:RegisterSkinning()
        addon:RegisterEditMode()
        addon:UpdateHotkey()
        addon:SnapshotWatchedQuests()
        addon:ResetMetrics()
        addon.startupScanPending = true
        addon:ScheduleScan("login", INITIAL_SCAN_GRACE)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if addon.layoutPending then
            local useSavedPosition = addon.layoutUseSavedPosition
            addon.layoutUseSavedPosition = nil
            addon:ApplyButtonLayout(useSavedPosition)
        end
        if addon.scanPending then
            addon:ScheduleScan("combat ended", GetBagScanDelay())
        end
    elseif event == "MERCHANT_SHOW" then
        addon.merchantOpen = true
        if addon:CanCloseMerchantSafely() then
            addon.slotActionBlocks.merchant = nil
            addon:ScheduleScan("merchant opened", GetBagScanDelay())
        else
            -- Clients without a callable close API keep the conservative behaviour.
            addon:SetSlotActionBlock("merchant", true)
        end
    elseif event == "MERCHANT_CLOSED" then
        addon.merchantOpen = false
        if addon.slotActionBlocks.merchant then
            addon:SetSlotActionBlock("merchant", false)
        else
            addon:ScheduleScan("merchant closed", GetBagScanDelay())
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
        or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        if unsafeSlotInteractionTypes[interactionType] then
            addon:SetSlotActionBlock("interaction:" .. tostring(interactionType),
                event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        -- Hovering any item loads tooltip data and fires these. Only rescan
        -- when a previous bag pass asked for that item ID and it was missing.
        local itemID, success = ...
        if addon.ShouldRescanForLoadedItem
            and addon:ShouldRescanForLoadedItem(itemID, success) then
            addon:NoteItemRefresh(itemID)
            addon:ScheduleScan(event, GetBagScanDelay())
        end
    elseif event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
        -- A quest starter may remain in the bag after its quest is accepted.
        -- Quest state changes need only a cached eligibility recheck, not a
        -- full inventory or tooltip scan. The delay lets the log settle.
        addon:ScheduleScan("quest state", 0.25)
    elseif event == "QUEST_TURNED_IN" then
        -- World quests and other turn-ins fire this even when the reward is
        -- only currency. Rescan bags only for weekly treatise quests.
        local questID = ...
        if addon:IsWatchedCompletionQuest(questID) then
            addon:NoteWatchedQuestCompleted(questID)
            if addon.Rules then
                for itemID, rule in pairs(addon.Rules) do
                    if rule.completedQuestID == questID then
                        addon:NoteItemRefresh(itemID, true)
                    end
                end
            end
            addon:ScheduleScan("quest completion", 0.15)
        end
    elseif event == "UNIT_QUEST_LOG_CHANGED" then
        local unit = ...
        if unit ~= "player" then
            return
        end
        if addon:ShouldRescanForQuestLog() then
            if addon.WatchedQuestIDs and addon.Rules then
                for itemID, rule in pairs(addon.Rules) do
                    if rule.completedQuestID and addon.WatchedQuestIDs[rule.completedQuestID] then
                        addon:NoteItemRefresh(itemID, true)
                    end
                end
            end
            addon:ScheduleScan("quest completion", 0.15)
        end
    elseif event == "BAG_UPDATE" then
        local changedBag = ...
        addon:NoteDirtyBag(changedBag)
        addon:InvalidateSecureActionForBag(changedBag)
        if not addon.workActive then
            addon:ScheduleScan(event, GetBagScanDelay())
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if not addon.workActive then
            addon:ScheduleScan(event, GetBagScanDelay())
        end
    elseif event == "PLAYER_LOOT_SPEC_UPDATED"
        or event == "PLAYER_LEVEL_CHANGED"
        or event == "SKILL_LINES_CHANGED"
        or event == "CHAT_MSG_SKILL" then
        addon:ScheduleScan("character state", 0.15)
    elseif event == "NEW_MOUNT_ADDED" then
        addon:ScheduleScan("collection:mount", 0.15)
    elseif event == "NEW_TOY_ADDED" then
        addon:ScheduleScan("collection:toy", 0.15)
    elseif event == "NEW_PET_ADDED" then
        addon:ScheduleScan("collection:pet", 0.15)
    elseif event == "COMPANION_LEARNED" then
        addon:ScheduleScan("collection:companion", 0.15)
    elseif event == "TRANSMOG_COLLECTION_UPDATED" then
        addon:ScheduleScan("collection:transmog", 0.15)
    elseif event == "NEW_RECIPE_LEARNED" then
        addon:ScheduleScan("collection:recipe", 0.15)
    elseif event == "UPDATE_BINDINGS" then
        addon:UpdateHotkey()
        addon:RefreshSettingsPanel()
    end
end)
