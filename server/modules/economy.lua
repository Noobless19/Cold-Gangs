local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}
RegisterNetEvent('cold-gangs:economy:Deposit', function(amount)
  local src = source
  
  -- Rate limiting
  if not ColdGangs.RateLimit.CheckLimit(src, 'deposit_money', 20) then
    TriggerClientEvent('QBCore:Notify', src, 'Too many requests. Please wait.', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then 
    TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
    return 
  end
  
  -- Validate amount
  local valid, validatedAmount = ColdGangs.Validation.ValidateAmount(amount)
  if not valid then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid deposit amount', 'error')
    return
  end
  
  amount = validatedAmount
  
  -- Check player has enough cash
  local cash = Player.PlayerData.money and Player.PlayerData.money.cash or 0
  if cash < amount then 
    TriggerClientEvent('QBCore:Notify', src, 'You do not have enough cash', 'error')
    return 
  end
  
  -- Remove money and add to gang
  if Player.Functions.RemoveMoney('cash', amount, 'Gang deposit') then
    local firstname = (Player.PlayerData.charinfo and Player.PlayerData.charinfo.firstname) or 'Unknown'
    ColdGangs.Core.AddGangMoney(gangId, amount, "Deposit by " .. firstname)
    TriggerClientEvent('QBCore:Notify', src, 'Deposit successful', 'success')
  else
    TriggerClientEvent('QBCore:Notify', src, 'Deposit failed', 'error')
  end
end)
RegisterNetEvent('cold-gangs:economy:Withdraw', function(amount)
  local src = source
  
  -- Rate limiting
  if not ColdGangs.RateLimit.CheckLimit(src, 'withdraw_money', 20) then
    TriggerClientEvent('QBCore:Notify', src, 'Too many requests. Please wait.', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then 
    TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
    return 
  end
  
  if not ColdGangs.Permissions.HasGangPermission(src, 'manageBank') then 
    TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to withdraw money', 'error')
    return 
  end
  
  -- Validate amount
  local valid, validatedAmount = ColdGangs.Validation.ValidateAmount(amount)
  if not valid then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid withdrawal amount', 'error')
    return
  end
  amount = validatedAmount
  
  local fee = 0
  if Config and Config.Economy and Config.Economy.transactionFee and Config.Economy.transactionFee > 0 then
    fee = math.floor(amount * Config.Economy.transactionFee)
  end
  
  local firstname = (Player.PlayerData.charinfo and Player.PlayerData.charinfo.firstname) or 'Unknown'
  if ColdGangs.Core.RemoveGangMoney(gangId, amount + fee, "Withdrawal by " .. firstname) then
    Player.Functions.AddMoney('cash', amount, 'Gang withdrawal')
    TriggerClientEvent('QBCore:Notify', src, 'Withdrawal successful', 'success')
  else
    TriggerClientEvent('QBCore:Notify', src, 'Withdrawal failed: insufficient funds', 'error')
  end
end)

RegisterNetEvent('cold-gangs:server:ChangeGangName', function(newName)
    local src = source
    
    -- Rate limiting
    if not ColdGangs.RateLimit.CheckLimit(src, 'change_gang_name', 5) then
        TriggerClientEvent('QBCore:Notify', src, 'Too many requests. Please wait.', 'error')
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = ColdGangs.Core.GetPlayerGangId(src)
    if not gangId then 
        TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
        return 
    end
    
    if not ColdGangs.Permissions.HasGangPermission(src, 'manageSettings') then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end
    
    -- Validate gang name
    local valid, err = ColdGangs.Validation.ValidateGangName(newName)
    if not valid then
        TriggerClientEvent('QBCore:Notify', src, err or 'Invalid gang name', 'error')
        return
    end
    
    -- Sanitize name
    newName = ColdGangs.Validation.SanitizeString(newName, Config.GangNameMaxLength)
    
    MySQL.update('UPDATE cold_gangs SET name = ? WHERE id = ?', {newName, gangId}, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('QBCore:Notify', src, 'Gang name updated', 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Failed to update gang name', 'error')
        end
    end)
end)

RegisterNetEvent('cold-gangs:server:ChangeGangTag', function(newTag)
    local src = source
    
    -- Rate limiting
    if not ColdGangs.RateLimit.CheckLimit(src, 'change_gang_tag', 5) then
        TriggerClientEvent('QBCore:Notify', src, 'Too many requests. Please wait.', 'error')
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = ColdGangs.Core.GetPlayerGangId(src)
    if not gangId then 
        TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
        return 
    end
    
    if not ColdGangs.Permissions.HasGangPermission(src, 'manageSettings') then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end
    
    -- Validate gang tag
    local valid, err = ColdGangs.Validation.ValidateGangTag(newTag)
    if not valid then
        TriggerClientEvent('QBCore:Notify', src, err or 'Invalid gang tag', 'error')
        return
    end
    
    -- Sanitize tag
    newTag = ColdGangs.Validation.SanitizeString(newTag, Config.GangTagMaxLength)
    
    MySQL.update('UPDATE cold_gangs SET tag = ? WHERE id = ?', {newTag, gangId}, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('QBCore:Notify', src, 'Gang tag updated', 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Failed to update gang tag', 'error')
        end
    end)
end)

RegisterNetEvent('cold-gangs:server:ChangeGangColor', function(newColor)
    local src = source
    
    -- Rate limiting
    if not ColdGangs.RateLimit.CheckLimit(src, 'change_gang_color', 5) then
        TriggerClientEvent('QBCore:Notify', src, 'Too many requests. Please wait.', 'error')
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = ColdGangs.Core.GetPlayerGangId(src)
    if not gangId then 
        TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
        return 
    end
    
    if not ColdGangs.Permissions.HasGangPermission(src, 'manageSettings') then
        TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error')
        return
    end
    
    -- Validate color
    local valid, err = ColdGangs.Validation.ValidateColor(newColor)
    if not valid then
        TriggerClientEvent('QBCore:Notify', src, err or 'Invalid color format', 'error')
        return
    end
    
    MySQL.update('UPDATE cold_gangs SET color = ? WHERE id = ?', {newColor, gangId}, function(affectedRows)
        if affectedRows > 0 then
            TriggerClientEvent('QBCore:Notify', src, 'Gang color updated', 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, 'Failed to update gang color', 'error')
        end
    end)
end)

RegisterNetEvent('cold-gangs:economy:Transfer', function(targetGangId, amount, reason)
  local src = source
  
  -- Rate limiting
  if not ColdGangs.RateLimit.CheckLimit(src, 'transfer_money', 10) then
    TriggerClientEvent('QBCore:Notify', src, 'Too many requests. Please wait.', 'error')
    return
  end
  
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return end
  
  local gangId = ColdGangs.Core.GetPlayerGangId(src)
  if not gangId then 
    TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
    return 
  end
  
  if not ColdGangs.Permissions.HasGangPermission(src, 'manageBank') then 
    TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to transfer money', 'error')
    return 
  end
  
  -- Validate inputs
  targetGangId = tonumber(targetGangId)
  if not targetGangId or targetGangId <= 0 then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid target gang', 'error')
    return
  end
  
  if targetGangId == gangId then
    TriggerClientEvent('QBCore:Notify', src, 'Cannot transfer to your own gang', 'error')
    return
  end
  
  local valid, validatedAmount = ColdGangs.Validation.ValidateAmount(amount)
  if not valid then
    TriggerClientEvent('QBCore:Notify', src, 'Invalid transfer amount', 'error')
    return
  end
  amount = validatedAmount
  
  -- Sanitize reason
  reason = ColdGangs.Validation.SanitizeString(reason or '', 100)
  
  -- Get target gang info
  MySQL.query('SELECT id, name FROM cold_gangs WHERE id = ?', {targetGangId}, function(tg)
    if not tg or #tg == 0 then 
      TriggerClientEvent('QBCore:Notify', src, 'Target gang not found', 'error')
      return 
    end
    
    -- Get source gang info
    MySQL.query('SELECT name FROM cold_gangs WHERE id = ?', {gangId}, function(sg)
      if not sg or #sg == 0 then 
        TriggerClientEvent('QBCore:Notify', src, 'Gang not found', 'error')
        return 
      end
      
      local fee = 0
      if Config and Config.Economy and Config.Economy.transactionFee and Config.Economy.transactionFee > 0 then
        fee = math.floor(amount * Config.Economy.transactionFee)
      end
      
      local totalDeduct = amount + fee
      
      -- Check balance first
      MySQL.query('SELECT bank FROM cold_gangs WHERE id = ?', {gangId}, function(balanceResult)
        local balance = balanceResult and balanceResult[1] and balanceResult[1].bank or 0
        
        if balance < totalDeduct then
          TriggerClientEvent('QBCore:Notify', src, 'Insufficient gang funds', 'error')
          return
        end
        
        -- Remove from source (use async with error handling)
        MySQL.update('UPDATE cold_gangs SET bank = bank - ? WHERE id = ? AND bank >= ?', 
          {totalDeduct, gangId, totalDeduct}, function(removed)
            if not removed or removed == 0 then
              TriggerClientEvent('QBCore:Notify', src, 'Transfer failed: insufficient funds or gang not found', 'error')
              return
            end
            
            -- Add to target
            MySQL.update('UPDATE cold_gangs SET bank = bank + ? WHERE id = ?', {amount, targetGangId}, function(added)
              if not added or added == 0 then
                -- Rollback: add money back to source
                MySQL.update('UPDATE cold_gangs SET bank = bank + ? WHERE id = ?', {totalDeduct, gangId}, function()
                  TriggerClientEvent('QBCore:Notify', src, 'Transfer failed: could not complete transaction', 'error')
                end)
                return
              end
              
              -- Log transactions
              local descOut = "Transfer to " .. tg[1].name
              if reason and reason ~= "" then descOut = descOut .. " (" .. reason .. ")" end
              
              local descIn = "Transfer from " .. sg[1].name
              if reason and reason ~= "" then descIn = descIn .. " (" .. reason .. ")" end
              
              MySQL.insert('INSERT INTO cold_gang_transactions (gang_id, amount, description, reason, timestamp) VALUES (?, ?, ?, ?, NOW())', 
                {gangId, -totalDeduct, descOut, 'transfer'}, function() end)
              
              MySQL.insert('INSERT INTO cold_gang_transactions (gang_id, amount, description, reason, timestamp) VALUES (?, ?, ?, ?, NOW())', 
                {targetGangId, amount, descIn, 'transfer'}, function() end)
              
              TriggerClientEvent('QBCore:Notify', src, 'Transfer successful', 'success')
            end)
          end)
      end)
    end)
  end)
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
