local _, addon = ...

local function CreateText(parent, template, point, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetPoint(point, parent, point, x or 0, y or 0)
    return text
end

local function HideButtonTooltip(button)
    if GameTooltip and GameTooltip.GetOwner and GameTooltip:GetOwner() == button then
        GameTooltip:Hide()
    end
end

local GLOW_SIZE_SCALE = 2

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

    button:SetScript("OnEnter", function(frame)
        local candidate = addon.current
        if not candidate then
            return
        end
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:SetBagItem(candidate.bag, candidate.slot)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(candidate.reason, 0.35, 0.85, 1, true)
        GameTooltip:AddLine("Left-click to use", 0.2, 1, 0.2)
        if candidate.secureBySlot and addon.merchantOpen then
            GameTooltip:AddLine("Vendor will close before use", 1, 0.82, 0.2)
        end
        GameTooltip:AddLine("Right-click to skip this session", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Ctrl-right-click to ignore", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Alt-drag to move", 0.65, 0.65, 0.65)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function(frame)
        HideButtonTooltip(frame)
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
        if candidate and not addon:IsInCombat() then
            frame:SetAttribute("type1", "macro")
            frame:SetAttribute("macrotext1", candidate.secureMacro)
        end
    end)

    button:SetScript("PreClick", function(frame, mouseButton)
        if addon:IsInCombat() then
            return
        end

        -- Alt-drag shares the left button with the secure use. Clear the
        -- action before click-on-press can consume the item.
        if mouseButton == "LeftButton" and IsAltKeyDown() then
            addon.suppressingSecureUse = true
            frame:SetAttribute("type1", nil)
            frame:SetAttribute("macrotext1", nil)
            return
        end

        local candidate = addon.current
        if mouseButton ~= "LeftButton" or not candidate or not candidate.secureBySlot
            or not addon.merchantOpen or not addon:CanCloseMerchantSafely() then
            return
        end

        -- A bag-slot use is interpreted as a sale while the merchant
        -- interaction is active. Close it immediately before the secure action
        -- runs. WoW does not reliably allow addons to reopen a fully closed
        -- merchant interaction, so the player must interact with the vendor again.
        local closed = pcall(CloseMerchant)
        if not closed or addon.merchantOpen then
            -- MERCHANT_CLOSED is synchronous. If it did not arrive, remove the
            -- action now so this click cannot fall through and sell the item.
            addon:SetSlotActionBlock("merchant", true)
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
            if candidate and not addon.movingButton and not addon:IsInCombat() then
                frame:SetAttribute("type1", "macro")
                frame:SetAttribute("macrotext1", candidate.secureMacro)
            end
            return
        end

        if mouseButton == "RightButton" then
            addon:SkipCurrent(IsControlKeyDown())
        else
            addon:ScheduleScan("item used", 0.3)
        end
    end)

    self:ApplyButtonLayout()
end

function addon:SetCandidate(candidate, total)
    if not self.button then
        return
    end
    if self:IsInCombat() then
        self.scanPending = true
        return
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
            self.button:SetAlpha(0.65)
            self.button:Show()
        else
            self.button:SetAlpha(1)
            self.button:Hide()
        end
        HideButtonTooltip(self.button)
        return
    end

    self.button:SetAlpha(1)
    self.button.icon:SetTexture(candidate.icon or 134400)
    self.button.count:SetText(candidate.count and candidate.count > 1 and candidate.count or "")
    self.button.more:SetText(total > 1 and ("+%d"):format(total - 1) or "")
    self.button:SetAttribute("type1", "macro")
    self.button:SetAttribute("macrotext1", candidate.secureMacro)
    self.button:Show()
    ShowButtonGlow(self.button)
end
