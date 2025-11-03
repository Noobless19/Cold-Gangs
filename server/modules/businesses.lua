local QBCore = exports['qb-core']:GetCoreObject()

ColdGangs = ColdGangs or {}
ColdGangs.Fronts = ColdGangs.Fronts or {}

local Fronts = {}

-- ========================
-- Forward Declarations
-- ========================
local SyncFrontsToAll
local LoadAll
local SaveFront

-- ========================
-- Boot / Schema / Loading
-- ========================

local function ensureFrontsSchema()
  MySQL.query([[
    CREATE TABLE IF NOT EXISTS cold_gang_fronts (
      id INT AUTO_INCREMENT PRIMARY KEY,
      gang_id INT NULL,
      ref VARCHAR(100) NOT NULL UNIQUE,
      label VARCHAR(120) NOT NULL,
      laundering_rate DECIMAL(5,4) DEFAULT 0.2000,
      laundering_fee DECIMAL(5,4) DEFAULT 0.0500,
      daily_cap INT DEFAULT 250000,
      heat INT DEFAULT 0,
      security INT DEFAULT 1,
      location TEXT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_gang (gang_id),
      INDEX idx_ref (ref)
    )
  ]])
end

local function ensurePoolSchema()
  MySQL.query([[
    CREATE TABLE IF NOT EXISTS cold_gang_fronts_pool (
      front_id INT PRIMARY KEY,
      dirty_value INT DEFAULT 0,
      processed_today INT DEFAULT 0,
      last_processed DATE NULL,
      FOREIGN KEY (front_id) REFERENCES cold_gang_fronts(id) ON DELETE CASCADE
    )
  ]])
end

-- Assign function body to forward declaration
LoadAll = function()
  Fronts = {}
  local rows = MySQL.query.await('SELECT * FROM cold_gang_fronts', {})
  for _, row in ipairs(rows or {}) do
    local location = { x = 0.0, y = 0.0, z = 0.0 }
    if row.location then
      local ok, parsed = pcall(json.decode, row.location)
      if ok and type(parsed) == 'table' then location = parsed end
    end

    -- Load pool
    local pool = MySQL.query.await('SELECT * FROM cold_gang_fronts_pool WHERE front_id = ? LIMIT 1', { row.id })
    local poolData = (pool and pool[1]) or { dirty_value = 0, processed_today = 0, last_processed = nil }

    Fronts[row.id] = {
      id = row.id,
      gangId = row.gang_id,
      ref = row.ref,
      label = row.label,
      launderingRate = tonumber(row.laundering_rate) or 0.20,
      launderingFee = tonumber(row.laundering_fee) or 0.05,
      dailyCap = tonumber(row.daily_cap) or 250000,
      heat = tonumber(row.heat) or 0,
      security = tonumber(row.security) or 1,
      location = location,
      dirtyValue = tonumber(poolData.dirty_value) or 0,
      processedToday = tonumber(poolData.processed_today) or 0,
      lastProcessed = poolData.last_processed
    }
  end
  print(('[cold-gangs] Loaded %d fronts'):format(#Fronts))
end

-- Assign function body to forward declaration
SaveFront = function(frontId)
  local f = Fronts[frontId]
  if not f then return end

  local locJson = json.encode(f.location or { x = 0.0, y = 0.0, z = 0.0 })
  MySQL.update.await([[
    UPDATE cold_gang_fronts
    SET gang_id = ?, label = ?, laundering_rate = ?, laundering_fee = ?, daily_cap = ?, heat = ?, security = ?, location = ?
    WHERE id = ?
  ]], { f.gangId, f.label, f.launderingRate, f.launderingFee, f.dailyCap, f.heat, f.security, locJson, frontId })

  MySQL.update.await([[
    UPDATE cold_gang_fronts_pool
    SET dirty_value = ?, processed_today = ?, last_processed = ?
    WHERE front_id = ?
  ]], { f.dirtyValue or 0, f.processedToday or 0, f.lastProcessed, frontId })
end

-- Assign function body to forward declaration
SyncFrontsToAll = function()
  TriggerClientEvent('cold-gangs:client:SyncFronts', -1, Fronts)
end

local function SyncFrontToPlayer(src, frontId)
  local f = Fronts[frontId]
  if not f then return end
  TriggerClientEvent('cold-gangs:client:UpdateFront', src, frontId, f)
end

-- ========================
-- Utilities
-- ========================

local function GetPlayerGangIdSafe(src)
  if not src or src <= 0 then return nil end
  
  if ColdGangs and ColdGangs.Core and ColdGangs.Core.GetPlayerGangId then
    local ok, gid = pcall(function() return ColdGangs.Core.GetPlayerGangId(src) end)
    if ok and gid and tonumber(gid) and tonumber(gid) > 0 then return tonumber(gid) end
  end
  
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return nil end
  
  if Player.PlayerData then
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

-- ========================
-- Business Logic
-- ========================

function ColdGangs.Fronts.DepositDirtyMoney(src, frontId, amount)
  if not src or not frontId or not amount then return false, "Invalid parameters." end
  
  local f = Fronts[frontId]
  if not f or not f.gangId then return false, "Front not found or not owned." end

  local gid = GetPlayerGangIdSafe(src)
  if not gid or gid ~= f.gangId then return false, "You don't have access to this front." end

  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return false, "Player not found." end

  local markedBills = Player.Functions.GetItemByName('markedbills')
  if not markedBills or markedBills.amount < amount then
    return false, "You don't have enough marked bills."
  end

  f.dirtyValue = (f.dirtyValue or 0) + amount
  f.heat = math.min((f.heat or 0) + math.floor(amount / 10000), 100)

  Player.Functions.RemoveItem('markedbills', amount)
  SaveFront(frontId)
  SyncFrontToPlayer(src, frontId)

  return true, "Deposited $" .. amount .. " in dirty money."
end

function ColdGangs.Fronts.ProcessDirtyMoney(src, frontId)
  if not src or not frontId then return false, "Invalid parameters." end
  
  local f = Fronts[frontId]
  if not f or not f.gangId then return false, "Front not found or not owned." end

  local gid = GetPlayerGangIdSafe(src)
  if not gid or gid ~= f.gangId then return false, "You don't have access to this front." end

  if (f.dirtyValue or 0) <= 0 then return false, "No dirty money to process." end

  local today = os.date('%Y-%m-%d')
  if f.lastProcessed ~= today then
    f.processedToday = 0
    f.lastProcessed = today
  end

  local remaining = (f.dailyCap or 250000) - (f.processedToday or 0)
  if remaining <= 0 then return false, "Daily processing cap reached." end

  local toProcess = math.min(f.dirtyValue, remaining)
  local rate = f.launderingRate or 0.20
  local fee = f.launderingFee or 0.05
  local clean = math.floor(toProcess * rate * (1.0 - fee))

  f.dirtyValue = f.dirtyValue - toProcess
  f.processedToday = (f.processedToday or 0) + toProcess
  f.heat = math.max((f.heat or 0) - 5, 0)

  local Player = QBCore.Functions.GetPlayer(src)
  if Player then
    Player.Functions.AddMoney('cash', clean, 'front-laundering')
  end

  SaveFront(frontId)
  SyncFrontToPlayer(src, frontId)

  return true, "Processed $" .. toProcess .. " → $" .. clean .. " clean."
end

function ColdGangs.Fronts.UpgradeSecurity(src, frontId)
  if not src or not frontId then return false, "Invalid parameters." end
  
  local f = Fronts[frontId]
  if not f or not f.gangId then return false, "Front not found or not owned." end

  local gid = GetPlayerGangIdSafe(src)
  if not gid or gid ~= f.gangId then return false, "You don't have access to this front." end

  if (f.security or 1) >= 5 then return false, "Security already maxed out." end

  local cost = 50000 * (f.security or 1)
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return false, "Player not found." end

  if Player.Functions.GetMoney('cash') < cost then
    return false, "Not enough cash. Cost: $" .. cost
  end

  Player.Functions.RemoveMoney('cash', cost, 'front-security-upgrade')
  f.security = (f.security or 1) + 1
  f.heat = math.max((f.heat or 0) - 10, 0)

  SaveFront(frontId)
  SyncFrontToPlayer(src, frontId)

  return true, "Security upgraded to level " .. f.security
end

-- ========================
-- Initialize (AFTER QBCore is ready)
-- ========================

CreateThread(function()
  -- Wait for QBCore to be ready
  while not QBCore do
    Wait(100)
    QBCore = exports['qb-core']:GetCoreObject()
  end
  
  Wait(2000) -- Extra buffer for QBCore to fully initialize
  
  ensureFrontsSchema()
  ensurePoolSchema()
  Wait(500)
  LoadAll()
  SyncFrontsToAll()
  
  print('[cold-gangs] Businesses module initialized')
end)

-- Listen for territories module signaling a resync
RegisterNetEvent('cold-gangs:fronts:server:Resync', function()
  LoadAll()
  SyncFrontsToAll()
end)

-- ========================
-- Callbacks (Register AFTER QBCore loads)
-- ========================

CreateThread(function()
  while not QBCore do Wait(100) end
  Wait(2000)
  
  QBCore.Functions.CreateCallback('cold-gangs:server:GetAllFronts', function(source, cb)
    if not source or source <= 0 then 
      cb({})
      return 
    end
    
    local gid = GetPlayerGangIdSafe(source)
    if not gid then 
      cb({})
      return 
    end

    local result = {}
    for id, f in pairs(Fronts) do
      if f.gangId == gid then
        result[id] = f
      end
    end
    cb(result)
  end)

  QBCore.Functions.CreateCallback('cold-gangs:server:GetFrontDetails', function(source, cb, frontId)
    if not source or source <= 0 or not frontId then
      cb(nil)
      return
    end
    
    local f = Fronts[frontId]
    if not f then 
      cb(nil)
      return 
    end

    local gid = GetPlayerGangIdSafe(source)
    if not gid or gid ~= f.gangId then 
      cb(nil)
      return 
    end

    cb(f)
  end)
  
  print('[cold-gangs] Businesses callbacks registered')
end)

-- ========================
-- Events
-- ========================

RegisterNetEvent('cold-gangs:server:DepositDirtyMoney', function(frontId, amount)
  local src = source
  local success, msg = ColdGangs.Fronts.DepositDirtyMoney(src, frontId, amount)
  TriggerClientEvent('QBCore:Notify', src, msg, success and 'success' or 'error')
end)

RegisterNetEvent('cold-gangs:server:ProcessDirtyMoney', function(frontId)
  local src = source
  local success, msg = ColdGangs.Fronts.ProcessDirtyMoney(src, frontId)
  TriggerClientEvent('QBCore:Notify', src, msg, success and 'success' or 'error')
end)

RegisterNetEvent('cold-gangs:server:UpgradeFrontSecurity', function(frontId)
  local src = source
  local success, msg = ColdGangs.Fronts.UpgradeSecurity(src, frontId)
  TriggerClientEvent('QBCore:Notify', src, msg, success and 'success' or 'error')
end)

-- ========================
-- Loops
-- ========================

-- Heat decay over time
CreateThread(function()
  while true do
    Wait(300000) -- 5 minutes
    for id, f in pairs(Fronts) do
      if f.heat and f.heat > 0 then
        f.heat = math.max(f.heat - 1, 0)
        SaveFront(id)
      end
    end
    SyncFrontsToAll()
  end
end)

-- Daily cap reset
CreateThread(function()
  while true do
    Wait(3600000) -- 1 hour check
    local today = os.date('%Y-%m-%d')
    for id, f in pairs(Fronts) do
      if f.lastProcessed and f.lastProcessed ~= today then
        f.processedToday = 0
        f.lastProcessed = today
        SaveFront(id)
      end
    end
  end
end)

-- ========================
-- Exports
-- ========================

exports('DepositDirtyMoney', function(src, frontId, amount)
  return ColdGangs.Fronts.DepositDirtyMoney(src, frontId, amount)
end)

exports('ProcessDirtyMoney', function(src, frontId)
  return ColdGangs.Fronts.ProcessDirtyMoney(src, frontId)
end)

exports('UpgradeSecurity', function(src, frontId)
  return ColdGangs.Fronts.UpgradeSecurity(src, frontId)
end)

exports('GetFronts', function()
  return Fronts
end)
