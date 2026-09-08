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
        SetWidth = Noop,
        SetJustifyH = Noop,
        SetWordWrap = Noop,
    }
end

local createdFrames = {}
local bagItem
local eventFrame
local merchantCloseCount = 0
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
    function frame:RegisterEvent(event)
        self.registeredEvents = self.registeredEvents or {}
        self.registeredEvents[event] = true
    end
    function frame:SetScript(script, callback) self.scripts[script] = callback end
    function frame:HookScript(script, callback) self.hooks[script] = callback end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:GetSize() return self.width, self.height end
    function frame:SetFrameLevel(level) self.frameLevel = level end
    function frame:GetFrameLevel() return self.frameLevel or 1 end
    function frame:SetClipsChildren() end
    function frame:SetWidth(width) self.width = width end
    function frame:SetOrientation() end
    function frame:SetClampedToScreen() end
    function frame:SetMovable() end
    function frame:EnableMouse() end
    function frame:RegisterForClicks(...) self.registeredClicks = { ... } end
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
    function frame:SetAllPoints() end
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
    return NewFrame(name)
end
local inCombat = false
local altDown = false
InCombatLockdown = function() return inCombat end
IsAltKeyDown = function() return altDown end
IsControlKeyDown = function() return false end
wipe = function(target) for key in pairs(target) do target[key] = nil end end
C_Timer = { After = function(_, callback) callback() end }
CloseMerchant = function()
    merchantCloseCount = merchantCloseCount + 1
    if eventFrame then
        eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_CLOSED")
    end
end
C_Item = {
    GetItemInfo = function(itemID)
        if not bagItem or bagItem.itemID ~= itemID then
            return nil
        end
        return bagItem.name, "item:" .. itemID, 4, 1, 1, "Armor", "Cosmetic", 1,
            bagItem.equipLocation, bagItem.icon, 0, 4, 0
    end,
    IsUsableItem = function() return true end,
    RequestLoadItemDataByID = Noop,
}
C_Container = {
    GetContainerNumSlots = function(bag)
        return bag == 0 and bagItem and 1 or 0
    end,
    GetContainerItemInfo = function(bag, slot)
        if bag == 0 and slot == 1 and bagItem then
            return {
                itemID = bagItem.itemID,
                hyperlink = "item:" .. bagItem.itemID,
                iconFileID = bagItem.icon,
                stackCount = 1,
            }
        end
    end,
    GetContainerItemID = function(bag, slot)
        return bag == 0 and slot == 1 and bagItem and bagItem.itemID or nil
    end,
    GetContainerItemLink = function(bag, slot)
        return bag == 0 and slot == 1 and bagItem and ("item:" .. bagItem.itemID) or nil
    end,
}
C_TooltipInfo = {
    GetBagItem = function()
        return {
            lines = bagItem and {
                { leftText = "Use: Add this appearance to your Warband collection." },
            } or {},
        }
    end,
}
C_MountJournal = {}
C_ToyBox = {}
C_PetJournal = {}
Enum = {
    ItemClass = { Recipe = 9 },
    PlayerInteractionType = {
        TradePartner = 1,
        Merchant = 5,
        Banker = 8,
        GuildBanker = 10,
        MailInfo = 17,
        Auctioneer = 21,
        Transmogrifier = 24,
        VoidStorageBanker = 26,
        BlackMarketAuctioneer = 27,
        ScrappingMachine = 40,
        ItemInteraction = 44,
        LegendaryCrafting = 48,
        ItemUpgrade = 53,
        ForgeMaster = 66,
        CharacterBanker = 67,
        AccountBanker = 68,
    },
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
GameTooltip = {
    SetOwner = function(self, owner)
        self.owner = owner
        self.lines = {}
    end,
    GetOwner = function(self) return self.owner end,
    SetBagItem = Noop,
    AddLine = function(self, text)
        self.lines[#self.lines + 1] = text
    end,
    Show = Noop,
    Hide = function(self)
        self.hideCount = (self.hideCount or 0) + 1
        self.owner = nil
    end,
}
local glowButton
ActionButtonSpellAlertManager = {
    ShowAlert = function(_, button)
        glowButton = button
        button.SpellActivationAlert = button.SpellActivationAlert or NewFrame("ItemFYISpellActivationAlert")
        button.SpellActivationAlert:SetSize(button.width, button.height)
    end,
    HideAlert = function() glowButton = nil end,
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

eventFrame = addon.eventFrame
assert(eventFrame and eventFrame.scripts.OnEvent, "event frame was not initialized")
assert(eventFrame.registeredEvents.MERCHANT_SHOW
    and eventFrame.registeredEvents.MERCHANT_CLOSED,
    "merchant safety events must be registered")
assert(eventFrame.registeredEvents.PLAYER_INTERACTION_MANAGER_FRAME_SHOW
    and eventFrame.registeredEvents.PLAYER_INTERACTION_MANAGER_FRAME_HIDE,
    "inventory-routing interaction events must be registered")
assert(eventFrame.registeredEvents.PLAYER_LOOT_SPEC_UPDATED
    and eventFrame.registeredEvents.QUEST_TURNED_IN
    and eventFrame.registeredEvents.UNIT_QUEST_LOG_CHANGED,
    "loot spec and quest completion events must be registered")
eventFrame.scripts.OnEvent(eventFrame, "ADDON_LOADED", "ItemFYI")
assert(addon.button, "secure action button was not created")
assert(addon.button.registeredClicks[1] == "AnyUp" and addon.button.registeredClicks[2] == "AnyDown",
    "secure button must register both click phases")
assert(SlashCmdList.ITEMFYI, "slash command was not registered")
assert(type(_G.ItemFYI_OnAddonCompartmentClick) == "function",
    "addon compartment click handler must be registered")
assert(addon.settingsCategory, "settings category was not registered")
assert(addon.settingsPanel.categoryChecks.curio, "settings must include a companion Curio toggle")
assert(addon.settingsPanel.categoryChecks.profession, "settings must include a profession progress item toggle")
SlashCmdList.ITEMFYI("")
assert(openedCategory == "ItemFYI", "bare /ifyi should open the settings category")
openedCategory = nil
_G.ItemFYI_OnAddonCompartmentClick()
assert(openedCategory == "ItemFYI", "addon compartment click should open settings")

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
local externalTooltipOwner = {}
GameTooltip.owner = externalTooltipOwner
local priorHideCount = GameTooltip.hideCount or 0
addon:SetCandidate(nil, 0)
assert(not addon.button.shown, "empty button should hide after leaving Edit Mode")
assert(GameTooltip.owner == externalTooltipOwner and (GameTooltip.hideCount or 0) == priorHideCount,
    "empty scans must not hide tooltips owned by other UI elements")

GameTooltip.owner = addon.button
addon:SetCandidate(nil, 0)
assert(GameTooltip.owner == nil and GameTooltip.hideCount == priorHideCount + 1,
    "empty scans should hide ItemFYI's own tooltip")

addon:SetCandidate({
    key = "123",
    itemID = 123,
    name = "Test Container",
    icon = 1,
    count = 2,
    bag = 0,
    slot = 4,
    reason = "Openable container — click to open",
    secureMacro = "/use item:123",
}, 3)

assert(addon.button.shown, "candidate should show the button")
assert(addon.button.attributes.type1 == "macro", "left click must use a secure macro action")
assert(addon.button.attributes.macrotext1 == "/use item:123",
    "secure macro must resolve the item by ID at click time")
assert(addon.button.attributes.item1 == nil, "left click should not use the equip-aware item action")
assert(addon.button.attributes.type2 == nil, "right click must not use the item")
assert(glowButton == addon.button, "candidate should use the modern spell-alert glow")
assert(addon.button.SpellActivationAlert
    and addon.button.SpellActivationAlert.width == addon.button.width * 1.7,
    "spell-alert glow should sit just outside the icon so the stack count stays readable")
assert(addon.button.badge
    and addon.button.badge:GetFrameLevel() > addon.button.SpellActivationAlert:GetFrameLevel(),
    "stack count overlay must draw above the glow")

addon.settingsPanel.showGlow.checked = false
addon.settingsPanel.showGlow.scripts.OnClick(addon.settingsPanel.showGlow)
assert(addon.db.showGlow == false, "glow checkbox should persist its value")
assert(glowButton == nil, "disabling the glow should hide the spell-alert overlay")
addon.settingsPanel.showGlow.checked = true
addon.settingsPanel.showGlow.scripts.OnClick(addon.settingsPanel.showGlow)
assert(addon.db.showGlow == true and glowButton == addon.button,
    "enabling the glow should restore the spell-alert overlay")

altDown = true
local merchantCountBeforeAlt = merchantCloseCount
addon.button.scripts.PreClick(addon.button, "LeftButton", true)
assert(addon.button.attributes.type1 == nil,
    "alt-click must clear the secure action before click-on-press")
assert(merchantCloseCount == merchantCountBeforeAlt,
    "alt-click must not close a merchant")
addon.button.scripts.PostClick(addon.button, "LeftButton", true)
addon.button.scripts.PostClick(addon.button, "LeftButton", false)
assert(addon.button.attributes.type1 == "macro" and addon.current and addon.current.itemID == 123,
    "releasing an alt-click must restore the action without consuming the item")
altDown = false

addon.db.ignored["999"] = { name = "Ignored Gem" }
addon:RefreshSettingsPanel()
assert(string.find(addon.settingsPanel.ignoredStatus.text, "Ignored Gem", 1, true),
    "settings must list ignored item names")
local ignoredEntries = addon:GetIgnoredEntries()
assert(ignoredEntries[1] and ignoredEntries[1].key == "999" and ignoredEntries[1].name == "Ignored Gem",
    "ignored entries must keep the stored name")
addon.db.ignored["999"] = nil
addon:RefreshSettingsPanel()

addon.button.scripts.PostClick(addon.button, "LeftButton", true)
assert(addon.current and addon.current.itemID == 123,
    "mouse-down follow-up must wait for the release phase")

addon:SetCandidate({
    key = "456",
    itemID = 456,
    name = "Test Appearance",
    icon = 1,
    count = 1,
    bag = 2,
    slot = 7,
    reason = "Uncollected appearance — click to learn",
    secureMacro = "/stopmacro [combat]\n/use 2 7",
    secureBySlot = true,
}, 1)
eventFrame.scripts.OnEvent(eventFrame, "BAG_UPDATE", 2)
assert(addon.current == nil and not addon.button.shown,
    "a changed bag must invalidate a slot-targeted appearance action")

bagItem = {
    itemID = 789,
    name = "Test Warband Appearance",
    icon = 1,
    equipLocation = "INVTYPE_WEAPON",
}
addon:ScanBags("merchant safety test")
assert(addon.current and addon.current.itemID == 789 and addon.current.secureBySlot,
    "equippable appearance should be selected outside inventory-routing windows")

eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_SHOW")
assert(addon.merchantOpen and not addon:IsSlotActionBlocked()
    and addon.current and addon.current.itemID == 789,
    "closable merchants must keep slot-targeted appearance actions available")

addon.button.scripts.OnEnter(addon.button)
local merchantWarningFound = false
for _, line in ipairs(GameTooltip.lines) do
    if line == "Vendor will close before use" then
        merchantWarningFound = true
    end
end
assert(merchantWarningFound,
    "slot-targeted appearances must explain that using them closes the vendor")

addon.button.scripts.PreClick(addon.button, "LeftButton", true)
assert(merchantCloseCount == 1 and not addon.merchantOpen,
    "a merchant must close before the secure slot action runs")
addon.button.scripts.PostClick(addon.button, "LeftButton", true)
addon.button.scripts.PreClick(addon.button, "LeftButton", false)
addon.button.scripts.PostClick(addon.button, "LeftButton", false)
assert(not addon.merchantOpen and not addon:IsSlotActionBlocked()
    and addon.current and addon.current.itemID == 789,
    "the safe slot action must remain available after closing the merchant")

local closeMerchant = CloseMerchant
eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_SHOW")
CloseMerchant = function() error("simulated merchant close failure") end
addon.button.scripts.PreClick(addon.button, "LeftButton", true)
assert(addon:IsSlotActionBlocked() and addon.current == nil,
    "a failed merchant handoff must abort and suppress the secure slot action")
CloseMerchant = closeMerchant
eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_CLOSED")
addon:ScanBags("merchant close failure ended")
assert(not addon:IsSlotActionBlocked() and addon.current and addon.current.itemID == 789,
    "ending a failed merchant handoff must restore the eligible appearance action")

local closeMerchantAgain = CloseMerchant
CloseMerchant = nil
eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_CLOSED")
eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_SHOW")
assert(addon:IsSlotActionBlocked() and addon.current == nil,
    "clients unable to close a merchant must suppress risky slot actions")
eventFrame.scripts.OnEvent(eventFrame, "MERCHANT_CLOSED")
CloseMerchant = closeMerchantAgain
addon:ScanBags("merchant fallback ended")
assert(not addon:IsSlotActionBlocked() and addon.current and addon.current.itemID == 789,
    "ending the merchant fallback must restore the eligible appearance action")

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
    Enum.PlayerInteractionType.Banker)
assert(addon:IsSlotActionBlocked() and addon.current == nil,
    "bank interactions must suppress slot-targeted appearance actions")

eventFrame.scripts.OnEvent(eventFrame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
    Enum.PlayerInteractionType.Banker)
assert(not addon:IsSlotActionBlocked() and addon.current and addon.current.itemID == 789,
    "closing an inventory-routing interaction must restore appearance actions")

local generation = addon.scanGeneration
eventFrame.scripts.OnEvent(eventFrame, "UNIT_QUEST_LOG_CHANGED", "target")
assert(addon.scanGeneration == generation,
    "other-unit quest log changes must not scan")
eventFrame.scripts.OnEvent(eventFrame, "UNIT_QUEST_LOG_CHANGED", "player")
assert(addon.scanGeneration > generation,
    "player quest log changes must rescan")
generation = addon.scanGeneration
eventFrame.scripts.OnEvent(eventFrame, "PLAYER_LOOT_SPEC_UPDATED")
assert(addon.scanGeneration > generation,
    "loot spec changes must rescan")

print("load and secure-button smoke test passed")
