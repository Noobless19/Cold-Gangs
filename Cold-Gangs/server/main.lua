local QBCore = exports['qb-core']:GetCoreObject()

-- ======================
-- GLOBAL TABLES
-- ======================

Gangs = {}
GangMembers = {}
Territories = {}
GangBank = {}
GangReputations = {}
SharedStashes = {}
GangStashes = {}
DrugLabs = {}
DrugFields = {}
Businesses = {}
ActiveWars = {}
ActiveHeists = {}
GangVehicles = {}
PendingInvites = {}

-- ======================
-- CORE TABLE
-- ======================

Core = {}

-- ======================
-- DATA LOADING
-- ======================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(1000)
        print('^2Cold-Gangs^7: Loading data...')

        -- Load gangs
        local gangs = MySQL.query.await('SELECT * FROM cold_gangs')
        if gangs and #gangs > 0 then
            for _, g in ipairs(gangs) do
                Gangs[g.id] = {
                    id = g.id,
                    name = g.name,
                    tag = g.tag,
                    leader = g.leader,
                    level = g.level,
                    bank = g.bank or 0,
                    reputation = g.reputation or 0,
                    maxMembers = g.max_members or Config.MaxGangMembers,
                    created_at = g.created_at,
                    color = g.color,
                    logo = g.logo
                }
                GangBank[g.id] = g.bank
                GangReputations[g.id] = g.reputation
            end
        end

        -- Load members
        local members = MySQL.query.await('SELECT * FROM cold_gang_members')
        if members and #members > 0 then
            for _, m in ipairs(members) do
                if not GangMembers[m.gang_id] then GangMembers[m.gang_id] = {} end
                GangMembers[m.gang_id][m.citizen_id] = {
                    rank = m.rank,
                    joined_at = m.joined_at,
                    name = m.name
                }
            end
        end

        -- Load territories
        local territories = MySQL.query.await('SELECT * FROM cold_territories')
        if territories and #territories > 0 then
            for _, t in ipairs(territories) do
                Territories[t.name] = {
                    gangId = t.gang_id,
                    gangName = t.gang_name,
                    claimed_at = t.claimed_at,
                    income_generated = t.income_generated or 0
                }
            end
        end

        -- Load gang stashes
        local stashes = MySQL.query.await('SELECT * FROM cold_gang_stashes')
        if stashes and #stashes > 0 then
            for _, s in ipairs(stashes) do
                GangStashes[s.gang_id] = {
                    id = s.id,
                    name = s.name,
                    weight = s.weight,
                    slots = s.slots,
                    location = s.location and json.decode(s.location) or nil
                }
            end
        end

        -- Load shared stashes
        local sharedStashes = MySQL.query.await('SELECT * FROM cold_shared_stashes')
        if sharedStashes and #sharedStashes > 0 then
            for _, s in ipairs(sharedStashes) do
                if not SharedStashes[s.gang_id] then SharedStashes[s.gang_id] = {} end
                SharedStashes[s.gang_id][s.id] = {
                    name = s.name,
                    location = s.location and json.decode(s.location) or nil,
                    accessRanks = s.access_ranks and json.decode(s.access_ranks) or {},
                    weight = s.weight,
                    slots = s.slots
                }
            end
        end

        -- Load drug labs
        local labs = MySQL.query.await('SELECT * FROM cold_drug_labs')
        if labs and #labs > 0 then
            for _, l in ipairs(labs) do
                DrugLabs[l.id] = {
                    id = l.id,
                    territoryName = l.territory_name,
                    drugType = l.drug_type,
                    level = l.level,
                    capacity = l.capacity,
                    owner = l.owner,
                    gangName = l.gang_name,
                    location = l.location and json.decode(l.location) or nil,
                    security = l.security or 50,
                    lastUpdated = l.last_updated
                }
            end
        end

        -- Load drug fields
        local fields = MySQL.query.await('SELECT * FROM cold_drug_fields')
        if fields and #fields > 0 then
            for _, f in ipairs(fields) do
                DrugFields[f.id] = {
                    id = f.id,
                    territoryName = f.territory_name,
                    resourceType = f.resource_type,
                    growthStage = f.growth_stage or 0,
                    maxYield = f.max_yield,
                    qualityRangeMin = f.quality_range_min,
                    qualityRangeMax = f.quality_range_max,
                    owner = f.owner,
                    gangName = f.gang_name,
                    location = f.location and json.decode(f.location) or nil,
                    lastUpdated = f.last_updated
                }
            end
        end

        -- Load businesses
        local businesses = MySQL.query.await('SELECT * FROM cold_gang_businesses')
        if businesses and #businesses > 0 then
            for _, b in ipairs(businesses) do
                Businesses[b.id] = {
                    id = b.id,
                    gangId = b.gang_id,
                    type = b.type,
                    level = b.level,
                    income = b.income,
                    income_stored = b.income_stored or 0,
                    last_payout = b.last_payout,
                    location = b.location and json.decode(b.location) or nil,
                    employees = b.employees or 0,
                    security = b.security or 1,
                    capacity = b.capacity or 5,
                    last_income_update = b.last_income_update
                }
            end
        end

        -- Load active wars
        local wars = MySQL.query.await('SELECT * FROM cold_active_wars WHERE status = "active"')
        if wars and #wars > 0 then
            for _, w in ipairs(wars) do
                ActiveWars[w.id] = {
                    id = w.id,
                    attackerId = w.attacker_id,
                    defenderId = w.defender_id,
                    attackerName = w.attacker_name,
                    defenderName = w.defender_name,
                    territoryName = w.territory_name,
                    startedAt = w.started_at,
                    attackerScore = w.attacker_score or 0,
                    defenderScore = w.defender_score or 0,
                    maxScore = w.max_score or 100,
                    status = w.status or 'active'
                }
            end
        end

        -- Load active heists
        local heists = MySQL.query.await('SELECT * FROM cold_active_heists WHERE status = "active"')
        if heists and #heists > 0 then
            for _, h in ipairs(heists) do
                ActiveHeists[h.id] = {
                    id = h.id,
                    heistType = h.heist_type,
                    gangId = h.gang_id,
                    status = h.status,
                    startTime = h.start_time,
                    participants = h.participants and json.decode(h.participants) or {},
                    currentStage = h.current_stage or 1,
                    rewards = h.rewards and json.decode(h.rewards) or {},
                    location = h.location and json.decode(h.location) or nil
                }
            end
        end

        -- Load gang vehicles
        local vehicles = MySQL.query.await('SELECT * FROM cold_gang_vehicles')
        if vehicles and #vehicles > 0 then
            for _, v in ipairs(vehicles) do
                GangVehicles[v.plate] = {
                    plate = v.plate,
                    gangId = v.gang_id,
                    model = v.model,
                    label = v.label,
                    stored = v.stored == 1,
                    impounded = v.impounded == 1,
                    lastSeen = v.last_seen,
                    location = v.location and json.decode(v.location) or nil
                }
            end
        end

        print(('^2Cold-Gangs^7: Loaded %s gangs, %s members, %s territories'):format(
            TableLength(Gangs),
            TableLength(GangMembers),
            TableLength(Territories)
        ))

        -- ======================
        -- CORE FUNCTIONS
        -- ======================

        Core.GetAllGangs = function() return Gangs end
        Core.GetAllTerritories = function() return Territories end
        Core.GetAllGangBanks = function() return GangBank end
        Core.GetGangById = function(gangId) return Gangs[gangId] end
        Core.GetGangMembers = function(gangId) return GangMembers[gangId] or {} end

        Core.NotifyGangMembers = function(gangId, title, message)
            local members = GangMembers[gangId]
            if not members then return end
            for citizenId in pairs(members) do
                local Player = QBCore.Functions.GetPlayerByCitizenId(citizenId)
                if Player then
                    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, title .. ": " .. message, "primary")
                end
            end
        end

        Core.AddGangMoney = function(gangId, amount, reason)
            if not Gangs[gangId] or amount <= 0 then return false end

            GangBank[gangId] = (GangBank[gangId] or 0) + amount
            Gangs[gangId].bank = GangBank[gangId]

            MySQL.update('UPDATE cold_gangs SET bank = ? WHERE id = ?', {GangBank[gangId], gangId})
            MySQL.insert('INSERT INTO cold_gang_transactions (gang_id, amount, description, timestamp) VALUES (?, ?, ?, NOW())', {
                gangId, amount, reason or 'Unknown'
            })

            return true
        end

        Core.RemoveGangMoney = function(gangId, amount, reason)
            if not Gangs[gangId] or amount <= 0 then return false end
            if (GangBank[gangId] or 0) < amount then return false end

            GangBank[gangId] = GangBank[gangId] - amount
            Gangs[gangId].bank = GangBank[gangId]

            MySQL.update('UPDATE cold_gangs SET bank = ? WHERE id = ?', {GangBank[gangId], gangId})
            MySQL.insert('INSERT INTO cold_gang_transactions (gang_id, amount, description, timestamp) VALUES (?, ?, ?, NOW())', {
                gangId, -amount, reason or 'Unknown'
            })

            return true
        end

        Core.AddGangReputation = function(gangId, amount)
            if not Gangs[gangId] then return false end
            
            Gangs[gangId].reputation = (Gangs[gangId].reputation or 0) + amount
            GangReputations[gangId] = Gangs[gangId].reputation
            
            MySQL.update('UPDATE cold_gangs SET reputation = ? WHERE id = ?', {Gangs[gangId].reputation, gangId})
            return true
        end

        Core.GetPlayerGangId = function(src)
            local Player = QBCore.Functions.GetPlayer(src)
            if not Player then return nil end
            local citizenId = Player.PlayerData.citizenid
            for gangId, members in pairs(GangMembers) do
                if members[citizenId] then return gangId end
            end
            return nil
        end

        Core.GetPlayerGangRank = function(src)
            local Player = QBCore.Functions.GetPlayer(src)
            if not Player then return nil end
            local citizenId = Player.PlayerData.citizenid
            for gangId, members in pairs(GangMembers) do
                if members[citizenId] then
                    return members[citizenId].rank
                end
            end
            return nil
        end

        Core.HasGangPermission = function(src, perm)
            local gangId = Core.GetPlayerGangId(src)
            if not gangId then return false end
            
            local Player = QBCore.Functions.GetPlayer(src)
            if not Player then return false end
            
            local citizenId = Player.PlayerData.citizenid
            local members = GangMembers[gangId]
            if not members or not members[citizenId] then return false end
            
            local rank = members[citizenId].rank
            local rankData = Config.Gangs.Ranks[rank]
            if not rankData then return false end
            
            -- Check if player is gang leader
            if Gangs[gangId].leader == citizenId then return true end
            
            -- Check permission
            local permKey = 'can' .. perm:sub(1,1):upper() .. perm:sub(2)
            return rankData[permKey] == true
        end

        Core.IsPlayerAdmin = function(src)
            local Player = QBCore.Functions.GetPlayer(src)
            if not Player then return false end
            
            -- Check admin groups
            for _, group in ipairs(Config.Admin.adminGroups) do
                if Player.PlayerData.group == group then
                    return true
                end
            end
            
            -- Check admin citizen IDs
            for _, adminId in ipairs(Config.Admin.adminCitizenIds) do
                if Player.PlayerData.citizenid == adminId then
                    return true
                end
            end
            
            return false
        end

        -- ======================
        -- EXPORTS
        -- ======================

        exports('GetAllGangs', Core.GetAllGangs)
        exports('GetAllTerritories', Core.GetAllTerritories)
        exports('GetAllGangBanks', Core.GetAllGangBanks)
        exports('GetGangById', Core.GetGangById)
        exports('GetGangMembers', Core.GetGangMembers)
        exports('NotifyGangMembers', Core.NotifyGangMembers)
        exports('AddGangMoney', Core.AddGangMoney)
        exports('RemoveGangMoney', Core.RemoveGangMoney)
        exports('AddGangReputation', Core.AddGangReputation)
        exports('GetPlayerGangId', Core.GetPlayerGangId)
        exports('GetPlayerGangRank', Core.GetPlayerGangRank)
        exports('HasGangPermission', Core.HasGangPermission)
        exports('IsPlayerAdmin', Core.IsPlayerAdmin)
    end)
end)

-- ======================
-- UTILITY FUNCTIONS
-- ======================

function TableLength(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

function FormatMoney(amount)
    if amount == nil or amount == 0 then return "$0" end
    local formatted = tostring(math.floor(amount))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return "$" .. formatted
end

function FormatDuration(seconds)
    if seconds <= 0 then return "0s" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    local str = ""
    if days > 0 then str = str .. days .. "d " end
    if hours > 0 then str = str .. hours .. "h " end
    if mins > 0 then str = str .. mins .. "m " end
    if secs > 0 or str == "" then str = str .. secs .. "s" end
    return str
end

