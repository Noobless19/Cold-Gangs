Config = {}

-- ======================
-- PERFORMANCE SETTINGS
-- ======================
Config.Performance = {
    updateInterval = 5000,           -- 5 seconds for most updates
    territoryCheckInterval = 10000,  -- 10 seconds for territory checks
    economyUpdateInterval = 30000,   -- 30 seconds for economy
    maxRenderDistance = 500.0,
    enableOptimizations = true,
    maxConcurrentOperations = 15,
    useThreadOptimization = true
}

-- ======================
-- ADMIN & DEBUG
-- ======================
Config.Admin = {
    adminGroups = { "admin", "god", "qbcore.admin", "qbcore.god" },
    adminCitizenIds = {},
    debugPermissions = true,
    adminBypass = true,
    logActions = true,
    enableAdminAlerts = true
}

Config.Debug = false

-- ======================
-- GANG CORE SETTINGS
-- ======================
Config.GangCreationCost = 50000
Config.MaxGangMembers = 25
Config.MaxGangsPerServer = 50

Config.GangNameMinLength = 3
Config.GangNameMaxLength = 30
Config.GangTagMinLength = 2
Config.GangTagMaxLength = 5

Config.InvitationExpireTime = 300000 -- 5 minutes

Config.RequireApprovalForCreation = true -- Admin approval required

-- ======================
-- ECONOMY
-- ======================
Config.Economy = {
    incomeInterval = 3600000, -- 1 hour in ms
    salaryMultiplier = 1.0,    -- Multiplier for salaries
    transactionFee = 0.05,     -- 5% transaction fee
    dailyUpkeepMultiplier = 100, -- Base upkeep cost per member
    taxRate = 0.1              -- 10% tax on income
}

-- ======================
-- SECURITY & ANTI-CHEAT
-- ======================
Config.Security = {
    enableAntiCheat = true,
    maxActionsPerMinute = 15,
    logSuspiciousActivity = true,
    autoKickCheaters = false,
    enableRateLimiting = true,
    maxDatabaseQueries = 50 -- Per minute per player
}

-- ======================
-- BLIPS & UI
-- ======================
Config.Blips = {
    showGangMembers = true,
    showTerritories = true,
    showWars = true,
    showHeists = true,
    showDrugLabs = true,
    memberBlipSprite = 1,
    territoryBlipSprite = 84,
    warBlipSprite = 161,
    heistBlipSprite = 486,
    drugLabBlipSprite = 499
}

-- ======================
-- INVENTORY
-- ======================
Config.Inventory = {
    maxStashWeight = 1000000,
    maxStashSlots = 50
}


Config.Businesses = BusinessConfig
