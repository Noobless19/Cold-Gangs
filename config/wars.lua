Config = Config or {}
Config.Wars = {
  enabled = true,
  declarationCost = 75000,
  minDuration = 1800000,
  maxDuration = 3600000,
  cooldownPeriod = 7200000,
  minMembersOnline = 3,
  maxSimultaneousWars = 3,
  winReward = 150000,
  loseReward = 25000,
  maxScore = 100
}
Config.Dispatch = {
  system = 'ps-dispatch',
  enableGangAlerts = true,
  enableWarAlerts = true,
  enableHeistAlerts = true,
  enableDrugAlerts = true,
  alertCooldown = 60000,
  systems = {
    ['ps-dispatch'] = { jobType = 'police', alertType = 'gang_activity', blipTime = 300000 },
    ['cd_dispatch'] = { jobType = 'police', alertType = 'gang_activity', blipTime = 300000 },
    ['qs-dispatch'] = { jobType = 'police', alertType = 'gang_activity', blipTime = 300000 }
  }
}
