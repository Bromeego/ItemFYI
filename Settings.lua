local _, addon = ...

local categoryOptions = {
    { key = "container", label = "Openables & stack combines" },
    { key = "transmog", label = "Transmog, visuals & customizations" },
    { key = "decor", label = "Housing decor" },
    { key = "mount", label = "Mounts" },
    { key = "toy", label = "Toys" },
    { key = "pet", label = "Battle pets" },
    { key = "curio", label = "Companion curios" },
    { key = "profession", label = "Profession progress & processing" },
    { key = "recipe", label = "Recipes" },
    { key = "progress", label = "Progression, Garrison & reputation" },
    { key = "quest", label = "Quests" },
}

local CLEAR_IGNORED_POPUP = "ITEMFYI_CLEAR_IGNORED"

-- One mis-click on the settings button would otherwise wipe every permanent
-- ignore. /ifyi clearignored is typed deliberately and stays immediate.
local function ConfirmClearIgnored()
    if not (StaticPopupDialogs and StaticPopup_Show) then
        addon:ClearIgnored()
        return
    end
    if not StaticPopupDialogs[CLEAR_IGNORED_POPUP] then
        StaticPopupDialogs[CLEAR_IGNORED_POPUP] = {
            text = "Clear all permanently ignored ItemFYI items?",
            button1 = YES or "Yes",
            button2 = NO or "No",
            OnAccept = function()
                addon:ClearIgnored()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show(CLEAR_IGNORED_POPUP)
end

local function CreateLabel(parent, text, template, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function IsChecked(control)
    return control:GetChecked() and true or false
end

local function CreateSizeSlider(parent)
    local templates = { "UISliderTemplate", "UISliderTemplateWithLabels" }
    for _, template in ipairs(templates) do
        local ok, slider = pcall(CreateFrame, "Slider", "ItemFYIButtonSizeSlider", parent, template)
        if ok and slider then
            return slider
        end
    end
    return CreateFrame("Slider", "ItemFYIButtonSizeSlider", parent)
end

function addon:RefreshSettingsPanel()
    local panel = self.settingsPanel
    if not panel or not self.db then
        return
    end

    panel.refreshing = true
    panel.enabled:SetChecked(self.db.enabled ~= false)
    for key, checkbox in pairs(panel.categoryChecks) do
        checkbox:SetChecked(self:IsCategoryEnabled(key))
        checkbox:SetEnabled(self.db.enabled ~= false)
    end
    panel.showGlow:SetChecked(self.db.showGlow ~= false)
    panel.showGlow:SetEnabled(self.db.enabled ~= false)
    panel.petUncollectedOnly:SetChecked(self.db.petUncollectedOnly == true)
    panel.petUncollectedOnly:SetEnabled(self.db.enabled ~= false and self:IsCategoryEnabled("pet"))
    local key = self.GetUseBindingKey and self:GetUseBindingKey()
    panel.keybindStatus:SetText(("Keybinding: %s (Options > Keybindings > ItemFYI)"):format(
        key and (GetBindingText and GetBindingText(key) or key) or "not bound"))
    panel.sizeSlider:SetValue(self.db.size or 42)
    panel.ignoredStatus:SetText(self:FormatIgnoredSummary())
    panel.refreshing = false
end

function addon:OpenSettings()
    local category = self.settingsCategory
    if not category or not Settings or not Settings.OpenToCategory then
        self:Print("The ItemFYI settings panel is not available in this client.")
        return
    end

    local categoryID = category.GetID and category:GetID() or category.ID
    Settings.OpenToCategory(categoryID)
end

function addon:RegisterSettings()
    if self.settingsCategory or not Settings or not Settings.RegisterCanvasLayoutCategory then
        return
    end

    local panel = CreateFrame("Frame", "ItemFYISettingsPanel")
    self.settingsPanel = panel
    panel.categoryChecks = {}

    CreateLabel(panel, "ItemFYI: Openables & Learnables", "GameFontNormalLarge", 16, -16)
    CreateLabel(panel, "Choose which actionable bag items ItemFYI should surface.", "GameFontHighlightSmall", 16, -42)

    local enabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    panel.enabled = enabled
    enabled:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -70)
    enabled.text = enabled:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    enabled.text:SetPoint("LEFT", enabled, "RIGHT", 4, 0)
    enabled.text:SetText("Enable ItemFYI")
    enabled:SetScript("OnClick", function(control)
        if panel.refreshing then
            return
        end
        addon.db.enabled = IsChecked(control)
        addon:RefreshSettingsPanel()
        addon:ScheduleScan("settings changed", 0)
    end)

    local showGlow = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    panel.showGlow = showGlow
    showGlow:SetPoint("TOPLEFT", panel, "TOPLEFT", 232, -70)
    showGlow.text = showGlow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    showGlow.text:SetPoint("LEFT", showGlow, "RIGHT", 4, 0)
    showGlow.text:SetText("Show attention glow")
    showGlow:SetScript("OnClick", function(control)
        if panel.refreshing then
            return
        end
        addon.db.showGlow = IsChecked(control)
        addon:ApplyButtonGlow()
    end)

    local categoryRowHeight = 30
    local categoryOriginY = -130
    CreateLabel(panel, "Item categories", "GameFontNormal", 16, -108)
    for index, option in ipairs(categoryOptions) do
        local categoryKey = option.key
        local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        panel.categoryChecks[categoryKey] = checkbox
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 12 + column * 260, categoryOriginY - row * categoryRowHeight)
        checkbox.text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        checkbox.text:SetText(option.label)
        checkbox:SetScript("OnClick", function(control)
            if panel.refreshing then
                return
            end
            addon.db.categories[categoryKey] = IsChecked(control)
            addon:RefreshSettingsPanel()
            addon:ScheduleScan("category changed", 0)
        end)
    end

    local categoryRows = math.ceil(#categoryOptions / 2)
    local petOptionY = categoryOriginY - categoryRows * categoryRowHeight - 4
    local petUncollectedOnly = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    panel.petUncollectedOnly = petUncollectedOnly
    petUncollectedOnly:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, petOptionY)
    petUncollectedOnly.text = petUncollectedOnly:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    petUncollectedOnly.text:SetPoint("LEFT", petUncollectedOnly, "RIGHT", 4, 0)
    petUncollectedOnly.text:SetText("Only show battle pets you don't own yet")
    petUncollectedOnly:SetScript("OnClick", function(control)
        if panel.refreshing then
            return
        end
        addon.db.petUncollectedOnly = IsChecked(control)
        addon:ScheduleScan("collection:pet", 0)
    end)

    local belowCategories = petOptionY - categoryRowHeight - 16
    CreateLabel(panel, "Button size", "GameFontNormal", 16, belowCategories)
    local sizeSlider = CreateSizeSlider(panel)
    panel.sizeSlider = sizeSlider
    sizeSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, belowCategories - 38)
    sizeSlider:SetSize(220, 17)
    sizeSlider:SetOrientation("HORIZONTAL")
    sizeSlider:SetMinMaxValues(32, 64)
    sizeSlider:SetValueStep(2)
    sizeSlider:SetObeyStepOnDrag(true)

    local sizeValue = sizeSlider:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    sizeValue:SetPoint("BOTTOM", sizeSlider, "TOP", 0, 2)
    sizeValue:SetText("42 px")
    panel.sizeSliderValue = sizeValue

    local sizeLow = sizeSlider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sizeLow:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -2)
    sizeLow:SetText("32")

    local sizeHigh = sizeSlider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sizeHigh:SetPoint("TOPRIGHT", sizeSlider, "BOTTOMRIGHT", 0, -2)
    sizeHigh:SetText("64")

    sizeSlider:SetScript("OnValueChanged", function(control, value)
        value = math.floor((tonumber(value) or 42) / 2 + 0.5) * 2
        sizeValue:SetText(("%d px"):format(value))
        if panel.refreshing then
            return
        end
        addon.db.size = value
        addon:ApplyButtonLayout()
    end)

    local resetPosition = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPosition:SetPoint("TOPLEFT", panel, "TOPLEFT", 320, belowCategories - 32)
    resetPosition:SetSize(150, 24)
    resetPosition:SetText("Reset position")
    resetPosition:SetScript("OnClick", function()
        addon:ResetPosition()
    end)

    CreateLabel(panel, "Dismissed items", "GameFontNormal", 16, belowCategories - 90)
    panel.ignoredStatus = CreateLabel(panel, "", "GameFontHighlightSmall", 16, belowCategories - 116)
    panel.ignoredStatus:SetWidth(540)
    panel.ignoredStatus:SetJustifyH("LEFT")
    if panel.ignoredStatus.SetWordWrap then
        panel.ignoredStatus:SetWordWrap(true)
    end

    local clearSkips = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearSkips:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, belowCategories - 162)
    clearSkips:SetSize(150, 24)
    clearSkips:SetText("Clear session skips")
    clearSkips:SetScript("OnClick", function()
        wipe(addon.sessionSkipped)
        addon:ScheduleScan("session skips cleared", 0)
    end)

    local clearIgnored = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.clearIgnored = clearIgnored
    clearIgnored:SetPoint("LEFT", clearSkips, "RIGHT", 10, 0)
    clearIgnored:SetSize(170, 24)
    clearIgnored:SetText("Clear permanent ignores")
    clearIgnored:SetScript("OnClick", ConfirmClearIgnored)

    local rescan = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.rescan = rescan
    rescan:SetPoint("LEFT", clearIgnored, "RIGHT", 10, 0)
    rescan:SetSize(110, 24)
    rescan:SetText("Rescan bags")
    rescan:SetScript("OnClick", function()
        wipe(addon.sessionSkipped)
        addon:ScheduleScan("manual settings scan", 0)
    end)

    panel.keybindStatus = CreateLabel(panel, "", "GameFontHighlightSmall", 16, belowCategories - 200)

    panel:SetScript("OnShow", function()
        addon:RefreshSettingsPanel()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "ItemFYI")
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category
    self:RefreshSettingsPanel()
end
