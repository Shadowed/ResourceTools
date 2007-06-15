RT = DongleStub("Dongle-1.0"):New( "RT" );

local L = ResourceToolsLocals;
local ScriptProfiling;

local TOTAL_SCROLL_ROWS = 15;
local TOTAL_COLUMNS = 5;

function RT:Enable()
	self.defaults = {
		profile = {
			includeSub = true,
			hideInjected = true,
			hideZeroFuncs = true,
			hideZeroEvents = true,
			searchName = "",
			enteredName = "",
			searchEvent = "",
		}
	}
	
	self.db = self:InitializeDB( "ResourceToolsDB", self.defaults )
	self.cmd = self:InitializeSlashCommand( L["ResourceTools Slash Commands"], "ResourceTools", "resourcetools", "rt" );
	self.cmd:RegisterSlashHandler( L["/rt mem <name> - Lists memory usage of the specified addon"], "mem (%S+)", "GetMemUsage" );	
	self.cmd:RegisterSlashHandler( L["/rt ui - Toggles the profiling UI"], "ui", "ToggleUI" );
	self.cmd:RegisterSlashHandler( L["/rt cpu - Toggles CPU usage on and off"], "cpu", "ToggleCPU" );
	self.cmd:RegisterSlashHandler( L["/rt reset - Resets CPU stats"], "reset", "ResetCPU" );
	self.cmd:RegisterSlashHandler( L["/rt total <addon> - Total CPU usage of the specified addon"], "total (%S+)", "GetTotalCPU" );
	self.cmd:RegisterSlashHandler( L["/rt frame <name> <true/false> - CPU usage on the specified frame, second argument is to include children"], "frame (%S+) (%S+)", "GetFrameCPU" );
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
	
	if( not RTBlacklist ) then
		RTBlacklist = {};
		RTBlacklist["RegisterEvent"] = true;
		RTBlacklist["UnregisterEvent"] = true;
		RTBlacklist["UnregisterAllEvents"] = true;
		RTBlacklist["IsEventRegistered"] = true;
		RTBlacklist["RegisterMessage"] = true;
		RTBlacklist["UnregisterMessage"] = true;
		RTBlacklist["UnregisterAllMessages"] = true;
		RTBlacklist["TriggerMessage"] = true;
		RTBlacklist["IsMessageRegistered"] = true;
		RTBlacklist["EnableDebug"] = true;
		RTBlacklist["IsDebugEnabled"] = true;
		RTBlacklist["Print"] = true;
		RTBlacklist["PrintF"] = true;
		RTBlacklist["Debug"] = true;
		RTBlacklist["DebugF"] = true;
		RTBlacklist["Echo"] = true;
		RTBlacklist["EchoF"] = true;
		RTBlacklist["InitializeDB"] = true;
		RTBlacklist["InitializeSlashCommand"] = true;
		RTBlacklist["NewModule"] = true;
		RTBlacklist["HasModule"] = true;
		RTBlacklist["IterateModules"] = true;
	end
	
	if( not self.eventFrame ) then
		self.eventFrame = CreateFrame( "Frame" );
		self.eventFrame:SetScript( "OnEvent", function()
			if( not RTEvents[ event ] ) then
				RTEvents[ event ] = true;
			end
		end );
		self.eventFrame:RegisterAllEvents();
	end
	
	-- Very simple method of making sure CPU profiling is enabled and not
	-- just toggled on but needing a reloadui
	if( GetCVar( "scriptProfile" ) == "1" ) then
		ScriptProfiling = true;
	end
end

function RT:Disable()
	if( self.frame ) then
		self.db.profile.searchName = self.nsSearchInput:GetText();
		self.db.profile.enteredName = self.namespaceInput:GetText();
		self.db.profile.searchEvent = self.eventInput:GetText();
		
		if( not self.namespaceSubs:GetChecked() ) then
			self.db.profile.includeSub = false;		
		else
			self.db.profile.includeSub = true;
		end

		if( not self.nsHideZero:GetChecked() ) then
			self.db.profile.hideZeroFuncs = false;		
		else
			self.db.profile.hideZeroFuncs = true;
		end

		if( not self.evtHideZero:GetChecked() ) then
			self.db.profile.hideZeroEvents = false;		
		else
			self.db.profile.hideZeroEvents = true;
		end
		
		if( not self.nsHideInject:GetChecked() ) then
			self.db.profile.hideInjected = false;
		else
			self.db.profile.hideInjected = true;	
		end
	end
end

local elapsed = 0;
function RT:OnUpdate()
	elapsed = elapsed + arg1;
	
	if( elapsed >= 2 ) then
		elapsed = 0;
		RT:UpdateUI();
	end
end

function RT:SortOnClick()
	if( this.sortType ) then
		if( this.sortType ~= RT.extrasFrame.sortType ) then
			RT.extrasFrame.sortOrder = false;
			RT.extrasFrame.sortType = this.sortType;
		else
			RT.extrasFrame.sortOrder = not RT.extrasFrame.sortOrder;
		end
		
		RT:UpdateOpenPanel();
	end
end

function RT:ToggleUI()
	self:CreateUI();
	
	if( self.frame:IsVisible() ) then
		self.frame:Hide();
		self.extrasFrame:Hide();
	else
		self:UpdateUI();
	end
end

function RT:CreateUI()
	if( self.frame ) then
		return;
	end
	
	local backdrop = {	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
				tile = false,
				edgeSize = 1,
				tileSize = 5,
				insets = { left = 1, right = 1, top = 1, bottom = 1 } };
				
	self.frame = CreateFrame( "Frame", "RTProfiling", UIParent );
	self.frame:SetClampedToScreen( true );
	self.frame:SetMovable( true );
	self.frame:SetHeight( 350 );
	self.frame:SetWidth( 250 );
	self.frame:SetBackdrop( backdrop );
	self.frame:SetBackdropColor( 0, 0, 0, 1 );
	self.frame:SetBackdropBorderColor( 0.75, 0.75, 0.75, 1 );
	self.frame:SetScript( "OnUpdate", RT.OnUpdate );
	self.frame:EnableKeyboard( false );
	self.frame:Hide();

	self.extrasFrame = CreateFrame( "Frame", self.frame:GetName() .. "Extras", self.frame );
	self.extrasFrame.currentPage = "";
	self.extrasFrame:SetHeight( 350 );
	self.extrasFrame:SetWidth( 450 );
	self.extrasFrame:SetBackdrop( backdrop );
	self.extrasFrame:SetBackdropColor( 0, 0, 0, 1 );
	self.extrasFrame:SetBackdropBorderColor( 0.75, 0.75, 0.75, 1 );
	self.extrasFrame:SetPoint( "CENTER", UIParent, "CENTER", 100, 100 );
	self.extrasFrame:Hide();
	
	self.frame:SetPoint( "TOPRIGHT", self.extrasFrame, "TOPLEFT", -10, 0 );

	self.closeButton = CreateFrame( "Button", self.frame:GetName() .. "Close", self.frame, "UIPanelButtonGrayTemplate" );
	self.closeButton:SetWidth( 75 );
	self.closeButton:SetHeight( 18 );
	self.closeButton:SetText( L["Close"] );
	self.closeButton:SetScript( "OnClick", function() RT.frame:Hide(); end );
	self.closeButton:SetPoint( "BOTTOMLEFT", self.frame, "BOTTOMLEFT", 0, 2 );
	
	-- Scroll frame
	self.extrasScroll = CreateFrame( "ScrollFrame", self.extrasFrame:GetName() .. "Scroll", self.extrasFrame, "FauxScrollFrameTemplate" )
	self.extrasScroll:SetWidth( 160 );
	self.extrasScroll:SetHeight( 341 );
	self.extrasScroll:SetPoint( "TOPRIGHT", self.extrasFrame, "TOPRIGHT", -25, -5 );
	self.extrasScroll:SetScript( "OnVerticalScroll", function()
		FauxScrollFrame_OnVerticalScroll( 20, RT.UpdateOpenPanel );
	end );

	FauxScrollFrame_SetOffset( self.extrasScroll, 0 );

	local texture = self.extrasScroll:CreateTexture( self.extrasScroll:GetName() .. "ScrollUp", "ARTWORK" )
	texture:SetWidth( 31 );
	texture:SetHeight( 256 );
	texture:SetPoint( "TOPLEFT", self.extrasScroll, "TOPRIGHT", -2, 5 );
	texture:SetTexCoord( 0, 0.484375, 0, 1.0 );

	texture = self.extrasScroll:CreateTexture( self.extrasScroll:GetName() .. "ScrollDown", "ARTWORK" )
	texture:SetWidth( 31 );
	texture:SetHeight( 256 );
	texture:SetPoint( "BOTTOMLEFT", self.extrasScroll, "BOTTOMRIGHT", -2, -2 );
	texture:SetTexCoord( 0.515625, 1.0, 0, 0.4140625 );
	
	-- Overall memory/CPU stuff
	self.overallText = self.frame:CreateFontString( self.frame:GetName() .. "Overall", "BACKGROUND" );
	self.overallText:SetFont( ( GameFontNormalSmall:GetFont() ), 13 );
	self.overallText:SetTextColor( 1, 1, 1 );
	self.overallText:SetPoint( "TOPLEFT", self.frame, "TOPLEFT", 4, -10 );
	self.overallText:SetText( L["Overall Usage"] );
	
	self.overallView = CreateFrame( "Button", self.frame:GetName() .. "ViewOverall",  self.frame, "UIPanelButtonGrayTemplate" );
	self.overallView:SetPoint( "TOPRIGHT", self.frame, "TOPRIGHT", -5, -8 );
	self.overallView:SetText( L["View"] );
	self.overallView:SetWidth( 75 );
	self.overallView:SetHeight( 18 );
	self.overallView:SetFont( ( self.overallView:GetFont() ), 10 );
	self.overallView:SetScript( "OnClick", self.ShowOverallUsage );
	
	self.overallMemory = self.frame:CreateFontString( self.frame:GetName() .. "OverallMemory", "BACKGROUND" );
	self.overallMemory:SetFontObject( GameFontNormalSmall );
	self.overallMemory:SetPoint( "TOPLEFT", self.overallText, "TOPLEFT", 0, -20 );

	self.overallCPU = self.frame:CreateFontString( self.frame:GetName() .. "OverallCPU", "BACKGROUND" );
	self.overallCPU:SetFontObject( GameFontNormalSmall );
	self.overallCPU:SetPoint( "TOPLEFT", self.overallMemory, "TOPLEFT", 0, -15 );

	self.overallEvent = self.frame:CreateFontString( self.frame:GetName() .. "OverallEvent", "BACKGROUND" );
	self.overallEvent:SetFontObject( GameFontNormalSmall );
	self.overallEvent:SetPoint( "TOPLEFT", self.overallCPU, "TOPLEFT", 0, -15 );
	
	-- Namespace profiling
	self.namespaceText = self.frame:CreateFontString( self.frame:GetName() .. "Namespace", "BACKGROUND" );
	self.namespaceText:SetFont( ( GameFontNormalSmall:GetFont() ), 13 );
	self.namespaceText:SetTextColor( 1, 1, 1 );
	self.namespaceText:SetPoint( "TOPLEFT", self.overallEvent, "TOPLEFT", 0, -36 );
	self.namespaceText:SetText( L["Namespace Profiling"] );
	
	self.namespaceView = CreateFrame( "Button", self.frame:GetName() .. "ViewNamespace",  self.frame, "UIPanelButtonGrayTemplate" );
	self.namespaceView:SetPoint( "TOPRIGHT", self.overallView, "TOPRIGHT", 0, -87 );
	self.namespaceView:SetText( L["View"] );
	self.namespaceView:SetWidth( 75 );
	self.namespaceView:SetHeight( 18 );
	self.namespaceView:SetFont( ( self.namespaceView:GetFont() ), 10 );
	self.namespaceView:SetScript( "OnClick", self.ShowNamespaceProfile );

	self.nsSearchText = self.frame:CreateFontString( self.frame:GetName() .. "NSSearchText", "BACKGROUND" );
	self.nsSearchText:SetFontObject( GameFontNormalSmall );
	self.nsSearchText:SetPoint( "TOPLEFT", self.namespaceText, "TOPLEFT", 0, -28 );
	self.nsSearchText:SetText( L["Search"] );
		
	self.nsSearchInput = CreateFrame( "EditBox", self.frame:GetName() .. "NSSearchInput", self.frame, "InputBoxTemplate" ); 
	self.nsSearchInput:SetHeight( 18 );
	self.nsSearchInput:SetWidth( 150 );
	self.nsSearchInput:SetAutoFocus( false );
	self.nsSearchInput:SetText( self.db.profile.searchName );
	self.nsSearchInput.blockShow = true;
	self.nsSearchInput:SetScript( "OnTextChanged", self.ShowNamespaceProfile );
	self.nsSearchInput:ClearAllPoints();
	self.nsSearchInput:SetPoint( "BOTTOMRIGHT", self.nsSearchText, "TOPRIGHT", 170, -14 );
	
	self.namespaceName = self.frame:CreateFontString( self.frame:GetName() .. "NamespaceSearch", "BACKGROUND" );
	self.namespaceName:SetFontObject( GameFontNormalSmall );
	self.namespaceName:SetPoint( "TOPLEFT", self.nsSearchText, "TOPLEFT", 0, -32 );
	self.namespaceName:SetText( L["Name"] );

	self.namespaceInput = CreateFrame( "EditBox", self.frame:GetName() .. "NamespaceInput", self.frame, "InputBoxTemplate" ); 
	self.namespaceInput:SetHeight( 18 );
	self.namespaceInput:SetWidth( 150 );
	self.namespaceInput:SetAutoFocus( false );
	self.namespaceInput.blockShow = true;
	self.namespaceInput:SetScript( "OnTextChanged", self.ShowNamespaceProfile );
	self.namespaceInput:SetText( self.db.profile.enteredName );
	self.namespaceInput:ClearAllPoints();
	self.namespaceInput:SetPoint( "BOTTOMRIGHT", self.namespaceName, "TOPRIGHT", 175, -14 );
	
	self.namespaceSubs = CreateFrame( "CheckButton", self.frame:GetName() .. "NamespaceSubRout", self.frame, "OptionsCheckButtonTemplate" );
	self.namespaceSubs:SetHeight( 26 );
	self.namespaceSubs:SetWidth( 26 );
	self.namespaceSubs:SetPoint( "TOPLEFT", self.namespaceName, "TOPLEFT", 0, -20 );
	self.namespaceSubs.blockShow = self.namespaceSubs:GetChecked();
	self.namespaceSubs:SetChecked( self.db.profile.includeSub );
	self.namespaceSubs:SetScript( "OnClick", self.ShowNamespaceProfile );
	getglobal( self.namespaceSubs:GetName() .. "Text" ):SetText( L["Include subroutines"] );

	self.nsHideZero = CreateFrame( "CheckButton", self.frame:GetName() .. "NamespaceNoCall", self.frame, "OptionsCheckButtonTemplate" );
	self.nsHideZero:SetHeight( 26 );
	self.nsHideZero:SetWidth( 26 );
	self.nsHideZero:SetPoint( "TOPLEFT", self.namespaceSubs, "TOPLEFT", 0, -20 );
	self.nsHideZero:SetChecked( self.db.profile.hideZeroFuncs );
	self.nsHideZero.blockShow = self.nsHideZero:GetChecked();
	self.nsHideZero:SetScript( "OnClick", self.ShowNamespaceProfile );
	getglobal( self.nsHideZero:GetName() .. "Text" ):SetText( L["Hide uncalled functions"] );

	self.nsHideInject = CreateFrame( "CheckButton", self.frame:GetName() .. "NamespaceInject", self.frame, "OptionsCheckButtonTemplate" );
	self.nsHideInject:SetHeight( 26 );
	self.nsHideInject:SetWidth( 26 );
	self.nsHideInject:SetPoint( "TOPLEFT", self.nsHideZero, "TOPLEFT", 0, -20 );
	self.nsHideInject:SetChecked( self.db.profile.hideInjected );
	self.nsHideInject.blockShow = self.nsHideInject:GetChecked();
	self.nsHideInject:SetScript( "OnClick", self.ShowNamespaceProfile );
	getglobal( self.nsHideInject:GetName() .. "Text" ):SetText( L["Hide injected functions"] );
		
	-- Event profiling
	self.eventText = self.frame:CreateFontString( self.frame:GetName() .. "Event", "BACKGROUND" );
	self.eventText:SetFont( ( GameFontNormalSmall:GetFont() ), 13 );
	self.eventText:SetTextColor( 1, 1, 1 );
	self.eventText:SetPoint( "TOPLEFT", self.nsHideInject, "TOPLEFT", 0, -36 );
	self.eventText:SetText( L["Event Profiling"] );
	
	self.eventView = CreateFrame( "Button", self.frame:GetName() .. "ViewEvent",  self.frame, "UIPanelButtonGrayTemplate" );
	self.eventView:SetPoint( "TOPRIGHT", self.namespaceView, "TOPRIGHT", 0, -155 );
	self.eventView:SetText( L["View"] );
	self.eventView:SetWidth( 75 );
	self.eventView:SetHeight( 18 );
	self.eventView:SetFont( ( self.eventView:GetFont() ), 10 );
	self.eventView:SetScript( "OnClick", self.ShowEventProfile );

	self.eventSearch = self.frame:CreateFontString( self.frame:GetName() .. "EventSearch", "BACKGROUND" );
	self.eventSearch:SetFontObject( GameFontNormalSmall );
	self.eventSearch:SetPoint( "TOPLEFT", self.eventText, "TOPLEFT", 0, -28 );
	self.eventSearch:SetText( L["Search"] );

	self.eventInput = CreateFrame( "EditBox", self.frame:GetName() .. "EventInput", self.frame, "InputBoxTemplate" ); 
	self.eventInput:SetHeight( 18 );
	self.eventInput:SetWidth( 150 );
	self.eventInput:SetAutoFocus( false );
	self.eventInput:SetText( self.db.profile.searchEvent );
	self.eventInput.blockShow = true;
	self.eventInput:SetScript( "OnTextChanged", self.ShowEventProfile );
	self.eventInput:ClearAllPoints();
	self.eventInput:SetPoint( "BOTTOMRIGHT", self.eventSearch, "TOPRIGHT", 160, -14 );
	
	self.evtHideZero = CreateFrame( "CheckButton", self.frame:GetName() .. "EventNoCAll", self.frame, "OptionsCheckButtonTemplate" );
	self.evtHideZero:SetHeight( 26 );
	self.evtHideZero:SetWidth( 26 );
	self.evtHideZero:SetPoint( "TOPLEFT", self.eventSearch, "TOPLEFT", 0, -20 );
	self.evtHideZero:SetChecked( self.db.profile.hideZeroEvents );
	self.evtHideZero.blockShow = self.evtHideZero:GetChecked();
	self.evtHideZero:SetScript( "OnClick", self.ShowEventProfile );
	getglobal( self.evtHideZero:GetName() .. "Text" ):SetText( L["Hide uncalled events"] );
			
	-- Basic extras frame
	local button;
	for i=1, 5 do
		button = CreateFrame( "Button", self.extrasFrame:GetName() .. "SortButton" .. i, self.extrasFrame );
		button:SetScript( "OnClick", self.SortOnClick );
		button:SetHeight( 20 );
		button:SetWidth( 75 );
		button:SetTextFontObject( GameFontNormal );
	end
	
	for i=1, TOTAL_SCROLL_ROWS do
		for j=1, TOTAL_COLUMNS do
			text = self.extrasFrame:CreateFontString( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column" .. j, self.extrasFrame );
			text:SetFont( ( GameFontNormalSmall:GetFont() ), 10 );
			text:SetTextColor( 1, 1, 1 );
			text:Hide();
			
			if( i > 1 ) then
				text:SetPoint( "TOPLEFT", self.extrasFrame:GetName() .. "SortRow" .. ( i - 1 ) .. "Column" .. j, "TOPLEFT", 0, -20 );
			else
				text:SetPoint( "TOPLEFT", self.extrasFrame:GetName() .. "SortButton" .. j, "TOPLEFT", 2, -28 );
			end
		end
	end
end

function RT:UpdateUI()
	if( not self.frame ) then
		return;
	end

	self.frame:Show();
	self.extrasFrame:Show();
	
	UpdateAddOnMemoryUsage();
	UpdateAddOnCPUUsage();
	
	local totalMem = 0;

	for i=1, GetNumAddOns() do
		totalMem = totalMem + ( GetAddOnMemoryUsage( i ) );
	end

	if( totalMem > 1000 ) then
		self.overallMemory:SetText( string.format( L["Memory: %s"], string.format( L["%.2f MB"], totalMem / 1000 ) ) );
	else
		self.overallMemory:SetText( string.format( L["Memory: %s"], string.format( L["%.2f KB"], totalMem / 1000 ) ) );
	end

	if( ScriptProfiling ) then
		self.overallCPU:SetText( string.format( L["CPU: %.3f seconds"], GetScriptCPUUsage() ) );
		self.overallEvent:SetText( string.format( L["All Events: %.3f seconds, called %d"], GetEventCPUUsage() ) );
	elseif( GetCVar( "scriptProfile" ) == "1" and not ScriptProfiling ) then
		self.overallCPU:SetText( L["CPU: UI reload needed"] );
		self.overallEvent:SetText( L["All Events: UI reload needed"] );
	else
		self.overallCPU:SetText( L["CPU: Disabled"] );
		self.overallEvent:SetText( L["All Events: Disabled"] );
	end
	
	self:UpdateOpenPanel();	
end

function RT:HideAllRows()
	for i=1, TOTAL_SCROLL_ROWS do
		for j=1, TOTAL_COLUMNS do
			getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column" .. j ):Hide();
		end
	end
end

function RT:UpdateOpenPanel()
	if( RT.extrasFrame.currentPage == "namespace" ) then
		RT:ShowNamespaceProfile();
	elseif( RT.extrasFrame.currentPage == "event" ) then
		RT:ShowEventProfile();
	else
		RT:ShowOverallUsage();
	end
end

function RT:UIError( ... )
	self:HideAllRows()
	
	local column;
	for i=1, select( "#", ... ) do
		if( i <= TOTAL_SCROLL_ROWS ) then
			column = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column1" );
			column:SetText( select( i, ... ) );
			column:Show();
		end
	end
end

local function SortAddOns( a, b )
	if( not b ) then
		return false;
	end
	
	if( RT.extrasFrame.sortOrder ) then
		if( RT.extrasFrame.sortType == "name" ) then
			return ( a.name < b.name );
		elseif( RT.extrasFrame.sortType == "cpu" ) then
			return ( a.cpu < b.cpu );
		end

		return ( a.memory < b.memory );
		
	else
		if( RT.extrasFrame.sortType == "name" ) then
			return ( a.name > b.name );
		elseif( RT.extrasFrame.sortType == "cpu" ) then
			return ( a.cpu > b.cpu );
		end

		return ( a.memory > b.memory );
	end
end

function RT:ShowOverallUsage()
	local self = RT;
	
	if( self.extrasFrame.currentPage ~= "overall" ) then
		local button = getglobal( self.extrasFrame:GetName() .. "SortButton1" );
		button.sortType = "name";
		button:SetText( L["Name"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame, "TOPLEFT", 5, -5 );
		button:Show();

		button = getglobal( self.extrasFrame:GetName() .. "SortButton2" );
		button.sortType = "memory";
		button:SetText( L["Memory"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame:GetName() .. "SortButton1", "TOPLEFT", 170, 0 );
		button:Show();

		button = getglobal( self.extrasFrame:GetName() .. "SortButton3" );
		button.sortType = "cpu";
		button:SetText( L["CPU"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame:GetName() .. "SortButton2", "TOPLEFT", 140, 0 );
		button:Show();
		
		getglobal( self.extrasFrame:GetName() .. "SortButton4" ):Hide();
		getglobal( self.extrasFrame:GetName() .. "SortButton5" ):Hide();

		self:HideAllRows();
		self.extrasFrame.currentPage = "overall";
	end
	
	local totalMem = 0;
	local totalCPU = 0;

	for i=1, GetNumAddOns() do
		totalMem = totalMem + ( GetAddOnMemoryUsage( i ) );
		totalCPU = totalCPU + ( GetAddOnCPUUsage( i ) );
	end

	local addonList = {};
	for i=1, GetNumAddOns() do
		if( IsAddOnLoaded( i ) ) then
			memory = GetAddOnMemoryUsage( i );
			cpu = GetAddOnCPUUsage( i );
			
			table.insert( addonList, { name = ( GetAddOnInfo( i ) ), memory = memory, cpu = cpu, cpuPerct = cpu / totalCPU * 100, memPerct = memory / totalMem * 100 } );
		end
	end
	
	table.sort( addonList, SortAddOns );

	FauxScrollFrame_Update( self.extrasScroll, #( addonList ), TOTAL_SCROLL_ROWS, 20 );
	
	local offset = FauxScrollFrame_GetOffset( self.extrasScroll );
	local index, column1, column2, column3;
	
	for i=1, TOTAL_SCROLL_ROWS do
		index = offset + i;
		
		column1 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column1" );
		column2 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column2" );
		column3 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column3" );
		
		if( index <= #( addonList ) ) then
			
			column1:SetText( addonList[ index ].name );
			if( ScriptProfiling ) then
				column3:SetText( string.format( L["%.2f (%.1f%%)"], addonList[ index ].cpu, addonList[ index ].cpuPerct ) );
			else
				column3:SetText( "----" );
			end
			
			if( addonList[ index ].memory > 1000 ) then
				column2:SetText( string.format( L["%.2f MB (%.1f%%)"], addonList[ index ].memory / 1000, addonList[ index ].memPerct ) );
			else
				column2:SetText( string.format( L["%.2f KB (%.1f%%)"], addonList[ index ].memory, addonList[ index ].memPerct ) );
			end
			
			column1:Show();
			column2:Show();
			column3:Show();
		else
			column1:Hide();
			column2:Hide();
			column3:Hide();
		end
	end
end

local function SortGeneric( a, b )
	if( not b ) then
		return false;
	end
	
	if( RT.extrasFrame.sortOrder ) then
		if( RT.extrasFrame.sortType == "name" ) then
			return ( a.name < b.name );
		elseif( RT.extrasFrame.sortType == "called" ) then
			return ( a.called < b.called );
		elseif( RT.extrasFrame.sortType == "avg" ) then
			return ( a.avgSeconds < b.avgSeconds );
		end

		return ( a.seconds < b.seconds );
		
	else
		if( RT.extrasFrame.sortType == "name" ) then
			return ( a.name > b.name );
		elseif( RT.extrasFrame.sortType == "called" ) then
			return ( a.called > b.called );
		elseif( RT.extrasFrame.sortType == "avg" ) then
			return ( a.avgSeconds > b.avgSeconds );
		end

		return ( a.seconds > b.seconds );
	end
end

function RT:ShowNamespaceProfile()
	if( this.blockShow ) then
		this.blockShow = nil;
		return;
	end

	local self = RT;
	
	if( not ScriptProfiling ) then
		self:UIError( L["You do not have CPU profiling on, or didn't reloadui."] );
		self.extrasFrame.currentPage = "namespace";
		return;
	end

	if( self.extrasFrame.currentPage ~= "namespace" ) then
		local button = getglobal( self.extrasFrame:GetName() .. "SortButton1" );
		button.sortType = "name";
		button:SetText( L["Name"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame, "TOPLEFT", 5, -5 );
		button:Show();

		button = getglobal( self.extrasFrame:GetName() .. "SortButton2" );
		button.sortType = "seconds";
		button:SetText( L["Seconds"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame:GetName() .. "SortButton1", "TOPLEFT", 210, 0 );
		button:Show();

		button = getglobal( self.extrasFrame:GetName() .. "SortButton3" );
		button.sortType = "avg";
		button:SetText( L["Avg"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame:GetName() .. "SortButton2", "TOPLEFT", 110, 0 );
		button:Show();

		button = getglobal( self.extrasFrame:GetName() .. "SortButton4" );
		button.sortType = "called";
		button:SetText( L["Called"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame:GetName() .. "SortButton3", "TOPLEFT", 55, 0 );
		button:Show();
		
		getglobal( self.extrasFrame:GetName() .. "SortButton5" ):Hide();

		self:HideAllRows();
		self.extrasFrame.currentPage = "namespace";
	end
	
	local namespaceText = string.trim( self.namespaceInput:GetText() );
	local searchFilter = string.trim( self.nsSearchInput:GetText() );
	local namespace = getglobal( namespaceText );
	
	if( not namespace ) then
		self:UIError( string.format( L["No namespace called \"%s\" seems to exist."], namespaceText ) );
		return;

	elseif( type( namespace ) ~= "table" ) then
		self:UIError( string.format( L["The variable \"%s\" isn't a table."], namespaceText ) );
		return;
	end
	
	if( searchFilter == "" ) then
		searchFilter = nil;
	end
	
	local funcList = {};
	local totalSeconds = 0;
	local seconds, called;

	for key, value in pairs( namespace ) do
		if( type( value ) == "function" and ( ( self.nsHideInject:GetChecked() and not RTBlacklist[ key ] ) or not self.nsHideInject:GetChecked() ) and ( ( searchFilter and string.find( key, searchFilter ) ) or not searchFilter ) ) then
			seconds, called = GetFunctionCPUUsage( namespace[ key ], self.namespaceSubs:GetChecked() );	
			
			if( ( self.nsHideZero:GetChecked() and called > 0 ) or not self.nsHideZero:GetChecked() ) then
				totalSeconds = totalSeconds + seconds;
				table.insert( funcList, { name = key, seconds = seconds, called = called, avgSeconds = seconds / called } );
			end
		end
	end
	
	if( #( funcList ) == 0 ) then
		if( searchFilter ) then
			self:UIError( string.format( L["Cannot find any functions inside the namespace \"%s\"."], namespaceText ), string.format( L["Filter Used: \"%s\""], searchFilter ) );
		else
			self:UIError( string.format( L["Cannot find any functions inside the namespace \"%s\"."], namespaceText ), string.format( L["Filter Used: \"%s\""], L["None"] ) );
		end
		return;
	end
	
	for id, func in pairs( funcList ) do
		funcList[ id ].secondsPerct = funcList[ id ].seconds / totalSeconds * 100;
	end
	
	table.sort( funcList, SortGeneric );

	FauxScrollFrame_Update( self.extrasScroll, #( funcList ), TOTAL_SCROLL_ROWS, 20 );
	
	local offset = FauxScrollFrame_GetOffset( self.extrasScroll );
	local index, column1, column2, column3;
	
	for i=1, TOTAL_SCROLL_ROWS do
		index = offset + i;
		
		column1 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column1" );
		column2 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column2" );
		column3 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column3" );
		column4 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column4" );
		
		if( index <= #( funcList ) ) then
			if( string.len( funcList[ index ].name ) >= 36 ) then
				funcList[ index ].name = string.sub( funcList[ index ].name, 0, 36 ) .. "...";
			end
			
			column1:SetText( funcList[ index ].name );
			column4:SetText( funcList[ index ].called );
			
			if( funcList[ index ].called > 0 ) then
				column2:SetText( string.format( L["%.2f (%.1f%%)"], funcList[ index ].seconds, funcList[ index ].secondsPerct ) );
				column3:SetText( string.format( "%.2f", funcList[ index ].avgSeconds ) );
			else
				column2:SetText( "----" );
				column3:SetText( "----" );
			end
						
			column1:Show();
			column2:Show();
			column3:Show();
			column4:Show();
		else
			column1:Hide();
			column2:Hide();
			column3:Hide();
			column4:Hide();
		end
	end
end

function RT:ShowEventProfile()
	if( this.blockShow ) then
		this.blockShow = nil;
		return;
	end
	
	local self = RT;
	
	if( not ScriptProfiling ) then
		self:UIError( L["You do not have CPU profiling on, or didn't reloadui."] );
		self.extrasFrame.currentPage = "event";
		return;
	end

	if( self.extrasFrame.currentPage ~= "event" ) then
		local button = getglobal( self.extrasFrame:GetName() .. "SortButton1" );
		button.sortType = "name";
		button:SetText( L["Name"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame, "TOPLEFT", 5, -5 );
		button:Show();

		button = getglobal( self.extrasFrame:GetName() .. "SortButton2" );
		button.sortType = "seconds";
		button:SetText( L["Seconds"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame:GetName() .. "SortButton1", "TOPLEFT", 210, 0 );
		button:Show();

		button = getglobal( self.extrasFrame:GetName() .. "SortButton3" );
		button.sortType = "avg";
		button:SetText( L["Avg"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame:GetName() .. "SortButton2", "TOPLEFT", 110, 0 );
		button:Show();

		button = getglobal( self.extrasFrame:GetName() .. "SortButton4" );
		button.sortType = "called";
		button:SetText( L["Called"] );
		button:SetWidth( button:GetFontString():GetStringWidth() + 3 );
		button:SetPoint( "TOPLEFT", self.extrasFrame:GetName() .. "SortButton3", "TOPLEFT", 55, 0 );
		button:Show();
		
		getglobal( self.extrasFrame:GetName() .. "SortButton5" ):Hide();

		self:HideAllRows();
		self.extrasFrame.currentPage = "event";
	end
	
	local searchFilter = string.trim( self.eventInput:GetText() );
	if( searchFilter == "" ) then
		searchFilter = nil;
	end
	
	local eventList = {};
	local totalSeconds = 0;
	local seconds, called = GetEventCPUUsage();
	
	if( not searchFilter ) then
		table.insert( eventList, { name = L["All Events"], seconds = seconds, called = called, avgSeconds = seconds / called } );
	end
	
	for event, _ in pairs( RTEvents ) do
		if( ( searchFilter and string.find( event, searchFilter ) ) or not searchFilter ) then
			seconds, called = GetEventCPUUsage( event );	
			
			if( ( self.evtHideZero:GetChecked() and called > 0 ) or not self.evtHideZero:GetChecked() ) then
				totalSeconds = totalSeconds + seconds;
				table.insert( eventList, { name = event, seconds = seconds, called = called, avgSeconds = seconds / called } );
			end
		end
	end
	
	if( #( eventList ) == 0 ) then
		if( searchFilter ) then
			self:UIError( string.format( L["No events found."], namespaceText ), string.format( L["Filter Used: \"%s\""], searchFilter ) );
		else
			self:UIError( string.format( L["No events found."], namespaceText ), string.format( L["Filter Used: \"%s\""], L["None"] ) );
		end
		return;
	end
	
	for id, event in pairs( eventList ) do
		eventList[ id ].secondsPerct = eventList[ id ].seconds / totalSeconds * 100;
	end
	
	table.sort( eventList, SortGeneric );

	FauxScrollFrame_Update( self.extrasScroll, #( eventList ), TOTAL_SCROLL_ROWS, 20 );
	
	local offset = FauxScrollFrame_GetOffset( self.extrasScroll );
	local index, column1, column2, column3;
	
	for i=1, TOTAL_SCROLL_ROWS do
		index = offset + i;
		
		column1 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column1" );
		column2 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column2" );
		column3 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column3" );
		column4 = getglobal( self.extrasFrame:GetName() .. "SortRow" .. i .. "Column4" );
		
		if( index <= #( eventList ) ) then
			if( string.len( eventList[ index ].name ) >= 30 ) then
				eventList[ index ].name = string.sub( eventList[ index ].name, 15 );

				if( string.sub( eventList[ index ].name, 0, 1 ) == "_" ) then
					eventList[ index ].name = string.sub( eventList[ index ].name, 2 );
				end
				
				eventList[ index ].name = "..." .. eventList[ index ].name;
			end

			column1:SetText( eventList[ index ].name );
			column4:SetText( eventList[ index ].called );

			if( eventList[ index ].called > 0 ) then
				column2:SetText( string.format( L["%.2f (%.1f%%)"], eventList[ index ].seconds, eventList[ index ].secondsPerct ) );
				column3:SetText( string.format( "%.2f", eventList[ index ].avgSeconds ) );
			else
				column2:SetText( "----" );
				column3:SetText( "----" );
			end
			
			column1:Show();
			column2:Show();
			column3:Show();
			column4:Show();
		else
			column1:Hide();
			column2:Hide();
			column3:Hide();
			column4:Hide();
		end
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
	if( not ScriptProfiling ) then
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
	if( not ScriptProfiling ) then
		self:Print( L["You have to enable CPU profiling first before you can use this."] );
		return;
	end

	UpdateAddOnCPUUsage();
	self:Echo( string.format( L["%s: %.3f seconds."], addon, GetAddOnCPUUsage( addon ) ) );
end

function RT:GetFrameCPU( text, includeChildren )
	if( not ScriptProfiling ) then
		self:Print( L["You have to enable CPU profiling first before you can use this."] );
		return;
	end
	
	UpdateAddOnCPUUsage();
	
	local usedChild;
	if( includeChildren == "true" ) then
		usedChild = L["included"];
		includeChildren = true;
	else
		usedChild = L["skipped"];
		includeChildren = nil;
	end
	
	local frame = getglobal( text );
	if( not frame ) then
		self:Print( string.format( L["Cannot find the frame %s."], text ) );
		return;
	end
	
	local seconds, called = GetFrameCPUUsage( frame, includeChildren );
	
	if( called > 0 ) then
		self:Print( string.format( L["%s (children %s) took %.3f seconds, called %d times, average %.3f."], text, usedChild, seconds, called, seconds / called ) );
	else
		self:Print( string.format( L["No calls made to the frame %s."], text ) );
	end
end

function RT:GetFunctionCPU( text, includeSub )
	if( not ScriptProfiling ) then
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
	if( not ScriptProfiling ) then
		self:Print( L["You have to enable CPU profiling first before you can use this."] );
		return;
	end
		
	UpdateAddOnCPUUsage();
	
	local seconds, called;

	for _, event in pairs( { string.split( ",", ( string.gsub( text, " ", "" ) ) ) } ) do
		if( event ~= "all" ) then
			seconds, called = GetEventCPUUsage( event );
		else
			seconds, called = GetEventCPUUsage();
			event = L["All Events"];
		end

		if( called > 0 ) then
			self:Echo( string.format( L["%s: %.3f seconds, called %d times, %.3f average."], event, seconds, called, seconds / called ) );
		else
			self:Echo( string.format( L["%s: no events by this name have been triggered."], event ) );
		end
	end
end