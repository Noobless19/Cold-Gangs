-- server/core/compat.lua
local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}

local function Player(src) return QBCore.Functions.GetPlayer(src) end
local function IsAdmin(src) return (ColdGangs.Permissions and ColdGangs.Permissions.IsPlayerAdmin(src)) == true end

-- Admin: Create
QBCore.Functions.CreateCallback('cold-gangs:server:AdminCreateGang', function(src, cb, name, tag, color, maxMembers,
  mainSlots, mainWeight, sharedSlots, sharedWeight, sharedLimit)
  if not IsAdmin(src) then cb(false, "No permission") return end

  name = (name or ''):sub(1, 50)
  tag = (tag or ''):sub(1, 10)
  if name == '' or tag == '' then cb(false, "Invalid input") return end

  color = color or '#ff3e3e'
  maxMembers = tonumber(maxMembers) or 25
  mainSlots = tonumber(mainSlots) or 50
  mainWeight = tonumber(mainWeight) or 1000000
  sharedSlots = tonumber(sharedSlots) or 50
  sharedWeight = tonumber(sharedWeight) or 1000000
  sharedLimit = tonumber(sharedLimit) or 0

  local P = Player(src); if not P then cb(false, "No player") return end
  local leaderCid = P.PlayerData.citizenid
  local leaderName = (P.PlayerData.charinfo and (P.PlayerData.charinfo.firstname .. ' ' .. P.PlayerData.charinfo.lastname)) or P.PlayerData.name

  local gid = MySQL.insert.await([[
    INSERT INTO cold_gangs
      (name, tag, leader, level, bank, reputation, max_members, color, logo,
       main_stash_slots, main_stash_weight, shared_stash_slots, shared_stash_weight, shared_stash_limit_count)
    VALUES (?, ?, ?, 1, 0, 0, ?, ?, NULL, ?, ?, ?, ?, ?)
  ]], { name, tag, leaderCid, maxMembers, color, mainSlots, mainWeight, sharedSlots, sharedWeight, sharedLimit })
  if not gid or gid <= 0 then cb(false, "DB error") return end

  MySQL.insert.await([[
    INSERT INTO cold_gang_members (gang_id, citizen_id, rank, name)
    VALUES (?, ?, 6, ?)
    ON DUPLICATE KEY UPDATE rank=VALUES(rank), name=VALUES(name)
  ]], { gid, leaderCid, leaderName })

  cb(true, "OK")
end)

-- Admin: Update
QBCore.Functions.CreateCallback('cold-gangs:server:AdminUpdateGang', function(src, cb, gangId, name, tag, color, maxMembers,
  mainSlots, mainWeight, sharedSlots, sharedWeight, sharedLimit)
  if not IsAdmin(src) then cb(false, "No permission") return end
  gangId = tonumber(gangId) or 0; if gangId <= 0 then cb(false, "Invalid gang") return end

  name = (name or ''):sub(1, 50)
  tag = (tag or ''):sub(1, 10)
  color = color or '#ff3e3e'
  maxMembers = tonumber(maxMembers) or 25
  mainSlots = tonumber(mainSlots) or 50
  mainWeight = tonumber(mainWeight) or 1000000
  sharedSlots = tonumber(sharedSlots) or 50
  sharedWeight = tonumber(sharedWeight) or 1000000
  sharedLimit = tonumber(sharedLimit) or 0

  local rows = MySQL.update.await([[
    UPDATE cold_gangs
    SET name=?, tag=?, color=?, max_members=?,
        main_stash_slots=?, main_stash_weight=?,
        shared_stash_slots=?, shared_stash_weight=?,
        shared_stash_limit_count=?
    WHERE id=?
  ]], { name, tag, color, maxMembers,
        mainSlots, mainWeight, sharedSlots, sharedWeight, sharedLimit, gangId })

  -- Ensure existing main stash record caps are aligned (optional but recommended)
  MySQL.update.await('UPDATE cold_gang_stashes SET slots=?, weight=? WHERE gang_id=?', { mainSlots, mainWeight, gangId })

  cb((rows or 0) > 0, ((rows or 0) > 0) and "OK" or "Not found")
end)

-- Admin: Delete
QBCore.Functions.CreateCallback('cold-gangs:server:AdminDeleteGang', function(src, cb, gangId)
  if not IsAdmin(src) then cb(false, "No permission") return end
  gangId = tonumber(gangId) or 0; if gangId <= 0 then cb(false, "Invalid gang") return end
  MySQL.update.await('DELETE FROM cold_gang_members WHERE gang_id = ?', { gangId })
  local rows = MySQL.update.await('DELETE FROM cold_gangs WHERE id = ?', { gangId })
  cb((rows or 0) > 0, ((rows or 0) > 0) and "OK" or "Not found")
end)

-- Admin: Add/Promote/Demote/Remove/GetMembers
QBCore.Functions.CreateCallback('cold-gangs:server:AdminAddMember', function(src, cb, gangId, citizenId, rank)
  if not IsAdmin(src) then cb(false, "No permission") return end
  gangId = tonumber(gangId) or 0
  rank = math.max(1, math.min(6, tonumber(rank) or 1))
  if gangId <= 0 or not citizenId or citizenId == '' then cb(false, "Invalid") return end

  local g = MySQL.query.await('SELECT id, max_members FROM cold_gangs WHERE id = ?', { gangId })
  if not g or not g[1] then cb(false, "Gang not found") return end
  local count = MySQL.scalar.await('SELECT COUNT(*) FROM cold_gang_members WHERE gang_id = ?', { gangId }) or 0
  if count >= (g[1].max_members or 25) then cb(false, "Gang is full") return end

  local inGang = MySQL.scalar.await('SELECT COUNT(*) FROM cold_gang_members WHERE citizen_id = ?', { citizenId }) or 0
  if inGang > 0 then cb(false, "Player already in a gang") return end

  local pname = MySQL.scalar.await([[
    SELECT CONCAT(JSON_UNQUOTE(JSON_EXTRACT(charinfo,'$.firstname')),' ',JSON_UNQUOTE(JSON_EXTRACT(charinfo,'$.lastname')))
    FROM players WHERE citizenid = ?
  ]], { citizenId }) or citizenId

  MySQL.insert.await([[
    INSERT INTO cold_gang_members (gang_id, citizen_id, rank, name)
    VALUES (?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE rank=VALUES(rank), name=VALUES(name)
  ]], { gangId, citizenId, rank, pname })

  cb(true, "OK")
end)

QBCore.Functions.CreateCallback('cold-gangs:server:AdminPromoteMember', function(src, cb, gangId, citizenId)
  if not IsAdmin(src) then cb(false, "No permission") return end
  gangId = tonumber(gangId) or 0
  if gangId <= 0 or not citizenId then cb(false, "Invalid") return end
  local r = MySQL.query.await('SELECT rank FROM cold_gang_members WHERE gang_id=? AND citizen_id=?', { gangId, citizenId })
  if not r or not r[1] then cb(false, "Not a member") return end
  local newRank = math.min(6, (tonumber(r[1].rank) or 1) + 1)
  MySQL.update.await('UPDATE cold_gang_members SET rank=? WHERE gang_id=? AND citizen_id=?', { newRank, gangId, citizenId })
  cb(true, "OK")
end)

QBCore.Functions.CreateCallback('cold-gangs:server:AdminDemoteMember', function(src, cb, gangId, citizenId)
  if not IsAdmin(src) then cb(false, "No permission") return end
  gangId = tonumber(gangId) or 0
  if gangId <= 0 or not citizenId then cb(false, "Invalid") return end
  local r = MySQL.query.await('SELECT rank FROM cold_gang_members WHERE gang_id=? AND citizen_id=?', { gangId, citizenId })
  if not r or not r[1] then cb(false, "Not a member") return end
  local newRank = math.max(1, (tonumber(r[1].rank) or 1) - 1)
  MySQL.update.await('UPDATE cold_gang_members SET rank=? WHERE gang_id=? AND citizen_id=?', { newRank, gangId, citizenId })
  cb(true, "OK")
end)

QBCore.Functions.CreateCallback('cold-gangs:server:AdminRemoveMember', function(src, cb, gangId, citizenId)
  if not IsAdmin(src) then cb(false, "No permission") return end
  gangId = tonumber(gangId) or 0
  if gangId <= 0 or not citizenId then cb(false, "Invalid") return end
  local leader = MySQL.scalar.await('SELECT leader FROM cold_gangs WHERE id = ?', { gangId })
  if leader and leader == citizenId then cb(false, "Cannot remove leader") return end
  local rows = MySQL.update.await('DELETE FROM cold_gang_members WHERE gang_id=? AND citizen_id=?', { gangId, citizenId })
  cb((rows or 0) > 0, ((rows or 0) > 0) and "OK" or "Not found")
end)

QBCore.Functions.CreateCallback('cold-gangs:server:AdminGetGangMembers', function(src, cb, gangId)
  if not IsAdmin(src) then cb(false) return end
  gangId = tonumber(gangId) or 0; if gangId <= 0 then cb(false) return end
  local rs = MySQL.query.await([[
    SELECT citizen_id AS citizenid, name, rank, joined_at
    FROM cold_gang_members
    WHERE gang_id = ?
    ORDER BY rank DESC, joined_at ASC
  ]], { gangId }) or {}
  local cap = MySQL.scalar.await('SELECT max_members FROM cold_gangs WHERE id = ?', { gangId }) or 0
  cb(true, rs, cap)
end)

-- Admin: Territory owner

QBCore.Functions.CreateCallback('cold-gangs:server:AdminSetTerritoryOwner', function(src, cb, territoryName, gangId)
  if not IsAdmin(src) then cb(false, "No permission") return end
  if not territoryName or territoryName == "" then cb(false, "Invalid territory") return end

  local numericGid = gangId and tonumber(gangId) or nil
  if numericGid and numericGid > 0 then
    local g = MySQL.query.await('SELECT name, color FROM cold_gangs WHERE id = ?', { numericGid })
    if not g or not g[1] then cb(false, "Gang not found") return end
    MySQL.update.await('UPDATE territories SET gang_id=?, gang_name=?, claimed_at=NOW(), color_hex=? WHERE name=?',
      { numericGid, g[1].name, g[1].color or '#808080', territoryName })
  else
    MySQL.update.await('UPDATE territories SET gang_id=NULL, gang_name="Unclaimed", claimed_at=NULL, color_hex="#808080" WHERE name=?', { territoryName })
    numericGid = nil
  end

  -- Update live state and push to clients
  TriggerEvent('cold-gangs:territories:AdminSetOwner', territoryName, numericGid)

  cb(true, "OK")
end)

