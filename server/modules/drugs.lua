local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}

local Fields = {}
local Labs   = {}

local function now_iso() return os.date('%Y-%m-%d %H:%M:%S') end
local function getPlayer(src) return QBCore.Functions.GetPlayer(src) end
local function ensureGangId(src) return ColdGangs.Core.GetPlayerGangId(src) end
local function hasPerm(src) return ColdGangs.Permissions.HasGangPermission(src, 'manageDrugs') end

local function db_decode(s)
  if type(s) ~= 'string' or s == '' then return nil end
  local ok, d = pcall(json.decode, s)
  return ok and d or nil
end

local function getTerritoryAtCoords(coords)
  if ColdGangs and ColdGangs.Territories and ColdGangs.Territories.GetTerritoryAtCoords then
    return ColdGangs.Territories.GetTerritoryAtCoords(coords)
  end
  return nil
end

local function territoryOwnedBy(territoryName, gangId)
  local row = MySQL.Sync.fetchAll('SELECT gang_id FROM territories WHERE name = ?', { territoryName })
  return (row and row[1] and tonumber(row[1].gang_id) == tonumber(gangId)) or false
end

local function getFieldDefaults(resourceType)
  local root = (Config.Drugs and Config.Drugs.Fields) or {}
  local d = root[resourceType] or {}
  return {
    growthStart = d.growthStart or 0,
    qualityMin  = d.qualityMin  or 40,
    qualityMax  = d.qualityMax  or 80,
    maxYield    = d.maxYield    or 100
  }
end

local function getFieldOutputItem(resourceType)
  local map = (Config.Drugs and Config.Drugs.FieldOutputs) or {
    weed = 'weed_leaf',
    coke = 'coca_leaf',
    meth = 'meth_precur'
  }
  return map[resourceType] or resourceType
end

local function getLabRecipe(drugType)
  local root = (Config.DrugLabs and Config.DrugLabs.recipes) or {}
  if root[drugType] then return root[drugType] end
  return {
    inputs  = { [drugType .. '_precursor'] = 2 },
    outputs = { [drugType] = 1 },
    time    = (Config.DrugLabs and Config.DrugLabs.processingTimes and Config.DrugLabs.processingTimes[drugType]) or 60000
  }
end

local function syncFields()
  TriggerClientEvent('cold-gangs:client:SyncDrugFields', -1, Fields)
end

local function syncLabs()
  TriggerClientEvent('cold-gangs:client:SyncDrugLabs', -1, Labs)
end

CreateThread(function()
  Wait(1000)
  local frs = MySQL.Sync.fetchAll('SELECT * FROM cold_drug_fields', {}) or {}
  for _, f in ipairs(frs) do
    Fields[f.id] = {
      id = f.id,
      territoryName   = f.territory_name,
      resourceType    = f.resource_type,
      growthStage     = f.growth_stage,
      maxYield        = f.max_yield,
      qualityRangeMin = f.quality_range_min,
      qualityRangeMax = f.quality_range_max,
      owner    = f.owner,
      gangName = f.gang_name,
      location = f.location,
      last_updated = f.last_updated
    }
  end

  local lrs = MySQL.Sync.fetchAll('SELECT * FROM cold_drug_labs', {}) or {}
  for _, l in ipairs(lrs) do
    Labs[l.id] = {
      id = l.id,
      territoryName = l.territory_name,
      drugType = l.drug_type,
      level = l.level,
      capacity = l.capacity,
      owner = l.owner,
      gangName = l.gang_name,
      location = l.location,
      security = l.security,
      last_updated = l.last_updated
    }
  end
end)

RegisterNetEvent('cold-gangs:server:CreateDrugField', function(resourceType, territoryName)
  local src = source
  local P = getPlayer(src); if not P then return end
  local gid = ensureGangId(src); if not gid then return end
  if not hasPerm(src) then return end
  if not resourceType or not territoryName then return end
  if not territoryOwnedBy(territoryName, gid) then
    TriggerClientEvent('QBCore:Notify', src, 'Place this within your gang territory', 'error')
    return
  end

  local pos = GetEntityCoords(GetPlayerPed(src))
  local def = getFieldDefaults(resourceType)
  local gangRow = MySQL.Sync.fetchAll('SELECT name FROM cold_gangs WHERE id = ?', { gid })
  local gname = (gangRow and gangRow[1] and gangRow[1].name) or "Unknown"

  local id = MySQL.insert.await([[
    INSERT INTO cold_drug_fields (territory_name, resource_type, growth_stage, max_yield, quality_range_min, quality_range_max, owner, gang_name, location, last_updated)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
  ]], {
    territoryName, resourceType, def.growthStart, def.maxYield, def.qualityMin, def.qualityMax,
    gid, gname, json.encode({ x = pos.x, y = pos.y, z = pos.z })
  })

  if id and id > 0 then
    Fields[id] = {
      id = id,
      territoryName   = territoryName,
      resourceType    = resourceType,
      growthStage     = def.growthStart,
      maxYield        = def.maxYield,
      qualityRangeMin = def.qualityMin,
      qualityRangeMax = def.qualityMax,
      owner    = gid,
      gangName = gname,
      location = json.encode({ x = pos.x, y = pos.y, z = pos.z }),
      last_updated = now_iso()
    }
    syncFields()
    TriggerClientEvent('QBCore:Notify', src, ('Field created: %s'):format(resourceType), 'success')
  end
end)

RegisterNetEvent('cold-gangs:server:HarvestDrugField', function(fieldId)
  local src = source
  local P = getPlayer(src); if not P then return end
  fieldId = tonumber(fieldId)
  local f = Fields[fieldId]; if not f then return end
  local gid = ensureGangId(src); if not gid or tonumber(f.owner) ~= tonumber(gid) then return end

  if (f.growthStage or 0) < 10 then
    TriggerClientEvent('QBCore:Notify', src, 'Plants are not ready for harvest', 'error')
    return
  end

  local quality = math.random(f.qualityRangeMin or 40, f.qualityRangeMax or 80)
  local baseYield = f.maxYield or 100
  local amt = math.max(1, math.floor(baseYield * (quality / 100)))
  local item = getFieldOutputItem(f.resourceType)

  P.Functions.AddItem(item, amt)
  TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', amt)
  TriggerClientEvent('QBCore:Notify', src, ('Harvested %dx %s'):format(amt, (QBCore.Shared.Items[item] and QBCore.Shared.Items[item].label) or item), 'success')

  f.growthStage = 0
  f.last_updated = now_iso()
  MySQL.update('UPDATE cold_drug_fields SET growth_stage = 0, last_updated = NOW() WHERE id = ?', { fieldId })
  syncFields()

  if Config.TerritoryIntegration and Config.TerritoryIntegration.enabled and Config.TerritoryIntegration.influenceEvents and Config.TerritoryIntegration.influenceEvents.harvest then
    if f.territoryName then
      ColdGangs.Territories.AddGangInfluence(f.territoryName, gid,
        (Config.Drugs and Config.Drugs.InfluenceGain and Config.Drugs.InfluenceGain.harvest) or 5,
        'harvest'
      )
    end
  end
end)

RegisterNetEvent('cold-gangs:server:CreateDrugLab', function(drugType, territoryName)
  local src = source
  local P = getPlayer(src); if not P then return end
  local gid = ensureGangId(src); if not gid then return end
  if not hasPerm(src) then return end
  if not drugType or not territoryName then return end
  if not territoryOwnedBy(territoryName, gid) then
    TriggerClientEvent('QBCore:Notify', src, 'Place this within your gang territory', 'error')
    return
  end

  local cost = (Config.DrugLabs and Config.DrugLabs.createCost) or 50000
  if cost > 0 and not ColdGangs.Core.RemoveGangMoney(gid, cost, ('Create Lab: %s'):format(drugType)) then
    TriggerClientEvent('QBCore:Notify', src, 'Not enough gang funds', 'error')
    return
  end

  local pos = GetEntityCoords(GetPlayerPed(src))
  local gangRow = MySQL.Sync.fetchAll('SELECT name FROM cold_gangs WHERE id = ?', { gid })
  local gname = (gangRow and gangRow[1] and gangRow[1].name) or "Unknown"

  local id = MySQL.insert.await([[
    INSERT INTO cold_drug_labs (territory_name, drug_type, level, capacity, owner, gang_name, location, security, last_updated)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
  ]], { territoryName, drugType, 1, 100, gid, gname, json.encode({ x = pos.x, y = pos.y, z = pos.z }), 50 })

  if id and id > 0 then
    Labs[id] = {
      id = id, territoryName = territoryName, drugType = drugType, level = 1, capacity = 100,
      owner = gid, gangName = gname, location = json.encode({ x = pos.x, y = pos.y, z = pos.z }),
      security = 50, last_updated = now_iso()
    }
    syncLabs()
    TriggerClientEvent('QBCore:Notify', src, ('Lab created: %s'):format(drugType), 'success')
  end
end)

RegisterNetEvent('cold-gangs:server:UpgradeDrugLab', function(labId, upgradeType)
  local src = source
  local P = getPlayer(src); if not P then return end
  labId = tonumber(labId)
  local L = Labs[labId]; if not L then return end
  local gid = ensureGangId(src); if not gid or tonumber(L.owner) ~= tonumber(gid) then return end
  if not hasPerm(src) then return end

  local level = tonumber(L.level or 1)
  local cap   = tonumber(L.capacity or 100)
  local sec   = tonumber(L.security or 50)
  local cost  = 0

  if upgradeType == 'level' then
    cost = 25000 * level
    level = level + 1
  elseif upgradeType == 'capacity' then
    cost = 15000 * math.floor(cap / 50)
    cap  = cap + 50
  elseif upgradeType == 'security' then
    cost = 20000 * math.floor(sec / 25)
    sec  = math.min(100, sec + 10)
  else
    return
  end

  if cost > 0 and not ColdGangs.Core.RemoveGangMoney(gid, cost, ('Lab Upgrade (%s)'):format(upgradeType)) then
    TriggerClientEvent('QBCore:Notify', src, 'Not enough gang funds', 'error')
    return
  end

  L.level = level; L.capacity = cap; L.security = sec; L.last_updated = now_iso()
  MySQL.update('UPDATE cold_drug_labs SET level=?, capacity=?, security=?, last_updated=NOW() WHERE id=?', { level, cap, sec, labId })
  syncLabs()
  TriggerClientEvent('QBCore:Notify', src, ('Lab upgraded (%s)'):format(upgradeType), 'success')
end)

local function getLabInventoryLoad(labId)
  local rs = MySQL.Sync.fetchAll('SELECT SUM(amount) as total FROM gang_lab_inventory WHERE lab_id = ?', { tostring(labId) })
  local total = (rs and rs[1] and rs[1].total) or 0
  return tonumber(total) or 0
end

local function addLabInventory(labId, item, amount)
  amount = tonumber(amount) or 0
  if amount <= 0 then return end
  MySQL.execute('INSERT INTO gang_lab_inventory (lab_id, item, amount) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE amount = amount + ?', {
    tostring(labId), item, amount, amount
  })
end

RegisterNetEvent('cold-gangs:server:CompleteDrugProcessing', function(labId)
  local src = source
  local P = getPlayer(src); if not P then return end
  labId = tonumber(labId)
  local L = Labs[labId]; if not L then return end
  local gid = ensureGangId(src); if not gid or tonumber(L.owner) ~= tonumber(gid) then return end

  local recipe = getLabRecipe(L.drugType)
  local missing = {}

  for item, amt in pairs(recipe.inputs or {}) do
    local it = P.Functions.GetItemByName(item)
    if not it or (it.amount or 0) < amt then
      missing[item] = amt
    end
  end
  if next(missing) then
    TriggerClientEvent('QBCore:Notify', src, 'Missing required items for processing', 'error', 6000)
    return
  end

  local totalOut = 0
  for _, amt in pairs(recipe.outputs or {}) do totalOut = totalOut + (tonumber(amt) or 0) end
  local currentLoad = getLabInventoryLoad(labId)
  if (currentLoad + totalOut) > (tonumber(L.capacity) or 100) then
    local free = math.max(0, (tonumber(L.capacity) or 100) - currentLoad)
    TriggerClientEvent('QBCore:Notify', src, ('Lab storage full. Free space: %d'):format(free), 'error', 6500)
    return
  end

  for item, amt in pairs(recipe.inputs or {}) do
    P.Functions.RemoveItem(item, amt)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'remove', amt)
  end

  for item, amt in pairs(recipe.outputs or {}) do
    addLabInventory(labId, item, amt)
  end

  MySQL.insert('INSERT INTO gang_lab_production_history (lab_id, recipe, player_id, gang_id, inputs, outputs, production_time) VALUES (?, ?, ?, ?, ?, ?, ?)', {
    tostring(labId),
    L.drugType,
    src,
    tostring(gid),
    json.encode(recipe.inputs or {}),
    json.encode(recipe.outputs or {}),
    math.floor((recipe.time or 0) / 1000)
  })

  L.last_updated = now_iso()
  MySQL.update('UPDATE cold_drug_labs SET last_updated=NOW() WHERE id=?', { labId })
  TriggerClientEvent('QBCore:Notify', src, 'Processing complete. Output stored in lab.', 'success')
end)

QBCore.Functions.CreateCallback('cold-gangs:server:CheckProcessingRequirements', function(source, cb, drugType)
  local P = getPlayer(source)
  if not P then cb(false, {}) return end
  local recipe = getLabRecipe(drugType)
  local missing = {}
  for item, amt in pairs(recipe.inputs or {}) do
    local it = P.Functions.GetItemByName(item)
    if not it or (it.amount or 0) < amt then
      missing[item] = amt
    end
  end
  cb(next(missing) == nil, missing)
end)

CreateThread(function()
  local baseInterval = (Config.Drugs and Config.Drugs.growthIntervalMs) or 15 * 60 * 1000
  while true do
    Wait(baseInterval)
    local changed = false

    local presence = {}
    for _, src in ipairs(QBCore.Functions.GetPlayers()) do
      local gid = ColdGangs.Core.GetPlayerGangId(src)
      if gid then
        local ped = GetPlayerPed(src)
        if ped and ped > 0 then
          local c = GetEntityCoords(ped)
          local terr = getTerritoryAtCoords({ x = c.x, y = c.y, z = c.z })
          if terr then
            presence[terr] = presence[terr] or {}
            presence[terr][gid] = (presence[terr][gid] or 0) + 1
          end
        end
      end
    end

    for id, f in pairs(Fields) do
      local gs = tonumber(f.growthStage or 0)
      if gs < 10 then
        local terr = f.territoryName
        local base = 1
        local bonus = 0
        if terr and presence[terr] and f.owner then
          local count = presence[terr][tonumber(f.owner)] or 0
          if count >= 3 then bonus = 2
          elseif count >= 1 then bonus = 1 end
        end
        local inc = base + bonus
        local newGS = math.min(10, gs + inc)
        if newGS ~= gs then
          f.growthStage = newGS
          f.last_updated = now_iso()
          MySQL.update('UPDATE cold_drug_fields SET growth_stage=?, last_updated=NOW() WHERE id=?', { newGS, id })
          changed = true
        end
      end
    end

    if changed then syncFields() end
  end
end)

local function setLabSecurity(labId, newSec)
  newSec = math.max(0, math.min(100, tonumber(newSec) or 0))
  local L = Labs[labId]; if not L then return newSec end
  L.security = newSec
  L.last_updated = now_iso()
  MySQL.update('UPDATE cold_drug_labs SET security=?, last_updated=NOW() WHERE id=?', { newSec, labId })
  return newSec
end

local function disableLabSecurityTemporarily(labId, seconds, sabotagedBy)
  local expires = os.date('%Y-%m-%d %H:%M:%S', os.time() + (seconds or 120))
  MySQL.execute([[
    INSERT INTO gang_lab_states (lab_id, is_producing, production_start_time, production_duration, recipe, player_id, is_sabotaged, sabotage_expires, sabotaged_by, security_disabled, security_expires)
    VALUES (?, 0, NULL, 0, NULL, NULL, 1, ?, ?, 1, ?)
    ON DUPLICATE KEY UPDATE
      is_sabotaged=VALUES(is_sabotaged),
      sabotage_expires=VALUES(sabotage_expires),
      sabotaged_by=VALUES(sabotaged_by),
      security_disabled=VALUES(security_disabled),
      security_expires=VALUES(security_expires),
      updated_at=CURRENT_TIMESTAMP
  ]], { tostring(labId), expires, sabotagedBy or 'unknown', expires })
end

local function broadcastRaidEffect(labId, effectType)
  TriggerClientEvent('cold-gangs:labs:client:showRaidEffects', -1, labId, effectType or 'alarm')
end

RegisterNetEvent('cold-gangs:labs:lockpickResult', function(labId, success)
  labId = tonumber(labId)
  if not labId or not Labs[labId] then return end
  local L = Labs[labId]
  if success then
    local newSec = setLabSecurity(labId, (tonumber(L.security) or 50) - 10)
    broadcastRaidEffect(labId, 'alarm')
    if L.owner then
      ColdGangs.Core.NotifyGangMembers(L.owner, 'Lab Lockpicked', ('Security reduced to %d'):format(newSec))
    end
  else
    setLabSecurity(labId, (tonumber(L.security) or 50) - 2)
  end
end)

RegisterNetEvent('cold-gangs:labs:hackingResult', function(labId, success)
  labId = tonumber(labId)
  if not labId or not Labs[labId] then return end
  local L = Labs[labId]
  if success then
    local newSec = setLabSecurity(labId, (tonumber(L.security) or 50) - 20)
    disableLabSecurityTemporarily(labId, 180, tostring(source))
    broadcastRaidEffect(labId, 'smoke')
    if L.owner then
      ColdGangs.Core.NotifyGangMembers(L.owner, 'Lab Hack', ('Security temporarily disabled; current security %d'):format(newSec))
    end
  else
    setLabSecurity(labId, (tonumber(L.security) or 50) - 5)
  end
end)

CreateThread(function()
  local regenInterval = (Config.DrugLabs and Config.DrugLabs.securityRegenIntervalMs) or (10 * 60 * 1000)
  local regenAmount   = (Config.DrugLabs and Config.DrugLabs.securityRegenAmount) or 2
  while true do
    Wait(regenInterval)
    local changed = false
    for id, L in pairs(Labs) do
      local sec = tonumber(L.security) or 0
      if sec < 100 then
        local newSec = math.min(100, sec + regenAmount)
        if newSec ~= sec then
          setLabSecurity(id, newSec)
          changed = true
        end
      end
    end
    if changed then syncLabs() end
  end
end)
