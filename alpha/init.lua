runner = nil -- global timer object used to read dht sensor
dht_pin = 4
endpoint = "http://192.168.1.122:6060/node1" -- endpoint where to send data
supports_float = false -- if supported, will send float values instead of integers

-- for debugging. allows to print tables
-- usage: table.foreach(object_to_look_at, inspect)
local function inspect(key, value)
	local prefix = name
	local out = prefix and prefix..".%s" or "%s"
	if type(value) == "table" then
		name = prefix.."."..key
		table.foreach(value, inspect)
		name = prefix
	else
		out = type(value) == "function" and out.."()" or out.." = %s"
		print(out:format(key, tostring(value)))
	end
end

-- makes JSON payload from temp and humi and sends it to endpoint
local function sendJSON(temp, humi)
	local payload = "{\"temp\":"..temp..",\"humi\":"..humi.."}"
	http.post(endpoint, nil, payload, function(code, body)
		print("Got response from server")
		print("Code: "..code)
		print("Body: "..body)
	end)
end

-- start dht sensor alarm runner
local function start()
	if runner ~= nil then
		runner:start()
		return nil
	end

	runner = tmr.create()
	runner:alarm(1000, tmr.ALARM_AUTO, function()
		status, i_temp, i_humi, d_temp, d_humi = dht.read11(dht_pin)

		if (status ~= dht.OK) then
			print('Failed to read sensor: ', status)
			return nil
		end

		if supports_float then
			sendJSON(d_temp, d_humi)
		else
			sendJSON(i_temp, i_humi)
		end
	end)
end

-- stop dht sensor runner
local function stop()
	if runner ~= nil then
		runner:stop()
	end
end

local function onWifiConnected(info)
	print("Connected to wifi")
	table.foreach(info, inspect)
end

local function onWifiDisconnected(info)
	print("Disconnected from wifi")
	table.foreach(info, inspect)
	stop()
end

local function onWifiGotIp(info)
	print("Got IP")
	table.foreach(info, inspect)
	start()
end

-- use low range, slow, less power hungry mode
wifi.setphymode(wifi.PHYMODE_N)

-- wifi config, this will survive restart
wifi.sta.config({
	ssid="Telia-AAF302",
	pwd="5L6PFN3WDIXMUJ",
	auto=true,
	save=true,
	connected_cb=onWifiConnected,
	disconnected_cb=onWifiDisconnected,
	got_ip_cb=onWifiGotIp,
})
