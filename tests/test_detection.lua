_G = _G or _ENV

local tooltipText = ""
local itemData = {}

C_Item = {
    GetItemInfo = function(itemID)
        local data = assert(itemData[itemID], "missing test item " .. tostring(itemID))
        return data.name, "item:" .. itemID, 1, 1, 1, data.itemType, data.itemSubType,
            1, "", data.icon or 1, 0, data.classID, data.subclassID
    end,
    GetItemInfoInstant = function() end,
    RequestLoadItemDataByID = function() end,
}

C_Container = {
    GetContainerItemID = function() return nil end,
    GetContainerItemLink = function(_, _, itemID) return itemID and ("item:" .. itemID) end,
}

C_TooltipInfo = {
    GetBagItem = function()
        return { lines = { { leftText = tooltipText } } }
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
    fields.bag = 0
    fields.slot = 1
    fields.link = fields.link or ("item:" .. itemID)
    fields.itemType = fields.itemType or "Miscellaneous"
    fields.itemSubType = fields.itemSubType or "Other"
    return fields
end

local category = addon:ClassifyItem(Context(280732))
assert(category == "container", "explicit Mistcrest rule failed")

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
