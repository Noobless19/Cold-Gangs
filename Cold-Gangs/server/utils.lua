-- ======================
-- UTILITY FUNCTIONS
-- ======================

-- Check if table contains value
function TableContains(table, val)
    for i = 1, #table do
        if table[i] == val then
            return true
        end
    end
    return false
end

-- Get table length
function TableLength(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
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

-- Get random element from table
function GetRandomFromTable(table)
    if #table == 0 then return nil end
    return table[math.random(1, #table)]
end

-- Get random number between min and max
function GetRandomNumber(min, max)
    return math.random(min, max)
end

-- Check if player is online
function IsPlayerOnline(citizenId)
    return QBCore.Functions.GetPlayerByCitizenId(citizenId) ~= nil
end

-- Get player by citizen ID
function GetPlayerByCitizenId(citizenId)
    return QBCore.Functions.GetPlayerByCitizenId(citizenId)
end

-- Get player by source
function GetPlayer(source)
    return QBCore.Functions.GetPlayer(source)
end

-- Add item to player
function AddItemToPlayer(source, item, amount, slot)
    local Player = GetPlayer(source)
    if not Player then return false end
    
    return Player.Functions.AddItem(item, amount, slot)
end

-- Remove item from player
function RemoveItemFromPlayer(source, item, amount, slot)
    local Player = GetPlayer(source)
    if not Player then return false end
    
    return Player.Functions.RemoveItem(item, amount, slot)
end

-- Check if player has item
function HasItem(source, item, amount)
    local Player = GetPlayer(source)
    if not Player then return false end
    
    local items = Player.Functions.GetItemsByName(item)
    if not items then return false end
    
    local count = 0
    for _, itemData in pairs(items) do
        count = count + itemData.amount
    end
    
    return count >= (amount or 1)
end

-- Add money to player
function AddMoneyToPlayer(source, moneyType, amount, reason)
    local Player = GetPlayer(source)
    if not Player then return false end
    
    return Player.Functions.AddMoney(moneyType, amount, reason)
end

-- Remove money from player
function RemoveMoneyFromPlayer(source, moneyType, amount, reason)
    local Player = GetPlayer(source)
    if not Player then return false end
    
    return Player.Functions.RemoveMoney(moneyType, amount, reason)
end

-- Log to console
function Log(message, level)
    level = level or "info"
    
    if level == "debug" and not Config.Debug then
        return
    end
    
    local prefix = "^3[Cold-Gangs]^7"
    local color = "^7" -- White
    
    if level == "error" then
        color = "^1" -- Red
    elseif level == "warning" then
        color = "^3" -- Yellow
    elseif level == "success" then
        color = "^2" -- Green
    elseif level == "debug" then
        color = "^5" -- Blue
    end
    
    print(prefix .. " " .. color .. message .. "^7")
end

-- Log to database
function LogToDatabase(gangId, action, details)
    if not Config.Admin.logActions then return end
    
    MySQL.insert('INSERT INTO cold_gang_logs (gang_id, action, details, timestamp) VALUES (?, ?, ?, NOW())', {
        gangId,
        action,
        details
    })
end

-- Check if player is admin
function IsPlayerAdmin(source)
    local Player = GetPlayer(source)
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

-- Get all online players
function GetAllPlayers()
    return QBCore.Functions.GetPlayers()
end

-- Get all online players with job
function GetPlayersWithJob(job)
    local players = {}
    for _, src in pairs(GetAllPlayers()) do
        local Player = GetPlayer(src)
        if Player and Player.PlayerData.job.name == job then
            table.insert(players, Player)
        end
    end
    return players
end

-- Count players with job
function CountPlayersWithJob(job)
    local count = 0
    for _, src in pairs(GetAllPlayers()) do
        local Player = GetPlayer(src)
        if Player and Player.PlayerData.job.name == job then
            count = count + 1
        end
    end
    return count
end

-- Notify all gang members
function NotifyGangMembers(gangId, title, message)
    if not GangMembers[gangId] then return end
    
    for citizenId in pairs(GangMembers[gangId]) do
        local Player = GetPlayerByCitizenId(citizenId)
        if Player then
            TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, title .. ": " .. message, "primary")
        end
    end
end

-- Notify all online admins
function NotifyAdmins(message)
    if not Config.Admin.enableAdminAlerts then return end
    
    for _, src in pairs(GetAllPlayers()) do
        if IsPlayerAdmin(src) then
            TriggerClientEvent('QBCore:Notify', src, "[Admin] " .. message, "error")
        end
    end
end

-- Register exports
exports('TableContains', TableContains)
exports('TableLength', TableLength)
exports('FormatMoney', FormatMoney)
exports('FormatDuration', FormatDuration)
exports('GetRandomFromTable', GetRandomFromTable)
exports('GetRandomNumber', GetRandomNumber)
exports('IsPlayerOnline', IsPlayerOnline)
exports('GetPlayerByCitizenId', GetPlayerByCitizenId)
exports('GetPlayer', GetPlayer)
exports('AddItemToPlayer', AddItemToPlayer)
exports('RemoveItemFromPlayer', RemoveItemFromPlayer)
exports('HasItem', HasItem)
exports('AddMoneyToPlayer', AddMoneyToPlayer)
exports('RemoveMoneyFromPlayer', RemoveMoneyFromPlayer)
exports('Log', Log)
exports('LogToDatabase', LogToDatabase)
exports('IsPlayerAdmin', IsPlayerAdmin)
exports('GetAllPlayers', GetAllPlayers)
exports('GetPlayersWithJob', GetPlayersWithJob)
exports('CountPlayersWithJob', CountPlayersWithJob)
exports('NotifyGangMembers', NotifyGangMembers)
exports('NotifyAdmins', NotifyAdmins)
