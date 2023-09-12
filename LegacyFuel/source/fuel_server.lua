local QBCore = exports['qb-core']:GetCoreObject()

local function round(value, numDecimalPlaces)
	return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", value))
end

RegisterNetEvent('fuel:pay', function(price, station, removefuel)
	local src = source
	local pData = QBCore.Functions.GetPlayer(src)
	local amount = round(price)
	if pData then
    	pData.Functions.RemoveMoney('cash', amount, "bought-fuel")

		if station then
			exports['wert-fuelstations']:AddMoneyStation(station, amount)
			exports['wert-fuelstations']:RemoveFuelStation(station, removefuel)
		end
	end
end)

RegisterNetEvent('fuel:delete-nozzle', function(veh)
	TriggerClientEvent("wert-fuel:delete-nozzle", -1, veh)
end)