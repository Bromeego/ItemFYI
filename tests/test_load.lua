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
    }
end

local createdFrames = {}
local function NewFrame(name)
    local frame = {
        name = name,
        scripts = {},
        attributes = {},
        shown = false,
    }
    function frame:RegisterEvent() end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:SetSize() end
    function frame:SetClampedToScreen() end
    function frame:SetMovable() end
    function frame:EnableMouse() end
    function frame:RegisterForClicks() end
    function frame:RegisterForDrag() end
    function frame:Hide() self.shown = false end
    function frame:Show() self.shown = true end
    function frame:CreateTexture() return NewRegion() end
    function frame:CreateFontString() return NewRegion() end
    function frame:SetAttribute(key, value) self.attributes[key] = value end
    function frame:ClearAllPoints() end
    function frame:SetPoint(point, _, relativePoint, x, y)
        self.point = { point, relativePoint, x, y }
    end
    function frame:GetPoint()
        local point = self.point or { "CENTER", "CENTER", 0, -120 }
        return point[1], UIParent, point[2], point[3], point[4]
    end
    function frame:StartMoving() end
    function frame:StopMovingOrSizing() end
    createdFrames[#createdFrames + 1] = frame
    return frame
end

UIParent = {}
CreateFrame = function(_, name) return NewFrame(name) end
InCombatLockdown = function() return false end
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

local addon = {}
assert(loadfile("Core.lua"))("ItemFYI", addon)
assert(loadfile("Rules.lua"))("ItemFYI", addon)
assert(loadfile("Detection.lua"))("ItemFYI", addon)
assert(loadfile("UI.lua"))("ItemFYI", addon)

local eventFrame = addon.eventFrame
assert(eventFrame and eventFrame.scripts.OnEvent, "event frame was not initialized")
eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "ItemFYI")
assert(addon.button, "secure action button was not created")
assert(SlashCmdList.ITEMFYI, "slash command was not registered")

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOGIN")
assert(addon.current == nil, "empty bags should not select a candidate")

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

