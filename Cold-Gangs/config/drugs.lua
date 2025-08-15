Config.DrugFields = {
    ["weed_field"] = {
        yield = { min = 5, max = 15 },
        qualityRange = { min = 60, max = 90 }
    },
    ["coke_field"] = {
        yield = { min = 4, max = 12 },
        qualityRange = { min = 65, max = 95 }
    },
    ["meth_field"] = {
        yield = { min = 6, max = 18 },
        qualityRange = { min = 70, max = 98 }
    }
}

Config.DrugLabs = {
    processingTimes = {
        weed = 1800000, -- 30 mins
        coke = 2400000, -- 40 mins
        meth = 3000000  -- 50 mins
    },
    successRates = {
        weed = 0.9,
        coke = 0.85,
        meth = 0.8
    }
}

Config.DrugPrices = {
    weed = 80,
    coke = 120,
    meth = 150
}
