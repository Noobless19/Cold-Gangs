local QBCore = exports['qb-core']:GetCoreObject()

-- Local variables
local PlayerGang = nil
local isLoggedIn = false

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
end)

-- Invite to Gang
RegisterNetEvent('cold-gangs:client:InviteToGang', function()
    local closestPlayer, distance = exports['cold-gangs']:GetClosestPlayer()
    if closestPlayer == -1 or distance > 5.0 then
        QBCore.Functions.Notify("No player nearby", "error")
        return
    end

    local targetId = GetPlayerServerId(closestPlayer)
    TriggerServerEvent('cold-gangs:server:InvitePlayerToGang', targetId)
end)

-- Handle invite received
RegisterNetEvent('cold-gangs:client:ReceiveGangInvite', function(gangName, gangTag)
    QBCore.Functions.Notify("You've been invited to join " .. gangName .. " (" .. gangTag .. ")", "primary")
    local menu = {
        {
            header = "Gang Invite",
            txt = "From: " .. gangName,
            isMenuHeader = true
        },
        {
            header = "Accept Invite",
            txt = "Join the gang",
            params = {
                event = "cold-gangs:server:AcceptGangInvite"
            }
        },
        {
            header = "Decline",
            txt = "Reject the invite",
            params = {
                event = "cold-gangs:server:DeclineGangInvite"
            }
        }
    }
    exports['qb-menu']:openMenu(menu)
end)
