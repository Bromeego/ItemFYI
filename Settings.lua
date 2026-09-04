local _, addon = ...

local categoryOptions = {
    { key = "container", label = "Openable containers" },
    { key = "transmog", label = "Transmog tokens" },
    { key = "decor", label = "Housing decor" },
    { key = "mount", label = "Mounts" },
    { key = "toy", label = "Toys" },
    { key = "pet", label = "Battle pets" },
    { key = "recipe", label = "Recipes" },
}

local function CreateLabel(parent, text, template, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function CountEntries(values)
    local count = 0
    for _ in pairs(values or {}) do
        count = count + 1
    end
    return count
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
    panel.sizeSlider:SetValue(self.db.size or 42)
    panel.ignoredStatus:SetText(("Permanently ignored items: %d"):format(CountEntries(self.db.ignored)))
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
        addon.db.enabled = control:GetChecked() == true
        addon:RefreshSettingsPanel()
        addon:ScheduleScan("settings changed", 0)
    end)

    CreateLabel(panel, "Item categories", "GameFontNormal", 16, -108)
    for index, option in ipairs(categoryOptions) do
        local categoryKey = option.key
        local checkbox = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        panel.categoryChecks[categoryKey] = checkbox
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 12 + column * 220, -130 - row * 30)
        checkbox.text = checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        checkbox.text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
        checkbox.text:SetText(option.label)
        checkbox:SetScript("OnClick", function(control)
            if panel.refreshing then
                return
            end
            addon.db.categories[categoryKey] = control:GetChecked() == true
            addon:ScheduleScan("category changed", 0)
        end)
    end

    CreateLabel(panel, "Button size", "GameFontNormal", 16, -260)
    local sizeSlider = CreateFrame("Slider", "ItemFYIButtonSizeSlider", panel, "OptionsSliderTemplate")
    panel.sizeSlider = sizeSlider
    sizeSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -288)
    sizeSlider:SetWidth(220)
    sizeSlider:SetMinMaxValues(32, 64)
    sizeSlider:SetValueStep(2)
    sizeSlider:SetObeyStepOnDrag(true)
    _G.ItemFYIButtonSizeSliderLow:SetText("32")
    _G.ItemFYIButtonSizeSliderHigh:SetText("64")
    _G.ItemFYIButtonSizeSliderText:SetText("42 px")
    sizeSlider:SetScript("OnValueChanged", function(control, value)
        value = math.floor((tonumber(value) or 42) / 2 + 0.5) * 2
        _G.ItemFYIButtonSizeSliderText:SetText(("%d px"):format(value))
        if panel.refreshing then
            return
        end
        addon.db.size = value
        addon:ApplyButtonLayout()
    end)

    local resetPosition = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPosition:SetPoint("TOPLEFT", panel, "TOPLEFT", 280, -282)
    resetPosition:SetSize(150, 24)
    resetPosition:SetText("Reset position")
    resetPosition:SetScript("OnClick", function()
        addon:ResetPosition()
    end)

    CreateLabel(panel, "Dismissed items", "GameFontNormal", 16, -340)
    panel.ignoredStatus = CreateLabel(panel, "", "GameFontHighlightSmall", 16, -366)

    local clearSkips = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearSkips:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -392)
    clearSkips:SetSize(150, 24)
    clearSkips:SetText("Clear session skips")
    clearSkips:SetScript("OnClick", function()
        wipe(addon.sessionSkipped)
        addon:ScheduleScan("session skips cleared", 0)
    end)

    local clearIgnored = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    clearIgnored:SetPoint("LEFT", clearSkips, "RIGHT", 10, 0)
    clearIgnored:SetSize(170, 24)
    clearIgnored:SetText("Clear permanent ignores")
    clearIgnored:SetScript("OnClick", function()
        wipe(addon.db.ignored)
        addon:RefreshSettingsPanel()
        addon:ScheduleScan("ignore list cleared", 0)
    end)

    local rescan = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    rescan:SetPoint("LEFT", clearIgnored, "RIGHT", 10, 0)
    rescan:SetSize(110, 24)
    rescan:SetText("Rescan bags")
    rescan:SetScript("OnClick", function()
        addon:ScheduleScan("manual settings scan", 0)
    end)

    panel:SetScript("OnShow", function()
        addon:RefreshSettingsPanel()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "ItemFYI")
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category
    self:RefreshSettingsPanel()
end
