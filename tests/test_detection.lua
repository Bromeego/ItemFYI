_G = _G or _ENV

local tooltipText = ""
local tooltipLines
local itemData = {}
local itemUsable = true

C_Item = {
    GetItemInfo = function(itemID)
        -- 4242 is the unloaded-item probe used by BuildContext tests.
        if itemID == 4242 then
            return nil
        end
        local data = assert(itemData[itemID], "missing test item " .. tostring(itemID))
        return data.name, "item:" .. itemID, 1, 1, 1, data.itemType, data.itemSubType,
            1, "", data.icon or 1, 0, data.classID, data.subclassID
    end,
    GetItemInfoInstant = function() end,
    IsUsableItem = function() return itemUsable end,
    RequestLoadItemDataByID = function() end,
}

C_Container = {
    GetContainerItemID = function() return nil end,
    GetContainerItemLink = function(_, _, itemID) return itemID and ("item:" .. itemID) end,
}

C_TooltipInfo = {
    GetBagItem = function()
        return { lines = tooltipLines or { { leftText = tooltipText } } }
    end,
}

C_MountJournal = {
    GetMountFromItem = function(itemID) return itemID == 101 and 9001 or nil end,
    GetMountInfoByID = function()
        return "Test Mount", 1, 1, false, true, 1, false, false, nil, false, false
    end,
}

C_ToyBox = {
    GetToyInfo = function(itemID) return itemID == 102 and "Test Toy" or nil end,
    IsToyKnown = function() return false end,
}

C_PetJournal = {
    GetNumCollectedInfo = function(speciesID)
        if speciesID == 555 then
            return 0, 1
        end
        return 0, 3
    end,
    GetPetInfoByItemID = function(itemID)
        if itemID == 271185 then
            return "Emberlyn", 1, 1, 262985, nil, nil, nil, nil, nil, nil, nil, 1, 555
        end
        return nil
    end,
}

local completedQuests = {}
C_QuestLog = {
    IsQuestFlaggedCompleted = function(questID)
        return completedQuests[questID] == true
    end,
}

PlayerHasToy = function() return false end
C_TransmogCollection = {
    PlayerHasTransmogByItemInfo = function(itemID)
        return itemID == 1234
    end,
}
Enum = {
    ItemClass = { Recipe = 9, Miscellaneous = 15, Battlepet = 17 },
    ItemMiscellaneousSubclass = { CompanionPet = 2 },
    TooltipDataType = { Item = 0, BattlePet = 6, CompanionPet = 9 },
}
local fishingSkill = 200
GetProfessions = function() return nil, nil, nil, 4 end
GetProfessionInfo = function(professionIndex)
    if professionIndex == 4 then
        return "Fishing", nil, fishingSkill, 300
    end
end

local addon = {}
assert(loadfile("Rules.lua"))("ItemFYI", addon)
assert(loadfile("Detection.lua"))("ItemFYI", addon)

local function Context(itemID, fields)
    fields = fields or {}
    fields.itemID = itemID
    fields.bag = fields.bag or 0
    fields.slot = fields.slot or 1
    fields.link = fields.link or ("item:" .. itemID)
    fields.itemType = fields.itemType or "Miscellaneous"
    fields.itemSubType = fields.itemSubType or "Other"
    return fields
end

local requestedID
local originalRequest = C_Item.RequestLoadItemDataByID
C_Item.RequestLoadItemDataByID = function(itemID)
    requestedID = itemID
end
assert(addon:BuildContext(0, 1, { itemID = 4242 }) == nil,
    "unloaded items should not build a context")
assert(requestedID == 4242, "unloaded items should request item data")
assert(addon.pendingItemLoads and addon.pendingItemLoads[4242] == true,
    "unloaded items should be remembered for a later rescan")
assert(addon:ShouldRescanForLoadedItem(19019, true) == false,
    "unrelated item loads must not request a bag rescan")
assert(addon:ShouldRescanForLoadedItem(4242, false) == false
    and addon.pendingItemLoads[4242] == true,
    "a failed requested load should wait for a later success")
assert(addon:ShouldRescanForLoadedItem(4242, true) == true,
    "a previously requested item load should request a bag rescan")
C_Item.RequestLoadItemDataByID = originalRequest

addon.useScanCache = true
local snapshotCalls = 0
local originalGetBagItem = C_TooltipInfo.GetBagItem
C_TooltipInfo.GetBagItem = function(...)
    snapshotCalls = snapshotCalls + 1
    return originalGetBagItem(...)
end
tooltipText = "Use: Open the satchel."
local firstSnapshot = addon:GetTooltipSnapshot(Context(100, {
    hasLoot = true,
    bag = 1,
    slot = 2,
    stackCount = 1,
}))
local afterFirst = snapshotCalls
local secondSnapshot = addon:GetTooltipSnapshot(Context(100, {
    hasLoot = true,
    bag = 1,
    slot = 2,
    stackCount = 1,
}))
assert(snapshotCalls == afterFirst, "unchanged bag slots should reuse tooltip snapshots")
assert(firstSnapshot.text == secondSnapshot.text,
    "cached tooltip snapshots should keep the original text")
addon:GetTooltipSnapshot(Context(100, {
    hasLoot = true,
    bag = 1,
    slot = 2,
    stackCount = 2,
}))
assert(snapshotCalls > afterFirst, "stack changes should refresh the tooltip snapshot")
addon:InvalidateScanCache()
addon:GetTooltipSnapshot(Context(100, {
    hasLoot = true,
    bag = 1,
    slot = 2,
    stackCount = 2,
}))
assert(snapshotCalls > afterFirst + 1, "invalidating the scan cache should refetch tooltips")

addon:GetTooltipSnapshot(Context(200, {
    hasLoot = true,
    bag = 5,
    slot = 2,
    stackCount = 1,
}))
addon:InvalidateScanCacheForItem(100)
local afterItemInvalidate = snapshotCalls
addon:GetTooltipSnapshot(Context(100, {
    hasLoot = true,
    bag = 1,
    slot = 2,
    stackCount = 2,
}))
assert(snapshotCalls > afterItemInvalidate,
    "using an item should refresh other copies of that item ID")
addon:GetTooltipSnapshot(Context(200, {
    hasLoot = true,
    bag = 5,
    slot = 2,
    stackCount = 1,
}))
assert(snapshotCalls == afterItemInvalidate + 1,
    "invalidating one item ID should keep other slot snapshots")
C_TooltipInfo.GetBagItem = originalGetBagItem
addon.useScanCache = nil
tooltipText = ""

local category = addon:ClassifyItem(Context(280732))
assert(category == "container", "explicit Mistcrest rule failed")

tooltipText = "Use: Gut the Shimmersiren. You monster."
category = addon:ClassifyItem(Context(238378))
assert(category == "profession", "generic single-item gutting action failed")

itemUsable = false
category = addon:ClassifyItem(Context(238378))
assert(category == nil, "an unusable single-item gutting action should remain hidden")
itemUsable = true

tooltipText = "Use: Salvage what you can from the Rimefin Tuna."
category = addon:ClassifyItem(Context(199346))
assert(category == "profession", "generic single-item salvage action failed")

tooltipText = "Use: Disenchant this item to produce Soothsayer's Dust."
category = addon:ClassifyItem(Context(72018, { itemType = "Quest" }))
assert(category == "profession", "bag-item disenchant-to-produce actions should be processed")

itemUsable = false
category = addon:ClassifyItem(Context(72018, { itemType = "Quest" }))
assert(category == nil, "an unusable disenchant-to-produce action should remain hidden")
itemUsable = true

tooltipText = "Can be disenchanted."
category = addon:ClassifyItem(Context(72019, { itemType = "Weapon", equipLocation = "INVTYPE_WEAPON" }))
assert(category == nil, "ordinary disenchantable gear must not be treated as a processing action")

local macro, secureBySlot = addon:BuildSecureUse(Context(201, {
    bag = 2,
    slot = 7,
    equipLocation = "INVTYPE_WEAPON",
}), "transmog")
assert(macro == "/stopmacro [combat]\n/use 2 7" and secureBySlot,
    "equippable appearance tokens must use their current bag slot")

macro, secureBySlot = addon:BuildSecureUse(Context(202, { bag = 3, slot = 5 }), "container")
assert(macro == "/use item:202" and not secureBySlot,
    "containers must continue resolving by item ID")

tooltipText = "Use: Combine 2 Fractured Sparks of Starlight with 0 Valorstones "
    .. "to create a Spark of Starlight."
category = addon:ClassifyItem(Context(231757, { stackCount = 1 }))
assert(category == nil, "a single Fractured Spark of Starlight should not be actionable")

category = addon:ClassifyItem(Context(231757, { stackCount = 2 }))
assert(category == "container", "two Fractured Sparks of Starlight should be actionable")

category = addon:ClassifyItem(Context(231757, { stackCount = 1, totalCount = 2 }))
assert(category == "container", "split Fractured Spark stacks should use their bag total")

itemUsable = false
category = addon:ClassifyItem(Context(231757, { stackCount = 2 }))
assert(category == nil, "Fractured Sparks should remain hidden when their conversion is unusable")
itemUsable = true

tooltipText = "Use: Combine 10 Bloom Baubles to create an Aquarius Bloom."
category = addon:ClassifyItem(Context(118, { stackCount = 9, totalCount = 9 }))
assert(category == nil, "a numeric stack conversion should remain hidden below its tooltip threshold")

category = addon:ClassifyItem(Context(118, { stackCount = 6, totalCount = 10 }))
assert(category == "container", "numeric stack conversions should use their whole-bag count")

itemUsable = false
category = addon:ClassifyItem(Context(118, { stackCount = 10, totalCount = 10 }))
assert(category == nil, "an unusable numeric stack conversion should remain hidden")
itemUsable = true

tooltipText = "Use: Combine the Ace through Eight to create a deck."
category = addon:ClassifyItem(Context(119, { stackCount = 8, totalCount = 8 }))
assert(category == nil, "distinct multi-part combines must not be treated as stack thresholds")

tooltipText = "Use: Combine two fragments to create a Champion Venom-Cursed item "
    .. "for your specialization."
category = addon:ClassifyItem(Context(279382, { stackCount = 1 }))
assert(category == nil, "single Venom-Cursed Fragment should not be actionable")

category = addon:ClassifyItem(Context(279382, { stackCount = 2 }))
assert(category == "container", "two Venom-Cursed Fragments should be actionable")

category = addon:ClassifyItem(Context(279382, { stackCount = 1, totalCount = 2 }))
assert(category == "container", "split Venom-Cursed Fragment stacks should use their bag total")

tooltipText = "Use: Combine many fragments to create a mystery item."
category = addon:ClassifyItem(Context(120, { stackCount = 99, totalCount = 99 }))
assert(category == nil, "unknown combine quantities must not invent a stack threshold")

tooltipText = "Use: Combine one rune with one catalyst to create a sigil."
category = addon:ClassifyItem(Context(121, { stackCount = 1, totalCount = 1 }))
assert(category == nil, "single-item dependency recipes must not become stack conversions")

category = addon:ClassifyItem(Context(268650, { stackCount = 4 }))
assert(category == nil, "four Ascendant Voidshards should not be actionable")

category = addon:ClassifyItem(Context(268650, { stackCount = 5 }))
assert(category == "container", "five Ascendant Voidshards should be actionable")

itemUsable = false
category = addon:ClassifyItem(Context(268650, { stackCount = 5 }))
assert(category == nil, "unusable Voidshards should remain hidden")
category = addon:ClassifyItem(Context(279576, { stackCount = 4 }))
assert(category == nil, "unusable Void Vestiges should remain hidden")
itemUsable = true

category = addon:ClassifyItem(Context(279576, { stackCount = 4 }))
assert(category == "container", "four Void Vestiges should be actionable")

category = addon:ClassifyItem(Context(100, { hasLoot = true }))
assert(category == "container", "generic hasLoot container detection failed")

category = addon:ClassifyItem(Context(101))
assert(category == "mount", "mount detection failed")

category = addon:ClassifyItem(Context(102))
assert(category == "toy", "toy detection failed")

category = addon:ClassifyItem(Context(103, { link = "|Hbattlepet:77:1:1:1:1:1:0:0|h[Test Pet]|h" }))
assert(category == "pet", "battle-pet detection failed")

tooltipText = "Use: Teaches you how to summon and dismiss this companion."
category = addon:ClassifyItem(Context(271185))
assert(category == "pet", "non-battle companion species lookup failed")

C_PetJournal.GetPetInfoByItemID = function() return nil end
category = addon:ClassifyItem(Context(271186))
assert(category == "pet", "companion tooltip fallback failed")

tooltipText = "Rank 2/4\nUse: Add this Curio to your companion's collection."
category = addon:ClassifyItem(Context(113))
assert(category == "curio", "companion Curio detection failed")

tooltipText = "Already known\nUse: Add this Curio to your companion's collection."
category = addon:ClassifyItem(Context(115))
assert(category == nil, "an already-known companion Curio should not be actionable")

tooltipText = "A Mislaid Curiosity may appear near you."
category = addon:ClassifyItem(Context(114))
assert(category == nil, "Curio flavour text without a collection action should not be actionable")

tooltipText = "Use: Increase Midnight Fishing skill by 100, up to a max of 300."
category = addon:ClassifyItem(Context(254875))
assert(category == "profession", "permanent profession skill item detection failed")

fishingSkill = 300
category = addon:ClassifyItem(Context(254875))
assert(category == nil, "a profession skill item should not appear at its stated cap")
fishingSkill = 200

tooltipText = "Use: Study to increase your Midnight Alchemy Knowledge by 3.\nRequires Midnight Alchemy (1)"
category = addon:ClassifyItem(Context(238539))
assert(category == "profession", "generic profession knowledge detection failed")

tooltipLines = {
    { leftText = "Use: Study to increase your Midnight Alchemy Knowledge by 3.", leftColor = { r = 0, g = 1, b = 0 } },
    { leftText = "Requires Midnight Alchemy (1)", leftColor = { r = 1, g = 0.125, b = 0.125 } },
}
category = addon:ClassifyItem(Context(238539))
assert(category == nil, "knowledge items for an unlearned profession should not appear")
tooltipLines = nil

tooltipText = "Use: Study to increase your Midnight Alchemy Knowledge by 1."
category = addon:ClassifyItem(Context(245755))
assert(category == "profession", "unused weekly treatise should appear")
tooltipLines = {
    { leftText = "Use: Study to increase your Midnight Alchemy Knowledge by 1.", leftColor = { r = 0, g = 1, b = 0 } },
    { leftText = "Requires Midnight Alchemy (25)", leftColor = { r = 1, g = 0.125, b = 0.125 } },
}
category = addon:ClassifyItem(Context(245755))
assert(category == nil, "a treatise for an unmet profession requirement should not appear")
tooltipLines = nil
completedQuests[95127] = true
category = addon:ClassifyItem(Context(245755))
assert(category == nil, "a treatise already used this week should not appear")
completedQuests[95127] = nil

tooltipText = "Use: Increases Fishing skill by 25 for 10 min."
category = addon:ClassifyItem(Context(116))
assert(category == nil, "temporary profession buffs should not be actionable")

tooltipText = "Use: Gut and clean 5 Small Fat Sleeper."
category = addon:ClassifyItem(Context(111651, { stackCount = 4, totalCount = 4 }))
assert(category == nil, "Draenor fish should not appear below their cleaning threshold")
category = addon:ClassifyItem(Context(111651, { stackCount = 3, totalCount = 5 }))
assert(category == "profession", "Draenor fish should use their whole-bag cleaning threshold")

tooltipText = "Housing Decor\nUse: Add this decor to your collection."
category = addon:ClassifyItem(Context(104))
assert(category == "decor", "housing decor detection failed")

tooltipText = "Housing Decor\nUse: Add this Decor to your House Chest.\n"
    .. "Requires Midnight Blacksmithing (50)"
tooltipLines = {
    { leftText = "Housing Decor", leftColor = { r = 1, g = 1, b = 1 } },
    { leftText = "Use: Add this Decor to your House Chest.", leftColor = { r = 0, g = 1, b = 0 } },
    { leftText = "Requires Midnight Blacksmithing (50)", leftColor = { r = 1, g = 0.125, b = 0.125 } },
}
category = addon:ClassifyItem(Context(117, { itemType = "Housing", itemSubType = "Housing Decor" }))
assert(category == nil, "housing decor with an unmet profession requirement should not appear")

tooltipLines[3].leftColor = { GetRGB = function() return 1, 1, 1 end }
category = addon:ClassifyItem(Context(117, { itemType = "Housing", itemSubType = "Housing Decor" }))
assert(category == "decor", "housing decor with a satisfied profession requirement should appear")
tooltipLines = nil

tooltipText = "Housing Dye\nUsed to recolour housing decor."
category = addon:ClassifyItem(Context(108, { itemType = "Housing", itemSubType = "Dye" }))
assert(category == nil, "non-usable housing dye should not be actionable")

tooltipText = "Use: Collect the appearances of the Test Ensemble."
category = addon:ClassifyItem(Context(105))
assert(category == "transmog", "transmog token detection failed")

category = addon:ClassifyItem(Context(1234))
assert(category == nil, "appearances already known to C_TransmogCollection should not appear")

tooltipText = "Use: Opens a portal to Dalaran."
category = addon:ClassifyItem(Context(130))
assert(category == nil, "portal open-text must not be treated as a container")

tooltipText = "Use: Open the satchel."
category = addon:ClassifyItem(Context(131))
assert(category == "container", "explicit open actions should remain containers")

tooltipText = "Naval Equipment\nSoulbound\nUse: Equip a ship with a Trained Shark Tank.\nCounters: Minelayer"
category = addon:ClassifyItem(Context(127892, { itemSubType = "Naval Equipment" }))
assert(category == "progress", "WoD naval equipment should be actionable")

tooltipText = "Use: Equip a ship with an Ice Cutter."
category = addon:ClassifyItem(Context(127884, { itemSubType = "Other" }))
assert(category == "progress", "naval equipment use text should be detected without the item subtype")

itemUsable = false
category = addon:ClassifyItem(Context(127884, { itemSubType = "Naval Equipment" }))
assert(category == nil, "unusable naval equipment should remain hidden")
itemUsable = true

tooltipText = "Use: Equip this cloak."
category = addon:ClassifyItem(Context(132, { itemSubType = "Cloth" }))
assert(category == nil, "ordinary equip actions must not be treated as garrison items")

tooltipText = "Use: Increases a follower's armor item level by 6."
category = addon:ClassifyItem(Context(114808))
assert(category == "progress", "garrison follower upgrades should be actionable")

tooltipText = "Use: Instantly upgrade a follower's weapon item level to 675."
category = addon:ClassifyItem(Context(120302))
assert(category == "progress", "garrison follower item-level tokens should be actionable")

tooltipText = "Use: Provides the plans needed to upgrade your Barn to Level 2."
category = addon:ClassifyItem(Context(111929))
assert(category == "progress", "garrison building blueprints should be actionable")

tooltipText = "Use: Grants 750 reputation with the Army of the Light. (2 Sec Cooldown)\nCurrent: Paragon (250/10,000)"
category = addon:ClassifyItem(Context(152956))
assert(category == "progress", "Legion reputation insignias should be actionable at Paragon")

tooltipText = "Use: Grants 2000 reputation with the Army of the Light. (2 Sec Cooldown)"
category = addon:ClassifyItem(Context(152957))
assert(category == "progress", "numeric reputation grants should be detected generically")

itemUsable = false
category = addon:ClassifyItem(Context(152956))
assert(category == nil, "unusable reputation tokens should remain hidden")
itemUsable = true

tooltipText = "A badge of the Army of the Light.\nReputation with this faction is earned through Argus world quests."
category = addon:ClassifyItem(Context(133))
assert(category == nil, "flavour text mentioning reputation must not become a reputation token")

tooltipText = "Use: Grants 750 artifact power to your currently equipped artifact."
category = addon:ClassifyItem(Context(134))
assert(category == nil, "artifact power items must not be treated as reputation tokens")

local pearlTooltips = {
    { 278335, "a cerulean hue" },
    { 278336, "a red hue" },
    { 278337, "an amber hue" },
    { 278339, "a purple hue" },
    { 278340, "Ula'tek's essence" },
}
for _, pearl in ipairs(pearlTooltips) do
    tooltipText = ("Use: Learn to infuse The Coiled Huntress with %s, unlocking additional "
        .. "visual effects when she sheds her skin.\nThis effect is Warband-wide."):format(pearl[2])
    category = addon:ClassifyItem(Context(pearl[1]))
    assert(category == "transmog", ("Coiled Huntress pearl %d should be learnable"):format(pearl[1]))
end

itemUsable = false
category = addon:ClassifyItem(Context(278336))
assert(category == nil, "an unusable visual-effect unlock should remain hidden")
itemUsable = true

tooltipText = "Use: Learn to infuse a weapon with power."
category = addon:ClassifyItem(Context(122))
assert(category == nil, "unrelated infusion actions must not be treated as visual unlocks")

tooltipText = "Use: Create a class set item appropriate for your loot specialization (Balance).\n"
    .. "Classes: Rogue, Death Knight, Mage, Druid\nRequires Level 30"
category = addon:ClassifyItem(Context(45661))
assert(category == "transmog", "usable class-set tier token detection failed")

tooltipText = "Use: Create a soulbound set leg item appropriate for your class."
category = addon:ClassifyItem(Context(280001))
assert(category == "transmog", "12.1 soulbound set-slot tokens should be detected")

tooltipText = "Use: Create a soulbound set helm item appropriate for your class."
category = addon:ClassifyItem(Context(280002))
assert(category == "transmog", "12.1 helm set tokens should use the same detector")

tooltipText = "Use: Create a soulbound mystery item appropriate for your class."
category = addon:ClassifyItem(Context(280003))
assert(category == nil, "non-set creations must not be treated as tier tokens")

macro, secureBySlot = addon:BuildSecureUse(Context(45661, { bag = 1, slot = 4 }), "transmog")
assert(macro == "/use item:45661" and not secureBySlot,
    "non-equippable tier tokens must use a stable item-ID action")

itemUsable = false
category = addon:ClassifyItem(Context(45661))
assert(category == nil, "tier tokens unusable by the current character should not appear")
itemUsable = true

tooltipLines = {
    {
        leftText = "Use: Create a class set item appropriate for your loot specialization.",
        leftColor = { r = 0, g = 1, b = 0 },
    },
    {
        leftText = "Classes: Paladin, Priest, Warlock",
        leftColor = { r = 1, g = 0.125, b = 0.125 },
    },
}
category = addon:ClassifyItem(Context(45644))
assert(category == nil, "tier tokens with an unmet class restriction should not appear")
tooltipLines = nil

tooltipText = "Already known\nUse: Teaches you how to craft a test item."
category = addon:ClassifyItem(Context(106, { itemType = "Recipe", classID = 9 }))
assert(category == nil, "known recipe should not be actionable")

tooltipText = "Use: Teaches you how to craft a test item."
category = addon:ClassifyItem(Context(107, { itemType = "Recipe", classID = 9 }))
assert(category == "recipe", "unknown recipe detection failed")

tooltipText = "Use: Teaches you how to craft a test item.\nRequires Northrend Leatherworking (75)"
tooltipLines = {
    { leftText = "Use: Teaches you how to craft a test item.", leftColor = { r = 0, g = 1, b = 0 } },
    { leftText = "Requires Northrend Leatherworking (75)", leftColor = { r = 1, g = 0.125, b = 0.125 } },
}
category = addon:ClassifyItem(Context(111, { itemType = "Recipe", classID = 9 }))
assert(category == nil, "a recipe unusable by this character should not be actionable")

tooltipLines = {
    { leftText = "Use: Teaches you how to craft a test item.", leftColor = { r = 0, g = 1, b = 0 } },
    {
        leftText = "Requires Northrend Leatherworking (75)",
        leftColor = { GetRGB = function() return 1, 1, 1 end },
    },
}
category = addon:ClassifyItem(Context(112, { itemType = "Recipe", classID = 9 }))
assert(category == "recipe", "a recipe with a satisfied requirement should remain actionable")
tooltipLines = nil

tooltipText = "Locked\nRequires Lockpicking"
category = addon:ClassifyItem(Context(109, { hasLoot = true }))
assert(category == nil, "locked lockbox should not be actionable")

tooltipText = "Unlocked strongbox"
category = addon:ClassifyItem(Context(110, { hasLoot = true }))
assert(category == "container", "unlocked container should remain actionable")

tooltipText = "You have collected all of the transmog looks contained in this cache.\n<Right Click to Open>"
category = addon:ClassifyItem(Context(264321, { hasLoot = true }))
assert(category == nil, "completed appearance cache should not be actionable")

-- BattlePetToolTip_Show copies GameTooltip:GetPoint(1). After a reload that
-- point does not exist yet, so a scan-tooltip SetBagItem on a caged pet errors.
local tooltipOverride
local surfaceArgsCalls = 0
TooltipUtil = {
    SurfaceArgs = function()
        surfaceArgsCalls = surfaceArgsCalls + 1
    end,
}
C_TooltipInfo.GetBagItem = function()
    if tooltipOverride then
        return tooltipOverride
    end
    return { lines = {} }
end
tooltipLines = nil
tooltipText = ""

local setBagItemCalls = 0
CreateFrame = function(_, name)
    return {
        SetOwner = function() end,
        ClearLines = function() end,
        GetName = function() return name end,
        NumLines = function() return 0 end,
        SetBagItem = function()
            setBagItemCalls = setBagItemCalls + 1
            error('BattlePetTooltip:SetPoint(): Usage: ("point" [, region or nil] [, "relativePoint"] [, offsetX, offsetY]')
        end,
    }
end
UIParent = UIParent or {}
addon.HideCompanionTooltips = function() end

C_PetJournal.GetPetInfoByItemID = function(itemID)
    if itemID == 271185 then
        return "Emberlyn", 1, 1, 262985, nil, nil, nil, nil, nil, nil, nil, 1, 555
    end
    if itemID == "item:271185" then
        error("GetPetInfoByItemID requires an item ID")
    end
    return nil
end

category = addon:ClassifyItem(Context(103, { link = "|Hbattlepet:77:1:1:1:1:1:0:0|h[Test Pet]|h" }))
assert(category == "pet", "battle-pet classification must not require a scan tooltip")
assert(setBagItemCalls == 0, "known battle pets must not call SetBagItem on the scan tooltip")

category = addon:ClassifyItem(Context(271185))
assert(category == "pet", "item-ID battle-pet lookup must not require a scan tooltip")
assert(setBagItemCalls == 0, "GetPetInfoByItemID pets must not call SetBagItem on the scan tooltip")

tooltipOverride = { battlePetSpeciesID = 77, lines = {} }
category = addon:ClassifyItem(Context(1628, { link = "item:1628" }))
assert(category == "pet", "TooltipData.battlePetSpeciesID must classify caged pets")
assert(setBagItemCalls == 0, "battlePetSpeciesID pets must not call SetBagItem on the scan tooltip")
assert(surfaceArgsCalls > 0, "TooltipUtil.SurfaceArgs should be used when it exists")

tooltipOverride = { battlePet = { speciesID = 77 }, lines = {} }
category = addon:ClassifyItem(Context(1629, { link = "item:1629" }))
assert(category == "pet", "nested battlePet.speciesID must still classify caged pets")
assert(setBagItemCalls == 0, "nested battlePet pets must not call SetBagItem on the scan tooltip")

tooltipOverride = {
    args = { { field = "battlePetSpeciesID", intVal = 77 } },
    lines = {},
}
category = addon:ClassifyItem(Context(1630, { link = "item:1630" }))
assert(category == "pet", "packed TooltipData.args battlePetSpeciesID must classify caged pets")
assert(setBagItemCalls == 0, "args-field battle pets must not call SetBagItem on the scan tooltip")

tooltipOverride = {
    type = Enum.TooltipDataType.BattlePet,
    hyperlink = "|Hbattlepet:77:1:1:1:1:1:0:0|h[Test Pet]|h",
    lines = {},
}
category = addon:ClassifyItem(Context(1631, { link = "item:1631" }))
assert(category == "pet", "battle-pet tooltip type plus hyperlink must classify caged pets")
assert(setBagItemCalls == 0, "battle-pet tooltip type must not call SetBagItem on the scan tooltip")

tooltipOverride = { lines = {} }
category = addon:ClassifyItem(Context(82800, {
    link = "item:82800",
    classID = 15,
    subclassID = 2,
    itemSubType = "Companion Pets",
}))
assert(setBagItemCalls == 0, "companion-pet item class must not call SetBagItem on the scan tooltip")

category = addon:ClassifyItem(Context(100, { hasLoot = true }))
assert(category == "container", "scan-tooltip SetBagItem errors must not hide openable items")
assert(setBagItemCalls == 1, "non-pet items should still fall back to the scan tooltip")

TooltipUtil = nil
tooltipOverride = { battlePetSpeciesID = 77, lines = {} }
category = addon:ClassifyItem(Context(1632, { link = "item:1632" }))
assert(category == "pet", "missing TooltipUtil.SurfaceArgs must not break battle-pet detection")

print("detection tests passed")
