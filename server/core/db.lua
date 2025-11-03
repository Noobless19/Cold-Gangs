local function exec(sql, params)
  if params then
    return MySQL.Sync.execute(sql, params)
  else
    return MySQL.Sync.execute(sql)
  end
end

local function fetchAll(sql, params)
  return MySQL.Sync.fetchAll(sql, params or {})
end

local function columnExists(tbl, col)
  local rows = fetchAll(("SHOW COLUMNS FROM `%s` LIKE ?"):format(tbl), { col })
  return rows and #rows > 0
end

local function addColumnIfMissing(tbl, col, ddl)
  if not columnExists(tbl, col) then
    exec(("ALTER TABLE `%s` ADD COLUMN %s"):format(tbl, ddl))
    print(("[cold-gangs][db] Added column %s.%s"):format(tbl, col))
  end
end

local function normalizeTextColumn(tbl, col, longtext)
  -- Remove default on TEXT/LONGTEXT and allow NULL (safe for most MySQL/MariaDB)
  local t = longtext and "LONGTEXT" or "TEXT"
  local ok, err = pcall(function()
    exec(("ALTER TABLE `%s` MODIFY `%s` %s NULL"):format(tbl, col, t))
  end)
  if ok then
    print(("[cold-gangs][db] Normalized %s.%s to %s NULL"):format(tbl, col, t))
  end
end

local function createAllTables()
  -- Gangs
  exec([[
    CREATE TABLE IF NOT EXISTS cold_gangs (
      id INT AUTO_INCREMENT PRIMARY KEY,
      name VARCHAR(50) NOT NULL,
      tag  VARCHAR(10) NOT NULL,
      leader VARCHAR(50) NOT NULL,
      level INT DEFAULT 1,
      bank  INT DEFAULT 0,
      reputation INT DEFAULT 0,
      max_members INT DEFAULT 25,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      color VARCHAR(10) DEFAULT '#ff3e3e',
      logo TEXT
    )
  ]])

  -- Members
  exec([[
    CREATE TABLE IF NOT EXISTS cold_gang_members (
      id INT AUTO_INCREMENT PRIMARY KEY,
      gang_id INT NOT NULL,
      citizen_id VARCHAR(50) NOT NULL,
      rank INT DEFAULT 1,
      name VARCHAR(100) NOT NULL,
      joined_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (gang_id) REFERENCES cold_gangs(id) ON DELETE CASCADE,
      INDEX idx_gang_id (gang_id),
      INDEX idx_citizen (citizen_id)
    )
  ]])

  -- Territories (unified schema, includes zone_points and influence_map; no TEXT defaults)
  exec([[
    CREATE TABLE IF NOT EXISTS territories (
      name VARCHAR(50) PRIMARY KEY,
      gang_id INT NULL,
      gang_name VARCHAR(100) DEFAULT 'Unclaimed',
      claimed_at DATETIME NULL,
      income_generated INT DEFAULT 0,
      influence INT DEFAULT 0,
      upgrades TEXT NULL,
      coords   TEXT NULL,
      center_x FLOAT DEFAULT 0,
      center_y FLOAT DEFAULT 0,
      center_z FLOAT DEFAULT 0,
      value INT DEFAULT 1000,
      contested TINYINT DEFAULT 0,
      contested_by INT NULL,
      color_hex VARCHAR(10) DEFAULT '#808080',
      zone_points LONGTEXT NULL,
      influence_map LONGTEXT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_gang_id (gang_id)
    )
  ]])

  -- Territory activity log (optional analytics)
  exec([[
    CREATE TABLE IF NOT EXISTS gang_territory_activities (
      id INT AUTO_INCREMENT PRIMARY KEY,
      gang_id INT NOT NULL,
      territory_name VARCHAR(50) NOT NULL,
      activity_type VARCHAR(50) NOT NULL,
      amount INT DEFAULT 1,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_gang_id (gang_id),
      INDEX idx_territory (territory_name),
      INDEX idx_timestamp (timestamp)
    )
  ]])

  -- Stashes
  exec([[
    CREATE TABLE IF NOT EXISTS cold_gang_stashes (
      id INT AUTO_INCREMENT PRIMARY KEY,
      gang_id INT NOT NULL,
      name VARCHAR(50) NOT NULL,
      weight INT DEFAULT 1000000,
      slots  INT DEFAULT 50,
      location TEXT,
      FOREIGN KEY (gang_id) REFERENCES cold_gangs(id) ON DELETE CASCADE,
      INDEX idx_gang (gang_id)
    )
  ]])

  -- Shared stashes
  exec([[
    CREATE TABLE IF NOT EXISTS cold_shared_stashes (
      id INT AUTO_INCREMENT PRIMARY KEY,
      gang_id INT NOT NULL,
      name VARCHAR(50) NOT NULL,
      location TEXT,
      access_ranks TEXT,
      weight INT DEFAULT 1000000,
      slots  INT DEFAULT 50,
      FOREIGN KEY (gang_id) REFERENCES cold_gangs(id) ON DELETE CASCADE,
      INDEX idx_gang (gang_id)
    )
  ]])

  -- Transactions (adds reason column with safe default)
  exec([[
    CREATE TABLE IF NOT EXISTS cold_gang_transactions (
      id INT AUTO_INCREMENT PRIMARY KEY,
      gang_id INT NOT NULL,
      amount INT NOT NULL,
      description TEXT,
      reason VARCHAR(64) NOT NULL DEFAULT 'other',
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (gang_id) REFERENCES cold_gangs(id) ON DELETE CASCADE,
      INDEX idx_gang (gang_id),
      INDEX idx_time (timestamp),
      INDEX idx_reason (reason)
    )
  ]])

  -- Drug labs
  exec([[
    CREATE TABLE IF NOT EXISTS cold_drug_labs (
      id INT AUTO_INCREMENT PRIMARY KEY,
      territory_name VARCHAR(50) NOT NULL,
      drug_type VARCHAR(50) NOT NULL,
      level INT DEFAULT 1,
      capacity INT DEFAULT 100,
      owner INT,
      gang_name VARCHAR(50),
      location TEXT,
      security INT DEFAULT 50,
      last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (owner) REFERENCES cold_gangs(id) ON DELETE SET NULL,
      INDEX idx_owner (owner),
      INDEX idx_territory (territory_name)
    )
  ]])

  -- Drug fields
  exec([[
    CREATE TABLE IF NOT EXISTS cold_drug_fields (
      id INT AUTO_INCREMENT PRIMARY KEY,
      territory_name VARCHAR(50) NOT NULL,
      resource_type VARCHAR(50) NOT NULL,
      growth_stage INT DEFAULT 0,
      max_yield INT DEFAULT 100,
      quality_range_min INT DEFAULT 1,
      quality_range_max INT DEFAULT 100,
      owner INT,
      gang_name VARCHAR(50),
      location TEXT,
      last_updated DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (owner) REFERENCES cold_gangs(id) ON DELETE SET NULL,
      INDEX idx_owner (owner),
      INDEX idx_territory (territory_name)
    )
  ]])

  -- Businesses
  exec([[
    CREATE TABLE IF NOT EXISTS cold_gang_businesses (
      id INT AUTO_INCREMENT PRIMARY KEY,
      gang_id INT NOT NULL,
      type VARCHAR(50) NOT NULL,
      level INT DEFAULT 1,
      income INT DEFAULT 0,
      income_stored INT DEFAULT 0,
      last_payout DATETIME DEFAULT CURRENT_TIMESTAMP,
      location TEXT,
      employees INT DEFAULT 0,
      security  INT DEFAULT 1,
      capacity  INT DEFAULT 5,
      last_income_update DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (gang_id) REFERENCES cold_gangs(id) ON DELETE CASCADE,
      INDEX idx_gang (gang_id)
    )
  ]])

  -- Wars
  exec([[
    CREATE TABLE IF NOT EXISTS cold_active_wars (
      id INT AUTO_INCREMENT PRIMARY KEY,
      attacker_id INT NOT NULL,
      defender_id INT NOT NULL,
      attacker_name VARCHAR(50) NOT NULL,
      defender_name VARCHAR(50) NOT NULL,
      territory_name VARCHAR(50) NOT NULL,
      started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      attacker_score INT DEFAULT 0,
      defender_score INT DEFAULT 0,
      max_score INT DEFAULT 100,
      status VARCHAR(20) DEFAULT 'active',
      winner_id INT NULL,
      ended_at DATETIME NULL,
      FOREIGN KEY (attacker_id) REFERENCES cold_gangs(id) ON DELETE CASCADE,
      FOREIGN KEY (defender_id) REFERENCES cold_gangs(id) ON DELETE CASCADE,
      INDEX idx_territory (territory_name),
      INDEX idx_status (status)
    )
  ]])

  -- Heists
  exec([[
    CREATE TABLE IF NOT EXISTS cold_active_heists (
      id INT AUTO_INCREMENT PRIMARY KEY,
      heist_type VARCHAR(50) NOT NULL,
      gang_id INT NOT NULL,
      status VARCHAR(20) DEFAULT 'active',
      start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
      participants TEXT,
      current_stage INT DEFAULT 1,
      rewards TEXT,
      location TEXT,
      FOREIGN KEY (gang_id) REFERENCES cold_gangs(id) ON DELETE CASCADE,
      INDEX idx_gang (gang_id),
      INDEX idx_type (heist_type),
      INDEX idx_status (status)
    )
  ]])

  -- Vehicles
  exec([[
    CREATE TABLE IF NOT EXISTS cold_gang_vehicles (
      plate VARCHAR(12) PRIMARY KEY,
      gang_id INT NOT NULL,
      model VARCHAR(50) NOT NULL,
      label VARCHAR(50),
      stored TINYINT DEFAULT 1,
      impounded TINYINT DEFAULT 0,
      last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
      location TEXT,
      mods TEXT,
      registered_by VARCHAR(50),
      registered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (gang_id) REFERENCES cold_gangs(id) ON DELETE CASCADE,
      INDEX idx_gang (gang_id),
      INDEX idx_stored (stored),
      INDEX idx_impounded (impounded)
    )
  ]])

  -- Logs
  exec([[
    CREATE TABLE IF NOT EXISTS cold_gang_logs (
      id INT AUTO_INCREMENT PRIMARY KEY,
      gang_id INT NOT NULL,
      action VARCHAR(50) NOT NULL,
      details TEXT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (gang_id) REFERENCES cold_gangs(id) ON DELETE CASCADE,
      INDEX idx_gang (gang_id),
      INDEX idx_action (action),
      INDEX idx_time (timestamp)
    )
  ]])

  -- Heist cooldowns
  exec([[
    CREATE TABLE IF NOT EXISTS cold_heist_cooldowns (
      id INT AUTO_INCREMENT PRIMARY KEY,
      heist_type VARCHAR(50) NOT NULL UNIQUE,
      last_completed DATETIME DEFAULT CURRENT_TIMESTAMP,
      available_at DATETIME NOT NULL
    )
  ]])

  -- Labs: inventory
  exec([[
    CREATE TABLE IF NOT EXISTS gang_lab_inventory (
      id INT AUTO_INCREMENT PRIMARY KEY,
      lab_id VARCHAR(50) NOT NULL,
      item VARCHAR(100) NOT NULL,
      amount INT NOT NULL DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY unique_lab_item (lab_id, item),
      KEY idx_lab_id (lab_id)
    )
  ]])

  -- Labs: states
  exec([[
    CREATE TABLE IF NOT EXISTS gang_lab_states (
      lab_id VARCHAR(50) PRIMARY KEY,
      is_producing TINYINT(1) NOT NULL DEFAULT 0,
      production_start_time DATETIME DEFAULT NULL,
      production_duration INT NOT NULL DEFAULT 0,
      recipe VARCHAR(100) DEFAULT NULL,
      player_id INT DEFAULT NULL,
      is_sabotaged TINYINT(1) NOT NULL DEFAULT 0,
      sabotage_expires DATETIME DEFAULT NULL,
      sabotaged_by VARCHAR(50) DEFAULT NULL,
      security_disabled TINYINT(1) NOT NULL DEFAULT 0,
      security_expires DATETIME DEFAULT NULL,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )
  ]])

  -- Labs: continuous
  exec([[
    CREATE TABLE IF NOT EXISTS gang_lab_continuous (
      id INT AUTO_INCREMENT PRIMARY KEY,
      lab_id VARCHAR(50) NOT NULL,
      recipe VARCHAR(100) NOT NULL,
      total_produced INT NOT NULL DEFAULT 0,
      last_production DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      production_interval INT NOT NULL DEFAULT 0,
      active TINYINT(1) NOT NULL DEFAULT 1,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      UNIQUE KEY unique_lab_continuous (lab_id),
      KEY idx_lab_id (lab_id),
      KEY idx_active (active)
    )
  ]])

  -- Labs: production history
  exec([[
    CREATE TABLE IF NOT EXISTS gang_lab_production_history (
      id INT AUTO_INCREMENT PRIMARY KEY,
      lab_id VARCHAR(50) NOT NULL,
      recipe VARCHAR(100) NOT NULL,
      player_id INT NOT NULL,
      gang_id VARCHAR(50) DEFAULT NULL,
      inputs LONGTEXT,
      outputs LONGTEXT,
      production_time INT NOT NULL DEFAULT 0,
      completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      KEY idx_lab_id (lab_id),
      KEY idx_player_id (player_id),
      KEY idx_gang_id (gang_id),
      KEY idx_completed_at (completed_at)
    )
  ]])

  -- Graffitis
  exec([[
    CREATE TABLE IF NOT EXISTS gang_graffitis (
      id INT AUTO_INCREMENT PRIMARY KEY,
      gang_id INT NOT NULL,
      gang_name VARCHAR(50) NOT NULL,
      territory VARCHAR(50) NULL,
      coords_x FLOAT NOT NULL,
      coords_y FLOAT NOT NULL,
      coords_z FLOAT NOT NULL,
      rotation_x FLOAT NOT NULL DEFAULT 0,
      rotation_y FLOAT NOT NULL DEFAULT 0,
      rotation_z FLOAT NOT NULL DEFAULT 0,
      surface_normal_x FLOAT NOT NULL DEFAULT 0,
      surface_normal_y FLOAT NOT NULL DEFAULT 1,
      surface_normal_z FLOAT NOT NULL DEFAULT 0,
      graffiti_type ENUM('text','logo') NOT NULL DEFAULT 'text',
      graffiti_text VARCHAR(50) NULL,
      graffiti_logo VARCHAR(50) NULL,
      creator_citizenid VARCHAR(50) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_gang (gang_id),
      INDEX idx_territory (territory),
      INDEX idx_coords (coords_x, coords_y, coords_z)
    )
  ]])
end

local function runMigrations()
  -- Transactions: reason column required
  addColumnIfMissing('cold_gang_transactions', 'reason', "reason VARCHAR(64) NOT NULL DEFAULT 'other'")

  -- Territories: ensure columns exist for older installations
  addColumnIfMissing('territories', 'zone_points', "zone_points LONGTEXT NULL")
  addColumnIfMissing('territories', 'influence_map', "influence_map LONGTEXT NULL")

  -- Normalize TEXT columns (remove invalid defaults if server created them improperly before)
  normalizeTextColumn('territories', 'upgrades', false)
  normalizeTextColumn('territories', 'coords',   false)

  -- Optional: add helpful indexes if missing (safe to attempt)
  pcall(function() exec("ALTER TABLE `cold_gang_transactions` ADD INDEX `idx_gang_time` (gang_id, timestamp)") end)
  pcall(function() exec("ALTER TABLE `territories` ADD INDEX `idx_gang` (gang_id)") end)
end

local function initDb()
  createAllTables()
  runMigrations()
  print("[cold-gangs][db] Schema ensured and migrations applied")
end

-- Prefer oxmysql ready hook when available
if MySQL and MySQL.ready then
  MySQL.ready(function()
    initDb()
  end)
else
  -- Fallback if MySQL.ready not exposed
  CreateThread(function()
    -- give oxmysql a moment on cold boots
    Wait(1500)
    initDb()
  end)
end
