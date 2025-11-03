Config = Config or {}
Config.Graffiti = {
  maxDistance = 2.5,
  sprayDuration = 8000,
  removeDuration = 5000,
  cooldownTime = 300000,
  maxGraffitisPerArea = 3,
  influenceGain = { text = 10, logo = 25 },
  sprayCanItem = "spraycan",
  paintRemoverItem = "paint_remover",
  minSurfaceAngle = 80.0,
  logoSettings = {
    textureDict = "gang_logos",
    fallbackText = true,
    logoScale = { min = 0.02, max = 0.1, distanceMultiplier = 0.002 },
    renderDistance = 50.0,
    textRenderDistance = 100.0
  },
  availableLogos = { "hydra", "ballas", "grove", "vagos", "families" }
}
Config.TerritoryIntegration = Config.TerritoryIntegration or {}
Config.TerritoryIntegration.enabled = true
Config.TerritoryIntegration.requireTerritory = false
Config.TerritoryIntegration.influenceEvents = {
  createGraffiti = "cold-gangs:server:Graffiti",
  removeGraffiti = "cold-gangs:server:GraffitiRemoved"
}
