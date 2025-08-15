CREATE TABLE IF NOT EXISTS `cold_gangs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `name` varchar(50) NOT NULL,
    `tag` varchar(5) NOT NULL,
    `leader` varchar(50) NOT NULL,
    `color` varchar(7) DEFAULT '#000000',
    `logo` varchar(255) DEFAULT NULL,
    `bank` int(11) DEFAULT 0,
    `reputation` int(11) DEFAULT 0,
    `level` int(11) DEFAULT 1,
    `max_members` int(11) DEFAULT 25,
    `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`),
    UNIQUE KEY `tag` (`tag`)
);

CREATE TABLE IF NOT EXISTS `cold_gang_members` (
    `gang_id` int(11) NOT NULL,
    `citizen_id` varchar(50) NOT NULL,
    `rank` int(11) NOT NULL DEFAULT 1,
    `name` varchar(100) NOT NULL,
    `joined_at` timestamp NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`gang_id`,`citizen_id`),
    CONSTRAINT `fk_gang_members_gang` FOREIGN KEY (`gang_id`) REFERENCES `cold_gangs` (`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `cold_territories` (
    `name` varchar(50) NOT NULL,
    `gang_id` int(11) DEFAULT NULL,
    `gang_name` varchar(50) DEFAULT NULL,
    `claimed_at` timestamp NULL DEFAULT NULL,
    `income_generated` int(11) DEFAULT 0,
    PRIMARY KEY (`name`),
    KEY `gang_id` (`gang_id`),
    CONSTRAINT `fk_territories_gang` FOREIGN KEY (`gang_id`) REFERENCES `cold_gangs` (`id`) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS `cold_gang_stashes` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `gang_id` int(11) NOT NULL,
    `name` varchar(50) NOT NULL,
    `weight` int(11) DEFAULT 1000000,
    `slots` int(11) DEFAULT 50,
    `location` varchar(255) DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `gang_id` (`gang_id`),
    CONSTRAINT `fk_gang_stashes_gang` FOREIGN KEY (`gang_id`) REFERENCES `cold_gangs` (`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `cold_shared_stashes` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `gang_id` int(11) NOT NULL,
    `name` varchar(50) NOT NULL,
    `location` varchar(255) NOT NULL,
    `access_ranks` varchar(255) NOT NULL,
    `weight` int(11) DEFAULT 1000000,
    `slots` int(11) DEFAULT 50,
    PRIMARY KEY (`id`),
    KEY `gang_id` (`gang_id`),
    CONSTRAINT `fk_shared_stashes_gang` FOREIGN KEY (`gang_id`) REFERENCES `cold_gangs` (`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `cold_drug_fields` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `territory_name` varchar(50) NOT NULL,
    `resource_type` varchar(50) NOT NULL,
    `growth_stage` int(11) DEFAULT 0,
    `max_yield` int(11) DEFAULT 10,
    `quality_range_min` int(11) DEFAULT 60,
    `quality_range_max` int(11) DEFAULT 90,
    `owner` int(11) DEFAULT NULL,
    `gang_name` varchar(50) DEFAULT NULL,
    `location` varchar(255) NOT NULL,
    `last_updated` timestamp NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    KEY `territory_name` (`territory_name`),
    KEY `owner` (`owner`),
    CONSTRAINT `fk_drug_fields_territory` FOREIGN KEY (`territory_name`) REFERENCES `cold_territories` (`name`) ON DELETE CASCADE,
    CONSTRAINT `fk_drug_fields_gang` FOREIGN KEY (`owner`) REFERENCES `cold_gangs` (`id`) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS `cold_drug_labs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `territory_name` varchar(50) NOT NULL,
    `drug_type` varchar(50) NOT NULL,
    `level` int(11) DEFAULT 1,
    `capacity` int(11) DEFAULT 100,
    `owner` int(11) DEFAULT NULL,
    `gang_name` varchar(50) DEFAULT NULL,
    `location` varchar(255) NOT NULL,
    `security` int(11) DEFAULT 50,
    `last_updated` timestamp NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    KEY `territory_name` (`territory_name`),
    KEY `owner` (`owner`),
    CONSTRAINT `fk_drug_labs_territory` FOREIGN KEY (`territory_name`) REFERENCES `cold_territories` (`name`) ON DELETE CASCADE,
    CONSTRAINT `fk_drug_labs_gang` FOREIGN KEY (`owner`) REFERENCES `cold_gangs` (`id`) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS `cold_gang_businesses` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `gang_id` int(11) NOT NULL,
    `type` varchar(50) NOT NULL,
    `level` int(11) DEFAULT 1,
    `income` int(11) DEFAULT 0,
    `income_stored` int(11) DEFAULT 0,
    `last_payout` timestamp NOT NULL DEFAULT current_timestamp(),
    `location` varchar(255) NOT NULL,
    `employees` int(11) DEFAULT 0,
    `security` int(11) DEFAULT 1,
    `capacity` int(11) DEFAULT 5,
    `last_income_update` timestamp NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    KEY `gang_id` (`gang_id`),
    CONSTRAINT `fk_businesses_gang` FOREIGN KEY (`gang_id`) REFERENCES `cold_gangs` (`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `cold_active_wars` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `attacker_id` int(11) NOT NULL,
    `defender_id` int(11) NOT NULL,
    `attacker_name` varchar(50) NOT NULL,
    `defender_name` varchar(50) NOT NULL,
    `territory_name` varchar(50) DEFAULT NULL,
    `started_at` timestamp NOT NULL DEFAULT current_timestamp(),
    `attacker_score` int(11) DEFAULT 0,
    `defender_score` int(11) DEFAULT 0,
    `max_score` int(11) DEFAULT 100,
    `status` varchar(20) DEFAULT 'active',
    `winner_id` int(11) DEFAULT NULL,
    `ended_at` timestamp NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `attacker_id` (`attacker_id`),
    KEY `defender_id` (`defender_id`),
    KEY `territory_name` (`territory_name`),
    CONSTRAINT `fk_wars_attacker` FOREIGN KEY (`attacker_id`) REFERENCES `cold_gangs` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_wars_defender` FOREIGN KEY (`defender_id`) REFERENCES `cold_gangs` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_wars_territory` FOREIGN KEY (`territory_name`) REFERENCES `cold_territories` (`name`) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS `cold_active_heists` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `heist_type` varchar(50) NOT NULL,
    `gang_id` int(11) NOT NULL,
    `status` varchar(20) DEFAULT 'active',
    `start_time` timestamp NOT NULL DEFAULT current_timestamp(),
    `participants` text DEFAULT NULL,
    `current_stage` int(11) DEFAULT 1,
    `rewards` text DEFAULT NULL,
    `location` text DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `gang_id` (`gang_id`),
    CONSTRAINT `fk_heists_gang` FOREIGN KEY (`gang_id`) REFERENCES `cold_gangs` (`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `cold_gang_vehicles` (
    `plate` varchar(8) NOT NULL,
    `gang_id` int(11) NOT NULL,
    `model` varchar(50) NOT NULL,
    `label` varchar(50) NOT NULL,
    `stored` tinyint(1) DEFAULT 1,
    `impounded` tinyint(1) DEFAULT 0,
    `last_seen` timestamp NOT NULL DEFAULT current_timestamp(),
    `location` text DEFAULT NULL,
    PRIMARY KEY (`plate`),
    KEY `gang_id` (`gang_id`),
    CONSTRAINT `fk_vehicles_gang` FOREIGN KEY (`gang_id`) REFERENCES `cold_gangs` (`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `cold_gang_transactions` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `gang_id` int(11) NOT NULL,
    `amount` int(11) NOT NULL,
    `description` varchar(255) NOT NULL,
    `timestamp` timestamp NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    KEY `gang_id` (`gang_id`),
    CONSTRAINT `fk_transactions_gang` FOREIGN KEY (`gang_id`) REFERENCES `cold_gangs` (`id`) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS `cold_heist_cooldowns` (
    `heist_type` varchar(50) NOT NULL,
    `last_completed` timestamp NOT NULL DEFAULT current_timestamp(),
    `available_at` timestamp NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`heist_type`)
);

CREATE TABLE IF NOT EXISTS `cold_gang_logs` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `gang_id` int(11) NOT NULL,
    `action` varchar(50) NOT NULL,
    `details` text DEFAULT NULL,
    `timestamp` timestamp NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    KEY `gang_id` (`gang_id`),
    CONSTRAINT `fk_logs_gang` FOREIGN KEY (`gang_id`) REFERENCES `cold_gangs` (`id`) ON DELETE CASCADE
);
