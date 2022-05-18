# ESP8266 Lua/NodeMCU module for SDS011 particle monitor

This repository contains a Lua module (`sds011.lua`) as well as ESP8266/NodeMCU
MQTT gateway application example (`init.lua`) for the **SDS011** particulate
matter (PM2.5 and PM10) sensor.

## Dependencies

sds011.lua has been tested with Lua 5.1 on NodeMCU firmware 3.0.1
(Release 202112300746, integer build). It requires the following modules.

* struct

Most practical applications (such as the example in init.lua) also need the
following modules.

* gpio
* mqtt
* node
* softuart
* tmr
* uart
* wifi

## Setup

Connect the SDS011 sensor to your ESP8266/NodeMCU board as follows.

* SDS011 GND → ESP8266/NodeMCU GND
* SDS011 5V → 5V input (note that the "5V" pin of NodeMCU or D1 mini dev boards is connected to its USB input via a protective diode, so when powering the board via USB the "5V" output is more like 4.7V. I have not tested whether that is an issue)
* SDS011 TXD → NodeMCU D1 (ESP8266 GPIO5)
* SDS011 RXD → NodeMCU D2 (ESP8266 GPIO4)

If you use different pins for TXD and RXD, you need to adjust the
softuart.setup call in the examples provided in this repository to reflect
those changes. Keep in mind that some ESP8266 pins must have well-defined logic
levels at boot time and may therefore be unsuitable for SDS011 connection.

## Usage

Copy **sds011.lua** to your NodeMCU board and set it up as follows.

```lua
sds011 = require("sds011")
port = softuart.setup(9600, 2, 1)
port:on("data", 10, uart_callback)

function uart_callback(data)
	if sds011.parse_frame(data) then
		-- PM values or work period have been updated
		if sds011.pm2_5i ~= nil then
			-- pm2_5i/pm10i contain the integer part (i.e., PM2.5 / PM10 value in µg/m³)
			-- pm2_5d/pm10d contain the decimal/fractional part (i.e., PM2.5 / PM10 fraction in .1 µg/m³, range 0 .. 9)
		else
			-- sds011.work_period has been updated after using sds011.set_work_period
		end
	end
end
```

## SDS011 Configuration API

If desired, **sds011.lua** can be used to configure the SDS011 sensor.
Currently, the following commands are supported

* `port:write(sds011.set_report_mode(active))`
  * active == true: periodically report PM2.5 and PM10 values via UART
  * active == false: only report PM2.5 and PM10 values when queried
* `port:write(sds011.sleep(sleep))`
  * sleep == true: put sensor into sleep mode. The fan is turned off, no further measurements are performed
  * sleep == false: wake up sensor.
* `port:write(sds011.set_work_period(period))`
  * period == nil: request current work period; does not change it
  * period == 0: continuous operation (about one measurement per second)
  * 0 < *period* ≤ 30: about one measurement every *period* minutes; fan turned off in-between

## Application Example

**init.lua** is an example application with HomeAssistant integration.
To use it, you need to create a **config.lua** file with WiFI and MQTT settings:

```lua
station_cfg.ssid = "..."
station_cfg.pwd = "..."
mqtt_host = "..."
```

Optionally, it can also publish readings to an InfluxDB.
To do so, configure URL and attribute:

```lua
influx_url = "..."
influx_attr = "..."
```

Readings will be stored as `sds011,[influx_attr] pm2_5_ugm3=...,pm10_ugm3=...`
