local luabox = require('luabox')
local bomb = require('bomb')

luabox.init( luabox.INPUT_CURRENT, luabox.OUTPUT_256 )

bomb.init()

local active = true

local function onkey( state, ch, key, mode )
	active = ch:lower() ~= 'q'
	if key == luabox.LEFT then
		bomb.moveplayer( state, -1, 0 )
	elseif key == luabox.RIGHT then
		bomb.moveplayer( state, 1, 0 )
	elseif key == luabox.UP then
		bomb.moveplayer( state, 0, -1 )
	elseif key == luabox.DOWN then
		bomb.moveplayer( state, 0, 1 )
	elseif key == luabox.SPACE then
		bomb.placebomb( state )
	end
end

local function update( state )
	bomb.updatestate( state )
end

local function render( state )
	if state.endgame then
		if state.player.lives > 0 then
			luabox.print( 'THE WINNAR ARE YOU', 1, 1, luabox.rgbf(1,1,1))
		else
			luabox.print( 'THE LOSAR ARE YOU', 1, 1, luabox.rgbf(1,1,1))
		end
		luabox.print( 'SCORE ' .. state.player.score, 1, 2, luabox.rgbf(1,1,1))
		return
	end
	for y, line in ipairs( state.level.tiles ) do
		for x, ch in ipairs( line ) do
			local color
			if ch == '*' then
				color = luabox.rgbf(1,1,1)
			elseif ch:byte() >= 97 and ch:byte() <= 122 then
				color = luabox.rgbf(0,1,0)
			else
				color = luabox.grayf(0.5)
			end
			luabox.setcell( ch, x-1, y-1, color )
		end
	end
	luabox.setcell( '@', state.player.x-1, state.player.y-1, luabox.rgbf(1,0,0))
	for enemy, _ in pairs( state.level.enemies ) do
		if not enemy.killed then
			luabox.setcell( enemy.prototype.symbol, enemy.x-1, enemy.y-1, luabox.rgbf(1,1,0))
		end
	end
	for i = 0, 10 do
		local msg = state.log[#state.log-i]
		if msg then
			luabox.print( msg, 40, i, luabox.grayf(1-i/10))
		else
			break
		end
	end
	for _, explossion in pairs( state.explossions ) do
		luabox.setcell( '*', explossion.x-1, explossion.y-1, luabox.rgbf(1,0.5,0))
	end
	luabox.print( ('SCORE %d\nLIVES %d\nBOMBS %d\nRANGE %d\nSPEED %d'):format( state.player.score, state.player.lives, state.player.bombs, state.player.range, state.player.speed ), 0, 14, luabox.grayf(1) ) 
end


local ok, err
local state = bomb.newgame()

luabox.setcallback( luabox.EVENT_KEY, function(...) onkey(state,...) end )

while active do
	luabox.clear()
	update( state )
	render( state )
	bomb.clearexplossions( state )
	luabox.present()
	luabox.peek()
end

luabox.shutdown()

if not ok then
	print( err )
end
