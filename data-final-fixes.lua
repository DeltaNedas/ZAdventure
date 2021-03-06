local md5 = require("lib/format/md5")
require 'lib/bplib'
require 'util'

local function debug ( level, msg, ... )

	if ZADV.debug >= tonumber(level) then
	
		if type(msg) == 'table' then
			log("\n[[ZADV]] ".. serpent.block(msg))
		
		else
			if type(msg) ~= 'string' then
				msg = tostring(msg)
			end
			log("[[ZADV]] ".. string.format(msg,...))
		end
		
	end
end

--
-- Prepare all known areas
--
local delete = {}
local replace_data = {}
local counter = 0
local replaced = 0
local total = ' Areas in total: %s%s'
local DataString = ""
local skiparea = {}


function table.length(T)
	local count = 0
	for k,v in pairs(T) do if v then count = count + 1 end end
	return count
end

for modname,list in pairs( ZADV.Data ) do
for bpname,bpdata in pairs(list) do
	
	if bpdata.update_for then
	
		local mod,aname = bpdata.update_for.modname, bpdata.update_for.areaname
		for k,v in pairs(bpdata) do if k ~= 'update_for' then
			if ZADV.Data[mod] and ZADV.Data[mod][aname] then
				debug(0,'Update for "%s-%s" %s',mod,aname,k)
				debug(2,'\n%s\n------------------[TO]------------------\n%s',serpent.block(ZADV.Data[mod][aname][k]),serpent.block(v))
				ZADV.Data[mod][aname][k] = v
			end
		end end
		
		skiparea[modname..bpname] = true
		ZADV.Data[modname][bpname] = nil
		if table.length(ZADV.Data[modname]) == 0 then ZADV.Data[modname] = nil end
		replaced = replaced+1
		total = ' Areas in total: %s (%s updated)'
		
	end

end end

if ZADV.TEST_MODE then
	local area = {}
	for modname,list in pairs( ZADV.Data ) do
	for bpname,bpdata in pairs(list) do
		if bpname == "TEST" then
			area = bpdata
			ZADV.debug = 2
		end
	end end
	
	ZADV.Data = {}
	ZADV.Data["TEST"] = {}
	ZADV.Data["TEST"]["TEST"] = area
end

for modname,list in pairs( ZADV.Data ) do
for bpname,bpdata in pairs(list) do
if not skiparea[modname..bpname] then
	
	-- check for empty area
	if bpdata.bp and ( type(bpdata.bp) == "table" and bpdata.bp[1]:len() > 0 or bpdata.bp:len() > 0 or #bpdata.entities > 0)
	and ((settings.startup["zadv_experemental"].value and bpdata.experemental) or not bpdata.experemental)
	and ((settings.startup["zadv_dangerous"].value and bpdata.dangerous) or not bpdata.dangerous) then
	
		-- prepare control string
		DataString = DataString .. modname .. bpname
		
		-- parse blueprint string into readable format
		local _data = BPlib.CalculateAreaData(type(bpdata.bp) == "table" and bpdata.bp[1] or bpdata.bp)
		if bpname == "TEST" then debug(2,BPlib.ParseToJson(type(bpdata.bp) == "table" and bpdata.bp[1] or bpdata.bp)) end
		
		-- check area size
		local maxsize = 2^8 
		if bpdata.skip_size_restrictions or (_data.area.size.x <= maxsize and _data.area.size.y <= maxsize) then
		
			ZADV.Data[modname] = ZADV.Data[modname] or {}
			
			-- save new area
			ZADV.Data[modname][bpname] = _data
			debug(0,'New Area "%s - %s" [%s:%s] added.', modname, bpname, _data.area.size.x, _data.area.size.y)
			
			-- check additional parametres
			local function _checkvalue(value, _type, default)
				local ret = ""
				if type(value) == _type then ret = value else ret = default end
				DataString = DataString .. tostring(ret)
				return ret
			end
			local function _checkforce(value, _type, default)
				local ret = ""
				if type(value) == _type then ret = value else ret = default end
				if ret ~= 'neutral' and ret ~= 'enemy' and ret ~= 'player' then
					ret = "ZADV_" .. ret
				end
				DataString = DataString .. tostring(ret)
				return ret
			end
			local function _checkentities(ents)
				if type(ents) ~= 'table' then return {} end
				local ret = {}
				for _,ent in pairs(ents) do
					if type(ents) == 'table' then
						ent.id = ent.id or #ret+1
						ret[#ret+1] = ent
					end
				end
				return ret
			end
			
			-- blueprint options
			ZADV.Data[modname][bpname].bp 					=  bpdata.bp
			ZADV.Data[modname][bpname].name 				=  modname ..'-'.. bpname
			ZADV.Data[modname][bpname].bpname 				=  bpname
			ZADV.Data[modname][bpname].modname 				=  modname
			ZADV.Data[modname][bpname].probability 			=  math.min(1000,math.max(1, bpdata.probability or 10)) or 10
			ZADV.Data[modname][bpname].remoteness_min 		= _checkvalue(bpdata.remoteness_min, 'number', 10)
			ZADV.Data[modname][bpname].remoteness_max 		= _checkvalue(bpdata.remoteness_max, 'number', 0)
			ZADV.Data[modname][bpname].only_once 			= _checkvalue(bpdata.only_once, 'boolean', false)
			ZADV.Data[modname][bpname].max_copies 			= _checkvalue(bpdata.max_copies, 'number', 0)
			ZADV.Data[modname][bpname].nearest_copy			= _checkvalue(bpdata.nearest_copy, 'number', 0)
			ZADV.Data[modname][bpname].progressive_remoteness= _checkvalue(bpdata.progressive_remoteness, 'number', 0)
			ZADV.Data[modname][bpname].ignore_technologies	= _checkvalue(bpdata.ignore_technologies, 'boolean', true)
			ZADV.Data[modname][bpname].force 				= _checkforce(bpdata.force, 'string', "neutral")
			ZADV.Data[modname][bpname].unique 				= _checkvalue(bpdata.unique, 'boolean', false)
			ZADV.Data[modname][bpname].force_build 			= _checkvalue(bpdata.force_build, 'boolean', true)
			ZADV.Data[modname][bpname].random_direction 	= _checkvalue(bpdata.random_direction, 'boolean', false)
			ZADV.Data[modname][bpname].finalize_build		= _checkvalue(bpdata.finalize_build, 'boolean', true)
			ZADV.Data[modname][bpname].force_reveal			= _checkvalue(bpdata.force_reveal, 'boolean', false)
			ZADV.Data[modname][bpname].only_freeplay		= _checkvalue(bpdata.only_freeplay, 'boolean', false)
			ZADV.Data[modname][bpname].ignore_water 		= _checkvalue(bpdata.ignore_water, 'boolean', false)
			ZADV.Data[modname][bpname].ignore_all_collision	= _checkvalue(bpdata.ignore_all_collision, 'boolean', false)
			
			-- additional options
			ZADV.Data[modname][bpname].active 				= _checkvalue(bpdata.active, 'boolean', true)
			ZADV.Data[modname][bpname].minable 				= _checkvalue(bpdata.minable, 'boolean', true)
			ZADV.Data[modname][bpname].destructible 		= _checkvalue(bpdata.destructible, 'boolean', true)
			ZADV.Data[modname][bpname].remains 				= _checkvalue(bpdata.remains, 'string', false)
			ZADV.Data[modname][bpname].health 				= _checkvalue(bpdata.health, 'number', 100)
			ZADV.Data[modname][bpname].operable 			= _checkvalue(bpdata.operable, 'boolean', true)
			ZADV.Data[modname][bpname].order_deconstruction = _checkvalue(bpdata.order_deconstruction, 'boolean', false)
			ZADV.Data[modname][bpname].rotatable 			= _checkvalue(bpdata.rotatable, 'boolean', true)
			
			-- other
			ZADV.Data[modname][bpname].entities 			= _checkentities(bpdata.entities)
			ZADV.Data[modname][bpname].areadata 			= table.deepcopy(bpdata.areadata and bpdata.areadata or {})
			ZADV.Data[modname][bpname].ScriptForEach 		= table.deepcopy((bpdata.ScriptForEach and type(bpdata.ScriptForEach) == 'function') and bpdata.ScriptForEach or function() end)
			ZADV.Data[modname][bpname].ScriptForAll 		= table.deepcopy((bpdata.ScriptForAll and type(bpdata.ScriptForAll) == 'function') and bpdata.ScriptForAll or function() end)
			ZADV.Data[modname][bpname].Events	 			= (bpdata.Events and type(bpdata.Events) == 'table') and table.deepcopy(bpdata.Events) or nil
			ZADV.Data[modname][bpname].messages 			= table.deepcopy((bpdata.messages and type(bpdata.messages) == 'table') and bpdata.messages or { { msg = "",  global.ZADV.Color.white } })
			
			ZADV.Data[modname][bpname].remoteness_min 		= ZADV.Settings['zadv_starting_radius'] + ZADV.Data[modname][bpname].remoteness_min
			ZADV.Data[modname][bpname].remoteness_max 		= ZADV.Data[modname][bpname].remoteness_max == 0 and 0 or ZADV.Settings['zadv_starting_radius'] + ZADV.Data[modname][bpname].remoteness_max
			ZADV.Data[modname][bpname].max_copies 			= ZADV.Data[modname][bpname].max_copies <= 0 and -1 or ZADV.Data[modname][bpname].max_copies
			
			ZADV.Data[modname][bpname].current_force		= ''..ZADV.Data[modname][bpname].force
			
			DataString = DataString .. serpent.dump(ZADV.Data[modname][bpname].bp)
			DataString = DataString .. serpent.dump(ZADV.Data[modname][bpname].entities)
			DataString = DataString .. serpent.dump(ZADV.Data[modname][bpname].areadata)
			DataString = DataString .. serpent.dump(ZADV.Data[modname][bpname].ScriptForEach)
			DataString = DataString .. serpent.dump(ZADV.Data[modname][bpname].ScriptForAll)
			DataString = DataString .. serpent.dump(ZADV.Data[modname][bpname].Events)
			DataString = DataString .. serpent.dump(ZADV.Data[modname][bpname].messages)
			
			counter = counter+1
			
		else
			table.insert(delete, 'ZADV.Data["'.. modname ..'"]["'.. bpname ..'"] = nil')
			debug(1,'Area "%s-%s" bigger than %s tiles in one of dimension, skiping..', modname, bpname, maxsize)
		end
		
	end
	
end end end

-- add collision types
ZADV.CollisionTypes = {
	'assembling-machine',
	'electric-furnace',
	'loader',
}
DataString = DataString .. serpent.dump(ZADV.CollisionTypes)

-- Calculate control hash
local ControlString = md5.sumhexa(DataString:gsub("[_- ]",''))

--
-- Store Prepared Data to Control
--
local dump = serpent.dump(ZADV.Data)
local chunks = math.floor(#dump / 199)
local sdump = serpent.dump(ZADV.Settings)
local schunks = math.floor(#sdump / 199)
local udump = serpent.dump(ZADV.CollisionTypes)
local uchunks = math.floor(#udump / 199)

debug(0,'----------------------------------------')
debug(0, total, counter, replaced>0 and replaced or "")
debug(0,' Data size: %.3f Kb', DataString:gsub("[_- ]",''):len()/1024)
debug(0,' Data chunks: %s', chunks+schunks+uchunks)
debug(0,' Hash: %s', ControlString)
debug(0,'----------------------------------------')
--debug(1,ZADV)

-- remember number of chunks
data:extend({
	{
		type = "flying-text",
		name = "ZADV_DATA_C",
		time_to_live = 0,
		speed = 1,
		order = "".. chunks+1
	},
	{
		type = "flying-text",
		name = "ZADV_DATA_S",
		time_to_live = 0,
		speed = 1,
		order = "".. schunks+1
	},
	{
		type = "flying-text",
		name = "ZADV_DATA_U",
		time_to_live = 0,
		speed = 1,
		order = "".. uchunks+1
	},
	-- save control string
	{
		type = "flying-text",
		name = "ZADV_DATA_CS",
		time_to_live = 0,
		speed = 1,
		order = "".. ControlString
	},
	-- remember debug level
	{
		type = "flying-text",
		name = "ZADV_DATA_D",
		time_to_live = 0,
		speed = 1,
		order = "".. ZADV.debug
	}
})

-- write data chunks
for i=0, chunks do
	local name = "ZADV_DATA_C_"..i
	data:extend({
	{
		type = "flying-text",
		name = name,
		time_to_live = 0,
		speed = 1,
		order = "".. dump:sub(i*199, (i+1)*199-1)
	}})
end
for i=0, schunks do
	local name = "ZADV_DATA_S_"..i
	data:extend({
	{
		type = "flying-text",
		name = name,
		time_to_live = 0,
		speed = 1,
		order = "".. sdump:sub(i*199, (i+1)*199-1)
	}})
end
for i=0, uchunks do
	local name = "ZADV_DATA_U_"..i
	data:extend({
	{
		type = "flying-text",
		name = name,
		time_to_live = 0,
		speed = 1,
		order = "".. udump:sub(i*199, (i+1)*199-1)
	}})
end


