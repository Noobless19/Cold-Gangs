-- server/modules/heists.lua
local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}
local ActiveHeists = {}
local function parse_dt(dt)
  if type(dt)=='number' then return dt end
  if type(dt)~='string' then return os.time() end
  local y,M,d,h,m,s = dt:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
  return os.time{year=y, month=M, day=d, hour=h, min=m, sec=s}
end
RegisterNetEvent('cold-gangs:heists:Start', function(heistType, locationIndex)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then return end
  if not ColdGangs.Permissions.HasGangPermission(src, 'manageHeists') then return end
  local cfg = Config.HeistTypes[heistType]
  if not cfg then return end
  local rep = MySQL.Sync.fetchScalar('SELECT reputation FROM cold_gangs WHERE id = ?', {gangId}) or 0
  local minRep = cfg.minReputation or 0
  if rep < minRep then return end
  if cfg.policeRequired and cfg.policeRequired > 0 then
    local count = 0
    for _, s in pairs(QBCore.Functions.GetPlayers()) do
      local P = QBCore.Functions.GetPlayer(s)
      if P and P.PlayerData.job and P.PlayerData.job.onduty then
        for _, j in ipairs(Config.PoliceJobs or {'police','sheriff'}) do
          if P.PlayerData.job.name == j then count = count + 1 break end
        end
      end
    end
    if count < cfg.policeRequired then return end
  end
  local cd = MySQL.Sync.fetchAll('SELECT * FROM cold_heist_cooldowns WHERE heist_type = ? AND available_at > NOW()', {heistType})
  if cd and #cd>0 then return end
  local location = cfg.locations and cfg.locations[locationIndex]
  if not location then return end
  local participants = {}
  participants[Player.PlayerData.citizenid] = { name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, role = "leader" }
  local heistId = MySQL.insert.await('INSERT INTO cold_active_heists (heist_type, gang_id, status, start_time, participants, current_stage, location) VALUES (?, ?, ?, NOW(), ?, ?, ?)', {
    heistType, gangId, 'active', json.encode(participants), 1, json.encode(location)
  })
  ActiveHeists[heistId] = {
    id = heistId, heistType = heistType, gangId = gangId, status = 'active',
    startTime = os.date('%Y-%m-%d %H:%M:%S'), participants = participants, currentStage = 1, rewards = {}, location = location
  }
  MySQL.query('INSERT INTO cold_heist_cooldowns (heist_type, last_completed, available_at) VALUES (?, NOW(), DATE_ADD(NOW(), INTERVAL ? SECOND)) ON DUPLICATE KEY UPDATE last_completed = NOW(), available_at = DATE_ADD(NOW(), INTERVAL ? SECOND)', {
    heistType, (cfg.cooldown or 0)/1000, (cfg.cooldown or 0)/1000
  })
  TriggerClientEvent('cold-gangs:client:HeistStarted', -1, heistId, ActiveHeists[heistId])
  TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
end)
RegisterNetEvent('cold-gangs:heists:Join', function(heistId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then return end
  local heist = ActiveHeists[heistId]
  if not heist or heist.gangId ~= gangId then return end
  if heist.participants[Player.PlayerData.citizenid] then return end
  local cfg = Config.HeistTypes[heist.heistType]
  local count = 0
  for _ in pairs(heist.participants) do count = count + 1 end
  if count >= (cfg.maxMembers or 4) then return end
  heist.participants[Player.PlayerData.citizenid] = { name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, role = "member" }
  MySQL.update('UPDATE cold_active_heists SET participants = ? WHERE id = ?', {json.encode(heist.participants), heistId})
  TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
end)
RegisterNetEvent('cold-gangs:heists:CompleteStage', function(heistId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then return end
  local heist = ActiveHeists[heistId]
  if not heist or heist.gangId ~= gangId then return end
  if not heist.participants[Player.PlayerData.citizenid] then return end
  local cfg = Config.HeistTypes[heist.heistType]
  local newStage = (heist.currentStage or 1) + 1
  if not cfg.stages or newStage > #cfg.stages then
    local payout = math.random(cfg.rewards.basePayout.min, cfg.rewards.basePayout.max)
    ColdGangs.Core.AddGangMoney(gangId, payout, "Heist Reward: "..heist.heistType)
    local repConf = cfg.rewards.reputation
    local rep = type(repConf)=='table' and math.random(repConf.min, repConf.max) or (repConf or 0)
    ColdGangs.Core.AddGangReputation(gangId, rep)
    MySQL.update('UPDATE cold_active_heists SET status=?, rewards=? WHERE id=?', {'completed', json.encode({money=payout, reputation=rep}), heistId})
    TriggerClientEvent('cold-gangs:client:HeistCompleted', -1, heistId, {money=payout, reputation=rep})
    ActiveHeists[heistId] = nil
    TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
    return
  end
  MySQL.update('UPDATE cold_active_heists SET current_stage = ? WHERE id = ?', {newStage, heistId})
  heist.currentStage = newStage
  TriggerClientEvent('cold-gangs:client:HeistStageUpdated', -1, heistId, newStage)
  TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
end)
RegisterNetEvent('cold-gangs:heists:Cancel', function(heistId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then return end
  if not ColdGangs.Permissions.HasGangPermission(src, 'manageHeists') then return end
  local heist = ActiveHeists[heistId]
  if not heist or heist.gangId ~= gangId then return end
  MySQL.update('UPDATE cold_active_heists SET status=? WHERE id=?', {'cancelled', heistId})
  TriggerClientEvent('cold-gangs:client:HeistFailed', -1, heistId, "Cancelled")
  ActiveHeists[heistId] = nil
  TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
end)
QBCore.Functions.CreateCallback('cold-gangs:server:GetActiveHeists', function(source, cb)
  cb(ActiveHeists)
end)
CreateThread(function()
  while true do
    Wait(60000)
    local now = os.time()
    for id, h in pairs(ActiveHeists) do
      local st = parse_dt(h.startTime)
      if now - st > 10800 then
        MySQL.update('UPDATE cold_active_heists SET status=? WHERE id=?', {'failed', id})
        TriggerClientEvent('cold-gangs:client:HeistFailed', -1, id, "Timed out")
        ActiveHeists[id] = nil
      end
    end
    TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
  end
end)
