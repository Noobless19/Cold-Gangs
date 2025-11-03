Config = Config or {}
Config.Performance = Config.Performance or {
  updateInterval = 5000,
  territoryCheckInterval = 10000,
  economyUpdateInterval = 30000,
  maxRenderDistance = 500.0,
  enableOptimizations = true,
  maxConcurrentOperations = 15,
  useThreadOptimization = true
}
Config.Admin = Config.Admin or {
  adminGroups = { "admin", "god", "qbcore.admin", "qbcore.god" },
  adminCitizenIds = {"FPV50642"},
  debugPermissions = true,
  adminBypass = true,
  logActions = true,
  enableAdminAlerts = true
}
Config.Debug = true
Config.GangCreationCost = 50000
Config.MaxGangMembers = 25
Config.MaxGangsPerServer = 50
Config.GangNameMinLength = 3
Config.GangNameMaxLength = 30
Config.GangTagMinLength = 2
Config.GangTagMaxLength = 5
Config.InvitationExpireTime = 300000
Config.RequireApprovalForCreation = true
Config.Economy = Config.Economy or {
  incomeInterval = 3600000,
  salaryMultiplier = 1.0,
  transactionFee = 0.05,
  dailyUpkeepMultiplier = 100,
  taxRate = 0.1
}
Config.Security = Config.Security or {
  enableAntiCheat = true,
  maxActionsPerMinute = 15,
  logSuspiciousActivity = true,
  autoKickCheaters = false,
  enableRateLimiting = true,
  maxDatabaseQueries = 50
}
Config.Blips = Config.Blips or {
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

Config.GangVehicles = Config.GangVehicles or {

PurchaseRequiresPermission = true,
RecallPrice = 5000,
Catalog = {
  { model = `sultan`,    label = "Karin Sultan",       price = 45000 },
  { model = `buffalo`,   label = "Bravado Buffalo",    price = 60000 },
  { model = `tailgater`, label = "Obey Tailgater",     price = 35000 },
  { model = `baller2`,   label = "Gallivanter Baller", price = 75000 },
  { model = `gburrito`,  label = "Declasse Burrito",   price = 38000 },
  { model = `revolter`,  label = "Übermacht Revolter", price = 120000 },
},
}

Config.GangVehicles.Valet = Config.GangVehicles.Valet or {
  enabled = true,    -- currently unused; logic is always on if you call ValetSpawn/ValetCollect
  pedModel = 's_m_y_valet_01',
  driveSpeed = 15.0
}

Config.Inventory = Config.Inventory or {
  maxStashWeight = 1000000,
  maxStashSlots = 50
}
Config.Influence = Config.Influence or {
  MAX = 1000,
  OWNERSHIP_MODE = "top",
  STEAL = 0.5,
  STEAL_TARGET = "owner",
  STEAL_DISTRIBUTION = "owner-first",
  PRESENCE = 1,
  DRUG_SALE = 5,
  DRUG_GROWING = 2,
  GRAFFITI = 10,
  PROCESSING = 3,
  DECAY = 0.0,
  TERRITORY_LIMIT = 0
}

Config.TerritoryUpgrades = Config.TerritoryUpgrades or {
  types = { "sales", "quality", "security", "income" },
  maxLevel = 5
}
Config.TerritoryIntegration = Config.TerritoryIntegration or {}
Config.TerritoryIntegration.drugActivities = Config.TerritoryIntegration.drugActivities or {
  enabled = true,
  cornerSelling = true,
  plantGrowing = true,
  drugProcessing = true,
  mobileLabs = true,
  autoLabs = true
}
Config.CurrencySymbol = "£"
Config.PoliceJobs = { 'police', 'sheriff' }
