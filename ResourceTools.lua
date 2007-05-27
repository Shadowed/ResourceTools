RT = DongleStub("Dongle-1.0"):New( "RT" );

local L = ResourceToolsLocals;

function RT:Enable()
	self.defaults = {
		profile = {
		}
	}
	
	self.db = self:InitializeDB( "ResourceToolsDB", self.defaults )
	self.cmd = self:InitializeSlashCommand( L["ResourceTools Slash Commands"], "ResourceTools", "resourcetools", "rt" );
	self.cmd:RegisterSlashHandler( L["/rt mem <name> - Lists memory usage of the specified addon"], "mem (%S+)", "GetMemUsage" );	
	self.cmd:RegisterSlashHandler( L["/rt cpu - Toggles CPU usage on and off"], "cpu", "ToggleCPU" );
	self.cmd:RegisterSlashHandler( L["/rt reset - Resets CPU stats"], "reset", "ResetCPU" );
	self.cmd:RegisterSlashHandler( L["/rt total <addon> - Total CPU usage of the specified addon"], "total (%S+)", "GetTotalCPU" );
	self.cmd:RegisterSlashHandler( L["/rt func <name> <true/false> - CPU usage on the specified function, second argument is to include subroutines."], "func (%S+) (%S+)", "GetFunctionCPU" );
	self.cmd:RegisterSlashHandler( L["/rt event <name> or all - Event names to register CPU usage for, you can specify multiple ones with a comma, or use \"all\" for a total based on all events."], "event (.+)", "GetEventCPU" );
	
	
	if( not RTEvents ) then
		RTEvents = {};
		
		if( DevTools_Events ) then
			RTEvents = DevTools_Events;
			RTEvents[" _Stop"] = nil;
			RTEvents[" _OnUpdate"] = nil;
			RTEvents[" _Start"] = nil;
		end
	end
	
	if( not self.frame ) then
		self.frame = CreateFrame( "Frame" );
		self.frame:SetScript( "OnEvent", self.CheckEvents );
		self.frame:RegisterAllEvents();
	end
end

--[[
Memory Profiling 
* Script memory is now tracked on a per-addon basis, with functions provided to analyze and query usage. 
* The script memory manager has been optimized and the garbage collection tuned so there is no longer any need for a hard cap on the amount of UI memory available. 
* NEW - UpdateAddOnMemoryUsage() - Scan through memory profiling data and update the per-addon statistics 
* NEW - usedKB = GetAddOnMemoryUsage(index or "name") - query an addon's memory use (in K, precision to 1 byte) - This returns a cached value calculated by UpdateAddOnMemoryUsage(). 

CPU Profiling 
* CPU profiling is disabled by default since it has some overhead. CPU profiling is controlled by the scriptProfile cvar, which persists across sessions, and takes effect after a UI reload. 
* When profiling is enabled, you can use the following functions to retrieve CPU usage statistics. Times are in seconds with about-a-microsecond precision: 
* NEW - time = GetScriptCPUUsage() - Returns the total timeused by the scripting system 
* NEW - UpdateAddOnCPUUsage() - Scan through the profiling data and update the per-addon statistics 
* NEW - time = GetAddOnCPUUsage(index or \"name\") - Returns the total time used by the specified AddOn. This returns a cached value calculated by UpdateAddOnCPUUsage(). 
* NEW - time, count = GetFunctionCPUUsage(function[, includeSubroutines]) - Returns the time used and number of times the specified function was called. If 'includeSubroutines' is true or omitted, the time includes both the time spent in the function and subroutines called by the function. If it is false, then time is only the time actually spent by the code in the function itself. 
* NEW - time, count = GetFrameCPUUsage(frame[, includeChildren]) - Returns the time used and number of function calls of any of the frame's script handlers. If 'includeChildren' is true or omitted, the time and call count will include the handlers for all of the frame's children as well. 
* NEW - time, count = GetEventCPUUsage(["event"]) - Returns the time used and number of times the specified event has been triggered. If 'event' is omitted, the time and count will be totals across all events. 
* NEW - ResetCPUUsage() - Reset all CPU profiling statistics to zero. ]]

function RT:CheckEvents( event )
	if( not RTEvents[ event ] ) then
		RTEvents[ event ] = true;
	end
end

function RT:GetMemUsage( addon )
	UpdateAddOnMemoryUsage();
	local usedKB = GetAddOnMemoryUsage( addon );
	
	if( usedKB > 1000 ) then
		self:Print( string.format( L["%s is using %s memory."], addon, string.format( L["%.2f MB"], usedKB / 1000 ) ) );
	else
		self:Print( string.format( L["%s is using %s memory."], addon, string.format( L["%.2f KB"], usedKB ) ) );
	end
end

function RT:ResetCPU()
	if( GetCVar( "scriptProfile" ) == "0" ) then
		self:Print( L["You have to enable CPU profiling first before you can use this."] );
		return;
	end
	
	ResetCPUUsage();
	self:Print( L["All CPU profiling statistics have been reset."] );
end

function RT:ToggleCPU()
	if( GetCVar( "scriptProfile" ) == "1" ) then
		SetCVar( "scriptProfile", "0", 1 );
		self:Print( L["CPU Profiling is now disabled, you will need to do a reloadui for this to take effect."] );	
	else
		SetCVar( "scriptProfile", "1", 1 );
		self:Print( L["CPU Profiling is now enabled, you will need to do a reloadui for this to take effect."] );
	end
end

function RT:GetTotalCPU( addon )
	if( GetCVar( "scriptProfile" ) == "0" ) then
		self:Print( L["You have to enable CPU profiling first before you can use this."] );
		return;
	end

	UpdateAddOnCPUUsage();
	self:Echo( string.format( L["%s: %.3f seconds."], addon, GetAddOnCPUUsage( addon ) ) );
end

function RT:GetFunctionCPU( text, includeSub )
	if( GetCVar( "scriptProfile" ) == "0" ) then
		self:Print( L["You have to enable CPU profiling first before you can use this."] );
		return;
	end
	
	UpdateAddOnCPUUsage();
	
	local usedSubs;
	if( includeSub == "true" ) then
		usedSubs = L["included"];
		includeSub = true;
	else
		usedSubs = L["skipped"];
		includeSub = nil;
	end
	
	if( string.match( text, "%." ) ) then
		local namespaceName, func = string.split( ".", text );
		local namespace = getglobal( namespaceName );
		
		if( not namespace ) then
			self:Print( string.format( L["Cannot find the namespace %s."], namespaceName ) );
			return;
		elseif( not namespace[ func ] ) then
			self:Print( string.format( L["Cannot find the function %s inside the namespace %s."], func, namespaceName ) );
			return;
		end
		
		
		local seconds, called = GetFunctionCPUUsage( namespace[ func ], includeSub );

		if( called > 0 ) then
			self:Print( string.format( L["%s (subroutines %s) took %.3f seconds, called %d times, average %.3f."], text, usedSubs, seconds, called, seconds / called ) );
		else
			self:Print( string.format( L["%s, no function calls found."], text ) );
		end
	else
		local func = getglobal( text );
		if( not func ) then
			self:Print( string.format( L["Cannot find the function %s."], text ) );
			return;
		end
		
		local seconds, called = GetFunctionCPUUsage( func, includeSub );

		if( called > 0 ) then
			self:Print( string.format( L["%s (subroutines %s) took %.3f seconds, called %d times, average %.3f."], text, usedSubs, seconds, called, seconds / called ) );
		else
			self:Print( string.format( L["%s, no function calls found."], text ) );
		end
	end
end

function RT:GetEventCPU( text )
	if( GetCVar( "scriptProfile" ) == "0" ) then
		self:Print( L["You have to enable CPU profiling first before you can use this."] );
		return;
	end
		
	UpdateAddOnCPUUsage();
	
	local seconds, called;

	if( text ~= "all" ) then
		for _, event in pairs( { string.split( ",", ( string.gsub( text, " ", "" ) ) ) } ) do
			seconds, called = GetEventCPUUsage( event );
			
			if( called > 0 ) then
				self:Echo( string.format( L["%s: %.3f seconds, called %d times, %.3f average."], event, seconds, called, seconds / called ) );
			else
				self:Echo( string.format( L["%s: no events by this name have been triggered."], event ) );
			end
		end
	else
		seconds, called = GetEventCPUUsage();
		
		self:Echo( string.format( L["%s: %.3f seconds, called %d times, %.3f average."], L["All Events"], seconds, called, seconds / called ) );
	end
end