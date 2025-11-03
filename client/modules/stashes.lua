local QBCore = exports['qb-core']:GetCoreObject()

local PlayerGang = nil
local GangStash = nil
local SharedStashes = {}
local StashZones = {}
local isLoggedIn = false

local STASH_INTERACT_DISTANCE = 2.5
local STASH_MARKER_DISTANCE = 10.0

local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function ParseLocation(loc)
    if not loc then return nil end
    if type(loc) == 'string' then
        local ok, decoded = pcall(json.decode, loc)
        return ok and decoded or nil
    end
    return loc
end

local function CreateStashBlip(coords, name, color, sprite)
    if not coords or not coords.x then return nil end
    local blip = AddBlipForCoord(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    SetBlipSprite(blip, sprite or 478)
    SetBlipColour(blip, color or 2)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(name or "Stash")
    EndTextCommandSetBlipName(blip)
    return blip
end

local function ClearAllStashZones()
    for _, zone in pairs(StashZones) do
        if zone.blip and DoesBlipExist(zone.blip) then
            RemoveBlip(zone.blip)
        end
    end
    StashZones = {}
end

local function SetupGangStash()
    if not PlayerGang or not PlayerGang.id then return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangStash', function(stash)
        if not stash then return end
        GangStash = stash
        local location = ParseLocation(stash.location)
        if location and location.x then
            if StashZones['main'] then
                if StashZones['main'].blip and DoesBlipExist(StashZones['main'].blip) then
                    RemoveBlip(StashZones['main'].blip)
                end
            end
            StashZones['main'] = {
                type = 'gang',
                coords = vector3(location.x, location.y, location.z),
                name = stash.name or "Gang Stash",
                stashId = 'gang_stash_' .. PlayerGang.id,
                slots = stash.slots or 50,
                weight = stash.weight or 1000000,
                blip = CreateStashBlip(location, "Gang Stash", 2, 478)
            }
        end
    end, PlayerGang.id)
end

local function SetupSharedStashes()
    if not PlayerGang or not PlayerGang.id then return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetSharedStashes', function(stashes)
        if not stashes then return end
        SharedStashes = stashes
        for key, zone in pairs(StashZones) do
            if zone.type == 'shared' then
                if zone.blip and DoesBlipExist(zone.blip) then
                    RemoveBlip(zone.blip)
                end
                StashZones[key] = nil
            end
        end
        for stashId, stash in pairs(stashes) do
            local location = ParseLocation(stash.location)
            if location and location.x then
                StashZones['shared_' .. stashId] = {
                    type = 'shared',
                    id = stashId,
                    coords = vector3(location.x, location.y, location.z),
                    name = stash.name or "Shared Stash",
                    stashId = 'shared_stash_' .. stashId,
                    slots = stash.slots or 50,
                    weight = stash.weight or 1000000,
                    blip = CreateStashBlip(location, stash.name or "Shared Stash", 3, 478)
                }
            end
        end
    end, PlayerGang.id)
end

RegisterNetEvent('cold-gangs:client:SetGangStashLocation', function()
    if not PlayerGang then
        QBCore.Functions.Notify("You are not in a gang", "error")
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local stashData = { x = coords.x, y = coords.y, z = coords.z, h = heading }
    TriggerServerEvent('cold-gangs:stashes:SetMainLocation', stashData)
end)

RegisterNetEvent('cold-gangs:client:OpenCodemStash', function(stashId, slots, weight, label)
    local ok = pcall(function()
        TriggerServerEvent('codem-inventory:server:openstash', stashId, tonumber(slots) or 50, tonumber(weight) or 100000, label or 'Stash')
    end)
    if not ok then
        print(('[Cold Gangs] codem-inventory:server:openstash failed for %s'):format(stashId))
    end
end)

RegisterNetEvent('cold-gangs:client:PromptCreateSharedStash', function()
    if not PlayerGang then
        QBCore.Functions.Notify("You are not in a gang", "error")
        return
    end
    local dialog = exports['qb-input']:ShowInput({
        header = "Create Shared Stash",
        submitText = "Create",
        inputs = {
            { text = "Stash Name", name = "name", type = "text", isRequired = true, default = "Shared Stash" },
            { text = "Minimum Rank (1-6)", name = "minRank", type = "number", isRequired = true, default = 1 }
        }
    })
    if dialog and dialog.name then
        local name = dialog.name
        local minRank = tonumber(dialog.minRank) or 1
        if minRank < 1 then minRank = 1 end
        if minRank > 6 then minRank = 6 end
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local stashData = { x = coords.x, y = coords.y, z = coords.z }
        TriggerServerEvent('cold-gangs:stashes:CreateShared', name, stashData, minRank)
    end
end)

RegisterNetEvent('cold-gangs:client:DeleteSharedStashPrompt', function()
    if not PlayerGang then
        QBCore.Functions.Notify("You are not in a gang", "error")
        return
    end
    local ped = PlayerPedId()
    local playerPos = GetEntityCoords(ped)
    local nearbyStashes = {}
    for key, zone in pairs(StashZones) do
        if zone.type == 'shared' then
            local distance = #(playerPos - zone.coords)
            if distance < 5.0 then
                table.insert(nearbyStashes, { id = zone.id, name = zone.name, distance = distance })
            end
        end
    end
    if #nearbyStashes == 0 then
        QBCore.Functions.Notify("No shared stashes nearby", "error")
        return
    end
    table.sort(nearbyStashes, function(a, b) return a.distance < b.distance end)
    local menuOptions = {}
    for _, stash in ipairs(nearbyStashes) do
        table.insert(menuOptions, {
            header = stash.name,
            txt = "Distance: " .. string.format("%.1f", stash.distance) .. "m",
            icon = "fas fa-trash",
            params = { isServer = false, event = "cold-gangs:client:ConfirmDeleteSharedStash", args = { id = stash.id, name = stash.name } }
        })
    end
    table.insert(menuOptions, { header = "← Back", icon = "fas fa-angle-left", params = { event = "cold-gangs:client:OpenGangMenu" } })
    exports['qb-menu']:openMenu(menuOptions)
end)

RegisterNetEvent('cold-gangs:client:ConfirmDeleteSharedStash', function(data)
    local alert = lib.alertDialog({
        header = 'Delete Shared Stash',
        content = 'Are you sure you want to delete "' .. data.name .. '"?',
        centered = true,
        cancel = true
    })
    if alert == 'confirm' then
        TriggerServerEvent('cold-gangs:stashes:DeleteShared', data.id)
    end
end)

RegisterNetEvent('cold-gangs:client:SharedStashCreated', function()
    Wait(500)
    SetupSharedStashes()
end)

RegisterNetEvent('cold-gangs:client:SharedStashDeleted', function()
    Wait(500)
    SetupSharedStashes()
end)

RegisterNetEvent('cold-gangs:client:StashAccessDenied', function()
    QBCore.Functions.Notify("You don't have access to this stash", "error")
end)

RegisterNetEvent('cold-gangs:client:SyncStashes', function()
    if not isLoggedIn or not PlayerGang then return end
    SetupGangStash()
    SetupSharedStashes()
end)

RegisterNetEvent('cold-gangs:client:GangStashLocationSet', function()
    QBCore.Functions.Notify("Gang stash location set successfully", "success")
    Wait(500)
    SetupGangStash()
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if isLoggedIn and PlayerGang then
            local ped = PlayerPedId()
            local playerPos = GetEntityCoords(ped)
            for _, zone in pairs(StashZones) do
                local distance = #(playerPos - zone.coords)
                if distance < STASH_MARKER_DISTANCE then
                    sleep = 0
                    local markerColor = zone.type == 'gang' and {0, 255, 0, 150} or {0, 150, 255, 150}
                    DrawMarker(2, zone.coords.x, zone.coords.y, zone.coords.z + 1.0, 0, 0, 0, 0, 0, 0, 0.3, 0.3, 0.3, markerColor[1], markerColor[2], markerColor[3], markerColor[4], false, false, 2, true, nil, nil, false)
                    if distance < STASH_INTERACT_DISTANCE then
                        local label = zone.type == 'gang' and '[~g~E~w~] ' or '[~b~E~w~] '
                        DrawText3D(zone.coords.x, zone.coords.y, zone.coords.z + 0.5, label .. zone.name)
                        if IsControlJustReleased(0, 38) then
                            if zone.type == 'gang' then
                                TriggerServerEvent('cold-gangs:stashes:OpenGang')
                            elseif zone.type == 'shared' then
                                TriggerServerEvent('cold-gangs:stashes:OpenShared', zone.id)
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterCommand('debugstashzones', function()
    for key, zone in pairs(StashZones) do
        print(key..': type='..zone.type..' name='..zone.name..' coords='..zone.coords.x..','..zone.coords.y..','..zone.coords.z)
    end
    if PlayerGang then
        print('Player Gang ID: '..tostring(PlayerGang.id))
    else
        print('Player Gang: NONE')
    end
    QBCore.Functions.Notify('Check F8 console for debug info', 'primary')
end, false)

RegisterCommand('reloadstashes', function()
    if not PlayerGang then
        QBCore.Functions.Notify("You are not in a gang", "error")
        return
    end
    ClearAllStashZones()
    Wait(500)
    SetupGangStash()
    SetupSharedStashes()
    QBCore.Functions.Notify("Stashes reloaded", "success")
end, false)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(100)
    end
    Wait(2000)
    isLoggedIn = true
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gang)
        if gang and gang.id then
            PlayerGang = gang
            SetupGangStash()
            SetupSharedStashes()
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    ClearAllStashZones()
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    ClearAllStashZones()
    isLoggedIn = false
    PlayerGang = nil
    GangStash = nil
    SharedStashes = {}
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    isLoggedIn = true
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gang)
        if gang and gang.id then
            PlayerGang = gang
            SetupGangStash()
            SetupSharedStashes()
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
    ClearAllStashZones()
    PlayerGang = gang
    if gang and gang.name then
        Wait(500)
        SetupGangStash()
        SetupSharedStashes()
    end
end)
