station_cfg = {}
publishing_mqtt = false
publishing_http = false

watchdog = tmr.create()
chip_id = string.format("%06X", node.chipid())
device_id = "esp8266_" .. chip_id
mqtt_prefix = "sensor/" .. device_id
mqttclient = mqtt.Client(device_id, 120)

dofile("config.lua")

print("ESP8266 " .. chip_id)

ledpin = 4
gpio.mode(ledpin, gpio.OUTPUT)
gpio.write(ledpin, 0)

sds011 = require("sds011")

function log_restart()
	print("Network error " .. wifi.sta.status())
end

function setup_client()
	print("Connected")
	gpio.write(ledpin, 1)
	publishing_mqtt = true
	mqttclient:publish(mqtt_prefix .. "/state", "online", 0, 1, function(client)
		publishing_mqtt = false
	end)
	port = softuart.setup(9600, 2, 1)
	port:on("data", 10, uart_callback)
end

function connect_mqtt()
	print("IP address: " .. wifi.sta.getip())
	print("Connecting to MQTT " .. mqtt_host)
	mqttclient:on("connect", hass_register)
	mqttclient:on("message", hass_config)
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
	local work_period = "continuous"
	if sds011.work_period > 0 then
		work_period = string.format("%d min", sds011.work_period)
	end
	local json_str = string.format('{"pm2_5_ugm3": %d.%d, "pm10_ugm3": %d.%d, "rssi_dbm": %d, "period": "%s"}', pm25i, pm25f, pm10i, pm10f, wifi.sta.getrssi(), work_period)
	local influx_str = string.format("pm2_5_ugm3=%d.%d,pm10_ugm3=%d.%d", pm25i, pm25f, pm10i, pm10f)
	if not publishing_mqtt then
		watchdog:start(true)
		publishing_mqtt = true
		gpio.write(ledpin, 0)
		mqttclient:publish(mqtt_prefix .. "/data", json_str, 0, 0, function(client)
			publishing_mqtt = false
			if influx_url and influx_attr and influx_str then
				publish_influx(influx_str)
			else
				gpio.write(ledpin, 1)
				collectgarbage()
			end
		end)
	end
end

function publish_influx(payload)
	if not publishing_http then
		publishing_http = true
		http.post(influx_url, influx_header, "sds011" .. influx_attr .. " " .. payload, function(code, data)
			publishing_http = false
			gpio.write(ledpin, 1)
			collectgarbage()
		end)
	end
end

function hass_config(client, topic, message)
	if topic == "config/" .. device_id .. "/set/work_period" then
		local work_period = 0
		local _, _, minutes = string.find(message, "([0-9]+) min")
		if minutes ~= nil then
			work_period = tonumber(minutes)
		end
		port:write(sds011.set_work_period(work_period))
	end
end

function hass_register()
	local hass_device = string.format('{"connections":[["mac","%s"]],"identifiers":["%s"],"model":"ESP8266 + SDS011","name":"SDS011 %s","manufacturer":"derf"}', wifi.sta.getmac(), device_id, chip_id)
	local hass_entity_base = string.format('"device":%s,"state_topic":"%s/data","expire_after":1800', hass_device, mqtt_prefix)
	local hass_pm2_5 = string.format('{%s,"name":"PM2.5","object_id":"%s_pm2_5","unique_id":"%s_pm2_5","device_class":"pm25","unit_of_measurement":"µg/m³","value_template":"{{value_json.pm2_5_ugm3}}"}', hass_entity_base, device_id, device_id)
	local hass_pm10 = string.format('{%s,"name":"PM10","object_id":"%s_pm10","unique_id":"%s_pm10","device_class":"pm10","unit_of_measurement":"µg/m³","value_template":"{{value_json.pm10_ugm3}}"}', hass_entity_base, device_id, device_id)
	local hass_rssi = string.format('{%s,"name":"RSSI","object_id":"%s_rssi","unique_id":"%s_rssi","device_class":"signal_strength","unit_of_measurement":"dBm","value_template":"{{value_json.rssi_dbm}}","entity_category":"diagnostic"}', hass_entity_base, device_id, device_id)
	local hass_period = string.format('{%s,"name":"Measurement Period","object_id":"%s_period","unique_id":"%s_period","icon":"mdi:clock-outline","command_topic":"config/%s/set/work_period","options":["continuous","1 min","2 min","3 min","4 min","5 min","6 min","7 min","8 min","9 min","10 min"],"value_template":"{{value_json.period}}","entity_category":"config"}', hass_entity_base, device_id, device_id, device_id)

	mqttclient:publish("homeassistant/sensor/" .. device_id .. "/pm2_5/config", hass_pm2_5, 0, 1, function(client)
		mqttclient:publish("homeassistant/sensor/" .. device_id .. "/pm10/config", hass_pm10, 0, 1, function(client)
			mqttclient:publish("homeassistant/sensor/" .. device_id .. "/rssi/config", hass_rssi, 0, 1, function(client)
				mqttclient:publish("homeassistant/select/" .. device_id .. "/work_period/config", hass_period, 0, 1, function(client)
					client:subscribe("config/" .. device_id .. "/set/work_period", 0, function(client)
						collectgarbage()
						setup_client()
					end)
				end)
			end)
		end)
	end)
end

watchdog:register(20 * 60 * 1000, tmr.ALARM_SEMI, node.restart)
watchdog:start()

connect_wifi()
