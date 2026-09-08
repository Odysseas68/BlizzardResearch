-- luacheck: globals C_PaperDollInfo CreateFrame GetTime INVSLOT_MAINHAND
-- luacheck: globals INVSLOT_OFFHAND IsControlKeyDown Item ItemEventListener
-- luacheck: globals ScrollBoxConstants SlashCmdList UIParent
-- luacheck: globals SLASH_ASYNCITEMCALLBACKSDIAGNOSTIC1 SLASH_ASYNCITEMCALLBACKSDIAGNOSTIC2

local _, RetailUIResearch = ...;
local ADDON_NAME = "AsyncItemCallbacksDiagnostic";
local bootstrap = assert(
	RetailUIResearch.AsyncItemCallbacksBootstrap,
	"Async item-callback diagnostic bootstrap did not load"
);

local MAX_LOG_ENTRIES = 80;
local MAX_ENTRY_CHARACTERS = 4000;
local MAX_BUCKET_ENTRIES = 16;
local MAX_STACK_LINES = 10;

local logEntries = {};
local logSequence = 0;
local logDisplay;
local equipmentText;
local restoringLogText = false;
local observedItemIDs = {};
local registrationsByItemID = {};
local cachedEquipmentStates;
local lastResolutionSignature;

local SLOT_DEFINITIONS = {
	{key = "main", label = "Main hand", inventorySlot = INVSLOT_MAINHAND},
	{key = "off", label = "Off hand", inventorySlot = INVSLOT_OFFHAND},
};

local function RefreshLog()
	if not logDisplay then
		return;
	end

	local authoritativeText = table.concat(logEntries, "\n\n");
	if logDisplay:GetText() ~= authoritativeText then
		restoringLogText = true;
		logDisplay:SetText(authoritativeText);
		restoringLogText = false;
	end
	logDisplay:GetScrollBox():ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation);
end

local function Record(text)
	logSequence = logSequence + 1;
	local entry = string.format("#%03d t=%.3f %s", logSequence, GetTime(), text);
	if #entry > MAX_ENTRY_CHARACTERS then
		entry = entry:sub(1, MAX_ENTRY_CHARACTERS) .. "\n    <entry truncated>";
	end

	logEntries[#logEntries + 1] = entry;
	if #logEntries > MAX_LOG_ENTRIES then
		table.remove(logEntries, 1);
	end
	RefreshLog();
end

local function GetSlotState(definition)
	local item = Item:CreateFromEquipmentSlot(definition.inventorySlot);
	local enchantInfo = C_PaperDollInfo.GetTemporaryEnchantmentInfo(definition.inventorySlot);
	return {
		key = definition.key,
		label = definition.label,
		inventorySlot = definition.inventorySlot,
		itemID = item:GetItemID(),
		enchantInfo = enchantInfo,
	};
end

local function GetEquipmentState()
	local states = {};
	for index = 1, #SLOT_DEFINITIONS do
		states[index] = GetSlotState(SLOT_DEFINITIONS[index]);
	end
	return states;
end

local function DescribeSlotState(state)
	local enchantInfo = state.enchantInfo;
	if enchantInfo then
		return string.format(
			"%s slot=%d itemID=%s tempEnchant=true enchantID=%s remainingMs=%s charges=%s",
			state.label,
			state.inventorySlot,
			tostring(state.itemID),
			tostring(enchantInfo.enchantID),
			tostring(enchantInfo.remainingTimeMs),
			tostring(enchantInfo.chargesRemaining)
		);
	end

	return string.format(
		"%s slot=%d itemID=%s tempEnchant=false",
		state.label,
		state.inventorySlot,
		tostring(state.itemID)
	);
end

local function DescribeEquipment(states)
	local descriptions = {};
	for index = 1, #states do
		descriptions[index] = DescribeSlotState(states[index]);
	end
	return table.concat(descriptions, "\n");
end

local function GetMatchingSlots(itemID, states)
	local matches = {};
	for index = 1, #states do
		local state = states[index];
		if state.itemID == itemID then
			matches[#matches + 1] = state;
		end
	end
	return matches;
end

local function DescribeMatches(matches)
	local descriptions = {};
	for index = 1, #matches do
		descriptions[index] = DescribeSlotState(matches[index]);
	end
	return table.concat(descriptions, "; ");
end

local function RefreshEquipmentDisplay(states)
	if equipmentText then
		equipmentText:SetText(DescribeEquipment(states or GetEquipmentState()));
	end
end

local function DescribeBucket(listener, itemID)
	local callbackMap = listener.callbacks;
	if type(callbackMap) ~= "table" then
		return "callbackMapType=" .. type(callbackMap);
	end

	local bucket = callbackMap[itemID];
	if type(bucket) ~= "table" then
		return "callbackMapType=table bucketType=" .. type(bucket);
	end

	local length = #bucket;
	local descriptions = {};
	local inspected = math.min(length, MAX_BUCKET_ENTRIES);
	for index = 1, inspected do
		local callback = bucket[index];
		descriptions[#descriptions + 1] = string.format(
			"%d:%s:%s",
			index,
			type(callback),
			tostring(callback)
		);
	end
	if length > inspected then
		descriptions[#descriptions + 1] = string.format("+%d more", length - inspected);
	end

	return string.format(
		"callbackMapType=table bucketType=table bucketLength=%d entries=[%s]",
		length,
		table.concat(descriptions, ", ")
	);
end

local function DescribeFunctionState(name)
	local value = _G[name];
	local secureText = "unavailable";
	if type(_G.issecurevariable) == "function" then
		local succeeded, isSecure, taintSource = pcall(_G.issecurevariable, name);
		if succeeded then
			secureText = string.format("%s taint=%s", tostring(isSecure), tostring(taintSource));
		else
			secureText = "check-error";
		end
	end
	return string.format("%s type=%s secure=%s", name, type(value), secureText);
end

local function DescribeRelevantFunctionState()
	return table.concat({
		DescribeFunctionState("xpcall"),
		DescribeFunctionState("ipairs"),
		DescribeFunctionState("CallErrorHandler"),
	}, "; ");
end

local function DescribeRelevantFunctionTypes()
	return string.format(
		"xpcall=%s ipairs=%s CallErrorHandler=%s",
		type(_G.xpcall),
		type(_G.ipairs),
		type(_G.CallErrorHandler)
	);
end

local function GetDiagnosticStack(maxLines, maxCharacters)
	if type(_G.debugstack) ~= "function" then
		return "<debugstack unavailable>";
	end

	local stack = _G.debugstack(3, maxLines, maxLines);
	if type(stack) ~= "string" or stack == "" then
		return "<empty debugstack>";
	end
	stack = stack:gsub("\r", "");
	if #stack > maxCharacters then
		stack = stack:sub(1, maxCharacters) .. "\n<stack truncated>";
	end
	return "    " .. stack:gsub("\n", "\n    ");
end

local function HasResolvedEquipmentIdentity(states)
	for index = 1, #states do
		if states[index].itemID ~= nil then
			return true;
		end
	end
	return false;
end

local function GetEquipmentIdentitySignature(states)
	local identities = {};
	for index = 1, #states do
		identities[index] = tostring(states[index].itemID);
	end
	return table.concat(identities, ":");
end

local function WasCallbackObserved(records, itemID, callbackIdentity)
	for index = 1, #records do
		local record = records[index];
		if record.itemID == itemID and record.callbackIdentity == callbackIdentity then
			return true;
		end
	end
	return false;
end

local function DescribePrefireCorrelation(observation)
	local descriptions = {};
	for index = 1, #observation.entries do
		local entry = observation.entries[index];
		local origin = "unseen-by-v3";
		if WasCallbackObserved(bootstrap.startupEntries, observation.itemID, entry.callbackIdentity) then
			origin = "present-at-v3-startup";
		elseif WasCallbackObserved(bootstrap.registrations, observation.itemID, entry.callbackIdentity) then
			origin = "AddCallback-observed-by-v3";
		end
		descriptions[#descriptions + 1] = string.format(
			"%d:%s:%s",
			entry.index,
			origin,
			entry.security
		);
	end
	if #descriptions == 0 then
		return "none";
	end
	return table.concat(descriptions, ", ");
end

local function RecordStartupObservation(observation, matches)
	observation.reported = true;
	observedItemIDs[observation.itemID] = true;
	Record(string.format(
		"STARTUP_CALLBACK id=%s capturedT=%.3f bucketIndex=%d bucketLength=%d "
			.. "callbackType=%s callback=%s entrySecurity=%s\n"
			.. "    equippedMatch: %s",
		tostring(observation.itemID),
		observation.timestamp,
		observation.index,
		observation.bucketLength,
		observation.callbackType,
		observation.callbackIdentity,
		observation.security,
		DescribeMatches(matches)
	));
end

local function RecordRegistrationObservation(observation, matches, resolvedFromBuffer)
	observedItemIDs[observation.itemID] = true;
	registrationsByItemID[observation.itemID] = (registrationsByItemID[observation.itemID] or 0) + 1;
	Record(string.format(
		"REGISTER id=%s hookOrder=%d observedForID=%d capturedT=%.3f resolvedFromBuffer=%s "
			.. "callbackType=%s callback=%s\n"
			.. "    equippedMatch: %s\n"
			.. "    equipmentAtHook: %s\n"
			.. "    bucketAfterReturn: %s\n"
			.. "    insertedEntrySecurity: %s\n"
			.. "    functionsAtHook: %s\n"
			.. "    postHookStack:\n%s",
		tostring(observation.itemID),
		observation.hookOrder,
		registrationsByItemID[observation.itemID],
		observation.timestamp,
		tostring(resolvedFromBuffer),
		observation.callbackType,
		observation.callbackIdentity,
		DescribeMatches(matches),
		observation.equipment,
		observation.bucket,
		observation.entrySecurity,
		observation.functionState,
		observation.stack
	));
end

local function RecordPrefireObservation(observation, matches, resolvedFromBuffer)
	observedItemIDs[observation.itemID] = true;
	Record(string.format(
		"PREFIRE id=%s getCallbacksOrder=%d capturedT=%.3f resolvedFromBuffer=%s\n"
			.. "    equippedMatch: %s\n"
			.. "    bucketBeforeClear: %s\n"
			.. "    entryOrigins: %s\n"
			.. "    functionsAtHook: %s\n"
			.. "    GetCallbacksPostHookStack:\n%s",
		tostring(observation.itemID),
		observation.hookOrder,
		observation.timestamp,
		tostring(resolvedFromBuffer),
		DescribeMatches(matches),
		observation.bucket,
		DescribePrefireCorrelation(observation),
		observation.functionState,
		observation.stack
	));
end

local function ResolveBufferedEvidence(states)
	if not HasResolvedEquipmentIdentity(states) then
		return;
	end

	local signature = GetEquipmentIdentitySignature(states);
	if signature == lastResolutionSignature then
		return;
	end
	lastResolutionSignature = signature;

	local bufferedStartup = #bootstrap.startupEntries;
	local bufferedRegistrations = #bootstrap.registrations;
	local bufferedPrefire = #bootstrap.prefireSnapshots;
	local matchedStartup = 0;
	local matchedRegistrations = 0;
	local matchedPrefire = 0;

	for index = 1, bufferedStartup do
		local observation = bootstrap.startupEntries[index];
		local matches = GetMatchingSlots(observation.itemID, states);
		if not observation.reported and #matches > 0 then
			matchedStartup = matchedStartup + 1;
			RecordStartupObservation(observation, matches);
		end
	end

	for index = 1, bufferedRegistrations do
		local observation = bootstrap.registrations[index];
		local matches = GetMatchingSlots(observation.itemID, states);
		if not observation.reported and #matches > 0 then
			matchedRegistrations = matchedRegistrations + 1;
			observation.reported = true;
			observation.equipment = "<equipment identity resolved after hook>";
			observation.functionState = DescribeRelevantFunctionTypes();
			RecordRegistrationObservation(observation, matches, true);
		end
	end

	for index = 1, bufferedPrefire do
		local observation = bootstrap.prefireSnapshots[index];
		local matches = GetMatchingSlots(observation.itemID, states);
		if not observation.reported and #matches > 0 then
			matchedPrefire = matchedPrefire + 1;
			observation.reported = true;
			observation.functionState = DescribeRelevantFunctionTypes();
			RecordPrefireObservation(observation, matches, true);
		end
	end

	Record(string.format(
		"BUFFER_RESOLVED startupRetained=%d newlyMatched=%d evicted=%d "
			.. "registrationsRetained=%d newlyMatched=%d evicted=%d "
			.. "prefireRetained=%d newlyMatched=%d evicted=%d\n"
			.. "    equipment: %s",
		bufferedStartup,
		matchedStartup,
		bootstrap.startupEvictions,
		bufferedRegistrations,
		matchedRegistrations,
		bootstrap.registrationEvictions,
		bufferedPrefire,
		matchedPrefire,
		bootstrap.prefireEvictions,
		DescribeEquipment(states):gsub("\n", "; ")
	));
end

local function UpdateEquipmentState(states)
	cachedEquipmentStates = states or GetEquipmentState();
	RefreshEquipmentDisplay(cachedEquipmentStates);
	ResolveBufferedEvidence(cachedEquipmentStates);
	return cachedEquipmentStates;
end

local function ObserveRegistration(observation, listener)
	local states = cachedEquipmentStates;
	local matches = GetMatchingSlots(observation.itemID, states);

	if #matches > 0 then
		observation.reported = true;
		observation.equipment = DescribeEquipment(states):gsub("\n", "; ");
		observation.bucket = DescribeBucket(listener, observation.itemID);
		observation.functionState = DescribeRelevantFunctionState();
		observation.stack = GetDiagnosticStack(MAX_STACK_LINES, MAX_ENTRY_CHARACTERS / 2);
		RecordRegistrationObservation(observation, matches, false);
	end
end

local function ObservePrefire(observation)
	local states = cachedEquipmentStates;
	local matches = GetMatchingSlots(observation.itemID, states);

	if #matches > 0 then
		observation.reported = true;
		observation.functionState = DescribeRelevantFunctionState();
		observation.stack = GetDiagnosticStack(MAX_STACK_LINES, MAX_ENTRY_CHARACTERS / 2);
		RecordPrefireObservation(observation, matches, false);
	end
end

cachedEquipmentStates = GetEquipmentState();
bootstrap.onRegistration = ObserveRegistration;
bootstrap.onPrefire = ObservePrefire;
bootstrap.onAddonLoaded = function()
	Record(string.format(
		"LIFECYCLE ADDON_LOADED addon=%s t=%.3f bootstrapLeadMs=%.3f",
		ADDON_NAME,
		bootstrap.addonLoadedTime,
		(bootstrap.addonLoadedTime - bootstrap.installTime) * 1000
	));
end;

local eventFrame = CreateFrame("Frame");
eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT");
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
eventFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player");

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local states = UpdateEquipmentState();

	if event == "ITEM_DATA_LOAD_RESULT" then
		local itemID, success = ...;
		local matches = GetMatchingSlots(itemID, states);
		if #matches > 0 or observedItemIDs[itemID] then
			Record(string.format(
				"COMPLETE id=%s success=%s currentMatch=%s\n"
					.. "    equipment: %s\n"
					.. "    bucketAtObserver: %s\n"
					.. "    functions: %s",
				tostring(itemID),
				tostring(success),
				#matches > 0 and DescribeMatches(matches) or "none (previously observed registration)",
				DescribeEquipment(states):gsub("\n", "; "),
				DescribeBucket(ItemEventListener, itemID),
				DescribeRelevantFunctionState()
			));
		end
	elseif event == "PLAYER_LOGIN" then
		Record("LIFECYCLE PLAYER_LOGIN\n    equipment: " .. DescribeEquipment(states):gsub("\n", "; "));
	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitialLogin, isReloadingUi = ...;
		Record(string.format(
			"LIFECYCLE PLAYER_ENTERING_WORLD initialLogin=%s reloadingUi=%s\n    equipment: %s",
			tostring(isInitialLogin),
			tostring(isReloadingUi),
			DescribeEquipment(states):gsub("\n", "; ")
		));
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		local equipmentSlot, hasCurrent = ...;
		if equipmentSlot == INVSLOT_MAINHAND or equipmentSlot == INVSLOT_OFFHAND then
			Record(string.format(
				"EQUIPMENT_CHANGED slot=%s hasCurrent=%s\n    equipment: %s",
				tostring(equipmentSlot),
				tostring(hasCurrent),
				DescribeEquipment(states):gsub("\n", "; ")
			));
		end
	end
end);

Record(
	string.format(
		"INIT v3 bootstrap installed at t=%.3f before Core.lua; startupEntries=%d startupEvicted=%d "
			.. "registrationsBuffered=%d registrationEvicted=%d prefireBuffered=%d prefireEvicted=%d; "
			.. "logging is active while the page is closed\n    equipment: %s",
		bootstrap.installTime,
		#bootstrap.startupEntries,
		bootstrap.startupEvictions,
		#bootstrap.registrations,
		bootstrap.registrationEvictions,
		#bootstrap.prefireSnapshots,
		bootstrap.prefireEvictions,
		DescribeEquipment(cachedEquipmentStates):gsub("\n", "; ")
	)
);
ResolveBufferedEvidence(cachedEquipmentStates);

local diagnosticFrame = CreateFrame("Frame", "AsyncItemCallbacksDiagnosticFrame", UIParent);
diagnosticFrame:Hide();
diagnosticFrame:SetSize(920, 660);
diagnosticFrame:SetPoint("CENTER");
diagnosticFrame:SetFrameStrata("DIALOG");
diagnosticFrame:SetClampedToScreen(true);
diagnosticFrame:SetMovable(true);

CreateFrame("Frame", nil, diagnosticFrame, "DialogBorderDarkTemplate");
local header = CreateFrame("Frame", nil, diagnosticFrame, "DialogHeaderTemplate");
header:Setup("Async Item Callbacks Diagnostic");
header:EnableMouse(true);
header:RegisterForDrag("LeftButton");
header:SetScript("OnDragStart", function()
	diagnosticFrame:StartMoving();
end);
header:SetScript("OnDragStop", function()
	diagnosticFrame:StopMovingOrSizing();
end);
CreateFrame("Button", nil, diagnosticFrame, "UIPanelCloseButtonDefaultAnchors");

local subtitle = diagnosticFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
subtitle:SetPoint("TOPLEFT", 24, -48);
subtitle:SetPoint("TOPRIGHT", -24, -48);
subtitle:SetJustifyH("LEFT");
subtitle:SetText(
	"Passive, bounded observation of equipped-weapon registrations and pre-clear callback buckets. "
		.. "Enable before fully exiting and relaunching WoW; no callbacks are wrapped or replaced."
);

equipmentText = diagnosticFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
equipmentText:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12);
equipmentText:SetPoint("TOPRIGHT", subtitle, "BOTTOMRIGHT", -230, -12);
equipmentText:SetJustifyH("LEFT");

local function CreateButton(text, width, callback)
	local button = CreateFrame("Button", nil, diagnosticFrame, "UIPanelButtonTemplate");
	button:SetSize(width, 24);
	button:SetText(text);
	button:SetScript("OnClick", callback);
	return button;
end

local refreshButton = CreateButton("Refresh Equipment", 150, function()
	local states = UpdateEquipmentState();
	Record("MANUAL equipment refresh\n    equipment: " .. DescribeEquipment(states):gsub("\n", "; "));
end);
refreshButton:SetPoint("TOPRIGHT", -24, -82);

local clearButton = CreateButton("Clear Log", 90, function()
	logEntries = {};
	RefreshLog();
	print(string.format("|cff33ff99%s:|r diagnostic log cleared; sequence numbering continues.", ADDON_NAME));
end);
clearButton:SetPoint("RIGHT", refreshButton, "LEFT", -8, 0);

local logLabel = diagnosticFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal");
logLabel:SetPoint("TOPLEFT", equipmentText, "BOTTOMLEFT", 0, -16);
logLabel:SetText("Bounded diagnostic log (newest 80 entries; click, then Ctrl+A / Ctrl+C)");

logDisplay = CreateFrame("Frame", nil, diagnosticFrame, "ScrollingEditBoxTemplate");
logDisplay:SetPoint("TOPLEFT", logLabel, "BOTTOMLEFT", 0, -8);
logDisplay:SetPoint("BOTTOMRIGHT", -24, 42);
logDisplay:SetFontObject("GameFontDisableSmall");
logDisplay:SetTextInsets(6, 6, 6, 6);

local logBackground = logDisplay:CreateTexture(nil, "BACKGROUND");
logBackground:SetAllPoints();
logBackground:SetColorTexture(0.015, 0.015, 0.022, 0.92);

local logEditBox = logDisplay:GetEditBox();
logEditBox:SetAutoFocus(false);
logEditBox:SetMultiLine(true);
logDisplay:RegisterCallback("OnTextChanged", function(_, _, isUserInput)
	if isUserInput and not restoringLogText then
		RefreshLog();
	end
end, diagnosticFrame);
logDisplay:RegisterCallback("OnKeyDown", function(_, editBox, key)
	if key == "A" and IsControlKeyDown() then
		editBox:HighlightText();
	end
end, diagnosticFrame);

local footer = diagnosticFrame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall");
footer:SetPoint("BOTTOMLEFT", 24, 16);
footer:SetPoint("BOTTOMRIGHT", -24, 16);
footer:SetJustifyH("LEFT");
footer:SetText(
	"In-memory only. V3 snapshots pre-hook buckets and retains bounded all-ID observations. "
		.. "GetCallbacks snapshots occur before FireCallbacks clears the mapped bucket."
);

diagnosticFrame:SetScript("OnShow", function()
	UpdateEquipmentState();
	RefreshLog();
end);

RefreshEquipmentDisplay(cachedEquipmentStates);
RefreshLog();

RetailUIResearch:RegisterSample({
	id = "async-item-callbacks",
	name = "Async Item Callbacks",
	frame = diagnosticFrame,
});

SLASH_ASYNCITEMCALLBACKSDIAGNOSTIC1 = "/asyncitemcallbacks";
SLASH_ASYNCITEMCALLBACKSDIAGNOSTIC2 = "/aicd";
SlashCmdList.ASYNCITEMCALLBACKSDIAGNOSTIC = function()
	RetailUIResearch:ToggleSample("async-item-callbacks");
end;
