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

local openText = {
    "use: open",
}

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

local function AppendTooltipValue(parts, value)
    if type(value) == "string" and value ~= "" then
        parts[#parts + 1] = value
    elseif type(value) == "table" then
        for _, nested in pairs(value) do
            AppendTooltipValue(parts, nested)
        end
    end
end

function addon:GetTooltipText(context)
    local parts = {}

    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local ok, tooltip = pcall(C_TooltipInfo.GetBagItem, context.bag, context.slot)
        if ok and tooltip and tooltip.lines then
            for _, line in ipairs(tooltip.lines) do
                AppendTooltipValue(parts, line.leftText)
                AppendTooltipValue(parts, line.rightText)
                AppendTooltipValue(parts, line.text)
                AppendTooltipValue(parts, line.args)
            end
        end
    end

    if #parts == 0 and CreateFrame and UIParent then
        if not self.scanTooltip then
            self.scanTooltip = CreateFrame("GameTooltip", "ItemFYIScanTooltip", UIParent, "GameTooltipTemplate")
            self.scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        end
        self.scanTooltip:ClearLines()
        self.scanTooltip:SetBagItem(context.bag, context.slot)
        local tooltipName = self.scanTooltip:GetName()
        for lineNumber = 1, self.scanTooltip:NumLines() do
            local left = _G[tooltipName .. "TextLeft" .. lineNumber]
            local right = _G[tooltipName .. "TextRight" .. lineNumber]
            AppendTooltipValue(parts, left and left:GetText())
            AppendTooltipValue(parts, right and right:GetText())
        end
    end

    return string.lower(table.concat(parts, "\n"))
end

local function GetPetSpecies(context)
    local link = context.link or ""
    local speciesID = tonumber(link:match("battlepet:(%d+)"))
    if speciesID then
        return speciesID
    end

    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local ok, tooltip = pcall(C_TooltipInfo.GetBagItem, context.bag, context.slot)
        if ok and tooltip and tooltip.battlePet then
            return tonumber(tooltip.battlePet.speciesID)
        end
    end

    if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
        -- This legacy API returns the pet name first and speciesID thirteenth.
        local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(context.itemID))
        return tonumber(speciesID)
    end
end

local function IsUncollectedPet(context)
    if not (C_PetJournal and C_PetJournal.GetNumCollectedInfo) then
        return false
    end
    local speciesID = GetPetSpecies(context)
    if not speciesID then
        return false
    end
    local owned, limit = C_PetJournal.GetNumCollectedInfo(speciesID)
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

function addon:ClassifyItem(context)
    local tooltipText = self:GetTooltipText(context)
    local alreadyKnown = ContainsAny(tooltipText, knownText)
    if alreadyKnown or IsLocked(tooltipText) then
        return nil
    end

    local explicit = self.Rules[context.itemID]
    if explicit then
        local availableCount = tonumber(context.totalCount) or tonumber(context.stackCount) or 0
        if explicit.minCount and availableCount < explicit.minCount then
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

    local itemType = string.lower(context.itemType or "")
    local itemSubType = string.lower(context.itemSubType or "")

    local isDecorType = itemType == "housing"
        or itemType == "decor"
        or itemSubType == "housing decor"
        or itemSubType == "decoration"
    local hasDecorUse = ContainsAny(tooltipText, decorText)
    if hasDecorUse and (isDecorType or string.find(tooltipText, "decor", 1, true)) then
        return "decor", "Housing decor — click to add"
    end

    if ContainsAny(tooltipText, transmogText) then
        return "transmog", "Uncollected appearance — click to learn"
    end

    local recipeClassID = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or 9
    local isRecipe = context.classID == recipeClassID or itemType == "recipe"
    if isRecipe and IsItemUsable(context.itemID) and ContainsAny(tooltipText, recipeText) then
        return "recipe", "Unlearned recipe — click to learn"
    end

    if context.hasLoot or ContainsAny(tooltipText, openText) then
        return "container", "Openable container — click to open"
    end
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

    for _, context in ipairs(contexts) do
        context.totalCount = totalCounts[context.itemID]
        local category, itemReason = self:ClassifyItem(context)
        local key = context.uniqueKey or tostring(context.itemID)
        if category and self:IsCategoryEnabled(category) and not seen[key]
            and not self.db.ignored[key] and not self.sessionSkipped[key] then
            local secureMacro, secureBySlot = self:BuildSecureUse(context, category)
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
