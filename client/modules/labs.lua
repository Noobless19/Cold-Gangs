local QBCore = exports['qb-core']:GetCoreObject()

local currentLab = nil
local isShowing = false
local lastInput = 0
local INPUT_COOLDOWN = 800
local nearbyLabs = {}

local function getClosestLab()
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local closest, closestDist = nil, 99999
    nearbyLabs = {}
    for labId, lab in pairs(Config.Labs or {}) do
        if lab.active and lab.coords then
            local d = #(pc - lab.coords)
            if d <= (Config.MaxDistance or 2.0) then
                nearbyLabs[labId] = d
                if d < closestDist then closest = labId closestDist = d end
            end
        end
    end
    return closest
end

local function drawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    DrawRect(0.0, 0.0125, 0.035 + (#text/250), 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function openInventoryMenu(labId)
    QBCore.Functions.TriggerCallback('cold-gangs:labs:getLabInventory', function(inv)
        local menu = { { header = "Lab Inventory", isMenuHeader = true } }
        if inv and next(inv) then
            for item, amount in pairs(inv) do
                local label = (QBCore.Shared.Items[item] and QBCore.Shared.Items[item].label) or item
                table.insert(menu, {
                    header = ("%s (%d)"):format(label, amount),
                    txt = "Withdraw",
                    params = { event = "cold-gangs:labs:client:withdraw", args = { labId = labId, item = item, amount = amount } }
                })
            end
        else
            table.insert(menu, { header = "Empty", disabled = true })
        end
        table.insert(menu, { header = "Deposit Items", params = { event = "cold-gangs:labs:client:deposit", args = { labId = labId } } })
        table.insert(menu, { header = "← Back", params = { event = "qb-menu:client:closeMenu" } })
        exports['qb-menu']:openMenu(menu)
    end, labId)
end

local function openProductionMenu(labId)
    local lab = Config.Labs[labId]
    local lt = Config.LabTypes[lab.type]
    local menu = { { header = "Production - " .. (lt.name or lab.type), isMenuHeader = true } }
    for recipe, data in pairs(lt.recipes or {}) do
        local inputs = {}
        for item, amt in pairs(data.inputs or {}) do
            local label = QBCore.Shared.Items[item] and QBCore.Shared.Items[item].label or item
            table.insert(inputs, ("%dx %s"):format(amt, label))
        end
        local outLabel = QBCore.Shared.Items[data.output.item] and QBCore.Shared.Items[data.output.item].label or data.output.item
        table.insert(menu, {
            header = recipe:upper(),
            txt = ("Input: %s\nOutput: %dx %s\nTime: %ds"):format(table.concat(inputs,", "), data.output.amount, outLabel, math.floor((data.time or 0)/1000)),
            params = { event = "cold-gangs:labs:client:start", args = { labId = labId, recipe = recipe } }
        })
    end
    table.insert(menu, { header = "← Back", params = { event = "qb-menu:client:closeMenu" } })
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('cold-gangs:labs:client:start', function(data)
    TriggerServerEvent('cold-gangs:labs:startProduction', data.labId, data.recipe)
end)

RegisterNetEvent('cold-gangs:labs:client:deposit', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = 'Deposit Items to Lab',
        submitText = 'Deposit',
        inputs = {
            { type = 'text', isRequired = true, name = 'item', text = 'Item name' },
            { type = 'number', isRequired = true, name = 'amount', text = 'Amount' }
        }
    })
    if dialog and dialog.item and tonumber(dialog.amount) then
        TriggerServerEvent('cold-gangs:labs:depositItem', data.labId, dialog.item, tonumber(dialog.amount))
    end
end)

RegisterNetEvent('cold-gangs:labs:client:withdraw', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = 'Withdraw Items from Lab',
        submitText = 'Withdraw',
        inputs = { { type = 'number', isRequired = true, name = 'amount', text = 'Amount (Max: ' .. data.amount .. ')' } }
    })
    if dialog and tonumber(dialog.amount) then
        local amt = tonumber(dialog.amount)
        if amt > 0 and amt <= data.amount then
            TriggerServerEvent('cold-gangs:labs:withdrawItem', data.labId, data.item, amt)
        else
            QBCore.Functions.Notify('Invalid amount', 'error')
        end
    end
end)

CreateThread(function()
    while true do
        local c = getClosestLab()
        currentLab = c
        isShowing = c ~= nil
        Wait(750)
    end
end)

CreateThread(function()
    while true do
        if isShowing and currentLab then
            local lab = Config.Labs[currentLab]
            drawText3D(lab.coords.x, lab.coords.y, lab.coords.z + 1.0, "[E] Access " .. (Config.LabTypes[lab.type].name or "Lab"))
            drawText3D(lab.coords.x, lab.coords.y, lab.coords.z + 0.6, "[H] Inventory")
            if IsControlJustReleased(0, 38) and (GetGameTimer() - lastInput > INPUT_COOLDOWN) then
                lastInput = GetGameTimer()
                openProductionMenu(currentLab)
            end
            if IsControlJustReleased(0, 74) and (GetGameTimer() - lastInput > INPUT_COOLDOWN) then
                lastInput = GetGameTimer()
                openInventoryMenu(currentLab)
            end
        end
        Wait(0)
    end
end)
