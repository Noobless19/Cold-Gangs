local QBCore = exports['qb-core']:GetCoreObject()

local PlayerData = nil
local PlayerGang = nil
local isLoggedIn = false
local isMenuOpen = false
local NuiReady = false

local function setFocus(enable)
    SetNuiFocus(enable, enable)
end

local function TryParseLocation(locationData)
    if not locationData then return nil end
    if type(locationData) == "table" then
        return {
            x = tonumber(locationData.x),
            y = tonumber(locationData.y),
            z = tonumber(locationData.z) or 0.0,
            h = tonumber(locationData.h) or 0.0
        }
    end
    if type(locationData) == "string" then
        local ok, decoded = pcall(json.decode, locationData)
        if ok and decoded then
            return {
                x = tonumber(decoded.x),
                y = tonumber(decoded.y),
                z = tonumber(decoded.z) or 0.0,
                h = tonumber(decoded.h) or 0.0
            }
        end
    end
    return nil
end

local function ParseLocation(locationData)
    return TryParseLocation(locationData)
end

local function dist2D(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function showNotification(message, ntype)
    if ntype == 'error' then
        QBCore.Functions.Notify(message, 'error')
    elseif ntype == 'success' then
        QBCore.Functions.Notify(message, 'success')
    elseif ntype == 'warning' then
        QBCore.Functions.Notify(message, 'warning')
    else
        QBCore.Functions.Notify(message, 'info')
    end
end

local function PrettyLabel(code)
    if not code or code == '' then return '-' end
    local s = code:gsub('_',' '):lower()
    return s:gsub("(%a)([%w_']*)", function(a,b) return a:upper()..b end)
end

local Zones = {}
local Types = {}

CreateThread(function()
    Zones = (Config and Config.MapZones) or {}
    Types = (Config and Config.Territories and Config.Territories.Types) or {}
end)

local function ResolveType(name, t)
    return (t and t.type) or (Zones[name] and Zones[name].type) or "residential"
end

local function ResolveLabel(name, t)
    return (t and t.label) or (Zones[name] and Zones[name].label) or PrettyLabel(name)
end

local function ResolveIncome(typ, t)
    local v = (t and t.income) or (t and t.income_rate)
    if tonumber(v) and tonumber(v) > 0 then return tonumber(v) end
    local def = Types[typ]
    return def and tonumber(def.baseIncome) or 0
end

local function refreshBank()
    if not PlayerGang then return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangBank', function(bal)
        SendNUIMessage({ action = 'update', type = 'bank', data = { bank = bal or 0 } })
    end, PlayerGang.id)
end

local function refreshTransactions()
    if not PlayerGang then return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangTransactions', function(txs)
        SendNUIMessage({ action = 'update', type = 'transactions', data = txs or {} })
    end, PlayerGang.id)
end

local function refreshMembers()
    if not PlayerGang then return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangMembers', function(members)
        if members then
            SendNUIMessage({ action = 'update', type = 'members', data = members })
        end
    end, PlayerGang.id)
end

local function refreshTerritories()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
        if territories then
            local arr = {}
            for name, t in pairs(territories or {}) do
                local typ = ResolveType(name, t)
                local label = ResolveLabel(name, t)
                local income = ResolveIncome(typ, t)
                table.insert(arr, {
                    name = name,
                    label = label,
                    gangId = t.gangId,
                    gangName = t.gangName or "Unclaimed",
                    status = t.gangId and "owned" or "unclaimed",
                    colorHex = t.colorHex or "#808080",
                    income = income,
                    type = typ,
                    upgrades = t.upgrades or {},
                    contested = t.contested or false,
                    contestedBy = t.contestedBy or nil,
                    influence = t.influence or 0
                })
            end
            SendNUIMessage({ action = 'update', type = 'territories', data = arr })
        end
    end)
end

local function refreshBusinesses()
    if not PlayerGang then return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangBusinesses', function(bz)
        local list = {}
        if type(bz) == "table" then
            for id, b in pairs(bz) do b.id = id table.insert(list, b) end
        end
        SendNUIMessage({ action = 'update', type = 'businesses', data = list })
    end, PlayerGang.id)
end

local function refreshVehicles()
    if not PlayerGang then return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangVehicles', function(vehicles)
        local vlist = {}
        if type(vehicles) == "table" then
            for _, v in pairs(vehicles) do table.insert(vlist, v) end
        end
        SendNUIMessage({ action = 'update', type = 'vehicles', data = vlist })
    end, PlayerGang.id)
end

local function refreshDrugs()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetDrugFields', function(fields)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetDrugLabs', function(labs)
            SendNUIMessage({ action = 'update', type = 'drugs', data = { fields = fields or {}, labs = labs or {} } })
        end)
    end)
end

local function refreshWars()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveWars', function(wars)
        SendNUIMessage({ action = 'update', type = 'wars', data = wars or {} })
    end)
end

local function refreshHeists()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveHeists', function(heists)
        SendNUIMessage({ action = 'update', type = 'heists', data = heists or {} })
    end)
end

function OpenAdminDashboard()
    setFocus(true)
    SendNUIMessage({ action = "openUI", startTab = "admin" })
    isMenuOpen = true
end

local function OpenGangDashboard()
    SendNUIMessage({ action = 'showLoading', message = 'Loading gang data...' })
    setFocus(true)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData)
        if not gangData then
            QBCore.Functions.TriggerCallback('cold-gangs:server:IsPlayerAdmin', function(isAdmin)
                if isAdmin then
                    OpenAdminDashboard()
                else
                    showNotification("You are not in a gang", "error")
                    SendNUIMessage({ action = 'hideLoading' })
                    setFocus(false)
                end
            end)
            return
        end
        PlayerGang = gangData
        local pd = PlayerData or QBCore.Functions.GetPlayerData()
        local ui = {
            playerData = {
                citizenId = pd and pd.citizenid or "",
                name = (pd and pd.charinfo and (pd.charinfo.firstname .. " " .. pd.charinfo.lastname)) or "Unknown",
                money = (pd and pd.money and pd.money.cash) or 0,
                rank = gangData.rank or 1,
                isAdmin = false
            },
            gangData = gangData,
            members = {},
            territories = {},
            transactions = {},
            activities = {},
            nearbyPlayers = {},
            availableGangs = {},
            rivalGangs = {},
            businesses = {},
            gangVehicles = {},
            drugFields = {},
            drugLabs = {},
            activeWars = {},
            activeHeists = {},
            config = Config or {}
        }
        local loaded = {
            gang = true, members = false, territories = false, transactions = false, bank = false,
            businesses = false, vehicles = false, drugs = false, wars = false, heists = false, admin = true
        }
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangMembers', function(members)
            ui.members = members or {}
            loaded.members = true
        end, gangData.id)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
            local arr = {}
            for name, t in pairs(territories or {}) do
                local typ = ResolveType(name, t)
                local label = ResolveLabel(name, t)
                local income = ResolveIncome(typ, t)
                table.insert(arr, {
                    name = name,
                    label = label,
                    gangId = t.gangId,
                    gangName = t.gangName or "Unclaimed",
                    status = t.gangId and "owned" or "unclaimed",
                    colorHex = t.colorHex or "#808080",
                    income = income,
                    type = typ,
                    upgrades = t.upgrades or {},
                    contested = t.contested or false,
                    contestedBy = t.contestedBy or nil,
                    influence = t.influence or 0
                })
            end
            ui.territories = arr
            loaded.territories = true
        end)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangTransactions', function(txs)
            ui.transactions = txs or {}
            loaded.transactions = true
        end, gangData.id)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangBank', function(bal)
            if ui.gangData then ui.gangData.bank = bal ui.gangData.money = bal end
            loaded.bank = true
        end, gangData.id)
ui.businesses = {}
loaded.businesses = true
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangVehicles', function(vehicles)
            local vlist = {}
            if type(vehicles) == "table" then
                for _, v in pairs(vehicles) do table.insert(vlist, v) end
            end
            ui.gangVehicles = vlist
            loaded.vehicles = true
        end, gangData.id)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetDrugFields', function(fields)
            ui.drugFields = fields or {}
            QBCore.Functions.TriggerCallback('cold-gangs:server:GetDrugLabs', function(labs)
                ui.drugLabs = labs or {}
                loaded.drugs = true
            end)
        end)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveWars', function(wars)
            ui.activeWars = wars or {}
            loaded.wars = true
        end)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveHeists', function(heists)
            ui.activeHeists = heists or {}
            loaded.heists = true
        end)
        QBCore.Functions.TriggerCallback('cold-gangs:server:IsPlayerAdmin', function(isAdmin)
            ui.playerData.isAdmin = isAdmin and true or false
        end)
        CreateThread(function()
            local timeout = GetGameTimer() + 8000
            while GetGameTimer() < timeout do
                local all = true
                for _, v in pairs(loaded) do if not v then all = false break end end
                if all then break end
                Wait(50)
            end
            SendNUIMessage({
                action = 'openGangMenu',
                type = 'openGangMenu',
                playerData = ui.playerData,
                gangData = ui.gangData,
                members = ui.members,
                territories = ui.territories,
                transactions = ui.transactions,
                activities = ui.activities,
                nearbyPlayers = ui.nearbyPlayers,
                availableGangs = ui.availableGangs,
                rivalGangs = ui.rivalGangs,
                businesses = ui.businesses,
                gangVehicles = ui.gangVehicles,
                drugFields = ui.drugFields,
                drugLabs = ui.drugLabs,
                activeWars = ui.activeWars,
                activeHeists = ui.activeHeists,
                config = ui.config
            })
            SendNUIMessage({ action = 'hideLoading' })
            isMenuOpen = true
        end)
    end)
end

CreateThread(function()
    Wait(1000)
    while not QBCore.Functions.GetPlayerData() do Wait(100) end
    isLoggedIn = true
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData) PlayerGang = gangData end)
end)

local function CloseDashboard()
    setFocus(false)
    isMenuOpen = false
    SendNUIMessage({ action = 'close' })
end


RegisterNUICallback('viewVehicle', function(data, cb)
    cb('ok')
end)

RegisterNUICallback('buyGangVehicle', function(data, cb)
    local model = data and data.model
    if not model or model == "" then
        QBCore.Functions.Notify("Invalid vehicle model", "error")
        cb('ok'); return
    end
    TriggerServerEvent('cold-gangs:vehicles:Purchase', model)
    QBCore.Functions.Notify("Purchase requested", "info")
    cb('ok')
end)

RegisterNUICallback('setGangGarage', function(_, cb)
    TriggerServerEvent('cold-gangs:vehicles:SetGarage')
    QBCore.Functions.Notify("Setting gang garage...", "info")
    cb('ok')
end)

RegisterNUICallback('garageWaypoint', function(_, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangGarage', function(g)
        if g and g.x and g.y then
            SetNewWaypoint(g.x + 0.0, g.y + 0.0)
            QBCore.Functions.Notify("Waypoint set to gang garage", "success")
        else
            QBCore.Functions.Notify("No garage set for your gang", "error")
        end
        cb('ok')
    end)
end)

RegisterNUICallback('nuiReady', function(_, cb) NuiReady = true cb('ok') end)
RegisterNUICallback('closeUI', function(_, cb) CloseDashboard() cb('ok') end)
RegisterNUICallback('exit', function(_, cb) CloseDashboard() cb('ok') end)

RegisterNUICallback('refreshUI', function(_, cb)
    refreshBank()
    refreshTransactions()
    refreshMembers()
    refreshTerritories()
    refreshBusinesses()
    refreshVehicles()
    refreshDrugs()
    refreshWars()
    refreshHeists()
    cb('ok')
end)

RegisterNUICallback('spawnVehicle', function(data, cb)
    local plate = data and data.plate
    if not plate or plate == "" then
        QBCore.Functions.Notify("Invalid plate", "error")
        cb('ok')
        return
    end
    TriggerServerEvent('cold-gangs:vehicles:ValetSpawn', plate)
    QBCore.Functions.Notify("Valet is bringing your vehicle...", "primary")
    cb('ok')
end)

RegisterNUICallback('recallVehicle', function(data, cb)
    local plate = data and data.plate
    if not plate or plate == "" then
        QBCore.Functions.Notify("No plate provided", "error")
        cb('ok'); return
    end
    TriggerServerEvent('cold-gangs:vehicles:Recall', plate)
    QBCore.Functions.Notify("Recall requested...", "primary")
    cb('ok')
end)

RegisterNUICallback('refreshVehicles', function(_, cb)
    local gid = nil
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGangId', function(id) gid = id end)
    local tries = 0
    while gid == nil and tries < 40 do Wait(50) tries = tries + 1 end

    local vehicles, garage, catalog, caps = nil, nil, nil, nil
    if gid then
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangVehicles', function(v) vehicles = v end, gid)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangGarage', function(g) garage = g end)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetVehicleCatalog', function(c) catalog = c or {} end)
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetVehiclesUiCaps', function(x) caps = x or {} end)
    else
        vehicles, garage, catalog, caps = {}, nil, {}, { canSetGarage = false, canPurchase = false, recallPrice = 50000 }
    end

    local n = 0
    while (vehicles == nil or garage == nil or catalog == nil or caps == nil) and n < 60 do Wait(50) n = n + 1 end

    local vlist = {}
    if type(vehicles) == "table" then
        for _, v in pairs(vehicles) do table.insert(vlist, v) end
    end

    SendNUIMessage({
        action = 'update',
        type = 'vehicles',
        data = {
            vehicles = vlist,
            garage = garage,
            catalog = catalog,
            canSetGarage = caps.canSetGarage == true,
            canPurchase = caps.canPurchase == true,
            recallPrice = caps.recallPrice or 50000
        }
    })
    cb('ok')
end)

RegisterNUICallback('refreshTerritories', function(_, cb) refreshTerritories() cb('ok') end)
RegisterNUICallback('refreshBank', function(_, cb) refreshBank() cb('ok') end)
RegisterNUICallback('refreshMembers', function(_, cb) refreshMembers() cb('ok') end)
RegisterNUICallback('refreshBusinesses', function(_, cb) refreshBusinesses() cb('ok') end)
RegisterNUICallback('refreshDrugs', function(_, cb) refreshDrugs() cb('ok') end)
RegisterNUICallback('refreshHeists', function(_, cb) refreshHeists() cb('ok') end)
RegisterNUICallback('refreshWars', function(_, cb) refreshWars() cb('ok') end)

RegisterNUICallback('viewTerritory', function(data, cb)
    local name = data and (data.territoryName or data.name)
    if not name or name == '' then cb('ok') return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetTerritoryDetails', function(territoryData)
        if territoryData then
            SendNUIMessage({
                action = 'showTerritoryDetails',
                data = territoryData,
                config = { CurrencySymbol = (Config and Config.CurrencySymbol) or "£" }
            })
        else
            TriggerEvent('QBCore:Notify', 'Territory not found', 'error')
        end
        cb('ok')
    end, name)
end)

RegisterNUICallback('territoryWaypoint', function(data, cb)
    local x, y
    if data and data.coords and data.coords.x and data.coords.y then
        x, y = tonumber(data.coords.x), tonumber(data.coords.y)
    else
        x, y = tonumber(data.x), tonumber(data.y)
    end
    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
        TriggerEvent('QBCore:Notify', 'Waypoint set', 'success')
    else
        TriggerEvent('QBCore:Notify', 'No coordinates for this territory', 'error')
    end
    cb('ok')
end)

RegisterNUICallback('upgradeTerritory', function(data, cb)
    local name = (data and (data.name or data.territoryName or data.territoryId)) or nil
    local utype = data and data.upgradeType or nil
    if not name or not utype then cb('ok') return end

    QBCore.Functions.TriggerCallback('cold-gangs:server:UpgradeTerritory', function(ok)
        if ok then
            QBCore.Functions.TriggerCallback('cold-gangs:server:GetTerritoryDetails', function(td)
                if td then
                    SendNUIMessage({
                        action = 'showTerritoryDetails',
                        data = td,
                        config = { CurrencySymbol = (Config and Config.CurrencySymbol) or "£" }
                    })
                    TriggerEvent('QBCore:Notify', ('Upgraded: %s'):format(utype), 'success')
                end
                cb('ok')
            end, name)
        else
            TriggerEvent('QBCore:Notify', 'Upgrade failed', 'error')
            cb('ok')
        end
    end, name, utype)
end)

RegisterNUICallback('createBusiness', function(data, cb)
    if data.businessType then
        local coords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('cold-gangs:businesses:Create', data.businessType, coords)
    end
    cb('ok')
end)

RegisterNUICallback('collectBusinessIncome', function(data, cb)
    if data.businessId then
        TriggerServerEvent('cold-gangs:businesses:Collect', data.businessId)
    end
    cb('ok')
end)

RegisterNUICallback('upgradeBusiness', function(data, cb)
    if data.businessId and data.upgradeType then
        TriggerServerEvent('cold-gangs:businesses:Upgrade', data.businessId, data.upgradeType)
    end
    cb('ok')
end)

RegisterNUICallback('viewBusiness', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:ViewBusiness', function(businessData)
        if businessData then
            SendNUIMessage({ action = 'showBusinessDetails', data = businessData })
        end
    end, data.businessId)
    cb('ok')
end)

RegisterNUICallback('registerVehicle', function(_, cb)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then showNotification("You must be in a vehicle", "error") cb('ok') return end
    local props = QBCore.Functions.GetVehicleProperties(veh)
    TriggerServerEvent('cold-gangs:vehicles:Register', props)
    showNotification("Registering current vehicle...", "info")
    cb('ok')
end)

RegisterNUICallback('storeVehicle', function(data, cb)
    local plate = data and data.plate
    if plate and plate ~= "" then
        TriggerServerEvent('cold-gangs:vehicles:Store', plate)
        QBCore.Functions.Notify("Storing vehicle...", "info")
        cb('ok')
        return
    end
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then
        QBCore.Functions.Notify("You must be in a vehicle", "error")
        cb('ok')
        return
    end
    local vplate = QBCore.Functions.GetPlate(veh)
    TriggerServerEvent('cold-gangs:vehicles:Store', vplate)
    QBCore.Functions.Notify("Storing vehicle...", "info")
    cb('ok')
end)

RegisterNUICallback('trackVehicle', function(data, cb)
    local plate = data and data.plate
    if plate and plate ~= "" then
        TriggerEvent('cold-gangs:client:TrackGangVehicle', plate)
    else
        showNotification("Plate required", "error")
    end
    cb('ok')
end)

RegisterNUICallback('viewVehicle', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:ViewVehicle', function(vehicleData)
        if vehicleData then
            SendNUIMessage({ action = 'showVehicleDetails', data = vehicleData })
        end
    end, data.plate)
    cb('ok')
end)

RegisterNUICallback('createField', function(data, cb)
    if data.resourceType and data.territoryName then
        TriggerServerEvent('cold-gangs:server:CreateDrugField', data.resourceType, data.territoryName)
    end
    cb('ok')
end)

RegisterNUICallback('harvestField', function(data, cb)
    if data.fieldId then
        TriggerServerEvent('cold-gangs:server:HarvestDrugField', data.fieldId)
    end
    cb('ok')
end)

RegisterNUICallback('createLab', function(data, cb)
    if data.drugType and data.territoryName then
        TriggerServerEvent('cold-gangs:server:CreateDrugLab', data.drugType, data.territoryName)
    end
    cb('ok')
end)

RegisterNUICallback('processDrugs', function(data, cb)
    if data.labId then
        TriggerServerEvent('cold-gangs:server:ProcessDrugs', data.labId)
    end
    cb('ok')
end)

RegisterNUICallback('upgradeLab', function(data, cb)
    if data.labId and data.upgradeType then
        TriggerServerEvent('cold-gangs:server:UpgradeLab', data.labId, data.upgradeType)
    end
    cb('ok')
end)

RegisterNUICallback('viewLab', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:ViewLab', function(labData)
        if labData then
            SendNUIMessage({ action = 'showLabDetails', data = labData })
        end
    end, data.labId)
    cb('ok')
end)

RegisterNUICallback('viewField', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:ViewField', function(fieldData)
        if fieldData then
            SendNUIMessage({ action = 'showFieldDetails', data = fieldData })
        end
    end, data.fieldId)
    cb('ok')
end)

RegisterNUICallback('startHeist', function(data, cb)
    if data.heistType then
        TriggerEvent('cold-gangs:client:StartHeist', data.heistType)
    end
    cb('ok')
end)

RegisterNUICallback('joinHeist', function(data, cb)
    if data.heistId then
        TriggerEvent('cold-gangs:client:JoinHeist', data.heistId)
    end
    cb('ok')
end)

RegisterNUICallback('startHeistMission', function(data, cb)
    if data.heistId then
        TriggerEvent('cold-gangs:client:StartHeistMission', data.heistId)
    end
    cb('ok')
end)

RegisterNUICallback('cancelHeist', function(data, cb)
    if data.heistId then
        TriggerServerEvent('cold-gangs:heists:Cancel', data.heistId)
        showNotification("Heist cancel requested", "info")
    end
    cb('ok')
end)

RegisterNUICallback('viewHeist', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:ViewHeist', function(heistData)
        if heistData then
            SendNUIMessage({ action = 'showHeistDetails', data = heistData })
        end
    end, data.heistId)
    cb('ok')
end)

RegisterNUICallback('declareWar', function(data, cb)
    TriggerServerEvent('cold-gangs:wars:Declare', tonumber(data.targetGangId), data.territoryName)
    showNotification("War declaration requested", "info")
    cb('ok')
end)

RegisterNUICallback('surrenderWar', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:SurrenderWar', function(success)
        if success then showNotification("War surrendered", "warning") else showNotification("Failed to surrender war", "error") end
    end, data.warId)
    cb('ok')
end)

RegisterNUICallback('viewWar', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:ViewWar', function(warData)
        if warData then
            SendNUIMessage({ action = 'showWarDetails', data = warData })
        end
    end, data.warId)
    cb('ok')
end)

RegisterNUICallback('invitePlayer', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:InvitePlayer', function(success)
        if success then showNotification("Player invited successfully", "success") else showNotification("Failed to invite player", "error") end
    end, data.targetId)
    cb('ok')
end)

RegisterNUICallback('promoteMember', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:PromoteMember', function(success)
        if success then showNotification("Member promoted successfully", "success") refreshMembers()
        else showNotification("Failed to promote member", "error") end
    end, data.citizenId)
    cb('ok')
end)

RegisterNUICallback('demoteMember', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:DemoteMember', function(success)
        if success then showNotification("Member demoted successfully", "success") refreshMembers()
        else showNotification("Failed to demote member", "error") end
    end, data.citizenId)
    cb('ok')
end)

RegisterNUICallback('kickMember', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:KickMember', function(success)
        if success then showNotification("Member kicked successfully", "success") refreshMembers()
        else showNotification("Failed to kick member", "error") end
    end, data.citizenId)
    cb('ok')
end)

-- Fronts: list for the tablet
RegisterNUICallback('refreshFronts', function(_, cb)
    local gid = nil
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGangId', function(id) gid = id end)
    local tries = 0
    while gid == nil and tries < 40 do Wait(50) tries = tries + 1 end

    if not gid then
        SendNUIMessage({ action = 'update', type = 'fronts', data = {} })
        cb('ok'); return
    end

    QBCore.Functions.TriggerCallback('cold-gangs:fronts:GetList', function(list)
        SendNUIMessage({ action = 'update', type = 'fronts', data = list or {} })
        cb('ok')
    end, gid)
end)

-- Fronts: detailed status (pool/rate/fee/cap + illegal catalog)
RegisterNUICallback('fronts_get_status', function(data, cb)
    local frontId = tonumber(data and data.frontId) or 0
    if frontId <= 0 then cb('ok') return end
    QBCore.Functions.TriggerCallback('cold-gangs:fronts:GetStatus', function(status)
        SendNUIMessage({ action = 'update', type = 'frontStatus', data = status or nil })
        cb('ok')
    end, frontId)
end)

-- Fronts: deposit marked bills into laundering pool
RegisterNUICallback('fronts_deposit', function(data, cb)
    local frontId = tonumber(data and data.frontId) or 0
    local amount = tonumber(data and data.amount) or 0
    if frontId <= 0 or amount <= 0 then
        QBCore.Functions.Notify("Invalid front/amount", "error")
        cb('ok'); return
    end
    TriggerServerEvent('cold-gangs:fronts:DepositDirty', frontId, amount)
    cb('ok')
end)

-- Fronts: set the illegal catalog (save full list)
RegisterNUICallback('fronts_set_catalog', function(data, cb)
    local frontId = tonumber(data and data.frontId) or 0
    local list = data and data.list or {}
    if frontId <= 0 then
        QBCore.Functions.Notify("Invalid front", "error")
        cb('ok'); return
    end
    QBCore.Functions.TriggerCallback('cold-gangs:fronts:SetCatalog', function(ok, msg)
        if ok then QBCore.Functions.Notify("Catalog updated", "success")
        else QBCore.Functions.Notify(msg or "Failed to update catalog", "error") end
        cb('ok')
    end, frontId, list)
end)


RegisterNUICallback('depositMoney', function(data, cb)
    local amt = tonumber(data and data.amount) or 0
    if amt <= 0 then
        QBCore.Functions.Notify("Enter a valid deposit amount", "error")
        cb('ok')
        return
    end

    QBCore.Functions.TriggerCallback('cold-gangs:server:DepositMoney', function(success)
        if success then
            showNotification("Money deposited successfully", "success")
            refreshBank()
            refreshTransactions()
        else
            showNotification("Failed to deposit money", "error")
        end
        cb('ok')
    end, amt)
end)

RegisterNUICallback('withdrawMoney', function(data, cb)
    local amt = tonumber(data and data.amount) or 0
    if amt <= 0 then
        QBCore.Functions.Notify("Enter a valid withdraw amount", "error")
        cb('ok')
        return
    end

    QBCore.Functions.TriggerCallback('cold-gangs:server:WithdrawMoney', function(success)
        if success then
            showNotification("Money withdrawn successfully", "success")
            refreshBank()
            refreshTransactions()
        else
            showNotification("Failed to withdraw money", "error")
        end
        cb('ok')
    end, amt)
end)

RegisterNUICallback('transferMoney', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:TransferMoney', function(success)
        if success then showNotification("Money transferred successfully", "success") refreshBank() refreshTransactions()
        else showNotification("Failed to transfer money", "error") end
    end, data.targetGangId, data.amount, data.reason) -- include reason
    cb('ok')
end)

RegisterNUICallback('changeGangName', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:ChangeGangName', function(success)
        if success then showNotification("Gang name changed successfully", "success") else showNotification("Failed to change gang name", "error") end
    end, data.name)
    cb('ok')
end)

RegisterNUICallback('changeGangTag', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:ChangeGangTag', function(success)
        if success then showNotification("Gang tag changed successfully", "success") else showNotification("Failed to change gang tag", "error") end
    end, data.tag)
    cb('ok')
end)

RegisterNUICallback('changeGangColor', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:ChangeGangColor', function(success)
        if success then showNotification("Gang color changed successfully", "success") else showNotification("Failed to change gang color", "error") end
    end, data.color)
    cb('ok')
end)

RegisterNUICallback('setMaxMembers', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:SetMaxMembers', function(success)
        if success then showNotification("Max members updated successfully", "success") else showNotification("Failed to update max members", "error") end
    end, data.amount)
    cb('ok')
end)

RegisterNUICallback('changeGangLogo', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:ChangeGangLogo', function(success)
        if success then showNotification("Gang logo changed successfully", "success") else showNotification("Failed to change gang logo", "error") end
    end, data.logo)
    cb('ok')
end)

RegisterNUICallback('leaveGang', function(_, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:LeaveGang', function(success)
        if success then showNotification("You left the gang", "warning") CloseDashboard()
        else showNotification("Failed to leave gang", "error") end
    end)
    cb('ok')
end)

RegisterNUICallback('disbandGang', function(_, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:DisbandGang', function(success)
        if success then showNotification("Gang disbanded", "warning") CloseDashboard()
        else showNotification("Failed to disband gang", "error") end
    end)
    cb('ok')
end)

RegisterNUICallback('transferLeadership', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:TransferLeadership', function(success)
        if success then showNotification("Leadership transferred successfully", "success") refreshMembers()
        else showNotification("Failed to transfer leadership", "error") end
    end, data.citizenId)
    cb('ok')
end)

RegisterNUICallback('openMainStash', function(_, cb)
    TriggerServerEvent('cold-gangs:stashes:OpenGang')
    cb({ success = true })
end)

RegisterNUICallback('openSharedStash', function(data, cb)
    local id = data and tonumber(data.stashId)
    if not id then
        QBCore.Functions.Notify("No stash ID", "error")
        cb({ success = false, message = "No stash id" })
        return
    end
    TriggerServerEvent('cold-gangs:stashes:OpenShared', id)
    cb({ success = true })
end)

RegisterNUICallback('setGangStashLocation', function(data, cb)
    if not PlayerGang then
        QBCore.Functions.Notify("You are not in a gang", "error")
        cb({success = false, message = "You are not in a gang"})
        return
    end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    local stashData = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = heading
    }
    
    TriggerServerEvent('cold-gangs:stashes:SetMainLocation', stashData)
    cb({success = true, message = "Gang stash location set"})
end)

RegisterNUICallback('createSharedStash', function(data, cb)
    if not PlayerGang then
        QBCore.Functions.Notify("You are not in a gang", "error")
        cb({success = false, message = "You are not in a gang"})
        return
    end
    
    if not data.name or data.name == "" then
        QBCore.Functions.Notify("Stash name is required", "error")
        cb({success = false, message = "Stash name is required"})
        return
    end
    
    local name = data.name
    local minRank = tonumber(data.minRank) or 1
    
    if minRank < 1 then minRank = 1 end
    if minRank > 6 then minRank = 6 end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    
    local stashData = {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
    
    TriggerServerEvent('cold-gangs:stashes:CreateShared', name, stashData, minRank)
    cb({success = true, message = "Shared stash created"})
end)

RegisterNUICallback('deleteSharedStash', function(data, cb)
    if not PlayerGang then
        QBCore.Functions.Notify("You are not in a gang", "error")
        cb({success = false, message = "You are not in a gang"})
        return
    end
    
    if not data.stashId then
        QBCore.Functions.Notify("No stash selected", "error")
        cb({success = false, message = "No stash selected"})
        return
    end
    
    TriggerServerEvent('cold-gangs:stashes:DeleteShared', tonumber(data.stashId))
    cb({success = true, message = "Stash deleted"})
end)


RegisterNUICallback('getSharedStashes', function(data, cb)
    if not PlayerGang then
        SendNUIMessage({ action = 'updateStashes', sharedStashes = {} })
        cb({ success = false, stashes = {} })
        return
    end

    QBCore.Functions.TriggerCallback('cold-gangs:server:GetSharedStashes', function(stashes)
        local stashList = {}
        for id, stash in pairs(stashes or {}) do
            local location = TryParseLocation(stash.location)
            table.insert(stashList, {
                id = id,
                name = stash.name,
                slots = stash.slots,
                weight = stash.weight,
                location = location,
                accessRanks = stash.accessRanks
            })
        end
        SendNUIMessage({ action = 'updateStashes', sharedStashes = stashList })
        cb({ success = true, stashes = stashList })
    end, PlayerGang.id)
end)

RegisterNUICallback('getGangStash', function(data, cb)
    if not PlayerGang then
        SendNUIMessage({ action = 'updateStashes', gangStash = nil })
        cb({ success = false, stash = nil })
        return
    end

    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangStash', function(stash)
        if stash then
            local location = TryParseLocation(stash.location)
            local payload = {
                name = stash.name,
                slots = stash.slots,
                weight = stash.weight,
                location = location,
                hasLocation = location ~= nil
            }
            SendNUIMessage({ action = 'updateStashes', gangStash = payload })
            cb({ success = true, stash = payload })
        else
            SendNUIMessage({ action = 'updateStashes', gangStash = nil })
            cb({ success = false, stash = nil })
        end
    end, PlayerGang.id)
end)

RegisterNUICallback('getNearbySharedStashes', function(_, cb)
    if not PlayerGang then
        cb({ success = false, stashes = {} })
        return
    end

    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)

    QBCore.Functions.TriggerCallback('cold-gangs:server:GetSharedStashes', function(stashes)
        local out = {}
        for id, stash in pairs(stashes or {}) do
            local loc = ParseLocation(stash.location)
            if loc and loc.x and loc.y then
                local d = dist2D(pc.x, pc.y, loc.x, loc.y)
                if d <= 10.0 then
                    table.insert(out, {
                        id = id,
                        name = stash.name or ("Stash "..tostring(id)),
                        distance = math.floor(d*10)/10,
                        coords = { x = loc.x, y = loc.y, z = loc.z or 0.0 }
                    })
                end
            end
        end
        table.sort(out, function(a,b) return a.distance < b.distance end)
        cb({ success = true, stashes = out })
    end, PlayerGang.id)
end)

RegisterNUICallback('admin_refresh_data', function(_, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAdminData', function(adminData)
        if adminData then
            if adminData.gangs then
                SendNUIMessage({ action = 'update', type = 'adminGangs', data = adminData.gangs })
            end
            if adminData.players then
                SendNUIMessage({ action = 'update', type = 'adminPlayers', data = adminData.players })
            end
            if adminData.territories then
                SendNUIMessage({ action = 'update', type = 'adminTerritories', data = adminData.territories })
            end
            if adminData.logs then
                SendNUIMessage({ action = 'update', type = 'adminLogs', data = adminData.logs })
            end
        end
    end)
    cb('ok')
end)

RegisterNUICallback('admin_create_gang', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:AdminCreateGang', function(ok, msg)
        if ok then showNotification("Gang created", "success") else showNotification(msg or "Failed to create gang", "error") end
    end,
    data.name, data.tag, data.color, tonumber(data.maxMembers),
    tonumber(data.mainStashSlots), tonumber(data.mainStashWeight),
    tonumber(data.sharedStashSlots), tonumber(data.sharedStashWeight),
    tonumber(data.sharedStashLimit)
    )
    cb('ok')
end)

RegisterNUICallback('admin_update_gang', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:AdminUpdateGang', function(ok, msg)
        if ok then showNotification("Gang updated", "success") else showNotification(msg or "Failed to update gang", "error") end
    end,
    tonumber(data.gangId), data.name, data.tag, data.color, tonumber(data.maxMembers),
    tonumber(data.mainStashSlots), tonumber(data.mainStashWeight),
    tonumber(data.sharedStashSlots), tonumber(data.sharedStashWeight),
    tonumber(data.sharedStashLimit)
    )
    cb('ok')
end)

RegisterNUICallback('admin_delete_gang', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:AdminDeleteGang', function(ok, msg)
        if ok then showNotification("Gang deleted", "success") else showNotification(msg or "Failed to delete gang", "error") end
    end, tonumber(data.gangId))
    cb('ok')
end)

RegisterNUICallback('admin_get_gang_members', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:AdminGetGangMembers', function(ok, members, capacity)
        if ok then
            SendNUIMessage({
                action = 'update',
                type = 'adminGangMembers',
                data = { gangId = data.gangId, members = members or {}, capacity = capacity or 0 }
            })
        else
            showNotification("Failed to load gang members", "error")
        end
    end, tonumber(data.gangId))
    cb('ok')
end)

RegisterNUICallback('admin_remove_member', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:AdminRemoveMember', function(ok, msg)
        if ok then showNotification("Member removed", "success") else showNotification(msg or "Failed to remove member", "error") end
        QBCore.Functions.TriggerCallback('cold-gangs:server:AdminGetGangMembers', function(ok2, members, capacity)
            if ok2 then
                SendNUIMessage({
                    action = 'update',
                    type = 'adminGangMembers',
                    data = { gangId = data.gangId, members = members or {}, capacity = capacity or 0 }
                })
            end
        end, tonumber(data.gangId))
    end, tonumber(data.gangId), tostring(data.citizenId))
    cb('ok')
end)

RegisterNUICallback('admin_set_territory_owner', function(data, cb)
    QBCore.Functions.TriggerCallback('cold-gangs:server:AdminSetTerritoryOwner', function(ok, msg)
        if ok then showNotification("Territory owner updated", "success") else showNotification(msg or "Failed to set owner", "error") end
    end, data.territoryName, data.gangId)
    cb('ok')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData) PlayerGang = gangData end)
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(_)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData)
        PlayerGang = gangData
        if isMenuOpen then
            refreshMembers()
            refreshBank()
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo) if PlayerData then PlayerData.job = JobInfo end end)
RegisterNetEvent('QBCore:Client:SetPlayerData', function(val) PlayerData = val end)

RegisterNetEvent('cold-gangs:client:OpenGangMenu', function() OpenGangDashboard() end)
RegisterNetEvent('cold-gangs:client:OpenAdminMenu', function() OpenAdminDashboard() end)
RegisterNetEvent('cold-gangs:client:CloseMenu', function() CloseDashboard() end)
RegisterNetEvent('cold-gangs:client:ShowNotification', function(message, ntype) showNotification(message, ntype) end)

RegisterKeyMapping('opengangmenu', 'Open Gang Menu', 'keyboard', 'F2')
RegisterCommand('opengangmenu', function()
    if isMenuOpen then CloseDashboard() else OpenGangDashboard() end
end, false)

RegisterCommand('opengangadmin', function()
    QBCore.Functions.TriggerCallback('cold-gangs:server:IsPlayerAdmin', function(isAdmin)
        if isAdmin then OpenAdminDashboard() else showNotification("You don't have permission to use this command", "error") end
    end)
end, false)

RegisterCommand('gangadmin', function()
    QBCore.Functions.TriggerCallback('cold-gangs:server:IsPlayerAdmin', function(isAdmin)
        if isAdmin then OpenAdminDashboard() else showNotification("You don't have permission to use this command", "error") end
    end)
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if isMenuOpen then setFocus(false) isMenuOpen = false end
end)
