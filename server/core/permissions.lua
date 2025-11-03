local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}
ColdGangs.Permissions = ColdGangs.Permissions or {}
function ColdGangs.Permissions.IsPlayerAdmin(src)
  if QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god') then return true end
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return false end
  for _, group in ipairs(Config.Admin.adminGroups or {}) do
    if Player.PlayerData.group == group then return true end
  end
  for _, id in ipairs(Config.Admin.adminCitizenIds or {}) do
    if Player.PlayerData.citizenid == id then return true end
  end
  return false
end
function ColdGangs.Permissions.HasGangPermission(src, permission)
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return false end
  local r = MySQL.Sync.fetchAll('SELECT rank FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid})
  if not r or #r==0 then return false end
  local rank = r[1].rank
  local rd = Config.Gangs and Config.Gangs.Ranks and Config.Gangs.Ranks[rank]
  if not rd then return false end
  local key = 'can' .. permission:sub(1,1):upper() .. permission:sub(2)
  return rd[key] == true
end
exports('IsPlayerAdmin', ColdGangs.Permissions.IsPlayerAdmin)
exports('HasGangPermission', ColdGangs.Permissions.HasGangPermission)
