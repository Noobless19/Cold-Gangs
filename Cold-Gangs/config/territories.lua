Config.Territories = {}

-- ======================
-- SYSTEM SETTINGS
-- ======================
Config.Territories.System = {
    enabled = true,
    captureTime = 300000, -- 5 minutes
    incomeInterval = 3600000, -- 1 hour
}

-- ======================
-- TERRITORY LIST
-- ======================
Config.Territories.List = {
    ["downtown_core"] = {
        coords = vector3(-300.0, -900.0, 30.0),
        radius = 60.0,
        income = 1500,
        type = "commercial",
        strategicValue = 10,
        importance = "major"
    },
    ["pillbox_hill"] = {
        coords = vector3(-750.0, -900.0, 30.0),
        radius = 50.0,
        income = 600,
        type = "residential",
        importance = "minor"
    },
    ["little_seoul"] = {
        coords = vector3(-670.0, -900.0, 30.0),
        radius = 55.0,
        income = 800,
        type = "commercial",
        importance = "minor"
    },
    ["textile_city"] = {
        coords = vector3(-400.0, -1000.0, 30.0),
        radius = 70.0,
        income = 900,
        type = "industrial",
        importance = "minor"
    },
    ["grove_street"] = {
        coords = vector3(200.0, -2000.0, 30.0),
        radius = 50.0,
        income = 300,
        type = "residential",
        importance = "minor"
    },
    ["ballas_territory"] = {
        coords = vector3(300.0, -2100.0, 30.0),
        radius = 50.0,
        income = 400,
        type = "residential",
        importance = "minor"
    },
    ["strawberry"] = {
        coords = vector3(321.89, -2039.23, 20.94),
        radius = 60.0,
        income = 500,
        type = "residential",
        importance = "minor"
    },
    ["sandy_shores"] = {
        coords = vector3(1800.0, 3700.0, 30.0),
        radius = 100.0,
        income = 1000,
        type = "residential",
        importance = "minor"
    },
    ["military_bunker"] = {
        coords = vector3(1800.0, 3200.0, 40.0),
        radius = 80.0,
        income = 2000,
        type = "military",
        strategicValue = 10,
        importance = "major"
    },
    ["industrial_yard"] = {
        coords = vector3(700.0, -2200.0, 30.0),
        radius = 90.0,
        income = 1200,
        type = "industrial",
        importance = "minor"
    },
    ["paleto_bay"] = {
        coords = vector3(50.0, 6500.0, 30.0),
        radius = 80.0,
        income = 1100,
        type = "port",
        strategicValue = 9,
        importance = "major"
    },
    ["vespucci_canals"] = {
        coords = vector3(-1315.45, -834.23, 16.96),
        radius = 70.0,
        income = 700,
        type = "residential",
        importance = "minor"
    },
    ["el_burro_heights"] = {
        coords = vector3(1201.73, -1666.22, 43.03),
        radius = 60.0,
        income = 650,
        type = "residential",
        importance = "minor"
    }
}
