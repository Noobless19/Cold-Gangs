local QBCore = exports['qb-core']:GetCoreObject()

-- Get closest player
function GetClosestPlayer()
    local closestPlayers = QBCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(PlayerPedId())

    for i = 1, #closestPlayers, 1 do
        if closestPlayers[i] ~= PlayerId() then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
    end

    return closestPlayer, closestDistance
end

-- Format money
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

-- Format duration
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

-- Table length
function TableLength(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

-- Draw 3D text
function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local distance = #(vector3(p.x, p.y, p.z) - vector3(x, y, z))
    local scale = (1 / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = scale * fov
    
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 90)
    end
end

-- Exports
exports('GetClosestPlayer', GetClosestPlayer)
exports('FormatMoney', FormatMoney)
exports('FormatDuration', FormatDuration)
exports('TableLength', TableLength)
exports('Draw3DText', Draw3DText)
