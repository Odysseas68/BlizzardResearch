-- luacheck: globals CreateFrame GetTimePreciseSec GuildRepairDiagnostics GuildRepairDiagnosticsDB

local ADDON_NAME, ns = ...;

local VERSION = "1";
local SCHEMA_VERSION = 1;
local SOURCE_COMMIT = "4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59";
local SOURCE_BUILD = "12.1.0.69814";
local MAX_RECORDS = 512;
local MAX_ARGUMENTS = 32;
local MAX_VALUE_STRING = 2048;
local MAX_LABEL = 128;
local MAX_MARKER_NAME = 96;
local MAX_FIELDS = 16;
local MAX_FIELD_KEY = 64;
local MAX_FIELD_STRING = 256;

local ready = false;
local initialized = false;
local activeRun;
local startClock;
local queryAttempted = false;
local hookedFrame;
local frameAttempts = {};
local instrumentation = {
	query = {status = "not-attempted", phase = "POST-CALL", coverage = "unverified"},
	bankFrame = {status = "waiting-for-natural-load", phase = "POST-SCRIPT"},
	events = {},
};

local RESEARCH_EVENTS = {
	"PLAYER_MONEY", "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED",
	"GUILDBANK_UPDATE_MONEY", "GUILDBANK_UPDATE_WITHDRAWMONEY",
	"GUILDBANKFRAME_OPENED", "GUILDBANKFRAME_CLOSED", "PLAYER_GUILD_UPDATE",
	"PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
};

-- Never tostring an unchecked API/event value, including an error object.
local function IsExportable(value)
	if type(_G.issecretvalue) ~= "function" then
		return false, "secret-check-unavailable";
	end
	local ok, secret = pcall(_G.issecretvalue, value);
	if not ok or secret then
		return false, "secret-or-uncheckable";
	end
	return true;
end

local function EncodeValue(value)
	local exportable, reason = IsExportable(value);
	if not exportable then
		return {status = "unexportable", reason = reason};
	end
	local valueType = type(value);
	if valueType == "string" and #value > MAX_VALUE_STRING then
		return {status = "unexportable", reason = "string-limit", length = #value};
	end
	if valueType == "number" and (value ~= value or value == math.huge or value == -math.huge) then
		return {status = "unexportable", reason = "nonfinite-number"};
	end
	if valueType ~= "nil" and valueType ~= "boolean" and valueType ~= "number" and valueType ~= "string" then
		return {status = "unexportable", reason = "nonprimitive", valueType = valueType};
	end
	return {status = "value", valueType = valueType, value = value};
end

local function Pack(...)
	return {n = select("#", ...), ...};
end

local function EncodeArgs(...)
	local raw = Pack(...);
	local result = {n = raw.n, values = {}};
	for index = 1, math.min(raw.n, MAX_ARGUMENTS) do
		result.values[index] = EncodeValue(raw[index]);
	end
	if raw.n > MAX_ARGUMENTS then
		result.omitted = raw.n - MAX_ARGUMENTS;
	end
	return result;
end

local function Read(func, ...)
	if type(func) ~= "function" then
		return {status = "unavailable"};
	end
	local results = Pack(pcall(func, ...));
	if not results[1] then
		return {status = "error", detail = EncodeValue(results[2])};
	end
	return {status = "returned", results = EncodeArgs(unpack(results, 2, results.n))};
end

local function Skipped(reason)
	return {status = "skipped", reason = reason};
end

local function FirstValue(read)
	if read.status == "returned" then
		local first = read.results.values[1];
		if first and first.status == "value" then
			return first.value;
		end
	end
	return nil;
end

local function FrameShown(frame)
	if frame == nil then
		return {status = "unavailable", reason = "frame-not-loaded"};
	end
	return Read(frame.IsShown, frame);
end

local function Interaction(enumName)
	local enum = _G.Enum and _G.Enum.PlayerInteractionType;
	local manager = _G.C_PlayerInteractionManager;
	if not enum or enum[enumName] == nil or not manager then
		return {status = "unavailable"};
	end
	return Read(manager.IsInteractingWithNpcOfType, enum[enumName]);
end

-- Reads are sequential, not atomic. Context predicates do not claim cache validity.
local function Snapshot()
	if not ready then
		return {status = "skipped", reason = "player-not-ready"};
	end
	local snapshot = {
		GetMoney = Read(_G.GetMoney),
		IsInGuild = Read(_G.IsInGuild),
		combat = Read(_G.InCombatLockdown),
		MerchantFrameExists = EncodeValue(_G.MerchantFrame ~= nil),
		MerchantFrameShown = FrameShown(_G.MerchantFrame),
		GuildBankFrameExists = EncodeValue(_G.GuildBankFrame ~= nil),
		GuildBankFrameShown = FrameShown(_G.GuildBankFrame),
		MerchantInteraction = Interaction("Merchant"),
		GuildBankerInteraction = Interaction("GuildBanker"),
	};
	local merchant = FirstValue(snapshot.MerchantInteraction) == true
		or FirstValue(snapshot.MerchantFrameShown) == true;
	local bank = FirstValue(snapshot.GuildBankerInteraction) == true
		or FirstValue(snapshot.GuildBankFrameShown) == true;
	if FirstValue(snapshot.IsInGuild) == true then
		snapshot.GetGuildBankMoney = Read(_G.GetGuildBankMoney);
		snapshot.GetGuildBankWithdrawMoney = Read(_G.GetGuildBankWithdrawMoney);
	else
		snapshot.GetGuildBankMoney = Skipped("guilded-player-not-established");
		snapshot.GetGuildBankWithdrawMoney = Skipped("guilded-player-not-established");
	end
	snapshot.CanMerchantRepair = merchant and Read(_G.CanMerchantRepair) or Skipped("no-merchant-context");
	snapshot.GetRepairAllCost = merchant and FirstValue(snapshot.CanMerchantRepair) == true
		and Read(_G.GetRepairAllCost) or Skipped("no-repair-capable-merchant-context");
	snapshot.CanGuildBankRepair = (merchant or bank) and Read(_G.CanGuildBankRepair)
		or Skipped("no-merchant-or-bank-context");
	return snapshot;
end

local function CopyTable(source)
	local copy = {};
	for key, value in pairs(source) do
		copy[key] = type(value) == "table" and CopyTable(value) or value;
	end
	return copy;
end

local function Elapsed()
	return GetTimePreciseSec() - startClock;
end

local function Record(kind, name, args, fields, terminal)
	if not activeRun then
		return false, "no-active-run";
	end
	local run = activeRun;
	run.sequence = run.sequence + 1;
	local elapsed = Elapsed();
	-- Preserve the earliest 511 observations and reserve the final slot.
	if not terminal and #run.records >= MAX_RECORDS - 1 then
		run.dropped.count = run.dropped.count + 1;
		run.dropped.firstSeq = run.dropped.firstSeq or run.sequence;
		run.dropped.lastSeq = run.sequence;
		run.dropped.lastElapsed = elapsed;
		return false, "record-cap-reached";
	end
	run.records[#run.records + 1] = {
		seq = run.sequence, elapsed = elapsed, kind = kind, name = name,
		args = args or {n = 0, values = {}}, snapshot = Snapshot(), fields = fields,
	};
	return true, "recorded";
end

local function UpdateInstrumentation()
	if activeRun then
		activeRun.instrumentation = CopyTable(instrumentation);
		Record("LIFECYCLE", "INSTRUMENTATION_STATUS", nil);
	end
end

local function InstallQueryHook()
	if queryAttempted then
		return;
	end
	if type(_G.QueryGuildBankTab) ~= "function" or type(_G.hooksecurefunc) ~= "function" then
		instrumentation.query.status = "unavailable";
		return;
	end
	queryAttempted = true;
	local before = Read(_G.issecurevariable, "QueryGuildBankTab");
	local ok, errorValue = pcall(_G.hooksecurefunc, "QueryGuildBankTab", function(...)
		if activeRun then
			Record("QUERY_POST", "QueryGuildBankTab POST-CALL", EncodeArgs(...));
		end
	end);
	instrumentation.query.status = ok and "installed-coverage-unverified" or "installation-failed";
	instrumentation.query.securityBefore = before;
	instrumentation.query.securityAfter = Read(_G.issecurevariable, "QueryGuildBankTab");
	if not ok then
		instrumentation.query.error = EncodeValue(errorValue);
	end
	UpdateInstrumentation();
end

local function InstallBankFrameHooks()
	local frame = _G.GuildBankFrame;
	if not frame or type(frame.HookScript) ~= "function" then
		return;
	end
	if hookedFrame ~= frame then
		hookedFrame = frame;
		frameAttempts = {};
		instrumentation.bankFrame.status = "frame-found";
	end
	for _, script in ipairs({"OnShow", "OnHide"}) do
		if not frameAttempts[script] then
			frameAttempts[script] = true;
			local ok, errorValue = pcall(frame.HookScript, frame, script, function(_, ...)
				if activeRun then
					Record("FRAME_SCRIPT_POST", "GuildBankFrame " .. script .. " POST-SCRIPT", EncodeArgs(...));
				end
			end);
			instrumentation.bankFrame[script] = {status = ok and "installed" or "installation-failed"};
			if not ok then
				instrumentation.bankFrame[script].error = EncodeValue(errorValue);
			end
			UpdateInstrumentation();
		end
	end
end

local function InitializeDB()
	if initialized then
		return;
	end
	initialized = true;
	if GuildRepairDiagnosticsDB == nil then
		GuildRepairDiagnosticsDB = {schemaVersion = SCHEMA_VERSION};
	end
	-- Refuse incompatible storage rather than deleting potentially useful evidence.
	if type(GuildRepairDiagnosticsDB) ~= "table" or GuildRepairDiagnosticsDB.schemaVersion ~= SCHEMA_VERSION then
		ns.storageError = "Incompatible SavedVariables; evidence preserved. Back it up before resetting it manually.";
		return;
	end
	local run = GuildRepairDiagnosticsDB.run;
	if run and run.status == "active" then
		-- No current-session reads or fabricated old-session timestamp on recovery.
		run.sequence = run.sequence + 1;
		run.records[#run.records + 1] = {
			seq = run.sequence, elapsedStatus = "unavailable-prior-session",
			kind = "INTERRUPTED", name = "PREVIOUS_SESSION_NOT_STOPPED",
			args = {n = 0, values = {}}, snapshot = Skipped("prior-session-unobservable"),
		};
		run.status = "interrupted";
	end
end

function ns.Start(label)
	if not initialized or not ready then
		return false, "Wait until the player has logged in.";
	end
	if ns.storageError then
		return false, ns.storageError;
	end
	if activeRun then
		return false, "A run is already active. Use /ousrd stop first.";
	end
	if GuildRepairDiagnosticsDB.run then
		return false, "Retained evidence exists. Copy it, then use /ousrd clear first.";
	end
	if type(_G.GetTimePreciseSec) ~= "function" then
		return false, "GetTimePreciseSec is unavailable; cannot start.";
	end
	InstallQueryHook();
	InstallBankFrameHooks();
	startClock = GetTimePreciseSec();
	activeRun = {
		diagnosticVersion = VERSION, schemaVersion = SCHEMA_VERSION,
		label = label:sub(1, MAX_LABEL), labelTruncated = #label > MAX_LABEL,
		clientBuild = Read(_G.GetBuildInfo),
		designSource = {commit = SOURCE_COMMIT, build = SOURCE_BUILD},
		instrumentation = CopyTable(instrumentation),
		status = "active", sequence = 0, records = {}, dropped = {count = 0},
		maxRecords = MAX_RECORDS,
	};
	GuildRepairDiagnosticsDB.run = activeRun;
	Record("START", "START");
	return true, "Run started. Observation only; no data requests or transactions are made.";
end

function ns.Stop()
	if not activeRun then
		return false, "No run is active.";
	end
	Record("STOP", "STOP", nil, nil, true);
	activeRun.status = "completed";
	activeRun = nil;
	startClock = nil;
	return true, "Run stopped; evidence retained. Use /ousrd show to copy it.";
end

function ns.Clear()
	if activeRun then
		return false, "A run is active. Use /ousrd stop before /ousrd clear.";
	end
	if not initialized or ns.storageError then
		return false, ns.storageError or "SavedVariables are not ready.";
	end
	GuildRepairDiagnosticsDB.run = nil;
	return true, "Retained evidence explicitly cleared.";
end

local function CopyMarkerFields(fields)
	if fields == nil then
		return {};
	end
	local exportable = IsExportable(fields);
	if not exportable or type(fields) ~= "table" then
		return nil, "fields-must-be-an-ordinary-table";
	end
	if type(_G.issecrettable) ~= "function" then
		return nil, "table-secret-check-unavailable";
	end
	local ok, secret = pcall(_G.issecrettable, fields);
	if not ok or secret or getmetatable(fields) ~= nil then
		return nil, "secret-or-metatable-fields-rejected";
	end
	local copy, count = {}, 0;
	for key, value in pairs(fields) do
		if not IsExportable(key) or type(key) ~= "string" or #key == 0 or #key > MAX_FIELD_KEY then
			return nil, "invalid-field-key";
		end
		local encoded = EncodeValue(value);
		if encoded.status ~= "value" or (encoded.valueType == "string" and #value > MAX_FIELD_STRING) then
			return nil, "invalid-field-value";
		end
		count = count + 1;
		if count > MAX_FIELDS then
			return nil, "too-many-fields";
		end
		copy[key] = value;
	end
	return copy;
end

GuildRepairDiagnostics = {};
function GuildRepairDiagnostics.Mark(name, fields)
	if not activeRun then
		return false, "no-active-run";
	end
	if not IsExportable(name) or type(name) ~= "string" or #name == 0 or #name > MAX_MARKER_NAME then
		return false, "invalid-marker-name";
	end
	local copy, errorMessage = CopyMarkerFields(fields);
	if not copy then
		return false, errorMessage;
	end
	return Record("MARK", name, nil, copy);
end

function ns.GetRun()
	if initialized and not ns.storageError then
		return GuildRepairDiagnosticsDB.run;
	end
	return nil;
end

function ns.GetInstrumentation()
	return instrumentation;
end

local eventFrame = CreateFrame("Frame");
for _, event in ipairs(RESEARCH_EVENTS) do
	local ok, errorValue = pcall(eventFrame.RegisterEvent, eventFrame, event);
	instrumentation.events[event] = {status = ok and "registered" or "registration-failed"};
	if not ok then
		instrumentation.events[event].error = EncodeValue(errorValue);
	end
end
eventFrame:RegisterEvent("ADDON_LOADED");
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:RegisterEvent("PLAYER_LOGOUT");
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local addon = ...;
		if addon == ADDON_NAME then
			InitializeDB();
		end
		-- Event-driven availability checks only; never load the bank UI ourselves.
		InstallQueryHook();
		if addon == "Blizzard_GuildBankUI" or addon == ADDON_NAME then
			InstallBankFrameHooks();
			if activeRun then
				Record("LIFECYCLE", "ADDON_LOADED", EncodeArgs(...));
			end
		end
	elseif event == "PLAYER_LOGIN" then
		ready = true;
		InitializeDB();
		InstallQueryHook();
		InstallBankFrameHooks();
	elseif event == "PLAYER_LOGOUT" then
		if activeRun then
			Record("INTERRUPTED", "PLAYER_LOGOUT", EncodeArgs(...), nil, true);
			activeRun.status = "interrupted";
			activeRun = nil;
			startClock = nil;
		end
		ready = false;
	elseif activeRun then
		Record("EVENT", event, EncodeArgs(...));
	end
end);

InstallQueryHook();
InstallBankFrameHooks();
