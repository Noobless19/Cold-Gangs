local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}

local function isAdmin(src)
  return ColdGangs.Permissions and ColdGangs.Permissions.IsPlayerAdmin(src)
end
-- alias for mixed case usage in older code
local function IsAdmin(src) return isAdmin(src) end

local function getPlayer(src) return QBCore.Functions.GetPlayer(src) end
local function clamp(n, a, b) n = tonumber(n) or a return math.max(a, math.min(b, n)) end

local function gangNameById(id)
  local r = MySQL.Sync.fetchAll('SELECT name FROM cold_gangs WHERE id = ?', { id })
  return r and r[1] and r[1].name or nil
end

-- Create Gang (leader = the admin who creates it)
RegisterNetEvent('cold-gangs:admin:CreateGang', function(name, tag, color, maxMembers)
  local src = source
  if not IsAdmin(src) then return end
  name = (name or ''):sub(1, 50)
  tag = (tag or ''):sub(1, 10)
  if name == '' or tag == '' then return end

  color = color or '#ff3e3e'
  maxMembers = clamp(maxMembers or 25, 5, 50)

  local P = getPlayer(src); if not P then return end
  local leaderCid = P.PlayerData.citizenid
  local leaderName = (P.PlayerData.charinfo and (P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname)) or P.PlayerData.name

  local gid = MySQL.insert.await([[
    INSERT INTO cold_gangs (name, tag, leader, level, bank, reputation, max_members, color, logo)
    VALUES (?, ?, ?, 1, 0, 0, ?, ?, NULL)
  ]], { name, tag, leaderCid, maxMembers, color })
  if not gid or gid <= 0 then
    TriggerClientEvent('QBCore:Notify', src, 'Failed to create gang (DB)', 'error')
    return
  end

  MySQL.insert.await([[
    INSERT INTO cold_gang_members (gang_id, citizen_id, rank, name)
    VALUES (?, ?, 6, ?)
    ON DUPLICATE KEY UPDATE rank=VALUES(rank), name=VALUES(name)
  ]], { gid, leaderCid, leaderName })

  TriggerClientEvent('QBCore:Notify', src, ('Gang created: %s'):format(name), 'success')
end)

-- Update gang
RegisterNetEvent('cold-gangs:admin:UpdateGang', function(gangId, name, tag, color, maxMembers)
  local src = source
  if not IsAdmin(src) then return end
  gangId = tonumber(gangId) or 0
  if gangId <= 0 then return end

  name = (name or ''):sub(1, 50)
  tag = (tag or ''):sub(1, 10)
  color = color or '#ff3e3e'
  maxMembers = clamp(maxMembers or 25, 5, 50)

  MySQL.update.await('UPDATE cold_gangs SET name=?, tag=?, color=?, max_members=? WHERE id=?',
    { name, tag, color, maxMembers, gangId })
  TriggerClientEvent('QBCore:Notify', src, 'Gang updated', 'success')
end)

-- Delete gang (cascades via FK)
RegisterNetEvent('cold-gangs:admin:DeleteGang', function(gangId)
  local src = source
  if not IsAdmin(src) then return end
  gangId = tonumber(gangId) or 0
  if gangId <= 0 then return end
  local gname = gangNameById(gangId) or ('#' .. gangId)
  MySQL.update.await('DELETE FROM cold_gang_members WHERE gang_id = ?', { gangId })
  MySQL.update.await('DELETE FROM cold_gangs WHERE id = ?', { gangId })
  TriggerClientEvent('QBCore:Notify', src, ('Gang deleted: %s'):format(gname), 'success')
end)

-- Add member (NET EVENT version used elsewhere)
RegisterNetEvent('cold-gangs:admin:AddMember', function(gangId, citizenId, rank)
  local src = source
  if not IsAdmin(src) then return end
  gangId = tonumber(gangId) or 0
  rank = clamp(rank or 1, 1, 6)
  if gangId <= 0 or not citizenId or citizenId == '' then return end

  local g = MySQL.query.await('SELECT id, max_members FROM cold_gangs WHERE id = ?', { gangId })
  if not g or not g[1] then return end
  local count = MySQL.scalar.await('SELECT COUNT(*) FROM cold_gang_members WHERE gang_id = ?', { gangId }) or 0
  if count >= (g[1].max_members or 25) then return end

  local inGang = MySQL.scalar.await('SELECT COUNT(*) FROM cold_gang_members WHERE citizen_id = ?', { citizenId }) or 0
  if inGang > 0 then return end

  local pname = MySQL.scalar.await([[
    SELECT CONCAT(
      JSON_UNQUOTE(JSON_EXTRACT(charinfo,'$.firstname')), ' ',
      JSON_UNQUOTE(JSON_EXTRACT(charinfo,'$.lastname'))
    ) FROM players WHERE citizenid = ?
  ]], { citizenId }) or citizenId

  MySQL.insert.await([[
    INSERT INTO cold_gang_members (gang_id, citizen_id, rank, name)
    VALUES (?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE rank=VALUES(rank), name=VALUES(name)
  ]], { gangId, citizenId, rank, pname })
  TriggerClientEvent('QBCore:Notify', src, 'Member added', 'success')
end)

-- Promote member
RegisterNetEvent('cold-gangs:admin:PromoteMember', function(gangId, citizenId)
  local src = source
  if not IsAdmin(src) then return end
  gangId = tonumber(gangId) or 0
  if gangId <= 0 or not citizenId then return end
  local r = MySQL.query.await('SELECT rank FROM cold_gang_members WHERE gang_id=? AND citizen_id=?', { gangId, citizenId })
  if not r or not r[1] then return end
  local newRank = math.min(6, (tonumber(r[1].rank) or 1) + 1)
  MySQL.update.await('UPDATE cold_gang_members SET rank=? WHERE gang_id=? AND citizen_id=?', { newRank, gangId, citizenId })
  TriggerClientEvent('QBCore:Notify', src, 'Member promoted', 'success')
end)

-- Demote member
RegisterNetEvent('cold-gangs:admin:DemoteMember', function(gangId, citizenId)
  local src = source
  if not IsAdmin(src) then return end
  gangId = tonumber(gangId) or 0
  if gangId <= 0 or not citizenId then return end
  local r = MySQL.query.await('SELECT rank FROM cold_gang_members WHERE gang_id=? AND citizen_id=?', { gangId, citizenId })
  if not r or not r[1] then return end
  local newRank = math.max(1, (tonumber(r[1].rank) or 1) - 1)
  MySQL.update.await('UPDATE cold_gang_members SET rank=? WHERE gang_id=? AND citizen_id=?', { newRank, gangId, citizenId })
  TriggerClientEvent('QBCore:Notify', src, 'Member demoted', 'success')
end)

-- Remove member
RegisterNetEvent('cold-gangs:admin:RemoveMember', function(gangId, citizenId)
  local src = source
  if not IsAdmin(src) then return end
  gangId = tonumber(gangId) or 0
  if gangId <= 0 or not citizenId then return end

  local leader = MySQL.scalar.await('SELECT leader FROM cold_gangs WHERE id = ?', { gangId })
  if leader and leader == citizenId then return end -- don’t remove leader

  MySQL.update.await('DELETE FROM cold_gang_members WHERE gang_id=? AND citizen_id=?', { gangId, citizenId })
  TriggerClientEvent('QBCore:Notify', src, 'Member removed', 'success')
end)

-- Set territory owner (correct table name: territories)
RegisterNetEvent('cold-gangs:admin:SetTerritoryOwner', function(territoryName, gangId)
  local src = source
  if not IsAdmin(src) then return end
  if not territoryName or territoryName == '' then return end
  local gid = tonumber(gangId) or 0

  if gid > 0 then
    local g = MySQL.Sync.fetchAll('SELECT name, color FROM cold_gangs WHERE id = ?', { gid })
    if not g or not g[1] then return end
    MySQL.update.await('UPDATE territories SET gang_id=?, gang_name=?, claimed_at=NOW(), color_hex=? WHERE name=?',
      { gid, g[1].name, g[1].color or '#808080', territoryName })
  else
    MySQL.update.await('UPDATE territories SET gang_id=NULL, gang_name="Unclaimed", claimed_at=NULL, color_hex="#808080" WHERE name=?', { territoryName })
  end
  TriggerClientEvent('QBCore:Notify', src, 'Territory owner updated', 'success')
end)
