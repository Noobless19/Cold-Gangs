-- client/modules/graffiti.lua

local QBCore = exports['qb-core']:GetCoreObject()

-- Config (client-side; server values can override via callback)
local CFG = {
  Graffiti = {
    maxDistance = 2.5,
    sprayDuration = 7000,
    removeDuration = 5000,
    minSurfaceAngle = 75.0,
    logoSettings = {
      textureDict = "shared",
      fallbackText = true,
      logoScale = { min = 0.24, max = 0.66, distanceMultiplier = 0.002 },
      renderDistance = 60.0,
      textRenderDistance = 110.0
    },
    availableLogos = {}
  }
}

-- Extended color palette
local COLORS = {
  { hex="FFFFFF", name="White" },   { hex="000000", name="Black" },   { hex="808080", name="Gray"  },
  { hex="FF3B3B", name="Red"   },   { hex="D7263D", name="Crimson" }, { hex="8B0000", name="DarkRed" },
  { hex="39C24A", name="Green" },   { hex="228B22", name="Forest"  }, { hex="00FF7F", name="Spring" },
  { hex="3AA7FF", name="Blue"  },   { hex="1E90FF", name="Dodger"  }, { hex="0000CD", name="MediumBlue" },
  { hex="F2E94E", name="Yellow"},   { hex="FFD700", name="Gold"    }, { hex="FFA500", name="Orange" },
  { hex="FF7AF6", name="Pink"  },   { hex="FF1493", name="DeepPink"}, { hex="FFC0CB", name="LightPink" },
  { hex="9F7BFF", name="Purple"},   { hex="8A2BE2", name="BlueViolet" }, { hex="800080", name="Indigo" },
  { hex="00CED1", name="DarkTurquoise"}, { hex="00FFFF", name="Cyan" }, { hex="40E0D0", name="Turquoise" },
  { hex="A52A2A", name="Brown" },   { hex="8B4513", name="SaddleBrown" }, { hex="C0C0C0", name="Silver" }
}

-- State
local graffitis = {}
local isPlacing = false

-- Fonts (gplayfont*.gfx loader fills this; ChaletLondon as fallback)
local FONTS = { { face = "ChaletLondon", label = "ChaletLondon" } }

local preview = {
  type = "text",
  text = "GRAFFITI",
  logo = nil,
  fontFace = "ChaletLondon",
  fontIndex = 1,
  colorHex = COLORS[1].hex,
  colorIndex = 1,
  scale = 0.60,
  nudge = vector3(0,0,0),
  rotationOffset = 0.0
}

local SPRAY_FORWARD_OFFSET = 0.035
local PLAYER_NAME_HEAP = {}
local SCALEFORM_PREVIEW = 12
local SCALEFORM_DRAW = 11

local rotCam = nil

-- Forbidden materials table
local FORBIDDEN_MATERIALS = {
  [1913209870]=true,[-1595148316]=true,[510490462]=true,[909950165]=true,
  [-1907520769]=true,[-1136057692]=true,[509508168]=true,[1288448767]=true,
  [-786060715]=true,[-1931024423]=true,[-1937569590]=true,[-878560889]=true,
  [1619704960]=true,[1550304810]=true,[951832588]=true,[2128369009]=true,
  [-356706482]=true,[1925605558]=true,[-1885547121]=true,[-1942898710]=true,
  [312396330]=true,[1635937914]=true,[-273490167]=true,[1109728704]=true,
  [223086562]=true,[1584636462]=true,[-461750719]=true,[1333033863]=true,
  [-1286696947]=true,[-1833527165]=true,[581794674]=true,[-913351839]=true,
  [-2041329971]=true,[-309121453]=true,[-1915425863]=true,[1429989756]=true,
  [673696729]=true,[244521486]=true,[435688960]=true,[-634481305]=true,[-1634184340]=true
}

-- Utils
local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end

local function EnsureScaleformsLoaded()
  for i = 1, 12 do
    if not PLAYER_NAME_HEAP[i] or not HasScaleformMovieLoaded(PLAYER_NAME_HEAP[i]) then
      local idx = i < 10 and ("0"..i) or tostring(i)
      PLAYER_NAME_HEAP[i] = RequestScaleformMovieInteractive("PLAYER_NAME_"..idx)
      while not HasScaleformMovieLoaded(PLAYER_NAME_HEAP[i]) do Wait(0) end
    end
  end
end

local function PushScaleformText(handle, face, hex, text)
  PushScaleformMovieFunction(handle, "SET_PLAYER_NAME")
  PushScaleformMovieFunctionParameterString(("<FONT FACE='%s' COLOR='#%s'>%s"):format(face or "ChaletLondon", hex or "FFFFFF", text or "GRAFFITI"))
  PopScaleformMovieFunctionVoid()
end

local function RotationToDirection(rotation)
  local r = { x = (math.pi/180)*rotation.x, y = (math.pi/180)*rotation.y, z = (math.pi/180)*rotation.z }
  return vector3(-math.sin(r.z) * math.abs(math.cos(r.x)), math.cos(r.z) * math.abs(math.cos(r.x)), math.sin(r.x))
end

local function CheckRay(ped, coords, direction)
  local rayEndPoint = coords + direction * 1000.0
  local rayHandle = StartShapeTestRay(coords.x,coords.y,coords.z, rayEndPoint.x,rayEndPoint.y,rayEndPoint.z, 1, ped)
  local _, hit, endCoords, surfaceNormal, materialHash, _ = GetShapeTestResultEx(rayHandle)
  return hit == 1, endCoords, surfaceNormal, materialHash
end

local function IsNormalSame(n1, n2)
  return math.abs(n1.x-n2.x) < 0.01 and math.abs(n1.y-n2.y) < 0.01 and math.abs(n1.z-n2.z) < 0.01
end

-- Cached multi-raycast to find good wall
local LastRayStart, LastRayDirection, LastComputedRayEndCoords, LastComputedRayNormal, LastError = nil,nil,nil,nil,nil
local function FindRaycastedWall()
  local ped = PlayerPedId()
  local coords = GetEntityCoords(ped)
  local cameraRotation = GetGameplayCamRot()
  local cameraCoord = GetGameplayCamCoord()
  local direction = RotationToDirection(cameraRotation)
  local rayStart = cameraCoord
  local rayDirection = direction

  if not LastRayStart or not LastRayDirection or (not LastComputedRayEndCoords and not LastError) or rayStart ~= LastRayStart or rayDirection ~= LastRayDirection then
    LastRayStart = rayStart
    LastRayDirection = rayDirection

    local rayHit, rayEndCoords, rayNormal, materialHash = CheckRay(ped, rayStart, rayDirection)
    local ray2Hit, ray2EndCoords, ray2Normal = CheckRay(ped, rayStart + vector3(0.0, 0.0, 0.2), rayDirection)
    local ray3Hit, ray3EndCoords, ray3Normal = CheckRay(ped, rayStart + vector3(1.0, 0.0, 0.0), rayDirection)
    local ray4Hit, ray4EndCoords, ray4Normal = CheckRay(ped, rayStart + vector3(-1.0, 0.0, 0.0), rayDirection)
    local ray5Hit, ray5EndCoords, ray5Normal = CheckRay(ped, rayStart + vector3(0.0, 1.0, 0.0), rayDirection)
    local ray6Hit, ray6EndCoords, ray6Normal = CheckRay(ped, rayStart + vector3(0.0, -1.0, 0.0), rayDirection)

    local isOnGround = ray2Normal and ray2Normal.z > 0.9
    if not isOnGround and rayHit and ray2Hit and ray3Hit and ray4Hit and ray5Hit and ray6Hit then
      if not FORBIDDEN_MATERIALS[materialHash] then
        if #(coords - rayEndCoords) < 3.5 then
          if IsNormalSame(rayNormal,ray2Normal) and IsNormalSame(rayNormal,ray3Normal) and IsNormalSame(rayNormal,ray4Normal) and IsNormalSame(rayNormal,ray5Normal) and IsNormalSame(rayNormal,ray6Normal) then
            LastComputedRayEndCoords = rayEndCoords
            LastComputedRayNormal = rayNormal
            LastError = nil
            return LastComputedRayEndCoords, LastComputedRayNormal, rayDirection
          else
            LastError = "not_flat"
          end
        else
          LastError = "too_far"
        end
      else
        LastError = "invalid_surface"
      end
    else
      LastError = "aim"
    end
    LastComputedRayEndCoords = nil
    LastComputedRayNormal = nil
    return nil,nil,nil
  else
    return LastComputedRayEndCoords, LastComputedRayNormal, LastComputedRayNormal
  end
end

local function NormalToRot(n, rotationOffset)
  local f = vector3(-n.x, -n.y, -n.z)
  local rotX = -math.deg(math.asin(f.z))
  local rotZ = math.deg(math.atan2(f.x, f.y))
  local rotY = rotationOffset or 0.0
  return vector3(rotX, rotY, rotZ)
end

local function CanSeeSpray(camCoords, sprayCoords)
  local rayHandle = StartShapeTestRay(camCoords.x,camCoords.y,camCoords.z, sprayCoords.x,sprayCoords.y,sprayCoords.z, 1, PlayerPedId())
  local _, hit = GetShapeTestResult(rayHandle)
  return hit == 0
end

local function HelpText(s)
  SetTextFont(0); SetTextScale(0.35,0.35); SetTextColour(255,255,255,255); SetTextOutline()
  BeginTextCommandDisplayText("STRING")
  AddTextComponentSubstringPlayerName(s)
  EndTextCommandDisplayText(0.015, 0.88)
end

local function LoadAnimDict(dict) while not HasAnimDictLoaded(dict) do RequestAnimDict(dict); Wait(50) end end

local function PlayGraffitiAnimation(durationMs, onDone, onCancel)
  local ped = PlayerPedId()
  local dict = "anim@amb@business@weed@weed_inspecting_lo_med_hi@"
  local anim = "weed_spraybottle_stand_spraying_01_inspector"
  LoadAnimDict(dict)
  local can = CreateObject(`ng_proc_spraycan01b`, 0.0, 0.0, 0.0, true, false, false)
  AttachEntityToEntity(can, ped, GetPedBoneIndex(ped, 57005), 0.072, 0.041, -0.06, 33.0, 38.0, 0.0, true, true, false, true, 1, true)
  TaskPlayAnim(ped, dict, anim, 2.0, 2.0, -1, 49, 0.0, false, false, false)
  local cancelled = false
  CreateThread(function()
    local ptfxDict = "scr_recartheft"
    RequestNamedPtfxAsset(ptfxDict)
    while not HasNamedPtfxAssetLoaded(ptfxDict) do Wait(0) end
    while not cancelled do
      UseParticleFxAssetNextCall(ptfxDict)
      local pcoords = GetEntityCoords(ped) + GetEntityForwardVector(ped) * 0.5 + vector3(0,0,1.2)
      StartNetworkedParticleFxNonLoopedAtCoord("scr_wheel_burnout", pcoords.x, pcoords.y, pcoords.z, 0.0, 0.0, GetEntityHeading(ped), 0.7, 0.0, 0.0, 0.0)
      Wait(600)
    end
    RemoveNamedPtfxAsset(ptfxDict)
  end)
  if QBCore and QBCore.Functions and QBCore.Functions.Progressbar then
    QBCore.Functions.Progressbar("creating_graffiti", "Spraying...", durationMs, false, true, {
      disableMovement = true, disableCarMovement = true, disableMouse = false, disableCombat = true
    }, { animDict = dict, anim = anim, flags = 49 }, {
      model = "ng_proc_spraycan01b", bone = 57005, coords = vector3(0.072, 0.041, -0.06), rotation = vector3(33.0, 38.0, 0.0)
    }, {}, function()
      cancelled = true
      ClearPedTasks(ped); if DoesEntityExist(can) then DeleteEntity(can) end
      if onDone then onDone() end
    end, function()
      cancelled = true
      ClearPedTasks(ped); if DoesEntityExist(can) then DeleteEntity(can) end
      if onCancel then onCancel() end
    end)
  else
    CreateThread(function()
      local endAt = GetGameTimer() + durationMs
      while GetGameTimer() < endAt do
        if IsControlJustPressed(0, 73) then cancelled = true break end
        Wait(0)
      end
      ClearPedTasks(ped); if DoesEntityExist(can) then DeleteEntity(can) end
      if cancelled then if onCancel then onCancel() end else if onDone then onDone() end end
    end)
  end
end

local function DrawLogoAtPos(coords, logo, scale)
  local dict = CFG.Graffiti.logoSettings.textureDict or "shared"
  if not HasStreamedTextureDictLoaded(dict) then RequestStreamedTextureDict(dict, false) end
  SetDrawOrigin(coords.x, coords.y, coords.z, 0)
  if HasStreamedTextureDictLoaded(dict) then
    DrawSprite(dict, logo, 0.0, 0.0, scale, scale, 0.0, 255,255,255,255)
  elseif CFG.Graffiti.logoSettings.fallbackText then
    SetTextFont(4); SetTextScale(scale*2, scale*2); SetTextColour(255,255,255,255)
    SetTextEntry("STRING"); SetTextCentre(1); AddTextComponentString(logo); DrawText(0.0, -0.02)
  end
  ClearDrawOrigin()
end

local function IsWithinRenderDistance(coords)
  local ped = PlayerPedId()
  local pc = GetEntityCoords(ped)
  return #(pc - vector3(coords.x, coords.y, coords.z)) <= (CFG.Graffiti.logoSettings.renderDistance or 60.0)
end

local function tryRegisterFont(name)
  local ok = pcall(function()
    RegisterFontFile(name)
    RegisterFontId(name)
  end)
  return ok
end

local function LoadGPlayFonts()
  local loaded = {}
  for i = 1, 20 do
    local candidates = {
      ("sprayfont%d"):format(i),
      ("sprayfont_%02d"):format(i),
      ("sprayfont_%d"):format(i),
      ("sprayyfont %d"):format(i),
    }
    local face = nil
    for _, n in ipairs(candidates) do
      if tryRegisterFont(n) then face = n break end
    end
    if face then loaded[#loaded+1] = face end
  end
  if #loaded > 0 then
    FONTS = {}
    for _, face in ipairs(loaded) do
      FONTS[#FONTS+1] = { face = face, label = face }
    end
    preview.fontIndex = 1
    preview.fontFace = FONTS[1].face
  end
end

-- Cycling controls
local function FontNext()
  if #FONTS == 0 then return end
  preview.fontIndex = ((preview.fontIndex or 1) % #FONTS) + 1
  preview.fontFace = FONTS[preview.fontIndex].face
  QBCore.Functions.Notify(("Font: %s"):format(preview.fontFace), "primary", 1200)
end

local function FontPrev()
  if #FONTS == 0 then return end
  preview.fontIndex = (preview.fontIndex or 1) - 1
  if preview.fontIndex < 1 then preview.fontIndex = #FONTS end
  preview.fontFace = FONTS[preview.fontIndex].face
  QBCore.Functions.Notify(("Font: %s"):format(preview.fontFace), "primary", 1200)
end

local function ColorNext()
  preview.colorIndex = ((preview.colorIndex or 1) % #COLORS) + 1
  preview.colorHex = COLORS[preview.colorIndex].hex
  QBCore.Functions.Notify(("Color: %s"):format(COLORS[preview.colorIndex].name), "primary", 1200)
end

-- Commands and key mappings
RegisterCommand('graff_font_prev', function() if isPlacing then FontPrev() end end, false)
RegisterCommand('graff_font_next', function() if isPlacing then FontNext() end end, false)
RegisterCommand('graff_font_next_alt', function() if isPlacing then FontNext() end end, false)
RegisterCommand('graff_font_next_num', function() if isPlacing then FontNext() end end, false)

RegisterCommand('graff_color_next', function() if isPlacing then ColorNext() end end, false)

-- Default bindings (users can remap in FiveM settings)
-- Keep requested "-" and "="; also add alternatives in case "=" is unreliable on some layouts
RegisterKeyMapping('graff_font_prev', 'Graffiti Font Previous', 'keyboard', 'minus')
RegisterKeyMapping('graff_font_next', 'Graffiti Font Next', 'keyboard', 'equals')
RegisterKeyMapping('graff_font_next_alt', 'Graffiti Font Next (Alt)', 'keyboard', 'rightbracket')
RegisterKeyMapping('graff_font_next_num', 'Graffiti Font Next (Numpad +)', 'keyboard', 'NUMPADPLUS')

-- Change color cycle from C to F as requested
RegisterKeyMapping('graff_color_next', 'Graffiti Color Next', 'keyboard', 'f')

-- Draw saved graffiti
local function DrawSavedGraffiti(g)
  if not g or not g.coords then return end
  if not IsWithinRenderDistance(g.coords) then return end
  local cam = GetGameplayCamCoord()
  local coords = vector3(g.coords.x, g.coords.y, g.coords.z)
  local normal = vector3(g.surfaceNormal.x, g.surfaceNormal.y, g.surfaceNormal.z)
  local pos = coords + normal * 0.001
  if not CanSeeSpray(cam, pos) then return end

  if g.type == 'logo' and g.logo and g.logo ~= "" then
    local minS = CFG.Graffiti.logoSettings.logoScale.min
    DrawLogoAtPos(pos, g.logo, minS)
  else
    local rot = NormalToRot(normal, g.rotationOffset or 0.0)
    local face = g.fontFace or preview.fontFace or "ChaletLondon"
    local hex  = g.colorHex or preview.colorHex or "FFFFFF"
    local txt  = g.text or "GRAFFITI"
    PushScaleformText(PLAYER_NAME_HEAP[SCALEFORM_DRAW], face, hex, txt)
    DrawScaleformMovie_3dNonAdditive(PLAYER_NAME_HEAP[SCALEFORM_DRAW], pos, rot, 1.0,1.0,1.0, (g.scale or 0.60), (g.scale or 0.60), 1.0, 2)
  end
end

-- Boot
CreateThread(function()
  QBCore.Functions.TriggerCallback('cold-gangs:graffiti:GetConfig', function(serverConfig)
    if type(serverConfig)=="table" then CFG.Graffiti = serverConfig end
  end)
  local i=0 while not CFG or not CFG.Graffiti do Wait(100) i=i+1 if i>50 then break end end
  EnsureScaleformsLoaded()
  LoadGPlayFonts()
  TriggerServerEvent('cold-gangs:server:RequestGraffitis')
end)

RegisterNetEvent('cold-gangs:client:ReloadConfig', function(serverCfg)
  if type(serverCfg)=="table" then CFG.Graffiti = serverCfg end
end)

-- Main render loop
CreateThread(function()
  while true do
    local sleep = 1000
    if next(graffitis) ~= nil then
      for _, g in pairs(graffitis) do
        DrawSavedGraffiti(g)
        sleep = 0
      end
    end
    Wait(sleep)
  end
end)

-- Sync
RegisterNetEvent('cold-gangs:client:LoadGraffitis', function(serverGraffitis)
  graffitis = serverGraffitis or {}
end)

RegisterNetEvent('cold-gangs:client:AddGraffiti', function(id, data)
  graffitis[id] = data
end)

RegisterNetEvent('cold-gangs:client:RemoveGraffiti', function(id)
  graffitis[id] = nil
end)

-- Entry
RegisterNetEvent('cold-gangs:client:UseSprayCan', function(gangData, availableLogos)
  if isPlacing then return end
  local input = exports['qb-input']:ShowInput({
    header = "Graffiti Text (Leave empty for logo)",
    submitText = "Next",
    inputs = { { type='text', isRequired=false, name='text', text='Enter graffiti text (max 20)' } }
  })
  if input and input.text and input.text ~= "" then
    preview.type = 'text'
    preview.logo = nil
    preview.text = string.sub(input.text, 1, 20)
    TriggerEvent('cold-gangs:client:_BeginPlacementLocked')
  else
    local logos = availableLogos or CFG.Graffiti.availableLogos or {}
    if not logos or #logos == 0 then
      QBCore.Functions.Notify("No logos available", "error")
      return
    end
    local menu = { { header = "Select Logo", isMenuHeader = true } }
    for _, l in ipairs(logos) do
      menu[#menu+1] = { header = l:upper(), params = { event = "cold-gangs:client:_LogoPicked", args = { logo = l } } }
    end
    menu[#menu+1] = { header = "Cancel", params = { event = "qb-menu:client:closeMenu" } }
    exports['qb-menu']:openMenu(menu)
  end
end)

RegisterNetEvent('cold-gangs:client:_LogoPicked', function(data)
  if isPlacing then return end
  preview.type = 'logo'
  preview.logo = data.logo
  TriggerEvent('cold-gangs:client:_BeginPlacementLocked')
end)

-- Placement
RegisterNetEvent('cold-gangs:client:_BeginPlacementLocked', function()
  if isPlacing then return end
  isPlacing = true
  preview.nudge = vector3(0,0,0)
  preview.rotationOffset = 0.0  

  local ped = PlayerPedId()
  FreezeEntityPosition(ped, true)

  CreateThread(function()
    while isPlacing do
      Wait(0)
      -- block movement and some common actions; also block F (23) so it doesn't enter vehicles
      DisableControlAction(0,30,true); DisableControlAction(0,31,true); DisableControlAction(0,21,true)
      DisableControlAction(0,22,true); DisableControlAction(0,24,true); DisableControlAction(0,25,true)
      DisableControlAction(0,32,true); DisableControlAction(0,33,true); DisableControlAction(0,34,true); DisableControlAction(0,35,true)
      DisableControlAction(0,23,true)  -- F key (enter/exit vehicle) so color cycle won't trigger vehicle entry

      local hit, normal, fwd = FindRaycastedWall()
      if hit and normal and fwd then
        local angle = math.deg(math.acos(math.abs(normal.z)))
        if angle < (CFG.Graffiti.minSurfaceAngle or 75.0) then
          HelpText("Surface not suitable")
        else
          local pos = hit + normal * 0.001 + preview.nudge
          local rot = NormalToRot(normal) -- stable (no flicker)
          if preview.type == 'logo' and preview.logo then
            local minS = CFG.Graffiti.logoSettings.logoScale.min
            local maxS = CFG.Graffiti.logoSettings.logoScale.max
            DrawLogoAtPos(pos, preview.logo, clamp(preview.scale, minS, maxS))
          else
	    local rot = NormalToRot(normal, preview.rotationOffset)
            PushScaleformText(PLAYER_NAME_HEAP[SCALEFORM_PREVIEW], preview.fontFace or "ChaletLondon", preview.colorHex or "FFFFFF", preview.text or "GRAFFITI")
            DrawScaleformMovie_3dNonAdditive(PLAYER_NAME_HEAP[SCALEFORM_PREVIEW], pos, rot, 1.0,1.0,1.0, preview.scale, preview.scale, 1.0, 2)
          end
          HelpText("G Confirm | X Cancel | Arrows Nudge | PgUp/PgDn Scale | Q/E Rotate | - Font | F Color")
        end
      else
        HelpText("Aim at a wall within ~3.5m")
      end

      -- Nudge + Scale
      if IsControlJustPressed(0, 172) then preview.nudge = preview.nudge + vector3(0,0,0.01)
      elseif IsControlJustPressed(0, 173) then preview.nudge = preview.nudge - vector3(0,0,0.01)
      elseif IsControlJustPressed(0, 174) then preview.nudge = preview.nudge - vector3(0.01,0,0)
      elseif IsControlJustPressed(0, 175) then preview.nudge = preview.nudge + vector3(0.01,0,0)
      elseif IsControlPressed(0, 10) then preview.scale = clamp(preview.scale + 0.05, 0.10, 1.50)
      elseif IsControlPressed(0, 11) then preview.scale = clamp(preview.scale - 0.05, 0.10, 1.50)
elseif IsControlPressed(0, 44) then  -- Q key - rotate counter-clockwise
  preview.rotationOffset = preview.rotationOffset - 2.0
  if preview.rotationOffset < -180.0 then preview.rotationOffset = preview.rotationOffset + 360.0 end
elseif IsControlPressed(0, 38) then  -- E key - rotate clockwise
  preview.rotationOffset = preview.rotationOffset + 2.0
  if preview.rotationOffset > 180.0 then preview.rotationOffset = preview.rotationOffset - 360.0 end

      -- Cycle color (mapped to F) and fonts (- /= via commands; plus fallbacks if needed)
      elseif IsDisabledControlJustPressed(0, 23) then ColorNext()   -- F
      elseif IsControlJustPressed(0, 84) then FontPrev()           -- fallback '-' (some layouts)
      elseif IsControlJustPressed(0, 85) then FontNext()           -- fallback '=' (may not work on all layouts)

      -- Confirm / Cancel
      elseif IsControlJustPressed(0, 47) then
        local finalHit, finalNormal = FindRaycastedWall()
        if not finalHit or not finalNormal then
          QBCore.Functions.Notify("Aim at a wall within ~3.5m", "error")
        else
          local finalPos = finalHit + finalNormal * 0.001
          local payload = {
            coords = { x = finalPos.x, y = finalPos.y, z = finalPos.z },
            rotation = { x = 0.0, y = 0.0, z = 0.0 },
            surfaceNormal = { x = finalNormal.x, y = finalNormal.y, z = finalNormal.z },
            type = preview.type,
            text = (preview.type == 'text') and preview.text or nil,
            logo = (preview.type == 'logo') and preview.logo or nil,
            fontFace = preview.fontFace,
            colorHex = preview.colorHex,
            scale = preview.scale,
            rotationOffset = preview.rotationOffset
          }
          PlayGraffitiAnimation((CFG.Graffiti.sprayDuration or 7000), function()
            TriggerServerEvent('cold-gangs:server:CreateGraffiti', payload)
            FreezeEntityPosition(ped, false)
            isPlacing = false
          end, function()
            QBCore.Functions.Notify("Spray cancelled", "error")
            FreezeEntityPosition(ped, false)
            isPlacing = false
          end)
        end
      elseif IsControlJustPressed(0, 73) then
        FreezeEntityPosition(ped, false)
        isPlacing = false
        QBCore.Functions.Notify("Cancelled", "error")
      end
    end
  end)
end)

-- Remover/Admin
RegisterNetEvent('cold-gangs:client:UsePaintRemover', function()
  local ped = PlayerPedId()
  local pc = GetEntityCoords(ped)
  local closestId, closestDist = nil, 1e9
  local maxd = CFG.Graffiti.maxDistance or 2.5
  for id, g in pairs(graffitis) do
    local c = vector3(g.coords.x,g.coords.y,g.coords.z)
    local d = #(pc - c)
    if d < closestDist and d <= maxd then closestDist, closestId = d, id end
  end
  if not closestId then QBCore.Functions.Notify("No graffiti nearby to remove", "error") return end
  TriggerServerEvent('cold-gangs:server:RemoveGraffiti', closestId)
end)

RegisterNetEvent('cold-gangs:client:AdminRemoveGraffiti', function()
  local ped = PlayerPedId()
  local pc = GetEntityCoords(ped)
  local closestId, closestDist = nil, 1e9
  for id, g in pairs(graffitis) do
    local c = vector3(g.coords.x,g.coords.y,g.coords.z)
    local d = #(pc - c)
    if d < closestDist and d <= 10.0 then closestDist, closestId = d, id end
  end
  if closestId then TriggerServerEvent('cold-gangs:server:RemoveGraffiti', closestId) else QBCore.Functions.Notify("No graffiti nearby", "error") end
end)

-- Utility
RegisterCommand('refreshgraffiti', function()
  TriggerServerEvent('cold-gangs:server:RequestGraffitis')
  QBCore.Functions.Notify("Refreshing graffitis...", "primary")
end, false)

exports('GetGraffitis', function() return graffitis end)
exports('IsCreatingGraffiti', function() return isPlacing end)

CreateThread(function()
  EnsureScaleformsLoaded()
end)
