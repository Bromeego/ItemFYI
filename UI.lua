local _, addon = ...

local function CreateText(parent, template, point, x, y)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    text:SetPoint(point, parent, point, x or 0, y or 0)
    return text
end

function addon:SavePosition()
    if not self.button or not self.db then
        return
    end
    local point, _, relativePoint, x, y = self.button:GetPoint(1)
    self.db.position.point = point or "CENTER"
    self.db.position.relativePoint = relativePoint or "CENTER"
    self.db.position.x = x or 0
    self.db.position.y = y or 0
end

function addon:ApplyButtonLayout()
    if not self.button or not self.db then
        return
    end
    if self:IsInCombat() then
        self.layoutPending = true
        return
    end
    local position = self.db.position
    local size = math.max(32, math.min(64, tonumber(self.db.size) or 42))
    self.db.size = size
    self.button:SetSize(size, size)
    self.button:ClearAllPoints()
    self.button:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
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
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:Hide()

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.background:SetColorTexture(0.025, 0.035, 0.045, 0.96)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetAllPoints()
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetPoint("TOPLEFT", 2, -2)
    button.highlight:SetPoint("BOTTOMRIGHT", -2, 2)
    button.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.highlight:SetBlendMode("ADD")

    button.count = CreateText(button, "NumberFontNormal", "BOTTOMRIGHT", -2, 2)
    button.more = CreateText(button, "GameFontNormalSmall", "TOPRIGHT", -1, -1)
    button.more:SetTextColor(0.35, 0.85, 1)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("BOTTOM", button, "TOP", 0, 3)
    button.label:SetText("ITEM FYI")
    button.label:SetTextColor(0.35, 0.85, 1)

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

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
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

    button:SetScript("PostClick", function(_, mouseButton)
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
    self.button:SetAttribute("type2", nil)

    if not candidate then
        if ActionButton_HideOverlayGlow then
            ActionButton_HideOverlayGlow(self.button)
        end
        self.button:Hide()
        GameTooltip:Hide()
        return
    end

    self.button.icon:SetTexture(candidate.icon or 134400)
    self.button.count:SetText(candidate.count and candidate.count > 1 and candidate.count or "")
    self.button.more:SetText(total > 1 and ("+%d"):format(total - 1) or "")
    self.button:SetAttribute("type1", "macro")
    self.button:SetAttribute("macrotext1", candidate.macro)
    self.button:Show()

    if ActionButton_ShowOverlayGlow then
        ActionButton_ShowOverlayGlow(self.button)
    end
end
