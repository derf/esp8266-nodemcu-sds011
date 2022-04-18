station_cfg = {}
dofile("config.lua")

delayed_restart = tmr.create()
chipid = node.chipid()
mqtt_prefix = "sensor/esp8266_" .. chipid
mqttclient = mqtt.Client("esp8266_" .. chipid, 120)

print("ESP8266 " .. chipid)

ledpin = 4
gpio.mode(ledpin, gpio.OUTPUT)
gpio.write(ledpin, 0)

sds011 = require("sds011")

function log_restart()
	print("Network error " .. wifi.sta.status() .. ". Restarting in 20 seconds.")
	delayed_restart:start()
end

function setup_client()
	gpio.write(ledpin, 1)
	publishing = true
	mqttclient:publish(mqtt_prefix .. "/state", "online", 0, 1, function(client)
		publishing = false
	end)
	port = softuart.setup(9600, 2, 1)
	port:on("data", 10, uart_callback)
end

function connect_mqtt()
	print("IP address: " .. wifi.sta.getip())
	print("Connecting to MQTT " .. mqtt_host)
	delayed_restart:stop()
	mqttclient:on("connect", setup_client)
	mqttclient:on("offline", log_restart)
	mqttclient:lwt(mqtt_prefix .. "/state", "offline", 0, 1)
	mqttclient:connect(mqtt_host)
end

function connect_wifi()
	print("WiFi MAC: " .. wifi.sta.getmac())
	print("Connecting to ESSID " .. station_cfg.ssid)
	wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, connect_mqtt)
	wifi.eventmon.register(wifi.eventmon.STA_DHCP_TIMEOUT, log_restart)
	wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, log_restart)
	wifi.setmode(wifi.STATION)
	wifi.sta.config(station_cfg)
	wifi.sta.connect()
end

function uart_callback(data)
	local pm25i, pm25f, pm10i, pm10f = sds011.parse_frame(data)
	if pm25i == nil then
		print("Invalid or data-less SDS011 frame")
		return
	end
	local json_str = string.format('{"pm25_ugm3": %d.%d, "pm10_ugm3": %d.%d, "rssi_dbm": %d}', pm25i, pm25f, pm10i, pm10f, wifi.sta.getrssi())
	if not publishing then
		publishing = true
		gpio.write(ledpin, 0)
		mqttclient:publish(mqtt_prefix .. "/data", json_str, 0, 0, function(client)
			publishing = false
			gpio.write(ledpin, 1)
			collectgarbage()
		end)
	end
end

delayed_restart:register(20 * 1000, tmr.ALARM_SINGLE, node.restart)

connect_wifi()
