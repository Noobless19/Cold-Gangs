local QBCore = exports['qb-core']:GetCoreObject()

function GetClosestPlayer()
    local closestPlayers = QBCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(PlayerPedId())
    for i=1,#closestPlayers do
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

function FormatMoney(amount)
    if amount == nil or amount == 0 then return "$0" end
    local s = tostring(math.floor(amount))
    local k
    while true do
        s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return "£" .. s
end

function FormatDuration(seconds)
    if seconds <= 0 then return "0s" end
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    local str = ""
    if d > 0 then str = str .. d .. "d " end
    if h > 0 then str = str .. h .. "h " end
    if m > 0 then str = str .. m .. "m " end
    if s > 0 or str == "" then str = str .. s .. "s" end
    return str
end

function TableLength(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

function Draw3DText(x, y, z, text)
    local on, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local d = #(vector3(p.x, p.y, p.z) - vector3(x, y, z))
    local scale = (1 / d) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    if on then
        SetTextScale(0.35*scale, 0.35*scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

exports('GetClosestPlayer', GetClosestPlayer)
exports('FormatMoney', FormatMoney)
exports('FormatDuration', FormatDuration)
exports('TableLength', TableLength)
exports('Draw3DText', Draw3DText)
