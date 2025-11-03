local QBCore = exports['qb-core']:GetCoreObject()

local graffitis = {}
local playerCooldowns = {}
local usableItemsRegistered = false
local serverEventsRegistered = false

CreateThread(function()
  InitializeDatabase()
end)

function InitializeDatabase()
  MySQL.query([[
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
      rotation_offset FLOAT DEFAULT 0.0,
      surface_normal_x FLOAT NOT NULL DEFAULT 0,
      surface_normal_y FLOAT NOT NULL DEFAULT 1,
      surface_normal_z FLOAT NOT NULL DEFAULT 0,
      graffiti_type VARCHAR(10) NOT NULL DEFAULT 'text',
      graffiti_text VARCHAR(80) NULL,
      graffiti_logo VARCHAR(50) NULL,
      color_hex VARCHAR(8) DEFAULT 'FFFFFF',
      font_face VARCHAR(64) DEFAULT 'ChaletLondon',
      scale FLOAT DEFAULT 0.18,
      creator_citizenid VARCHAR(50) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_gang (gang_id),
      INDEX idx_territory (territory),
      INDEX idx_coords (coords_x, coords_y, coords_z)
    )
  ]], {}, function()
    EnsureColumns()
  end)
end

function EnsureColumns()
  local function ensure(col, ddl, cb)
    MySQL.query(("SHOW COLUMNS FROM gang_graffitis LIKE '%s'"):format(col), {}, function(r)
      if not r or #r == 0 then
        MySQL.query(("ALTER TABLE gang_graffitis ADD COLUMN %s"):format(ddl), {}, cb)
      else
        if cb then cb() end
      end
    end)
  end
  ensure('color_hex',  "color_hex VARCHAR(8) DEFAULT 'FFFFFF'", function()
    ensure('font_face', "font_face VARCHAR(64) DEFAULT 'ChaletLondon'", function()
      ensure('scale',    "scale FLOAT DEFAULT 0.18", function()
       ensure('rotation_offset', "rotation_offset FLOAT DEFAULT 0.0", function()
        LoadGraffitis()
      end)
    end)
  end)
 end)
end

function LoadGraffitis()
  MySQL.query('SELECT * FROM gang_graffitis ORDER BY created_at DESC', {}, function(result)
    graffitis = {}
    if result and #result > 0 then
      for _, row in ipairs(result) do
        graffitis[row.id] = {
          id = row.id,
          gangId = row.gang_id,
          gangName = row.gang_name,
          territory = row.territory,
          coords = { x = tonumber(row.coords_x), y = tonumber(row.coords_y), z = tonumber(row.coords_z) },
          rotation = { x = tonumber(row.rotation_x), y = tonumber(row.rotation_y), z = tonumber(row.rotation_z) },
          rotationOffset = tonumber(row.rotation_offset) or 0.0,
          surfaceNormal = { x = tonumber(row.surface_normal_x), y = tonumber(row.surface_normal_y), z = tonumber(row.surface_normal_z) },
          type = row.graffiti_type,
          text = row.graffiti_text,
          logo = row.graffiti_logo,
          colorHex = row.color_hex or "FFFFFF",
          fontFace = row.font_face or "ChaletLondon",
          scale = tonumber(row.scale) or 0.18,
          creator = row.creator_citizenid,
          createdAt = row.created_at
        }
      end
    end
    RegisterUsableItems()
    RegisterServerEvents()
    TriggerClientEvent('cold-gangs:client:LoadGraffitis', -1, graffitis)
  end)
end

function RegisterUsableItems()
  if usableItemsRegistered then return end
  usableItemsRegistered = true
  QBCore.Functions.CreateUseableItem(Config.Graffiti.sprayCanItem, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local gang = GetPlayerGang(src)
    if not gang then TriggerClientEvent('QBCore:Notify', src, "You need to be in a gang to use spray cans", "error"); return end
    local now = GetGameTimer()
    local cd = Config.Graffiti.cooldownTime or 300000
    if playerCooldowns[src] and (now - playerCooldowns[src]) < cd then
      local remaining = math.ceil((cd - (now - playerCooldowns[src]))/1000)
      TriggerClientEvent('QBCore:Notify', src, ("Wait %ds before using spray can again"):format(remaining), "error")
      return
    end
    TriggerClientEvent('cold-gangs:client:UseSprayCan', src, gang, Config.Graffiti.availableLogos or {})
  end)

  QBCore.Functions.CreateUseableItem(Config.Graffiti.paintRemoverItem, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local canUse = false
    if Player.PlayerData.job and (Player.PlayerData.job.name == 'police' or Player.PlayerData.job.name == 'sheriff') then
      canUse = true
    else
      local gang = GetPlayerGang(src)
      if gang then canUse = true end
    end
    if not canUse then TriggerClientEvent('QBCore:Notify', src, "You cannot use paint remover", "error"); return end
    TriggerClientEvent('cold-gangs:client:UsePaintRemover', src)
  end)
end

function RegisterServerEvents()
  if serverEventsRegistered then return end
  serverEventsRegistered = true
  QBCore.Functions.CreateCallback('cold-gangs:graffiti:GetConfig', function(src, cb) cb(Config.Graffiti) end)

  RegisterNetEvent('cold-gangs:server:RequestGraffitis', function()
    local src = source
    TriggerClientEvent('cold-gangs:client:LoadGraffitis', src, graffitis)
    TriggerClientEvent('cold-gangs:client:ReloadConfig', src, Config.Graffiti)
  end)

  RegisterNetEvent('cold-gangs:graffiti:Create', function(payload)
    TriggerEvent('cold-gangs:server:CreateGraffiti', payload)
  end)

  RegisterNetEvent('cold-gangs:server:CreateGraffiti', function(d)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not d or not d.coords or not d.rotation or not d.surfaceNormal then TriggerClientEvent('QBCore:Notify', src, "Invalid graffiti data", "error"); return end
    if not d.type or (d.type=='text' and not d.text) or (d.type=='logo' and not d.logo) then TriggerClientEvent('QBCore:Notify', src, "Invalid graffiti data", "error"); return end

    local gang = GetPlayerGang(src)
    if not gang then TriggerClientEvent('QBCore:Notify', src, "You are not in a gang", "error"); return end

    local can = Player.Functions.GetItemByName(Config.Graffiti.sprayCanItem)
    if not can or (can.amount or 0) < 1 then TriggerClientEvent('QBCore:Notify', src, "You need a spray can", "error"); return end

    local maxd = Config.Graffiti.maxDistance or 2.5
    for _, g in pairs(graffitis) do
      local dx = (g.coords.x - d.coords.x); local dy = (g.coords.y - d.coords.y); local dz = (g.coords.z - d.coords.z)
      if math.sqrt(dx*dx + dy*dy + dz*dz) <= maxd then TriggerClientEvent('QBCore:Notify', src, "There's already graffiti too close", "error"); return end
    end

    playerCooldowns[src] = GetGameTimer()

    local territory = d.territory
    if (not territory or territory=='Unknown') and exports['cold-gangs'] and exports['cold-gangs'].GetTerritoryAtCoords then
      territory = exports['cold-gangs']:GetTerritoryAtCoords(vector3(d.coords.x,d.coords.y,d.coords.z)) or 'Unknown'
    end

    local coords_x,coords_y,coords_z = tonumber(d.coords.x) or 0.0, tonumber(d.coords.y) or 0.0, tonumber(d.coords.z) or 0.0
    local rotation_x,rotation_y,rotation_z = tonumber(d.rotation.x) or 0.0, tonumber(d.rotation.y) or 0.0, tonumber(d.rotation.z) or 0.0
    local surface_x,surface_y,surface_z = tonumber(d.surfaceNormal.x) or 0.0, tonumber(d.surfaceNormal.y) or 1.0, tonumber(d.surfaceNormal.z) or 0.0
    local color_hex = d.colorHex or "FFFFFF"
    local font_face = d.fontFace or "ChaletLondon"
    local scale = tonumber(d.scale) or 0.18
    if d.type=='text' and d.text then d.text = string.sub(d.text, 1, 80) end

    MySQL.insert('INSERT INTO gang_graffitis (gang_id, gang_name, territory, coords_x, coords_y, coords_z, rotation_x, rotation_y, rotation_z, rotation_offset, surface_normal_x, surface_normal_y, surface_normal_z, graffiti_type, graffiti_text, graffiti_logo, color_hex, font_face, scale, creator_citizenid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
      gang.id, gang.name, territory,
      coords_x, coords_y, coords_z,
      rotation_x, rotation_y, rotation_z,
      tonumber(d.rotationOffset) or 0.0,
      surface_x, surface_y, surface_z,
      d.type, d.text, d.logo,
      color_hex, font_face, scale,
      Player.PlayerData.citizenid
    }, function(insertId)
      if not insertId then TriggerClientEvent('QBCore:Notify', src, "Failed to create graffiti", "error"); return end
      graffitis[insertId] = {
        id = insertId,
        gangId = gang.id, gangName = gang.name, territory = territory or 'Unknown',
        coords = { x=coords_x, y=coords_y, z=coords_z },
        rotation = { x=rotation_x, y=rotation_y, z=rotation_z },
        surfaceNormal = { x=surface_x, y=surface_y, z=surface_z },
        type = d.type, text = d.text, logo = d.logo,
        colorHex = color_hex, fontFace = font_face, scale = scale,
        creator = Player.PlayerData.citizenid, createdAt = os.date('%Y-%m-%d %H:%M:%S')
      }

      Player.Functions.RemoveItem(Config.Graffiti.sprayCanItem, 1)
      TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Graffiti.sprayCanItem], "remove", 1)

      if Config.TerritoryIntegration and Config.TerritoryIntegration.enabled and territory and Config.TerritoryIntegration.influenceEvents and Config.TerritoryIntegration.influenceEvents.createGraffiti then
        local gain = (Config.Graffiti.influenceGain and Config.Graffiti.influenceGain[d.type]) or 10
        TriggerEvent(Config.TerritoryIntegration.influenceEvents.createGraffiti, territory, gang.id, gain, 'graffiti')
        TriggerClientEvent('QBCore:Notify', src, ("Graffiti created! +%d influence"):format(gain), "success")
      else
        TriggerClientEvent('QBCore:Notify', src, "Graffiti created successfully!", "success")
      end

      TriggerClientEvent('cold-gangs:client:AddGraffiti', -1, insertId, graffitis[insertId])
    end)
  end)

  RegisterNetEvent('cold-gangs:server:RemoveGraffiti', function(graffitiId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local g = graffitis[graffitiId]
    if not g then TriggerClientEvent('QBCore:Notify', src, "Graffiti not found", "error"); return end

    local canRemove, needsPR, reason = false, false, ""
    if QBCore.Functions.HasPermission(src, 'admin') then
      canRemove = true; reason = "admin"
    elseif Player.PlayerData.job and (Player.PlayerData.job.name=='police' or Player.PlayerData.job.name=='sheriff') then
      canRemove = true; needsPR = true; reason = "police"
    else
      local gang = GetPlayerGang(src)
      if gang then
        canRemove = true
        if gang.id ~= g.gangId then needsPR = true; reason = "rival_gang" else reason = "own_gang" end
      end
    end

    if not canRemove then TriggerClientEvent('QBCore:Notify', src, "You cannot remove this graffiti", "error"); return end
    if needsPR then
      local pr = Player.Functions.GetItemByName(Config.Graffiti.paintRemoverItem)
      if not pr or (pr.amount or 0) < 1 then TriggerClientEvent('QBCore:Notify', src, "You need paint remover to remove this graffiti", "error"); return end
      Player.Functions.RemoveItem(Config.Graffiti.paintRemoverItem, 1)
      TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.Graffiti.paintRemoverItem], "remove", 1)
    end

    MySQL.query('DELETE FROM gang_graffitis WHERE id = ?', {graffitiId}, function(affected)
      if affected and affected > 0 then
        local removed = graffitis[graffitiId]
        graffitis[graffitiId] = nil
        TriggerClientEvent('cold-gangs:client:RemoveGraffiti', -1, graffitiId)
        if reason == "rival_gang" and removed.territory and Config.TerritoryIntegration and Config.TerritoryIntegration.enabled and Config.TerritoryIntegration.influenceEvents and Config.TerritoryIntegration.influenceEvents.removeGraffiti then
          local gang = GetPlayerGang(src)
          if gang then
            local gain = math.floor(((Config.Graffiti.influenceGain and Config.Graffiti.influenceGain[removed.type]) or 10) * 0.5)
            TriggerEvent(Config.TerritoryIntegration.influenceEvents.removeGraffiti, removed.territory, gang.id, gain, 'graffiti_removal')
            TriggerClientEvent('QBCore:Notify', src, ("Rival graffiti removed! +%d influence"):format(gain), "success")
          end
        else
          TriggerClientEvent('QBCore:Notify', src, "Graffiti removed successfully", "success")
        end
      else
        TriggerClientEvent('QBCore:Notify', src, "Failed to remove graffiti", "error")
      end
    end)
  end)

  RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    TriggerClientEvent('cold-gangs:client:ReloadConfig', src, Config.Graffiti)
    TriggerClientEvent('cold-gangs:client:LoadGraffitis', src, graffitis)
  end)
end

function GetPlayerGang(src)
  local Player = QBCore.Functions.GetPlayer(src)
  if not Player then return nil end
  if ColdGangs and ColdGangs.Core and ColdGangs.Core.GetPlayerGangId then
    local gid = ColdGangs.Core.GetPlayerGangId(src)
    if gid then
      local row = MySQL.Sync.fetchAll('SELECT id, name, color FROM cold_gangs WHERE id = ? LIMIT 1', { gid })
      if row and row[1] then
        return { id = row[1].id, name = row[1].name, label = row[1].name, color = row[1].color or '#FF0000' }
      end
    end
  end
  local pd = Player.PlayerData
  if pd and pd.gang and pd.gang.name and pd.gang.name ~= 'none' then
    local r = MySQL.Sync.fetchAll('SELECT id, name, color FROM cold_gangs WHERE name = ? LIMIT 1', { pd.gang.name })
    if r and r[1] then return { id = r[1].id, name = r[1].name, label = pd.gang.label or r[1].name, color = r[1].color or '#FF0000' } end
  end
  local res = MySQL.Sync.fetchAll('SELECT g.id, g.name, g.color FROM cold_gangs g JOIN cold_gang_members gm ON g.id = gm.gang_id WHERE gm.citizen_id = ? LIMIT 1', { pd.citizenid })
  if res and res[1] then return { id = res[1].id, name = res[1].name, label = res[1].name, color = res[1].color or '#FF0000' } end
  return nil
end

QBCore.Commands.Add('removegraffiti', 'Remove nearby graffiti (Admin)', {}, false, function(source)
  local src = source
  if not QBCore.Functions.HasPermission(src, 'admin') then TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error'); return end
  TriggerClientEvent('cold-gangs:client:AdminRemoveGraffiti', src)
end, 'admin')

QBCore.Commands.Add('reloadgraffiti', 'Reload all graffitis (Admin)', {}, false, function(source)
  local src = source
  if not QBCore.Functions.HasPermission(src, 'admin') then TriggerClientEvent('QBCore:Notify', src, 'No permission', 'error'); return end
  LoadGraffitis()
  TriggerClientEvent('QBCore:Notify', src, 'Graffitis reloaded', 'success')
end, 'admin')

exports('GetGraffitis', function() return graffitis end)
exports('GetGraffitisByGang', function(gangName) local r = {}; for id,g in pairs(graffitis) do if g.gangName==gangName then r[id]=g end end return r end)
exports('ReloadGraffitis', function() LoadGraffitis() end)
