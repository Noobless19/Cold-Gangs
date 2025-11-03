local QBCore = exports['qb-core']:GetCoreObject()

local PlayerGang = nil
local ActiveWars = {}
local WarBlips = {}
local isInWarZone = false
local currentWarId = nil
local killCooldown = false

local function getTerritoryCenter(name)
    local center = nil
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
        local t = territories and territories[name]
        if t and t.center_x and t.center_y then
            center = vector3(t.center_x, t.center_y, t.center_z or 30.0)
        else
            local zones = (Config and Config.MapZones) or {}
            local z = zones[name]
            if z and z.parts and z.parts[1] then
                local p = z.parts[1]
                center = vector3((p.x1+p.x2)/2,(p.y1+p.y2)/2,30.0)
            end
        end
    end)
    local i=0 while not center and i<20 do Wait(50) i=i+1 end
    return center
end

local function CreateWarBlips()
    for _, blip in pairs(WarBlips) do RemoveBlip(blip) end
    WarBlips = {}
    for warId, war in pairs(ActiveWars) do
        if war.territoryName then
            local c = getTerritoryCenter(war.territoryName)
            if c then
                local blip = AddBlipForCoord(c.x, c.y, c.z)
                SetBlipSprite(blip, 310)
                SetBlipColour(blip, 1)
                SetBlipScale(blip, 1.0)
                SetBlipFlashes(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(("WAR: %s vs %s"):format(war.attackerName, war.defenderName))
                EndTextCommandSetBlipName(blip)
                WarBlips[warId] = blip
            end
        end
    end
end

CreateThread(function()
    while not QBCore.Functions.GetPlayerData() do Wait(100) end
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData) PlayerGang = gangData end)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetActiveWars', function(wars) ActiveWars = wars or {} CreateWarBlips() end)
end)

RegisterNetEvent('cold-gangs:client:SyncWars', function(wars)
    ActiveWars = wars or {}
    CreateWarBlips()
end)

RegisterNetEvent('cold-gangs:client:DeclareWar', function(targetGangId)
    if not PlayerGang then QBCore.Functions.Notify("You need to be in a gang", "error") return end
    if not exports['cold-gangs']:HasGangPermission('declareWar') then QBCore.Functions.Notify("You don't have permission", "error") return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
        local menu = { { header = "Select Territory to Contest", isMenuHeader = true } }
        local tg = {}
        for name, t in pairs(territories or {}) do
            if t.gangId == targetGangId then table.insert(tg, {name=name, territory=t}) end
        end
        if #tg == 0 then QBCore.Functions.Notify("This gang doesn't control any territories", "error") return end
        for _, entry in ipairs(tg) do
            table.insert(menu, {
                header = entry.name, txt = "Controlled by: " .. (entry.territory.gangName or "Unknown"),
                params = { event = "cold-gangs:client:ConfirmWarDeclaration", args = { targetGangId = targetGangId, territoryName = entry.name } }
            })
        end
        table.insert(menu, { header = "← Cancel", params = { event = "qb-menu:client:closeMenu" } })
        exports['qb-menu']:openMenu(menu)
    end)
end)

RegisterNetEvent('cold-gangs:client:ConfirmWarDeclaration', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = "Declare War",
        submitText = "Confirm",
        inputs = { { text = "War declaration will cost $" .. (Config.Wars and Config.Wars.declarationCost or 0), name = "confirm", type = "checkbox", isRequired = true } }
    })
    if dialog and dialog.confirm then
        TriggerServerEvent('cold-gangs:wars:Declare', data.targetGangId, data.territoryName)
    end
end)

RegisterNetEvent('cold-gangs:client:WarStarted', function(warId, warData)
    ActiveWars[warId] = warData
    CreateWarBlips()
    if PlayerGang and (warData.attackerId == PlayerGang.id or warData.defenderId == PlayerGang.id) then
        QBCore.Functions.Notify("War has begun against " .. (warData.attackerId == PlayerGang.id and warData.defenderName or warData.attackerName), "error", 10000)
        PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
        Wait(100) PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
        Wait(100) PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
    end
end)

RegisterNetEvent('cold-gangs:client:WarEnded', function(warId, winnerId, winnerName)
    local warData = ActiveWars[warId]
    ActiveWars[warId] = nil
    if WarBlips[warId] then RemoveBlip(WarBlips[warId]) WarBlips[warId] = nil end
    if warData and PlayerGang and (warData.attackerId == PlayerGang.id or warData.defenderId == PlayerGang.id) then
        local isWinner = PlayerGang.id == winnerId
        local message = isWinner and ("Your gang has won the war against %s"):format(warData.attackerId == PlayerGang.id and warData.defenderName or warData.attackerName)
                                    or ("Your gang has lost the war against %s"):format(winnerName or "")
        QBCore.Functions.Notify(message, isWinner and "success" or "error", 10000)
        if isWinner then PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 1)
        else PlaySoundFrontend(-1, "ScreenFlash", "WastedSounds", 1) end
    end
end)

RegisterNetEvent('cold-gangs:client:WarScoreUpdated', function(warId, attackerScore, defenderScore)
    if not ActiveWars[warId] then return end
    ActiveWars[warId].attackerScore = attackerScore
    ActiveWars[warId].defenderScore = defenderScore
    if PlayerGang and (ActiveWars[warId].attackerId == PlayerGang.id or ActiveWars[warId].defenderId == PlayerGang.id) then
        local ours = ActiveWars[warId].attackerId == PlayerGang.id and attackerScore or defenderScore
        local theirs = ActiveWars[warId].attackerId == PlayerGang.id and defenderScore or attackerScore
        QBCore.Functions.Notify(("War Score Updated: %d - %d"):format(ours, theirs), "primary")
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if PlayerGang and ActiveWars and next(ActiveWars) then
            local pc = GetEntityCoords(PlayerPedId())
            local inZone, warId = false, nil
            for id, war in pairs(ActiveWars) do
                if war.territoryName and (war.attackerId == PlayerGang.id or war.defenderId == PlayerGang.id) then
                    local c = getTerritoryCenter(war.territoryName)
                    if c then
                        local radius = 200.0
                        if #(pc - c) <= radius then inZone = true warId = id break end
                    end
                end
            end
            if inZone ~= isInWarZone then
                isInWarZone = inZone
                currentWarId = warId
                if isInWarZone then
                    TriggerEvent('cold-gangs:client:EnteredWarZone', currentWarId)
                else
                    TriggerEvent('cold-gangs:client:LeftWarZone')
                end
            end
        else
            Wait(3000)
        end
    end
end)

RegisterNetEvent('cold-gangs:client:EnteredWarZone', function(warId)
    if not ActiveWars[warId] then return end
    local warData = ActiveWars[warId]
    local enemy = warData.attackerId == PlayerGang.id and warData.defenderName or warData.attackerName
    QBCore.Functions.Notify("You entered a war zone against " .. enemy, "error", 10000)
    PlaySoundFrontend(-1, "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS", 1)
end)

RegisterNetEvent('cold-gangs:client:LeftWarZone', function()
    QBCore.Functions.Notify("You left the war zone", "primary")
end)

RegisterNetEvent('hospital:client:Revive', function()
    if isInWarZone and currentWarId and ActiveWars[currentWarId] and not killCooldown then
        killCooldown = true
        TriggerServerEvent('cold-gangs:wars:ReportDeath', currentWarId)
        SetTimeout(60000, function() killCooldown = false end)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in pairs(WarBlips) do RemoveBlip(blip) end
    WarBlips = {}
end)
