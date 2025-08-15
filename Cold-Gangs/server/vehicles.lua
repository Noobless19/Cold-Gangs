local QBCore = exports['qb-core']:GetCoreObject()

-- ======================
-- REGISTER VEHICLE
-- ======================

-- Register Gang Vehicle
RegisterNetEvent('cold-gangs:server:RegisterGangVehicle', function(plate, props, model, label)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageVehicles') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to register vehicles", "error")
        return
    end

    -- Check if vehicle is already registered
    local result = MySQL.query.await('SELECT * FROM cold_gang_vehicles WHERE plate = ?', {plate})
    if result and #result > 0 then
        TriggerClientEvent('QBCore:Notify', src, "This vehicle is already registered", "error")
        return
    end

    -- Check gang vehicle limit
    local vehicleCount = MySQL.query.await('SELECT COUNT(*) as count FROM cold_gang_vehicles WHERE gang_id = ?', {gangId})
    if vehicleCount and vehicleCount[1].count >= (Config.MaxGangVehicles or 10) then
        TriggerClientEvent('QBCore:Notify', src, "Your gang has reached the vehicle limit", "error")
        return
    end

    -- Register vehicle
    MySQL.insert('INSERT INTO cold_gang_vehicles (plate, gang_id, model, label, stored, impounded, last_seen) VALUES (?, ?, ?, ?, ?, ?, NOW())', {
        plate,
        gangId,
        model,
        label,
        1, -- Stored
        0  -- Not impounded
    })

    -- Add to memory
    GangVehicles[plate] = {
        plate = plate,
        gangId = gangId,
        model = model,
        label = label,
        stored = true,
        impounded = false,
        lastSeen = os.date('%Y-%m-%d %H:%M:%S'),
        location = nil,
        props = props
    }

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Vehicle registered: " .. label .. " (" .. plate .. ")", "success")
    Core.NotifyGangMembers(gangId, "Vehicle Registered", Player.PlayerData.charinfo.firstname .. " registered a " .. label)

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncVehicles', -1, GangVehicles)
end)

-- ======================
-- SPAWN VEHICLE
-- ======================

-- Spawn Gang Vehicle
RegisterNetEvent('cold-gangs:server:SpawnGangVehicle', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    -- Check if vehicle exists and belongs to gang
    if not GangVehicles[plate] or GangVehicles[plate].gangId ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Vehicle not found or doesn't belong to your gang", "error")
        return
    end

    -- Check if vehicle is stored
    if not GangVehicles[plate].stored then
        TriggerClientEvent('QBCore:Notify', src, "This vehicle is already out", "error")
        return
    end

    -- Check if vehicle is impounded
    if GangVehicles[plate].impounded then
        TriggerClientEvent('QBCore:Notify', src, "This vehicle is impounded", "error")
        return
    end

    -- Get player position
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local heading = GetEntityHeading(GetPlayerPed(src))

    -- Update vehicle status
    MySQL.update('UPDATE cold_gang_vehicles SET stored = ?, last_seen = NOW() WHERE plate = ?', {0, plate})
    GangVehicles[plate].stored = false
    GangVehicles[plate].lastSeen = os.date('%Y-%m-%d %H:%M:%S')
    GangVehicles[plate].location = {
        x = playerCoords.x,
        y = playerCoords.y,
        z = playerCoords.z,
        h = heading
    }

    -- Spawn vehicle for player
    TriggerClientEvent('cold-gangs:client:VehicleSpawned', src, {
        plate = plate,
        model = GangVehicles[plate].model,
        props = GangVehicles[plate].props,
        label = GangVehicles[plate].label
    }, {
        x = playerCoords.x,
        y = playerCoords.y,
        z = playerCoords.z,
        h = heading
    })

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncVehicles', -1, GangVehicles)
end)

-- ======================
-- STORE VEHICLE
-- ======================

-- Store Gang Vehicle
RegisterNetEvent('cold-gangs:server:StoreGangVehicle', function(plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    -- Check if vehicle exists and belongs to gang
    if not GangVehicles[plate] or GangVehicles[plate].gangId ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Vehicle not found or doesn't belong to your gang", "error")
        return
    end

    -- Check if vehicle is already stored
    if GangVehicles[plate].stored then
        TriggerClientEvent('QBCore:Notify', src, "This vehicle is already stored", "error")
        return
    end

    -- Update vehicle status
    MySQL.update('UPDATE cold_gang_vehicles SET stored = ?, last_seen = NOW() WHERE plate = ?', {1, plate})
    GangVehicles[plate].stored = true
    GangVehicles[plate].lastSeen = os.date('%Y-%m-%d %H:%M:%S')
    GangVehicles[plate].location = nil

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Vehicle stored: " .. GangVehicles[plate].label, "success")

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncVehicles', -1, GangVehicles)
end)

-- ======================
-- UPDATE VEHICLE POSITION
-- ======================

-- Update Vehicle Position
RegisterNetEvent('cold-gangs:server:UpdateVehiclePosition', function(plate, coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then return end

    -- Check if vehicle exists and belongs to gang
    if not GangVehicles[plate] or GangVehicles[plate].gangId ~= gangId then return end

    -- Check if vehicle is not stored
    if GangVehicles[plate].stored then return end

    -- Update vehicle location
    GangVehicles[plate].location = coords
    GangVehicles[plate].lastSeen = os.date('%Y-%m-%d %H:%M:%S')

    -- Update database occasionally (not every time to reduce database load)
    if math.random(1, 10) == 1 then
        MySQL.update('UPDATE cold_gang_vehicles SET location = ?, last_seen = NOW() WHERE plate = ?', {json.encode(coords), plate})
    end
end)

-- ======================
-- CALLBACKS
-- ======================

-- Get Gang Vehicles
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangVehicles', function(source, cb, gangId)
    local vehicles = {}
    
    for plate, vehicle in pairs(GangVehicles) do
        if vehicle.gangId == gangId then
            vehicles[plate] = vehicle
        end
    end
    
    cb(vehicles)
end)

-- Check if Vehicle is Registered
QBCore.Functions.CreateCallback('cold-gangs:server:IsVehicleRegistered', function(source, cb, plate)
    cb(GangVehicles[plate] ~= nil)
end)

-- Check if Gang Vehicle
QBCore.Functions.CreateCallback('cold-gangs:server:IsGangVehicle', function(source, cb, plate, gangId)
    cb(GangVehicles[plate] ~= nil and GangVehicles[plate].gangId == gangId)
end)

-- ======================
-- PERIODIC UPDATES
-- ======================

-- Sync vehicles to clients
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        TriggerClientEvent('cold-gangs:client:SyncVehicles', -1, GangVehicles)
    end
end)

-- ======================
-- EXPORTS
-- ======================

-- Get Gang Vehicle
function GetGangVehicle(plate)
    return GangVehicles[plate]
end

-- Get Gang Vehicles by Gang ID
function GetGangVehiclesByGangId(gangId)
    local vehicles = {}
    
    for plate, vehicle in pairs(GangVehicles) do
        if vehicle.gangId == gangId then
            vehicles[plate] = vehicle
        end
    end
    
    return vehicles
end

-- Register exports
exports('GetGangVehicle', GetGangVehicle)
exports('GetGangVehiclesByGangId', GetGangVehiclesByGangId)
