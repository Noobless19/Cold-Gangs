local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayerGang = nil
local GangVehicles = {}
local VehicleBlips = {}

-- Initialize
CreateThread(function()
    while not QBCore do
        QBCore = exports['qb-core']:GetCoreObject()
        Wait(100)
    end
    
    while not QBCore.Functions.GetPlayerData() do 
        Wait(100) 
    end

    isLoggedIn = true
    PlayerData = QBCore.Functions.GetPlayerData()

    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData)
        PlayerGang = gangData
    end)

    -- Sync vehicles
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangVehicles', function(vehicles)
        GangVehicles = vehicles or {}
        CreateVehicleBlips()
    end)
end)

-- Sync vehicles from server
RegisterNetEvent('cold-gangs:client:SyncVehicles', function(vehicles)
    GangVehicles = vehicles or {}
    CreateVehicleBlips()
end)

-- Create Vehicle Blips
function CreateVehicleBlips()
    -- Clear old blips
    for _, blip in pairs(VehicleBlips) do
        RemoveBlip(blip)
    end
    VehicleBlips = {}

    if not GangVehicles then return end

    for plate, vehicle in pairs(GangVehicles) do
        if not vehicle.stored and not vehicle.impounded and vehicle.location then
            local coords = json.decode(vehicle.location)
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, 225)
            SetBlipColour(blip, 2)
            SetBlipScale(blip, 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(vehicle.label .. " (" .. vehicle.plate .. ")")
            EndTextCommandSetBlipName(blip)
            VehicleBlips[plate] = blip
        end
    end
end

-- Register Vehicle
RegisterNetEvent('cold-gangs:client:RegisterVehicle', function()
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    if not exports['cold-gangs']:HasGangPermission('manageVehicles') then
        QBCore.Functions.Notify("You don't have permission to register vehicles", "error")
        return
    end
    
    -- Check if player is in a vehicle
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then
        QBCore.Functions.Notify("You need to be in a vehicle", "error")
        return
    end
    
    -- Check if vehicle is already registered
    local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
    
    QBCore.Functions.TriggerCallback('cold-gangs:server:IsVehicleRegistered', function(isRegistered)
        if isRegistered then
            QBCore.Functions.Notify("This vehicle is already registered", "error")
            return
        end
        
        -- Get vehicle properties
        local props = QBCore.Functions.GetVehicleProperties(vehicle)
        local model = GetEntityModel(vehicle)
        local displayName = GetDisplayNameFromVehicleModel(model)
        local label = GetLabelText(displayName)
        if label == "NULL" then label = displayName end
        
        -- Register vehicle
        TriggerServerEvent('cold-gangs:server:RegisterGangVehicle', plate, props, model, label)
    end, plate)
end)

-- Spawn Gang Vehicle
RegisterNetEvent('cold-gangs:client:SpawnGangVehicle', function(plate)
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    -- Check if near garage
    local isNearGarage = false
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, garage in pairs(Config.GangGarages or {}) do
        if #(playerCoords - garage.coords) < 10.0 then
            isNearGarage = true
            break
        end
    end
    
    if not isNearGarage then
        QBCore.Functions.Notify("You need to be at a gang garage", "error")
        return
    end
    
    -- Spawn vehicle
    TriggerServerEvent('cold-gangs:server:SpawnGangVehicle', plate)
end)

-- Store Gang Vehicle
RegisterNetEvent('cold-gangs:client:StoreGangVehicle', function()
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    -- Check if player is in a vehicle
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle == 0 then
        QBCore.Functions.Notify("You need to be in a vehicle", "error")
        return
    end
    
    -- Check if near garage
    local isNearGarage = false
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, garage in pairs(Config.GangGarages or {}) do
        if #(playerCoords - garage.coords) < 10.0 then
            isNearGarage = true
            break
        end
    end
    
    if not isNearGarage then
        QBCore.Functions.Notify("You need to be at a gang garage", "error")
        return
    end
    
    -- Get plate
    local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
    
    -- Check if gang vehicle
    QBCore.Functions.TriggerCallback('cold-gangs:server:IsGangVehicle', function(isGangVehicle)
        if not isGangVehicle then
            QBCore.Functions.Notify("This is not a gang vehicle", "error")
            return
        end
        
        -- Store vehicle
        TriggerServerEvent('cold-gangs:server:StoreGangVehicle', plate)
        
        -- Delete vehicle
        QBCore.Functions.DeleteVehicle(vehicle)
    end, plate, PlayerGang.id)
end)

-- Vehicle Spawned
RegisterNetEvent('cold-gangs:client:VehicleSpawned', function(vehicleData, coords)
    if not vehicleData or not coords then return end
    
    -- Request model
    local model = vehicleData.model
    if not IsModelInCdimage(model) then return end
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    -- Spawn vehicle
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, coords.h, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    
    -- Set vehicle properties
    QBCore.Functions.SetVehicleProperties(vehicle, vehicleData.props)
    
    -- Set plate
    SetVehicleNumberPlateText(vehicle, vehicleData.plate)
    
    -- Give keys
    TriggerEvent('vehiclekeys:client:SetOwner', vehicleData.plate)
    
    -- Notification
    QBCore.Functions.Notify("Vehicle spawned: " .. vehicleData.label, "success")
    
    -- Set as current vehicle
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
end)

-- Track Vehicle
RegisterNetEvent('cold-gangs:client:TrackVehicle', function(plate)
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    if not GangVehicles[plate] then
        QBCore.Functions.Notify("Vehicle not found", "error")
        return
    end
    
    if GangVehicles[plate].stored then
        QBCore.Functions.Notify("Vehicle is stored in the garage", "error")
        return
    end
    
    if GangVehicles[plate].impounded then
        QBCore.Functions.Notify("Vehicle is impounded", "error")
        return
    end
    
    if not GangVehicles[plate].location then
        QBCore.Functions.Notify("Vehicle location unknown", "error")
        return
    end
    
    -- Set waypoint
    local coords = json.decode(GangVehicles[plate].location)
    SetNewWaypoint(coords.x, coords.y)
    
    QBCore.Functions.Notify("Waypoint set to vehicle location", "success")
end)

-- Update Vehicle Position
CreateThread(function()
    while true do
        Wait(10000) -- Every 10 seconds
        
        if isLoggedIn and PlayerGang then
            local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
            if vehicle ~= 0 then
                local plate = GetVehicleNumberPlateText(vehicle):gsub("%s+", "")
                
                -- Check if gang vehicle
                if GangVehicles[plate] and not GangVehicles[plate].stored and not GangVehicles[plate].impounded then
                    local coords = GetEntityCoords(vehicle)
                    local heading = GetEntityHeading(vehicle)
                    
                    -- Update position
                    TriggerServerEvent('cold-gangs:server:UpdateVehiclePosition', plate, {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z,
                        h = heading
                    })
                end
            end
        end
    end
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    for _, blip in pairs(VehicleBlips) do
        RemoveBlip(blip)
    end
    VehicleBlips = {}
end)
