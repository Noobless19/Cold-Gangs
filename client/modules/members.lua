local QBCore = exports['qb-core']:GetCoreObject()

local PlayerGang = nil
local isLoggedIn = false
local PlayerData = {}

CreateThread(function()
    while not QBCore.Functions.GetPlayerData() do Wait(100) end
    isLoggedIn = true
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData) PlayerGang = gangData end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    isLoggedIn = true
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData) PlayerGang = gangData end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
    PlayerGang = nil
    PlayerData = {}
end)

RegisterNetEvent('cold-gangs:client:InviteToGang', function()
    local closestPlayers = QBCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(PlayerPedId())
    for i=1,#closestPlayers do
        if closestPlayers[i] ~= PlayerId() then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(coords - pos)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
    end
    if closestPlayer == -1 or closestDistance > 5.0 then QBCore.Functions.Notify("No player nearby", "error") return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData)
        if not gangData then QBCore.Functions.Notify("You are not in a gang", "error") return end
        local targetId = GetPlayerServerId(closestPlayer)
        TriggerServerEvent('cold-gangs:server:InvitePlayerToGang', targetId)
    end)
end)

RegisterNetEvent('cold-gangs:client:ReceiveGangInvite', function(data)
    local menu = {
        { header = "Gang Invite", txt = "From: " .. data.gangName, isMenuHeader = true },
        { header = "Accept Invite", txt = "Join the gang", params = { event = "cold-gangs:client:AcceptGangInvite", args = { id = data.id } } },
        { header = "Decline", txt = "Reject the invite", params = { event = "cold-gangs:client:DeclineGangInvite", args = { id = data.id } } }
    }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('cold-gangs:client:AcceptGangInvite', function(data)
    TriggerServerEvent('cold-gangs:server:AcceptGangInvite', data.id)
end)

RegisterNetEvent('cold-gangs:client:DeclineGangInvite', function(data)
    TriggerServerEvent('cold-gangs:server:DeclineGangInvite', data.id)
end)

RegisterNetEvent('cold-gangs:client:GangCreated', function(gangData) PlayerGang = gangData QBCore.Functions.Notify("Gang created: " .. gangData.name, "success") end)
RegisterNetEvent('cold-gangs:client:GangJoined', function(gangData) PlayerGang = gangData QBCore.Functions.Notify("You joined " .. gangData.name, "success") end)
RegisterNetEvent('cold-gangs:client:GangLeft', function() PlayerGang = nil QBCore.Functions.Notify("You left the gang", "primary") end)
RegisterNetEvent('cold-gangs:client:KickedFromGang', function(reason) PlayerGang = nil QBCore.Functions.Notify("You were kicked: " .. (reason or ""), "error") end)
RegisterNetEvent('cold-gangs:client:RankChanged', function(newRank) if PlayerGang then PlayerGang.rank = newRank QBCore.Functions.Notify("Your rank has been updated", "primary") end end)

exports('GetPlayerGang', function() return PlayerGang end)
exports('RefreshGangData', function(cb) QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(g) PlayerGang = g if cb then cb(g) end end) end)
exports('IsInGang', function() return PlayerGang ~= nil end)
