local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}
RegisterNetEvent('cold-gangs:economy:Deposit', function(amount)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then return end
  amount = tonumber(amount)
  if not amount or amount <= 0 then return end
  if Player.PlayerData.money.cash < amount then return end
  Player.Functions.RemoveMoney('cash', amount, 'Gang deposit')
  ColdGangs.Core.AddGangMoney(gangId, amount, "Deposit by "..Player.PlayerData.charinfo.firstname)
end)
RegisterNetEvent('cold-gangs:economy:Withdraw', function(amount)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then return end
  if not ColdGangs.Permissions.HasGangPermission(src, 'manageBank') then return end
  amount = tonumber(amount)
  if not amount or amount <= 0 then return end
  local fee = 0
  if Config and Config.Economy and Config.Economy.transactionFee and Config.Economy.transactionFee > 0 then
    fee = math.floor(amount * Config.Economy.transactionFee)
  end
  if ColdGangs.Core.RemoveGangMoney(gangId, amount + fee, "Withdrawal by "..Player.PlayerData.charinfo.firstname) then
    Player.Functions.AddMoney('cash', amount, 'Gang withdrawal')
  end
end)

RegisterNetEvent('cold-gangs:server:ChangeGangName', function(newName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = ColdGangs.Core.GetPlayerGangId(src)
    if not gangId then return end
    
    if not ColdGangs.Permissions.HasGangPermission(src, 'manageSettings') then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end
    
    MySQL.update('UPDATE cold_gangs SET name = ? WHERE id = ?', {newName, gangId})
    TriggerClientEvent('QBCore:Notify', src, 'Gang name updated', 'success')
end)

RegisterNetEvent('cold-gangs:server:ChangeGangTag', function(newTag)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = ColdGangs.Core.GetPlayerGangId(src)
    if not gangId then return end
    
    if not ColdGangs.Permissions.HasGangPermission(src, 'manageSettings') then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end
    
    MySQL.update('UPDATE cold_gangs SET tag = ? WHERE id = ?', {newTag, gangId})
    TriggerClientEvent('QBCore:Notify', src, 'Gang tag updated', 'success')
end)

RegisterNetEvent('cold-gangs:server:ChangeGangColor', function(newColor)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = ColdGangs.Core.GetPlayerGangId(src)
    if not gangId then return end
    
    if not ColdGangs.Permissions.HasGangPermission(src, 'manageSettings') then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end
    
    MySQL.update('UPDATE cold_gangs SET color = ? WHERE id = ?', {newColor, gangId})
    TriggerClientEvent('QBCore:Notify', src, 'Gang color updated', 'success')
end)

RegisterNetEvent('cold-gangs:economy:Transfer', function(targetGangId, amount, reason)
  local src = source
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then return end
  if not ColdGangs.Permissions.HasGangPermission(src, 'manageBank') then return end
  local tg = MySQL.Sync.fetchAll('SELECT * FROM cold_gangs WHERE id = ?', {targetGangId})
  if not tg or #tg==0 then return end
  amount = tonumber(amount)
  if not amount or amount <= 0 then return end
  local fee = 0
  if Config and Config.Economy and Config.Economy.transactionFee and Config.Economy.transactionFee > 0 then
    fee = math.floor(amount * Config.Economy.transactionFee)
  end
  local sg = MySQL.Sync.fetchAll('SELECT name FROM cold_gangs WHERE id = ?', {gangId})
  if not sg or #sg==0 then return end
  if ColdGangs.Core.RemoveGangMoney(gangId, amount + fee, "Transfer to "..tg[1].name) then
    ColdGangs.Core.AddGangMoney(targetGangId, amount, "Transfer from "..sg[1].name)
  end
end)

local function getAllGangMembers()
  local res = MySQL.Sync.fetchAll('SELECT * FROM cold_gang_members ORDER BY gang_id', {})
  local map = {}
  if res then
    for _, m in ipairs(res) do
      map[m.gang_id] = map[m.gang_id] or {}
      map[m.gang_id][m.citizen_id] = { name = m.name, rank = m.rank, joined_at = m.joined_at }
    end
  end
  return map
end

local function getGangMoney(gangId)
  return MySQL.Sync.fetchScalar('SELECT bank FROM cold_gangs WHERE id = ?', {gangId}) or 0
end

local function processSalaries()
  local all = getAllGangMembers()
  for gangId, members in pairs(all) do
    local total = 0
    for citizenId, m in pairs(members) do
      local rankData = Config.Gangs and Config.Gangs.Ranks and Config.Gangs.Ranks[m.rank]
      if rankData and rankData.salary and getGangMoney(gangId) >= rankData.salary then
        ColdGangs.Core.RemoveGangMoney(gangId, rankData.salary, "Salary: "..(m.name or ""))
        local P = QBCore.Functions.GetPlayerByCitizenId(citizenId)
        if P then
          P.Functions.AddMoney('bank', rankData.salary, 'Gang salary')
        end
        total = total + rankData.salary
      end
    end
  end
end

local function processUpkeep()
  local gangs = MySQL.Sync.fetchAll('SELECT id FROM cold_gangs', {})
  for _, g in ipairs(gangs) do
    local members = MySQL.Sync.fetchScalar('SELECT COUNT(*) FROM cold_gang_members WHERE gang_id = ?', {g.id}) or 0
    local mult = Config.Economy and Config.Economy.dailyUpkeepMultiplier or 50
    local cost = mult * members
    if getGangMoney(g.id) >= cost then
      ColdGangs.Core.RemoveGangMoney(g.id, cost, "Daily Upkeep")
    end
  end
end

QBCore.Functions.CreateCallback('cold-gangs:server:GetGangBank', function(source, cb, gangId)
  if not gangId then gangId = ColdGangs.Core.GetPlayerGangId(source) end
  if not gangId then cb(0) return end
  local bal = MySQL.Sync.fetchScalar('SELECT bank FROM cold_gangs WHERE id=?', {gangId}) or 0
  cb(bal)
end)

QBCore.Functions.CreateCallback('cold-gangs:server:GetGangTransactions', function(source, cb, gangId)
  if not gangId then gangId = ColdGangs.Core.GetPlayerGangId(source) end
  if not gangId then cb({}) return end
  local rs = MySQL.query.await('SELECT * FROM cold_gang_transactions WHERE gang_id = ? ORDER BY timestamp DESC LIMIT 50', {gangId})
  cb(rs or {})
end)

QBCore.Functions.CreateCallback('cold-gangs:server:DepositMoney', function(src, cb, amount)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false) return end
    local gangId = ColdGangs.Core.GetPlayerGangId(src)
    if not gangId then cb(false) return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then cb(false) return end

    if (Player.PlayerData.money.cash or 0) < amount then
        cb(false)
        return
    end

    Player.Functions.RemoveMoney('cash', amount, 'Gang deposit')
    local first = Player.PlayerData.charinfo and Player.PlayerData.charinfo.firstname or Player.PlayerData.name or "Unknown"
    ColdGangs.Core.AddGangMoney(gangId, amount, ("Deposit by %s"):format(first))
    cb(true)
end)

QBCore.Functions.CreateCallback('cold-gangs:server:WithdrawMoney', function(src, cb, amount)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false) return end
    local gangId = ColdGangs.Core.GetPlayerGangId(src)
    if not gangId then cb(false) return end

    if not ColdGangs.Permissions.HasGangPermission(src, 'manageBank') then
        cb(false)
        return
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then cb(false) return end

    local fee = 0
    if Config and Config.Economy and Config.Economy.transactionFee and Config.Economy.transactionFee > 0 then
        fee = math.floor(amount * Config.Economy.transactionFee)
    end

    if ColdGangs.Core.RemoveGangMoney(gangId, amount + fee, ("Withdrawal by %s"):format(Player.PlayerData.charinfo and Player.PlayerData.charinfo.firstname or Player.PlayerData.name or "")) then
        Player.Functions.AddMoney('cash', amount, 'Gang withdrawal')
        cb(true)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('cold-gangs:server:TransferMoney', function(src, cb, targetGangId, amount, reason)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false) return end
    local gangId = ColdGangs.Core.GetPlayerGangId(src)
    if not gangId then cb(false) return end

    if not ColdGangs.Permissions.HasGangPermission(src, 'manageBank') then
        cb(false)
        return
    end

    targetGangId = tonumber(targetGangId)
    amount = tonumber(amount)
    if not targetGangId or targetGangId <= 0 or not amount or amount <= 0 then
        cb(false)
        return
    end

    local tg = MySQL.Sync.fetchAll('SELECT id, name FROM cold_gangs WHERE id = ?', {targetGangId})
    if not tg or #tg == 0 then cb(false) return end

    local fee = 0
    if Config and Config.Economy and Config.Economy.transactionFee and Config.Economy.transactionFee > 0 then
        fee = math.floor(amount * Config.Economy.transactionFee)
    end

    local sg = MySQL.Sync.fetchAll('SELECT name FROM cold_gangs WHERE id = ?', {gangId})
    if not sg or #sg == 0 then cb(false) return end

    local toName = tg[1].name
    local fromName = sg[1].name
    local descOut = ("Transfer to %s"):format(toName)
    if reason and reason ~= "" then descOut = descOut .. (" (%s)"):format(reason) end

    if ColdGangs.Core.RemoveGangMoney(gangId, amount + fee, descOut) then
        local descIn = ("Transfer from %s"):format(fromName)
        if reason and reason ~= "" then descIn = descIn .. (" (%s)"):format(reason) end

        ColdGangs.Core.AddGangMoney(targetGangId, amount, descIn)
        cb(true)
    else
        cb(false)
    end
end)

CreateThread(function()
  while true do
    Wait(Config.Economy and Config.Economy.incomeInterval or 3600000)
    processSalaries()
  end
end)

CreateThread(function()
  while true do
    Wait(86400000)
    processUpkeep()
  end
end)
