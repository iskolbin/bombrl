local rawset, setmetatable, require = _G.rawset, _G.setmetatable, _G.require

local function getcache( kgroup )
	return setmetatable( {}, { __index = function( self, kitem )
		local t = require( 'assets.' .. kgroup .. '.' .. kitem )
		rawset( self, kitem, t )
		return t
	end})
end

return setmetatable( {}, {__index = function( self, kgroup )
	local t = getcache( kgroup )
	rawset( self, kgroup, t )
	return t
end})
