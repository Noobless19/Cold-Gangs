local QBCore = exports['qb-core']:GetCoreObject()

local PlayerData = {}
local PlayerGang = nil
local Territories = {}
local GangInfluence = {}
local isLoggedIn = false

local function GetGangId()
    local gangId = nil
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGangId', function(id) gangId = id end)
    local timeout = 0
    while gangId == nil and timeout < 50 do Wait(10) timeout = timeout + 1 end
    return gangId
end

local function IsInGang()
    local inGang = nil
    QBCore.Functions.TriggerCallback('cold-gangs:server:IsPlayerInGang', function(result)
        inGang = result and true or false
    end)
    local timeout = 0
    while inGang == nil and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    return inGang == true
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    isLoggedIn = true
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData) PlayerGang = gangData end)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territoryData) Territories = territoryData or {} end)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetGangInfluence', function(inf) GangInfluence = inf or {} end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    isLoggedIn = false
    PlayerGang = nil
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    PlayerData = data
end)

RegisterNetEvent('cold-gangs:client:SyncTerritories', function(territoryData)
    Territories = territoryData or {}
end)

RegisterNetEvent('cold-gangs:client:SyncGangData', function(gangData)
    if gangData and gangData.id then
        PlayerGang = gangData
    else
        PlayerGang = nil
    end
end)

RegisterNetEvent('cold-gangs:client:GangCreated', function(gangData)
    PlayerGang = gangData
    QBCore.Functions.Notify("You have joined " .. gangData.name, "success")
end)

RegisterNetEvent('cold-gangs:client:GangJoined', function(gangData)
    PlayerGang = gangData
    QBCore.Functions.Notify("You have joined " .. gangData.name, "success")
end)

RegisterNetEvent('cold-gangs:client:GangLeft', function()
    PlayerGang = nil
    QBCore.Functions.Notify("You have left your gang", "primary")
end)

RegisterCommand('gangmenu', function()
    if not IsInGang() then QBCore.Functions.Notify("You are not in a gang", "error") return end
    TriggerEvent('cold-gangs:client:OpenGangMenu')
end)
    RegisterCommand('gangui', function()
        if not IsInGang() then QBCore.Functions.Notify("You are not in a gang", "error") return end
        TriggerEvent('cold-gangs:client:OpenGangMenu')
    end)
