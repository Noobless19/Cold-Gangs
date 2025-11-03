local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}
local ActiveWars = {}
RegisterNetEvent('cold-gangs:wars:Declare', function(targetGangId, territoryName)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then return end
  if not ColdGangs.Permissions.HasGangPermission(src, 'declareWar') then return end
  local g = MySQL.Sync.fetchAll('SELECT * FROM cold_gangs WHERE id = ?', {targetGangId})
  if not g or #g==0 then return end
  local t = MySQL.Sync.fetchAll('SELECT gang_id FROM territories WHERE name = ?', {territoryName})
  if not t or #t==0 or t[1].gang_id ~= targetGangId then return end
  for _, w in pairs(ActiveWars) do
    if (w.attackerId == gangId and w.defenderId == targetGangId) or (w.attackerId == targetGangId and w.defenderId == gangId) then return end
  end
  local warCount = 0
  for _, w in pairs(ActiveWars) do if w.attackerId == gangId or w.defenderId == gangId then warCount = warCount + 1 end end
  if warCount >= (Config.Wars and Config.Wars.maxSimultaneousWars or 3) then return end
  if not ColdGangs.Core.RemoveGangMoney(gangId, Config.Wars.declarationCost or 0, "War Declaration") then return end
  local me = MySQL.Sync.fetchAll('SELECT name FROM cold_gangs WHERE id = ?', {gangId})
  local warId = MySQL.insert.await('INSERT INTO cold_active_wars (attacker_id, defender_id, attacker_name, defender_name, territory_name, started_at, attacker_score, defender_score, max_score, status) VALUES (?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?)', {
    gangId, targetGangId, me[1].name, g[1].name, territoryName, 0, 0, Config.Wars and Config.Wars.maxScore or 100, 'active'
  })
  ActiveWars[warId] = {
    id = warId, attackerId = gangId, defenderId = targetGangId, attackerName = me[1].name, defenderName = g[1].name,
    territoryName = territoryName, startedAt = os.date('%Y-%m-%d %H:%M:%S'), attackerScore = 0, defenderScore = 0, maxScore = Config.Wars and Config.Wars.maxScore or 100, status = 'active'
  }
  TriggerClientEvent('cold-gangs:client:WarStarted', -1, warId, ActiveWars[warId])
  ColdGangs.Core.AddGangReputation(gangId, 50)
  TriggerClientEvent('cold-gangs:client:SyncWars', -1, ActiveWars)
end)
RegisterNetEvent('cold-gangs:wars:ReportDeath', function(warId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then return end
  local war = ActiveWars[warId]
  if not war then return end
  if war.attackerId ~= gangId and war.defenderId ~= gangId then return end
  if war.attackerId == gangId then
    war.defenderScore = war.defenderScore + 1
    MySQL.update('UPDATE cold_active_wars SET defender_score=? WHERE id=?', {war.defenderScore, warId})
  else
    war.attackerScore = war.attackerScore + 1
    MySQL.update('UPDATE cold_active_wars SET attacker_score=? WHERE id=?', {war.attackerScore, warId})
  end
  TriggerClientEvent('cold-gangs:client:WarScoreUpdated', -1, warId, war.attackerScore, war.defenderScore)
  if war.attackerScore >= war.maxScore or war.defenderScore >= war.maxScore then
    local winnerId = war.attackerScore >= war.maxScore and war.attackerId or war.defenderId
    MySQL.update('UPDATE cold_active_wars SET status=?, winner_id=?, ended_at=NOW() WHERE id=?', {'ended', winnerId, warId})
    local winner = MySQL.Sync.fetchAll('SELECT name FROM cold_gangs WHERE id = ?', {winnerId})
    TriggerClientEvent('cold-gangs:client:WarEnded', -1, warId, winnerId, winner and winner[1] and winner[1].name or '')
    local territoryName = war.territoryName
    local wg = MySQL.Sync.fetchAll('SELECT name, color FROM cold_gangs WHERE id = ?', {winnerId})
    if wg and #wg>0 then
      MySQL.update('UPDATE territories SET gang_id=?, gang_name=?, claimed_at=NOW(), color_hex=? WHERE name=?', {winnerId, wg[1].name, wg[1].color or '#808080', territoryName})
    end
    ColdGangs.Core.AddGangMoney(winnerId, Config.Wars and Config.Wars.winReward or 0, "War Victory Reward")
    local loserId = (winnerId == war.attackerId) and war.defenderId or war.attackerId
    ColdGangs.Core.AddGangMoney(loserId, Config.Wars and Config.Wars.loseReward or 0, "War Consolation Prize")
    ActiveWars[warId] = nil
    TriggerClientEvent('cold-gangs:client:SyncWars', -1, ActiveWars)
  end
end)
RegisterNetEvent('cold-gangs:wars:Surrender', function(warId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gid = ColdGangs.Core.GetPlayerGangId(src)
  if not gid then return end
  if not ColdGangs.Permissions.HasGangPermission(src, 'declareWar') then return end
  local war = ActiveWars[warId]
  if not war then return end
  if war.attackerId ~= gid and war.defenderId ~= gid then return end
  local winnerId = war.attackerId == gid and war.defenderId or war.attackerId
  MySQL.update('UPDATE cold_active_wars SET status=?, winner_id=?, ended_at=NOW() WHERE id=?', {'ended', winnerId, warId})
  local winner = MySQL.Sync.fetchAll('SELECT name, color FROM cold_gangs WHERE id = ?', {winnerId})
  MySQL.update('UPDATE territories SET gang_id=?, gang_name=?, claimed_at=NOW(), color_hex=? WHERE name=?', {winnerId, winner[1].name, winner[1].color or '#808080', war.territoryName})
  ColdGangs.Core.AddGangMoney(winnerId, Config.Wars and Config.Wars.winReward or 0, "War Victory Reward")
  local loserId = winnerId == war.attackerId and war.defenderId or war.attackerId
  ColdGangs.Core.AddGangMoney(loserId, Config.Wars and Config.Wars.loseReward or 0, "War Consolation Prize")
  TriggerClientEvent('cold-gangs:client:WarEnded', -1, warId, winnerId, winner and winner[1] and winner[1].name or '')
  ActiveWars[warId] = nil
  TriggerClientEvent('cold-gangs:client:SyncWars', -1, ActiveWars)
end)
QBCore.Functions.CreateCallback('cold-gangs:server:GetActiveWars', function(source, cb) cb(ActiveWars) end)
CreateThread(function()
  while true do
    Wait(60000)
    TriggerClientEvent('cold-gangs:client:SyncWars', -1, ActiveWars)
  end
end)
