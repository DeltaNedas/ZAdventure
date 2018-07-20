require 'stdlib/area/position'
require 'stdlib/area/area'
require 'stdlib/area/chunk'
require 'stdlib/area/tile'
require 'stdlib/table'
require 'stdlib/game'
require 'lib/bplib'
require 'util'

--
-- global variables
--
global.ZADV = global.ZADV or {}
global.ZADV_InProcess = false
global.ZADV_ForceUnlock = false
global.ZADV_ForceUnlock = false
global.ZADV_EventLock = 0


--
-- local variables
--


local format = string.format
local floor = math.floor
local serpd = serpent.dump
local serpb = serpent.block
local ZADV = {}
local ZADV_initialized = false
local ZADV_ForcedArea = false

Color = {
	black 	= {r = 0.0, g = 0.0, b = 0.0},
	red 	= {r = 1.0, g = 0.2, b = 0.2},
	green 	= {r = 0.3, g = 0.7, b = 0.0},
	yellow	= {r = 0.9, g = 0.7, b = 0.0},
	orange	= {r = 0.9, g = 0.4, b = 0.0},
	blue	= {r = 0.3, g = 0.7, b = 1.0}
}


--
-- debug settings
--
ZADV.debug = 0

function debug ( msg, ... )
	if type(msg) == 'table' then
		if ZADV.debug >= 1 then log("\n[[ZADV]] ".. serpent.block(msg)) end
	else
		if type(msg) ~= 'string' then
			msg = tostring(msg)
		end
		if ZADV.debug >= 1 then log("[[ZADV]] ".. format(msg,...)) end
		if ZADV.debug >= 2 and game and string.len(msg) <= 200 then
			game.print(format(msg,...))
		end
	end
end


--
-- Initialization
--

--- Prepare operable blueprint
local function PrepareBlueprint()
	
	if not global.ZADV.blueprint then
		
		if not global.ZADV.entity then
			
			if not game.surfaces['ZADV_SURFACE'] then
				game.create_surface("ZADV_SURFACE",{width=3,height=3,peaceful_mode=true})
				debug("Creating operable surface")
			end
			
			global.ZADV.entity = game.surfaces['ZADV_SURFACE'].create_entity{name="wooden-chest", position={0,0}, force=game.forces["neutral"]}
			global.ZADV.entity.insert{name="blueprint", count=1}
			debug("Creating operable entity")
			
		end
		
		global.ZADV.blueprint = global.ZADV.entity.get_inventory(defines.inventory.chest).find_item_stack("blueprint")
		debug("Creating operable blueprint")
		
	end
	
end

--- Reassign events after loadstring
local function ReEvent()

	global.ZADV.Events = global.ZADV.Events or {}
	
	for event,data in pairs(global.ZADV.Events) do
		if not script.get_event_handler(event) then
			script.on_event(event, Global_Handler)
		end
	end
	
end

--- Global initialization
local function Init()
	
	--parse raw data
	local dump, sdump, ndump = "", "", ""
	local chunks = game.entity_prototypes["ZADV_DATA_C"].order
	local schunks = game.entity_prototypes["ZADV_SDATA_C"].order
	local nchunks = game.entity_prototypes["ZADV_NDATA_C"].order
	global.ZADV.ControlString = game.entity_prototypes["ZADV_DATA_CS"].order
	ZADV.debug = tonumber(game.entity_prototypes["ZADV_DATA_D"].order)
	debug("Set debug level: ".. ZADV.debug)
	
	for i=0, chunks-1 do
		local name = "ZADV_DATA_"..i
		dump = dump .. game.entity_prototypes[name].order
	end
	
	for i=0, schunks-1 do
		local name = "ZADV_SDATA_"..i
		sdump = sdump .. game.entity_prototypes[name].order
	end
	
	for i=0, nchunks-1 do
		local name = "ZADV_NDATA_"..i
		ndump = ndump .. game.entity_prototypes[name].order
	end
	
	-- apply parsed data
	ZADV.Data = loadstring(dump)() or {}
	ZADV.Settings = loadstring(sdump)() or {}
	ZADV.NamePairList = loadstring(ndump)() or {}
	debug("Raw data requested.")
	
	-- set globals
	global.ZADV.UsedTypes = global.ZADV.UsedTypes or {}
	
end
local function PostInit()
	
	if not ZADV.Data or not ZADV.Settings or not ZADV.NamePairList then
		Init()
		ZADV_initialized = false
	end
	
	
	-- info about new data
	if not global.ZADV.ControlString
	or game.entity_prototypes["ZADV_DATA_CS"].order ~= global.ZADV.ControlString
	then 
		game.print("[ZAdv] New or updated areas found. Start re-initialization...", Color.green)
		debug("Old seed:\t".. global.ZADV.ControlString)
		debug("New seed:\t".. game.entity_prototypes["ZADV_DATA_MD"].order)
		Init()
		ZADV_initialized = false
	end
	
	if not ZADV_initialized then
		ZADV_initialized = true
		
		-- creating blueprint instance
		PrepareBlueprint()
		
		-- events
		debug('Prepare events')
		ReEvent()
		
		debug("Initialization complete.")
		debug("Initialization complete. %s", serpb(global.ZADV))
		
	end
end

--- Global handler
function Global_Handler(event)
	
	if global.ZADV_EventLock ~= game.tick then
		global.ZADV_EventLock = game.tick
		
		PostInit()
		
		for id,data in pairs(global.ZADV.Events) do
			for dname,edata in pairs(data) do
				if type(ZADV.Data[edata.mod][edata.area].Events[id]) == 'function'
				and global.ZADV.ArData[dname]then
					for indx,ardata in pairs(global.ZADV.ArData[dname]) do
						if not ardata.disabled and ((event.name == 0 and event.tick % 10 == indx % 10) or event.name ~= 0) then
							local done, err = pcall(ZADV.Data[edata.mod][edata.area].Events[id], event,  global.ZADV.ArData[dname][indx], game)
							if not done and err then debug("\n[%s].on_event[%s] return with error:\n%s", dname, id, err) end
						elseif ardata.disabled then
							global.ZADV.ArData[dname][indx] = nil
							local cnt = 0
							for i in pairs(global.ZADV.ArData[dname]) do cnt = cnt+1 end
							if cnt == 0 then global.ZADV.ArData[dname] = nil end
						end
					end
				end
			end
		end
		
	end
end


--
-- Local functions
--

--- Integer to base with up rounding
-- @param int
-- @return possitive integer rounded up to neares solid number
local function base( int )
	int = tonumber(int)
	return floor((int < 0 and 0 - int or int)  + 0.5)
end

--- Check if position inside restricted area
-- @param distance : from position in chunks
-- @param position : {x,y} array current position
-- @return true if the position inside area, false otherwise
local function isInsideBounds( position, distance )
	return Area.inside(Area.expand(Area.construct(0,0,0,0), (distance or 12)*32), position)
end

--- Collision check on surface in selected area
-- @param surface : LuaSurface instance
-- @param area : BoundingBox {left_top :: Position, right_bottom :: Position}
-- @return true if area have collision tles, false otherwise
local function CollisionCheckArea(surface, area)
	local types = {"unit", "unit-spawner", "corpse", "simple-entity", "container", "resource", "cliff"}
	for t in pairs(global.ZADV.UsedTypes) do table.insert(types, t) end
	if surface.count_tiles_filtered{area=area,  collision_mask="water-tile"} > 0
	or surface.count_entities_filtered{area=area, type=types} > 0
	then return true else return false end
end

--- Split string to array
-- @param str : input string
-- @param sep : separator
-- @return arrray of strings
local function strsplit(str,sep)
	local sar = {}
	for s in string.gmatch(str,"([^"..sep.."]+)") do sar[#sar+1] = s end
	return sar
end

--- Generate random number
-- @param min : minimum value
-- @param max : maximum value
-- @param adseed : additional seed
-- @return random number
local function Rnd(min,max,adseed)
	min = min or 1
	max = max or 1
	adseed = adseed or 0
	global.adseed = global.adseed or 2^16
	global.adseed = global.adseed + adseed
	global.adseed = global.adseed > 2^31 and 1 or global.adseed
	local seed = game.tick + floor(tonumber(tostring({}):sub(8,-4))) + adseed
	global.generator = global.generator or game.create_random_generator(seed)
	global.generator.re_seed(seed)
	return math.min(max, math.max(min, floor(global.generator(min, math.max(min, base(max+global.adseed))) % max) ) )
end
--- globalize Rnd function
function ZADVRnd(min,max,adseed)
	return Rnd(min,max,adseed)
end

--- Generate random number
-- @param T : table
-- @return table length
local function tlength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

--- Generate random number
-- @param name : requested name
-- @return string with possible replacement name
-- [ not implemented yet ]
local function getname(name)
	return name
end

--- Find nearest players
-- @param pos : relative position
-- @return LuaPlayer table
local function FindNearestPlayer(pos)
	local indx = 0
	local dist = false
	for i,p in pairs(game.connected_players) do
		if not dist or Position.distance(pos, p.position) < dist then
			indx = i; dist = Position.distance(pos, p.position)
		end
	end
	return game.connected_players[indx] or false
end

--- Randomize and prepare new area
-- @param seed : center of new chunk
-- @return table area data
local function GetRandomArea(seed)
	
	local pos = seed
	seed = pos.x + pos.y
	
	-- randomize global step
	local roll = Rnd(1,1000,seed)
	if not ZADV_ForcedArea and roll > tonumber(ZADV.Settings['zadv_global_frequency']) * (ZADV.debug + 1) then return nil end
	
	-- run through the list of areas
	local areas = {}
	roll = Rnd(1,1000,seed)
	
	
	for mn,mod in pairs(ZADV.Data) do
		for an,ar in pairs(mod) do
			
			-- check if no more copiees alloewd
			global.ZADV.restrictedareas = global.ZADV.restrictedareas or {}
			
			-- unicality check
			if ar.unique and ar.force == 'player' then
			
				global.ZADV.uniqueforces = global.ZADV.uniqueforces or {}
				global.ZADV.uniqueforces[ar.name] = global.ZADV.uniqueforces[ar.name] or {}
				
				local forces = {}
				for _,f in pairs(game.forces) do
					if not global.ZADV.uniqueforces[ar.name][f.name]
					and f.name ~= 'neutral' and f.name ~= 'enemy' and not f.name:find('ZADV_')
					then
						table.insert(forces,f.name)
					end
				end
				
				if not forces[1] then
					global.ZADV.restrictedareas[ar.name] = true
				else
					ZADV.Data[mn][an].current_force = forces[Rnd(1,#forces,seed)] or ar.current_force
				end
				
			else ZADV.Data[mn][an].unique = false end
			
			ar.restricted = global.ZADV.restrictedareas[ar.name]
			
			if not ar.restricted and roll <= ar.probability * (ZADV.debug + 1) then
			
				-- technology check
				local techallow = false
				if ar.ignore_technologies then
					techallow = true
				elseif ar.techs then
					techallow = false
					for _,f in pairs(game.forces) do
					for _,t in pairs(ar.techs) do
					if f.technologies[t].researched then
						techallow = true
					end end	end
					--if not techallow then debug('Not enough technologies for "%s - %s", skip this time..',mn,an) end
				end
				
				-- placeing check
				local placeallow = true
				if isInsideBounds(pos, ar.remoteness_min or ZADV.Data[mn][an].remoteness_min) then
					placeallow = false
					--debug('Area "%s-%s" too close starting area', mn, an)
				elseif ( ZADV.Data[mn][an].remoteness_max ~= 0 and not isInsideBounds(pos, ar.remoteness_max or ZADV.Data[mn][an].remoteness_max) ) then
					placeallow = false
					--debug('Area "%s-%s" is outside placing bounds', mn, an)
				end
				
				-- all checks done
				if techallow and placeallow and not ar.restricted then
					-- store triggered area
					table.insert(areas, {mn,an})
				end
				
			end
	end end
	
	-- if we have multiple triggered areas - choose one
	if tlength(areas) > 0 then
		roll = (Rnd(1,1000,seed) % #areas) + 1
		areas = areas[roll]
		
	-- select one if we must
	elseif ZADV_ForcedArea then
		roll = (Rnd(1,1000,seed) % #ZADV.NamePairList) + 1
		areas = ZADV.NamePairList[roll]
		
	-- nothing to do
	else return false end
	
	ZADV_ForcedArea = false
	
	-- decrease copies counter
	ZADV.Data[areas[1]][areas[2]].max_copies =
		ZADV.Data[areas[1]][areas[2]].max_copies < 0 and -10
		or math.max(0, ZADV.Data[areas[1]][areas[2]].max_copies - 1 + (ZADV.debug -1))
	
	if ZADV.Data[areas[1]][areas[2]].unique then
		global.ZADV.uniqueforces[ZADV.Data[areas[1]][areas[2]].name][ZADV.Data[areas[1]][areas[2]].current_force] = true
	end
	
	-- if only once or no more copiees
	if ZADV.Data[areas[1]][areas[2]].only_once
	or ZADV.Data[areas[1]][areas[2]].max_copies >=0 then
		global.ZADV.restrictedareas[ZADV.Data[areas[1]][areas[2]].name] =
			ZADV.Data[areas[1]][areas[2]].only_once or ZADV.Data[areas[1]][areas[2]].max_copies == 0
	end
	
	-- return area
	return ZADV.Data[areas[1]][areas[2]]
	
end


--
-- Area generation
--

--- place blueprint automaticly
-- @param surface : Surface to build on
-- @param center : The position to build at
-- @param newarea : blueprint to build
local function AplyBlueprintAuto(surface, center, newarea)
	
	debug("New area: %s",newarea.name)
	
	-- fault check
	if not newarea or not center or not surface then return end
	
	-- prepare blueprint
	global.ZADV.blueprint.import_stack(newarea.bp)
	if global.ZADV.blueprint.is_blueprint_setup() then
		
		--[[ adapt blueprint options ]]--
		
		-- force
		if not game.forces[newarea.force] then
			if type(newarea.force) == 'string' then
				if #game.forces >= 62 then
					newarea.force = "neutral"
				else
					game.create_force(newarea.force)
					debug("Created new force: ".. newarea.force)
				end
			else newarea.force = "neutral" end
		elseif newarea.force == 'player' and #game.forces > 3 then
			local forces = {}
			for _,f in pairs(game.forces) do 
				if f.name ~= 'neutral' and f.name ~= 'enemy' then table.insert(forces, f.name) end
			end
			newarea.force = forces[Rnd(1,#forces)]
			debug("Selected force: ".. newarea.force)
		end
		
		-- direction
		if newarea.random_direction then
			newarea.direction = math.min(4,Rnd(1,5))*2-2
		else
			newarea.direction = 0
		end
		
		
		--[[ place blueprint on surface ]]--
		--debug("place bp @ %s", serpent.block(center))
		local ghosts = global.ZADV.blueprint.build_blueprint{
			surface=surface,
			force=game.forces[newarea.current_force],	-- modded
			position=center,
			force_build=newarea.force_build,			-- modded
			direction=newarea.direction,				-- modded
			skip_fog_of_war=false
		}
		
		--[[ finalize placed entities ]]--
		
		local area = {
			{center.x-(newarea.area.size.x/2)-1, center.y-(newarea.area.size.y/2)-1},
			{center.x+(newarea.area.size.x/2)+1, center.y+(newarea.area.size.y/2)+1}
		}
		local _center = Area.center(area)
		
		local area2d = newarea.chunkarea
		area2d.right_bottom.x = area2d.right_bottom.x - 1
		area2d.right_bottom.y = area2d.right_bottom.y - 1
		
		local bigarea2d = newarea.bigchunkarea or false
		if bigarea2d then
			bigarea2d.right_bottom.x = bigarea2d.right_bottom.x - 1
			bigarea2d.right_bottom.y = bigarea2d.right_bottom.y - 1
		end
		
		-- prepare areadata
		global.ZADV.ArData = global.ZADV.ArData or {}
		local areadata = table.deepcopy(newarea.areadata) or {}

		local entities = {}
		if newarea.finalize_build then					-- modded
			for k,v in pairs(ghosts) do
				local _,_e
				if v.valid and not v.revive() then
					for _,e in pairs(surface.find_entities_filtered{
						area=v.bounding_box,
						name=v.name,
						invert=true
					}) do e.destroy() end
					v.revive()
				end
			end
			
			if newarea.names then
				
				entities = surface.find_entities_filtered{
					area=area,
					name=newarea.names
				}
				
				-- local storage
				local locstor = {}
				
				-- update used types list
				global.ZADV.UsedTypes = global.ZADV.UsedTypes or {}
				
				for _,e in pairs(entities) do if e and e.valid then 
				
					-- store type for future checks
					global.ZADV.UsedTypes[e.type] = true
					
					-- Deactivating an entity will stop all its operations (inserters will stop working)
					e.active = newarea.active
					
					-- Not minable entities can still be destroyed
					e.minable = newarea.minable
					
					-- When the entity is not destructible it can't be damaged
					e.destructible = newarea.destructible
					
					-- Replace entities with their remains if they have it
					if newarea.remains then
						e.die('neutral')
					end
					
					-- Set health in procentage of the entity. Entities with 0 health can not be attacked. Setting health to higher than max health will set health to max health
					if newarea.health >= 0 then
						e.health = e.prototype.max_health * (newarea.health/100)
					end
					
					-- Player can't open gui of this entity and he can't quick insert/input stuff in to the entity when it is not operable
					e.operable = newarea.operable
					
					-- Sets the entity to be deconstructed by construction robots
					if newarea.order_deconstruction then
						e.order_deconstruction('neutral')
					end
					
					-- When entity is not to be rotatable (inserter, transport belt etc), it can't be rotated by player using the R key
					e.rotatable = newarea.rotatable
					
					-- Script for each entity in new area
					if type(newarea.ScriptForEach) == 'function' then
					
						local done, err = pcall(newarea.ScriptForEach, Rnd(1,1000), game, surface, newarea.force, area, _center, e, newarea.names or {}, locstor, areadata)
						if not done then debug("\n[%s].ScriptForEach return with error:\n%s", newarea.name, err) end
						
						if ZADV.debug >= 2 and newarea.name:find('TEST') then
							local _testfunc = loadstring(serpd(function(rndroll, game, surface, force, area, center, entity, namelist, locstore, areadata)
-------------------------------------------------------------------------------------------------------------------------------------------
----v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v----
--[[-----------------------------------------------------------------------------------------------------------------------------------]]--
		
--[[-------------------------------------------------------------------------------------------------------------------------------]]--]]--
----^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^--------
-------------------------------------------------------------------------------------------------------------------------------------------
							end))()
							done, err = pcall(_testfunc, Rnd(1,1000), game, surface, newarea.force, area, _center, e, newarea.names or {}, locstor, areadata)
							if not done then debug("\n[[DEBUG]]\n[%s].ScriptForEach return with error:\n%s", newarea.name, err) end
						end
						
					end
					
				end end
			end
		else
			entities = ghosts
		end
		
		
		-- Script for all entities in new area
		if type(newarea.ScriptForAll) == 'function' then
		
			local done, err = pcall(newarea.ScriptForAll, Rnd(1,1000), game, surface, newarea.force, area, _center, newarea.names or {}, entities or {}, areadata)
			if not done then debug("\n[%s].ScriptForAll return with error:\n%s", newarea.name, err) end
			
			if ZADV.debug >= 2 and newarea.name:find('TEST') then
				local _testfunc = loadstring(serpd(function(rndroll, game, surface, force, area, center, namelist, entitylist, areadata)
-------------------------------------------------------------------------------------------------------------------------------------------
----v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v----
--[[-----------------------------------------------------------------------------------------------------------------------------------]]--
		
--[[-------------------------------------------------------------------------------------------------------------------------------]]--]]--
----^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^--------
-------------------------------------------------------------------------------------------------------------------------------------------
				end))()
				done, err = pcall(_testfunc, Rnd(1,1000), game, surface, newarea.force, area, _center, newarea.names or {}, entities or {}, areadata)
				if not done then debug("\n[[DEBUG]]\n[%s].ScriptForAll return with error:\n%s", newarea.name, err) end
			end
		end
		
		-- Event handling
		
		if ZADV.debug >= 2 and newarea.name:find('TEST') then
		--	ZADV.Data[newarea.modname][newarea.bpname].Events = loadstring(serpd({
-------------------------------------------------------------------------------------------------------------------------------------------
----v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v-v----
--[[-----------------------------------------------------------------------------------------------------------------------------------]]--
		
--[[-------------------------------------------------------------------------------------------------------------------------------]]--]]--
----^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^-^--------
-------------------------------------------------------------------------------------------------------------------------------------------
		--	}))()
		end
		
		if ZADV.Data[newarea.modname][newarea.bpname].Events and type(ZADV.Data[newarea.modname][newarea.bpname].Events) == 'table' then
			for evnt,func in pairs(ZADV.Data[newarea.modname][newarea.bpname].Events) do
				if type(func) == 'function' then
					global.ZADV.Events[evnt] = global.ZADV.Events[evnt] or {}
					global.ZADV.Events[evnt][newarea.name] = {mod = newarea.modname, area = newarea.bpname}
				end
			end
		end
		
		-- save areadata
		if type(areadata) == 'table' then
			local cnt = 0
			for i in pairs(areadata) do cnt = cnt + 1 end
			if cnt > 0 then
				global.ZADV.ArData[newarea.name] = global.ZADV.ArData[newarea.name] or {}
				table.insert(global.ZADV.ArData[newarea.name], areadata)
			end
		else
			global.ZADV.ArData[newarea.name] = global.ZADV.ArData[newarea.name] or {}
			table.insert(global.ZADV.ArData[newarea.name], areadata)
		end

		-- update events
		ReEvent()
		
		-- remove unfinished deconstruction
		surface.cancel_deconstruct_area{area=area, force=newarea.force}
		
		-- force chart area
		if ZADV.debug >= 2 or newarea.force_reveal or ZADV.force_reveal then
		for _,f in pairs(game.forces) do
		if f.name ~= 'neutral' and f.name ~= 'enemy' then
			if bigarea2d then f.chart(surface, bigarea2d)
			else f.chart(surface, area2d) end
		end end end
		
		-- shoot the message
		local possiblemessages = {}
		for _,m in pairs(newarea.messages) do if m.msg:len() > 0
			then table.insert(possiblemessages, m) end end
		if #possiblemessages > 0 then
			local message = possiblemessages[Rnd(1,#possiblemessages)]
			pcall(game.print, message.msg, message.color)
		end
		if ZADV.force_reveal then game.print("New area  ".. newarea.name) end
		
		
		-- erase blueprint
		global.ZADV.blueprint.clear()
	
	end
end

--- place blueprint directly
-- @param surface : Surface to build on
-- @param center : The position to build at
-- @param newarea : blueprint to build
local function AplyBlueprintManualy(surface, center, newarea)

end



--
-- EVENTS
--

-- force unlock chunk event
local function UnlockChunkEvent()
	if global.ZADV_ForceUnlock then
		global.ZADV_InProcess = false
		global.ZADV_ForceUnlock = false
		debug("ForceUnlock")
	end
end

--- new chunk generated event handler
local function GenerateChunkArea( event )
	
	-- Initialized ?
	if not ZADV_initialized then return false end
	
	local skipgeneration = false
	
	-- on chunk charted
	if event.surface_index then
		skipgeneration = true
	end
	
	-- skip generation this time
	if skipgeneration then return true end
	
	-- event lock
	if global.ZADV_InProcess then return
	else global.ZADV_InProcess = true end
	
	-- variables
	local position = Area.center(event.area)
	local chunk_position = Chunk.from_position(position)
	local chunk_data = Chunk.get_data(event.surface, chunk_position) or {}
	
	-- check if chunk already charted
	if game.forces['neutral'].is_chunk_charted(event.surface, chunk_position) then
		debug("Chunk [%s] already charted.",serpent.block(chunk_position))
		return
	end
	
	-- check collisions and if true - ignore chunk
	if CollisionCheckArea(event.surface, event.area) then 
		chunk_data["generated"] = true
		--ZADV_ForcedArea = true
	end
	
	-- check if chunk already generated or in starting area - ignore if true
	if chunk_data["generated"] or isInsideBounds(position, ZADV.Settings['zadv_starting_radiius']) then
		-- event unlock and exit
		global.ZADV_InProcess = false
		Chunk.set_data(event.surface, chunk_position, chunk_data)
		return
	end
	
	-- get random area
	local newarea = GetRandomArea(position)
	
	-- if we get one...
	if newarea and not isInsideBounds(position, newarea.remoteness_min)
	and ( newarea.remoteness_max == 0 or isInsideBounds(position, newarea.remoteness_max) )
	then
				
		-- check area size
		if newarea.area.size.x > 32 or newarea.area.size.y > 32 then
			
			script.on_nth_tick(game.tick + 300, UnlockChunkEvent)
			global.ZADV_ForceUnlock = true
			
			local chunk = { ["generated"] = true }
			
			-- apply offset to x
			if position.x < 0 then position.x = position.x - 16
			else position.x = position.x + 16 end
			
			-- apply offset to y
			if position.y < 0 then position.y = position.y - 16
			else position.y = position.y + 16 end
			
			-- calculate new area box
			newarea.bigchunkarea = {
				left_top={x = position.x-32, y = position.y-32},
				right_bottom={x = position.x+32, y = position.y+32}
			}
			
			-- mark chunks as generated
			Chunk.set_data(event.surface, Chunk.from_position(Position.offset(position, 16, 16)), chunk)
			Chunk.set_data(event.surface, Chunk.from_position(Position.offset(position, -16, 16)), chunk)
			Chunk.set_data(event.surface, Chunk.from_position(Position.offset(position, 16, -16)), chunk)
			Chunk.set_data(event.surface, Chunk.from_position(Position.offset(position, -16, -16)), chunk)
			
			-- re-check collisions
			if CollisionCheckArea(event.surface, newarea.bigchunkarea) then
				-- mark chunk
				chunk_data["generated"] = true
				Chunk.set_data(event.surface, chunk_position, chunk_data)
				return
			end
		
		end
		
		-- let's build it
		newarea.chunkarea = event.area
		AplyBlueprintAuto(event.surface, position, newarea)
		
		-- mark chunk
		chunk_data["generated"] = true
		Chunk.set_data(event.surface, chunk_position, chunk_data)
	
	end
	
	-- event unlock
	if not global.ZADV_ForceUnlock then global.ZADV_InProcess = false end
	
end

--- new chunk generation delayed start
local function DelayedGenerateChunkArea( event )
	script.on_nth_tick(game.tick+1, function() GenerateChunkArea( event ) end)
end


script.on_init(Init)
script.on_event(defines.events.on_tick, Global_Handler)
script.on_event(defines.events.on_chunk_generated, GenerateChunkArea)
--script.on_event(defines.events.on_chunk_charted, GenerateChunkArea)
--script.on_event(defines.events.on_chunk_generated, DelayedGenerateChunkArea)


--
-- Script commands
--

remote.add_interface("ZADV", {

	-- /c remote.call("ZADV", "debug_lvl", 0)
	debug_lvl = function(lvl)
		
		if not lvl then lvl = 0 end
		if type(lvl) == 'string' then lvl = tonumber(lvl) end
		if type(lvl) == 'number' then
			lvl = math.min(3,math.max(0,lvl))
			if ZADV.debug ~= lvl then game.print("Debug level set to "..lvl) end
			ZADV.debug = lvl
			debug("Debug level set to "..lvl)
		else
			game.print("Incorrect 3rd argument, number expected")
		end
		
	end,

	-- /c remote.call("ZADV", "force_reveal", true)
	force_reveal = function(state)
		ZADV.force_reveal = state
		game.print("Force reveal = ".. tostring(state))
	end,
})

