local slotNames = {"BackSlot","ChestSlot","FeetSlot","Finger0Slot","Finger1Slot","HandsSlot","HeadSlot","LegsSlot","MainHandSlot","NeckSlot","SecondaryHandSlot","ShoulderSlot","Trinket0Slot","Trinket1Slot","WaistSlot","WristSlot"};

local datSets = {}
datSets["Wearing 1H/OH"] = {
    INVTYPE_HEAD=1,
    INVTYPE_NECK=1,
    INVTYPE_SHOULDER=1,
    INVTYPE_CLOAK=1,
    INVTYPE_CHEST=1,
    INVTYPE_WRIST=1,
    INVTYPE_HAND=1,
    INVTYPE_WAIST=1,
    INVTYPE_LEGS=1,
    INVTYPE_FEET=1,
    INVTYPE_FINGER=2,
    INVTYPE_TRINKET=2,
    INVTYPE_WEAPONMAINHAND=1,
    INVTYPE_WEAPONOFFHAND=1
}
datSets["Wearing 2H"] = {
    INVTYPE_HEAD=1,
    INVTYPE_NECK=1,
    INVTYPE_SHOULDER=1,
    INVTYPE_CLOAK=1,
    INVTYPE_CHEST=1,
    INVTYPE_WRIST=1,
    INVTYPE_HAND=1,
    INVTYPE_WAIST=1,
    INVTYPE_LEGS=1,
    INVTYPE_FEET=1,
    INVTYPE_FINGER=2,
    INVTYPE_TRINKET=2,
    INVTYPE_2HWEAPON=1
}

interestingItemLevels = {435, 460, 470, 480, 500}

gEquipSlots = {}
gOptions = {}

function Dat_Command(msg)
    gEquipSlots = {}
    gOptions = {}

    local goalItemLevel = nil

    local rawOpts = { strsplit(" ", msg) }
    for i,v in ipairs(rawOpts) do
        local n = tonumber(v)
        if n == nil then
            gOptions[v] = 1
        else
            goalItemLevel = n
        end
    end

    local averageItemLevel, averageEquippedItemLevel = GetAverageItemLevel();
    if(goalItemLevel == nil) then
        goalItemLevel = averageItemLevel
        for i, v in ipairs(interestingItemLevels) do
            if(averageItemLevel < v) then
                goalItemLevel = v
                break
            end
        end
    end
    if(goalItemLevel == nil) then
        datError("I can't figure out what item level you're shooting for, bailing out.")
        return
    end
    if(goalItemLevel <= averageItemLevel) then
        datError("You've already made it to iLevel "..goalItemLevel..". Grats!")
        return
    end

    datLog("Average Item Level: " .. averageItemLevel)
    datLog("Average Equipped Item Level: " .. averageEquippedItemLevel)
    datLog("Shooting for iLevel " .. goalItemLevel)

    -- Traverse Equipped Items
    local lookedAtEquippedCount = 0
    for i, slotName in ipairs(slotNames) do
        local slotID = GetInventorySlotInfo(slotName)
        local itemID = GetInventoryItemID("player", slotID)
        if itemID ~= nil then
            itemLink = GetInventoryItemLink("player", slotID)
            datThinkAbout(itemID, itemLink)
            lookedAtEquippedCount = lookedAtEquippedCount + 1
        end
    end
    datVerbose("Looked at " .. lookedAtEquippedCount .. " equipped items.")

    -- Traverse Bag and Bank
    local lookedAtBagCount = 0
    for bagIndex = BANK_CONTAINER, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
        local bagSize = GetContainerNumSlots(bagIndex)
        if bagSize > 0 then
            lookedAtBagCount = lookedAtBagCount + 1
            for slotIndex = 1, bagSize do
                itemID = GetContainerItemID(bagIndex, slotIndex)
                if itemID ~= nil then
                    itemLink = GetContainerItemLink(bagIndex, slotIndex)
                    datThinkAbout(itemID, itemLink)
                end
            end
        end
    end

    local bankWarning = ""
    if(lookedAtBagCount < 7) then
        bankWarning = " (bank not open?)"
    end
    datVerbose("Looked at " .. lookedAtBagCount .. " bags. " .. bankWarning)

    for slotName, items in pairs(gEquipSlots) do
        sort(items, datSortByItemLevel)
--        for i, item in ipairs(items) do
--            datLog("slot " .. slotName .. ": " .. item.name .. " ["..item.ilevel.."]")
--        end
    end

    for name, set in pairs(datSets) do
        datCalcSet(name, set, goalItemLevel)
    end
end

------------------------------------------------------------------------------------------

SLASH_DAT1 = "/dat";
SlashCmdList["DAT"] = Dat_Command

------------------------------------------------------------------------------------------

function c(t, r, g, b)
    return format("|cff00ff00%s|r", t)
end

function datCalcSet(name, set, goalItemLevel)
    local totalItems = 0
    local itemLevelSum = 0
    for equipSlot, equipCount in pairs(set) do
        totalItems = totalItems + equipCount
        if gEquipSlots[equipSlot] then
            local count = getn(gEquipSlots[equipSlot])
            if count < equipCount then
                datLog("Warning: Not enough items of type " .. equipSlot)
            end
            if count > equipCount then
                count = equipCount
            end
            for i=1,equipCount do
                item = gEquipSlots[equipSlot][i]
                itemLevelSum = itemLevelSum + item.ilevel
                datVerbose(name..": ["..item.equipSlot.."]: " .. item.name .. ", " .. item.ilevel)
            end
        else
            datLog("Warning: Nothing to equip for slot " .. equipSlot)
        end
    end
    local goalSum = goalItemLevel * totalItems
    local itemLevelAverage = itemLevelSum / totalItems
    local itemLevelsNeeded = goalSum - itemLevelSum
    datLog(name.." ["..totalItems.." slots]: Goal Sum ["..c(goalItemLevel,255,255,0).."]: "..c(goalSum,255,255,0)..", iLevel Sum: " .. c(itemLevelSum,255,255,0) .. ", iLevel Avg: " .. c(format("%4.4f", itemLevelAverage),255,255,0) .. ", Raw iLevels Needed: " .. c(itemLevelsNeeded,255,255,0))
end

function datSortByItemLevel(a, b)
    return (a.ilevel > b.ilevel)
end

function datThinkAbout(itemID, itemLink)
    item = datItemInfo(itemID, itemLink)
    if string.len(item.equipSlot) > 0 then
        if datCanUse(itemLink) then
            if gEquipSlots[item.equipSlot] == nil then
                gEquipSlots[item.equipSlot] = {}
            end
            tinsert(gEquipSlots[item.equipSlot], item)
        end
    end
end

-- What a terrible hack.
function datCanUse(itemLink)
    DatTooltip:ClearLines()
    DatTooltip:SetHyperlink(itemLink)

    local l = { "TextLeft", "TextRight" }

    local n = DatTooltip:NumLines(0)
    --if n > 5 then n = 5 end
    -- only go down to line 5, recipies and patterns may contain red text

    for i = 2, n do
        for _, v in pairs( l ) do
            local obj = _G[string.format( "%s%s%s", DatTooltip:GetName(), v, i )]
            if obj and obj:IsShown() then

                local txt = obj:GetText()

                if txt == "" then
                    -- recipies and patterns have a blank line between the item and what it creates
                    return false
                end

                local r, g, b = obj:GetTextColor()
                local c = string.format( "%02x%02x%02x", r * 255, g * 255, b * 255 )

                if ( c == "fe1f1f" ) then
                    --ArkInventory.Output( "line[", i, "]=[", txt, "]" )
                    if txt ~= ITEM_DISENCHANT_NOT_DISENCHANTABLE then
                        return false
                    end
                end

            end
        end
    end

    return true

end


-- via Ro - http://us.battle.net/wow/en/forum/topic/7199032730
function GetActualItemLevel(link, baseLevel)
    local levelAdjust = { -- 11th item:id field and level adjustment
        ["0"]=0,["1"]=8,["373"]=4,["374"]=8,["375"]=4,["376"]=4,
        ["377"]=4,["379"]=4,["380"]=4,["445"]=0,["446"]=4,["447"]=8,
        ["451"]=0,["452"]=8,["453"]=0,["454"]=4,["455"]=8,["456"]=0,
        ["457"]=8,["458"]=0,["459"]=4,["460"]=8,["461"]=12,["462"]=16}
    local upgrade = link:match(":(%d+)\124h%[")

    if baseLevel and upgrade then
        return baseLevel + levelAdjust[upgrade]
    else
        return baseLevel
    end;
end;

function datItemInfo(itemID, itemLink)
    local name, _, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemID)
    if (iLevel >= 450) then
        iLevel = GetActualItemLevel(itemLink, iLevel)
    end
    if(equipSlot == "INVTYPE_ROBE") then -- "ROBE" is stupid
        equipSlot = "INVTYPE_CHEST"
    end
    if(equipSlot == "INVTYPE_HOLDABLE") then -- "HOLDABLE" is stupid
        equipSlot = "INVTYPE_WEAPONOFFHAND"
    end
    return {name=name, ilevel=iLevel, equipSlot=equipSlot}
end

function datLog(msg)
    print("Dat: " .. msg)
end

function datVerbose(msg)
    if gOptions["verbose"] then
        datLog(msg)
    end
end

function datError(msg)
    print("Dat Error: " .. msg)
end