local QBCore = exports['qb-core']:GetCoreObject()

-- ======================
-- OPEN STASHES
-- ======================

-- Open Gang Stash
RegisterNetEvent('cold-gangs:server:OpenGangStash', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not GangStashes[gangId] then
        TriggerClientEvent('QBCore:Notify', src, "Your gang has no stash", "error")
        return
    end

    -- Prepare stash data
    local stashId = 'gang_stash_' .. gangId
    local stashData = GangStashes[gangId]

    -- Trigger inventory
    TriggerClientEvent('inventory:client:OpenInventory', src, 'stash', stashId, {
        maxweight = stashData.weight,
        slots = stashData.slots
    })
    TriggerClientEvent('QBCore:Notify', src, "Opened " .. stashData.name, "success")
end)

-- Open Shared Stash
RegisterNetEvent('cold-gangs:server:OpenSharedStash', function(stashId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    if not SharedStashes[gangId] or not SharedStashes[gangId][stashId] then
        TriggerClientEvent('QBCore:Notify', src, "Stash not found", "error")
        return
    end

    local stash = SharedStashes[gangId][stashId]
    local playerRank = exports['cold-gangs']:GetPlayerGangRank(src)

    -- Check rank permission
    local hasAccess = false
    for rank, allowed in pairs(stash.accessRanks) do
        if tonumber(rank) <= playerRank and allowed then
            hasAccess = true
            break
        end
    end

    if not hasAccess then
        TriggerClientEvent('cold-gangs:client:StashAccessDenied', src)
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to access this stash", "error")
        return
    end

    -- Open inventory
    TriggerClientEvent('inventory:client:OpenInventory', src, 'stash', 'shared_stash_' .. stashId, {
        maxweight = stash.weight,
        slots = stash.slots
    })
    TriggerClientEvent('QBCore:Notify', src, "Opened " .. stash.name, "success")
end)

-- ======================
-- CREATE STASHES
-- ======================

-- Create Shared Stash
RegisterNetEvent('cold-gangs:server:CreateSharedStash', function(gangId, name, location, accessRanks)
    local src = source
    if not exports['cold-gangs']:IsPlayerAdmin(src) and not exports['cold-gangs']:HasGangPermission(src, 'manageStashes') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to create stashes", "error")
        return
    end

    if not Gangs[gangId] then
        TriggerClientEvent('QBCore:Notify', src, "Invalid gang ID", "error")
        return
    end

    -- Insert into DB
    local stashId = MySQL.insert.await('INSERT INTO cold_shared_stashes (gang_id, name, location, access_ranks, weight, slots) VALUES (?, ?, ?, ?, ?, ?)', {
        gangId,
        name,
        json.encode(location),
        json.encode(accessRanks),
        Config.Inventory.maxStashWeight,
        Config.Inventory.maxStashSlots
    })

    if not SharedStashes[gangId] then SharedStashes[gangId] = {} end
    SharedStashes[gangId][stashId] = {
        name = name,
        location = json.encode(location),
        accessRanks = accessRanks,
        weight = Config.Inventory.maxStashWeight,
        slots = Config.Inventory.maxStashSlots
    }

    -- Notify
    Core.NotifyGangMembers(gangId, "Stash Created", "A new shared stash has been created: " .. name)
    TriggerClientEvent('QBCore:Notify', src, "Shared stash created: " .. name, "success")
    TriggerClientEvent('cold-gangs:client:SharedStashCreated', src, stashId, name)
end)

-- ======================
-- DELETE STASHES
-- ======================

-- Delete Shared Stash
RegisterNetEvent('cold-gangs:server:DeleteSharedStash', function(stashId)
    local src = source
    if not exports['cold-gangs']:IsPlayerAdmin(src) and not exports['cold-gangs']:HasGangPermission(src, 'manageStashes') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission", "error")
        return
    end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not SharedStashes[gangId] or not SharedStashes[gangId][stashId] then
        TriggerClientEvent('QBCore:Notify', src, "Stash not found", "error")
        return
    end

    -- Remove from DB
    MySQL.query('DELETE FROM cold_shared_stashes WHERE id = ?', {stashId})

    -- Remove from memory
    local stashName = SharedStashes[gangId][stashId].name
    SharedStashes[gangId][stashId] = nil

    TriggerClientEvent('QBCore:Notify', src, "Shared stash deleted: " .. stashName, "success")
end)

-- ======================
-- CALLBACKS
-- ======================

-- Get gang stash
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangStash', function(source, cb, gangId)
    cb(GangStashes[gangId])
end)

-- Get shared stashes
QBCore.Functions.CreateCallback('cold-gangs:server:GetSharedStashes', function(source, cb, gangId)
    cb(SharedStashes[gangId] or {})
end)

-- ======================
-- EXPORTS
-- ======================

-- Get stash by ID
function GetSharedStash(stashId)
    for gangId, stashes in pairs(SharedStashes) do
        if stashes[stashId] then
            return stashes[stashId]
        end
    end
    return nil
end

-- Get gang stash
function GetGangStash(gangId)
    return GangStashes[gangId]
end

-- Register exports
exports('GetSharedStash', GetSharedStash)
exports('GetGangStash', GetGangStash)

-- Sync stashes to client
RegisterNetEvent('cold-gangs:server:SyncStashes', function()
    TriggerClientEvent('cold-gangs:client:SyncStashes', -1, GangStashes, SharedStashes)
end)

-- Periodic sync
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        TriggerClientEvent('cold-gangs:client:SyncStashes', -1, GangStashes, SharedStashes)
    end
end)
