# ESP8266 Lua/NodeMCU module for Nova SDS011 PM sensors

[esp8266-nodemcu-sds011](https://finalrewind.org/projects/esp8266-nodemcu-sds011/)
provides an ESP8266 NodeMCU Lua module (`sds011.lua`) as well MQTT /
HomeAssistant / InfluxDB integration example (`init.lua`) for **SDS011**
particulate matter (PM2.5 and PM10) sensors connected via UART.

## Dependencies

sds011.lua has been tested with Lua 5.1 on NodeMCU firmware 3.0.1
(Release 202112300746, integer build). It requires the following modules.

* struct

Most practical applications (such as the example in init.lua) also need the
following modules.

* gpio
* http (for InfluxDB integration)
* mqtt (for HomeAssistant / MQTT integration)
* node
* softuart
* tmr
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
		if sds011.pm2_5i ~= nil then
			-- pm2_5i/pm10i contain the integer part (i.e., PM2.5 / PM10 value in µg/m³)
			-- pm2_5f/pm10f contain the decimal/fractional part (i.e., PM2.5 / PM10 fraction in .1 µg/m³, range 0 .. 9)
		end
	end
end
```

## SDS011 API

If desired, **sds011.lua** can be used to configure the SDS011 sensor.

### Commands

* `port:write(sds011.set_report_mode(active))`
  * active == nil: request current mode; do not change it.
    The mode can be read from `sds011.active_mode` after a few milliseconds.
  * active == true: periodically report PM2.5 and PM10 values via UART
  * active == false: only report PM2.5 and PM10 values when queried
* `port:write(sds011.set_work_period(period))`
  * period == nil: request current work period; do not change it.
    The work period can be read from `sds011.work_period` after a few milliseconds.
  * period == 0: continuous operation (about one measurement per second)
  * 0 < *period* ≤ 30: about one measurement every *period* minutes; fan turned off in-between
* `port:write(sds011.sleep(sleep))`
  * sleep == nil: query current sleep mode; do not change it.
    The mode can be read from `sds011.working` after a few milliseconds; do
    not trust its value before that.
    Background: SDS011 sensors only respond to a sleep mode query when they are
    not in sleep mode. To handle this, the driver sets `sds011.working = false`
    when running the query, and reverts it to `sds011.working = true` only if
    it receives an appropriate response.
  * sleep == true: put sensor into sleep mode.
    The fan is turned off, no further measurements are performed. In this mode,
    `port:write(sds011.sleep(false))` is the only command accepted by the
    device.
  * sleep == false: wake up sensor
* `port:write(sds011.query())`: Query PM2.5 and PM10 values in passive mode.
  data is available after a few milliseconds.

### Variables

* `sds011.active_mode`
  * true: the sensor automatically reports readings
  * false: the sensor only reports readings when queried
* `sds011.work_period`
  * 0: perform one reading measurement every second
  * otherwise: number of minutes between measurements
* `sds011.working`
  * true: the sensor is enabled
  * false: the sensor is in sleep mode
* `sds011.pm2_5i`, `sds011.pm2_5f`, `sds011.pm10i`, `sds011.pm10f`: see Usage

## Application Example

**init.lua** is an example application with optional HomeAssistant and InfluxDB integration.
To use it, you need to create a **config.lua** file with WiFI and MQTT/InfluxDB settings:

```lua
station_cfg = {ssid = "...", pwd = "..."}
mqtt_host = "..."
influx_url = "..."
influx_attr = "..."
```

Both `mqtt_host` and `influx_url` are optional, though it does not make much sense to specify neither.
InfluxDB readings will be published as `sds011[influx_attr] pm2_5_ugm3=%d.%01d,pm10_ugm3=%d.%01d`.
So, unless `influx_attr = ''`, it must start with a comma, e.g. `influx_attr = ',device=' .. device_id`.

## Images

![](https://finalrewind.org/projects/esp8266-nodemcu-sds011/media/preview.png)
