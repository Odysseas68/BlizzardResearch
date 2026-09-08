-- luacheck: globals CreateFrame GetTime ItemEventListener debugstack hooksecurefunc issecurevariable

local ADDON_NAME, RetailUIResearch = ...;

local MAX_RECORDS = 512;
local MAX_BUCKET_ENTRIES = 16;
local MAX_STACK_LINES = 6;
local MAX_STACK_CHARACTERS = 1200;

local state = {
	installTime = GetTime(),
	startupEntries = {},
	registrations = {},
	prefireSnapshots = {},
	startupEvictions = 0,
	registrationEvictions = 0,
	prefireEvictions = 0,
	registrationOrder = 0,
	prefireOrder = 0,
};

RetailUIResearch.AsyncItemCallbacksBootstrap = state;

local lifecycleFrame = CreateFrame("Frame");
lifecycleFrame:RegisterEvent("ADDON_LOADED");
lifecycleFrame:SetScript("OnEvent", function(self, _, loadedAddonName)
	if loadedAddonName == ADDON_NAME then
		state.addonLoadedTime = GetTime();
		self:UnregisterAllEvents();
		if state.onAddonLoaded then
			state.onAddonLoaded();
		end
	end
end);

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
	return "    " .. stack:gsub("\n", "\n    ");
end

local function DescribeEntrySecurity(callbacks, index)
	if type(issecurevariable) ~= "function" then
		return "unavailable";
	end

	local succeeded, isSecure, taintSource = pcall(issecurevariable, callbacks, index);
	if not succeeded then
		return "check-error";
	end
	return string.format("secure=%s taint=%s", tostring(isSecure), tostring(taintSource));
end

local function CaptureBucket(listener, itemID)
	local callbackMap = listener.callbacks;
	if type(callbackMap) ~= "table" then
		return "callbackMapType=" .. type(callbackMap), {};
	end

	local bucket = callbackMap[itemID];
	if type(bucket) ~= "table" then
		return "callbackMapType=table bucketType=" .. type(bucket), {};
	end

	local length = #bucket;
	local entries = {};
	local descriptions = {};
	local inspected = math.min(length, MAX_BUCKET_ENTRIES);
	for index = 1, inspected do
		local callback = bucket[index];
		local entry = {
			index = index,
			callbackType = type(callback),
			callbackIdentity = tostring(callback),
			security = DescribeEntrySecurity(bucket, index),
		};
		entries[#entries + 1] = entry;
		descriptions[#descriptions + 1] = string.format(
			"%d:%s:%s:%s",
			entry.index,
			entry.callbackType,
			entry.callbackIdentity,
			entry.security
		);
	end
	if length > inspected then
		descriptions[#descriptions + 1] = string.format("+%d more", length - inspected);
	end

	return string.format(
		"callbackMapType=table bucketType=table bucketLength=%d entries=[%s]",
		length,
		table.concat(descriptions, ", ")
	), entries;
end

local function AppendBounded(records, record, evictionField)
	records[#records + 1] = record;
	if #records > MAX_RECORDS then
		table.remove(records, 1);
		state[evictionField] = state[evictionField] + 1;
	end
end

assert(ItemEventListener ~= nil, "ItemEventListener is unavailable during diagnostic bootstrap");
assert(
	type(ItemEventListener.AddCallback) == "function",
	"ItemEventListener:AddCallback is unavailable during diagnostic bootstrap"
);
assert(
	type(ItemEventListener.GetCallbacks) == "function",
	"ItemEventListener:GetCallbacks is unavailable during diagnostic bootstrap"
);

local callbackMap = ItemEventListener.callbacks;
if type(callbackMap) == "table" then
	for itemID, bucket in pairs(callbackMap) do
		if type(bucket) == "table" then
			local bucketLength = #bucket;
			for index = 1, bucketLength do
				local callback = bucket[index];
				AppendBounded(state.startupEntries, {
					itemID = itemID,
					index = index,
					bucketLength = bucketLength,
					callbackType = type(callback),
					callbackIdentity = tostring(callback),
					security = DescribeEntrySecurity(bucket, index),
					timestamp = state.installTime,
				}, "startupEvictions");
			end
		end
	end
end

hooksecurefunc(ItemEventListener, "AddCallback", function(listener, itemID, callbackFunction)
	state.registrationOrder = state.registrationOrder + 1;
	local bucket, entries = CaptureBucket(listener, itemID);
	local record = {
		itemID = itemID,
		hookOrder = state.registrationOrder,
		timestamp = GetTime(),
		callbackType = type(callbackFunction),
		callbackIdentity = tostring(callbackFunction),
		bucket = bucket,
		entries = entries,
		entrySecurity = entries[#entries] and entries[#entries].security or "unavailable-after-return",
		stack = CaptureStack(),
	};
	AppendBounded(state.registrations, record, "registrationEvictions");
	if state.onRegistration then
		state.onRegistration(record, listener);
	end
end);

hooksecurefunc(ItemEventListener, "GetCallbacks", function(listener, itemID)
	state.prefireOrder = state.prefireOrder + 1;
	local bucket, entries = CaptureBucket(listener, itemID);
	local record = {
		itemID = itemID,
		hookOrder = state.prefireOrder,
		timestamp = GetTime(),
		bucket = bucket,
		entries = entries,
		stack = CaptureStack(),
	};
	AppendBounded(state.prefireSnapshots, record, "prefireEvictions");
	if state.onPrefire then
		state.onPrefire(record, listener);
	end
end);
