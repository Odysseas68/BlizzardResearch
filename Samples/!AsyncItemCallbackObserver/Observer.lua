-- luacheck: globals C_AddOns ChatFontNormal CreateFrame GetTime GetTimePreciseSec ItemEventListener
-- luacheck: globals QuestEventListener SpellEventListener
-- luacheck: globals SlashCmdList UIParent debugstack hooksecurefunc issecurevariable
-- luacheck: globals SLASH_ASYNCITEMCALLBACKOBSERVER1 _G

local nativeSetErrorHandler = _G.seterrorhandler;
local nativeGetErrorHandler = _G.geterrorhandler;
local nativeIsSecretValue = _G.issecretvalue;
local nativeType = _G.type;
local nativeTostring = _G.tostring;
local nativeSelect = _G.select;
local nativeUnpack = _G.unpack or (_G.table and _G.table.unpack);
local nativeStringGsub = _G.string and _G.string.gsub;
local nativeStringSub = _G.string and _G.string.sub;
local nativePcall = _G.pcall;
local nativeRawequal = _G.rawequal;
local nativeSetMetatable = _G.setmetatable;
local originalCallErrorHandler = _G.CallErrorHandler;

local ADDON_NAME = ...;

local MAX_GENERIC_RECORDS = 128;
local MAX_TARGET_RECORDS = 16;
local MAX_TARGET_PREFIRE_RECORDS = 32;
local MAX_ACTIVE_HANDLER_WRAPPER_RECORDS = 48;
local MAX_CALLERROR_WRAPPER_RECORDS = 48;
local MAX_CALLERROR_IDENTITY_RECORDS = 64;
local MAX_LOAD_EVENTS = 512;
local MAX_BUCKET_ENTRIES = 16;
local MAX_STACK_LINES = 10;
local MAX_STACK_CHARACTERS = 1800;
local MAX_ERROR_TEXT_BYTES = 512;
local MAX_DISPATCH_RECORDS = 128;
local MAX_TARGET_STRUCTURAL_RECORDS = 128;
local MAX_DISPATCH_FAILURE_RECORDS = 16;
local MAX_BOUNDARY_PROVENANCE_RECORDS = 48;
local STRUCTURAL_TARGET_ITEM_ID = 268203;
local TARGET_ITEM_IDS = {
	[268203] = true,
	[275218] = true,
};
local state = {
	installTime = 0,
	registrationCount = 0,
	getCallbacksCount = 0,
	activeHandlerWrapperEntryCount = 0,
	activeHandlerWrapperReturnCount = 0,
	callErrorWrapperEntryCount = 0,
	callErrorWrapperReturnCount = 0,
	genericEvictions = 0,
	activeHandlerWrapperEvictions = 0,
	callErrorWrapperEvictions = 0,
	callErrorIdentityEvictions = 0,
	loadEventCount = 0,
	loadEventDrops = 0,
	dispatchSequence = 0,
	dispatchOpenCount = 0,
	dispatchNormalExitCount = 0,
	dispatchRecordHead = 1,
	dispatchRecordCount = 0,
	dispatchRecordEvictions = 0,
	targetStructuralDrops = 0,
	targetGenerationRegistrationEvictions = 0,
	dispatchStackMismatchCount = 0,
	maxDispatchDepth = 0,
	dispatchFailureCount = 0,
	dispatchFailureDrops = 0,
	boundaryRecordsRetained = 0,
	boundaryRecordDrops = 0,
	boundarySnapshotFailures = 0,
	boundarySequence = 0,
	targetDispatchOpenCount = 0,
	bucketGenerationSequence = 0,
	lastCompletedAddon = "<none observed>",
	lastGetCallbacks = nil,
	lastTargetGetCallbacks = nil,
	genericRecords = {},
	activeHandlerWrapperRecords = {},
	activeHandlerWrapperRecordHead = 1,
	activeHandlerWrapperRecordCount = 0,
	callErrorWrapperRecords = {},
	callErrorWrapperRecordHead = 1,
	callErrorWrapperRecordCount = 0,
	callErrorIdentityRecords = {},
	dispatchRecords = {},
	targetStructuralRecords = {},
	dispatchFailureRecords = {},
	boundaryRecords = {},
	openDispatchStack = {},
	bucketGenerationByReference = {},
	targetGenerationRegistrations = {},
	targetGenerationRegistrationKeys = {},
	listenerHookStatus = {},
	callErrorHandlerAfterObserverHooksValue = nil,
	callErrorHandlerBeforeBugGrabberEventValue = nil,
	callErrorHandlerAfterBugGrabberWrapperValue = nil,
	callErrorHandlerDirectWrapperValue = nil,
	activeHandlerWrapperInstallAttempted = false,
	activeHandlerWrapperInstalled = false,
	activeHandlerWrapperInstallStatus = "not attempted",
	activeHandlerWrapperTarget = "<not selected>",
	activeHandlerWrapperInstallTrigger = "<not attempted>",
	activeHandlerWrapperInstallTimestamp = nil,
	activeHandlerWrapperInstallElapsed = nil,
	bugGrabberEnableCheckStatus = "not checked",
	bugGrabberEnabledForCharacter = nil,
	callErrorWrapperInstallAttempted = false,
	callErrorWrapperInstalled = false,
	callErrorWrapperInstallStatus = "not attempted",
	callErrorWrapperInstallTimestamp = nil,
	callErrorWrapperInstallElapsed = nil,
	bugSackInstallGateStatus = "not checked",
	bugSackLoadedAtInstallGate = nil,
	bugSackLoadedOrLoadingAtInstallGate = nil,
	bugSackLoadedAfterDirectWrapperInstall = false,
	nativeSetterCaptured = nativeType(nativeSetErrorHandler) == "function",
	nativeGetterCaptured = nativeType(nativeGetErrorHandler) == "function",
	nativeUnpackCaptured = nativeType(nativeUnpack) == "function",
	originalCallErrorHandlerCaptured = nativeType(originalCallErrorHandler) == "function",
	originalCallErrorHandlerType = nativeType(originalCallErrorHandler),
	originalCallErrorHandlerIdentity = nativeType(originalCallErrorHandler) == "function"
		and nativeTostring(originalCallErrorHandler) or "<not-function>",
	callErrorHandlerSecurityBeforeReplacement = "<not captured>",
	callErrorHandlerSecurityAfterReplacement = "<not captured>",
	callErrorHandlerAfterReplacementType = "<not captured>",
	callErrorHandlerAfterReplacementIdentity = "<not captured>",
	nativeIsSecretValueCaptured = nativeType(nativeIsSecretValue) == "function",
	nativeSetterType = nativeType(nativeSetErrorHandler),
	nativeSetterIdentity = nativeType(nativeSetErrorHandler) == "function"
		and nativeTostring(nativeSetErrorHandler) or "<not-function>",
	nativeGetterType = nativeType(nativeGetErrorHandler),
	nativeGetterIdentity = nativeType(nativeGetErrorHandler) == "function"
		and nativeTostring(nativeGetErrorHandler) or "<not-function>",
	retainedActiveHandlerType = "<not captured>",
	retainedActiveHandlerIdentity = "<not captured>",
	retainedActiveHandlerSecurity = "direct function security/taint unavailable",
	getErrorHandlerGlobalSecurity = "<not captured>",
	setErrorHandlerGlobalSecurity = "<not captured>",
	publicSetterTypeAtHandlerInstall = "<not captured>",
	publicSetterIdentityAtHandlerInstall = "<not captured>",
	activeHandlerAfterInstallType = "<not captured>",
	activeHandlerAfterInstallIdentity = "<not captured>",
	targetRecords = {
		[268203] = {},
		[275218] = {},
	},
	targetDrops = {
		[268203] = 0,
		[275218] = 0,
	},
	targetPrefireRecords = {
		[268203] = {},
		[275218] = {},
	},
	targetPrefireDrops = {
		[268203] = 0,
		[275218] = 0,
	},
	loadEvents = {},
	milestones = {},
};

if nativeType(nativeSetMetatable) == "function" then
	nativeSetMetatable(state.bucketGenerationByReference, {__mode = "k"});
end

local function GetTimestamp()
	if type(GetTimePreciseSec) == "function" then
		return GetTimePreciseSec();
	end
	return GetTime();
end

state.installTime = GetTimestamp();

local function GetElapsed(timestamp)
	return timestamp - state.installTime;
end

state.milestones.observerInstall = {
	timestamp = state.installTime,
};

local function CaptureStack()
	if type(debugstack) ~= "function" then
		return "<debugstack unavailable>";
	end

	local stack = debugstack(3, MAX_STACK_LINES, MAX_STACK_LINES);
	if type(stack) ~= "string" or stack == "" then
		return "<empty debugstack>";
	end

	stack = stack:gsub("\r", "");
	if #stack > MAX_STACK_CHARACTERS then
		stack = stack:sub(1, MAX_STACK_CHARACTERS) .. "\n<stack truncated>";
	end
	return stack;
end

local function GetAddonLoadedState(addonName)
	if type(C_AddOns) ~= "table" or type(C_AddOns.IsAddOnLoaded) ~= "function" then
		return {
			available = false,
			status = "C_AddOns.IsAddOnLoaded unavailable",
		};
	end

	local succeeded, loadedOrLoading, loaded = pcall(C_AddOns.IsAddOnLoaded, addonName);
	if not succeeded then
		return {
			available = false,
			status = "C_AddOns.IsAddOnLoaded call-error",
		};
	end

	return {
		available = true,
		status = "ok",
		loadedOrLoading = loadedOrLoading,
		loaded = loaded,
	};
end

local function IsAddonLoaded(addonName)
	local loadedState = GetAddonLoadedState(addonName);
	if not loadedState.available then
		return loadedState.status;
	end
	return tostring(loadedState.loaded);
end

local function CaptureLoadedAddonInventory()
	local inventory = {
		timestamp = GetTimestamp(),
		status = "ok",
		records = {},
		errors = {},
	};

	if type(C_AddOns) ~= "table"
		or type(C_AddOns.GetNumAddOns) ~= "function"
		or type(C_AddOns.GetAddOnInfo) ~= "function"
		or type(C_AddOns.IsAddOnLoaded) ~= "function"
	then
		inventory.status = "C_AddOns inventory APIs unavailable";
		return inventory;
	end

	local countSucceeded, addonCount = pcall(C_AddOns.GetNumAddOns);
	if not countSucceeded or type(addonCount) ~= "number" then
		inventory.status = "C_AddOns.GetNumAddOns call-error";
		return inventory;
	end

	for addonIndex = 1, addonCount do
		local infoSucceeded, addonName = pcall(C_AddOns.GetAddOnInfo, addonIndex);
		if infoSucceeded and type(addonName) == "string" then
			local loadState = GetAddonLoadedState(addonName);
			if loadState.available and loadState.loaded then
				inventory.records[#inventory.records + 1] = {
					addonIndex = addonIndex,
					addonName = addonName,
				};
			elseif not loadState.available then
				inventory.errors[#inventory.errors + 1] = string.format(
					"index=%d addon=%s status=%s",
					addonIndex,
					addonName,
					loadState.status
				);
			end
		else
			inventory.errors[#inventory.errors + 1] = string.format(
				"index=%d GetAddOnInfo=%s",
				addonIndex,
				infoSucceeded and "invalid-name" or "call-error"
			);
		end
	end

	if #inventory.errors > 0 then
		inventory.status = "partial";
	end
	return inventory;
end

local function DescribeSecureVariable(owner, key, isGlobal)
	if type(_G.issecurevariable) ~= "function" then
		return "unavailable";
	end
	if not isGlobal and type(owner) ~= "table" then
		return "owner-type=" .. type(owner);
	end

	local succeeded, isSecure, taintSource;
	if isGlobal then
		succeeded, isSecure, taintSource = pcall(_G.issecurevariable, key);
	else
		succeeded, isSecure, taintSource = pcall(_G.issecurevariable, owner, key);
	end
	if not succeeded then
		return "check-error";
	end
	return string.format("secure=%s taint=%s", tostring(isSecure), tostring(taintSource));
end

local function CaptureCallErrorHandlerIdentity(checkpoint, force)
	local value = _G.CallErrorHandler;
	local valueType = nativeType(value);
	local securityStatus = "unavailable";
	local isSecure = "<unavailable>";
	local taintSource = "<unavailable>";
	if nativeType(_G.issecurevariable) == "function" then
		local succeeded, secureValue, taintValue = pcall(_G.issecurevariable, "CallErrorHandler");
		if succeeded then
			securityStatus = "ok";
			isSecure = nativeTostring(secureValue);
			taintSource = nativeTostring(taintValue);
		else
			securityStatus = "check-error";
		end
	end

	local records = state.callErrorIdentityRecords;
	local previous = records[#records];
	if not force
		and previous
		and rawequal(previous.value, value)
		and previous.valueType == valueType
		and previous.securityStatus == securityStatus
		and previous.isSecure == isSecure
		and previous.taintSource == taintSource
	then
		return;
	end

	local timestamp = GetTimestamp();
	records[#records + 1] = {
		checkpoint = checkpoint,
		timestamp = timestamp,
		elapsed = GetElapsed(timestamp),
		value = value,
		valueType = valueType,
		identity = valueType == "function" and nativeTostring(value) or "<not-function>",
		equalsInitial = rawequal(value, originalCallErrorHandler),
		securityStatus = securityStatus,
		isSecure = isSecure,
		taintSource = taintSource,
		lastCompletedAddon = state.lastCompletedAddon,
	};
	if #records > MAX_CALLERROR_IDENTITY_RECORDS then
		table.remove(records, 1);
		state.callErrorIdentityEvictions = state.callErrorIdentityEvictions + 1;
	end
end

local function DescribeCallable(name, owner, key, isGlobal)
	local value;
	if isGlobal then
		value = _G[key];
	elseif type(owner) == "table" then
		value = owner[key];
	end

	local valueType = type(value);
	local identity = valueType == "function" and tostring(value) or "<not-function>";
	return string.format(
		"%s type=%s identity=%s %s",
		name,
		valueType,
		identity,
		DescribeSecureVariable(owner, key, isGlobal)
	);
end

local function CaptureCallableState()
	local cItem = _G.C_Item;
	local cAddOns = _G.C_AddOns;
	local lines = {
		DescribeCallable("GetItemInfo", nil, "GetItemInfo", true),
		DescribeCallable("C_Item.GetItemInfo", cItem, "GetItemInfo", false),
		DescribeCallable("C_Item.GetItemStats", cItem, "GetItemStats", false),
		DescribeCallable("EJ_GetInstanceInfo", nil, "EJ_GetInstanceInfo", true),
		DescribeCallable("EJ_GetEncounterInfo", nil, "EJ_GetEncounterInfo", true),
		DescribeCallable("select", nil, "select", true),
		DescribeCallable("table.insert", _G.table, "insert", false),
		DescribeCallable("GetCVarBool", nil, "GetCVarBool", true),
		DescribeCallable("C_AddOns.IsAddOnLoaded", cAddOns, "IsAddOnLoaded", false),
	};

	local getCVarBool = _G.GetCVarBool;
	if type(getCVarBool) == "function" then
		local succeeded, value = pcall(getCVarBool, "loadDeprecationFallbacks");
		lines[#lines + 1] = string.format(
			"GetCVarBool(loadDeprecationFallbacks) call=%s value=%s",
			succeeded and "ok" or "error",
			succeeded and tostring(value) or "<unavailable>"
		);
	else
		lines[#lines + 1] = "GetCVarBool(loadDeprecationFallbacks) call=unavailable value=<unavailable>";
	end

	local deprecatedState = GetAddonLoadedState("Blizzard_DeprecatedItemScript");
	if deprecatedState.available then
		lines[#lines + 1] = string.format(
			"C_AddOns.IsAddOnLoaded(Blizzard_DeprecatedItemScript) call=ok loadedOrLoading=%s loaded=%s",
			tostring(deprecatedState.loadedOrLoading),
			tostring(deprecatedState.loaded)
		);
	else
		lines[#lines + 1] = string.format(
			"C_AddOns.IsAddOnLoaded(Blizzard_DeprecatedItemScript) call=unavailable status=%s",
			deprecatedState.status
		);
	end

	return table.concat(lines, "\n");
end

local function DescribeCallbackSecurity(listener, itemID, callbackFunction)
	local callbackMap = listener.callbacks;
	if type(callbackMap) ~= "table" then
		return "callbackMap=" .. type(callbackMap);
	end

	local bucket = callbackMap[itemID];
	if type(bucket) ~= "table" then
		return "bucket=" .. type(bucket) .. " after return";
	end

	for index = 1, #bucket do
		if rawequal(bucket[index], callbackFunction) then
			if type(issecurevariable) ~= "function" then
				return string.format("index=%d secure=unavailable", index);
			end

			local succeeded, isSecure, taintSource = pcall(issecurevariable, bucket, index);
			if not succeeded then
				return string.format("index=%d secure=check-error", index);
			end
			return string.format(
				"index=%d secure=%s taint=%s",
				index,
				tostring(isSecure),
				tostring(taintSource)
			);
		end
	end

	return string.format("bucketLength=%d callback=not-present-after-return", #bucket);
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
	local inspected = math.min(length, MAX_BUCKET_ENTRIES);
	local descriptions = {};
	for index = 1, inspected do
		local callback = bucket[index];
		descriptions[#descriptions + 1] = string.format(
			"%d:%s:%s:%s",
			index,
			type(callback),
			tostring(callback),
			DescribeSecureVariable(bucket, index, false)
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

local function AppendGeneric(record)
	local records = state.genericRecords;
	records[#records + 1] = record;
	if #records > MAX_GENERIC_RECORDS then
		table.remove(records, 1);
		state.genericEvictions = state.genericEvictions + 1;
	end
end

local function PreserveTarget(record)
	if not TARGET_ITEM_IDS[record.itemID] then
		return;
	end

	local records = state.targetRecords[record.itemID];
	if #records < MAX_TARGET_RECORDS then
		records[#records + 1] = record;
	else
		state.targetDrops[record.itemID] = state.targetDrops[record.itemID] + 1;
	end
end

local function PreserveTargetPrefire(record)
	local records = state.targetPrefireRecords[record.itemID];
	if #records < MAX_TARGET_PREFIRE_RECORDS then
		records[#records + 1] = record;
	else
		state.targetPrefireDrops[record.itemID] = state.targetPrefireDrops[record.itemID] + 1;
	end
end

local function CopyGetCallbacksCorrelation(record)
	if not record then
		return nil;
	end

	return {
		order = record.order,
		timestamp = record.timestamp,
		elapsed = record.elapsed,
		itemID = record.itemID,
		isTarget = record.isTarget,
	};
end

local retainedActiveHandler;
local CallErrorHandlerWrapper;

local function GetBoundedWrapperValueText(value, valueType)
	if valueType == "string" then
		if state.nativeIsSecretValueCaptured and nativeIsSecretValue(value) then
			return "<secret>";
		end

		local truncated = #value > MAX_ERROR_TEXT_BYTES;
		local text = nativeStringSub(value, 1, MAX_ERROR_TEXT_BYTES);
		text = nativeStringGsub(text, "\\", "\\\\");
		text = nativeStringGsub(text, "\"", "\\\"");
		text = nativeStringGsub(text, "\r", "\\r");
		text = nativeStringGsub(text, "\n", "\\n");
		text = nativeStringGsub(text, "\t", "\\t");
		if #text > MAX_ERROR_TEXT_BYTES then
			text = nativeStringSub(text, 1, MAX_ERROR_TEXT_BYTES);
			truncated = true;
		end
		return truncated and (text .. "<truncated>") or text;
	end

	if valueType == "nil" or valueType == "boolean" or valueType == "number" then
		return nativeTostring(value);
	end

	return "<" .. valueType .. " value omitted>";
end

local function AppendDispatchRecord(record)
	local records = state.dispatchRecords;
	local count = state.dispatchRecordCount;
	local head = state.dispatchRecordHead;
	local index;
	if count < MAX_DISPATCH_RECORDS then
		index = ((head + count - 1) % MAX_DISPATCH_RECORDS) + 1;
		state.dispatchRecordCount = count + 1;
	else
		index = head;
		state.dispatchRecordHead = (head % MAX_DISPATCH_RECORDS) + 1;
		state.dispatchRecordEvictions = state.dispatchRecordEvictions + 1;
	end
	record.bucket = nil;
	record.listener = nil;
	record.snapshot = nil;
	record.retainedSnapshot = nil;
	record.mappedSnapshot = nil;
	record.targetSnapshot = nil;
	record.targetMappedSnapshot = nil;
	records[index] = record;
end

local function PreserveTargetStructural(record)
	local records = state.targetStructuralRecords;
	if #records < MAX_TARGET_STRUCTURAL_RECORDS then
		records[#records + 1] = record;
	else
		state.targetStructuralDrops = state.targetStructuralDrops + 1;
	end
end

local function PreserveDispatchFailure(phase, listenerKind, id, errorValue)
	state.dispatchFailureCount = state.dispatchFailureCount + 1;
	local records = state.dispatchFailureRecords;
	if #records >= MAX_DISPATCH_FAILURE_RECORDS then
		state.dispatchFailureDrops = state.dispatchFailureDrops + 1;
		return;
	end
	local timestamp = GetTimestamp();
	records[#records + 1] = {
		phase = phase,
		listenerKind = listenerKind,
		id = id,
		timestamp = timestamp,
		elapsed = GetElapsed(timestamp),
		errorType = nativeType(errorValue),
		errorText = GetBoundedWrapperValueText(errorValue, nativeType(errorValue)),
	};
end

local function CaptureEntrySecurity(bucket, index, includeSecurity)
	if not includeSecurity then
		return "not-rechecked", "<not-rechecked>", "<not-rechecked>";
	end
	if nativeType(_G.issecurevariable) ~= "function" then
		return "unavailable", "<unavailable>", "<unavailable>";
	end
	local succeeded, secureValue, taintValue = nativePcall(_G.issecurevariable, bucket, index);
	if not succeeded then
		return "check-error", "<error>", "<error>";
	end
	return "ok", nativeTostring(secureValue), nativeTostring(taintValue);
end

local function CaptureBucketSnapshot(bucket, includeSecurity)
	local bucketType = nativeType(bucket);
	local snapshot = {
		bucketType = bucketType,
		identity = bucketType == "table" and nativeTostring(bucket) or "<nil>",
		length = nil,
		entries = {},
		rawValues = {},
		inspectionCapped = false,
	};
	if bucketType ~= "table" then
		return snapshot;
	end

	snapshot.length = #bucket;
	local inspected = math.min(snapshot.length, MAX_BUCKET_ENTRIES);
	for index = 1, inspected do
		local value = bucket[index];
		local securityStatus, secureValue, taintValue = CaptureEntrySecurity(bucket, index, includeSecurity);
		snapshot.rawValues[index] = value;
		snapshot.entries[#snapshot.entries + 1] = {
			index = index,
			valueType = nativeType(value),
			identity = nativeTostring(value),
			securityStatus = securityStatus,
			secure = secureValue,
			taint = taintValue,
		};
	end
	snapshot.inspectionCapped = snapshot.length > inspected;
	return snapshot;
end

local function GetMappedBucket(listener, id)
	if listener == nil then
		return nil, "listener=nil";
	end
	local callbackMap = listener.callbacks;
	if nativeType(callbackMap) ~= "table" then
		return nil, "callbackMapType=" .. nativeType(callbackMap);
	end
	local bucket = callbackMap[id];
	if nativeType(bucket) ~= "table" then
		return nil, "bucketType=" .. nativeType(bucket);
	end
	return bucket, "bucketType=table";
end

local function ResolveBucketGeneration(listenerKind, id, bucket)
	if nativeType(bucket) ~= "table" then
		return nil;
	end
	local bindings = state.bucketGenerationByReference[bucket];
	if bindings then
		for _, binding in ipairs(bindings) do
			if binding.listenerKind == listenerKind and binding.id == id then
				return binding.generation;
			end
		end
	else
		bindings = {};
		state.bucketGenerationByReference[bucket] = bindings;
	end

	state.bucketGenerationSequence = state.bucketGenerationSequence + 1;
	local generation = state.bucketGenerationSequence;
	bindings[#bindings + 1] = {
		listenerKind = listenerKind,
		id = id,
		generation = generation,
	};
	return generation;
end

local function CaptureMappedBucketSnapshot(listenerKind, listener, id, includeSecurity)
	local bucket, status = GetMappedBucket(listener, id);
	local snapshot = CaptureBucketSnapshot(bucket, includeSecurity);
	snapshot.status = status;
	snapshot.generation = ResolveBucketGeneration(listenerKind, id, bucket);
	return bucket, snapshot;
end

local function CompareBucketSnapshots(before, after)
	if before.bucketType ~= after.bucketType then
		return string.format("snapshot change observed bucketType=%s->%s", before.bucketType, after.bucketType);
	end
	if before.bucketType ~= "table" then
		return "no comparable bucket table";
	end
	if before.length ~= after.length then
		return string.format("snapshot change observed length=%s->%s", tostring(before.length), tostring(after.length));
	end
	local inspected = math.min(before.length or 0, after.length or 0, MAX_BUCKET_ENTRIES);
	for index = 1, inspected do
		if not nativeRawequal(before.rawValues[index], after.rawValues[index]) then
			return string.format(
				"snapshot change observed index=%d type=%s->%s identity=%s->%s",
				index,
				nativeType(before.rawValues[index]),
				nativeType(after.rawValues[index]),
				nativeTostring(before.rawValues[index]),
				nativeTostring(after.rawValues[index])
			);
		end
	end
	if before.inspectionCapped or after.inspectionCapped then
		return "no snapshot change in inspected prefix; comparison capped";
	end
	return "no snapshot change observed";
end

local function ApplyKnownEntrySecurity(snapshot, knownSnapshot)
	if not snapshot or not knownSnapshot then
		return;
	end
	for index, entry in ipairs(snapshot.entries) do
		local knownEntry = knownSnapshot.entries[index];
		if knownEntry and nativeRawequal(snapshot.rawValues[index], knownSnapshot.rawValues[index]) then
			entry.securityStatus = "from-open-snapshot:" .. knownEntry.securityStatus;
			entry.secure = knownEntry.secure;
			entry.taint = knownEntry.taint;
		end
	end
end

local function GetNearestOpenTarget()
	for index = #state.openDispatchStack, 1, -1 do
		local entry = state.openDispatchStack[index];
		if entry.isTarget then
			return entry;
		end
	end
	return nil;
end

local function GetNearestOpenCrossListener()
	for index = #state.openDispatchStack, 1, -1 do
		local entry = state.openDispatchStack[index];
		if entry.listenerKind == "quest" or entry.listenerKind == "spell" then
			return entry;
		end
	end
	return nil;
end

local function CaptureCompactDispatchContext()
	local stack = state.openDispatchStack;
	local active = stack[#stack];
	local target = GetNearestOpenTarget();
	local compactEntries = {};
	for index, entry in ipairs(stack) do
		compactEntries[index] = string.format(
			"%s:%s:%s:d%s:t%s",
			nativeTostring(entry.sequence),
			nativeTostring(entry.listenerKind),
			nativeTostring(entry.id),
			nativeTostring(entry.depth),
			nativeTostring(entry.targetAncestorSequence)
		);
	end
	return {
		status = active and "observed-dispatch-open" or "no-open-dispatch",
		openDepth = #stack,
		activeDispatchSequence = active and active.sequence or nil,
		activeListenerKind = active and active.listenerKind or nil,
		activeID = active and active.id or nil,
		targetAncestorSequence = target and target.sequence or nil,
		compactOpenStack = #compactEntries > 0 and table.concat(compactEntries, " > ") or "<empty>",
	};
end

local function CaptureBoundarySecurity(globalName)
	if nativeType(_G.issecurevariable) ~= "function" then
		return "unavailable", "<unavailable>", "<unavailable>";
	end
	local succeeded, isSecure, taintSource = nativePcall(_G.issecurevariable, globalName);
	if not succeeded then
		state.boundarySnapshotFailures = state.boundarySnapshotFailures + 1;
		return "check-error", "<error>", "<error>";
	end
	return "ok", nativeTostring(isSecure), nativeTostring(taintSource);
end

local function CaptureBoundaryGlobalSnapshot(globalName)
	local value = _G[globalName];
	local valueType = nativeType(value);
	local displayIdentity = valueType == "function"
		and nativeTostring(value) or GetBoundedWrapperValueText(value, valueType);
	local securityStatus, isSecure, taintSource = CaptureBoundarySecurity(globalName);
	local snapshot = {
		valueType = valueType,
		displayIdentity = displayIdentity,
		securityStatus = securityStatus,
		isSecure = isSecure,
		taintSource = taintSource,
	};
	if globalName == "CallErrorHandler" then
		snapshot.equalsOriginal = nativeRawequal(value, originalCallErrorHandler);
		snapshot.equalsInstalledWrapper = CallErrorHandlerWrapper ~= nil
			and nativeRawequal(value, CallErrorHandlerWrapper) or false;
		if snapshot.equalsOriginal then
			snapshot.identityClass = "original-captured";
		elseif snapshot.equalsInstalledWrapper then
			snapshot.identityClass = "installed-aico-wrapper";
		else
			snapshot.identityClass = "neither";
		end
	end
	return snapshot;
end

local function AddBoundaryLabel(record, label)
	record.labels[#record.labels + 1] = label;
end

local function ApplyBoundaryChangeLabels(record)
	local baseline = state.boundaryBaseline;
	if not baseline then
		return;
	end
	if record.xpcall.valueType ~= baseline.xpcall.valueType then
		AddBoundaryLabel(record, "XPCALL_BOUNDARY_TYPE_CHANGED");
	end
	if record.xpcall.displayIdentity ~= baseline.xpcall.displayIdentity then
		AddBoundaryLabel(record, "XPCALL_BOUNDARY_IDENTITY_CHANGED");
	end
	if record.callErrorHandler.valueType ~= baseline.callErrorHandler.valueType then
		AddBoundaryLabel(record, "CALLERRORHANDLER_BOUNDARY_TYPE_CHANGED");
	end
	if record.callErrorHandler.displayIdentity ~= baseline.callErrorHandler.displayIdentity then
		AddBoundaryLabel(record, "CALLERRORHANDLER_BOUNDARY_IDENTITY_CHANGED");
	end
end

local function PreserveBoundaryRecord(record)
	local records = state.boundaryRecords;
	if #records < MAX_BOUNDARY_PROVENANCE_RECORDS then
		state.boundaryRecordsRetained = state.boundaryRecordsRetained + 1;
		record.retainedOrdinal = state.boundaryRecordsRetained;
		records[#records + 1] = record;
	else
		state.boundaryRecordDrops = state.boundaryRecordDrops + 1;
	end
end

local function CaptureBoundaryRecord(phase, timestamp, detail)
	state.boundarySequence = state.boundarySequence + 1;
	local record = {
		boundarySequence = state.boundarySequence,
		phase = phase,
		timestamp = timestamp,
		elapsed = GetElapsed(timestamp),
		xpcall = CaptureBoundaryGlobalSnapshot("xpcall"),
		callErrorHandler = CaptureBoundaryGlobalSnapshot("CallErrorHandler"),
		labels = {},
	};
	if detail then
		for key, value in pairs(detail) do
			record[key] = value;
		end
	end
	if record.captureDispatchContext then
		record.dispatchContext = CaptureCompactDispatchContext();
		record.captureDispatchContext = nil;
	end

	local isTargetOpen = phase == "TARGET_DISPATCH_OPEN"
		or phase == "TARGET_NIL_BUCKET_REPEAT_DISPATCH_OPEN";
	if state.lastTargetOpenBoundary then
		record.deltaFromLastTargetOpen = timestamp - state.lastTargetOpenBoundary.timestamp;
	end
	if state.lastTargetNormalExitBoundary then
		record.deltaFromLastTargetNormalExit = timestamp - state.lastTargetNormalExitBoundary.timestamp;
	end
	if isTargetOpen and not state.boundaryBaseline then
		state.boundaryBaseline = {
			boundarySequence = record.boundarySequence,
			xpcall = record.xpcall,
			callErrorHandler = record.callErrorHandler,
		};
	end
	ApplyBoundaryChangeLabels(record);

	local context = record.dispatchContext;
	if phase == "CALLERRORHANDLER_ENTRY" then
		if context and context.targetAncestorSequence then
			AddBoundaryLabel(record, "B_BEFORE_TARGET_NORMAL_EXIT");
		elseif state.lastTargetNormalExitBoundary then
			AddBoundaryLabel(record, "B_AFTER_TARGET_NORMAL_EXIT");
			AddBoundaryLabel(record, "TARGET_NORMAL_EXIT_BEFORE_B");
		end
	elseif phase == "ACTIVE_HANDLER_ENTRY" then
		AddBoundaryLabel(
			record,
			record.callErrorWrapperCurrentlyActive and "C_DURING_ACTIVE_B" or "C_WITHOUT_ACTIVE_B"
		);
		if state.lastTargetNormalExitBoundary
			and not (context and context.targetAncestorSequence)
		then
			AddBoundaryLabel(record, "TARGET_NORMAL_EXIT_BEFORE_C");
		end
	end

	PreserveBoundaryRecord(record);
	if isTargetOpen then
		state.lastTargetOpenBoundary = record;
	elseif phase == "TARGET_DISPATCH_NORMAL_EXIT" then
		state.lastTargetNormalExitBoundary = record;
	end
	return record;
end

local function RunBoundaryCapture(phase, timestamp, detail)
	local succeeded, record = nativePcall(CaptureBoundaryRecord, phase, timestamp, detail);
	if not succeeded then
		state.boundarySnapshotFailures = state.boundarySnapshotFailures + 1;
		state.lastBoundarySnapshotFailurePhase = phase;
		return nil;
	end
	return record;
end

local function CopyDispatchFields(entry, phase, timestamp)
	return {
		phase = phase,
		timestamp = timestamp,
		elapsed = GetElapsed(timestamp),
		sequence = entry.sequence,
		listenerKind = entry.listenerKind,
		id = entry.id,
		depth = entry.depth,
		parentSequence = entry.parentSequence,
		targetAncestorSequence = entry.targetAncestorSequence,
		isTarget = entry.isTarget,
		bucketIdentity = entry.bucketIdentity,
		bucketGeneration = entry.bucketGeneration,
		bucketLength = entry.openSnapshot.length,
	};
end

local function FindTargetRegistrationCorrelation(generation, snapshot)
	local generationRecord = generation and state.targetGenerationRegistrations[generation];
	if generationRecord then
		return generationRecord.order, generationRecord.callbackIdentity;
	end
	if not snapshot or #snapshot.entries ~= 1 then
		return nil, nil;
	end
	local callbackIdentity = snapshot.entries[1].identity;
	local records = state.targetRecords[STRUCTURAL_TARGET_ITEM_ID];
	for index = #records, 1, -1 do
		local record = records[index];
		if record.callbackIdentity == callbackIdentity then
			return record.order, record.callbackIdentity;
		end
	end
	return nil, nil;
end

local function CaptureDispatchOpen(listenerKind, listener, id)
	state.dispatchSequence = state.dispatchSequence + 1;
	state.dispatchOpenCount = state.dispatchOpenCount + 1;
	local timestamp = GetTimestamp();
	local parent = state.openDispatchStack[#state.openDispatchStack];
	local nearestTarget = GetNearestOpenTarget();
	local crossListenerAncestor = GetNearestOpenCrossListener();
	local bucket, snapshot = CaptureMappedBucketSnapshot(
		listenerKind,
		listener,
		id,
		listenerKind == "item" and id == STRUCTURAL_TARGET_ITEM_ID
	);
	local isTarget = listenerKind == "item" and id == STRUCTURAL_TARGET_ITEM_ID;
	local sequence = state.dispatchSequence;
	local registrationOrder, registrationCallbackIdentity = FindTargetRegistrationCorrelation(
		snapshot.generation,
		snapshot
	);
	local entry = {
		sequence = sequence,
		listenerKind = listenerKind,
		listener = listener,
		id = id,
		parentSequence = parent and parent.sequence or nil,
		depth = #state.openDispatchStack + 1,
		bucket = bucket,
		bucketIdentity = snapshot.identity,
		bucketGeneration = snapshot.generation,
		openSnapshot = snapshot,
		isTarget = isTarget,
		targetAncestorSequence = isTarget and sequence or (nearestTarget and nearestTarget.sequence or nil),
		targetRelevant = isTarget or nearestTarget ~= nil,
		registrationOrder = registrationOrder,
		registrationCallbackIdentity = registrationCallbackIdentity,
		openTimestamp = timestamp,
	};
	state.openDispatchStack[#state.openDispatchStack + 1] = entry;
	state.maxDispatchDepth = math.max(state.maxDispatchDepth, entry.depth);

	local openRecord = CopyDispatchFields(entry, "DISPATCH_OPEN", timestamp);
	openRecord.registrationOrder = registrationOrder;
	openRecord.registrationCallbackIdentity = registrationCallbackIdentity;
	AppendDispatchRecord(openRecord);

	if isTarget then
		for index = 1, #state.openDispatchStack - 1 do
			local ancestor = state.openDispatchStack[index];
			if not ancestor.targetRelevant then
				ancestor.targetRelevant = true;
				local ancestorRecord = CopyDispatchFields(ancestor, "TARGET_ANCESTOR_OPEN", timestamp);
				ancestorRecord.relationship = "target-opened-while-ancestor-open";
				ancestorRecord.targetSequence = sequence;
				PreserveTargetStructural(ancestorRecord);
			end
		end

		local targetRecord = CopyDispatchFields(entry, "DISPATCH_OPEN", timestamp);
		targetRecord.snapshot = snapshot;
		targetRecord.relationship = parent and "target-opened-inside-existing-dispatch" or "outermost-observed";
		targetRecord.registrationOrder = registrationOrder;
		targetRecord.registrationCallbackIdentity = registrationCallbackIdentity;
		PreserveTargetStructural(targetRecord);
		state.targetDispatchOpenCount = state.targetDispatchOpenCount + 1;
		local boundaryPhase = entry.bucket == nil and state.targetDispatchOpenCount > 1
			and "TARGET_NIL_BUCKET_REPEAT_DISPATCH_OPEN" or "TARGET_DISPATCH_OPEN";
		RunBoundaryCapture(boundaryPhase, timestamp, {
			targetDispatchSequence = sequence,
			targetOpenOrdinal = state.targetDispatchOpenCount,
			listenerKind = listenerKind,
			id = id,
			bucketIdentity = snapshot.identity,
			bucketGeneration = snapshot.generation,
			bucketLength = snapshot.length,
			registrationOrder = registrationOrder,
			registrationCallbackIdentity = registrationCallbackIdentity,
			soleCallbackIdentity = #snapshot.entries == 1 and snapshot.entries[1].identity or nil,
			precedingTargetGetCallbacks = CopyGetCallbacksCorrelation(state.lastTargetGetCallbacks),
			captureDispatchContext = true,
		});

		if nearestTarget then
			local nestedRecord = CopyDispatchFields(entry, "TARGET_NESTED_DISPATCH", timestamp);
			nestedRecord.observation = "SAME-ID NESTED DISPATCH OBSERVED";
			nestedRecord.outerSequence = nearestTarget.sequence;
			nestedRecord.innerSequence = entry.sequence;
			nestedRecord.outerGeneration = nearestTarget.bucketGeneration;
			nestedRecord.innerGeneration = entry.bucketGeneration;
			nestedRecord.snapshot = snapshot;
			nestedRecord.registrationOrder = registrationOrder;
			nestedRecord.registrationCallbackIdentity = registrationCallbackIdentity;
			PreserveTargetStructural(nestedRecord);
		elseif crossListenerAncestor then
			local nestedRecord = CopyDispatchFields(entry, "TARGET_NESTED_DISPATCH", timestamp);
			nestedRecord.observation = "TARGET ITEM DISPATCH OBSERVED INSIDE CROSS-LISTENER DISPATCH";
			nestedRecord.outerSequence = crossListenerAncestor.sequence;
			nestedRecord.innerSequence = entry.sequence;
			PreserveTargetStructural(nestedRecord);
		end
	elseif nearestTarget then
		local nestedRecord = CopyDispatchFields(entry, "TARGET_NESTED_DISPATCH", timestamp);
		nestedRecord.observation = listenerKind == "quest" or listenerKind == "spell"
			and "CROSS-LISTENER NESTED DISPATCH OBSERVED" or "ITEM NESTED DISPATCH OBSERVED";
		nestedRecord.outerSequence = nearestTarget.sequence;
		nestedRecord.innerSequence = entry.sequence;
		PreserveTargetStructural(nestedRecord);
	end
end

local function CaptureDispatchNormalExit(listenerKind, listener, id)
	state.dispatchNormalExitCount = state.dispatchNormalExitCount + 1;
	local timestamp = GetTimestamp();
	local stack = state.openDispatchStack;
	local matchIndex;
	for index = #stack, 1, -1 do
		local candidate = stack[index];
		if nativeRawequal(candidate.listener, listener) and candidate.listenerKind == listenerKind and candidate.id == id then
			matchIndex = index;
			break;
		end
	end

	local entry = matchIndex and stack[matchIndex] or nil;
	local stackMatch = matchIndex ~= nil and matchIndex == #stack;
	local mappedBucket, mappedSnapshot = CaptureMappedBucketSnapshot(
		listenerKind,
		listener,
		id,
		entry and entry.isTarget or false
	);
	local exitRecord;
	if entry then
		exitRecord = CopyDispatchFields(entry, "DISPATCH_NORMAL_EXIT", timestamp);
	else
		exitRecord = {
			phase = "DISPATCH_NORMAL_EXIT",
			timestamp = timestamp,
			elapsed = GetElapsed(timestamp),
			sequence = nil,
			listenerKind = listenerKind,
			id = id,
			depth = #stack,
		};
	end
	exitRecord.stackMatch = stackMatch;
	exitRecord.mappedBucketIdentity = mappedSnapshot.identity;
	exitRecord.mappedBucketGeneration = mappedSnapshot.generation;
	exitRecord.mappedBucketLength = mappedSnapshot.length;
	exitRecord.mappedEqualsRetained = entry and nativeRawequal(mappedBucket, entry.bucket) or false;
	exitRecord.mappedRelationship = mappedBucket == nil and "nil"
		or (entry and nativeRawequal(mappedBucket, entry.bucket) and "same-retained-table" or "different-bucket");

	if not stackMatch then
		state.dispatchStackMismatchCount = state.dispatchStackMismatchCount + 1;
		exitRecord.mismatchReason = matchIndex and "matching-open-not-top" or "matching-open-not-found";
		local nearestTarget = GetNearestOpenTarget();
		if nearestTarget or (listenerKind == "item" and id == STRUCTURAL_TARGET_ITEM_ID) then
			local mismatchRecord = {
				phase = "STACK_MISMATCH",
				timestamp = timestamp,
				elapsed = GetElapsed(timestamp),
				sequence = entry and entry.sequence or nil,
				listenerKind = listenerKind,
				id = id,
				depth = #stack,
				targetAncestorSequence = nearestTarget and nearestTarget.sequence or nil,
				stackMatch = false,
				mismatchReason = exitRecord.mismatchReason,
			};
			PreserveTargetStructural(mismatchRecord);
		end
	else
		stack[#stack] = nil;
		local retainedSnapshot = CaptureBucketSnapshot(entry.bucket, entry.isTarget);
		retainedSnapshot.generation = entry.bucketGeneration;
		exitRecord.retainedSnapshot = retainedSnapshot;
		exitRecord.snapshotChange = entry.isTarget and CompareBucketSnapshots(entry.openSnapshot, retainedSnapshot) or nil;
		if entry.targetRelevant then
			local targetExitRecord = CopyDispatchFields(entry, "DISPATCH_NORMAL_EXIT", timestamp);
			targetExitRecord.stackMatch = true;
			targetExitRecord.retainedSnapshot = retainedSnapshot;
			targetExitRecord.mappedSnapshot = mappedSnapshot;
			targetExitRecord.mappedBucketIdentity = mappedSnapshot.identity;
			targetExitRecord.mappedBucketGeneration = mappedSnapshot.generation;
			targetExitRecord.mappedBucketLength = mappedSnapshot.length;
			targetExitRecord.mappedEqualsRetained = nativeRawequal(mappedBucket, entry.bucket);
			targetExitRecord.mappedRelationship = exitRecord.mappedRelationship;
			targetExitRecord.snapshotChange = entry.isTarget
				and CompareBucketSnapshots(entry.openSnapshot, retainedSnapshot) or nil;
			PreserveTargetStructural(targetExitRecord);
		end
		if entry.isTarget and mappedSnapshot.generation and mappedSnapshot.generation ~= entry.bucketGeneration then
			PreserveTargetStructural({
				phase = "TARGET_NEW_GENERATION",
				observation = "SAME-ID NEW BUCKET GENERATION OBSERVED",
				timestamp = timestamp,
				elapsed = GetElapsed(timestamp),
				sequence = entry.sequence,
				listenerKind = listenerKind,
				id = id,
				depth = entry.depth,
				parentSequence = entry.parentSequence,
				targetAncestorSequence = entry.sequence,
				outerGeneration = entry.bucketGeneration,
				newGeneration = mappedSnapshot.generation,
				mappedBucketIdentity = mappedSnapshot.identity,
				mappedBucketLength = mappedSnapshot.length,
			});
		end
	end
	AppendDispatchRecord(exitRecord);
	if stackMatch and entry and entry.isTarget then
		RunBoundaryCapture("TARGET_DISPATCH_NORMAL_EXIT", timestamp, {
			targetDispatchSequence = entry.sequence,
			targetOpenOrdinal = state.targetDispatchOpenCount,
			listenerKind = listenerKind,
			id = id,
			bucketIdentity = entry.bucketIdentity,
			bucketGeneration = entry.bucketGeneration,
			bucketLength = mappedSnapshot.length,
			mappedRelationship = exitRecord.mappedRelationship,
			captureDispatchContext = true,
		});
	end
end

local function CaptureTargetRegistrationGeneration(listener, itemID, record)
	if itemID ~= STRUCTURAL_TARGET_ITEM_ID then
		return;
	end
	local bucket, snapshot = CaptureMappedBucketSnapshot("item", listener, itemID, false);
	record.mappedBucketIdentity = snapshot.identity;
	record.mappedBucketGeneration = snapshot.generation;
	record.mappedBucketLength = snapshot.length;
	if snapshot.generation then
		if state.targetGenerationRegistrations[snapshot.generation] == nil then
			local keys = state.targetGenerationRegistrationKeys;
			keys[#keys + 1] = snapshot.generation;
			if #keys > MAX_TARGET_STRUCTURAL_RECORDS then
				local evictedGeneration = table.remove(keys, 1);
				state.targetGenerationRegistrations[evictedGeneration] = nil;
				state.targetGenerationRegistrationEvictions = state.targetGenerationRegistrationEvictions + 1;
			end
		end
		state.targetGenerationRegistrations[snapshot.generation] = {
			order = record.order,
			callbackIdentity = record.callbackIdentity,
		};
	end

	local openTarget = GetNearestOpenTarget();
	if openTarget and bucket and not nativeRawequal(bucket, openTarget.bucket) then
		PreserveTargetStructural({
			phase = "TARGET_NEW_GENERATION",
			observation = "SAME-ID NEW BUCKET GENERATION OBSERVED",
			timestamp = record.timestamp,
			elapsed = record.elapsed,
			sequence = openTarget.sequence,
			listenerKind = "item",
			id = itemID,
			depth = openTarget.depth,
			parentSequence = openTarget.parentSequence,
			targetAncestorSequence = openTarget.sequence,
			outerGeneration = openTarget.bucketGeneration,
			newGeneration = snapshot.generation,
			mappedBucketIdentity = snapshot.identity,
			mappedBucketLength = snapshot.length,
			registrationOrder = record.order,
			registrationCallbackIdentity = record.callbackIdentity,
		});
	end
end

local function CaptureHandlerDispatchContext(timestamp)
	local stack = state.openDispatchStack;
	local active = stack[#stack];
	local target = GetNearestOpenTarget();
	local stackSnapshot = {};
	for index, entry in ipairs(stack) do
		stackSnapshot[index] = {
			sequence = entry.sequence,
			listenerKind = entry.listenerKind,
			id = entry.id,
			depth = entry.depth,
			parentSequence = entry.parentSequence,
			bucketIdentity = entry.bucketIdentity,
			bucketGeneration = entry.bucketGeneration,
			isTarget = entry.isTarget,
			targetAncestorSequence = entry.targetAncestorSequence,
		};
	end
	local context = {
		status = active and "handlerObservedWhileDispatchOpen" or "no-open-dispatch",
		openDepth = #stack,
		activeDispatchSequence = active and active.sequence or nil,
		activeListenerKind = active and active.listenerKind or nil,
		activeID = active and active.id or nil,
		activeDepth = active and active.depth or nil,
		activeParentSequence = active and active.parentSequence or nil,
		targetAncestorSequence = target and target.sequence or nil,
		stackSnapshot = stackSnapshot,
	};
	if active then
		local mappedBucket, mappedSnapshot = CaptureMappedBucketSnapshot(
			active.listenerKind,
			active.listener,
			active.id,
			false
		);
		context.activeRetainedBucketIdentity = active.bucketIdentity;
		context.activeRetainedBucketGeneration = active.bucketGeneration;
		context.activeMappedBucketIdentity = mappedSnapshot.identity;
		context.activeMappedBucketGeneration = mappedSnapshot.generation;
		context.activeMappedBucketLength = mappedSnapshot.length;
		context.activeMappedEqualsRetained = nativeRawequal(mappedBucket, active.bucket);
		context.activeMappedRelationship = mappedBucket == nil and "nil"
			or (context.activeMappedEqualsRetained and "same-retained-table" or "different-bucket");
		context.activeMappedSnapshot = mappedSnapshot;
		context.activeRetainedSnapshot = CaptureBucketSnapshot(active.bucket, false);
		context.activeRetainedSnapshot.generation = active.bucketGeneration;
		ApplyKnownEntrySecurity(context.activeRetainedSnapshot, active.openSnapshot);
		context.activeSnapshotChange = CompareBucketSnapshots(active.openSnapshot, context.activeRetainedSnapshot);
	end
	if target then
		local targetMappedBucket, targetMappedSnapshot = CaptureMappedBucketSnapshot(
			"item",
			target.listener,
			target.id,
			false
		);
		local retainedSnapshot = CaptureBucketSnapshot(target.bucket, false);
		retainedSnapshot.generation = target.bucketGeneration;
		ApplyKnownEntrySecurity(retainedSnapshot, target.openSnapshot);
		context.targetSequence = target.sequence;
		context.targetDepth = target.depth;
		context.targetParentSequence = target.parentSequence;
		context.targetRetainedBucketIdentity = target.bucketIdentity;
		context.targetRetainedBucketGeneration = target.bucketGeneration;
		context.targetRetainedSnapshot = retainedSnapshot;
		context.targetMappedBucketIdentity = targetMappedSnapshot.identity;
		context.targetMappedBucketGeneration = targetMappedSnapshot.generation;
		context.targetMappedBucketLength = targetMappedSnapshot.length;
		context.targetMappedEqualsRetained = nativeRawequal(targetMappedBucket, target.bucket);
		context.targetMappedRelationship = targetMappedBucket == nil and "nil"
			or (context.targetMappedEqualsRetained and "same-retained-table" or "different-bucket");
		context.targetMappedSnapshot = targetMappedSnapshot;
		context.targetSnapshotChange = CompareBucketSnapshots(target.openSnapshot, retainedSnapshot);
		PreserveTargetStructural({
			phase = "HANDLER_DISPATCH_CONTEXT",
			timestamp = timestamp,
			elapsed = GetElapsed(timestamp),
			sequence = active and active.sequence or nil,
			listenerKind = active and active.listenerKind or nil,
			id = active and active.id or nil,
			depth = active and active.depth or #stack,
			parentSequence = active and active.parentSequence or nil,
			targetAncestorSequence = target.sequence,
			targetSequence = target.sequence,
			bucketIdentity = target.bucketIdentity,
			bucketGeneration = target.bucketGeneration,
			bucketLength = retainedSnapshot.length,
			mappedBucketIdentity = targetMappedSnapshot.identity,
			mappedBucketGeneration = targetMappedSnapshot.generation,
			mappedBucketLength = targetMappedSnapshot.length,
			retainedSnapshot = retainedSnapshot,
			mappedSnapshot = targetMappedSnapshot,
			mappedEqualsRetained = context.targetMappedEqualsRetained,
			mappedRelationship = context.targetMappedRelationship,
			snapshotChange = context.targetSnapshotChange,
		});
		if targetMappedSnapshot.generation
			and targetMappedSnapshot.generation ~= target.bucketGeneration
		then
			PreserveTargetStructural({
				phase = "TARGET_NEW_GENERATION",
				observation = "SAME-ID NEW BUCKET GENERATION OBSERVED",
				timestamp = timestamp,
				elapsed = GetElapsed(timestamp),
				sequence = target.sequence,
				listenerKind = "item",
				id = target.id,
				depth = target.depth,
				parentSequence = target.parentSequence,
				targetAncestorSequence = target.sequence,
				outerGeneration = target.bucketGeneration,
				newGeneration = targetMappedSnapshot.generation,
				mappedBucketIdentity = targetMappedSnapshot.identity,
				mappedBucketLength = targetMappedSnapshot.length,
				mappedRelationship = context.targetMappedRelationship,
			});
		end
	elseif active then
		PreserveTargetStructural({
			phase = "HANDLER_DISPATCH_CONTEXT",
			timestamp = timestamp,
			elapsed = GetElapsed(timestamp),
			sequence = active.sequence,
			listenerKind = active.listenerKind,
			id = active.id,
			depth = active.depth,
			parentSequence = active.parentSequence,
			targetAncestorSequence = nil,
			bucketIdentity = active.bucketIdentity,
			bucketGeneration = active.bucketGeneration,
			bucketLength = context.activeRetainedSnapshot.length,
			mappedBucketIdentity = context.activeMappedSnapshot.identity,
			mappedBucketGeneration = context.activeMappedSnapshot.generation,
			mappedBucketLength = context.activeMappedSnapshot.length,
			retainedSnapshot = context.activeRetainedSnapshot,
			mappedSnapshot = context.activeMappedSnapshot,
			mappedEqualsRetained = context.activeMappedEqualsRetained,
			mappedRelationship = context.activeMappedRelationship,
			snapshotChange = context.activeSnapshotChange,
			observation = "HANDLER OBSERVED WHILE NON-TARGET DISPATCH OPEN",
		});
	else
		PreserveTargetStructural({
			phase = "HANDLER_DISPATCH_CONTEXT",
			timestamp = timestamp,
			elapsed = GetElapsed(timestamp),
			depth = 0,
			observation = "NO TRACKED DISPATCH OPEN AT HANDLER ENTRY",
		});
	end
	return context;
end

local function RunDispatchProbe(phase, captureFunction, listenerKind, listener, id)
	local succeeded, errorValue = nativePcall(captureFunction, listenerKind, listener, id);
	if not succeeded then
		PreserveDispatchFailure(phase, listenerKind, id, errorValue);
	end
end

local function InstallListenerDispatchProbe(listenerKind, listener)
	local status = {
		listenerKind = listenerKind,
		listenerAvailable = listener ~= nil,
		getCallbacksHooked = false,
		fireCallbacksHooked = false,
	};
	state.listenerHookStatus[listenerKind] = status;
	if listener == nil then
		status.status = "listener unavailable";
		return;
	end
	if nativeType(listener.GetCallbacks) ~= "function" or nativeType(listener.FireCallbacks) ~= "function" then
		status.status = "required methods unavailable";
		return;
	end

	local getCallbacksHook = function(hookedListener, id)
		RunDispatchProbe("DISPATCH_OPEN", CaptureDispatchOpen, listenerKind, hookedListener, id);
	end;
	local fireCallbacksHook = function(hookedListener, id)
		RunDispatchProbe("DISPATCH_NORMAL_EXIT", CaptureDispatchNormalExit, listenerKind, hookedListener, id);
	end;
	local openSucceeded, openError = nativePcall(hooksecurefunc, listener, "GetCallbacks", getCallbacksHook);
	status.getCallbacksHooked = openSucceeded;
	if not openSucceeded then
		PreserveDispatchFailure("INSTALL_GETCALLBACKS_HOOK", listenerKind, nil, openError);
	end
	local exitSucceeded, exitError = nativePcall(hooksecurefunc, listener, "FireCallbacks", fireCallbacksHook);
	status.fireCallbacksHooked = exitSucceeded;
	if not exitSucceeded then
		PreserveDispatchFailure("INSTALL_FIRECALLBACKS_HOOK", listenerKind, nil, exitError);
	end
	status.status = openSucceeded and exitSucceeded and "installed" or "partial-or-failed";
end

local function AppendActiveHandlerWrapperRecord(record)
	local records = state.activeHandlerWrapperRecords;
	local count = state.activeHandlerWrapperRecordCount;
	local head = state.activeHandlerWrapperRecordHead;
	local index;
	if count < MAX_ACTIVE_HANDLER_WRAPPER_RECORDS then
		index = ((head + count - 1) % MAX_ACTIVE_HANDLER_WRAPPER_RECORDS) + 1;
		state.activeHandlerWrapperRecordCount = count + 1;
	else
		index = head;
		state.activeHandlerWrapperRecordHead = (head % MAX_ACTIVE_HANDLER_WRAPPER_RECORDS) + 1;
		state.activeHandlerWrapperEvictions = state.activeHandlerWrapperEvictions + 1;
	end
	records[index] = record;
end

local function PackHandlerReturns(...)
	return {
		count = nativeSelect("#", ...),
		...,
	};
end

local function AppendCallErrorWrapperRecord(record)
	local records = state.callErrorWrapperRecords;
	local count = state.callErrorWrapperRecordCount;
	local head = state.callErrorWrapperRecordHead;
	local index;
	if count < MAX_CALLERROR_WRAPPER_RECORDS then
		index = ((head + count - 1) % MAX_CALLERROR_WRAPPER_RECORDS) + 1;
		state.callErrorWrapperRecordCount = count + 1;
	else
		index = head;
		state.callErrorWrapperRecordHead = (head % MAX_CALLERROR_WRAPPER_RECORDS) + 1;
		state.callErrorWrapperEvictions = state.callErrorWrapperEvictions + 1;
	end
	records[index] = record;
end

CallErrorHandlerWrapper = function(...)
	state.callErrorWrapperEntryCount = state.callErrorWrapperEntryCount + 1;
	local sequence = state.callErrorWrapperEntryCount;
	local timestamp = GetTimestamp();
	local errorValue = ...;
	local errorType = nativeType(errorValue);
	local record = {
		sequence = sequence,
		entryTimestamp = timestamp,
		entryElapsed = GetElapsed(timestamp),
		argumentCount = nativeSelect("#", ...),
		errorType = errorType,
		errorText = GetBoundedWrapperValueText(errorValue, errorType),
		precedingGetCallbacks = CopyGetCallbacksCorrelation(state.lastGetCallbacks),
		precedingTargetGetCallbacks = CopyGetCallbacksCorrelation(state.lastTargetGetCallbacks),
		lastCompletedAddon = state.lastCompletedAddon,
		playerLoginSeen = state.milestones.playerLogin ~= nil,
		playerEnteringWorldSeen = state.milestones.playerEnteringWorld ~= nil,
		normalReturn = false,
	};
	local entryBoundary = RunBoundaryCapture("CALLERRORHANDLER_ENTRY", timestamp, {
		callErrorWrapperSequence = sequence,
		errorType = errorType,
		errorText = record.errorText,
		precedingTargetGetCallbacks = record.precedingTargetGetCallbacks,
		captureDispatchContext = true,
	});
	record.boundaryEntrySequence = entryBoundary and entryBoundary.boundarySequence or nil;
	record.boundaryEntryLabels = entryBoundary and entryBoundary.labels or {};
	record.xpcallSnapshot = entryBoundary and entryBoundary.xpcall or nil;
	record.callErrorHandlerSnapshot = entryBoundary and entryBoundary.callErrorHandler or nil;
	record.dispatchContext = entryBoundary and entryBoundary.dispatchContext or {
		status = "boundary-diagnostic-context-failed",
		openDepth = #state.openDispatchStack,
		compactOpenStack = "<capture failed>",
	};
	state.lastCallErrorWrapperRecord = record;
	state.activeCallErrorWrapperRecord = record;
	AppendCallErrorWrapperRecord(record);

	local results = PackHandlerReturns(originalCallErrorHandler(...));
	local returnTimestamp = GetTimestamp();
	state.callErrorWrapperReturnCount = state.callErrorWrapperReturnCount + 1;
	record.normalReturn = true;
	record.returnTimestamp = returnTimestamp;
	record.returnElapsed = GetElapsed(returnTimestamp);
	record.returnValueCount = results.count;
	if results.count > 0 then
		record.firstReturnType = nativeType(results[1]);
		record.firstReturnText = GetBoundedWrapperValueText(results[1], record.firstReturnType);
	else
		record.firstReturnType = "<none>";
		record.firstReturnText = "<none>";
	end
	local returnBoundary = RunBoundaryCapture("CALLERRORHANDLER_RETURN", returnTimestamp, {
		callErrorWrapperSequence = sequence,
		deltaFromCallErrorEntry = returnTimestamp - timestamp,
		returnValueCount = results.count,
		firstReturnType = record.firstReturnType,
		firstReturnText = record.firstReturnText,
		captureDispatchContext = true,
	});
	record.boundaryReturnSequence = returnBoundary and returnBoundary.boundarySequence or nil;
	record.boundaryReturnLabels = returnBoundary and returnBoundary.labels or {};
	record.returnDispatchContext = returnBoundary and returnBoundary.dispatchContext or nil;
	record.returnXpcallSnapshot = returnBoundary and returnBoundary.xpcall or nil;
	record.returnCallErrorHandlerSnapshot = returnBoundary and returnBoundary.callErrorHandler or nil;
	if nativeRawequal(state.activeCallErrorWrapperRecord, record) then
		state.activeCallErrorWrapperRecord = nil;
	end

	return nativeUnpack(results, 1, results.count);
end

local function ActiveHandlerWrapper(...)
	state.activeHandlerWrapperEntryCount = state.activeHandlerWrapperEntryCount + 1;
	local sequence = state.activeHandlerWrapperEntryCount;
	local timestamp = GetTimestamp();
	local errorValue = ...;
	local errorType = nativeType(errorValue);
	local record = {
		sequence = sequence,
		handlerTarget = state.activeHandlerWrapperTarget,
		entryTimestamp = timestamp,
		entryElapsed = GetElapsed(timestamp),
		errorType = errorType,
		errorText = GetBoundedWrapperValueText(errorValue, errorType),
		precedingGetCallbacks = CopyGetCallbacksCorrelation(state.lastGetCallbacks),
		precedingTargetGetCallbacks = CopyGetCallbacksCorrelation(state.lastTargetGetCallbacks),
		lastCompletedAddon = state.lastCompletedAddon,
		playerLoginSeen = state.milestones.playerLogin ~= nil,
		playerEnteringWorldSeen = state.milestones.playerEnteringWorld ~= nil,
		normalReturn = false,
	};
	local activeCallErrorRecord = state.activeCallErrorWrapperRecord;
	local mostRecentCallErrorRecord = activeCallErrorRecord or state.lastCallErrorWrapperRecord;
	record.callErrorCorrelation = {
		mostRecentSequence = mostRecentCallErrorRecord and mostRecentCallErrorRecord.sequence or nil,
		currentlyActive = activeCallErrorRecord ~= nil,
		deltaFromEntry = mostRecentCallErrorRecord
			and (timestamp - mostRecentCallErrorRecord.entryTimestamp) or nil,
		errorTextMatches = mostRecentCallErrorRecord ~= nil
			and errorType == mostRecentCallErrorRecord.errorType
			and record.errorText == mostRecentCallErrorRecord.errorText or false,
	};
	record.callErrorCorrelation.label = record.callErrorCorrelation.currentlyActive
		and "ACTIVE HANDLER DURING OBSERVED CALLERRORHANDLER"
		or "ACTIVE HANDLER WITHOUT OBSERVED ACTIVE CALLERRORHANDLER";
	local handlerBoundary = RunBoundaryCapture("ACTIVE_HANDLER_ENTRY", timestamp, {
		activeHandlerWrapperSequence = sequence,
		errorType = errorType,
		errorText = record.errorText,
		mostRecentCallErrorWrapperSequence = record.callErrorCorrelation.mostRecentSequence,
		callErrorWrapperCurrentlyActive = record.callErrorCorrelation.currentlyActive,
		deltaFromCallErrorEntry = record.callErrorCorrelation.deltaFromEntry,
		callErrorTextMatches = record.callErrorCorrelation.errorTextMatches,
		captureDispatchContext = true,
	});
	record.boundaryEntrySequence = handlerBoundary and handlerBoundary.boundarySequence or nil;
	record.boundaryEntryLabels = handlerBoundary and handlerBoundary.labels or {};
	record.xpcallSnapshot = handlerBoundary and handlerBoundary.xpcall or nil;
	record.callErrorHandlerSnapshot = handlerBoundary and handlerBoundary.callErrorHandler or nil;
	local contextSucceeded, contextOrError = nativePcall(CaptureHandlerDispatchContext, timestamp);
	if contextSucceeded then
		record.dispatchContext = contextOrError;
	else
		PreserveDispatchFailure("HANDLER_DISPATCH_CONTEXT", nil, nil, contextOrError);
		record.dispatchContext = {
			status = "diagnostic-context-failed",
			openDepth = #state.openDispatchStack,
			stackSnapshot = {},
		};
	end
	AppendActiveHandlerWrapperRecord(record);

	local results = PackHandlerReturns(retainedActiveHandler(...));
	local returnTimestamp = GetTimestamp();
	state.activeHandlerWrapperReturnCount = state.activeHandlerWrapperReturnCount + 1;
	record.normalReturn = true;
	record.returnTimestamp = returnTimestamp;
	record.returnElapsed = GetElapsed(returnTimestamp);
	record.returnValueCount = results.count;
	if results.count > 0 then
		record.firstReturnType = nativeType(results[1]);
		record.firstReturnText = GetBoundedWrapperValueText(results[1], record.firstReturnType);
	else
		record.firstReturnType = "<none>";
		record.firstReturnText = "<none>";
	end

	return nativeUnpack(results, 1, results.count);
end

local function InstallActiveHandlerWrapper(handlerTarget, installTrigger)
	if state.activeHandlerWrapperInstallAttempted then
		return;
	end
	local installTimestamp = GetTimestamp();
	state.activeHandlerWrapperInstallAttempted = true;
	state.activeHandlerWrapperTarget = handlerTarget;
	state.activeHandlerWrapperInstallTrigger = installTrigger;
	state.activeHandlerWrapperInstallTimestamp = installTimestamp;
	state.activeHandlerWrapperInstallElapsed = GetElapsed(installTimestamp);
	state.getErrorHandlerGlobalSecurity = DescribeSecureVariable(nil, "geterrorhandler", true);
	state.setErrorHandlerGlobalSecurity = DescribeSecureVariable(nil, "seterrorhandler", true);
	state.publicSetterTypeAtHandlerInstall = nativeType(_G.seterrorhandler);
	state.publicSetterIdentityAtHandlerInstall = state.publicSetterTypeAtHandlerInstall == "function"
		and nativeTostring(_G.seterrorhandler) or "<not-function>";

	if not state.nativeSetterCaptured then
		state.activeHandlerWrapperInstallStatus = "native seterrorhandler was not captured as a function";
		return;
	end
	if not state.nativeGetterCaptured then
		state.activeHandlerWrapperInstallStatus = "native geterrorhandler was not captured as a function";
		return;
	end
	if not state.nativeUnpackCaptured
		or nativeType(nativeSelect) ~= "function"
		or nativeType(nativeStringGsub) ~= "function"
		or nativeType(nativeStringSub) ~= "function"
	then
		state.activeHandlerWrapperInstallStatus = "required native return/text helper unavailable";
		return;
	end

	local activeHandler = nativeGetErrorHandler();
	state.retainedActiveHandlerType = nativeType(activeHandler);
	state.retainedActiveHandlerIdentity = state.retainedActiveHandlerType == "function"
		and nativeTostring(activeHandler) or "<not-function>";
	if state.retainedActiveHandlerType ~= "function" then
		state.activeHandlerWrapperInstallStatus = "selected active handler was not a function";
		return;
	end

	retainedActiveHandler = activeHandler;
	nativeSetErrorHandler(ActiveHandlerWrapper);
	local installedHandler = nativeGetErrorHandler();
	state.activeHandlerAfterInstallType = nativeType(installedHandler);
	state.activeHandlerAfterInstallIdentity = state.activeHandlerAfterInstallType == "function"
		and nativeTostring(installedHandler) or "<not-function>";
	state.activeHandlerWrapperInstalled = rawequal(installedHandler, ActiveHandlerWrapper);
	state.activeHandlerWrapperInstallStatus = state.activeHandlerWrapperInstalled
		and "installed and verified active" or "setter returned but wrapper identity was not active";
end

local function InstallCallErrorHandlerWrapper()
	if state.callErrorWrapperInstallAttempted then
		return;
	end
	state.callErrorWrapperInstallAttempted = true;
	local installTimestamp = GetTimestamp();
	state.callErrorWrapperInstallTimestamp = installTimestamp;
	state.callErrorWrapperInstallElapsed = GetElapsed(installTimestamp);
	state.callErrorHandlerSecurityBeforeReplacement = DescribeSecureVariable(nil, "CallErrorHandler", true);

	if state.bugGrabberEnabledForCharacter ~= false then
		state.callErrorWrapperInstallStatus = "BugGrabber-off character state was not verified";
		return;
	end
	if not state.activeHandlerWrapperInstalled
		or state.activeHandlerWrapperTarget ~= "pre-existing handler at PLAYER_ENTERING_WORLD; !BugGrabber disabled"
	then
		state.callErrorWrapperInstallStatus = "BugGrabber-off active-handler control was not installed and verified";
		return;
	end
	if state.bugSackLoadedAtInstallGate ~= false
		or state.bugSackLoadedOrLoadingAtInstallGate ~= false
	then
		state.callErrorWrapperInstallStatus = "BugSack-off install gate was not verified";
		return;
	end
	if not state.originalCallErrorHandlerCaptured then
		state.callErrorWrapperInstallStatus = "original CallErrorHandler was not captured as a function";
		return;
	end
	if not state.nativeUnpackCaptured or nativeType(nativeSelect) ~= "function" then
		state.callErrorWrapperInstallStatus = "required native return helper unavailable";
		return;
	end
	CaptureCallErrorHandlerIdentity("F before direct-wrapper identity guard", true);
	if not rawequal(_G.CallErrorHandler, originalCallErrorHandler) then
		state.callErrorWrapperInstallStatus = "global CallErrorHandler changed before diagnostic replacement";
		CaptureCallErrorHandlerIdentity("F guard rejected identity mismatch", true);
		return;
	end

	_G.CallErrorHandler = CallErrorHandlerWrapper;
	state.callErrorHandlerAfterReplacementType = nativeType(_G.CallErrorHandler);
	state.callErrorHandlerAfterReplacementIdentity = state.callErrorHandlerAfterReplacementType == "function"
		and nativeTostring(_G.CallErrorHandler) or "<not-function>";
	state.callErrorHandlerSecurityAfterReplacement = DescribeSecureVariable(nil, "CallErrorHandler", true);
	state.callErrorWrapperInstalled = rawequal(_G.CallErrorHandler, CallErrorHandlerWrapper);
	state.callErrorWrapperInstallStatus = state.callErrorWrapperInstalled
		and "installed and verified global" or "assignment returned but wrapper identity was not global";
	state.callErrorHandlerDirectWrapperValue = _G.CallErrorHandler;
	CaptureCallErrorHandlerIdentity("G after direct-wrapper installation", true);
end

local function DetectBugGrabberEnabledForCharacter()
	if nativeType(C_AddOns) ~= "table"
		or nativeType(C_AddOns.GetAddOnEnableState) ~= "function"
	then
		state.bugGrabberEnableCheckStatus = "C_AddOns.GetAddOnEnableState unavailable";
		return nil;
	end

	local character;
	if nativeType(_G.UnitGUID) == "function" then
		character = _G.UnitGUID("player");
	end

	local succeeded, enableState;
	if nativeType(character) == "string" then
		succeeded, enableState = pcall(C_AddOns.GetAddOnEnableState, "!BugGrabber", character);
	else
		succeeded, enableState = pcall(C_AddOns.GetAddOnEnableState, "!BugGrabber");
	end
	if not succeeded then
		state.bugGrabberEnableCheckStatus = "GetAddOnEnableState query failed";
		return nil;
	end
	if nativeType(enableState) ~= "number" then
		state.bugGrabberEnableCheckStatus = "GetAddOnEnableState returned non-number";
		return nil;
	end

	state.bugGrabberEnabledForCharacter = enableState > 0;
	state.bugGrabberEnableCheckStatus = "ok enableState=" .. nativeTostring(enableState);
	return state.bugGrabberEnabledForCharacter;
end

local function InstallBugGrabberOffBoundaryProbe()
	local bugSackState = GetAddonLoadedState("BugSack");
	if not bugSackState.available then
		state.bugSackInstallGateStatus = bugSackState.status;
		state.callErrorWrapperInstallStatus = "not attempted: BugSack loaded-state query unavailable";
		return;
	end
	state.bugSackLoadedAtInstallGate = bugSackState.loaded == true;
	state.bugSackLoadedOrLoadingAtInstallGate = bugSackState.loadedOrLoading == true;
	if state.bugSackLoadedAtInstallGate or state.bugSackLoadedOrLoadingAtInstallGate then
		state.bugSackInstallGateStatus = "blocked: BugSack loaded or loading";
		state.callErrorWrapperInstallStatus = "not attempted: BugSack was loaded or loading";
		return;
	end
	state.bugSackInstallGateStatus = "verified not loaded or loading";
	InstallCallErrorHandlerWrapper();
end

local function CaptureRegistration(listener, itemID, callbackFunction)
	state.registrationCount = state.registrationCount + 1;
	local timestamp = GetTimestamp();
	local record = {
		order = state.registrationCount,
		timestamp = timestamp,
		elapsed = GetElapsed(timestamp),
		itemID = itemID,
		callbackType = type(callbackFunction),
		callbackIdentity = tostring(callbackFunction),
		security = DescribeCallbackSecurity(listener, itemID, callbackFunction),
		lastCompletedAddon = state.lastCompletedAddon,
		chonkyLoaded = IsAddonLoaded("ChonkyCharacterSheet"),
		retailUIResearchLoaded = IsAddonLoaded("RetailUIResearch"),
		playerLoginSeen = state.milestones.playerLogin ~= nil,
		playerEnteringWorldSeen = state.milestones.playerEnteringWorld ~= nil,
		stack = CaptureStack(),
	};
	if TARGET_ITEM_IDS[itemID] then
		record.callableState = CaptureCallableState();
	end
	local generationSucceeded, generationError = nativePcall(
		CaptureTargetRegistrationGeneration,
		listener,
		itemID,
		record
	);
	if not generationSucceeded then
		PreserveDispatchFailure("REGISTER_RETURN_GENERATION", "item", itemID, generationError);
	end

	AppendGeneric(record);
	PreserveTarget(record);
end

CaptureCallErrorHandlerIdentity("A file-scope initial capture", true);

assert(ItemEventListener ~= nil, "ItemEventListener unavailable during observer load");
assert(
	type(ItemEventListener.AddCallback) == "function",
	"ItemEventListener:AddCallback unavailable during observer load"
);
assert(
	type(ItemEventListener.GetCallbacks) == "function",
	"ItemEventListener:GetCallbacks unavailable during observer load"
);
assert(type(_G.CallErrorHandler) == "function", "CallErrorHandler unavailable during observer load");

DetectBugGrabberEnabledForCharacter();

hooksecurefunc(ItemEventListener, "AddCallback", CaptureRegistration);

hooksecurefunc(ItemEventListener, "GetCallbacks", function(listener, itemID)
	state.getCallbacksCount = state.getCallbacksCount + 1;
	local timestamp = GetTimestamp();
	local correlation = {
		order = state.getCallbacksCount,
		timestamp = timestamp,
		elapsed = GetElapsed(timestamp),
		itemID = itemID,
		isTarget = TARGET_ITEM_IDS[itemID] == true,
	};
	state.lastGetCallbacks = correlation;
	if not correlation.isTarget then
		return;
	end
	state.lastTargetGetCallbacks = correlation;

	PreserveTargetPrefire({
		order = state.getCallbacksCount,
		timestamp = timestamp,
		elapsed = GetElapsed(timestamp),
		itemID = itemID,
		bucket = DescribeBucket(listener, itemID),
		lastCompletedAddon = state.lastCompletedAddon,
		chonkyLoaded = IsAddonLoaded("ChonkyCharacterSheet"),
		retailUIResearchLoaded = IsAddonLoaded("RetailUIResearch"),
		playerLoginSeen = state.milestones.playerLogin ~= nil,
		playerEnteringWorldSeen = state.milestones.playerEnteringWorld ~= nil,
		callableState = CaptureCallableState(),
		stack = CaptureStack(),
	});
end);

InstallListenerDispatchProbe("item", ItemEventListener);
InstallListenerDispatchProbe("quest", QuestEventListener);
InstallListenerDispatchProbe("spell", SpellEventListener);

state.callErrorHandlerAfterObserverHooksValue = _G.CallErrorHandler;
CaptureCallErrorHandlerIdentity("B after passive listener hooks", true);

local eventFrame = CreateFrame("Frame");
eventFrame:RegisterEvent("ADDON_LOADED");
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local timestamp = GetTimestamp();
	if event == "ADDON_LOADED" then
		local loadedAddonName = ...;
		local isBugGrabber = loadedAddonName == "!BugGrabber";
		if isBugGrabber then
			state.callErrorHandlerBeforeBugGrabberEventValue = _G.CallErrorHandler;
		end
		CaptureCallErrorHandlerIdentity(
			isBugGrabber and "C before !BugGrabber ADDON_LOADED processing"
				or ("ADDON_LOADED start: " .. loadedAddonName),
			isBugGrabber or loadedAddonName == ADDON_NAME
		);
		state.lastCompletedAddon = loadedAddonName;
		state.loadEventCount = state.loadEventCount + 1;
		local record = {
			order = state.loadEventCount,
			timestamp = timestamp,
			elapsed = GetElapsed(timestamp),
			addonName = loadedAddonName,
		};
		if #state.loadEvents < MAX_LOAD_EVENTS then
			state.loadEvents[#state.loadEvents + 1] = record;
		else
			state.loadEventDrops = state.loadEventDrops + 1;
		end

		if loadedAddonName == ADDON_NAME then
			state.milestones.observerAddonLoaded = record;
		elseif loadedAddonName == "!BugGrabber" then
			state.milestones.bugGrabberAddonLoaded = record;
			CaptureCallErrorHandlerIdentity("D !BugGrabber ADDON_LOADED handler start", true);
			InstallActiveHandlerWrapper("BugGrabber", "!BugGrabber ADDON_LOADED");
			state.callErrorHandlerAfterBugGrabberWrapperValue = _G.CallErrorHandler;
			CaptureCallErrorHandlerIdentity("E after BugGrabber handler-wrapper installation", true);
			state.callErrorWrapperInstallStatus = "not attempted: BugGrabber-enabled mode intentionally excluded";
		elseif loadedAddonName == "BugSack" then
			state.bugSackLoadedAfterDirectWrapperInstall = state.callErrorWrapperInstalled;
		elseif loadedAddonName == "ChonkyCharacterSheet" then
			state.milestones.chonkyAddonLoaded = record;
		elseif loadedAddonName == "RetailUIResearch" then
			state.milestones.retailUIResearchAddonLoaded = record;
		end
	elseif event == "PLAYER_LOGIN" and not state.milestones.playerLogin then
		state.milestones.playerLogin = {
			timestamp = timestamp,
			elapsed = GetElapsed(timestamp),
		};
	elseif event == "PLAYER_ENTERING_WORLD" and not state.milestones.playerEnteringWorld then
		local isInitialLogin, isReloadingUi = ...;
		state.milestones.playerEnteringWorld = {
			timestamp = timestamp,
			elapsed = GetElapsed(timestamp),
			isInitialLogin = isInitialLogin,
			isReloadingUi = isReloadingUi,
		};
		if state.bugGrabberEnabledForCharacter == false and isInitialLogin == true then
			InstallActiveHandlerWrapper(
				"pre-existing handler at PLAYER_ENTERING_WORLD; !BugGrabber disabled",
				"first PLAYER_ENTERING_WORLD"
			);
			InstallBugGrabberOffBoundaryProbe();
		end
	end
end);

local function AppendLine(lines, text)
	lines[#lines + 1] = text;
end

local function AppendIndentedBlock(lines, label, text)
	AppendLine(lines, label);
	AppendLine(lines, "    " .. text:gsub("\n", "\n    "));
end

local function AppendRecord(lines, label, record)
	AppendLine(lines, string.format(
		"%s REGISTER order=%d time=%.6f elapsed=+%.6f id=%s callbackType=%s callback=%s",
		label,
		record.order,
		record.timestamp,
		record.elapsed,
		tostring(record.itemID),
		record.callbackType,
		record.callbackIdentity
	));
	AppendLine(lines, "  security=" .. record.security);
	if record.mappedBucketIdentity then
		AppendLine(lines, string.format(
			"  mappedBucketAfterReturn identity=%s generation=%s length=%s",
			record.mappedBucketIdentity,
			record.mappedBucketGeneration ~= nil and tostring(record.mappedBucketGeneration) or "<none>",
			record.mappedBucketLength ~= nil and tostring(record.mappedBucketLength) or "<none>"
		));
	end
	AppendLine(lines, string.format(
		"  context lastCompletedAddon=%s chonkyLoaded=%s retailUIResearchLoaded=%s "
			.. "playerLoginSeen=%s playerEnteringWorldSeen=%s",
		tostring(record.lastCompletedAddon),
		record.chonkyLoaded,
		record.retailUIResearchLoaded,
		tostring(record.playerLoginSeen),
		tostring(record.playerEnteringWorldSeen)
	));
	if record.callableState then
		AppendIndentedBlock(lines, "  callableState:", record.callableState);
	end
	AppendIndentedBlock(lines, "  stack:", record.stack);
end

local function AppendPrefireRecord(lines, record)
	AppendLine(lines, string.format(
		"TARGET PREFIRE getCallbacksOrder=%d time=%.6f elapsed=+%.6f id=%s",
		record.order,
		record.timestamp,
		record.elapsed,
		tostring(record.itemID)
	));
	AppendLine(lines, "  bucketBeforeClear=" .. record.bucket);
	AppendLine(lines, string.format(
		"  context lastCompletedAddon=%s chonkyLoaded=%s retailUIResearchLoaded=%s "
			.. "playerLoginSeen=%s playerEnteringWorldSeen=%s",
		tostring(record.lastCompletedAddon),
		record.chonkyLoaded,
		record.retailUIResearchLoaded,
		tostring(record.playerLoginSeen),
		tostring(record.playerEnteringWorldSeen)
	));
	AppendIndentedBlock(lines, "  callableState:", record.callableState);
	AppendIndentedBlock(lines, "  GetCallbacksPostHookStack:", record.stack);
end

local function AppendGetCallbacksCorrelation(lines, label, record)
	if not record then
		AppendLine(lines, string.format(
			"  %sOrder=<none> %sTime=<none> %sElapsed=<none> %sItemID=<none> %sIsTarget=<none>",
			label,
			label,
			label,
			label,
			label
		));
		return;
	end

	AppendLine(lines, string.format(
		"  %sOrder=%d %sTime=%.6f %sElapsed=+%.6f %sItemID=%s %sIsTarget=%s",
		label,
		record.order,
		label,
		record.timestamp,
		label,
		record.elapsed,
		label,
		tostring(record.itemID),
		label,
		tostring(record.isTarget)
	));
end

local function FormatOptional(value)
	return value ~= nil and tostring(value) or "<none>";
end

local function FormatBoundaryLabels(labels)
	return labels and #labels > 0 and table.concat(labels, ",") or "<none>";
end

local function AppendCompactDispatchContext(lines, label, context)
	if not context then
		AppendLine(lines, "  " .. label .. " <not captured>");
		return;
	end
	AppendLine(lines, string.format(
		"  %s status=%s openDepth=%s activeDispatchSequence=%s listenerKind=%s id=%s "
			.. "targetAncestorSequence=%s openStack=%s",
		label,
		context.status,
		FormatOptional(context.openDepth),
		FormatOptional(context.activeDispatchSequence),
		FormatOptional(context.activeListenerKind),
		FormatOptional(context.activeID),
		FormatOptional(context.targetAncestorSequence),
		context.compactOpenStack or "<not captured>"
	));
end

local function AppendBoundaryGlobalSnapshot(lines, label, snapshot)
	if not snapshot then
		AppendLine(lines, "  " .. label .. " <not captured>");
		return;
	end
	AppendLine(lines, string.format(
		"  %s type=%s identity=%s securityStatus=%s secure=%s taint=%s",
		label,
		snapshot.valueType,
		snapshot.displayIdentity,
		snapshot.securityStatus,
		snapshot.isSecure,
		snapshot.taintSource
	));
	if snapshot.identityClass then
		AppendLine(lines, string.format(
			"    equalsOriginal=%s equalsInstalledWrapper=%s identityClass=%s",
			tostring(snapshot.equalsOriginal),
			tostring(snapshot.equalsInstalledWrapper),
			snapshot.identityClass
		));
	end
end

local function AppendBoundaryRecordObservation(lines, record)
	AppendLine(lines, string.format(
		"BOUNDARY retainedOrdinal=%s sequence=%d phase=%s time=%.6f elapsed=+%.6f labels=%s",
		FormatOptional(record.retainedOrdinal),
		record.boundarySequence,
		record.phase,
		record.timestamp,
		record.elapsed,
		FormatBoundaryLabels(record.labels)
	));
	if record.targetDispatchSequence or record.targetOpenOrdinal then
		AppendLine(lines, string.format(
			"  targetDispatchSequence=%s targetOpenOrdinal=%s listenerKind=%s id=%s "
				.. "bucketIdentity=%s bucketGeneration=%s bucketLength=%s mappedRelationship=%s",
			FormatOptional(record.targetDispatchSequence),
			FormatOptional(record.targetOpenOrdinal),
			FormatOptional(record.listenerKind),
			FormatOptional(record.id),
			FormatOptional(record.bucketIdentity),
			FormatOptional(record.bucketGeneration),
			FormatOptional(record.bucketLength),
			FormatOptional(record.mappedRelationship)
		));
		AppendLine(lines, string.format(
			"  registrationOrder=%s registrationCallback=%s soleCallback=%s",
			FormatOptional(record.registrationOrder),
			FormatOptional(record.registrationCallbackIdentity),
			FormatOptional(record.soleCallbackIdentity)
		));
	end
	if record.callErrorWrapperSequence or record.activeHandlerWrapperSequence then
		AppendLine(lines, string.format(
			"  callErrorWrapperSequence=%s activeHandlerWrapperSequence=%s errorType=%s error=\"%s\"",
			FormatOptional(record.callErrorWrapperSequence),
			FormatOptional(record.activeHandlerWrapperSequence),
			FormatOptional(record.errorType),
			FormatOptional(record.errorText)
		));
	end
	if record.mostRecentCallErrorWrapperSequence ~= nil
		or record.callErrorWrapperCurrentlyActive ~= nil
	then
		AppendLine(lines, string.format(
			"  mostRecentCallErrorWrapperSequence=%s currentlyActive=%s deltaFromBEntry=%s "
				.. "errorTextMatches=%s",
			FormatOptional(record.mostRecentCallErrorWrapperSequence),
			FormatOptional(record.callErrorWrapperCurrentlyActive),
			record.deltaFromCallErrorEntry
				and string.format("%+.6f", record.deltaFromCallErrorEntry) or "<none>",
			FormatOptional(record.callErrorTextMatches)
		));
	end
	if record.returnValueCount ~= nil then
		AppendLine(lines, string.format(
			"  retainedOriginalReturn valueCount=%d firstType=%s first=\"%s\"",
			record.returnValueCount,
			FormatOptional(record.firstReturnType),
			FormatOptional(record.firstReturnText)
		));
	end
	AppendLine(lines, string.format(
		"  deltas fromLastTargetOpen=%s fromLastTargetNormalExit=%s fromBEntry=%s",
		record.deltaFromLastTargetOpen
			and string.format("%+.6f", record.deltaFromLastTargetOpen) or "<none>",
		record.deltaFromLastTargetNormalExit
			and string.format("%+.6f", record.deltaFromLastTargetNormalExit) or "<none>",
		record.deltaFromCallErrorEntry
			and string.format("%+.6f", record.deltaFromCallErrorEntry) or "<none>"
	));
	AppendGetCallbacksCorrelation(lines, "precedingTargetGetCallbacks", record.precedingTargetGetCallbacks);
	AppendCompactDispatchContext(
		lines,
		record.phase == "CALLERRORHANDLER_ENTRY" and "CALLERRORHANDLER_DISPATCH_CONTEXT"
			or "BOUNDARY_DISPATCH_CONTEXT",
		record.dispatchContext
	);
	AppendBoundaryGlobalSnapshot(lines, "xpcallSnapshot", record.xpcall);
	AppendBoundaryGlobalSnapshot(lines, "CallErrorHandlerSnapshot", record.callErrorHandler);
end

local function AppendBucketSnapshot(lines, label, snapshot)
	if not snapshot then
		AppendLine(lines, "  " .. label .. "=<not captured>");
		return;
	end
	AppendLine(lines, string.format(
		"  %s identity=%s generation=%s type=%s length=%s status=%s capped=%s",
		label,
		snapshot.identity,
		FormatOptional(snapshot.generation),
		snapshot.bucketType,
		FormatOptional(snapshot.length),
		snapshot.status or "retained-reference",
		tostring(snapshot.inspectionCapped)
	));
	for _, entry in ipairs(snapshot.entries) do
		AppendLine(lines, string.format(
			"    index=%d type=%s identity=%s securityStatus=%s secure=%s taint=%s",
			entry.index,
			entry.valueType,
			entry.identity,
			entry.securityStatus,
			entry.secure,
			entry.taint
		));
	end
end

local function AppendDispatchRecordObservation(lines, record)
	AppendLine(lines, string.format(
		"%s time=%.6f elapsed=+%.6f sequence=%s listenerKind=%s id=%s depth=%s "
			.. "parentSequence=%s targetAncestorSequence=%s bucketIdentity=%s bucketGeneration=%s "
			.. "bucketLength=%s mappedBucketIdentity=%s mappedBucketGeneration=%s "
			.. "mappedEqualsRetained=%s stackMatch=%s",
		record.phase,
		record.timestamp,
		record.elapsed,
		FormatOptional(record.sequence),
		FormatOptional(record.listenerKind),
		FormatOptional(record.id),
		FormatOptional(record.depth),
		FormatOptional(record.parentSequence),
		FormatOptional(record.targetAncestorSequence),
		FormatOptional(record.bucketIdentity),
		FormatOptional(record.bucketGeneration),
		FormatOptional(record.bucketLength),
		FormatOptional(record.mappedBucketIdentity),
		FormatOptional(record.mappedBucketGeneration),
		FormatOptional(record.mappedEqualsRetained),
		FormatOptional(record.stackMatch)
	));
	if record.observation then
		AppendLine(lines, "  observation=\"" .. record.observation .. "\"");
	end
	if record.relationship then
		AppendLine(lines, "  relationship=" .. record.relationship);
	end
	if record.mismatchReason then
		AppendLine(lines, "  mismatchReason=" .. record.mismatchReason);
	end
	if record.mappedRelationship then
		AppendLine(lines, "  mappedRelationship=" .. record.mappedRelationship);
	end
	if record.outerSequence or record.innerSequence or record.targetSequence
		or record.outerGeneration or record.innerGeneration or record.newGeneration
	then
		AppendLine(lines, string.format(
			"  outerSequence=%s innerSequence=%s targetSequence=%s outerGeneration=%s "
				.. "innerGeneration=%s newGeneration=%s",
			FormatOptional(record.outerSequence),
			FormatOptional(record.innerSequence),
			FormatOptional(record.targetSequence),
			FormatOptional(record.outerGeneration),
			FormatOptional(record.innerGeneration),
			FormatOptional(record.newGeneration)
		));
	end
	if record.registrationOrder or record.registrationCallbackIdentity then
		AppendLine(lines, string.format(
			"  registrationOrder=%s registrationCallback=%s",
			FormatOptional(record.registrationOrder),
			FormatOptional(record.registrationCallbackIdentity)
		));
	end
	if record.snapshotChange then
		AppendLine(lines, "  retainedComparison=" .. record.snapshotChange);
	end
	if record.snapshot then
		AppendBucketSnapshot(lines, "targetBucketSnapshot", record.snapshot);
	end
	if record.retainedSnapshot then
		AppendBucketSnapshot(lines, "retainedBucketSnapshot", record.retainedSnapshot);
	end
	if record.mappedSnapshot then
		AppendBucketSnapshot(lines, "mappedBucketSnapshot", record.mappedSnapshot);
	end
end

local function AppendHandlerDispatchContext(lines, context)
	if not context then
		AppendLine(lines, "  HANDLER_DISPATCH_CONTEXT <not captured>");
		return;
	end
	AppendLine(lines, string.format(
		"  HANDLER_DISPATCH_CONTEXT status=%s openDepth=%d activeDispatchSequence=%s "
			.. "listenerKind=%s id=%s depth=%s parentSequence=%s targetAncestorSequence=%s",
		context.status,
		context.openDepth,
		FormatOptional(context.activeDispatchSequence),
		FormatOptional(context.activeListenerKind),
		FormatOptional(context.activeID),
		FormatOptional(context.activeDepth),
		FormatOptional(context.activeParentSequence),
		FormatOptional(context.targetAncestorSequence)
	));
	if #context.stackSnapshot == 0 then
		AppendLine(lines, "    openStack=<empty>");
	else
		for _, entry in ipairs(context.stackSnapshot) do
			AppendLine(lines, string.format(
				"    openStack sequence=%s listenerKind=%s id=%s depth=%s parentSequence=%s "
					.. "targetAncestorSequence=%s bucketIdentity=%s bucketGeneration=%s isTarget=%s",
				FormatOptional(entry.sequence),
				FormatOptional(entry.listenerKind),
				FormatOptional(entry.id),
				FormatOptional(entry.depth),
				FormatOptional(entry.parentSequence),
				FormatOptional(entry.targetAncestorSequence),
				FormatOptional(entry.bucketIdentity),
				FormatOptional(entry.bucketGeneration),
				tostring(entry.isTarget)
			));
		end
	end
	if context.activeDispatchSequence then
		AppendLine(lines, string.format(
			"    activeRetainedBucketIdentity=%s generation=%s mappedBucketIdentity=%s "
				.. "mappedGeneration=%s mappedLength=%s mappedEqualsRetained=%s mappedRelationship=%s",
			FormatOptional(context.activeRetainedBucketIdentity),
			FormatOptional(context.activeRetainedBucketGeneration),
			FormatOptional(context.activeMappedBucketIdentity),
			FormatOptional(context.activeMappedBucketGeneration),
			FormatOptional(context.activeMappedBucketLength),
			FormatOptional(context.activeMappedEqualsRetained),
			FormatOptional(context.activeMappedRelationship)
		));
		if not context.targetSequence then
			AppendLine(lines, "    activeRetainedComparison=" .. context.activeSnapshotChange);
			AppendBucketSnapshot(lines, "handlerActiveRetainedBucket", context.activeRetainedSnapshot);
			AppendBucketSnapshot(lines, "handlerActiveMappedBucket", context.activeMappedSnapshot);
		end
	end
	if context.targetSequence then
		AppendLine(lines, string.format(
			"    targetSequence=%s targetDepth=%s targetParentSequence=%s retainedBucketIdentity=%s "
				.. "retainedGeneration=%s mappedBucketIdentity=%s mappedGeneration=%s "
				.. "mappedLength=%s mappedEqualsRetained=%s mappedRelationship=%s",
			FormatOptional(context.targetSequence),
			FormatOptional(context.targetDepth),
			FormatOptional(context.targetParentSequence),
			FormatOptional(context.targetRetainedBucketIdentity),
			FormatOptional(context.targetRetainedBucketGeneration),
			FormatOptional(context.targetMappedBucketIdentity),
			FormatOptional(context.targetMappedBucketGeneration),
			FormatOptional(context.targetMappedBucketLength),
			FormatOptional(context.targetMappedEqualsRetained),
			FormatOptional(context.targetMappedRelationship)
		));
		AppendLine(lines, "    retainedComparison=" .. context.targetSnapshotChange);
		AppendBucketSnapshot(lines, "handlerTargetRetainedBucket", context.targetRetainedSnapshot);
		AppendBucketSnapshot(lines, "handlerTargetMappedBucket", context.targetMappedSnapshot);
	end
end

local function GetDispatchRecord(ordinal)
	local index = ((state.dispatchRecordHead + ordinal - 2) % MAX_DISPATCH_RECORDS) + 1;
	return state.dispatchRecords[index];
end

local function GetActiveHandlerWrapperRecord(ordinal)
	local index = (
		(state.activeHandlerWrapperRecordHead + ordinal - 2) % MAX_ACTIVE_HANDLER_WRAPPER_RECORDS
	) + 1;
	return state.activeHandlerWrapperRecords[index];
end

local function GetCallErrorWrapperRecord(ordinal)
	local index = (
		(state.callErrorWrapperRecordHead + ordinal - 2) % MAX_CALLERROR_WRAPPER_RECORDS
	) + 1;
	return state.callErrorWrapperRecords[index];
end

local function AppendCallErrorWrapperObservation(lines, record)
	AppendLine(lines, string.format(
		"CALLERROR sequence=%d ENTRY time=%.6f elapsed=+%.6f argumentCount=%d errorType=%s error=\"%s\"",
		record.sequence,
		record.entryTimestamp,
		record.entryElapsed,
		record.argumentCount,
		record.errorType,
		record.errorText
	));
	AppendGetCallbacksCorrelation(lines, "precedingGetCallbacks", record.precedingGetCallbacks);
	AppendGetCallbacksCorrelation(lines, "precedingTargetGetCallbacks", record.precedingTargetGetCallbacks);
	AppendLine(lines, string.format(
		"  boundaryEntrySequence=%s labels=%s",
		FormatOptional(record.boundaryEntrySequence),
		FormatBoundaryLabels(record.boundaryEntryLabels)
	));
	AppendCompactDispatchContext(lines, "CALLERRORHANDLER_DISPATCH_CONTEXT", record.dispatchContext);
	AppendBoundaryGlobalSnapshot(lines, "ENTRY xpcallSnapshot", record.xpcallSnapshot);
	AppendBoundaryGlobalSnapshot(lines, "ENTRY CallErrorHandlerSnapshot", record.callErrorHandlerSnapshot);
	AppendLine(lines, string.format(
		"  context lastCompletedAddon=%s playerLoginSeen=%s playerEnteringWorldSeen=%s",
		tostring(record.lastCompletedAddon),
		tostring(record.playerLoginSeen),
		tostring(record.playerEnteringWorldSeen)
	));
	if record.normalReturn then
		AppendLine(lines, string.format(
			"  RETURN time=%.6f elapsed=+%.6f normalReturn=true valueCount=%d "
				.. "firstType=%s first=\"%s\"",
			record.returnTimestamp,
			record.returnElapsed,
			record.returnValueCount,
			record.firstReturnType,
			record.firstReturnText
		));
		AppendLine(lines, string.format(
			"  boundaryReturnSequence=%s labels=%s",
			FormatOptional(record.boundaryReturnSequence),
			FormatBoundaryLabels(record.boundaryReturnLabels)
		));
		AppendCompactDispatchContext(lines, "RETURN_DISPATCH_CONTEXT", record.returnDispatchContext);
		AppendBoundaryGlobalSnapshot(lines, "RETURN xpcallSnapshot", record.returnXpcallSnapshot);
		AppendBoundaryGlobalSnapshot(
			lines,
			"RETURN CallErrorHandlerSnapshot",
			record.returnCallErrorHandlerSnapshot
		);
	else
		AppendLine(lines, "  RETURN <not observed> normalReturn=false");
	end
end

local function DescribeIdentityEquality(value, comparisonValue)
	if comparisonValue == nil then
		return "<not captured>";
	end
	return nativeTostring(rawequal(value, comparisonValue));
end

local function AppendCallErrorIdentityObservation(lines, record)
	AppendLine(lines, string.format(
		"checkpoint=\"%s\" time=%.6f elapsed=+%.6f type=%s identity=%s",
		record.checkpoint,
		record.timestamp,
		record.elapsed,
		record.valueType,
		record.identity
	));
	AppendLine(lines, string.format(
		"  equalsInitial=%s equalsAfterObserverHooks=%s equalsBeforeBugGrabberEvent=%s "
			.. "equalsAfterBugGrabberWrapper=%s equalsDirectWrapper=%s",
		nativeTostring(record.equalsInitial),
		DescribeIdentityEquality(record.value, state.callErrorHandlerAfterObserverHooksValue),
		DescribeIdentityEquality(record.value, state.callErrorHandlerBeforeBugGrabberEventValue),
		DescribeIdentityEquality(record.value, state.callErrorHandlerAfterBugGrabberWrapperValue),
		DescribeIdentityEquality(record.value, state.callErrorHandlerDirectWrapperValue)
	));
	AppendLine(lines, string.format(
		"  secureVariableStatus=%s secure=%s taint=%s lastCompletedAddon=%s",
		record.securityStatus,
		record.isSecure,
		record.taintSource,
		tostring(record.lastCompletedAddon)
	));
end

local function AppendActiveHandlerWrapperObservation(lines, record)
	AppendLine(lines, string.format(
		"INVOCATION sequence=%d target=\"%s\" ENTRY time=%.6f elapsed=+%.6f errorType=%s error=\"%s\"",
		record.sequence,
		record.handlerTarget,
		record.entryTimestamp,
		record.entryElapsed,
		record.errorType,
		record.errorText
	));
	AppendGetCallbacksCorrelation(lines, "precedingGetCallbacks", record.precedingGetCallbacks);
	AppendGetCallbacksCorrelation(lines, "precedingTargetGetCallbacks", record.precedingTargetGetCallbacks);
	AppendLine(lines, string.format(
		"  %s mostRecentCallErrorWrapperSequence=%s currentlyActive=%s deltaFromBEntry=%s "
			.. "errorTextMatches=%s boundaryEntrySequence=%s labels=%s",
		record.callErrorCorrelation.label,
		FormatOptional(record.callErrorCorrelation.mostRecentSequence),
		tostring(record.callErrorCorrelation.currentlyActive),
		record.callErrorCorrelation.deltaFromEntry
			and string.format("%+.6f", record.callErrorCorrelation.deltaFromEntry) or "<none>",
		tostring(record.callErrorCorrelation.errorTextMatches),
		FormatOptional(record.boundaryEntrySequence),
		FormatBoundaryLabels(record.boundaryEntryLabels)
	));
	AppendBoundaryGlobalSnapshot(lines, "ENTRY xpcallSnapshot", record.xpcallSnapshot);
	AppendBoundaryGlobalSnapshot(lines, "ENTRY CallErrorHandlerSnapshot", record.callErrorHandlerSnapshot);
	AppendHandlerDispatchContext(lines, record.dispatchContext);
	AppendLine(lines, string.format(
		"  context lastCompletedAddon=%s playerLoginSeen=%s playerEnteringWorldSeen=%s",
		tostring(record.lastCompletedAddon),
		tostring(record.playerLoginSeen),
		tostring(record.playerEnteringWorldSeen)
	));
	if record.normalReturn then
		AppendLine(lines, string.format(
			"  RETURN time=%.6f elapsed=+%.6f normalReturn=true valueCount=%d "
				.. "firstType=%s first=\"%s\"",
			record.returnTimestamp,
			record.returnElapsed,
			record.returnValueCount,
			record.firstReturnType,
			record.firstReturnText
		));
	else
		AppendLine(lines, "  RETURN <not observed> normalReturn=false");
	end
end

local function AppendMilestone(lines, label, record, detail)
	if not record then
		AppendLine(lines, label .. " <not observed>");
		return;
	end

	AppendLine(lines, string.format(
		"%s time=%.6f elapsed=+%.6f%s",
		label,
		record.timestamp,
		record.elapsed or GetElapsed(record.timestamp),
		detail and (" " .. detail) or ""
	));
end

local function CaptureCurrentActiveHandler()
	if not state.nativeGetterCaptured then
		return {
			status = "native geterrorhandler unavailable",
			valueType = "<unavailable>",
			identity = "<unavailable>",
			equalsWrapper = false,
		};
	end

	local succeeded, value = pcall(nativeGetErrorHandler);
	if not succeeded then
		return {
			status = "geterrorhandler query failed",
			valueType = "<query-error>",
			identity = "<query-error>",
			equalsWrapper = false,
		};
	end

	local valueType = nativeType(value);
	return {
		status = "ok",
		valueType = valueType,
		identity = valueType == "function" and nativeTostring(value) or "<not-function>",
		equalsWrapper = rawequal(value, ActiveHandlerWrapper),
	};
end

local function LoadedInventoryContains(inventory, addonName)
	for _, record in ipairs(inventory.records) do
		if record.addonName == addonName then
			return true;
		end
	end
	return false;
end

local function GetBugGrabberOffControlValidity(inventory, currentActiveHandler)
	local bugGrabberLoaded = LoadedInventoryContains(inventory, "!BugGrabber");
	local bugSackLoaded = LoadedInventoryContains(inventory, "BugSack");
	local valid = false;
	local reason;

	if state.bugGrabberEnabledForCharacter ~= false then
		reason = "!BugGrabber was not verified disabled for this character";
	elseif inventory.status ~= "ok" then
		reason = "loaded-addon inventory was not complete";
	elseif bugGrabberLoaded then
		reason = "!BugGrabber was loaded at snapshot time";
	elseif bugSackLoaded then
		reason = "BugSack was loaded at snapshot time";
	elseif not state.activeHandlerWrapperInstallAttempted then
		reason = "fallback installation was not attempted";
	elseif state.activeHandlerWrapperInstallTrigger ~= "first PLAYER_ENTERING_WORLD" then
		reason = "wrapper was not installed by the BugGrabber-off fallback";
	elseif not state.activeHandlerWrapperInstalled then
		reason = "fallback wrapper was not installed and verified";
	elseif not currentActiveHandler.equalsWrapper then
		reason = "fallback wrapper was no longer active at snapshot time";
	else
		valid = true;
		reason = "BugGrabber-off fallback installed and remained active through snapshot";
	end

	return {
		valid = valid,
		reason = reason,
		bugGrabberLoaded = bugGrabberLoaded,
		bugSackLoaded = bugSackLoaded,
	};
end

local function GetActiveHandlerMode()
	if state.bugGrabberEnabledForCharacter == true then
		return "BUGGRABBER-ON";
	elseif state.bugGrabberEnabledForCharacter == false then
		return "BUGGRABBER-OFF CONTROL";
	end
	return "UNRESOLVED";
end

local function GetBoundaryProvenanceControlValidity(bugGrabberOffControl)
	local globalWrapperActive = state.callErrorWrapperInstalled
		and nativeRawequal(_G.CallErrorHandler, CallErrorHandlerWrapper);
	local valid = false;
	local reason;
	if not bugGrabberOffControl.valid then
		reason = "BugGrabber-off active-handler control invalid: " .. bugGrabberOffControl.reason;
	elseif state.bugSackInstallGateStatus ~= "verified not loaded or loading" then
		reason = "BugSack-off install gate was not verified";
	elseif not state.callErrorWrapperInstallAttempted then
		reason = "direct CallErrorHandler wrapper installation was not attempted";
	elseif not state.callErrorWrapperInstalled then
		reason = "direct CallErrorHandler wrapper was not installed and verified";
	elseif not globalWrapperActive then
		reason = "direct CallErrorHandler wrapper was no longer global at snapshot time";
	elseif state.bugSackLoadedAfterDirectWrapperInstall then
		reason = "BugSack loaded after direct-wrapper installation";
	else
		valid = true;
		reason = "BugGrabber-off controls and direct global wrapper remained verified through snapshot";
	end
	return {
		valid = valid,
		reason = reason,
		globalWrapperActive = globalWrapperActive,
	};
end

local function BuildLogText()
	local lines = {};
	local inventory = CaptureLoadedAddonInventory();
	local currentActiveHandler = CaptureCurrentActiveHandler();
	local bugGrabberOffControl = GetBugGrabberOffControlValidity(inventory, currentActiveHandler);
	local boundaryProvenanceControl = GetBoundaryProvenanceControlValidity(bugGrabberOffControl);
	local snapshotElapsed = GetElapsed(inventory.timestamp);
	local milestones = state.milestones;
	AppendLine(lines, "Async Item Callback Observer");
	AppendLine(lines, "");
	AppendLine(lines, "SESSION SUMMARY");
	AppendLine(lines, string.format(
		"observerAddon=%s installTime=%.6f snapshotTime=%.6f snapshotElapsed=+%.6f",
		ADDON_NAME,
		state.installTime,
		inventory.timestamp,
		snapshotElapsed
	));
	AppendLine(lines, string.format(
		"elapsedToChonky=%s elapsedToRetailUIResearch=%s elapsedToPlayerLogin=%s",
		milestones.chonkyAddonLoaded and string.format("+%.6f", milestones.chonkyAddonLoaded.elapsed) or "<not observed>",
		milestones.retailUIResearchAddonLoaded
			and string.format("+%.6f", milestones.retailUIResearchAddonLoaded.elapsed) or "<not observed>",
		milestones.playerLogin and string.format("+%.6f", milestones.playerLogin.elapsed) or "<not observed>"
	));
	AppendLine(lines, string.format(
		"loadedAddonCount=%d loadedInventoryStatus=%s registrations=%d getCallbacks=%d "
			.. "genericRetained=%d genericEvictions=%d",
		#inventory.records,
		inventory.status,
		state.registrationCount,
		state.getCallbacksCount,
		#state.genericRecords,
		state.genericEvictions
	));
	AppendLine(lines, string.format(
		"activeHandlerMode=\"%s\" activeHandlerWrapperInstalled=%s target=\"%s\" "
			.. "wrapperEntries=%d wrapperNormalReturns=%d "
			.. "wrapperUnmatched=%d wrapperRetained=%d wrapperEvictions=%d wrapperLimit=%d",
		GetActiveHandlerMode(),
		tostring(state.activeHandlerWrapperInstalled),
		state.activeHandlerWrapperTarget,
		state.activeHandlerWrapperEntryCount,
		state.activeHandlerWrapperReturnCount,
		state.activeHandlerWrapperEntryCount - state.activeHandlerWrapperReturnCount,
		state.activeHandlerWrapperRecordCount,
		state.activeHandlerWrapperEvictions,
		MAX_ACTIVE_HANDLER_WRAPPER_RECORDS
	));
	AppendLine(lines, string.format(
		"bugGrabberEnabledForCharacter=%s enableCheck=\"%s\"",
		tostring(state.bugGrabberEnabledForCharacter),
		state.bugGrabberEnableCheckStatus
	));
	AppendLine(lines, string.format(
		"activeHandlerAtSnapshot status=%s type=%s identity=%s equalsWrapper=%s",
		currentActiveHandler.status,
		currentActiveHandler.valueType,
		currentActiveHandler.identity,
		tostring(currentActiveHandler.equalsWrapper)
	));
	AppendLine(lines, string.format(
		"bugGrabberOffControlValid=%s reason=\"%s\" bugGrabberLoaded=%s bugSackLoaded=%s",
		tostring(bugGrabberOffControl.valid),
		bugGrabberOffControl.reason,
		tostring(bugGrabberOffControl.bugGrabberLoaded),
		tostring(bugGrabberOffControl.bugSackLoaded)
	));
	AppendLine(lines, string.format(
		"boundaryProvenanceControlValid=%s reason=\"%s\" directWrapperGlobalActive=%s "
			.. "bugSackInstallGate=\"%s\" bugSackLoadedAfterInstall=%s",
		tostring(boundaryProvenanceControl.valid),
		boundaryProvenanceControl.reason,
		tostring(boundaryProvenanceControl.globalWrapperActive),
		state.bugSackInstallGateStatus,
		tostring(state.bugSackLoadedAfterDirectWrapperInstall)
	));
	AppendLine(lines, string.format(
		"callErrorWrapperInstalled=%s wrapperEntries=%d wrapperNormalReturns=%d "
			.. "wrapperUnmatched=%d wrapperRetained=%d wrapperEvictions=%d wrapperLimit=%d",
		tostring(state.callErrorWrapperInstalled),
		state.callErrorWrapperEntryCount,
		state.callErrorWrapperReturnCount,
		state.callErrorWrapperEntryCount - state.callErrorWrapperReturnCount,
		state.callErrorWrapperRecordCount,
		state.callErrorWrapperEvictions,
		MAX_CALLERROR_WRAPPER_RECORDS
	));
	AppendLine(lines, string.format(
		"callErrorIdentityRetained=%d identityEvictions=%d identityLimit=%d",
		#state.callErrorIdentityRecords,
		state.callErrorIdentityEvictions,
		MAX_CALLERROR_IDENTITY_RECORDS
	));
	AppendLine(lines, string.format(
		"boundaryRecordsRetained=%d boundaryRecordDrops=%d boundarySnapshotFailures=%d boundaryLimit=%d",
		state.boundaryRecordsRetained,
		state.boundaryRecordDrops,
		state.boundarySnapshotFailures,
		MAX_BOUNDARY_PROVENANCE_RECORDS
	));
	AppendLine(lines, string.format(
		"target268203Registrations=%d registrationDrops=%d prefire=%d prefireDrops=%d",
		#state.targetRecords[268203],
		state.targetDrops[268203],
		#state.targetPrefireRecords[268203],
		state.targetPrefireDrops[268203]
	));
	AppendLine(lines, string.format(
		"target275218Registrations=%d registrationDrops=%d prefire=%d prefireDrops=%d",
		#state.targetRecords[275218],
		state.targetDrops[275218],
		#state.targetPrefireRecords[275218],
		state.targetPrefireDrops[275218]
	));
	AppendLine(lines, string.format(
		"dispatchOpens=%d normalExits=%d currentOpenDepth=%d maxDepth=%d "
			.. "dispatchRetained=%d dispatchEvictions=%d dispatchLimit=%d stackMismatches=%d",
		state.dispatchOpenCount,
		state.dispatchNormalExitCount,
		#state.openDispatchStack,
		state.maxDispatchDepth,
		state.dispatchRecordCount,
		state.dispatchRecordEvictions,
		MAX_DISPATCH_RECORDS,
		state.dispatchStackMismatchCount
	));
	AppendLine(lines, string.format(
		"targetStructuralRetained=%d targetStructuralDrops=%d targetStructuralLimit=%d generationRegistrationEvictions=%d "
			.. "dispatchFailures=%d failureRetained=%d failureDrops=%d failureLimit=%d",
		#state.targetStructuralRecords,
		state.targetStructuralDrops,
		MAX_TARGET_STRUCTURAL_RECORDS,
		state.targetGenerationRegistrationEvictions,
		state.dispatchFailureCount,
		#state.dispatchFailureRecords,
		state.dispatchFailureDrops,
		MAX_DISPATCH_FAILURE_RECORDS
	));
	AppendLine(lines, "ITEM_DATA_LOAD_RESULT success=true means item-data event success, not callback-body success.");

	AppendLine(lines, "");
	AppendLine(lines, "ADDON LOAD TIMELINE");
	AppendLine(lines, string.format(
		"observed=%d retained=%d drops=%d limit=%d",
		state.loadEventCount,
		#state.loadEvents,
		state.loadEventDrops,
		MAX_LOAD_EVENTS
	));
	if #state.loadEvents == 0 then
		AppendLine(lines, "<no ADDON_LOADED events observed after installation>");
	else
		for _, record in ipairs(state.loadEvents) do
			AppendLine(lines, string.format(
				"%03d +%.6f time=%.6f %s",
				record.order,
				record.elapsed,
				record.timestamp,
				record.addonName
			));
		end
	end

	AppendLine(lines, "");
	AppendLine(lines, "LIFECYCLE MILESTONES");
	AppendMilestone(lines, "OBSERVER_INSTALL", milestones.observerInstall);
	AppendMilestone(lines, "ADDON_LOADED observer", milestones.observerAddonLoaded);
	AppendMilestone(lines, "ADDON_LOADED !BugGrabber", milestones.bugGrabberAddonLoaded);
	AppendMilestone(lines, "ADDON_LOADED ChonkyCharacterSheet", milestones.chonkyAddonLoaded);
	AppendMilestone(lines, "ADDON_LOADED RetailUIResearch", milestones.retailUIResearchAddonLoaded);
	AppendMilestone(lines, "PLAYER_LOGIN", milestones.playerLogin);
	local enteringWorld = milestones.playerEnteringWorld;
	AppendMilestone(
		lines,
		"PLAYER_ENTERING_WORLD",
		enteringWorld,
		enteringWorld and string.format(
			"initialLogin=%s reloadingUi=%s",
			tostring(enteringWorld.isInitialLogin),
			tostring(enteringWorld.isReloadingUi)
		) or nil
	);

	AppendLine(lines, "");
	AppendLine(lines, "ASYNC CALLBACK DISPATCH STRUCTURE");
	AppendLine(
		lines,
		"DISPATCH_OPEN is observed after GetCallbacks returns; source FireCallbacks calls it, "
			.. "but direct callers can also produce it."
	);
	AppendLine(
		lines,
		"DISPATCH_NORMAL_EXIT is a secure post-hook observation and proves only normal FireCallbacks return."
	);
	AppendLine(lines, "Bucket generations use retained raw table references; nil mapped state is not a generation.");
	AppendLine(lines, "Snapshot comparisons are discrete observations, not continuous mutation monitoring.");
	AppendLine(lines, "No record exposes FireCallbacks loop-local callback/index or xpcall result state.");
	for _, listenerKind in ipairs({"item", "quest", "spell"}) do
		local hookStatus = state.listenerHookStatus[listenerKind];
		AppendLine(lines, string.format(
			"listenerKind=%s available=%s getCallbacksHooked=%s fireCallbacksHooked=%s status=%s",
			listenerKind,
			tostring(hookStatus and hookStatus.listenerAvailable or false),
			tostring(hookStatus and hookStatus.getCallbacksHooked or false),
			tostring(hookStatus and hookStatus.fireCallbacksHooked or false),
			hookStatus and hookStatus.status or "not attempted"
		));
	end
	AppendLine(lines, string.format(
		"TARGET STRUCTURAL RECORDS retained=%d drops=%d limit=%d",
		#state.targetStructuralRecords,
		state.targetStructuralDrops,
		MAX_TARGET_STRUCTURAL_RECORDS
	));
	if #state.targetStructuralRecords == 0 then
		AppendLine(lines, "<no target/correlation structural records observed>");
	else
		for _, record in ipairs(state.targetStructuralRecords) do
			AppendDispatchRecordObservation(lines, record);
		end
	end
	AppendLine(lines, string.format(
		"RECENT DISPATCH WINDOW retained=%d evictions=%d limit=%d",
		state.dispatchRecordCount,
		state.dispatchRecordEvictions,
		MAX_DISPATCH_RECORDS
	));
	if state.dispatchRecordCount == 0 then
		AppendLine(lines, "<no dispatch records retained>");
	else
		for ordinal = 1, state.dispatchRecordCount do
			AppendDispatchRecordObservation(lines, GetDispatchRecord(ordinal));
		end
	end
	AppendLine(lines, string.format(
		"DISPATCH PROBE FAILURES total=%d retained=%d drops=%d limit=%d",
		state.dispatchFailureCount,
		#state.dispatchFailureRecords,
		state.dispatchFailureDrops,
		MAX_DISPATCH_FAILURE_RECORDS
	));
	for _, record in ipairs(state.dispatchFailureRecords) do
		AppendLine(lines, string.format(
			"FAILURE phase=%s time=%.6f elapsed=+%.6f listenerKind=%s id=%s errorType=%s error=\"%s\"",
			record.phase,
			record.timestamp,
			record.elapsed,
			FormatOptional(record.listenerKind),
			FormatOptional(record.id),
			record.errorType,
			record.errorText
		));
	end

	AppendLine(lines, "");
	AppendLine(lines, "TARGET BOUNDARY PROVENANCE");
	AppendLine(lines, string.format(
		"boundaryRecordsRetained=%d boundaryRecordDrops=%d boundarySnapshotFailures=%d limit=%d "
			.. "baselineBoundarySequence=%s",
		state.boundaryRecordsRetained,
		state.boundaryRecordDrops,
		state.boundarySnapshotFailures,
		MAX_BOUNDARY_PROVENANCE_RECORDS,
		state.boundaryBaseline and FormatOptional(state.boundaryBaseline.boundarySequence) or "<none>"
	));
	AppendLine(
		lines,
		"Target open/normal-exit, direct CallErrorHandler ENTRY/RETURN, and active-handler ENTRY are discrete observations."
	);
	AppendLine(
		lines,
		"CallErrorHandler ENTRY proves only that AICO's installed global wrapper path was traversed."
	);
	AppendLine(
		lines,
		"Active-handler ENTRY without active B means the handler was observed without AICO's active "
			.. "global-B frame; it is not labeled native."
	);
	AppendLine(
		lines,
		"Stable boundary snapshots do not rule out transient identity/type changes between samples."
	);
	AppendLine(
		lines,
		"Ordering labels report observed timestamps/stack state only; they do not assign error ownership or exact VM timing."
	);
	if #state.boundaryRecords == 0 then
		AppendLine(lines, "<no boundary-provenance records retained>");
	else
		for _, record in ipairs(state.boundaryRecords) do
			AppendBoundaryRecordObservation(lines, record);
		end
	end

	AppendLine(lines, "");
	AppendLine(lines, "CALLERRORHANDLER IDENTITY TIMELINE");
	AppendLine(lines, string.format(
		"retained=%d evictions=%d limit=%d",
		#state.callErrorIdentityRecords,
		state.callErrorIdentityEvictions,
		MAX_CALLERROR_IDENTITY_RECORDS
	));
	AppendLine(lines, "A/B verify that the untouched identity survives AICO's passive listener-observer hooks.");
	AppendLine(lines, "C-E bound the !BugGrabber event and BugGrabber-enabled active-handler path.");
	AppendLine(lines, "F/G record the BugGrabber-off direct-wrapper guard and verified installation when attempted.");
	AppendLine(lines, "Other ADDON_LOADED records appear only when identity or observable security state changes.");
	AppendLine(lines, "A transition identifies an observation interval, not the code or native mechanism that caused it.");
	for _, record in ipairs(state.callErrorIdentityRecords) do
		AppendCallErrorIdentityObservation(lines, record);
	end

	AppendLine(lines, "");
	AppendLine(lines, "CALLERRORHANDLER ENTRY/RETURN WRAPPER");
	AppendLine(lines, string.format(
		"wrapperInstalled=%s installAttempted=%s installStatus=\"%s\"",
		tostring(state.callErrorWrapperInstalled),
		tostring(state.callErrorWrapperInstallAttempted),
		state.callErrorWrapperInstallStatus
	));
	AppendLine(lines, string.format(
		"installTime=%s installElapsed=%s bugSackInstallGate=\"%s\" "
			.. "bugSackLoaded=%s bugSackLoadedOrLoading=%s boundaryProvenanceControlValid=%s",
		state.callErrorWrapperInstallTimestamp
			and string.format("%.6f", state.callErrorWrapperInstallTimestamp) or "<not attempted>",
		state.callErrorWrapperInstallElapsed
			and string.format("+%.6f", state.callErrorWrapperInstallElapsed) or "<not attempted>",
		state.bugSackInstallGateStatus,
		tostring(state.bugSackLoadedAtInstallGate),
		tostring(state.bugSackLoadedOrLoadingAtInstallGate),
		tostring(boundaryProvenanceControl.valid)
	));
	AppendLine(lines, string.format(
		"originalCaptured=%s type=%s identity=%s",
		tostring(state.originalCallErrorHandlerCaptured),
		state.originalCallErrorHandlerType,
		state.originalCallErrorHandlerIdentity
	));
	AppendLine(lines, string.format(
		"globalBefore=\"%s\" globalAfter=\"%s\" replacementType=%s identity=%s",
		state.callErrorHandlerSecurityBeforeReplacement,
		state.callErrorHandlerSecurityAfterReplacement,
		state.callErrorHandlerAfterReplacementType,
		state.callErrorHandlerAfterReplacementIdentity
	));
	AppendLine(lines, string.format(
		"totalEntries=%d totalNormalReturns=%d unmatchedEntries=%d retained=%d evictions=%d limit=%d",
		state.callErrorWrapperEntryCount,
		state.callErrorWrapperReturnCount,
		state.callErrorWrapperEntryCount - state.callErrorWrapperReturnCount,
		state.callErrorWrapperRecordCount,
		state.callErrorWrapperEvictions,
		MAX_CALLERROR_WRAPPER_RECORDS
	));
	AppendLine(lines, "ENTRY is recorded before directly calling the retained original CallErrorHandler once.");
	AppendLine(
		lines,
		"RETURN proves only that the retained original CallErrorHandler returned to AICO's wrapper."
	);
	AppendLine(
		lines,
		"An active-handler ENTRY without a currently active matching B entry means AICO observed a path "
			.. "outside its installed global wrapper frame."
	);
	AppendLine(
		lines,
		"This one-run BugGrabber-off diagnostic intentionally replaces a global and is more invasive than Logs_17."
	);
	AppendLine(
		lines,
		"RETURN is written before the wrapper's final unpack/return expression; that last boundary remains unobserved."
	);
	AppendLine(lines, "Preceding GetCallbacks fields are temporal correlation only, not causation or callback identity.");
	if state.callErrorWrapperRecordCount == 0 then
		AppendLine(lines, "<no wrapper entries retained>");
	else
		for ordinal = 1, state.callErrorWrapperRecordCount do
			AppendCallErrorWrapperObservation(lines, GetCallErrorWrapperRecord(ordinal));
		end
	end

	AppendLine(lines, "");
	AppendLine(lines, "ACTIVE ERROR-HANDLER WRAPPER");
	AppendLine(lines, "mode=\"" .. GetActiveHandlerMode() .. "\"");
	AppendLine(lines, string.format(
		"wrapperInstalled=%s installAttempted=%s target=\"%s\" installStatus=\"%s\"",
		tostring(state.activeHandlerWrapperInstalled),
		tostring(state.activeHandlerWrapperInstallAttempted),
		state.activeHandlerWrapperTarget,
		state.activeHandlerWrapperInstallStatus
	));
	AppendLine(lines, string.format(
		"installTrigger=\"%s\" installTime=%s installElapsed=%s",
		state.activeHandlerWrapperInstallTrigger,
		state.activeHandlerWrapperInstallTimestamp
			and string.format("%.6f", state.activeHandlerWrapperInstallTimestamp) or "<not attempted>",
		state.activeHandlerWrapperInstallElapsed
			and string.format("+%.6f", state.activeHandlerWrapperInstallElapsed) or "<not attempted>"
	));
	AppendLine(lines, string.format(
		"bugGrabberEnabledForCharacter=%s enableCheck=\"%s\"",
		tostring(state.bugGrabberEnabledForCharacter),
		state.bugGrabberEnableCheckStatus
	));
	AppendLine(lines, string.format(
		"activeHandlerAtSnapshot status=%s type=%s identity=%s equalsWrapper=%s",
		currentActiveHandler.status,
		currentActiveHandler.valueType,
		currentActiveHandler.identity,
		tostring(currentActiveHandler.equalsWrapper)
	));
	AppendLine(lines, string.format(
		"bugGrabberOffControlValid=%s reason=\"%s\" bugGrabberLoaded=%s bugSackLoaded=%s",
		tostring(bugGrabberOffControl.valid),
		bugGrabberOffControl.reason,
		tostring(bugGrabberOffControl.bugGrabberLoaded),
		tostring(bugGrabberOffControl.bugSackLoaded)
	));
	AppendLine(lines, string.format(
		"boundaryProvenanceControlValid=%s reason=\"%s\" directWrapperGlobalActive=%s",
		tostring(boundaryProvenanceControl.valid),
		boundaryProvenanceControl.reason,
		tostring(boundaryProvenanceControl.globalWrapperActive)
	));
	AppendLine(lines, string.format(
		"nativeSetterCaptured=%s type=%s identity=%s nativeGetterCaptured=%s type=%s identity=%s "
			.. "nativeUnpackCaptured=%s nativeIsSecretValueCaptured=%s",
		tostring(state.nativeSetterCaptured),
		state.nativeSetterType,
		state.nativeSetterIdentity,
		tostring(state.nativeGetterCaptured),
		state.nativeGetterType,
		state.nativeGetterIdentity,
		tostring(state.nativeUnpackCaptured),
		tostring(state.nativeIsSecretValueCaptured)
	));
	AppendLine(lines, string.format(
		"retainedActiveHandlerType=%s identity=%s security=\"%s\"",
		state.retainedActiveHandlerType,
		state.retainedActiveHandlerIdentity,
		state.retainedActiveHandlerSecurity
	));
	AppendLine(lines, string.format(
		"geterrorhandlerGlobal=%s seterrorhandlerGlobal=%s publicSetterAtInstallType=%s identity=%s",
		state.getErrorHandlerGlobalSecurity,
		state.setErrorHandlerGlobalSecurity,
		state.publicSetterTypeAtHandlerInstall,
		state.publicSetterIdentityAtHandlerInstall
	));
	AppendLine(lines, string.format(
		"activeHandlerAfterInstallType=%s identity=%s totalEntries=%d totalNormalReturns=%d "
			.. "unmatchedEntries=%d retained=%d evictions=%d limit=%d",
		state.activeHandlerAfterInstallType,
		state.activeHandlerAfterInstallIdentity,
		state.activeHandlerWrapperEntryCount,
		state.activeHandlerWrapperReturnCount,
		state.activeHandlerWrapperEntryCount - state.activeHandlerWrapperReturnCount,
		state.activeHandlerWrapperRecordCount,
		state.activeHandlerWrapperEvictions,
		MAX_ACTIVE_HANDLER_WRAPPER_RECORDS
	));
	AppendLine(lines, "With !BugGrabber enabled, this wraps its retained handler after that addon loads.");
	AppendLine(lines, "With !BugGrabber disabled, this wraps the pre-existing handler at first PLAYER_ENTERING_WORLD.");
	AppendLine(lines, "It delegates directly to the retained active handler exactly once without pcall/xpcall.");
	AppendLine(
		lines,
		"ENTRY + RETURN: the selected retained handler returned normally; this does not identify the original error source."
	);
	AppendLine(
		lines,
		"ENTRY without RETURN: the selected handler or synchronous work it invoked did not return normally; "
			.. "internal ownership remains unresolved."
	);
	AppendLine(
		lines,
		"No ENTRY with a visible stored error: consider stale/deduplicated display or a path that did not "
			.. "invoke this wrapper."
	);
	AppendLine(
		lines,
		"ENTRY + RETURN without a CALLERROR entry: the active handler was reached outside the installed "
			.. "CallErrorHandler wrapper path."
	);
	AppendLine(lines, "Preceding GetCallbacks fields are temporal correlation only, not causation or callback identity.");
	if state.activeHandlerWrapperRecordCount == 0 then
		AppendLine(lines, "<no wrapper entries retained>");
	else
		for ordinal = 1, state.activeHandlerWrapperRecordCount do
			AppendActiveHandlerWrapperObservation(lines, GetActiveHandlerWrapperRecord(ordinal));
		end
	end

	AppendLine(lines, "");
	AppendLine(lines, "LOADED ADDONS");
	AppendLine(lines, string.format(
		"snapshotTime=%.6f elapsed=+%.6f status=%s count=%d",
		inventory.timestamp,
		snapshotElapsed,
		inventory.status,
		#inventory.records
	));
	for ordinal, record in ipairs(inventory.records) do
		AppendLine(lines, string.format(
			"%03d %s addonIndex=%d",
			ordinal,
			record.addonName,
			record.addonIndex
		));
	end
	for _, inventoryError in ipairs(inventory.errors) do
		AppendLine(lines, "ERROR " .. inventoryError);
	end

	AppendLine(lines, "");
	for _, itemID in ipairs({268203, 275218}) do
		local records = state.targetRecords[itemID];
		AppendLine(lines, string.format("TARGET %d REGISTRATIONS", itemID));
		if #records == 0 then
			AppendLine(lines, "<none observed>");
		else
			for _, record in ipairs(records) do
				AppendRecord(lines, "TARGET", record);
			end
		end
		AppendLine(lines, "");
	end

	AppendLine(lines, "TARGET CALLABLE SNAPSHOTS / PREFIRE EVIDENCE");
	for _, itemID in ipairs({268203, 275218}) do
		local records = state.targetPrefireRecords[itemID];
		AppendLine(lines, string.format(
			"TARGET %d PREFIRE retained=%d drops=%d",
			itemID,
			#records,
			state.targetPrefireDrops[itemID]
		));
		if #records == 0 then
			AppendLine(lines, "<none observed>");
		else
			for _, record in ipairs(records) do
				AppendPrefireRecord(lines, record);
			end
		end
	end

	AppendLine(lines, "");
	AppendLine(lines, "RETAINED GENERIC REGISTRATION WINDOW");
	if #state.genericRecords == 0 then
		AppendLine(lines, "<none observed>");
	else
		for _, record in ipairs(state.genericRecords) do
			AppendRecord(lines, "GENERIC", record);
		end
	end

	return table.concat(lines, "\n");
end

local outputFrame;
local outputEditBox;
local outputScrollFrame;

local function CreateOutputFrame()
	local frame = CreateFrame("Frame", "AsyncItemCallbackObserverOutput", UIParent, "BackdropTemplate");
	frame:SetSize(680, 460);
	frame:SetPoint("CENTER");
	frame:SetFrameStrata("DIALOG");
	frame:SetClampedToScreen(true);
	frame:SetMovable(true);
	frame:EnableMouse(true);
	frame:RegisterForDrag("LeftButton");
	frame:SetScript("OnDragStart", frame.StartMoving);
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing);
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true,
		tileSize = 32,
		edgeSize = 32,
		insets = {left = 8, right = 8, top = 8, bottom = 8},
	});

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
	title:SetPoint("TOP", 0, -16);
	title:SetText("Async Item Callback Observer");

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
	close:SetPoint("TOPRIGHT", -5, -5);

	local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	instructions:SetPoint("TOPLEFT", 18, -42);
	instructions:SetText("Ctrl+A, Ctrl+C to copy. Run /aico again to refresh this snapshot.");

	local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate");
	scrollFrame:SetPoint("TOPLEFT", 18, -62);
	scrollFrame:SetPoint("BOTTOMRIGHT", -34, 18);

	local editBox = CreateFrame("EditBox", nil, scrollFrame);
	editBox:SetMultiLine(true);
	editBox:SetAutoFocus(false);
	editBox:SetFontObject(ChatFontNormal);
	editBox:SetWidth(615);
	editBox:SetTextInsets(4, 4, 4, 4);
	editBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus();
	end);
	editBox:SetScript("OnTextChanged", function()
		scrollFrame:UpdateScrollChildRect();
	end);
	scrollFrame:SetScrollChild(editBox);

	outputFrame = frame;
	outputEditBox = editBox;
	outputScrollFrame = scrollFrame;
end

local function ShowLog()
	if not outputFrame then
		CreateOutputFrame();
	end

	local text = BuildLogText();
	local _, newlineCount = text:gsub("\n", "\n");
	outputEditBox:SetHeight(math.max(outputScrollFrame:GetHeight(), ((newlineCount + 1) * 14) + 8));
	outputEditBox:SetText(text);
	outputScrollFrame:SetVerticalScroll(0);
	outputFrame:Show();
	outputEditBox:SetFocus();
	outputEditBox:HighlightText();
end

SLASH_ASYNCITEMCALLBACKOBSERVER1 = "/aico";
SlashCmdList.ASYNCITEMCALLBACKOBSERVER = ShowLog;
