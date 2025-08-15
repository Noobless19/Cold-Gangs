local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayerGang = nil
local GangStashes = {}
local SharedStashes = {}
local StashBlips = {}

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

    -- Sync stashes
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangStash', function(stash)
        GangStashes = stash or {}
    end, PlayerGang and PlayerGang.id)

    QBCore.Functions.TriggerCallback('cold-gangs:server:GetSharedStashes', function(stashes)
        SharedStashes = stashes or {}
        CreateStashBlips()
    end, PlayerGang and PlayerGang.id)
end)

-- Sync stashes from server
RegisterNetEvent('cold-gangs:client:SyncStashes', function(gangStashes, sharedStashes)
    GangStashes = gangStashes or {}
    SharedStashes = sharedStashes or {}
    CreateStashBlips()
end)

-- Create Stash Blips
function CreateStashBlips()
    -- Clear old blips
    for _, blip in pairs(StashBlips) do
        RemoveBlip(blip)
    end
    StashBlips = {}

    -- Main stash
    if GangStashes and GangStashes.location then
        local coords = json.decode(GangStashes.location)
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 478)
        SetBlipColour(blip, 2)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Gang Stash")
        EndTextCommandSetBlipName(blip)
        StashBlips["main"] = blip
    end

    -- Shared stashes
    if SharedStashes then
        for id, stash in pairs(SharedStashes) do
            if stash.location then
                local coords = json.decode(stash.location)
                local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
                SetBlipSprite(blip, 478)
                SetBlipColour(blip, 3)
                SetBlipScale(blip, 0.6)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString("Shared Stash: " .. stash.name)
                EndTextCommandSetBlipName(blip)
                StashBlips[id] = blip
            end
        end
    end
end

-- Create Shared Stash
RegisterNetEvent('cold-gangs:client:CreateSharedStash', function(name, minRank)
    if not PlayerGang then
        QBCore.Functions.Notify("You need to be in a gang", "error")
        return
    end
    
    if not exports['cold-gangs']:HasGangPermission('manageStashes') then
        QBCore.Functions.Notify("You don't have permission to create stashes", "error")
        return
    end
    
    -- Get player position
    local coords = GetEntityCoords(PlayerPedId())
    
    -- Create access ranks
    local accessRanks = {}
    for i = minRank, 6 do
        accessRanks[i] = true
    end
    
    -- Create stash
    TriggerServerEvent('cold-gangs:server:CreateSharedStash', PlayerGang.id, name, coords, accessRanks)
end)

-- Stash Access Denied
RegisterNetEvent('cold-gangs:client:StashAccessDenied', function()
    QBCore.Functions.Notify("You don't have access to this stash", "error")
end)

-- Shared Stash Created
RegisterNetEvent('cold-gangs:client:SharedStashCreated', function(stashId, name)
    QBCore.Functions.Notify("Shared stash created: " .. name, "success")
end)

-- Draw 3D text for stashes
CreateThread(function()
    while true do
        Wait(0)
        
        if isLoggedIn and PlayerGang then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local sleep = true
            
            -- Main stash
            if GangStashes and GangStashes.location then
                local stashCoords = json.decode(GangStashes.location)
                local distance = #(playerCoords - vector3(stashCoords.x, stashCoords.y, stashCoords.z))
                
                if distance < 10.0 then
                    sleep = false
                    Draw3DText(stashCoords.x, stashCoords.y, stashCoords.z + 1.0, "Gang Stash")
                    
                    if distance < 2.0 then
                        Draw3DText(stashCoords.x, stashCoords.y, stashCoords.z + 0.5, "Press [E] to access")
                        
                        if IsControlJustPressed(0, 38) then -- E key
                            TriggerServerEvent('cold-gangs:server:OpenGangStash')
                        end
                    end
                end
            end
            
            -- Shared stashes
            for id, stash in pairs(SharedStashes) do
                if stash.location then
                    local stashCoords = json.decode(stash.location)
                    local distance = #(playerCoords - vector3(stashCoords.x, stashCoords.y, stashCoords.z))
                    
                    if distance < 10.0 then
                        sleep = false
                        Draw3DText(stashCoords.x, stashCoords.y, stashCoords.z + 1.0, "Shared Stash: " .. stash.name)
                        
                        if distance < 2.0 then
                            Draw3DText(stashCoords.x, stashCoords.y, stashCoords.z + 0.5, "Press [E] to access")
                            
                            if IsControlJustPressed(0, 38) then -- E key
                                TriggerServerEvent('cold-gangs:server:OpenSharedStash', id)
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
    
    for _, blip in pairs(StashBlips) do
        RemoveBlip(blip)
    end
    StashBlips = {}
end)
