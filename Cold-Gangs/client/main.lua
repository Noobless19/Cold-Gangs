local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayerData = {}
local PlayerGang = nil
local Territories = {}
local ActiveWars = {}
local GangBlips = {}
local TerritoryBlips = {}
local WarBlips = {}
local CurrentZone = nil
local isLoggedIn = false
local isCapturing = false
local captureProgress = 0
local captureBlip = nil
local ZoneEffects = {}

-- Initialize QBCore and player data
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

    -- Request initial gang data
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData)
        PlayerGang = gangData
    end)

    -- Sync territories
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territoryData)
        if territoryData then
            Territories = territoryData
            CreateTerritoryBlips()
        end
    end)

    -- Sync wars
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveWars', function(warData)
        if warData then
            ActiveWars = warData
            CreateWarBlips()
        end
    end)
end)

-- Handle player login
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
    PlayerData = QBCore.Functions.GetPlayerData()

    -- Refresh gang data
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData)
        PlayerGang = gangData
    end)

    -- Refresh territories
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territoryData)
        if territoryData then
            Territories = territoryData
            CreateTerritoryBlips()
        end
    end)

    -- Refresh wars
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveWars', function(warData)
        if warData then
            ActiveWars = warData
            CreateWarBlips()
        end
    end)
end)

-- Handle player logout
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
    PlayerGang = nil
    CurrentZone = nil
    ZoneEffects = {}
    PlayerData = {}
    
    -- Clean up blips
    for _, blip in pairs(GangBlips) do RemoveBlip(blip) end
    for _, blip in pairs(TerritoryBlips) do RemoveBlip(blip) end
    for _, blip in pairs(WarBlips) do RemoveBlip(blip) end
    GangBlips = {}
    TerritoryBlips = {}
    WarBlips = {}
end)

-- Create Territory Blips
function CreateTerritoryBlips()
    -- Clear old blips
    for _, blip in pairs(TerritoryBlips) do
        RemoveBlip(blip)
    end
    TerritoryBlips = {}

    if not Territories or not Config or not Config.Territories or not Config.Territories.List then
        return
    end

    for name, territory in pairs(Territories) do
        local coords = Config.Territories.List[name] and Config.Territories.List[name].coords
        if coords then
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, 500)
            SetBlipScale(blip, 0.8)
            
            if territory.gangId then
                SetBlipColour(blip, GetGangBlipColor(territory.gangId))
                SetBlipDisplay(blip, 4)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(name .. " (" .. (territory.gangName or "Unknown") .. ")")
                EndTextCommandSetBlipName(blip)
            else
                SetBlipColour(blip, 0)
                SetBlipDisplay(blip, 6)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(name .. " (Unclaimed)")
                EndTextCommandSetBlipName(blip)
            end
            
            TerritoryBlips[name] = blip
        end
    end
end

-- Create War Blips
function CreateWarBlips()
    for _, blip in pairs(WarBlips) do
        RemoveBlip(blip)
    end
    WarBlips = {}

    if not ActiveWars or not Config or not Config.Territories or not Config.Territories.List then
        return
    end

    for warId, war in pairs(ActiveWars) do
        if war.territoryName and Territories[war.territoryName] then
            local coords = Config.Territories.List[war.territoryName] and Config.Territories.List[war.territoryName].coords
            if coords then
                local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                SetBlipSprite(blip, 1)
                SetBlipColour(blip, 1)
                SetBlipFlashTimer(blip, 500)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("WAR: " .. (war.attackerName or "Unknown") .. " vs " .. (war.defenderName or "Unknown"))
                EndTextCommandSetBlipName(blip)
                WarBlips[warId] = blip
            end
        end
    end
end

-- Get Gang Blip Color
function GetGangBlipColor(gangId)
    return 2
end

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

            -- Handle territory entry/exit
            if closestTerritory ~= CurrentZone then
                if CurrentZone then
                    TriggerEvent('cold-gangs:client:LeftTerritory', CurrentZone)
                end
                CurrentZone = closestTerritory
                if CurrentZone then
                    TriggerEvent('cold-gangs:client:EnteredTerritory', CurrentZone)
                end
            end
        end
    end
end)

-- Zone Entered
RegisterNetEvent('cold-gangs:client:EnteredTerritory', function(territoryName)
    local territory = Territories[territoryName]
    local ownerName = territory and territory.gangName or "Unclaimed"
    local color = territory and territory.gangId == PlayerGang.id and 0 or 1

    QBCore.Functions.Notify("Entered: " .. territoryName .. " | Controlled by: " .. ownerName, color == 0 and "success" or "error")

    -- Play sound if enemy territory
    if territory and territory.gangId and territory.gangId ~= PlayerGang.id then
        PlaySoundFrontend(-1, "FocusIn", "HintCamSounds", true)
    end
end)

-- Zone Left
RegisterNetEvent('cold-gangs:client:LeftTerritory', function(territoryName)
    QBCore.Functions.Notify("Left: " .. territoryName, "primary")
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, blip in pairs(GangBlips) do RemoveBlip(blip) end
    for _, blip in pairs(TerritoryBlips) do RemoveBlip(blip) end
    for _, blip in pairs(WarBlips) do RemoveBlip(blip) end
    if captureBlip then RemoveBlip(captureBlip) end

    GangBlips = {}
    TerritoryBlips = {}
    WarBlips = {}
    captureBlip = nil
end)

