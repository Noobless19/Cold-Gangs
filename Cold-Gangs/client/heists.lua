local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayerGang = nil
local ActiveHeists = {}
local HeistBlips = {}
local currentHeist = nil
local currentStage = 0
local heistTimer = 0

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

    -- Sync heists
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveHeists', function(heists)
        ActiveHeists = heists or {}
        CreateHeistBlips()
    end)
end)

-- Sync heists from server
RegisterNetEvent('cold-gangs:client:SyncHeists', function(heists)
    ActiveHeists = heists or {}
    CreateHeistBlips()
end)

-- Create Heist Blips
function CreateHeistBlips()
    -- Clear old blips
    for _, blip in pairs(HeistBlips) do
        RemoveBlip(blip)
    end
    HeistBlips = {}

    if not ActiveHeists then return end

    for id, heist in pairs(ActiveHeists) do
        if heist.gangId == PlayerGang.id and heist.location then
            local coords = json.decode(heist.location)
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, 486)
            SetBlipColour(blip, 1)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(heist.heistType:gsub("_", " "):gsub("^%l", string.upper) .. " Heist")
            EndTextCommandSetBlipName(blip)
            HeistBlips[id] = blip
        end
    end
end

-- Start Heist
RegisterNetEvent('cold-gangs:client:StartHeist', function(heistType)
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    if not exports['cold-gangs']:HasGangPermission('manageHeists') then
        QBCore.Functions.Notify("You don't have permission to start heists", "error")
        return
    end
    
    if not Config.HeistTypes[heistType] then
        QBCore.Functions.Notify("Invalid heist type", "error")
        return
    end
    
    local heistConfig = Config.HeistTypes[heistType]
    
    -- Check gang reputation
    if heistConfig.minReputation > 0 then
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangReputation', function(reputation)
            if reputation < heistConfig.minReputation then
                QBCore.Functions.Notify("Your gang needs at least " .. heistConfig.minReputation .. " reputation to start this heist", "error")
                return
            end
            
            -- Check police count
            if heistConfig.policeRequired > 0 then
                QBCore.Functions.TriggerCallback('cold-gangs:server:GetPoliceCount', function(policeCount)
                    if policeCount < heistConfig.policeRequired then
                        QBCore.Functions.Notify("Not enough police online. Required: " .. heistConfig.policeRequired, "error")
                        return
                    end
                    
                    -- Show location selection
                    ShowHeistLocationSelection(heistType)
                end)
            else
                -- Show location selection
                ShowHeistLocationSelection(heistType)
            end
        end)
    else
        -- Check police count
        if heistConfig.policeRequired > 0 then
            QBCore.Functions.TriggerCallback('cold-gangs:server:GetPoliceCount', function(policeCount)
                if policeCount < heistConfig.policeRequired then
                    QBCore.Functions.Notify("Not enough police online. Required: " .. heistConfig.policeRequired, "error")
                    return
                end
                
                -- Show location selection
                ShowHeistLocationSelection(heistType)
            end)
        else
            -- Show location selection
            ShowHeistLocationSelection(heistType)
        end
    end
end)

-- Show Heist Location Selection
function ShowHeistLocationSelection(heistType)
    local heistConfig = Config.HeistTypes[heistType]
    
    if not heistConfig.locations or #heistConfig.locations == 0 then
        -- No locations to select, use default
        TriggerServerEvent('cold-gangs:server:StartHeist', heistType, 1)
        return
    end
    
    local menu = {
        {
            header = "Select Heist Location",
            isMenuHeader = true
        }
    }
    
    for i, location in ipairs(heistConfig.locations) do
        table.insert(menu, {
            header = location.name,
            txt = "Select this location",
            params = {
                event = "cold-gangs:client:ConfirmHeistLocation",
                args = {
                    heistType = heistType,
                    locationIndex = i
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
end

-- Confirm Heist Location
RegisterNetEvent('cold-gangs:client:ConfirmHeistLocation', function(data)
    TriggerServerEvent('cold-gangs:server:StartHeist', data.heistType, data.locationIndex)
end)

-- Join Heist
RegisterNetEvent('cold-gangs:client:JoinHeist', function(heistId)
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    if not ActiveHeists[heistId] then
        QBCore.Functions.Notify("Heist not found", "error")
        return
    end
    
    if ActiveHeists[heistId].gangId ~= PlayerGang.id then
        QBCore.Functions.Notify("This is not your gang's heist", "error")
        return
    end
    
    TriggerServerEvent('cold-gangs:server:JoinHeist', heistId)
end)

-- Heist Started
RegisterNetEvent('cold-gangs:client:HeistStarted', function(heistId, heistData)
    ActiveHeists[heistId] = heistData
    CreateHeistBlips()
    
    if PlayerGang and heistData.gangId == PlayerGang.id then
        QBCore.Functions.Notify("Heist started: " .. heistData.heistType:gsub("_", " "):gsub("^%l", string.upper), "success", 10000)
        
        -- Play sound
        PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 1)
    end
end)

-- Heist Stage Updated
RegisterNetEvent('cold-gangs:client:HeistStageUpdated', function(heistId, stage)
    if not ActiveHeists[heistId] then return end
    
    ActiveHeists[heistId].currentStage = stage
    
    if currentHeist == heistId then
        currentStage = stage
    end
    if PlayerGang and ActiveHeists[heistId].gangId == PlayerGang.id then
        local heistType = ActiveHeists[heistId].heistType
        local stageName = "Unknown"
        
        if Config.HeistTypes[heistType] and Config.HeistTypes[heistType].stages and Config.HeistTypes[heistType].stages[stage] then
            stageName = Config.HeistTypes[heistType].stages[stage].name
        end
        
        QBCore.Functions.Notify("Heist stage updated: " .. stageName, "primary")
    end
end)

-- Heist Completed
RegisterNetEvent('cold-gangs:client:HeistCompleted', function(heistId, rewards)
    if not ActiveHeists[heistId] then return end
    
    if PlayerGang and ActiveHeists[heistId].gangId == PlayerGang.id then
        QBCore.Functions.Notify("Heist completed! Rewards have been distributed.", "success", 10000)
        
        -- Display rewards
        local rewardText = "Heist Rewards:\n"
        for item, amount in pairs(rewards.items or {}) do
            rewardText = rewardText .. item .. ": " .. amount .. "\n"
        end
        if rewards.money and rewards.money > 0 then
            rewardText = rewardText .. "Money: $" .. rewards.money .. "\n"
        end
        if rewards.reputation and rewards.reputation > 0 then
            rewardText = rewardText .. "Reputation: " .. rewards.reputation
        end
        
        QBCore.Functions.Notify(rewardText, "primary", 15000)
        
        -- Play sound
        PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 1)
        
        -- Reset current heist if needed
        if currentHeist == heistId then
            currentHeist = nil
            currentStage = 0
            heistTimer = 0
        end
    end
    
    -- Remove from active heists
    ActiveHeists[heistId] = nil
    
    -- Remove blip
    if HeistBlips[heistId] then
        RemoveBlip(HeistBlips[heistId])
        HeistBlips[heistId] = nil
    end
end)

-- Heist Failed
RegisterNetEvent('cold-gangs:client:HeistFailed', function(heistId, reason)
    if not ActiveHeists[heistId] then return end
    
    if PlayerGang and ActiveHeists[heistId].gangId == PlayerGang.id then
        QBCore.Functions.Notify("Heist failed: " .. reason, "error", 10000)
        
        -- Play sound
        PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", 1)
        
        -- Reset current heist if needed
        if currentHeist == heistId then
            currentHeist = nil
            currentStage = 0
            heistTimer = 0
        end
    end
    
    -- Remove from active heists
    ActiveHeists[heistId] = nil
    
    -- Remove blip
    if HeistBlips[heistId] then
        RemoveBlip(HeistBlips[heistId])
        HeistBlips[heistId] = nil
    end
end)

-- Start Heist Mission
RegisterNetEvent('cold-gangs:client:StartHeistMission', function(heistId)
    if not ActiveHeists[heistId] then
        QBCore.Functions.Notify("Heist not found", "error")
        return
    end
    
    if PlayerGang and ActiveHeists[heistId].gangId == PlayerGang.id then
        currentHeist = heistId
        currentStage = ActiveHeists[heistId].currentStage
        
        -- Start heist mission
        local heistType = ActiveHeists[heistId].heistType
        local heistConfig = Config.HeistTypes[heistType]
        
        if not heistConfig then
            QBCore.Functions.Notify("Invalid heist configuration", "error")
            return
        end
        
        -- Get current stage
        local stageConfig = heistConfig.stages and heistConfig.stages[currentStage]
        if not stageConfig then
            QBCore.Functions.Notify("Invalid stage configuration", "error")
            return
        end
        
        -- Start stage timer
        heistTimer = stageConfig.duration or 60000
        
        -- Notify
        QBCore.Functions.Notify("Starting heist mission: " .. stageConfig.name, "primary", 10000)
        
        -- Start mission thread
        CreateThread(function()
            while currentHeist and heistTimer > 0 do
                Wait(1000)
                heistTimer = heistTimer - 1000
                
                -- Update every 15 seconds
                if heistTimer % 15000 == 0 then
                    QBCore.Functions.Notify("Time remaining: " .. math.floor(heistTimer / 1000) .. "s", "primary")
                end
            end
            
            if currentHeist and heistTimer <= 0 then
                -- Stage completed
                TriggerServerEvent('cold-gangs:server:CompleteHeistStage', currentHeist)
            end
        end)
    end
end)

-- Cancel Heist
RegisterNetEvent('cold-gangs:client:CancelHeist', function(heistId)
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    if not exports['cold-gangs']:HasGangPermission('manageHeists') then
        QBCore.Functions.Notify("You don't have permission to cancel heists", "error")
        return
    end
    
    if not ActiveHeists[heistId] then
        QBCore.Functions.Notify("Heist not found", "error")
        return
    end
    
    if ActiveHeists[heistId].gangId ~= PlayerGang.id then
        QBCore.Functions.Notify("This is not your gang's heist", "error")
        return
    end
    
    -- Show confirmation dialog
    local dialog = exports['qb-input']:ShowInput({
        header = "Cancel Heist",
        submitText = "Confirm",
        inputs = {
            {
                text = "Are you sure you want to cancel this heist?",
                name = "confirm",
                type = "checkbox",
                isRequired = true
            }
        }
    })
    
    if dialog and dialog.confirm then
        TriggerServerEvent('cold-gangs:server:CancelHeist', heistId)
    end
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    for _, blip in pairs(HeistBlips) do
        RemoveBlip(blip)
    end
    HeistBlips = {}
end)
