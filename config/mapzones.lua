Config = Config or {}
Config.Territories = Config.Territories or {}

Config.Territories.Types = {
  ['major_strategic'] = { 
    name = 'Major Strategic Zone', 
    baseIncome = 8000,
    hasFront = true,
    frontTier = 'premium'
  },
  ['minor_strategic'] = { 
    name = 'Minor Strategic Zone', 
    baseIncome = 3000,
    hasFront = true,
    frontTier = 'advanced'
  },
  ['commercial'] = { 
    name = 'Commercial District', 
    baseIncome = 2000,
    hasFront = true,
    frontTier = 'standard'
  },
  ['industrial'] = { 
    name = 'Industrial Zone', 
    baseIncome = 1800,
    hasFront = true,
    frontTier = 'standard'
  },
  ['residential'] = { 
    name = 'Residential Area', 
    baseIncome = 500,
    hasFront = true,
    frontTier = 'basic'
  },
  ['port'] = { 
    name = 'Port Facility', 
    baseIncome = 3500,
    hasFront = true,
    frontTier = 'advanced'
  },
  ['airport'] = { 
    name = 'Airport Zone', 
    baseIncome = 9000,
    hasFront = true,
    frontTier = 'premium'
  }
}

Config.MapZones = {
  DOWNT = { name = 'DOWNT', label = 'Downtown Core', type = 'major_strategic', neighbors = { 'TEXTL', 'PILLB', 'KOREAT', 'MIRRP', 'HAWICK', 'DTVIEW' }, parts = { { x1 = 48.53, y1 = -20.78, x2 = 695.87, y2 = 445.02 } } },
  TEXTL = { name = 'TEXTL', label = 'Textile City', type = 'industrial', neighbors = { 'DOWNT', 'KOREAT', 'PILLB', 'CYPFL' }, parts = { { x1 = 285.43, y1 = -877.91, x2 = 505.03, y2 = -510.0 } } },
  KOREAT = { name = 'KOREAT', label = 'Little Seoul', type = 'residential', neighbors = { 'DOWNT', 'TEXTL', 'PILLB', 'MORN' }, parts = { { x1 = -1127.62, y1 = -723.01, x2 = -1072.88, y2 = -576.61 }, { x1 = -1072.88, y1 = -723.01, x2 = -998.41, y2 = -543.51 }, { x1 = -931.96, y1 = -849.49, x2 = -774.41, y2 = -723.01 }, { x1 = -865.98, y1 = -907.78, x2 = -774.41, y2 = -849.49 }, { x1 = -812.41, y1 = -1019.71, x2 = -774.41, y2 = -907.78 }, { x1 = -998.41, y1 = -723.01, x2 = -403.51, y2 = -511.48 }, { x1 = -920.61, y1 = -511.48, x2 = -521.31, y2 = -465.30 }, { x1 = -573.84, y1 = -1425.40, x2 = -403.51, y2 = -1158.02 }, { x1 = -774.41, y1 = -1158.02, x2 = -354.71, y2 = -723.01 } } },
  PILLB = { name = 'PILLB', label = 'Pillbox Hill', type = 'residential', neighbors = { 'DOWNT', 'TEXTL', 'KOREAT', 'CHAMH', 'MIRRP' }, parts = { { x1 = -276.21, y1 = -722.91, x2 = 285.43, y2 = -573.01 }, { x1 = -354.71, y1 = -1158.02, x2 = 119.43, y2 = -722.91 }, { x1 = 199.43, y1 = -877.91, x2 = 285.43, y2 = -722.91 }, { x1 = 119.43, y1 = -1158.02, x2 = 199.43, y2 = -722.91 } } },
  MORN = { name = 'MORN', label = 'Morningwood', type = 'residential', neighbors = { 'KOREAT', 'ROCKF', 'WVINE', 'CHAMH' }, parts = { { x1 = -1635.47, y1 = -500.0, x2 = -1379.12, y2 = -107.29 }, { x1 = -1379.12, y1 = -511.5, x2 = -1299.88, y2 = -257.26 } } },
  WVINE = { name = 'WVINE', label = 'West Vinewood', type = 'residential', neighbors = { 'MORN', 'ROCKF', 'MOVIE', 'BURTON', 'HAWICK' }, parts = { { x1 = -743.39, y1 = 13.47, x2 = 48.53, y2 = 445.02 }, { x1 = -246.39, y1 = -20.78, x2 = 48.53, y2 = 13.48 } } },
  MOVIE = { name = 'MOVIE', label = 'Vinewood', type = 'commercial', neighbors = { 'WVINE', 'ROCKF', 'VINEH', 'HAWICK' }, parts = { { x1 = -1380.23, y1 = -849.50, x2 = -1172.24, y2 = -511.48 }, { x1 = -1172.24, y1 = -576.61, x2 = -1072.88, y2 = -543.51 }, { x1 = -1172.24, y1 = -722.8, x2 = -1127.62, y2 = -576.61 }, { x1 = -1172.24, y1 = -543.51, x2 = -998.41, y2 = -511.48 }, { x1 = -1299.88, y1 = -511.48, x2 = -920.5, y2 = -407.23 } } },
  ROCKF = { name = 'ROCKF', label = 'Rockford Hills', type = 'commercial', neighbors = { 'MORN', 'WVINE', 'MOVIE', 'BURTON', 'RICHM' }, parts = { { x1 = -1379.12, y1 = -257.26, x2 = -1299.88, y2 = -38.12 }, { x1 = -920.61, y1 = -465.30, x2 = -521.31, y2 = -407.48 }, { x1 = -1299.5, y1 = -407.3, x2 = -550.21, y2 = -126.82 }, { x1 = -1299.55, y1 = -126.82, x2 = -743.39, y2 = 445.02 }, { x1 = -743.39, y1 = -126.82, x2 = -594.91, y2 = 13.48 } } },
  BURTON = { name = 'BURTON', label = 'Burton', type = 'commercial', neighbors = { 'ROCKF', 'WVINE', 'DOWNT', 'HAWICK' }, parts = { { x1 = -594.91, y1 = -126.82, x2 = -246.39, y2 = 13.48 }, { x1 = -550.21, y1 = -310.80, x2 = -246.39, y2 = -126.82 }, { x1 = -246.39, y1 = -378.61, x2 = -90.0, y2 = -20.78 }, { x1 = -246.39, y1 = -452.98, x2 = -90.0, y2 = -378.61 } } },
  HAWICK = { name = 'HAWICK', label = 'Hawick', type = 'commercial', neighbors = { 'BURTON', 'DOWNT', 'MOVIE', 'DELPER', 'MIRRP' }, parts = { { x1 = -90.0, y1 = -177.0, x2 = 695.87, y2 = -20.78 } } },
  DELP = { name = 'DELP', label = 'Del Perro', type = 'commercial', neighbors = { 'HAWICK', 'MIRRP', 'CHAMH' }, parts = { { x1 = 199.43, y1 = -1158.02, x2 = 505.03, y2 = -877.91 } } },
  MIRRP = { name = 'MIRRP', label = 'Mirror Park', type = 'residential', neighbors = { 'DOWNT', 'PILLB', 'CHAMH', 'DELP', 'HAWICK' }, parts = { { x1 = 869.70, y1 = -820.90, x2 = 1391.07, y2 = -282.32 } } },
  CHAMH = { name = 'CHAMH', label = 'Chamberlain Hills', type = 'residential', neighbors = { 'PILLB', 'MIRRP', 'DELP', 'MORN', 'STRAW' }, parts = { { x1 = -283.92, y1 = -1761.99, x2 = -63.92, y2 = -1425.40 } } },
  STRAW = { name = 'STRAW', label = 'Strawberry', type = 'residential', neighbors = { 'CHAMH', 'DAVIS', 'MAZE' }, parts = { { x1 = -63.92, y1 = -1700.53, x2 = 91.27, y2 = -1425.40 }, { x1 = -403.51, y1 = -1425.40, x2 = 359.48, y2 = -1158.02 } } },
  DAVIS = { name = 'DAVIS', label = 'Davis', type = 'residential', neighbors = { 'STRAW', 'RANCHO', 'BALLY', 'MAZE' }, parts = { { x1 = -63.92, y1 = -1761.99, x2 = 271.51, y2 = -1700.53 }, { x1 = 91.27, y1 = -1700.53, x2 = 271.51, y2 = -1613.16 }, { x1 = 91.27, y1 = -1613.16, x2 = 359.48, y2 = -1425.40 }, { x1 = -139.74, y1 = -2022.57, x2 = -9.70, y2 = -1761.99 }, { x1 = -9.70, y1 = -2022.57, x2 = 115.40, y2 = -1761.99 }, { x1 = 115.40, y1 = -2022.57, x2 = 222.40, y2 = -1761.99 } } },
  RANCHO = { name = 'RANCHO', label = 'Rancho', type = 'residential', neighbors = { 'DAVIS', 'BALLY', 'CYPFL', 'E_BURR' }, parts = { { x1 = 359.48, y1 = -1761.99, x2 = 618.43, y2 = -1158.02 }, { x1 = 271.51, y1 = -1761.99, x2 = 359.48, y2 = -1613.16 }, { x1 = 222.40, y1 = -2022.57, x2 = 505.03, y2 = -1761.99 }, { x1 = 123.73, y1 = -2168.95, x2 = 505.03, y2 = -2022.57 } } },
  CYPFL = { name = 'CYPFL', label = 'Cypress Flats', type = 'residential', neighbors = { 'RANCHO', 'BALLY', 'E_BURR', 'GROVE' }, parts = { { x1 = 618.7, y1 = -2718.48, x2 = 921.45, y2 = -1708.33 }, { x1 = 921.45, y1 = -2718.48, x2 = 1048.54, y2 = -1901.45 } } },
  E_BURR = { name = 'E_BURR', label = 'El Burro Heights', type = 'residential', neighbors = { 'RANCHO', 'CYPFL', 'GROVE' }, parts = { { x1 = 1118.89, y1 = -1901.45, x2 = 1485.92, y2 = -1391.50 } } },
  SANDY = { name = 'SANDY', label = 'Sandy Shores', type = 'residential', neighbors = { 'GR_SEN', 'HARMONY', 'STAB', 'ALAMO' }, parts = { { x1 = 1295.66, y1 = 3455.35, x2 = 2145.09, y2 = 4012.51 }, { x1 = 2413.98, y1 = 3554.05, x2 = 2807.76, y2 = 4036.53 }, { x1 = 2145.09, y1 = 3554.05, x2 = 2413.98, y2 = 3819.50 }, { x1 = 2145.09, y1 = 3294.46, x2 = 2693.05, y2 = 3554.05 }, { x1 = 2083.31, y1 = 3925.83, x2 = 2145.09, y2 = 3954.88 }, { x1 = 2057.38, y1 = 3954.88, x2 = 2145.09, y2 = 4012.50 }, { x1 = 1990.20, y1 = 3973.64, x2 = 2057.38, y2 = 4012.51 }, { x1 = 1976.69, y1 = 3981.51, x2 = 1990.20, y2 = 3995.50 }, { x1 = 1752.23, y1 = 3995.50, x2 = 1990.20, y2 = 4012.50 }, { x1 = 1691.23, y1 = 3983.57, x2 = 1752.23, y2 = 4012.50 }, { x1 = 1691.23, y1 = 3967.40, x2 = 1713.04, y2 = 3983.58 }, { x1 = 1446.97, y1 = 3954.97, x2 = 1691.23, y2 = 4012.50 }, { x1 = 1446.97, y1 = 3930.21, x2 = 1683.75, y2 = 3954.97 }, { x1 = 1446.97, y1 = 3888.02, x2 = 1508.13, y2 = 3930.21 }, { x1 = 1508.13, y1 = 3888.02, x2 = 1540.87, y2 = 3904.46 }, { x1 = 1532.13, y1 = 3856.76, x2 = 1584.82, y2 = 3888.02 }, { x1 = 1446.97, y1 = 3819.74, x2 = 1532.13, y2 = 3888.02 }, { x1 = 1295.66, y1 = 3888.02, x2 = 1446.97, y2 = 4012.51 }, { x1 = 1295.66, y1 = 3812.33, x2 = 1388.96, y2 = 3888.02 }, { x1 = 1295.66, y1 = 3741.06, x2 = 1356.98, y2 = 3812.33 }, { x1 = 1295.66, y1 = 3713.35, x2 = 1325.48, y2 = 3741.06 } } },
  PALETO = { name = 'PALETO', label = 'Paleto Bay', type = 'residential', neighbors = { 'PFOREST', 'GREATC', 'PROBE' }, parts = { { x1 = -333.95, y1 = 6006.86, x2 = -188.97, y2 = 6147.87 }, { x1 = -282.23, y1 = 6147.87, x2 = -137.25, y2 = 6288.88 }, { x1 = -137.25, y1 = 6195.79, x2 = 7.74, y2 = 6336.80 }, { x1 = -59.31, y1 = 6336.80, x2 = 66.28, y2 = 6452.00 }, { x1 = 66.28, y1 = 6409.34, x2 = 211.26, y2 = 6518.35 }, { x1 = 110.86, y1 = 6518.35, x2 = 516.84, y2 = 6614.36 }, { x1 = -680.83, y1 = 6147.87, x2 = -282.23, y2 = 6288.88 }, { x1 = -598.05, y1 = 6288.88, x2 = -137.25, y2 = 6477.81 }, { x1 = 66.28, y1 = 6518.35, x2 = 110.86, y2 = 6614.36 }, { x1 = -357.76, y1 = 6477.81, x2 = 66.28, y2 = 6614.36 }, { x1 = 10.82, y1 = 6614.36, x2 = 133.50, y2 = 7165.53 }, { x1 = -188.97, y1 = 6006.86, x2 = -39.51, y2 = 6147.87 }, { x1 = -137.25, y1 = 6147.87, x2 = -39.51, y2 = 6195.79 }, { x1 = 7.74, y1 = 6195.79, x2 = 66.28, y2 = 6336.80 }, { x1 = -137.25, y1 = 6336.80, x2 = -59.31, y2 = 6477.81 }, { x1 = -59.31, y1 = 6452.00, x2 = 66.28, y2 = 6477.81 }, { x1 = -481.00, y1 = 6006.37, x2 = -333.95, y2 = 6147.87 }, { x1 = -112.83, y1 = 6614.36, x2 = 10.82, y2 = 6786.93 }, { x1 = -202.03, y1 = 6614.36, x2 = -112.83, y2 = 6703.23 }, { x1 = -164.47, y1 = 6703.23, x2 = -112.83, y2 = 6744.03 }, { x1 = 133.50, y1 = 6614.36, x2 = 465.00, y2 = 6785.33 }, { x1 = 133.50, y1 = 6785.33, x2 = 387.30, y2 = 6900.54 }, { x1 = 133.50, y1 = 6900.54, x2 = 284.08, y2 = 6996.90 }, { x1 = 133.50, y1 = 6996.90, x2 = 224.78, y2 = 7065.80 }, { x1 = 465.00, y1 = 6705.98, x2 = 617.57, y2 = 6745.77 }, { x1 = 387.30, y1 = 6785.33, x2 = 473.72, y2 = 6840.19 }, { x1 = 284.08, y1 = 6900.54, x2 = 386.59, y2 = 6949.75 }, { x1 = 133.50, y1 = 7065.80, x2 = 193.80, y2 = 7165.53 }, { x1 = 224.78, y1 = 6996.90, x2 = 277.79, y2 = 7065.80 }, { x1 = 284.08, y1 = 6949.75, x2 = 332.08, y2 = 6996.90 }, { x1 = 387.30, y1 = 6840.19, x2 = 430.30, y2 = 6900.54 }, { x1 = 465.00, y1 = 6745.77, x2 = 541.00, y2 = 6785.33 }, { x1 = 465.00, y1 = 6614.36, x2 = 617.57, y2 = 6705.98 }, { x1 = -43.31, y1 = 6882.58, x2 = 10.82, y2 = 7165.53 }, { x1 = -103.31, y1 = 6786.93, x2 = 10.82, y2 = 6882.58 }, { x1 = -234.25, y1 = 6006.86, x2 = -188.97, y2 = 6046.44 }, { x1 = -61.55, y1 = 6006.86, x2 = -39.51, y2 = 6025.03 }, { x1 = -165.24, y1 = 6006.86, x2 = -149.20, y2 = 6021.46 }, { x1 = -58.57, y1 = 6115.46, x2 = -39.51, y2 = 6147.87 }, { x1 = -117.17, y1 = 6056.50, x2 = -39.51, y2 = 6115.46 }, { x1 = -108.56, y1 = 6006.86, x2 = -88.03, y2 = 6017.70 }, { x1 = -128.49, y1 = 6020.11, x2 = -93.62, y2 = 6045.88 } } },
  GRAPE = { name = 'GRAPE', label = 'Grapeseed', type = 'residential', neighbors = { 'CHILIAD', 'SANDY', 'HARMONY' }, parts = { { x1 = 1605.27, y1 = 4543.62, x2 = 2413.98, y2 = 5269.38 }, { x1 = 2413.98, y1 = 5138.80, x2 = 2498.52, y2 = 5269.38 }, { x1 = 2413.98, y1 = 4778.17, x2 = 2561.79, y2 = 5138.80 }, { x1 = 2413.98, y1 = 4417.53, x2 = 2632.58, y2 = 4778.17 }, { x1 = 2413.98, y1 = 4036.53, x2 = 2734.72, y2 = 4417.53 }, { x1 = 1605.27, y1 = 4820.46, x2 = 1648.42, y2 = 4931.77 } } },
  HARMONY = { name = 'HARMONY', label = 'Harmony', type = 'industrial', neighbors = { 'GR_SEN', 'SANDY', 'GRAPE', 'STAB' }, parts = { { x1 = 369.23, y1 = 2491.78, x2 = 729.23, y2 = 2851.78 } } },
  STAB = { name = 'STAB', label = 'Stab City', type = 'residential', neighbors = { 'SANDY', 'HARMONY', 'ALAMO', 'SENF' }, parts = { { x1 = -73.22, y1 = 3514.45, x2 = 326.78, y2 = 3914.45 } } },
  ALTA = { name = 'ALTA', label = 'Alta', type = 'residential', neighbors = { 'DOWNT', 'LEGSQ', 'LOSFLZ' }, parts = { { x1 = -90.0, y1 = -480.90, x2 = 695.99, y2 = -177.0 } } },
  LMESA = { name = 'LMESA', label = 'La Mesa', type = 'residential', neighbors = { 'DTVIEW', 'VINEH', 'E_BURR', 'MORN' }, parts = { { x1 = 921.45, y1 = -1901.45, x2 = 1118.89, y2 = -1708.33 }, { x1 = 505.03, y1 = -1158.02, x2 = 934.14, y2 = -1006.57 }, { x1 = 618.7, y1 = -1708.33, x2 = 1118.89, y2 = -1158.02 }, { x1 = 505.03, y1 = -1006.57, x2 = 888.46, y2 = -820.90 }, { x1 = 505.03, y1 = -820.90, x2 = 869.70, y2 = -510.0 } } },
  VINEH = { name = 'VINEH', label = 'Vinewood Hills', type = 'commercial', neighbors = { 'MOVIE', 'HAWICK', 'RICHM', 'LOSFLZ' }, parts = { { x1 = 696.0, y1 = -282.5, x2 = 1391.0, y2 = -35.97 } } },
  VESPU = { name = 'VESPU', label = 'Vespucci Beach', type = 'commercial', neighbors = { 'DELP', 'LSIA', 'PACBL' }, parts = { { x1 = -1450.59, y1 = -1287.02, x2 = -1232.34, y2 = -1237.30 }, { x1 = -1450.59, y1 = -1237.30, x2 = -1249.24, y2 = -1174.30 }, { x1 = -1450.59, y1 = -1174.30, x2 = -1250.79, y2 = -1074.78 }, { x1 = -1450.59, y1 = -1389.87, x2 = -1202.04, y2 = -1287.02 }, { x1 = -1450.59, y1 = -1600.40, x2 = -1182.04, y2 = -1389.87 } } },
  DEPBEA = { name = 'DEPBEA', label = 'Del Perro Beach', type = 'commercial', neighbors = { 'DELP', 'PACBL', 'SMON' }, parts = { { x1 = -1319.77, y1 = -1074.78, x2 = -1095.41, y2 = -960.49 }, { x1 = -1272.77, y1 = -960.49, x2 = -1095.41, y2 = -849.49 }, { x1 = -1250.79, y1 = -1174.30, x2 = -1095.41, y2 = -1074.78 }, { x1 = -1249.24, y1 = -1237.30, x2 = -1095.41, y2 = -1174.30 }, { x1 = -1232.34, y1 = -1287.02, x2 = -1095.41, y2 = -1237.30 }, { x1 = -1202.04, y1 = -1389.87, x2 = -1095.41, y2 = -1287.02 }, { x1 = -1182.04, y1 = -1450.40, x2 = -1095.41, y2 = -1389.87 }, { x1 = -1095.41, y1 = -1214.40, x2 = -774.41, y2 = -1019.71 }, { x1 = -1095.41, y1 = -1019.71, x2 = -812.41, y2 = -907.78 }, { x1 = -1095.41, y1 = -907.78, x2 = -865.98, y2 = -849.49 }, { x1 = -1172.0, y1 = -849.49, x2 = -931.96, y2 = -723.01 } } }
}

Config.FrontTypes = {
  ['nightclub'] = {
    name = 'Nightclub',
    icon = 'fa-music',
    dailyCap = 50000,
    processingRate = 0.75, -- 75% conversion rate
    processingFee = 0.15,  -- 15% fee
    heatGeneration = 2.5,
    description = 'High-capacity money laundering through nightlife activities'
  },
  ['car_wash'] = {
    name = 'Car Wash',
    icon = 'fa-car',
    dailyCap = 25000,
    processingRate = 0.65,
    processingFee = 0.10,
    heatGeneration = 1.0,
    description = 'Low-profile laundering operation'
  },
  ['restaurant'] = {
    name = 'Restaurant',
    icon = 'fa-utensils',
    dailyCap = 35000,
    processingRate = 0.70,
    processingFee = 0.12,
    heatGeneration = 1.5,
    description = 'Moderate capacity with good cover'
  },
  ['mechanic_shop'] = {
    name = 'Mechanic Shop',
    icon = 'fa-wrench',
    dailyCap = 40000,
    processingRate = 0.72,
    processingFee = 0.13,
    heatGeneration = 1.8,
    description = 'Industrial front with solid capacity'
  },
  ['electronics_store'] = {
    name = 'Electronics Store',
    icon = 'fa-tv',
    dailyCap = 45000,
    processingRate = 0.73,
    processingFee = 0.14,
    heatGeneration = 2.0,
    description = 'High-value goods provide excellent cover'
  },
  ['import_export'] = {
    name = 'Import/Export Business',
    icon = 'fa-shipping-fast',
    dailyCap = 75000,
    processingRate = 0.80,
    processingFee = 0.18,
    heatGeneration = 3.5,
    description = 'Premium operation for major players'
  },
  ['convenience_store'] = {
    name = 'Convenience Store',
    icon = 'fa-store',
    dailyCap = 20000,
    processingRate = 0.60,
    processingFee = 0.08,
    heatGeneration = 0.8,
    description = 'Small-scale operation, minimal suspicion'
  },
  ['strip_club'] = {
    name = 'Strip Club',
    icon = 'fa-glass-martini',
    dailyCap = 55000,
    processingRate = 0.76,
    processingFee = 0.16,
    heatGeneration = 2.8,
    description = 'Cash-heavy business with high capacity'
  },
  ['pawn_shop'] = {
    name = 'Pawn Shop',
    icon = 'fa-gem',
    dailyCap = 30000,
    processingRate = 0.68,
    processingFee = 0.11,
    heatGeneration = 1.3,
    description = 'Versatile front for various goods'
  },
  ['casino'] = {
    name = 'Casino',
    icon = 'fa-dice',
    dailyCap = 100000,
    processingRate = 0.85,
    processingFee = 0.20,
    heatGeneration = 4.0,
    description = 'Ultimate laundering operation - highest capacity and risk'
  },
  ['warehouse'] = {
    name = 'Warehouse',
    icon = 'fa-warehouse',
    dailyCap = 60000,
    processingRate = 0.77,
    processingFee = 0.17,
    heatGeneration = 3.0,
    description = 'Industrial scale operations'
  },
  ['taxi_company'] = {
    name = 'Taxi Company',
    icon = 'fa-taxi',
    dailyCap = 28000,
    processingRate = 0.67,
    processingFee = 0.10,
    heatGeneration = 1.2,
    description = 'Service-based front with steady flow'
  },
  ['yacht_club'] = {
    name = 'Yacht Club',
    icon = 'fa-ship',
    dailyCap = 90000,
    processingRate = 0.82,
    processingFee = 0.19,
    heatGeneration = 3.8,
    description = 'Luxury front for high-end operations'
  },
  ['arcade'] = {
    name = 'Arcade',
    icon = 'fa-gamepad',
    dailyCap = 32000,
    processingRate = 0.69,
    processingFee = 0.12,
    heatGeneration = 1.4,
    description = 'Entertainment front with moderate capacity'
  }
}

-- Map fronts to each territory zone
Config.TerritoryFronts = {
  -- Major Strategic Zones
  ['DOWNT'] = {
    frontType = 'casino',
    label = 'Downtown Casino',
    blip = { sprite = 679, color = 5 }
  },
  
  -- Commercial Districts
  ['TEXTL'] = {
    frontType = 'mechanic_shop',
    label = 'Textile District Garage',
    blip = { sprite = 446, color = 17 }
  },
  
  ['KOREAT'] = {
    frontType = 'restaurant',
    label = 'Little Seoul Restaurant',
    blip = { sprite = 106, color = 2 }
  },
  
  ['PILLB'] = {
    frontType = 'electronics_store',
    label = 'Pillbox Electronics',
    blip = { sprite = 521, color = 3 }
  },
  
  ['MORN'] = {
    frontType = 'convenience_store',
    label = 'Morningwood 24/7',
    blip = { sprite = 52, color = 2 }
  },
  
  ['WVINE'] = {
    frontType = 'pawn_shop',
    label = 'West Vinewood Pawn',
    blip = { sprite = 267, color = 5 }
  },
  
  ['MOVIE'] = {
    frontType = 'nightclub',
    label = 'Vinewood Nightclub',
    blip = { sprite = 614, color = 27 }
  },
  
  ['ROCKF'] = {
    frontType = 'yacht_club',
    label = 'Rockford Hills Marina',
    blip = { sprite = 455, color = 3 }
  },
  
  ['BURTON'] = {
    frontType = 'electronics_store',
    label = 'Burton Tech Store',
    blip = { sprite = 521, color = 3 }
  },
  
  ['HAWICK'] = {
    frontType = 'strip_club',
    label = 'Hawick Gentlemen\'s Club',
    blip = { sprite = 121, color = 27 }
  },
  
  ['DELP'] = {
    frontType = 'restaurant',
    label = 'Del Perro Bistro',
    blip = { sprite = 106, color = 2 }
  },
  
  ['MIRRP'] = {
    frontType = 'car_wash',
    label = 'Mirror Park Car Wash',
    blip = { sprite = 100, color = 37 }
  },
  
  ['CHAMH'] = {
    frontType = 'convenience_store',
    label = 'Chamberlain 24/7',
    blip = { sprite = 52, color = 2 }
  },
  
  ['STRAW'] = {
    frontType = 'pawn_shop',
    label = 'Strawberry Pawn',
    blip = { sprite = 267, color = 5 }
  },
  
  ['DAVIS'] = {
    frontType = 'taxi_company',
    label = 'Davis Cab Co.',
    blip = { sprite = 56, color = 5 }
  },
  
  ['RANCHO'] = {
    frontType = 'mechanic_shop',
    label = 'Rancho Repair Shop',
    blip = { sprite = 446, color = 17 }
  },
  
  ['CYPFL'] = {
    frontType = 'warehouse',
    label = 'Cypress Flats Warehouse',
    blip = { sprite = 473, color = 2 }
  },
  
  ['E_BURR'] = {
    frontType = 'warehouse',
    label = 'El Burro Storage',
    blip = { sprite = 473, color = 2 }
  },
  
  -- Industrial/Port Zones
  ['SANDY'] = {
    frontType = 'convenience_store',
    label = 'Sandy Shores Store',
    blip = { sprite = 52, color = 2 }
  },
  
  ['PALETO'] = {
    frontType = 'car_wash',
    label = 'Paleto Bay Car Wash',
    blip = { sprite = 100, color = 37 }
  },
  
  ['GRAPE'] = {
    frontType = 'mechanic_shop',
    label = 'Grapeseed Garage',
    blip = { sprite = 446, color = 17 }
  },
  
  ['HARMONY'] = {
    frontType = 'warehouse',
    label = 'Harmony Industrial',
    blip = { sprite = 473, color = 2 }
  },
  
  ['STAB'] = {
    frontType = 'pawn_shop',
    label = 'Stab City Trading Post',
    blip = { sprite = 267, color = 5 }
  },
  
  ['ALTA'] = {
    frontType = 'restaurant',
    label = 'Alta Fine Dining',
    blip = { sprite = 106, color = 2 }
  },
  
  ['LMESA'] = {
    frontType = 'arcade',
    label = 'La Mesa Arcade',
    blip = { sprite = 740, color = 4 }
  },
  
  ['VINEH'] = {
    frontType = 'import_export',
    label = 'Vinewood Hills Import Co.',
    blip = { sprite = 477, color = 2 }
  },
  
  ['VESPU'] = {
    frontType = 'nightclub',
    label = 'Vespucci Beach Club',
    blip = { sprite = 614, color = 27 }
  },
  
  ['DEPBEA'] = {
    frontType = 'yacht_club',
    label = 'Del Perro Marina',
    blip = { sprite = 455, color = 3 }
  }
}

