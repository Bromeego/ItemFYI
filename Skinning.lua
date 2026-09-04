local _, addon = ...
local Unpack = unpack or table.unpack

local function RegisterEllesmereUISkin(self)
    if not (EllesmereUI and type(EllesmereUI.RegisterSkin) == "function") then
        return false
    end

    EllesmereUI.RegisterSkin("ItemFYI", function(skin)
        if not (addon.button and skin and type(skin.Button) == "function") then
            return
        end

        skin.Button(addon.button, { "Icon" })
        addon.skinProvider = "EllesmereUI"
    end)
    return true
end

local function ApplyElvUISkin(self)
    if type(ElvUI) ~= "table" then
        return false
    end

    local engine = Unpack(ElvUI)
    if not (engine and type(engine.GetModule) == "function") then
        return false
    end

    local skins = engine:GetModule("Skins", true)
    if not (skins and type(skins.HandleItemButton) == "function") then
        return false
    end

    local applied = pcall(skins.HandleItemButton, skins, self.button, true)
    if applied then
        self.skinProvider = "ElvUI"
    end
    return applied
end

function addon:RegisterSkinning()
    if self.skinRegistered or not self.button then
        return
    end

    self.skinRegistered = true

    -- EllesmereUI has a public callback API and keeps registered skins in sync
    -- with live theme changes, so prefer it when both UI suites are installed.
    if RegisterEllesmereUISkin(self) then
        return
    end

    -- ElvUI does not expose the same callback contract, but its item-button
    -- handler is the established way its own item buttons receive the theme.
    ApplyElvUISkin(self)
end
