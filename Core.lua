local ADDON_NAME, addon = ...

_G.ItemFYI = addon

addon.name = ADDON_NAME
addon.version = "0.1.0"
addon.sessionSkipped = {}
addon.current = nil
addon.candidates = {}
addon.scanPending = false
addon.scanGeneration = 0
addon.layoutPending = false

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
    editMode = {},
    editModeMigration = 0,
    categories = {
        container = true,
        transmog = true,
        decor = true,
        mount = true,
        toy = true,
        pet = true,
        recipe = true,
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

function addon:IsCategoryEnabled(category)
    return not self.db or not self.db.categories or self.db.categories[category] ~= false
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
        self.db.ignored[candidate.key] = true
        self:Print(("Ignoring %s. Use /ifyi unignore %s to restore it."):format(candidate.name, candidate.key))
        self:RefreshSettingsPanel()
    else
        self.sessionSkipped[candidate.key] = true
        self:Print(("Skipped %s for this session."):format(candidate.name))
    end

    self:ScheduleScan("dismissed", 0)
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
        self:Print("/ifyi scan, list, skip, ignore, unignore <key>, clearignored, clearskips, reset")
    elseif command == "scan" then
        self.sessionSkipped = {}
        self:ScheduleScan("manual", 0)
    elseif command == "list" then
        self:ListCandidates()
    elseif command == "skip" then
        self:SkipCurrent(false)
    elseif command == "ignore" then
        self:SkipCurrent(true)
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
            addon:ScheduleScan("combat ended", 0)
        end
    elseif event == "BAG_UPDATE" then
        local changedBag = ...
        local current = addon.current
        if current and current.secureBySlot and current.bag == changedBag and not addon:IsInCombat() then
            -- Do not leave a slot-targeted appearance action clickable while
            -- the slot may contain a different item. BAG_UPDATE_DELAYED will
            -- rebuild it after Blizzard finishes the bag change.
            addon:SetCandidate(nil, 0)
        end
        addon:ScheduleScan(event, 0.05)
    else
        addon:ScheduleScan(event, 0.15)
    end
end)
