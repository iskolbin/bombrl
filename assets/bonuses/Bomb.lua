return {
	name = 'Bomb',
	symbol = 'b',
	apply = function( state )
		state.player.bombs = state.player.bombs + 1
	end,
}
