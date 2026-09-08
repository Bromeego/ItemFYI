local addon = {}
local chunk = assert(loadfile("Rules.lua"))
chunk("ItemFYI", addon)

assert(addon.Rules[280732], "Warbound Pack of Hero Mistcrests is missing")
assert(addon.Rules[280732].category == "container", "Mistcrest rule has the wrong category")
assert(addon.Rules[246752], "Hero Dawncrest pack is missing")
assert(addon.Rules[279382] == nil and addon.Rules[231757] == nil,
    "standard stack conversions should use generic tooltip detection")
assert(addon.Rules[268650] and addon.Rules[268650].minCount == 5
    and addon.Rules[268650].requireUsable == true,
    "Ascendant Voidshard must require a usable stack of five")
assert(addon.Rules[279576] and addon.Rules[279576].minCount == 4
    and addon.Rules[279576].requireUsable == true,
    "Void Vestige must require a usable stack of four")
assert(addon.CategoryPriority.curio < addon.CategoryPriority.container,
    "curios must precede ordinary containers")
assert(addon.CategoryPriority.profession < addon.CategoryPriority.container,
    "profession progress items must precede ordinary containers")
assert(addon.CategoryPriority.progress < addon.CategoryPriority.container,
    "garrison and reputation items must precede ordinary containers")
assert(addon.Rules[245755] and addon.Rules[245755].completedQuestID == 95127,
    "Thalassian Alchemy treatise must use its weekly completion quest")
assert(addon.Rules[238378] == nil and addon.Rules[199346] == nil,
    "standard gut and salvage actions should use generic tooltip detection")
assert(addon.Rules[222548] and addon.Rules[222548].completedQuestID == 83730,
    "Algari Inscription treatise must use its weekly completion quest")
assert(addon.Rules[194703] and addon.Rules[194703].completedQuestID == 74112,
    "Draconic Jewelcrafting treatise must use its weekly completion quest")
assert(addon.CategoryPriority.mount < addon.CategoryPriority.container, "collectibles must precede containers")

local count = 0
for itemID, rule in pairs(addon.Rules) do
    assert(type(itemID) == "number" and itemID > 0, "invalid rule item ID")
    assert(type(rule.category) == "string", "rule category is required")
    assert(type(rule.reason) == "string" and rule.reason ~= "", "rule reason is required")
    assert(rule.minCount == nil or (type(rule.minCount) == "number" and rule.minCount >= 1),
        "rule minimum count must be a positive number")
    assert(rule.completedQuestID == nil
        or (type(rule.completedQuestID) == "number" and rule.completedQuestID >= 1),
        "rule completion quest must be a positive number")
    assert(rule.requireUsable == nil or type(rule.requireUsable) == "boolean",
        "rule usability flag must be boolean")
    count = count + 1
end

assert(count == 64, ("expected 64 explicit rules, found %d"):format(count))
print(("rule tests passed (%d rules)"):format(count))
