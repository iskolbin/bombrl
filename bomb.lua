local assets = require('assets')
local unpack = table.unpack or unpack

local bomb = {
	DIRECTIONS = {
		{-1, 0, 'left' },
		{ 1, 0, 'right' },
		{ 0,-1, 'up' },
		{ 0, 1, 'down' },
	},
}

bomb.DIRECTIONS_AND_NONE = {{ 0, 0,'none'}, unpack( bomb.DIRECTIONS )}

local symbol2enemy = {}

local BOMB_DELAY = 4000
local PLAYER_DELAY = 500

function bomb.init()
	for _, enemy in pairs( assets.enemies ) do
		symbol2enemy[enemy.symbol] = enemy
	end
end

function bomb.loadlevel( level )
	local tiles = {}
	local enemies = {}
	local playerpos = {1,1}
	local actions = require('libs.binaryheap.IndirectBinaryMinHeap')()
	
	for y, line in ipairs( level.tiles ) do
		local x = 0
		tiles[y] = {}
		for ch in string.gmatch( line, '.' ) do
			x = x + 1
			if ch == '#' or ch == ' ' or ch == '*' then
				tiles[y][x] = ch
			elseif ch == '@' then
				playerpos = {y = y, x = x}
				tiles[y][x] = ' '
			elseif symbol2enemy[ch] then
				local prototype = symbol2enemy[ch]
				enemies[#enemies+1] = {
					x = x,
					y = y,
					hp = prototype.hp,
					prototype = prototype,
					direction = bomb.DIRECTIONS[math.random(#bomb.DIRECTIONS)],
					enemy = true,
				}
				tiles[y][x] = ' '
			else
				error(( 'Unknown character at row %d column %d: %q' ):format( y, x, ch ))
			end
		end
	end

	return {
		actions = actions,
		level = level,
		tiles = tiles,
		enemies = enemies,
		playerpos = playerpos,
	}
end

function bomb.newgame()
	local level = bomb.loadlevel( assets.levels.level1 )
	local state = {
		time = 0,
		level = level,
		player = {
			player = true,
			x = level.playerpos.x,
			y = level.playerpos.y,
			lives = 3,
			range = 1,
			bombs = 1,
			speed = 1,
		},
		log = {},
		explossions = {},
	}

	level.actions:enqueue( state.player, 0 )

	for _, enemy in pairs( level.enemies ) do
		level.actions:enqueue( enemy, enemy.prototype.delay )
	end

	return state
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
		for i, e in pairs( state.level.enemies ) do
			if e == enemy then
				table.remove( state.level.enemies, i )
			end
		end
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
	for _, e in pairs( state.level.enemies ) do
		if e.x == x and e.y == y then
			state.player.killed = true
		end
	end
end

local function doenemyactions( state, enemy )
	bomb.log( state, 'do actions for enemy' )

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

local function dobombexplosion( state, bomb_ )
	bomb.log( state, 'do bomb explossion' )
	local x, y, range = bomb_.x, bomb_.y, bomb_.range
	for _, dxdy in pairs( bomb.DIRECTIONS_AND_NONE ) do
		local dx, dy = dxdy[1], dxdy[2]
		for i = 1, bomb_.range do
			local x_, y_ = x + i*dx, y + i*dy
			local ch = bomb.getch( state, x_, y_ )
			if ch == '#' then 
				break
			elseif ch == '*' or ch == 'o' then
				bomb.setch( state, x_, y_, ' ' )
				addexplossion( state, x_, y_ )
				if ch == '*' then break end
			end
			
			for _, enemy in pairs( state.level.enemies ) do
				if enemy.x == x_ and enemy.y == y_ then
					enemy.killed = true
				end
			end
		
			if state.player.x == x_ and state.player.y == y_ then
				state.player.killed = true
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
		elseif action.player then
			if action.killed then
				state.player.lives = state.player.lives - 1
				action.killed = false
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


function bomb.moveplayer( state, dx, dy )
	if bomb.iswalkable( state, state.player.x + dx, state.player.y + dy ) then
		state.player.x = state.player.x + dx
		state.player.y = state.player.y + dy
		updatecollidefoes( state )
	end
end

function bomb.placebomb( state )
	local x, y = state.player.x, state.player.y
	local ch = bomb.getch( state, x, y )
	if ch ~= 'o' then
		bomb.setch( state, x, y, 'o' )
		state.level.actions:enqueue( {bomb = true, x = x, y = y, range = state.player.range}, state.time + BOMB_DELAY )
	end
end

return bomb
