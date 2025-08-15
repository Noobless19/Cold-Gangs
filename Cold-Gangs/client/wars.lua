local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayerGang = nil
local ActiveWars = {}
local WarBlips = {}
local isInWarZone = false
local currentWarId = nil
local killCooldown = false

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

    -- Sync active wars
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveWars', function(wars)
        ActiveWars = wars or {}
        CreateWarBlips()
    end)
end)

-- Sync wars from server
RegisterNetEvent('cold-gangs:client:SyncWars', function(wars)
    ActiveWars = wars or {}
    CreateWarBlips()
end)

-- Create War Blips
function CreateWarBlips()
    -- Clear old blips
    for _, blip in pairs(WarBlips) do
        RemoveBlip(blip)
    end
    WarBlips = {}

    if not ActiveWars or not Config or not Config.Territories or not Config.Territories.List then
        return
    end

    for warId, war in pairs(ActiveWars) do
        if war.territoryName and Config.Territories.List[war.territoryName] then
            local coords = Config.Territories.List[war.territoryName].coords
            if coords then
                local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                SetBlipSprite(blip, 310)
                SetBlipColour(blip, 1)
                SetBlipScale(blip, 1.0)
                SetBlipFlashes(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("WAR: " .. war.attackerName .. " vs " .. war.defenderName)
                EndTextCommandSetBlipName(blip)
                WarBlips[warId] = blip
            end
        end
    end
end

-- Declare War
RegisterNetEvent('cold-gangs:client:DeclareWar', function(targetGangId)
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    if not exports['cold-gangs']:HasGangPermission('declareWar') then
        QBCore.Functions.Notify("You don't have permission to declare war", "error")
        return
    end
    
    -- Show territory selection menu
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
        local menu = {
            {
                header = "Select Territory to Contest",
                isMenuHeader = true
            }
        }
        
        local targetGangTerritories = {}
        for name, territory in pairs(territories) do
            if territory.gangId == targetGangId then
                table.insert(targetGangTerritories, {
                    name = name,
                    territory = territory
                })
            end
        end
        
        if #targetGangTerritories == 0 then
            QBCore.Functions.Notify("This gang doesn't control any territories", "error")
            return
        end
        
        for _, t in ipairs(targetGangTerritories) do
            table.insert(menu, {
                header = t.name,
                txt = "Controlled by: " .. t.territory.gangName,
                params = {
                    event = "cold-gangs:client:ConfirmWarDeclaration",
                    args = {
                        targetGangId = targetGangId,
                        territoryName = t.name
                    }
                }
            })
        end
        
        table.insert(menu, {
            header = "← Cancel",
            txt = "",
            params = {
                event = "qb-menu:client:closeMenu"
            }
        })
        
        exports['qb-menu']:openMenu(menu)
    end)
end)

-- Confirm War Declaration
RegisterNetEvent('cold-gangs:client:ConfirmWarDeclaration', function(data)
    local targetGangId = data.targetGangId
    local territoryName = data.territoryName
    
    -- Show confirmation dialog
    local dialog = exports['qb-input']:ShowInput({
        header = "Declare War",
        submitText = "Confirm",
        inputs = {
            {
                text = "War declaration will cost $" .. Config.Wars.declarationCost,
                name = "confirm",
                type = "checkbox",
                isRequired = true
            }
        }
    })
    
    if dialog and dialog.confirm then
        TriggerServerEvent('cold-gangs:server:DeclareWar', targetGangId, territoryName)
    end
end)

-- War Started
RegisterNetEvent('cold-gangs:client:WarStarted', function(warId, warData)
    ActiveWars[warId] = warData
    CreateWarBlips()
    
    if PlayerGang and (warData.attackerId == PlayerGang.id or warData.defenderId == PlayerGang.id) then
        QBCore.Functions.Notify("War has begun against " .. (warData.attackerId == PlayerGang.id and warData.defenderName or warData.attackerName), "error", 10000)
        
        -- Play sound
        PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
        Wait(100)
        PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
        Wait(100)
        PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
    end
end)

-- War Ended
RegisterNetEvent('cold-gangs:client:WarEnded', function(warId, winnerId, winnerName)
    if not ActiveWars[warId] then return end
    
    local warData = ActiveWars[warId]
    ActiveWars[warId] = nil
    
    if WarBlips[warId] then
        RemoveBlip(WarBlips[warId])
        WarBlips[warId] = nil
    end
    
    if PlayerGang and (warData.attackerId == PlayerGang.id or warData.defenderId == PlayerGang.id) then
        local isWinner = PlayerGang.id == winnerId
        local message = isWinner and "Your gang has won the war against " .. (warData.attackerId == PlayerGang.id and warData.defenderName or warData.attackerName) or
                                    "Your gang has lost the war against " .. winnerName
        
        QBCore.Functions.Notify(message, isWinner and "success" or "error", 10000)
        
        -- Play sound
        if isWinner then
            PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 1)
        else
            PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", 1)
        end
    end
end)

-- War Score Updated
RegisterNetEvent('cold-gangs:client:WarScoreUpdated', function(warId, attackerScore, defenderScore)
    if not ActiveWars[warId] then return end
    
    ActiveWars[warId].attackerScore = attackerScore
    ActiveWars[warId].defenderScore = defenderScore
    
    if PlayerGang and (ActiveWars[warId].attackerId == PlayerGang.id or ActiveWars[warId].defenderId == PlayerGang.id) then
        local ourScore = ActiveWars[warId].attackerId == PlayerGang.id and attackerScore or defenderScore
        local theirScore = ActiveWars[warId].attackerId == PlayerGang.id and defenderScore or attackerScore
        
        QBCore.Functions.Notify("War Score Updated: " .. ourScore .. " - " .. theirScore, "primary")
    end
end)

-- Monitor player position for war zones
CreateThread(function()
    while true do
        Wait(1000)
        
        if isLoggedIn and PlayerGang and ActiveWars and Config and Config.Territories and Config.Territories.List then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local inWarZone = false
            local warId = nil
            
            for id, war in pairs(ActiveWars) do
                if war.territoryName and Config.Territories.List[war.territoryName] then
                    local territoryCoords = Config.Territories.List[war.territoryName].coords
                    local territoryRadius = Config.Territories.List[war.territoryName].radius
                    
                    if territoryCoords and territoryRadius then
                        local distance = #(playerCoords - territoryCoords)
                        
                        if distance <= territoryRadius and (war.attackerId == PlayerGang.id or war.defenderId == PlayerGang.id) then
                            inWarZone = true
                            warId = id
                            break
                        end
                    end
                end
            end
            
            -- Handle war zone entry/exit
            if inWarZone ~= isInWarZone then
                isInWarZone = inWarZone
                currentWarId = warId
                
                if isInWarZone then
                    TriggerEvent('cold-gangs:client:EnteredWarZone', currentWarId)
                else
                    TriggerEvent('cold-gangs:client:LeftWarZone')
                end
            end
        else
            Wait(3000)
        end
    end
end)

-- Entered War Zone
RegisterNetEvent('cold-gangs:client:EnteredWarZone', function(warId)
    if not ActiveWars[warId] then return end
    
    local warData = ActiveWars[warId]
    local enemyName = warData.attackerId == PlayerGang.id and warData.defenderName or warData.attackerName
    
    QBCore.Functions.Notify("You entered a war zone against " .. enemyName, "error", 10000)
    
    -- Play sound
    PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
end)

-- Left War Zone
RegisterNetEvent('cold-gangs:client:LeftWarZone', function()
    QBCore.Functions.Notify("You left the war zone", "primary")
end)

-- Handle player death in war zone
RegisterNetEvent('hospital:client:Revive', function()
    if isInWarZone and currentWarId and ActiveWars[currentWarId] and not killCooldown then
        killCooldown = true
        
        -- Report death to server
        TriggerServerEvent('cold-gangs:server:ReportWarDeath', currentWarId)
        
        -- Reset cooldown after 60 seconds
        SetTimeout(60000, function()
            killCooldown = false
        end)
    end
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    for _, blip in pairs(WarBlips) do
        RemoveBlip(blip)
    end
    WarBlips = {}
end)
