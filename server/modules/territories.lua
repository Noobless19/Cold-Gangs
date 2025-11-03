local QBCore = exports['qb-core']:GetCoreObject()

ColdGangs = ColdGangs or {}
ColdGangs.Territories = ColdGangs.Territories or {}

local Territories = {}
local PlayerTerritories = {}

-- ========================
-- Boot / Schema / Loading
-- ========================

local function ensureTerritoriesSchema()
  MySQL.query([[
    CREATE TABLE IF NOT EXISTS territories (
      name VARCHAR(50) PRIMARY KEY,
      gang_id INT NULL,
      gang_name VARCHAR(100) DEFAULT 'Unclaimed',
      claimed_at DATETIME NULL,
      income_generated INT DEFAULT 0,
      influence INT DEFAULT 0,
      upgrades TEXT DEFAULT '{}',
      coords TEXT DEFAULT '{"x":0,"y":0,"z":0}',
      center_x FLOAT DEFAULT 0,
      center_y FLOAT DEFAULT 0,
      center_z FLOAT DEFAULT 0,
      value INT DEFAULT 1000,
      contested TINYINT DEFAULT 0,
      contested_by INT NULL,
      color_hex VARCHAR(10) DEFAULT '#808080',
      zone_points LONGTEXT DEFAULT '[]',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  ]])
end

local function ensureFrontsSchema()
  MySQL.query([[
    CREATE TABLE IF NOT EXISTS gang_fronts (
      territory_name VARCHAR(50) PRIMARY KEY,
      gang_id INT NULL,
      gang_name VARCHAR(100) NULL,
      front_type VARCHAR(50) NOT NULL,
      label VARCHAR(120) NOT NULL,
      processed_today INT DEFAULT 0,
      pool_dirty INT DEFAULT 0,
      last_processed DATE NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  ]])
end

local function ensureInfluenceMapColumn()
  local ok, cols = pcall(function()
    return MySQL.query.await("SHOW COLUMNS FROM territories LIKE 'influence_map'")
  end)
  if not ok then return end
  if not cols or #cols == 0 then
    MySQL.query.await("ALTER TABLE territories ADD COLUMN influence_map LONGTEXT NULL")
    print("[cold-gangs] Added territories.influence_map column")
  end
end

local function loadFromDB()
  Territories = {}
  local rs = MySQL.query.await('SELECT * FROM territories', {})
  for _, row in ipairs(rs or {}) do
    local infl_map = {}
    if row.influence_map then
      if type(row.influence_map) == "string" then
        local okj, parsed = pcall(json.decode, row.influence_map)
        if okj and type(parsed) == "table" then infl_map = parsed end
      elseif type(row.influence_map) == "table" then
        infl_map = row.influence_map
      end
    end

    local upgrades = {}
    if row.upgrades then
      local okj, parsed = pcall(json.decode, row.upgrades)
      if okj and type(parsed) == "table" then upgrades = parsed end
    end

    local coords = { x = row.center_x or 0, y = row.center_y or 0, z = row.center_z or 30.0 }
    if row.coords then
      local okc, parsed = pcall(json.decode, row.coords)
      if okc and type(parsed) == "table" then coords = parsed end
    end

    local zone_points = {}
    if row.zone_points then
      local okp, parsed = pcall(json.decode, row.zone_points)
      if okp and type(parsed) == "table" then zone_points = parsed end
    end

    Territories[row.name] = {
      gangId = row.gang_id,
      gangName = row.gang_name or "Unclaimed",
      claimed_at = row.claimed_at,
      income_generated = row.income_generated or 0,
      influence = row.influence or 0,
      upgrades = upgrades,
      coords = coords,
      center_x = row.center_x or coords.x or 0,
      center_y = row.center_y or coords.y or 0,
      center_z = row.center_z or coords.z or 0,
      value = row.value or 1000,
      contested = row.contested == 1,
      contestedBy = row.contested_by,
      colorHex = row.color_hex or '#808080',
      zone_points = zone_points,
      influence_map = infl_map
    }
  end

  TriggerClientEvent('cold-gangs:client:SyncTerritories', -1, Territories)
end

-- ============================
-- Bridge to businesses fronts
-- Forward declarations used by the bridge (bound later)
-- ============================
local getFrontConfigForTerritory
local labelFor
local coordsFor

-- Map our front config to businesses' columns
local function _frontDefaultsFor(territoryName)
  local cfg = getFrontConfigForTerritory and getFrontConfigForTerritory(territoryName) or nil
  if not cfg then return nil end
  local ft = cfg.def or {}
  return {
    ref   = territoryName,                         -- unique, stable ref per territory
    label = cfg.label or labelFor(territoryName),  -- display label
    rate  = tonumber(ft.processingRate)  or 0.20,  -- laundering_rate
    fee   = tonumber(ft.processingFee)   or 0.05,  -- laundering_fee
    cap   = tonumber(ft.dailyCap)        or 250000 -- daily_cap
  }
end

-- Upsert a cold_gang_fronts row from territory ownership and ensure pool exists
local function upsertColdFrontForTerritory(name, t)
  local defaults = _frontDefaultsFor(name)
  if not defaults then return false end

  local cx, cy, cz = coordsFor(name, t)
  local locJson = json.encode({ x = cx or 0.0, y = cy or 0.0, z = cz or 0.0 })

  local existing = MySQL.query.await('SELECT id FROM cold_gang_fronts WHERE ref = ? LIMIT 1', { defaults.ref })
  if existing and existing[1] and existing[1].id then
    -- Update owner, params, and location
    MySQL.update.await([[
      UPDATE cold_gang_fronts
         SET gang_id = ?,
             label   = ?,
             laundering_rate = ?,
             laundering_fee  = ?,
             daily_cap       = ?,
             location        = ?
       WHERE id = ?
    ]], { t.gangId, defaults.label, defaults.rate, defaults.fee, defaults.cap, locJson, existing[1].id })

    -- Ensure pool row exists
    MySQL.insert.await([[
      INSERT INTO cold_gang_fronts_pool (front_id, dirty_value, processed_today)
      VALUES (?, 0, 0)
      ON DUPLICATE KEY UPDATE front_id = front_id
    ]], { existing[1].id })
    return true
  else
    -- Create new front
    local id = MySQL.insert.await([[
      INSERT INTO cold_gang_fronts
        (gang_id, ref, label, laundering_rate, laundering_fee, daily_cap, heat, security, location)
      VALUES (?, ?, ?, ?, ?, ?, 0, 1, ?)
    ]], { t.gangId, defaults.ref, defaults.label, defaults.rate, defaults.fee, defaults.cap, locJson })
    if id and id > 0 then
      MySQL.insert.await('INSERT INTO cold_gang_fronts_pool (front_id, dirty_value, processed_today) VALUES (?, 0, 0)', { id })
      return true
    end
  end
  return false
end

-- Unassign owner (keep the front instance for later reuse)
local function unassignColdFrontForTerritory(name)
  MySQL.update.await('UPDATE cold_gang_fronts SET gang_id = NULL WHERE ref = ?', { name })
end

-- Seed/align cold_gang_fronts from Territories (run at boot and after config changes)
local function ensureFrontInstancesFromTerritories()
  local touched = 0
  for name, t in pairs(Territories) do
    if getFrontConfigForTerritory(name) and t.gangId and t.gangId > 0 then
      if upsertColdFrontForTerritory(name, t) then
        touched = touched + 1
      end
    end
  end
  print(('[cold-gangs] Seeded/updated %d cold_gang_fronts from Territories'):format(touched))
  -- Ask businesses module to reload and push to clients (handled in businesses.lua)
  TriggerEvent('cold-gangs:fronts:server:Resync')
end

CreateThread(function()
  Wait(1000)
  ensureTerritoriesSchema()
  ensureInfluenceMapColumn()
  ensureFrontsSchema()
  loadFromDB()
  ensureFrontInstancesFromTerritories()
end)

-- ==========
-- Utilities
-- ==========

local function prettyLabel(code)
  if not code or code == '' then return '-' end
  local s = code:gsub('_', ' '):lower()
  return s:gsub("(%a)([%w_']*)", function(a, b) return a:upper() .. b end)
end

local function inRect(x, y, part)
  local minX = math.min(part.x1, part.x2)
  local maxX = math.max(part.x1, part.x2)
  local minY = math.min(part.y1, part.y2)
  local maxY = math.max(part.y1, part.y2)
  return x >= minX and x <= maxX and y >= minY and y <= maxY
end

local function pointInPolygon(x, y, pts)
  local inside = false
  local j = #pts
  for i = 1, #pts do
    local xi, yi = pts[i].x, pts[i].y
    local xj, yj = pts[j].x, pts[j].y
    local intersect = ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 1e-9) + xi)
    if intersect then inside = not inside end
    j = i
  end
  return inside
end

-- Defined early so coordsFor can use it
local function centerFromParts(parts)
  if type(parts) ~= 'table' or #parts == 0 then return 0.0, 0.0, 30.0 end
  local wx, wy, area = 0.0, 0.0, 0.0
  for _, r in ipairs(parts) do
    local x1, y1, x2, y2 = tonumber(r.x1), tonumber(r.y1), tonumber(r.x2), tonumber(r.y2)
    if x1 and y1 and x2 and y2 then
      local cx = (x1 + x2) / 2.0
      local cy = (y1 + y2) / 2.0
      local a = math.abs((x2 - x1) * (y2 - y1))
      if a > 0 then
        wx = wx + cx * a
        wy = wy + cy * a
        area = area + a
      end
    end
  end
  if area > 0 then return wx / area, wy / area, 30.0 end
  return 0.0, 0.0, 30.0
end

-- Assign function bodies to the forward-declared upvalues (so bridge sees locals, not globals)
getFrontConfigForTerritory = function(name)
  local map = (Config and Config.TerritoryFronts) or {}
  local def = map[name]
  if not def then return nil end
  local types = (Config and Config.FrontTypes) or {}
  local ftype = types[def.frontType]
  if not ftype then return nil end
  return {
    key   = def.frontType,
    def   = ftype,
    label = def.label or (Config.MapZones[name] and Config.MapZones[name].label) or name
  }
end

local function zoneFor(name) return (Config and Config.MapZones and Config.MapZones[name]) or nil end

labelFor = function(name)
  local z = zoneFor(name)
  return (z and z.label) or prettyLabel(name)
end

local function typeFor(name) local z = zoneFor(name); return (z and z.type) or 'residential' end

coordsFor = function(name, t)
  if t and t.coords and t.coords.x and t.coords.y then return t.coords.x, t.coords.y, t.coords.z or 30.0 end
  if t and t.center_x and t.center_y then return t.center_x, t.center_y, t.center_z or 30.0 end
  local z = zoneFor(name)
  if z and z.parts then return centerFromParts(z.parts) end
  return 0.0, 0.0, 30.0
end

local function incomeForType(typ)
  local defs = (Config and Config.Territories and Config.Territories.Types) or {}
  local row = defs[typ]
  return row and tonumber(row.baseIncome) or 0
end

local function computeIncome(name, t)
  local typ = typeFor(name)
  local base = incomeForType(typ)
  local lvl = (t and t.upgrades and t.upgrades.income) or 0
  if lvl > 0 then base = math.floor(base * (1.0 + (0.1 * lvl))) end
  return base
end

-- Influence map helpers
local function getInfluMap(t) t.influence_map = t.influence_map or {}; return t.influence_map end
local function totalInflu(map) local s=0; for _,v in pairs(map) do s = s + (tonumber(v) or 0) end; return s end

local function clampMapToMax(map)
  local cap = (Config.Influence and Config.Influence.MAX) or 500
  local s = totalInflu(map)
  if s <= cap or s <= 0 then return end
  local factor = cap / s
  for k, v in pairs(map) do
    local nv = (tonumber(v) or 0) * factor
    if nv <= 0.0001 then map[k] = nil else map[k] = nv end
  end
end

local function recalcOwner(name)
  local t = Territories[name]; if not t then return false end
  local map = getInfluMap(t)
  local topGid, topVal, secondVal = nil, 0, 0
  for gidStr, val in pairs(map) do
    local v = tonumber(val) or 0
    if v > topVal then secondVal = topVal; topVal = v; topGid = tonumber(gidStr)
    elseif v > secondVal then secondVal = v end
  end

  local mode = (Config.Influence and Config.Influence.OWNERSHIP_MODE) or "top"
  local threshold = (Config.Influence and Config.Influence.CAPTURE_THRESHOLD) or 100
  local newOwner = nil
  if mode == "threshold" then
    if topVal >= threshold then newOwner = topGid end
  else
    newOwner = (topVal > 0) and topGid or nil
  end

  local oldOwner = t.gangId
  local changed = (oldOwner ~= newOwner)

  if not changed then
    t.contested = (topVal > 0 and secondVal > 0) or false
    t.influence = topVal
    return false
  end

  t.gangId = newOwner
  if t.gangId then
    local g = MySQL.Sync.fetchAll('SELECT id, name, color FROM cold_gangs WHERE id = ?', { t.gangId })
    if g and g[1] then
      t.gangName = g[1].name
      t.colorHex = g[1].color or t.colorHex or '#808080'
    else
      t.gangName = ('Gang #%d'):format(t.gangId)
      t.colorHex = t.colorHex or '#808080'
    end
  else
    t.gangName = "Unclaimed"
    t.colorHex = '#808080'
  end

  t.contested = (topVal > 0 and secondVal > 0) or false
  t.influence = topVal
  return true
end

-- Front helpers (per-territory metadata table)

local function GrantTerritoryFront(territoryName, gangId, gangName)
  local cfg = getFrontConfigForTerritory(territoryName)
  if not cfg then return end
  MySQL.query.await([[
    INSERT INTO gang_fronts (territory_name, gang_id, gang_name, front_type, label, processed_today, pool_dirty, last_processed)
    VALUES (?, ?, ?, ?, ?, 0, 0, CURDATE())
    ON DUPLICATE KEY UPDATE
      gang_id = VALUES(gang_id),
      gang_name = VALUES(gang_name),
      front_type = VALUES(front_type),
      label = VALUES(label)
  ]], { territoryName, gangId, gangName or ("Gang #" .. tostring(gangId)), cfg.key, cfg.label })
end

local function RemoveTerritoryFront(territoryName)
  MySQL.update.await("UPDATE gang_fronts SET gang_id = NULL, gang_name = NULL WHERE territory_name = ?", { territoryName })
end

-- Steal/Decay logic

local function stealInfluence(map, gainerKey, gain, opts)
  local cfg = Config.Influence or {}
  local ratio = (cfg.STEAL ~= nil) and cfg.STEAL or 0
  if (ratio or 0) <= 0 then return end

  local amountToSteal = (tonumber(gain) or 0) * ratio
  if amountToSteal <= 0 then return end

  local targetMode = (cfg.STEAL_TARGET or "owner")
  local distribution = (cfg.STEAL_DISTRIBUTION or "owner-first")

  local candidates = {}
  local ownerKey, ownerVal = nil, 0

  for k, v in pairs(map) do
    if k ~= gainerKey then
      local val = tonumber(v) or 0
      if val > 0 then
        candidates[k] = val
        if val > ownerVal then ownerVal = val; ownerKey = k end
      end
    end
  end
  if next(candidates) == nil then return end

  local targets = {}
  if targetMode == "owner" then
    if ownerKey then targets[ownerKey] = candidates[ownerKey] end
  elseif targetMode == "others" then
    for k, v in pairs(candidates) do targets[k] = v end
  elseif targetMode == "all-nonpresent" then
    local presentSet = opts and opts.presentSet or {}
    for k, v in pairs(candidates) do
      if not presentSet[k] then targets[k] = v end
    end
    if next(targets) == nil then
      if ownerKey then targets[ownerKey] = candidates[ownerKey] end
    end
  else
    if ownerKey then targets[ownerKey] = candidates[ownerKey] end
  end

  if next(targets) == nil then return end

  local remaining = amountToSteal

  if distribution == "owner-first" and targets[ownerKey] then
    local take = math.min(remaining, targets[ownerKey])
    map[ownerKey] = (targets[ownerKey] - take) > 0 and (targets[ownerKey] - take) or nil
    remaining = remaining - take
  end

  if remaining > 0 then
    local tkeys, tsum = {}, 0
    for k, _ in pairs(targets) do
      local cur = tonumber(map[k] or 0) or 0
      if cur > 0 then
        tkeys[#tkeys+1] = k
        tsum = tsum + cur
      end
    end
    if #tkeys == 0 then return end

    if distribution == "proportional" and tsum > 0 then
      for _, k in ipairs(tkeys) do
        local cur = tonumber(map[k] or 0) or 0
        local share = remaining * (cur / tsum)
        local nv = cur - share
        map[k] = (nv > 0) and nv or nil
      end
    else
      local per = remaining / #tkeys
      for _, k in ipairs(tkeys) do
        local cur = tonumber(map[k] or 0) or 0
        local nv = cur - per
        map[k] = (nv > 0) and nv or nil
      end
    end
  end
end

local function buildInfluences(name)
  local t = Territories[name]; if not t then return {} end
  local map = getInfluMap(t)
  local out = {}
  for gidStr, val in pairs(map) do
    local gid = tonumber(gidStr)
    local v = tonumber(val) or 0
    local g = MySQL.Sync.fetchAll('SELECT name, color FROM cold_gangs WHERE id = ?', { gid })
    out[#out+1] = {
      gangId = gid,
      gangName = (g and g[1] and g[1].name) or ("Gang #"..gid),
      influence = v,
      color = (g and g[1] and g[1].color) or '#808080'
    }
  end
  table.sort(out, function(a,b) return (a.influence or 0) > (b.influence or 0) end)
  return out
end

-- ==================================
-- Territory lookup (server-side)
-- ==================================

function ColdGangs.Territories.GetTerritoryAtCoords(coords)
  for name, t in pairs(Territories) do
    local pts = t.zone_points
    if pts and type(pts) == 'table' and #pts >= 3 then
      if pointInPolygon(coords.x, coords.y, pts) then return name end
    end
  end
  for name, zone in pairs(Config.MapZones or {}) do
    if zone.parts then
      for _, p in ipairs(zone.parts) do
        if inRect(coords.x, coords.y, p) then return name end
      end
    end
  end
  return nil
end

-- ==================
-- Save territory row
-- ==================

local function saveTerritory(name)
  local t = Territories[name]
  if not t then return end

  local claimed_at_db
  if t.claimed_at == nil then
    claimed_at_db = nil
  elseif type(t.claimed_at) == "number" then
    local ts = t.claimed_at
    if ts > 9999999999 then ts = math.floor(ts / 1000) end
    claimed_at_db = os.date("!%Y-%m-%d %H:%M:%S", ts)
  elseif type(t.claimed_at) == "string" then
    claimed_at_db = t.claimed_at
  else
    claimed_at_db = nil
  end

  local upgradesJson = json.encode(t.upgrades or {})
  local coordsJson = json.encode(t.coords or {x=t.center_x or 0, y=t.center_y or 0, z=t.center_z or 30.0})
  local zoneJson = json.encode(t.zone_points or {})
  local inflJson = json.encode(t.influence_map or {})

  MySQL.query('SELECT name FROM territories WHERE name = ?', {name}, function(r)
    if r and #r > 0 then
      MySQL.query([[
        UPDATE territories SET 
          gang_id = ?, gang_name = ?, claimed_at = ?, income_generated = ?, influence = ?, 
          upgrades = ?, coords = ?, center_x = ?, center_y = ?, center_z = ?, 
          value = ?, contested = ?, contested_by = ?, color_hex = ?, zone_points = ?, influence_map = ?
        WHERE name = ?
      ]], {
        t.gangId, t.gangName or "Unclaimed", claimed_at_db, t.income_generated or 0, t.influence or 0,
        upgradesJson, coordsJson, t.center_x or 0, t.center_y or 0, t.center_z or 0,
        t.value or 1000, t.contested and 1 or 0, t.contestedBy, t.colorHex or '#808080', zoneJson, inflJson, name
      })
    else
      MySQL.query([[
        INSERT INTO territories 
          (name, gang_id, gang_name, claimed_at, income_generated, influence, upgrades, coords, center_x, center_y, center_z, value, contested, contested_by, color_hex, zone_points, influence_map)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ]], {
        name, t.gangId, t.gangName or "Unclaimed", claimed_at_db, t.income_generated or 0, t.influence or 0,
        upgradesJson, coordsJson, t.center_x or 0, t.center_y or 0, t.center_z or 0,
        t.value or 1000, t.contested and 1 or 0, t.contestedBy, t.colorHex or '#808080', zoneJson, inflJson
      })
    end
    TriggerClientEvent('cold-gangs:client:UpdateTerritory', -1, name, t)
  end)
end

-- ======================
-- Influence API / Logic
-- ======================

local function GetPlayerGangIdSafe(src)
  -- Preferred
  if ColdGangs and ColdGangs.Core and ColdGangs.Core.GetPlayerGangId then
    local ok, gid = pcall(function() return ColdGangs.Core.GetPlayerGangId(src) end)
    if ok and gid and tonumber(gid) and tonumber(gid) > 0 then return tonumber(gid) end
  end
  -- Fallbacks
  local Player = QBCore.Functions.GetPlayer(src)
  if Player and Player.PlayerData then
    local gid = Player.PlayerData.gang and Player.PlayerData.gang.id
    if gid and tonumber(gid) and tonumber(gid) > 0 then return tonumber(gid) end
    local cid = Player.PlayerData.citizenid
    if cid then
      local rs = MySQL.query.await('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ? LIMIT 1', { cid })
      if rs and rs[1] and rs[1].gang_id then return tonumber(rs[1].gang_id) end
    end
  end
  return nil
end

function ColdGangs.Territories.AddGangInfluence(territoryName, gangId, amount, activity)
  if not territoryName or not gangId or not amount then return end
  local t = Territories[territoryName]; if not t then return end

  local map = getInfluMap(t)
  local key = tostring(gangId)
  local gain = tonumber(amount) or 0
  if gain <= 0 then return end

  map[key] = (tonumber(map[key]) or 0) + gain

  stealInfluence(map, key, gain, nil)

  local decay = (Config.Influence and Config.Influence.DECAY) or 0
  if decay > 0 then
    for gidStr, v in pairs(map) do
      if gidStr ~= key then
        local nv = (tonumber(v) or 0) - decay
        if nv <= 0 then map[gidStr] = nil else map[gidStr] = nv end
      end
    end
  end

  clampMapToMax(map)
  local oldOwner = t.gangId
  local changedOwner = recalcOwner(territoryName)
  saveTerritory(territoryName)
  if changedOwner then
    TriggerClientEvent('cold-gangs:client:SyncTerritories', -1, Territories)
    TriggerEvent('cold-gangs:server:territoryChanged', territoryName, t.gangId, oldOwner)
  else
    TriggerClientEvent('cold-gangs:client:UpdateTerritory', -1, territoryName, t)
  end
end

function ColdGangs.Territories.ReduceGangInfluence(territoryName, gangId, amount, activity)
  if not territoryName or not gangId or not amount then return end
  local t = Territories[territoryName]; if not t then return end
  local map = getInfluMap(t)
  local key = tostring(gangId)
  local loss = tonumber(amount) or 0
  if loss <= 0 then return end

  local cur = tonumber(map[key]) or 0
  local nv = cur - loss
  if nv <= 0 then map[key] = nil else map[key] = nv end

  clampMapToMax(map)
  local changedOwner = recalcOwner(territoryName)
  saveTerritory(territoryName)
  if changedOwner then
    TriggerClientEvent('cold-gangs:client:SyncTerritories', -1, Territories)
  else
    TriggerClientEvent('cold-gangs:client:UpdateTerritory', -1, territoryName, t)
  end
end

-- ==================================
-- FRONT OWNERSHIP CHANGE HANDLER
-- ==================================

RegisterNetEvent('cold-gangs:server:territoryChanged', function(territoryName, newGangId, oldGangId)
  if not territoryName then return end
  if newGangId and newGangId > 0 then
    local g = MySQL.Sync.fetchAll('SELECT id, name FROM cold_gangs WHERE id = ?', { newGangId })
    local gname = (g and g[1] and g[1].name) or ("Gang #" .. tostring(newGangId))
    GrantTerritoryFront(territoryName, newGangId, gname)
    local t = Territories[territoryName]
    if t then upsertColdFrontForTerritory(territoryName, t) end
  else
    RemoveTerritoryFront(territoryName)
    unassignColdFrontForTerritory(territoryName)
  end
  TriggerEvent('cold-gangs:fronts:server:Resync')
end)

-- ===========
-- Admin tools
-- ===========

QBCore.Commands.Add("createterritory", "Create a new gang territory (Admin Only)", {
  {name="name", help="Territory name"},
  {name="label", help="Display label"}
}, false, function(source, args)
  local src = source
  if not QBCore.Functions.HasPermission(src, "god") and not QBCore.Functions.HasPermission(src, "admin") then
    TriggerClientEvent("QBCore:Notify", src, "You don't have permission to use this command.", "error")
    return
  end
  local name = args[1]
  local label = args[2] or args[1]
  if not name then
    TriggerClientEvent("QBCore:Notify", src, "Usage: /createterritory [name] [label]", "error")
    return
  end
  TriggerClientEvent("cold-gangs:client:StartZoneCreation", src, name, label)
end)

RegisterNetEvent("cold-gangs:server:SaveNewTerritory", function(name, label, points)
  local src = source
  if not QBCore.Functions.HasPermission(src, "god") and not QBCore.Functions.HasPermission(src, "admin") then
    print(("[SECURITY] %s tried to create a territory without permission."):format(GetPlayerName(src)))
    return
  end
  if not points or #points < 3 then
    TriggerClientEvent("QBCore:Notify", src, "You need at least 3 points to form a zone.", "error")
    return
  end
  local xSum, ySum, zSum = 0, 0, 0
  for _, p in ipairs(points) do
    xSum = xSum + p.x
    ySum = ySum + p.y
    zSum = zSum + (p.z or 30.0)
  end
  local center = { x = xSum / #points, y = ySum / #points, z = zSum / #points }
  Territories[name] = {
    gangId = nil,
    gangName = "Unclaimed",
    claimed_at = nil,
    income_generated = 0,
    influence = 0,
    upgrades = {},
    coords = center,
    center_x = center.x,
    center_y = center.y,
    center_z = center.z,
    value = 1000,
    contested = false,
    contestedBy = nil,
    colorHex = "#808080",
    zone_points = points,
    influence_map = {}
  }
  MySQL.insert.await([[
    INSERT INTO territories
      (name, gang_id, gang_name, claimed_at, income_generated, influence, upgrades, coords, center_x, center_y, center_z, value, contested, contested_by, color_hex, zone_points, influence_map)
    VALUES (?, NULL, 'Unclaimed', NULL, 0, 0, '{}', ?, ?, ?, ?, 1000, 0, NULL, '#808080', ?, '{}')
    ON DUPLICATE KEY UPDATE coords = VALUES(coords), center_x = VALUES(center_x), center_y = VALUES(center_y), center_z = VALUES(center_z), zone_points = VALUES(zone_points)
  ]], { name, json.encode(center), center.x, center.y, center.z, json.encode(points) })
  TriggerClientEvent("QBCore:Notify", src, ("Territory '%s' created successfully!"):format(name), "success")
  TriggerClientEvent("cold-gangs:client:SyncTerritories", -1, Territories)
end)

-- ==================
-- NUI/Tablet Callbacks
-- ==================

QBCore.Functions.CreateCallback('cold-gangs:server:GetAllTerritories', function(source, cb)
  local res = {}
  for name, t in pairs(Territories) do
    local lbl = labelFor(name)
    local typ = typeFor(name)
    local inc = computeIncome(name, t)
    res[name] = {
      name = name,
      label = lbl,
      type = typ,
      gangId = t.gangId,
      gangName = t.gangName or "Unclaimed",
      claimed_at = t.claimed_at,
      income_generated = t.income_generated or 0,
      influence = t.influence or 0,
      upgrades = t.upgrades or {},
      income = inc,
      income_rate = inc,
      colorHex = t.colorHex or '#808080',
      contested = t.contested or false,
      contestedBy = t.contestedBy or nil
    }
  end
  cb(res)
end)

QBCore.Functions.CreateCallback('cold-gangs:server:GetTerritoryDetails', function(source, cb, territoryName)
  if not territoryName or territoryName == '' then cb(nil) return end
  local t = Territories and Territories[territoryName] or nil
  if not t then cb(nil) return end

  local lbl = labelFor(territoryName)
  local typ = typeFor(territoryName)
  local inc = computeIncome(territoryName, t)
  local cx, cy, cz = coordsFor(territoryName, t)

  -- Front info
  local frontCfg = getFrontConfigForTerritory(territoryName)
  local frontRow = nil
  if frontCfg then
    local r = MySQL.query.await('SELECT gang_id, gang_name, front_type, label, processed_today, pool_dirty, last_processed FROM gang_fronts WHERE territory_name = ? LIMIT 1', { territoryName })
    frontRow = r and r[1] or nil
  end

  cb({
    name        = territoryName,
    label       = lbl,
    type        = typ,
    gangId      = t.gangId or nil,
    gangName    = t.gangName or (t.gangId and ("Gang #" .. t.gangId)) or "Unclaimed",
    contested   = t.contested or false,
    income_rate = inc,
    income      = inc,
    value       = t.value or inc or 0,
    influences  = buildInfluences(territoryName),
    coords      = { x = cx or 0.0, y = cy or 0.0, z = cz or 30.0 },
    colorHex    = t.colorHex or '#808080',
    upgrades    = t.upgrades or {},

    -- Front fields
    hasFront             = frontCfg ~= nil,
    frontType            = frontCfg and frontCfg.key or nil,
    frontTypeLabel       = frontCfg and frontCfg.def.name or nil,
    frontLabel           = (frontRow and frontRow.label) or (frontCfg and frontCfg.label) or nil,
    frontIcon            = frontCfg and frontCfg.def.icon or nil,
    frontDailyCap        = frontCfg and frontCfg.def.dailyCap or nil,
    frontProcessingRate  = frontCfg and frontCfg.def.processingRate or nil,
    frontProcessingFee   = frontCfg and frontCfg.def.processingFee or nil,
    frontHeat            = frontCfg and frontCfg.def.heatGeneration or nil,
    frontDescription     = frontCfg and frontCfg.def.description or nil,
    frontOwnerGangId     = frontRow and frontRow.gang_id or nil,
    frontOwnerGangName   = frontRow and frontRow.gang_name or nil,
    frontProcessedToday  = frontRow and frontRow.processed_today or 0,
    frontPoolDirty       = frontRow and frontRow.pool_dirty or 0
  })
end)

QBCore.Functions.CreateCallback('cold-gangs:server:GetPlayerTerritory', function(source, cb)
  local name = PlayerTerritories[source]
  if not name then cb(nil) return end
  local t = Territories[name]
  if not t then cb(nil) return end
  local zone = Config.MapZones and Config.MapZones[name] or nil
  local gangId = GetPlayerGangIdSafe(source)
  local gi = 0
  if gangId then
    local map = getInfluMap(t)
    gi = tonumber(map[tostring(gangId)] or 0) or 0
  end
  local inc = computeIncome(name, t)
  cb({
    name = name,
    label = zone and zone.label or prettyLabel(name),
    gangId = t.gangId,
    gangName = t.gangName,
    influence = t.influence or 0,
    gangInfluence = gi,
    captureThreshold = Config.Influence and Config.Influence.CAPTURE_THRESHOLD or 100,
    income_rate = inc,
    type = zone and zone.type or "residential",
    value = t.value or 1000,
    contested = t.contested or false,
    colorHex = t.colorHex or '#808080'
  })
end)

QBCore.Functions.CreateCallback('cold-gangs:server:UpgradeTerritory', function(src, cb, name, utype)
  if not name or not utype then cb(false) return end
  local gid = GetPlayerGangIdSafe(src)
  if not gid then cb(false) return end
  if not ColdGangs.Permissions or not ColdGangs.Permissions.HasGangPermission or not ColdGangs.Permissions.HasGangPermission(src, 'manageTerritories') then cb(false) return end
  local t = Territories[name]
  if not t or t.gangId ~= gid then cb(false) return end
  TriggerEvent('cold-gangs:territories:Upgrade', name, utype)
  cb(true)
end)

-- ============
-- Sync events
-- ============

RegisterNetEvent('cold-gangs:server:InfluenceActivity', function(payload)
  local src = source
  local raw = (payload and payload.type) or 'drug_sale'
  local alias = {
    spray='graffiti', spraying='graffiti', sprayed='graffiti',
    tag='graffiti', tagging='graffiti', tagged='graffiti',
    graffiti='graffiti',
    drug_sell='drug_sale', sell_drugs='drug_sale',
    processing='drug_processing', process_drugs='drug_processing',
    grow='drug_growing', growing='drug_growing'
  }
  local activity = alias[raw] or raw

  local gid = GetPlayerGangIdSafe(src)
  if not gid or gid == 0 then
    print(('[cold-gangs] InfluenceActivity ignored: no gang id | src=%s type=%s'):format(src, tostring(activity)))
    return
  end

  local ped = GetPlayerPed(src)
  if not ped or ped <= 0 then return end
  local coords = GetEntityCoords(ped)
  if not coords then return end

  local terrName = ColdGangs.Territories.GetTerritoryAtCoords(coords)
  if not terrName or terrName == '' then
    print(('[cold-gangs] InfluenceActivity ignored: not in territory | src=%s type=%s'):format(src, tostring(activity)))
    return
  end

  local gainByType = {
    drug_sale       = (Config.Influence and Config.Influence.DRUG_SALE) or 5,
    drug_growing    = (Config.Influence and Config.Influence.DRUG_GROWING) or 2,
    drug_processing = (Config.Influence and Config.Influence.PROCESSING) or 3,
    graffiti        = (Config.Influence and Config.Influence.GRAFFITI) or 10,
  }
  local amount = gainByType[activity] or 0
  if amount <= 0 then
    print(('[cold-gangs] InfluenceActivity ignored: amount=0 | src=%s type=%s'):format(src, tostring(activity)))
    return
  end

  ColdGangs.Territories.AddGangInfluence(terrName, gid, amount, activity)
  print(('[cold-gangs] +%d influence (%s) terr=%s gid=%s src=%s'):format(amount, activity, terrName, gid, src))
end)

-- Keep clients in sync when they load
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
  local src = source
  TriggerClientEvent('cold-gangs:client:SyncTerritories', src, Territories)
end)

RegisterNetEvent('QBCore:Server:OnPlayerUnload', function()
  local src = source
  PlayerTerritories[src] = nil
end)

-- ======================
-- Territory actions APIs
-- ======================

RegisterNetEvent('cold-gangs:territories:Capture', function(name)
  local src = source
  local gid = GetPlayerGangIdSafe(src)
  if not gid or not Territories[name] then return end
  if not ColdGangs.Permissions or not ColdGangs.Permissions.HasGangPermission or not ColdGangs.Permissions.HasGangPermission(src, 'manageTerritories') then return end
  local gain = (Config.Influence and Config.Influence.CAPTURE_THRESHOLD) or 100
  ColdGangs.Territories.AddGangInfluence(name, gid, gain, 'ui_capture')
end)

RegisterNetEvent('cold-gangs:territories:Defend', function(name)
  local src = source
  local gid = GetPlayerGangIdSafe(src)
  if not gid or not Territories[name] or Territories[name].gangId ~= gid then return end
  if not ColdGangs.Permissions or not ColdGangs.Permissions.HasGangPermission or not ColdGangs.Permissions.HasGangPermission(src, 'manageTerritories') then return end
  local gain = (Config.Influence and Config.Influence.DEFENSE_THRESHOLD) or 50
  ColdGangs.Territories.AddGangInfluence(name, gid, gain, 'ui_defend')
end)

-- Optional: allow clients to report their current territory (heartbeat-safe)
RegisterNetEvent('cold-gangs:server:SetPlayerTerritory', function(name)
  local src = source
  if name ~= nil and name ~= '' then
    PlayerTerritories[src] = tostring(name)
  else
    PlayerTerritories[src] = nil
  end
end)

-- =========
-- Loops
-- =========

-- Track which territory players are in (server-side) with correct player source
CreateThread(function()
  while true do
    Wait((Config.Performance and Config.Performance.territoryCheckInterval) or 10000)
    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
      local src = Player and Player.PlayerData and Player.PlayerData.source
      if src then
        local ped = GetPlayerPed(src)
        if ped and ped > 0 then
          local coords = GetEntityCoords(ped)
          local name = ColdGangs.Territories.GetTerritoryAtCoords(coords)
          if name ~= PlayerTerritories[src] then
            PlayerTerritories[src] = name
          end
        end
      end
    end
  end
end)

-- Passive income tick
CreateThread(function()
  while true do
    Wait(60000)
    for name, t in pairs(Territories) do
      if t.gangId then
        local base = computeIncome(name, t)
        t.income_generated = (t.income_generated or 0) + (base or 0)
        saveTerritory(name)
        TriggerClientEvent('cold-gangs:client:TerritoryIncomeGenerated', -1, { territory = name, gangId = t.gangId, amount = base or 0 })
      end
    end
  end
end)

-- Presence ➝ influence tick (process only loaded territories; do not create blanks)
CreateThread(function()
  while true do
    Wait(60000)
    for name, t in pairs(Territories) do
      -- Who is present in this territory (source -> gang)
      local present = {}
      for src, cur in pairs(PlayerTerritories) do
        if cur == name then
          local gid = GetPlayerGangIdSafe(src)
          if gid and gid > 0 then
            present[gid] = (present[gid] or 0) + 1
          end
        end
      end

      local map = getInfluMap(t)
      local perHead = (Config.Influence and Config.Influence.PRESENCE) or 1
      local decay = (Config.Influence and Config.Influence.DECAY) or 0

      -- Build present set (string keys) for "all-nonpresent" steal mode
      local presentSet = {}
      for gid, _ in pairs(present) do presentSet[tostring(gid)] = true end

      -- Presence gains + immediate steal
      for gid, count in pairs(present) do
        local key = tostring(gid)
        local gain = perHead * count
        map[key] = (tonumber(map[key]) or 0) + gain
        stealInfluence(map, key, gain, { presentSet = presentSet })
      end

      -- Decay non-present gangs
      if decay > 0 then
        for k, v in pairs(map) do
          if not presentSet[k] then
            local nv = (tonumber(v) or 0) - decay
            map[k] = (nv > 0) and nv or nil
          end
        end
      end

      clampMapToMax(map)
      local oldOwner = t.gangId
      local changedOwner = recalcOwner(name)
      saveTerritory(name)
      if changedOwner then
        TriggerClientEvent('cold-gangs:client:SyncTerritories', -1, Territories)
        TriggerEvent('cold-gangs:server:territoryChanged', name, t.gangId, oldOwner)
      else
        TriggerClientEvent('cold-gangs:client:UpdateTerritory', -1, name, t)
      end
    end
  end
end)

-- ========
-- Exports
-- ========

exports('GetTerritoryAtCoords', function(coords) return ColdGangs.Territories.GetTerritoryAtCoords(coords) end)
exports('AddGangInfluence',     function(name, gid, amt, act) return ColdGangs.Territories.AddGangInfluence(name, gid, amt, act) end)
exports('ReduceGangInfluence',  function(name, gid, amt, act) return ColdGangs.Territories.ReduceGangInfluence(name, gid, amt, act) end)

-- Query configured front + row (if any)
exports('GetTerritoryFront', function(territoryName)
  local cfg = getFrontConfigForTerritory(territoryName)
  if not cfg then return nil end
  local r = MySQL.query.await('SELECT * FROM gang_fronts WHERE territory_name = ? LIMIT 1', { territoryName })
  return {
    config = cfg,  -- key, def (FrontTypes row), label
    row = r and r[1] or nil
  }
end)
