local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}

-- ════════════════════════════════════════════════════════════════════════════════════
-- CACHE SYSTEM
-- ════════════════════════════════════════════════════════════════════════════════════

local GangStashes = {}
local SharedStashes = {}

-- ════════════════════════════════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ════════════════════════════════════════════════════════════════════════════════════

local function GetPlayerGangId(src)
    if ColdGangs.Core and ColdGangs.Core.GetPlayerGangId then 
        return ColdGangs.Core.GetPlayerGangId(src) 
    end
    
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil end
    
    local result = MySQL.query.await('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ? LIMIT 1', {
        Player.PlayerData.citizenid
    })
    
    return result and result[1] and tonumber(result[1].gang_id) or nil
end

local function HasPermission(src, permission)
    if ColdGangs.Permissions and ColdGangs.Permissions.HasGangPermission then
        return ColdGangs.Permissions.HasGangPermission(src, permission)
    end
    return false
end

local function LoadGangStash(gangId)
    if GangStashes[gangId] then return GangStashes[gangId] end
    
    local result = MySQL.query.await('SELECT * FROM cold_gang_stashes WHERE gang_id = ? LIMIT 1', {gangId})
    
    if result and result[1] then
        -- Read gang caps for defaults if fields are missing
        local caps = MySQL.query.await([[
          SELECT main_stash_slots, main_stash_weight FROM cold_gangs WHERE id = ? LIMIT 1
        ]], { gangId })

        local defaultSlots = (caps and caps[1] and tonumber(caps[1].main_stash_slots)) or (Config.Inventory.maxStashSlots or 50)
        local defaultWeight = (caps and caps[1] and tonumber(caps[1].main_stash_weight)) or (Config.Inventory.maxStashWeight or 1000000)

        local row = result[1]
        local slots = tonumber(row.slots) or defaultSlots
        local weight = tonumber(row.weight) or defaultWeight

        -- Heal bad rows in DB
        if row.slots == nil or row.weight == nil then
            MySQL.update.await('UPDATE cold_gang_stashes SET slots = ?, weight = ? WHERE id = ?', { slots, weight, row.id })
        end

        GangStashes[gangId] = {
            id = row.id,
            name = row.name or "Gang Stash",
            weight = weight,
            slots = slots,
            location = row.location
        }
    else
        -- Create default stash if doesn't exist
        local caps = MySQL.query.await([[
          SELECT main_stash_slots, main_stash_weight FROM cold_gangs WHERE id = ? LIMIT 1
        ]], { gangId })
        local mainSlots = (caps and caps[1] and tonumber(caps[1].main_stash_slots)) or (Config.Inventory.maxStashSlots or 50)
        local mainWeight = (caps and caps[1] and tonumber(caps[1].main_stash_weight)) or (Config.Inventory.maxStashWeight or 1000000)

        local id = MySQL.insert.await('INSERT INTO cold_gang_stashes (gang_id, name, weight, slots) VALUES (?, ?, ?, ?)', {
            gangId, "Gang Stash", mainWeight, mainSlots
        })
        
        GangStashes[gangId] = {
            id = id,
            name = "Gang Stash",
            weight = mainWeight,
            slots = mainSlots,
            location = nil
        }
    end
    
    return GangStashes[gangId]
end

local function LoadSharedStashes(gangId)
    if SharedStashes[gangId] then return SharedStashes[gangId] end
    
    local result = MySQL.query.await('SELECT * FROM cold_shared_stashes WHERE gang_id = ?', {gangId})
    
    SharedStashes[gangId] = {}
    
    if result then
        for _, stash in ipairs(result) do
            SharedStashes[gangId][stash.id] = {
                name = stash.name,
                location = stash.location,
                accessRanks = stash.access_ranks and json.decode(stash.access_ranks) or {},
                weight = stash.weight,
                slots = stash.slots
            }
        end
    end
    
    return SharedStashes[gangId]
end

local function SyncStashesToGang(gangId)
    local Players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(Players) do
        local playerGangId = GetPlayerGangId(Player.PlayerData.source)
        if playerGangId == gangId then
            TriggerClientEvent('cold-gangs:client:SyncStashes', Player.PlayerData.source)
        end
    end
end

-- ════════════════════════════════════════════════════════════════════════════════════
-- GANG STASH EVENTS
-- ════════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('cold-gangs:stashes:OpenGang', function()
    local src = source
    local gangId = GetPlayerGangId(src)
    
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
        return
    end
    
    local stash = LoadGangStash(gangId)
    
    if not stash then
        TriggerClientEvent('QBCore:Notify', src, 'Stash not found', 'error')
        return
    end
    
    -- Check if location is set
    if not stash.location then
        TriggerClientEvent('QBCore:Notify', src, 'Gang stash location not set. Leader must set it with /setgangstash', 'error')
        return
    end
    
    -- Verify player is near the stash
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return end
    
    local playerCoords = GetEntityCoords(ped)
    local location = type(stash.location) == 'string' and json.decode(stash.location) or stash.location
    
    if not location or not location.x then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid stash location', 'error')
        return
    end
    
    local distance = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - vector3(location.x, location.y, location.z))
    
    if distance > 3.0 then
        TriggerClientEvent('QBCore:Notify', src, 'You are too far from the stash', 'error')
        return
    end
    
    -- Open stash using Codem method
    local stashId = 'gang_stash_' .. gangId
    TriggerClientEvent('cold-gangs:client:OpenCodemStash', src, stashId, stash.slots or 50, stash.weight or 1000000, stash.name or 'Gang Stash')
end)

RegisterNetEvent('cold-gangs:stashes:SetMainLocation', function(location)
    local src = source
    local gangId = GetPlayerGangId(src)
    
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
        return
    end
    
    if not HasPermission(src, 'manageStashes') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission', 'error')
        return
    end
    
    if not location or not location.x then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid location', 'error')
        return
    end
    
    -- Update or create stash with location
    local existing = MySQL.query.await('SELECT id FROM cold_gang_stashes WHERE gang_id = ? LIMIT 1', {gangId})
    
    if existing and existing[1] then
        MySQL.update.await('UPDATE cold_gang_stashes SET location = ? WHERE gang_id = ?', {
            json.encode(location),
            gangId
        })
        
        if GangStashes[gangId] then
            GangStashes[gangId].location = json.encode(location)
        end
    else
        local id = MySQL.insert.await('INSERT INTO cold_gang_stashes (gang_id, name, weight, slots, location) VALUES (?, ?, ?, ?, ?)', {
            gangId,
            "Gang Stash",
            Config.Inventory.maxStashWeight or 1000000,
            Config.Inventory.maxStashSlots or 50,
            json.encode(location)
        })
        
        GangStashes[gangId] = {
            id = id,
            name = "Gang Stash",
            weight = Config.Inventory.maxStashWeight or 1000000,
            slots = Config.Inventory.maxStashSlots or 50,
            location = json.encode(location)
        }
    end
    
    TriggerClientEvent('cold-gangs:client:GangStashLocationSet', src)
    SyncStashesToGang(gangId)
end)

-- ════════════════════════════════════════════════════════════════════════════════════
-- SHARED STASH EVENTS
-- ════════════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('cold-gangs:stashes:OpenShared', function(stashId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local gangId = GetPlayerGangId(src)
    if not gangId then return end
    
    local sharedStashes = LoadSharedStashes(gangId)
    local stash = sharedStashes[stashId]
    
    if not stash then
        TriggerClientEvent('cold-gangs:client:StashAccessDenied', src)
        return
    end
    
    -- Verify player is near the stash
    local ped = GetPlayerPed(src)
    if not ped or ped <= 0 then return end
    
    local playerCoords = GetEntityCoords(ped)
    local location = type(stash.location) == 'string' and json.decode(stash.location) or stash.location
    
    if not location or not location.x then
        TriggerClientEvent('cold-gangs:client:StashAccessDenied', src)
        return
    end
    
    local distance = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - vector3(location.x, location.y, location.z))
    
    if distance > 3.0 then
        TriggerClientEvent('QBCore:Notify', src, 'You are too far from the stash', 'error')
        return
    end
    
    -- Check rank access
    local result = MySQL.query.await('SELECT rank FROM cold_gang_members WHERE citizen_id = ? LIMIT 1', {
        Player.PlayerData.citizenid
    })
    
    if not result or not result[1] then return end
    
    local playerRank = tonumber(result[1].rank) or 1
    local hasAccess = false
    
    for rankStr, allowed in pairs(stash.accessRanks or {}) do
        local rank = tonumber(rankStr)
        if rank and allowed and playerRank >= rank then
            hasAccess = true
            break
        end
    end
    
    if not hasAccess then
        TriggerClientEvent('cold-gangs:client:StashAccessDenied', src)
        return
    end
    
    -- Open stash using Codem method
    local stashKey = 'shared_stash_' .. stashId
    TriggerClientEvent('cold-gangs:client:OpenCodemStash', src, stashKey, stash.slots or 50, stash.weight or 1000000, stash.name or 'Shared Stash')
end)

RegisterNetEvent('cold-gangs:stashes:CreateShared', function(name, location, minRank)
    local src = source
    local gangId = GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
        return
    end
    if not HasPermission(src, 'manageStashes') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission', 'error')
        return
    end
    if not location or not location.x then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid location', 'error')
        return
    end

    -- Pull per-gang shared stash caps and limit
    local caps = MySQL.query.await([[
      SELECT shared_stash_slots, shared_stash_weight, shared_stash_limit_count
      FROM cold_gangs WHERE id = ? LIMIT 1
    ]], { gangId })
    local sharedSlots = (caps and caps[1] and tonumber(caps[1].shared_stash_slots)) or (Config.Inventory.maxStashSlots or 50)
    local sharedWeight = (caps and caps[1] and tonumber(caps[1].shared_stash_weight)) or (Config.Inventory.maxStashWeight or 1000000)
    local sharedLimit = (caps and caps[1] and tonumber(caps[1].shared_stash_limit_count)) or 0

    -- Enforce count limit if set
    if sharedLimit > 0 then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM cold_shared_stashes WHERE gang_id = ?', { gangId }) or 0
        if count >= sharedLimit then
            TriggerClientEvent('QBCore:Notify', src, ('Shared stash limit reached (%d)'):format(sharedLimit), 'error')
            return
        end
    end

    -- Validate rank (1-6)
    local rank = math.max(1, math.min(6, tonumber(minRank) or 1))

    -- Build access ranks
    local accessRanks = {}
    for r = rank, 6 do
        accessRanks[tostring(r)] = true
    end

    -- Insert
    local id = MySQL.insert.await('INSERT INTO cold_shared_stashes (gang_id, name, location, access_ranks, weight, slots) VALUES (?, ?, ?, ?, ?, ?)', {
        gangId,
        name or ('Shared Stash ' .. tostring(math.random(100, 999))),
        json.encode(location),
        json.encode(accessRanks),
        sharedWeight,
        sharedSlots
    })

    -- Cache
    if not SharedStashes[gangId] then SharedStashes[gangId] = {} end
    SharedStashes[gangId][id] = {
        name = name, location = json.encode(location),
        accessRanks = accessRanks,
        weight = sharedWeight, slots = sharedSlots
    }

    TriggerClientEvent('cold-gangs:client:SharedStashCreated', src, id, name)
    SyncStashesToGang(gangId)
end)

RegisterNetEvent('cold-gangs:stashes:DeleteShared', function(stashId)
    local src = source
    local gangId = GetPlayerGangId(src)
    
    if not gangId then return end
    
    if not HasPermission(src, 'manageStashes') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission', 'error')
        return
    end
    
    local sharedStashes = LoadSharedStashes(gangId)
    local stash = sharedStashes[stashId]
    
    if not stash then
        TriggerClientEvent('QBCore:Notify', src, 'Stash not found', 'error')
        return
    end
    
    -- Delete from database
    MySQL.update.await('DELETE FROM cold_shared_stashes WHERE id = ? AND gang_id = ?', {stashId, gangId})
    
    -- Update cache
    if SharedStashes[gangId] then
        SharedStashes[gangId][stashId] = nil
    end
    
    TriggerClientEvent('cold-gangs:client:SharedStashDeleted', src, stash.name)
    SyncStashesToGang(gangId)
end)

-- ════════════════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ════════════════════════════════════════════════════════════════════════════════════

QBCore.Functions.CreateCallback('cold-gangs:server:GetGangStash', function(source, cb, gangId)
    if not gangId then
        cb(nil)
        return
    end
    
    local stash = LoadGangStash(gangId)
    cb(stash)
end)

QBCore.Functions.CreateCallback('cold-gangs:server:GetSharedStashes', function(source, cb, gangId)
    if not gangId then
        cb({})
        return
    end
    
    local stashes = LoadSharedStashes(gangId)
    cb(stashes)
end)

-- ════════════════════════════════════════════════════════════════════════════════════
-- COMMANDS
-- ════════════════════════════════════════════════════════════════════════════════════

QBCore.Commands.Add('setgangstash', 'Set main gang stash location (Leader/Manager)', {}, false, function(source)
    local src = source
    local gangId = GetPlayerGangId(src)
    
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
        return
    end
    
    if not HasPermission(src, 'manageStashes') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to set stash location', 'error')
        return
    end
    
    TriggerClientEvent('cold-gangs:client:SetGangStashLocation', src)
end)

QBCore.Commands.Add('createsharedstash', 'Create a shared stash at your location (Manager)', {}, false, function(source)
    local src = source
    local gangId = GetPlayerGangId(src)
    
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
        return
    end
    
    if not HasPermission(src, 'manageStashes') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to create stashes', 'error')
        return
    end
    
    TriggerClientEvent('cold-gangs:client:PromptCreateSharedStash', src)
end)

QBCore.Commands.Add('deletesharedstash', 'Delete a shared stash (Manager)', {}, false, function(source)
    local src = source
    local gangId = GetPlayerGangId(src)
    
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, 'You are not in a gang', 'error')
        return
    end
    
    if not HasPermission(src, 'manageStashes') then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission to delete stashes', 'error')
        return
    end
    
    TriggerClientEvent('cold-gangs:client:DeleteSharedStashPrompt', src)
end)

-- ════════════════════════════════════════════════════════════════════════════════════
-- CACHE MANAGEMENT
-- ════════════════════════════════════════════════════════════════════════════════════

local function ClearGangCache(gangId)
    if GangStashes[gangId] then
        GangStashes[gangId] = nil
    end
    if SharedStashes[gangId] then
        SharedStashes[gangId] = nil
    end
end

local function ReloadGangStashes(gangId)
    ClearGangCache(gangId)
    LoadGangStash(gangId)
    LoadSharedStashes(gangId)
end

exports('GetGangStash', function(gangId)
    return LoadGangStash(gangId)
end)

exports('GetSharedStashes', function(gangId)
    return LoadSharedStashes(gangId)
end)

exports('ClearGangCache', ClearGangCache)
exports('ReloadGangStashes', ReloadGangStashes)

-- ════════════════════════════════════════════════════════════════════════════════════
-- ADMIN COMMANDS
-- ════════════════════════════════════════════════════════════════════════════════════

QBCore.Commands.Add('resetgangstash', 'Reset gang stash location (Admin)', {{name = 'gangid', help = 'Gang ID'}}, true, function(source, args)
    local src = source
    local gangId = tonumber(args[1])
    
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid gang ID', 'error')
        return
    end
    
    MySQL.update.await('UPDATE cold_gang_stashes SET location = NULL WHERE gang_id = ?', {gangId})
    ClearGangCache(gangId)
    
    TriggerClientEvent('QBCore:Notify', src, 'Gang stash location reset', 'success')
    SyncStashesToGang(gangId)
end, 'admin')

QBCore.Commands.Add('listsharedstashes', 'List all shared stashes for a gang (Admin)', {{name = 'gangid', help = 'Gang ID'}}, true, function(source, args)
    local src = source
    local gangId = tonumber(args[1])
    
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid gang ID', 'error')
        return
    end
    
    local stashes = LoadSharedStashes(gangId)
    
    if not stashes or next(stashes) == nil then
        TriggerClientEvent('QBCore:Notify', src, 'No shared stashes found for this gang', 'error')
        return
    end
    
    print('^3[Cold Gangs]^7 Shared Stashes for Gang ID: ' .. gangId)
    for id, stash in pairs(stashes) do
        print('^2ID:^7 ' .. id .. ' ^2Name:^7 ' .. stash.name)
    end
    
    TriggerClientEvent('QBCore:Notify', src, 'Check server console for stash list', 'primary')
end, 'admin')

QBCore.Commands.Add('clearstashcache', 'Clear stash cache for a gang (Admin)', {{name = 'gangid', help = 'Gang ID'}}, true, function(source, args)
    local src = source
    local gangId = tonumber(args[1])
    
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid gang ID', 'error')
        return
    end
    
    ClearGangCache(gangId)
    TriggerClientEvent('QBCore:Notify', src, 'Stash cache cleared for gang ' .. gangId, 'success')
end, 'admin')

-- ════════════════════════════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ════════════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(2000)
    print('^2[Cold Gangs]^7 Stash system initialized for Codem Inventory')
end)
