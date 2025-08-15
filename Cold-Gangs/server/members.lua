local QBCore = exports['qb-core']:GetCoreObject()

-- ======================
-- INVITE SYSTEM
-- ======================

-- Invite Player to Gang
RegisterNetEvent('cold-gangs:server:InvitePlayerToGang', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', src, "Player not found", "error")
        return
    end

    -- Get player's gang
    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    -- Check permission
    if not exports['cold-gangs']:HasGangPermission(src, 'inviteMembers') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to invite members", "error")
        return
    end

    -- Check if target is already in a gang
    if exports['cold-gangs']:GetPlayerGangId(targetId) then
        TriggerClientEvent('QBCore:Notify', src, "This player is already in a gang", "error")
        return
    end

    -- Check if target already has a pending invite
    if PendingInvites and PendingInvites[targetId] then
        TriggerClientEvent('QBCore:Notify', src, "This player already has a pending invite", "error")
        return
    end

    -- Enforce member limit
    local currentMemberCount = TableLength(GangMembers[gangId] or {})
    local maxMembers = (Gangs[gangId] and Gangs[gangId].maxMembers) or Config.MaxGangMembers
    if currentMemberCount >= maxMembers then
        TriggerClientEvent('QBCore:Notify', src, "Your gang is full (" .. currentMemberCount .. "/" .. maxMembers .. ")", "error")
        return
    end

    -- Send invite
    TriggerClientEvent('cold-gangs:client:ReceiveGangInvite', targetId, Gangs[gangId].name, Gangs[gangId].tag)

    -- Store pending invite
    if not PendingInvites then PendingInvites = {} end
    PendingInvites[targetId] = {
        gangId = gangId,
        inviter = Player.PlayerData.citizenid,
        timestamp = os.time(),
        expires = os.time() + (Config.InvitationExpireTime / 1000)
    }

    TriggerClientEvent('QBCore:Notify', src, "Invite sent to " .. targetPlayer.PlayerData.charinfo.firstname .. " " .. targetPlayer.PlayerData.charinfo.lastname, "success")
end)

-- Accept Gang Invite
RegisterNetEvent('cold-gangs:server:AcceptGangInvite', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not PendingInvites or not PendingInvites[src] then
        TriggerClientEvent('QBCore:Notify', src, "You have no pending invites", "error")
        return
    end

    local invite = PendingInvites[src]
    local gangId = invite.gangId

    if not Gangs[gangId] then
        TriggerClientEvent('QBCore:Notify', src, "Gang no longer exists", "error")
        PendingInvites[src] = nil
        return
    end

    -- Check if invite expired
    if invite.expires < os.time() then
        TriggerClientEvent('QBCore:Notify', src, "Invite has expired", "error")
        PendingInvites[src] = nil
        return
    end

    -- Re-check member limit
    local currentMemberCount = TableLength(GangMembers[gangId])
    if currentMemberCount >= Gangs[gangId].maxMembers then
        TriggerClientEvent('QBCore:Notify', src, "This gang is full", "error")
        PendingInvites[src] = nil
        return
    end

    -- Add to DB
    local name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    MySQL.insert('INSERT INTO cold_gang_members (gang_id, citizen_id, rank, name, joined_at) VALUES (?, ?, ?, ?, NOW())', {
        gangId,
        Player.PlayerData.citizenid,
        1, -- Recruit
        name
    })

    -- Add to memory
    if not GangMembers[gangId] then GangMembers[gangId] = {} end
    GangMembers[gangId][Player.PlayerData.citizenid] = {
        rank = 1,
        name = name,
        joined_at = os.date('%Y-%m-%d %H:%M:%S')
    }

    -- Clear invite
    PendingInvites[src] = nil

    -- Notify
    Core.NotifyGangMembers(gangId, "New Member", Player.PlayerData.charinfo.firstname .. " has joined the gang!")
    TriggerClientEvent('QBCore:Notify', src, "Welcome to " .. Gangs[gangId].name .. "!", "success")

    -- Sync client
    TriggerClientEvent('cold-gangs:client:PlayerJoinedGang', src, {
        id = gangId,
        name = Gangs[gangId].name,
        tag = Gangs[gangId].tag,
        rank = 1,
        isLeader = false
    })
end)

-- Decline Gang Invite
RegisterNetEvent('cold-gangs:server:DeclineGangInvite', function()
    local src = source
    if PendingInvites and PendingInvites[src] then
        PendingInvites[src] = nil
        TriggerClientEvent('QBCore:Notify', src, "You declined the invite", "primary")
    end
end)

-- ======================
-- KICK MEMBER
-- ======================

-- Kick Member
RegisterNetEvent('cold-gangs:server:KickMember', function(targetCitizenId, reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Get player's gang
    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then return end

    -- Check if target is in same gang
    if not GangMembers[gangId][targetCitizenId] then
        TriggerClientEvent('QBCore:Notify', src, "This player is not in your gang", "error")
        return
    end

    -- Check permission
    if not exports['cold-gangs']:HasGangPermission(src, 'kickMembers') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to kick members", "error")
        return
    end

    -- Can't kick leader unless you're admin
    if Gangs[gangId].leader == targetCitizenId and not exports['cold-gangs']:IsPlayerAdmin(src) then
        TriggerClientEvent('QBCore:Notify', src, "Only admins can kick the leader", "error")
        return
    end

    -- Remove from DB
    MySQL.query('DELETE FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, targetCitizenId})

    -- Remove from memory
    local memberName = GangMembers[gangId][targetCitizenId] and GangMembers[gangId][targetCitizenId].name or "Unknown"
    GangMembers[gangId][targetCitizenId] = nil

    -- Find target player and notify
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    if targetPlayer then
        TriggerClientEvent('cold-gangs:client:KickedFromGang', targetPlayer.PlayerData.source, reason)
        TriggerClientEvent('QBCore:Notify', targetPlayer.PlayerData.source, "You were kicked from the gang: " .. reason, "error")
    end

    -- Notify gang
    Core.NotifyGangMembers(gangId, "Member Kicked", memberName .. " was kicked: " .. reason)
end)

-- ======================
-- PROMOTE / DEMOTE
-- ======================

-- Promote Member
RegisterNetEvent('cold-gangs:server:PromoteMember', function(targetCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then return end

    if not GangMembers[gangId][targetCitizenId] then
        TriggerClientEvent('QBCore:Notify', src, "Player not found in gang", "error")
        return
    end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageRanks') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to manage ranks", "error")
        return
    end

    local currentRank = GangMembers[gangId][targetCitizenId].rank
    if currentRank >= 6 then
        TriggerClientEvent('QBCore:Notify', src, "This member is already at the highest rank", "error")
        return
    end

    local newRank = currentRank + 1

    -- Update DB
    MySQL.update('UPDATE cold_gang_members SET rank = ? WHERE gang_id = ? AND citizen_id = ?', {newRank, gangId, targetCitizenId})
    GangMembers[gangId][targetCitizenId].rank = newRank

    -- Notify
    local targetName = GangMembers[gangId][targetCitizenId].name
    local rankName = Config.Gangs.Ranks[newRank] and Config.Gangs.Ranks[newRank].name or "Unknown"
    Core.NotifyGangMembers(gangId, "Member Promoted", targetName .. " was promoted to " .. rankName)

    -- Update client
    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    if targetPlayer then
        TriggerClientEvent('cold-gangs:client:RankUpdated', targetPlayer.PlayerData.source, newRank)
    end
end)

-- Demote Member
RegisterNetEvent('cold-gangs:server:DemoteMember', function(targetCitizenId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then return end

    if not GangMembers[gangId][targetCitizenId] then return end

    if not exports['cold-gangs']:HasGangPermission(src, 'manageRanks') then
        TriggerClientEvent('QBCore:Notify', src, "You don't have permission to manage ranks", "error")
        return
    end

    local currentRank = GangMembers[gangId][targetCitizenId].rank
    if currentRank <= 1 then
        TriggerClientEvent('QBCore:Notify', src, "This member is already at the lowest rank", "error")
        return
    end

    local newRank = currentRank - 1

    MySQL.update('UPDATE cold_gang_members SET rank = ? WHERE gang_id = ? AND citizen_id = ?', {newRank, gangId, targetCitizenId})
    GangMembers[gangId][targetCitizenId].rank = newRank

    local targetName = GangMembers[gangId][targetCitizenId].name
    local rankName = Config.Gangs.Ranks[newRank] and Config.Gangs.Ranks[newRank].name or "Unknown"
    Core.NotifyGangMembers(gangId, "Member Demoted", targetName .. " was demoted to " .. rankName)

    local targetPlayer = QBCore.Functions.GetPlayerByCitizenId(targetCitizenId)
    if targetPlayer then
        TriggerClientEvent('cold-gangs:client:RankUpdated', targetPlayer.PlayerData.source, newRank)
    end
end)

-- ======================
-- LEAVE GANG
-- ======================

-- Leave Gang
RegisterNetEvent('cold-gangs:server:LeaveGang', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local gangId = exports['cold-gangs']:GetPlayerGangId(src)
    if not gangId then
        TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error")
        return
    end

    -- Can't leave if you're the leader
    if Gangs[gangId].leader == Player.PlayerData.citizenid then
        TriggerClientEvent('QBCore:Notify', src, "You cannot leave your gang as the leader. Transfer leadership first.", "error")
        return
    end

    -- Remove from DB
    MySQL.query('DELETE FROM cold_gang_members WHERE gang_id = ? AND citizen_id = ?', {gangId, Player.PlayerData.citizenid})

    -- Remove from memory
    GangMembers[gangId][Player.PlayerData.citizenid] = nil

    -- Notify
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    Core.NotifyGangMembers(gangId, "Member Left", playerName .. " has left the gang.")
    TriggerClientEvent('cold-gangs:client:LeftGang', src)
end)

-- ======================
-- CALLBACKS
-- ======================

-- Get Player Gang
QBCore.Functions.CreateCallback('cold-gangs:server:GetPlayerGang', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then 
        cb(nil)
        return
    end
    
    local citizenId = Player.PlayerData.citizenid
    for gangId, members in pairs(GangMembers) do
        if members[citizenId] then
            cb({
                id = gangId,
                name = Gangs[gangId].name,
                tag = Gangs[gangId].tag,
                rank = members[citizenId].rank,
                isLeader = Gangs[gangId].leader == citizenId,
                color = Gangs[gangId].color,
                logo = Gangs[gangId].logo
            })
            return
        end
    end
    cb(nil)
end)

-- Get Gang Data
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangData', function(source, cb, gangId)
    if not Gangs[gangId] then
        cb(nil)
        return
    end

    cb({
        id = Gangs[gangId].id,
        name = Gangs[gangId].name,
        tag = Gangs[gangId].tag,
        leader = Gangs[gangId].leader,
        level = Gangs[gangId].level,
        bank = Gangs[gangId].bank,
        reputation = Gangs[gangId].reputation,
        maxMembers = Gangs[gangId].maxMembers,
        created_at = Gangs[gangId].created_at,
        color = Gangs[gangId].color,
        logo = Gangs[gangId].logo,
        members = GangMembers[gangId] or {}
    })
end)

-- Get Gang Members
QBCore.Functions.CreateCallback('cold-gangs:server:GetGangMembers', function(source, cb, gangId)
    local members = {}
    if GangMembers[gangId] then
        for cid, data in pairs(GangMembers[gangId]) do
            table.insert(members, {
                citizenId = cid,
                name = data.name or "Unknown",
                rank = data.rank,
                joinedAt = data.joined_at
            })
        end
    end
    cb(members)
end)

-- ======================
-- CLEANUP
-- ======================

-- Clean up expired invites
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute
        
        if PendingInvites then
            local now = os.time()
            for targetId, invite in pairs(PendingInvites) do
                if invite.expires < now then
                    PendingInvites[targetId] = nil
                end
            end
        end
    end
end)
