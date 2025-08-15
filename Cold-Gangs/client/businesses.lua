local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayerGang = nil
local Businesses = {}
local BusinessBlips = {}

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

    -- Sync businesses
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangBusinesses', function(businesses)
        Businesses = businesses or {}
        CreateBusinessBlips()
    end)
end)

-- Sync businesses from server
RegisterNetEvent('cold-gangs:client:SyncBusinesses', function(businesses)
    Businesses = businesses or {}
    CreateBusinessBlips()
end)

-- Create Business Blips
function CreateBusinessBlips()
    -- Clear old blips
    for _, blip in pairs(BusinessBlips) do
        RemoveBlip(blip)
    end
    BusinessBlips = {}

    if not Businesses then return end

    for id, business in pairs(Businesses) do
        if business.location then
            local coords = json.decode(business.location)
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            
            -- Set blip sprite based on business type
            local sprite = 375 -- Default
            if business.type == "dispensary" then
                sprite = 140
            elseif business.type == "bar" then
                sprite = 93
            elseif business.type == "garage" then
                sprite = 357
            elseif business.type == "club" then
                sprite = 121
            end
            
            SetBlipSprite(blip, sprite)
            SetBlipColour(blip, 2)
            SetBlipScale(blip, 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(business.type:gsub("^%l", string.upper) .. " (Level " .. business.level .. ")")
            EndTextCommandSetBlipName(blip)
            BusinessBlips[id] = blip
        end
    end
end

-- Create Business
RegisterNetEvent('cold-gangs:client:CreateBusiness', function(businessType)
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    if not exports['cold-gangs']:HasGangPermission('manageBusinesses') then
        QBCore.Functions.Notify("You don't have permission to create businesses", "error")
        return
    end
    
    if not Config.BusinessTypes[businessType] then
        QBCore.Functions.Notify("Invalid business type", "error")
        return
    end
    
    local businessConfig = Config.BusinessTypes[businessType]
    
    -- Show confirmation dialog
    local dialog = exports['qb-input']:ShowInput({
        header = "Create " .. businessConfig.name,
        submitText = "Confirm",
        inputs = {
            {
                text = "Cost: $" .. businessConfig.purchaseCost,
                name = "confirm",
                type = "checkbox",
                isRequired = true
            }
        }
    })
    
    if dialog and dialog.confirm then
        -- Get player position
        local coords = GetEntityCoords(PlayerPedId())
        
        -- Create business
        TriggerServerEvent('cold-gangs:server:CreateBusiness', businessType, coords)
    end
end)

-- Access Business
RegisterNetEvent('cold-gangs:client:AccessBusiness', function(businessId)
    local business = nil
    for id, b in pairs(Businesses) do
        if id == businessId then
            business = b
            break
        end
    end
    
    if not business then
        QBCore.Functions.Notify("Business not found", "error")
        return
    end
    
    -- Show business menu
    local menu = {
        {
            header = business.type:gsub("^%l", string.upper) .. " (Level " .. business.level .. ")",
            isMenuHeader = true
        },
        {
            header = "Business Information",
            txt = "Income: $" .. business.income .. "/hr | Stored: $" .. business.income_stored,
            params = {
                event = "cold-gangs:client:ViewBusinessInfo",
                args = {
                    businessId = businessId
                }
            }
        },
        {
            header = "Collect Income",
            txt = "Available: $" .. business.income_stored,
            params = {
                event = "cold-gangs:client:CollectBusinessIncome",
                args = {
                    businessId = businessId
                }
            }
        }
    }
    
    if exports['cold-gangs']:HasGangPermission('manageBusinesses') then
        table.insert(menu, {
            header = "Upgrade Business",
            txt = "Current Level: " .. business.level,
            params = {
                event = "cold-gangs:client:UpgradeBusiness",
                args = {
                    businessId = businessId
                }
            }
        })
        
        table.insert(menu, {
            header = "Manage Employees",
            txt = "Current: " .. business.employees .. "/" .. business.capacity,
            params = {
                event = "cold-gangs:client:ManageBusinessEmployees",
                args = {
                    businessId = businessId
                }
            }
        })
    end
    
    table.insert(menu, {
        header = "← Close",
        txt = "",
        params = {
            event = "qb-menu:client:closeMenu"
        }
    })
    
    exports['qb-menu']:openMenu(menu)
end)

-- View Business Info
RegisterNetEvent('cold-gangs:client:ViewBusinessInfo', function(data)
    local businessId = data.businessId
    
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetBusinessDetails', function(details)
        if not details then
            QBCore.Functions.Notify("Failed to get business details", "error")
            return
        end
        
        local info = "Type: " .. details.type:gsub("^%l", string.upper) .. "\n" ..
                    "Level: " .. details.level .. "\n" ..
                    "Income: $" .. details.income .. "/hr\n" ..
                    "Stored: $" .. details.income_stored .. "\n" ..
                    "Employees: " .. details.employees .. "/" .. details.capacity .. "\n" ..
                    "Security: " .. details.security .. "\n" ..
                    "Last Payout: " .. details.last_payout
        
        QBCore.Functions.Notify(info, "primary", 10000)
    end, businessId)
end)

-- Collect Business Income
RegisterNetEvent('cold-gangs:client:CollectBusinessIncome', function(data)
    local businessId = data.businessId
    TriggerServerEvent('cold-gangs:server:CollectBusinessIncome', businessId)
end)

-- Upgrade Business
RegisterNetEvent('cold-gangs:client:UpgradeBusiness', function(data)
    local businessId = data.businessId
    
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetBusinessUpgradeOptions', function(options)
        if not options then
            QBCore.Functions.Notify("Failed to get upgrade options", "error")
            return
        end
        
        local menu = {
            {
                header = "Business Upgrades",
                isMenuHeader = true
            }
        }
        
        -- Main level upgrade
        if options.mainLevel then
            table.insert(menu, {
                header = "Upgrade Business Level",
                txt = "Current: " .. options.mainLevel.current .. " | Cost: $" .. options.mainLevel.cost,
                params = {
                    event = "cold-gangs:client:ConfirmBusinessUpgrade",
                    args = {
                        businessId = businessId,
                        upgradeType = "level"
                    }
                }
            })
        end
        
        -- Security upgrade
        if options.security then
            table.insert(menu, {
                header = "Upgrade Security",
                txt = "Current: " .. options.security.current .. " | Cost: $" .. options.security.cost,
                params = {
                    event = "cold-gangs:client:ConfirmBusinessUpgrade",
                    args = {
                        businessId = businessId,
                        upgradeType = "security"
                    }
                }
            })
        end
        
        -- Capacity upgrade
        if options.capacity then
            table.insert(menu, {
                header = "Upgrade Capacity",
                txt = "Current: " .. options.capacity.current .. " | Cost: $" .. options.capacity.cost,
                params = {
                    event = "cold-gangs:client:ConfirmBusinessUpgrade",
                    args = {
                        businessId = businessId,
                        upgradeType = "capacity"
                    }
                }
            })
        end
        
        table.insert(menu, {
            header = "← Close",
            txt = "",
            params = {
                event = "qb-menu:client:closeMenu"
            }
        })
        
        exports['qb-menu']:openMenu(menu)
    end, businessId)
end)

-- Confirm Business Upgrade
RegisterNetEvent('cold-gangs:client:ConfirmBusinessUpgrade', function(data)
    TriggerServerEvent('cold-gangs:server:UpgradeBusiness', data.businessId, data.upgradeType)
end)

-- Manage Business Employees
RegisterNetEvent('cold-gangs:client:ManageBusinessEmployees', function(data)
    local businessId = data.businessId
    
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetBusinessEmployees', function(employees, capacity)
        local menu = {
            {
                header = "Business Employees (" .. #employees .. "/" .. capacity .. ")",
                isMenuHeader = true
            }
        }
        
        if #employees < capacity then
            table.insert(menu, {
                header = "Hire Employee",
                txt = "Cost: $500",
                params = {
                    event = "cold-gangs:client:HireBusinessEmployee",
                    args = {
                        businessId = businessId
                    }
                }
            })
        end
        
        for i, employee in ipairs(employees) do
            table.insert(menu, {
                header = employee.name,
                txt = "Salary: $" .. employee.salary .. " | Efficiency: " .. employee.efficiency .. "%",
                params = {
                    event = "cold-gangs:client:FireBusinessEmployee",
                    args = {
                        businessId = businessId,
                        employeeId = employee.id
                    }
                }
            })
        end
        
        table.insert(menu, {
            header = "← Close",
            txt = "",
            params = {
                event = "qb-menu:client:closeMenu"
            }
        })
        
        exports['qb-menu']:openMenu(menu)
    end, businessId)
end)

-- Hire Business Employee
RegisterNetEvent('cold-gangs:client:HireBusinessEmployee', function(data)
    TriggerServerEvent('cold-gangs:server:HireBusinessEmployee', data.businessId)
end)

-- Fire Business Employee
RegisterNetEvent('cold-gangs:client:FireBusinessEmployee', function(data)
    TriggerServerEvent('cold-gangs:server:FireBusinessEmployee', data.businessId, data.employeeId)
end)

-- Draw 3D text for businesses
CreateThread(function()
    while true do
        Wait(0)
        
        if isLoggedIn and PlayerGang then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local sleep = true
            
            for id, business in pairs(Businesses) do
                if business.location then
                    local businessCoords = json.decode(business.location)
                    local distance = #(playerCoords - vector3(businessCoords.x, businessCoords.y, businessCoords.z))
                    
                    if distance < 10.0 then
                        sleep = false
                        local text = business.type:gsub("^%l", string.upper) .. "\nLevel: " .. business.level .. "\nIncome: $" .. business.income .. "/hr"
                        if business.income_stored > 0 then
                            text = text .. "\nStored: $" .. business.income_stored
                        end
                        Draw3DText(businessCoords.x, businessCoords.y, businessCoords.z + 1.0, text)
                        
                        if distance < 2.0 then
                            Draw3DText(businessCoords.x, businessCoords.y, businessCoords.z + 0.5, "Press [E] to access")
                            
                            if IsControlJustPressed(0, 38) then -- E key
                                TriggerEvent('cold-gangs:client:AccessBusiness', id)
                            end
                        end
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
    
    for _, blip in pairs(BusinessBlips) do
        RemoveBlip(blip)
    end
    BusinessBlips = {}
end)

            
