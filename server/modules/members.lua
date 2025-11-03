local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}
RegisterNetEvent('cold-gangs:server:InvitePlayerToGang', function(targetId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local tPlayer = QBCore.Functions.GetPlayer(targetId)
  if not tPlayer then return end
  local r = MySQL.Sync.fetchAll('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid})
  if not r or #r==0 then return end
  local gangId = r[1].gang_id
  if not ColdGangs.Permissions.HasGangPermission(src, 'inviteMembers') then return end
  local tg = MySQL.Sync.fetchAll('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {tPlayer.PlayerData.citizenid})
  if tg and #tg>0 then return end
  local count = MySQL.Sync.fetchScalar('SELECT COUNT(*) FROM cold_gang_members WHERE gang_id = ?', {gangId})
  local gdata = MySQL.Sync.fetchAll('SELECT * FROM cold_gangs WHERE id = ?', {gangId})
  if not gdata or #gdata==0 then return end
  local maxMembers = gdata[1].max_members or Config.MaxGangMembers
  if count >= maxMembers then return end
  local inviteId = "invite_"..math.random(100000,999999).."_"..os.time()
  ColdGangs.PendingInvites = ColdGangs.PendingInvites or {}
  ColdGangs.PendingInvites[inviteId] = {
    gangId = gangId,
    gangName = gdata[1].name,
    inviterId = Player.PlayerData.citizenid,
    inviterName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
    targetId = targetId,
    expires = os.time() + math.floor((Config.InvitationExpireTime or 300000)/1000),
    created = os.time()
  }
  TriggerClientEvent('cold-gangs:client:ReceiveGangInvite', targetId, {
    id = inviteId,
    gangName = gdata[1].name,
    gangTag = gdata[1].tag,
    inviterName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
  })
end)
RegisterNetEvent('cold-gangs:server:AcceptGangInvite', function(inviteId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  ColdGangs.PendingInvites = ColdGangs.PendingInvites or {}
  local invite = ColdGangs.PendingInvites[inviteId]
  if not invite or invite.expires < os.time() then return end
  local ex = MySQL.Sync.fetchAll('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid})
  if ex and #ex>0 then return end
  local g = MySQL.Sync.fetchAll('SELECT * FROM cold_gangs WHERE id = ?', {invite.gangId})
  if not g or #g==0 then return end
  local memberName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
  MySQL.Sync.insert('INSERT INTO cold_gang_members (gang_id, citizen_id, rank, name) VALUES (?, ?, ?, ?)', {invite.gangId, Player.PlayerData.citizenid, 1, memberName})
  ColdGangs.PendingInvites[inviteId] = nil
  TriggerClientEvent('cold-gangs:client:GangJoined', src, {
    id = g[1].id, name = g[1].name, tag = g[1].tag, rank = 1, isLeader = false, bank = g[1].bank, color = g[1].color, logo = g[1].logo
  })
  ColdGangs.Core.NotifyGangMembers(invite.gangId, "New Member", memberName .. " has joined the gang")
end)
RegisterNetEvent('cold-gangs:server:DeclineGangInvite', function(inviteId)
  ColdGangs.PendingInvites = ColdGangs.PendingInvites or {}
  ColdGangs.PendingInvites[inviteId] = nil
end)
RegisterNetEvent('cold-gangs:server:KickMember', function(targetCitizenId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local r = MySQL.Sync.fetchAll('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid})
  if not r or #r==0 then return end
  local gangId = r[1].gang_id
  if not ColdGangs.Permissions.HasGangPermission(src, 'kickMembers') then return end
  local t = MySQL.Sync.fetchAll('SELECT name, rank FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, targetCitizenId})
  if not t or #t==0 then return end
  local g = MySQL.Sync.fetchAll('SELECT leader FROM cold_gangs WHERE id = ?', {gangId})
  if g and #g>0 and g[1].leader == targetCitizenId then return end
  local playerRank = MySQL.Sync.fetchScalar('SELECT rank FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, Player.PlayerData.citizenid})
  if t[1].rank >= playerRank and g and #g>0 and g[1].leader ~= Player.PlayerData.citizenid then return end
  MySQL.Sync.execute('DELETE FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, targetCitizenId})
  ColdGangs.Core.NotifyGangMembers(gangId, "Member Kicked", t[1].name .. " was kicked from the gang")
  local TP = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
  if TP then
    TriggerClientEvent('cold-gangs:client:GangLeft', TP.PlayerData.source)
  end
end)
RegisterNetEvent('cold-gangs:server:PromoteMember', function(targetCitizenId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local r = MySQL.Sync.fetchAll('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid})
  if not r or #r==0 then return end
  local gangId = r[1].gang_id
  if not ColdGangs.Permissions.HasGangPermission(src, 'manageRanks') then return end
  local t = MySQL.Sync.fetchAll('SELECT name, rank FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, targetCitizenId})
  if not t or #t==0 then return end
  if t[1].rank >= 5 then return end
  local playerRank = MySQL.Sync.fetchScalar('SELECT rank FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, Player.PlayerData.citizenid})
  if (t[1].rank + 1) >= playerRank then
    local leader = MySQL.Sync.fetchAll('SELECT leader FROM cold_gangs WHERE id = ?', {gangId})
    if not (leader and #leader>0 and leader[1].leader == Player.PlayerData.citizenid) then return end
  end
  local newRank = t[1].rank + 1
  MySQL.Sync.execute('UPDATE cold_gang_members SET rank = ? WHERE gang_id = ? AND citizen_id = ?', {newRank, gangId, targetCitizenId})
  ColdGangs.Core.NotifyGangMembers(gangId, "Member Promoted", t[1].name .. " was promoted to rank " .. newRank)
  local TP = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
  if TP then
    TriggerClientEvent('cold-gangs:client:RankChanged', TP.PlayerData.source, newRank)
  end
end)
RegisterNetEvent('cold-gangs:server:DemoteMember', function(targetCitizenId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local r = MySQL.Sync.fetchAll('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid})
  if not r or #r==0 then return end
  local gangId = r[1].gang_id
  if not ColdGangs.Permissions.HasGangPermission(src, 'manageRanks') then return end
  local t = MySQL.Sync.fetchAll('SELECT name, rank FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, targetCitizenId})
  if not t or #t==0 then return end
  if t[1].rank <= 1 then return end
  local leader = MySQL.Sync.fetchAll('SELECT leader FROM cold_gangs WHERE id = ?', {gangId})
  if leader and #leader>0 and leader[1].leader == targetCitizenId then return end
  local playerRank = MySQL.Sync.fetchScalar('SELECT rank FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, Player.PlayerData.citizenid})
  if t[1].rank >= playerRank then
    if not (leader and #leader>0 and leader[1].leader == Player.PlayerData.citizenid) then return end
  end
  local newRank = t[1].rank - 1
  MySQL.Sync.execute('UPDATE cold_gang_members SET rank = ? WHERE gang_id = ? AND citizen_id = ?', {newRank, gangId, targetCitizenId})
  ColdGangs.Core.NotifyGangMembers(gangId, "Member Demoted", t[1].name .. " was demoted to rank " .. newRank)
  local TP = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
  if TP then
    TriggerClientEvent('cold-gangs:client:RankChanged', TP.PlayerData.source, newRank)
  end
end)
RegisterNetEvent('cold-gangs:server:LeaveGang', function()
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local r = MySQL.Sync.fetchAll('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid})
  if not r or #r==0 then return end
  local gangId = r[1].gang_id
  local g = MySQL.Sync.fetchAll('SELECT leader FROM cold_gangs WHERE id = ?', {gangId})
  if g and #g>0 and g[1].leader == Player.PlayerData.citizenid then return end
  local name = MySQL.Sync.fetchScalar('SELECT name FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, Player.PlayerData.citizenid})
  MySQL.Sync.execute('DELETE FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, Player.PlayerData.citizenid})
  TriggerClientEvent('cold-gangs:client:GangLeft', src)
  ColdGangs.Core.NotifyGangMembers(gangId, "Member Left", name .. " has left the gang")
end)
RegisterNetEvent('cold-gangs:server:TransferLeadership', function(targetCitizenId)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local r = MySQL.Sync.fetchAll('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid})
  if not r or #r==0 then return end
  local gangId = r[1].gang_id
  local g = MySQL.Sync.fetchAll('SELECT leader FROM cold_gangs WHERE id = ?', {gangId})
  if not g or #g==0 or g[1].leader ~= Player.PlayerData.citizenid then return end
  local tm = MySQL.Sync.fetchAll('SELECT name FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, targetCitizenId})
  if not tm or #tm==0 then return end
  MySQL.Sync.execute('UPDATE cold_gangs SET leader = ? WHERE id = ?', {targetCitizenId, gangId})
  MySQL.Sync.execute('UPDATE cold_gang_members SET rank = ? WHERE gang_id = ? AND citizen_id = ?', {6, gangId, targetCitizenId})
  MySQL.Sync.execute('UPDATE cold_gang_members SET rank = ? WHERE gang_id = ? AND citizen_id = ?', {5, gangId, Player.PlayerData.citizenid})
  ColdGangs.Core.NotifyGangMembers(gangId, "Leadership Transferred", Player.PlayerData.charinfo.firstname .. " has transferred leadership to " .. tm[1].name)
  local TP = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
  if TP then
    TriggerClientEvent('cold-gangs:client:RankChanged', TP.PlayerData.source, 6)
  end
  TriggerClientEvent('cold-gangs:client:RankChanged', src, 5)
end)
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangMembers', function(source, cb, gangId)
  local result = MySQL.Sync.fetchAll('SELECT citizen_id, name, rank, joined_at FROM cold_gang_members WHERE gang_id = ?', {gangId})
  local members = {}
  if result then
    for _, m in ipairs(result) do
      local isOnline = QBCore.Functions.GetPlayerByCitizenId(m.citizen_id) ~= nil
      table.insert(members, { citizenId = m.citizen_id, name = m.name, rank = m.rank, joinedAt = m.joined_at, isOnline = isOnline })
    end
  end
  cb(members)
end)
CreateThread(function()
  while true do
    Wait(60000)
    if ColdGangs.PendingInvites then
      local now = os.time()
      for id, inv in pairs(ColdGangs.PendingInvites) do
        if now > inv.expires then ColdGangs.PendingInvites[id] = nil end
      end
    end
  end
end)
