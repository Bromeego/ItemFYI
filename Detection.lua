local _, addon = ...

local GetItemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo

-- Blizzard's localized GlobalStrings cover the generic tooltip states on any
-- client. Action-specific "Use: ..." wording below is still English-only.
local function LocalizedText(name)
    local value = _G[name]
    if type(value) == "string" and value ~= "" then
        return string.lower(value)
    end
end

-- Turn a format string such as "Requires Level %d" into a whole-line pattern,
-- so translations that put the placeholder first still match exactly.
local function LocalizedLinePattern(name)
    local format = LocalizedText(name)
    if not format then
        return nil
    end
    local marked = string.gsub(format, "%%[%d%$%.]*[sdf]", "\1")
    if marked == format or #string.gsub(marked, "[\1%s%p]", "") < 3 then
        return nil
    end
    local escaped = string.gsub(marked, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    return "^" .. string.gsub(escaped, "\1", ".+") .. "$"
end

local localizedUsePrefix = LocalizedText("ITEM_SPELL_TRIGGER_ONUSE")
local localizedKnown = LocalizedText("ITEM_SPELL_KNOWN")
local localizedOpenable = LocalizedText("ITEM_OPENABLE")
local localizedLocked = LocalizedText("LOCKED")
local localizedStartsQuest = LocalizedText("ITEM_STARTS_QUEST")

local localizedRestrictionPatterns = {}
for _, name in ipairs({
    "ITEM_MIN_LEVEL", "ITEM_REQ_SKILL", "ITEM_MIN_SKILL", "ITEM_REQ_REPUTATION",
    "ITEM_CLASSES_ALLOWED", "ITEM_RACES_ALLOWED",
}) do
    local pattern = LocalizedLinePattern(name)
    if pattern then
        localizedRestrictionPatterns[#localizedRestrictionPatterns + 1] = pattern
    end
end

local function HasUseText(text)
    return string.find(text, "use:", 1, true) ~= nil
        or (localizedUsePrefix ~= nil and string.find(text, localizedUsePrefix, 1, true) ~= nil)
end

local function HasExactLine(text, line)
    if not line then
        return false
    end
    for candidate in string.gmatch(text, "[^\n]+") do
        if string.match(candidate, "^%s*(.-)%s*$") == line then
            return true
        end
    end
    return false
end

-- Some legacy quest turn-in materials have a complete Blizzard tooltip
-- consisting only of their name. They have no bag use/learn action and need
-- no delayed retries. Keep these exceptions exact: learnable Curios can also
-- initially return a name-only tooltip before their Use: line arrives.
local inertNameOnlyItemIDs = {
    [18945] = true, -- Dark Iron Residue (Thorium Brotherhood turn-in)
    [20858] = true, -- Stone Scarab
    [20859] = true, -- Gold Scarab
    [20860] = true, -- Silver Scarab
    [20861] = true, -- Bronze Scarab
    [20862] = true, -- Crystal Scarab
    [20863] = true, -- Clay Scarab
    [20864] = true, -- Bone Scarab
    [20865] = true, -- Ivory Scarab
}

local knownText = {
    "already known",
    "already collected",
    "you have collected this appearance",
    "you have collected all of the transmog looks",
}
if localizedKnown and localizedKnown ~= "already known" then
    knownText[#knownText + 1] = localizedKnown
end

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

local customizationItemTypes = {
    ["drakewatcher manuscript"] = true,
    ["airship schematic"] = true,
}

local function HasTooltipTypeLine(text, typeName)
    return string.find("\n" .. text .. "\n", "\n" .. typeName .. "\n", 1, true) ~= nil
end

local function IsCustomizationItem(context, text)
    local itemType = string.lower(context and context.itemType or "")
    local itemSubType = string.lower(context and context.itemSubType or "")
    if customizationItemTypes[itemType] or customizationItemTypes[itemSubType] then
        return true
    end
    return HasTooltipTypeLine(text, "drakewatcher manuscript")
        or HasTooltipTypeLine(text, "airship schematic")
end

local function IsCustomizationUnlock(text)
    -- Drakewatcher Manuscripts, Airship Schematics, Gob-Trotter parts, and
    -- other Rostrum of Transformation unlocks. Match the family, not one drake.
    return string.find(text, "use:%s+unlocks [^\n]-customization") ~= nil
        or string.find(text, "use:[^\n]*rostrum of transformation") ~= nil
end

local function IsDelveBotUpgrade(text)
    -- Miscellaneous Airship Schematic whose left-side type line is
    -- "Airship Schematic", but whose action is a toy update rather than a
    -- Rostrum unlock. The Midnight software chip has this Use line and no
    -- spell, so IsUsableItem stays false while clicking still consumes it.
    return string.find(text, "use:%s+update your delve%-o%-bot") ~= nil
end

local function IsPepeCostumeUnlock(text)
    return string.find(text, "use:%s+when summoned, pepe will sometimes be dressed") ~= nil
end

local function IsWeaponIllusionUnlock(text)
    -- Illusion: Mongoose and the rest of the weapon-enchantment collection.
    return string.find(text, "use: collect the weapon enchantment appearance", 1, true) ~= nil
end

local function IsTierTokenAction(text)
    -- Legacy: "Use: Create a class set item appropriate for your loot specialization"
    -- 12.1: "Use: Create a soulbound set leg item appropriate for your class."
    -- Warlords: "Use: Create a soulbound Tier 17 item appropriate for your class."
    return string.find(text,
        "use:%s+create a [^\n]-%f[%a]set%f[%A] [^\n]-item appropriate for your") ~= nil
        or string.find(text,
            "use:%s+create a [^\n]-%f[%a]tier%s+%d+%s+[^\n]-item appropriate for your") ~= nil
end

local function IsLootSpecGearToken(text)
    -- Baleful Armament, Timeless tokens, Munificent Trinket, and other
    -- catch-up tokens. The client may append the current spec:
    -- "Use: Create a soulbound item appropriate for your loot specialization (Fury)."
    return string.find(text,
        "use:%s+create a soulbound item appropriate for your loot specialization") ~= nil
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
        or string.match(text, "use:%s+combine%s+([%w]+)%s+[^\n]-to obtain")
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
    -- Draenor caches, turn-in rewards, and similar consumables commonly use
    -- "Use: Gain 25 Garrison Resources." Detect the action, not individual IDs.
    -- Keep the match on a Use: line; flavour text alone is not actionable.
    if string.find(text, "use:%s+gain%s+%d[%d,%.]*%s+garrison resources%f[%A]") then
        return "Garrison Resources — click to collect"
    end
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

local function GetLabyrinthActionReason(text)
    -- Permanent Loa powers have a real collection Use: action and a Labyrinth
    -- description. Match their tooltip wording, not a growing list of IDs.
    if string.find(text, "use:%s+permanently gain%s+[^\n]-labyrinth") then
        return "Labyrinth power — click to unlock"
    end
end

local function IsReputationGrantAction(text)
    -- The client inserts a thousands separator, so "1000" appears as "1,000"
    -- or "2.500". The amount stays on the Use: line.
    local amount = "%d[%d,%.]*"
    return string.find(text, "use:%s+grants?%s+" .. amount .. "%s+reputation with") ~= nil
        or string.find(text, "use:%s+awards?%s+" .. amount .. "%s+reputation with") ~= nil
        or string.find(text, "use:%s+increases?%s+your%s+[^\n]-reputation%s+by%s+" .. amount) ~= nil
        or string.find(text, "use:%s+increases?%s+reputation%s+with%s+[^\n]-%sby%s+" .. amount) ~= nil
        or string.find(text, "use:%s+increases?%s+your%s+reputation with") ~= nil
end

local function IsQuestStartAction(text)
    -- Blizzard's yellow "This Item Begins a Quest" line, or an explicit use
    -- action. Turn-in quest items do not carry either phrase.
    return string.find(text, "this item begins a quest", 1, true) ~= nil
        or (localizedStartsQuest ~= nil and string.find(text, localizedStartsQuest, 1, true) ~= nil)
        or string.find(text, "use:%s+[^\n]*begins? a quest") ~= nil
        or string.find(text, "use:%s+[^\n]*starts? a quest") ~= nil
end

local function IsCompletedQuestTooltip(text)
    -- Finished starters such as Direbrew's Dire Brew keep the begins-a-quest
    -- line and add a separate "Quest completed" status line.
    return string.find("\n" .. text .. "\n", "\nquest completed%f[%A]") ~= nil
end

local function QuestIsTaken(questID)
    questID = tonumber(questID)
    if not (questID and questID > 0 and C_QuestLog) then
        return false
    end
    if C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) == true then
        return true
    end
    if C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(questID) == true then
        return true
    end
    return false
end

local function ContainerStartQuest(context)
    if not (context and C_Container and C_Container.GetContainerItemQuestInfo
        and context.bag ~= nil and context.slot ~= nil) then
        return nil
    end
    -- Retail returns one ItemQuestInfo table. Older callers returned
    -- isQuestItem, questID, isActive.
    local ok, info, questID, isActive = pcall(C_Container.GetContainerItemQuestInfo, context.bag, context.slot)
    if not ok or info == nil then
        return nil
    end
    if type(info) ~= "table" then
        info = { questID = questID, isActive = isActive }
    end
    return info
end

local function IsStartQuestUnavailable(context)
    local info = ContainerStartQuest(context)
    if info and (info.isActive == true or info.isActive == 1 or QuestIsTaken(info.questID)) then
        return true
    end

    local snapshot = addon:GetTooltipSnapshot(context)
    local questIDs = snapshot and snapshot.questIDs
    if not questIDs then
        return false
    end
    for index = 1, #questIDs do
        if QuestIsTaken(questIDs[index]) then
            return true
        end
    end
    return false
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

local function IsRightClickOpen(text)
    -- Blizzard's ITEM_OPENABLE line. Loot-Filled Pumpkins, Loot-Stuffed
    -- Pumpkins, Crudely Wrapped Gifts, and the old Treat Bag use it instead
    -- of a Use: line. The angle brackets are part of that global string.
    return string.find(text, "<right click to open>", 1, true) ~= nil
        or (localizedOpenable ~= nil and string.find(text, localizedOpenable, 1, true) ~= nil)
end

local function IsTreatClaimAction(text)
    -- Handful of Treats: "Use: Claim your treats." The spell opens the bag,
    -- but the line does not say "open".
    return string.find(text, "use:%s+claim your treats%f[%A]") ~= nil
end

local function IsOpenAction(text)
    -- Require a non-letter after "open" so "Use: Opens a portal" is excluded.
    return string.find(text, "use:%s+open%f[%A]") ~= nil
        or IsRightClickOpen(text)
end

local function IsBlingtronMessageAction(text)
    -- Gift-package scraps such as Encoded Message ("Use: Decode the message.")
    -- and Encrypted Message ("Use: Decrypt the message."). Using one consumes
    -- it and creates a collectible decoded or decrypted message.
    return string.find(text, "use:%s+decode the message%f[%A]") ~= nil
        or string.find(text, "use:%s+decrypt the message%f[%A]") ~= nil
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
    -- Blizzard's LOCKED status is a line of its own. Matching the word anywhere
    -- would also hide items whose name or flavour text mentions "locked".
    return string.find(text, "requires lockpicking", 1, true) ~= nil
        or string.find("\n" .. text .. "\n", "\n%s*locked%s*\n") ~= nil
        or HasExactLine(text, localizedLocked)
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
    if string.find(text, "^requires[%s:]") or string.find(text, "^classes[%s:]") then
        return true
    end
    for index = 1, #localizedRestrictionPatterns do
        if string.find(text, localizedRestrictionPatterns[index]) then
            return true
        end
    end
    return false
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

local function NoteQuestID(questIDs, seen, value)
    value = tonumber(value)
    if not (value and value > 0) or seen[value] then
        return
    end
    seen[value] = true
    questIDs[#questIDs + 1] = value
end

local function NoteQuestLine(line, questIDs, seen)
    if type(line) ~= "table" then
        return
    end
    local lineTypes = Enum and Enum.TooltipDataLineType
    local questTitle = lineTypes and lineTypes.QuestTitle or 17
    local nestedBlock = lineTypes and lineTypes.NestedBlock or 19
    local questTooltip = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Quest or 23
    if line.type == questTitle then
        NoteQuestID(questIDs, seen, line.id)
        NoteQuestID(questIDs, seen, line.tooltipID)
    elseif line.type == nestedBlock and line.tooltipType == questTooltip then
        NoteQuestID(questIDs, seen, line.tooltipID or line.id)
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

local function SlotCacheKey(bag, slot)
    return tostring(bag) .. ":" .. tostring(slot)
end

local function DefaultMetrics()
    return {
        slotsInspected = 0,
        slotsChanged = 0,
        tooltipSnapshots = 0,
        incompleteTooltipReads = 0,
        tooltipRetriesScheduled = 0,
        itemsClassified = 0,
        workTicks = 0,
        maxWorkPerTick = 0,
        fallbackTooltips = 0,
        maxTickMs = 0,
        totalTickMs = 0,
    }
end

function addon:ResetMetrics()
    self.metrics = DefaultMetrics()
end

function addon:GetMetrics()
    return self.metrics or DefaultMetrics()
end

function addon:NoteMetric(name, amount)
    if not self.metrics then
        self.metrics = DefaultMetrics()
    end
    self.metrics[name] = (self.metrics[name] or 0) + (amount or 1)
end

function addon:InvalidateScanCache()
    self.scanCache = {}
end

function addon:InvalidateScanCacheForItem(itemID)
    if not (self.scanCache and itemID) then
        return
    end
    for key, entry in pairs(self.scanCache) do
        if entry.itemID == itemID then
            self.scanCache[key] = nil
        end
    end
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
    if not context or not snapshot or snapshot.complete == false then
        return
    end
    self.scanCache = self.scanCache or {}
    local key = SlotCacheKey(context.bag, context.slot)
    local entry = self.scanCache[key] or {}
    entry.itemID = context.itemID
    entry.link = context.link
    entry.stackCount = context.stackCount
    entry.snapshot = snapshot
    self.scanCache[key] = entry
end

function addon:IsTooltipSnapshotComplete(snapshot)
    return snapshot and snapshot.complete ~= false
end

function addon:GetTooltipSnapshot(context)
    if context.tooltipSnapshot then
        return context.tooltipSnapshot
    end

    local cached = self.useScanCache and self:GetSlotTooltipCache(context)
    if cached and cached.complete ~= false then
        context.tooltipSnapshot = cached
        return cached
    end

    self:NoteMetric("tooltipSnapshots")

    local parts = {}
    local state = {
        unmetRequirement = false,
        sawRestrictionText = false,
        sawRestrictionColor = false,
    }
    local battlePetSpeciesID
    local questIDs = {}
    local seenQuestIDs = {}
    local skipCompanionScan = IsCompanionPetItem(context)
    local tooltipReadFailed = false

    if C_TooltipInfo and C_TooltipInfo.GetBagItem then
        local ok, tooltip = pcall(C_TooltipInfo.GetBagItem, context.bag, context.slot)
        if not ok then
            tooltipReadFailed = true
        elseif tooltip then
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
                    NoteQuestLine(line, questIDs, seenQuestIDs)
                    CollectRestrictionState(line.leftText, line.leftColor, state)
                    CollectRestrictionState(line.rightText, line.rightColor, state)
                    CollectRestrictionState(line.text, line.color or line.leftColor, state)
                end
            end
        else
            tooltipReadFailed = true
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
            self:NoteMetric("fallbackTooltips")
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

    local text = string.lower(table.concat(parts, "\n"))
    local hasUseText = HasUseText(text)
    local missingRestrictionColor = state.sawRestrictionText and not state.sawRestrictionColor
        and not state.unmetRequirement
    -- A fully loaded item can legitimately have NO Use: line: crafting
    -- reagents, equipment, ordinary materials, etc. Treating all such items
    -- as incomplete made each of them retry several times after every reload.
    -- Keep retrying genuinely suspicious short/name-only tooltips, since a
    -- Curio or another learnable may receive its Use: line asynchronously.
    -- Quest starters can be finished without any Use: line. Right-click
    -- containers such as a Loot-Filled Pumpkin never grow a Use: line either.
    local nameOnly = text ~= "" and context.name ~= nil
        and text == string.lower(context.name)
    local looksPartial = text == "" or not string.find(text, "\n", 1, true)
        or nameOnly
    -- Combat and utility Curios can initially have a long, otherwise complete
    -- tooltip (name, type, rank, flavour/effect) before their collection Use:
    -- line arrives. Ordinary multi-line equipment/reagents should NOT retry.
    -- A known Curio is intentionally complete even without an action line.
    local itemType = string.lower(context.itemType or "")
    local itemSubType = string.lower(context.itemSubType or "")
    local curioTooltip = HasTooltipTypeLine(text, "combat curio")
        or HasTooltipTypeLine(text, "utility curio")
        or itemType == "combat curio" or itemType == "utility curio"
        or itemSubType == "combat curio" or itemSubType == "utility curio"
    local waitingForCurioUse = curioTooltip
        and not ContainsAny(text, curioText)
        and not ContainsAny(text, knownText)
    local complete = not tooltipReadFailed
        and not missingRestrictionColor
        and not waitingForCurioUse
        and (hasUseText or IsQuestStartAction(text) or IsRightClickOpen(text)
            or battlePetSpeciesID
            or context.hasLoot == true or inertNameOnlyItemIDs[context.itemID]
            or not looksPartial)
    if not complete then
        self:NoteMetric("incompleteTooltipReads")
    end

    context.tooltipSnapshot = {
        text = text,
        unmetRequirement = state.unmetRequirement,
        sawRestrictionText = state.sawRestrictionText == true,
        battlePetSpeciesID = battlePetSpeciesID,
        questIDs = questIDs[1] and questIDs or nil,
        questStarter = IsQuestStartAction(text),
        nameOnly = nameOnly == true,
        complete = complete,
    }
    if self.useScanCache and complete then
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

local function IsUncollectedPet(context, uncollectedOnly)
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
    local learnable = owned < limit and not (uncollectedOnly and owned > 0)
    return learnable, speciesID, owned, limit
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
    self:NoteMetric("itemsClassified")
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
        if self:HasUnmetRequirement(context) then
            return nil
        end
        return "mount", "Uncollected mount — click to learn"
    end

    if IsUncollectedToy(context.itemID) then
        if self:HasUnmetRequirement(context) then
            return nil
        end
        return "toy", "Uncollected toy — click to learn"
    end

    local isPet, speciesID, ownedPets, petLimit = IsUncollectedPet(context,
        self.db and self.db.petUncollectedOnly == true)
    context.petSpeciesID = speciesID
    if isPet then
        if self:HasUnmetRequirement(context) then
            return nil
        end
        context.uniqueKey = "pet:" .. speciesID
        if ownedPets > 0 then
            return "pet", ("Battle pet (%d/%d owned) — click to learn"):format(ownedPets, petLimit)
        end
        return "pet", "Uncollected battle pet — click to learn"
    end

    -- Some cosmetic companions do not expose battle-pet metadata consistently.
    -- Their standard use text is still an explicit learn action.
    if not speciesID and ContainsAny(tooltipText, companionText) then
        if self:HasUnmetRequirement(context) then
            return nil
        end
        return "pet", "Uncollected companion — click to learn"
    end

    if ContainsAny(tooltipText, curioText) then
        if self:HasUnmetRequirement(context) then
            return nil
        end
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

    local labyrinthReason = GetLabyrinthActionReason(tooltipText)
    if labyrinthReason and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "progress", labyrinthReason
    end

    if IsReputationGrantAction(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "progress", "Reputation token — click to use"
    end

    if IsQuestStartAction(tooltipText) and not IsCompletedQuestTooltip(tooltipText)
        and not IsStartQuestUnavailable(context) and not self:HasUnmetRequirement(context) then
        -- Some starters, such as Celestial Invitation, have no spell and no
        -- Use: line. IsUsableItem is false for those, but clicking still opens
        -- the quest. A real Use: line still has to pass the usable-item check.
        if not HasUseText(tooltipText) or IsItemUsable(context.itemID) then
            return "quest", "Quest starter — click to begin"
        end
    end

    local itemType = string.lower(context.itemType or "")
    local itemSubType = string.lower(context.itemSubType or "")

    local isDecorType = itemType == "housing"
        or itemType == "decor"
        or itemSubType == "housing decor"
        or itemSubType == "decoration"
    local hasDecorUse = ContainsAny(tooltipText, decorText)
    -- A House Chest deposit adds another copy, even when the decor is learned.
    -- Trust this explicit action if generic item usability reports false; keep
    -- the usability guard for other decor actions and all requirement checks.
    local isHouseChestDeposit = string.find("\n" .. tooltipText,
        "\n%s*use:%s+adds? this decor to your house chest%.") ~= nil
    if hasDecorUse and (isDecorType or string.find(tooltipText, "decor", 1, true))
        and (isHouseChestDeposit or IsItemUsable(context.itemID))
        and not self:HasUnmetRequirement(context) then
        return "decor", "Housing decor — click to add"
    end

    if IsDelveBotUpgrade(tooltipText) and not self:HasUnmetRequirement(context) then
        return "toy", "Delve-O-Bot upgrade — click to apply"
    end

    if IsLootSpecGearToken(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "transmog", "Gear token — click to create item"
    end

    if IsTierTokenAction(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "transmog", "Tier token — click to create set item"
    end

    if IsVisualEffectUnlock(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "transmog", "Visual effect unlock — click to learn"
    end

    if (IsCustomizationUnlock(tooltipText) or IsCustomizationItem(context, tooltipText))
        and IsItemUsable(context.itemID) and not self:HasUnmetRequirement(context) then
        return "transmog", "Mount customization — click to learn"
    end

    -- The explicit costume-learning action is sufficient even when the
    -- usable-item API reports false. Keep known/restriction tooltip guards.
    if IsPepeCostumeUnlock(tooltipText) and not self:HasUnmetRequirement(context) then
        return "transmog", "Pepe costume — click to learn"
    end

    if IsWeaponIllusionUnlock(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "transmog", "Weapon illusion — click to learn"
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

    if IsBlingtronMessageAction(tooltipText) and IsItemUsable(context.itemID)
        and not self:HasUnmetRequirement(context) then
        return "container", "Blingtron message — click to decode"
    end

    if IsTreatClaimAction(tooltipText) then
        -- The claim spell has no item spell in the tooltip data, so
        -- IsUsableItem can stay false while the line is still usable. A red
        -- "Requires Hallow's End" line is the reliable off-season check.
        if self:HasUnmetRequirement(context) then
            return nil
        end
        return "container", "Hallow's End treats — click to claim"
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
    if category == "pet" and context.itemID == PET_CAGE_ITEM_ID then
        -- Cages share one item ID across species. Use the displayed cage,
        -- with the same combat and interaction guards as appearance tokens.
        return ("/stopmacro [combat]\n/use %d %d"):format(context.bag, context.slot), true
    end
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

