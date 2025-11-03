local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('cold-gangs:labs:client:lockpickMinigame', function(labId)
    local success = false
    QBCore.Functions.Progressbar('lockpicking', 'Lockpicking...', 5000, false, true, {
        disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true
    }, {
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flags = 16
    }, {}, {}, function()
        success = math.random() > 0.3
        TriggerServerEvent('cold-gangs:labs:lockpickResult', labId, success)
    end, function()
        QBCore.Functions.Notify('Lockpicking cancelled', 'error')
    end)
end)

RegisterNetEvent('cold-gangs:labs:client:hackingMinigame', function(labId)
    local success = false
    QBCore.Functions.Progressbar('hacking', 'Hacking security systems...', 8000, false, true, {
        disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true
    }, {
        animDict = 'anim@heists@prison_heisttig_1_security@', anim = 'hacker_loop', flags = 16
    }, {
        model = 'hei_prop_hst_laptop', bone = 60309, coords = vector3(0.1, 0.02, 0.0), rotation = vector3(0.0, 0.0, 0.0)
    }, {}, function()
        success = math.random() > 0.4
        TriggerServerEvent('cold-gangs:labs:hackingResult', labId, success)
    end, function()
        QBCore.Functions.Notify('Hacking cancelled', 'error')
    end)
end)

RegisterNetEvent('cold-gangs:labs:client:showRaidEffects', function(labId, effectType)
    local lab = Config.Labs[labId]
    if not lab then return end
    if effectType == 'alarm' then
        CreateThread(function()
            local endTime = GetGameTimer() + 10000
            while GetGameTimer() < endTime do
                DrawLightWithRange(lab.coords.x, lab.coords.y, lab.coords.z + 2.0, 255, 0, 0, 10.0, 1.0)
                Wait(500)
                DrawLightWithRange(lab.coords.x, lab.coords.y, lab.coords.z + 2.0, 255, 255, 255, 10.0, 0.5)
                Wait(500)
            end
        end)
    elseif effectType == 'explosion' then
        AddExplosion(lab.coords.x, lab.coords.y, lab.coords.z, 10, 0.5, true, false, 1.0)
    elseif effectType == 'smoke' then
        UseParticleFxAssetNextCall('core')
        StartParticleFxNonLoopedAtCoord('ent_sht_steam', lab.coords.x, lab.coords.y, lab.coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false)
    end
end)
