local _, addon = ...

-- Small exception list for actionable items that Blizzard does not consistently
-- expose as loot-bearing containers. Generic detection remains the primary path.
addon.Rules = {
    -- Midnight crest containers
    [246751] = { category = "container", reason = "Champion Dawncrest satchel — click to open" },
    [246752] = { category = "container", reason = "Hero Dawncrest pack — click to open" },
    [246753] = { category = "container", reason = "Myth Dawncrest cluster — click to open" },
    [246756] = { category = "container", reason = "Hero Dawncrest pack — click to open" },
    [263976] = { category = "container", reason = "Adventurer Dawncrest bundle — click to open" },
    [263977] = { category = "container", reason = "Veteran Dawncrest satchel — click to open" },
    [268297] = { category = "container", reason = "Reward bag — click to open" },

    -- Midnight 12.1 Mistcrest conversions and Warbound rewards
    [269856] = { category = "container", reason = "Adventurer Mistcrest bundle — click to open" },
    [269859] = { category = "container", reason = "Veteran Mistcrest pouch — click to open" },
    [269857] = { category = "container", reason = "Champion Mistcrest satchel — click to open" },
    [269858] = { category = "container", reason = "Hero Mistcrest pack — click to open" },
    [269867] = { category = "container", reason = "Veteran Mistcrest satchel — click to open" },
    [269864] = { category = "container", reason = "Champion Mistcrest satchel — click to open" },
    [269865] = { category = "container", reason = "Hero Mistcrest pack — click to open" },
    [269866] = { category = "container", reason = "Myth Mistcrest cluster — click to open" },
    [280737] = { category = "container", reason = "Warbound Veteran Mistcrest pack — click to open" },
    [280734] = { category = "container", reason = "Warbound Champion Mistcrest pack — click to open" },
    [280732] = { category = "container", reason = "Warbound Hero Mistcrest pack — click to open" },

    -- Stack-based item conversions
    [268650] = {
        category = "container",
        minCount = 5,
        requireUsable = true,
        reason = "Five Ascendant Voidshards ready — click to combine",
    },
    [279576] = {
        category = "container",
        minCount = 4,
        requireUsable = true,
        reason = "Four Void Vestiges ready — click to combine",
    },
}

local function AddTreatise(itemID, completedQuestID)
    addon.Rules[itemID] = {
        category = "profession",
        completedQuestID = completedQuestID,
        requireUsable = true,
        reason = "Profession treatise ready — click to study",
    }
end

-- Treatises are weekly consumables. Their hidden quest completion flags are
-- more reliable than the item cooldown alone, especially after a weekly use.
-- Dragonflight: Draconic Treatises
AddTreatise(194697, 74108) -- Alchemy
AddTreatise(198454, 74109) -- Blacksmithing
AddTreatise(194702, 74110) -- Enchanting
AddTreatise(198510, 74111) -- Engineering
AddTreatise(194704, 74107) -- Herbalism
AddTreatise(194699, 74105) -- Inscription
AddTreatise(194703, 74112) -- Jewelcrafting
AddTreatise(194700, 74113) -- Leatherworking
AddTreatise(194708, 74106) -- Mining
AddTreatise(201023, 74114) -- Skinning
AddTreatise(194698, 74115) -- Tailoring

-- The War Within: Algari Treatises
AddTreatise(222546, 83725) -- Alchemy
AddTreatise(222554, 83726) -- Blacksmithing
AddTreatise(222550, 83727) -- Enchanting
AddTreatise(222621, 83728) -- Engineering
AddTreatise(222552, 83729) -- Herbalism
AddTreatise(222548, 83730) -- Inscription
AddTreatise(222551, 83731) -- Jewelcrafting
AddTreatise(222549, 83732) -- Leatherworking
AddTreatise(222553, 83733) -- Mining
AddTreatise(222649, 83734) -- Skinning
AddTreatise(222547, 83735) -- Tailoring

-- The War Within 11.1: Undermine Treatises
AddTreatise(232499, 85734) -- Alchemy
AddTreatise(232500, 85735) -- Blacksmithing
AddTreatise(232501, 85736) -- Enchanting
AddTreatise(232507, 85737) -- Engineering
AddTreatise(232503, 85738) -- Herbalism
AddTreatise(232508, 85739) -- Inscription
AddTreatise(232504, 85740) -- Jewelcrafting
AddTreatise(232505, 85741) -- Leatherworking
AddTreatise(232509, 85742) -- Mining
AddTreatise(232506, 85744) -- Skinning
AddTreatise(232502, 85745) -- Tailoring

-- Midnight: Thalassian Treatises
AddTreatise(245755, 95127) -- Alchemy
AddTreatise(245763, 95128) -- Blacksmithing
AddTreatise(245759, 95129) -- Enchanting
AddTreatise(245809, 95138) -- Engineering
AddTreatise(245761, 95130) -- Herbalism
AddTreatise(245757, 95131) -- Inscription
AddTreatise(245760, 95133) -- Jewelcrafting
AddTreatise(245758, 95134) -- Leatherworking
AddTreatise(245762, 95135) -- Mining
AddTreatise(245828, 95136) -- Skinning
AddTreatise(245756, 95137) -- Tailoring

addon.CategoryPriority = {
    mount = 10,
    pet = 11,
    curio = 12,
    toy = 13,
    decor = 14,
    transmog = 15,
    profession = 16,
    recipe = 17,
    container = 50,
}
