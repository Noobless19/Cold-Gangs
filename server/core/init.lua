local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}
ColdGangs.Core = ColdGangs.Core or {}
ColdGangs.Config = Config
ColdGangs.State = ColdGangs.State or {
  Gangs = {},
  GangMembers = {},
  Territories = {},
  ActiveWars = {},
  ActiveHeists = {},
  GangBank = {},
  GangReputations = {},
  GangStashes = {},
  SharedStashes = {},
  DrugLabs = {},
  DrugFields = {},
  Businesses = {},
  GangVehicles = {}
}
function ColdGangs.Core.FormatMoney(a)
  local s = Config.CurrencySymbol or "£"
  a = math.floor(tonumber(a or 0))
  local t = tostring(a):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
  return s .. t
end
function ColdGangs.Core.FormatDuration(seconds)
  seconds = tonumber(seconds or 0)
  if seconds <= 0 then return "0s" end
  local d = math.floor(seconds/86400)
  local h = math.floor((seconds%86400)/3600)
  local m = math.floor((seconds%3600)/60)
  local s = seconds%60
  local str = ""
  if d>0 then str=str..d.."d " end
  if h>0 then str=str..h.."h " end
  if m>0 then str=str..m.."m " end
  if s>0 or str=="" then str=str..s.."s" end
  return str
end
function ColdGangs.Core.GetPlayerGangId(src)
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return nil end
  local r = MySQL.Sync.fetchAll('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ?', {Player.PlayerData.citizenid})
  if r and r[1] and r[1].gang_id then return r[1].gang_id end
  return nil
end
function ColdGangs.Core.AddGangMoney(gangId, amount, reason)
  if not gangId or not amount or amount<=0 then return false end
  MySQL.update('UPDATE cold_gangs SET bank = bank + ? WHERE id = ?', {amount, gangId})
  MySQL.insert('INSERT INTO cold_gang_transactions (gang_id, amount, description, timestamp) VALUES (?, ?, ?, NOW())', {gangId, amount, reason or 'Gang income'})
  return true
end
function ColdGangs.Core.RemoveGangMoney(gangId, amount, reason)
  if not gangId or not amount or amount<=0 then return false end
  local bal = MySQL.Sync.fetchScalar('SELECT bank FROM cold_gangs WHERE id = ?', {gangId})
  if not bal or bal < amount then return false end
  MySQL.update('UPDATE cold_gangs SET bank = bank - ? WHERE id = ?', {amount, gangId})
  MySQL.insert('INSERT INTO cold_gang_transactions (gang_id, amount, description, timestamp) VALUES (?, ?, ?, NOW())', {gangId, -amount, reason or 'Gang expense'})
  return true
end
function ColdGangs.Core.AddGangReputation(gangId, amount)
  if not gangId or not amount then return false end
  MySQL.update('UPDATE cold_gangs SET reputation = reputation + ? WHERE id = ?', {amount, gangId})
  return true
end
function ColdGangs.Core.NotifyGangMembers(gangId, title, message)
  local r = MySQL.Sync.fetchAll('SELECT citizen_id FROM cold_gang_members WHERE gang_id = ?', {gangId})
  if not r then return end
  for _, row in ipairs(r) do
    local Player = QBCore.Functions.GetPlayerByCitizenId(row.citizen_id)
    if Player then
      TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, title .. ": " .. message, "primary")
    end
  end
end
