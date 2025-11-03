local QBCore = exports['qb-core']:GetCoreObject()

local PlayerGang = nil
local ActiveHeists = {}
local HeistBlips = {}
local currentHeist = nil
local currentStage = 0
local heistTimer = 0

CreateThread(function()
    while not QBCore.Functions.GetPlayerData() do Wait(100) end
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData)
        PlayerGang = gangData
    end)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveHeists', function(heists)
        ActiveHeists = heists or {}
        CreateHeistBlips()
    end)
end)

RegisterNetEvent('cold-gangs:client:SyncHeists', function(heists)
    ActiveHeists = heists or {}
    CreateHeistBlips()
end)

local function toCoords(loc)
    if type(loc) == "string" then
        local ok, decoded = pcall(json.decode, loc)
        if ok and decoded and decoded.x and decoded.y and decoded.z then
            return vector3(decoded.x, decoded.y, decoded.z)
        end
    elseif type(loc) == "table" and loc.x and loc.y and loc.z then
        return vector3(loc.x, loc.y, loc.z)
    end
    return nil
end

function CreateHeistBlips()
    for _, blip in pairs(HeistBlips) do
        RemoveBlip(blip)
    end
    HeistBlips = {}
    if not ActiveHeists or not PlayerGang then return end
    for id, heist in pairs(ActiveHeists) do
        if heist.gangId == PlayerGang.id and heist.location then
            local coords = toCoords(heist.location) or (heist.location.coords and toCoords(heist.location.coords))
            if coords then
                local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                SetBlipSprite(blip, 486)
                SetBlipColour(blip, 1)
                SetBlipScale(blip, 0.8)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString((heist.heistType or "Heist"):gsub("_", " "):gsub("^%l", string.upper))
                EndTextCommandSetBlipName(blip)
                HeistBlips[id] = blip
            end
        end
    end
end

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
    local cfg = Config.HeistTypes[heistType]
    local function showLocations()
        local menu = { { header = "Select Heist Location", isMenuHeader = true } }
        if not cfg.locations or #cfg.locations == 0 then
            TriggerServerEvent('cold-gangs:heists:Start', heistType, 1)
            return
        end
        for i, loc in ipairs(cfg.locations) do
            table.insert(menu, {
                header = loc.name,
                txt = "Select this location",
                params = { event = "cold-gangs:client:ConfirmHeistLocation", args = { heistType = heistType, locationIndex = i } }
            })
        end
        table.insert(menu, { header = "← Cancel", params = { event = "qb-menu:client:closeMenu" } })
        exports['qb-menu']:openMenu(menu)
    end
    if (cfg.minReputation or 0) > 0 then
        QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangReputation', function(rep)
            if rep < cfg.minReputation then
                QBCore.Functions.Notify(("Your gang needs at least %d reputation"):format(cfg.minReputation), "error")
                return
            end
            if (cfg.policeRequired or 0) > 0 then
                QBCore.Functions.TriggerCallback('cold-gangs:server:GetPoliceCount', function(pc)
                    if pc < cfg.policeRequired then
                        QBCore.Functions.Notify(("Not enough police online. Required: %d"):format(cfg.policeRequired), "error")
                        return
                    end
                    showLocations()
                end)
            else
                showLocations()
            end
        end)
    else
        if (cfg.policeRequired or 0) > 0 then
            QBCore.Functions.TriggerCallback('cold-gangs:server:GetPoliceCount', function(pc)
                if pc < cfg.policeRequired then
                    QBCore.Functions.Notify(("Not enough police online. Required: %d"):format(cfg.policeRequired), "error")
                    return
                end
                showLocations()
            end)
        else
            showLocations()
        end
    end
end)

RegisterNetEvent('cold-gangs:client:ConfirmHeistLocation', function(data)
    TriggerServerEvent('cold-gangs:heists:Start', data.heistType, data.locationIndex)
end)

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
    TriggerServerEvent('cold-gangs:heists:Join', heistId)
end)

RegisterNetEvent('cold-gangs:client:HeistStarted', function(heistId, data)
    ActiveHeists[heistId] = data
    CreateHeistBlips()
    if PlayerGang and data.gangId == PlayerGang.id then
        QBCore.Functions.Notify("Heist started: " .. (data.heistType or "Heist"):gsub("_", " "):gsub("^%l", string.upper), "success", 10000)
        PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 1)
    end
end)

RegisterNetEvent('cold-gangs:client:HeistStageUpdated', function(heistId, stage)
    if not ActiveHeists[heistId] then return end
    ActiveHeists[heistId].currentStage = stage
    if currentHeist == heistId then currentStage = stage end
    if PlayerGang and ActiveHeists[heistId].gangId == PlayerGang.id then
        local heistType = ActiveHeists[heistId].heistType
        local stageName = "Unknown"
        if Config.HeistTypes[heistType] and Config.HeistTypes[heistType].stages and Config.HeistTypes[heistType].stages[stage] then
            stageName = Config.HeistTypes[heistType].stages[stage].name
        end
        QBCore.Functions.Notify("Heist stage updated: " .. stageName, "primary")
    end
end)

RegisterNetEvent('cold-gangs:client:HeistCompleted', function(heistId, rewards)
    if not ActiveHeists[heistId] then return end
    if PlayerGang and ActiveHeists[heistId].gangId == PlayerGang.id then
        QBCore.Functions.Notify("Heist completed! Rewards have been distributed.", "success", 10000)
        local rt = "Heist Rewards:\n"
        for item, amount in pairs(rewards.items or {}) do
            rt = rt .. item .. ": " .. amount .. "\n"
        end
        if rewards.money and rewards.money > 0 then rt = rt .. "Money: $" .. rewards.money .. "\n" end
        if rewards.reputation and rewards.reputation > 0 then rt = rt .. "Reputation: " .. rewards.reputation end
        QBCore.Functions.Notify(rt, "primary", 15000)
        PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 1)
        if currentHeist == heistId then currentHeist = nil currentStage = 0 heistTimer = 0 end
    end
    ActiveHeists[heistId] = nil
    if HeistBlips[heistId] then RemoveBlip(HeistBlips[heistId]) HeistBlips[heistId] = nil end
end)

RegisterNetEvent('cold-gangs:client:HeistFailed', function(heistId, reason)
    if not ActiveHeists[heistId] then return end
    if PlayerGang and ActiveHeists[heistId].gangId == PlayerGang.id then
        QBCore.Functions.Notify("Heist failed: " .. reason, "error", 10000)
        PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", 1)
        if currentHeist == heistId then currentHeist = nil currentStage = 0 heistTimer = 0 end
    end
    ActiveHeists[heistId] = nil
    if HeistBlips[heistId] then RemoveBlip(HeistBlips[heistId]) HeistBlips[heistId] = nil end
end)

RegisterNetEvent('cold-gangs:client:StartHeistMission', function(heistId)
    if not ActiveHeists[heistId] then QBCore.Functions.Notify("Heist not found", "error") return end
    if PlayerGang and ActiveHeists[heistId].gangId == PlayerGang.id then
        currentHeist = heistId
        currentStage = ActiveHeists[heistId].currentStage
        local heistType = ActiveHeists[heistId].heistType
        local cfg = Config.HeistTypes[heistType]
        if not cfg then QBCore.Functions.Notify("Invalid heist configuration", "error") return end
        local sc = cfg.stages and cfg.stages[currentStage]
        if not sc then QBCore.Functions.Notify("Invalid stage configuration", "error") return end
        heistTimer = sc.duration or 60000
        QBCore.Functions.Notify("Starting heist mission: " .. sc.name, "primary", 10000)
        CreateThread(function()
            while currentHeist and heistTimer > 0 do
                Wait(1000)
                heistTimer = heistTimer - 1000
                if heistTimer % 15000 == 0 then
                    QBCore.Functions.Notify("Time remaining: " .. math.floor(heistTimer / 1000) .. "s", "primary")
                end
            end
            if currentHeist and heistTimer <= 0 then
                TriggerServerEvent('cold-gangs:heists:CompleteStage', currentHeist)
            end
        end)
    end
end)

RegisterNetEvent('cold-gangs:client:CancelHeist', function(heistId)
    if not PlayerGang then QBCore.Functions.Notify("You need to be in a gang", "error") return end
    if not exports['cold-gangs']:HasGangPermission('manageHeists') then
        QBCore.Functions.Notify("You don't have permission to cancel heists", "error")
        return
    end
    if not ActiveHeists[heistId] then QBCore.Functions.Notify("Heist not found", "error") return end
    if ActiveHeists[heistId].gangId ~= PlayerGang.id then QBCore.Functions.Notify("This is not your gang's heist", "error") return end
    local dialog = exports['qb-input']:ShowInput({
        header = "Cancel Heist",
        submitText = "Confirm",
        inputs = { { text = "Are you sure you want to cancel this heist?", name = "confirm", type = "checkbox", isRequired = true } }
    })
    if dialog and dialog.confirm then
        TriggerServerEvent('cold-gangs:heists:Cancel', heistId)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, blip in pairs(HeistBlips) do RemoveBlip(blip) end
    HeistBlips = {}
end)
