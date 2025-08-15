local QBCore = exports['qb-core']:GetCoreObject()

-- ======================
-- DRUG FIELDS
-- ======================

-- Create Drug Field
RegisterNetEvent('cold-gangs:server:CreateDrugField', function(resourceType, territoryName, coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageDrugs') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to create drug fields", "error")
        return
    end

    -- Check if territory is controlled by gang
    if not exports['cold-gangs']:IsTerritoryControlledByGang(territoryName, gangId) then
        TriggerClientEvent('QBCore:Notify', src, "Your gang doesn't control this territory", "error")
        return
    end

    -- Check field limit
    local fieldCount = 0
    for _, field in pairs(DrugFields) do
        if field.owner == gangId then
            fieldCount = fieldCount + 1
        end
    end

    if fieldCount >= (Config.MaxDrugFields or 5) then
        TriggerClientEvent('QBCore:Notify', src, "Your gang has reached the maximum number of drug fields", "error")
        return
    end

    -- Check if resource type is valid
    if not Config.DrugFields[resourceType .. "_field"] then
        TriggerClientEvent('QBCore:Notify', src, "Invalid resource type", "error")
        return
    end

    local fieldConfig = Config.DrugFields[resourceType .. "_field"]

    -- Create field
    local fieldId = MySQL.insert.await('INSERT INTO cold_drug_fields (territory_name, resource_type, growth_stage, max_yield, quality_range_min, quality_range_max, owner, gang_name, location, last_updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())', {
        territoryName,
        resourceType,
        0, -- Initial growth stage
        fieldConfig.yield.max,
        fieldConfig.qualityRange.min,
        fieldConfig.qualityRange.max,
        gangId,
        Gangs[gangId].name,
        json.encode(coords)
    })

    -- Add to memory
    DrugFields[fieldId] = {
        id = fieldId,
        territoryName = territoryName,
        resourceType = resourceType,
        growthStage = 0,
        maxYield = fieldConfig.yield.max,
        qualityRangeMin = fieldConfig.qualityRange.min,
        qualityRangeMax = fieldConfig.qualityRange.max,
        owner = gangId,
        gangName = Gangs[gangId].name,
        location = coords,
        lastUpdated = os.date('%Y-%m-%d %H:%M:%S')
    }

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Drug field created: " .. resourceType, "success")
    Core.NotifyGangMembers(gangId, "Drug Field Created", Player.PlayerData.charinfo.firstname .. " created a " .. resourceType .. " field")

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncDrugFields', -1, DrugFields)
end)

-- Harvest Drug Field
RegisterNetEvent('cold-gangs:server:HarvestDrugField', function(fieldId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    -- Check if field exists and belongs to gang
    if not DrugFields[fieldId] or DrugFields[fieldId].owner ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Field not found or doesn't belong to your gang", "error")
        return
    end

    -- Check if field is ready for harvest
    if DrugFields[fieldId].growthStage < 10 then
        TriggerClientEvent('QBCore:Notify', src, "Plants are not ready for harvest yet", "error")
        return
    end

    local field = DrugFields[fieldId]
    local resourceType = field.resourceType
    local yield = math.random(Config.DrugFields[resourceType .. "_field"].yield.min, field.maxYield)
    local quality = math.random(field.qualityRangeMin, field.qualityRangeMax)

    -- Give items to player
    local itemName = resourceType .. "_leaf"
    Player.Functions.AddItem(itemName, yield, nil, {quality = quality})
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "add", yield)

    -- Reset field growth
    MySQL.update('UPDATE cold_drug_fields SET growth_stage = ?, last_updated = NOW() WHERE id = ?', {0, fieldId})
    DrugFields[fieldId].growthStage = 0
    DrugFields[fieldId].lastUpdated = os.date('%Y-%m-%d %H:%M:%S')

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Harvested " .. yield .. " " .. resourceType .. " leaves (Quality: " .. quality .. "%)", "success")

    -- Add reputation
    exports['cold-gangs']:AddGangReputation(gangId, math.floor(yield * quality / 100))

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncDrugFields', -1, DrugFields)
end)

-- ======================
-- DRUG LABS
-- ======================

-- Create Drug Lab
RegisterNetEvent('cold-gangs:server:CreateDrugLab', function(drugType, territoryName, coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageDrugs') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to create drug labs", "error")
        return
    end

    -- Check if territory is controlled by gang
    if not exports['cold-gangs']:IsTerritoryControlledByGang(territoryName, gangId) then
        TriggerClientEvent('QBCore:Notify', src, "Your gang doesn't control this territory", "error")
        return
    end

    -- Check lab limit
    local labCount = 0
    for _, lab in pairs(DrugLabs) do
        if lab.owner == gangId then
            labCount = labCount + 1
        end
    end

    if labCount >= (Config.MaxDrugLabs or 3) then
        TriggerClientEvent('QBCore:Notify', src, "Your gang has reached the maximum number of drug labs", "error")
        return
    end

    -- Check if drug type is valid
    if not Config.DrugLabs.processingTimes[drugType] then
        TriggerClientEvent('QBCore:Notify', src, "Invalid drug type", "error")
        return
    end

    -- Check if gang has enough money
    local labCost = 50000
    if not exports['cold-gangs']:RemoveGangMoney(gangId, labCost, "Drug Lab Creation") then
        TriggerClientEvent('QBCore:Notify', src, "Your gang doesn't have enough money ($" .. labCost .. ")", "error")
        return
    end

    -- Create lab
    local labId = MySQL.insert.await('INSERT INTO cold_drug_labs (territory_name, drug_type, level, capacity, owner, gang_name, location, security, last_updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())', {
        territoryName,
        drugType,
        1, -- Initial level
        100, -- Initial capacity
        gangId,
        Gangs[gangId].name,
        json.encode(coords),
        50 -- Initial security
    })

    -- Add to memory
    DrugLabs[labId] = {
        id = labId,
        territoryName = territoryName,
        drugType = drugType,
        level = 1,
        capacity = 100,
        owner = gangId,
        gangName = Gangs[gangId].name,
        location = coords,
        security = 50,
        lastUpdated = os.date('%Y-%m-%d %H:%M:%S')
    }

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Drug lab created: " .. drugType, "success")
    Core.NotifyGangMembers(gangId, "Drug Lab Created", Player.PlayerData.charinfo.firstname .. " created a " .. drugType .. " lab")

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncDrugLabs', -1, DrugLabs)
end)

-- Check Processing Requirements
QBCore.Functions.CreateCallback('cold-gangs:server:CheckProcessingRequirements', function(source, cb, drugType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        cb(false, {})
        return
    end

    local requiredItems = {
        weed = {
            weed_leaf = 5
        },
        coke = {
            coke_leaf = 5,
            chemicals = 2
        },
        meth = {
            chemicals = 3,
            acetone = 1
        }
    }

    local required = requiredItems[drugType] or {}
    local hasAllItems = true

    for item, amount in pairs(required) do
        if not Player.Functions.GetItemByName(item) or Player.Functions.GetItemByName(item).amount < amount then
            hasAllItems = false
            break
        end
    end

    cb(hasAllItems, required)
end)

-- Complete Drug Processing
RegisterNetEvent('cold-gangs:server:CompleteDrugProcessing', function(labId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    -- Check if lab exists and belongs to gang
    if not DrugLabs[labId] or DrugLabs[labId].owner ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Lab not found or doesn't belong to your gang", "error")
        return
    end

    local lab = DrugLabs[labId]
    local drugType = lab.drugType

    -- Check required items
    local requiredItems = {
        weed = {
            weed_leaf = 5
        },
        coke = {
            coke_leaf = 5,
            chemicals = 2
        },
        meth = {
            chemicals = 3,
            acetone = 1
        }
    }

    local required = requiredItems[drugType] or {}
    local hasAllItems = true

    for item, amount in pairs(required) do
        if not Player.Functions.GetItemByName(item) or Player.Functions.GetItemByName(item).amount < amount then
            hasAllItems = false
            break
        end
    end

    if not hasAllItems then
        TriggerClientEvent('QBCore:Notify', src, "You don't have the required items", "error")
        return
    end

    -- Remove required items
    for item, amount in pairs(required) do
        Player.Functions.RemoveItem(item, amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "remove", amount)
    end

    -- Calculate output
    local baseAmount = 3
    local labBonus = (lab.level - 1) * 0.5
    local outputAmount = math.floor(baseAmount * (1 + labBonus))
    
    -- Calculate quality
    local baseQuality = 70
    local labQualityBonus = (lab.level - 1) * 5
    local quality = math.min(98, baseQuality + labQualityBonus)
    
    -- Add success rate check
    local successRate = Config.DrugLabs.successRates[drugType] or 0.9
    local success = math.random() <= successRate
    
    if success then
        -- Give processed drugs
        local outputItem = drugType .. "_processed"
        Player.Functions.AddItem(outputItem, outputAmount, nil, {quality = quality})
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[outputItem], "add", outputAmount)
        
        -- Notify
        TriggerClientEvent('QBCore:Notify', src, "Successfully processed " .. outputAmount .. " " .. drugType .. " (Quality: " .. quality .. "%)", "success")
        
        -- Add reputation
        exports['cold-gangs']:AddGangReputation(gangId, math.floor(outputAmount * quality / 20))
    else
        -- Processing failed
        TriggerClientEvent('QBCore:Notify', src, "Processing failed! The batch was ruined.", "error")
    end
end)

-- Upgrade Drug Lab
RegisterNetEvent('cold-gangs:server:UpgradeDrugLab', function(labId, upgradeType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageDrugs') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to upgrade drug labs", "error")
        return
    end

    -- Check if lab exists and belongs to gang
    if not DrugLabs[labId] or DrugLabs[labId].owner ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Lab not found or doesn't belong to your gang", "error")
        return
    end

    local lab = DrugLabs[labId]
    
    -- Calculate upgrade cost based on current level
    local baseCost = 25000
    local levelMultiplier = lab.level
    local upgradeCost = baseCost * levelMultiplier
    
    -- Check if gang has enough money
    if not exports['cold-gangs']:RemoveGangMoney(gangId, upgradeCost, "Drug Lab Upgrade") then
        TriggerClientEvent('QBCore:Notify', src, "Your gang doesn't have enough money ($" .. upgradeCost .. ")", "error")
        return
    end
    
    -- Apply upgrade
    if upgradeType == "capacity" then
        local newCapacity = lab.capacity + 50
        MySQL.update('UPDATE cold_drug_labs SET capacity = ? WHERE id = ?', {newCapacity, labId})
        DrugLabs[labId].capacity = newCapacity
        TriggerClientEvent('QBCore:Notify', src, "Lab capacity upgraded to " .. newCapacity, "success")
    elseif upgradeType == "security" then
        local newSecurity = math.min(100, lab.security + 10)
        MySQL.update('UPDATE cold_drug_labs SET security = ? WHERE id = ?', {newSecurity, labId})
        DrugLabs[labId].security = newSecurity
        TriggerClientEvent('QBCore:Notify', src, "Lab security upgraded to " .. newSecurity, "success")
    elseif upgradeType == "level" then
        if lab.level >= 5 then
            exports['cold-gangs']:AddGangMoney(gangId, upgradeCost, "Refund - Lab already max level")
            TriggerClientEvent('QBCore:Notify', src, "This lab is already at maximum level", "error")
            return
        end
        
        local newLevel = lab.level + 1
        MySQL.update('UPDATE cold_drug_labs SET level = ? WHERE id = ?', {newLevel, labId})
        DrugLabs[labId].level = newLevel
        TriggerClientEvent('QBCore:Notify', src, "Lab upgraded to level " .. newLevel, "success")
    else
        exports['cold-gangs']:AddGangMoney(gangId, upgradeCost, "Refund - Invalid upgrade type")
        TriggerClientEvent('QBCore:Notify', src, "Invalid upgrade type", "error")
        return
    end
    
    -- Notify gang
    Core.NotifyGangMembers(gangId, "Lab Upgraded", Player.PlayerData.charinfo.firstname .. " upgraded the " .. lab.drugType .. " lab")
    
    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncDrugLabs', -1, DrugLabs)
end)

-- ======================
-- CALLBACKS
-- ======================

-- Get Drug Fields
QBCore.Functions.CreateCallback('cold-gangs:server:GetDrugFields', function(source, cb)
    cb(DrugFields)
end)

-- Get Drug Labs
QBCore.Functions.CreateCallback('cold-gangs:server:GetDrugLabs', function(source, cb)
    cb(DrugLabs)
end)

-- ======================
-- PERIODIC UPDATES
-- ======================

-- Update drug field growth
CreateThread(function()
    while true do
        Wait(1800000) -- Every 30 minutes
        
        for id, field in pairs(DrugFields) do
            if field.growthStage < 10 then
                -- Increase growth stage
                field.growthStage = field.growthStage + 1
                
                -- Update database
                MySQL.update('UPDATE cold_drug_fields SET growth_stage = ?, last_updated = NOW() WHERE id = ?', {
                    field.growthStage,
                    id
                })
            end
        end
        
        -- Sync to clients
        TriggerClientEvent('cold-gangs:client:SyncDrugFields', -1, DrugFields)
    end
end)

-- Sync drugs to clients
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        TriggerClientEvent('cold-gangs:client:SyncDrugFields', -1, DrugFields)
        TriggerClientEvent('cold-gangs:client:SyncDrugLabs', -1, DrugLabs)
    end
end)

-- ======================
-- EXPORTS
-- ======================

-- Get Drug Field
function GetDrugField(fieldId)
    return DrugFields[fieldId]
end

-- Get Drug Lab
function GetDrugLab(labId)
    return DrugLabs[labId]
end

-- Get Drug Fields by Gang ID
function GetDrugFieldsByGangId(gangId)
    local fields = {}
    
    for id, field in pairs(DrugFields) do
        if field.owner == gangId then
            fields[id] = field
        end
    end
    
    return fields
end

-- Get Drug Labs by Gang ID
function GetDrugLabsByGangId(gangId)
    local labs = {}
    
    for id, lab in pairs(DrugLabs) do
        if lab.owner == gangId then
            labs[id] = lab
        end
    end
    
    return labs
end

-- Register exports
exports('GetDrugField', GetDrugField)
exports('GetDrugLab', GetDrugLab)
exports('GetDrugFieldsByGangId', GetDrugFieldsByGangId)
exports('GetDrugLabsByGangId', GetDrugLabsByGangId)

