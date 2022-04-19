local sds011 = {}

local c_head = 0xaa
local c_tail = 0xab
local c_id = 0xb4

local c_read = 0x00
local c_write = 0x01

local c_report_mode = 0x02
local c_active = 0x00
local c_passive = 0x01

local c_query = 0x04

local c_sleepcmd = 0x06
local c_sleep = 0x00
local c_work = 0x01
local c_workperiod = 0x08

sds011.work_period = 0

function sds011.finish_cmd(cmd)
	cmd = cmd .. string.char(0xff, 0xff)
	local checksum = 0
	for i = 3, string.len(cmd) do
		checksum = (checksum + string.byte(cmd, i)) % 256
	end
	cmd = cmd .. string.char(checksum, c_tail)
	return cmd
end

function sds011.set_report_mode(active)
	local cmd = string.char(c_head, c_id, c_report_mode, c_write)
	if active then
		cmd = cmd .. string.char(c_active)
	else
		cmd = cmd .. string.char(c_passive)
	end
	cmd = cmd .. string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	return sds011.finish_cmd(cmd)
end

function sds011.sleep(sleep)
	local cmd = string.char(c_head, c_id, c_sleepcmd, c_write)
	if sleep then
		cmd = cmd .. string.char(c_sleep)
	else
		cmd = cmd .. string.char(c_work)
	end
	cmd = cmd .. string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	return sds011.finish_cmd(cmd)
end

function sds011.set_work_period(period)
	-- period == 0 : continuous operation, about one measurement per second
	-- period > 0  : about one measurement every <period> minutes, fan is turned off in-between
	if period < 0 or period > 30 then
		return
	end
	sds011.work_period = period
	local cmd = string.char(c_head, c_id, c_workperiod, c_write, period)
	cmd = cmd .. string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	return sds011.finish_cmd(cmd)
end

function sds011.parse_frame(data)
	local header, command, pm25l, pm25h, pm10l, pm10h, id1, id2, sum, tail = struct.unpack("BBBBBBBBBB", data)
	if header ~= c_head or command ~= 0xc0 or (pm25l + pm25h + pm10l + pm10h + id1 + id2) % 256 ~= sum or tail ~= c_tail then
		return nil
	end
	pm25 = pm25h * 256 + pm25l
	pm10 = pm10h * 256 + pm10l
	return pm25 / 10, pm25 % 10, pm10 / 10, pm10 % 10
end

return sds011
