Config = Config or {}
Config.Debug = true
Config.UpdateInterval = 30000
Config.MaxDistance = 2.0
Config.MaxStorageSlots = 50
Config.ContinuousProduction = true
Config.UseInfluenceSystem = true
Config.MinInfluenceForAccess = 50
Config.MinInfluenceForRaid = 25
Config.RaidSettings = {
  minPlayersToRaid = 3,
  maxRaidDistance = 50.0,
  cooldownTime = 3600000,
  defenseTime = 300000,
  raidDuration = 900000,
  sabotageChance = 0.5,
  stealPercentage = 0.3,
  sabotageDowntime = 1800000,
  influenceGain = 25,
  influenceGainFailed = 10,
  defenseBonus = 15,
  productionBonus = { controlled = 1.5, contested = 1.0, enemy = 0.5 }
}
Config.Notifications = {
  raidStarted = true,
  raidDefense = true,
  productionComplete = true,
  territoryLost = true,
  sabotageAlert = true
}
Config.LabTypes = {
  ['drug_lab'] = {
    name = 'Drug Laboratory',
    securityLevel = 'medium',
    raidDifficulty = 2,
    recipes = {
      ['cocaine'] = { inputs = { ['coca_leaf'] = 10, ['sulfuric_acid'] = 5, ['acetone'] = 3 }, output = { item = 'cocaine', amount = 8 }, time = 300000, continuous = true },
      ['meth'] = { inputs = { ['ephedrine'] = 8, ['battery_acid'] = 4, ['aluminum'] = 2 }, output = { item = 'meth', amount = 6 }, time = 420000, continuous = true }
    }
  },
  ['weapon_lab'] = {
    name = 'Weapon Manufacturing',
    securityLevel = 'high',
    raidDifficulty = 3,
    recipes = {
      ['pistol_ammo'] = { inputs = { ['copper'] = 5, ['steel'] = 1 }, output = { item = 'pistol_ammo', amount = 1 }, time = 3600000, continuous = true },
      ['weapon_pistol'] = { inputs = { ['steel'] = 15, ['rubber'] = 8, ['spring'] = 5 }, output = { item = 'weapon_pistol', amount = 1 }, time = 900000, continuous = false }
    }
  },
  ['counterfeit_lab'] = {
    name = 'Counterfeit Operation',
    securityLevel = 'low',
    raidDifficulty = 1,
    recipes = {
      ['dirty_money'] = { inputs = { ['paper'] = 20, ['ink'] = 10, ['chemicals'] = 5 }, output = { item = 'dirty_money', amount = 5000 }, time = 600000, continuous = true }
    }
  }
}
Config.Labs = {
  [1] = { id = 1, type = 'drug_lab', coords = vector3(1386.07, 3606.16, 38.94), territory_name = 'SANDY', active = true, security = { cameras = true, alarms = true, guards = false } },
  [2] = { id = 2, type = 'weapon_lab', coords = vector3(716.84, -962.05, 30.39), territory_name = 'LMESA', active = true, security = { cameras = true, alarms = true, guards = true } },
  [3] = { id = 3, type = 'drug_lab', coords = vector3(-1150.24, -1425.78, 4.95), territory_name = 'VESPU', active = true, security = { cameras = false, alarms = true, guards = false } },
  [4] = { id = 4, type = 'counterfeit_lab', coords = vector3(1274.25, -1710.45, 54.77), territory_name = 'E_BURR', active = true, security = { cameras = true, alarms = false, guards = false } },
  [5] = { id = 5, type = 'drug_lab', coords = vector3(2434.16, 4968.88, 42.35), territory_name = 'GRAPE', active = true, security = { cameras = false, alarms = false, guards = false } }
}
Config.RequiredItems = {
  ['coca_leaf'] = { name = 'coca_leaf', label = 'Coca Leaf', weight = 100, type = 'item', image = 'coca_leaf.png', unique = false, useable = false, shouldClose = true, description = 'Raw coca leaves for processing' },
  ['sulfuric_acid'] = { name = 'sulfuric_acid', label = 'Sulfuric Acid', weight = 500, type = 'item', image = 'sulfuric_acid.png', unique = false, useable = false, shouldClose = true, description = 'Dangerous chemical' },
  ['acetone'] = { name = 'acetone', label = 'Acetone', weight = 200, type = 'item', image = 'acetone.png', unique = false, useable = false, shouldClose = true, description = 'Chemical solvent' },
  ['ephedrine'] = { name = 'ephedrine', label = 'Ephedrine', weight = 150, type = 'item', image = 'ephedrine.png', unique = false, useable = false, shouldClose = true, description = 'Pharmaceutical ingredient' },
  ['battery_acid'] = { name = 'battery_acid', label = 'Battery Acid', weight = 300, type = 'item', image = 'battery_acid.png', unique = false, useable = false, shouldClose = true, description = 'Corrosive battery acid' },
  ['aluminum'] = { name = 'aluminum', label = 'Aluminum', weight = 80, type = 'item', image = 'aluminum.png', unique = false, useable = false, shouldClose = true, description = 'Lightweight metal' },
  ['copper'] = { name = 'copper', label = 'Copper', weight = 50, type = 'item', image = 'copper.png', unique = false, useable = false, shouldClose = true, description = 'Raw copper' },
  ['steel'] = { name = 'steel', label = 'Steel', weight = 100, type = 'item', image = 'steel.png', unique = false, useable = false, shouldClose = true, description = 'Reinforced steel' },
  ['rubber'] = { name = 'rubber', label = 'Rubber', weight = 60, type = 'item', image = 'rubber.png', unique = false, useable = false, shouldClose = true, description = 'Flexible rubber' },
  ['spring'] = { name = 'spring', label = 'Spring', weight = 20, type = 'item', image = 'spring.png', unique = false, useable = false, shouldClose = true, description = 'Metal spring' },
  ['paper'] = { name = 'paper', label = 'High Quality Paper', weight = 10, type = 'item', image = 'paper.png', unique = false, useable = false, shouldClose = true, description = 'Special paper' },
  ['ink'] = { name = 'ink', label = 'Special Ink', weight = 50, type = 'item', image = 'ink.png', unique = false, useable = false, shouldClose = true, description = 'High-grade printing ink' },
  ['chemicals'] = { name = 'chemicals', label = 'Processing Chemicals', weight = 200, type = 'item', image = 'chemicals.png', unique = false, useable = false, shouldClose = true, description = 'Various processing chemicals' },
  ['cocaine'] = { name = 'cocaine', label = 'Cocaine', weight = 100, type = 'item', image = 'cocaine.png', unique = false, useable = true, shouldClose = true, description = 'Processed cocaine' },
  ['meth'] = { name = 'meth', label = 'Methamphetamine', weight = 80, type = 'item', image = 'meth.png', unique = false, useable = true, shouldClose = true, description = 'Crystal meth' },
  ['dirty_money'] = { name = 'dirty_money', label = 'Counterfeit Bills', weight = 1, type = 'item', image = 'dirty_money.png', unique = false, useable = false, shouldClose = true, description = 'Fake currency' },
  ['lockpick_advanced'] = { name = 'lockpick_advanced', label = 'Advanced Lockpick', weight = 100, type = 'item', image = 'lockpick_advanced.png', unique = false, useable = true, shouldClose = true, description = 'For breaching' },
  ['hacking_device'] = { name = 'hacking_device', label = 'Hacking Device', weight = 500, type = 'item', image = 'hacking_device.png', unique = false, useable = true, shouldClose = true, description = 'Electronic hacking tool' },
  ['emp_device'] = { name = 'emp_device', label = 'EMP Device', weight = 800, type = 'item', image = 'emp_device.png', unique = false, useable = true, shouldClose = true, description = 'EMP device' }
}
Config.DatabaseTables = Config.DatabaseTables or {}
Config.TerritorySettings = {
  influenceThresholds = { full_control = 3, contested = 2, minimal = 1, no_access = 0 },
  influenceGains = { single_production = 3, continuous_production = 2, successful_defense = 10, successful_raid = 15, sabotage = 5 },
  influenceLosses = { failed_defense = 10, lab_sabotaged = 5, territory_lost = 20 }
}
Config.SecuritySettings = {
  cameras = { detection_chance = 0.3, alert_delay = 10000, disable_duration = 120000 },
  alarms = { trigger_chance = 0.5, alert_radius = 200.0, sound_duration = 30000, disable_duration = 180000 },
  guards = { response_time = 60000, combat_difficulty = 2, backup_chance = 0.4, patrol_radius = 100.0 }
}
Config.MinigameSettings = {
  lockpicking = { difficulty = 'medium', time_limit = 30000, success_rate_base = 0.7, skill_bonus = true, failure_consequences = { trigger_alarm = 0.3, break_tool = 0.2 } },
  hacking = { difficulty = 'hard', time_limit = 45000, success_rate_base = 0.6, skill_bonus = true, failure_consequences = { trigger_alarm = 0.5, trace_back = 0.3 } }
}
Config.Exports = { 'GetLabInventory', 'IsLabSabotaged', 'SabotageLab', 'GetPlayerGangId', 'DoesGangControlTerritory', 'GetLabTerritoryName', 'AddLabInfluence' }
