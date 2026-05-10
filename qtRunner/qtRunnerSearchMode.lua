local strfind = string.find

local strlower = string.lower

local strgsub = string.gsub

local tinsert = table.insert

local tsort = table.sort



qtRunnerSearchMode = {

    mode = "warp",

    cacheDirty = true,

    cachedZoneId = nil,

    cachedItems = nil,

    cachedQuests = nil,

    cachedNpcs = nil,

    npcCacheZoneId = nil,

    previewLootZoneId = nil,

    previewLootZoneName = nil,

}



local ATTUNE_FORGE_TF = 1

local ATTUNE_FORGE_WF = 2

local ATTUNE_FORGE_LF = 3



local FORGE_BADGE_COLORS = {

    TF = "|cff8080FF",

    WF = "|cffFFA680",

    LF = "|cffFFFFA6",

}



local function RowForgeItemTier(item)

    if not item or not item.objId then

        return nil

    end

    local cached = tonumber(item.forgeItemTier)

    if cached == ATTUNE_FORGE_TF or cached == ATTUNE_FORGE_WF or cached == ATTUNE_FORGE_LF then

        return cached

    end

    if not qtRunnerSearchData or not qtRunnerSearchData.GetForgeItemTier then

        return nil

    end

    return tonumber(qtRunnerSearchData:GetForgeItemTier(item.objId, item.itemLink))

end



local function GetForgeBadgeText(item)

    local n = RowForgeItemTier(item)

    if n == ATTUNE_FORGE_WF then

        return FORGE_BADGE_COLORS.WF .. "[WF]|r"

    elseif n == ATTUNE_FORGE_LF then

        return FORGE_BADGE_COLORS.LF .. "[LF]|r"

    elseif n == ATTUNE_FORGE_TF then

        return FORGE_BADGE_COLORS.TF .. "[TF]|r"

    end

    return ""

end



local function SplitForgeQueryTokens(query)

    local want = {}

    local q = query or ""

    q = q:gsub("/%s*([%a]+)", function(w)

        local lw = strlower(w)

        if lw == "tf" then

            want.tf = true

            return " "

        elseif lw == "wf" then

            want.wf = true

            return " "

        elseif lw == "lf" then

            want.lf = true

            return " "

        elseif lw == "acc" then

            want.acc = true

            return " "

        elseif lw == "a" then

            want.acc = true

            return " "

        elseif lw == "ab" then

            want.accboe = true

            return " "

        elseif lw == "v" then

            want.vendor = true

            return " "

        elseif lw == "va" then

            want.vendorattune = true

            return " "

        elseif lw == "vab" then

            want.vendoraccboe = true

            return " "

        elseif lw == "vb" then

            want.vendorboe = true

            return " "

        elseif lw == "q" then

            want.quest = true

            return " "

        elseif lw == "t" then

            want.trash = true

            return " "

        elseif lw == "c" then

            want.craft = true

            return " "

        elseif lw == "ca" then

            want.craftacc = true

            return " "

        elseif lw == "b" then

            want.boss = true

            return " "

        elseif lw == "ba" then

            want.bossacc = true

            return " "

        elseif lw == "u" then

            want.unique = true

            return " "

        elseif lw == "ub" then

            want.ub = true

            return " "

        elseif lw == "zo" then

            want.zoneonly = true

            return " "

        elseif lw == "ua" then

            want.ua = true

            return " "

        end

        return "/" .. w

    end)

    q = q:gsub("%s+", " ")

    q = q:gsub("^%s+", ""):gsub("%s+$", "")

    return want, q

end



local function ForgeWantAny(want)

    return want.tf or want.wf or want.lf or want.ua
        or want.acc or want.accboe or want.vendor or want.vendorattune or want.vendoraccboe
        or want.vendorboe
        or want.quest or want.trash or want.craft or want.craftacc or want.boss or want.bossacc or want.unique or want.ub or want.zoneonly

end



local function NormalizeItemSearchQuery(q)

    q = strlower(strgsub(tostring(q or ""), "^%s*(.-)%s*$", "%1"))

    q = strgsub(q, "%s+", " ")

    return q

end



local function ItemNamePlainMatch(name, nameQuery)

    local lname = strlower(name or "")

    local lq = NormalizeItemSearchQuery(nameQuery)

    if lq == "" then return true end

    return strfind(lname, lq, 1, true) == 1

end



local function ItemNameTokenMatches(name, nameQuery)

    local lname = strlower(name or "")

    local lq = NormalizeItemSearchQuery(nameQuery)

    if lq == "" then return true, 0, 0, 0 end

    if strfind(lname, lq, 1, true) == 1 then

        return true, 0, 0, #lname

    end

    local pos = strfind(lname, lq, 1, true)

    if pos then

        return true, 1, pos, #lname

    end

    local worst = 0

    for w in string.gmatch(lq, "%S+") do

        local p = strfind(lname, w, 1, true)

        if not p then return false end

        if p > worst then worst = p end

    end

    return true, 2, worst, #lname

end



local function ItemPassesForgeTokens(item, want)

    local any = false

    local hit = false

    local tier = RowForgeItemTier(item)

    if want.lf then

        any = true

        if tier == ATTUNE_FORGE_LF then hit = true end

    end

    if want.wf then

        any = true

        if tier == ATTUNE_FORGE_WF then hit = true end

    end

    if want.tf then

        any = true

        if tier == ATTUNE_FORGE_TF then hit = true end

    end

    if want.ua then

        any = true

        if not item.badgeAcc and (item.unattuned or item.canAttuneHelperOne) then hit = true end

    end

    if want.vendor then

        any = true

        if item.badgeVendor and item.canAttuneHelperOne and not item.badgeAcc then hit = true end

    end

    if want.vendorattune then

        any = true

        if item.badgeVendor and item.canAttuneHelperOne then hit = true end

    end

    if want.vendoraccboe then

        any = true

        if item.badgeVendor and item.badgeAcc and item.isBoe and item.isAttunableTag then hit = true end

    end

    if want.vendorboe then

        any = true

        if item.badgeVendor and item.isBoe then hit = true end

    end

    if want.accboe then

        any = true

        if item.badgeAcc and item.isBoe and item.isAttunableTag then hit = true end

    end

    if want.quest then

        any = true

        if item.badgeQuest then hit = true end

    end

    if want.trash then

        any = true

        if item.dropTag == "Trash" and not item.badgeCraft then hit = true end

    end

    if want.craft then

        any = true

        if item.badgeCraft and item.canAttuneHelperOne and not item.badgeAcc then hit = true end

    end

    if want.craftacc then

        any = true

        if item.badgeCraft and item.canAttuneHelperRaw ~= nil and item.canAttuneHelperRaw < 1 then hit = true end

    end

    if want.boss then

        any = true

        if item.dropTag == "Boss"
            and not item.badgeVendor
            and not item.badgeQuest
            and not item.badgeCraft
            and item.canAttuneHelperOne
        then
            hit = true
        end

    end

    if want.bossacc then

        any = true

        if item.dropTag == "Boss"
            and not item.badgeVendor
            and not item.badgeQuest
            and not item.badgeCraft
            and item.canAttuneHelperRaw ~= nil
            and item.canAttuneHelperRaw < 1
        then
            hit = true
        end

    end

    if want.unique then

        any = true

        if item.dropTag == "Unique"
            and not item.badgeVendor
            and not item.badgeQuest
            and not item.badgeCraft
            and item.canAttuneHelperOne
        then
            hit = true
        end

    end

    if want.ub then

        any = true

        local charUnique = item.dropTag == "Unique"
            and not item.badgeVendor
            and not item.badgeQuest
            and not item.badgeCraft
            and item.canAttuneHelperOne
        local accBoeShare = item.badgeAcc and item.isBoe and item.isAttunableTag
            and not item.badgeCraft
            and not item.badgeVendor
            and item.dropTag ~= "Trash"

        if charUnique or accBoeShare then
            hit = true
        end

    end

    if want.zoneonly then

        any = true

        if item.badgeZoneOnly then hit = true end

    end

    return not any or hit

end



local function MatchQuery(name, query)

    if not query or query == "" then

        return true

    end

    return strfind(strlower(name or ""), strlower(query), 1, true) ~= nil

end

local function ZoneQuestMatchesQuery(quest, questQuery)
    if not questQuery or questQuery == "" then
        return true
    end
    if MatchQuery(quest.name, questQuery) then
        return true
    end
    local entryId = tonumber(quest.chainEntryQuestId) or tonumber(quest.objId)
    if Custom_GetQuestName and entryId and entryId > 0 then
        if MatchQuery(Custom_GetQuestName(entryId), questQuery) then
            return true
        end
    end
    local rid = tonumber(quest.rewardItemId)
    if rid and rid > 0 and GetItemInfo then
        if MatchQuery(GetItemInfo(rid), questQuery) then
            return true
        end
    end
    if type(quest.rewardItemIds) == "table" then
        for j = 1, #quest.rewardItemIds do
            local iid = tonumber(quest.rewardItemIds[j])
            if iid and iid > 0 and GetItemInfo then
                if MatchQuery(GetItemInfo(iid), questQuery) then
                    return true
                end
            end
        end
    end
    if type(quest.chainRewardQuestIds) == "table" and Custom_GetQuestName then
        for j = 1, #quest.chainRewardQuestIds do
            local cq = tonumber(quest.chainRewardQuestIds[j])
            if cq and cq > 0 and MatchQuery(Custom_GetQuestName(cq), questQuery) then
                return true
            end
        end
    end
    return false
end



local function ItemRowColor(item)

    local pct = item.forgePctRounded or 0

    if pct >= 90 then

        return { r = 0.3, g = 1, b = 0.3 }

    elseif pct >= 50 then

        return { r = 1, g = 0.82, b = 0.24 }

    end

    return { r = 1, g = 0.44, b = 0.44 }

end

local function ItemQualityRowColor(item)

    if GetItemQualityColor then

        local q = tonumber(item and item.itemQuality) or 0

        local r, g, b = GetItemQualityColor(q)

        if r and g and b then

            return { r = r, g = g, b = b }

        end

    end

    return { r = 1, g = 1, b = 1 }

end



local function AttuneTooltipLine(item)

    local pct = item.forgePctRounded

    if pct == nil or pct <= 0 then

        return nil

    end

    return "Attune: " .. tostring(pct) .. "%"

end



local function DropTagPrefix(tag)

    if tag == "Unique" then return "|cFFBB88FF[U]|r " end

    if tag == "Boss" then return "|cFFFFAA66[B]|r " end

    if tag == "Trash" then return "|cFF888888[T]|r " end

    return "|cFF6699AA[M]|r "

end



local function RowDropTagPrefix(item)

    if item.badgeCraft then

        return ""

    end

    if item.badgeQuest then

        return ""

    end

    if item.badgeVendor then

        return ""

    end

    return DropTagPrefix(item.dropTag)

end

local function ItemBadgeSortRank(item)

    if item.badgeQuest then return 1 end

    if item.badgeVendor then return 2 end

    if item.dropTag == "Boss" then return 3 end

    if item.dropTag == "Unique" then return 4 end

    if item.dropTag == "Trash" then return 5 end

    if item.badgeCraft then return 6 end

    return 7

end

local function CompareItemByBadgeThenIlvl(a, b)

    local ra = ItemBadgeSortRank(a.item)
    local rb = ItemBadgeSortRank(b.item)
    if ra ~= rb then return ra < rb end

    local ila = tonumber(a.item.itemLevel) or 0
    local ilb = tonumber(b.item.itemLevel) or 0
    if ila ~= ilb then return ila > ilb end

    return nil

end



local function SourceBadgesColored(item, noTrailingSpace, wantAcc)

    local s = ""

    if item.badgeCraft then

        s = "|cFF88DD88[C]|r"

        if not noTrailingSpace then

            s = s .. " "

        end

        return s

    end

    if item.badgeQuest then

        s = s .. "|cFF66AAFF[Q]|r"

        if not noTrailingSpace then

            s = s .. " "

        end

        return s

    end

    local accBadge = item.badgeAcc
        and (wantAcc or (item.dropTag == "Unique" and item.isBoe and not item.canAttuneHelperOne))

    if accBadge then

        s = s .. "|cFFFFCC00[ACC]|r"

    end

    if item.badgeVendor then

        s = s .. "|cFFCAA266[V]|r"

    end

    if s ~= "" and not noTrailingSpace then

        s = s .. " "

    end

    return s

end



local function DropTooltipLine(item)

    local tag = item.dropTag or "?"

    local n = item.dropSrcTotal or 0

    local bh = item.dropBossHits or 0

    if item.badgeCraft then

        local line = "Craft/prof (" .. tostring(n) .. " sources)"

        local badges = SourceBadgesColored(item, true)

        if badges ~= "" then

            line = line .. "  " .. badges

        end

        return line

    end

    local line = "Drop: " .. tag .. " (" .. tostring(n) .. " sources)"

    if bh > 0 then

        line = line .. "  boss+" .. tostring(bh)

    end

    local badges = SourceBadgesColored(item, true)

    if badges ~= "" then

        line = line .. "  " .. badges

    end

    return line

end



function qtRunnerSearchMode:IsWarpMode()

    return self.mode == "warp"

end



function qtRunnerSearchMode:GetModeLabel()

    if self.mode == "zone_pick" then return "Zone search" end

    if self.mode == "zone_items" then

        if self.previewLootZoneName then

            return "Zone Items (" .. self.previewLootZoneName .. ")"

        end

        return "Zone Items"

    end

    if self.mode == "zone_quests" then return "Zone Quests" end

    -- FEATURE CULLED zone NPC mode
    -- if self.mode == "zone_npcs" then return "Zone NPCs" end

    return "Warp"

end



function qtRunnerSearchMode:SetMode(modeName)

    -- FEATURE CULLED: zone_npcs removed from accepted modes.
    if modeName ~= "zone_items" and modeName ~= "zone_quests" and modeName ~= "warp" and modeName ~= "zone_pick" then

        return

    end

    self.mode = modeName

    if modeName == "warp" or modeName == "zone_pick" then

        self:MarkDirty()

    end

end



function qtRunnerSearchMode:ClearLootZonePreview()

    self.previewLootZoneId = nil

    self.previewLootZoneName = nil

    self:MarkDirty()

end



function qtRunnerSearchMode:MarkDirty()

    self.cacheDirty = true

    self.cachedZoneId = nil

    self.cachedItems = nil

    self.cachedQuests = nil

    self.cachedNpcs = nil

    self.npcCacheZoneId = nil

end



function qtRunnerSearchMode:InstallTrackerHook(onRefresh)

    if self.hookInstalled then

        return

    end

    self.hookInstalled = true

    local oldHook = _G.__itemHuntHook

    _G.__itemHuntHook = function()

        self:MarkDirty()

        if onRefresh then

            onRefresh()

        end

        if oldHook then

            oldHook()

        end

    end



    if not self.zoneEventFrame then

        self.zoneEventFrame = CreateFrame("Frame")

        self.zoneEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

        -- ʕ •ᴥ•ʔ✿ ItemHuntFrame populates async after zone change, schedule a 2s one-shot rebuild ✿ ʕ •ᴥ•ʔ
        local trackerDelay = CreateFrame("Frame")
        trackerDelay:Hide()
        trackerDelay:SetScript("OnUpdate", function(frame)
            if GetTime() < (frame.deadline or 0) then return end
            frame:Hide()
            if qtRunnerSearchData and qtRunnerSearchData.ClearQuestieAttunableCache then
                qtRunnerSearchData:ClearQuestieAttunableCache()
            end
            self:MarkDirty()
            if onRefresh then onRefresh() end
        end)
        self.zoneTrackerDelayFrame = trackerDelay

        self.zoneEventFrame:SetScript("OnEvent", function()

            if qtRunnerSearchData and qtRunnerSearchData.ClearQuestieAttunableCache then

                qtRunnerSearchData:ClearQuestieAttunableCache()

            end

            self:MarkDirty()

            if onRefresh then

                onRefresh()

            end

            trackerDelay.deadline = GetTime() + 2
            trackerDelay:Show()

        end)

    end

end



function qtRunnerSearchMode:BuildEntries(query)

    local zoneId = self.previewLootZoneId or qtRunnerSearchData:GetCurrentZoneId()

    local wantItems = self.mode == "zone_items"

    local wantQuests = self.mode == "zone_quests"

    -- FEATURE CULLED zone_npcs BuildZoneEntries(..., true) path.
    -- local needNpcs = self.mode == "zone_npcs"

    if self.cacheDirty or self.cachedZoneId ~= zoneId then

        self.cachedItems = nil

        self.cachedQuests = nil

    end

    if wantItems and not self.cachedItems then

        local items = select(1, qtRunnerSearchData:BuildZoneEntries(zoneId, false, true, false))

        self.cachedItems = items or {}

        self.cachedQuests = nil

    elseif wantQuests and not self.cachedQuests then

        local _, quests = qtRunnerSearchData:BuildZoneEntries(zoneId, false, false, true)

        self.cachedQuests = quests or {}

        self.cachedItems = nil

    end

    self.cachedZoneId = zoneId

    self.cacheDirty = false

    --[[ FEATURE CULLED
    if needNpcs and (self.npcCacheZoneId ~= zoneId or not self.cachedNpcs) then

        local _, _, npcs = qtRunnerSearchData:BuildZoneEntries(zoneId, true, true, true)

        self.cachedNpcs = npcs or {}

        self.npcCacheZoneId = zoneId

    end
    ]]

    local items = self.cachedItems or {}

    local quests = self.cachedQuests or {}

    local npcs = self.cachedNpcs or {}

    local entries = {}



    if self.mode == "zone_items" then

        local forgeWant, nameQuery = SplitForgeQueryTokens(query)

        nameQuery = NormalizeItemSearchQuery(nameQuery)

        local tokenNameMode = ForgeWantAny(forgeWant)

        local wantRollForge = forgeWant.tf or forgeWant.wf or forgeWant.lf

        local wantAcc = forgeWant.acc and true or false

        local defaultAttuneOnly = not tokenNameMode

        local scratch = {}

        for i = 1, #items do

            local item = items[i]

            if not (item.forgeSearchOnly and not wantRollForge)
                and ItemPassesForgeTokens(item, forgeWant)
                and (not wantAcc or item.badgeAcc)
                and (not defaultAttuneOnly or item.canAttuneHelperOne)
            then

                if tokenNameMode then

                    local ok, mt, mp, blen = ItemNameTokenMatches(item.name, nameQuery)

                    if ok then

                        tinsert(scratch, { item = item, mt = mt, mp = mp, blen = blen })

                    end

                elseif ItemNamePlainMatch(item.name, nameQuery) then

                    tinsert(scratch, { item = item })

                end

            end

        end

        if tokenNameMode then

            if wantRollForge then

                tsort(scratch, function(a, b)
                    local badgeCmp = CompareItemByBadgeThenIlvl(a, b)
                    if badgeCmp ~= nil then return badgeCmp end

                    local qa = tonumber(a.item.itemQuality) or 0

                    local qb = tonumber(b.item.itemQuality) or 0

                    if qa ~= qb then return qa > qb end

                    return strlower(a.item.name) < strlower(b.item.name)

                end)

            else

                tsort(scratch, function(a, b)
                    local badgeCmp = CompareItemByBadgeThenIlvl(a, b)
                    if badgeCmp ~= nil then return badgeCmp end

                    if a.mt ~= b.mt then return a.mt < b.mt end

                    if a.mp ~= b.mp then return a.mp < b.mp end

                    if a.blen ~= b.blen then return a.blen < b.blen end

                    local ta = a.item.dropTier or 4

                    local tb = b.item.dropTier or 4

                    if ta ~= tb then return ta < tb end

                    return strlower(a.item.name) < strlower(b.item.name)

                end)

            end

        else

            tsort(scratch, function(a, b)
                local badgeCmp = CompareItemByBadgeThenIlvl(a, b)
                if badgeCmp ~= nil then return badgeCmp end

                return strlower(a.item.name) < strlower(b.item.name)

            end)

        end

        for i = 1, #scratch do

            local item = scratch[i].item

            local badge = GetForgeBadgeText(item)

            local label

            if wantRollForge then

                label = item.name

                if badge ~= "" then

                    label = label .. "  " .. badge

                end

            else

                label = RowDropTagPrefix(item) .. SourceBadgesColored(item, false, wantAcc) .. item.name

                if badge ~= "" then

                    label = label .. "  " .. badge

                end

            end

            local tipLine = AttuneTooltipLine(item)

            local tipDrop = wantRollForge and nil or DropTooltipLine(item)

            tinsert(entries, {

                mode = self.mode,

                typeId = item.typeId,

                objId = item.objId,

                npcName = nil,

                label = label,

                tooltipAttune = tipLine,

                tooltipDrop = tipDrop,

                icon = item.icon,

                tracked = item.tracked,

                color = wantRollForge and ItemQualityRowColor(item) or ItemRowColor(item),

            })

        end

    elseif self.mode == "zone_quests" then

        local wantAccountAny = false
        local wantAccountOnly = false
        local wantCrossFaction = false
        local wantCharOnly = false
        local questQuery = tostring(query or "")
        questQuery = questQuery:gsub("/%s*([%a]+)", function(w)
            local lw = strlower(w)
            if lw == "acc" then
                wantAccountAny = true
                wantAccountOnly = true
                wantCrossFaction = true
                return " "
            end
            if lw == "a" then
                wantAccountAny = true
                wantCrossFaction = true
                return " "
            end
            if lw == "c" then
                wantCharOnly = true
                return " "
            end
            return "/" .. w
        end)
        questQuery = questQuery:gsub("%s+", " ")
        questQuery = questQuery:gsub("^%s+", ""):gsub("%s+$", "")

        local scopeTipLine
        if wantCharOnly then
            scopeTipLine = "|cFF888888List scope: this character only (/c).|r"
        elseif wantAccountOnly then
            scopeTipLine = "|cFF888888List scope: account-only alt-side rewards (/acc).|r"
        elseif wantAccountAny then
            scopeTipLine = "|cFF888888List scope: account attune + all factions (/a).|r"
        else
            scopeTipLine = "|cFF888888List scope: character + account; rival faction hidden (/a or /acc).|r"
        end

        for i = 1, #quests do

            local quest = quests[i]

            if ZoneQuestMatchesQuery(quest, questQuery) then
                if quest.wrongFaction and not wantCrossFaction then
                elseif wantAccountAny and not quest.accountAttunable then
                elseif wantAccountOnly and quest.charAttunable then
                elseif wantCharOnly and not quest.charAttunable then
                elseif not wantAccountAny and not quest.charAttunable and not quest.accountAttunable then
                else

                local factionPrefix = ""
                if wantCrossFaction and quest.wrongFaction and quest.factionBadge and quest.factionBadge ~= "" then
                    factionPrefix = quest.factionBadge
                end
                local badge = ""
                local rowColor = { r = 0.86, g = 0.9, b = 1 }
                local availableNow = (quest.availableChain ~= nil and quest.availableChain) or quest.onQuest or quest.canAccept
                if quest.charAttunable then
                    rowColor = { r = 0.55, g = 1, b = 0.55 }
                elseif quest.accountAttunable then
                    badge = "[ACC] "
                    rowColor = { r = 0.55, g = 0.8, b = 1 }
                end
                if not availableNow then
                    rowColor = { r = 0.42, g = 0.42, b = 0.45 }
                end
                local dist = quest.distanceText or "--"
                local distLabel = (dist ~= "--") and (tostring(dist) .. " Yards") or "Distance unavailable"
                local mapPct = tonumber(quest.distanceMapPercent)
                local mapPctLabel = mapPct and string.format("%.2f%% map span", mapPct) or "world yards (Questie)"
                local availLabel = availableNow and "Available now" or "Not currently pickable"
                local entryId = tonumber(quest.chainEntryQuestId) or tonumber(quest.objId)
                local entryName = (Custom_GetQuestName and Custom_GetQuestName(entryId)) or ("#" .. tostring(entryId))
                local listRowQuestTitle = quest.name
                if entryId and quest.objId and entryId ~= quest.objId and entryName and entryName ~= "" then
                    listRowQuestTitle = entryName
                end
                local L = "|cFF88CCFF"
                local V = "|cFFFFFFFF"
                local G = "|cFF66EE66"
                local R = "|cFFCC7070"
                local QN = "|cFFFFD200"
                local QID = "|cFF909090"
                local DIM = "|cFF888888"
                local HDR = "|cFFFFCC66"

                local tooltipQuestLines = {}
                tinsert(tooltipQuestLines, scopeTipLine)
                tinsert(tooltipQuestLines, L .. "Starter distance:|r " .. V .. distLabel .. "|r")
                tinsert(tooltipQuestLines, L .. "Map distance:|r " .. V .. mapPctLabel .. "|r")
                local availCol = availableNow and G or R
                tinsert(tooltipQuestLines, L .. "Availability:|r " .. availCol .. availLabel .. "|r")
                tinsert(tooltipQuestLines, L .. "Available at this quest point:|r " .. QN .. entryName .. "|r " .. QID .. "(" .. tostring(entryId) .. ")|r")
                if type(quest.chainPrereqRootQuestIds) == "table" and #quest.chainPrereqRootQuestIds > 1 then
                    tinsert(tooltipQuestLines, "  " .. DIM .. "Several Questie prerequisite starts; this row picks the nearest starter.|r")
                end
                if type(quest.chainRewardQuestIds) == "table" and #quest.chainRewardQuestIds > 1 then
                    tinsert(tooltipQuestLines, HDR .. "Attunable / reward quests (merged chain line):|r")
                    for ai = 1, #quest.chainRewardQuestIds do
                        local qid = tonumber(quest.chainRewardQuestIds[ai])
                        if qid and qid > 0 then
                            local qn = (Custom_GetQuestName and Custom_GetQuestName(qid)) or ("#" .. tostring(qid))
                            tinsert(tooltipQuestLines, "  " .. QN .. qn .. "|r " .. QID .. "(" .. tostring(qid) .. ")|r")
                        end
                    end
                else
                    tinsert(tooltipQuestLines, L .. "Attunable / reward quest:|r " .. QN .. quest.name .. "|r " .. QID .. "(" .. tostring(quest.objId) .. ")|r")
                end
                if quest.chainTooltipExtra and quest.chainTooltipExtra ~= "" then
                    tinsert(tooltipQuestLines, " ")
                    for segment in string.gmatch(quest.chainTooltipExtra, "[^\n]+") do
                        tinsert(tooltipQuestLines, DIM .. segment .. "|r")
                    end
                end

                tinsert(entries, {

                    mode = self.mode,

                    typeId = quest.typeId,

                    objId = quest.objId,
                    trackQuestId = quest.trackQuestId,
                    questId = quest.objId,
                    questName = quest.name,
                    listRowQuestTitle = listRowQuestTitle,
                    distance = quest.distance,
                    x = quest.x,
                    y = quest.y,
                    zoneId = quest.zoneId,
                    starterNpcName = quest.starterNpcName,
                    chainEntryQuestId = quest.chainEntryQuestId,
                    chainSpineRootQuestId = quest.chainSpineRootQuestId,
                    chainPrereqRootQuestIds = quest.chainPrereqRootQuestIds,
                    chainRewardQuestIds = quest.chainRewardQuestIds,
                    rewardItemIds = quest.rewardItemIds,
                    rewardItemId = quest.rewardItemId,

                    label = factionPrefix .. badge .. listRowQuestTitle,

                    tooltipAttune = nil,
                    tooltipQuestLines = tooltipQuestLines,
                    tooltipDrop = nil,

                    icon = quest.rewardIcon or "Interface\\Icons\\INV_Misc_Note_01",

                    tracked = quest.tracked,

                    color = rowColor,

                })
                end

            end

        end

    end

    --[[ FEATURE CULLED zone_npc list rows (was elseif self.mode == "zone_npcs" then ... )

    elseif self.mode == "zone_npcs" then

        for i = 1, #npcs do

            local npc = npcs[i]

            if MatchQuery(npc.name, query) then

                tinsert(entries, {

                    mode = self.mode,

                    typeId = npc.typeId,

                    objId = npc.objId,

                    npcName = npc.name,

                    label = npc.name,

                    tooltipAttune = nil,

                    icon = "Interface\\Icons\\Ability_Hunter_BeastCall",

                    tracked = npc.tracked,

                    color = { r = 1, g = 0.85, b = 0.5 },

                })

            end

        end

    ]]



    return entries

end



function qtRunnerSearchMode:ActivateEntry(entry)

    if not entry then return end

    if entry.mode == "zone_items" and entry.objId then

        local zoneId = self.previewLootZoneId or qtRunnerSearchData:GetCurrentZoneId()
        local npcName = qtRunnerSearchData:PickBestNpcNameForItemInZone(entry.objId, zoneId)

        if npcName and npcName ~= "" then
            SendChatMessage(".findnpc " .. npcName, "SAY")
        elseif qtRunner and qtRunner.FastLootDbFirstSource and OpenLootDb then
            local ok = pcall(function()
                qtRunner:FastLootDbFirstSource(entry.objId)
            end)
            if not ok then
                print("qtRunner: PickBestNpcNameForItemInZone nil for itemId=" .. tostring(entry.objId))
            end
        else
            print("qtRunner: PickBestNpcNameForItemInZone nil for itemId=" .. tostring(entry.objId))
        end

    --[[ FEATURE CULLED zone_npcs activation
    elseif entry.mode == "zone_npcs" and entry.npcName then

        local bestNpc = qtRunnerSearchData:PickNearestNpc({

            {

                objId = entry.objId,

                name = entry.npcName,

                chance = 0,

                spawnedCount = 0,

                sourceIndex = 1,

            }

        })

        local npcName = bestNpc and bestNpc.name or entry.npcName

        SendChatMessage(".findnpc " .. npcName, "SAY")

    ]]
    elseif entry.mode == "zone_quests" and entry.objId then

        local questRefId = self:GetEntryTrackObjId(entry) or entry.objId
        qtRunnerSearchData:SetTomTomWaypointForQuest(questRefId, entry.x, entry.y, entry.zoneId, entry.listRowQuestTitle or entry.questName or entry.label)

        local npcName = entry.starterNpcName
        if not npcName or npcName == "" then
            local travelStarter = qtRunnerSearchData:_QuestChainTravelStarterQuestId(questRefId, entry.zoneId)
            npcName = qtRunnerSearchData:_ResolveQuestStarterNpcName(travelStarter)
        end
        if npcName and npcName ~= "" then
            SendChatMessage(".findnpc " .. npcName, "SAY")
        else
            local rewardItemId = tonumber(entry.rewardItemId)
            if (not rewardItemId or rewardItemId <= 0) and entry.rewardItemIds and entry.rewardItemIds[1] then
                rewardItemId = tonumber(entry.rewardItemIds[1])
            end
            if rewardItemId and rewardItemId > 0 and qtRunner and qtRunner.FastLootDbFirstSource then
                qtRunner:FastLootDbFirstSource(rewardItemId)
            else
                print("qtRunner: no starter NPC name for questId=" .. tostring(questRefId))
            end
        end

    end

end



function qtRunnerSearchMode:BulkTrackZoneQuests()

    local zoneId = self.previewLootZoneId or qtRunnerSearchData:GetCurrentZoneId()
    local list, info = qtRunnerSearchData:BulkTrackZoneAttunableQuests(zoneId)
    if list and info and info.source == "questie" then
        return info.added or 0, info
    end
    local quests = qtRunnerSearchData:GetZoneQuestEntries(zoneId)
    list = {}
    for i = 1, #quests do
        local qrow = quests[i]
        local tid = tonumber(qrow.trackQuestId) or tonumber(qrow.chainEntryQuestId) or tonumber(qrow.objId)
        if tid and tid > 0 then
            list[#list + 1] = tid
        end
    end
    local added = qtRunnerSearchData:TrackQuestSet(list)
    return added, {
        source = "tracker-fallback",
        added = added or 0,
        sorted = #list,
        waypoints = 0,
    }

end



function qtRunnerSearchMode:BulkTrackTrackerQuests()

    local set = qtRunnerSearchData:GetTrackerQuestIdSet()

    return qtRunnerSearchData:TrackQuestSet(set)

end



function qtRunnerSearchMode:GetEntryTrackObjId(entry)
    if not entry then
        return nil
    end
    local t = tonumber(entry.trackQuestId)
    if entry.mode == "zone_quests" and t and t > 0 then
        return t
    end
    return tonumber(entry.objId)
end

function qtRunnerSearchMode:ToggleTrackForEntry(entry)

    if not entry or entry.typeId == nil then

        return

    end
    local oid = self:GetEntryTrackObjId(entry)
    if not oid then
        return
    end

    qtRunnerSearchData:ToggleTracked(entry.typeId, oid)

end



function qtRunnerSearchMode:ClearTracked()

    qtRunnerSearchData:ClearTracked()

end

