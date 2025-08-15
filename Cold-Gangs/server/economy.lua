local QBCore = exports['qb-core']:GetCoreObject()

-- ======================
-- DEPOSIT / WITHDRAW
-- ======================

-- Deposit Money to Gang Bank
RegisterNetEvent('cold-gangs:server:DepositGangMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "Invalid amount", "error")
        return
    end

    if Player.PlayerData.money.cash < amount then
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough cash", "error")
        return
    end

    -- Remove from player
    Player.Functions.RemoveMoney('cash', amount, 'Gang deposit')

    -- Add to gang
    exports['cold-gangs']:AddGangMoney(gangId, amount, "Deposit by " .. Player.PlayerData.charinfo.firstname)

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Deposited $" .. amount .. " to gang bank", "success")
    Core.NotifyGangMembers(gangId, "Money Deposited", Player.PlayerData.charinfo.firstname .. " deposited $" .. amount .. " to the gang bank")
end)

-- Withdraw Money from Gang Bank
RegisterNetEvent('cold-gangs:server:WithdrawGangMoney', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageBank') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to withdraw money", "error")
        return
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "Invalid amount", "error")
        return
    end

    local fee = 0
    if Config.Economy.transactionFee > 0 then
        fee = math.floor(amount * Config.Economy.transactionFee)
    end

    if exports['cold-gangs']:RemoveGangMoney(gangId, amount + fee, "Withdrawal by " .. Player.PlayerData.charinfo.firstname) then
        Player.Functions.AddMoney('cash', amount, 'Gang withdrawal')

        local message = "Withdrew $" .. amount .. " from gang bank"
        if fee > 0 then
            message = message .. " (Fee: $" .. fee .. ")"
        end

        TriggerClientEvent('QBCore:Notify', src, message, "success")
        Core.NotifyGangMembers(gangId, "Money Withdrawn", Player.PlayerData.charinfo.firstname .. " withdrew $" .. amount .. " from the gang bank")
    else
        TriggerClientEvent('QBCore:Notify', src, "Failed to withdraw money", "error")
    end
end)

-- ======================
-- TRANSFER MONEY
-- ======================

-- Transfer Gang Money
RegisterNetEvent('cold-gangs:server:TransferGangMoney', function(targetGangId, amount, reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageBank') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to transfer money", "error")
        return
    end

    if not targetGangId or not Gangs[targetGangId] then
        TriggerClientEvent('QBCore:Notify', src, "Invalid target gang", "error")
        return
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "Invalid amount", "error")
        return
    end

    local fee = 0
    if Config.Economy.transactionFee > 0 then
        fee = math.floor(amount * Config.Economy.transactionFee)
    end

    if exports['cold-gangs']:RemoveGangMoney(gangId, amount + fee, "Transfer to " .. Gangs[targetGangId].name) then
        if exports['cold-gangs']:AddGangMoney(targetGangId, amount, "Transfer from " .. Gangs[gangId].name) then
            local message = "Transferred $" .. amount .. " to " .. Gangs[targetGangId].name
            if fee > 0 then
                message = message .. " (Fee: $" .. fee .. ")"
            end
            TriggerClientEvent('QBCore:Notify', src, message, "success")
            Core.NotifyGangMembers(gangId, "Money Transfer", "Your gang transferred $" .. amount .. " to " .. Gangs[targetGangId].name)
            Core.NotifyGangMembers(targetGangId, "Money Received", "Your gang received $" .. amount .. " from " .. Gangs[gangId].name)
        else
            -- Refund
            exports['cold-gangs']:AddGangMoney(gangId, amount + fee, "Refund - Failed transfer to " .. Gangs[targetGangId].name)
            TriggerClientEvent('QBCore:Notify', src, "Failed to transfer money", "error")
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "Your gang doesn't have enough money", "error")
    end
end)

-- ======================
-- SALARIES & PAYOUTS
-- ======================

-- Process Salaries
function ProcessGangSalaries()
    for gangId, members in pairs(GangMembers) do
        if Gangs[gangId] then
            local totalSalary = 0
            local paidCount = 0

            for citizenId, member in pairs(members) do
                local rankData = Config.Gangs.Ranks[member.rank]
                if rankData and rankData.salary then
                    local salary = rankData.salary * Config.Economy.salaryMultiplier

                    if Gangs[gangId].bank >= salary then
                        exports['cold-gangs']:RemoveGangMoney(gangId, salary, "Salary: " .. member.name)
                        totalSalary = totalSalary + salary

                        -- Find and pay player if online
                        local player = QBCore.Functions.GetPlayerByCitizenId(citizenId)
                        if player then
                            player.Functions.AddMoney('bank', salary, 'Gang salary')
                            TriggerClientEvent('QBCore:Notify', player.PlayerData.source, "You received $" .. salary .. " from your gang", "success")
                            paidCount = paidCount + 1
                        end
                    end
                end
            end

            if totalSalary > 0 then
                Core.NotifyGangMembers(gangId, "Salaries Paid", "Gang salaries totaling $" .. totalSalary .. " have been paid to " .. paidCount .. " members")
            else
                Core.NotifyGangMembers(gangId, "Salary Payment Failed", "Your gang doesn't have enough money to pay salaries")
            end
        end
    end
end

-- Run every 24 hours
CreateThread(function()
    while true do
        Wait(Config.Economy.incomeInterval)
        ProcessGangSalaries()
    end
end)

-- ======================
-- GANG UPKEEP
-- ======================

-- Process Gang Upkeep
function ProcessGangUpkeep()
    for gangId, gang in pairs(Gangs) do
        local memberCount = 0
        if GangMembers[gangId] then
            for _ in pairs(GangMembers[gangId]) do
                memberCount = memberCount + 1
            end
        end
        
        local upkeep = Config.Economy.dailyUpkeepMultiplier * memberCount
        if gang.bank >= upkeep then
            exports['cold-gangs']:RemoveGangMoney(gangId, upkeep, "Daily Upkeep")
            Core.NotifyGangMembers(gangId, "Upkeep Paid", "Your gang paid $" .. upkeep .. " in daily upkeep")
        else
            Core.NotifyGangMembers(gangId, "Upkeep Failed", "Your gang failed to pay $" .. upkeep .. " in daily upkeep. Consider downsizing or earning more.")
        end
    end
end

-- Run every 24 hours
CreateThread(function()
    while true do
        Wait(86400000) -- 24 hours
        ProcessGangUpkeep()
    end
end)

-- ======================
-- CALLBACKS
-- ======================

-- Get gang bank balance
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangBank', function(source, cb, gangId)
    cb(GangBank[gangId] or 0)
end)

-- Get gang transaction history
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangTransactions', function(source, cb, gangId)
    local result = MySQL.query.await('SELECT * FROM cold_gang_transactions WHERE gang_id = ? ORDER BY timestamp DESC LIMIT 50', {gangId})
    cb(result or {})
end)

-- Sync economy to client
RegisterNetEvent('cold-gangs:server:SyncEconomy', function()
    TriggerClientEvent('cold-gangs:client:SyncEconomy', -1, GangBank, GangReputations)
end)

-- Periodic sync
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        TriggerClientEvent('cold-gangs:client:SyncEconomy', -1, GangBank, GangReputations)
    end
end)
