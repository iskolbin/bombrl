local assets = require('assets')
local unpack = table.unpack or unpack
local PriorityQueue = require('libs.priorityqueue.PriorityQueue')

local bomb = {
	DIRECTIONS = {
		{-1, 0, 'left' },
		{ 1, 0, 'right' },
		{ 0,-1, 'up' },
		{ 0, 1, 'down' },
	},
}

local RESERVED_SYMBOLS = {
	[' '] = true,
	['>'] = true,
}

local function cachesymbolmt( name )
	return { __index = function( self, k )
		if RESERVED_SYMBOLS[k] then
			return nil
		end
		local item = assets[name][k]
		rawset( self, item.symbol, item )
		return item
	end }
end

local symbol2enemy = setmetatable( {}, cachesymbolmt( 'enemies' ))
local symbol2bonus = setmetatable( {}, cachesymbolmt( 'bonuses' ))

bomb.symbol2enemy = symbol2enemy
bomb.symbol2bonus = symbol2bonus

local BOMB_DELAY = 4000
local PLAYER_DELAY = 500

function bomb.init()
end

local function genlevel( level )
	local w, h, density = level.width, level.height, level.density
	local tiles = {}
	local top, free, bottom = {}, {}, {}
	for x = 1, w do
		top[x], free[x], bottom[x] = '#', ' ', '#'
	end
	for x = 4, w do
		free[x] = (math.random()>level.density) and ' ' or '*'
	end
	free[1], free[w] = '#', '#'
	tiles[#tiles+1] = top
	tiles[#tiles+1] = free
	for y = 2, h-1, 2 do
		local walled, free = {}, {}
		walled[1], free[1] = '#', '#'
		for x = 2, w-1 do
			walled[x] = (x % 2) == 1 and '#' or (math.random()>level.density) and ' ' or '*'
			free[x] = (math.random()>level.density) and ' ' or '*'
		end
		walled[w], free[w] = '#', '#'
		tiles[#tiles+1] = walled
		tiles[#tiles+1] = free
	end
	tiles[3][2] = ' '
	tiles[#tiles+1] = bottom
	return tiles
end

local function genenemies( level, tiles )
	local enemies = {}
	local w, h, density = level.width, level.height, level.density
	for e, count in pairs( level.enemies ) do
		for i = 1, count do
			local x, y = math.random( 2, w-1 ), math.random( 2, h-1 )
			while tiles[y][x] ~= ' ' and tiles[y][x] ~= '*' and (x < 5 and y < 5) do
				x, y = math.random( 2, w-1 ), math.random( 2, h-1 )
			end
			tiles[y][x] = ' '
			local prototype = assets.enemies[e]
			symbol2enemy[prototype.symbol] = prototype
			local enemy = {
				x = x,
				y = y,
				hp = prototype.hp,
				prototype = prototype,
				direction = bomb.DIRECTIONS[math.random(#bomb.DIRECTIONS)],
				enemy = true,
			}
			enemies[enemy] = true
		end
	end
	return enemies
end

function bomb.loadlevel( level )
	local tiles = {}
	local enemies = {}
	local bonuses = {}
	local actions = PriorityQueue()

	local tiles = genlevel( level )
	local enemies = genenemies( level, tiles )
	
	for bonus, count in pairs( level.bonuses ) do
		for i = 1, count do
			local prototype = assets.bonuses[bonus]
			bonuses[#bonuses+1] = prototype
			symbol2bonus[prototype.symbol] = prototype
		end
	end

	return {
		actions = actions,
		bonuses = bonuses,
		level = level,
		tiles = tiles,
		enemies = enemies,
		playerpos = {x = 2, y = 2},
	}
end

function bomb.newlevel( levelname, player )
	local level = bomb.loadlevel( assets.levels[levelname] )
	player.x, player.y = level.playerpos.x, level.playerpos.y
	local state = {
		time = 0,
		level = level,
		player = player,
		placedbombs = 0,
		log = {},
		explossions = {},
	}

	level.actions:enqueue( state.player, 0 )

	for enemy, _ in pairs( level.enemies ) do
		level.actions:enqueue( enemy, enemy.prototype.delay ) 
	end

	return state
end

function bomb.newgame()
	local player = {
		player = true,
		x = 2,
		y = 2,
		lives = 3,
		range = 1,
		bombs = 1,
		speed = 1,
		score = 0,
	}
	return bomb.newlevel( 'level1', player )
end

function bomb.log( state, msg )
	table.insert( state.log, msg )
end

function bomb.getwalkabledirs( state, x, y )
	local dirs = {}
	for _, dir in pairs( bomb.DIRECTIONS ) do
		if bomb.iswalkable( state, x+dir[1], y+dir[2] ) then 
			dirs[#dirs+1] = dir
		end
	end
	return dirs
end

function bomb.getrandomdirs( state )
	return bomb.DIRECTIONS
end

local function updatealive( state, enemy )
	if enemy.killed then
		state.level.enemies[enemy] = nil
		return false
	end

	return true
end

local function updatecollideenemy( state, enemy )
	local x, y = state.player.x, state.player.y
	if enemy.x == x and enemy.y == y then
		state.player.killed = true
	end
end

local function updatecollidefoes( state )
	local x, y = state.player.x, state.player.y
	for e, _ in pairs( state.level.enemies ) do
		if e.x == x and e.y == y then
			state.player.killed = true
		end
	end
end

local function doenemyactions( state, enemy )
	local x, y = enemy.x + enemy.direction[1], enemy.y + enemy.direction[2]
	if bomb.iswalkable( state, x, y ) then
		enemy.x, enemy.y = x, y
	else
		if enemy.prototype.behavior.TurnOnCollide then
			local directions = bomb.getwalkabledirs( state, enemy.x, enemy.y )
			if #directions == 0 then
				directions = bomb.getrandomdirs( state )
			end
			enemy.direction = directions[math.random(#directions)]
		end
	end
	updatecollideenemy( state, enemy )
end

local function addexplossion( state, x, y )
	table.insert( state.explossions, {x = x, y = y} )
end

function bomb.counttiles( state, tile )
	local count = 0
	for y, line in pairs( state.level.tiles ) do
		for x, ch in pairs( line ) do
			if ch == tile then
				count = count + 1
			end
		end
	end
	return count
end

local function sameplace( o1, o2 )
	return o1.x == o2.x and o1.y == o2.y
end

local function dobombexplosion( state, bomb_ )
	local x, y, range = bomb_.x, bomb_.y, bomb_.range

	addexplossion( state, x, y )
	state.player.killed = state.player.killed or sameplace( state.player, bomb )
	for enemy, _ in pairs( state.level.enemies ) do
		if not enemy.killed and sameplace( enemy, bomb ) then
			state.player.score = score.player.score + enemy.prototype.score
			enemy.killed = true
		end
	end
	bomb.setch( state, x, y, ' ' )

	local place = {x = x, y = y}
	for _, dxdy in pairs( bomb.DIRECTIONS ) do
		local dx, dy = dxdy[1], dxdy[2]
		for i = 1, bomb_.range do
			local x_, y_ = x + i*dx, y + i*dy
			local ch = bomb.getch( state, x_, y_ )
			if ch == '#' then 
				break
			elseif ch == '*' then
				bomb.setch( state, x_, y_, ' ' )
				addexplossion( state, x_, y_ )
				if ch == '*' and #state.level.bonuses > 0 or not state.level.exitfound then	
					local count = bomb.counttiles( state, '*' ) - #state.level.bonuses - (state.level.exitfound and 0 or 1)
					if math.random( count ) then
						if not state.level.exitfound and math.random() > 0.5 then
							bomb.setch( state, x_, y_, '>' )
							state.level.exitfound = true
						elseif #state.level.bonuses > 0 then
							local bonus = table.remove( state.level.bonuses, math.random(#state.level.bonuses))
							bomb.setch( state, x_, y_, bonus.symbol )
						end
					end
					break
				end
			end

			place.x, place.y = x_, y_
			state.player.killed = state.player.killed or sameplace( state.player, place )
			for enemy, _ in pairs( state.level.enemies ) do
				if not enemy.killed and sameplace( enemy, place ) then
					state.player.score = state.player.score + enemy.prototype.score
					enemy.killed = true
				end
			end

			addexplossion( state, x_, y_ )
		end
	end
end

function bomb.clearexplossions( state )
	if next( state.explossions ) then
		state.explossions = {}
	end
end

function bomb.updatestate( state )
	local actions = state.level.actions
	while not actions:empty() do
		local action, priority = actions:dequeue()
		state.time = priority
		if action.enemy then
			if updatealive( state, action ) then
				doenemyactions( state, action )
				actions:enqueue( action, state.time + action.prototype.delay )
			end
		elseif action.bomb then
			dobombexplosion( state, action )
			state.placedbombs = state.placedbombs - 1
		elseif action.player then
			if action.killed then
				state.player.lives = state.player.lives - 1
				action.killed = false
				if state.player.lives <= 0 then
					state.endgame = true
				end
			end
			actions:enqueue( action, state.time + PLAYER_DELAY )
			break
		end
	end
end

function bomb.getch( state, x, y )
	return state.level.tiles[y][x]
end

function bomb.setch( state, x, y, ch )
	local tiles = state.level.tiles
	if not tiles[y] or not tiles[y][x] then
		error( ('Out of bounds: %d, %d'):format( x, y ))
	end
	tiles[y][x] = ch
end

function bomb.iswalkable( state, x, y )
	local ch = bomb.getch( state, x, y )
	return ch ~= '#' and ch ~= '*' and ch ~= 'o'
end

local function updatecollidebonus( state )
	local ch = bomb.getch( state, state.player.x, state.player.y )
	local bonus = symbol2bonus[ch]
	if bonus then
		bomb.setch( state, state.player.x, state.player.y, ' ' )
		bonus.apply( state )
	end
end

local function updatecollidexit( state )
	local ch = bomb.getch( state, state.player.x, state.player.y )
	if ch == '>' then
		if bomb.isexitworking( state ) then
			if state.level.level.next == nil then
				state.endgame = true
			else
				local newstate = bomb.newlevel( state.level.level.next, state.player )
				for k, v in pairs( newstate ) do
					state[k] = v
				end
			end
		end
	end
end

function bomb.isexitworking( state )
	return bomb.isallfoesdied( state )
end

function bomb.moveplayer( state, dx, dy )
	if bomb.iswalkable( state, state.player.x + dx, state.player.y + dy ) then
		state.player.x = state.player.x + dx
		state.player.y = state.player.y + dy
		updatecollidebonus( state )
		updatecollidefoes( state )
		updatecollidexit( state )
	end
end

function bomb.placebomb( state )
	local x, y = state.player.x, state.player.y
	local ch = bomb.getch( state, x, y )
	if ch ~= 'o' and state.placedbombs < state.player.bombs then
		bomb.setch( state, x, y, 'o' )
		state.level.actions:enqueue( {bomb = true, x = x, y = y, range = state.player.range}, state.time + BOMB_DELAY )
		state.placedbombs = state.placedbombs + 1
	end
end

function bomb.isallfoesdied( state )
	for e, _ in pairs( state.level.enemies ) do
		if not e.killed then
			return false
		end
	end
	return true
end

return bomb
