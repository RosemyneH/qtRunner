local ipairs = ipairs
local pairs = pairs
local strlower = string.lower
local strfind = string.find
local tinsert = table.insert
local tsort = table.sort
local math_floor = math.floor
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
    local npcLootBreadthCache = {}

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
    if item.dropTag == "Boss" then
        return 3
    end
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

local function EstimateYardsFromMapPercent(distancePercent)
    distancePercent = tonumber(distancePercent)
    if not distancePercent then
        return nil
    end
    if distancePercent <= 0 then
        return 0
    end
    local yards = math_floor((distancePercent * 50) + 0.5)
    return yards
end

local MAX_REWARD_BADGE_ITEMS = 4

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
                local x, y, starterZoneId = self:_ResolveQuestStarterCoords(questId, zoneId)
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
                    tracked = self:IsTracked(tracked, OBJTYPE_QUEST, questId),
                    charAttunable = charAttunable,
                    accountAttunable = accountAttunable,
                    starterNpcName = self:_ResolveQuestStarterNpcName(questId),
                    rewardItemIds = CopyRewardIdsLimited(metaRow and metaRow.rewardItemIds or nil),
                    rewardItemId = metaRow and metaRow.firstRewardItemId or nil,
                    wrongFaction = wrongFaction,
                    factionBadge = factionBadge,
                    attuneRank = attuneRank,
                })
            end
        end
    end
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
    local quests, source = self:GetAttunableQuestRowsForZone(zoneId)
    if source ~= "questie" then
        return nil, { source = source, added = 0, sorted = 0, waypoints = 0, tomtom = (TomTom ~= nil) }
    end
    local list = {}
    for i = 1, #quests do
        list[#list + 1] = quests[i].questId
    end
    local added = self:TrackQuestSet(list)
    local waypoints = self:_AddTomTomWaypointsForQuestRows(quests)
    return list, {
        source = source,
        added = added or 0,
        sorted = #quests,
        waypoints = waypoints or 0,
        tomtom = (TomTom ~= nil),
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
                local canAccept = ((Custom_GetQuestCanAccept and Custom_GetQuestCanAccept(questId)) or 0) > 0
                local onQuest = (Custom_IsOnQuest and Custom_IsOnQuest(questId)) and true or false
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
                    name = q.questName or ((Custom_GetQuestName and Custom_GetQuestName(questId)) or ("Quest #" .. questId)),
                    onQuest = onQuest,
                    completed = completed,
                    canAccept = canAccept,
                    tracked = self:IsTracked(tracked, OBJTYPE_QUEST, questId),
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
                    rewardItemIds = q.rewardItemIds,
                    rewardItemId = rewardItemId,
                    rewardIcon = rewardIcon,
                    wrongFaction = q.wrongFaction and true or false,
                    factionBadge = q.factionBadge or "",
                    attuneRank = tonumber(q.attuneRank) or 3,
                }
                seen[questId] = true
            end
        end
    else
        local objectives = self:GetTrackerObjectives()
        for i = 1, #objectives do
            local obj = objectives[i]
            local objZone = obj.zoneId
            if objZone == 0 then
                objZone = zoneId
            end
            if objZone == zoneId and obj.objType == 2 and obj.objId and obj.objId > 0 and not seen[obj.objId] then
                local questId = obj.objId
                local qflags = Custom_GetQuestData and Custom_GetQuestData(questId) or nil
                local valid = (qflags ~= nil) and band(qflags, QUEST_INVALID_FLAG) == 0
                if valid then
                    local questName = (Custom_GetQuestName and Custom_GetQuestName(questId)) or ("Quest #" .. questId)
                    local onQuest = (Custom_IsOnQuest and Custom_IsOnQuest(questId)) and true or false
                    local completed = (Custom_GetQuestCompleted and Custom_GetQuestCompleted(questId)) and true or false
                    local canAccept = ((Custom_GetQuestCanAccept and Custom_GetQuestCanAccept(questId)) or 0) > 0
                    seen[questId] = true
                    local qx, qy, qz = self:_ResolveQuestStarterCoords(questId, objZone)
                    local starterNpcName = self:_ResolveQuestStarterNpcName(questId)
                    local sid = (qz and qz > 0) and qz or objZone
                    local distanceYards = self:_DistanceYardsQuestieWorld(sid, qx, qy)
                    local distance = distanceYards or 999999999
                    tinsert(rows, {
                        typeId = OBJTYPE_QUEST,
                        objId = questId,
                        name = questName,
                        onQuest = onQuest,
                        completed = completed,
                        canAccept = canAccept,
                        tracked = self:IsTracked(tracked, OBJTYPE_QUEST, questId),
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
    tsort(rows, function(a, b)
        local aa = (a.onQuest or a.canAccept) and 1 or 0
        local ab = (b.onQuest or b.canAccept) and 1 or 0
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
    local way = SlashCmdList and SlashCmdList["TOMTOM_WAY"] or nil
    if type(way) ~= "function" then
        return false
    end
    local x, y, zoneId = self:_ResolveQuestStarterCoords(questId, fallbackZoneId)
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

    local function AddItem(itemId)
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 or itemById[itemId] then
            return
        end
        if ItemLocItemIsInZone and not IsCustomLootZoneId(zoneId) and not ItemLocItemIsInZone(itemId, zoneId) then
            return
        end
        local itemName, itemLink, texture, itemQuality, itemLevel = self:ResolveItemDisplay(itemId)
        local forgePct = (GetHighestAttunePct and GetHighestAttunePct(itemId, -1))
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
                local ok, zoneItems = pcall(ItemLocGetAllItemsInZone, queryZoneId, 0, 1) -- do not change
                if ok and type(zoneItems) == "table" then
                    for i = 1, #zoneItems do
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
                    AddItem(obj.objId)
                end
            end
        end

        if includeNpcSources and ItemLocGetObjCount and ItemLocGetObjAt then
            for npcId, npc in pairs(npcById) do
                local npcCount = ItemLocGetObjCount(OBJTYPE_CREATURE, npcId) or 0
                for idx = 1, npcCount do
                    local srcType, itemId = ItemLocGetObjAt(OBJTYPE_CREATURE, npcId, idx)
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
        local pa = (a.onQuest or a.canAccept) and 1 or 0
        local pb = (b.onQuest or b.canAccept) and 1 or 0
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

    return items, quests, npcs
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
