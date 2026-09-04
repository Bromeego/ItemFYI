_G = _G or _ENV

local function Noop() end

local function NewRegion()
    return {
        SetAllPoints = Noop,
        SetColorTexture = Noop,
        SetPoint = Noop,
        SetTexture = Noop,
        SetBlendMode = Noop,
        SetTexCoord = Noop,
        SetTextColor = Noop,
        SetText = function(self, value) self.text = value end,
        GetText = function(self) return self.text end,
    }
end

local createdFrames = {}
local function NewFrame(name)
    local frame = {
        name = name,
        scripts = {},
        hooks = {},
        attributes = {},
        shown = false,
        width = 42,
        height = 42,
    }
    function frame:RegisterEvent() end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:HookScript(script, callback) self.hooks[script] = callback end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetWidth(width) self.width = width end
    function frame:SetClampedToScreen() end
    function frame:SetMovable() end
    function frame:EnableMouse() end
    function frame:RegisterForClicks() end
    function frame:RegisterForDrag() end
    function frame:Hide() self.shown = false end
    function frame:Show() self.shown = true end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown end
    function frame:SetAlpha(value) self.alpha = value end
    function frame:CreateTexture() return NewRegion() end
    function frame:CreateFontString() return NewRegion() end
    function frame:SetAttribute(key, value) self.attributes[key] = value end
    function frame:SetText(value) self.text = value end
    function frame:SetChecked(value) self.checked = value end
    function frame:GetChecked() return self.checked end
    function frame:SetEnabled(value) self.enabled = value end
    function frame:SetMinMaxValues(low, high) self.low, self.high = low, high end
    function frame:SetValueStep(step) self.step = step end
    function frame:SetObeyStepOnDrag() end
    function frame:SetValue(value)
        self.value = value
        if self.scripts.OnValueChanged then
            self.scripts.OnValueChanged(self, value)
        end
    end
    function frame:ClearAllPoints() end
    function frame:SetPoint(point, _, relativePoint, x, y)
        self.point = { point, relativePoint, x, y }
    end
    function frame:GetPoint()
        local point = self.point or { "CENTER", "CENTER", 0, -120 }
        return point[1], UIParent, point[2], point[3], point[4]
    end
    function frame:GetRect() return 100, 200, self.width, self.height end
    function frame:GetName() return self.name end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

UIParent = { GetRect = function() return 0, 0, 1920, 1080 end }
CreateFrame = function(_, name)
    local frame = NewFrame(name)
    if name == "ItemFYIButtonSizeSlider" then
        _G.ItemFYIButtonSizeSliderLow = NewRegion()
        _G.ItemFYIButtonSizeSliderHigh = NewRegion()
        _G.ItemFYIButtonSizeSliderText = NewRegion()
    end
    return frame
end
local inCombat = false
InCombatLockdown = function() return inCombat end
IsAltKeyDown = function() return false end
IsControlKeyDown = function() return false end
wipe = function(target) for key in pairs(target) do target[key] = nil end end
C_Timer = { After = function(_, callback) callback() end }
C_Item = {
    GetItemInfo = function() return nil end,
    RequestLoadItemDataByID = Noop,
}
C_Container = {
    GetContainerNumSlots = function() return 0 end,
    GetContainerItemInfo = function() return nil end,
    GetContainerItemID = function() return nil end,
    GetContainerItemLink = function() return nil end,
}
C_TooltipInfo = { GetBagItem = function() return { lines = {} } end }
C_MountJournal = {}
C_ToyBox = {}
C_PetJournal = {}
Enum = { ItemClass = { Recipe = 9 } }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
GameTooltip = {
    SetOwner = Noop,
    SetBagItem = Noop,
    AddLine = Noop,
    Show = Noop,
    Hide = Noop,
}
SlashCmdList = {}
local editModeLib = { framesDB = {} }
function editModeLib:RegisterFrame(frame, _, db)
    frame.system = 20
    frame.Selection = NewFrame("ItemFYIEditModeSelection")
    self.framesDB[frame.system] = db
end
function editModeLib:SetDontResize() end
function editModeLib:RegisterCoordinates() end
function editModeLib:RepositionFrame() end
LibStub = function(name)
    if name == "EditModeExpanded-1.0" then
        return editModeLib
    end
end
EditModeManagerFrame = NewFrame("EditModeManagerFrame")
EditModeManagerFrame.editModeActive = false
local openedCategory
Settings = {
    RegisterCanvasLayoutCategory = function(_, name)
        return { ID = name, GetID = function(self) return self.ID end }
    end,
    RegisterAddOnCategory = Noop,
    OpenToCategory = function(categoryID) openedCategory = categoryID end,
}

local addon = {}
assert(loadfile("Core.lua"))("ItemFYI", addon)
assert(loadfile("Rules.lua"))("ItemFYI", addon)
assert(loadfile("Detection.lua"))("ItemFYI", addon)
assert(loadfile("UI.lua"))("ItemFYI", addon)
assert(loadfile("Skinning.lua"))("ItemFYI", addon)
assert(loadfile("EditMode.lua"))("ItemFYI", addon)
assert(loadfile("Settings.lua"))("ItemFYI", addon)

local eventFrame = addon.eventFrame
assert(eventFrame and eventFrame.scripts.OnEvent, "event frame was not initialized")
eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "ItemFYI")
assert(addon.button, "secure action button was not created")
assert(SlashCmdList.ITEMFYI, "slash command was not registered")
assert(addon.settingsCategory, "settings category was not registered")
SlashCmdList.ITEMFYI("")
assert(openedCategory == "ItemFYI", "bare /ifyi should open the settings category")

addon.settingsPanel.categoryChecks.container.checked = false
addon.settingsPanel.categoryChecks.container.scripts.OnClick(addon.settingsPanel.categoryChecks.container)
assert(addon.db.categories.container == false, "category checkbox should persist its value")

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
assert(addon.editModeRegistered, "button was not registered with Edit Mode")
assert(addon.db.editModeMigration == 1, "legacy position was not migrated")
assert(addon.current == nil, "empty bags should not select a candidate")

inCombat = true
addon:ResetPosition()
assert(addon.layoutPending and addon.layoutUseSavedPosition,
    "position reset in combat should be deferred without losing reset intent")
inCombat = false
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_REGEN_ENABLED")
assert(not addon.layoutPending, "deferred position reset should apply after combat")

EditModeManagerFrame.editModeActive = true
addon:SetCandidate(nil, 0)
assert(addon.button.shown, "button placeholder should be visible in Edit Mode")
assert(addon.button.alpha == 0.65, "Edit Mode placeholder should be visually muted")
EditModeManagerFrame.editModeActive = false
addon:SetCandidate(nil, 0)
assert(not addon.button.shown, "empty button should hide after leaving Edit Mode")

addon:SetCandidate({
    key = "123",
    itemID = 123,
    name = "Test Container",
    icon = 1,
    count = 2,
    bag = 0,
    slot = 4,
    reason = "Openable container — click to open",
    macro = "/use 0 4",
}, 3)

assert(addon.button.shown, "candidate should show the button")
assert(addon.button.attributes.type1 == "macro", "left click must use a secure macro")
assert(addon.button.attributes.macrotext1 == "/use 0 4", "secure macro must target the exact bag slot")
assert(addon.button.attributes.type2 == nil, "right click must not use the item")

print("load and secure-button smoke test passed")
