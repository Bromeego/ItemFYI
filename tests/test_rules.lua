local addon = {}
local chunk = assert(loadfile("Rules.lua"))
chunk("ItemFYI", addon)

assert(addon.Rules[280732], "Warbound Pack of Hero Mistcrests is missing")
assert(addon.Rules[280732].category == "container", "Mistcrest rule has the wrong category")
assert(addon.Rules[246752], "Hero Dawncrest pack is missing")
assert(addon.Rules[279382] and addon.Rules[279382].minCount == 2,
    "Venom-Cursed Fragment must require a stack of two")
assert(addon.CategoryPriority.mount < addon.CategoryPriority.container, "collectibles must precede containers")

local count = 0
for itemID, rule in pairs(addon.Rules) do
    assert(type(itemID) == "number" and itemID > 0, "invalid rule item ID")
    assert(type(rule.category) == "string", "rule category is required")
    assert(type(rule.reason) == "string" and rule.reason ~= "", "rule reason is required")
    assert(rule.minCount == nil or (type(rule.minCount) == "number" and rule.minCount >= 1),
        "rule minimum count must be a positive number")
    count = count + 1
end

assert(count == 19, ("expected 19 explicit rules, found %d"):format(count))
print(("rule tests passed (%d rules)"):format(count))
