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
    [279382] = {
        category = "container",
        minCount = 2,
        reason = "Two Venom-Cursed Fragments ready — click to combine",
    },
}

addon.CategoryPriority = {
    mount = 10,
    pet = 11,
    toy = 12,
    decor = 13,
    transmog = 14,
    recipe = 15,
    container = 50,
}
