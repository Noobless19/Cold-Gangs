local QBCore = exports['qb-core']:GetCoreObject()

local VALET_PED = `s_m_y_valet_01`
local VALET_DRIVE_SPEED = 18.0
local VALET_PARK_DIST = 7.5
local GarageZones = {}
local GARAGE_DISTANCE = 15.0 -- Distance you need to be from garage to store vehicle

-- ════════════════════════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ════════════════════════════════════════════════════════════════════════════════════

local function started(r) 
    return GetResourceState(r) == 'started' 
end

local function LoadModel(hash)
    if type(hash) == 'string' then hash = GetHashKey(hash) end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 200 do 
        timeout = timeout + 1 
        Wait(10) 
    end
    return HasModelLoaded(hash)
end

local function ApplyProps(veh, props)
    if QBCore and QBCore.Functions and QBCore.Functions.SetVehicleProperties then 
        QBCore.Functions.SetVehicleProperties(veh, props) 
    end
    if props and props.plate then 
        SetVehicleNumberPlateText(veh, props.plate) 
    end
end

local function GetSafeSpawnCoords(x, y, z)
    -- Try to find ground
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 100.0, false)
    
    if foundGround then
        z = groundZ + 1.0
    end
    
    -- Try to find nearest vehicle node (road)
    local found, nodePos, nodeHeading = GetClosestVehicleNodeWithHeading(x, y, z, 1, 3.0, 0)
    
    if found then
        -- Check if the node is too far away (more than 50 units)
        local distance = #(vector3(x, y, z) - vector3(nodePos.x, nodePos.y, nodePos.z))
        if distance < 50.0 then
            return vector3(nodePos.x, nodePos.y, nodePos.z + 0.5), nodeHeading
        end
    end
    
    -- Fallback: just use the position with ground Z
    return vector3(x, y, z), 0.0
end

local function forceUnlockVehicle(veh)
    SetVehicleDoorsLocked(veh, 1)
    SetVehicleDoorsLockedForAllPlayers(veh, false)
    SetVehicleDoorsLockedForPlayer(veh, PlayerId(), false)
    SetVehicleDoorsLockedForTeam(veh, PlayerId(), false)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehicleEngineOn(veh, false, false, false)
end

local function giveKeys(veh, plate)
    if not DoesEntityExist(veh) then return end
    
    -- Get the actual plate from the vehicle
    local actualPlate = GetVehicleNumberPlateText(veh)
    actualPlate = actualPlate and string.gsub(actualPlate, "^%s*(.-)%s*$", "%1") or plate -- Trim whitespace
    
    forceUnlockVehicle(veh)
    
    if started('qb-vehiclekeys') then
        -- vehiclekeys:client:SetOwner expects the plate text as parameter
        TriggerEvent('vehiclekeys:client:SetOwner', actualPlate)
        TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', actualPlate)
        return
    end
    
    if started('ps-vehiclekeys') then
        local success = pcall(function()
            exports['ps-vehiclekeys']:GiveKeys(veh)
        end)
        if not success then
            TriggerEvent('vehiclekeys:client:SetOwner', actualPlate)
        end
        return
    end
    
    if started('qs-vehiclekeys') then
        local success = pcall(function()
            exports['qs-vehiclekeys']:GiveKeys(actualPlate)
        end)
        if not success then
            TriggerEvent('vehiclekeys:client:SetOwner', actualPlate)
        end
        return
    end
    
    -- Fallback
    TriggerEvent('vehiclekeys:client:SetOwner', actualPlate)
end

local function ValetSpawnNearPlayer(minDist, maxDist)
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local h  = GetEntityHeading(ped)
    local rad = math.rad(h)
    local dist = math.random(math.floor(minDist or 40), math.floor(maxDist or 60))
    
    -- Calculate position behind player
    local x = pc.x - math.sin(rad) * dist
    local y = pc.y + math.cos(rad) * dist
    local z = pc.z
    
    -- Get safe spawn coordinates
    local safeCoords, safeHeading = GetSafeSpawnCoords(x, y, z)
    
    return safeCoords, safeHeading
end

local function DeleteVehicleByPlateLocal(plate)
    local s = (string.gsub((plate or ""), "%s+", "") or ""):upper()
    if s == "" then return false end
    
    local vehs = GetGamePool('CVehicle') or {}
    for _, v in ipairs(vehs) do
        if DoesEntityExist(v) then
            local p = (QBCore.Functions.GetPlate and QBCore.Functions.GetPlate(v)) or GetVehicleNumberPlateText(v) or ""
            p = (string.gsub(p, "%s+", "") or ""):upper()
            
            if p == s then
                -- Request network control
                local netId = NetworkGetNetworkIdFromEntity(v)
                if netId then
                    SetNetworkIdCanMigrate(netId, true)
                end
                
                local timeout = 0
                NetworkRequestControlOfEntity(v)
                while not NetworkHasControlOfEntity(v) and timeout < 50 do 
                    Wait(10) 
                    NetworkRequestControlOfEntity(v) 
                    timeout = timeout + 1 
                end
                
                SetEntityAsMissionEntity(v, true, true)
                DeleteVehicle(v)
                
                -- Fallback delete
                if DoesEntityExist(v) then 
                    DeleteEntity(v) 
                end
                
                return true
            end
        end
    end
    return false
end

-- Check if player is near their gang's garage
local function IsNearGangGarage()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    
    for gangId, garageCoords in pairs(GarageZones) do
        local garagePos = vector3(garageCoords.x, garageCoords.y, garageCoords.z)
        local distance = #(pos - garagePos)
        
        if distance <= GARAGE_DISTANCE then
            return true, distance
        end
    end
    
    return false, nil
end

-- ════════════════════════════════════════════════════════════════════════════════════
-- VALET DELIVERY SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('cold-gangs:client:ValetDeliver', function(data)
    local props = data and data.props or {}
    local drop = data and data.dropOff
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    drop = drop or { x = pc.x, y = pc.y, z = pc.z }
    
    local model = props.model
    if type(model) == 'string' then model = GetHashKey(model) end
    if type(model) ~= 'number' or model == 0 then
        TriggerEvent('cold-gangs:client:SpawnGangVehicle', props, { x=pc.x, y=pc.y, z=pc.z, h=GetEntityHeading(ped) })
        QBCore.Functions.Notify("Valet fallback delivery", "primary")
        return
    end
    
    if not LoadModel(VALET_PED) or not LoadModel(model) then
        TriggerEvent('cold-gangs:client:SpawnGangVehicle', props, { x=pc.x, y=pc.y, z=pc.z, h=GetEntityHeading(ped) })
        QBCore.Functions.Notify("Valet fallback delivery", "primary")
        return
    end
    
    local spawnPos, spawnH = ValetSpawnNearPlayer(40, 60)
    
    -- Create valet ped
    local valet = CreatePed(4, VALET_PED, spawnPos.x, spawnPos.y, spawnPos.z, spawnH, true, false)
    if not valet or not DoesEntityExist(valet) then
        TriggerEvent('cold-gangs:client:SpawnGangVehicle', props, { x=pc.x, y=pc.y, z=pc.z, h=GetEntityHeading(ped) })
        QBCore.Functions.Notify("Valet fallback delivery", "primary")
        return
    end
    
    SetEntityAsMissionEntity(valet, true, true)
    SetBlockingOfNonTemporaryEvents(valet, true)
    SetEntityInvincible(valet, true)
    
    -- Create vehicle
    local veh = CreateVehicle(model, spawnPos.x, spawnPos.y, spawnPos.z, spawnH, true, false)
    if not veh or not DoesEntityExist(veh) then
        DeleteEntity(valet)
        TriggerEvent('cold-gangs:client:SpawnGangVehicle', props, { x=pc.x, y=pc.y, z=pc.z, h=GetEntityHeading(ped) })
        QBCore.Functions.Notify("Valet fallback delivery", "primary")
        return
    end
    
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetVehicleOnGroundProperly(veh)
    
    -- Apply props and set plate
    ApplyProps(veh, props)
    
    -- Wait for plate to sync, then give keys
    Wait(1000)
    giveKeys(veh, props.plate)
    
    -- Lock for valet
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleEngineOn(veh, true, true, false)
    
    -- Put valet in vehicle and drive to player
    SetPedIntoVehicle(valet, veh, -1)
    TaskVehicleDriveToCoord(valet, veh, drop.x+0.0, drop.y+0.0, drop.z+0.0, VALET_DRIVE_SPEED, 0, model, 786603, 3.0, true)
    
    -- Create blip for tracking
    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 225)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 1)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Gang Vehicle")
    EndTextCommandSetBlipName(blip)
    
    QBCore.Functions.Notify("Valet is on the way with your vehicle", "primary", 3000)
    
    -- Monitor valet arrival
    local start = GetGameTimer()
    local arrived = false
    
    CreateThread(function()
        while DoesEntityExist(valet) and DoesEntityExist(veh) do
            local cur = GetEntityCoords(veh)
            if #(vector3(drop.x, drop.y, drop.z) - cur) <= VALET_PARK_DIST then 
                arrived = true 
                break 
            end
            if GetGameTimer() - start > 40000 then 
                break 
            end
            Wait(500)
        end
        
        if arrived and DoesEntityExist(valet) and DoesEntityExist(veh) then
            -- Valet has arrived
            ClearPedTasks(valet)
            TaskVehicleTempAction(valet, veh, 27, 3000)
            Wait(1500)
            
            TaskLeaveVehicle(valet, veh, 0)
            Wait(3000)
            
            if DoesEntityExist(veh) then
                forceUnlockVehicle(veh)
                SetVehicleOnGroundProperly(veh)
                Wait(1000)
                
                -- Give keys again after valet exits
                giveKeys(veh, props.plate)
                
                QBCore.Functions.Notify("Your vehicle is ready", "success")
            end
            
            -- Cleanup valet
            if DoesEntityExist(valet) then
                TaskWanderStandard(valet, 10.0, 10)
                SetPedKeepTask(valet, true)
                Wait(10000)
                if DoesEntityExist(valet) then
                    DeleteEntity(valet)
                end
            end
        else
            -- Valet failed to arrive, teleport vehicle to player
            if DoesEntityExist(valet) then 
                DeleteEntity(valet) 
            end
            
            if DoesEntityExist(veh) then
                local newPc = GetEntityCoords(PlayerPedId())
                local safePos, safeH = GetSafeSpawnCoords(newPc.x, newPc.y, newPc.z)
                
                SetEntityCoords(veh, safePos.x, safePos.y, safePos.z, false, false, false, false)
                SetEntityHeading(veh, safeH)
                SetVehicleOnGroundProperly(veh)
                
                forceUnlockVehicle(veh)
                Wait(1000)
                
                giveKeys(veh, props.plate)
                
                QBCore.Functions.Notify("Valet couldn't reach you, delivered nearby", "primary")
            end
        end
        
        -- Location tracking thread
        CreateThread(function()
            while DoesEntityExist(veh) do
                Wait(10000)
                local c = GetEntityCoords(veh)
                TriggerServerEvent('cold-gangs:vehicles:UpdateLocation', props.plate, { x=c.x, y=c.y, z=c.z })
            end
            if DoesBlipExist(blip) then 
                RemoveBlip(blip) 
            end
        end)
    end)
end)

-- ════════════════════════════════════════════════════════════════════════════════════
-- INSTANT SPAWN SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('cold-gangs:client:SpawnGangVehicle', function(props, spawnAt)
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local pos = { 
        x = (spawnAt and spawnAt.x) or pc.x, 
        y = (spawnAt and spawnAt.y) or pc.y, 
        z = (spawnAt and spawnAt.z) or pc.z, 
        h = (spawnAt and spawnAt.h) or GetEntityHeading(ped) 
    }
    
    -- Get safe spawn position
    local safePos, safeH = GetSafeSpawnCoords(pos.x, pos.y, pos.z)
    
    local model = props.model
    if type(model) == 'string' then model = GetHashKey(model) end
    if not LoadModel(model) then return end
    
    -- Create vehicle
    local veh = CreateVehicle(model, safePos.x, safePos.y, safePos.z, safeH, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehicleOnGroundProperly(veh)
    
    -- Apply properties
    ApplyProps(veh, props)
    
    -- Give keys
    Wait(1000)
    giveKeys(veh, props.plate)
    
    -- Put player in vehicle
    TaskWarpPedIntoVehicle(ped, veh, -1)
    
    -- Create blip
    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, 225)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 2)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Gang Vehicle")
    EndTextCommandSetBlipName(blip)
    
    -- Location tracking thread
    CreateThread(function()
        while DoesEntityExist(veh) do
            Wait(10000)
            local c = GetEntityCoords(veh)
            TriggerServerEvent('cold-gangs:vehicles:UpdateLocation', props.plate, { x=c.x, y=c.y, z=c.z })
        end
        if DoesBlipExist(blip) then 
            RemoveBlip(blip) 
        end
    end)
end)

-- ════════════════════════════════════════════════════════════════════════════════════
-- VEHICLE STORAGE SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('cold-gangs:client:AttemptStoreVehicle', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    
    -- Check if player is in a vehicle
    if not veh or veh == 0 then
        QBCore.Functions.Notify("You must be in the vehicle to store it", "error")
        return
    end
    
    -- Check if player is near their gang garage
    local nearGarage, distance = IsNearGangGarage()
    if not nearGarage then
        QBCore.Functions.Notify("You must be near your gang garage to store vehicles (within 15m)", "error")
        return
    end
    
    -- Get vehicle plate
    local vehiclePlate = QBCore.Functions.GetPlate(veh)
    
    -- Server will verify ownership and store
    QBCore.Functions.TriggerCallback('cold-gangs:server:CanStoreVehicle', function(canStore, message)
        if canStore then
            QBCore.Functions.Notify("Storing vehicle...", "primary", 2000)
            
            -- Make player exit vehicle first
            TaskLeaveVehicle(ped, veh, 0)
            
            -- Wait for player to exit and then delete vehicle
            CreateThread(function()
                local timeout = 0
                while IsPedInVehicle(ped, veh, false) and timeout < 50 do
                    Wait(100)
                    timeout = timeout + 1
                end
                
                Wait(500)
                
                -- Try to get network control first
                local netId = NetworkGetNetworkIdFromEntity(veh)
                if netId then
                    SetNetworkIdCanMigrate(netId, true)
                    NetworkRequestControlOfEntity(veh)
                    
                    local attempts = 0
                    while not NetworkHasControlOfEntity(veh) and attempts < 50 do
                        Wait(10)
                        NetworkRequestControlOfEntity(veh)
                        attempts = attempts + 1
                    end
                end
                
                -- Delete the vehicle
                SetEntityAsMissionEntity(veh, true, true)
                DeleteVehicle(veh)
                
                -- Double check and force delete if needed
                Wait(100)
                if DoesEntityExist(veh) then
                    DeleteEntity(veh)
                end
                
                Wait(100)
                if DoesEntityExist(veh) then
                    -- Last resort - try deleting by plate
                    DeleteVehicleByPlateLocal(vehiclePlate)
                end
                
                QBCore.Functions.Notify("Vehicle stored successfully", "success")
            end)
        else
            QBCore.Functions.Notify(message or "Cannot store this vehicle", "error")
        end
    end, vehiclePlate)
end)

-- Old event for backwards compatibility
RegisterNetEvent('cold-gangs:client:StoreVehicle', function(plate)
    TriggerEvent('cold-gangs:client:AttemptStoreVehicle')
end)

-- ════════════════════════════════════════════════════════════════════════════════════
-- VEHICLE RECALL/DELETE SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('cold-gangs:client:RecallVehicle', function(plate)
    DeleteVehicleByPlateLocal(plate)
end)

RegisterNetEvent('cold-gangs:client:DeleteVehicleByPlate', function(plate)
    DeleteVehicleByPlateLocal(plate)
end)

-- ════════════════════════════════════════════════════════════════════════════════════
-- VEHICLE TRACKING SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('cold-gangs:client:TrackGangVehicle', function(plate)
    if not plate or plate == '' then 
        QBCore.Functions.Notify("Invalid plate", "error") 
        return 
    end
    
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetVehicleLocation', function(loc)
        if loc and loc.x and loc.y then
            SetNewWaypoint(loc.x + 0.0, loc.y + 0.0)
            QBCore.Functions.Notify("Waypoint set to vehicle location", "success")
        else
            QBCore.Functions.Notify("No location data for this vehicle", "error")
        end
    end, plate)
end)

-- ════════════════════════════════════════════════════════════════════════════════════
-- GARAGE MARKER SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════════

local function buildGarageInteract(gangId, coords)
    GarageZones[gangId] = coords
    
    CreateThread(function()
        while GarageZones[gangId] do
            Wait(0)
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local c = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
            local d = #(p - c)
            
            if d < 20.0 then
                DrawMarker(1, c.x, c.y, c.z - 1.0, 0, 0, 0, 0, 0, 0, 2.2, 2.2, 0.3, 255, 0, 0, 120, false, false, 2, false, nil, nil, false)
                
                if d < 2.0 then
                    SetTextComponentFormat('STRING')
                    AddTextComponentString('Press ~INPUT_CONTEXT~ to open Gang Garage')
                    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                    
                    if IsControlJustReleased(0, 38) then 
                        TriggerEvent('cold-gangs:client:OpenGangMenu') 
                    end
                end
            else
                Wait(250)
            end
        end
    end)
end

-- ════════════════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ════════════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(1200)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(g)
        if g and g.id then
            QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangGarage', function(gar)
                if gar and gar.x then 
                    buildGarageInteract(g.id, gar) 
                end
            end)
        end
    end)
end)

RegisterNetEvent('cold-gangs:client:GarageUpdated', function(gangId, coords)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(g)
        if g and g.id == gangId then 
            buildGarageInteract(gangId, coords) 
        end
    end)
end)
