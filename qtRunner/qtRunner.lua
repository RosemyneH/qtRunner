local CreateFrame = CreateFrame
local UIParent = UIParent
local ipairs = ipairs
local pairs = pairs
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local strgsub = string.gsub
local strlower = string.lower
local tinsert = table.insert
local tsort = table.sort
local print = print
local _G = _G
local GetSpellInfo = GetSpellInfo
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory

qtRunner = {}
qtRunner.version = "bangarang"

local defaults = {
    defaultZone = "Dalaran",
    theme = "dark",
    submitWithEnter = true,
    submitWithBacktick = true,
    useQuestie = true,
    useTomTom = true,
}

local runnerFrame = nil
local searchBox = nil
local listHost = nil
local listScrollOffset = 0
local previewIcon = nil
local selectedNameText = nil
local modeNameText = nil
local filteredZones = {}
local currentEntries = {}
local selectedIndex = 1
local lastWarpSearchCompact = ""
local lastListScrollKey = nil
local runnerPrevEntryCount = 0
local isRunnerVisible = false
local lineButtons = {}
local settingsFrame = nil
local trackToggleButton = nil
local trackClearButton = nil
local trackActionsFrame = nil
local zoneHelpButton = nil
local qtRunnerRewardsTooltip = nil

local FRAME_W = 208
local ICON_SIZE = 56
local ROW_ICON = 20
local LINE_HEIGHT = 26
local LIST_HEIGHT = 168
local NUM_VISIBLE = math_max(1, math_floor(LIST_HEIGHT / LINE_HEIGHT))

local function Trim(text)
    return strgsub(text or "", "^%s*(.-)%s*$", "%1")
end

local function TrackKey(typeId, objId)
    return tostring(typeId or -1) .. ":" .. tostring(objId or -1)
end

local function ZoneItemEntryHyperlink(entry)
    if not entry or entry.mode ~= "zone_items" or not entry.objId then
        return nil
    end
    if qtRunnerSearchData and qtRunnerSearchData.ResolveItemDisplay then
        local _, link = qtRunnerSearchData:ResolveItemDisplay(entry.objId)
        if link and link ~= "" then
            return link
        end
    end
    return nil
end

local function HideQTRunnerRewardTooltip()
    if qtRunnerRewardsTooltip and qtRunnerRewardsTooltip:IsShown() then
        qtRunnerRewardsTooltip:Hide()
    end
end

local function AddRewardItemRowToTooltip(tt, itemId)
    itemId = tonumber(itemId)
    if not itemId or itemId <= 0 or not tt then
        return
    end
    local name, link, tex
    if qtRunnerSearchData and qtRunnerSearchData.ResolveItemDisplay then
        name, link, tex = qtRunnerSearchData:ResolveItemDisplay(itemId)
    else
        if GetItemInfo then
            local n, l, _, _, _, _, _, _, _, t = GetItemInfo(itemId)
            name = n
            link = l
            tex = t
        end
        if (not tex or tex == "") and GetItemIcon then
            tex = GetItemIcon(itemId)
        end
    end
    if not tex or tex == "" then
        tex = "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    local text = (link and link ~= "") and link or (name and ("item:" .. name) or ("item:" .. tostring(itemId)))
    local icon = "|T" .. tex .. ":" .. ROW_ICON .. ":" .. ROW_ICON .. ":0:0|t "
    tt:AddLine(icon .. text, 0.9, 0.95, 1)
end

local function ShowQTRunnerRewardTooltip(entry)
    if not qtRunnerRewardsTooltip or not entry or not entry.rewardItemIds then
        return
    end
    qtRunnerRewardsTooltip:SetOwner(GameTooltip, "ANCHOR_NONE")
    qtRunnerRewardsTooltip:ClearLines()
    qtRunnerRewardsTooltip:AddLine("Attunable Rewards", 0.95, 0.85, 0.35)
    for i = 1, #entry.rewardItemIds do
        AddRewardItemRowToTooltip(qtRunnerRewardsTooltip, entry.rewardItemIds[i])
    end
    qtRunnerRewardsTooltip:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMRIGHT", 4, 0)
    qtRunnerRewardsTooltip:Show()
end

local function AppendEntryTooltipExtras(entry, skipQuestRewardsOnPrimary)
    if entry and entry.tooltipDrop then
        GameTooltip:AddLine(entry.tooltipDrop, 0.78, 0.88, 1)
    end
    if skipQuestRewardsOnPrimary and entry and entry.mode == "zone_quests" then
        return
    end
    if entry and entry.rewardItemIds and type(entry.rewardItemIds) == "table" and #entry.rewardItemIds > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Attunable Rewards", 0.95, 0.85, 0.35)
        local maxShow = 4
        for i = 1, #entry.rewardItemIds do
            if i > maxShow then
                GameTooltip:AddLine("... +" .. tostring(#entry.rewardItemIds - maxShow) .. " more", 0.7, 0.7, 0.7)
                break
            end
            AddRewardItemRowToTooltip(GameTooltip, entry.rewardItemIds[i])
        end
    end
end

local function HideCompareTooltips()
    if ShoppingTooltip1 and ShoppingTooltip1:IsShown() then
        ShoppingTooltip1:Hide()
    end
    if ShoppingTooltip2 and ShoppingTooltip2:IsShown() then
        ShoppingTooltip2:Hide()
    end
end

local function ShowRunnerEntryTooltip(owner, entry)
    if not owner or not entry then
        return
    end
    HideQTRunnerRewardTooltip()
    local zoneHyp = ZoneItemEntryHyperlink(entry)
    if entry.mode == "zone_items" then
        if zoneHyp then
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(zoneHyp)
            HideCompareTooltips()
            if entry.tooltipAttune then
                GameTooltip:AddLine(entry.tooltipAttune, 1, 1, 1)
            end
            AppendEntryTooltipExtras(entry)
            GameTooltip:Show()
        elseif entry.tooltipAttune then
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:SetText(entry.label or "", 1, 1, 1, true)
            GameTooltip:AddLine(entry.tooltipAttune, 0.92, 0.92, 1)
            AppendEntryTooltipExtras(entry)
            GameTooltip:Show()
        end
    elseif entry.mode == "zone_quests" and entry.tooltipQuestLines and type(entry.tooltipQuestLines) == "table" then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:SetText(entry.label or "", 1, 1, 1, true)
        for i = 1, #entry.tooltipQuestLines do
            GameTooltip:AddLine(entry.tooltipQuestLines[i], 1, 1, 1, true)
        end
        AppendEntryTooltipExtras(entry, true)
        GameTooltip:Show()
        if entry.rewardItemIds and type(entry.rewardItemIds) == "table" and #entry.rewardItemIds > 0 then
            ShowQTRunnerRewardTooltip(entry)
        end
    elseif entry.tooltipAttune then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:SetText(entry.label or "", 1, 1, 1, true)
        GameTooltip:AddLine(entry.tooltipAttune, 0.92, 0.92, 1)
        AppendEntryTooltipExtras(entry)
        GameTooltip:Show()
    elseif entry.itemLink then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(entry.itemLink)
        HideCompareTooltips()
        AppendEntryTooltipExtras(entry)
        GameTooltip:Show()
    end
end

function qtRunner:IsWarpSpellKnown(zoneName)
    if not zoneName or zoneName == "" then return false end
    local warpIndex = qtRunnerData.spells[zoneName]
    if not warpIndex then return false end
    if CustomHasTeleport then
        return CustomHasTeleport(warpIndex) > 0
    end
    return true
end

function qtRunner:GetDefaultZone()
    local zoneName = qtRunnerDB and qtRunnerDB.defaultZone or defaults.defaultZone
    if zoneName and qtRunnerData.spells[zoneName] then
        return zoneName
    end
    return defaults.defaultZone
end

function qtRunner:IsSubmitKeyEnabled(key)
    if key == "ENTER" or key == "NUMPADENTER" then
        local v = qtRunnerDB and qtRunnerDB.submitWithEnter
        if v == nil then
            return defaults.submitWithEnter
        end
        return v
    end
    if key == "GRAVE" or key == "`" then
        local v = qtRunnerDB and qtRunnerDB.submitWithBacktick
        if v == nil then
            return defaults.submitWithBacktick
        end
        return v
    end
    return false
end

function qtRunner:HandleSearchTextChanged(text)
    if self:IsSubmitKeyEnabled("GRAVE") and text and text:find("`", 1, true) then
        local stripped = text:gsub("`", "")
        if stripped ~= text then
            searchBox:SetText(stripped)
        end
        self:ActivateSelectedEntry({ skipToggleTrack = true })
        return true
    end
    if qtRunnerSearchMode and text then
        if qtRunnerSearchMode.mode == "zone_quests" then
            local bulkToken = nil
            local stripped = text:gsub("/%s*([%a]+)", function(w)
                local lw = strlower(w)
                if not bulkToken and (lw == "al" or lw == "all" or lw == "at") then
                    bulkToken = (lw == "at") and "at" or "al"
                    return " "
                end
                return "/" .. w
            end)
            if bulkToken then
                stripped = Trim(stripped)
                if searchBox and stripped ~= text then
                    searchBox:SetText(stripped)
                end
                local added = 0
                if bulkToken == "al" then
                    local info = nil
                    added, info = qtRunnerSearchMode:BulkTrackZoneQuests()
                    added = added or 0
                    local src = info and info.source or "unknown"
                    local sorted = info and info.sorted or 0
                    local waypoints = info and info.waypoints or 0
                    local tomtom = (info and info.tomtom) and "ready" or "missing"
                    print("[qtRunner] /al source: " .. tostring(src) .. " | tomtom: " .. tomtom .. " | sorted: " .. tostring(sorted) .. " | waypoints: " .. tostring(waypoints) .. " | tracked: " .. tostring(added))
                else
                    added = qtRunnerSearchMode:BulkTrackTrackerQuests() or 0
                    print("[qtRunner] /at source: tracker-set | tracked: " .. tostring(added))
                end
                self:HideRunner()
                return true
            end
        end
        if text:match("^%s*!%s*w%s*$") then
            qtRunnerSearchMode:ClearTracked()
            self:HideRunner()
            return true
        end
        local cmd, rest = text:match("^%s*!%s*([zxqs])%s*(.*)$")
        if cmd then
            cmd = strlower(cmd)
            if cmd == "z" then
                qtRunnerSearchMode:ClearLootZonePreview()
                qtRunnerSearchMode.previewLootZoneId = qtRunnerSearchData:GetCurrentZoneId()
                qtRunnerSearchMode.previewLootZoneName = nil
                qtRunnerSearchMode:SetMode("zone_items")
            elseif cmd == "x" then
                qtRunnerSearchMode:ClearLootZonePreview()
                qtRunnerSearchMode.previewLootZoneId = qtRunnerSearchData:GetCurrentZoneId()
                qtRunnerSearchMode.previewLootZoneName = nil
                qtRunnerSearchMode:SetMode("zone_quests")
            -- FEATURE CULLED zone NPC mode (!c): low value vs maintenance.
            -- elseif cmd == "c" then
            --     qtRunnerSearchMode:ClearLootZonePreview()
            --     qtRunnerSearchMode.previewLootZoneId = qtRunnerSearchData:GetCurrentZoneId()
            --     qtRunnerSearchMode.previewLootZoneName = nil
            --     qtRunnerSearchMode:SetMode("zone_npcs")
            elseif cmd == "q" then
                qtRunnerSearchMode:ClearLootZonePreview()
                qtRunnerSearchMode:SetMode("warp")
            elseif cmd == "s" then
                qtRunnerSearchMode:ClearLootZonePreview()
                qtRunnerSearchMode.previewLootZoneId = qtRunnerSearchData:GetCurrentZoneId()
                qtRunnerSearchMode.previewLootZoneName = nil
                qtRunnerSearchMode:SetMode("zone_items")
            end
            searchBox:SetText(Trim(rest))
            selectedIndex = 1
            lastWarpSearchCompact = ""
            self:RefreshRunnerList()
            return true
        end
    end
    return false
end

local learnedZonesCache = nil
local spellChangedFrame = nil

local function InvalidateLearnedZonesCache()
    learnedZonesCache = nil
    if qtRunnerSearchData and qtRunnerSearchData.InvalidateLootZoneCatalog then
        qtRunnerSearchData:InvalidateLootZoneCatalog()
    end
end

local function BuildLearnedZoneList()
    if not CustomHasTeleport then
        if not qtRunnerData.sortedLearnedZones then
            local list = {}
            for zoneName in pairs(qtRunnerData.spells) do
                tinsert(list, zoneName)
            end
            tsort(list)
            qtRunnerData.sortedLearnedZones = list
        end
        return qtRunnerData.sortedLearnedZones
    end
    if learnedZonesCache then
        return learnedZonesCache
    end
    local list = {}
    for zoneName in pairs(qtRunnerData.spells) do
        if qtRunner:IsWarpSpellKnown(zoneName) then
            tinsert(list, zoneName)
        end
    end
    tsort(list)
    learnedZonesCache = list
    return list
end

function qtRunner:GetLearnedZones()
    return BuildLearnedZoneList()
end

local function CmpZoneSortKey(ka, kb)
    local na, nb = #ka, #kb
    local n = math_max(na, nb)
    for i = 1, n do
        local a, b = ka[i], kb[i]
        if a == nil then
            return true
        end
        if b == nil then
            return false
        end
        if a ~= b then
            return a < b
        end
    end
    return false
end

local function GetFilteredZones(query)
    local all = BuildLearnedZoneList()
    local out = {}
    local q = query or ""
    for _, z in ipairs(all) do
        if qtRunnerData:ZoneMatchesQuery(z, q) then
            tinsert(out, z)
        end
    end
    tsort(out, function(a, b)
        return CmpZoneSortKey(qtRunnerData:ZoneSearchSortKey(a, q), qtRunnerData:ZoneSearchSortKey(b, q))
    end)
    return out
end

local function GetFilteredLootZones(query)
    local all = qtRunnerSearchData and qtRunnerSearchData.GetLootZoneCatalog and qtRunnerSearchData:GetLootZoneCatalog() or {}
    if #all == 0 then
        local fallback = BuildLearnedZoneList()
        for i = 1, #fallback do
            all[#all + 1] = { zoneName = fallback[i], zoneId = nil }
        end
    end
    local out = {}
    local q = query or ""
    for i = 1, #all do
        local row = all[i]
        local z = row and row.zoneName
        if z and qtRunnerData:ZoneMatchesQuery(z, q) then
            tinsert(out, row)
        end
    end
    tsort(out, function(a, b)
        return CmpZoneSortKey(qtRunnerData:ZoneSearchSortKey(a.zoneName, q), qtRunnerData:ZoneSearchSortKey(b.zoneName, q))
    end)
    return out
end

local function BuildWarpEntries(query, entryMode)
    entryMode = entryMode or "warp"
    local zones
    if entryMode == "zone_pick" then
        zones = GetFilteredLootZones(query)
    else
        zones = GetFilteredZones(query)
    end
    local out = {}
    for i = 1, #zones do
        local zoneRow = zones[i]
        local zoneName = zoneRow
        local zoneId = nil
        if type(zoneRow) == "table" then
            zoneName = zoneRow.zoneName
            zoneId = zoneRow.zoneId
        end
        local info = qtRunnerData:GetZoneSpellInfo(zoneName)
        tinsert(out, {
            mode = entryMode,
            zoneName = zoneName,
            zoneId = zoneId,
            label = zoneName,
            icon = (info and info.icon) or "Interface\\Icons\\Spell_Arcane_TeleportStormwind",
        })
    end
    return out
end

local function GetSelectedEntry()
    return currentEntries[selectedIndex]
end

local function UpdatePreview()
    local colors = qtRunner:GetColors()
    local entry = GetSelectedEntry()
    if modeNameText then
        if qtRunnerSearchMode then
            modeNameText:SetText(qtRunnerSearchMode:GetModeLabel())
        else
            modeNameText:SetText("Warp")
        end
        modeNameText:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b)
    end
    if entry then
        previewIcon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        selectedNameText:SetText(entry.label or "")
        if entry.color then
            selectedNameText:SetTextColor(entry.color.r or colors.text.r, entry.color.g or colors.text.g, entry.color.b or colors.text.b)
        else
            selectedNameText:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
        end
    else
        previewIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        selectedNameText:SetText("")
    end
    if zoneHelpButton and qtRunnerSearchMode then
        local hm = qtRunnerSearchMode.mode
        if hm == "zone_items" or hm == "zone_quests" or hm == "warp" or hm == "zone_pick" then
            zoneHelpButton:Show()
        else
            zoneHelpButton:Hide()
        end
    elseif zoneHelpButton then
        zoneHelpButton:Hide()
    end
end

local function UpdateScrollList()
    local colors = qtRunner:GetColors()
    local nEntries = #currentEntries
    local maxOff = math_max(0, nEntries - NUM_VISIBLE)
    if maxOff == 0 then
        listScrollOffset = 0
    end
    local offset = listScrollOffset
    if offset < 0 then
        offset = 0
    end
    if offset > maxOff then
        offset = maxOff
        listScrollOffset = offset
    end
    for i = 1, NUM_VISIBLE do
        local btn = lineButtons[i]
        local idx = i + offset
        if idx <= nEntries then
            local entry = currentEntries[idx]
            btn.rowIcon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            btn.rowIcon:SetVertexColor(1, 1, 1)
            local label = entry.label or ""
            if entry.tracked then
                label = label .. "  [Tracked]"
            end
            btn.label:SetText(label)
            if entry.color then
                btn.label:SetTextColor(entry.color.r or colors.text.r, entry.color.g or colors.text.g, entry.color.b or colors.text.b)
            else
                btn.label:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
            end
            btn.listIndex = idx
            if idx == selectedIndex then
                btn.sel:SetVertexColor(colors.sel.r, colors.sel.g, colors.sel.b, colors.sel.a)
            else
                btn.sel:SetVertexColor(0, 0, 0, 0)
            end
            btn:Show()
        else
            btn:Hide()
        end
    end
    UpdatePreview()
end

function qtRunner:RefreshRunnerList()
    local prevSel = GetSelectedEntry()
    local stickZone = prevSel and prevSel.zoneName
    local stickMode = prevSel and prevSel.mode
    local stickObjId = prevSel and prevSel.objId

    local q = searchBox and searchBox:GetText() or ""
    q = Trim(q)
    local zonePick = qtRunnerSearchMode and qtRunnerSearchMode.mode == "zone_pick"
    local inWarp = not qtRunnerSearchMode or qtRunnerSearchMode:IsWarpMode()

    if zonePick then
        currentEntries = BuildWarpEntries(q, "zone_pick")
    elseif inWarp then
        currentEntries = BuildWarpEntries(q, "warp")
    else
        currentEntries = qtRunnerSearchMode:BuildEntries(q)
    end
    filteredZones = currentEntries
    local qCompact = strgsub(q, "%s+", "")
    local nRows = #currentEntries

    local listModeKey = (qtRunnerSearchMode and qtRunnerSearchMode.mode) or "warp"
    local scrollKey = listModeKey .. "\0" .. qCompact
    if lastListScrollKey ~= scrollKey then
        lastListScrollKey = scrollKey
        listScrollOffset = 0
    end

    if nRows <= NUM_VISIBLE then
        listScrollOffset = 0
    end

    if zonePick or inWarp then
        if qCompact ~= "" then
            if lastWarpSearchCompact ~= qCompact then
                selectedIndex = 1
                lastWarpSearchCompact = qCompact
                listScrollOffset = 0
            end
        else
            lastWarpSearchCompact = ""
        end
    end

    if nRows == 1 and runnerPrevEntryCount > 1 then
        listScrollOffset = 0
    end
    runnerPrevEntryCount = nRows

    local stuck = false

    if nRows == 0 then
        selectedIndex = 1
    else
        local warpStick = (inWarp or zonePick) and qCompact == "" and stickZone and (stickMode == "warp" or stickMode == "zone_pick")
        if warpStick then
            for i = 1, nRows do
                local e = currentEntries[i]
                if e.zoneName == stickZone and e.mode == stickMode then
                    selectedIndex = i
                    stuck = true
                    break
                end
            end
        elseif not inWarp and not zonePick and stickObjId ~= nil and stickMode and stickMode ~= "warp" and stickMode ~= "zone_pick" then
            local curMode = qtRunnerSearchMode.mode
            if stickMode == curMode then
                for i = 1, nRows do
                    local e = currentEntries[i]
                    if e.objId == stickObjId and e.mode == stickMode then
                        selectedIndex = i
                        stuck = true
                        break
                    end
                end
            end
        end

        if not stuck then
            if (inWarp or zonePick) and qCompact == "" then
                local defZone = self:GetDefaultZone()
                local defIdx
                for i = 1, nRows do
                    if currentEntries[i].zoneName == defZone then
                        defIdx = i
                        break
                    end
                end
                if defIdx then
                    selectedIndex = defIdx
                elseif selectedIndex > nRows then
                    selectedIndex = math_max(1, nRows)
                end
            else
                if selectedIndex > nRows then selectedIndex = math_max(1, nRows) end
                if selectedIndex < 1 then selectedIndex = 1 end
            end
        end
    end
    local maxOff = math_max(0, nRows - NUM_VISIBLE)
    local curOff = listScrollOffset
    local off
    if maxOff <= 0 then
        off = 0
    else
        off = math_min(math_max(0, curOff), maxOff)
        off = math_min(math_max(off, selectedIndex - NUM_VISIBLE), maxOff)
    end
    listScrollOffset = off
    if trackToggleButton and trackClearButton and qtRunnerSearchMode then
        local showActions = not qtRunnerSearchMode:IsWarpMode() and qtRunnerSearchMode.mode ~= "zone_pick"
        if showActions then
            trackActionsFrame:Show()
            runnerFrame.dropBg:ClearAllPoints()
            runnerFrame.dropBg:SetPoint("TOP", trackActionsFrame, "BOTTOM", 0, -4)
        else
            trackActionsFrame:Hide()
            runnerFrame.dropBg:ClearAllPoints()
            runnerFrame.dropBg:SetPoint("TOP", runnerFrame.searchBg, "BOTTOM", 0, -4)
        end
    end
    UpdateScrollList()
end

function qtRunner:HandleControlCommand(key)
    if not IsControlKeyDown() or not qtRunnerSearchMode then
        return false
    end
    if key == "Z" then
        qtRunnerSearchMode:ClearLootZonePreview()
        qtRunnerSearchMode.previewLootZoneId = qtRunnerSearchData:GetCurrentZoneId()
        qtRunnerSearchMode.previewLootZoneName = nil
        qtRunnerSearchMode:SetMode("zone_items")
    elseif key == "X" then
        qtRunnerSearchMode:ClearLootZonePreview()
        qtRunnerSearchMode.previewLootZoneId = qtRunnerSearchData:GetCurrentZoneId()
        qtRunnerSearchMode.previewLootZoneName = nil
        qtRunnerSearchMode:SetMode("zone_quests")
    -- FEATURE CULLED zone NPC mode (Ctrl+C).
    -- elseif key == "C" then
    --     qtRunnerSearchMode:ClearLootZonePreview()
    --     qtRunnerSearchMode.previewLootZoneId = qtRunnerSearchData:GetCurrentZoneId()
    --     qtRunnerSearchMode.previewLootZoneName = nil
    --     qtRunnerSearchMode:SetMode("zone_npcs")
    elseif key == "Q" then
        qtRunnerSearchMode:ClearLootZonePreview()
        qtRunnerSearchMode:SetMode("warp")
    elseif key == "T" then
        self:ToggleTrackSelected()
        return true
    elseif key == "R" then
        self:ClearTrackedObjects()
        return true
    else
        return false
    end
    if searchBox and searchBox:HasFocus() then
        searchBox:ClearFocus()
    end
    selectedIndex = 1
    self:RefreshRunnerList()
    return true
end

local function TeleportToZone(zoneName)
    if not zoneName or zoneName == "" then return end
    if not qtRunner:IsWarpSpellKnown(zoneName) then
        print("Warp to " .. zoneName .. " is not learned!")
        return
    end
    if CustomTeleportName then
        CustomTeleportName(zoneName)
    end
end

function qtRunner:ActivateSelectedEntry(submitOpts)
    local entry = GetSelectedEntry()
    if not entry then
        return
    end
    if entry.mode == "zone_pick" then
        local zid = qtRunnerSearchData:GetCurrentZoneId()
        qtRunnerSearchMode.previewLootZoneId = zid
        qtRunnerSearchMode.previewLootZoneName = entry.zoneName
        qtRunnerSearchMode:SetMode("zone_items")
        qtRunnerSearchMode:MarkDirty()
        if searchBox then
            searchBox:SetText("")
        end
        selectedIndex = 1
        lastWarpSearchCompact = ""
        self:RefreshRunnerList()
        return
    end
    if entry.mode == "warp" then
        TeleportToZone(entry.zoneName)
        self:HideRunner()
    else
        qtRunnerSearchMode:ActivateEntry(entry)
        if submitOpts and submitOpts.skipToggleTrack then
            local tid = entry.typeId
            local oid = qtRunnerSearchMode:GetEntryTrackObjId(entry)
            if tid ~= nil and oid then
                local tracked = qtRunnerSearchData:GetTrackedLookup()
                if not qtRunnerSearchData:IsTracked(tracked, tid, oid) then
                    qtRunnerSearchMode:ToggleTrackForEntry(entry)
                end
            end
        else
            qtRunnerSearchMode:ToggleTrackForEntry(entry)
        end
        self:HideRunner()
    end
end

function qtRunner:WarpSelected()
    if qtRunnerSearchMode and qtRunnerSearchMode.mode == "zone_pick" then
        self:ActivateSelectedEntry()
        return
    end
    if qtRunnerSearchMode and not qtRunnerSearchMode:IsWarpMode() then
        return
    end
    self:ActivateSelectedEntry()
end

function qtRunner:ToggleTrackSelected()
    if not qtRunnerSearchMode or qtRunnerSearchMode:IsWarpMode() then
        return
    end
    local entry = GetSelectedEntry()
    if not entry then
        return
    end
    qtRunnerSearchMode:ToggleTrackForEntry(entry)
    self:RefreshRunnerList()
end

function qtRunner:TrackSearchResults()
    if not qtRunnerSearchMode or qtRunnerSearchMode:IsWarpMode() then
        return
    end
    local tracked = qtRunnerSearchData:GetTrackedLookup()
    local seen = {}
    local rows = {}
    for i = 1, #currentEntries do
        local entry = currentEntries[i]
        local trackOid = qtRunnerSearchMode:GetEntryTrackObjId(entry)
        if entry and entry.typeId ~= nil and trackOid then
            local key = TrackKey(entry.typeId, trackOid)
            if not seen[key] then
                seen[key] = true
                rows[#rows + 1] = entry
            end
        end
    end
    if #rows == 0 then
        return
    end
    for i = 1, #rows do
        local entry = rows[i]
        local trackOid = qtRunnerSearchMode:GetEntryTrackObjId(entry)
        local key = TrackKey(entry.typeId, trackOid)
        local isTracked = qtRunnerSearchData:IsTracked(tracked, entry.typeId, trackOid)
        if not isTracked then
            qtRunnerSearchData:ToggleTracked(entry.typeId, trackOid, tracked)
            tracked[key] = true
        end
    end
    self:RefreshRunnerList()
    if qtRunnerSearchMode.mode == "zone_quests" then
        local bestEntry, bestDist = nil, math.huge
        for j = 1, #rows do
            local e = rows[j]
            if e.mode == "zone_quests" then
                local d = tonumber(e.distance)
                if not d or d ~= d then
                    d = 999999999
                end
                if d < bestDist then
                    bestDist = d
                    bestEntry = e
                end
            end
        end
        if bestEntry then
            qtRunnerSearchMode:ActivateEntry(bestEntry)
        end
        self:HideRunner()
    end
end

function qtRunner:ClearTrackedObjects()
    if not qtRunnerSearchMode or qtRunnerSearchMode:IsWarpMode() then
        return
    end
    qtRunnerSearchMode:ClearTracked()
    self:RefreshRunnerList()
end

function qtRunner:OpenLootDbForEntry(entry)
    if not entry or entry.mode ~= "zone_items" or not entry.objId then
        return false
    end
    if not OpenLootDb then
        return false
    end
    local ok = pcall(OpenLootDb, entry.objId)
    if not ok then
        return false
    end
    local frame = _G.LootDBFrame
    if frame and frame.ClearAllPoints and frame.SetPoint then
        frame:ClearAllPoints()
        frame:SetPoint("LEFT", runnerFrame, "RIGHT", 12, 0)
        local right = frame.GetRight and frame:GetRight() or nil
        if right and GetScreenWidth and right > (GetScreenWidth() - 12) then
            frame:ClearAllPoints()
            frame:SetPoint("RIGHT", runnerFrame, "LEFT", -12, 0)
        end
    end
    return true
end

function qtRunner:FastLootDbFirstSource(itemID)
    OpenLootDb(itemID)
    _G["LootDBFrame-SLine-1"]:Click()
    LootDBFrame:Hide()
end

function qtRunner:CloseLootDbWindow()
    if not CloseLootDb then
        return
    end
    pcall(CloseLootDb)
end

local function QtRunnerShowModeHelpTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.ClearLines then
        GameTooltip:ClearLines()
    end
    local sm = qtRunnerSearchMode
    if not sm then
        GameTooltip:SetText("qtRunner", 1, 1, 1)
        GameTooltip:Show()
        return
    end
    local m = sm.mode
    if m == "warp" or m == "zone_pick" then
        GameTooltip:SetText("|cFFFFD200qtRunner — Warp|r", 1, 1, 1)
        GameTooltip:AddLine("|cFF888888Search box — mode switches|r", 0.75, 0.8, 0.88)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!z|r", "Zone items (current area)", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!x|r", "Zone quests", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!q|r", "Warp list (this screen)", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!s|r", "Zone items (same as !z)", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddDoubleLine("|cFFFFFFFF!w|r", "Clear all tracked & close", 0.9, 0.92, 1, 0.65, 0.7, 0.78)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFF666666Type to filter zone names.|r", 0.55, 0.58, 0.62)
        GameTooltip:Show()
        return
    end
    if m == "zone_quests" then
        GameTooltip:SetText("|cFFFFD200qtRunner — Zone Quests|r", 1, 1, 1)
        GameTooltip:AddLine("|cFF888888Switch modes (search box)|r", 0.75, 0.8, 0.88)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!q|r", "Warp", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!z|r", "Zone items", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!x|r", "Zone quests (refresh)", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!s|r", "Zone items (same as !z)", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFF888888Quest filters (in search text)|r", 0.75, 0.8, 0.88)
        GameTooltip:AddLine("  |cFFAAAAAADefault:|r character + account; rival faction hidden (use /a or /acc).", 0.72, 0.76, 0.82)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/a|r", "Account attune + all factions (incl. rival tags)", 1, 1, 1, 0.72, 0.8, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/acc|r", "Account-only list + [A]/[H] tags", 1, 1, 1, 0.72, 0.8, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/c|r", "This character only (hide account-only rows)", 1, 1, 1, 0.72, 0.8, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/al|r |cFF888888·|r |cFFFFFFFF/all|r", "Bulk track zone quests (+ TomTom if set)", 1, 1, 1, 0.72, 0.8, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/at|r", "Bulk track tracker quest set", 1, 1, 1, 0.72, 0.8, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddDoubleLine("|cFFFFFFFF!w|r", "Clear all tracked & close", 0.9, 0.92, 1, 0.65, 0.7, 0.78)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFF666666Combine name text with tokens — e.g. ice /a, ring /c, chain /acc|r", 0.55, 0.58, 0.62)
        GameTooltip:Show()
        return
    end
    if m == "zone_items" then
        GameTooltip:SetText("|cFFFFD200qtRunner — Zone Items|r", 1, 1, 1)
        GameTooltip:AddLine("|cFF888888Mode switches|r", 0.75, 0.8, 0.88)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!q|r", "Warp", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!x|r", "Zone quests", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF!z|r / |cFFFFFFFF!s|r", "Zone items", 1, 1, 1, 0.72, 0.82, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFF66CCFFForged|r", 0.4, 0.8, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/tf|r", "Titanforged", 0.9, 0.95, 1, 0.75, 0.85, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/wf|r", "Warforged", 0.9, 0.95, 1, 0.75, 0.85, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/lf|r", "Lightforged", 0.9, 0.95, 1, 0.75, 0.85, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFFFFAA66Boss|r", 1, 0.67, 0.4)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/b|r", "Boss + char attunable", 1, 0.93, 0.85, 0.9, 0.78, 0.68)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/ba|r", "Boss + account-side", 1, 0.93, 0.85, 0.9, 0.78, 0.68)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFF88DD88Vendor|r", 0.55, 0.9, 0.55)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/v|r", "Vendor + char attunable", 0.9, 1, 0.9, 0.72, 0.9, 0.72)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/va|r", "Vendor + char attunable", 0.9, 1, 0.9, 0.72, 0.9, 0.72)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/vb|r", "Vendor + BOE", 0.9, 1, 0.9, 0.72, 0.9, 0.72)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/vab|r", "Vendor + account BOE", 0.9, 1, 0.9, 0.72, 0.9, 0.72)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFFB48CFFSource / attune|r", 0.7, 0.55, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/a|r |cFF888888·|r |cFFFFFFFF/acc|r", "Account attune filters", 0.92, 0.88, 1, 0.82, 0.75, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/ab|r", "Account attunable BOE", 0.92, 0.88, 1, 0.82, 0.75, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/u|r", "Unique drops (char attunable)", 0.92, 0.88, 1, 0.82, 0.75, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/ub|r", "Char uniques + account BOE", 0.92, 0.88, 1, 0.82, 0.75, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/t|r", "Trash drops", 0.92, 0.88, 1, 0.82, 0.75, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/c|r", "Craft + char attunable", 0.92, 0.88, 1, 0.82, 0.75, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/ca|r", "Craft + account-side", 0.92, 0.88, 1, 0.82, 0.75, 1)
        GameTooltip:AddDoubleLine("  |cFFFFFFFF/q|r", "Quest sources", 0.92, 0.88, 1, 0.82, 0.75, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFF666666Combine text + token — e.g. ring /b|r", 0.55, 0.58, 0.62)
        GameTooltip:Show()
        return
    end
    GameTooltip:SetText("qtRunner", 1, 1, 1)
    GameTooltip:Show()
end

local function CreateRunnerFrame()
    runnerFrame = CreateFrame("Frame", "qtRunnerPanel", UIParent)
    runnerFrame:SetFrameStrata("DIALOG")
    runnerFrame:SetFrameLevel(100)
    runnerFrame:SetSize(FRAME_W, ICON_SIZE + 112 + LIST_HEIGHT + 8)
    runnerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 36)
    runnerFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    runnerFrame:SetBackdropColor(0.02, 0.02, 0.04, 0.92)
    runnerFrame:SetBackdropBorderColor(0.2, 0.28, 0.38, 0.45)
    runnerFrame:Hide()
    runnerFrame:EnableKeyboard(true)

    qtRunnerRewardsTooltip = CreateFrame("GameTooltip", "qtRunnerRewardsTooltip", UIParent, "GameTooltipTemplate")
    qtRunnerRewardsTooltip:SetFrameStrata("TOOLTIP")
    qtRunnerRewardsTooltip:Hide()

    zoneHelpButton = CreateFrame("Button", nil, runnerFrame)
    zoneHelpButton:SetSize(18, 18)
    zoneHelpButton:SetPoint("TOPLEFT", runnerFrame, "TOPRIGHT", 4, -2)
    zoneHelpButton:EnableMouse(true)
    zoneHelpButton:Hide()
    zoneHelpButton.text = zoneHelpButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneHelpButton.text:SetPoint("CENTER", zoneHelpButton, "CENTER", 0, 0)
    zoneHelpButton.text:SetText("?")
    zoneHelpButton:SetScript("OnEnter", function(self)
        QtRunnerShowModeHelpTooltip(self)
    end)
    zoneHelpButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    previewIcon = runnerFrame:CreateTexture(nil, "ARTWORK")
    previewIcon:SetSize(ICON_SIZE, ICON_SIZE)
    previewIcon:SetPoint("TOP", 0, -8)
    previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local previewHitBtn = CreateFrame("Button", "qtRunnerPanelIconPreview", runnerFrame)
    previewHitBtn:SetSize(ICON_SIZE, ICON_SIZE)
    previewHitBtn:SetPoint("CENTER", previewIcon, "CENTER", 0, 0)
    previewHitBtn:SetAlpha(0)
    previewHitBtn:EnableMouse(true)
    previewHitBtn:SetScript("OnClick", function(_, button)
        if button ~= "LeftButton" then return end
        if IsAltKeyDown and IsAltKeyDown() then
            local entry = GetSelectedEntry()
            if entry then
                qtRunner:OpenLootDbForEntry(entry)
            end
        end
    end)
    previewHitBtn:SetScript("OnEnter", function()
        local entry = GetSelectedEntry()
        if not entry then return end
        ShowRunnerEntryTooltip(previewHitBtn, entry)
    end)
    previewHitBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        HideQTRunnerRewardTooltip()
    end)

    selectedNameText = runnerFrame:CreateFontString(nil, "OVERLAY", "QuestFont_Large")
    selectedNameText:SetPoint("TOP", previewIcon, "BOTTOM", 0, -4)
    selectedNameText:SetWidth(FRAME_W - 16)
    selectedNameText:SetJustifyH("CENTER")
    selectedNameText:SetText("")

    modeNameText = runnerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeNameText:SetPoint("TOP", selectedNameText, "BOTTOM", 0, -2)
    modeNameText:SetWidth(FRAME_W - 16)
    modeNameText:SetJustifyH("CENTER")
    modeNameText:SetText("Warp")

    local searchBg = CreateFrame("Frame", nil, runnerFrame)
    searchBg:SetSize(FRAME_W - 20, 26)
    searchBg:SetPoint("TOP", modeNameText, "BOTTOM", 0, -6)
    searchBg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 6,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    searchBg:SetBackdropColor(0, 0, 0, 0.55)
    searchBg:SetBackdropBorderColor(0.35, 0.4, 0.5, 0.2)
    runnerFrame.searchBg = searchBg

    searchBox = CreateFrame("EditBox", "qtRunnerPanelSearch", runnerFrame)
    searchBox:SetFontObject("GameFontHighlightLarge")
    searchBox:SetSize(FRAME_W - 36, 24)
    searchBox:SetPoint("CENTER", searchBg, "CENTER", 0, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(10, 10, 0, 0)
    searchBox:SetScript("OnTextChanged", function(self)
        if qtRunner:HandleSearchTextChanged(self:GetText()) then
            return
        end
        qtRunner:RefreshRunnerList()
    end)
    searchBox:SetScript("OnEscapePressed", function()
        qtRunner:HideRunner()
    end)
    searchBox:SetScript("OnEnterPressed", function()
        if qtRunner:IsSubmitKeyEnabled("ENTER") then
            qtRunner:ActivateSelectedEntry({ skipToggleTrack = true })
        end
    end)
    -- ʕ •ᴥ•ʔ Do not SetScript(OnKeyDown) on EditBox — breaks Enter / submit on some clients ✿

    trackActionsFrame = CreateFrame("Frame", nil, runnerFrame)
    trackActionsFrame:SetSize(FRAME_W - 20, 20)
    trackActionsFrame:SetPoint("TOPLEFT", searchBg, "BOTTOMLEFT", 0, -4)
    trackActionsFrame:Hide()

    trackToggleButton = CreateFrame("Button", nil, trackActionsFrame)
    trackToggleButton:SetSize((FRAME_W - 24) / 2, 20)
    trackToggleButton:SetPoint("TOPLEFT", trackActionsFrame, "TOPLEFT", 0, 0)
    trackToggleButton:SetNormalFontObject("GameFontNormalSmall")
    trackToggleButton:SetText("Track All")
    trackToggleButton:SetScript("OnClick", function()
        qtRunner:TrackSearchResults()
    end)
    trackClearButton = CreateFrame("Button", nil, trackActionsFrame)
    trackClearButton:SetSize((FRAME_W - 24) / 2, 20)
    trackClearButton:SetPoint("LEFT", trackToggleButton, "RIGHT", 4, 0)
    trackClearButton:SetNormalFontObject("GameFontNormalSmall")
    trackClearButton:SetText("Clear Tracked")
    trackClearButton:SetScript("OnClick", function()
        qtRunner:ClearTrackedObjects()
    end)
    local dropBg = CreateFrame("Frame", nil, runnerFrame)
    dropBg:SetSize(FRAME_W - 12, LIST_HEIGHT + 4)
    dropBg:SetPoint("TOP", searchBg, "BOTTOM", 0, -4)
    dropBg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 6,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dropBg:SetBackdropColor(0, 0, 0, 0.5)
    dropBg:SetBackdropBorderColor(0.3, 0.35, 0.45, 0.18)
    runnerFrame.dropBg = dropBg

    listHost = CreateFrame("Frame", nil, dropBg)
    listHost:SetPoint("TOPLEFT", dropBg, "TOPLEFT", 4, -3)
    listHost:SetSize(FRAME_W - 22, LIST_HEIGHT)
    listHost:SetFrameLevel(dropBg:GetFrameLevel() + 2)
    listHost:EnableMouse(true)
    listHost:EnableMouseWheel(true)
    listHost:SetScript("OnMouseWheel", function(_, delta)
        local nEntries = #currentEntries
        local maxOff = math_max(0, nEntries - NUM_VISIBLE)
        if maxOff <= 0 then
            return
        end
        if delta > 0 then
            listScrollOffset = math_max(0, listScrollOffset - 1)
        else
            listScrollOffset = math_min(maxOff, listScrollOffset + 1)
        end
        UpdateScrollList()
    end)

    for i = 1, NUM_VISIBLE do
        local btn = CreateFrame("Button", "qtRunnerPanelLine" .. i, listHost)
        btn:SetHeight(LINE_HEIGHT)
        btn:SetPoint("TOPLEFT", listHost, "TOPLEFT", 0, -(i - 1) * LINE_HEIGHT)
        btn:SetPoint("TOPRIGHT", listHost, "TOPRIGHT", -2, -(i - 1) * LINE_HEIGHT)
        local sel = btn:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints(btn)
        btn.sel = sel
        local hi = btn:CreateTexture(nil, "HIGHLIGHT")
        hi:SetAllPoints(btn)
        hi:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hi:SetBlendMode("ADD")
        hi:SetVertexColor(0.4, 0.65, 0.95, 0.22)
        btn.hi = hi
        local rowIcon = btn:CreateTexture(nil, "ARTWORK")
        rowIcon:SetSize(ROW_ICON, ROW_ICON)
        rowIcon:SetPoint("LEFT", 4, 0)
        rowIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.rowIcon = rowIcon
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", rowIcon, "RIGHT", 6, 0)
        label:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
        label:SetJustifyH("CENTER")
        btn.label = label
        btn:SetScript("OnClick", function(self)
            if self.listIndex then
                selectedIndex = self.listIndex
                UpdateScrollList()
                if IsAltKeyDown and IsAltKeyDown() then
                    local entry = currentEntries[self.listIndex]
                    qtRunner:OpenLootDbForEntry(entry)
                    return
                end
            end
        end)
        btn:SetScript("OnDoubleClick", function()
            qtRunner:ActivateSelectedEntry()
        end)
        btn:SetScript("OnEnter", function(self)
            local idx = self.listIndex
            local entry = idx and currentEntries[idx]
            if not entry then return end
            ShowRunnerEntryTooltip(self, entry)
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
            HideQTRunnerRewardTooltip()
        end)
        lineButtons[i] = btn
    end

    runnerFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            qtRunner:HideRunner()
        elseif key == "UP" then
            if selectedIndex > 1 then
                selectedIndex = selectedIndex - 1
                local off = listScrollOffset
                if selectedIndex <= off then
                    listScrollOffset = selectedIndex - 1
                end
                UpdateScrollList()
            end
        elseif key == "DOWN" then
            if selectedIndex < #currentEntries then
                selectedIndex = selectedIndex + 1
                local off = listScrollOffset
                if selectedIndex > off + NUM_VISIBLE then
                    listScrollOffset = selectedIndex - NUM_VISIBLE
                end
                UpdateScrollList()
            end
        elseif qtRunner:HandleControlCommand(key) then
            return
        elseif ((key == "ENTER" or key == "NUMPADENTER") and qtRunner:IsSubmitKeyEnabled("ENTER"))
            or (key == "GRAVE" and qtRunner:IsSubmitKeyEnabled("GRAVE")) then
            if searchBox:HasFocus() then
                return
            end
            qtRunner:ActivateSelectedEntry()
        end
    end)

    runnerFrame:SetScript("OnShow", function(self)
        selectedIndex = 1
        if qtRunnerSearchMode then
            qtRunnerSearchMode:SetMode("warp")
            qtRunnerSearchMode:ClearLootZonePreview()
        end
        searchBox:SetText("")
        lastWarpSearchCompact = ""
        lastListScrollKey = nil
        listScrollOffset = 0
        runnerPrevEntryCount = 0
        qtRunner:RefreshRunnerList()
        searchBox:ClearFocus()
        self:SetScript("OnUpdate", function(f)
            f:SetScript("OnUpdate", nil)
            if searchBox and f:IsShown() then
                searchBox:SetFocus()
            end
        end)
    end)
    runnerFrame:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
    end)
end

function qtRunner:_ApplyRunnerPanelColors(colors)
    if not colors or not runnerFrame then
        return
    end
    runnerFrame:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, colors.panel.a)
    runnerFrame:SetBackdropBorderColor(colors.border.r, colors.border.g, colors.border.b, colors.border.a)
    if runnerFrame.searchBg then
        runnerFrame.searchBg:SetBackdropColor(colors.panelInset.r, colors.panelInset.g, colors.panelInset.b, colors.panelInset.a)
        runnerFrame.searchBg:SetBackdropBorderColor(colors.borderSoft.r, colors.borderSoft.g, colors.borderSoft.b, colors.borderSoft.a)
    end
    if runnerFrame.dropBg then
        runnerFrame.dropBg:SetBackdropColor(colors.panelInset.r, colors.panelInset.g, colors.panelInset.b, 0.5 + (colors.panelInset.a * 0.15))
        runnerFrame.dropBg:SetBackdropBorderColor(colors.listBorder.r, colors.listBorder.g, colors.listBorder.b, colors.listBorder.a)
    end
    if searchBox then
        searchBox:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b)
    end
    if selectedNameText then
        selectedNameText:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
    end
    for _, btn in ipairs(lineButtons) do
        if btn and btn.hi then
            btn.hi:SetVertexColor(colors.hi.r, colors.hi.g, colors.hi.b, colors.hi.a)
        end
        if btn and btn.label then
            btn.label:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
        end
    end
end

function qtRunner:_RunnerFrameIsVisible()
    return runnerFrame and runnerFrame:IsShown()
end

local function EnsureRunnerFrame()
    if runnerFrame then
        return
    end
    CreateRunnerFrame()
    if qtRunner.ApplyTheme then
        qtRunner:ApplyTheme()
    end
end

function qtRunner:ShowRunner()
    EnsureRunnerFrame()
    runnerFrame:Show()
    isRunnerVisible = true
end

function qtRunner:HideRunner()
    self:CloseLootDbWindow()
    HideQTRunnerRewardTooltip()
    if runnerFrame then
        runnerFrame:SetScript("OnUpdate", nil)
        runnerFrame:Hide()
    end
    isRunnerVisible = false
end

function qtRunner:ToggleRunner()
    if isRunnerVisible then
        self:HideRunner()
    else
        self:ShowRunner()
    end
end

function qtRunner:Initialize()
    if not qtRunnerDB then
        qtRunnerDB = {}
    end
    for k, v in pairs(defaults) do
        if qtRunnerDB[k] == nil then
            qtRunnerDB[k] = v
        end
    end
    if not qtRunnerDB.aliases then
        qtRunnerDB.aliases = qtRunnerData:GetDefaultAliases()
    end
    qtRunnerData:SetAliases(qtRunnerDB.aliases)
    CreateRunnerFrame()
    if qtRunnerSearchMode then
        qtRunnerSearchMode:InstallTrackerHook(function()
            if runnerFrame and runnerFrame:IsShown() then
                qtRunner:RefreshRunnerList()
            end
        end)
    end
    self:SetupKeybind()
    self:CreateSettingsPanel()
    if not spellChangedFrame then
        spellChangedFrame = CreateFrame("Frame")
        spellChangedFrame:RegisterEvent("SPELLS_CHANGED")
        spellChangedFrame:SetScript("OnEvent", function()
            if CustomHasTeleport then
                InvalidateLearnedZonesCache()
                if runnerFrame and runnerFrame:IsShown() then
                    qtRunner:RefreshRunnerList()
                end
            end
        end)
    end
    if self.ApplyTheme then
        self:ApplyTheme()
    end
    print("qtRunner loaded. Toggle with ` by default, or use /qtr.")
end

function qtRunner:SetupKeybind()
    BINDING_HEADER_QTRUNNER = "qtRunner"
    BINDING_NAME_QTRUNNERTOGGLE = "Toggle qtRunner"

    SLASH_QTRUNNER1 = "/qtr"
    SLASH_QTRUNNER2 = "/qtrunner"
    SlashCmdList["QTRUNNER"] = function(msg)
        msg = strlower(msg or "")
        if msg == "show" then
            qtRunner:ShowRunner()
        elseif msg == "hide" then
            qtRunner:HideRunner()
        elseif msg == "config" then
            qtRunner:ShowSettings()
        elseif msg == "panel" then
            InterfaceOptionsFrame_OpenToCategory("qtRunner")
        elseif msg == "gendata" then
            local spellList = {}
            for i = 0, 71 do
                local spellID = 80567 + i
                local spellName = GetSpellInfo(spellID)
                if spellName then
                    tinsert(spellList, { name = spellName, id = i })
                end
            end
            tsort(spellList, function(a, b) return a.id < b.id end)
            local outputString = "qtRunnerData.spells = {\n"
            for _, data in ipairs(spellList) do
                outputString = outputString .. "    [\"" .. data.name .. "\"] = " .. data.id .. ",\n"
            end
            outputString = outputString .. "}"
            print(outputString)
        elseif msg == "" then
            qtRunner:ToggleRunner()
        else
            print("qtRunner: /qtr | /qtr show | /qtr hide | /qtr config | /qtr panel | /qtr gendata")
        end
    end
end

function qtRunner_Toggle()
    qtRunner:ToggleRunner()
end

function qtRunner:CreateSettingsPanel()
    settingsFrame = CreateFrame("Frame", "qtRunnerSettings", InterfaceOptionsFramePanelContainer)
    settingsFrame.name = "qtRunner"
    settingsFrame:SetScript("OnShow", function(self)
        self:SetPoint("TOPLEFT", 0, -20)
    end)
    local title = settingsFrame:CreateFontString("qtRunnerTitle", "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -20)
    title:SetText("qtRunner")
    local info = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    info:SetPoint("TOPLEFT", 20, -55)
    info:SetWidth(520)
    info:SetText("Open the dedicated qtRunner settings window for defaults, alias editing, submit-key toggles, and theme switching.")
    info:SetTextColor(0.75, 0.75, 0.8)
    local instructions = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    instructions:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -22)
    instructions:SetText("Type /qtr config")
    instructions:SetTextColor(0.95, 0.82, 0.45)
    local subtext = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    subtext:SetPoint("TOPLEFT", instructions, "BOTTOMLEFT", 0, -12)
    subtext:SetText("Use /qtr panel to come back to this Blizzard options page.")
    subtext:SetTextColor(0.6, 0.6, 0.65)
    local bindingHint = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    bindingHint:SetPoint("TOPLEFT", subtext, "BOTTOMLEFT", 0, -12)
    bindingHint:SetText("Toggle default binding: `")
    bindingHint:SetTextColor(0.6, 0.6, 0.65)
    InterfaceOptions_AddCategory(settingsFrame)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and (addonName == "qtRunner" or addonName == "WarpRing") then
        qtRunner:Initialize()
    end
end)
