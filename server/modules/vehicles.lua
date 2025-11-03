local QBCore = exports['qb-core']:GetCoreObject()
ColdGangs = ColdGangs or {}

local GangGarages = {}

local function getGangId(src)
    if ColdGangs.Core and ColdGangs.Core.GetPlayerGangId then return ColdGangs.Core.GetPlayerGangId(src) end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return nil end
    local r = MySQL.query.await('SELECT gang_id FROM cold_gang_members WHERE citizen_id = ? LIMIT 1', { P.PlayerData.citizenid })
    return r and r[1] and tonumber(r[1].gang_id) or nil
end

local function hasPerm(src, perm)
    if ColdGangs.Permissions and ColdGangs.Permissions.HasGangPermission then return ColdGangs.Permissions.HasGangPermission(src, perm) == true end
    return false
end

local function canManage(src, gid)
    if not gid then return false end
    return hasPerm(src, 'manageVehicles')
end

local function normPlate(p)
    p = tostring(p or ""):upper()
    return p:gsub("%s+", "")
end

local function getCatalog()
    local cat = (Config and Config.GangVehicles and Config.GangVehicles.Catalog) or {}
    return cat
end

local function getValetConfig()
    local freeRadius = (Config and Config.GangVehicles and Config.GangVehicles.ValetFreeRadius) or 6.0
    local perMeter   = (Config and Config.GangVehicles and Config.GangVehicles.ValetPerMeter) or 1.0
    local maxFee     = (Config and Config.GangVehicles and Config.GangVehicles.ValetMaxFee) or 5000
    return freeRadius, perMeter, maxFee
end

local function getGangTag(gid)
    local tag = MySQL.scalar.await('SELECT tag FROM cold_gangs WHERE id = ? LIMIT 1', { gid }) or 'GG'
    tag = string.upper(tag):gsub('[^A-Z0-9]', '')
    if tag == '' then tag = 'GG' end
    return tag
end

local function randAlnum(n)
    local chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local out = {}
    for i=1, n do
        local idx = math.random(#chars)
        out[i] = chars:sub(idx, idx)
    end
    return table.concat(out)
end

local function generateTagPlate(gid)
    local prefix = string.sub(getGangTag(gid), 1, 3)
    local tries = 0
    while tries < 150 do
        local plate = string.format('%s-%s', prefix, randAlnum(3))
        local exists = MySQL.scalar.await('SELECT COUNT(*) FROM cold_gang_vehicles WHERE plate = ? LIMIT 1', { plate }) or 0
        if exists == 0 then return plate end
        tries = tries + 1
    end
    local fallback = string.format('%s-%03d', prefix, math.random(0,999))
    return fallback
end

CreateThread(function()
    local grows = MySQL.query.await('SELECT * FROM cold_gang_garages', {}) or {}
    for _, r in ipairs(grows) do
        GangGarages[tonumber(r.gang_id)] = { x = r.x, y = r.y, z = r.z, h = (r.h or r.heading or 0.0) }
    end
end)

QBCore.Functions.CreateCallback('cold-gangs:server:GetVehiclesUiCaps', function(source, cb)
    local gid = getGangId(source)
    local canSet = gid and canManage(source, gid) or false
    local canBuy = not ((Config and Config.GangVehicles and Config.GangVehicles.PurchaseRequiresPermission) == true) or canSet
    local price  = (Config and Config.GangVehicles and Config.GangVehicles.RecallPrice) or 50000
    cb({ canSetGarage = canSet, canPurchase = canBuy, recallPrice = price })
end)

QBCore.Functions.CreateCallback('cold-gangs:server:GetGangGarage', function(source, cb)
    local gid = getGangId(source); if not gid then cb(nil) return end
    cb(GangGarages[gid] or nil)
end)

QBCore.Functions.CreateCallback('cold-gangs:server:GetVehicleCatalog', function(source, cb)
    cb(getCatalog())
end)

QBCore.Functions.CreateCallback('cold-gangs:server:GetGangVehicles', function(source, cb, gangId)
    local gid = gangId or getGangId(source)
    if not gid then cb({}) return end
    local rows = MySQL.query.await('SELECT * FROM cold_gang_vehicles WHERE gang_id = ? ORDER BY stored DESC, plate ASC', { gid }) or {}
    cb(rows)
end)

QBCore.Functions.CreateCallback('cold-gangs:server:GetVehicleLocation', function(source, cb, plate)
    plate = normPlate(plate)
    if plate == "" then cb(nil) return end
    local r = MySQL.query.await('SELECT location, stored, gang_id FROM cold_gang_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not r or not r[1] then cb(nil) return end
    local loc = r[1].location
    if type(loc) == "string" then local ok, d = pcall(json.decode, loc); loc = ok and d or nil end
    if loc and loc.x and loc.y then cb(loc) return end
    if tonumber(r[1].stored) == 1 then
        local gid = tonumber(r[1].gang_id)
        cb(GangGarages[gid] or nil)
        return
    end
    cb(nil)
end)

QBCore.Functions.CreateCallback('cold-gangs:server:CanStoreVehicle', function(source, cb, plate)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false, "Player not found") return end
    
    local gangId = Player.PlayerData.gang and Player.PlayerData.gang.name
    if not gangId then cb(false, "You are not in a gang") return end
    
    -- Check if vehicle belongs to the gang
    local result = MySQL.query.await('SELECT * FROM gang_vehicles WHERE gang_id = ? AND plate = ?', {
        gangId, plate
    })
    
    if not result or #result == 0 then
        cb(false, "This vehicle doesn't belong to your gang")
        return
    end
    
    -- Update vehicle state to stored
    MySQL.update.await('UPDATE gang_vehicles SET state = ? WHERE plate = ?', {
        'stored', plate
    })
    
    cb(true)
end)

QBCore.Functions.CreateCallback('cold-gangs:server:ViewVehicle', function(source, cb, plate)
    plate = normPlate(plate)
    if plate == "" then cb(nil) return end
    local r = MySQL.query.await('SELECT * FROM cold_gang_vehicles WHERE plate = ? LIMIT 1', { plate })
    cb(r and r[1] or nil)
end)

RegisterNetEvent('cold-gangs:vehicles:SetGarage', function()
    local src = source
    local gid = getGangId(src); if not gid then return end
    if not canManage(src, gid) then TriggerClientEvent('QBCore:Notify', src, "No permission", "error") return end
    local ped = GetPlayerPed(src); if not ped or ped <= 0 then return end
    local c = GetEntityCoords(ped); local h = GetEntityHeading(ped)
    MySQL.insert.await([[
      INSERT INTO cold_gang_garages (gang_id, x, y, z, h)
      VALUES (?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE x=VALUES(x), y=VALUES(y), z=VALUES(z), h=VALUES(h)
    ]], { gid, c.x, c.y, c.z, h })
    GangGarages[gid] = { x = c.x, y = c.y, z = c.z, h = h }
    TriggerClientEvent('QBCore:Notify', src, "Garage set", "success")
    TriggerClientEvent('cold-gangs:client:GarageUpdated', -1, gid, GangGarages[gid])
end)

RegisterNetEvent('cold-gangs:vehicles:Purchase', function(model)
    local src = source
    local gid = getGangId(src); if not gid then return end
    local req = (Config and Config.GangVehicles and Config.GangVehicles.PurchaseRequiresPermission) == true
    if req and not canManage(src, gid) then TriggerClientEvent('QBCore:Notify', src, "No permission", "error") return end
    local cat = getCatalog(); local entry = nil
    for _, c in ipairs(cat) do if tostring(c.model) == tostring(model) or tonumber(c.model) == tonumber(model) then entry = c break end end
    if not entry then TriggerClientEvent('QBCore:Notify', src, "Unknown model", "error") return end
    local limit = tonumber((Config and Config.GangVehicles and Config.GangVehicles.MaxGangVehicles) or 10)
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM cold_gang_vehicles WHERE gang_id = ?', { gid }) or 0
    if tonumber(count) >= limit then TriggerClientEvent('QBCore:Notify', src, "Garage full", "error") return end
    local price = tonumber(entry.price or 0)
    if price > 0 then
        local ok = false
        if ColdGangs.Core and ColdGangs.Core.RemoveGangMoney then
            ok = ColdGangs.Core.RemoveGangMoney(gid, price, ('Gang Vehicle Purchase: %s'):format(entry.label or tostring(entry.model)))
        else
            local ch = MySQL.update.await('UPDATE cold_gangs SET bank = bank - ? WHERE id = ? AND bank >= ?', { price, gid, price })
            ok = (ch or 0) > 0
            if ok then
                MySQL.insert.await('INSERT INTO cold_gang_transactions (gang_id, amount, description, reason) VALUES (?, ?, ?, ?)', { gid, -price, ('Purchase %s'):format(entry.label or tostring(entry.model)), 'vehicle_purchase' })
            end
        end
        if not ok then TriggerClientEvent('QBCore:Notify', src, "Insufficient gang funds", "error") return end
    end
    local plate = generateTagPlate(gid)
    local garage = GangGarages[gid] or {}
    local now = os.date('%Y-%m-%d %H:%M:%S')
    local hash = tonumber(entry.model) or (type(entry.model) == "string" and GetHashKey(entry.model)) or entry.model
    local props = { model = hash, plate = plate }
    MySQL.insert.await('INSERT INTO cold_gang_vehicles (plate, gang_id, model, label, stored, impounded, last_seen, location, mods, registered_by, registered_at) VALUES (?, ?, ?, ?, 1, 0, NOW(), ?, ?, ?, ?)', {
        plate, gid, hash, entry.label or tostring(entry.model), json.encode(garage), json.encode(props), GetPlayerName(src), now
    })
    TriggerClientEvent('QBCore:Notify', src, ('Purchased %s (%s)'):format(entry.label or tostring(entry.model), plate), "success")
end)

RegisterNetEvent('cold-gangs:vehicles:Store', function(plate)
    local src = source
    local gid = getGangId(src); if not gid then return end
    plate = normPlate(plate)
    if plate == "" then TriggerClientEvent('QBCore:Notify', src, "Plate required", "error") return end
    if not canManage(src, gid) then TriggerClientEvent('QBCore:Notify', src, "No permission", "error") return end
    local r = MySQL.query.await('SELECT stored FROM cold_gang_vehicles WHERE plate = ? AND gang_id = ? LIMIT 1', { plate, gid })
    if not r or not r[1] then TriggerClientEvent('QBCore:Notify', src, "Vehicle not found", "error") return end
    if tonumber(r[1].stored) == 1 then TriggerClientEvent('QBCore:Notify', src, "Already stored", "primary") return end
    local gar = GangGarages[gid] or {}
    MySQL.update.await('UPDATE cold_gang_vehicles SET stored = 1, location = ?, last_seen = NOW() WHERE plate = ?', { json.encode(gar), plate })
    TriggerClientEvent('cold-gangs:client:RecallVehicle', -1, plate)
    TriggerClientEvent('QBCore:Notify', src, "Stored", "success")
end)

RegisterNetEvent('cold-gangs:vehicles:Recall', function(plate)
    local src = source
    local gid = getGangId(src); if not gid then return end
    if not canManage(src, gid) then TriggerClientEvent('QBCore:Notify', src, "No permission", "error") return end
    plate = normPlate(plate); if plate == "" then TriggerClientEvent('QBCore:Notify', src, "Invalid plate", "error") return end
    local r = MySQL.query.await('SELECT stored FROM cold_gang_vehicles WHERE plate = ? AND gang_id = ? LIMIT 1', { plate, gid })
    if not r or not r[1] then TriggerClientEvent('QBCore:Notify', src, "Not found", "error") return end
    if tonumber(r[1].stored) == 1 then TriggerClientEvent('QBCore:Notify', src, "Already stored", "error") return end
    local fee = (Config and Config.GangVehicles and Config.GangVehicles.RecallPrice) or 50000
    if fee > 0 then
        local ok = false
        if ColdGangs.Core and ColdGangs.Core.RemoveGangMoney then
            ok = ColdGangs.Core.RemoveGangMoney(gid, fee, ("Vehicle Recall (%s)"):format(plate))
        else
            local ch = MySQL.update.await('UPDATE cold_gangs SET bank = bank - ? WHERE id = ? AND bank >= ?', { fee, gid, fee })
            ok = (ch or 0) > 0
            if ok then
                MySQL.insert.await('INSERT INTO cold_gang_transactions (gang_id, amount, description, reason) VALUES (?, ?, ?, ?)', { gid, -fee, ("Recall %s"):format(plate), 'vehicle_recall' })
            end
        end
        if not ok then TriggerClientEvent('QBCore:Notify', src, "Insufficient funds", "error") return end
    end
    local gar = GangGarages[gid] or {}
    MySQL.update.await('UPDATE cold_gang_vehicles SET stored = 1, location = ?, last_seen = NOW() WHERE plate = ?', { json.encode(gar), plate })
    TriggerClientEvent('cold-gangs:client:RecallVehicle', -1, plate)
    TriggerClientEvent('QBCore:Notify', src, "Recalled", "success")
end)

RegisterNetEvent('cold-gangs:vehicles:UpdateLocation', function(plate, coords)
    local src = source
    plate = normPlate(plate)
    if plate == "" or not coords or not coords.x or not coords.y then return end
    local gid = getGangId(src); if not gid then return end
    local r = MySQL.query.await('SELECT gang_id FROM cold_gang_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not r or not r[1] or tonumber(r[1].gang_id) ~= tonumber(gid) then return end
    MySQL.update.await('UPDATE cold_gang_vehicles SET location = ?, last_seen = NOW() WHERE plate = ?', { json.encode(coords), plate })
end)

RegisterNetEvent('cold-gangs:vehicles:ValetSpawn', function(plate)
    local src = source
    local gid = getGangId(src); if not gid then return end
    plate = normPlate(plate)
    if plate == "" then TriggerClientEvent('QBCore:Notify', src, "Invalid plate", "error") return end

    local r = MySQL.query.await('SELECT plate, gang_id, stored, model, label, mods FROM cold_gang_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not r or not r[1] or tonumber(r[1].gang_id) ~= tonumber(gid) then TriggerClientEvent('QBCore:Notify', src, "Vehicle not found", "error") return end
    local row = r[1]

    if tonumber(row.stored) ~= 1 then
        TriggerClientEvent('cold-gangs:client:DeleteVehicleByPlate', -1, plate)
        Wait(250)
        MySQL.update.await('UPDATE cold_gang_vehicles SET stored = 1 WHERE plate = ? AND stored = 0', { plate })
        row.stored = 1
    end

    local gar = GangGarages[gid]; if not gar or not gar.x then TriggerClientEvent('QBCore:Notify', src, "Garage not set", "error") return end

    local ped = GetPlayerPed(src); if not ped or ped <= 0 then return end
    local pc = GetEntityCoords(ped)

    local freeRadius, perMeter, maxFee = getValetConfig()
    local dx, dy = (pc.x - gar.x), (pc.y - gar.y)
    local dist = math.sqrt(dx*dx + dy*dy)
    local fee = 0
    if dist > freeRadius then fee = math.floor(math.min(maxFee, dist * perMeter)) end

    local props = nil
    if row.mods and type(row.mods) == "string" then local okj, dec = pcall(json.decode, row.mods); props = okj and dec or nil end
    props = props or { model = row.model, plate = row.plate }

    if fee == 0 then
        local ok = MySQL.update.await('UPDATE cold_gang_vehicles SET stored = 0, last_seen = NOW(), location = ? WHERE plate = ? AND stored = 1', { json.encode(gar), plate })
        if not ok or ok <= 0 then TriggerClientEvent('QBCore:Notify', src, "Already out", "error") return end
        TriggerClientEvent('cold-gangs:client:SpawnGangVehicle', src, props, { x = gar.x, y = gar.y, z = gar.z, h = gar.h or 0.0 })
        return
    end

    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.Functions.RemoveMoney('cash', fee, ('Valet fee (%dm)'):format(math.floor(dist))) then
        TriggerClientEvent('QBCore:Notify', src, "Not enough cash for valet", "error")
        return
    end

    local ok = MySQL.update.await('UPDATE cold_gang_vehicles SET stored = 0, last_seen = NOW(), location = ? WHERE plate = ? AND stored = 1', { json.encode(gar), plate })
    if not ok or ok <= 0 then
        P.Functions.AddMoney('cash', fee, 'Valet refund (already out)')
        TriggerClientEvent('QBCore:Notify', src, "Vehicle is already out, refunded valet fee", "error")
        return
    end

    TriggerClientEvent('cold-gangs:client:ValetDeliver', src, {
        props = props,
        valetSpawn = { x = gar.x, y = gar.y, z = gar.z, h = gar.h or 0.0 },
        dropOff = { x = pc.x, y = pc.y, z = pc.z }
    })
    TriggerClientEvent('QBCore:Notify', src, ("Valet fee paid: $%d"):format(fee), "primary")
end)
