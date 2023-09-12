local QBCore = exports['qb-core']:GetCoreObject()

local isNearPump = false
local isFueling = false
local currentFuel = 0.0
local currentCost = 0.0
local currentCash = 1000
local fuelSynced = false
local inBlacklisted = false
local PreviousVehicleEngine = nil
local nozzle = nil
local rope = nil
local aktifblipler = {}
local blip = false
local cancelpump = nil
local cancelvehicle = nil

local function LoadAnimDict(dict)
	if not HasAnimDictLoaded(dict) then
		RequestAnimDict(dict)
		while not HasAnimDictLoaded(dict) do
			Wait(1)
		end
	end
end

local function Round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

function aktifblip()
	for i=1, #Config.GasStations do
		local blip = AddBlipForCoord(Config.GasStations[i])
		SetBlipSprite(blip, 361)
		SetBlipScale(blip, 0.5)
		SetBlipColour(blip, 60)
		SetBlipDisplay(blip, 4)
		SetBlipAsShortRange(blip, true)

		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString("Gas Station")
		EndTextCommandSetBlipName(blip)
		table.insert(aktifblipler, blip)
	end
end

function pasifblip()
	for i=1, #aktifblipler do
		RemoveBlip(aktifblipler[i])
	end
	aktifblipler = {}
end

function SetFuel(vehicle, fuel)
	if type(fuel) == 'number' and fuel >= 0 and fuel <= 100 then
		SetVehicleFuelLevel(vehicle, fuel + 0.0)
		DecorSetFloat(vehicle, Config.FuelDecor, GetVehicleFuelLevel(vehicle))
	end
end

function GetFuel(vehicle)
	return DecorGetFloat(vehicle, Config.FuelDecor)
end

function ManageFuelUsage(vehicle)
	if not DecorExistOn(vehicle, Config.FuelDecor) then
		SetFuel(vehicle, math.random(200, 800) / 10)
	elseif not fuelSynced then
		SetFuel(vehicle, GetFuel(vehicle))
		fuelSynced = true
	end
	if IsVehicleEngineOn(vehicle) then
		SetFuel(vehicle, GetVehicleFuelLevel(vehicle) - Config.FuelUsage[Round(GetVehicleCurrentRpm(vehicle), 1)] * (Config.Classes[GetVehicleClass(vehicle)] or 1.0) / 10)
	end
end

-- Events

AddEventHandler('fuel:startFuelUpTick', function(pumpObject, ped, vehicle, data)
	currentFuel = GetVehicleFuelLevel(vehicle)
	local add_fuel_amount = 0
	local station_fuel = data.station_fuel
	local literprice = data.literprice
	while isFueling do
		Wait(500)
		local oldFuel = DecorGetFloat(vehicle, Config.FuelDecor)
		local fuelToAdd = math.random(10, 20) / 10.0
		local extraCost = fuelToAdd / 1.6
		if station_fuel and literprice then
			extraCost = literprice / 1.6
		end 
		if not pumpObject then
			if GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100 >= 0 then
				currentFuel = oldFuel + fuelToAdd
				SetPedAmmo(ped, 883325847, math.floor(GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100))
			else
				isFueling = false
				SendNUIMessage({
					type = "status",
					status = false
				})
				TriggerServerEvent('fuel:delete-nozzle', VehToNet(vehicle))
			end
		else
			currentFuel = oldFuel + fuelToAdd
			add_fuel_amount = add_fuel_amount + fuelToAdd
		end

		if currentFuel > 100.0 then
			currentFuel = 100.0
			isFueling = false
			TriggerServerEvent('fuel:delete-nozzle', VehToNet(vehicle))
    		RopeUnloadTextures()
    		DeleteRope(rope)
			SendNUIMessage({
				type = "status",
				status = false
			})
		end

		currentCost = currentCost + extraCost

		if station_fuel then
			if station_fuel >= add_fuel_amount and currentCash >= currentCost then
				SetFuel(vehicle, currentFuel)
			else
				isFueling = false
				TriggerServerEvent('fuel:delete-nozzle', VehToNet(vehicle))
				RopeUnloadTextures()
				DeleteRope(rope)
				SendNUIMessage({
					type = "status",
					status = false
				})
			end
		else
			if currentCash >= currentCost then
				SetFuel(vehicle, currentFuel)
			else
				isFueling = false
				TriggerServerEvent('fuel:delete-nozzle', VehToNet(vehicle))
				RopeUnloadTextures()
				DeleteRope(rope)
				SendNUIMessage({
					type = "status",
					status = false
				})
			end
		end
	end


	local GetCurrentStation = exports['wert-fuelstations']:CurrentFuelStation()
	TriggerServerEvent('fuel:pay', currentCost, GetCurrentStation, add_fuel_amount)

	currentCost = 0.0
end)

AddEventHandler('fuel:refuelFromPump', function(pumpObject, ped, vehicle, data)
	TaskTurnPedToFaceEntity(ped, vehicle, 1000)
	Wait(250)
	SetCurrentPedWeapon(ped, -1569615261, true)
	LoadAnimDict("timetable@gardener@filling_can")
	TaskPlayAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
	TriggerEvent('fuel:startFuelUpTick', pumpObject, ped, vehicle, data)
	cancelpump = pumpObject
	cancelvehicle = vehicle
	--Mert ekleme
	nozzle = CreateObject(`prop_cs_fuel_nozle`, 0, 0, 0, true, true, true)
	
	local isBike = false
	local tankBone = nil
	local vehClass = GetVehicleClass(vehicle)
	local testcoord = GetEntityCoords(pumpObject)
                
    if vehClass == 8 and vehClass ~= 13 then
        tankBone = GetEntityBoneIndexByName(vehicle, "petroltank")
        if tankBone == -1 then
            tankBone = GetEntityBoneIndexByName(vehicle, "engine")
        end
        isBike = true
    elseif vehClass ~= 13 then
        tankBone = GetEntityBoneIndexByName(vehicle, "petroltank_l")
        if tankBone == -1 then
            tankBone = GetEntityBoneIndexByName(vehicle, "hub_lr")
        end
    end
	if isBike then
        AttachEntityToEntity(nozzle, vehicle, tankBone, 0.0, -0.2, 0.2, -80.0, 0.0, 0.0, true, true, false, false, 1, true)
    else
        AttachEntityToEntity(nozzle, vehicle, tankBone, -0.23, 0.0, 0.6, -125.0, -90.0, -90.0, true, true, false, false, 1, true)
    end
	RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Wait(0)
    end
	RopeLoadTextures()
    while not testcoord do
        Wait(0)
    end
    rope = AddRope(testcoord.x, testcoord.y, testcoord.z, 0.0, 0.0, 0.0, 3.0, 1, 1000.0, 0.0, 1.0, false, false, false, 1.0, true)
    while not rope do
        Wait(0)
    end
    ActivatePhysics(rope)
    local nozzlePos = GetEntityCoords(nozzle)
    nozzlePos = GetOffsetFromEntityInWorldCoords(nozzle, 0.0, -0.033, -0.195)
    AttachEntitiesToRope(rope, pumpObject, nozzle, testcoord.x, testcoord.y, testcoord.z + 1.45, nozzlePos.x, nozzlePos.y, nozzlePos.z, 5.0, false, false, nil, nil)

	SendNUIMessage({
        type = "status",
        status = true
    })
    SendNUIMessage({
        type = "update",
        fuelCost = "0.00",
        fuelTank = "0.00"
    })

	while isFueling do
		Wait(1)
		for k,v in pairs(Config.DisableKeys) do
			DisableControlAction(0, v)
		end
		local vehicleCoords = GetEntityCoords(vehicle)
		if pumpObject then
			SendNUIMessage({
				type = "update",
				fuelCost = string.format("%.2f", Round(currentCost, 1)),
				fuelTank = string.format("%.2f", Round(currentFuel, 1))
			})
		end
		if not IsEntityPlayingAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 3) then
			TaskPlayAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
		end
	end
	ClearPedTasks(ped)
	RemoveAnimDict("timetable@gardener@filling_can")
end)

RegisterNetEvent("yakitdoldur", function(pompentity)
	local GetCurrentStation = exports['wert-fuelstations']:CurrentFuelStation()
	local GetSellingStations = exports['wert-fuelstations']:SellingStations()
	QBCore.Functions.TriggerCallback('wert-fuelstations:server:get-station-all-data', function(result)
		if GetCurrentStation then
			if result and result.status > 0 then
				if not GetSellingStations[GetCurrentStation] or result.fuel > 0 then
					local ped = PlayerPedId()
					if not isFueling and ((GetEntityHealth(pompentity) > 0) or (GetSelectedPedWeapon(ped) == 883325847)) then
						if IsPedInAnyVehicle(ped) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped), -1) == ped then
							QBCore.Functions.Notify("You must be outside the vehicle", "error")
						else
							local vehicle = GetVehiclePedIsIn(GetPlayerPed(-1), true)
							local vehicleCoords = GetEntityCoords(vehicle)
							if DoesEntityExist(vehicle) and GetDistanceBetweenCoords(GetEntityCoords(ped), vehicleCoords) < 2.5 then
								if not DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) then
									local stringCoords = GetEntityCoords(pompentity)
									local canFuel = true
									if GetSelectedPedWeapon(ped) == 883325847 then
										stringCoords = vehicleCoords
										if GetAmmoInPedWeapon(ped, 883325847) < 100 then
											canFuel = false
										end
									end
									if GetVehicleFuelLevel(vehicle) < 95 and canFuel then
										currentCash = QBCore.Functions.GetPlayerData().money.cash
										if currentCash > 0 then
											isFueling = true
											PreviousVehicleEngine = GetVehicleEngineHealth(vehicle)
											TriggerEvent('fuel:refuelFromPump', pompentity, ped, vehicle, {station_fuel = result.fuel, literprice = result.price})
											LoadAnimDict("timetable@gardener@filling_can")
										else
											QBCore.Functions.Notify("You don't have enough money", "error")
										end
									else
										QBCore.Functions.Notify("The vehicle's tank is full", "error")
									end
								end
							end
						end
					end
				else
					QBCore.Functions.Notify('There is no fuel at the station!', 'error')
				end
			else
				QBCore.Functions.Notify('No fuel is sold at this station!', 'error')
			end
		else
			local ped = PlayerPedId()
			if not isFueling and ((GetEntityHealth(pompentity) > 0) or (GetSelectedPedWeapon(ped) == 883325847)) then
				if IsPedInAnyVehicle(ped) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped), -1) == ped then
					QBCore.Functions.Notify("You must be outside the vehicle", "error")
				else
					local vehicle = GetVehiclePedIsIn(GetPlayerPed(-1), true)
					local vehicleCoords = GetEntityCoords(vehicle)
					if DoesEntityExist(vehicle) and GetDistanceBetweenCoords(GetEntityCoords(ped), vehicleCoords) < 2.5 then
						if not DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) then
							local stringCoords = GetEntityCoords(pompentity)
							local canFuel = true
							if GetSelectedPedWeapon(ped) == 883325847 then
								stringCoords = vehicleCoords
								if GetAmmoInPedWeapon(ped, 883325847) < 100 then
									canFuel = false
								end
							end
							if GetVehicleFuelLevel(vehicle) < 95 and canFuel then
								currentCash = QBCore.Functions.GetPlayerData().money.cash
								if currentCash > 0 then
									isFueling = true
									PreviousVehicleEngine = GetVehicleEngineHealth(vehicle)
									TriggerEvent('fuel:refuelFromPump', pompentity, ped, vehicle, {station_fuel = nil, literprice = nil})
									LoadAnimDict("timetable@gardener@filling_can")
								else
									QBCore.Functions.Notify("You don't have enough money", "error")
								end
							else
								QBCore.Functions.Notify("The vehicle's tank is full", "error")
							end
						end
					end
				end
			end
		end
	end, GetCurrentStation)
end)

RegisterNetEvent('hud:client:OnMoneyChange', function()
    currentCash = QBCore.Functions.GetPlayerData().money['cash']
end)

RegisterNetEvent("LegacyFuel:blipAcKapa", function()
	if blip then
		pasifblip()
		blip = false
	else
		aktifblip()
		blip = true
	end
end)

RegisterNetEvent("wert-fuel:delete-nozzle", function(sss)
	local veh = NetToEnt(sss)
	local nozzlehash = GetHashKey("prop_cs_fuel_nozle")
	if veh and veh ~= 0 then
		for k, v in pairs(GetGamePool('CObject')) do
			if GetEntityModel(v) == nozzlehash and IsEntityAttachedToEntity(veh, v) then
				SetEntityAsMissionEntity(v, true, true)
				DeleteObject(v)
				DeleteEntity(v)
			end
		end
	end
end)

RegisterNetEvent("wert-fuel:client:iptal", function()
	if DoesEntityExist(cancelvehicle) then
		isFueling = false
		TriggerServerEvent('fuel:delete-nozzle', VehToNet(cancelvehicle))
		RopeUnloadTextures()
		DeleteRope(rope)
		SendNUIMessage({
			type = "status",
			status = false
		})
		if PreviousVehicleEngine then
			SetVehicleEngineHealth(cancelvehicle, PreviousVehicleEngine)
			PreviousVehicleEngine = nil
		end
		cancelpump = nil
		cancelvehicle = nil
	end
end)

-- Threads

CreateThread(function()
	DecorRegister(Config.FuelDecor, 1)
	for i = 1, #Config.Blacklist do
		if type(Config.Blacklist[i]) == 'string' then
			Config.Blacklist[GetHashKey(Config.Blacklist[i])] = true
		else
			Config.Blacklist[Config.Blacklist[i]] = true
		end
	end
	for i = #Config.Blacklist, 1, -1 do
		table.remove(Config.Blacklist, i)
	end
	local pompalar = {
		-2007231801,
		1339433404,
		1694452750,
		1933174915,
		-462817101,
		-469694731,
		-164877493
	}
	exports["qb-target"]:AddTargetModel(pompalar, {
        options = {
            {
                icon = "fas fa-gas-pump",
                label = "Fill Fuel",
				action = function(entity)
					TriggerEvent("yakitdoldur", entity)
				end,
				canInteract = function()
					if not isFueling then
						return true
					end
					return false
				end,
            },
			{
				icon = "fa-solid fa-xmark",
				label = "Cancel the filling process",
				event = "wert-fuel:client:iptal",
				canInteract = function()
					if isFueling and cancelpump then
						return true
					end
					return false
				end,
			},
        },
        distance = 1.5
    })
	while true do
		Wait(1000)
		local ped = PlayerPedId()
		if IsPedInAnyVehicle(ped) then
			local vehicle = GetVehiclePedIsIn(ped)
			if Config.Blacklist[GetEntityModel(vehicle)] then
				inBlacklisted = true
			else
				inBlacklisted = false
			end
			if not inBlacklisted and GetPedInVehicleSeat(vehicle, -1) == ped then
				ManageFuelUsage(vehicle)
			end
		else
			if fuelSynced then
				fuelSynced = false
			end
			if inBlacklisted then
				inBlacklisted = false
			end
		end
	end
end)