-- Packed rows are constants; SavedVariables only store qtRunnerDB.theme (name string).
local themesPacked = {
    dark = {
        0.92, 0.94, 0.98, 0.55, 0.62, 0.72, 0.55, 0.78, 1.0,
        0.22, 0.42, 0.62, 0.45, 0.4, 0.65, 0.95, 0.22, 0.02, 0.02, 0.04, 0.92, 0, 0, 0, 0.55,
        0.2, 0.28, 0.38, 0.45, 0.35, 0.4, 0.5, 0.2, 0.3, 0.35, 0.45, 0.18, 0.46, 0.9, 0.58, 1.0, 0.45, 0.45,
    },
    light = {
        0.14, 0.18, 0.24, 0.38, 0.44, 0.52, 0.12, 0.44, 0.76,
        0.42, 0.67, 0.95, 0.34, 0.28, 0.52, 0.82, 0.12, 0.96, 0.97, 1.0, 0.96, 0.88, 0.91, 0.96, 0.96,
        0.58, 0.67, 0.8, 0.9, 0.52, 0.63, 0.78, 0.55, 0.52, 0.63, 0.78, 0.45, 0.12, 0.55, 0.22, 0.75, 0.22, 0.22,
    },
    red = {
        0.98, 0.92, 0.93, 0.72, 0.56, 0.58, 1.0, 0.34, 0.36,
        0.72, 0.18, 0.22, 0.5, 1.0, 0.42, 0.4, 0.24, 0.09, 0.02, 0.04, 0.94, 0.16, 0.04, 0.06, 0.64,
        0.58, 0.18, 0.2, 0.65, 0.74, 0.28, 0.3, 0.32, 0.62, 0.2, 0.24, 0.28, 0.45, 0.88, 0.56, 1.0, 0.48, 0.48,
    },
    blue = {
        0.91, 0.96, 1.0, 0.56, 0.68, 0.82, 0.34, 0.7, 1.0,
        0.14, 0.34, 0.64, 0.48, 0.34, 0.7, 1.0, 0.22, 0.02, 0.05, 0.11, 0.94, 0.03, 0.1, 0.18, 0.62,
        0.2, 0.42, 0.74, 0.6, 0.28, 0.52, 0.86, 0.28, 0.22, 0.46, 0.78, 0.24, 0.48, 0.9, 0.64, 1.0, 0.5, 0.5,
    },
    green = {
        0.92, 0.98, 0.94, 0.56, 0.74, 0.62, 0.34, 0.9, 0.5,
        0.08, 0.42, 0.2, 0.48, 0.36, 1.0, 0.58, 0.2, 0.03, 0.08, 0.04, 0.94, 0.04, 0.14, 0.08, 0.62,
        0.16, 0.52, 0.28, 0.6, 0.24, 0.66, 0.38, 0.3, 0.2, 0.58, 0.34, 0.24, 0.44, 0.94, 0.56, 1.0, 0.48, 0.46,
    },
    yellow = {
        0.2, 0.16, 0.04, 0.44, 0.36, 0.14, 0.92, 0.72, 0.16,
        0.94, 0.78, 0.22, 0.34, 0.98, 0.84, 0.3, 0.16, 0.97, 0.91, 0.62, 0.96, 0.9, 0.82, 0.42, 0.94,
        0.7, 0.56, 0.16, 0.85, 0.76, 0.62, 0.22, 0.5, 0.72, 0.58, 0.18, 0.44, 0.12, 0.5, 0.2, 0.72, 0.2, 0.18,
    },
    purple = {
        0.96, 0.92, 1.0, 0.66, 0.58, 0.8, 0.72, 0.46, 1.0,
        0.38, 0.18, 0.62, 0.48, 0.78, 0.5, 1.0, 0.2, 0.06, 0.03, 0.1, 0.94, 0.12, 0.05, 0.18, 0.62,
        0.42, 0.24, 0.72, 0.6, 0.58, 0.34, 0.9, 0.3, 0.5, 0.28, 0.8, 0.24, 0.44, 0.9, 0.58, 1.0, 0.46, 0.56,
    },
    orange = {
        1.0, 0.94, 0.88, 0.78, 0.6, 0.46, 1.0, 0.56, 0.18,
        0.72, 0.32, 0.08, 0.48, 1.0, 0.62, 0.22, 0.22, 0.1, 0.05, 0.02, 0.94, 0.18, 0.09, 0.03, 0.62,
        0.74, 0.36, 0.08, 0.62, 0.88, 0.48, 0.14, 0.3, 0.78, 0.4, 0.1, 0.24, 0.52, 0.9, 0.56, 1.0, 0.46, 0.4,
    },
    teal = {
        0.9, 0.98, 0.98, 0.54, 0.76, 0.76, 0.22, 0.84, 0.82,
        0.06, 0.42, 0.42, 0.46, 0.28, 0.92, 0.88, 0.2, 0.02, 0.08, 0.08, 0.94, 0.03, 0.15, 0.14, 0.62,
        0.14, 0.52, 0.5, 0.62, 0.2, 0.68, 0.64, 0.3, 0.18, 0.6, 0.58, 0.24, 0.48, 0.94, 0.62, 1.0, 0.48, 0.48,
    },
    rose = {
        1.0, 0.93, 0.96, 0.78, 0.58, 0.68, 1.0, 0.42, 0.66,
        0.68, 0.18, 0.4, 0.46, 1.0, 0.48, 0.72, 0.2, 0.1, 0.03, 0.07, 0.94, 0.16, 0.05, 0.11, 0.62,
        0.72, 0.22, 0.44, 0.62, 0.86, 0.34, 0.58, 0.3, 0.78, 0.28, 0.5, 0.24, 0.48, 0.92, 0.62, 1.0, 0.46, 0.54,
    },
}

local function newColorView()
    local function c3()
        return { r = 0, g = 0, b = 0 }
    end
    local function c4()
        return { r = 0, g = 0, b = 0, a = 1 }
    end
    return {
        text = c3(),
        textMuted = c3(),
        accent = c3(),
        sel = c4(),
        hi = c4(),
        panel = c4(),
        panelInset = c4(),
        border = c4(),
        borderSoft = c4(),
        listBorder = c4(),
        good = c3(),
        bad = c3(),
    }
end

local function applyPackedTheme(p, view)
    local i = 1
    local function u3(t)
        t.r, t.g, t.b = p[i], p[i + 1], p[i + 2]
        i = i + 3
    end
    local function u4(t)
        t.r, t.g, t.b, t.a = p[i], p[i + 1], p[i + 2], p[i + 3]
        i = i + 4
    end
    u3(view.text)
    u3(view.textMuted)
    u3(view.accent)
    u4(view.sel)
    u4(view.hi)
    u4(view.panel)
    u4(view.panelInset)
    u4(view.border)
    u4(view.borderSoft)
    u4(view.listBorder)
    u3(view.good)
    u3(view.bad)
end

local themeOrder = {
    "dark",
    "light",
    "red",
    "blue",
    "green",
    "yellow",
    "purple",
    "orange",
    "teal",
    "rose",
}

local themeLabels = {
    dark = "Dark",
    light = "Light",
    red = "Red",
    blue = "Blue",
    green = "Green",
    yellow = "Yellow",
    purple = "Purple",
    orange = "Orange",
    teal = "Teal",
    rose = "Rose",
}

local colorView = nil
local colorsThemeApplied = nil

function qtRunner:GetColors()
    local themeName = qtRunnerDB and qtRunnerDB.theme or "dark"
    if not colorView then
        colorView = newColorView()
    end
    if colorsThemeApplied ~= themeName then
        colorsThemeApplied = themeName
        local packed = themesPacked[themeName] or themesPacked.dark
        applyPackedTheme(packed, colorView)
    end
    return colorView
end

function qtRunner:ThemePreviewColors(themeName)
    local p = themesPacked[themeName] or themesPacked.dark
    return p[7], p[8], p[9], p[18], p[19], p[20]
end

function qtRunner:GetThemeList()
    return themeOrder
end

function qtRunner:GetThemeLabel(themeName)
    return themeLabels[themeName] or themeName or "Dark"
end

function qtRunner:ApplyTheme()
    local colors = self:GetColors()
    if self._ApplyRunnerPanelColors then
        self:_ApplyRunnerPanelColors(colors)
    end
    if self.RefreshSettingsTheme then
        self:RefreshSettingsTheme()
    end
    if self.RefreshRunnerList and self._RunnerFrameIsVisible and self:_RunnerFrameIsVisible() then
        self:RefreshRunnerList()
    end
end

function qtRunner:IsQuestieEnabled()
    if qtRunnerDB and qtRunnerDB.useQuestie == false then
        return false
    end
    return true
end

function qtRunner:IsTomTomEnabled()
    if qtRunnerDB and qtRunnerDB.useTomTom == false then
        return false
    end
    return true
end

function qtRunner:OnIntegrationChanged()
    if qtRunnerSearchData then
        qtRunnerSearchData._questieDepsReady = nil
        qtRunnerSearchData._questieReady = nil
        if qtRunnerSearchData.ClearQuestieAttunableCache then
            qtRunnerSearchData:ClearQuestieAttunableCache()
        end
    end
    if qtRunnerSearchMode and qtRunnerSearchMode.MarkDirty then
        qtRunnerSearchMode:MarkDirty()
    end
    if self.RefreshRunnerList then
        self:RefreshRunnerList()
    end
end

function qtRunner:ResetDefaults()
    qtRunnerDB.defaultZone = "Dalaran"
    qtRunnerDB.theme = "dark"
    qtRunnerDB.submitWithEnter = true
    qtRunnerDB.submitWithBacktick = true
    qtRunnerDB.useQuestie = true
    qtRunnerDB.useTomTom = true
    qtRunnerDB.aliases = qtRunnerData:GetDefaultAliases()
    qtRunnerData:SetAliases(qtRunnerDB.aliases)
    if self.RefreshSettings then
        self:RefreshSettings()
    end
    self:ApplyTheme()
    self:OnIntegrationChanged()
end
