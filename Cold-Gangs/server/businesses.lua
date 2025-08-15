local QBCore = exports['qb-core']:GetCoreObject()

-- ======================
-- CREATE BUSINESS
-- ======================

-- Create Business
RegisterNetEvent('cold-gangs:server:CreateBusiness', function(businessType, coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageBusinesses') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to create businesses", "error")
        return
    end

    -- Check if business type is valid
    if not Config.BusinessTypes[businessType] then
        TriggerClientEvent('QBCore:Notify', src, "Invalid business type", "error")
        return
    end

    local businessConfig = Config.BusinessTypes[businessType]

    -- Check business limit
    local businessCount = 0
    for _, business in pairs(Businesses) do
        if business.gangId == gangId then
            businessCount = businessCount + 1
        end
    end

    if businessCount >= (Config.MaxBusinesses or 5) then
        TriggerClientEvent('QBCore:Notify', src, "Your gang has reached the maximum number of businesses", "error")
        return
    end

    -- Check if gang has enough money
    if not exports['cold-gangs']:RemoveGangMoney(gangId, businessConfig.purchaseCost, "Business Purchase: " .. businessType) then
        TriggerClientEvent('QBCore:Notify', src, "Your gang doesn't have enough money ($" .. businessConfig.purchaseCost .. ")", "error")
        return
    end

    -- Create business
    local businessId = MySQL.insert.await('INSERT INTO cold_gang_businesses (gang_id, type, level, income, income_stored, last_payout, location, employees, security, capacity, last_income_update) VALUES (?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?, NOW())', {
        gangId,
        businessType,
        1, -- Initial level
        businessConfig.income,
        0, -- Initial stored income
        json.encode(coords),
        0, -- Initial employees
        1, -- Initial security
        5  -- Initial capacity
    })

    -- Add to memory
    Businesses[businessId] = {
        id = businessId,
        gangId = gangId,
        type = businessType,
        level = 1,
        income = businessConfig.income,
        income_stored = 0,
        last_payout = os.date('%Y-%m-%d %H:%M:%S'),
        location = coords,
        employees = 0,
        security = 1,
        capacity = 5,
        last_income_update = os.date('%Y-%m-%d %H:%M:%S')
    }

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Business created: " .. businessType, "success")
    Core.NotifyGangMembers(gangId, "Business Created", Player.PlayerData.charinfo.firstname .. " created a " .. businessType .. " business")

    -- Add reputation
    exports['cold-gangs']:AddGangReputation(gangId, 50)

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncBusinesses', -1, Businesses)
end)

-- ======================
-- COLLECT INCOME
-- ======================

-- Collect Business Income
RegisterNetEvent('cold-gangs:server:CollectBusinessIncome', function(businessId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    -- Check if business exists and belongs to gang
    if not Businesses[businessId] or Businesses[businessId].gangId ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Business not found or doesn't belong to your gang", "error")
        return
    end

    local business = Businesses[businessId]

    -- Check if there's income to collect
    if business.income_stored <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "No income to collect", "error")
        return
    end

    -- Add money to gang bank
    exports['cold-gangs']:AddGangMoney(gangId, business.income_stored, "Business Income: " .. business.type)

    -- Reset stored income
    MySQL.update('UPDATE cold_gang_businesses SET income_stored = 0, last_payout = NOW() WHERE id = ?', {businessId})
    Businesses[businessId].income_stored = 0
    Businesses[businessId].last_payout = os.date('%Y-%m-%d %H:%M:%S')

    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Collected $" .. business.income_stored .. " from business", "success")
    Core.NotifyGangMembers(gangId, "Income Collected", Player.PlayerData.charinfo.firstname .. " collected $" .. business.income_stored .. " from the " .. business.type)

    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncBusinesses', -1, Businesses)
end)

-- ======================
-- UPGRADE BUSINESS
-- ======================

-- Upgrade Business
RegisterNetEvent('cold-gangs:server:UpgradeBusiness', function(businessId, upgradeType)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageBusinesses') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to upgrade businesses", "error")
        return
    end

    -- Check if business exists and belongs to gang
    if not Businesses[businessId] or Businesses[businessId].gangId ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Business not found or doesn't belong to your gang", "error")
        return
    end

    local business = Businesses[businessId]
    local businessConfig = Config.BusinessTypes[business.type]
    
    if not businessConfig then
        TriggerClientEvent('QBCore:Notify', src, "Invalid business configuration", "error")
        return
    end
    
    -- Calculate upgrade cost and effects
    local upgradeCost = 0
    local upgradeEffect = {}
    
    if upgradeType == "level" then
        -- Main level upgrade
        if business.level >= businessConfig.maxLevel then
            TriggerClientEvent('QBCore:Notify', src, "This business is already at maximum level", "error")
            return
        end
        
        upgradeCost = businessConfig.upgradeCost * business.level
        upgradeEffect = {
            level = business.level + 1,
            income = math.floor(business.income * 1.2) -- 20% income increase
        }
    elseif upgradeType == "security" then
        -- Security upgrade
        if business.security >= 3 then
            TriggerClientEvent('QBCore:Notify', src, "Security is already at maximum level", "error")
            return
        end
        
        upgradeCost = 15000 * business.security
        upgradeEffect = {
            security = business.security + 1
        }
    elseif upgradeType == "capacity" then
        -- Capacity upgrade
        if business.capacity >= 15 then
            TriggerClientEvent('QBCore:Notify', src, "Capacity is already at maximum", "error")
            return
        end
        
        upgradeCost = 10000 * math.floor(business.capacity / 5)
        upgradeEffect = {
            capacity = business.capacity + 5
        }
    else
        TriggerClientEvent('QBCore:Notify', src, "Invalid upgrade type", "error")
        return
    end
    
    -- Check if gang has enough money
    if not exports['cold-gangs']:RemoveGangMoney(gangId, upgradeCost, "Business Upgrade: " .. business.type) then
        TriggerClientEvent('QBCore:Notify', src, "Your gang doesn't have enough money ($" .. upgradeCost .. ")", "error")
        return
    end
    
    -- Apply upgrade
    local updateFields = {}
    local updateValues = {}
    
    for field, value in pairs(upgradeEffect) do
        table.insert(updateFields, field .. " = ?")
        table.insert(updateValues, value)
        Businesses[businessId][field] = value
   end
    
    table.insert(updateValues, businessId)
    
    MySQL.update('UPDATE cold_gang_businesses SET ' .. table.concat(updateFields, ", ") .. ' WHERE id = ?', updateValues)
    
    -- Notify
    local upgradeText = ""
    if upgradeEffect.level then
        upgradeText = "level " .. upgradeEffect.level
    elseif upgradeEffect.security then
        upgradeText = "security level " .. upgradeEffect.security
    elseif upgradeEffect.capacity then
        upgradeText = "capacity " .. upgradeEffect.capacity
    end
    
    TriggerClientEvent('QBCore:Notify', src, "Business upgraded: " .. upgradeText, "success")
    Core.NotifyGangMembers(gangId, "Business Upgraded", Player.PlayerData.charinfo.firstname .. " upgraded the " .. business.type .. " to " .. upgradeText)
    
    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncBusinesses', -1, Businesses)
end)

-- ======================
-- EMPLOYEE MANAGEMENT
-- ======================

-- Hire Business Employee
RegisterNetEvent('cold-gangs:server:HireBusinessEmployee', function(businessId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageBusinesses') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to manage employees", "error")
        return
    end

    -- Check if business exists and belongs to gang
    if not Businesses[businessId] or Businesses[businessId].gangId ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Business not found or doesn't belong to your gang", "error")
        return
    end

    local business = Businesses[businessId]
    
    -- Check if at capacity
    if business.employees >= business.capacity then
        TriggerClientEvent('QBCore:Notify', src, "This business is at maximum employee capacity", "error")
        return
    end
    
    -- Cost to hire employee
    local hireCost = 500
    
    -- Check if gang has enough money
    if not exports['cold-gangs']:RemoveGangMoney(gangId, hireCost, "Hire Employee: " .. business.type) then
        TriggerClientEvent('QBCore:Notify', src, "Your gang doesn't have enough money ($" .. hireCost .. ")", "error")
        return
    end
    
    -- Update business
    local newEmployeeCount = business.employees + 1
    MySQL.update('UPDATE cold_gang_businesses SET employees = ? WHERE id = ?', {newEmployeeCount, businessId})
    Businesses[businessId].employees = newEmployeeCount
    
    -- Calculate new income (each employee adds 10% to base income)
    local baseIncome = Config.BusinessTypes[business.type].income * (1 + (business.level - 1) * 0.2)
    local newIncome = math.floor(baseIncome * (1 + newEmployeeCount * 0.1))
    MySQL.update('UPDATE cold_gang_businesses SET income = ? WHERE id = ?', {newIncome, businessId})
    Businesses[businessId].income = newIncome
    
    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Employee hired. New income: $" .. newIncome .. "/hr", "success")
    
    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncBusinesses', -1, Businesses)
end)

-- Fire Business Employee
RegisterNetEvent('cold-gangs:server:FireBusinessEmployee', function(businessId, employeeId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageBusinesses') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to manage employees", "error")
        return
    end

    -- Check if business exists and belongs to gang
    if not Businesses[businessId] or Businesses[businessId].gangId ~= gangId then
        TriggerClientEvent('QBCore:Notify', src, "Business not found or doesn't belong to your gang", "error")
        return
    end

    local business = Businesses[businessId]
    
    -- Check if has employees
    if business.employees <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "This business has no employees to fire", "error")
        return
    end
    
    -- Update business
    local newEmployeeCount = business.employees - 1
    MySQL.update('UPDATE cold_gang_businesses SET employees = ? WHERE id = ?', {newEmployeeCount, businessId})
    Businesses[businessId].employees = newEmployeeCount
    
    -- Calculate new income (each employee adds 10% to base income)
    local baseIncome = Config.BusinessTypes[business.type].income * (1 + (business.level - 1) * 0.2)
    local newIncome = math.floor(baseIncome * (1 + newEmployeeCount * 0.1))
    MySQL.update('UPDATE cold_gang_businesses SET income = ? WHERE id = ?', {newIncome, businessId})
    Businesses[businessId].income = newIncome
    
    -- Notify
    TriggerClientEvent('QBCore:Notify', src, "Employee fired. New income: $" .. newIncome .. "/hr", "success")
    
    -- Sync to clients
    TriggerClientEvent('cold-gangs:client:SyncBusinesses', -1, Businesses)
end)

-- ======================
-- CALLBACKS
-- ======================

-- Get Gang Businesses
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangBusinesses', function(source, cb, gangId)
    local businesses = {}
    
    for id, business in pairs(Businesses) do
        if business.gangId == gangId then
            businesses[id] = business
        end
    end
    
    cb(businesses)
end)

-- Get Business Details
QBCore.Functions.CreateCallback('cold-gangs:server:GetBusinessDetails', function(source, cb, businessId)
    cb(Businesses[businessId])
end)

-- Get Business Upgrade Options
QBCore.Functions.CreateCallback('cold-gangs:server:GetBusinessUpgradeOptions', function(source, cb, businessId)
    local business = Businesses[businessId]
    if not business then
        cb(nil)
        return
    end
    
    local businessConfig = Config.BusinessTypes[business.type]
    if not businessConfig then
        cb(nil)
        return
    end
    
    local options = {}
    
    -- Main level upgrade
    if business.level < businessConfig.maxLevel then
        options.mainLevel = {
            current = business.level,
            max = businessConfig.maxLevel,
            cost = businessConfig.upgradeCost * business.level,
            effects = "Income +20%"
        }
    end
    
    -- Security upgrade
    if business.security < 3 then
        options.security = {
            current = business.security,
            max = 3,
            cost = 15000 * business.security,
            effects = "Reduces raid chance"
        }
    end
    
    -- Capacity upgrade
    if business.capacity < 15 then
        options.capacity = {
            current = business.capacity,
            max = 15,
            cost = 10000 * math.floor(business.capacity / 5),
            effects = "Employee capacity +5"
        }
    end
    
    cb(options)
end)

-- Get Business Employees
QBCore.Functions.CreateCallback('cold-gangs:server:GetBusinessEmployees', function(source, cb, businessId)
    local business = Businesses[businessId]
    if not business then
        cb({}, 0)
        return
    end
    
    -- Generate random employees for display purposes
    local employees = {}
    local firstNames = {"John", "Jane", "Mike", "Sarah", "David", "Lisa", "Robert", "Emily", "James", "Jessica"}
    local lastNames = {"Smith", "Johnson", "Williams", "Jones", "Brown", "Davis", "Miller", "Wilson", "Moore", "Taylor"}
    
    for i = 1, business.employees do
        local firstName = firstNames[math.random(1, #firstNames)]
        local lastName = lastNames[math.random(1, #lastNames)]
        local efficiency = math.random(70, 95)
        local salary = math.random(300, 500)
        
        table.insert(employees, {
            id = i,
            name = firstName .. " " .. lastName,
            efficiency = efficiency,
            salary = salary
        })
    end
    
    cb(employees, business.capacity)
end)

-- ======================
-- PERIODIC UPDATES
-- ======================

-- Generate business income
CreateThread(function()
    while true do
        Wait(3600000) -- Every hour
        
        for id, business in pairs(Businesses) do
            -- Calculate income based on level, employees, and random factors
            local baseIncome = business.income
            local randomFactor = math.random(90, 110) / 100 -- 0.9 to 1.1
            local securityFactor = 1 - (0.1 * (3 - business.security)) -- Security reduces chance of loss
            
            local finalIncome = math.floor(baseIncome * randomFactor * securityFactor)
            
            -- Add income to stored amount
            local newStoredIncome = business.income_stored + finalIncome
            MySQL.update('UPDATE cold_gang_businesses SET income_stored = ?, last_income_update = NOW() WHERE id = ?', {newStoredIncome, id})
            Businesses[id].income_stored = newStoredIncome
            Businesses[id].last_income_update = os.date('%Y-%m-%d %H:%M:%S')
            
            -- Notify gang if significant income
            if finalIncome >= 1000 then
                Core.NotifyGangMembers(business.gangId, "Business Income", "Your " .. business.type .. " generated $" .. finalIncome)
            end
        end
        
        -- Sync to clients
        TriggerClientEvent('cold-gangs:client:SyncBusinesses', -1, Businesses)
    end
end)

-- Sync businesses to clients
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        TriggerClientEvent('cold-gangs:client:SyncBusinesses', -1, Businesses)
    end
end)

-- ======================
-- EXPORTS
-- ======================

-- Get Business
function GetBusiness(businessId)
    return Businesses[businessId]
end

-- Get Businesses by Gang ID
function GetBusinessesByGangId(gangId)
    local businesses = {}
    
    for id, business in pairs(Businesses) do
        if business.gangId == gangId then
            businesses[id] = business
        end
    end
    
    return businesses
end

-- Register exports
exports('GetBusiness', GetBusiness)
exports('GetBusinessesByGangId', GetBusinessesByGangId)

