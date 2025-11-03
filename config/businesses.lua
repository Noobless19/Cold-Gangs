Config = Config or {}
BusinessConfig = {
  BusinessTypes = {
    dispensary = { name = "Dispensary", purchaseCost = 75000, upgradeCost = 25000, income = 500, maxLevel = 5, description = "A cannabis dispensary." },
    bar = { name = "Bar", purchaseCost = 100000, upgradeCost = 30000, income = 750, maxLevel = 5, description = "A bar." },
    garage = { name = "Garage", purchaseCost = 125000, upgradeCost = 35000, income = 600, maxLevel = 5, description = "A garage." },
    club = { name = "Nightclub", purchaseCost = 200000, upgradeCost = 50000, income = 1000, maxLevel = 5, description = "A nightclub." }
  },
  MaxBusinesses = 5,
  UpgradeTypes = {
    security = { name = "Security", description = "Reduces chance of raids and theft", maxLevel = 3 },
    capacity = { name = "Capacity", description = "Increases employee capacity", maxLevel = 3 },
    quality = { name = "Quality", description = "Improves product quality and income", maxLevel = 3 }
  }
}
Config.Businesses = BusinessConfig
