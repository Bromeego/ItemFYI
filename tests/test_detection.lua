_G = _G or _ENV

local tooltipText = ""
local tooltipLines
local itemData = {}

C_Item = {
    GetItemInfo = function(itemID)
        local data = assert(itemData[itemID], "missing test item " .. tostring(itemID))
        return data.name, "item:" .. itemID, 1, 1, 1, data.itemType, data.itemSubType,
            1, "", data.icon or 1, 0, data.classID, data.subclassID
    end,
    GetItemInfoInstant = function() end,
    IsUsableItem = function() return true end,
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

PlayerHasToy = function() return false end
Enum = { ItemClass = { Recipe = 9 } }

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

local category = addon:ClassifyItem(Context(280732))
assert(category == "container", "explicit Mistcrest rule failed")

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

category = addon:ClassifyItem(Context(279382, { stackCount = 1 }))
assert(category == nil, "single Venom-Cursed Fragment should not be actionable")

category = addon:ClassifyItem(Context(279382, { stackCount = 2 }))
assert(category == "container", "two Venom-Cursed Fragments should be actionable")

category = addon:ClassifyItem(Context(279382, { stackCount = 1, totalCount = 2 }))
assert(category == "container", "split Venom-Cursed Fragment stacks should use their bag total")

category = addon:ClassifyItem(Context(268650, { stackCount = 4 }))
assert(category == nil, "four Ascendant Voidshards should not be actionable")

category = addon:ClassifyItem(Context(268650, { stackCount = 5 }))
assert(category == "container", "five Ascendant Voidshards should be actionable")

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

tooltipText = "Housing Decor\nUse: Add this decor to your collection."
category = addon:ClassifyItem(Context(104))
assert(category == "decor", "housing decor detection failed")

tooltipText = "Housing Dye\nUsed to recolour housing decor."
category = addon:ClassifyItem(Context(108, { itemType = "Housing", itemSubType = "Dye" }))
assert(category == nil, "non-usable housing dye should not be actionable")

tooltipText = "Use: Collect the appearances of the Test Ensemble."
category = addon:ClassifyItem(Context(105))
assert(category == "transmog", "transmog token detection failed")

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

print("detection tests passed")
