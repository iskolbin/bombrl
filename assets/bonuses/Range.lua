return {
	name = 'Range',
	symbol = 'r',
	apply = function( state )
		state.player.range = state.player.range + 1
	end,
}
