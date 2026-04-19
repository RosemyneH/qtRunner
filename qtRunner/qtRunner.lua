local CreateFrame = CreateFrame
local UIParent = UIParent
local ipairs = ipairs
local pairs = pairs
local math_max = math.max
local math_min = math.min
local strgsub = string.gsub
local strlower = string.lower
local tinsert = table.insert
local tsort = table.sort
local print = print
local _G = _G
local GetSpellInfo = GetSpellInfo
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local band = bit.band

qtRunner = {}
qtRunner.version = "banana"

local defaults = {
    defaultZone = "Dalaran",
    theme = "dark",
    submitWithEnter = true,
    submitWithBacktick = true,
}

local runnerFrame = nil
local searchBox = nil
local scrollFrame = nil
local previewIcon = nil
local selectedNameText = nil
local filteredZones = {}
local selectedIndex = 1
local isRunnerVisible = false
local lineButtons = {}
local settingsFrame = nil

local FRAME_W = 208
local ICON_SIZE = 56
local ROW_ICON = 18
local LINE_HEIGHT = 24
local LIST_HEIGHT = 168
local NUM_VISIBLE = LIST_HEIGHT / LINE_HEIGHT

local function Trim(text)
    return strgsub(text or "", "^%s*(.-)%s*$", "%1")
end

function qtRunner:IsWarpSpellKnown(zoneName)
    if not zoneName or zoneName == "" then return false end
    local warpIndex = qtRunnerData.spells[zoneName]
    if not warpIndex then return false end
    if CustomHasTeleport then
        return CustomHasTeleport(band(warpIndex, 0x7F)) > 0
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
    if key == "ENTER" then
        return qtRunnerDB and qtRunnerDB.submitWithEnter
    end
    if key == "GRAVE" or key == "`" then
        return qtRunnerDB and qtRunnerDB.submitWithBacktick
    end
    return false
end

function qtRunner:HandleSearchTextChanged(text)
    if self:IsSubmitKeyEnabled("GRAVE") and text and text:find("`", 1, true) then
        local stripped = text:gsub("`", "")
        if stripped ~= text then
            searchBox:SetText(stripped)
        end
        self:WarpSelected()
        return true
    end
    return false
end

local learnedZonesCache = nil
local spellChangedFrame = nil

local function InvalidateLearnedZonesCache()
    learnedZonesCache = nil
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

local function GetFilteredZones(query)
    local all = BuildLearnedZoneList()
    local out = {}
    local exact = query and qtRunnerData:ResolveZoneCanonical(query)
    if exact and qtRunner:IsWarpSpellKnown(exact) then
        tinsert(out, exact)
        local seen = { [exact] = true }
        for _, z in ipairs(all) do
            if not seen[z] and qtRunnerData:ZoneMatchesQuery(z, query) then
                tinsert(out, z)
                seen[z] = true
            end
        end
        return out
    end
    for _, z in ipairs(all) do
        if qtRunnerData:ZoneMatchesQuery(z, query or "") then
            tinsert(out, z)
        end
    end
    return out
end

local function UpdatePreview()
    local colors = qtRunner:GetColors()
    local z = filteredZones[selectedIndex]
    if z then
        local info = qtRunnerData:GetZoneSpellInfo(z)
        if info and info.icon then
            previewIcon:SetTexture(info.icon)
        else
            previewIcon:SetTexture("Interface\\Icons\\Spell_Arcane_TeleportStormwind")
        end
        selectedNameText:SetText(z)
        selectedNameText:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
    else
        previewIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        selectedNameText:SetText("")
    end
end

local function UpdateScrollList()
    local colors = qtRunner:GetColors()
    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    for i = 1, NUM_VISIBLE do
        local btn = lineButtons[i]
        local idx = i + offset
        if idx <= #filteredZones then
            local zoneName = filteredZones[idx]
            local info = qtRunnerData:GetZoneSpellInfo(zoneName)
            if info and info.icon then
                btn.rowIcon:SetTexture(info.icon)
            else
                btn.rowIcon:SetTexture("Interface\\Icons\\Spell_Arcane_TeleportStormwind")
            end
            btn.rowIcon:SetVertexColor(1, 1, 1)
            btn.label:SetText(zoneName)
            btn.label:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
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
    FauxScrollFrame_Update(scrollFrame, #filteredZones, NUM_VISIBLE, LINE_HEIGHT)
    UpdatePreview()
end

function qtRunner:RefreshRunnerList()
    local q = searchBox and searchBox:GetText() or ""
    q = Trim(q)
    filteredZones = GetFilteredZones(q)
    local qCompact = strgsub(q, "%s+", "")
    local nZones = #filteredZones
    if qCompact == "" then
        local defIdx = nil
        for i, z in ipairs(filteredZones) do
            if z == self:GetDefaultZone() then
                defIdx = i
                break
            end
        end
        if defIdx then
            selectedIndex = defIdx
        else
            if selectedIndex > nZones then selectedIndex = math_max(1, nZones) end
            if nZones > 0 and selectedIndex < 1 then selectedIndex = 1 end
        end
    else
        if selectedIndex > nZones then selectedIndex = math_max(1, nZones) end
        if nZones > 0 and selectedIndex < 1 then selectedIndex = 1 end
    end
    local maxOff = math_max(0, nZones - NUM_VISIBLE)
    local off = 0
    if maxOff > 0 then
        off = math_min(math_max(0, selectedIndex - NUM_VISIBLE), maxOff)
    end
    FauxScrollFrame_SetOffset(scrollFrame, off)
    UpdateScrollList()
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

function qtRunner:WarpSelected()
    local z = filteredZones[selectedIndex]
    if z then
        TeleportToZone(z)
        self:HideRunner()
    end
end

local function CreateRunnerFrame()
    runnerFrame = CreateFrame("Frame", "qtRunnerPanel", UIParent)
    qtRunner.runnerFrame = runnerFrame
    runnerFrame:SetFrameStrata("DIALOG")
    runnerFrame:SetFrameLevel(100)
    runnerFrame:SetSize(FRAME_W, ICON_SIZE + 86 + LIST_HEIGHT + 8)
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

    previewIcon = runnerFrame:CreateTexture(nil, "ARTWORK")
    qtRunner.previewIcon = previewIcon
    previewIcon:SetSize(ICON_SIZE, ICON_SIZE)
    previewIcon:SetPoint("TOP", 0, -8)
    previewIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    selectedNameText = runnerFrame:CreateFontString(nil, "OVERLAY", "QuestFont_Large")
    qtRunner.selectedNameText = selectedNameText
    selectedNameText:SetPoint("TOP", previewIcon, "BOTTOM", 0, -4)
    selectedNameText:SetWidth(FRAME_W - 16)
    selectedNameText:SetJustifyH("CENTER")
    selectedNameText:SetText("")

    local searchBg = CreateFrame("Frame", nil, runnerFrame)
    searchBg:SetSize(FRAME_W - 20, 26)
    searchBg:SetPoint("TOP", selectedNameText, "BOTTOM", 0, -6)
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
    qtRunner.searchBox = searchBox
    searchBox:SetFontObject("GameFontHighlightLarge")
    searchBox:SetSize(FRAME_W - 36, 24)
    searchBox:SetPoint("CENTER", searchBg, "CENTER", 0, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(10, 10, 0, 0)
    searchBox:SetScript("OnTextChanged", function(self)
        if qtRunner:HandleSearchTextChanged(self:GetText()) then
            return
        end
        selectedIndex = 1
        qtRunner:RefreshRunnerList()
    end)
    searchBox:SetScript("OnEscapePressed", function()
        qtRunner:HideRunner()
    end)
    searchBox:SetScript("OnEnterPressed", function()
        if qtRunner:IsSubmitKeyEnabled("ENTER") then
            qtRunner:WarpSelected()
        end
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

    scrollFrame = CreateFrame("ScrollFrame", "qtRunnerPanelScroll", runnerFrame, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", dropBg, "TOPLEFT", 4, -3)
    scrollFrame:SetWidth(FRAME_W - 22)
    scrollFrame:SetHeight(LIST_HEIGHT)

    local sfName = scrollFrame:GetName()
    local scrollBar = _G[sfName .. "ScrollBar"]
    if scrollBar then
        scrollBar:Hide()
        scrollBar:SetAlpha(0)
        scrollBar:EnableMouse(false)
        local thumb = _G[scrollBar:GetName() .. "Thumb"]
        if thumb then thumb:Hide() end
    end
    local scrollUp = _G[sfName .. "ScrollBarScrollUpButton"]
    local scrollDown = _G[sfName .. "ScrollBarScrollDownButton"]
    if scrollUp then scrollUp:Hide() end
    if scrollDown then scrollDown:Hide() end

    for i = 1, NUM_VISIBLE do
        local btn = CreateFrame("Button", "qtRunnerPanelLine" .. i, scrollFrame)
        btn:SetHeight(LINE_HEIGHT)
        btn:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -(i - 1) * LINE_HEIGHT)
        btn:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -2, -(i - 1) * LINE_HEIGHT)
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
            end
        end)
        btn:SetScript("OnDoubleClick", function()
            qtRunner:WarpSelected()
        end)
        lineButtons[i] = btn
    end
    qtRunner.lineButtons = lineButtons

    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LINE_HEIGHT, UpdateScrollList)
    end)

    runnerFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            qtRunner:HideRunner()
        elseif key == "UP" then
            if selectedIndex > 1 then
                selectedIndex = selectedIndex - 1
                local off = FauxScrollFrame_GetOffset(scrollFrame)
                if selectedIndex <= off then
                    FauxScrollFrame_SetOffset(scrollFrame, selectedIndex - 1)
                end
                UpdateScrollList()
            end
        elseif key == "DOWN" then
            if selectedIndex < #filteredZones then
                selectedIndex = selectedIndex + 1
                local off = FauxScrollFrame_GetOffset(scrollFrame)
                if selectedIndex > off + NUM_VISIBLE then
                    FauxScrollFrame_SetOffset(scrollFrame, selectedIndex - NUM_VISIBLE)
                end
                UpdateScrollList()
            end
        elseif (key == "ENTER" or key == "GRAVE") and qtRunner:IsSubmitKeyEnabled(key) then
            if searchBox:HasFocus() then
                return
            end
            qtRunner:WarpSelected()
        end
    end)

    runnerFrame:SetScript("OnShow", function(self)
        selectedIndex = 1
        searchBox:SetText("")
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

function qtRunner:ShowRunner()
    runnerFrame:Show()
    isRunnerVisible = true
end

function qtRunner:HideRunner()
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
                local spellID = 80567 + band(i, 0x7F)
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
