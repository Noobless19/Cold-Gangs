local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayerGang = nil
local isLoggedIn = false
local isMenuOpen = false
local currentNuiFocus = false
local NuiReady = false

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

    -- Sync player gang
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData)
        PlayerGang = gangData
    end)
end)

-- Open Dashboard
function OpenDashboard()
    if not NuiReady then
        QBCore.Functions.Notify("UI not ready", "error")
        return
    end

    if not PlayerGang then
        QBCore.Functions.Notify("You are not in a gang", "error")
        return
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openDashboard',
        gang = PlayerGang,
        config = Config
    })
    isMenuOpen = true
    currentNuiFocus = true
end

-- Close Dashboard
RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    isMenuOpen = false
    currentNuiFocus = false
    cb({success = true})
end)

-- NUI Ready
RegisterNUICallback('nuiReady', function(data, cb)
    NuiReady = true
    cb({success = true})
end)

-- Get Player ID
RegisterNUICallback('getPlayerId', function(data, cb)
    cb({
        success = true,
        playerId = GetPlayerServerId(PlayerId())
    })
end)

-- Get Members
RegisterNUICallback('getMembers', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangMembers', function(members)
        if not members then
            cb({success = false, error = "Failed to fetch members"})
            return
        end
        
        -- Add online status to members
        for i, member in ipairs(members) do
            local player = QBCore.Functions.GetPlayerByCitizenId(member.citizenId)
            members[i].isOnline = player ~= nil
        end
        
        cb({
            success = true,
            data = members
        })
    end, PlayerGang.id)
end)

-- Get Territories
RegisterNUICallback('getTerritories', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
        if not territories then
            cb({success = false, error = "Failed to fetch territories"})
            return
        end
        
        local ownedTerritories = {}
        for name, territory in pairs(territories) do
            if territory.gangId == PlayerGang.id then
                table.insert(ownedTerritories, {
                    name = name,
                    income = Config.Territories.List[name] and Config.Territories.List[name].income or 0,
                    type = Config.Territories.List[name] and Config.Territories.List[name].type or "unknown",
                    contested = false
                })
            end
        end
        
        cb({
            success = true,
            data = ownedTerritories
        })
    end)
end)

-- Get Businesses
RegisterNUICallback('getBusinesses', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangBusinesses', function(businesses)
        cb({
            success = true,
            data = businesses or {}
        })
    end, PlayerGang.id)
end)

-- Get Business Upgrade Options
RegisterNUICallback('getBusinessUpgradeOptions', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetBusinessUpgradeOptions', function(options)
        cb({
            success = true,
            data = options or {}
        })
    end, data.businessId)
end)

-- Get Drugs
RegisterNUICallback('getDrugs', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetDrugFields', function(fields)
        local gangFields = {}
        if fields then
            for _, field in pairs(fields) do
                if field.owner == PlayerGang.id then
                    table.insert(gangFields, field)
                end
            end
        end
        
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetDrugLabs', function(labs)
            local gangLabs = {}
            if labs then
                for _, lab in pairs(labs) do
                    if lab.owner == PlayerGang.id then
                        table.insert(gangLabs, lab)
                    end
                end
            end
            
            cb({
                success = true,
                data = {
                    fields = gangFields,
                    labs = gangLabs
                }
            })
        end)
    end)
end)

-- Get Lab Processing Options
RegisterNUICallback('getLabProcessingOptions', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetLabProcessingOptions', function(options)
        cb({
            success = true,
            data = options or {}
        })
    end, data.labId)
end)

-- Get Wars
RegisterNUICallback('getWars', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveWars', function(wars)
        local gangWars = {}
        if wars then
            for _, war in pairs(wars) do
                if war.attackerId == PlayerGang.id or war.defenderId == PlayerGang.id then
                    table.insert(gangWars, war)
                end
            end
        end
        
        cb({
            success = true,
            data = gangWars
        })
    end)
end)

-- Get Heists
RegisterNUICallback('getHeists', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveHeists', function(heists)
        local gangHeists = {}
        if heists then
            for _, heist in pairs(heists) do
                if heist.gangId == PlayerGang.id then
                    table.insert(gangHeists, heist)
                end
            end
        end
        
        cb({
            success = true,
            data = gangHeists
        })
    end)
end)

-- Get Vehicles
RegisterNUICallback('getVehicles', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangVehicles', function(vehicles)
        cb({
            success = true,
            data = vehicles or {}
        })
    end, PlayerGang.id)
end)

-- Get Stashes
RegisterNUICallback('getStashes', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangStash', function(mainStash)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetSharedStashes', function(sharedStashes)
            cb({
                success = true,
                data = {
                    main = mainStash,
                    shared = sharedStashes or {}
                }
            })
        end, PlayerGang.id)
    end, PlayerGang.id)
end)

-- Get Recent Activities
RegisterNUICallback('getRecentActivities', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangTransactions', function(transactions)
        local activities = {}
        if transactions then
            for i = 1, math.min(10, #transactions) do
                local tx = transactions[i]
                table.insert(activities, {
                    time = os.date("%H:%M", tx.timestamp),
                    description = tx.description .. " ($" .. tx.amount .. ")"
                })
            end
        end
        
        cb({
            success = true,
            data = activities
        })
    end, PlayerGang.id)
end)

-- Get Available Gangs
RegisterNUICallback('getAvailableGangs', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllGangs', function(gangs)
        local availableGangs = {}
        if gangs then
            for _, gang in pairs(gangs) do
                if gang.id ~= PlayerGang.id then
                    table.insert(availableGangs, {
                        id = gang.id,
                        name = gang.name,
                        tag = gang.tag
                    })
                end
            end
        end
        
        cb({
            success = true,
            data = availableGangs
        })
    end)
end)

-- Member Management
RegisterNUICallback('promoteMember', function(data, cb)
    TriggerServerEvent('cold-gangs:server:PromoteMember', data.citizenId)
    cb({success = true})
end)

RegisterNUICallback('demoteMember', function(data, cb)
    TriggerServerEvent('cold-gangs:server:DemoteMember', data.citizenId)
    cb({success = true})
end)

RegisterNUICallback('kickMember', function(data, cb)
    TriggerServerEvent('cold-gangs:server:KickMember', data.citizenId, data.reason or "No reason provided")
    cb({success = true})
end)

RegisterNUICallback('inviteMember', function(data, cb)
    TriggerEvent('cold-gangs:client:InviteToGang')
    cb({success = true})
end)

-- Bank Management
RegisterNUICallback('depositGangMoney', function(data, cb)
    TriggerServerEvent('cold-gangs:server:DepositGangMoney', tonumber(data.amount))
    cb({success = true})
end)

RegisterNUICallback('withdrawGangMoney', function(data, cb)
    TriggerServerEvent('cold-gangs:server:WithdrawGangMoney', tonumber(data.amount))
    cb({success = true})
end)

RegisterNUICallback('transferGangMoney', function(data, cb)
    TriggerServerEvent('cold-gangs:server:TransferGangMoney', tonumber(data.targetGangId), tonumber(data.amount), data.reason or "Gang Transfer")
    cb({success = true})
end)

-- Territory Management
RegisterNUICallback('viewTerritory', function(data, cb)
    local territory = Config.Territories.List[data.territoryName]
    if territory and territory.coords then
        SetNewWaypoint(territory.coords.x, territory.coords.y)
        QBCore.Functions.Notify("Waypoint set to " .. data.territoryName, "success")
    end
    cb({success = true})
end)

RegisterNUICallback('abandonTerritory', function(data, cb)
    TriggerServerEvent('cold-gangs:server:AbandonTerritory', data.territoryName)
    cb({success = true})
end)

-- Business Management
RegisterNUICallback('createBusiness', function(data, cb)
    TriggerEvent('cold-gangs:client:CreateBusiness', data.businessType)
    cb({success = true})
end)

RegisterNUICallback('upgradeBusiness', function(data, cb)
    TriggerServerEvent('cold-gangs:server:UpgradeBusiness', data.businessId, data.upgradeType)
    cb({success = true})
end)

RegisterNUICallback('manageBusiness', function(data, cb)
    TriggerEvent('cold-gangs:client:AccessBusiness', data.businessId)
    cb({success = true})
end)

RegisterNUICallback('collectBusinessIncome', function(data, cb)
    TriggerServerEvent('cold-gangs:server:CollectBusinessIncome', data.businessId)
    cb({success = true})
end)

-- Drug Management
RegisterNUICallback('harvestField', function(data, cb)
    TriggerServerEvent('cold-gangs:server:HarvestDrugField', data.fieldId)
    cb({success = true})
end)

RegisterNUICallback('viewField', function(data, cb)
    for _, field in pairs(DrugFields) do
        if field.id == data.fieldId and field.location then
            local coords = json.decode(field.location)
            SetNewWaypoint(coords.x, coords.y)
            QBCore.Functions.Notify("Waypoint set to drug field", "success")
            break
        end
    end
    cb({success = true})
end)

RegisterNUICallback('processDrugs', function(data, cb)
    TriggerEvent('cold-gangs:client:StartDrugProcessing', {labId = data.labId})
    cb({success = true})
end)

RegisterNUICallback('upgradeLab', function(data, cb)
    TriggerEvent('cold-gangs:client:UpgradeDrugLab', {labId = data.labId})
    cb({success = true})
end)

-- War Management
RegisterNUICallback('declareWar', function(data, cb)
    TriggerServerEvent('cold-gangs:server:DeclareWar', tonumber(data.targetGangId))
    cb({success = true})
end)

RegisterNUICallback('viewWar', function(data, cb)
    for _, war in pairs(ActiveWars) do
        if war.id == data.warId and war.territoryName then
            local territory = Config.Territories.List[war.territoryName]
            if territory and territory.coords then
                SetNewWaypoint(territory.coords.x, territory.coords.y)
                QBCore.Functions.Notify("Waypoint set to war zone", "success")
                break
            end
        end
    end
    cb({success = true})
end)

RegisterNUICallback('surrenderWar', function(data, cb)
    TriggerServerEvent('cold-gangs:server:SurrenderWar', data.warId)
    cb({success = true})
end)

-- Heist Management
RegisterNUICallback('planHeist', function(data, cb)
    TriggerServerEvent('cold-gangs:server:StartHeist', data.heistType)
    cb({success = true})
end)

RegisterNUICallback('joinHeist', function(data, cb)
    TriggerServerEvent('cold-gangs:server:JoinHeist', data.heistId)
    cb({success = true})
end)

RegisterNUICallback('viewHeist', function(data, cb)
    for _, heist in pairs(ActiveHeists) do
        if heist.id == data.heistId and heist.location then
            local coords = heist.location.coords or heist.location
            SetNewWaypoint(coords.x, coords.y)
            QBCore.Functions.Notify("Waypoint set to heist location", "success")
            break
        end
    end
    cb({success = true})
end)

RegisterNUICallback('cancelHeist', function(data, cb)
    TriggerServerEvent('cold-gangs:server:CancelHeist', data.heistId)
    cb({success = true})
end)

-- Vehicle Management
RegisterNUICallback('registerVehicle', function(data, cb)
    TriggerEvent('cold-gangs:client:RegisterVehicle')
    cb({success = true})
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    TriggerServerEvent('cold-gangs:server:SpawnGangVehicle', data.plate)
    cb({success = true})
end)

RegisterNUICallback('storeVehicle', function(data, cb)
    TriggerServerEvent('cold-gangs:server:StoreGangVehicle', data.plate)
    cb({success = true})
end)

RegisterNUICallback('trackVehicle', function(data, cb)
    for _, vehicle in pairs(GangVehicles) do
        if vehicle.plate == data.plate and not vehicle.stored and vehicle.location then
            local coords = json.decode(vehicle.location)
            SetNewWaypoint(coords.x, coords.y)
            QBCore.Functions.Notify("Waypoint set to vehicle location", "success")
            break
        end
    end
    cb({success = true})
end)

-- Stash Management
RegisterNUICallback('createStash', function(data, cb)
    local playerCoords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('cold-gangs:server:CreateSharedStash', PlayerGang.id, data.name, playerCoords, {[data.minRank] = true})
    cb({success = true})
end)

RegisterNUICallback('openStash', function(data, cb)
    if data.stashId == 'main' then
        TriggerServerEvent('cold-gangs:server:OpenGangStash')
    else
        TriggerServerEvent('cold-gangs:server:OpenSharedStash', data.stashId)
    end
    cb({success = true})
end)

RegisterNUICallback('deleteStash', function(data, cb)
    TriggerServerEvent('cold-gangs:server:DeleteSharedStash', data.stashId)
    cb({success = true})
end)

-- Gang Settings
RegisterNUICallback('changeGangName', function(data, cb)
    TriggerServerEvent('cold-gangs:server:ChangeGangName', PlayerGang.id, data.name)
    cb({success = true})
end)

RegisterNUICallback('changeGangTag', function(data, cb)
    TriggerServerEvent('cold-gangs:server:ChangeGangTag', PlayerGang.id, data.tag)
    cb({success = true})
end)

RegisterNUICallback('changeGangColor', function(data, cb)
    TriggerServerEvent('cold-gangs:server:ChangeGangColor', PlayerGang.id, data.color)
    cb({success = true})
end)

RegisterNUICallback('changeGangLogo', function(data, cb)
    TriggerServerEvent('cold-gangs:server:ChangeGangLogo', PlayerGang.id, data.logo)
    cb({success = true})
end)

RegisterNUICallback('transferLeadership', function(data, cb)
    TriggerServerEvent('cold-gangs:server:TransferLeadership', data.targetCitizenId)
    cb({success = true})
end)

RegisterNUICallback('setMaxMembers', function(data, cb)
    TriggerServerEvent('cold-gangs:server:SetMaxMembers', PlayerGang.id, tonumber(data.maxMembers))
    cb({success = true})
end)

RegisterNUICallback('leaveGang', function(data, cb)
    TriggerServerEvent('cold-gangs:server:LeaveGang')
    cb({success = true})
end)

RegisterNUICallback('disbandGang', function(data, cb)
    TriggerServerEvent('cold-gangs:server:DeleteGang', PlayerGang.id)
    cb({success = true})
end)

-- Event Handlers
RegisterNetEvent('cold-gangs:client:UpdateGangData', function(gangId, updates)
    if PlayerGang and PlayerGang.id == gangId then
        for key, value in pairs(updates) do
            PlayerGang[key] = value
        end
        
        if isMenuOpen then
            SendNUIMessage({
                action = 'updateGangData',
                gang = PlayerGang
            })
        end
    end
end)

RegisterNetEvent('cold-gangs:client:GangCreated', function(gangData)
    PlayerGang = gangData
    QBCore.Functions.Notify("Gang created: " .. gangData.name, "success")
end)

RegisterNetEvent('cold-gangs:client:LeftGang', function()
    PlayerGang = nil
    QBCore.Functions.Notify("You left the gang", "primary")
    if isMenuOpen then
        SetNuiFocus(false, false)
        isMenuOpen = false
        currentNuiFocus = false
    end
end)

RegisterNetEvent('cold-gangs:client:KickedFromGang', function(reason)
    PlayerGang = nil
    QBCore.Functions.Notify("You were kicked from the gang: " .. reason, "error")
    if isMenuOpen then
        SetNuiFocus(false, false)
        isMenuOpen = false
        currentNuiFocus = false
    end
end)

RegisterNetEvent('cold-gangs:client:RankUpdated', function(newRank)
    if PlayerGang then
        PlayerGang.rank = newRank
        QBCore.Functions.Notify("Your rank has been updated", "primary")
        
        if isMenuOpen then
            SendNUIMessage({
                action = 'updateGangData',
                gang = PlayerGang
            })
        end
    end
end)

-- Add a command to open the UI
RegisterCommand('gangui', function()
    OpenDashboard()
end, false)

-- Add a key binding to open the UI (G key)
RegisterKeyMapping('gangui', 'Open Gang UI', 'keyboard', 'g')

-- Helper Functions
function IsInGang()
    return PlayerGang ~= nil
end

function HasGangPermission(perm)
    if not PlayerGang then return false end
    local rankData = Config.Gangs.Ranks[PlayerGang.rank]
    if not rankData then return false end
    return rankData['can' .. perm:sub(1,1):upper()..perm:sub(2)] or false
end

function GetRankName(rankId)
    if Config.Gangs.Ranks[rankId] then
        return Config.Gangs.Ranks[rankId].name
    end
    return "Unknown"
end

-- Exports
exports('IsInGang', IsInGang)
exports('HasGangPermission', HasGangPermission)
exports('GetRankName', GetRankName)
exports('OpenGangUI', OpenDashboard)
