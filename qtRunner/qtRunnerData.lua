-- qtRunner data — spell database for zone warps
local GetSpellInfo = GetSpellInfo
local band = bit.band
local pairs = pairs
local strfind = string.find
local strgsub = string.gsub
local strlower = string.lower
local strsub = string.sub
local tinsert = table.insert
local tsort = table.sort

local function strCompactLower(s)
    return strlower(strgsub(s, "%s+", ""))
end

qtRunnerData = {}

qtRunnerData.spells = {
    ["Isle of Quel'Danas"] = 0,
    ["Eversong Woods"] = 1,
    ["Ghostlands"] = 2,
    ["Eastern Plaguelands"] = 3,
    ["Western Plaguelands"] = 4,
    ["Tirisfal Glades"] = 5,
    ["Undercity"] = 6,
    ["Silverpine Forest"] = 7,
    ["Alterac Mountains"] = 8,
    ["Hillsbrad Foothills"] = 9,
    ["The Hinterlands"] = 10,
    ["Arathi Highlands"] = 11,
    ["Wetlands"] = 12,
    ["Loch Modan"] = 13,
    ["Ironforge"] = 14,
    ["Dun Morogh"] = 15,
    ["Badlands"] = 16,
    ["Searing Gorge"] = 17,
    ["Burning Steppes"] = 18,
    ["Redridge Mountains"] = 19,
    ["Elwynn Forest"] = 20,
    ["Stormwind City"] = 21,
    ["Westfall"] = 22,
    ["Duskwood"] = 23,
    ["Deadwind Pass"] = 24,
    ["Swamp of Sorrows"] = 25,
    ["Blasted Lands"] = 26,
    ["Stranglethorn Vale"] = 27,
    ["Silvermoon City"] = 28,
    ["Silithus"] = 29,
    ["Un'Goro Crater"] = 30,
    ["Tanaris"] = 31,
    ["Thousand Needles"] = 32,
    ["Feralas"] = 33,
    ["Desolace"] = 34,
    ["Mulgore"] = 35,
    ["Thunder Bluff"] = 36,
    ["The Barrens"] = 37,
    ["Dustwallow Marsh"] = 38,
    ["Stonetalon Mountains"] = 39,
    ["Durotar"] = 40,
    ["Orgrimmar"] = 41,
    ["Ashenvale"] = 42,
    ["Azshara"] = 43,
    ["Winterspring"] = 44,
    ["Felwood"] = 45,
    ["Darkshore"] = 46,
    ["Moonglade"] = 47,
    ["Teldrassil"] = 48,
    ["Darnassus"] = 49,
    ["Azuremyst Isle"] = 50,
    ["The Exodar"] = 51,
    ["Bloodmyst Isle"] = 52,
    ["Hellfire Peninsula"] = 53,
    ["Zangarmarsh"] = 54,
    ["Nagrand"] = 55,
    ["Terokkar Forest"] = 56,
    ["Shadowmoon Valley"] = 57,
    ["Blade's Edge Mountains"] = 58,
    ["Netherstorm"] = 59,
    ["Shattrath City"] = 60,
    ["Howling Fjord"] = 61,
    ["Grizzly Hills"] = 62,
    ["Zul'Drak"] = 63,
    ["The Storm Peaks"] = 64,
    ["Crystalsong Forest"] = 65,
    ["Dalaran"] = 66,
    ["Icecrown"] = 67,
    ["Dragonblight"] = 68,
    ["Wintergrasp"] = 69,
    ["Sholazar Basin"] = 70,
    ["Borean Tundra"] = 71,
}

qtRunnerData.baseAliases = {
    alterac = "Alterac Mountains",
    ah = "The Exodar",
    ash = "Ashenvale",
    az = "Azshara",
    ai = "Azuremyst Isle",
    badlands = "Badlands",
    bem = "Blade's Edge Mountains",
    bl = "Blasted Lands",
    bi = "Bloodmyst Isle",
    bt = "Borean Tundra",
    bs = "Burning Steppes",
    cf = "Crystalsong Forest",
    dal = "Dalaran",
    ds = "Darkshore",
    darn = "Darnassus",
    dp = "Deadwind Pass",
    desolace = "Desolace",
    db = "Dragonblight",
    dm = "Dun Morogh",
    durotar = "Durotar",
    ["dw"] = "Duskwood",
    dwm = "Dustwallow Marsh",
    epl = "Eastern Plaguelands",
    ef = "Elwynn Forest",
    ew = "Eversong Woods",
    fw = "Felwood",
    feralas = "Feralas",
    ["gl"] = "Ghostlands",
    ["gh"] = "Grizzly Hills",
    hfp = "Hellfire Peninsula",
    hb = "Hillsbrad Foothills",
    hf = "Howling Fjord",
    icecrown = "Icecrown",
    icc = "Icecrown",
    ["if"] = "Ironforge",
    iqd = "Isle of Quel'Danas",
    lm = "Loch Modan",
    moonglade = "Moonglade",
    mulgore = "Mulgore",
    nagrand = "Nagrand",
    ns = "Netherstorm",
    org = "Orgrimmar",
    rrm = "Redridge Mountains",
    sg = "Searing Gorge",
    smv = "Shadowmoon Valley",
    sh = "Shattrath City",
    shat = "Shattrath City",
    shol = "Sholazar Basin",
    silithus = "Silithus",
    smc = "Silvermoon City",
    sf = "Silverpine Forest",
    stm = "Stonetalon Mountains",
    sw = "Stormwind City",
    stv = "Stranglethorn Vale",
    sos = "Swamp of Sorrows",
    tanaris = "Tanaris",
    tel = "Teldrassil",
    terokkar = "Terokkar Forest",
    barrens = "The Barrens",
    exodar = "The Exodar",
    hinterlands = "The Hinterlands",
    ["sp"] = "The Storm Peaks",
    ["1k"] = "Thousand Needles",
    tb = "Thunder Bluff",
    tg = "Tirisfal Glades",
    ungoro = "Un'Goro Crater",
    uc = "Undercity",
    wpl = "Western Plaguelands",
    wf = "Westfall",
    wetlands = "Wetlands",
    wg = "Wintergrasp",
    ws = "Winterspring",
    zang = "Zangarmarsh",
    zuldrak = "Zul'Drak",
    isle = "Isle of Quel'Danas",
    quel = "Isle of Quel'Danas",
    queldanas = "Isle of Quel'Danas",
    zg = "Stranglethorn Vale",
    zangar = "Zangarmarsh",
    netherstorm = "Netherstorm",
    hellfire = "Hellfire Peninsula",
    borean = "Borean Tundra",
}

qtRunnerData.aliases = {}
qtRunnerData._spellCompact = {}
qtRunnerData._aliasCompact = {}
qtRunnerData._aliasesByCanon = {}

local function BuildCaches()
    local spellCompactToCanon = {}
    local aliasCompactToCanon = {}
    local aliasesByCanon = {}

    for zoneName in pairs(qtRunnerData.spells) do
        spellCompactToCanon[strCompactLower(zoneName)] = zoneName
    end

    for alias, canon in pairs(qtRunnerData.aliases) do
        if qtRunnerData.spells[canon] then
            aliasCompactToCanon[strCompactLower(alias)] = canon
            local row = aliasesByCanon[canon]
            if not row then
                row = {}
                aliasesByCanon[canon] = row
            end
            local alow = strlower(alias)
            tinsert(row, { alias = alias, alow = alow, acomp = strgsub(alow, "%s+", "") })
        end
    end

    for _, row in pairs(aliasesByCanon) do
        tsort(row, function(a, b)
            return a.alow < b.alow
        end)
    end

    qtRunnerData._spellCompact = spellCompactToCanon
    qtRunnerData._aliasCompact = aliasCompactToCanon
    qtRunnerData._aliasesByCanon = aliasesByCanon
end

function qtRunnerData:GetDefaultAliases()
    local copy = {}
    for alias, canon in pairs(self.baseAliases) do
        copy[alias] = canon
    end
    return copy
end

function qtRunnerData:SetAliases(aliasMap)
    self.aliases = {}
    if aliasMap then
        for alias, canon in pairs(aliasMap) do
            if type(alias) == "string" and type(canon) == "string" and self.spells[canon] then
                local trimmedAlias = strgsub(alias, "^%s*(.-)%s*$", "%1")
                if trimmedAlias ~= "" then
                    self.aliases[trimmedAlias] = canon
                end
            end
        end
    end
    BuildCaches()
end

function qtRunnerData:GetSortedSpellZoneNames()
    if not self._sortedSpellZones then
        local list = {}
        for zoneName in pairs(self.spells) do
            tinsert(list, zoneName)
        end
        tsort(list)
        self._sortedSpellZones = list
    end
    return self._sortedSpellZones
end

function qtRunnerData:GetAliasPairs()
    local rows = {}
    for alias, canon in pairs(self.aliases) do
        tinsert(rows, {
            alias = alias,
            canon = canon,
        })
    end
    tsort(rows, function(a, b)
        return strlower(a.alias) < strlower(b.alias)
    end)
    return rows
end

BuildCaches()

function qtRunnerData:ResolveSpellCanonical(input)
    if not input or input == "" then return nil end
    local trimmed = strgsub(input, "^%s*(.-)%s*$", "%1")
    if self.spells[trimmed] then return trimmed end
    local compact = strCompactLower(trimmed)
    if compact == "" then return nil end
    local zn = self._spellCompact[compact]
    if zn then return zn end
    local n = #compact
    if n >= 2 and n <= 12 then
        local match = nil
        for canon in pairs(self.spells) do
            local clow = strlower(canon)
            if #clow >= n and strsub(clow, 1, n) == compact then
                if match and match ~= canon then return nil end
                match = canon
            end
        end
        if match then return match end
    end
    return nil
end

function qtRunnerData:ResolveZoneCanonical(input)
    if not input or input == "" then return nil end
    local trimmed = strgsub(input, "^%s*(.-)%s*$", "%1")
    if self.spells[trimmed] then return trimmed end
    local compact = strCompactLower(trimmed)
    if compact == "" then return nil end
    local zn = self._spellCompact[compact]
    if zn then return zn end
    local ac = self._aliasCompact[compact]
    if ac then return ac end
    local n = #compact
    if n >= 2 and n <= 12 then
        local match = nil
        for alias, canon in pairs(self.aliases) do
            if self.spells[canon] then
                local alow = strlower(alias)
                local clow = strlower(canon)
                if (#alow >= n and strsub(alow, 1, n) == compact) or (#clow >= n and strsub(clow, 1, n) == compact) then
                    if match and match ~= canon then return nil end
                    match = canon
                end
            end
        end
        if match then return match end
    end
    return nil
end

function qtRunnerData:ZoneMatchesQuery(zoneName, query)
    if not query or query == "" then return true end
    local trimmed = strgsub(query, "^%s*(.-)%s*$", "%1")
    local lt = strlower(trimmed)
    local compact = strCompactLower(trimmed)
    local n = #compact
    local zlow = strlower(zoneName)
    local zcomp = strgsub(zlow, "%s+", "")
    if strfind(zcomp, compact, 1, true) or strfind(zlow, lt, 1, true) then return true end
    if n >= 2 and n <= 12 and #zcomp >= n and strsub(zcomp, 1, n) == compact then return true end
    local rows = self._aliasesByCanon[zoneName]
    if rows then
        for i = 1, #rows do
            local r = rows[i]
            local alow, acomp = r.alow, r.acomp
            if strfind(acomp, compact, 1, true) or strfind(alow, lt, 1, true) then return true end
            if n >= 2 and n <= 12 and #acomp >= n and strsub(acomp, 1, n) == compact then return true end
        end
    end
    return false
end

function qtRunnerData:GetZoneSpellInfo(zoneName)
    local cache = self._zoneSpellCache
    if not cache then
        cache = {}
        self._zoneSpellCache = cache
    end
    local cached = cache[zoneName]
    if cached then return cached end

    local warpIndex = self.spells[zoneName]
    if not warpIndex then
        return nil
    end

    local spellId = 80567 + band(warpIndex, 0x7F)
    local name, rank, icon = GetSpellInfo(spellId)
    local info

    if not name then
        info = {
            name = zoneName,
            icon = "Interface\\Icons\\Spell_Arcane_TeleportStormwind",
            warpIndex = warpIndex,
            zoneName = zoneName,
        }
    else
        info = {
            name = name,
            icon = icon or "Interface\\Icons\\Spell_Arcane_TeleportStormwind",
            warpIndex = warpIndex,
            zoneName = zoneName,
        }
    end

    cache[zoneName] = info
    return info
end
