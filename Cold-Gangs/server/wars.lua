local QBCore = exports['qb-core']:GetCoreObject()

-- ======================
-- DECLARE WAR
-- ======================

-- Declare War
RegisterNetEvent('cold-gangs:server:DeclareWar', function(targetGangId, territoryName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'declareWar') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to declare war", "error")
        return
    end

    -- Check if target gang exists
    if not Gangs[targetGangId] then
        TriggerClientEvent('QBCore:Notify', src, "Target gang not found", "error")
        return
    end

    -- Check if territory exists and is controlled by target gang
    if not Territories[territoryName] or Territories[territoryName].gangId ~= targetGangId then
        TriggerClientEvent('QBCore:Notify', src, "This territory is not controlled by the target gang", "error")
        return
    end

    -- Check if already at war with this gang
    for _, war in pairs(ActiveWars) do
        if (war.attackerId == gangId and war.defenderId == targetGangId) or
           (war.attackerId == targetGangId and war.defenderId == gangId) then
            TriggerClientEvent('QBCore:Notify', src, "You are already at war with this gang", "error")
            return
        end
    end

    -- Check if at max wars
    local warCount = 0
    for _, war in pairs(ActiveWars) do
        if war.attackerId == gangId or war.defenderId == gangId then
            warCount = warCount + 1
        end
    end

    if warCount >= Config.Wars.maxSimultaneousWars then
        TriggerClientEvent('QBCore:Notify', src, "Your gang is already involved in the maximum number of wars", "error")
        return
    end

    -- Check if enough members online
    local onlineMembers = 0
    for citizenId in pairs(GangMembers[gangId] or {}) do
        if QBCore.Functions.GetPlayerByCitizenId(citizenId) then
            onlineMembers = onlineMembers + 1
        end
    end

    if onlineMembers < Config.Wars.minMembersOnline then
        TriggerClientEvent('QBCore:Notify', src, "You need at least " .. Config.Wars.minMembersOnline .. " gang members online to declare war", "error")
        return
    end

    -- Check if gang has enough money
    if not exports['cold-gangs']:RemoveGangMoney(gangId, Config.Wars.declarationCost, "War Declaration against " .. Gangs[targetGangId].name) then
        TriggerClientEvent('QBCore:Notify', src, "Your gang doesn't have enough money ($" .. Config.Wars.declarationCost .. ")", "error")
        return
    end

    -- Create war
    local warId = MySQL.insert.await('INSERT INTO cold_active_wars (attacker_id, defender_id, attacker_name, defender_name, territory_name, started_at, attacker_score, defender_score, max_score, status) VALUES (?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?)', {
        gangId,
        targetGangId,
        Gangs[gangId].name,
        Gangs[targetGangId].name,
        territoryName,
        0, -- Initial attacker score
        0, -- Initial defender score
        Config.Wars.maxScore,
        'active'
    })

    -- Add to memory
    ActiveWars[warId] = {
        id = warId,
        attackerId = gangId,
        defenderId = targetGangId,
        attackerName = Gangs[gangId].name,
        defenderName = Gangs[targetGangId].name,
        territoryName = territoryName,
        startedAt = os.date('%Y-%m-%d %H:%M:%S'),
        attackerScore = 0,
        defenderScore = 0,
        maxScore = Config.Wars.maxScore,
        status = 'active'
    }

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "War declared against " .. Gangs[targetGangId].name .. " for territory: " .. territoryName, "success")
    Core.NotifyGangMembers(gangId, "War Declared", "Your gang has declared war against " .. Gangs[targetGangId].name .. " for territory: " .. territoryName)
    Core.NotifyGangMembers(targetGangId, "War Declared", Gangs[gangId].name .. " has declared war against your gang for territory: " .. territoryName)

    -- Notify all clients
    TriggerClientEvent('cold-gangs:client:WarStarted', -1, warId, ActiveWars[warId])

    -- Add reputation
    exports['cold-gangs']:AddGangReputation(gangId, 50)

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncWars', -1, ActiveWars)
end)

-- ======================
-- REPORT WAR DEATH
-- ======================

-- Report War Death
RegisterNetEvent('cold-gangs:server:ReportWarDeath', function(warId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then return end

    -- Check if war exists
    if not ActiveWars[warId] then return end

    local war = ActiveWars[warId]

    -- Check if player's gang is involved in this war
    if war.attackerId ~= gangId and war.defenderId ~= gangId then return end

    -- Determine which side gets a point
    if war.attackerId == gangId then
        -- Attacker died, defender gets a point
        war.defenderScore = war.defenderScore + 1
        MySQL.update('UPDATE cold_active_wars SET defender_score = ? WHERE id = ?', {war.defenderScore, warId})
        
        -- Notify
        Core.NotifyGangMembers(war.attackerId, "War Death", "Your gang lost a point in the war against " .. war.defenderName)
        Core.NotifyGangMembers(war.defenderId, "War Kill", "Your gang gained a point in the war against " .. war.attackerName)
    else
        -- Defender died, attacker gets a point
        war.attackerScore = war.attackerScore + 1
        MySQL.update('UPDATE cold_active_wars SET attacker_score = ? WHERE id = ?', {war.attackerScore, warId})
        
        -- Notify
        Core.NotifyGangMembers(war.defenderId, "War Death", "Your gang lost a point in the war against " .. war.attackerName)
        Core.NotifyGangMembers(war.attackerId, "War Kill", "Your gang gained a point in the war against " .. war.defenderName)
    end

    -- Update clients
    TriggerClientEvent('cold-gangs:client:WarScoreUpdated', -1, warId, war.attackerScore, war.defenderScore)

    -- Check if war is over
    if war.attackerScore >= war.maxScore or war.defenderScore >= war.maxScore then
        EndWar(warId)
    end
end)

-- ======================
-- SURRENDER WAR
-- ======================

-- Surrender War
RegisterNetEvent('cold-gangs:server:SurrenderWar', function(warId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'declareWar') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to surrender wars", "error")
        return
    end

    -- Check if war exists
    if not ActiveWars[warId] then
        TriggerClientEvent('QBCore:Notify', src, "War not found", "error")
        return
    end

    local war = ActiveWars[warId]

    -- Check if player's gang is involved in this war
    if war.attackerId ~= gangId and war.defenderId ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Your gang is not involved in this war", "error")
        return
    end

    -- Determine winner
    local winnerId, winnerName, loserId, loserName
    if war.attackerId == gangId then
        winnerId = war.defenderId
        winnerName = war.defenderName
        loserId = war.attackerId
        loserName = war.attackerName
    else
        winnerId = war.attackerId
        winnerName = war.attackerName
        loserId = war.defenderId
        loserName = war.defenderName
    end

    -- Update war status
    MySQL.update('UPDATE cold_active_wars SET status = ?, winner_id = ?, ended_at = NOW() WHERE id = ?', {'ended', winnerId, warId})

    -- Process war rewards
    ProcessWarRewards(winnerId, loserId, war.territoryName)

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "You have surrendered the war against " .. winnerName, "error")
    Core.NotifyGangMembers(gangId, "War Surrendered", "Your gang has surrendered the war against " .. winnerName)
    Core.NotifyGangMembers(winnerId, "War Won", loserName .. " has surrendered the war. Your gang is victorious!")

    -- Notify all clients
    TriggerClientEvent('cold-gangs:client:WarEnded', -1, warId, winnerId, winnerName)

    -- Remove from active wars
    ActiveWars[warId] = nil

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncWars', -1, ActiveWars)
end)

-- ======================
-- END WAR
-- ======================

-- End War
function EndWar(warId)
    local war = ActiveWars[warId]
    if not war then return end

    -- Determine winner
    local winnerId, winnerName, loserId, loserName
    if war.attackerScore >= war.maxScore then
        winnerId = war.attackerId
        winnerName = war.attackerName
        loserId = war.defenderId
        loserName = war.defenderName
    else
        winnerId = war.defenderId
        winnerName = war.defenderName
        loserId = war.attackerId
        loserName = war.attackerName
    end

    -- Update war status
    MySQL.update('UPDATE cold_active_wars SET status = ?, winner_id = ?, ended_at = NOW() WHERE id = ?', {'ended', winnerId, warId})

    -- Process war rewards
    ProcessWarRewards(winnerId, loserId, war.territoryName)

    -- Notify
    Core.NotifyGangMembers(winnerId, "War Won", "Your gang has won the war against " .. loserName .. "!")
    Core.NotifyGangMembers(loserId, "War Lost", "Your gang has lost the war against " .. winnerName)

    -- Notify all clients
    TriggerClientEvent('cold-gangs:client:WarEnded', -1, warId, winnerId, winnerName)

    -- Remove from active wars
    ActiveWars[warId] = nil

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncWars', -1, ActiveWars)
end

-- Process War Rewards
function ProcessWarRewards(winnerId, loserId, territoryName)
    -- Transfer territory ownership
    if Territories[territoryName] then
        MySQL.update('UPDATE cold_territories SET gang_id = ?, gang_name = ?, claimed_at = NOW() WHERE name = ?', {
            winnerId,
            Gangs[winnerId].name,
            territoryName
        })
        
        Territories[territoryName] = {
            gangId = winnerId,
            gangName = Gangs[winnerId].name,
            claimed_at = os.date('%Y-%m-%d %H:%M:%S'),
            income_generated = Territories[territoryName].income_generated or 0
        }
    end

    -- Add money to winner
    exports['cold-gangs']:AddGangMoney(winnerId, Config.Wars.winReward, "War Victory Reward")

    -- Add consolation prize to loser
    exports['cold-gangs']:AddGangMoney(loserId, Config.Wars.loseReward, "War Consolation Prize")

    -- Add reputation
    exports['cold-gangs']:AddGangReputation(winnerId, 200)
    exports['cold-gangs']:AddGangReputation(loserId, -100)

    -- Sync territories to clients
    TriggerClientEvent('cold-gangs:client:SyncTerritories', -1, Territories)
end

-- ======================
-- CALLBACKS
-- ======================

-- Get Active Wars
QBCore.Functions.CreateCallback('cold-gangs:server:GetActiveWars', function(source, cb)
    cb(ActiveWars)
end)

-- Get Gang Wars
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangWars', function(source, cb, gangId)
    local wars = {}
    
    for id, war in pairs(ActiveWars) do
        if war.attackerId == gangId or war.defenderId == gangId then
            wars[id] = war
        end
    end
    
    cb(wars)
end)

-- Get Police Count
QBCore.Functions.CreateCallback('cold-gangs:server:GetPoliceCount', function(source, cb)
    local policeCount = 0
    
    for _, src in pairs(QBCore.Functions.GetPlayers()) do
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and (Player.PlayerData.job.name == 'police' and Player.PlayerData.job.onduty) then
            policeCount = policeCount + 1
        end
    end
    
    cb(policeCount)
end)

-- ======================
-- PERIODIC UPDATES
-- ======================

-- Sync wars to clients
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        TriggerClientEvent('cold-gangs:client:SyncWars', -1, ActiveWars)
    end
end)

-- ======================
-- EXPORTS
-- ======================

-- Get War
function GetWar(warId)
    return ActiveWars[warId]
end

-- Get Wars by Gang ID
function GetWarsByGangId(gangId)
    local wars = {}
    
    for id, war in pairs(ActiveWars) do
        if war.attackerId == gangId or war.defenderId == gangId then
            wars[id] = war
        end
    end
    
    return wars
end

-- Register exports
exports('GetWar', GetWar)
exports('GetWarsByGangId', GetWarsByGangId)
