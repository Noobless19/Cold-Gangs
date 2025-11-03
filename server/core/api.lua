local QBCore = exports['qb-core']:GetCoreObject()

ColdGangs = ColdGangs or {}
ColdGangs.API = ColdGangs.API or {}

local function getPlayer(src) return QBCore.Functions.GetPlayer(src) end

-- Basic: player -> gang id
QBCore.Functions.CreateCallback('cold-gangs:server:GetPlayerGangId', function(source, cb)
  local Player = getPlayer(source)
  if not Player then cb(nil) return end
  local r = MySQL.Sync.fetchAll('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', { Player.PlayerData.citizenid })
  cb(r and r[1] and r[1].gang_id or nil)
end)

-- Police count for heists and other gating
QBCore.Functions.CreateCallback('cold-gangs:server:GetPoliceCount', function(source, cb)
  local jobs = Config.PoliceJobs or { 'police', 'sheriff' }
  local count = 0
  for _, src in pairs(QBCore.Functions.GetPlayers()) do
    local P = QBCore.Functions.GetPlayer(src)
    if P and P.PlayerData.job and P.PlayerData.job.onduty then
      local n = P.PlayerData.job.name
      for _, j in ipairs(jobs) do
        if j == n then count = count + 1 break end
      end
    end
  end
  cb(count)
end)

-- Admin: list all gangs (used in admin screens)
QBCore.Functions.CreateCallback('cold-gangs:admin:GetAllGangs', function(source, cb)
  if not ColdGangs.Permissions.IsPlayerAdmin(source) then cb({}) return end
  local rs = MySQL.Sync.fetchAll([[
    SELECT g.*, COUNT(m.citizen_id) as memberCount
    FROM cold_gangs g
    LEFT JOIN cold_gang_members m ON g.id = m.gang_id
    GROUP BY g.id
  ]])
  cb(rs or {})
end)

-- Admin/permission wrappers used across UI and clients
QBCore.Functions.CreateCallback('cold-gangs:server:IsPlayerAdmin', function(source, cb)
  cb(ColdGangs.Permissions and ColdGangs.Permissions.IsPlayerAdmin(source) or false)
end)

QBCore.Functions.CreateCallback('cold-gangs:server:HasGangPermission', function(source, cb, permission)
  cb(ColdGangs.Permissions and ColdGangs.Permissions.HasGangPermission(source, permission) or false)
end)

-- Is player in a gang?
QBCore.Functions.CreateCallback('cold-gangs:server:IsPlayerInGang', function(source, cb)
  local Player = getPlayer(source)
  if not Player then cb(false) return end
  local r = MySQL.Sync.fetchScalar('SELECT COUNT(*) FROM cold_gang_members WHERE citizen_id = ?', { Player.PlayerData.citizenid })
  cb((r or 0) > 0)
end)

-- Main gang object for current player (includes isLeader and money mirror)
QBCore.Functions.CreateCallback('cold-gangs:server:GetPlayerGang', function(source, cb)
  local Player = getPlayer(source)
  if not Player then cb(nil) return end
  local data = MySQL.Sync.fetchAll([[
    SELECT g.*, m.rank
    FROM cold_gang_members m
    JOIN cold_gangs g ON g.id = m.gang_id
    WHERE m.citizen_id = ?
  ]], { Player.PlayerData.citizenid })
  local row = data and data[1]
  if not row then cb(nil) return end
  cb({
    id = row.id, name = row.name, tag = row.tag, leader = row.leader, level = row.level,
    bank = row.bank, money = row.bank, reputation = row.reputation, max_members = row.max_members,
    color = row.color, logo = row.logo, rank = row.rank,
    isLeader = (row.leader == Player.PlayerData.citizenid)
  })
end)

-- Reputation (heists prereq)
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangReputation', function(source, cb, gangId)
  if not gangId then
    gangId = ColdGangs.Core.GetPlayerGangId(source)
    if not gangId then cb(0) return end
  end
  local rep = MySQL.Sync.fetchScalar('SELECT reputation FROM cold_gangs WHERE id = ?', { gangId }) or 0
  cb(rep)
end)

-- Drugs: fields list (normalized shape for clients/UI)
QBCore.Functions.CreateCallback('cold-gangs:server:GetDrugFields', function(source, cb)
  local rs = MySQL.Sync.fetchAll('SELECT * FROM cold_drug_fields', {}) or {}
  local out = {}
  for _, f in ipairs(rs) do
    table.insert(out, {
      id = f.id,
      resourceType = f.resource_type,
      growthStage = f.growth_stage,
      maxYield = f.max_yield,
      qualityRangeMin = f.quality_range_min,
      qualityRangeMax = f.quality_range_max,
      owner = f.owner,
      gangName = f.gang_name,
      territoryName = f.territory_name,
      location = f.location, -- JSON string; client decodes
    })
  end
  cb(out)
end)

-- Drugs: labs list (normalized shape for clients/UI)
QBCore.Functions.CreateCallback('cold-gangs:server:GetDrugLabs', function(source, cb)
  local rs = MySQL.Sync.fetchAll('SELECT * FROM cold_drug_labs', {}) or {}
  local out = {}
  for _, l in ipairs(rs) do
    table.insert(out, {
      id = l.id,
      drugType = l.drug_type,
      level = l.level,
      capacity = l.capacity,
      owner = l.owner,
      gangName = l.gang_name,
      territoryName = l.territory_name,
      security = l.security,
      location = l.location, -- JSON string; client decodes
    })
  end
  cb(out)
end)

-- Admin data aggregator (admin_refresh_data)
QBCore.Functions.CreateCallback('cold-gangs:server:GetAdminData', function(source, cb)
  if not ColdGangs.Permissions.IsPlayerAdmin(source) then cb({}) return end
  local gangs = MySQL.Sync.fetchAll('SELECT id, name, tag, leader, level, bank, reputation, max_members, color FROM cold_gangs', {}) or {}
  local territories = MySQL.Sync.fetchAll('SELECT * FROM territories', {}) or {}
  local logs = MySQL.Sync.fetchAll('SELECT * FROM cold_gang_logs ORDER BY id DESC LIMIT 200', {}) or {}

  local players = {}
  for _, src in ipairs(QBCore.Functions.GetPlayers()) do
    local P = QBCore.Functions.GetPlayer(src)
    if P then
      local cid = P.PlayerData.citizenid
      local gid = MySQL.Sync.fetchScalar('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', { cid })
      local gname = gid and MySQL.Sync.fetchScalar('SELECT name FROM cold_gangs WHERE id = ?', { gid }) or nil
      players[#players+1] = {
        source = src,
        citizenid = cid,
        name = (P.PlayerData.charinfo and (P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname)) or P.PlayerData.name,
        gang_id = gid,
        gang_name = gname
      }
    end
  end

  cb({ gangs = gangs, territories = territories, players = players, logs = logs })
end)

-- Admin: fetch members of a gang (used by UI admin_get_gang_members)
QBCore.Functions.CreateCallback('cold-gangs:admin:GetGangMembers', function(source, cb, gangId)
  if not ColdGangs.Permissions.IsPlayerAdmin(source) then cb({}) return end
  local rs = MySQL.Sync.fetchAll('SELECT citizen_id, name, rank, joined_at FROM cold_gang_members WHERE gang_id = ?', { gangId }) or {}
  local out = {}
  for _, m in ipairs(rs) do
    local isOnline = QBCore.Functions.GetPlayerByCitizenId(m.citizen_id) ~= nil
    table.insert(out, { citizenId = m.citizen_id, name = m.name, rank = m.rank, joinedAt = m.joined_at, isOnline = isOnline })
  end
  cb(out)
end)

-- Expose core helpers for other resources
exports('AddGangMoney',       ColdGangs.Core.AddGangMoney)
exports('RemoveGangMoney',    ColdGangs.Core.RemoveGangMoney)
exports('AddGangReputation',  ColdGangs.Core.AddGangReputation)
exports('NotifyGangMembers',  ColdGangs.Core.NotifyGangMembers)
exports('GetPlayerGangId',    ColdGangs.Core.GetPlayerGangId)
