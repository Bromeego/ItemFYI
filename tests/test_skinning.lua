_G = _G or _ENV

local ellesmereCallback
EllesmereUI = {
    RegisterSkin = function(name, callback)
        assert(name == "ItemFYI", "unexpected EllesmereUI skin name")
        ellesmereCallback = callback
    end,
}

local addon = { button = { Icon = {} } }
assert(loadfile("Skinning.lua"))("ItemFYI", addon)
addon:RegisterSkinning()
assert(ellesmereCallback, "EllesmereUI skin callback was not registered")

local ellesmereButton
local preservedKey
ellesmereCallback({
    Button = function(button, keepKeys)
        ellesmereButton = button
        preservedKey = keepKeys and keepKeys[1]
    end,
})
assert(ellesmereButton == addon.button, "EllesmereUI did not receive the ItemFYI button")
assert(preservedKey == "Icon", "EllesmereUI skin must preserve the item icon")
assert(addon.skinProvider == "EllesmereUI", "EllesmereUI provider was not recorded")

EllesmereUI = nil
local elvUIButton
local skins = {
    HandleItemButton = function(_, button, setInside)
        elvUIButton = button
        assert(setInside == true, "ElvUI icon should be inset inside its border")
    end,
}
local engine = {
    GetModule = function(_, name)
        assert(name == "Skins", "unexpected ElvUI module")
        return skins
    end,
}
ElvUI = { engine }

local secondAddon = { button = { Icon = {} } }
assert(loadfile("Skinning.lua"))("ItemFYI", secondAddon)
secondAddon:RegisterSkinning()
assert(elvUIButton == secondAddon.button, "ElvUI did not receive the ItemFYI button")
assert(secondAddon.skinProvider == "ElvUI", "ElvUI provider was not recorded")

print("UI skinning tests passed")
