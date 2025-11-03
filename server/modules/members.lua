local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}

-- Initialize pending invites cleanup
ColdGangs.PendingInvites = ColdGangs.PendingInvites or {}

RegisterNetEvent('cold-gangs:server:InvitePlayerToGang', function(targetId)
  local src = source
  
  -- Rate limiting
  if not ColdGangs.RateLimit.CheckLimit(src, 'invite_member', 10) then
    TriggerClientEvent('QBCore:Notify', src, 'Too many requests. Please wait.', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  
  -- Validate target ID
  targetId = tonumber(targetId)
  if not targetId or targetId <= 0 then return end
  
  local tPlayer = QBCore.Functions.GetPlayer(targetId)
  if not tPlayer then 
    TriggerClientEvent('QBCore:Notify', src, 'Player not found', 'error')
    return 
  end
  
  -- Check inviter's gang
  MySQL.query('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid}, function(r)
    if not r or #r == 0 then return end
    local gangId = r[1].gang_id
    
    -- Permission check
    if not ColdGangs.Permissions.HasGangPermission(src, 'inviteMembers') then 
      TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to invite members', 'error')
      return 
    end
    
    -- Check if target is already in a gang
    MySQL.query('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {tPlayer.PlayerData.citizenid}, function(tg)
      if tg and #tg > 0 then 
        TriggerClientEvent('QBCore:Notify', src, 'Player is already in a gang', 'error')
        return 
      end
      
      -- Check member count and get gang data
      MySQL.query('SELECT COUNT(*) as count FROM cold_gang_members WHERE gang_id = ?', {gangId}, function(countResult)
        local count = countResult and countResult[1] and countResult[1].count or 0
        
        MySQL.query('SELECT * FROM cold_gangs WHERE id = ?', {gangId}, function(gdata)
          if not gdata or #gdata == 0 then return end
          
          local maxMembers = gdata[1].max_members or Config.MaxGangMembers
          if count >= maxMembers then 
            TriggerClientEvent('QBCore:Notify', src, 'Gang is at maximum capacity', 'error')
            return 
          end
          
          local charinfo = Player.PlayerData.charinfo or {}
          local inviterName = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or 'Unknown')
          
          local inviteId = "invite_"..math.random(100000,999999).."_"..os.time()
          ColdGangs.PendingInvites[inviteId] = {
            gangId = gangId,
            gangName = gdata[1].name,
            inviterId = Player.PlayerData.citizenid,
            inviterName = inviterName,
            targetId = targetId,
            expires = os.time() + math.floor((Config.InvitationExpireTime or 300000)/1000),
            created = os.time()
          }
          
          TriggerClientEvent('cold-gangs:client:ReceiveGangInvite', targetId, {
            id = inviteId,
            gangName = gdata[1].name,
            gangTag = gdata[1].tag,
            inviterName = inviterName
          })
          
          TriggerClientEvent('QBCore:Notify', src, 'Invitation sent', 'success')
        end)
      end)
    end)
  end)
end)
RegisterNetEvent('cold-gangs:server:AcceptGangInvite', function(inviteId)
  local src = source
  
  -- Rate limiting
  if not ColdGangs.RateLimit.CheckLimit(src, 'accept_invite', 5) then
    TriggerClientEvent('QBCore:Notify', src, 'Too many requests. Please wait.', 'error')
    return
  end
  
  -- Validate invite ID
  if not inviteId or type(inviteId) ~= "string" then return end
  
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  
  local invite = ColdGangs.PendingInvites[inviteId]
  
  -- Validate invite exists and not expired
  if not invite then 
    TriggerClientEvent('QBCore:Notify', src, 'Invalid invitation', 'error')
    return 
  end
  
  if invite.expires < os.time() then 
    ColdGangs.PendingInvites[inviteId] = nil
    TriggerClientEvent('QBCore:Notify', src, 'Invitation has expired', 'error')
    return 
  end
  
  -- Verify target matches
  if invite.targetId ~= src then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid invitation', 'error')
    return
  end
  
  -- Check if already in a gang (atomic check)
  MySQL.query('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid}, function(ex)
    if ex and #ex > 0 then 
      ColdGangs.PendingInvites[inviteId] = nil
      TriggerClientEvent('QBCore:Notify', src, 'You are already in a gang', 'error')
      return 
    end
    
    -- Get gang data and check member limit atomically
    MySQL.query('SELECT * FROM cold_gangs WHERE id = ?', {invite.gangId}, function(g)
      if not g or #g == 0 then 
        ColdGangs.PendingInvites[inviteId] = nil
        return 
      end
      
      -- Check member count
      MySQL.query('SELECT COUNT(*) as count FROM cold_gang_members WHERE gang_id = ?', {invite.gangId}, function(countResult)
        local count = countResult and countResult[1] and countResult[1].count or 0
        local maxMembers = g[1].max_members or Config.MaxGangMembers
        
        if count >= maxMembers then
          ColdGangs.PendingInvites[inviteId] = nil
          TriggerClientEvent('QBCore:Notify', src, 'Gang is now at maximum capacity', 'error')
          return
        end
        
        -- Use transaction for atomic insert
        local charinfo = Player.PlayerData.charinfo or {}
        local memberName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Player')
        
        MySQL.insert('INSERT INTO cold_gang_members (gang_id, citizen_id, rank, name) VALUES (?, ?, ?, ?)', 
          {invite.gangId, Player.PlayerData.citizenid, 1, memberName}, function(insertId)
            if insertId then
              ColdGangs.PendingInvites[inviteId] = nil
              
              TriggerClientEvent('cold-gangs:client:GangJoined', src, {
                id = g[1].id, name = g[1].name, tag = g[1].tag, rank = 1, isLeader = false, 
                bank = g[1].bank, color = g[1].color, logo = g[1].logo
              })
              
              ColdGangs.Core.NotifyGangMembers(invite.gangId, "New Member", memberName .. " has joined the gang")
              TriggerClientEvent('QBCore:Notify', src, 'You have joined ' .. g[1].name, 'success')
            else
              TriggerClientEvent('QBCore:Notify', src, 'Failed to join gang', 'error')
            end
          end)
      end)
    end)
  end)
end)
RegisterNetEvent('cold-gangs:server:DeclineGangInvite', function(inviteId)
  ColdGangs.PendingInvites = ColdGangs.PendingInvites or {}
  ColdGangs.PendingInvites[inviteId] = nil
end)
RegisterNetEvent('cold-gangs:server:KickMember', function(targetCitizenId)
  local src = source
  
  -- Rate limiting
  if not ColdGangs.RateLimit.CheckLimit(src, 'kick_member', 10) then
    TriggerClientEvent('QBCore:Notify', src, 'Too many requests. Please wait.', 'error')
    return
  end
  
  -- Validate input
  local valid, err = ColdGangs.Validation.ValidateCitizenId(targetCitizenId)
  if not valid then
    TriggerClientEvent('QBCore:Notify', src, err or 'Invalid citizen ID', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  
  MySQL.query('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid}, function(r)
    if not r or #r == 0 then return end
    local gangId = r[1].gang_id
    
    if not ColdGangs.Permissions.HasGangPermission(src, 'kickMembers') then 
      TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to kick members', 'error')
      return 
    end
    
    MySQL.query('SELECT name, rank FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, targetCitizenId}, function(t)
      if not t or #t == 0 then 
        TriggerClientEvent('QBCore:Notify', src, 'Member not found', 'error')
        return 
      end
      
      MySQL.query('SELECT leader FROM cold_gangs WHERE id = ?', {gangId}, function(g)
        if g and #g > 0 and g[1].leader == targetCitizenId then 
          TriggerClientEvent('QBCore:Notify', src, 'Cannot kick the gang leader', 'error')
          return 
        end
        
        MySQL.query('SELECT rank FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', 
          {gangId, Player.PlayerData.citizenid}, function(playerRankResult)
            local playerRank = playerRankResult and playerRankResult[1] and playerRankResult[1].rank or 1
            
            if t[1].rank >= playerRank and g and #g > 0 and g[1].leader ~= Player.PlayerData.citizenid then 
              TriggerClientEvent('QBCore:Notify', src, 'You cannot kick members of equal or higher rank', 'error')
              return 
            end
            
            MySQL.update('DELETE FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', 
              {gangId, targetCitizenId}, function(affectedRows)
                if affectedRows > 0 then
                  ColdGangs.Core.NotifyGangMembers(gangId, "Member Kicked", t[1].name .. " was kicked from the gang")
                  local TP = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
                  if TP then
                    TriggerClientEvent('cold-gangs:client:GangLeft', TP.PlayerData.source)
                  end
                  TriggerClientEvent('QBCore:Notify', src, 'Member kicked successfully', 'success')
                end
              end)
          end)
      end)
    end)
  end)
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
