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

sds011.work_period = nil
sds011.active_mode = nil

function sds011.finish_cmd(cmd)
	cmd = cmd .. string.char(0xff, 0xff)
	local checksum = 0
	for i = 3, string.len(cmd) do
		checksum = (checksum + string.byte(cmd, i)) % 256
	end
	cmd = cmd .. string.char(checksum, c_tail)
	return cmd
end

function sds011.query()
	local cmd = string.char(c_head, c_id, c_query)
	cmd = cmd .. string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	return sds011.finish_cmd(cmd)
end

function sds011.set_report_mode(active)
	local op = c_write
	local cmd = c_passive
	if active == nil then
		op = c_read
		active = false
	elseif active then
		cmd = c_active
	end
	local cmd = string.char(c_head, c_id, c_report_mode, op, cmd)
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
	if period ~= nil and (period < 0 or period > 30) then
		return
	end
	local op = c_write
	if period == nil then
		op = c_read
		period = 0
	end
	local cmd = string.char(c_head, c_id, c_workperiod, op, period)
	cmd = cmd .. string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	return sds011.finish_cmd(cmd)
end

function sds011.parse_frame(data)
	local header, command, pm25l, pm25h, pm10l, pm10h, id1, id2, sum, tail = struct.unpack("BBBBBBBBBB", data)
	if header ~= c_head or (pm25l + pm25h + pm10l + pm10h + id1 + id2) % 256 ~= sum or tail ~= c_tail then
		return false
	end
	if command == 0xc0 then
		local pm25 = pm25h * 256 + pm25l
		local pm10 = pm10h * 256 + pm10l
		sds011.pm2_5i = pm25 / 10
		sds011.pm2_5f = pm25 % 10
		sds011.pm10i = pm10 / 10
		sds011.pm10f = pm10 % 10
		return true
	elseif command == 0xc5 and pm25l == 0x02 then
		sds011.active_mode = pm10l == 0
		return true
	elseif command == 0xc5 and pm25l == 0x08 then
		sds011.work_period = pm10l
		return true
	end
	return false
end

return sds011
