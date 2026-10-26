local _, addon = ...

local function CreateText(parent, template, point, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetPoint(point, parent, point, x or 0, y or 0)
    return text
end

local function TooltipIsOwnedBy(button)
    if not (GameTooltip and GameTooltip.GetOwner) then
        return false
    end
    local owner = GameTooltip:GetOwner()
    return owner == button or (button.moreHit and owner == button.moreHit)
end

local function HideButtonTooltip(button, hideCompanions)
    if TooltipIsOwnedBy(button) then
        GameTooltip:Hide()
        hideCompanions = true
    end
    if hideCompanions then
        addon:HideCompanionTooltips()
    end
end

function addon:GetUseBindingKey()
    return GetBindingKey and GetBindingKey(self.USE_BINDING) or nil
end

function addon:UpdateHotkey()
    local button = self.button
    if not (button and button.hotkey) then
        return
    end
    local key = self:GetUseBindingKey()
    local text = key and GetBindingText and GetBindingText(key, true) or key
    button.hotkey:SetText(text or "")
end

local QUEUE_TOOLTIP_LIMIT = 8

local function ShowQueueTooltip(owner)
    local candidates = addon.candidates
    if not (owner and GameTooltip and candidates and #candidates > 1) then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Also waiting", 1, 0.82, 0)
    local shown = 0
    for index = 2, #candidates do
        if shown >= QUEUE_TOOLTIP_LIMIT then
            break
        end
        local candidate = candidates[index]
        local label = candidate.link or candidate.name or "Unknown item"
        if candidate.count and candidate.count > 1 then
            label = label .. " x" .. candidate.count
        end
        GameTooltip:AddLine(label, 1, 1, 1, true)
        if candidate.reason then
            GameTooltip:AddLine(candidate.reason, 0.35, 0.85, 1, true)
        end
        shown = shown + 1
    end
    local extra = #candidates - 1 - shown
    if extra > 0 then
        GameTooltip:AddLine(("+%d more"):format(extra), 0.65, 0.65, 0.65)
    end
    GameTooltip:Show()
end

local function ShowButtonTooltip(button)
    local candidate = addon.current
    if not candidate or not GameTooltip then
        return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetBagItem(candidate.bag, candidate.slot)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(candidate.reason, 0.35, 0.85, 1, true)
    local key = addon:GetUseBindingKey()
    if key then
        local keyText = GetBindingText and GetBindingText(key) or key
        GameTooltip:AddLine(("Left-click or press %s to use"):format(keyText), 0.2, 1, 0.2)
    else
        GameTooltip:AddLine("Left-click to use", 0.2, 1, 0.2)
    end
    GameTooltip:AddLine("Right-click to skip this session", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Ctrl-right-click to ignore", 0.9, 0.9, 0.9)
    GameTooltip:AddLine("Alt-drag to move", 0.65, 0.65, 0.65)
    GameTooltip:Show()
end

local function RefreshButtonTooltip(button)
    if not (GameTooltip and GameTooltip.GetOwner) then
        return
    end
    local owner = GameTooltip:GetOwner()
    if owner == button then
        addon:HideCompanionTooltips()
        ShowButtonTooltip(button)
    elseif button.moreHit and owner == button.moreHit then
        addon:HideCompanionTooltips()
        if button.moreHit:IsShown() then
            ShowQueueTooltip(button.moreHit)
        else
            GameTooltip:Hide()
        end
    end
end

local GLOW_SIZE_SCALE = 1.7

local function FitButtonGlow(button)
    local alert = button and button.SpellActivationAlert
    if not (alert and alert.SetSize) then
        return
    end

    local width, height = button:GetSize()
    width = tonumber(width) or 42
    height = tonumber(height) or width
    alert:ClearAllPoints()
    alert:SetPoint("CENTER", button, "CENTER")
    alert:SetSize(width * GLOW_SIZE_SCALE, height * GLOW_SIZE_SCALE)
    if alert.EnableMouse then
        alert:EnableMouse(false)
    end

    if button.badge and button.badge.SetFrameLevel then
        local alertLevel = alert.GetFrameLevel and alert:GetFrameLevel() or button:GetFrameLevel()
        button.badge:SetFrameLevel((tonumber(alertLevel) or 1) + 5)
    end
end

local function ShowButtonGlow(button)
    if ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.ShowAlert then
        ActionButtonSpellAlertManager:ShowAlert(button)
        FitButtonGlow(button)
        return
    end
    if ActionButton_ShowOverlayGlow then
        ActionButton_ShowOverlayGlow(button)
        FitButtonGlow(button)
    end
end

local function HideButtonGlow(button)
    if ActionButtonSpellAlertManager and ActionButtonSpellAlertManager.HideAlert then
        ActionButtonSpellAlertManager:HideAlert(button)
        return
    end
    if ActionButton_HideOverlayGlow then
        ActionButton_HideOverlayGlow(button)
    end
end

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

-- Read the cooldown of exactly what the button's action uses: the targeted
-- bag slot for slot macros, or the item ID for /use item:ID. Anything missing,
-- secret, or not yet started returns nil, so no overlay is shown.
local function ReadCandidateCooldown(candidate)
    local container = C_Container
    local ok, start, duration, enable
    if candidate.secureBySlot then
        if not (container and container.GetContainerItemCooldown) then
            return nil
        end
        ok, start, duration, enable = pcall(container.GetContainerItemCooldown,
            candidate.bag, candidate.slot)
    else
        if not (container and container.GetItemCooldown and candidate.itemID) then
            return nil
        end
        ok, start, duration, enable = pcall(container.GetItemCooldown, candidate.itemID)
    end
    if not ok or IsSecret(start) or IsSecret(duration) or IsSecret(enable) then
        return nil
    end
    start, duration = tonumber(start), tonumber(duration)
    -- enable is 0 while a cooldown waits to start (for example, a potion
    -- used in combat); the sweep would show the wrong time then.
    if not (start and duration and start > 0 and duration > 0)
        or (enable ~= 1 and enable ~= true) then
        return nil
    end
    return start, duration
end

-- Cooldown changes never touch secure attributes. In combat the displayed
-- action cannot change, a running sweep keeps animating, and the next
-- refresh waits until combat ends.
function addon:UpdateButtonCooldown()
    local cooldown = self.button and self.button.cooldown
    if not cooldown then
        return
    end
    if self:IsInCombat() then
        self.cooldownRefreshPending = true
        return
    end
    self.cooldownRefreshPending = nil

    local start, duration
    if self.current then
        start, duration = ReadCandidateCooldown(self.current)
    end
    if start then
        cooldown:SetCooldown(start, duration)
    elseif cooldown.Clear then
        cooldown:Clear()
    else
        cooldown:SetCooldown(0, 0)
    end
end

-- Grey the icon in combat only when the action's macro stops in combat
-- (slot-targeted pet cages and appearance tokens). This changes a texture,
-- never the secure button.
function addon:ApplyCombatDimming(inCombat)
    local icon = self.button and self.button.icon
    if not (icon and icon.SetDesaturated) then
        return
    end
    local current = self.current
    icon:SetDesaturated(inCombat == true and current ~= nil and current.blockedInCombat == true)
end

function addon:ShouldShowGlow()
    return not self.db or self.db.showGlow ~= false
end

function addon:ApplyButtonGlow()
    if not self.button then
        return
    end
    if self.current and self:ShouldShowGlow() then
        ShowButtonGlow(self.button)
    else
        HideButtonGlow(self.button)
    end
end

function addon:SavePosition(skipEditMode)
    if not self.button or not self.db then
        return
    end
    local point, _, relativePoint, x, y = self.button:GetPoint(1)
    self.db.position.point = point or "CENTER"
    self.db.position.relativePoint = relativePoint or "CENTER"
    self.db.position.x = x or 0
    self.db.position.y = y or 0
    if not skipEditMode then
        self:SaveEditModePosition()
    end
end

function addon:ApplyButtonLayout(useSavedPosition)
    if not self.button or not self.db then
        return
    end
    if self:IsInCombat() then
        self.layoutPending = true
        if useSavedPosition then
            self.layoutUseSavedPosition = true
        end
        return
    end
    local position = self.db.position
    local size = math.max(32, math.min(64, tonumber(self.db.size) or 42))
    self.db.size = size
    self.button:SetSize(size, size)
    FitButtonGlow(self.button)

    if self.editModeRegistered and not useSavedPosition then
        self.editModeLib:RepositionFrame(self.button)
        self:SavePosition(true)
        self.layoutPending = false
        return
    end

    self.button:ClearAllPoints()
    self.button:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    if useSavedPosition then
        self:SaveEditModePosition()
    end
    self.layoutPending = false
end

function addon:RestorePosition()
    self:ApplyButtonLayout()
end

function addon:CreateUI()
    if self.button then
        return
    end

    local button = CreateFrame("Button", "ItemFYIActionButton", UIParent, "SecureActionButtonTemplate")
    self.button = button
    button:SetSize(42, 42)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:EnableMouse(true)
    if button.SetClipsChildren then
        button:SetClipsChildren(false)
    end
    -- Secure actions may fire on press or release depending on the player's
    -- ActionButtonUseKeyDown setting, so register both phases.
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:RegisterForDrag("LeftButton")
    button:Hide()

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.background:SetColorTexture(0.025, 0.035, 0.045, 0.96)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon = button.icon
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Blizzard's standard cooldown sweep, over the icon only. It is visual and
    -- has no mouse input, so clicks still reach the secure button.
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.Cooldown = button.cooldown
    button.cooldown:SetAllPoints(button.icon)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetPoint("TOPLEFT", 2, -2)
    button.highlight:SetPoint("BOTTOMRIGHT", -2, 2)
    button.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.highlight:SetBlendMode("ADD")

    -- Keep count and +N above the spell-alert glow, which is a child frame.
    button.badge = CreateFrame("Frame", nil, button)
    button.badge:SetAllPoints()
    button.badge:SetFrameLevel(button:GetFrameLevel() + 10)

    button.count = CreateText(button.badge, "NumberFontNormal", "BOTTOMRIGHT", -2, 2)
    button.Count = button.count
    button.more = CreateText(button.badge, "GameFontNormalSmall", "TOPRIGHT", -1, -1)
    button.more:SetTextColor(0.35, 0.85, 1)
    button.hotkey = CreateText(button.badge, "NumberFontNormalSmallGray", "TOPLEFT", 2, -2)
    button.HotKey = button.hotkey

    -- FontStrings do not receive hover. This corner frame lists the rest of
    -- the queue. Clicks pass through so the secure use still fires.
    button.moreHit = CreateFrame("Frame", nil, button.badge)
    button.moreHit:SetPoint("TOPRIGHT", button.more, "TOPRIGHT", 4, 4)
    button.moreHit:SetPoint("BOTTOMLEFT", button.more, "BOTTOMLEFT", -8, -4)
    button.moreHit:EnableMouse(true)
    if button.moreHit.SetPropagateMouseClicks then
        button.moreHit:SetPropagateMouseClicks(true)
    end
    button.moreHit:Hide()
    button.moreHit:SetScript("OnEnter", function(frame)
        ShowQueueTooltip(frame)
    end)
    button.moreHit:SetScript("OnLeave", function()
        if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == button.moreHit then
            GameTooltip:Hide()
            addon:HideCompanionTooltips()
        end
    end)

    button:SetScript("OnEnter", function(frame)
        ShowButtonTooltip(frame)
    end)

    button:SetScript("OnLeave", function(frame)
        HideButtonTooltip(frame, true)
    end)

    button:SetScript("OnDragStart", function(frame)
        if addon:IsInCombat() or not IsAltKeyDown() then
            return
        end
        addon.movingButton = true
        frame:SetAttribute("type1", nil)
        frame:SetAttribute("macrotext1", nil)
        frame:StartMoving()
    end)

    button:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        addon.movingButton = false
        addon:SavePosition()
        local candidate = addon.current
        if candidate and not addon:IsInCombat() and not addon:IsItemUseBlocked() then
            frame:SetAttribute("type1", "macro")
            frame:SetAttribute("macrotext1", candidate.secureMacro)
        end
    end)

    button:SetScript("PreClick", function(frame, mouseButton)
        if addon:IsInCombat() then
            return
        end

        -- Alt-drag shares the left button with the secure use. Clear the
        -- action before click-on-press can consume the item. A key binding
        -- with an Alt modifier fires away from the cursor and must still use.
        local overButton = not frame.IsMouseOver or frame:IsMouseOver()
        if mouseButton == "LeftButton" and IsAltKeyDown() and overButton then
            addon.suppressingSecureUse = true
            frame:SetAttribute("type1", nil)
            frame:SetAttribute("macrotext1", nil)
            return
        end

        -- Backstop only: opening a vendor or routing window already cleared
        -- the action. This runs before the secure OnClick of the same press
        -- or release, so it stops a stale action out of combat. In combat the
        -- button cannot be changed, so this guard cannot be relied on alone.
        if addon:IsItemUseBlocked() then
            frame:SetAttribute("type1", nil)
            frame:SetAttribute("macrotext1", nil)
        end
    end)

    button:SetScript("PostClick", function(frame, mouseButton, down)
        -- With both click phases registered, perform our insecure follow-up
        -- only once after the mouse button is released.
        if down then
            return
        end

        if addon.suppressingSecureUse or addon.movingButton then
            addon.suppressingSecureUse = false
            local candidate = addon.current
            if candidate and not addon.movingButton and not addon:IsInCombat()
                and not addon:IsItemUseBlocked() then
                frame:SetAttribute("type1", "macro")
                frame:SetAttribute("macrotext1", candidate.secureMacro)
            end
            return
        end

        if mouseButton == "RightButton" then
            addon:SkipCurrent(IsControlKeyDown(), true)
        elseif addon.current then
            -- A key press on the hidden, empty button uses nothing to rescan for.
            addon:NoteItemRefresh(addon.current.itemID)
            addon:ScheduleScan("item used", 0.3)
        end
    end)

    self:ApplyButtonLayout()
    self:UpdateHotkey()
end

function addon:SetCandidate(candidate, total)
    if not self.button then
        return
    end
    if self:IsInCombat() then
        self.scanPending = true
        return
    end
    if candidate and self:IsItemUseBlocked() then
        -- No path may arm an action while a vendor or routing window is open.
        candidate, total = nil, 0
    end

    self.current = candidate
    self.suppressingSecureUse = false
    self.movingButton = false
    self.button:SetAttribute("type1", nil)
    self.button:SetAttribute("macrotext1", nil)
    self.button:SetAttribute("item1", nil)
    self.button:SetAttribute("type2", nil)

    if not candidate then
        HideButtonGlow(self.button)
        if self:EditModeIsActive() then
            self.button.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
            self.button.count:SetText("")
            self.button.more:SetText("")
            self.button.moreHit:Hide()
            self.button:SetAlpha(0.65)
            self.button:Show()
        else
            self.button:SetAlpha(1)
            self.button:Hide()
        end
        self.button.moreHit:Hide()
        HideButtonTooltip(self.button)
        self:ApplyCombatDimming(false)
        self:UpdateButtonCooldown()
        return
    end

    self.button:SetAlpha(1)
    self.button.icon:SetTexture(candidate.icon or 134400)
    self.button.count:SetText(candidate.count and candidate.count > 1 and candidate.count or "")
    self.button.more:SetText(total > 1 and ("+%d"):format(total - 1) or "")
    if total > 1 then
        self.button.moreHit:Show()
    else
        self.button.moreHit:Hide()
    end
    self.button:SetAttribute("type1", "macro")
    self.button:SetAttribute("macrotext1", candidate.secureMacro)
    self.button:Show()
    -- SetCandidate only runs out of combat, so the icon is never dimmed here.
    self:ApplyCombatDimming(false)
    self:UpdateButtonCooldown()
    self:ApplyButtonGlow()
    RefreshButtonTooltip(self.button)
end
