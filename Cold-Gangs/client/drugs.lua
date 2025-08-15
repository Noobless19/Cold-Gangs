local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayerGang = nil
local DrugFields = {}
local DrugLabs = {}
local isProcessing = false
local processingTimer = 0
local currentLab = nil

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

    -- Sync drug fields and labs
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetDrugFields', function(fields)
        DrugFields = fields or {}
    end)

    QBCore.Functions.TriggerCallback('cold-gangs:server:GetDrugLabs', function(labs)
        DrugLabs = labs or {}
    end)
end)

-- Sync drug fields from server
RegisterNetEvent('cold-gangs:client:SyncDrugFields', function(fields)
    DrugFields = fields or {}
end)

-- Sync drug labs from server
RegisterNetEvent('cold-gangs:client:SyncDrugLabs', function(labs)
    DrugLabs = labs or {}
end)

-- Harvest drug field
RegisterNetEvent('cold-gangs:client:HarvestDrugField', function(data)
    local fieldId = data.fieldId
    
    -- Find field in local data
    local field = nil
    for _, f in pairs(DrugFields) do
        if f.id == fieldId then
            field = f
            break
        end
    end
    
    if not field then
        QBCore.Functions.Notify("Field not found", "error")
        return
    end
    
    if field.growthStage < 10 then
        QBCore.Functions.Notify("Plants are not ready for harvest yet", "error")
        return
    end
    
    -- Start harvesting animation
    TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_GARDENER_PLANT", 0, true)
    QBCore.Functions.Progressbar("harvesting_drugs", "Harvesting " .. field.resourceType, 10000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function() -- Done
        ClearPedTasks(PlayerPedId())
        TriggerServerEvent('cold-gangs:server:HarvestDrugField', fieldId)
    end, function() -- Cancel
        ClearPedTasks(PlayerPedId())
        QBCore.Functions.Notify("Cancelled", "error")
    end)
end)

-- Start drug processing
RegisterNetEvent('cold-gangs:client:StartDrugProcessing', function(data)
    local labId = data.labId
    
    -- Find lab in local data
    local lab = nil
    for _, l in pairs(DrugLabs) do
        if l.id == labId then
            lab = l
            break
        end
    end
    
    if not lab then
        QBCore.Functions.Notify("Lab not found", "error")
        return
    end
    
    -- Check if already processing
    if isProcessing then
        QBCore.Functions.Notify("Already processing drugs", "error")
        return
    end
    
    -- Check if player has required items
    QBCore.Functions.TriggerCallback('cold-gangs:server:CheckProcessingRequirements', function(hasItems, requiredItems)
        if not hasItems then
            local itemsText = ""
            for item, amount in pairs(requiredItems) do
                itemsText = itemsText .. item .. " x" .. amount .. ", "
            end
            itemsText = itemsText:sub(1, -3) -- Remove last comma and space
            QBCore.Functions.Notify("Missing items: " .. itemsText, "error")
            return
        end
        
        -- Start processing
        isProcessing = true
        currentLab = lab
        
        -- Get processing time from config
        local processingTime = Config.DrugLabs.processingTimes[lab.drugType] or 60000
        
        -- Start processing animation
        TaskStartScenarioInPlace(PlayerPedId(), "PROP_HUMAN_BUM_BIN", 0, true)
        QBCore.Functions.Progressbar("processing_drugs", "Processing " .. lab.drugType, processingTime, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function() -- Done
            ClearPedTasks(PlayerPedId())
            TriggerServerEvent('cold-gangs:server:CompleteDrugProcessing', labId)
            isProcessing = false
            currentLab = nil
        end, function() -- Cancel
            ClearPedTasks(PlayerPedId())
            QBCore.Functions.Notify("Cancelled", "error")
            isProcessing = false
            currentLab = nil
        end)
    end, lab.drugType)
end)

-- Upgrade drug lab
RegisterNetEvent('cold-gangs:client:UpgradeDrugLab', function(data)
    local labId = data.labId
    
    -- Find lab in local data
    local lab = nil
    for _, l in pairs(DrugLabs) do
        if l.id == labId then
            lab = l
            break
        end
    end
    
    if not lab then
        QBCore.Functions.Notify("Lab not found", "error")
        return
    end
    
    -- Show upgrade options
    local menu = {
        {
            header = "Upgrade " .. lab.drugType .. " Lab",
            isMenuHeader = true
        },
        {
            header = "Upgrade Capacity",
            txt = "Current: " .. lab.capacity .. " | Cost: $" .. (10000 * lab.level),
            params = {
                event = "cold-gangs:client:ConfirmLabUpgrade",
                args = {
                    labId = labId,
                    upgradeType = "capacity"
                }
            }
        },
        {
            header = "Upgrade Security",
            txt = "Current: " .. lab.security .. " | Cost: $" .. (15000 * lab.level),
            params = {
                event = "cold-gangs:client:ConfirmLabUpgrade",
                args = {
                    labId = labId,
                    upgradeType = "security"
                }
            }
        },
        {
            header = "Upgrade Quality",
            txt = "Improves product quality | Cost: $" .. (20000 * lab.level),
            params = {
                event = "cold-gangs:client:ConfirmLabUpgrade",
                args = {
                    labId = labId,
                    upgradeType = "quality"
                }
            }
        },
        {
            header = "← Close",
            txt = "",
            params = {
                event = "qb-menu:client:closeMenu"
            }
        }
    }
    
    exports['qb-menu']:openMenu(menu)
end)

-- Confirm lab upgrade
RegisterNetEvent('cold-gangs:client:ConfirmLabUpgrade', function(data)
    TriggerServerEvent('cold-gangs:server:UpgradeDrugLab', data.labId, data.upgradeType)
end)

-- Create drug field
RegisterNetEvent('cold-gangs:client:CreateDrugField', function(data)
    local resourceType = data.resourceType
    local territoryName = data.territoryName
    
    if not resourceType or not territoryName then
        QBCore.Functions.Notify("Invalid data", "error")
        return
    end
    
    -- Check if player is in a gang
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    -- Check if player has permission
    if not exports['cold-gangs']:HasGangPermission('manageDrugs') then
        QBCore.Functions.Notify("You don't have permission to create drug fields", "error")
        return
    end
    
    -- Get player position
    local coords = GetEntityCoords(PlayerPedId())
    
    -- Create field
    TriggerServerEvent('cold-gangs:server:CreateDrugField', resourceType, territoryName, coords)
end)

-- Create drug lab
RegisterNetEvent('cold-gangs:client:CreateDrugLab', function(data)
    local drugType = data.drugType
    local territoryName = data.territoryName
    
    if not drugType or not territoryName then
        QBCore.Functions.Notify("Invalid data", "error")
        return
    end
    
    -- Check if player is in a gang
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    -- Check if player has permission
    if not exports['cold-gangs']:HasGangPermission('manageDrugs') then
        QBCore.Functions.Notify("You don't have permission to create drug labs", "error")
        return
    end
    
    -- Get player position
    local coords = GetEntityCoords(PlayerPedId())
    
    -- Create lab
    TriggerServerEvent('cold-gangs:server:CreateDrugLab', drugType, territoryName, coords)
end)

-- Draw 3D text for drug fields and labs
CreateThread(function()
    while true do
        Wait(0)
        
        if isLoggedIn and PlayerGang then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local sleep = true
            
            -- Draw drug fields
            for _, field in pairs(DrugFields) do
                if field.owner == PlayerGang.id and field.location then
                    local fieldCoords = json.decode(field.location)
                    local distance = #(playerCoords - vector3(fieldCoords.x, fieldCoords.y, fieldCoords.z))
                    
                    if distance < 10.0 then
                        sleep = false
                        local text = field.resourceType .. " Field\nGrowth: " .. field.growthStage .. "/10"
                        if field.growthStage >= 10 then
                            text = text .. "\nReady for harvest"
                        end
                        Draw3DText(fieldCoords.x, fieldCoords.y, fieldCoords.z + 1.0, text)
                    end
                end
            end
            
            -- Draw drug labs
            for _, lab in pairs(DrugLabs) do
                if lab.owner == PlayerGang.id and lab.location then
                    local labCoords = json.decode(lab.location)
                    local distance = #(playerCoords - vector3(labCoords.x, labCoords.y, labCoords.z))
                    
                    if distance < 10.0 then
                        sleep = false
                        local text = lab.drugType .. " Lab\nLevel: " .. lab.level .. "\nCapacity: " .. lab.capacity
                        Draw3DText(labCoords.x, labCoords.y, labCoords.z + 1.0, text)
                    end
                end
            end
            
            if sleep then
                Wait(1000)
            end
        else
            Wait(1000)
        end
    end
end)

-- Resource stop cleanup
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    if isProcessing then
        ClearPedTasks(PlayerPedId())
    end
end)
