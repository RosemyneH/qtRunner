local CreateFrame = CreateFrame
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_Update = FauxScrollFrame_Update
local GameFontNormal = GameFontNormal
local GameFontNormalLarge = GameFontNormalLarge
local GameFontNormalSmall = GameFontNormalSmall
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory
local UIParent = UIParent
local MouseIsOver = MouseIsOver
local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert

local settingsUI = {
    frame = nil,
    sections = {},
    tabs = {},
    rows = {},
    texts = {},
    statusTexts = {},
    panels = {},
    inputs = {},
    buttons = {},
    themeButtons = {},
}

local DROPDOWN_VISIBLE_ROWS = 6
local ZONE_AC_VISIBLE_ROWS = 6
local RefreshDefaultZoneDropdown
local ToggleDefaultZoneDropdown
local HideZoneAutocomplete
local RefreshZoneAutocomplete
local ShowZoneAutocomplete
local CloseAddAliasDialog

local function Trim(text)
    return (text or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function CreatePanel(parent, width, height, point, relativeTo, relativePoint, x, y)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, height)
    frame:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    tinsert(settingsUI.panels, frame)
    return frame
end

local function CreateText(parent, template, point, relativeTo, relativePoint, x, y, width, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
    if width then
        fs:SetWidth(width)
    end
    if justify then
        fs:SetJustifyH(justify)
    end
    fs.mode = "text"
    tinsert(settingsUI.texts, fs)
    return fs
end

local function CreateInput(parent, width, point, relativeTo, relativePoint, x, y)
    local bg = CreatePanel(parent, width, 24, point, relativeTo, relativePoint, x, y)
    local input = CreateFrame("EditBox", nil, parent)
    input:SetPoint("TOPLEFT", bg, "TOPLEFT", 6, -4)
    input:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -6, 4)
    input:SetFontObject(GameFontNormal)
    input:SetAutoFocus(false)
    input.bg = bg
    tinsert(settingsUI.inputs, bg)
    return input
end

local function CreateButton(parent, width, height, label, point, relativeTo, relativePoint, x, y, onClick)
    local button = CreatePanel(parent, width, height, point, relativeTo, relativePoint, x, y)
    button:EnableMouse(true)
    button.text = CreateText(button, "GameFontNormal", "CENTER", button, "CENTER", 0, 0)
    button.text:SetText(label)
    button:SetScript("OnMouseUp", function()
        onClick()
    end)
    tinsert(settingsUI.buttons, button)
    return button
end

local function CreateThemeButton(parent, width, height, themeName, point, relativeTo, relativePoint, x, y, onClick)
    local button = CreatePanel(parent, width, height, point, relativeTo, relativePoint, x, y)
    button.themeName = themeName
    button:EnableMouse(true)
    button.swatch = button:CreateTexture(nil, "ARTWORK")
    button.swatch:SetSize(14, 14)
    button.swatch:SetPoint("LEFT", button, "LEFT", 8, 0)
    button.swatchGlow = button:CreateTexture(nil, "BACKGROUND")
    button.swatchGlow:SetPoint("TOPLEFT", button.swatch, "TOPLEFT", -2, 2)
    button.swatchGlow:SetPoint("BOTTOMRIGHT", button.swatch, "BOTTOMRIGHT", 2, -2)
    button.text = CreateText(button, "GameFontNormalSmall", "LEFT", button.swatch, "RIGHT", 8, 0, width - 40, "LEFT")
    button.text:SetText(qtRunner:GetThemeLabel(themeName))
    button:SetScript("OnMouseUp", function()
        onClick(themeName)
    end)
    tinsert(settingsUI.themeButtons, button)
    return button
end

local function UpdateSummary()
    if not settingsUI.general then return end
    local keys = {}
    if qtRunnerDB.submitWithEnter then
        tinsert(keys, "Enter")
    end
    if qtRunnerDB.submitWithBacktick then
        tinsert(keys, "`")
    end
    settingsUI.general.summary:SetText("Default zone: " .. qtRunner:GetDefaultZone() .. "    Theme: " .. qtRunner:GetThemeLabel(qtRunnerDB.theme or "dark") .. "    Submit keys: " .. (#keys > 0 and table.concat(keys, ", ") or "none"))
end

local function SetDefaultZone(zoneName)
    if not zoneName then return end
    qtRunnerDB.defaultZone = zoneName
    qtRunner:RefreshRunnerList()
    UpdateSummary()
    if settingsUI.general and settingsUI.general.UpdateDefaultZoneButton then
        settingsUI.general:UpdateDefaultZoneButton()
    end
end

local function RefreshAliasRows()
    if not settingsUI.aliases then return end
    local rows = qtRunnerData:GetAliasPairs()
    local offset = FauxScrollFrame_GetOffset(settingsUI.aliases.scroll)
    FauxScrollFrame_Update(settingsUI.aliases.scroll, #rows, #settingsUI.rows, 38)

    for i = 1, #settingsUI.rows do
        local row = settingsUI.rows[i]
        local data = rows[i + offset]
        row.data = data
        if data then
            row.aliasBox:SetText(data.alias)
            row.zoneBox:SetText(data.canon)
            row.status.mode = "good"
            row.status:SetText("Saved")
            row:Show()
        else
            row.aliasBox:SetText("")
            row.zoneBox:SetText("")
            row.status.mode = "muted"
            row.status:SetText("")
            row:Hide()
        end
    end
    qtRunner:RefreshSettingsTheme()
end

local function SaveAliasRow(row, deleteOnly)
    HideZoneAutocomplete()
    if not row or not row.data then return end
    local oldAlias = row.data.alias
    local oldCanon = row.data.canon
    qtRunnerDB.aliases[row.data.alias] = nil

    if not deleteOnly then
        local alias = Trim(row.aliasBox:GetText())
        local zone = qtRunnerData:ResolveSpellCanonical(row.zoneBox:GetText())
        if alias == "" then
            qtRunnerDB.aliases[oldAlias] = oldCanon
            row.status.mode = "bad"
            row.status:SetText("Alias required")
            qtRunner:RefreshSettingsTheme()
            qtRunnerData:SetAliases(qtRunnerDB.aliases)
            return
        end
        if not zone then
            qtRunnerDB.aliases[oldAlias] = oldCanon
            row.status.mode = "bad"
            row.status:SetText("Invalid destination")
            qtRunner:RefreshSettingsTheme()
            qtRunnerData:SetAliases(qtRunnerDB.aliases)
            return
        end
        qtRunnerDB.aliases[alias] = zone
    end

    qtRunnerData:SetAliases(qtRunnerDB.aliases)
    qtRunner:RefreshRunnerList()
    RefreshAliasRows()
end

local zoneAutocomplete = {
    frame = nil,
    scroll = nil,
    rows = {},
    matches = {},
    anchorEdit = nil,
    deferFrame = nil,
}

HideZoneAutocomplete = function()
    if zoneAutocomplete.frame then
        zoneAutocomplete.frame:Hide()
    end
    zoneAutocomplete.anchorEdit = nil
    zoneAutocomplete.matches = {}
end

RefreshZoneAutocomplete = function()
    if not zoneAutocomplete.frame or not zoneAutocomplete.anchorEdit then return end
    local edit = zoneAutocomplete.anchorEdit
    local q = Trim(edit:GetText())
    local all = qtRunnerData:GetSortedSpellZoneNames()
    local matches = {}
    if q == "" then
        for i = 1, #all do
            matches[i] = all[i]
        end
    else
        for i = 1, #all do
            local z = all[i]
            if qtRunnerData:ZoneMatchesQuery(z, q) then
                tinsert(matches, z)
            end
        end
    end
    zoneAutocomplete.matches = matches
    local offset = FauxScrollFrame_GetOffset(zoneAutocomplete.scroll)
    FauxScrollFrame_Update(zoneAutocomplete.scroll, #matches, #zoneAutocomplete.rows, 24)
    for i = 1, #zoneAutocomplete.rows do
        local row = zoneAutocomplete.rows[i]
        local zoneName = matches[i + offset]
        row.zoneName = zoneName
        if zoneName then
            local info = qtRunnerData:GetZoneSpellInfo(zoneName)
            row.icon:SetTexture(info and info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.text:SetText(zoneName)
            row:Show()
        else
            row.zoneName = nil
            row:Hide()
        end
    end
end

local function DeferHideZoneAutocomplete()
    if not zoneAutocomplete.deferFrame then
        zoneAutocomplete.deferFrame = CreateFrame("Frame")
        zoneAutocomplete.deferFrame:Hide()
    end
    zoneAutocomplete.deferFrame:SetScript("OnUpdate", function(self)
        self:Hide()
        self:SetScript("OnUpdate", nil)
        if zoneAutocomplete.frame and zoneAutocomplete.frame:IsShown() and MouseIsOver(zoneAutocomplete.frame) then
            return
        end
        HideZoneAutocomplete()
    end)
    zoneAutocomplete.deferFrame:Show()
end

ShowZoneAutocomplete = function(editBox)
    if not zoneAutocomplete.frame or not editBox or not editBox.bg then return end
    zoneAutocomplete.anchorEdit = editBox
    zoneAutocomplete.frame:ClearAllPoints()
    zoneAutocomplete.frame:SetPoint("TOPLEFT", editBox.bg, "BOTTOMLEFT", 0, -2)
    zoneAutocomplete.frame:SetFrameStrata("FULLSCREEN_DIALOG")
    local acLevel = (settingsUI.frame and settingsUI.frame:GetFrameLevel() or 0) + 30
    if settingsUI.addAliasDialog and settingsUI.addAliasDialog:IsShown() then
        acLevel = settingsUI.addAliasDialog:GetFrameLevel() + 10
    end
    zoneAutocomplete.frame:SetFrameLevel(acLevel)
    RefreshZoneAutocomplete()
    if #zoneAutocomplete.matches == 0 then
        zoneAutocomplete.frame:Hide()
        return
    end
    zoneAutocomplete.frame:Show()
end

local function WireDestinationAutocomplete(editBox)
    editBox:SetScript("OnEditFocusGained", function(self)
        ShowZoneAutocomplete(self)
    end)
    editBox:SetScript("OnEditFocusLost", function()
        DeferHideZoneAutocomplete()
    end)
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            ShowZoneAutocomplete(self)
        else
            HideZoneAutocomplete()
        end
    end)
end

local function OpenAddAliasDialog()
    if not settingsUI.addAliasDialog then return end
    HideZoneAutocomplete()
    settingsUI.addAliasDialog.aliasEdit:SetText("")
    settingsUI.addAliasDialog.zoneEdit:SetText(qtRunner:GetDefaultZone())
    settingsUI.addAliasDialog.status:SetText("")
    settingsUI.addAliasDialog.status.mode = "muted"
    settingsUI.addAliasDialog:Show()
    settingsUI.addAliasDialog.aliasEdit:SetFocus()
    qtRunner:RefreshSettingsTheme()
end

local function SaveAddAliasDialog()
    if not settingsUI.addAliasDialog then return end
    local alias = Trim(settingsUI.addAliasDialog.aliasEdit:GetText())
    local zone = qtRunnerData:ResolveSpellCanonical(settingsUI.addAliasDialog.zoneEdit:GetText())
    if alias == "" then
        settingsUI.addAliasDialog.status.mode = "bad"
        settingsUI.addAliasDialog.status:SetText("Alias required")
        qtRunner:RefreshSettingsTheme()
        return
    end
    if not zone then
        settingsUI.addAliasDialog.status.mode = "bad"
        settingsUI.addAliasDialog.status:SetText("Invalid destination")
        qtRunner:RefreshSettingsTheme()
        return
    end
    qtRunnerDB.aliases[alias] = zone
    qtRunnerData:SetAliases(qtRunnerDB.aliases)
    qtRunner:RefreshRunnerList()
    HideZoneAutocomplete()
    settingsUI.addAliasDialog:Hide()
    RefreshAliasRows()
end

CloseAddAliasDialog = function()
    HideZoneAutocomplete()
    if settingsUI.addAliasDialog then
        settingsUI.addAliasDialog:Hide()
    end
end

local function SelectTab(name)
    settingsUI.activeTab = name
    ToggleDefaultZoneDropdown(false)
    HideZoneAutocomplete()
    CloseAddAliasDialog()
    if name == "general" then
        settingsUI.general.section:Show()
        settingsUI.aliases.section:Hide()
    else
        settingsUI.general.section:Hide()
        settingsUI.aliases.section:Show()
    end
    qtRunner:RefreshSettingsTheme()
end

RefreshDefaultZoneDropdown = function()
    if not settingsUI.general or not settingsUI.general.dropdown then return end

    local rows = qtRunner:GetLearnedZones()
    local dropdown = settingsUI.general.dropdown
    local offset = FauxScrollFrame_GetOffset(dropdown.scroll)
    FauxScrollFrame_Update(dropdown.scroll, #rows, #dropdown.rows, 24)

    for i = 1, #dropdown.rows do
        local row = dropdown.rows[i]
        local zoneName = rows[i + offset]
        row.zoneName = zoneName
        if zoneName then
            local info = qtRunnerData:GetZoneSpellInfo(zoneName)
            row.icon:SetTexture(info and info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.text:SetText(zoneName)
            row:Show()
        else
            row.zoneName = nil
            row:Hide()
        end
    end
end

ToggleDefaultZoneDropdown = function(forceState)
    if not settingsUI.general or not settingsUI.general.dropdown then return end
    local dropdown = settingsUI.general.dropdown
    local shouldShow = forceState
    if shouldShow == nil then
        shouldShow = not dropdown:IsShown()
    end
    if shouldShow then
        HideZoneAutocomplete()
        RefreshDefaultZoneDropdown()
        dropdown:Show()
    else
        dropdown:Hide()
    end
end

local function BuildAliasRow(parent, index)
    local row = CreatePanel(parent, 690, 34, "TOPLEFT", parent, "TOPLEFT", 8, -8 - ((index - 1) * 38))
    row.aliasLabel = CreateText(row, "GameFontNormalSmall", "LEFT", row, "LEFT", 8, 8)
    row.aliasLabel:SetText("Alias")
    row.aliasBox = CreateInput(row, 150, "LEFT", row, "LEFT", 54, 0)
    row.aliasBox:SetMaxLetters(32)
    row.zoneLabel = CreateText(row, "GameFontNormalSmall", "LEFT", row, "LEFT", 224, 8)
    row.zoneLabel:SetText("Destination")
    row.zoneBox = CreateInput(row, 180, "LEFT", row, "LEFT", 296, 0)
    row.zoneBox:SetMaxLetters(64)
    row.status = CreateText(row, "GameFontNormalSmall", "LEFT", row, "LEFT", 490, 0)
    row.status.mode = "muted"
    tinsert(settingsUI.statusTexts, row.status)

    row.saveButton = CreateButton(row, 54, 22, "Save", "RIGHT", row, "RIGHT", -64, 0, function()
        SaveAliasRow(row)
    end)
    row.deleteButton = CreateButton(row, 54, 22, "Delete", "RIGHT", row, "RIGHT", -8, 0, function()
        SaveAliasRow(row, true)
    end)

    row.aliasBox:SetScript("OnEnterPressed", function()
        SaveAliasRow(row)
    end)
    row.zoneBox:SetScript("OnEnterPressed", function()
        SaveAliasRow(row)
    end)

    WireDestinationAutocomplete(row.zoneBox)

    settingsUI.rows[index] = row
end

local function BuildSettingsFrame()
    local frame = CreateFrame("Frame", "qtRunnerOptionsFrame", UIParent)
    frame:SetSize(760, 620)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    tinsert(settingsUI.panels, frame)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    frame:Hide()
    tinsert(UISpecialFrames, "qtRunnerOptionsFrame")
    settingsUI.frame = frame

    zoneAutocomplete.frame = CreatePanel(frame, 200, 156, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    zoneAutocomplete.frame:Hide()
    zoneAutocomplete.frame:EnableMouse(true)
    zoneAutocomplete.scroll = CreateFrame("ScrollFrame", "qtRunnerZoneACScroll", zoneAutocomplete.frame, "FauxScrollFrameTemplate")
    zoneAutocomplete.scroll:SetPoint("TOPLEFT", zoneAutocomplete.frame, "TOPLEFT", 0, -4)
    zoneAutocomplete.scroll:SetWidth(200)
    zoneAutocomplete.scroll:SetHeight(148)
    zoneAutocomplete.scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 24, RefreshZoneAutocomplete)
    end)
    for i = 1, ZONE_AC_VISIBLE_ROWS do
        local acRow = CreatePanel(zoneAutocomplete.frame, 192, 22, "TOPLEFT", zoneAutocomplete.frame, "TOPLEFT", 4, -4 - ((i - 1) * 24))
        acRow:EnableMouse(true)
        acRow.icon = acRow:CreateTexture(nil, "ARTWORK")
        acRow.icon:SetSize(16, 16)
        acRow.icon:SetPoint("LEFT", acRow, "LEFT", 6, 0)
        acRow.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        acRow.text = CreateText(acRow, "GameFontNormalSmall", "LEFT", acRow.icon, "RIGHT", 8, 0, 150, "LEFT")
        acRow:SetScript("OnMouseUp", function(self)
            if not self.zoneName or not zoneAutocomplete.anchorEdit then return end
            zoneAutocomplete.anchorEdit:SetText(self.zoneName)
            zoneAutocomplete.anchorEdit:SetCursorPosition(string.len(self.zoneName))
            HideZoneAutocomplete()
        end)
        zoneAutocomplete.rows[i] = acRow
    end

    settingsUI.addAliasDialog = CreatePanel(frame, 380, 210, "CENTER", frame, "CENTER", 0, 0)
    settingsUI.addAliasDialog:Hide()
    settingsUI.addAliasDialog:SetFrameStrata("FULLSCREEN_DIALOG")
    settingsUI.addAliasDialog:SetFrameLevel(90)
    local addDlgTitle = CreateText(settingsUI.addAliasDialog, "GameFontNormalLarge", "TOPLEFT", settingsUI.addAliasDialog, "TOPLEFT", 20, -16)
    addDlgTitle:SetText("Add alias")
    local addDlgHelp = CreateText(settingsUI.addAliasDialog, "GameFontNormalSmall", "TOPLEFT", addDlgTitle, "BOTTOMLEFT", 0, -8, 340, "LEFT")
    addDlgHelp.mode = "muted"
    addDlgHelp:SetText("Pick a short alias and a destination. The destination field suggests every warp zone as you type.")
    settingsUI.addAliasDialog.aliasLabel = CreateText(settingsUI.addAliasDialog, "GameFontNormalSmall", "TOPLEFT", addDlgHelp, "BOTTOMLEFT", 0, -14, 80, "LEFT")
    settingsUI.addAliasDialog.aliasLabel.mode = "muted"
    settingsUI.addAliasDialog.aliasLabel:SetText("Alias")
    settingsUI.addAliasDialog.aliasEdit = CreateInput(settingsUI.addAliasDialog, 220, "TOPLEFT", settingsUI.addAliasDialog.aliasLabel, "BOTTOMLEFT", 0, -4)
    settingsUI.addAliasDialog.aliasEdit:SetMaxLetters(32)
    settingsUI.addAliasDialog.zoneLabel = CreateText(settingsUI.addAliasDialog, "GameFontNormalSmall", "TOPLEFT", settingsUI.addAliasDialog.aliasEdit.bg, "BOTTOMLEFT", 0, -14, 120, "LEFT")
    settingsUI.addAliasDialog.zoneLabel.mode = "muted"
    settingsUI.addAliasDialog.zoneLabel:SetText("Destination")
    settingsUI.addAliasDialog.zoneEdit = CreateInput(settingsUI.addAliasDialog, 220, "TOPLEFT", settingsUI.addAliasDialog.zoneLabel, "BOTTOMLEFT", 0, -4)
    settingsUI.addAliasDialog.zoneEdit:SetMaxLetters(64)
    WireDestinationAutocomplete(settingsUI.addAliasDialog.zoneEdit)
    settingsUI.addAliasDialog.aliasEdit:SetScript("OnEnterPressed", function()
        settingsUI.addAliasDialog.zoneEdit:SetFocus()
    end)
    settingsUI.addAliasDialog.zoneEdit:SetScript("OnEnterPressed", function()
        SaveAddAliasDialog()
    end)
    settingsUI.addAliasDialog.status = CreateText(settingsUI.addAliasDialog, "GameFontNormalSmall", "TOPLEFT", settingsUI.addAliasDialog.zoneEdit.bg, "BOTTOMLEFT", 0, -10, 340, "LEFT")
    settingsUI.addAliasDialog.status.mode = "muted"
    tinsert(settingsUI.statusTexts, settingsUI.addAliasDialog.status)
    local addDlgCancel = CreateButton(settingsUI.addAliasDialog, 100, 26, "Cancel", "BOTTOMRIGHT", settingsUI.addAliasDialog, "BOTTOMRIGHT", -16, 14, CloseAddAliasDialog)
    CreateButton(settingsUI.addAliasDialog, 100, 26, "Save", "RIGHT", addDlgCancel, "LEFT", -12, 0, SaveAddAliasDialog)

    settingsUI.title = CreateText(frame, "GameFontNormalLarge", "TOPLEFT", frame, "TOPLEFT", 20, -18)
    settingsUI.title:SetText("qtRunner Control Center")
    settingsUI.subtitle = CreateText(frame, "GameFontNormalSmall", "TOPLEFT", settingsUI.title, "BOTTOMLEFT", 0, -8, 560, "LEFT")
    settingsUI.subtitle.mode = "muted"
    settingsUI.subtitle:SetText("A two-tab settings page for defaults, aliases, submit keys, and theme switching.")

    settingsUI.close = CreateButton(frame, 28, 24, "X", "TOPRIGHT", frame, "TOPRIGHT", -16, -14, function()
        ToggleDefaultZoneDropdown(false)
        CloseAddAliasDialog()
        frame:Hide()
    end)

    settingsUI.tabs.general = CreateButton(frame, 150, 28, "General", "TOPLEFT", frame, "TOPLEFT", 20, -74, function()
        SelectTab("general")
    end)
    settingsUI.tabs.aliases = CreateButton(frame, 150, 28, "Aliases", "LEFT", settingsUI.tabs.general, "RIGHT", 12, 0, function()
        SelectTab("aliases")
    end)

    settingsUI.general = {}
    settingsUI.general.section = CreateFrame("Frame", nil, frame)
    settingsUI.general.section:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -116)
    settingsUI.general.section:SetSize(720, 484)

    local hero = CreatePanel(settingsUI.general.section, 720, 100, "TOPLEFT", settingsUI.general.section, "TOPLEFT", 0, 0)
    settingsUI.general.heroTitle = CreateText(hero, "GameFontNormalLarge", "TOPLEFT", hero, "TOPLEFT", 16, -14)
    settingsUI.general.heroTitle:SetText("Defaults")
    settingsUI.general.heroCopy = CreateText(hero, "GameFontNormalSmall", "TOPLEFT", settingsUI.general.heroTitle, "BOTTOMLEFT", 0, -10, 520, "LEFT")
    settingsUI.general.heroCopy.mode = "muted"
    settingsUI.general.heroCopy:SetText("Pick the default destination highlighted on open, choose which keys submit instantly, and swap between a full set of color themes.")
    settingsUI.general.summary = CreateText(hero, "GameFontNormal", "BOTTOMLEFT", hero, "BOTTOMLEFT", 16, 14, 660, "LEFT")
    settingsUI.general.summary.mode = "accent"

    local behavior = CreatePanel(settingsUI.general.section, 350, 220, "TOPLEFT", hero, "BOTTOMLEFT", 0, -16)
    settingsUI.general.behaviorTitle = CreateText(behavior, "GameFontNormalLarge", "TOPLEFT", behavior, "TOPLEFT", 16, -14)
    settingsUI.general.behaviorTitle:SetText("Runner behavior")
    settingsUI.general.zoneLabel = CreateText(behavior, "GameFontNormalSmall", "TOPLEFT", settingsUI.general.behaviorTitle, "BOTTOMLEFT", 0, -12, 300, "LEFT")
    settingsUI.general.zoneLabel.mode = "muted"
    settingsUI.general.zoneLabel:SetText("Default destination")
    settingsUI.general.defaultZoneButton = CreatePanel(behavior, 220, 26, "TOPLEFT", settingsUI.general.zoneLabel, "BOTTOMLEFT", 0, -8)
    settingsUI.general.defaultZoneButton:EnableMouse(true)
    settingsUI.general.defaultZoneButton.icon = settingsUI.general.defaultZoneButton:CreateTexture(nil, "ARTWORK")
    settingsUI.general.defaultZoneButton.icon:SetSize(18, 18)
    settingsUI.general.defaultZoneButton.icon:SetPoint("LEFT", settingsUI.general.defaultZoneButton, "LEFT", 6, 0)
    settingsUI.general.defaultZoneButton.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    settingsUI.general.defaultZoneButton.text = CreateText(settingsUI.general.defaultZoneButton, "GameFontNormal", "LEFT", settingsUI.general.defaultZoneButton.icon, "RIGHT", 8, 0, 170, "LEFT")
    settingsUI.general.defaultZoneButton.arrow = CreateText(settingsUI.general.defaultZoneButton, "GameFontNormal", "RIGHT", settingsUI.general.defaultZoneButton, "RIGHT", -8, 0)
    settingsUI.general.defaultZoneButton.arrow:SetText("v")
    settingsUI.general.defaultZoneButton:SetScript("OnMouseUp", function()
        ToggleDefaultZoneDropdown()
    end)

    settingsUI.general.dropdown = CreatePanel(behavior, 220, 156, "TOPLEFT", settingsUI.general.defaultZoneButton, "BOTTOMLEFT", 0, -4)
    settingsUI.general.dropdown:SetFrameStrata("DIALOG")
    settingsUI.general.dropdown:Hide()
    settingsUI.general.dropdown.scroll = CreateFrame("ScrollFrame", "qtRunnerDefaultZoneDropdownScroll", settingsUI.general.dropdown, "FauxScrollFrameTemplate")
    settingsUI.general.dropdown.scroll:SetPoint("TOPLEFT", settingsUI.general.dropdown, "TOPLEFT", 0, -4)
    settingsUI.general.dropdown.scroll:SetWidth(220)
    settingsUI.general.dropdown.scroll:SetHeight(148)
    settingsUI.general.dropdown.rows = {}
    settingsUI.general.dropdown.scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 24, RefreshDefaultZoneDropdown)
    end)

    for i = 1, DROPDOWN_VISIBLE_ROWS do
        local row = CreatePanel(settingsUI.general.dropdown, 212, 22, "TOPLEFT", settingsUI.general.dropdown, "TOPLEFT", 4, -4 - ((i - 1) * 24))
        row:EnableMouse(true)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.text = CreateText(row, "GameFontNormalSmall", "LEFT", row.icon, "RIGHT", 8, 0, 170, "LEFT")
        row:SetScript("OnMouseUp", function(self)
            if self.zoneName then
                SetDefaultZone(self.zoneName)
                ToggleDefaultZoneDropdown(false)
            end
        end)
        settingsUI.general.dropdown.rows[i] = row
    end

    function settingsUI.general:UpdateDefaultZoneButton()
        local zoneName = qtRunner:GetDefaultZone()
        local info = qtRunnerData:GetZoneSpellInfo(zoneName)
        self.defaultZoneButton.icon:SetTexture(info and info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.defaultZoneButton.text:SetText(zoneName)
    end

    settingsUI.general.enterCheck = CreateFrame("CheckButton", nil, behavior, "UICheckButtonTemplate")
    settingsUI.general.enterCheck:SetPoint("TOPLEFT", settingsUI.general.defaultZoneButton, "BOTTOMLEFT", -4, -16)
    settingsUI.general.enterCheck.label = CreateText(behavior, "GameFontNormal", "LEFT", settingsUI.general.enterCheck, "RIGHT", 4, 1)
    settingsUI.general.enterCheck.label:SetText("Submit on Enter")
    settingsUI.general.enterCheck:SetScript("OnClick", function(self)
        qtRunnerDB.submitWithEnter = self:GetChecked() and true or false
        UpdateSummary()
    end)

    settingsUI.general.graveCheck = CreateFrame("CheckButton", nil, behavior, "UICheckButtonTemplate")
    settingsUI.general.graveCheck:SetPoint("TOPLEFT", settingsUI.general.enterCheck, "BOTTOMLEFT", 0, -10)
    settingsUI.general.graveCheck.label = CreateText(behavior, "GameFontNormal", "LEFT", settingsUI.general.graveCheck, "RIGHT", 4, 1)
    settingsUI.general.graveCheck.label:SetText("Submit on `")
    settingsUI.general.graveCheck:SetScript("OnClick", function(self)
        qtRunnerDB.submitWithBacktick = self:GetChecked() and true or false
        UpdateSummary()
    end)

    local theme = CreatePanel(settingsUI.general.section, 350, 220, "TOPRIGHT", hero, "BOTTOMRIGHT", 0, -16)
    settingsUI.general.themeTitle = CreateText(theme, "GameFontNormalLarge", "TOPLEFT", theme, "TOPLEFT", 16, -14)
    settingsUI.general.themeTitle:SetText("Theme")
    settingsUI.general.themeCopy = CreateText(theme, "GameFontNormalSmall", "TOPLEFT", settingsUI.general.themeTitle, "BOTTOMLEFT", 0, -10, 318, "LEFT")
    settingsUI.general.themeCopy.mode = "muted"
    settingsUI.general.themeCopy:SetText("Choose a color preset for both the runner and control center.")
    settingsUI.general.themeButtons = {}

    local themeNames = qtRunner:GetThemeList()
    for index, themeName in ipairs(themeNames) do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local point = "TOPLEFT"
        local relativeTo
        local relativePoint
        local offsetX
        local offsetY

        if row == 0 then
            relativeTo = theme
            relativePoint = "TOPLEFT"
            offsetX = column == 0 and 16 or 182
            offsetY = -76
        else
            relativeTo = settingsUI.general.themeButtons[index - 2]
            relativePoint = "BOTTOMLEFT"
            offsetX = 0
            offsetY = -6
        end

        local button = CreateThemeButton(theme, 152, 22, themeName, point, relativeTo, relativePoint, offsetX, offsetY, function(selectedTheme)
            qtRunnerDB.theme = selectedTheme
            qtRunner:ApplyTheme()
            UpdateSummary()
        end)
        settingsUI.general.themeButtons[index] = button
    end

    local actions = CreatePanel(settingsUI.general.section, 720, 110, "TOPLEFT", theme, "BOTTOMLEFT", -370, -16)
    settingsUI.general.actionsTitle = CreateText(actions, "GameFontNormalLarge", "TOPLEFT", actions, "TOPLEFT", 16, -14)
    settingsUI.general.actionsTitle:SetText("Actions")
    settingsUI.general.actionsCopy = CreateText(actions, "GameFontNormalSmall", "TOPLEFT", settingsUI.general.actionsTitle, "BOTTOMLEFT", 0, -10, 520, "LEFT")
    settingsUI.general.actionsCopy.mode = "muted"
    settingsUI.general.actionsCopy:SetText("The addon toggle now defaults to ` in Key Bindings. You can also open Blizzard's keybind panel or fully reset qtRunner from here.")
    settingsUI.general.bindButton = CreateButton(actions, 180, 28, "Open Key Bindings", "BOTTOMLEFT", actions, "BOTTOMLEFT", 16, 16, function()
        InterfaceOptionsFrame_OpenToCategory(KEY_BINDINGS or "Key Bindings")
    end)
    settingsUI.general.resetButton = CreateButton(actions, 180, 28, "Reset qtRunner", "LEFT", settingsUI.general.bindButton, "RIGHT", 12, 0, function()
        qtRunner:ResetDefaults()
    end)

    settingsUI.aliases = {}
    settingsUI.aliases.section = CreateFrame("Frame", nil, frame)
    settingsUI.aliases.section:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -116)
    settingsUI.aliases.section:SetSize(720, 424)
    settingsUI.aliases.section:Hide()

    local aliasHero = CreatePanel(settingsUI.aliases.section, 720, 84, "TOPLEFT", settingsUI.aliases.section, "TOPLEFT", 0, 0)
    settingsUI.aliases.title = CreateText(aliasHero, "GameFontNormalLarge", "TOPLEFT", aliasHero, "TOPLEFT", 16, -14)
    settingsUI.aliases.title:SetText("Aliases")
    settingsUI.aliases.copy = CreateText(aliasHero, "GameFontNormalSmall", "TOPLEFT", settingsUI.aliases.title, "BOTTOMLEFT", 0, -10, 520, "LEFT")
    settingsUI.aliases.copy.mode = "muted"
    settingsUI.aliases.copy:SetText("Change shorthand names without editing Lua files. Alias matches affect both exact resolution and live search.")
    settingsUI.aliases.addButton = CreateButton(aliasHero, 120, 26, "Add Alias", "TOPRIGHT", aliasHero, "TOPRIGHT", -16, -16, OpenAddAliasDialog)

    settingsUI.aliases.list = CreatePanel(settingsUI.aliases.section, 720, 310, "TOPLEFT", aliasHero, "BOTTOMLEFT", 0, -16)
    settingsUI.aliases.scroll = CreateFrame("ScrollFrame", "qtRunnerAliasScroll", settingsUI.aliases.list, "FauxScrollFrameTemplate")
    settingsUI.aliases.scroll:SetPoint("TOPLEFT", settingsUI.aliases.list, "TOPLEFT", 0, 0)
    settingsUI.aliases.scroll:SetWidth(720)
    settingsUI.aliases.scroll:SetHeight(310)
    settingsUI.aliases.scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, 38, RefreshAliasRows)
    end)

    for i = 1, 7 do
        BuildAliasRow(settingsUI.aliases.list, i)
    end

    settingsUI.aliases.footer = CreatePanel(settingsUI.aliases.section, 720, 72, "TOPLEFT", settingsUI.aliases.list, "BOTTOMLEFT", 0, -16)
    settingsUI.aliases.footerTitle = CreateText(settingsUI.aliases.footer, "GameFontNormal", "TOPLEFT", settingsUI.aliases.footer, "TOPLEFT", 16, -14)
    settingsUI.aliases.footerTitle:SetText("Good defaults")
    settingsUI.aliases.footerCopy = CreateText(settingsUI.aliases.footer, "GameFontNormalSmall", "TOPLEFT", settingsUI.aliases.footerTitle, "BOTTOMLEFT", 0, -8, 640, "LEFT")
    settingsUI.aliases.footerCopy.mode = "muted"
    settingsUI.aliases.footerCopy:SetText("Examples: dal -> Dalaran, shat -> Shattrath City, org -> Orgrimmar. Destination fields autocomplete all warp zones; press Enter or Save.")

    SelectTab("general")
end

function qtRunner:RefreshSettingsTheme()
    if not settingsUI.frame then return end
    local colors = self:GetColors()

    for _, panel in ipairs(settingsUI.panels) do
        panel:SetBackdropColor(colors.panel.r, colors.panel.g, colors.panel.b, colors.panel.a)
        panel:SetBackdropBorderColor(colors.border.r, colors.border.g, colors.border.b, colors.border.a)
    end

    for _, input in ipairs(settingsUI.inputs) do
        input:SetBackdropColor(colors.panelInset.r, colors.panelInset.g, colors.panelInset.b, colors.panelInset.a)
        input:SetBackdropBorderColor(colors.borderSoft.r, colors.borderSoft.g, colors.borderSoft.b, colors.borderSoft.a)
    end

    for _, fs in ipairs(settingsUI.texts) do
        if fs.mode == "muted" then
            fs:SetTextColor(colors.textMuted.r, colors.textMuted.g, colors.textMuted.b)
        elseif fs.mode == "accent" then
            fs:SetTextColor(colors.accent.r, colors.accent.g, colors.accent.b)
        else
            fs:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
        end
    end

    settingsUI.tabs.general.text:SetTextColor(settingsUI.activeTab == "general" and colors.accent.r or colors.text.r, settingsUI.activeTab == "general" and colors.accent.g or colors.text.g, settingsUI.activeTab == "general" and colors.accent.b or colors.text.b)
    settingsUI.tabs.aliases.text:SetTextColor(settingsUI.activeTab == "aliases" and colors.accent.r or colors.text.r, settingsUI.activeTab == "aliases" and colors.accent.g or colors.text.g, settingsUI.activeTab == "aliases" and colors.accent.b or colors.text.b)
    settingsUI.general.defaultZoneButton.text:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
    settingsUI.general.defaultZoneButton.arrow:SetTextColor(colors.textMuted.r, colors.textMuted.g, colors.textMuted.b)

    for _, button in ipairs(settingsUI.themeButtons) do
        local themeColors = qtRunner.Themes[button.themeName]
        local isSelected = qtRunnerDB.theme == button.themeName
        local border = isSelected and colors.accent or colors.borderSoft
        local borderAlpha = isSelected and 0.95 or border.a
        local panelColor = isSelected and colors.panelInset or colors.panel
        local panelAlpha = isSelected and 0.98 or panelColor.a

        button:SetBackdropColor(panelColor.r, panelColor.g, panelColor.b, panelAlpha)
        button:SetBackdropBorderColor(border.r, border.g, border.b, borderAlpha)
        button.text:SetTextColor(isSelected and colors.accent.r or colors.text.r, isSelected and colors.accent.g or colors.text.g, isSelected and colors.accent.b or colors.text.b)

        if themeColors then
            button.swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
            button.swatch:SetVertexColor(themeColors.accent.r, themeColors.accent.g, themeColors.accent.b, 1)
            button.swatchGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
            button.swatchGlow:SetVertexColor(themeColors.panel.r, themeColors.panel.g, themeColors.panel.b, 1)
        end
    end

    for _, row in ipairs(settingsUI.rows) do
        if row.status.mode == "good" then
            row.status:SetTextColor(colors.good.r, colors.good.g, colors.good.b)
        elseif row.status.mode == "bad" then
            row.status:SetTextColor(colors.bad.r, colors.bad.g, colors.bad.b)
        else
            row.status:SetTextColor(colors.textMuted.r, colors.textMuted.g, colors.textMuted.b)
        end
        row.aliasLabel:SetTextColor(colors.textMuted.r, colors.textMuted.g, colors.textMuted.b)
        row.zoneLabel:SetTextColor(colors.textMuted.r, colors.textMuted.g, colors.textMuted.b)
        row.saveButton.text:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
        row.deleteButton.text:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
    end

    if settingsUI.general.dropdown then
        for _, row in ipairs(settingsUI.general.dropdown.rows) do
            row.text:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
        end
    end

    if zoneAutocomplete.rows then
        for _, acRow in ipairs(zoneAutocomplete.rows) do
            if acRow.text then
                acRow.text:SetTextColor(colors.text.r, colors.text.g, colors.text.b)
            end
        end
    end
end

function qtRunner:RefreshSettings()
    if not settingsUI.frame then
        BuildSettingsFrame()
    end
    settingsUI.general:UpdateDefaultZoneButton()
    settingsUI.general.enterCheck:SetChecked(qtRunnerDB.submitWithEnter)
    settingsUI.general.graveCheck:SetChecked(qtRunnerDB.submitWithBacktick)
    ToggleDefaultZoneDropdown(false)
    UpdateSummary()
    RefreshAliasRows()
    self:RefreshSettingsTheme()
end

function qtRunner:ShowSettings()
    self:RefreshSettings()
    settingsUI.frame:Show()
end
