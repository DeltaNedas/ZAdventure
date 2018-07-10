require 'stdlib/area/position'
require 'stdlib/area/area'
require 'stdlib/area/chunk'
require 'stdlib/area/tile'
require 'stdlib/table'
require 'stdlib/game'
require 'lib/bplib'

--
-- global variables
--
global.ZADV = global.ZADV or {}
ZADV = global.ZADV or {}
ZADV.Data = global.ZADV.Data
global.ZADV_InProcess = false
global.ZADV_ForceUnlock = false


--
-- local variables
--
local format = string.format
local floor = math.floor

ZADV_initialized = false
ZADV_ForcedArea = false

Color = {
	red 	= {r = 1, g = 0, b = 0, a = 0.5},
	green 	= {r = 0, g = 1, b = 0, a = 0.5}
}


--
-- debug settings
--
ZADV.debug = 0

function debug ( msg, ... )
	if type(msg) == 'table' then
		if ZADV.debug >= 1 then
		log("\n[[ZADV]] ".. serpent.block(msg))
		end
	else
		if type(msg) ~= 'string' then
			msg = tostring(msg)
		end
		log("[[ZADV]] ".. format(msg,...))
		if ZADV.debug >= 2 and game and string.len(msg) <= 200 then
			game.print(format(msg,...))
		end
	end
end


--
-- Initialization
--

--- Prepare operable blueprint
function PrepareBlueprint()
	
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
		
		global.ZADV.blueprint = ZADV.entity.get_inventory(defines.inventory.chest).find_item_stack("blueprint")
		debug("Creating operable blueprint")
		
	end
	
end

--- Post initialization
local function PostInit()
	
	-- skip if already done
	if ZADV_initialized then return end
	
	-- creating blueprint instance
	PrepareBlueprint()
	
	-- localize globals
	ZADV.blueprint = global.ZADV.blueprint
	ZADV.Data = global.ZADV.Data
	ZADV.NamePairList = global.ZADV.NamePairList
	ZADV.Settings = global.ZADV.Settings
	global.ZADV.UsedTypes = global.ZADV.UsedTypes or {}
	ZADV.UsedTypes = global.ZADV.UsedTypes
	ZADV.debug = global.ZADV.debug
	debug("Set debug level: ".. ZADV.debug)
		
	-- debug dependings
	if ZADV.debug >= 2 then
		BPlib.chunkMarkerArray = BPlib.ParseToArray(BPlib.chunkMarker)
		debug("Prepare Chunk Marker Array")
	end
	
	-- globals
	global.generator = game.create_random_generator(game.tick)
		
	-- Done
	ZADV_initialized = true
	debug("Initialization complete.")
	
end

--- Global initialization
function Init()
	
	-- creating blueprint instance
	PrepareBlueprint()
	
	
	--parse raw data
	local dump, sdump, ndump = "", "", ""
	local chunks = game.entity_prototypes["ZADV_DATA_C"].order
	local schunks = game.entity_prototypes["ZADV_SDATA_C"].order
	local nchunks = game.entity_prototypes["ZADV_NDATA_C"].order
	global.ZADV.ControlString = game.entity_prototypes["ZADV_DATA_MD"].order
	global.ZADV.debug = tonumber(game.entity_prototypes["ZADV_DATA_D"].order)
	
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
	global.ZADV.Data = loadstring(dump)() or {}
	global.ZADV.Settings = loadstring(sdump)() or {}
	global.ZADV.NamePairList = loadstring(ndump)() or {}
	debug("Raw data requested.")
	
	
	-- localize globals
	PostInit()
	
end

--- New data re-initialization
local function ReInit()
	
	--parse raw data
	local dump, sdump, ndump = "", "", ""
	local chunks = game.entity_prototypes["ZADV_DATA_C"].order
	local nchunks = game.entity_prototypes["ZADV_NDATA_C"].order
	global.ZADV.debug = tonumber(game.entity_prototypes["ZADV_DATA_D"].order)
	global.ZADV.ControlString = game.entity_prototypes["ZADV_DATA_MD"].order
	
	for i=0, chunks-1 do
		local name = "ZADV_DATA_"..i
		dump = dump .. game.entity_prototypes[name].order
	end
	
	for i=0, nchunks-1 do
		local name = "ZADV_NDATA_"..i
		ndump = ndump .. game.entity_prototypes[name].order
	end
	
	-- apply parsed data
	global.ZADV.Data = loadstring(dump)() or {}
	global.ZADV.NamePairList = loadstring(ndump)() or {}
	debug("New raw data requested.")
	
	-- localize globals
	ZADV.Data = global.ZADV.Data
	ZADV.NamePairList = global.ZADV.NamePairList
	global.ZADV.UsedTypes = global.ZADV.UsedTypes or {}
	ZADV.UsedTypes = global.ZADV.UsedTypes
	ZADV.debug = global.ZADV.debug
	debug("Set debug level: ".. ZADV.debug)
	
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

--- Check if position inside restrcted area
-- @param remoteness : distance from starting point in chunks
-- @param position : {x,y} array current position
-- @return true if the position inside restrcted area, false otherwise
local function isRestrictedPosition( remoteness, position )
	return Area.inside(Area.expand(Area.construct(0,0,0,0), remoteness*32), position)
end

--- Collision check on surface in selected area
-- @param surface : LuaSurface instance
-- @param area : BoundingBox {left_top :: Position, right_bottom :: Position}
-- @return true if area have collision tles, false otherwise
local function CollisionCheckArea(surface, area)
	local types = {"unit", "unit-spawner", "corpse", "simple-entity", "container", "resource"}
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
	adseed = adseed or 0
	global.adseed = global.adseed or 2^16
	global.adseed = global.adseed + adseed
	global.adseed = global.adseed > 2^31 and 1 or global.adseed
	local seed = game.tick + floor(tonumber(tostring({}):sub(8,-4))) + adseed
	global.generator = global.generator or game.create_random_generator(seed)
	global.generator.re_seed(seed)
	return math.min(max, math.max(min, floor(global.generator(min, base(max+global.adseed)) % max) ) )
end

--- Generate random number
-- @param T : table
-- @return table length
local function tlength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

--- Randomize and prepare new area
-- @param seed : center of new chunk
-- @return table area data
local function GetRandomArea(seed)
	
	-- randomize global step
	local roll = Rnd(1,1000,seed)
	if not ZADV_ForcedArea and roll > tonumber(ZADV.Settings['zadv_global_frequency']) then return nil end
	
	-- run through the list of areas
	local areas = {}
	roll = Rnd(1,1000,seed)
	
	for mn,mod in pairs(ZADV.Data) do
		for an,a in pairs(mod) do
			if roll <= a.probability*10 then
			
				local techallow = false
				
				-- technology check
				if a.ignore_technologies then
					techallow = true
				elseif a.techs then
					techallow = true
					for _,f in pairs(game.forces) do
					for _,t in pairs(a.techs) do
					if not f.technologies[t].researched then
						techallow = false
					end end	end
				end
				
				-- all checks done
				if techallow then
					-- store triggered area
					table.insert(areas, {mn,an})
				else
					if not techallow then
						debug('Not enough technologies for "%s - %s", skip this time..',mn,an)
					end
				end
				
			end
	end end
	
	-- if we have multiple triggered areas - choose one
	if tlength(areas) > 0 then
		roll = (Rnd(1,100,seed) % #areas) + 1
		areas = areas[roll]
		
	-- select one if we must
	elseif ZADV_ForcedArea then
		roll = (Rnd(1,100,seed) % #ZADV.NamePairList) + 1
		areas = ZADV.NamePairList[roll]
		
	-- nothing to do
	else return false end
	
	ZADV_ForcedArea = false
	debug('New area "%s - %s"', areas[1], areas[2])
	
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
	
	-- fault check
	if not newarea or not center or not surface then return end
	
	-- prepare blueprint
	ZADV.blueprint.import_stack(newarea.bp)
	if ZADV.blueprint.is_blueprint_setup() then
		
		--[[ adapt blueprint options ]]--
		
		-- force
		if not game.forces[newarea.force] then
			if type(newarea.force) ~= 'string' then
				if #game.forces >= 62 then
					newarea.force = "neutral"
				else
					game.create_force(newarea.force)
				end
			else newarea.force = "neutral" end
		end
		
		-- direction
		if newarea.random_direction then
			newarea.direction = math.min(4,Rnd(1,5))*2-2
		else
			newarea.direction = 2
		end
		
		
		--[[ place blueprint on surface ]]--
		--debug("place bp @ %s", serpent.block(center))
		local ghosts = ZADV.blueprint.build_blueprint{
			surface=surface,
			force=game.forces[newarea.force],			-- modded
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
		
		local area2d = newarea.chunkarea
		area2d.right_bottom.x = area2d.right_bottom.x - 1
		area2d.right_bottom.y = area2d.right_bottom.y - 1
		
		local bigarea2d = newarea.bigchunkarea or false
		if bigarea2d then
			bigarea2d.right_bottom.x = bigarea2d.right_bottom.x - 1
			bigarea2d.right_bottom.y = bigarea2d.right_bottom.y - 1
		end

		if newarea.finalize_build then					-- modded
			for k,v in pairs(ghosts) do
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
				
				local entities = surface.find_entities_filtered{
					area=area,
					name=newarea.names
				}
				
				-- update used types list
				global.ZADV.UsedTypes = global.ZADV.UsedTypes or {}
				
				for _,e in pairs(entities) do
				
					-- store type for later checks
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
					if type(newarea.ScriptForEach) == 'function' then pcall(newarea.ScriptForEach, game, surface, e, newarea.names or false) end
					
				end
				
				-- Script for all entities in new area
				if type(newarea.ScriptForAll) == 'function' then pcall(newarea.ScriptForAll, game, surface, area, center, newarea.names or false, entities or false) end
				
			end
		end
		
		-- force chart area
		if newarea.force_reveal then
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
		
		
		-- erase blueprint
		ZADV.blueprint.clear()
	
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

	-- event lock
	if global.ZADV_InProcess then return
	else global.ZADV_InProcess = true end
	
	-- check new data
	if not global.ZADV.ControlString
	or game.entity_prototypes["ZADV_DATA_MD"].order ~= global.ZADV.ControlString
	then 
		game.print("[ZAdv] New or updated areas found. Start re-initialization...", Color.green)
		debug("Old seed:\t".. global.ZADV.ControlString)
		debug("New seed:\t".. game.entity_prototypes["ZADV_DATA_MD"].order)
		ReInit()
	end
	
	-- variables
	local position = Area.center(event.area)
	local chunk_position = Chunk.from_position(position)
	local chunk_data = Chunk.get_data(event.surface, chunk_position) or {}
	
	-- check collisions and if true - ignore chunk
	if CollisionCheckArea(event.surface, event.area) then 
		chunk_data["generated"] = true
		--ZADV_ForcedArea = true
	end
	
	-- check if chunk already generated or in starting area - ignore if true
	if chunk_data["generated"] or isRestrictedPosition(ZADV.Settings['zadv_starting_radiius'], position) then
		-- event unlock and exit
		global.ZADV_InProcess = false
		Chunk.set_data(event.surface, chunk_position, chunk_data)
		return
	end
	
	-- get random area
	local newarea = GetRandomArea(position.x + position.y)
	
	-- if we get one...
	if newarea and not isRestrictedPosition(newarea.remoteness, position) then
	
		-- check area size
		if newarea.area.size.x > 16 or newarea.area.size.y > 16 then
			
			script.on_nth_tick(game.tick + 300, UnlockChunkEvent)
			global.ZADV_ForceUnlock = true
			
			local chunk = { ["generated"] = true }
			
			-- apply offset to x
			if position.x < 0 then position.x = position.x - 16
			else position.x = position.x + 14 end
			
			-- apply offset to y
			if position.y < 0 then position.y = position.y - 16
			else position.y = position.y + 16 end
			
			-- calculate new area box
			newarea.bigchunkarea = {
				left_top={x = position.x-30, y = position.y-32},
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

script.on_init(Init)
script.on_nth_tick({33,666,9999}, PostInit)
script.on_event(defines.events.on_chunk_generated, 	GenerateChunkArea)

