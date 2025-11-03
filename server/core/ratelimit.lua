-- Rate Limiting System for Cold-Gangs
local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}
ColdGangs.RateLimit = ColdGangs.RateLimit or {}

local rateLimits = {}

-- Clean up old entries periodically
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        local now = os.time()
        for key, data in pairs(rateLimits) do
            if now > data.reset then
                rateLimits[key] = nil
            end
        end
    end
end)

function ColdGangs.RateLimit.CheckLimit(src, action, maxPerMinute)
    if not Config.Security or not Config.Security.enableRateLimiting then
        return true -- Rate limiting disabled
    end
    
    maxPerMinute = maxPerMinute or Config.Security.maxActionsPerMinute or 15
    
    local key = src .. "_" .. action
    local now = os.time()
    
    -- Initialize or reset if expired
    if not rateLimits[key] or now > rateLimits[key].reset then
        rateLimits[key] = { count = 1, reset = now + 60 }
        return true
    end
    
    -- Check if over limit
    if rateLimits[key].count >= maxPerMinute then
        if Config.Security.logSuspiciousActivity then
            print(string.format("[cold-gangs][ratelimit] Player %d exceeded rate limit for action: %s (%d/%d)", 
                src, action, rateLimits[key].count, maxPerMinute))
        end
        return false
    end
    
    rateLimits[key].count = rateLimits[key].count + 1
    return true
end

function ColdGangs.RateLimit.GetRemaining(src, action, maxPerMinute)
    maxPerMinute = maxPerMinute or Config.Security.maxActionsPerMinute or 15
    local key = src .. "_" .. action
    if not rateLimits[key] or os.time() > rateLimits[key].reset then
        return maxPerMinute
    end
    return math.max(0, maxPerMinute - rateLimits[key].count)
end

exports('CheckRateLimit', ColdGangs.RateLimit.CheckLimit)
exports('GetRemainingLimit', ColdGangs.RateLimit.GetRemaining)