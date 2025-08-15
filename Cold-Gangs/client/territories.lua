local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayerGang = nil
local Territories = {}
local CurrentTerritory = nil
local isCapturing = false
local captureProgress = 0
local captureBlip = nil
local isLoggedIn = false

-- Wait for player load
CreateThread(function()
    while not QBCore do
        QBCore = exports['qb-core']:GetCoreObject()
        Wait(100)
    end
    
    while not QBCore.Functions.GetPlayerData() do 
        Wait(100)
    end
    
    PlayerData = QBCore.Functions.GetPlayerData()
    isLoggedIn = true

    -- Sync territories
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territoryData)
        if territoryData then
            Territories = territoryData
        end
    end)
end)

-- Sync territories from server
RegisterNetEvent('cold-gangs:client:SyncTerritories', function(territoryData)
    if territoryData then
        Territories = territoryData
    end
end)

-- Entered territory
RegisterNetEvent('cold-gangs:client:EnteredTerritory', function(territoryName)
    local territory = Territories[territoryName]
    local ownerName = territory and territory.gangName or "Unclaimed"
    local color = "primary"

    if territory and territory.gangId then
        if territory.gangId == PlayerGang.id then
            color = "success"
        else
            color = "error"
        end
    end

    QBCore.Functions.Notify("Entered: " .. territoryName .. " | Controlled by: " .. ownerName, color)

    -- Play sound if enemy territory
    if territory and territory.gangId and territory.gangId ~= PlayerGang.id then
        PlaySoundFrontend(-1, "FocusIn", "HintCamSounds", true)
    end
end)

-- Left territory
RegisterNetEvent('cold-gangs:client:LeftTerritory', function(territoryName)
    QBCore.Functions.Notify("Left: " .. territoryName, "primary")
end)

-- Start capture
RegisterNetEvent('cold-gangs:client:StartCapture', function(territoryName, captureTime)
    if isCapturing then return end

    isCapturing = true
    captureProgress = 0
    CurrentTerritory = territoryName

    -- Create blip
    local coords = Config.Territories.List[territoryName] and Config.Territories.List[territoryName].coords
    if coords then
        captureBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(captureBlip, 1)
        SetBlipColour(captureBlip, 1)
        SetBlipFlashTimer(captureBlip, 500)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("CAPTURING: " .. territoryName)
        EndTextCommandSetBlipName(captureBlip)
    end

    -- Show progress
    CreateThread(function()
        while isCapturing do
            Wait(1000)
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local territoryCoords = Config.Territories.List[CurrentTerritory] and Config.Territories.List[CurrentTerritory].coords

            if not territoryCoords or #(playerCoords - vector3(territoryCoords.x, territoryCoords.y, territoryCoords.z)) > (Config.Territories.List[CurrentTerritory].radius + 10.0) then
                -- Out of range
                TriggerServerEvent('cold-gangs:server:LeftCaptureArea', CurrentTerritory)
                isCapturing = false
                captureProgress = 0
                if captureBlip then
                    RemoveBlip(captureBlip)
                    captureBlip = nil
                end
                QBCore.Functions.Notify("Territory capture cancelled", "error")
                return
            end

            -- Update progress
            captureProgress = captureProgress + (1000 / captureTime)
            if captureProgress >= 100 then
                TriggerServerEvent('cold-gangs:server:CompleteCapture', CurrentTerritory)
                isCapturing = false
                captureProgress = 0
                if captureBlip then
                    RemoveBlip(captureBlip)
                    captureBlip = nil
                end
                return
            end

            -- Send progress to server
            TriggerServerEvent('cold-gangs:server:UpdateCaptureProgress', CurrentTerritory, captureProgress)
        end
    end)
end)

-- Update capture progress
RegisterNetEvent('cold-gangs:client:UpdateCaptureProgress', function(territoryName, progress)
    if CurrentTerritory == territoryName then
        captureProgress = progress
    end
end)

-- Capture ended
RegisterNetEvent('cold-gangs:client:CaptureEnded', function(territoryName, success)
    if not isCapturing then return end

    isCapturing = false
    captureProgress = 0

    if captureBlip then
        RemoveBlip(captureBlip)
        captureBlip = nil
    end

    if success then
        QBCore.Functions.Notify("Successfully captured " .. territoryName, "success")
        PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", true)
    else
        QBCore.Functions.Notify("Failed to capture " .. territoryName, "error")
    end
end)

-- Monitor player position for territories
CreateThread(function()
    while true do
        Wait(3000)
        
        if isLoggedIn and PlayerGang and Config and Config.Territories and Config.Territories.List then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local closestTerritory = nil
            local closestDistance = -1

            for name, config in pairs(Config.Territories.List) do
                if config and config.coords and config.radius then
                    local distance = #(playerCoords - config.coords)
                    if distance <= config.radius then
                        if closestDistance == -1 or distance < closestDistance then
                            closestTerritory = name
                            closestDistance = distance
                        end
                    end
                end
            end

            -- Handle territory changes
            if closestTerritory ~= CurrentTerritory then
                if CurrentTerritory then
                    TriggerEvent('cold-gangs:client:LeftTerritory', CurrentTerritory)
                end
                CurrentTerritory = closestTerritory
                if CurrentTerritory then
                    TriggerEvent('cold-gangs:client:EnteredTerritory', CurrentTerritory)
                end
            end
        end
    end
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if captureBlip then
        RemoveBlip(captureBlip)
        captureBlip = nil
    end
end)
