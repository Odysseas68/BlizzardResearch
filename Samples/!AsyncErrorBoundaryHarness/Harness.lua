-- luacheck: globals C_AddOns ChatFontNormal CreateFrame DEFAULT_CHAT_FRAME GetTime
-- luacheck: globals GetTimePreciseSec InCombatLockdown SlashCmdList UIParent _G
-- luacheck: globals hooksecurefunc issecurevariable
-- luacheck: globals SLASH_ASYNCERRORBOUNDARYHARNESS1

local ADDON_NAME = ...;

local nativeGetErrorHandler = _G.geterrorhandler;
local nativeSetErrorHandler = _G.seterrorhandler;
local nativeIsSecureVariable = _G.issecurevariable;
local nativeIsSecretValue = _G.issecretvalue;
local nativePcall = _G.pcall;
local nativeSelect = _G.select;
local nativeTostring = _G.tostring;
local nativeType = _G.type;
local nativeUnpack = _G.unpack;
local preciseTime = _G.GetTimePreciseSec;

local MAX_RUNS = 8;
local MAX_EVENTS_PER_RUN = 64;
local MAX_AMBIENT_EVENTS = 16;
local MAX_VALUE_TEXT = 400;
local SYNTHETIC_ERROR_TEXT = "[AEBH SYNTHETIC] SomeSyntheticFile.lua:404: attempt to call a nil value";
local RUN_TOKEN = {};

local state = {
	runSequence = 0,
	runs = {},
	runEvictions = 0,
	activeRun = nil,
	ambientSequence = 0,
	ambientEvents = {},
	ambientDrops = 0,
	bDepth = 0,
	cDepth = 0,
	handlerInstallAttempted = false,
	handlerInstalled = false,
	handlerInstallStatus = "not attempted",
	retainedActiveHandler = nil,
	dispatcherHookInstalled = false,
	dispatcherHookStatus = "not attempted",
};

local function GetTimestamp()
	if nativeType(preciseTime) == "function" then
		return preciseTime();
	end
	return GetTime();
end

local function PackValues(...)
	return {
		count = nativeSelect("#", ...),
		...,
	};
end

local function IsSecret(value)
	if nativeType(nativeIsSecretValue) ~= "function" then
		return false;
	end
	local succeeded, result = nativePcall(nativeIsSecretValue, value);
	return succeeded and result == true;
end

local function KnownBoundedText(value)
	local valueType = nativeType(value);
	local text;
	if valueType == "string" then
		text = value;
	elseif valueType == "nil" or valueType == "number" or valueType == "boolean" then
		text = nativeTostring(value);
	elseif valueType == "function" or valueType == "table" or valueType == "userdata" then
		text = nativeTostring(value);
	else
		text = "<" .. valueType .. ">";
	end
	text = text:gsub("\\", "\\\\"):gsub("\r", "\\r"):gsub("\n", "\\n"):gsub('"', '\\"');
	if #text > MAX_VALUE_TEXT then
		text = text:sub(1, MAX_VALUE_TEXT) .. "...<truncated>";
	end
	return text;
end

local function BoundedText(value)
	if IsSecret(value) then
		return "<secret>";
	end
	return KnownBoundedText(value);
end

local function Field(name, value)
	return string.format('%s="%s"', name, KnownBoundedText(value));
end

local function ValueField(name, value)
	return string.format('%s="%s"', name, BoundedText(value));
end

local function DescribeIdentity(value)
	local valueType = nativeType(value);
	if valueType == "function" or valueType == "table" or valueType == "userdata" then
		return BoundedText(value);
	end
	return "<" .. valueType .. ">";
end

local function DescribeSecureVariable(owner, key)
	if nativeType(nativeIsSecureVariable) ~= "function" then
		return "unavailable", "<unavailable>", "<unavailable>";
	end
	local succeeded, secure, taint;
	if owner == nil then
		succeeded, secure, taint = nativePcall(nativeIsSecureVariable, key);
	else
		succeeded, secure, taint = nativePcall(nativeIsSecureVariable, owner, key);
	end
	if not succeeded then
		return "query-failed", "<error>", "<error>";
	end
	return "ok", secure, taint;
end

local function DescribeReturns(results)
	local fields = {Field("returnCount", results.count)};
	local limit = math.min(results.count, 4);
	for index = 1, limit do
		fields[#fields + 1] = Field("return" .. index .. "Type", nativeType(results[index]));
		fields[#fields + 1] = ValueField("return" .. index, results[index]);
	end
	if results.count > limit then
		fields[#fields + 1] = Field("returnsTruncated", results.count - limit);
	end
	return table.concat(fields, " ");
end

local function BuildRunStateFields(run)
	return table.concat({
		Field("xpcallType", run.xpcallType),
		Field("xpcallIdentity", run.xpcallIdentity),
		Field("AType", run.aType),
		Field("AIdentity", run.aIdentity),
		Field("AEqualsB", run.aEqualsB),
		Field("BIdentity", run.bIdentity),
		Field("CIdentity", run.cIdentity),
		Field("BActive", state.bDepth > 0),
		Field("callbackEnded", run.callbackEnded),
		Field("cleanupCompleted", run.cleanupCompleted),
		Field("methodBodyEnded", run.methodBodyEnded),
		Field("postHookSeen", run.postHookSeen),
		Field("callerAfterSeen", run.callerAfterSeen)
	}, " ");
end

local function RecordRunEvent(run, phase, extra)
	if not run or run.token ~= RUN_TOKEN then
		return;
	end
	run.eventSequence = run.eventSequence + 1;
	local timestamp = GetTimestamp();
	local line = string.format(
		"AEBH run=%d event=%d case=%s phase=%s time=%.6f delta=+%.6f %s%s",
		run.sequence,
		run.eventSequence,
		run.caseName,
		phase,
		timestamp,
		timestamp - run.startTime,
		BuildRunStateFields(run),
		extra and (" " .. extra) or ""
	);
	if #run.events < MAX_EVENTS_PER_RUN then
		run.events[#run.events + 1] = line;
	else
		run.eventDrops = run.eventDrops + 1;
	end
end

local function RecordAmbientEvent(phase, errorValue, argumentCount)
	state.ambientSequence = state.ambientSequence + 1;
	local line = string.format(
		"AEBH run=0 event=%d case=ambient phase=%s time=%.6f delta=<none> %s %s %s",
		state.ambientSequence,
		phase,
		GetTimestamp(),
		Field("argumentCount", argumentCount or 0),
		Field("errorType", nativeType(errorValue)),
		ValueField("errorText", errorValue)
	);
	if #state.ambientEvents < MAX_AMBIENT_EVENTS then
		state.ambientEvents[#state.ambientEvents + 1] = line;
	else
		state.ambientDrops = state.ambientDrops + 1;
	end
end

local function RecordAmbientReturn(results)
	state.ambientSequence = state.ambientSequence + 1;
	local line = string.format(
		"AEBH run=0 event=%d case=ambient phase=C_RETURN time=%.6f delta=<none> %s",
		state.ambientSequence,
		GetTimestamp(),
		DescribeReturns(results)
	);
	if #state.ambientEvents < MAX_AMBIENT_EVENTS then
		state.ambientEvents[#state.ambientEvents + 1] = line;
	else
		state.ambientDrops = state.ambientDrops + 1;
	end
end

local function GetAddonRuntimeState(addonName)
	if nativeType(C_AddOns) ~= "table" or nativeType(C_AddOns.IsAddOnLoaded) ~= "function" then
		return {
			valid = false,
			status = "C_AddOns.IsAddOnLoaded unavailable",
			loadedOrLoading = "<unavailable>",
			loaded = "<unavailable>",
		};
	end
	local succeeded, loadedOrLoading, loaded = nativePcall(C_AddOns.IsAddOnLoaded, addonName);
	if not succeeded or nativeType(loadedOrLoading) ~= "boolean" or nativeType(loaded) ~= "boolean" then
		return {
			valid = false,
			status = succeeded and "unexpected return types" or "query failed",
			loadedOrLoading = BoundedText(loadedOrLoading),
			loaded = BoundedText(loaded),
		};
	end
	return {
		valid = true,
		status = "ok",
		loadedOrLoading = loadedOrLoading,
		loaded = loaded,
	};
end

local function GetCompositionGate()
	local bugGrabber = GetAddonRuntimeState("!BugGrabber");
	local bugSack = GetAddonRuntimeState("BugSack");
	local valid = bugGrabber.valid and bugSack.valid
		and not bugGrabber.loadedOrLoading and not bugGrabber.loaded
		and not bugSack.loadedOrLoading and not bugSack.loaded;
	return {
		valid = valid,
		bugGrabber = bugGrabber,
		bugSack = bugSack,
		reason = valid and "both addons runtime-absent; configuration enable state not inferred"
			or "BugGrabber/BugSack state unavailable, loaded, or loading",
	};
end

local retainedActiveHandler;
local ActiveHandlerWrapper;
local HarnessMessageHandler;

-- A is the per-run xpcall message-handler value. B is HarnessMessageHandler.
-- C is the active handler returned by geterrorhandler(); the installed wrapper
-- observes C independently and delegates to the retained pre-install handler.

ActiveHandlerWrapper = function(...)
	state.cDepth = state.cDepth + 1;
	local run = state.activeRun;
	local errorValue = ...;
	local argumentCount = nativeSelect("#", ...);
	if run then
		RecordRunEvent(run, "C_ENTRY", table.concat({
			Field("CDepth", state.cDepth),
			Field("argumentCount", argumentCount),
			Field("errorType", nativeType(errorValue)),
			ValueField("errorText", errorValue)
		}, " "));
	else
		RecordAmbientEvent("C_ENTRY", errorValue, argumentCount);
	end

	local results = PackValues(retainedActiveHandler(...));
	if run then
		RecordRunEvent(run, "C_RETURN", table.concat({
			Field("CDepth", state.cDepth),
			DescribeReturns(results)
		}, " "));
	else
		RecordAmbientReturn(results);
	end
	state.cDepth = state.cDepth - 1;
	return nativeUnpack(results, 1, results.count);
end

HarnessMessageHandler = function(...)
	state.bDepth = state.bDepth + 1;
	local run = state.activeRun;
	local errorValue = ...;
	local argumentCount = nativeSelect("#", ...);
	local currentC = nativeGetErrorHandler();
	RecordRunEvent(run, "B_ENTRY", table.concat({
		Field("BDepth", state.bDepth),
		Field("argumentCount", argumentCount),
		Field("errorType", nativeType(errorValue)),
		ValueField("errorText", errorValue),
		Field("actualCType", nativeType(currentC)),
		Field("actualCIdentity", DescribeIdentity(currentC))
	}, " "));

	local results = PackValues(currentC(...));
	RecordRunEvent(run, "B_RETURN", table.concat({
		Field("BDepth", state.bDepth),
		DescribeReturns(results)
	}, " "));
	state.bDepth = state.bDepth - 1;
	return nativeUnpack(results, 1, results.count);
end

local function CallbackNormal()
	local run = state.activeRun;
	RecordRunEvent(run, "CALLBACK_ENTRY");
	local deterministicTotal = 0;
	for value = 1, 4 do
		deterministicTotal = deterministicTotal + value;
	end
	run.callbackEnded = true;
	RecordRunEvent(run, "CALLBACK_END", Field("deterministicTotal", deterministicTotal));
	return "normal-result", nil, deterministicTotal;
end

local function CallbackNilCall()
	local run = state.activeRun;
	RecordRunEvent(run, "CALLBACK_ENTRY");
	local harnessOwnedNil = nil;
	harnessOwnedNil(); -- Deliberate stable nil-call site for CASE 1 and CASE 3.
	run.callbackEnded = true;
	RecordRunEvent(run, "CALLBACK_END");
end

local function InvokeCurrentC(run, errorText)
	local currentC = nativeGetErrorHandler();
	RecordRunEvent(run, "DIRECT_C_CALL", table.concat({
		Field("actualCType", nativeType(currentC)),
		Field("actualCIdentity", DescribeIdentity(currentC)),
		Field("errorType", nativeType(errorText)),
		Field("errorText", errorText)
	}, " "));
	local results = PackValues(currentC(errorText));
	RecordRunEvent(run, "DIRECT_C_RETURN", DescribeReturns(results));
	return nativeUnpack(results, 1, results.count);
end

local Dispatcher = {};

function Dispatcher.Run(_, run, callbackValue, handlerValue, directCInBody)
	RecordRunEvent(run, "METHOD_ENTRY");
	local retained = {
		callback = callbackValue,
		cleanupMarker = true,
	};
	local results;
	if directCInBody then
		RecordRunEvent(run, "SYNTHETIC_BODY_ENTRY", Field("innerXpcallUsed", false));
		results = PackValues(InvokeCurrentC(run, SYNTHETIC_ERROR_TEXT));
	else
		local xpcallValue = _G.xpcall;
		RecordRunEvent(run, "BEFORE_XPCALL", table.concat({
			Field("actualXpcallType", nativeType(xpcallValue)),
			Field("actualXpcallIdentity", DescribeIdentity(xpcallValue)),
			Field("actualAType", nativeType(handlerValue)),
			Field("actualAIdentity", DescribeIdentity(handlerValue))
		}, " "));
		results = PackValues(xpcall(retained.callback, handlerValue));
		RecordRunEvent(run, "XPCALL_RETURN", DescribeReturns(results));
	end

	RecordRunEvent(run, "CLEANUP_BEGIN");
	retained.callback = nil;
	retained.cleanupMarker = nil;
	run.cleanupCompleted = true;
	RecordRunEvent(run, "CLEANUP_END");
	run.methodBodyEnded = true;
	RecordRunEvent(run, "METHOD_BODY_FINAL");
	return nativeUnpack(results, 1, results.count);
end

local dispatcherIdentityBeforeHook = DescribeIdentity(Dispatcher.Run);
local dispatcherHookSucceeded, dispatcherHookError = nativePcall(
	hooksecurefunc,
	Dispatcher,
	"Run",
	function(_, run)
		if run and run.token == RUN_TOKEN then
			run.postHookSeen = true;
			RecordRunEvent(run, "SECURE_POST_HOOK_ENTRY");
		end
	end
);
state.dispatcherHookInstalled = dispatcherHookSucceeded;
state.dispatcherHookStatus = dispatcherHookSucceeded and "installed"
	or ("installation failed: " .. BoundedText(dispatcherHookError));
local dispatcherIdentityAfterHook = DescribeIdentity(Dispatcher.Run);

local function Chat(message)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("AEBH: " .. message);
	end
end

local function IsOutOfCombat()
	return nativeType(InCombatLockdown) == "function" and not InCombatLockdown();
end

local function InstallActiveHandlerWrapper()
	if not IsOutOfCombat() then
		Chat("refusing handler installation while combat state is locked or unavailable");
		return;
	end
	local gate = GetCompositionGate();
	if not gate.valid then
		Chat("refusing install: " .. gate.reason);
		return;
	end
	if state.handlerInstalled then
		local current = nativeGetErrorHandler();
		if rawequal(current, ActiveHandlerWrapper) then
			Chat("active-handler wrapper is already installed and verified");
		else
			state.handlerInstalled = false;
			state.handlerInstallStatus = "recorded installed wrapper is no longer active";
			Chat("recorded wrapper is no longer active; refusing to overwrite the current handler");
		end
		return;
	end
	if nativeType(nativeGetErrorHandler) ~= "function"
		or nativeType(nativeSetErrorHandler) ~= "function"
		or nativeType(nativeUnpack) ~= "function"
	then
		state.handlerInstallStatus = "required getter, setter, or unpack unavailable";
		Chat(state.handlerInstallStatus);
		return;
	end

	state.handlerInstallAttempted = true;
	local current = nativeGetErrorHandler();
	if nativeType(current) ~= "function" or rawequal(current, ActiveHandlerWrapper) then
		state.handlerInstallStatus = "current handler was not a distinct function";
		Chat(state.handlerInstallStatus);
		return;
	end
	retainedActiveHandler = current;
	state.retainedActiveHandler = current;
	nativeSetErrorHandler(ActiveHandlerWrapper);
	local installed = nativeGetErrorHandler();
	state.handlerInstalled = rawequal(installed, ActiveHandlerWrapper);
	state.handlerInstallStatus = state.handlerInstalled and "installed and verified active"
		or "setter returned but wrapper identity was not active";
	Chat(state.handlerInstallStatus);
end

local function RestoreActiveHandler()
	if not IsOutOfCombat() then
		Chat("refusing handler restoration while combat state is locked or unavailable");
		return;
	end
	if state.activeRun then
		Chat("a run is still active or aborted; dump it, then /aebh clear before restore");
		return;
	end
	if not state.handlerInstalled then
		Chat("no verified harness handler installation is recorded");
		return;
	end
	local current = nativeGetErrorHandler();
	if not rawequal(current, ActiveHandlerWrapper) then
		state.handlerInstalled = false;
		state.handlerInstallStatus = "restore refused: current handler changed after install";
		Chat(state.handlerInstallStatus .. "; no handler was overwritten");
		return;
	end
	if nativeType(retainedActiveHandler) ~= "function" then
		state.handlerInstallStatus = "restore refused: retained handler unavailable";
		Chat(state.handlerInstallStatus);
		return;
	end

	nativeSetErrorHandler(retainedActiveHandler);
	local restored = nativeGetErrorHandler();
	if rawequal(restored, retainedActiveHandler) then
		state.handlerInstalled = false;
		state.handlerInstallStatus = "restored and verified";
		state.retainedActiveHandler = nil;
		retainedActiveHandler = nil;
		Chat(state.handlerInstallStatus);
	else
		state.handlerInstallStatus = "restore setter returned but retained identity was not active";
		Chat(state.handlerInstallStatus);
	end
end

local function ResolveCase(caseName)
	if caseName == "normal" then
		return CallbackNormal, HarnessMessageHandler, false, false, "CASE 0 normal control";
	elseif caseName == "callback-nil" then
		return CallbackNilCall, HarnessMessageHandler, false, false, "CASE 1 nil call inside callback";
	elseif caseName == "first-nil" then
		return nil, HarnessMessageHandler, false, false, "CASE 2 nil first argument";
	elseif caseName == "first-number" then
		return 17, HarnessMessageHandler, false, false, "CASE 2 number first argument";
	elseif caseName == "handler-nil" then
		return CallbackNilCall, nil, false, false, "CASE 3 nil message handler";
	elseif caseName == "handler-number" then
		return CallbackNilCall, 17, false, false, "CASE 3 number message handler";
	elseif caseName == "direct-c-body" then
		return nil, nil, true, false, "CASE 4 direct C inside method body";
	elseif caseName == "direct-c-after" then
		return CallbackNormal, HarnessMessageHandler, false, true, "CASE 4 direct C after post-hook/caller return";
	end
	return nil;
end

local function BeginRun(caseName, handlerValue, aUsed, caseDescription)
	if not IsOutOfCombat() then
		return nil, "refusing tests while combat state is locked or unavailable";
	end
	if state.activeRun then
		return nil, "a prior run is still active or aborted; dump it, then /aebh clear";
	end
	if not state.dispatcherHookInstalled then
		return nil, "dispatcher secure post-hook was not installed";
	end
	if not state.handlerInstalled or not rawequal(nativeGetErrorHandler(), ActiveHandlerWrapper) then
		return nil, "C wrapper is not installed and verified; use /aebh install";
	end
	local gate = GetCompositionGate();
	if not gate.valid then
		return nil, "BugGrabber/BugSack provenance gate failed: " .. gate.reason;
	end
	local xpcallStatus, xpcallSecure, xpcallTaint = DescribeSecureVariable(nil, "xpcall");
	if nativeType(_G.xpcall) ~= "function" then
		return nil, "global xpcall is not a function";
	end
	if xpcallStatus == "ok" and (xpcallSecure ~= true or xpcallTaint ~= nil) then
		return nil, "global xpcall is not secure/untainted";
	end

	state.runSequence = state.runSequence + 1;
	local startTime = GetTimestamp();
	local run = {
		token = RUN_TOKEN,
		sequence = state.runSequence,
		caseName = caseName,
		caseDescription = caseDescription,
		startTime = startTime,
		eventSequence = 0,
		events = {},
		eventDrops = 0,
		callbackEnded = false,
		cleanupCompleted = false,
		methodBodyEnded = false,
		postHookSeen = false,
		callerAfterSeen = false,
		completed = false,
		xpcallType = nativeType(_G.xpcall),
		xpcallIdentity = DescribeIdentity(_G.xpcall),
		xpcallSecurityStatus = xpcallStatus,
		xpcallSecure = xpcallSecure,
		xpcallTaint = xpcallTaint,
		aType = aUsed and nativeType(handlerValue) or "<not-used>",
		aIdentity = aUsed and DescribeIdentity(handlerValue) or "<not-used>",
		aEqualsB = aUsed and rawequal(handlerValue, HarnessMessageHandler) or false,
		bIdentity = DescribeIdentity(HarnessMessageHandler),
		cIdentity = DescribeIdentity(ActiveHandlerWrapper),
		bugGrabberLoadedOrLoading = gate.bugGrabber.loadedOrLoading,
		bugGrabberLoaded = gate.bugGrabber.loaded,
		bugSackLoadedOrLoading = gate.bugSack.loadedOrLoading,
		bugSackLoaded = gate.bugSack.loaded,
	};
	if #state.runs >= MAX_RUNS then
		table.remove(state.runs, 1);
		state.runEvictions = state.runEvictions + 1;
	end
	state.runs[#state.runs + 1] = run;
	state.activeRun = run;
	RecordRunEvent(run, "RUN_BEGIN", table.concat({
		Field("description", caseDescription),
		Field("AUsed", aUsed),
		Field("BSecurityStatus", "unavailable-local-function"),
		Field("CSecurityStatus", "unavailable-direct-function"),
		Field("xpcallSecurityStatus", xpcallStatus),
		Field("xpcallSecure", xpcallSecure),
		Field("xpcallTaint", xpcallTaint),
		Field("BugGrabberLoadedOrLoading", gate.bugGrabber.loadedOrLoading),
		Field("BugGrabberLoaded", gate.bugGrabber.loaded),
		Field("BugSackLoadedOrLoading", gate.bugSack.loadedOrLoading),
		Field("BugSackLoaded", gate.bugSack.loaded),
		Field("runtimeAbsenceIsNotConfigurationDisableProof", true)
	}, " "));
	return run;
end

local function RunCase(caseName)
	local callbackValue, handlerValue, directCInBody, directCAfter, caseDescription = ResolveCase(caseName);
	if not caseDescription then
		Chat("unknown case; use /aebh help");
		return;
	end
	local run, reason = BeginRun(caseName, handlerValue, not directCInBody, caseDescription);
	if not run then
		Chat(reason);
		return;
	end

	RecordRunEvent(run, "CALLER_BEFORE");
	local results = PackValues(Dispatcher:Run(run, callbackValue, handlerValue, directCInBody));
	run.callerAfterSeen = true;
	RecordRunEvent(run, "CALLER_AFTER", DescribeReturns(results));
	if directCAfter then
		RecordRunEvent(run, "DIRECT_C_AFTER_BEGIN", Field("tautologicalOrderingControl", true));
		InvokeCurrentC(run, SYNTHETIC_ERROR_TEXT);
		RecordRunEvent(run, "DIRECT_C_AFTER_END", Field("tautologicalOrderingControl", true));
	end
	run.completed = true;
	RecordRunEvent(run, "RUN_COMPLETE", Field("normalHarnessReturn", true));
	state.activeRun = nil;
	Chat(string.format("run %d (%s) completed; use /aebh dump", run.sequence, caseName));
end

local function BuildStatusLines()
	local gate = GetCompositionGate();
	local xpcallStatus, xpcallSecure, xpcallTaint = DescribeSecureVariable(nil, "xpcall");
	local methodStatus, methodSecure, methodTaint = DescribeSecureVariable(Dispatcher, "Run");
	local currentC = nativeType(nativeGetErrorHandler) == "function" and nativeGetErrorHandler() or nil;
	local combatState = nativeType(InCombatLockdown) == "function"
		and tostring(InCombatLockdown()) or "<unavailable>";
	return {
		"AEBH SESSION",
		"addon=" .. ADDON_NAME,
		string.format("runsRetained=%d runEvictions=%d activeRun=%s ambientRetained=%d ambientDrops=%d",
			#state.runs, state.runEvictions, state.activeRun and state.activeRun.sequence or "<none>",
			#state.ambientEvents, state.ambientDrops),
		string.format("handlerInstallAttempted=%s handlerInstalled=%s handlerStatus=%q",
			tostring(state.handlerInstallAttempted), tostring(state.handlerInstalled), state.handlerInstallStatus),
		string.format("currentCType=%s currentCIdentity=%s equalsHarnessWrapper=%s retainedCType=%s retainedCIdentity=%s",
			nativeType(currentC), DescribeIdentity(currentC), tostring(rawequal(currentC, ActiveHandlerWrapper)),
			nativeType(state.retainedActiveHandler), DescribeIdentity(state.retainedActiveHandler)),
		string.format("BType=%s BIdentity=%s BSecurity=unavailable-local-function",
			nativeType(HarnessMessageHandler), DescribeIdentity(HarnessMessageHandler)),
		"C security=unavailable-direct-function; no table/global slot is inferred from geterrorhandler().",
		string.format("dispatcherHookInstalled=%s hookStatus=%q identityBefore=%s identityAfter=%s",
			tostring(state.dispatcherHookInstalled), state.dispatcherHookStatus,
			dispatcherIdentityBeforeHook, dispatcherIdentityAfterHook),
		string.format("xpcallType=%s identity=%s securityStatus=%s secure=%s taint=%s globalXpcallWrapped=false",
			nativeType(_G.xpcall), DescribeIdentity(_G.xpcall), xpcallStatus,
			tostring(xpcallSecure), BoundedText(xpcallTaint)),
		string.format("dispatcherMethodSecurityStatus=%s secure=%s taint=%s",
			methodStatus, tostring(methodSecure), BoundedText(methodTaint)),
		string.format("BugGrabber status=%s loadedOrLoading=%s loaded=%s",
			gate.bugGrabber.status, tostring(gate.bugGrabber.loadedOrLoading), tostring(gate.bugGrabber.loaded)),
		string.format("BugSack status=%s loadedOrLoading=%s loaded=%s",
			gate.bugSack.status, tostring(gate.bugSack.loadedOrLoading), tostring(gate.bugSack.loaded)),
		"compositionGateValid=" .. tostring(gate.valid) .. " reason=" .. gate.reason,
		"inCombatLockdown=" .. combatState .. " outOfCombatGateValid=" .. tostring(IsOutOfCombat()),
		"Runtime absence is not proof that either addon is configuration-disabled.",
		"Blizzard FireCallbacks replaced=false; production callbacks mutated=false; SavedVariables=false.",
	};
end

local function BuildLogText()
	local lines = BuildStatusLines();
	for _, run in ipairs(state.runs) do
		lines[#lines + 1] = "";
		lines[#lines + 1] = string.format(
			"RUN %d case=%s description=%q completed=%s eventsRetained=%d eventDrops=%d",
			run.sequence, run.caseName, run.caseDescription, tostring(run.completed), #run.events, run.eventDrops
		);
		for _, line in ipairs(run.events) do
			lines[#lines + 1] = line;
		end
	end
	if #state.ambientEvents > 0 then
		lines[#lines + 1] = "";
		lines[#lines + 1] = "AMBIENT C EVENTS (not attributed to a harness run)";
		for _, line in ipairs(state.ambientEvents) do
			lines[#lines + 1] = line;
		end
	end
	return table.concat(lines, "\n");
end

local outputFrame;
local outputEditBox;
local outputScrollFrame;

local function CreateOutputFrame()
	local frame = CreateFrame("Frame", "AsyncErrorBoundaryHarnessOutput", UIParent, "BackdropTemplate");
	frame:SetSize(760, 480);
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
	title:SetText("Async Error Boundary Harness");
	local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
	instructions:SetPoint("TOPLEFT", 18, -42);
	instructions:SetText("Ctrl+A, Ctrl+C to copy. /aebh dump refreshes this snapshot.");
	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
	close:SetPoint("TOPRIGHT", -5, -5);

	local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate");
	scrollFrame:SetPoint("TOPLEFT", 18, -62);
	scrollFrame:SetPoint("BOTTOMRIGHT", -34, 18);
	local editBox = CreateFrame("EditBox", nil, scrollFrame);
	editBox:SetMultiLine(true);
	editBox:SetAutoFocus(false);
	editBox:SetFontObject(ChatFontNormal);
	editBox:SetWidth(695);
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

local function ClearRecords()
	state.runs = {};
	state.activeRun = nil;
	state.ambientEvents = {};
	state.ambientDrops = 0;
	Chat("retained run and ambient records cleared; run numbering was preserved");
end

local function ShowStatus()
	for _, line in ipairs(BuildStatusLines()) do
		Chat(line);
	end
end

local function ShowHelp()
	Chat("commands: status, install, run <case>, dump, clear, restore");
	Chat("cases: normal, callback-nil, first-nil, first-number, handler-nil, handler-number,");
	Chat("direct-c-body, direct-c-after");
	Chat("malformed xpcall cases may abort before cleanup/post-hook; dump the incomplete run, then clear it");
end

SLASH_ASYNCERRORBOUNDARYHARNESS1 = "/aebh";
SlashCmdList.ASYNCERRORBOUNDARYHARNESS = function(input)
	local command, argument = input:match("^(%S+)%s*(.-)%s*$");
	command = command and command:lower() or "help";
	argument = argument and argument:lower() or "";
	if command == "status" then
		ShowStatus();
	elseif command == "install" then
		InstallActiveHandlerWrapper();
	elseif command == "run" then
		RunCase(argument);
	elseif command == "dump" then
		ShowLog();
	elseif command == "clear" then
		ClearRecords();
	elseif command == "restore" then
		RestoreActiveHandler();
	else
		ShowHelp();
	end
end;
