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

    button.count = CreateText(button, "NumberFontNormal", "BOTTOMRIGHT", -2, 2)
    button.Count = button.count
    button.more = CreateText(button, "GameFontNormalSmall", "TOPRIGHT", -1, -1)
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
        frame:StartMoving()
    end)

    button:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        addon:SavePosition()
    end)

    button:SetScript("PostClick", function(_, mouseButton, down)
        -- With both click phases registered, perform our insecure follow-up
        -- only once after the mouse button is released.
        if down then
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
    self.button:SetAttribute("type1", nil)
    self.button:SetAttribute("macrotext1", nil)
    self.button:SetAttribute("item1", nil)
    self.button:SetAttribute("type2", nil)

    if not candidate then
        if ActionButton_HideOverlayGlow then
            ActionButton_HideOverlayGlow(self.button)
        end
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

    if ActionButton_ShowOverlayGlow then
        ActionButton_ShowOverlayGlow(self.button)
    end
end
