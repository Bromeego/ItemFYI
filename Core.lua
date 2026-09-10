local ADDON_NAME, addon = ...

_G.ItemFYI = addon

addon.name = ADDON_NAME
addon.version = "0.2.13"
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

function addon:ScheduleScan(reason, delay)
    self.scanGeneration = self.scanGeneration + 1
    local generation = self.scanGeneration

    if self:IsInCombat() then
        self.scanPending = true
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
        addon:ScanBags(reason)
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

function addon:HandleSlash(input)
    local command, argument = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")

    if command == "" then
        self:OpenSettings()
    elseif command == "help" then
        self:Print("/ifyi opens settings. Commands: scan, list, skip, ignore, ignored, unignore <key>, clearignored, clearskips, reset")
    elseif command == "scan" then
        self.sessionSkipped = {}
        self:ScheduleScan("manual", 0)
    elseif command == "list" then
        self:ListCandidates()
    elseif command == "skip" then
        self:SkipCurrent(false)
    elseif command == "ignore" then
        self:SkipCurrent(true)
    elseif command == "ignored" then
        self:ListIgnored()
    elseif command == "unignore" and argument ~= "" then
        self.db.ignored[argument] = nil
        local numericKey = tonumber(argument)
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
events:RegisterEvent("UNIT_QUEST_LOG_CHANGED")

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
        addon:ScheduleScan("login", 0.4)
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
            addon:ScheduleScan(event, GetBagScanDelay())
        end
    elseif event == "UNIT_QUEST_LOG_CHANGED" then
        local unit = ...
        if unit ~= "player" then
            return
        end
        addon:ScheduleScan(event, 0.15)
    elseif event == "BAG_UPDATE" then
        local changedBag = ...
        local current = addon.current
        if current and current.secureBySlot and current.bag == changedBag and not addon:IsInCombat() then
            -- Do not leave a slot-targeted appearance action clickable while
            -- the slot may contain a different item. BAG_UPDATE_DELAYED will
            -- rebuild it after Blizzard finishes the bag change.
            addon:SetCandidate(nil, 0)
        end
        addon:ScheduleScan(event, GetBagScanDelay())
    elseif event == "BAG_UPDATE_DELAYED" then
        addon:ScheduleScan(event, GetBagScanDelay())
    else
        addon:ScheduleScan(event, 0.15)
    end
end)
