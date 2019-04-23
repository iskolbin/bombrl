local R = require('raylib')
local bomb = require('bomb')

local CELL_SIZE = 32
local FONT_SIZE = 32

bomb.init()

local active = true

local function onkey( state )
	if R.IsKeyDown(R.KEY_LEFT) then
		bomb.moveplayer( state, -1, 0 )
	elseif R.IsKeyDown(R.KEY_RIGHT) then
		bomb.moveplayer( state, 1, 0 )
	elseif R.IsKeyDown(R.KEY_UP) then
		bomb.moveplayer( state, 0, -1 )
	elseif R.IsKeyDown(R.KEY_DOWN) then
		bomb.moveplayer( state, 0, 1 )
	elseif R.IsKeyDown(R.KEY_SPACE) then
		bomb.placebomb( state )
	end
end

local function update( state )
	onkey( state )
	bomb.updatestate( state )
end

local WHITE = R.Color( 255, 255, 255, 255 )
local RED = R.Color( 255, 0, 0, 255 )
local GREEN = R.Color( 0, 255, 0, 255 )
local GRAY = R.Color( 127, 127, 127, 255 )
local ORANGE = R.Color( 255, 127, 0, 255 )
local YELLOW = R.Color( 255, 255, 0, 255 )

local function setcell( ch, x, y, color )
	R.DrawText( ch, x*CELL_SIZE, y*CELL_SIZE, FONT_SIZE, color )
end

local function settext( str, x, y, color )
	R.DrawText( str, x*CELL_SIZE, y*CELL_SIZE, FONT_SIZE, color )
end

local function render( state )
	if state.endgame then
		if state.player.lives > 0 then
			settext( 'THE WINNAR ARE YOU', 1, 1, WHITE )
		else
			settext( 'THE LOSAR ARE YOU', 1, 1, WHITE )
		end
		settext( 'SCORE ' .. state.player.score, 1, 2, WHITE )
		return
	end
	for y, line in ipairs( state.level.tiles ) do
		for x, ch in ipairs( line ) do
			local color
			if ch == '*' then
				color = WHITE
			elseif ch:byte() >= 97 and ch:byte() <= 122 then
				color = GREEN
			else
				color = GRAY
			end
			setcell( ch, x-1, y-1, color )
		end
	end
	setcell( '@', state.player.x-1, state.player.y-1, RED )
	for enemy, _ in pairs( state.level.enemies ) do
		if not enemy.killed then
			setcell( enemy.prototype.symbol, enemy.x-1, enemy.y-1, YELLOW )
		end
	end
	for i = 0, 10 do
		local msg = state.log[#state.log-i]
		if msg then
			luabox.print( msg, 40, i, GRAY )
		else
			break
		end
	end
	for _, explossion in pairs( state.explossions ) do
		setcell( '*', explossion.x-1, explossion.y-1, ORANGE )
	end
	settext( ('SCORE %d\nLIVES %d\nBOMBS %d\nRANGE %d\nSPEED %d'):format( state.player.score, state.player.lives, state.player.bombs, state.player.range, state.player.speed ), 0, 14, WHITE ) 
end


local state = bomb.newgame()

R.InitWindow( 800, 480, 'BombRL' )
R.SetTargetFPS( 16 )
while not R.WindowShouldClose() do
	R.BeginDrawing()
	do
		R.ClearBackgroundU(0, 0, 0, 255)
		update( state )
		render( state )
		bomb.clearexplossions( state )
	end
	R.EndDrawing()
end

R.CloseWindow()
