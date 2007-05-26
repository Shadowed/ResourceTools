if( GetLocale() ~= "deDE" ) then
	return;
end

ResourceToolsLocals = setmetatable( {
}, { __index = ResourceToolsLocals } );