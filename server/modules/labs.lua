local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}
local labStates = {}
local labContinuous = {}
local labInventories = {}
local function to_dt(ts)
  return os.date('%Y-%m-%d %H:%M:%S', math.floor((ts or os.time()) ))
end
local function now_ts()
  return os.time()
end
local function loadLabInventory(labId)
  labInventories[labId] = {}
  local rs = MySQL.Sync.fetchAll('SELECT item, amount FROM gang_lab_inventory WHERE lab_id = ?', {labId})
  if rs then for _, r in ipairs(rs) do labInventories[labId][r.item] = r.amount end end
end
local function saveLabInventory(labId, item, amount)
  if amount <= 0 then
    MySQL.execute('DELETE FROM gang_lab_inventory WHERE lab_id=? AND item=?', {labId, item})
    if labInventories[labId] then labInventories[labId][item] = nil end
  else
    MySQL.execute('INSERT INTO gang_lab_inventory (lab_id, item, amount) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE amount=?', {labId, item, amount, amount})
    labInventories[labId] = labInventories[labId] or {}
    labInventories[labId][item] = amount
  end
end
local function saveLabState(labId)
  local s = labStates[labId]
  if not s then return end
  MySQL.execute([[
    INSERT INTO gang_lab_states (lab_id, is_producing, production_start_time, production_duration, recipe, player_id, is_sabotaged, sabotage_expires, sabotaged_by, security_disabled, security_expires)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
    is_producing=VALUES(is_producing), production_start_time=VALUES(production_start_time), production_duration=VALUES(production_duration),
    recipe=VALUES(recipe), player_id=VALUES(player_id), is_sabotaged=VALUES(is_sabotaged), sabotage_expires=VALUES(sabotage_expires),
    sabotaged_by=VALUES(sabotaged_by), security_disabled=VALUES(security_disabled), security_expires=VALUES(security_expires)
  ]], {
    labId, s.isProducing and 1 or 0, s.productionStartTime and os.date('%Y-%m-%d %H:%M:%S', math.floor(s.productionStartTime)) or nil,
    s.productionDuration or 0, s.recipe, s.playerId, s.isSabotaged and 1 or 0,
    s.sabotageExpires and os.date('%Y-%m-%d %H:%M:%S', math.floor(s.sabotageExpires)) or nil, s.sabotagedBy,
    s.securityDisabled and 1 or 0, s.securityExpires and os.date('%Y-%m-%d %H:%M:%S', math.floor(s.securityExpires)) or nil
  })
end
local function initLabs()
  for labId, lab in pairs(Config.Labs or {}) do
    if lab.active then
      labStates[labId] = labStates[labId] or {
        isProducing=false, productionStartTime=0, productionDuration=0, recipe=nil, playerId=nil,
        isSabotaged=false, sabotageExpires=0, sabotagedBy=nil, securityDisabled=false, securityExpires=0
      }
      loadLabInventory(labId)
    end
  end
end
RegisterNetEvent('cold-gangs:labs:startProduction', function(labId, recipe)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gid = ColdGangs.Core.GetPlayerGangId(src)
  if not gid then return end
  local lab = Config.Labs[labId]
  if not lab then return end
  local owner = MySQL.Sync.fetchAll('SELECT gang_id FROM territories WHERE name = ?', {lab.territory_name})
  if not owner or #owner==0 or owner[1].gang_id ~= gid then return end
  local lt = Config.LabTypes[lab.type]
  if not lt or not lt.recipes[recipe] then return end
  local rcp = lt.recipes[recipe]
  for item, amt in pairs(rcp.inputs) do
    local it = Player.Functions.GetItemByName(item)
    if not it or it.amount < amt then return end
  end
  for item, amt in pairs(rcp.inputs) do
    Player.Functions.RemoveItem(item, amt)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "remove", amt)
  end
  local state = labStates[labId]
  if state.isProducing then return end
  local time = rcp.time
  state.isProducing = true
  state.productionStartTime = now_ts()
  state.productionDuration = time
  state.recipe = recipe
  state.playerId = src
  saveLabState(labId)
  SetTimeout(time, function()
    local P = QBCore.Functions.GetPlayer(state.playerId)
    if P then
      P.Functions.AddItem(rcp.output.item, rcp.output.amount)
      TriggerClientEvent('inventory:client:ItemBox', state.playerId, QBCore.Shared.Items[rcp.output.item], "add", rcp.output.amount)
    end
    state.isProducing=false
    state.productionStartTime=0
    state.productionDuration=0
    state.recipe=nil
    state.playerId=nil
    saveLabState(labId)
  end)
end)
RegisterNetEvent('cold-gangs:labs:depositItem', function(labId, item, amount)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gid = ColdGangs.Core.GetPlayerGangId(src)
  if not gid then return end
  local lab = Config.Labs[labId]
  if not lab then return end
  local owner = MySQL.Sync.fetchAll('SELECT gang_id FROM territories WHERE name = ?', {lab.territory_name})
  if not owner or #owner==0 or owner[1].gang_id ~= gid then return end
  local it = Player.Functions.GetItemByName(item)
  if not it or it.amount < amount then return end
  Player.Functions.RemoveItem(item, amount)
  TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "remove", amount)
  local current = (labInventories[labId] and labInventories[labId][item]) or 0
  saveLabInventory(labId, item, current + amount)
end)
RegisterNetEvent('cold-gangs:labs:withdrawItem', function(labId, item, amount)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gid = ColdGangs.Core.GetPlayerGangId(src)
  if not gid then return end
  local lab = Config.Labs[labId]
  if not lab then return end
  local owner = MySQL.Sync.fetchAll('SELECT gang_id FROM territories WHERE name = ?', {lab.territory_name})
  if not owner or #owner==0 or owner[1].gang_id ~= gid then return end
  local inv = labInventories[labId] or {}
  if not inv[item] or inv[item] < amount then return end
  Player.Functions.AddItem(item, amount)
  TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "add", amount)
  saveLabInventory(labId, item, inv[item] - amount)
end)
QBCore.Functions.CreateCallback('cold-gangs:labs:getLabInventory', function(source, cb, labId)
  cb(labInventories[labId] or {})
end)
CreateThread(function()
  Wait(2000)
  initLabs()
end)
