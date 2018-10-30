require 'config'

runner = nil -- global timer object used to read dht sensor

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

-- makes JSON payload from temp, humi & lux and sends it to endpoint
local function sendJSON(temp, humi, lux)
	local payload = "{\"temp\":"..temp..",\"humi\":"..humi..",\"lux\":"..lux.."}"

	if id_debug then
		print("Sending payload: "..payload)
	end

	http.post(endpoint, nil, payload, function(code, body)
		if is_debug then
			print("Got response from server")
			print("Code: "..code)
			print("Body: "..body)
		end
		return true
	end)
end

-- start timer based main loop
local function start()
	if runner ~= nil then
		runner:start()
		return nil
	end

	runner = tmr.create()
	runner:alarm(interval, tmr.ALARM_AUTO, function()
		status, i_temp, i_humi, d_temp, d_humi = dht.read11(dht_pin)

		if status ~= dht.OK then
			if id_debug then
				print('Failed to read DHT sensor: ', status)
			end
			return nil
		end

		-- bh1750 (gy-302) light sensor
		-- make sure it's connected to 3.3v
		id = 0
		i2c.setup(id, lux_sda_pin, lux_sci_pin, i2c.SLOW)
		i2c.start(id)

		-- by default, bh1750 is assigned to 0x23 address.
		-- if some other component is already assigned to that address,
		-- connect bh1750 addr pin to 3.3v and change 0x23 to 0x5C.
		i2c.address(id, 0x23, i2c.TRANSMITTER)

		-- with different modes, we can measure between 0.11 lx to 100 000 lx.
		-- name, resolution, measurement time, payload
		-- cont. h-res mode    1lx    120ms  0x10  (for dark)
		-- cont. h-res mode2   0.5lx  120ms  0x11
		-- cont. l-res mode    4lx     16ms  0x13  (for daylight)
		-- 1 time h-res mode   1lx    120ms  0x20  
		-- 1 time h-res mode2  0.5lx  120ms  0x21
		-- 1 time l-res mode   4lx     16ms  0x23
		i2c.write(id, 0x10)
		i2c.stop(id)
		i2c.start(id)
		
		-- read from sensor address
		i2c.address(id, 0x23, i2c.RECEIVER)

		-- wait 200ms
		if not tmr.create():alarm(200, tmr.ALARM_SINGLE, function()
			raw = i2c.read(id, 2)
			i2c.stop(id)

			lux_raw = raw:byte(1) * 256 + raw:byte(2)
			lux = (lux_raw * 1000 / 12) / 100

			if supports_float then
				sendJSON(d_temp, d_humi, lux)
			else
				sendJSON(i_temp, i_humi, lux)
			end
		end) then
			if supports_float then
				sendJSON(d_temp, d_humi, 0)
			else
				sendJSON(i_temp, i_humi, 0)
			end
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
	if is_debug then
		print("Connected to wifi")
		table.foreach(info, inspect)
	end
end

local function onWifiDisconnected(info)
	if is_debug then
		print("Disconnected from wifi")
		table.foreach(info, inspect)
	end
	stop()
end

local function onWifiGotIp(info)
	if is_debug then
		print("Got IP")
		table.foreach(info, inspect)
	end
	start()
end

wifi.setmode(wifi.STATION)

-- use low range, slow, less power hungry mode
wifi.setphymode(wifi.PHYMODE_N)

-- wifi config, this will survive restart
wifi.sta.config({
	ssid=wifi_ssid,
	pwd=wifi_pwd,
	auto=true,
	save=true,
	connected_cb=onWifiConnected,
	disconnected_cb=onWifiDisconnected,
	got_ip_cb=onWifiGotIp,
})
