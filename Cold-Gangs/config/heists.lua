Config.HeistTypes = {
    ['convenience_store'] = {
        name = 'Convenience Store Robbery',
        category = 'street',
        description = 'Rob a local convenience store for quick cash',
        minReputation = 0,
        minMembers = 1,
        maxMembers = 3,
        policeRequired = 0,
        cooldown = 7200000, -- 2 hours
        rewards = {
            basePayout = { min = 5000, max = 15000 },
            reputation = { min = 20, max = 40 }
        },
        stages = {
            { name = "recon", duration = 60000 },
            { name = "approach", duration = 240000 },
            { name = "escape", duration = 120000 }
        },
        locations = {
            { name = "Rob's Liquor", coords = vector3(-353.41, -54.5, 49.04) }
        }
    },
    ['jewelry_store'] = {
        name = 'Jewelry Store Heist',
        category = 'commercial',
        description = 'Rob the Vangelico Jewelry Store',
        minReputation = 400,
        minMembers = 2,
        maxMembers = 5,
        policeRequired = 2,
        cooldown = 10800000, -- 3 hours
        rewards = {
            basePayout = { min = 40000, max = 70000 },
            reputation = 150
        }
    }
}

Config.HeistSettings = {
    failureCooldownMultiplier = 1.5,
    heatIncrease = 25,
    perfectHeistBonus = 0.25,
    speedBonus = 0.15,
    policeNotificationDelay = 30000,
    escapeTimeLimit = 600000 -- 10 minutes
}
