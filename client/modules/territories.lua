local QBCore = exports['qb-core']:GetCoreObject()

local Territories = {}
local TerritoryBlips = {}
local ShowTerritories = true
local ShowOutlines = false
local CurrentZone = nil
local PlayerGang = nil
local isLoggedIn = false
local NotificationCooldowns = {}

local creatingZone = false
local drawnPoints = {}
local zoneName, zoneLabel = nil, nil
local createThread = nil

local CFG = {
  TERRITORY_CHECK_INTERVAL = 5000,
  BLIP_REFRESH_INTERVAL = 45000,
  NOTIFICATION_COOLDOWN = 8000,
  BLIP = {
    DISPLAY = 3,
    ALPHA_UNCLAIMED = 80,
    ALPHA_CLAIMED = 130,
    ALPHA_CONTESTED = 180,
    FLASH_INTERVAL = 500,
    FLASH_DURATION = 60000,
    POLY_STEP = 90.0,
    POLY_MAX_RECTS = 120,
    GREY_COLOR_ID = 39 -- ensure default #808080 shows as GREY (not white)
  }
}

-- Helpers

local function GetMapZones()
  if Config and Config.MapZones then return Config.MapZones end
  if _G.Config and _G.Config.MapZones then return _G.Config.MapZones end
  return {}
end

local function SendNotificationWithCooldown(message, type, duration, key)
  local now = GetGameTimer()
  key = key or "default"
  if NotificationCooldowns[key] and now - NotificationCooldowns[key] < CFG.NOTIFICATION_COOLDOWN then return end
  NotificationCooldowns[key] = now
  QBCore.Functions.Notify(message, type, duration or 5000)
end

-- Force default unclaimed (#808080) to grey blip ID instead of white
local function GetBlipColorFromHex(hex)
  local GREY_ID = CFG.BLIP.GREY_COLOR_ID or 39
  if not hex or hex == "" then return GREY_ID end
  hex = hex:gsub("#", ""):lower()
  local map = {
    ["ff0000"]=1, ["dc143c"]=1, ["8b0000"]=1,
    ["00ff00"]=2, ["228b22"]=2, ["32cd32"]=2,
    ["0000ff"]=3, ["000080"]=3, ["4169e1"]=3,
    ["ffff00"]=5, ["ffd700"]=5,
    ["ff8000"]=6, ["ffa500"]=6, ["ff4500"]=6,
    ["ff00ff"]=7, ["800080"]=7, ["9400d3"]=7,
    ["00ffff"]=8, ["008b8b"]=8, ["20b2aa"]=8,
    ["ffffff"]=0, ["000000"]=40,
    ["808080"]=GREY_ID
  }
  if map[hex] ~= nil then return map[hex] end
  local r = tonumber(hex:sub(1,2),16) or 128
  local g = tonumber(hex:sub(3,4),16) or 128
  local b = tonumber(hex:sub(5,6),16) or 128
  local maxv = math.max(r,g,b)
  local minv = math.min(r,g,b)
  local diff = maxv-minv
  if diff < 30 then
    if maxv > 200 then return GREY_ID elseif maxv < 50 then return 40 else return GREY_ID end
  end
  if r == maxv then
    if g > b + 30 then return 5 elseif b > g + 30 then return 7 else return 1 end
  elseif g == maxv then
    if r > b + 30 then return 5 elseif b > r + 30 then return 8 else return 2 end
  else
    if r > g + 30 then return 7 elseif g > r + 30 then return 8 else return 3 end
  end
end

local function PrettyLabel(code)
  if not code or code == '' then return '-' end
  local s = code:gsub('_',' '):lower()
  return s:gsub("(%a)([%w_']*)", function(a,b) return a:upper()..b end)
end

local function RemoveAllTerritoryBlips()
  for _, blip in pairs(TerritoryBlips) do
    if DoesBlipExist(blip) then RemoveBlip(blip) end
  end
  TerritoryBlips = {}
end

-- Geometry helpers
local function inRect(x, y, part)
  local minX = math.min(part.x1, part.x2)
  local maxX = math.max(part.x1, part.x2)
  local minY = math.min(part.y1, part.y2)
  local maxY = math.max(part.y1, part.y2)
  return x >= minX and x <= maxX and y >= minY and y <= maxY
end

local function pointInPolygon(x, y, pts)
  local inside = false
  local j = #pts
  for i = 1, #pts do
    local xi, yi = pts[i].x, pts[i].y
    local xj, yj = pts[j].x, pts[j].y
    local intersect = ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 1e-9) + xi)
    if intersect then inside = not inside end
    j = i
  end
  return inside
end

local function polygonFillRects(pts, step, maxRects)
  local rects = {}
  if not pts or #pts < 3 then return rects end
  local minY, maxY = math.huge, -math.huge
  for i = 1, #pts do
    local p = pts[i]
    if p.y < minY then minY = p.y end
    if p.y > maxY then maxY = p.y end
  end
  step = step or 100.0
  maxRects = maxRects or 120

  local y = minY
  while y < maxY and #rects < maxRects do
    local yMid = y + step * 0.5
    local xs = {}
    local n = #pts
    for i = 1, n do
      local a = pts[i]
      local b = pts[(i % n) + 1]
      local y1, y2 = a.y, b.y
      local x1, x2 = a.x, b.x
      if ((y1 <= yMid and y2 > yMid) or (y2 <= yMid and y1 > yMid)) and (y2 - y1) ~= 0 then
        local xInt = x1 + (yMid - y1) * (x2 - x1) / (y2 - y1)
        xs[#xs+1] = xInt
      end
    end
    table.sort(xs, function(a,b) return a < b end)
    for i = 1, #xs, 2 do
      local xL = xs[i]
      local xR = xs[i+1]
      if xL and xR and xR > xL then
        local width = xR - xL
        local height = step
        local cx = (xL + xR) * 0.5
        local cy = yMid
        rects[#rects+1] = { x = cx, y = cy, w = width, h = height }
        if #rects >= maxRects then break end
      end
    end
    y = y + step
  end
  return rects
end

-- Territory detection on client
local function GetCurrentTerritory()
  local coords = GetEntityCoords(PlayerPedId())
  for name, t in pairs(Territories) do
    local pts = t.zone_points
    if pts and type(pts) == 'table' and #pts >= 3 then
      if pointInPolygon(coords.x, coords.y, pts) then return name end
    end
  end
  local zones = GetMapZones()
  for name, zone in pairs(zones) do
    if zone.parts then
      for _, p in ipairs(zone.parts) do
        if inRect(coords.x, coords.y, p) then return name end
      end
    end
  end
  return nil
end

local function MergeThinIntoLocal(thin)
  if not thin then return end
  for name, u in pairs(thin) do
    local t = Territories[name] or {}
    t.label       = u.label or t.label
    t.gangId      = u.gangId
    t.gangName    = u.gangName or t.gangName
    t.colorHex    = u.colorHex or t.colorHex
    t.contested   = (u.contested ~= nil) and u.contested or t.contested
    t.contestedBy = (u.contestedBy ~= nil) and u.contestedBy or t.contestedBy
    Territories[name] = t
  end
end

-- Blips

local function CreateTerritoryBlips()
  RemoveAllTerritoryBlips()
  if not Territories or not next(Territories) then return end
  local zones = GetMapZones()
  for name, t in pairs(Territories) do
    local zone = zones[name]
    local color = GetBlipColorFromHex(t.colorHex)
    local alpha = t.gangId and CFG.BLIP.ALPHA_CLAIMED or CFG.BLIP.ALPHA_UNCLAIMED
    if t.contested then alpha = CFG.BLIP.ALPHA_CONTESTED end

    if zone and zone.parts and #zone.parts > 0 then
      for i, part in ipairs(zone.parts) do
        local width = math.abs(part.x2 - part.x1)
        local height = math.abs(part.y2 - part.y1)
        local x = (part.x1 + part.x2) / 2.0
        local y = (part.y1 + part.y2) / 2.0
        local blip = AddBlipForArea(x, y, 0.0, width, height)
        SetBlipColour(blip, color)
        SetBlipAlpha(blip, alpha)
        SetBlipDisplay(blip, CFG.BLIP.DISPLAY)
        SetBlipHighDetail(blip, true)
        SetBlipAsShortRange(blip, false)
        if i == 1 then
          BeginTextCommandSetBlipName("STRING")
          local label = (t and t.label) or (zone and zone.label) or PrettyLabel(name)
          if t.gangName and t.gangName ~= "Unclaimed" then label = label .. " (" .. t.gangName .. ")" end
          AddTextComponentString(label)
          EndTextCommandSetBlipName(blip)
        end
        if t.contested then
          SetBlipFlashes(blip, true)
          SetBlipFlashInterval(blip, CFG.BLIP.FLASH_INTERVAL)
          SetBlipFlashTimer(blip, CFG.BLIP.FLASH_DURATION)
        end
        TerritoryBlips[name .. "_part_" .. i] = blip
      end

    elseif t.zone_points and type(t.zone_points) == 'table' and #t.zone_points >= 3 then
      local rects = polygonFillRects(t.zone_points, CFG.BLIP.POLY_STEP, CFG.BLIP.POLY_MAX_RECTS)
      for i, r in ipairs(rects) do
        local blip = AddBlipForArea(r.x, r.y, 0.0, r.w, r.h)
        SetBlipColour(blip, color)
        SetBlipAlpha(blip, alpha)
        SetBlipDisplay(blip, CFG.BLIP.DISPLAY)
        SetBlipHighDetail(blip, true)
        SetBlipAsShortRange(blip, false)
        if i == 1 then
          BeginTextCommandSetBlipName("STRING")
          local label = (t and t.label) or PrettyLabel(name)
          if t.gangName and t.gangName ~= "Unclaimed" then label = label .. " (" .. t.gangName .. ")" end
          AddTextComponentString(label)
          EndTextCommandSetBlipName(blip)
        end
        if t.contested then
          SetBlipFlashes(blip, true)
          SetBlipFlashInterval(blip, CFG.BLIP.FLASH_INTERVAL)
          SetBlipFlashTimer(blip, CFG.BLIP.FLASH_DURATION)
        end
        TerritoryBlips[name .. "_poly_" .. i] = blip
      end

    else
      local cx = t.center_x or (t.coords and t.coords.x)
      local cy = t.center_y or (t.coords and t.coords.y)
      local cz = t.center_z or (t.coords and t.coords.z) or 30.0
      if cx and cy then
        local blip = AddBlipForCoord(cx, cy, cz)
        SetBlipSprite(blip, 84)
        SetBlipColour(blip, color)
        SetBlipAlpha(blip, alpha)
        SetBlipDisplay(blip, CFG.BLIP.DISPLAY)
        SetBlipHighDetail(blip, true)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName("STRING")
        local label = (t and t.label) or (zone and zone.label) or PrettyLabel(name)
        if t.gangName and t.gangName ~= "Unclaimed" then label = label .. " (" .. t.gangName .. ")" end
        AddTextComponentString(label)
        EndTextCommandSetBlipName(blip)
        TerritoryBlips[name .. "_point"] = blip
      end
    end
  end
end

local function UpdateTerritoryBlip(name, data)
  local zones = GetMapZones()
  local zone = zones[name]
  for key, blip in pairs(TerritoryBlips) do
    if key:find(name .. "_part_") or key == name .. "_point" or key:find(name .. "_poly_") then
      if DoesBlipExist(blip) then RemoveBlip(blip) end
      TerritoryBlips[key] = nil
    end
  end

  local color = GetBlipColorFromHex(data.colorHex)
  local alpha = data.gangId and CFG.BLIP.ALPHA_CLAIMED or CFG.BLIP.ALPHA_UNCLAIMED
  if data.contested then alpha = CFG.BLIP.ALPHA_CONTESTED end

  if zone and zone.parts and #zone.parts > 0 then
    for i, part in ipairs(zone.parts) do
      local width = math.abs(part.x2 - part.x1)
      local height = math.abs(part.y2 - part.y1)
      local x = (part.x1 + part.x2) / 2.0
      local y = (part.y1 + part.y2) / 2.0
      local blip = AddBlipForArea(x, y, 0.0, width, height)
      SetBlipColour(blip, color)
      SetBlipAlpha(blip, alpha)
      SetBlipDisplay(blip, CFG.BLIP.DISPLAY)
      SetBlipHighDetail(blip, true)
      SetBlipAsShortRange(blip, false)
      if i == 1 then
        BeginTextCommandSetBlipName("STRING")
        local label = (data and data.label) or (zone and zone.label) or PrettyLabel(name)
        if data.gangName and data.gangName ~= "Unclaimed" then label = label .. " (" .. data.gangName .. ")" end
        AddTextComponentString(label)
        EndTextCommandSetBlipName(blip)
      end
      if data.contested then
        SetBlipFlashes(blip, true)
        SetBlipFlashInterval(blip, CFG.BLIP.FLASH_INTERVAL)
        SetBlipFlashTimer(blip, CFG.BLIP.FLASH_DURATION)
      end
      TerritoryBlips[name .. "_part_" .. i] = blip
    end

  elseif data.zone_points and type(data.zone_points) == 'table' and #data.zone_points >= 3 then
    local rects = polygonFillRects(data.zone_points, CFG.BLIP.POLY_STEP, CFG.BLIP.POLY_MAX_RECTS)
    for i, r in ipairs(rects) do
      local blip = AddBlipForArea(r.x, r.y, 0.0, r.w, r.h)
      SetBlipColour(blip, color)
      SetBlipAlpha(blip, alpha)
      SetBlipDisplay(blip, CFG.BLIP.DISPLAY)
      SetBlipHighDetail(blip, true)
      SetBlipAsShortRange(blip, false)
      if i == 1 then
        BeginTextCommandSetBlipName("STRING")
        local label = (data and data.label) or PrettyLabel(name)
        if data.gangName and data.gangName ~= "Unclaimed" then label = label .. " (" .. data.gangName .. ")" end
        AddTextComponentString(label)
        EndTextCommandSetBlipName(blip)
      end
      if data.contested then
        SetBlipFlashes(blip, true)
        SetBlipFlashInterval(blip, CFG.BLIP.FLASH_INTERVAL)
        SetBlipFlashTimer(blip, CFG.BLIP.FLASH_DURATION)
      end
      TerritoryBlips[name .. "_poly_" .. i] = blip
    end

  else
    local cx = data.center_x or (data.coords and data.coords.x)
    local cy = data.center_y or (data.coords and data.coords.y)
    local cz = data.center_z or (data.coords and data.coords.z) or 30.0
    if cx and cy then
      local blip = AddBlipForCoord(cx, cy, cz)
      SetBlipSprite(blip, 84)
      SetBlipColour(blip, color)
      SetBlipAlpha(blip, alpha)
      SetBlipDisplay(blip, CFG.BLIP.DISPLAY)
      SetBlipHighDetail(blip, true)
      SetBlipAsShortRange(blip, false)
      BeginTextCommandSetBlipName("STRING")
      local label = (data and data.label) or (zone and zone.label) or PrettyLabel(name)
      if data.gangName and data.gangName ~= "Unclaimed" then label = label .. " (" .. data.gangName .. ")" end
      AddTextComponentString(label)
      EndTextCommandSetBlipName(blip)
      TerritoryBlips[name .. "_point"] = blip
    end
  end
end

-- Initial fetch
CreateThread(function()
  Wait(3000)
  QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
    MergeThinIntoLocal(territories or {})
    if ShowTerritories then CreateTerritoryBlips() end
  end)
end)

-- Zone tracking and server presence reporting
CreateThread(function()
  local lastCheck = 0
  while true do
    if isLoggedIn then
      local now = GetGameTimer()
      if now - lastCheck >= CFG.TERRITORY_CHECK_INTERVAL then
        local newZone = GetCurrentTerritory()
        if newZone ~= CurrentZone then
          if CurrentZone then
            TriggerEvent('cold-gangs:client:LeftTerritory', CurrentZone)
            TriggerServerEvent('cold-gangs:server:LeftTerritory', CurrentZone)
          end
          CurrentZone = newZone
          TriggerServerEvent('cold-gangs:server:SetPlayerTerritory', CurrentZone)
          if CurrentZone then
            TriggerEvent('cold-gangs:client:EnteredTerritory', CurrentZone)
            TriggerServerEvent('cold-gangs:server:EnteredTerritory', CurrentZone)
          end
        end

        -- Heartbeat: keep server-side mapping alive across restarts
        TriggerServerEvent('cold-gangs:server:SetPlayerTerritory', CurrentZone)

        lastCheck = now
      end
      Wait(1000)
    else
      Wait(3000)
    end
  end
end)

-- Periodic blip refresh
CreateThread(function()
  while true do
    Wait(CFG.BLIP_REFRESH_INTERVAL)
    if ShowTerritories and isLoggedIn then
      QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
        if territories and next(territories) then
          local hadAny = next(Territories) ~= nil
          MergeThinIntoLocal(territories)
          if ShowTerritories and hadAny then
            CreateTerritoryBlips()
          end
        end
      end)
    end
  end
end)

-- Optional outlines
CreateThread(function()
  while true do
    Wait(0)
    if ShowOutlines and Territories and next(Territories) then
      for _, t in pairs(Territories) do
        local pts = t.zone_points
        if pts and #pts > 2 then
          local r,g,b,a = 0,255,0,180
          for i=1,#pts do
            local p1 = pts[i]
            local p2 = pts[i+1] or pts[1]
            DrawLine(p1.x, p1.y, (p1.z or 30.0) + 0.2, p2.x, p2.y, (p2.z or 30.0) + 0.2, r,g,b,a)
          end
        end
      end
    else
      Wait(500)
    end
  end
end)

-- Player load/unload

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
  isLoggedIn = true
  if QBCore and QBCore.Functions and QBCore.Functions.TriggerCallback then
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(gangData)
      PlayerGang = gangData
    end)
  end
  QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
    MergeThinIntoLocal(territories or {})
    if ShowTerritories then CreateTerritoryBlips() end
  end)
  CurrentZone = GetCurrentTerritory()
  TriggerServerEvent('cold-gangs:server:SetPlayerTerritory', CurrentZone)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
  isLoggedIn = false
  RemoveAllTerritoryBlips()
  CurrentZone = nil
  PlayerGang = nil
  NotificationCooldowns = {}
end)

-- Sync from server

RegisterNetEvent('cold-gangs:client:SyncTerritories', function(territories)
  Territories = territories or {}
  if ShowTerritories then CreateTerritoryBlips() end
end)

RegisterNetEvent('cold-gangs:client:UpdateTerritory', function(name, data)
  Territories[name] = data
  if ShowTerritories then UpdateTerritoryBlip(name, data) end
end)

-- Notifications

RegisterNetEvent('cold-gangs:client:EnteredTerritory', function(name)
  local t = Territories[name] or {}
  local owner = t.gangName or "Unclaimed"
  local zones = GetMapZones()
  local label = t.label or (zones[name] and zones[name].label) or PrettyLabel(name)
  local color = "primary"
  if t.gangId and PlayerGang and PlayerGang.id == t.gangId then
    color = "success"
  elseif t.gangId then
    color = "error"
  end
  SendNotificationWithCooldown("Entered: " .. label .. " | Controlled by: " .. owner, color, 4000, "enter_"..name)
end)

RegisterNetEvent('cold-gangs:client:LeftTerritory', function(name)
  local t = Territories[name] or {}
  local zones = GetMapZones()
  local label = t.label or (zones[name] and zones[name].label) or PrettyLabel(name)
  SendNotificationWithCooldown("Left: " .. label, "primary", 2000, "leave_"..name)
end)

RegisterNetEvent('cold-gangs:client:TerritoryCapture', function(name, gangName, gangColor)
  local key = "capture_"..name.."_"..(gangName or "unknown")
  local now = GetGameTimer()
  if NotificationCooldowns[key] and now - NotificationCooldowns[key] < 15000 then return end
  NotificationCooldowns[key] = now
  local t = Territories[name] or {}
  local zones = GetMapZones()
  local label = t.label or (zones[name] and zones[name].label) or PrettyLabel(name)
  QBCore.Functions.Notify("🏆 Territory Captured!\n" .. label .. " is now controlled by " .. (gangName or "Unknown"), "success", 8000)
  if Territories[name] then
    Territories[name].gangName = gangName
    Territories[name].colorHex = gangColor
    Territories[name].contested = false
    if ShowTerritories then UpdateTerritoryBlip(name, Territories[name]) end
  end
end)

RegisterNetEvent('cold-gangs:client:TerritoryLost', function(name)
  local t = Territories[name] or {}
  local zones = GetMapZones()
  local label = t.label or (zones[name] and zones[name].label) or PrettyLabel(name)
  SendNotificationWithCooldown("📉 Territory Lost: " .. label .. " is now unclaimed", "error", 6000, "lost_"..name)
  if Territories[name] then
    Territories[name].gangName = "Unclaimed"
    Territories[name].colorHex = '#808080'
    Territories[name].contested = false
    if ShowTerritories then UpdateTerritoryBlip(name, Territories[name]) end
  end
end)

RegisterNetEvent('cold-gangs:client:TerritoryContestedStart', function(name, contestingGang)
  local t = Territories[name] or {}
  local zones = GetMapZones()
  local label = t.label or (zones[name] and zones[name].label) or PrettyLabel(name)
  SendNotificationWithCooldown("⚔️ Territory Contested!\n" .. label .. " is being challenged by " .. (contestingGang or "Unknown"), "warning", 8000, "contested_"..name)
  if Territories[name] then
    Territories[name].contested = true
    Territories[name].contestedBy = contestingGang
    if ShowTerritories then UpdateTerritoryBlip(name, Territories[name]) end
  end
end)

RegisterNetEvent('cold-gangs:client:TerritoryContestedEnd', function(name)
  local t = Territories[name] or {}
  local zones = GetMapZones()
  local label = t.label or (zones[name] and zones[name].label) or PrettyLabel(name)
  SendNotificationWithCooldown("✅ Territory Stable: " .. label .. " is no longer contested", "primary", 5000, "stable_"..name)
  if Territories[name] then
    Territories[name].contested = false
    Territories[name].contestedBy = nil
    if ShowTerritories then UpdateTerritoryBlip(name, Territories[name]) end
  end
end)

-- Commands

RegisterCommand('toggleterritories', function()
  ShowTerritories = not ShowTerritories
  if ShowTerritories then
    QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
      MergeThinIntoLocal(territories or {})
      CreateTerritoryBlips()
    end)
    QBCore.Functions.Notify("Territory display enabled", "success")
  else
    RemoveAllTerritoryBlips()
    QBCore.Functions.Notify("Territory display disabled", "primary")
  end
end, false)

RegisterCommand('showzones', function()
  QBCore.Functions.TriggerCallback('cold-gangs:server:IsPlayerAdmin', function(isAdmin)
    if not isAdmin then
      QBCore.Functions.Notify("You don't have permission to use this.", "error")
      return
    end
    ShowOutlines = not ShowOutlines
    QBCore.Functions.Notify(ShowOutlines and "Zone outlines ON" or "Zone outlines OFF", ShowOutlines and "success" or "error")
  end)
end, false)

RegisterCommand('refreshterritories', function()
  QBCore.Functions.TriggerCallback('cold-gangs:server:GetAllTerritories', function(territories)
    MergeThinIntoLocal(territories or {})
    if ShowTerritories then CreateTerritoryBlips() end
    QBCore.Functions.Notify("Territories refreshed", "success")
  end)
end, false)

-- Zone creation tool

RegisterNetEvent("cold-gangs:client:StartZoneCreation", function(name, label)
  QBCore.Functions.TriggerCallback('cold-gangs:server:IsPlayerAdmin', function(isAdmin)
    if not isAdmin then
      QBCore.Functions.Notify("You don't have permission to create territories", "error")
      return
    end
    if creatingZone then
      QBCore.Functions.Notify("Already creating a zone.", "error")
      return
    end
    creatingZone = true
    zoneName = name
    zoneLabel = label or name
    drawnPoints = {}
    QBCore.Functions.Notify("Zone creation started. [E] add points, [G] finish, [X] cancel", "primary")
    if createThread then createThread = nil end
    createThread = CreateThread(function()
      while creatingZone do
        Wait(0)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0,0,0,0,0,0, 0.25,0.25,0.25, 0,255,0,150, false,false,2,false,nil,nil,false)
        if IsControlJustPressed(0, 38) then
          table.insert(drawnPoints, {x=coords.x, y=coords.y, z=coords.z})
          QBCore.Functions.Notify(("Added point #%d"):format(#drawnPoints), "success")
        elseif IsControlJustPressed(0, 47) then
          if #drawnPoints >= 3 then
            creatingZone = false
            QBCore.Functions.Notify("Finalizing zone...", "primary")
            TriggerServerEvent("cold-gangs:server:SaveNewTerritory", zoneName, zoneLabel, drawnPoints)
          else
            QBCore.Functions.Notify("Need at least 3 points.", "error")
          end
        elseif IsControlJustPressed(0, 73) then
          creatingZone = false
          QBCore.Functions.Notify("Cancelled zone creation.", "error")
        end
        for i, p in ipairs(drawnPoints) do
          DrawMarker(28, p.x, p.y, p.z + 0.1, 0,0,0,0,0,0, 0.3,0.3,0.3, 0,255,0,180, false,true,2,false,nil,nil,false)
          if i > 1 then
            local prev = drawnPoints[i-1]
            DrawLine(prev.x, prev.y, prev.z + 0.05, p.x, p.y, p.z + 0.05, 0,255,0,200)
          end
        end
        if #drawnPoints >= 3 then
          local first, last = drawnPoints[1], drawnPoints[#drawnPoints]
          DrawLine(last.x, last.y, last.z + 0.05, first.x, first.y, first.z + 0.05, 0,255,0,160)
        end
      end
    end)
  end)
end)

-- Exports

exports('GetCurrentTerritory', GetCurrentTerritory)
exports('IsInTerritory', function(name) return CurrentZone == name end)
exports('GetTerritories', function() return Territories end)
exports('RefreshTerritoryBlips', CreateTerritoryBlips)
exports('RemoveAllBlips', RemoveAllTerritoryBlips)
exports('GetTerritoryColor', function(name) return Territories[name] and Territories[name].colorHex or '#808080' end)
