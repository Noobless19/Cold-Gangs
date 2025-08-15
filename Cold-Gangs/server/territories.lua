local QBCore = exports['qb-core']:GetCoreObject()

-- Local data
local ActiveCaptures = {}

-- ======================
-- CLAIMING & CAPTURE
-- ======================

-- Player enters territory
RegisterNetEvent('cold-gangs:server:EnteredTerritory', function(territoryName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then return end

    local territory = Territories[territoryName]
    local zone = Config.Territories.List[territoryName]

    if not zone then return end

    -- If unclaimed and player is in a gang, start capture
    if not territory or not territory.gangId then
        if not exports['cold-gangs']:HasGangPermission(src, 'manageTerritories') then return end

        if not ActiveCaptures[territoryName] then
            -- Start capture
            ActiveCaptures[territoryName] = {
                gangId = gangId,
                gangName = (Gangs[gangId] and Gangs[gangId].name) or "Unknown Gang",
                progress = 0,
                players = {},
                startTime = os.time(),
                requiredPlayers = 1
            }
            TriggerClientEvent('cold-gangs:client:StartCapture', -1, territoryName, Config.Territories.System.captureTime)
        end

        -- Add player to capture
        if ActiveCaptures[territoryName] and ActiveCaptures[territoryName].gangId == gangId then
            ActiveCaptures[territoryName].players[src] = true
        end
    end
end)

-- Player leaves territory
RegisterNetEvent('cold-gangs:server:LeftTerritory', function(territoryName)
    local src = source

    if ActiveCaptures[territoryName] and ActiveCaptures[territoryName].players[src] then
        ActiveCaptures[territoryName].players[src] = nil
    end
end)

-- Update capture progress
RegisterNetEvent('cold-gangs:server:UpdateCaptureProgress', function(territoryName, progress)
    local src = source
    if not ActiveCaptures[territoryName] then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId or ActiveCaptures[territoryName].gangId ~= gangId then return end

    ActiveCaptures[territoryName].progress = progress

    -- Sync to all clients
    TriggerClientEvent('cold-gangs:client:UpdateCaptureProgress', -1, territoryName, progress)
end)

-- Complete capture
RegisterNetEvent('cold-gangs:server:CompleteCapture', function(territoryName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not ActiveCaptures[territoryName] then return end

    local capturingGangId = ActiveCaptures[territoryName].gangId
    local currentGangId = Territories[territoryName] and Territories[territoryName].gangId

    -- Can't capture if already owned by same gang
    if currentGangId == capturingGangId then return end

    -- Update DB
    if currentGangId then
        MySQL.update('UPDATE cold_territories SET gang_id = ?, gang_name = ?, claimed_at = NOW() WHERE name = ?', {
            capturingGangId,
            (Gangs[capturingGangId] and Gangs[capturingGangId].name) or "Unknown Gang",
            territoryName
        })
        
        -- Add reputation for capturing from another gang
        exports['cold-gangs']:AddGangReputation(capturingGangId, 150)
        
        -- Deduct reputation from losing gang
        exports['cold-gangs']:AddGangReputation(currentGangId, -200)
    else
        -- Insert new territory claim
        MySQL.insert('INSERT INTO cold_territories (name, gang_id, gang_name, claimed_at) VALUES (?, ?, ?, NOW())', {
            territoryName,
            capturingGangId,
            (Gangs[capturingGangId] and Gangs[capturingGangId].name) or "Unknown Gang"
        })
        
        -- Add reputation for claiming unclaimed territory
        exports['cold-gangs']:AddGangReputation(capturingGangId, 100)
    end

    -- Update in memory
    Territories[territoryName] = {
        gangId = capturingGangId,
        gangName = (Gangs[capturingGangId] and Gangs[capturingGangId].name) or "Unknown Gang",
        capturedAt = os.date('%Y-%m-%d %H:%M:%S'),
        incomeGenerated = 0
    }

    -- Clear capture
    ActiveCaptures[territoryName] = nil

    -- Notify
    Core.NotifyGangMembers(capturingGangId, "Territory Captured", "Your gang has captured " .. territoryName .. "!")
    if currentGangId then
        Core.NotifyGangMembers(currentGangId, "Territory Lost", "Your gang has lost control of " .. territoryName .. "!")
    end
    
    TriggerClientEvent('cold-gangs:client:CaptureEnded', -1, territoryName, true)
    TriggerClientEvent('cold-gangs:client:SyncTerritories', -1, Territories)
end)

-- Cancel capture if player leaves
RegisterNetEvent('cold-gangs:server:LeftCaptureArea', function(territoryName)
    local src = source

    if ActiveCaptures[territoryName] then
        ActiveCaptures[territoryName].players[src] = nil

        -- If no players left, cancel
        local playerCount = 0
        for _ in pairs(ActiveCaptures[territoryName].players) do
            playerCount = playerCount + 1
        end

        if playerCount == 0 then
            ActiveCaptures[territoryName] = nil
            TriggerClientEvent('cold-gangs:client:CaptureEnded', -1, territoryName, false)
        end
    end
end)

-- Abandon territory
RegisterNetEvent('cold-gangs:server:AbandonTerritory', function(territoryName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then return end

    local territory = Territories[territoryName]
    if not territory or territory.gangId ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "You don't control this territory", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageTerritories') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to abandon territories", "error")
        return
    end

    -- Remove from DB
    MySQL.query('DELETE FROM cold_territories WHERE name = ?', {territoryName})

    -- Remove from memory
    Territories[territoryName] = nil

    -- Notify
    Core.NotifyGangMembers(gangId, "Territory Abandoned", "Your gang has abandoned " .. territoryName)
    TriggerClientEvent('QBCore:Notify', src, "Territory abandoned", "success")
    TriggerClientEvent('cold-gangs:client:SyncTerritories', -1, Territories)
end)

-- ======================
-- INCOME GENERATION
-- ======================

-- Process territory income
function ProcessTerritoryIncome()
    for name, territory in pairs(Territories) do
        if territory.gangId and Gangs[territory.gangId] then
            local income = Config.Territories.List[name] and Config.Territories.List[name].income or 100
            exports['cold-gangs']:AddGangMoney(territory.gangId, income, "Territory Income: " .. name)
            territory.incomeGenerated = (territory.incomeGenerated or 0) + income
            
            -- Update DB
            MySQL.update('UPDATE cold_territories SET income_generated = income_generated + ? WHERE name = ?', {income, name})
        end
    end
end

-- Run every hour
CreateThread(function()
    while true do
        Wait(Config.Territories.System.incomeInterval)
        ProcessTerritoryIncome()
    end
end)

-- ======================
-- CALLBACKS
-- ======================

-- Get all territories
QBCore.Functions.CreateCallback('cold-gangs:server:GetAllTerritories', function(source, cb)
    cb(Territories)
end)

-- Get capture status
QBCore.Functions.CreateCallback('cold-gangs:server:GetCaptureStatus', function(source, cb, territoryName)
    cb(ActiveCaptures[territoryName])
end)

-- ======================
-- EXPORTS
-- ======================

-- Is territory controlled by gang
function IsTerritoryControlledByGang(territoryName, gangId)
    return Territories[territoryName] and Territories[territoryName].gangId == gangId
end

-- Get territory owner
function GetTerritoryOwner(territoryName)
    return Territories[territoryName] and Territories[territoryName].gangId
end

-- Get territory income
function GetTerritoryIncome(territoryName)
    return Config.Territories.List[territoryName] and Config.Territories.List[territoryName].income or 0
end

-- Register exports
exports('IsTerritoryControlledByGang', IsTerritoryControlledByGang)
exports('GetTerritoryOwner', GetTerritoryOwner)
exports('GetTerritoryIncome', GetTerritoryIncome)

-- Sync territories to client
RegisterNetEvent('cold-gangs:server:SyncTerritories', function()
    TriggerClientEvent('cold-gangs:client:SyncTerritories', -1, Territories)
end)

-- Periodic sync
CreateThread(function()
    while true do
        Wait(10000) -- Every 10 seconds
        TriggerClientEvent('cold-gangs:client:SyncTerritories', -1, Territories)
    end
end)
