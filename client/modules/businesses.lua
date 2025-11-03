local QBCore = exports['qb-core']:GetCoreObject()

local PlayerData, PlayerGang = nil, nil
local isLoggedIn = false
local Fronts = {}
local Blips = {}

local function HasManagePerm()
  if not PlayerGang then return false end
  if PlayerGang.isLeader then return true end
  return exports['cold-gangs']:HasGangPermission('manageBusinesses')
end

local function ClearFrontBlips()
  for _, b in pairs(Blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
  Blips = {}
end

local function CreateFrontBlips()
  ClearFrontBlips()
  for id, f in pairs(Fronts) do
    if f.location and f.location.x and f.location.y then
      local b = AddBlipForCoord(f.location.x + 0.0, f.location.y + 0.0, (f.location.z or 0.0) + 0.0)
      SetBlipSprite(b, 605)
      SetBlipScale(b, 0.7)
      SetBlipColour(b, 2)
      SetBlipAsShortRange(b, true)
      BeginTextCommandSetBlipName("STRING")
      AddTextComponentString(("%s (Front)"):format(f.label or f.ref))
      EndTextCommandSetBlipName(b)
      Blips[id] = b
    end
  end
end

RegisterNetEvent('cold-gangs:client:FrontsSync', function(payload)
  Fronts = payload or {}
  CreateFrontBlips()
end)

CreateThread(function()
  while not QBCore.Functions.GetPlayerData() do Wait(100) end
  isLoggedIn = true
  PlayerData = QBCore.Functions.GetPlayerData()
  QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(g) PlayerGang = g end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
  isLoggedIn = true
  PlayerData = QBCore.Functions.GetPlayerData()
  QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(g) PlayerGang = g end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
  isLoggedIn = false
  PlayerData, PlayerGang = nil, nil
  Fronts = {}
  ClearFrontBlips()
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(_)
  QBCore.Functions.TriggerCallback('cold-gangs:server:GetPlayerGang', function(g)
    PlayerGang = g
  end)
end)

local function Draw3DText(x, y, z, text)
  local on, _x, _y = World3dToScreen2d(x,y,z)
  local cam = GetGameplayCamCoords()
  local dist = #(vector3(cam.x,cam.y,cam.z) - vector3(x,y,z))
  if on and dist < 50.0 then
    local scale = (1/dist) * 2.0 * ((1/GetGameplayCamFov()) * 100.0)
    SetTextScale(0.35*scale, 0.35*scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255,255,255,215)
    SetTextCentre(1)
    BeginTextCommandDisplayText("STRING")
    AddTextComponentString(text)
    EndTextCommandDisplayText(_x,_y)
  end
end

CreateThread(function()
  while true do
    Wait(0)
    if not isLoggedIn or not PlayerGang then Wait(750) goto continue end
    local ped = PlayerPedId()
    local pc = GetEntityCoords(ped)
    local sleeping = true
    for id, f in pairs(Fronts) do
      if tonumber(f.gangId) == tonumber(PlayerGang and PlayerGang.id or -1) then
        local loc = f.location
        if loc and loc.x and loc.y then
          local d = #(pc - vector3(loc.x + 0.0, loc.y + 0.0, (loc.z or 0.0) + 0.0))
          if d < 10.0 then
            sleeping = false
            Draw3DText(loc.x, loc.y, (loc.z or 0.0) + 1.0, ("%s (Front)\nHeat: %d"):format(f.label or f.ref, f.heat or 0))
            if d < 2.0 then
              Draw3DText(loc.x, loc.y, (loc.z or 0.0) + 0.5, "Press [E] to manage front")
              if IsControlJustPressed(0, 38) then
                TriggerEvent('cold-gangs:client:OpenFrontMenu', id)
              end
            end
          end
        end
      end
    end
    if sleeping then Wait(800) end
    ::continue::
  end
end)

RegisterNetEvent('cold-gangs:client:OpenFrontMenu', function(frontId)
  local id = tonumber(frontId)
  QBCore.Functions.TriggerCallback('cold-gangs:fronts:GetStatus', function(data)
    if not data or not data.front then QBCore.Functions.Notify("Front not found", "error") return end
    local f, p = data.front, data.pool
    local menu = {
      { header = ("%s (ref: %s)"):format(f.label, f.ref), isMenuHeader = true },
      { header = "Status", txt = ("Pool: $%d | Today: $%d | Rate: %d%% | Fee: %d%% | Cap: $%d"):format(
          p.dirty_value or 0, p.processed_today or 0, math.floor((f.rate or 0)*100), math.floor((f.fee or 0)*100), f.cap or 0
        ), isMenuHeader = true
      },
      { header = "Deposit Dirty (Marked Bills)", txt = "Convert marked bills to pool", params = { event = "cold-gangs:client:DepositDirtyPrompt", args = { id = id } } },
    }
    if HasManagePerm() then
      table.insert(menu, { header = "Manage Illegal Catalog", txt = "Add/Update items & stock", params = { event = "cold-gangs:client:FrontCatalogMenu", args = { id = id } } })
    end
    table.insert(menu, { header = "← Close", params = { event = "qb-menu:client:closeMenu" } })
    exports['qb-menu']:openMenu(menu)
  end, id)
end)

RegisterNetEvent('cold-gangs:client:DepositDirtyPrompt', function(data)
  local id = data.id
  local dialog = exports['qb-input']:ShowInput({
    header = "Deposit Marked Bills",
    submitText = "Deposit",
    inputs = { { text = "Amount ($)", name = "amount", type = "number", isRequired = true } }
  })
  if dialog and dialog.amount then
    local amt = tonumber(dialog.amount) or 0
    if amt > 0 then
      TriggerServerEvent('cold-gangs:fronts:DepositDirty', id, amt)
    else
      QBCore.Functions.Notify("Invalid amount", "error")
    end
  end
end)

RegisterNetEvent('cold-gangs:client:FrontCatalogMenu', function(data)
  local id = data.id
  QBCore.Functions.TriggerCallback('cold-gangs:fronts:GetStatus', function(res)
    if not res or not res.front then return end
    local list = res.illegal or {}
    local menu = { { header = "Illegal Catalog", isMenuHeader = true } }
    for _, row in ipairs(list) do
      table.insert(menu, {
        header = ("%s | $%d | %d/%d"):format(row.item, row.price, row.stock, row.max_stock),
        txt = row.visible and "Visible" or "Hidden",
        params = { event = "cold-gangs:client:EditFrontItem", args = { id=id, row=row } }
      })
    end
    table.insert(menu, { header = "Add New Item", params = { event = "cold-gangs:client:AddFrontItem", args = { id=id } } })
    table.insert(menu, { header = "← Back", params = { event = "cold-gangs:client:OpenFrontMenu", args = id } })
    exports['qb-menu']:openMenu(menu)
  end, id)
end)

RegisterNetEvent('cold-gangs:client:AddFrontItem', function(data)
  local id = data.id
  local dialog = exports['qb-input']:ShowInput({
    header = "Add Illegal Item",
    submitText = "Save",
    inputs = {
      { text = "Item name", name = "item", type = "text", isRequired = true },
      { text = "Price", name = "price", type = "number", isRequired = true },
      { text = "Stock", name = "stock", type = "number", isRequired = true },
      { text = "Max Stock", name = "max_stock", type = "number", isRequired = false },
      { text = "Visible (1=Yes, 0=No)", name = "visible", type = "number", isRequired = true }
    }
  })
  if not dialog or not dialog.item then return end
  QBCore.Functions.TriggerCallback('cold-gangs:fronts:GetStatus', function(res)
    local list = res and res.illegal or {}
    table.insert(list, {
      item = dialog.item,
      price = tonumber(dialog.price) or 0,
      stock = tonumber(dialog.stock) or 0,
      max_stock = tonumber(dialog.max_stock) or tonumber(dialog.stock) or 0,
      visible = tonumber(dialog.visible) == 1
    })
    QBCore.Functions.TriggerCallback('cold-gangs:fronts:SetCatalog', function(ok)
      if ok then QBCore.Functions.Notify("Catalog updated", "success") else QBCore.Functions.Notify("Failed to update catalog", "error") end
    end, id, list)
  end, id)
end)

RegisterNetEvent('cold-gangs:client:EditFrontItem', function(data)
  local id, row = data.id, data.row
  local dialog = exports['qb-input']:ShowInput({
    header = ("Edit %s"):format(row.item),
    submitText = "Save",
    inputs = {
      { text = "Price", name = "price", type = "number", default = tostring(row.price), isRequired = true },
      { text = "Stock", name = "stock", type = "number", default = tostring(row.stock), isRequired = true },
      { text = "Max Stock", name = "max_stock", type = "number", default = tostring(row.max_stock), isRequired = false },
      { text = "Visible (1=Yes, 0=No)", name = "visible", type = "number", default = row.visible and "1" or "0", isRequired = true }
    }
  })
  if not dialog then return end
  QBCore.Functions.TriggerCallback('cold-gangs:fronts:GetStatus', function(res)
    local list = res and res.illegal or {}
    local newList = {}
    for _, r in ipairs(list) do
      if r.item == row.item then
        newList[#newList+1] = {
          item = row.item,
          price = tonumber(dialog.price) or row.price,
          stock = tonumber(dialog.stock) or row.stock,
          max_stock = tonumber(dialog.max_stock) or row.max_stock,
          visible = tonumber(dialog.visible) == 1
        }
      else
        newList[#newList+1] = r
      end
    end
    QBCore.Functions.TriggerCallback('cold-gangs:fronts:SetCatalog', function(ok)
      if ok then QBCore.Functions.Notify("Catalog updated", "success") else QBCore.Functions.Notify("Failed to update catalog", "error") end
    end, id, newList)
  end, id)
end)

RegisterNetEvent('cold-gangs:client:FrontAssignAtCoords', function(args)
  local c = GetEntityCoords(PlayerPedId())
  local loc = { x = c.x, y = c.y, z = c.z }
  QBCore.Functions.TriggerCallback('cold-gangs:fronts:AdminAssign', function(ok, msg)
    if ok then QBCore.Functions.Notify("Front assigned", "success") else QBCore.Functions.Notify(msg or "Failed", "error") end
  end, tonumber(args.gangId), args.ref, args.label, loc, nil, nil, nil)
end)

RegisterCommand('frontsrefresh', function()
  QBCore.Functions.TriggerCallback('cold-gangs:fronts:GetList', function(list)
    QBCore.Functions.Notify(("You have %d fronts"):format(#(list or {})), "primary")
  end)
end, false)
