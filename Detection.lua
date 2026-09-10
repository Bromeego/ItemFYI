local _, addon = ...

local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo

local knownText = {
    "already known",
    "already collected",
    "you have collected this appearance",
    "you have collected all of the transmog looks",
}

local transmogText = {
    "use: collect the appearance",
    "use: collect the appearances",
    "use: adds this appearance",
    "use: add this appearance",
}

local function IsVisualEffectUnlock(text)
    return string.find(text, "use: learn to infuse ", 1, true) ~= nil
        and string.find(text, "unlocking additional visual effects", 1, true) ~= nil
end

local function IsTierTokenAction(text)
    -- Legacy: "Use: Create a class set item appropriate for your loot specialization"
    -- 12.1: "Use: Create a soulbound set leg item appropriate for your class."
    return string.find(text,
        "use:%s+create a [^\n]-%f[%a]set%f[%A] [^\n]-item appropriate for your") ~= nil
end

local decorText = {
    "use: add this decor",
    "use: adds this decor",
    "decor to your collection",
}

local recipeText = {
    "use: teaches you how to",
    "use: permanently teaches you",
}

local companionText = {
    "use: teaches you how to summon and dismiss this companion",
}

local curioText = {
    "use: add this curio to your companion's collection",
    "use: adds this curio to your companion's collection",
}

local function IsProfessionKnowledgeItem(text)
    return string.find(text,
        "use:%s+study to increase your [^\n]- knowledge by %d+") ~= nil
end

local function GetBulkFishProcessingMinimum(text)
    return tonumber(string.match(text, "use:%s+gut and clean%s+(%d+)%s+"))
end

local combineNumberWords = {
    two = 2,
    three = 3,
    four = 4,
    five = 5,
    six = 6,
    seven = 7,
    eight = 8,
    nine = 9,
    ten = 10,
    twelve = 12,
    fifteen = 15,
    twenty = 20,
    fifty = 50,
    hundred = 100,
}

local function GetStackCombineMinimum(text)
    local amount = string.match(text,
        "use:%s+combine%s+([%w]+)%s+[^\n]-to create")
    local minimum = tonumber(amount) or combineNumberWords[amount]
    if minimum and minimum >= 2 then
        return minimum
    end
end

local function IsSingleItemProfessionProcessingAction(text)
    -- Keep this deliberately narrower than a generic "Use:" detector. The
    -- "gut and clean N" family has a separate count-aware path below.
    -- "Disenchant this item to produce ..." is a bag-item processing action,
    -- not the Enchanting profession spell used on gear.
    local lines = "\n" .. text
    return string.find(lines, "\n%s*use:%s+gut%s+the%s+") ~= nil
        or string.find(lines, "\n%s*use:%s+salvage%s+") ~= nil
        or string.find(lines, "\n%s*use:%s+disenchant this item to produce") ~= nil
end

local function GetPermanentSkillIncrease(text)
    local skillName, maximum = string.match(text,
        "use:%s+increases?%s+([^\n]-)%s+skill%s+by%s+%d+.-up to a max of%s+(%d+)")
    return skillName, tonumber(maximum)
end

local function GetGarrisonActionReason(text, context)
    local itemSubType = string.lower(context and context.itemSubType or "")
    if itemSubType == "naval equipment"
        or string.find(text, "use:%s+equip a ship with") then
        return "Naval equipment — click to equip a ship"
    end
    if string.find(text, "use:%s+unlocks the ability to build")
        or string.find(text, "use:%s+unlocks the [^\n]- ship type") then
        return "Shipyard blueprint — click to learn"
    end
    if string.find(text, "use:%s+provides the plans needed to")
        or string.find(text, "use:%s+provides the plans to build")
        or string.find(text, "use:%s+teaches the blueprints needed") then
        return "Garrison blueprint — click to learn"
    end
    if string.find(text, "use:%s+increases? a [^\n]-follower")
        or string.find(text, "use:%s+increases? the item level of a [^\n]-follower")
        or string.find(text, "use:%s+instantly upgrade a follower")
        or string.find(text, "use:%s+create an uncommon, rare or epic follower") then
        return "Follower upgrade — click to apply"
    end
end

local function IsReputationGrantAction(text)
    return string.find(text, "use:%s+grants?%s+%d+%s+reputation with") ~= nil
        or string.find(text, "use:%s+awards?%s+%d+%s+reputation with") ~= nil
        or string.find(text, "use:%s+increases? your reputation with") ~= nil
end

local function HasReachedProfessionCap(skillName, maximum)
    if not (skillName and maximum and GetProfessions and GetProfessionInfo) then
        return false
    end

    local professionIndices = { GetProfessions() }
    for position = 1, 6 do
        local professionIndex = professionIndices[position]
        if professionIndex then
            local professionName, _, skillLevel = GetProfessionInfo(professionIndex)
            professionName = string.lower(professionName or "")
            if professionName ~= "" and string.find(skillName, professionName, 1, true)
                and (tonumber(skillLevel) or 0) >= maximum then
                return true
            end
        end
    end

    return false
end

local function IsOpenAction(text)
    -- Require a non-letter after "open" so "Use: Opens a portal" is excluded.
    return string.find(text, "use: open%f[%A]") ~= nil
end

local function ContainsAny(text, needles)
    for _, needle in ipairs(needles) do
        if string.find(text, needle, 1, true) then
            return true
        end
    end
    return false
end

local function IsLocked(text)
    return string.find(text, "requires lockpicking", 1, true) ~= nil
        or string.find(text, "%f[%a]locked%f[%A]") ~= nil
end

local function IsItemUsable(itemID)
    local usabilityCheck = C_Item and C_Item.IsUsableItem or _G.IsUsableItem
    if not usabilityCheck then
        return true
    end

    local ok, usable = pcall(usabilityCheck, itemID)
    if not ok then
        return true
    end

    -- Only an explicit false should hide an item. A nil result can be
    -- temporary while Blizzard finishes loading item data.
    return usable ~= false
end

local function IsRestrictionText(text)
    if type(text) ~= "string" then
        return false
    end

    text = string.lower(text)
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.match(text, "^%s*(.-)%s*$") or ""
    return string.find(text, "^requires[%s:]") ~= nil
        or string.find(text, "^classes[%s:]") ~= nil
end

local function GetColorRGB(color)
    if type(color) ~= "table" then
        return nil
    end

    if type(color.GetRGB) == "function" then
        local ok, red, green, blue = pcall(color.GetRGB, color)
        if ok then
            return tonumber(red), tonumber(green), tonumber(blue)
        end
    end

    return tonumber(color.r), tonumber(color.g), tonumber(color.b)
end

local function IsFailureColor(color)
    local red, green, blue = GetColorRGB(color)
    return red and green and blue
        and red >= 0.75
        and green <= 0.4
        and blue <= 0.4
        and red > green * 1.5
        and red > blue * 1.5
end

local function FontStringHasFailedRequirement(fontString)
    if not (fontString and fontString.GetText and fontString.GetTextColor) then
        return false
    end

    local text = fontString:GetText()
    if not IsRestrictionText(text) then
        return false
    end

    local red, green, blue = fontString:GetTextColor()
    return IsFailureColor({ r = red, g = green, b = blue })
end

local function AppendTooltipValue(parts, value)
    if type(value) == "string" and value ~= "" then
        parts[#parts + 1] = value
    elseif type(value) == "table" then
        for _, nested in pairs(value) do
            AppendTooltipValue(parts, nested)
        end
    end
end

local function CollectRestrictionState(text, color, state)
    if not IsRestrictionText(text) then
        return
    end
    state.sawRestrictionText = true
    if color ~= nil then
        state.sawRestrictionColor = true
        if IsFailureColor(color) then
            state.unmetRequirement = true
        end
    end
end

local function EnsureScanTooltip(self)
    if not (CreateFrame and UIParent) then
        return nil
    end
    if not self.scanTooltip then
        self.scanTooltip = CreateFrame("GameTooltip", "ItemFYIScanTooltip", UIParent, "GameTooltipTemplate")
    end
    -- Hide() and some Set methods clear the owner; restore it before each scan.
    self.scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    return self.scanTooltip
end

local PET_CAGE_ITEM_ID = 82800

local function SpeciesFromBattlePetLink(value)
    if type(value) ~= "string" then
        return nil
    end
    return tonumber(value:match("battlepet:(%d+)"))
end

local function SpeciesFromTooltipArgs(args)
    if type(args) ~= "table" then
        return nil
    end
    for _, arg in pairs(args) do
        if type(arg) == "table" and arg.field == "battlePetSpeciesID" then
            return tonumber(arg.intVal or arg.floatVal or arg.stringVal)
        end
    end
end

local function SurfaceTooltipData(tooltip)
    -- SurfaceArgs flattened TooltipData.args onto named fields. It became a
    -- no-op in Dragonflight and was removed in 11.0.2; call it only if present.
    if not (tooltip and TooltipUtil and type(TooltipUtil.SurfaceArgs) == "function") then
        return
    end
    pcall(TooltipUtil.SurfaceArgs, tooltip)
    if tooltip.lines then
        for _, line in ipairs(tooltip.lines) do
            pcall(TooltipUtil.SurfaceArgs, line)
        end
    end
end

local function IsBattlePetTooltipType(tooltipType)
    local types = Enum and Enum.TooltipDataType
    return types ~= nil and (tooltipType == types.BattlePet or tooltipType == types.CompanionPet)
end

local function IsCompanionPetItem(context)
    if tonumber(context.itemID) == PET_CAGE_ITEM_ID then
        return true
    end

    local itemClass = Enum and Enum.ItemClass
    local companionSubclass = Enum and Enum.ItemMiscellaneousSubclass
        and Enum.ItemMiscellaneousSubclass.CompanionPet
    if itemClass then
        if itemClass.Battlepet and context.classID == itemClass.Battlepet then
            return true
        end
        if itemClass.Miscellaneous and companionSubclass
            and context.classID == itemClass.Miscellaneous
            and context.subclassID == companionSubclass then
            return true
        end
    end

    local subType = string.lower(context.itemSubType or "")
    return subType == "companion pets" or subType == "companion pet"
end

local function GetBattlePetSpeciesIDFromTooltip(tooltip)
    if type(tooltip) ~= "table" then
        return nil
    end

    local speciesID = tonumber(tooltip.battlePetSpeciesID)
    if not speciesID and type(tooltip.battlePet) == "table" then
        speciesID = tonumber(tooltip.battlePet.speciesID)
    end
    return speciesID
        or SpeciesFromBattlePetLink(tooltip.hyperlink)
        or SpeciesFromBattlePetLink(tooltip.battlePetLink)
        or SpeciesFromTooltipArgs(tooltip.args)
end

local function GetBattlePetSpeciesID(context, tooltip)
    local speciesID = GetBattlePetSpeciesIDFromTooltip(tooltip)
        or SpeciesFromBattlePetLink(context and context.link)
    if speciesID then
        return speciesID
    end

    if C_PetJournal and C_PetJournal.GetPetInfoByItemID and context and context.itemID then
        -- This legacy API returns the pet name first and speciesID thirteenth.
        -- Extra parentheses keep Lua 5.1 from calling tonumber with no argument.
        -- GetPetInfoByItemID errors if given an item link instead of an ID.
        local ok, resolved = pcall(function()
            return tonumber((select(13, C_PetJournal.GetPetInfoByItemID(context.itemID))))
        end)
        if ok then
            return resolved
        end
    end
end

local bagScanReasons = {
    BAG_UPDATE = true,
    BAG_UPDATE_DELAYED = true,
    GET_ITEM_INFO_RECEIVED = true,
    ITEM_DATA_LOAD_RESULT = true,
}

local function SlotCacheKey(bag, slot)
    return tostring(bag) .. ":" .. tostring(slot)
end

function addon:InvalidateScanCache()
    self.scanCache = {}
end

function addon:GetSlotTooltipCache(context)
    local cache = self.scanCache
    if not cache or not context then
        return
    end
    local entry = cache[SlotCacheKey(context.bag, context.slot)]
    if not entry then
        return
    end
    if entry.itemID == context.itemID and entry.link == context.link
        and entry.stackCount == context.stackCount then
        return entry.snapshot
    end
end

function addon:SetSlotTooltipCache(context, snapshot)
    if not context or not snapshot then
        return
    end
    self.scanCache = self.scanCache or {}
    self.scanCache[SlotCacheKey(context.bag, context.slot)] = {
        itemID = context.itemID,
        link = context.link,
        stackCount = context.stackCount,
        snapshot = snapshot,
    }
end

function addon:GetTooltipSnapshot(context)
    if context.tooltipSnapshot then
        return context.tooltipSnapshot
    end

    local cached = self.useScanCache and self:GetSlotTooltipCache(context)
    if cached then
        context.tooltipSnapshot = cached
        return cached
    end

    local parts = {}
    local state = {
        unmetRequirement = false,
        sawRestrictionText = false,
        sawRestrictionColor = false,
    }
    local battlePetSpeciesID
    local skipCompanionScan = IsCompanionPetItem(context)

    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local ok, tooltip = pcall(C_TooltipInfo.GetBagItem, context.bag, context.slot)
        if ok and tooltip then
            SurfaceTooltipData(tooltip)
            skipCompanionScan = skipCompanionScan or IsBattlePetTooltipType(tooltip.type)
            battlePetSpeciesID = GetBattlePetSpeciesIDFromTooltip(tooltip)
                or SpeciesFromBattlePetLink(context.link)
            if tooltip.lines then
                for _, line in ipairs(tooltip.lines) do
                    AppendTooltipValue(parts, line.leftText)
                    AppendTooltipValue(parts, line.rightText)
                    AppendTooltipValue(parts, line.text)
                    AppendTooltipValue(parts, line.args)
                    CollectRestrictionState(line.leftText, line.leftColor, state)
                    CollectRestrictionState(line.rightText, line.rightColor, state)
                    CollectRestrictionState(line.text, line.color or line.leftColor, state)
                end
            end
        end
    end

    local needScanForText = #parts == 0
    local needScanForColor = state.sawRestrictionText and not state.sawRestrictionColor
        and not state.unmetRequirement
    -- SetBagItem on a battle pet calls BattlePetToolTip_Show, which copies
    -- GameTooltip:GetPoint(1). That point does not exist after a reload until
    -- the player has hovered something, and BugSack reports the SetPoint error.
    if needScanForText or needScanForColor then
        battlePetSpeciesID = battlePetSpeciesID or GetBattlePetSpeciesID(context)
    end
    if (needScanForText or needScanForColor) and not battlePetSpeciesID and not skipCompanionScan then
        local scanTooltip = EnsureScanTooltip(self)
        if scanTooltip then
            local companionShown = BattlePetTooltip and BattlePetTooltip.IsShown
                and BattlePetTooltip:IsShown()
            scanTooltip:ClearLines()
            pcall(scanTooltip.SetBagItem, scanTooltip, context.bag, context.slot)
            if not companionShown and self.HideCompanionTooltips then
                self:HideCompanionTooltips()
            end
            local tooltipName = scanTooltip:GetName()
            for lineNumber = 1, scanTooltip:NumLines() do
                local left = _G[tooltipName .. "TextLeft" .. lineNumber]
                local right = _G[tooltipName .. "TextRight" .. lineNumber]
                if needScanForText then
                    AppendTooltipValue(parts, left and left:GetText())
                    AppendTooltipValue(parts, right and right:GetText())
                end
                if FontStringHasFailedRequirement(left) or FontStringHasFailedRequirement(right) then
                    state.unmetRequirement = true
                end
            end
        end
    end

    context.tooltipSnapshot = {
        text = string.lower(table.concat(parts, "\n")),
        unmetRequirement = state.unmetRequirement,
        battlePetSpeciesID = battlePetSpeciesID,
    }
    if self.useScanCache then
        self:SetSlotTooltipCache(context, context.tooltipSnapshot)
    end
    return context.tooltipSnapshot
end

function addon:GetTooltipText(context)
    return self:GetTooltipSnapshot(context).text
end

function addon:HasUnmetRequirement(context)
    return self:GetTooltipSnapshot(context).unmetRequirement
end

local function GetPetSpecies(context)
    local snapshot = addon:GetTooltipSnapshot(context)
    return snapshot.battlePetSpeciesID or GetBattlePetSpeciesID(context)
end

local function IsUncollectedPet(context)
    if not (C_PetJournal and C_PetJournal.GetNumCollectedInfo) then
        return false
    end
    local speciesID = GetPetSpecies(context)
    if not speciesID then
        return false
    end
    local ok, owned, limit = pcall(C_PetJournal.GetNumCollectedInfo, speciesID)
    if not ok then
        return false
    end
    owned = tonumber(owned) or 0
    limit = tonumber(limit) or 3
    return owned < limit, speciesID
end

local function IsUncollectedMount(itemID)
    if not (C_MountJournal and C_MountJournal.GetMountFromItem and C_MountJournal.GetMountInfoByID) then
        return false
    end
    local mountID = C_MountJournal.GetMountFromItem(itemID)
    if not mountID then
        return false
    end
    local info = { C_MountJournal.GetMountInfoByID(mountID) }
    return info[11] ~= true, mountID
end

local function IsUncollectedToy(itemID)
    if not (C_ToyBox and C_ToyBox.GetToyInfo) then
        return false
    end
    local toyName = C_ToyBox.GetToyInfo(itemID)
    if not toyName then
        return false
    end
    local known
    if PlayerHasToy then
        known = PlayerHasToy(itemID)
    elseif C_ToyBox.IsToyKnown then
        known = C_ToyBox.IsToyKnown(itemID)
    end
    return known == false
end

local function QueryCollectedAppearance(query)
    if not query or not C_TransmogCollection then
        return false
    end

    if C_TransmogCollection.PlayerHasTransmogByItemInfo then
        local ok, collected = pcall(C_TransmogCollection.PlayerHasTransmogByItemInfo, query)
        if ok and collected == true then
            return true
        end
    end

    if type(query) == "number" and C_TransmogCollection.PlayerHasTransmog then
        local ok, collected = pcall(C_TransmogCollection.PlayerHasTransmog, query)
        if ok and collected == true then
            return true
        end
    end

    if C_TransmogCollection.GetItemInfo and C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance then
        local ok, _, sourceID = pcall(C_TransmogCollection.GetItemInfo, query)
        if ok and sourceID then
            local hasOk, hasAppearance = pcall(C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance, sourceID)
            if hasOk and hasAppearance == true then
                return true
            end
        end
    end

    return false
end

local function IsCollectedAppearance(itemID, itemLink)
    return QueryCollectedAppearance(itemID) or QueryCollectedAppearance(itemLink)
end

function addon:ClassifyItem(context)
    local tooltipText = self:GetTooltipText(context)
    local alreadyKnown = ContainsAny(tooltipText, knownText)
    if alreadyKnown or IsLocked(tooltipText) then
        return nil
    end

    local availableCount = tonumber(context.totalCount) or tonumber(context.stackCount) or 0
    local explicit = self.Rules[context.itemID]
    if explicit then
        if explicit.minCount and availableCount < explicit.minCount then
            return nil
        end
        if explicit.completedQuestID and C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
            and C_QuestLog.IsQuestFlaggedCompleted(explicit.completedQuestID) then
            return nil
        end
        if explicit.requireUsable
            and (not IsItemUsable(context.itemID) or self:HasUnmetRequirement(context)) then
            return nil
        end
        return explicit.category, explicit.reason
    end

    local isMount = IsUncollectedMount(context.itemID)
    if isMount then
        return "mount", "Uncollected mount — click to learn"
    end

    if IsUncollectedToy(context.itemID) then
        return "toy", "Uncollected toy — click to learn"
    end

    local isPet, speciesID = IsUncollectedPet(context)
    if isPet then
        context.uniqueKey = "pet:" .. speciesID
        return "pet", "Collectible battle pet — click to learn"
    end

    -- Some cosmetic companions do not expose battle-pet metadata consistently.
    -- Their standard use text is still an explicit learn action.
    if not speciesID and ContainsAny(tooltipText, companionText) then
        return "pet", "Uncollected companion — click to learn"
    end

    if ContainsAny(tooltipText, curioText) then
        return "curio", "Companion Curio — click to add"
    end

    if IsProfessionKnowledgeItem(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "profession", "Profession knowledge — click to study"
    end

    local fishMinimum = GetBulkFishProcessingMinimum(tooltipText)
    if fishMinimum and availableCount >= fishMinimum and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "profession", "Fish ready to gut and clean — click to process"
    end

    if IsSingleItemProfessionProcessingAction(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "profession", "Profession material ready — click to process"
    end

    local skillName, maximumSkill = GetPermanentSkillIncrease(tooltipText)
    if skillName and IsItemUsable(context.itemID) and not self:HasUnmetRequirement(context)
        and not HasReachedProfessionCap(skillName, maximumSkill) then
        return "profession", "Permanent profession skill increase — click to use"
    end

    local garrisonReason = GetGarrisonActionReason(tooltipText, context)
    if garrisonReason and IsItemUsable(context.itemID) and not self:HasUnmetRequirement(context) then
        return "progress", garrisonReason
    end

    if IsReputationGrantAction(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "progress", "Reputation token — click to use"
    end

    local itemType = string.lower(context.itemType or "")
    local itemSubType = string.lower(context.itemSubType or "")

    local isDecorType = itemType == "housing"
        or itemType == "decor"
        or itemSubType == "housing decor"
        or itemSubType == "decoration"
    local hasDecorUse = ContainsAny(tooltipText, decorText)
    if hasDecorUse and (isDecorType or string.find(tooltipText, "decor", 1, true))
        and IsItemUsable(context.itemID) and not self:HasUnmetRequirement(context) then
        return "decor", "Housing decor — click to add"
    end

    if IsTierTokenAction(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "transmog", "Tier token — click to create set item"
    end

    if IsVisualEffectUnlock(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "transmog", "Visual effect unlock — click to learn"
    end

    if ContainsAny(tooltipText, transmogText) then
        -- Warband tokens must still appear on the wrong armour class, so this
        -- path uses collection APIs instead of generic usability checks.
        if IsCollectedAppearance(context.itemID, context.link) then
            return nil
        end
        return "transmog", "Uncollected appearance — click to learn"
    end

    local recipeClassID = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or 9
    local isRecipe = context.classID == recipeClassID or itemType == "recipe"
    if isRecipe and IsItemUsable(context.itemID) and not self:HasUnmetRequirement(context)
        and ContainsAny(tooltipText, recipeText) then
        return "recipe", "Unlearned recipe — click to learn"
    end

    local combineMinimum = GetStackCombineMinimum(tooltipText)
    if combineMinimum and availableCount >= combineMinimum and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "container", ("Stack of %d ready — click to combine"):format(combineMinimum)
    end

    if context.hasLoot or IsOpenAction(tooltipText) then
        return "container", "Openable container — click to open"
    end
end

function addon:NotePendingItemLoad(itemID)
    if itemID == nil then
        return
    end
    self.pendingItemLoads = self.pendingItemLoads or {}
    self.pendingItemLoads[itemID] = true
end

function addon:ShouldRescanForLoadedItem(itemID, success)
    if success == false or itemID == nil then
        return false
    end
    if not self.pendingItemLoads or not self.pendingItemLoads[itemID] then
        return false
    end
    self.pendingItemLoads[itemID] = nil
    return true
end

function addon:BuildContext(bag, slot, info)
    local itemID = info.itemID or C_Container.GetContainerItemID(bag, slot)
    if not itemID then
        return nil
    end

    local itemName, itemLink, _, _, _, itemType, itemSubType, _, equipLocation, itemTexture,
        _, classID, subclassID = GetItemInfo(itemID)
    if not itemName then
        if C_Item and C_Item.RequestLoadItemDataByID then
            self:NotePendingItemLoad(itemID)
            C_Item.RequestLoadItemDataByID(itemID)
        end
        return nil
    end

    return {
        bag = bag,
        slot = slot,
        itemID = itemID,
        name = itemName,
        link = info.hyperlink or C_Container.GetContainerItemLink(bag, slot) or itemLink,
        icon = info.iconFileID or itemTexture,
        stackCount = info.stackCount or 1,
        hasLoot = info.hasLoot == true,
        isLocked = info.isLocked == true,
        itemType = itemType,
        itemSubType = itemSubType,
        equipLocation = equipLocation,
        classID = classID,
        subclassID = subclassID,
    }
end

function addon:BuildSecureUse(context, category)
    if category == "transmog" and context.equipLocation and context.equipLocation ~= "" then
        -- Item-ID macros prefer equipping equippable gear. Target the current
        -- bag slot so WoW follows the same use path as right-clicking the item.
        -- Appearance collection is not useful in combat, and blocking it there
        -- removes the only period where this slot cannot be refreshed safely.
        return ("/stopmacro [combat]\n/use %d %d"):format(context.bag, context.slot), true
    end

    -- IDs remain safest for containers and other non-equippable actions because
    -- vendor purchases and bag sorting can move their original slots.
    return ("/use item:%d"):format(context.itemID), false
end

function addon:ScanBags(reason)
    if not self.db or not self.db.enabled then
        self.candidates = {}
        self:SetCandidate(nil, 0)
        return
    end
    if self:IsInCombat() then
        self.scanPending = true
        return
    end

    if not bagScanReasons[reason] then
        self:InvalidateScanCache()
    end

    local candidates = {}
    local contexts = {}
    local totalCounts = {}
    local seen = {}
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5

    for bag = 0, lastBag do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and not info.isLocked then
                local context = self:BuildContext(bag, slot, info)
                if context then
                    contexts[#contexts + 1] = context
                    totalCounts[context.itemID] = (totalCounts[context.itemID] or 0)
                        + (tonumber(context.stackCount) or 0)
                end
            end
        end
    end

    if bagScanReasons[reason] and self.scanCache then
        local live = {}
        for _, context in ipairs(contexts) do
            live[SlotCacheKey(context.bag, context.slot)] = true
        end
        for key in pairs(self.scanCache) do
            if not live[key] then
                self.scanCache[key] = nil
            end
        end
    end

    self.useScanCache = true
    for _, context in ipairs(contexts) do
        context.totalCount = totalCounts[context.itemID]
        local category, itemReason = self:ClassifyItem(context)
        local key = context.uniqueKey or tostring(context.itemID)
        if category and self:IsCategoryEnabled(category) and not seen[key]
            and not self.db.ignored[key] and not self.sessionSkipped[key] then
            local secureMacro, secureBySlot = self:BuildSecureUse(context, category)
            if not (secureBySlot and self:IsSlotActionBlocked()) then
                seen[key] = true
                candidates[#candidates + 1] = {
                    key = key,
                    itemID = context.itemID,
                    name = context.name,
                    link = context.link,
                    icon = context.icon,
                    count = context.totalCount,
                    bag = context.bag,
                    slot = context.slot,
                    category = category,
                    reason = itemReason,
                    priority = self.CategoryPriority[category] or 100,
                    secureMacro = secureMacro,
                    secureBySlot = secureBySlot,
                }
            end
        end
    end
    self.useScanCache = nil

    table.sort(candidates, function(left, right)
        if left.priority ~= right.priority then
            return left.priority < right.priority
        end
        if left.itemID ~= right.itemID then
            return left.itemID < right.itemID
        end
        return left.slot < right.slot
    end)

    self.candidates = candidates
    self:SetCandidate(candidates[1], #candidates)
end
