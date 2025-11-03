local QBCore = exports['qb-core']:GetCoreObject()

local PlayerGang = nil
local DrugFields = {}
local DrugLabs = {}
local isProcessing = false

CreateThread(function()
    while not QBCore.Functions.GetPlayerData() do Wait(100) end
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData) PlayerGang = gangData end)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetDrugFields', function(fields) DrugFields = fields or {} end)
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetDrugLabs', function(labs) DrugLabs = labs or {} end)
end)

RegisterNetEvent('cold-gangs:client:SyncDrugFields', function(fields) DrugFields = fields or {} end)
RegisterNetEvent('cold-gangs:client:SyncDrugLabs', function(labs) DrugLabs = labs or {} end)

RegisterNetEvent('cold-gangs:client:HarvestDrugField', function(data)
    local fieldId = data.fieldId
    local f = nil
    for _, v in pairs(DrugFields) do if v.id == fieldId then f = v break end end
    if not f then QBCore.Functions.Notify("Field not found", "error") return end
    if f.growthStage < 10 then QBCore.Functions.Notify("Plants are not ready for harvest yet", "error") return end
    TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_GARDENER_PLANT", 0, true)
    QBCore.Functions.Progressbar("harvesting_drugs", "Harvesting " .. f.resourceType, 10000, false, true, { disableMovement=true, disableCarMovement=true, disableCombat=true }, {}, {}, {}, function()
        ClearPedTasks(PlayerPedId())
        TriggerServerEvent('cold-gangs:server:HarvestDrugField', fieldId)
    end, function() ClearPedTasks(PlayerPedId()) QBCore.Functions.Notify("Cancelled", "error") end)
end)

RegisterNetEvent('cold-gangs:client:StartDrugProcessing', function(data)
    local labId = data.labId
    local lab = nil
    for _, l in pairs(DrugLabs) do if l.id == labId then lab = l break end end
    if not lab then QBCore.Functions.Notify("Lab not found", "error") return end
    if isProcessing then QBCore.Functions.Notify("Already processing drugs", "error") return end
    QBCore.Functions.TriggerCallback('cold-gangs:server:CheckProcessingRequirements', function(hasItems, required)
        if not hasItems then
            local itemsText = ""
            for item, amt in pairs(required or {}) do itemsText = itemsText .. ("%s x%d, "):format(item, amt) end
            itemsText = itemsText ~= "" and itemsText:sub(1, -3) or "Missing items"
            QBCore.Functions.Notify("Missing items: " .. itemsText, "error")
            return
        end
        isProcessing = true
        TaskStartScenarioInPlace(PlayerPedId(), "PROP_HUMAN_BUM_BIN", 0, true)
        local pt = Config.DrugLabs.processingTimes[lab.drugType] or 60000
        QBCore.Functions.Progressbar("processing_drugs", "Processing " .. lab.drugType, pt, false, true, { disableMovement=true, disableCarMovement=true, disableCombat=true }, {}, {}, {}, function()
            ClearPedTasks(PlayerPedId())
            TriggerServerEvent('cold-gangs:server:CompleteDrugProcessing', labId)
            isProcessing = false
        end, function() ClearPedTasks(PlayerPedId()) QBCore.Functions.Notify("Cancelled", "error") isProcessing = false end)
    end, lab.drugType)
end)

RegisterNetEvent('cold-gangs:client:UpgradeDrugLab', function(data)
    local labId = data.labId
    local lab = nil
    for _, l in pairs(DrugLabs) do if l.id == labId then lab = l break end end
    if not lab then QBCore.Functions.Notify("Lab not found", "error") return end
    local menu = {
        { header = "Upgrade " .. lab.drugType .. " Lab", isMenuHeader = true },
        { header = "Upgrade Capacity", txt = ("Current: %d | Cost: $%d"):format(lab.capacity, (10000 * lab.level)), params = { event = "cold-gangs:client:ConfirmLabUpgrade", args = { labId = labId, upgradeType = "capacity" } } },
        { header = "Upgrade Security", txt = ("Current: %d | Cost: $%d"):format(lab.security, (15000 * lab.level)), params = { event = "cold-gangs:client:ConfirmLabUpgrade", args = { labId = labId, upgradeType = "security" } } },
        { header = "Upgrade Quality", txt = ("Improves product quality | Cost: $%d"):format(20000 * lab.level), params = { event = "cold-gangs:client:ConfirmLabUpgrade", args = { labId = labId, upgradeType = "level" } } },
        { header = "← Close", params = { event = "qb-menu:client:closeMenu" } }
    }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('cold-gangs:client:ConfirmLabUpgrade', function(data)
    TriggerServerEvent('cold-gangs:server:UpgradeDrugLab', data.labId, data.upgradeType)
end)

CreateThread(function()
    while true do
        Wait(0)
        if PlayerGang then
            local pc = GetEntityCoords(PlayerPedId())
            local sleep = true
            for _, f in pairs(DrugFields) do
                if f.owner == PlayerGang.id and f.location then
                    local c = json.decode(f.location)
                    local d = #(pc - vector3(c.x, c.y, c.z))
                    if d < 10.0 then
                        sleep = false
                        local text = ("%s Field\nGrowth: %d/10%s"):format(f.resourceType, f.growthStage, f.growthStage>=10 and "\nReady for harvest" or "")
                        Draw3DText(c.x, c.y, c.z + 1.0, text)
                    end
                end
            end
            for _, l in pairs(DrugLabs) do
                if l.owner == PlayerGang.id and l.location then
                    local c = json.decode(l.location)
                    local d = #(pc - vector3(c.x, c.y, c.z))
                    if d < 10.0 then
                        sleep = false
                        local text = ("%s Lab\nLevel: %d\nCapacity: %d"):format(l.drugType, l.level, l.capacity)
                        Draw3DText(c.x, c.y, c.z + 1.0, text)
                    end
                end
            end
            if sleep then Wait(1000) end
        else
            Wait(1000)
        end
    end
end)

function Draw3DText(x, y, z, text)
    local on,_x,_y = World3dToScreen2d(x,y,z)
    local p = GetGameplayCamCoords()
    local d = #(vector3(p.x,p.y,p.z)-vector3(x,y,z))
    local s = (1/d)*2*((1/GetGameplayCamFov())*100)
    if on then
        SetTextScale(0.35*s, 0.35*s)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255,255,255,215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x,_y)
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isProcessing then ClearPedTasks(PlayerPedId()) end
end)
