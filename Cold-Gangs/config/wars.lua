Config.Wars = {
    enabled = true,
    declarationCost = 75000,
    minDuration = 1800000, -- 30 minutes
    maxDuration = 3600000, -- 1 hour
    cooldownPeriod = 7200000, -- 2 hours
    minMembersOnline = 3,
    maxSimultaneousWars = 3,
    winReward = 150000,
    loseReward = 25000,
    maxScore = 100
}

-- Dispatch Integration
Config.Dispatch = {
    system = 'ps-dispatch', -- 'ps-dispatch', 'cd_dispatch', 'qs-dispatch', etc.
    enableGangAlerts = true,
    enableWarAlerts = true,
    enableHeistAlerts = true,
    enableDrugAlerts = true,
    alertCooldown = 60000, -- 1 minute between alerts
    systems = {
        ['ps-dispatch'] = {
            jobType = 'police',
            alertType = 'gang_activity',
            blipTime = 300000 -- 5 minutes
        },
        ['cd_dispatch'] = {
            jobType = 'police',
            alertType = 'gang_activity',
            blipTime = 300000
        },
        ['qs-dispatch'] = {
            jobType = 'police',
            alertType = 'gang_activity',
            blipTime = 300000
        }
    }
}
