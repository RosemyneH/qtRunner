local ipairs = ipairs
local pairs = pairs
local strlower = string.lower
local strfind = string.find
local strsub = string.sub
local tinsert = table.insert
local tsort = table.sort
local math_floor = math.floor
local math_min = math.min
local math_sqrt = math.sqrt
local band = bit.band
local bor = bit.bor
local lshift = bit.lshift

qtRunnerSearchData = {}

local OBJTYPE_CREATURE = 0
local OBJTYPE_QUEST = 2
local OBJTYPE_ITEM = 3
local QUEST_INVALID_FLAG = 8

local function TextContainsAny(text, needles)
    text = strlower(tostring(text or ""))
    for i = 1, #needles do
        if text:find(needles[i], 1, true) then
            return true
        end
    end
    return false
end

local function strtrim(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local SRC_QUEST_REWARD = 2
local SRC_VENDOR = 9
local ITEMLOC_SORT_CHANCE = 4
local SRC_CRAFT_FLAGS = {
    [5] = true,
    [6] = true,
    [7] = true,
    [8] = true,
    [10] = true,
    [11] = true,
    [12] = true,
    [13] = true,
}

local ITEMLOC_SRC_CREATURE = 1

local function ItemLocRowIsNpcDrop(srcType, objType, objName)
    local st = strlower(tostring(srcType or ""))
    local ot = strlower(tostring(objType or ""))
    local nm = strlower(tostring(objName or ""))
    local snum = tonumber(srcType)
    local isVendorRow = snum == SRC_VENDOR or TextContainsAny(st, { "vendor" })
    if isVendorRow then
        return false
    end
    local isObjLoot = TextContainsAny(st, { "cache", "chest", "container", "object", "vendor", "fishing", "mill", "prospect", "craft", "quest", "disenchant" })
        or TextContainsAny(ot, { "cache", "chest", "container", "object", "gameobject" })
        or nm:find("cache", 1, true) or nm:find("chest", 1, true)
    if isObjLoot then
        return false
    end
    local isCreatureNpc = (tonumber(objType) == OBJTYPE_CREATURE)
        or (snum == ITEMLOC_SRC_CREATURE)
        or TextContainsAny(st, { "creature", "npc", "boss", "skin", "pickpocket" })
        or TextContainsAny(ot, { "creature", "npc", "boss" })
        or TextContainsAny(nm, { "[boss]", "boss " })
    return isCreatureNpc
end

local function IsSourceInZone(zoneId, zoneName)
    local zid = tonumber(zoneId) or 0
    if zid <= 0 then
        return false
    end
    local zname = tostring(zoneName or "")
    if zname == "" then
        return false
    end
    local selectedIsCustom = band(zid, 0x8000) ~= 0
    if Custom_GetLootZoneIdForWarpName then
        local ok, sourceZoneId = pcall(Custom_GetLootZoneIdForWarpName, zname)
        if ok and type(sourceZoneId) == "number" and sourceZoneId > 0 then
            if sourceZoneId == zid then
                return true
            end
            if selectedIsCustom and band(sourceZoneId, 0x8000) ~= 0 then
                local selectedMapId = band(zid, 0x03FF)
                local sourceMapId = band(sourceZoneId, 0x03FF)
                if selectedMapId > 0 and sourceMapId > 0 and selectedMapId == sourceMapId then
                    return true
                end
            end
        end
    end
    if qtRunnerData and qtRunnerData.lootZoneIds then
        local sourceZoneId = qtRunnerData.lootZoneIds[zname]
        if type(sourceZoneId) == "number" and sourceZoneId > 0 then
            return sourceZoneId == zid
        end
    end
    return false
end

local function ItemLocSourcesShareZonePrefix5(itemId)
    if not itemId or not ItemLocGetSourceCount or not ItemLocGetSourceAt then
        return false
    end
    local c = ItemLocGetSourceCount(itemId) or 0
    if c <= 0 then
        return false
    end
    local ok, _, _, _, _, _, z = pcall(ItemLocGetSourceAt, itemId, 1)
    if not ok then
        return false
    end
    local f = strsub(tostring(z or ""), 1, 5)
    for i = 2, c do
        ok, _, _, _, _, _, z = pcall(ItemLocGetSourceAt, itemId, i)
        if not ok then
            return false
        end
        if strsub(tostring(z or ""), 1, 5) ~= f then
            return false
        end
    end
    return true
end

local function ClassifyItemDropMeta(itemId, zoneId)
    itemId = tonumber(itemId)
    zoneId = tonumber(zoneId) or 0
    local isInstanceZone = band(zoneId, 0x8000) ~= 0
    local tier = 4
    local tag = "Mixed"
    local bossHits = 0
    local srcTotal = 0
    local creatureRows = 0
    local distinctCreature = {}
    local objectHeavy = 0
    local hasQuest = false
    local hasVendor = false
    local hasCraft = false
    local allSourcesInZone = true

    if not itemId or not ItemLocGetSourceCount or not ItemLocGetSourceAt then
        return tier, tag, bossHits, srcTotal, hasQuest, hasVendor, hasCraft, false
    end

    local sortType = ItemLocGetSourceSort and ItemLocGetSourceSort(itemId) or 0
    if ItemLocSetSourceSort then
        ItemLocSetSourceSort(itemId, sortType)
    end

    local maxScan = 32
    local count = ItemLocGetSourceCount(itemId) or 0
    if count > maxScan then count = maxScan end

    for idx = 1, count do
        local ok, srcType, srcObjType, srcObjId, chance, dropsPerThousand, objName, zoneName = pcall(ItemLocGetSourceAt, itemId, idx)
        if not ok or srcType == nil then
            break
        end
        srcTotal = srcTotal + 1
        if not IsSourceInZone(zoneId, zoneName) then
            allSourcesInZone = false
        end
        local st = strlower(tostring(srcType or ""))
        local ot = strlower(tostring(srcObjType or ""))
        local nm = strlower(tostring(objName or ""))
        local snum = tonumber(srcType)
        local isVendorRow = snum == SRC_VENDOR or TextContainsAny(st, { "vendor" })

        if not isVendorRow and (snum == SRC_QUEST_REWARD or srcObjType == OBJTYPE_QUEST or TextContainsAny(st, { "quest" })) then
            hasQuest = true
        end
        if isVendorRow then
            hasVendor = true
        end
        if snum and SRC_CRAFT_FLAGS[snum] then
            hasCraft = true
        end
        if TextContainsAny(st, { "fish", "mill", "prospect", "disenchant", "crafted", "profession", "trainer", "recipe", "enchant" }) then
            hasCraft = true
        end

        local isObjLoot = TextContainsAny(st, { "cache", "chest", "container", "object", "vendor", "fishing", "mill", "prospect", "craft", "quest", "disenchant" })
            or TextContainsAny(ot, { "cache", "chest", "container", "object", "gameobject" })
            or nm:find("cache", 1, true) or nm:find("chest", 1, true)

        if ItemLocRowIsNpcDrop(srcType, srcObjType, objName) then
            creatureRows = creatureRows + 1
            local cid = tonumber(srcObjId) or 0
            if cid > 0 then
                distinctCreature[cid] = true
            end
            --[[ boss tag: ItemLocGetObjCount + instance drop-chance heuristics
            local npcLootBreadthCache = {}
            local likelyBossByBreadth = false
            if cid > 0 and ItemLocGetObjCount then
                local breadth = npcLootBreadthCache[cid]
                if breadth == nil then
                    local bCount = ItemLocGetObjCount(OBJTYPE_CREATURE, cid)
                    breadth = tonumber(bCount) or 0
                    npcLootBreadthCache[cid] = breadth
                end
                if breadth >= 25 then
                    likelyBossByBreadth = true
                end
            end
            local dropChance = tonumber(chance or 0) or 0
            local explicitBossName = nm:find("boss", 1, true) or nm:find("[boss]", 1, true)
            local veryHighChance = isInstanceZone and dropChance >= 80
            local strongBossSignal = isInstanceZone and likelyBossByBreadth and dropChance >= 10
            if explicitBossName or veryHighChance or strongBossSignal then
                bossHits = bossHits + 1
            end
            --]]
        elseif isObjLoot then
            objectHeavy = objectHeavy + 1
        end
    end

    local uniqCre = 0
    for _ in pairs(distinctCreature) do
        uniqCre = uniqCre + 1
    end

    if srcTotal <= 0 then
        tier, tag = 4, "Mixed"
    elseif bossHits >= 1 then
        if srcTotal > 6 then
            tier, tag = 3, "Trash"
        else
            tier, tag = 2, "Boss"
        end
    elseif uniqCre == 1 and creatureRows == 1 and objectHeavy == 0 and srcTotal == 1 then
        tier, tag = 1, "Unique"
    elseif creatureRows >= 1 and (uniqCre >= 4 or srcTotal >= 10) then
        tier, tag = 3, "Trash"
    elseif objectHeavy >= creatureRows and creatureRows == 0 then
        tier, tag = 4, "Mixed"
    elseif creatureRows >= 1 then
        tier, tag = 3, "Trash"
    else
        tier, tag = 4, "Mixed"
    end

    if ItemLocSourcesShareZonePrefix5(itemId) and srcTotal > 0 and bossHits < 1 and tag == "Mixed" then
        tier, tag = 1, "Unique"
    end

    local zoneOnly = srcTotal > 0 and allSourcesInZone
    return tier, tag, bossHits, srcTotal, hasQuest, hasVendor, hasCraft, zoneOnly
end

local function ItemBadgeSortRank(item)
    if item.badgeQuest then
        return 1
    end
    if item.badgeVendor then
        return 2
    end
    --[[
    if item.dropTag == "Boss" then
        return 3
    end
    --]]
    if item.dropTag == "Unique" then
        return 4
    end
    if item.dropTag == "Trash" then
        return 5
    end
    if item.badgeCraft then
        return 6
    end
    return 7
end

local function IsCustomLootZoneId(zoneId)
    zoneId = tonumber(zoneId) or 0
    return band(zoneId, 0x8000) ~= 0
end

local function BuildCustomMapZoneId(mapId, diffId)
    mapId = tonumber(mapId) or 0
    diffId = tonumber(diffId) or 0
    if mapId <= 0 then
        return nil
    end
    return bor(0x8000, band(mapId, 0x03FF), lshift(diffId, 10))
end

local function ExpandLootQueryZoneIds(zoneId)
    zoneId = tonumber(zoneId) or 0
    if zoneId <= 0 then
        return {}
    end
    return { zoneId }
end

local function MakeKey(typeId, objId)
    return tostring(typeId or -1) .. ":" .. tostring(objId or -1)
end

local MAX_REWARD_BADGE_ITEMS = 4

--[[
Quest chain "start" semantics (QuestieDB fields):
- chainSpineRootQuestId: root of the NextQuestId line — reverse index on nextQuestInChain (reference only in tooltips).
- chainEntryQuestId: prerequisite roots (preQuest*) when they name a different quest than the row; if the only root
  is the reward itself, Questie had no prereq edges so we use the nextQuestInChain spine starter instead. Several
  roots pick the nearest starter (tie: lower quest id). Empty roots → spine. TomTom / distance / .findnpc use this.
- chainPrereqRootQuestIds: prerequisite graph only — preQuestGroup (recurse all), preQuestSingle (recurse each OR branch)
  until quests with no prereqs; may be several valid entry quests. Shown when useful; reward quest id on the row is still the attunable grantor.
External SQL parity: compare quest_template.NextQuestId / PrevQuestId with Questie nextQuestInChain when auditing ambiguous reverse links.
]]

local QUEST_CHAIN_SPINE_MAX_HOPS = 384
local QUEST_CHAIN_PREREQ_MAX_NODES = 2048
local QUEST_CHAIN_TOOLTIP_MAX_PREREQ_IDS = 10

local function CopyRewardIdsLimited(src)
    if type(src) ~= "table" or #src == 0 then
        return nil
    end
    local out = {}
    local n = #src
    if n > MAX_REWARD_BADGE_ITEMS then
        n = MAX_REWARD_BADGE_ITEMS
    end
    for i = 1, n do
        out[i] = src[i]
    end
    return out
end

qtRunnerSearchData._lootZoneCatalog = nil
qtRunnerSearchData._questCompletedBootstrapDone = false
qtRunnerSearchData._zoneNameResolveCache = {}
qtRunnerSearchData._zoneNameResolveState = {}
local GuessZoneNameFromItems

function qtRunnerSearchData:GetCurrentZoneId()
    if Custom_GetCurrentZoneOur then
        return Custom_GetCurrentZoneOur() or 0
    end
    return 0
end

function qtRunnerSearchData:ResolveLootZoneIdForWarpName(zoneName)
    if not zoneName or zoneName == "" then
        return nil
    end
    if Custom_GetLootZoneIdForWarpName then
        local ok, z = pcall(Custom_GetLootZoneIdForWarpName, zoneName)
        if ok and type(z) == "number" and z > 0 then
            return z
        end
    end
    local map = qtRunnerData.lootZoneIds
    if map then
        local z = map[zoneName]
        if type(z) == "number" and z > 0 then
            return z
        end
    end
    return nil
end

local function NormalizeZoneLabel(s)
    s = strlower(tostring(s or ""))
    s = s:gsub("%b[]", " ")
    s = s:gsub("%b()", " ")
    s = s:gsub("[%p]", " ")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function DetectDifficultyFromLabel(s)
    s = strlower(tostring(s or ""))
    if s:find("mythic", 1, true) or s:find("%[m%]") then return 9 end
    if s:find("25 heroic", 1, true) or s:find("25h", 1, true) or s:find("%[25h%]") then return 8 end
    if s:find("10 heroic", 1, true) or s:find("10h", 1, true) or s:find("%[10h%]") then return 7 end
    if s:find("25 normal", 1, true) or s:find("25n", 1, true) or s:find("%[25n%]") then return 6 end
    if s:find("10 normal", 1, true) or s:find("10n", 1, true) or s:find("%[10n%]") then return 5 end
    if s:find("25man", 1, true) or s:find("25 man", 1, true) or s:find("%[25%]") then return 4 end
    if s:find("10man", 1, true) or s:find("10 man", 1, true) or s:find("%[10%]") then return 3 end
    if s:find("heroic", 1, true) or s:find("%[h%]") then return 2 end
    if s:find("normal", 1, true) or s:find("%[n%]") then return 1 end
    if s:find("%[all%]") then return 0 end
    return nil
end

local function ZoneNamesLikelyMatch(a, b)
    a = NormalizeZoneLabel(a)
    b = NormalizeZoneLabel(b)
    if a == "" or b == "" then
        return false
    end
    if a == b then
        return true
    end
    return a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil
end

function qtRunnerSearchData:DiscoverLootZoneIdByName(zoneName)
    return nil
end

function qtRunnerSearchData:ResolveLootZoneIdSmart(zoneName)
    return nil
end

function qtRunnerSearchData:InvalidateLootZoneCatalog()
    self._lootZoneCatalog = nil
    self._zoneNameResolveCache = {}
    self._zoneNameResolveState = {}
end

local function ZoneKindPriority(kind)
    if kind == "lootdb" then return 0 end
    if kind == "source" then return 1 end
    if kind == "map" then return 2 end
    return 3
end

local function AddZoneCatalogRow(catalog, zoneName, zoneId, kind, sourceWeight)
    zoneName = tostring(zoneName or ""):gsub("^%s*(.-)%s*$", "%1")
    if zoneName == "" then
        return
    end
    local row = catalog.byName[zoneName]
    if not row then
        row = {
            zoneName = zoneName,
            zoneId = nil,
            kindHint = kind or "unknown",
            sourceCount = 0,
            sourceWeight = 0,
        }
        catalog.byName[zoneName] = row
    end
    zoneId = tonumber(zoneId)
    if zoneId and zoneId > 0 then
        row.zoneId = zoneId
    end
    sourceWeight = tonumber(sourceWeight) or 1
    row.sourceWeight = row.sourceWeight + sourceWeight
    row.sourceCount = row.sourceCount + 1
    if ZoneKindPriority(kind) < ZoneKindPriority(row.kindHint) then
        row.kindHint = kind
    end
end

local function ScanItemSourceZones(itemId, catalog, maxRows)
    itemId = tonumber(itemId)
    if not itemId or itemId <= 0 or not ItemLocGetSourceCount or not ItemLocGetSourceAt then
        return
    end
    local count = ItemLocGetSourceCount(itemId) or 0
    if count <= 0 then
        return
    end
    if maxRows and count > maxRows then
        count = maxRows
    end
    for i = 1, count do
        local ok, srcType, objType, objId, chance, dropsPerThousand, objName, zoneName = pcall(ItemLocGetSourceAt, itemId, i)
        if ok and zoneName and zoneName ~= "" then
            AddZoneCatalogRow(catalog, zoneName, nil, "source", 1)
        end
    end
end

local DIFF_LABELS = {
    [0] = "All",
    [1] = "N",
    [2] = "H",
    [3] = "10",
    [4] = "25",
    [5] = "10N",
    [6] = "25N",
    [7] = "10H",
    [8] = "25H",
    [9] = "M",
}

GuessZoneNameFromItems = function(itemIds, maxItems)
    if type(itemIds) ~= "table" or not ItemLocGetSourceCount or not ItemLocGetSourceAt then
        return nil
    end
    local counts = {}
    local bestName = nil
    local bestCount = 0
    local limit = #itemIds
    if maxItems and limit > maxItems then
        limit = maxItems
    end
    for i = 1, limit do
        local itemId = tonumber(itemIds[i])
        if itemId and itemId > 0 then
            local srcCount = ItemLocGetSourceCount(itemId) or 0
            if srcCount > 8 then srcCount = 8 end
            for si = 1, srcCount do
                local ok, srcType, objType, objId, chance, dpt, objName, zoneName = pcall(ItemLocGetSourceAt, itemId, si)
                if ok and type(zoneName) == "string" then
                    zoneName = zoneName:gsub("^%s*(.-)%s*$", "%1")
                    if zoneName ~= "" then
                        local c = (counts[zoneName] or 0) + 1
                        counts[zoneName] = c
                        if c > bestCount then
                            bestCount = c
                            bestName = zoneName
                        end
                    end
                end
            end
        end
    end
    return bestName
end

local function AddDiscoveredZoneRows(catalog, baseName, mapId, diffRows, kindHint)
    baseName = baseName or ("Map " .. tostring(mapId))
    for diffId, row in pairs(diffRows) do
        if row and row.zoneId and row.zoneId > 0 then
            local suffix = DIFF_LABELS[diffId] or tostring(diffId)
            local zoneName = baseName .. " [" .. suffix .. "]"
            AddZoneCatalogRow(catalog, zoneName, row.zoneId, kindHint or "scan", row.weight or 2)
        end
    end
end

function qtRunnerSearchData:GetLootZoneCatalog()
    return {}
end

function qtRunnerSearchData:GetTrackerObjectives()
    local rows = {}
    local tracker = ItemHuntFrame and ItemHuntFrame.cele and ItemHuntFrame.cele.objArr
    if not tracker then
        return rows
    end

    for i = 1, #tracker do
        local obj = tracker[i]
        local objId = obj and obj.objId
        if objId and objId > 0 then
            tinsert(rows, {
                objType = obj.objType,
                objId = objId,
                zoneId = obj.zoneId or obj.areaId or 0,
                objText = obj.objText,
                done = obj.objDone and true or false,
            })
        end
    end
    return rows
end

function qtRunnerSearchData:GetTrackerQuestIdSet()
    local set = {}
    local objectives = self:GetTrackerObjectives()
    for i = 1, #objectives do
        local obj = objectives[i]
        if obj and obj.objType == OBJTYPE_QUEST and obj.objId and obj.objId > 0 then
            set[obj.objId] = true
        end
    end
    return set
end

function qtRunnerSearchData:_LoadQuestieDeps()
    if self._questieDepsReady then
        return self._questieReady == true
    end
    self._questieDepsReady = true
    self._questieReady = false
    if qtRunner and qtRunner.IsQuestieEnabled and not qtRunner:IsQuestieEnabled() then
        return false
    end
    local loader = rawget(_G, "QuestieLoader")
    if not loader or type(loader.ImportModule) ~= "function" then
        return false
    end
    local okDb, db = pcall(loader.ImportModule, loader, "QuestieDB")
    if not okDb or not db then
        return false
    end
    self._questieDB = db
    local okZone, zone = pcall(loader.ImportModule, loader, "ZoneDB")
    if okZone and zone then
        self._questieZoneDB = zone
    end
    local okCoords, coords = pcall(loader.ImportModule, loader, "QuestieCoords")
    if okCoords and coords then
        self._questieCoords = coords
    end
    local compat = rawget(_G, "QuestieCompat")
    if compat then
        self._questieMap = compat.C_Map
    end
    self._questieReady = true
    return true
end

function qtRunnerSearchData:_DistanceYardsQuestieWorld(starterZoneId, questX, questY)
    if not self:_LoadQuestieDeps() then
        return nil
    end
    local coords = self._questieCoords
    local cmap = self._questieMap
    local zoneDb = self._questieZoneDB
    if not coords or not coords.GetPlayerMapPosition or not cmap or not cmap.GetWorldPosFromMapPos or not zoneDb or not zoneDb.GetUiMapIdByAreaId then
        return nil
    end
    local pPos, pUi = coords.GetPlayerMapPosition()
    if not pPos or not pUi then
        return nil
    end
    local _, pWorld = cmap.GetWorldPosFromMapPos(pUi, pPos)
    if not pWorld or not pWorld.x or not pWorld.y then
        return nil
    end
    local zid = tonumber(starterZoneId)
    if not zid or zid <= 0 then
        return nil
    end
    local targetUi = zoneDb:GetUiMapIdByAreaId(zid)
    if not targetUi then
        return nil
    end
    local qx = tonumber(questX)
    local qy = tonumber(questY)
    if not qx or not qy then
        return nil
    end
    if qx > 1 or qy > 1 then
        qx = qx / 100
        qy = qy / 100
    end
    local _, qWorld = cmap.GetWorldPosFromMapPos(targetUi, { x = qx, y = qy })
    if not qWorld or not qWorld.x or not qWorld.y then
        return nil
    end
    local dx = qWorld.x - pWorld.x
    local dy = qWorld.y - pWorld.y
    return math_floor(math_sqrt(dx * dx + dy * dy) + 0.5)
end

function qtRunnerSearchData:_QuestieHasQuest(questId)
    questId = tonumber(questId)
    if not questId or questId <= 0 then
        return false
    end
    if not self:_LoadQuestieDeps() then
        return false
    end
    local db = self._questieDB
    if db and db.QuestPointers then
        return db.QuestPointers[questId] ~= nil
    end
    return true
end

function qtRunnerSearchData:_QuestieQueryQuest(questId, field)
    if not self:_QuestieHasQuest(questId) then
        return nil
    end
    local db = self._questieDB
    if not db or not db.QueryQuestSingle then
        return nil
    end
    local ok, v = pcall(function()
        return db.QueryQuestSingle(questId, field)
    end)
    if ok then
        return v
    end
    return nil
end

-- ʕ •ᴥ•ʔ Quest chain spine (nextQuestInChain reverse) + prereq roots for attunable starter routing
function qtRunnerSearchData:_EnsureQuestChainParentsIndex()
    if self._questChainParentsBuilt then
        return self._questChainParentsByNext ~= nil
    end
    self._questChainParentsBuilt = true
    self._questChainParentsByNext = {}
    if not self:_LoadQuestieDeps() then
        return false
    end
    local db = self._questieDB
    local parents = self._questChainParentsByNext
    if not db or not parents then
        return false
    end
    local pointers = db.QuestPointers
    if type(pointers) ~= "table" then
        return false
    end
    for questId in pairs(pointers) do
        local qid = tonumber(questId)
        if qid and qid > 0 then
            local nxt = tonumber(self:_QuestieQueryQuest(qid, "nextQuestInChain") or 0) or 0
            if nxt > 0 then
                local t = parents[nxt]
                if not t then
                    t = {}
                    parents[nxt] = t
                end
                t[#t + 1] = qid
            end
        end
    end
    return true
end

function qtRunnerSearchData:_QuestChainSpineRoot(rewardQuestId)
    local current = tonumber(rewardQuestId) or 0
    if current <= 0 then
        return 0
    end
    if not self:_EnsureQuestChainParentsIndex() then
        return current
    end
    local parents = self._questChainParentsByNext
    local guard = {}
    local hops = 0
    while hops < QUEST_CHAIN_SPINE_MAX_HOPS do
        hops = hops + 1
        local plist = parents[current]
        if type(plist) ~= "table" or #plist == 0 then
            break
        end
        if guard[current] then
            break
        end
        guard[current] = true
        local pick = plist[1]
        for i = 2, #plist do
            if plist[i] < pick then
                pick = plist[i]
            end
        end
        current = pick
    end
    return current
end

function qtRunnerSearchData:_QuestChainSpineStarterQuestId(rewardQuestId)
    local r = tonumber(rewardQuestId) or 0
    if r <= 0 then
        return 0
    end
    local root = self:_QuestChainSpineRoot(r)
    local rr = tonumber(root) or 0
    if rr <= 0 then
        return r
    end
    return rr
end

-- ʕ •ᴥ•ʔ Prereq-graph entry for travel; multi-root → nearest starter (duo picks one by distance)
function qtRunnerSearchData:_QuestChainTravelStarterQuestId(rewardQuestId, hintZoneId)
    local r = tonumber(rewardQuestId) or 0
    if r <= 0 then
        return 0
    end
    local hint = tonumber(hintZoneId) or 0
    if hint <= 0 then
        hint = tonumber(self:GetCurrentZoneId()) or 0
    end
    local roots = self:_QuestChainPrereqRootsList(r)
    if type(roots) ~= "table" or #roots == 0 then
        return self:_QuestChainSpineStarterQuestId(r)
    end
    if #roots == 1 then
        local only = tonumber(roots[1])
        if not only or only <= 0 then
            return self:_QuestChainSpineStarterQuestId(r)
        end
        if only ~= r then
            return only
        end
        return self:_QuestChainSpineStarterQuestId(r)
    end
    local bestQ, bestDist = nil, 1e100
    for i = 1, #roots do
        local qid = tonumber(roots[i])
        if qid and qid > 0 then
            local x, y, zid = self:_ResolveQuestStarterCoords(qid, hint)
            local sid = (zid and zid > 0) and zid or hint
            local yards = self:_DistanceYardsQuestieWorld(sid, x, y)
            local d = tonumber(yards) or 1e100
            if d < bestDist or (d == bestDist and (not bestQ or qid < bestQ)) then
                bestDist = d
                bestQ = qid
            end
        end
    end
    if bestQ then
        return bestQ
    end
    return tonumber(roots[1]) or self:_QuestChainSpineStarterQuestId(r)
end

-- ʕ •ᴥ•ʔ Collapse multiple attunable rows that share one Questie nextQuestInChain line
function qtRunnerSearchData:_QuestChainForwardMembershipFromSpine(spineRoot)
    local set = {}
    local cur = tonumber(spineRoot) or 0
    local hops = 0
    while cur and cur > 0 and hops < QUEST_CHAIN_SPINE_MAX_HOPS do
        hops = hops + 1
        set[cur] = true
        local nq = tonumber(self:_QuestieQueryQuest(cur, "nextQuestInChain") or 0) or 0
        if nq <= 0 then
            break
        end
        cur = nq
    end
    return set
end

function qtRunnerSearchData:_QuestChainLineMemberSetToLast(spineRoot, lastQuestId)
    local set = {}
    local spine = tonumber(spineRoot) or 0
    local last = tonumber(lastQuestId) or 0
    if spine <= 0 or last <= 0 then
        return set
    end
    local cur = spine
    local hops = 0
    while cur > 0 and hops < QUEST_CHAIN_SPINE_MAX_HOPS do
        hops = hops + 1
        set[cur] = true
        if cur == last then
            return set
        end
        cur = tonumber(self:_QuestieQueryQuest(cur, "nextQuestInChain") or 0) or 0
    end
    return set
end

function qtRunnerSearchData:_QuestChainOrderRankFromRoot(spineRoot, questId)
    local target = tonumber(questId) or 0
    local cur = tonumber(spineRoot) or 0
    if target <= 0 then
        return 1e9
    end
    if cur <= 0 then
        return 1e8 + target
    end
    local rank = 0
    local hops = 0
    while cur > 0 and hops < QUEST_CHAIN_SPINE_MAX_HOPS do
        hops = hops + 1
        if cur == target then
            return rank
        end
        rank = rank + 1
        cur = tonumber(self:_QuestieQueryQuest(cur, "nextQuestInChain") or 0) or 0
    end
    return 1e8 + target
end

function qtRunnerSearchData:_MergeAttunableQuestRowCluster(grp, tracked, familySpineForSort)
    tsort(grp, function(a, b)
        local da = tonumber(a.distance) or 1e99
        local db = tonumber(b.distance) or 1e99
        if da ~= db then
            return da < db
        end
        return (tonumber(a.questId) or 0) < (tonumber(b.questId) or 0)
    end)
    local best = grp[1]
    local idSeen = {}
    local orderedRewards = {}
    for i = 1, #grp do
        local qi = tonumber(grp[i].questId)
        if qi and qi > 0 and not idSeen[qi] then
            idSeen[qi] = true
            orderedRewards[#orderedRewards + 1] = qi
        end
    end
    local spine = tonumber(familySpineForSort) or tonumber(best.chainSpineRootQuestId) or 0
    if spine > 0 then
        tsort(orderedRewards, function(x, y)
            local rx = self:_QuestChainOrderRankFromRoot(spine, x)
            local ry = self:_QuestChainOrderRankFromRoot(spine, y)
            if rx ~= ry then
                return rx < ry
            end
            return x < y
        end)
    else
        tsort(orderedRewards)
    end
    local mergedItems = {}
    local itemSeen = {}
    for i = 1, #grp do
        local list = grp[i].rewardItemIds
        if type(list) == "table" then
            for k = 1, #list do
                local iid = tonumber(list[k])
                if iid and iid > 0 and not itemSeen[iid] and #mergedItems < MAX_REWARD_BADGE_ITEMS then
                    itemSeen[iid] = true
                    mergedItems[#mergedItems + 1] = iid
                end
            end
        end
    end
    local primaryQ = orderedRewards[1]
    local nameParts = {}
    for i = 1, #orderedRewards do
        local qid = orderedRewards[i]
        nameParts[#nameParts + 1] = (Custom_GetQuestName and Custom_GetQuestName(qid)) or ("Quest #" .. tostring(qid))
    end
    local combinedName = table.concat(nameParts, " → ")
    local charAtt = false
    local accountAtt = false
    local wrongF = false
    local factionBadge = best.factionBadge or ""
    for i = 1, #grp do
        if grp[i].charAttunable then
            charAtt = true
        end
        if grp[i].accountAttunable then
            accountAtt = true
        end
        if grp[i].wrongFaction then
            wrongF = true
        end
    end
    for i = 1, #grp do
        if grp[i].accountAttunable and grp[i].factionBadge and grp[i].factionBadge ~= "" then
            factionBadge = grp[i].factionBadge
            break
        end
    end
    local starterQuestId = tonumber(best.chainEntryQuestId) or primaryQ
    local attuneRank = self:_GetQuestAttuneSortRank(charAtt, accountAtt)
    return {
        questId = primaryQ,
        questName = combinedName,
        zoneId = best.zoneId,
        zoneName = best.zoneName,
        x = best.x,
        y = best.y,
        distance = best.distance,
        distanceMapPercent = best.distanceMapPercent,
        distanceYards = best.distanceYards,
        tracked = self:IsTracked(tracked, OBJTYPE_QUEST, starterQuestId),
        charAttunable = charAtt,
        accountAttunable = accountAtt,
        starterNpcName = best.starterNpcName,
        chainEntryQuestId = starterQuestId,
        chainSpineRootQuestId = best.chainSpineRootQuestId,
        chainPrereqRootQuestIds = best.chainPrereqRootQuestIds,
        chainTooltipExtra = best.chainTooltipExtra,
        rewardItemIds = mergedItems,
        rewardItemId = mergedItems[1],
        wrongFaction = wrongF,
        factionBadge = factionBadge,
        attuneRank = attuneRank,
        chainRewardQuestIds = orderedRewards,
    }
end

function qtRunnerSearchData:_CollectChainRootCandidates(rows, zoneId)
    local seen = {}
    local out = {}
    local zid = tonumber(zoneId) or 0
    for i = 1, #rows do
        local row = rows[i]
        local qid = tonumber(row and row.questId) or 0
        if qid > 0 then
            local s = tonumber(self:_QuestChainSpineRoot(qid)) or 0
            if s > 0 and not seen[s] then
                seen[s] = true
                out[#out + 1] = s
            end
            local rowSpine = tonumber(row.chainSpineRootQuestId) or 0
            if rowSpine > 0 and not seen[rowSpine] then
                seen[rowSpine] = true
                out[#out + 1] = rowSpine
            end
            local spineStart = tonumber(self:_QuestChainSpineStarterQuestId(qid)) or 0
            if spineStart > 0 and not seen[spineStart] then
                seen[spineStart] = true
                out[#out + 1] = spineStart
            end
            if zid > 0 then
                local travel = tonumber(self:_QuestChainTravelStarterQuestId(qid, zid)) or 0
                if travel > 0 and not seen[travel] then
                    seen[travel] = true
                    out[#out + 1] = travel
                end
            end
        end
    end
    tsort(out)
    return out
end

function qtRunnerSearchData:_QuestChainPickUpstreamRootForReward(rewardQuestId, candidateRoots)
    local rewardQ = tonumber(rewardQuestId) or 0
    if rewardQ <= 0 then
        return 0
    end
    if type(candidateRoots) ~= "table" or #candidateRoots == 0 then
        return tonumber(self:_QuestChainSpineRoot(rewardQ)) or rewardQ
    end
    local valid = {}
    for i = 1, #candidateRoots do
        local r = tonumber(candidateRoots[i]) or 0
        if r > 0 then
            local line = self:_QuestChainForwardMembershipFromSpine(r)
            if line[rewardQ] then
                valid[#valid + 1] = r
            end
        end
    end
    if #valid == 0 then
        return tonumber(self:_QuestChainSpineRoot(rewardQ)) or rewardQ
    end
    if #valid == 1 then
        return valid[1]
    end
    for i = 1, #valid do
        local r = valid[i]
        local upstream = true
        for j = 1, #valid do
            local s = valid[j]
            if s ~= r then
                local lineS = self:_QuestChainForwardMembershipFromSpine(s)
                if lineS[r] then
                    upstream = false
                    break
                end
            end
        end
        if upstream then
            return r
        end
    end
    return valid[1]
end

function qtRunnerSearchData:_AttunableRowApplyFamilyChainStart(row, zoneId, familyRootQuestId, tracked)
    if type(row) ~= "table" then
        return row
    end
    local fr = tonumber(familyRootQuestId) or 0
    if fr <= 0 then
        fr = tonumber(row.chainSpineRootQuestId) or tonumber(row.questId) or 0
    end
    if fr <= 0 then
        return row
    end
    local zid = tonumber(zoneId) or 0
    row.chainFamilyRootQuestId = fr
    row.chainSpineRootQuestId = fr
    local starterQuestId = tonumber(self:_QuestChainTravelStarterQuestId(fr, zid)) or fr
    row.chainEntryQuestId = starterQuestId
    row.starterNpcName = self:_ResolveQuestStarterNpcName(starterQuestId)
    local x, y, starterZoneId = self:_ResolveQuestStarterCoords(starterQuestId, zid)
    row.x = x
    row.y = y
    row.zoneId = starterZoneId or zid
    local sid = tonumber(row.zoneId) or zid
    local yardEstimate = self:_DistanceYardsQuestieWorld(sid, x, y)
    row.distance = yardEstimate or 999999999
    row.distanceYards = yardEstimate
    local primaryReward = tonumber(row.questId) or 0
    row.chainPrereqRootQuestIds = self:_QuestChainPrereqRootsList(primaryReward)
    row.chainTooltipExtra = self:GetQuestChainTooltipExtra(fr, primaryReward, row.chainPrereqRootQuestIds)
    row.tracked = self:IsTracked(tracked, OBJTYPE_QUEST, starterQuestId)
    return row
end

function qtRunnerSearchData:_CollapseAttunableQuestRowsByFamily(rows, tracked, zoneId)
    if type(rows) ~= "table" or #rows == 0 then
        return rows
    end
    local candidates = self:_CollectChainRootCandidates(rows, zoneId)
    local n = #rows
    local keys = {}
    for i = 1, n do
        keys[i] = self:_QuestChainPickUpstreamRootForReward(rows[i].questId, candidates)
    end
    if n == 1 then
        return { self:_AttunableRowApplyFamilyChainStart(rows[1], zoneId, keys[1], tracked) }
    end
    local parent = {}
    for i = 1, n do
        parent[i] = i
    end
    local function ufind(i)
        while parent[i] ~= i do
            parent[i] = parent[parent[i]]
            i = parent[i]
        end
        return i
    end
    local function uunion(ai, bj)
        local ra, rb = ufind(ai), ufind(bj)
        if ra ~= rb then
            parent[rb] = ra
        end
    end
    for i = 1, n do
        for j = i + 1, n do
            local ki, kj = tonumber(keys[i]) or 0, tonumber(keys[j]) or 0
            if ki > 0 and ki == kj then
                uunion(i, j)
            end
        end
    end
    local clusters = {}
    for i = 1, n do
        local r = ufind(i)
        if not clusters[r] then
            clusters[r] = {}
        end
        tinsert(clusters[r], i)
    end
    local out = {}
    for _, idxList in pairs(clusters) do
        local fam = keys[idxList[1]]
        local grp = {}
        for ii = 1, #idxList do
            grp[#grp + 1] = rows[idxList[ii]]
        end
        if #grp == 1 then
            tinsert(out, self:_AttunableRowApplyFamilyChainStart(grp[1], zoneId, fam, tracked))
        else
            local merged = self:_MergeAttunableQuestRowCluster(grp, tracked, fam)
            tinsert(out, self:_AttunableRowApplyFamilyChainStart(merged, zoneId, fam, tracked))
        end
    end
    return out
end

function qtRunnerSearchData:_CollapseAttunableQuestRowsBySharedChainEntry(rows, tracked, zoneId)
    if type(rows) ~= "table" or #rows <= 1 then
        return rows
    end
    local z0 = tonumber(zoneId) or 0
    local n = #rows
    local keys = {}
    for i = 1, n do
        local r = rows[i]
        local e = tonumber(r and r.chainEntryQuestId) or 0
        local z = tonumber(r and r.zoneId) or z0
        if e > 0 then
            keys[i] = tostring(z) .. ":" .. tostring(e)
        else
            keys[i] = "isolated:" .. tostring(i)
        end
    end
    local parent = {}
    for i = 1, n do
        parent[i] = i
    end
    local function ufind(i)
        while parent[i] ~= i do
            parent[i] = parent[parent[i]]
            i = parent[i]
        end
        return i
    end
    local function uunion(ai, bj)
        local ra, rb = ufind(ai), ufind(bj)
        if ra ~= rb then
            parent[rb] = ra
        end
    end
    for i = 1, n do
        for j = i + 1, n do
            if keys[i] == keys[j] and strsub(keys[i], 1, 10) ~= "isolated:" then
                uunion(i, j)
            end
        end
    end
    local clusters = {}
    for i = 1, n do
        local r = ufind(i)
        if not clusters[r] then
            clusters[r] = {}
        end
        tinsert(clusters[r], i)
    end
    local out = {}
    for _, idxList in pairs(clusters) do
        local grp = {}
        for ii = 1, #idxList do
            grp[#grp + 1] = rows[idxList[ii]]
        end
        if #grp == 1 then
            tinsert(out, grp[1])
        else
            tsort(grp, function(a, b)
                local da = tonumber(a.distance) or 1e99
                local db = tonumber(b.distance) or 1e99
                if da ~= db then
                    return da < db
                end
                return (tonumber(a.questId) or 0) < (tonumber(b.questId) or 0)
            end)
            local best = grp[1]
            local famSpine = tonumber(best.chainFamilyRootQuestId) or tonumber(best.chainSpineRootQuestId) or 0
            local merged = self:_MergeAttunableQuestRowCluster(grp, tracked, famSpine > 0 and famSpine or nil)
            local entryStable = tonumber(merged.chainEntryQuestId) or tonumber(best.chainEntryQuestId) or 0
            if entryStable > 0 then
                merged = self:_AttunableRowApplyFamilyChainStart(merged, zoneId, entryStable, tracked)
            end
            local tipSeen = {}
            local tipParts = {}
            for ii = 1, #grp do
                local t = grp[ii].chainTooltipExtra
                if t and t ~= "" and not tipSeen[t] then
                    tipSeen[t] = true
                    tipParts[#tipParts + 1] = t
                end
            end
            if #tipParts > 1 then
                merged.chainTooltipExtra = table.concat(tipParts, "\n\n")
            elseif #tipParts == 1 then
                merged.chainTooltipExtra = tipParts[1]
            end
            tinsert(out, merged)
        end
    end
    return out
end

function qtRunnerSearchData:_QuestChainPrereqChildIds(questId)
    local db = self._questieDB
    if not db or not db.GetQuest or not self:_QuestieHasQuest(questId) then
        return nil
    end
    local qid = tonumber(questId) or 0
    if qid <= 0 then
        return nil
    end
    local ok, qd = pcall(function()
        return db.GetQuest(qid)
    end)
    if not ok or not qd then
        return nil
    end
    local out = {}
    if type(qd.preQuestGroup) == "table" then
        for _, v in pairs(qd.preQuestGroup) do
            local id = tonumber(v)
            if id and id > 0 then
                out[#out + 1] = id
            end
        end
    end
    if type(qd.preQuestSingle) == "table" then
        for _, v in pairs(qd.preQuestSingle) do
            local id = tonumber(v)
            if id and id > 0 then
                out[#out + 1] = id
            end
        end
    else
        local one = tonumber(qd.preQuestSingle)
        if one and one > 0 then
            out[#out + 1] = one
        end
    end
    if #out == 0 then
        return nil
    end
    return out
end

function qtRunnerSearchData:_QuestChainPrereqRootsList(rewardQuestId)
    local rootSet = {}
    local stack = {}
    local n0 = tonumber(rewardQuestId) or 0
    if n0 > 0 then
        stack[1] = n0
    end
    local visited = {}
    local nodes = 0
    while #stack > 0 and nodes < QUEST_CHAIN_PREREQ_MAX_NODES do
        local qid = stack[#stack]
        stack[#stack] = nil
        if qid and qid > 0 then
            if not visited[qid] then
                visited[qid] = true
                nodes = nodes + 1
                local kids = self:_QuestChainPrereqChildIds(qid)
                if not kids then
                    rootSet[qid] = true
                else
                    for i = 1, #kids do
                        local c = kids[i]
                        if c and c > 0 and not visited[c] then
                            stack[#stack + 1] = c
                        end
                    end
                end
            end
        end
    end
    local list = {}
    for q in pairs(rootSet) do
        list[#list + 1] = q
    end
    tsort(list)
    return list
end

function qtRunnerSearchData:GetQuestChainTooltipExtra(chainSpineRootQuestId, rewardQuestId, chainPrereqRootQuestIds)
    local spine = tonumber(chainSpineRootQuestId) or 0
    local rwd = tonumber(rewardQuestId) or 0
    local parts = {}
    if spine > 0 and rwd > 0 and spine ~= rwd then
        local n = (Custom_GetQuestName and Custom_GetQuestName(spine)) or ("#" .. tostring(spine))
        tinsert(parts, "Chain start (NextQuestId line): " .. n .. " (" .. tostring(spine) .. ")")
    end
    local plist = chainPrereqRootQuestIds
    if type(plist) == "table" and #plist > 0 then
        local lim = QUEST_CHAIN_TOOLTIP_MAX_PREREQ_IDS
        if #plist > 1 then
            local shown = {}
            for i = 1, math_min(#plist, lim) do
                local id = tonumber(plist[i])
                if id and id > 0 then
                    local n = (Custom_GetQuestName and Custom_GetQuestName(id)) or ("#" .. tostring(id))
                    shown[#shown + 1] = n .. " (" .. tostring(id) .. ")"
                end
            end
            local tail = (#plist > lim) and (" (+" .. tostring(#plist - lim) .. " more)") or ""
            tinsert(parts, "Prerequisite entry points: " .. table.concat(shown, ", ") .. tail)
        else
            local only = tonumber(plist[1])
            if only and only > 0 and only ~= rwd and only ~= spine then
                local n = (Custom_GetQuestName and Custom_GetQuestName(only)) or ("#" .. tostring(only))
                tinsert(parts, "Prerequisite root: " .. n .. " (" .. tostring(only) .. ")")
            end
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, "\n")
end

function qtRunnerSearchData:ResolveNpcDisplayName(npcId)
    npcId = tonumber(npcId)
    if not npcId or npcId <= 0 then
        return nil
    end
    local cache = self._questieNpcNameCache
    if not cache then
        cache = {}
        self._questieNpcNameCache = cache
    end
    if cache[npcId] then
        return cache[npcId]
    end
    if not self:_LoadQuestieDeps() then
        return nil
    end
    local db = self._questieDB
    if not db or not db.QueryNPCSingle then
        return nil
    end
    local name = db.QueryNPCSingle(npcId, "name")
    if name and tostring(name) ~= "" then
        local s = tostring(name)
        cache[npcId] = s
        return s
    end
    return nil
end

function qtRunnerSearchData:_GetItemAttuneFlags(itemId)
    itemId = tonumber(itemId)
    if not itemId or itemId <= 0 then
        return false, false
    end
    local accountAttunable = false
    local charAttunable = false
    if IsAttunableBySomeone then
        local ok, v = pcall(IsAttunableBySomeone, itemId)
        accountAttunable = ok and (v == true or v == 1)
    end
    if CanAttuneItemHelper then
        local ok, v = pcall(CanAttuneItemHelper, itemId)
        charAttunable = ok and (v == true or v == 1)
    end
    local attunable = accountAttunable or charAttunable
    if not attunable then
        return false, false
    end
    if GetItemAttuneProgress and GetItemAttuneForge then
        local okP, progress = pcall(GetItemAttuneProgress, itemId)
        local okF, forge = pcall(GetItemAttuneForge, itemId)
        local p = okP and tonumber(progress) or nil
        local f = okF and tonumber(forge) or nil
        if p ~= nil and p > 0 then
            return false, false
        end
        if f ~= nil and f ~= -1 then
            return false, false
        end
    end
    return charAttunable, accountAttunable
end

function qtRunnerSearchData:_GatherAttunableQuestMetaForZone(zoneId)
    local zidNum = tonumber(zoneId) or 0
    if zidNum <= 0 then
        return {}
    end
    local metaCache = self._attunableQuestMetaCache
    if not metaCache then
        metaCache = {}
        self._attunableQuestMetaCache = metaCache
    end
    local cachedAgg = metaCache[zidNum]
    if cachedAgg then
        return cachedAgg
    end
    local agg = {}
    if not self:_LoadQuestieDeps() then
        metaCache[zidNum] = agg
        return agg
    end
    local db = self._questieDB
    if not db or not db.ItemPointers or not db.QueryItemSingle then
        metaCache[zidNum] = agg
        return agg
    end
    local relCache = {}
    local function questRelatesToZone(q)
        q = tonumber(q)
        if not q or q <= 0 then
            return false
        end
        local hit = relCache[q]
        if hit ~= nil then
            return hit
        end
        hit = self:_QuestRelatedToZone(q, zidNum)
        relCache[q] = hit
        return hit
    end
    for itemId in pairs(db.ItemPointers) do
        local rewards = db.QueryItemSingle(itemId, "questRewards")
        if type(rewards) == "table" and #rewards > 0 then
            local charAttunable, accountAttunable = self:_GetItemAttuneFlags(itemId)
            if charAttunable or accountAttunable then
                for ri = 1, #rewards do
                    local questId = tonumber(rewards[ri])
                    if questId and questId > 0 and self:_QuestieHasQuest(questId) and questRelatesToZone(questId) then
                        local row = agg[questId]
                        if not row then
                            row = {
                                charAttunable = false,
                                accountAttunable = false,
                                rewardItemIds = {},
                                _rwSeen = {},
                            }
                            agg[questId] = row
                        end
                        if charAttunable then
                            row.charAttunable = true
                        end
                        if accountAttunable then
                            row.accountAttunable = true
                        end
                        if not row._rwSeen[itemId] then
                            row._rwSeen[itemId] = true
                            if #row.rewardItemIds < MAX_REWARD_BADGE_ITEMS then
                                row.rewardItemIds[#row.rewardItemIds + 1] = itemId
                            end
                            if not row.firstRewardItemId then
                                row.firstRewardItemId = itemId
                            end
                        end
                    end
                end
            end
        end
    end
    for _, row in pairs(agg) do
        row._rwSeen = nil
    end
    metaCache[zidNum] = agg
    return agg
end

function qtRunnerSearchData:ClearQuestieAttunableCache()
    self._attunableQuestMetaCache = nil
    self._questChainParentsByNext = nil
    self._questChainParentsBuilt = false
end

function qtRunnerSearchData:_QuestInZoneByQuestie(questId, zoneId)
    if not self:_QuestieHasQuest(questId) then
        return false
    end
    local db = self._questieDB
    if not db then
        return false
    end
    local z = tonumber(zoneId) or 0
    if z <= 0 then
        return false
    end
    local zoneOrSort = tonumber(self:_QuestieQueryQuest(questId, "zoneOrSort") or 0) or 0
    if zoneOrSort == z then
        return true
    end
    local extraObjectives = self:_QuestieQueryQuest(questId, "extraObjectives")
    if type(extraObjectives) == "table" then
        for i = 1, #extraObjectives do
            local objective = extraObjectives[i]
            if objective and type(objective[1]) == "table" and objective[1][z] then
                return true
            end
        end
    end
    return false
end

function qtRunnerSearchData:_QuestRelatedToZone(questId, zoneId)
    if not self:_QuestieHasQuest(questId) then
        return false
    end
    if self:_QuestInZoneByQuestie(questId, zoneId) then
        return true
    end
    if not self:_LoadQuestieDeps() then
        return false
    end
    local db = self._questieDB
    if not db or not db.GetQuest then
        return false
    end
    local maxHops = 24
    local cur = tonumber(questId)
    local hops = 0
    while cur and cur > 0 and hops < maxHops do
        hops = hops + 1
        local ok, qd = pcall(function()
            return db.GetQuest(cur)
        end)
        if not ok or not qd then
            break
        end
        local pre = qd.preQuestSingle
        if type(pre) == "table" then
            pre = pre[1]
        end
        pre = tonumber(pre)
        if (not pre or pre <= 0) and qd.preQuestGroup and qd.preQuestGroup[1] then
            pre = tonumber(qd.preQuestGroup[1])
        end
        if not pre or pre <= 0 then
            break
        end
        if not self:_QuestieHasQuest(pre) then
            break
        end
        if self:_QuestInZoneByQuestie(pre, zoneId) then
            return true
        end
        cur = pre
    end
    cur = tonumber(questId)
    hops = 0
    while cur and cur > 0 and hops < maxHops do
        hops = hops + 1
        local ok, qd = pcall(function()
            return db.GetQuest(cur)
        end)
        if not ok or not qd then
            break
        end
        local nq = tonumber(qd.nextQuestInChain)
        if not nq or nq <= 0 then
            break
        end
        if not self:_QuestieHasQuest(nq) then
            break
        end
        if self:_QuestInZoneByQuestie(nq, zoneId) then
            return true
        end
        cur = nq
    end
    return false
end

function qtRunnerSearchData:_EnsureQuestFactionMasks()
    if self._questFactionMasksReady then
        return
    end
    self._questFactionMasksReady = true
    self._questAllianceRaceMask = 0
    self._questHordeRaceMask = 0
    if not self:_LoadQuestieDeps() or not self._questieDB or not self._questieDB.raceKeys then
        return
    end
    local rk = self._questieDB.raceKeys
    local function orMask(...)
        local n = select("#", ...)
        local m = 0
        for i = 1, n do
            local v = select(i, ...)
            v = tonumber(v)
            if v then
                m = bor(m, v)
            end
        end
        return m
    end
    self._questAllianceRaceMask = orMask(rk.HUMAN, rk.DWARF, rk.NIGHT_ELF, rk.GNOME, rk.DRAENEI)
    self._questHordeRaceMask = orMask(rk.ORC, rk.UNDEAD, rk.SCOURGE, rk.TAUREN, rk.TROLL, rk.BLOOD_ELF)
end

function qtRunnerSearchData:_IsQuestForPlayerFaction(questId)
    if not self:_LoadQuestieDeps() or not self._questieDB then
        return true
    end
    local requiredRaces = self:_QuestieQueryQuest(questId, "requiredRaces")
    requiredRaces = tonumber(requiredRaces) or 0
    if requiredRaces == 0 then
        return true
    end
    local _, playerRace = UnitRace("player")
    if not playerRace then
        return true
    end
    if not self._questieRaceKeys then
        self._questieRaceKeys = self._questieDB.raceKeys
    end
    local raceKeys = self._questieRaceKeys
    if not raceKeys then
        return true
    end
    local raceMap = {
        Human = raceKeys.HUMAN,
        Orc = raceKeys.ORC,
        Dwarf = raceKeys.DWARF,
        NightElf = raceKeys.NIGHT_ELF,
        Scourge = raceKeys.UNDEAD,
        Tauren = raceKeys.TAUREN,
        Gnome = raceKeys.GNOME,
        Troll = raceKeys.TROLL,
        BloodElf = raceKeys.BLOOD_ELF,
        Draenei = raceKeys.DRAENEI,
    }
    local raceMask = raceMap[playerRace]
    if not raceMask then
        return true
    end
    return band(requiredRaces, raceMask) ~= 0
end

function qtRunnerSearchData:_QuestFactionSideBadge(questId)
    self:_EnsureQuestFactionMasks()
    if not self:_LoadQuestieDeps() or not self._questieDB then
        return ""
    end
    local requiredRaces = tonumber(self:_QuestieQueryQuest(questId, "requiredRaces")) or 0
    if requiredRaces == 0 then
        return ""
    end
    local am = tonumber(self._questAllianceRaceMask) or 0
    local hm = tonumber(self._questHordeRaceMask) or 0
    local hasA = am ~= 0 and band(requiredRaces, am) ~= 0
    local hasH = hm ~= 0 and band(requiredRaces, hm) ~= 0
    if hasA and not hasH then
        return "[A] "
    end
    if hasH and not hasA then
        return "[H] "
    end
    return ""
end

function qtRunnerSearchData:_GetQuestAttuneSortRank(charAttunable, accountAttunable)
    if charAttunable then
        return 1
    end
    if accountAttunable then
        return 2
    end
    return 3
end

function qtRunnerSearchData:_GetQuestWrongFaction(questId)
    if not self:_LoadQuestieDeps() then
        return false
    end
    local requiredRaces = self:_QuestieQueryQuest(questId, "requiredRaces")
    requiredRaces = tonumber(requiredRaces) or 0
    if requiredRaces == 0 then
        return false
    end
    return not self:_IsQuestForPlayerFaction(questId)
end

function qtRunnerSearchData:_GetQuestStarterCoordFromQuestie(questId, zoneId)
    if not self:_LoadQuestieDeps() then
        return nil
    end
    local db = self._questieDB
    if not db then
        return nil
    end
    local startedBy = self:_QuestieQueryQuest(questId, "startedBy")
    if type(startedBy) ~= "table" then
        return nil
    end
    local zid = tonumber(zoneId) or 0
    local function pickFromSpawnMap(spawns)
        if type(spawns) ~= "table" then
            return nil
        end
        local rows = spawns[zid]
        if type(rows) == "table" and rows[1] and rows[1][1] and rows[1][2] then
            return tonumber(rows[1][1]), tonumber(rows[1][2]), zid
        end
        for zoneKey, coords in pairs(spawns) do
            if type(coords) == "table" and coords[1] and coords[1][1] and coords[1][2] then
                return tonumber(coords[1][1]), tonumber(coords[1][2]), tonumber(zoneKey) or 0
            end
        end
        return nil
    end
    local npcStarts = startedBy[1]
    if type(npcStarts) == "table" and db.QueryNPCSingle then
        for _, rawNpcId in pairs(npcStarts) do
            local npcId = rawNpcId
            local spawns
            if db.QueryNPCSingle then
                local okS, s = pcall(function()
                    return db.QueryNPCSingle(npcId, "spawns")
                end)
                if okS then
                    spawns = s
                end
            end
            local x, y, foundZoneId = pickFromSpawnMap(spawns)
            if x and y and (foundZoneId == zid or foundZoneId > 0) then
                return x, y, foundZoneId
            end
        end
    end
    local objStarts = startedBy[2]
    if type(objStarts) == "table" and db.QueryObjectSingle then
        for _, rawObjId in pairs(objStarts) do
            local objId = rawObjId
            local spawns
            if db.QueryObjectSingle then
                local okS, s = pcall(function()
                    return db.QueryObjectSingle(objId, "spawns")
                end)
                if okS then
                    spawns = s
                end
            end
            local x, y, foundZoneId = pickFromSpawnMap(spawns)
            if x and y and (foundZoneId == zid or foundZoneId > 0) then
                return x, y, foundZoneId
            end
        end
    end
    return nil
end

function qtRunnerSearchData:_GetQuestStarterNpcNameFromQuestie(questId)
    if not self:_LoadQuestieDeps() then
        return nil
    end
    local db = self._questieDB
    if not db then
        return nil
    end
    local startedBy = self:_QuestieQueryQuest(questId, "startedBy")
    if type(startedBy) == "table" then
        local npcStarts = startedBy[1]
        if type(npcStarts) == "table" then
            for _, rawId in pairs(npcStarts) do
                local npcId = tonumber(rawId)
                if npcId and npcId > 0 then
                    local name = self:ResolveNpcDisplayName(npcId)
                    if name then
                        return name, npcId
                    end
                end
            end
        end
    end
    if db.GetQuest then
        local qid = tonumber(questId)
        if qid and qid > 0 then
            local okQ, q = pcall(function()
                return db.GetQuest(qid)
            end)
            if okQ and q and q.Starts and type(q.Starts.NPC) == "table" then
                local npcTbl = q.Starts.NPC
                for _, rawId in pairs(npcTbl) do
                    local npcId = tonumber(rawId)
                    if npcId and npcId > 0 then
                        local name = self:ResolveNpcDisplayName(npcId)
                        if name then
                            return name, npcId
                        end
                    end
                end
            end
        end
    end
    return nil
end

function qtRunnerSearchData:_ResolveQuestStarterCoords(questId, preferredZoneId)
    local x, y, zid = self:_GetQuestStarterCoordFromQuestie(questId, preferredZoneId)
    if x and y and zid and tonumber(zid) and tonumber(zid) > 0 then
        return x, y, zid
    end
    return nil
end

function qtRunnerSearchData:_ResolveQuestStarterNpcName(questId)
    local name = self:_GetQuestStarterNpcNameFromQuestie(questId)
    if name and name ~= "" then
        return name
    end
    return nil
end

function qtRunnerSearchData:_GetPlayerZonePosition()
    if not SetMapToCurrentZone or not GetPlayerMapPosition then
        return nil
    end
    local originalContinent = GetCurrentMapContinent and GetCurrentMapContinent() or nil
    local originalZone = GetCurrentMapZone and GetCurrentMapZone() or nil
    pcall(SetMapToCurrentZone)
    local x, y = GetPlayerMapPosition("player")
    if originalContinent and originalZone and originalContinent > 0 and originalZone > 0 and SetMapZoom then
        pcall(SetMapZoom, originalContinent, originalZone)
    end
    x = tonumber(x)
    y = tonumber(y)
    if not x or not y or (x == 0 and y == 0) then
        return nil
    end
    return x * 100, y * 100
end

function qtRunnerSearchData:_GetZoneNameByQuestie(zoneId)
    local zid = tonumber(zoneId) or 0
    if zid <= 0 then
        return nil
    end
    local zoneDb = self._questieZoneDB
    local cmap = self._questieMap
    if zoneDb and cmap and zoneDb.GetUiMapIdByAreaId then
        local uiMapId = zoneDb:GetUiMapIdByAreaId(zid)
        if uiMapId and cmap.GetMapInfo then
            local info = cmap.GetMapInfo(uiMapId)
            if info and info.name and info.name ~= "" then
                return info.name
            end
        end
    end
    return nil
end

function qtRunnerSearchData:_AddTomTomWaypointsForQuestRows(rows)
    if type(rows) ~= "table" or #rows == 0 or not TomTom then
        return 0
    end
    if qtRunner and qtRunner.IsTomTomEnabled and not qtRunner:IsTomTomEnabled() then
        return 0
    end
    local way = SlashCmdList and SlashCmdList["TOMTOM_WAY"] or nil
    if type(way) ~= "function" then
        return 0
    end
    local added = 0
    local seen = {}
    for i = 1, #rows do
        local row = rows[i]
        local x = tonumber(row and row.x)
        local y = tonumber(row and row.y)
        local zoneId = tonumber(row and row.zoneId)
        local questId = tonumber(row and row.questId)
        if x and y and zoneId and zoneId > 0 and questId and questId > 0 then
            local key = tostring(zoneId) .. ":" .. tostring(questId)
            if not seen[key] then
                seen[key] = true
                local zoneName = self:_GetZoneNameByQuestie(zoneId)
                if zoneName and zoneName ~= "" then
                    local title = (row.questName and row.questName ~= "") and row.questName or ("Quest " .. tostring(questId))
                    local cmd = string.format("%s %.1f %.1f %s", zoneName, x, y, title)
                    pcall(way, cmd)
                    added = added + 1
                end
            end
        end
    end
    return added
end

function qtRunnerSearchData:GetAttunableQuestRowsForZone(zoneId)
    local rows = {}
    if not self:_LoadQuestieDeps() then
        return rows, "questie-missing"
    end
    local attuneMeta = self:_GatherAttunableQuestMetaForZone(zoneId)
    local tracked = self:GetTrackedLookup()
    local zoneName = self:_GetZoneNameByQuestie(zoneId)
    for questId, metaRow in pairs(attuneMeta) do
        local qflags = Custom_GetQuestData and Custom_GetQuestData(questId) or nil
        local valid = (qflags ~= nil) and band(qflags, QUEST_INVALID_FLAG) == 0
        if valid then
            local completed = (Custom_GetQuestCompleted and Custom_GetQuestCompleted(questId)) and true or false
            if not completed then
                local charAttunable = metaRow and metaRow.charAttunable or false
                local accountAttunable = metaRow and metaRow.accountAttunable or false
                local wrongFaction = self:_GetQuestWrongFaction(questId)
                local factionBadge = self:_QuestFactionSideBadge(questId)
                local attuneRank = self:_GetQuestAttuneSortRank(charAttunable, accountAttunable)
                local chainSpineRootQuestId = self:_QuestChainSpineRoot(questId)
                if not chainSpineRootQuestId or chainSpineRootQuestId <= 0 then
                    chainSpineRootQuestId = questId
                end
                local chainPrereqRootQuestIds = self:_QuestChainPrereqRootsList(questId)
                local starterQuestId = self:_QuestChainTravelStarterQuestId(questId, zoneId)
                local x, y, starterZoneId = self:_ResolveQuestStarterCoords(starterQuestId, zoneId)
                local sid = starterZoneId or zoneId
                local yardEstimate = self:_DistanceYardsQuestieWorld(sid, x, y)
                local d = yardEstimate or 999999999
                tinsert(rows, {
                    questId = questId,
                    questName = (Custom_GetQuestName and Custom_GetQuestName(questId)) or ("Quest #" .. tostring(questId)),
                    zoneId = starterZoneId or zoneId,
                    zoneName = zoneName,
                    x = x,
                    y = y,
                    distance = d,
                    distanceMapPercent = nil,
                    distanceYards = yardEstimate,
                    tracked = self:IsTracked(tracked, OBJTYPE_QUEST, starterQuestId),
                    charAttunable = charAttunable,
                    accountAttunable = accountAttunable,
                    starterNpcName = self:_ResolveQuestStarterNpcName(starterQuestId),
                    chainEntryQuestId = starterQuestId,
                    chainSpineRootQuestId = chainSpineRootQuestId,
                    chainPrereqRootQuestIds = chainPrereqRootQuestIds,
                    chainTooltipExtra = self:GetQuestChainTooltipExtra(chainSpineRootQuestId, questId, chainPrereqRootQuestIds),
                    rewardItemIds = CopyRewardIdsLimited(metaRow and metaRow.rewardItemIds or nil),
                    rewardItemId = metaRow and metaRow.firstRewardItemId or nil,
                    wrongFaction = wrongFaction,
                    factionBadge = factionBadge,
                    attuneRank = attuneRank,
                })
            end
        end
    end
    rows = self:_CollapseAttunableQuestRowsByFamily(rows, tracked, zoneId)
    rows = self:_CollapseAttunableQuestRowsBySharedChainEntry(rows, tracked, zoneId)
    tsort(rows, function(a, b)
        local da = a.distance or 999999999
        local db = b.distance or 999999999
        if da ~= db then
            return da < db
        end
        local wa = a.wrongFaction and true or false
        local wb = b.wrongFaction and true or false
        if wa ~= wb then
            return not wa
        end
        local ra = a.attuneRank or 3
        local rb = b.attuneRank or 3
        if ra ~= rb then
            return ra < rb
        end
        return (a.questId or 0) < (b.questId or 0)
    end)
    return rows, "questie"
end

function qtRunnerSearchData:BulkTrackZoneAttunableQuests(zoneId)
    local tomtomActive = (TomTom ~= nil) and (not qtRunner or not qtRunner.IsTomTomEnabled or qtRunner:IsTomTomEnabled())
    local quests, source = self:GetAttunableQuestRowsForZone(zoneId)
    if source ~= "questie" then
        return nil, { source = source, added = 0, sorted = 0, waypoints = 0, tomtom = tomtomActive }
    end
    local list = {}
    for i = 1, #quests do
        local row = quests[i]
        local tid = tonumber(row.chainEntryQuestId) or tonumber(row.questId)
        if tid and tid > 0 then
            list[#list + 1] = tid
        end
    end
    local added = self:TrackQuestSet(list)
    local waypoints = self:_AddTomTomWaypointsForQuestRows(quests)
    return list, {
        source = source,
        added = added or 0,
        sorted = #quests,
        waypoints = waypoints or 0,
        tomtom = tomtomActive,
    }
end

function qtRunnerSearchData:GetTrackedLookup()
    local lookup = {}
    local tbl = Custom_GetAllTrackObjLoc and Custom_GetAllTrackObjLoc() or nil
    if not tbl then
        return lookup
    end

    for k, row in pairs(tbl) do
        local typeId, objId
        if type(k) == "number" and type(row) == "table" then
            typeId = row.typeid or row.typeId or row.objType or row[1]
            objId = row.objid or row.objId or row.id or row[2]
        elseif type(k) == "string" and type(row) == "number" then
            typeId = tonumber(k)
            objId = row
        elseif type(row) == "number" then
            typeId = k
            objId = row
        end
        if typeId ~= nil and objId ~= nil then
            lookup[MakeKey(typeId, objId)] = true
        end
    end

    return lookup
end

function qtRunnerSearchData:IsTracked(lookup, typeId, objId)
    return lookup and lookup[MakeKey(typeId, objId)] == true
end

-- GetItemAttuneForge: <0 unattuned, 0 base attuned, 1 TF, 2 WF, 3 LF
function qtRunnerSearchData:GetItemForgeLevel(itemId)
    itemId = tonumber(itemId)
    if not itemId or itemId <= 0 then return nil end
    if GetItemAttuneForge then
        local ok, v = pcall(GetItemAttuneForge, itemId)
        if ok and v ~= nil then
            local n = tonumber(v)
            if n ~= nil then return n end
        end
    end
    return nil
end

function qtRunnerSearchData:GetForgeItemTier(itemId, itemLink)
    itemId = tonumber(itemId)
    local link = itemLink
    if (link == nil or link == "") and itemId and GetItemInfo then
        link = select(2, GetItemInfo(itemId))
    end

    local function tierFromLink(L)
        if not L or L == "" then
            return nil
        end
        local AH = _G.AH
        if AH and AH.GetForgeLevelFromLink then
            local gf = AH.GetForgeLevelFromLink
            local ok, hv = pcall(gf, L)
            if not ok or hv == nil then
                ok, hv = pcall(function()
                    return AH:GetForgeLevelFromLink(L)
                end)
            end
            if (not ok or hv == nil) and type(gf) == "function" then
                ok, hv = pcall(gf, AH, L)
            end
            if ok and hv ~= nil then
                local n = tonumber(hv)
                if n == 1 or n == 2 or n == 3 then
                    return n
                end
            end
        end
        local tFunc = _G.GetItemLinkTitanforge
        if tFunc then
            local ok, v = pcall(tFunc, L)
            if ok and v ~= nil then
                local n = tonumber(v)
                if n == 1 or n == 2 or n == 3 then
                    return n
                end
            end
        end
        local forgeLinkAlts = { "GetItemLinkForgeLevel", "GetItemLinkForge", "GetItemForgeFromLink" }
        for ai = 1, #forgeLinkAlts do
            local fn = rawget(_G, forgeLinkAlts[ai])
            if type(fn) == "function" then
                local ok2, fv = pcall(fn, L)
                if ok2 and fv ~= nil then
                    local n2 = tonumber(fv)
                    if n2 == 1 or n2 == 2 or n2 == 3 then
                        return n2
                    end
                end
            end
        end
        return nil
    end

    local fromLink = tierFromLink(link)
    if fromLink then
        return fromLink
    end

    if itemId then
        local lv = tonumber(self:GetItemForgeLevel(itemId))
        if lv == 1 or lv == 2 or lv == 3 then
            return lv
        end
    end
    return nil
end

function qtRunnerSearchData:RoundAttunePct(pct)
    if pct == nil then return 0 end
    return math_floor(tonumber(pct) + 0.5)
end

function qtRunnerSearchData:ResolveItemDisplay(itemId)
    itemId = tonumber(itemId)
    if not itemId or itemId <= 0 then
        return nil, nil, "Interface\\Icons\\INV_Misc_QuestionMark", 0, 0
    end
    local name, link, texture, quality, itemLevel
    if GetItemInfo then
        local n, l, q, il, _, _, _, _, _, tex = GetItemInfo(itemId)
        name = name or n
        link = link or l
        quality = quality or tonumber(q)
        itemLevel = itemLevel or tonumber(il)
        texture = texture or tex
        if texture == "" then texture = nil end
    end
    if GetItemInfoCustom then
        local pack = {pcall(GetItemInfoCustom, itemId)}
        if pack[1] then
            name = pack[2]
            link = pack[3]
            quality = tonumber(pack[4]) or quality
            itemLevel = tonumber(pack[5]) or itemLevel
            local function isIconPath(s)
                return type(s) == "string" and s ~= "" and strfind(s, "Interface", 1, true)
            end
            local tPick = nil
            for _, idx in ipairs({11, 10, 12}) do
                if isIconPath(pack[idx]) then
                    tPick = pack[idx]
                    break
                end
            end
            if tPick then
                texture = tPick
            end
        end
    end

    if (not texture or texture == "") and GetItemIcon then
        texture = GetItemIcon(itemId)
    end
    if not texture or texture == "" then
        texture = "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    name = name or ("Item #" .. itemId)
    return name, link, texture, quality or 0, itemLevel or 0
end

local function BuildNpcCandidate(objId, objName, chance, spawnedCount, sourceIndex)
    return {
        objId = tonumber(objId),
        name = tostring(objName or ""),
        chance = tonumber(chance) or 0,
        spawnedCount = tonumber(spawnedCount) or 0,
        sourceIndex = tonumber(sourceIndex) or 0,
    }
end

local function CollectMergedCreatureSources(itemId, zoneFilterId)
    if not itemId or not ItemLocGetSourceCount or not ItemLocGetSourceAt then
        return {}
    end
    itemId = tonumber(itemId)
    if not itemId then
        return {}
    end
    local prevSort = 0
    if ItemLocGetSourceSort then
        prevSort = ItemLocGetSourceSort(itemId) or 0
    end
    if ItemLocSetSourceSort then
        ItemLocSetSourceSort(itemId, ITEMLOC_SORT_CHANCE)
    end
    local merged = {}
    local count = ItemLocGetSourceCount(itemId) or 0
    local zf = tonumber(zoneFilterId) or 0
    for i = 1, count do
        local srcType, srcObjType, srcObjId, chance, dropsPerThousand, objName, zoneName, spawnedCount =
            ItemLocGetSourceAt(itemId, i)
        if ItemLocRowIsNpcDrop(srcType, srcObjType, objName) then
            local oid = tonumber(srcObjId)
            if oid and oid > 0 then
                if zf <= 0 or IsSourceInZone(zf, zoneName) then
                    local ch = tonumber(chance) or 0
                    local sc = tonumber(spawnedCount) or 0
                    local ex = merged[oid]
                    if not ex then
                        merged[oid] = BuildNpcCandidate(oid, objName, ch, sc, i)
                    else
                        if ch > ex.chance then
                            ex.chance = ch
                            if objName and tostring(objName) ~= "" then
                                ex.name = tostring(objName)
                            end
                        end
                        if sc > ex.spawnedCount then
                            ex.spawnedCount = sc
                        end
                        if i < ex.sourceIndex then
                            ex.sourceIndex = i
                        end
                    end
                end
            end
        end
    end
    if ItemLocSetSourceSort then
        ItemLocSetSourceSort(itemId, prevSort)
    end
    local out = {}
    for _, row in pairs(merged) do
        tinsert(out, row)
    end
    return out
end

local function FirstNpcNameFromItemSources(self, itemId)
    itemId = tonumber(itemId)
    if not itemId or itemId <= 0 or not ItemLocGetSourceCount or not ItemLocGetSourceAt then
        return nil
    end
    local count = ItemLocGetSourceCount(itemId) or 0
    for i = 1, count do
        local srcType, srcObjType, srcObjId, chance, dropsPerThousand, objName =
            ItemLocGetSourceAt(itemId, i)
        if ItemLocRowIsNpcDrop(srcType, srcObjType, objName) then
            local oid = tonumber(srcObjId)
            if oid and oid > 0 then
                local q = self:ResolveNpcDisplayName(oid)
                if q then
                    return q
                end
            end
            if objName and tostring(objName) ~= "" then
                return tostring(objName)
            end
        end
    end
    return nil
end

function qtRunnerSearchData:GetItemNpcCandidates(itemId)
    return CollectMergedCreatureSources(itemId, nil)
end

function qtRunnerSearchData:GetItemNpcCandidatesForZone(itemId, zoneId)
    return CollectMergedCreatureSources(itemId, zoneId)
end

function qtRunnerSearchData:PickBestChanceNpcForItemInZone(itemId, zoneId)
    local list = self:GetItemNpcCandidatesForZone(itemId, zoneId)
    local zid = tonumber(zoneId) or 0
    if #list == 0 and zid > 0 then
        list = self:GetItemNpcCandidates(itemId)
    end
    if #list == 0 then
        return nil
    end
    tsort(list, function(a, b)
        if a.chance ~= b.chance then
            return a.chance > b.chance
        end
        if a.spawnedCount ~= b.spawnedCount then
            return a.spawnedCount > b.spawnedCount
        end
        return a.sourceIndex < b.sourceIndex
    end)
    return list[1]
end

function qtRunnerSearchData:PickBestNpcNameForItemInZone(itemId, zoneId)
    itemId = tonumber(itemId)
    if not itemId or itemId <= 0 or not ItemLocGetSourceAt then
        return nil
    end
    local best = self:PickBestChanceNpcForItemInZone(itemId, zoneId)
    if best then
        if best.objId and best.objId > 0 then
            local qname = self:ResolveNpcDisplayName(best.objId)
            if qname and qname ~= "" then
                return qname
            end
        end
        if best.name and best.name ~= "" then
            return best.name
        end
    end
    return FirstNpcNameFromItemSources(self, itemId)
end

function qtRunnerSearchData:PickBestNpcNameForItem(itemId)
    return self:PickBestNpcNameForItemInZone(itemId, nil)
end

local function PushSpawnPoint(points, mapId, x, y, z)
    mapId = tonumber(mapId)
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    if not mapId or not x or not y then
        return
    end
    tinsert(points, { mapId = mapId, x = x, y = y, z = z })
end

local function AppendQuestieSpawnMapToPoints(points, spawns)
    if type(spawns) ~= "table" then
        return
    end
    for zoneKey, coordBlock in pairs(spawns) do
        local mapId = tonumber(zoneKey) or 0
        if mapId > 0 and type(coordBlock) == "table" then
            for i = 1, #coordBlock do
                local pt = coordBlock[i]
                if type(pt) == "table" then
                    local x1, y1, z1 = pt[1], pt[2], pt[3]
                    if x1 and y1 then
                        PushSpawnPoint(points, mapId, tonumber(x1), tonumber(y1), tonumber(z1) or 0)
                    elseif pt.x and pt.y then
                        PushSpawnPoint(points, mapId, tonumber(pt.x), tonumber(pt.y), tonumber(pt.z) or 0)
                    end
                end
            end
        end
    end
end

function qtRunnerSearchData:GetNpcSpawnPoints(npcId)
    local points = {}
    npcId = tonumber(npcId)
    if not npcId or npcId <= 0 then
        return points
    end
    if not self:_LoadQuestieDeps() then
        return points
    end
    local db = self._questieDB
    if not db or not db.QueryNPCSingle then
        return points
    end
    local spawns = db.QueryNPCSingle(npcId, "spawns")
    if type(spawns) == "table" then
        AppendQuestieSpawnMapToPoints(points, spawns)
    end
    return points
end

local function NpcCandidateSort(a, b)
    if (a.near and 1 or 0) ~= (b.near and 1 or 0) then
        return a.near
    end
    if a.distance ~= b.distance then
        return a.distance < b.distance
    end
    if a.chance ~= b.chance then
        return a.chance > b.chance
    end
    if a.spawnedCount ~= b.spawnedCount then
        return a.spawnedCount > b.spawnedCount
    end
    return a.sourceIndex < b.sourceIndex
end

function qtRunnerSearchData:PickNearestNpc(candidates)
    if type(candidates) ~= "table" or #candidates == 0 then
        return nil
    end
    local ranked = {}
    for i = 1, #candidates do
        local c = candidates[i]
        local row = {
            objId = c.objId,
            name = c.name,
            chance = c.chance or 0,
            spawnedCount = c.spawnedCount or 0,
            sourceIndex = c.sourceIndex or i,
            near = false,
            distance = 999999999,
        }
        local points = self:GetNpcSpawnPoints(c.objId)
        for j = 1, #points do
            local p = points[j]
            if Custom_IsPlayerNear and Custom_IsPlayerNear(p.mapId, p.x, p.y, p.z, 30) then
                row.near = true
            end
            local d = (p.x * p.x) + (p.y * p.y)
            if d < row.distance then
                row.distance = d
            end
        end
        tinsert(ranked, row)
    end
    tsort(ranked, NpcCandidateSort)
    return ranked[1]
end

function qtRunnerSearchData:PickNearestNpcForItem(itemId)
    local candidates = self:GetItemNpcCandidates(itemId)
    return self:PickNearestNpc(candidates)
end

function qtRunnerSearchData:GetZoneQuestEntries(zoneId)
    if not self._questCompletedBootstrapDone then
        self._questCompletedBootstrapDone = true
        if QueryQuestsCompleted then
            pcall(QueryQuestsCompleted)
        end
    end
    zoneId = zoneId or self:GetCurrentZoneId()
    local tracked = self:GetTrackedLookup()
    local rows = {}
    local seen = {}
    local questieRows, source = self:GetAttunableQuestRowsForZone(zoneId)
    if source == "questie" and type(questieRows) == "table" and #questieRows > 0 then
        for i = 1, #questieRows do
            local q = questieRows[i]
            local questId = tonumber(q.questId)
            if questId and questId > 0 and not seen[questId] then
                local completed = (Custom_GetQuestCompleted and Custom_GetQuestCompleted(questId)) and true or false
                local onQuest = (Custom_IsOnQuest and Custom_IsOnQuest(questId)) and true or false
                local canAccept = ((Custom_GetQuestCanAccept and Custom_GetQuestCanAccept(questId)) or 0) > 0
                local cr = q.chainRewardQuestIds
                if type(cr) == "table" then
                    for ci = 1, #cr do
                        local rq = tonumber(cr[ci])
                        if rq and rq > 0 and rq ~= questId then
                            if Custom_IsOnQuest and Custom_IsOnQuest(rq) then
                                onQuest = true
                            end
                            if ((Custom_GetQuestCanAccept and Custom_GetQuestCanAccept(rq)) or 0) > 0 then
                                canAccept = true
                            end
                        end
                    end
                    if #cr > 1 then
                        local spine = tonumber(q.chainSpineRootQuestId) or 0
                        local lastR = tonumber(cr[#cr]) or 0
                        if spine > 0 and lastR > 0 then
                            local cov = self:_QuestChainLineMemberSetToLast(spine, lastR)
                            for midId in pairs(cov) do
                                local mq = tonumber(midId)
                                if mq then
                                    if Custom_IsOnQuest and Custom_IsOnQuest(mq) then
                                        onQuest = true
                                    end
                                    if ((Custom_GetQuestCanAccept and Custom_GetQuestCanAccept(mq)) or 0) > 0 then
                                        canAccept = true
                                    end
                                end
                            end
                        end
                    end
                end
                local chainEntryId = tonumber(q.chainEntryQuestId) or questId
                local availableChain = onQuest or canAccept
                if chainEntryId > 0 and chainEntryId ~= questId then
                    local onEntry = (Custom_IsOnQuest and Custom_IsOnQuest(chainEntryId)) and true or false
                    local canEntry = ((Custom_GetQuestCanAccept and Custom_GetQuestCanAccept(chainEntryId)) or 0) > 0
                    availableChain = onEntry or canEntry or onQuest or canAccept
                end
                local distance = q.distance
                if type(distance) ~= "number" then
                    distance = 999999999
                end
                local rewardItemId = q.rewardItemId and tonumber(q.rewardItemId) or nil
                local rewardIcon = nil
                if rewardItemId and rewardItemId > 0 then
                    local _, _, texture = self:ResolveItemDisplay(rewardItemId)
                    rewardIcon = texture
                end
                rows[#rows + 1] = {
                    typeId = OBJTYPE_QUEST,
                    objId = questId,
                    trackQuestId = chainEntryId,
                    name = q.questName or ((Custom_GetQuestName and Custom_GetQuestName(questId)) or ("Quest #" .. questId)),
                    onQuest = onQuest,
                    completed = completed,
                    canAccept = canAccept,
                    availableChain = availableChain,
                    tracked = self:IsTracked(tracked, OBJTYPE_QUEST, chainEntryId),
                    x = q.x,
                    y = q.y,
                    zoneId = q.zoneId or zoneId,
                    distance = distance,
                    distanceMapPercent = q.distanceMapPercent,
                    distanceYards = q.distanceYards,
                    distanceText = (q.distanceYards and q.distanceYards > 0) and tostring(q.distanceYards) or "--",
                    source = "questie",
                    charAttunable = q.charAttunable and true or false,
                    accountAttunable = q.accountAttunable and true or false,
                    starterNpcName = q.starterNpcName,
                    chainEntryQuestId = q.chainEntryQuestId,
                    chainSpineRootQuestId = q.chainSpineRootQuestId,
                    chainPrereqRootQuestIds = q.chainPrereqRootQuestIds,
                    chainTooltipExtra = q.chainTooltipExtra,
                    rewardItemIds = q.rewardItemIds,
                    rewardItemId = rewardItemId,
                    rewardIcon = rewardIcon,
                    wrongFaction = q.wrongFaction and true or false,
                    factionBadge = q.factionBadge or "",
                    attuneRank = tonumber(q.attuneRank) or 3,
                    chainRewardQuestIds = q.chainRewardQuestIds,
                }
                seen[questId] = true
            end
        end
    else
        -- ʕ •ᴥ•ʔ✿ Questie missing: surface every quest on the item tracker, not just current-zone rows ✿ ʕ •ᴥ•ʔ
        local objectives = self:GetTrackerObjectives()
        for i = 1, #objectives do
            local obj = objectives[i]
            if obj.objType == OBJTYPE_QUEST and obj.objId and obj.objId > 0 and not seen[obj.objId] then
                local objZone = obj.zoneId
                if objZone == 0 then
                    objZone = zoneId
                end
                local questId = obj.objId
                local qflags = Custom_GetQuestData and Custom_GetQuestData(questId) or nil
                local valid = (qflags ~= nil) and band(qflags, QUEST_INVALID_FLAG) == 0
                if valid then
                    if Custom_IsOnQuest and Custom_IsOnQuest(questId) then
                        seen[questId] = true
                    else
                        local questName = (Custom_GetQuestName and Custom_GetQuestName(questId)) or ("Quest #" .. questId)
                        local onQuest = false
                        local completed = (Custom_GetQuestCompleted and Custom_GetQuestCompleted(questId)) and true or false
                        local canAccept = ((Custom_GetQuestCanAccept and Custom_GetQuestCanAccept(questId)) or 0) > 0
                        seen[questId] = true
                        local starterQ = self:_QuestChainTravelStarterQuestId(questId, objZone)
                        local availableChain = onQuest or canAccept
                        if starterQ > 0 and starterQ ~= questId then
                            local onEntry = (Custom_IsOnQuest and Custom_IsOnQuest(starterQ)) and true or false
                            local canEntry = ((Custom_GetQuestCanAccept and Custom_GetQuestCanAccept(starterQ)) or 0) > 0
                            availableChain = onEntry or canEntry or onQuest or canAccept
                        end
                        local qx, qy, qz = self:_ResolveQuestStarterCoords(starterQ, objZone)
                        local starterNpcName = self:_ResolveQuestStarterNpcName(starterQ)
                        local sid = (qz and qz > 0) and qz or objZone
                        local distanceYards = self:_DistanceYardsQuestieWorld(sid, qx, qy)
                        local distance = distanceYards or 999999999
                        local spineRoot = self:_QuestChainSpineRoot(questId)
                        if not spineRoot or spineRoot <= 0 then
                            spineRoot = questId
                        end
                        local prereqRoots = self:_QuestChainPrereqRootsList(questId)
                        local trackQ = (starterQ and starterQ > 0) and starterQ or questId
                        tinsert(rows, {
                            typeId = OBJTYPE_QUEST,
                            objId = questId,
                            trackQuestId = trackQ,
                            name = questName,
                            onQuest = onQuest,
                            completed = completed,
                            canAccept = canAccept,
                            availableChain = availableChain,
                            tracked = self:IsTracked(tracked, OBJTYPE_QUEST, trackQ),
                            x = qx,
                            y = qy,
                            zoneId = (qz and qz > 0) and qz or objZone,
                            distance = distance,
                            distanceMapPercent = nil,
                            distanceYards = distanceYards,
                            distanceText = (distanceYards and distanceYards > 0) and tostring(distanceYards) or "--",
                            source = "tracker",
                            charAttunable = false,
                            accountAttunable = false,
                            starterNpcName = starterNpcName,
                            chainEntryQuestId = starterQ,
                            chainSpineRootQuestId = spineRoot,
                            chainPrereqRootQuestIds = prereqRoots,
                            chainTooltipExtra = self:GetQuestChainTooltipExtra(spineRoot, questId, prereqRoots),
                            rewardItemIds = nil,
                            rewardItemId = nil,
                            rewardIcon = nil,
                            wrongFaction = false,
                            factionBadge = "",
                            attuneRank = 3,
                        })
                    end
                end
            end
        end
    end
    tsort(rows, function(a, b)
        local aa = (a.availableChain or a.onQuest or a.canAccept) and 1 or 0
        local ab = (b.availableChain or b.onQuest or b.canAccept) and 1 or 0
        if aa ~= ab then return aa > ab end
        local da = tonumber(a.distance) or 999999999
        local db = tonumber(b.distance) or 999999999
        if da ~= db then return da < db end
        local wa = a.wrongFaction and true or false
        local wb = b.wrongFaction and true or false
        if wa ~= wb then return not wa end
        local ra = a.attuneRank or 3
        local rb = b.attuneRank or 3
        if ra ~= rb then return ra < rb end
        if a.completed ~= b.completed then return not a.completed end
        if a.canAccept ~= b.canAccept then return a.canAccept end
        return strlower(a.name) < strlower(b.name)
    end)
    return rows
end

function qtRunnerSearchData:SetTomTomWaypointForQuest(questId, fallbackX, fallbackY, fallbackZoneId, questName)
    if not TomTom then
        return false
    end
    if qtRunner and qtRunner.IsTomTomEnabled and not qtRunner:IsTomTomEnabled() then
        return false
    end
    local way = SlashCmdList and SlashCmdList["TOMTOM_WAY"] or nil
    if type(way) ~= "function" then
        return false
    end
    local starterQuestId = self:_QuestChainTravelStarterQuestId(questId, fallbackZoneId)
    local x, y, zoneId = self:_ResolveQuestStarterCoords(starterQuestId, fallbackZoneId)
    if not x or not y then
        x = tonumber(fallbackX)
        y = tonumber(fallbackY)
        zoneId = tonumber(fallbackZoneId)
    end
    if not x or not y or not zoneId or zoneId <= 0 then
        return false
    end
    local zoneName = self:_GetZoneNameByQuestie(zoneId)
    if not zoneName or zoneName == "" then
        return false
    end
    local title = questName or ("Quest " .. tostring(questId or ""))
    local cmd = string.format("%s %.1f %.1f %s", zoneName, x, y, title)
    pcall(way, cmd)
    return true
end

function qtRunnerSearchData:TrackQuestSet(setOrList)
    local tracked = self:GetTrackedLookup()
    if type(setOrList) ~= "table" then
        return 0
    end
    local added = 0
    if #setOrList > 0 then
        for i = 1, #setOrList do
            local questId = tonumber(setOrList[i])
            if questId and questId > 0 and not self:IsTracked(tracked, OBJTYPE_QUEST, questId) then
                if Custom_AddTrackObjLoc then
                    Custom_AddTrackObjLoc(OBJTYPE_QUEST, questId)
                    tracked[MakeKey(OBJTYPE_QUEST, questId)] = true
                    added = added + 1
                end
            end
        end
    else
        for questId, enabled in pairs(setOrList) do
            if enabled then
                local qid = tonumber(questId)
                if qid and qid > 0 and not self:IsTracked(tracked, OBJTYPE_QUEST, qid) then
                    if Custom_AddTrackObjLoc then
                        Custom_AddTrackObjLoc(OBJTYPE_QUEST, qid)
                        tracked[MakeKey(OBJTYPE_QUEST, qid)] = true
                        added = added + 1
                    end
                end
            end
        end
    end
    return added
end

function qtRunnerSearchData:BuildZoneEntries(zoneId, includeNpcSources, wantItems, wantQuests)
    local items = {}
    local itemById = {}
    local quests = {}
    local npcById = {}
    zoneId = zoneId or self:GetCurrentZoneId()
    includeNpcSources = includeNpcSources and true or false
    if wantItems == nil then
        wantItems = true
    end
    if wantQuests == nil then
        wantQuests = true
    end

    local objectives = wantItems and self:GetTrackerObjectives() or {}
    local tracked = self:GetTrackedLookup()
    local zoneAttunePctById = {}
    local zoneBaseAttunedById = {}
    local zoneAttuneSeen = {}
    local zoneAttuneCharSeen = {}
    local zoneAttuneAccountSeen = {}
    local zoneAffixIdsById = {}
    local zoneAffixPctByKey = {}
    local zoneAffixSeen = {}
    local zoneAffixCharSeen = {}
    local zoneAffixAccountSeen = {}
    local includeZoneStats = qtRunner and qtRunner.IsZoneAttuneBarEnabled and qtRunner:IsZoneAttuneBarEnabled() or false
    local includeZoneAffixes = includeZoneStats and qtRunner and qtRunner.IsZoneAttuneAffixesEnabled and qtRunner:IsZoneAttuneAffixesEnabled() or false
    local zoneAttuneStats = {
        zoneId = zoneId,
        statsEnabled = includeZoneStats,
        affixesEnabled = includeZoneAffixes,
        total = 0,
        count = 0,
        complete = 0,
        charCount = 0,
        charDoneCount = 0,
        accountCount = 0,
        accountDoneCount = 0,
        affixTotal = 0,
        affixComplete = 0,
        affixCharTotal = 0,
        affixCharDoneTotal = 0,
        affixCharComplete = 0,
        affixAccountTotal = 0,
        affixAccountDoneTotal = 0,
        affixAccountComplete = 0,
        pct = 0,
    }

    local function NormalizeZoneAttunePct(pct)
        pct = tonumber(pct)
        if pct == nil then
            return nil
        end
        if pct < 0 then
            return 0
        elseif pct > 100 then
            return 100
        end
        return pct
    end

    local function ReadZoneAttuneProgress(itemId, affixId)
        if GetItemAttuneProgress then
            local ok, progress = pcall(GetItemAttuneProgress, itemId, affixId, nil)
            local pct = ok and NormalizeZoneAttunePct(progress) or nil
            if pct ~= nil then
                return pct
            end
        end
        if GetHighestAttunePct then
            local fallbackAffixId = affixId
            if fallbackAffixId == nil then
                fallbackAffixId = -1
            end
            local ok, progress = pcall(GetHighestAttunePct, itemId, fallbackAffixId)
            return ok and NormalizeZoneAttunePct(progress) or nil
        end
        return nil
    end

    local function GetZoneAttuneHelperValue(itemId)
        if not CanAttuneItemHelper then
            return nil
        end
        local ok, value = pcall(CanAttuneItemHelper, itemId)
        return ok and tonumber(value) or nil
    end

    local function IsZoneAccountAttunable(itemId)
        if not IsAttunableBySomeone then
            return false
        end
        local ok, value = pcall(IsAttunableBySomeone, itemId)
        return ok and value and true or false
    end

    local function GetZoneAttunePct(itemId)
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 then
            return nil
        end
        local cached = zoneAttunePctById[itemId]
        if cached ~= nil then
            return cached or nil
        end
        local pct = ReadZoneAttuneProgress(itemId, nil)
        if pct == nil then
            zoneAttunePctById[itemId] = false
            return nil
        end
        zoneAttunePctById[itemId] = pct
        return pct
    end

    local function IsZoneBaseItemAttuned(itemId)
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 then
            return false
        end
        local cached = zoneBaseAttunedById[itemId]
        if cached ~= nil then
            return cached
        end
        local pct = GetZoneAttunePct(itemId)
        local isAttuned = pct ~= nil and pct >= 100
        zoneBaseAttunedById[itemId] = isAttuned
        return isAttuned
    end

    local function AddZoneAttuneProgress(itemId)
        if not includeZoneStats then
            return
        end
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 or zoneAttuneSeen[itemId] then
            return
        end
        zoneAttuneSeen[itemId] = true
        local pct = GetZoneAttunePct(itemId)
        if pct ~= nil then
            zoneAttuneStats.total = zoneAttuneStats.total + pct
            zoneAttuneStats.count = zoneAttuneStats.count + 1
            if pct >= 100 then
                zoneAttuneStats.complete = zoneAttuneStats.complete + 1
            end
        end
    end

    local function AddZoneAttuneBucket(itemId, seen, key)
        if not includeZoneStats then
            return
        end
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 or seen[itemId] then
            return
        end
        seen[itemId] = true
        if GetZoneAttunePct(itemId) ~= nil then
            zoneAttuneStats[key] = (zoneAttuneStats[key] or 0) + 1
        end
    end

    local function AddZoneAttuneBuckets(itemId)
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 or GetZoneAttunePct(itemId) == nil then
            return
        end
        local helperValue = GetZoneAttuneHelperValue(itemId)
        if helperValue == 1 then
            AddZoneAttuneBucket(itemId, zoneAttuneCharSeen, "charCount")
        elseif helperValue and helperValue < 0 then
            AddZoneAttuneBucket(itemId, zoneAttuneAccountSeen, "accountCount")
        end
    end

    local function GetZoneAffixIds(itemId)
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 then
            return nil
        end
        local cached = zoneAffixIdsById[itemId]
        if cached ~= nil then
            return cached or nil
        end
        if not GetItemAffixMask then
            zoneAffixIdsById[itemId] = false
            return nil
        end
        local ok, mask1, mask2 = pcall(GetItemAffixMask, itemId)
        if not ok then
            zoneAffixIdsById[itemId] = false
            return nil
        end
        local ids = {}
        if mask1 then
            for b = 0, 31 do
                if band(mask1, lshift(1, b)) ~= 0 then
                    ids[#ids + 1] = b + 1
                end
            end
        end
        if mask2 then
            for b = 0, 31 do
                if band(mask2, lshift(1, b)) ~= 0 then
                    ids[#ids + 1] = b + 33
                end
            end
        end
        if #ids == 0 then
            zoneAffixIdsById[itemId] = false
            return nil
        end
        zoneAffixIdsById[itemId] = ids
        return ids
    end

    local function GetZoneAffixPct(itemId, affixId)
        local key = tostring(itemId) .. ":" .. tostring(affixId)
        local cached = zoneAffixPctByKey[key]
        if cached ~= nil then
            return cached or nil
        end
        local pct = ReadZoneAttuneProgress(itemId, affixId)
        if pct == nil then
            zoneAffixPctByKey[key] = false
            return nil
        end
        zoneAffixPctByKey[key] = pct
        return pct
    end

    local function IsZoneAffixWeaponItem(itemId)
        if not GetItemInfo then
            return false
        end
        local ok, _, _, _, _, _, itemType, _, _, equipLoc = pcall(GetItemInfo, itemId)
        if not ok then
            return false
        end
        return itemType == "Weapon"
            or equipLoc == "INVTYPE_WEAPON"
            or equipLoc == "INVTYPE_2HWEAPON"
            or equipLoc == "INVTYPE_WEAPONMAINHAND"
            or equipLoc == "INVTYPE_WEAPONOFFHAND"
            or equipLoc == "INVTYPE_RANGED"
            or equipLoc == "INVTYPE_RANGEDRIGHT"
            or equipLoc == "INVTYPE_THROWN"
    end

    local function AddZoneAffixProgress(itemId, seen, totalKey, completeKey)
        if not includeZoneAffixes then
            return
        end
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 then
            return
        end
        if IsZoneAffixWeaponItem(itemId) then
            return
        end
        if not IsZoneBaseItemAttuned(itemId) then
            return
        end
        local ids = GetZoneAffixIds(itemId)
        if not ids then
            return
        end
        for i = 1, #ids do
            local affixId = ids[i]
            local key = tostring(itemId) .. ":" .. tostring(affixId)
            if not seen[key] then
                seen[key] = true
                zoneAttuneStats[totalKey] = (zoneAttuneStats[totalKey] or 0) + 1
                local pct = GetZoneAffixPct(itemId, affixId)
                if pct and pct >= 100 then
                    zoneAttuneStats[completeKey] = (zoneAttuneStats[completeKey] or 0) + 1
                end
            end
        end
    end

    local function AddZoneAffixBuckets(itemId)
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 then
            return
        end
        local helperValue = GetZoneAttuneHelperValue(itemId)
        if helperValue == 1 then
            AddZoneAffixProgress(itemId, zoneAffixCharSeen, "affixCharTotal", "affixCharComplete")
        end
        if IsZoneAccountAttunable(itemId) then
            AddZoneAffixProgress(itemId, zoneAffixAccountSeen, "affixAccountTotal", "affixAccountComplete")
        end
    end

    local function AddItem(itemId)
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 or itemById[itemId] then
            return
        end
        if ItemLocItemIsInZone and not IsCustomLootZoneId(zoneId) and not ItemLocItemIsInZone(itemId, zoneId) then
            return
        end
        local itemName, itemLink, texture, itemQuality, itemLevel = self:ResolveItemDisplay(itemId)
        local forgePct = GetZoneAttunePct(itemId)
        local forgeItemTier = self:GetForgeItemTier(itemId, itemLink)
        local hasRollForge = forgeItemTier == 1 or forgeItemTier == 2 or forgeItemTier == 3
        if forgePct ~= nil and forgePct >= 100 then
            if not hasRollForge then
                return
            end
        elseif forgePct == nil then
            if not hasRollForge then
                return
            end
        end
        local validattunable = true
        if IsAttunableBySomeone then
            validattunable = IsAttunableBySomeone(itemId) and true or false
        end
        if not validattunable and not hasRollForge then
            return
        end
        local forgeSearchOnly = hasRollForge and (forgePct == nil or forgePct >= 100)
        itemById[itemId] = true
        local forgeLevel = self:GetItemForgeLevel(itemId)
        local pctRounded = self:RoundAttunePct(forgePct)
        local hasAffixes = not IsZoneAffixWeaponItem(itemId) and GetZoneAffixIds(itemId) ~= nil
        local unattuned = (forgeLevel ~= nil and forgeLevel < 0)
            or (forgeLevel == nil and pctRounded <= 0)
        local dropTier, dropTag, bossHits, srcTotal, hasQuest, hasVendor, hasCraft, zoneOnly = ClassifyItemDropMeta(itemId, zoneId)
        local badgeAcc = false
        local canAttuneHelperOne = false
        local canAttuneHelperRaw = nil
        local itemTags1, itemTags2 = 0, 0
        if GetItemTagsCustom then
            local okTags, t1, t2 = pcall(GetItemTagsCustom, itemId)
            if okTags then
                itemTags1 = tonumber(t1) or 0
                itemTags2 = tonumber(t2) or 0
            end
        end
        local isAttunableTag = band(itemTags1, 0x40) ~= 0
        local isBop = band(itemTags2, 0x80) ~= 0
        local isBoe = not isBop
        if CanAttuneItemHelper then
            local ok, av = pcall(CanAttuneItemHelper, itemId)
            if ok then
                local n = tonumber(av)
                canAttuneHelperRaw = n
                if n ~= nil and n < 0 then
                    badgeAcc = true
                elseif n == 1 then
                    canAttuneHelperOne = true
                end
            end
        end
        tinsert(items, {
            typeId = OBJTYPE_ITEM,
            objId = itemId,
            name = itemName,
            icon = texture or "Interface\\Icons\\INV_Misc_QuestionMark",
            itemQuality = itemQuality,
            itemLevel = itemLevel,
            forgePct = forgePct or 0,
            forgePctRounded = pctRounded,
            forgeLevel = forgeLevel,
            forgeItemTier = forgeItemTier,
            hasAffixes = hasAffixes,
            unattuned = unattuned,
            canAttuneHelperOne = canAttuneHelperOne,
            canAttuneHelperRaw = canAttuneHelperRaw,
            itemTags1 = itemTags1,
            itemTags2 = itemTags2,
            isAttunableTag = isAttunableTag,
            isBop = isBop,
            isBoe = isBoe,
            validattunable = validattunable,
            tracked = self:IsTracked(tracked, OBJTYPE_ITEM, itemId),
            dropTier = dropTier,
            dropTag = dropTag,
            dropBossHits = bossHits,
            dropSrcTotal = srcTotal,
            badgeAcc = badgeAcc,
            badgeQuest = hasQuest,
            badgeVendor = hasVendor,
            badgeCraft = hasCraft,
            badgeZoneOnly = zoneOnly,
            forgeSearchOnly = forgeSearchOnly,
        })

        if includeNpcSources and ItemLocGetSourceCount and ItemLocGetSourceAt then
            local count = ItemLocGetSourceCount(itemId) or 0
            for srcIndex = 1, count do
                local srcType, srcObjType, srcObjId, chance, dropsPerThousand, objName, zoneName = ItemLocGetSourceAt(itemId, srcIndex)
                if ItemLocRowIsNpcDrop(srcType, srcObjType, objName) and srcObjId and srcObjId > 0 then
                    local npc = npcById[srcObjId]
                    if not npc then
                        local disp = self:ResolveNpcDisplayName(srcObjId)
                        npc = {
                            typeId = OBJTYPE_CREATURE,
                            objId = srcObjId,
                            name = disp or objName or ("NPC #" .. srcObjId),
                            zoneName = zoneName or "",
                            tracked = self:IsTracked(tracked, OBJTYPE_CREATURE, srcObjId),
                        }
                        npcById[srcObjId] = npc
                    end
                end
            end
        end
    end

    if wantItems then
        if ItemLocGetAllItemsInZone then
            local queryZoneIds = ExpandLootQueryZoneIds(zoneId)
            for zi = 1, #queryZoneIds do
                local queryZoneId = queryZoneIds[zi]
                if includeZoneStats then
                    local okAll, allZoneItems = pcall(ItemLocGetAllItemsInZone, queryZoneId, 0, 0, 1, 1)
                    if okAll and type(allZoneItems) == "table" then
                        for i = 1, #allZoneItems do
                            AddZoneAttuneProgress(allZoneItems[i])
                            AddZoneAffixProgress(allZoneItems[i], zoneAffixSeen, "affixTotal", "affixComplete")
                            AddZoneAffixBuckets(allZoneItems[i])
                        end
                    end
                    local okChar, charZoneItems = pcall(ItemLocGetAllItemsInZone, queryZoneId, 1, 0, 1, 1)
                    if okChar and type(charZoneItems) == "table" then
                        for i = 1, #charZoneItems do
                            AddZoneAttuneBucket(charZoneItems[i], zoneAttuneCharSeen, "charCount")
                        end
                    end
                    local okCharDone, charDoneZoneItems = pcall(ItemLocGetAllItemsInZone, queryZoneId, -1, 0, 1, 1)
                    if okCharDone and type(charDoneZoneItems) == "table" then
                        for i = 1, #charDoneZoneItems do
                            AddZoneAttuneBucket(charDoneZoneItems[i], zoneAttuneCharSeen, "charDoneCount")
                        end
                    end
                    local okAccount, accountZoneItems = pcall(ItemLocGetAllItemsInZone, queryZoneId, 0, 1, 1, 1)
                    if okAccount and type(accountZoneItems) == "table" then
                        for i = 1, #accountZoneItems do
                            AddZoneAttuneBucket(accountZoneItems[i], zoneAttuneAccountSeen, "accountCount")
                        end
                    end
                    local okAccountDone, accountDoneZoneItems = pcall(ItemLocGetAllItemsInZone, queryZoneId, 0, -1, 1, 1)
                    if okAccountDone and type(accountDoneZoneItems) == "table" then
                        for i = 1, #accountDoneZoneItems do
                            AddZoneAttuneBucket(accountDoneZoneItems[i], zoneAttuneAccountSeen, "accountDoneCount")
                        end
                    end
                end
                local ok, zoneItems = pcall(ItemLocGetAllItemsInZone, queryZoneId, 0, 0, 1, 1)
                if ok and type(zoneItems) == "table" then
                    for i = 1, #zoneItems do
                        AddZoneAttuneProgress(zoneItems[i])
                        AddZoneAffixProgress(zoneItems[i], zoneAffixSeen, "affixTotal", "affixComplete")
                        AddZoneAffixBuckets(zoneItems[i])
                        AddItem(zoneItems[i])
                    end
                end
            end
        end

        for i = 1, #objectives do
            local obj = objectives[i]
            local objZone = obj.zoneId
            if objZone == 0 then
                objZone = zoneId
            end
            if objZone == zoneId then
                if obj.objType == 1 then
                    AddZoneAttuneProgress(obj.objId)
                    AddZoneAffixProgress(obj.objId, zoneAffixSeen, "affixTotal", "affixComplete")
                    AddZoneAffixBuckets(obj.objId)
                    AddItem(obj.objId)
                end
            end
        end

        if includeNpcSources and ItemLocGetObjCount and ItemLocGetObjAt then
            for npcId, npc in pairs(npcById) do
                local npcCount = ItemLocGetObjCount(OBJTYPE_CREATURE, npcId) or 0
                for idx = 1, npcCount do
                    local srcType, itemId = ItemLocGetObjAt(OBJTYPE_CREATURE, npcId, idx)
                    AddZoneAttuneProgress(itemId)
                    AddZoneAffixProgress(itemId, zoneAffixSeen, "affixTotal", "affixComplete")
                    AddZoneAffixBuckets(itemId)
                    AddItem(itemId)
                end
            end
        end
    end

    if wantQuests then
        quests = self:GetZoneQuestEntries(zoneId)
    end

    local npcs = {}
    for _, npc in pairs(npcById) do
        tinsert(npcs, npc)
    end
    if zoneAttuneStats.count > 0 then
        zoneAttuneStats.pct = zoneAttuneStats.total / zoneAttuneStats.count
    end

    tsort(items, function(a, b)
        local ra = ItemBadgeSortRank(a)
        local rb = ItemBadgeSortRank(b)
        if ra ~= rb then
            return ra < rb
        end
        local ila = tonumber(a.itemLevel) or 0
        local ilb = tonumber(b.itemLevel) or 0
        if ila ~= ilb then
            return ila > ilb
        end
        local ta = a.dropTier or 4
        local tb = b.dropTier or 4
        if ta ~= tb then
            return ta < tb
        end
        local ba = a.dropBossHits or 0
        local bb = b.dropBossHits or 0
        if ba ~= bb then
            return ba > bb
        end
        local sa = a.dropSrcTotal or 0
        local sb = b.dropSrcTotal or 0
        if sa ~= sb then
            return sa < sb
        end
        if a.forgePct ~= b.forgePct then
            return a.forgePct > b.forgePct
        end
        return strlower(a.name) < strlower(b.name)
    end)
    tsort(quests, function(a, b)
        local pa = (a.availableChain or a.onQuest or a.canAccept) and 1 or 0
        local pb = (b.availableChain or b.onQuest or b.canAccept) and 1 or 0
        if pa ~= pb then
            return pa > pb
        end
        local da = tonumber(a.distance) or 6767676767
        local db = tonumber(b.distance) or 6767676767
        if da ~= db then return da < db end
        local wa = a.wrongFaction and true or false
        local wb = b.wrongFaction and true or false
        if wa ~= wb then return not wa end
        local ra = a.attuneRank or 3
        local rb = b.attuneRank or 3
        if ra ~= rb then return ra < rb end
        if a.completed ~= b.completed then return not a.completed end
        if a.canAccept ~= b.canAccept then return a.canAccept end
        return strlower(a.name) < strlower(b.name)
    end)
    tsort(npcs, function(a, b)
        return strlower(a.name) < strlower(b.name)
    end)

    return items, quests, npcs, zoneAttuneStats
end

function qtRunnerSearchData:ToggleTracked(typeId, objId, trackedLookup)
    local isTracked = self:IsTracked(trackedLookup or self:GetTrackedLookup(), typeId, objId)
    if isTracked then
        if Custom_RemoveTrackObjLoc then
            Custom_RemoveTrackObjLoc(typeId, objId)
        end
        return false
    end
    if Custom_AddTrackObjLoc then
        Custom_AddTrackObjLoc(typeId, objId)
    end
    return true
end

function qtRunnerSearchData:ClearTracked()
    if Custom_ClearTrackObjLoc then
        Custom_ClearTrackObjLoc()
    end
end
