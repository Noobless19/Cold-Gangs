local QBCore = exports['qb-core']:GetCoreObject()

-- ======================
-- START HEIST
-- ======================

-- Start Heist
RegisterNetEvent('cold-gangs:server:StartHeist', function(heistType, locationIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageHeists') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to start heists", "error")
        return
    end

    -- Check if heist type is valid
    if not Config.HeistTypes[heistType] then
        TriggerClientEvent('QBCore:Notify', src, "Invalid heist type", "error")
        return
    end

    local heistConfig = Config.HeistTypes[heistType]

    -- Check gang reputation
    if heistConfig.minReputation > 0 then
        if (Gangs[gangId].reputation or 0) < heistConfig.minReputation then
            TriggerClientEvent('QBCore:Notify', src, "Your gang needs at least " .. heistConfig.minReputation .. " reputation to start this heist", "error")
            return
        end
    end

    -- Check police count
    if heistConfig.policeRequired > 0 then
        local policeCount = 0
        for _, src in pairs(QBCore.Functions.GetPlayers()) do
            local Player = QBCore.Functions.GetPlayer(src)
            if Player and (Player.PlayerData.job.name == 'police' and Player.PlayerData.job.onduty) then
                policeCount = policeCount + 1
            end
        end

        if policeCount < heistConfig.policeRequired then
            TriggerClientEvent('QBCore:Notify', src, "Not enough police online. Required: " .. heistConfig.policeRequired, "error")
            return
        end
    end

    -- Check if gang already has an active heist
    for _, heist in pairs(ActiveHeists) do
        if heist.gangId == gangId and heist.status == 'active' then
            TriggerClientEvent('QBCore:Notify', src, "Your gang already has an active heist", "error")
            return
        end
    end

    -- Check cooldown
    local cooldownCheck = MySQL.query.await('SELECT * FROM cold_heist_cooldowns WHERE heist_type = ? AND available_at > NOW()', {heistType})
    if cooldownCheck and #cooldownCheck > 0 then
        local timeLeft = os.difftime(os.time(os.date("!*t", cooldownCheck[1].available_at)), os.time())
        TriggerClientEvent('QBCore:Notify', src, "This heist is on cooldown. Available in " .. FormatDuration(timeLeft), "error")
        return
    end

    -- Get location
    local location = nil
    if heistConfig.locations and heistConfig.locations[locationIndex] then
        location = heistConfig.locations[locationIndex]
    else
        TriggerClientEvent('QBCore:Notify', src, "Invalid location", "error")
        return
    end

    -- Create heist
    local participants = {
        [Player.PlayerData.citizenid] = {
            name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
            role = "leader"
        }
    }

    local heistId = MySQL.insert.await('INSERT INTO cold_active_heists (heist_type, gang_id, status, start_time, participants, current_stage, location) VALUES (?, ?, ?, NOW(), ?, ?, ?)', {
        heistType,
        gangId,
        'active',
        json.encode(participants),
        1, -- Initial stage
        json.encode(location)
    })

    -- Add to memory
    ActiveHeists[heistId] = {
        id = heistId,
        heistType = heistType,
        gangId = gangId,
        status = 'active',
        startTime = os.date('%Y-%m-%d %H:%M:%S'),
        participants = participants,
        currentStage = 1,
        rewards = {},
        location = location
    }

    -- Set cooldown
    MySQL.query('INSERT INTO cold_heist_cooldowns (heist_type, last_completed, available_at) VALUES (?, NOW(), DATE_ADD(NOW(), INTERVAL ? SECOND)) ON DUPLICATE KEY UPDATE last_completed = NOW(), available_at = DATE_ADD(NOW(), INTERVAL ? SECOND)', {
        heistType,
        heistConfig.cooldown / 1000,
        heistConfig.cooldown / 1000
    })

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Heist started: " .. heistType, "success")
    Core.NotifyGangMembers(gangId, "Heist Started", Player.PlayerData.charinfo.firstname .. " started a " .. heistType .. " heist")

    -- Notify police if configured
    if Config.Dispatch.enableHeistAlerts then
        for _, src in pairs(QBCore.Functions.GetPlayers()) do
            local Player = QBCore.Functions.GetPlayer(src)
            if Player and (Player.PlayerData.job.name == 'police' and Player.PlayerData.job.onduty) then
                TriggerClientEvent('QBCore:Notify', src, "A heist may be in progress", "error")
            end
        end
    end

    -- Notify all clients
    TriggerClientEvent('cold-gangs:client:HeistStarted', -1, heistId, ActiveHeists[heistId])

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
end)

-- ======================
-- JOIN HEIST
-- ======================

-- Join Heist
RegisterNetEvent('cold-gangs:server:JoinHeist', function(heistId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    -- Check if heist exists and belongs to gang
    if not ActiveHeists[heistId] or ActiveHeists[heistId].gangId ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Heist not found or doesn't belong to your gang", "error")
        return
    end

    local heist = ActiveHeists[heistId]
    local heistConfig = Config.HeistTypes[heist.heistType]

    -- Check if already a participant
    if heist.participants[Player.PlayerData.citizenid] then
        TriggerClientEvent('QBCore:Notify', src, "You are already participating in this heist", "error")
        return
    end

    -- Check if heist is full
    local participantCount = 0
    for _ in pairs(heist.participants) do
        participantCount = participantCount + 1
    end

    if participantCount >= heistConfig.maxMembers then
        TriggerClientEvent('QBCore:Notify', src, "This heist is full", "error")
        return
    end

    -- Add player to participants
    heist.participants[Player.PlayerData.citizenid] = {
        name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
        role = "member"
    }

    -- Update database
    MySQL.update('UPDATE cold_active_heists SET participants = ? WHERE id = ?', {json.encode(heist.participants), heistId})

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "You joined the " .. heist.heistType .. " heist", "success")
    Core.NotifyGangMembers(gangId, "Heist Joined", Player.PlayerData.charinfo.firstname .. " joined the " .. heist.heistType .. " heist")

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
end)

-- ======================
-- COMPLETE HEIST STAGE
-- ======================

-- Complete Heist Stage
RegisterNetEvent('cold-gangs:server:CompleteHeistStage', function(heistId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then return end

    -- Check if heist exists and belongs to gang
    if not ActiveHeists[heistId] or ActiveHeists[heistId].gangId ~= gangId then return end

    local heist = ActiveHeists[heistId]
    local heistConfig = Config.HeistTypes[heist.heistType]

    -- Check if player is a participant
    if not heist.participants[Player.PlayerData.citizenid] then return end

    -- Update stage
    local newStage = heist.currentStage + 1
    
    -- Check if heist is complete
    if not heistConfig.stages or newStage > #heistConfig.stages then
        -- Heist complete
        CompleteHeist(heistId)
        return
    end
    
    -- Update to next stage
    MySQL.update('UPDATE cold_active_heists SET current_stage = ? WHERE id = ?', {newStage, heistId})
    ActiveHeists[heistId].currentStage = newStage
    
    -- Notify
    local stageName = heistConfig.stages[newStage] and heistConfig.stages[newStage].name or "Stage " .. newStage
    Core.NotifyGangMembers(gangId, "Heist Progress", "Your heist has advanced to: " .. stageName)
    
    -- Notify all clients
    TriggerClientEvent('cold-gangs:client:HeistStageUpdated', -1, heistId, newStage)
    
    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
end)

-- ======================
-- COMPLETE HEIST
-- ======================

-- Complete Heist
function CompleteHeist(heistId)
    local heist = ActiveHeists[heistId]
    if not heist then return end
    
    local gangId = heist.gangId
    local heistConfig = Config.HeistTypes[heist.heistType]
    
    -- Calculate rewards
    local rewards = {
        money = math.random(heistConfig.rewards.basePayout.min, heistConfig.rewards.basePayout.max),
        items = {},
        reputation = heistConfig.rewards.reputation
    }
    
    -- Add money to gang
    exports['cold-gangs']:AddGangMoney(gangId, rewards.money, "Heist Reward: " .. heist.heistType)
    
    -- Add reputation
    exports['cold-gangs']:AddGangReputation(gangId, rewards.reputation)
    
    -- Update heist status
    MySQL.update('UPDATE cold_active_heists SET status = ?, rewards = ? WHERE id = ?', {'completed', json.encode(rewards), heistId})
    
    -- Notify
    Core.NotifyGangMembers(gangId, "Heist Completed", "Your gang completed the " .. heist.heistType .. " heist! Reward: $" .. rewards.money)
    
    -- Notify all clients
    TriggerClientEvent('cold-gangs:client:HeistCompleted', -1, heistId, rewards)
    
    -- Remove from active heists
    ActiveHeists[heistId] = nil
    
    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
end

-- ======================
-- CANCEL HEIST
-- ======================

-- Cancel Heist
RegisterNetEvent('cold-gangs:server:CancelHeist', function(heistId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageHeists') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to cancel heists", "error")
        return
    end

    -- Check if heist exists and belongs to gang
    if not ActiveHeists[heistId] or ActiveHeists[heistId].gangId ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Heist not found or doesn't belong to your gang", "error")
        return
    end

    local heist = ActiveHeists[heistId]

    -- Update heist status
    MySQL.update('UPDATE cold_active_heists SET status = ? WHERE id = ?', {'cancelled', heistId})

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Heist cancelled", "error")
    Core.NotifyGangMembers(gangId, "Heist Cancelled", Player.PlayerData.charinfo.firstname .. " cancelled the " .. heist.heistType .. " heist")

    -- Notify all clients
    TriggerClientEvent('cold-gangs:client:HeistFailed', -1, heistId, "Cancelled by gang leader")

    -- Remove from active heists
    ActiveHeists[heistId] = nil

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
end)

-- ======================
-- CALLBACKS
-- ======================

-- Get Active Heists
QBCore.Functions.CreateCallback('cold-gangs:server:GetActiveHeists', function(source, cb)
    cb(ActiveHeists)
end)

-- Get Gang Heists
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangHeists', function(source, cb, gangId)
    local heists = {}
    
    for id, heist in pairs(ActiveHeists) do
        if heist.gangId == gangId then
            heists[id] = heist
        end
    end
    
    cb(heists)
end)

-- Get Gang Reputation
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangReputation', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        cb(0)
        return
    end
    
    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        cb(0)
        return
    end
    
    cb(Gangs[gangId].reputation or 0)
end)

-- ======================
-- PERIODIC UPDATES
-- ======================

-- Check for failed heists
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        
        local currentTime = os.time()
        
        for id, heist in pairs(ActiveHeists) do
            local heistConfig = Config.HeistTypes[heist.heistType]
            local startTime = os.time(os.date("!*t", heist.startTime))
            
            -- Check if heist has timed out (3 hours max)
            if currentTime - startTime > 10800 then -- 3 hours
                -- Fail heist
                MySQL.update('UPDATE cold_active_heists SET status = ? WHERE id = ?', {'failed', id})
                
                -- Notify
                Core.NotifyGangMembers(heist.gangId, "Heist Failed", "Your " .. heist.heistType .. " heist has failed due to timeout")
                
                -- Notify all clients
                TriggerClientEvent('cold-gangs:client:HeistFailed', -1, id, "Timed out")
                
                -- Remove from active heists
                ActiveHeists[id] = nil
            end
        end
        
        -- Sync to clients
        TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
    end
end)

-- Sync heists to clients
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        TriggerClientEvent('cold-gangs:client:SyncHeists', -1, ActiveHeists)
    end
end)

-- ======================
-- EXPORTS
-- ======================

-- Get Heist
function GetHeist(heistId)
    return ActiveHeists[heistId]
end

-- Get Heists by Gang ID
function GetHeistsByGangId(gangId)
    local heists = {}
    
    for id, heist in pairs(ActiveHeists) do
        if heist.gangId == gangId then
            heists[id] = heist
        end
    end
    
    return heists
end

-- Register exports
exports('GetHeist', GetHeist)
exports('GetHeistsByGangId', GetHeistsByGangId)
