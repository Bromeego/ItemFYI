local _, addon = ...

local EDIT_MODE_MIGRATION_VERSION = 1

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function GetSafeFrameRect(frame)
    if not frame or not frame.GetRect then
        return
    end

    local x, y, width, height = frame:GetRect()
    if not (x and y and width and height) then
        return
    end
    if IsSecret(x) or IsSecret(y) or IsSecret(width) or IsSecret(height) then
        return
    end

    local screenX, screenY, screenWidth, screenHeight = UIParent:GetRect()
    if not (screenX and screenY and screenWidth and screenHeight) then
        return
    end
    if IsSecret(screenX) or IsSecret(screenY) or IsSecret(screenWidth) or IsSecret(screenHeight) then
        return
    end

    if x + width <= screenX or y + height <= screenY
        or x >= screenX + screenWidth or y >= screenY + screenHeight then
        return
    end

    return x, y
end

function addon:EditModeIsActive()
    return EditModeManagerFrame and EditModeManagerFrame.editModeActive or false
end

function addon:SaveEditModePosition()
    if not (self.editModeRegistered and self.editModeLib and self.button and self.button.system) then
        return
    end

    local framesDB = self.editModeLib.framesDB
    local db = framesDB and framesDB[self.button.system]
    if not db then
        return
    end

    local x, y = self.button:GetRect()
    if not (x and y) or IsSecret(x) or IsSecret(y) then
        return
    end

    db.x = x
    db.y = y
end

function addon:RefreshEditModeVisibility()
    if not self.button or self:IsInCombat() then
        return
    end
    self:SetCandidate(self.current, #self.candidates)
end

local function MigrateSavedPosition(self)
    if (self.db.editModeMigration or 0) >= EDIT_MODE_MIGRATION_VERSION then
        return
    end

    local x, y = GetSafeFrameRect(self.button)
    if not (x and y) then
        self.button:ClearAllPoints()
        self.button:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
        x, y = GetSafeFrameRect(self.button)
    end

    if x and y then
        local db = self.db.editMode
        db.profiles = nil
        db.x = x
        db.y = y
        db.enabled = true
        db.settings = db.settings or {}
    end
end

function addon:RegisterEditMode()
    if self.editModeRegistered or not (self.button and self.db and LibStub) then
        return
    end

    local lib = LibStub("EditModeExpanded-1.0", true)
    if not lib then
        return
    end

    MigrateSavedPosition(self)
    lib:RegisterFrame(self.button, "ItemFYI", self.db.editMode, UIParent, "BOTTOMLEFT")
    lib:SetDontResize(self.button)
    lib:RegisterCoordinates(self.button)

    self.editModeLib = lib
    self.editModeRegistered = true
    self.db.editModeMigration = EDIT_MODE_MIGRATION_VERSION

    if self.button.Selection then
        self.button.Selection:EnableMouse(true)
        self.button.Selection:RegisterForDrag("LeftButton")
        self.button.Selection:SetScript("OnDragStart", function()
            if addon:IsInCombat() then
                return
            end
            addon.button:SetMovable(true)
            addon.button:StartMoving()
        end)
        self.button.Selection:HookScript("OnDragStop", function()
            addon:SaveEditModePosition()
            addon:SavePosition(true)
        end)
        self.button.Selection:HookScript("OnKeyUp", function(_, key)
            if key == "LEFT" or key == "RIGHT" or key == "UP" or key == "DOWN" then
                addon:SaveEditModePosition()
                addon:SavePosition(true)
            end
        end)
    end

    if EditModeManagerFrame and EditModeManagerFrame.HookScript then
        EditModeManagerFrame:HookScript("OnShow", function()
            C_Timer.After(0, function()
                addon:RefreshEditModeVisibility()
            end)
        end)
        EditModeManagerFrame:HookScript("OnHide", function()
            C_Timer.After(0, function()
                addon:RefreshEditModeVisibility()
            end)
        end)
    end

    self:SavePosition(true)
end
