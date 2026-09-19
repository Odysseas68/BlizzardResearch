-- luacheck: globals CreateFrame UIParent IsControlKeyDown SlashCmdList SLASH_GUILDREPAIRDIAGNOSTICS1

local _, ns = ...;
local viewer;
local display;
local renderedText = "";
local restoring = false;

-- Only observer-owned, primitive-encoded evidence reaches this renderer.
local function Serialize(value)
	local valueType = type(value);
	if valueType == "string" then
		return string.format("%q", value);
	elseif valueType == "number" then
		return string.format("%.17g", value);
	elseif valueType ~= "table" then
		return tostring(value);
	end
	local keys = {};
	for key in pairs(value) do
		keys[#keys + 1] = key;
	end
	table.sort(keys, function(left, right)
		if type(left) == "number" and type(right) == "number" then
			return left < right;
		end
		return tostring(left) < tostring(right);
	end);
	local parts = {};
	for _, key in ipairs(keys) do
		parts[#parts + 1] = "[" .. Serialize(key) .. "]=" .. Serialize(value[key]);
	end
	return "{" .. table.concat(parts, ", ") .. "}";
end

local function EvidenceText()
	local lines = {
		"Guild Repair Diagnostics — observer evidence, not transaction attribution",
		"Sequence orders observer callbacks. Timestamps do not establish causation.",
		"Snapshots are sequential, not atomic. Query/frame markers are POST-CALL/POST-SCRIPT.",
	};
	if ns.storageError then
		lines[#lines + 1] = ns.storageError;
	end
	local run = ns.GetRun();
	if not run then
		lines[#lines + 1] = "No retained run.";
		lines[#lines + 1] = "Current instrumentation: " .. Serialize(ns.GetInstrumentation());
		return table.concat(lines, "\n\n");
	end
	local metadata = {};
	for key, value in pairs(run) do
		if key ~= "records" then
			metadata[key] = value;
		end
	end
	lines[#lines + 1] = "Run metadata: " .. Serialize(metadata);
	lines[#lines + 1] = "Retained records: " .. #run.records .. " / " .. run.maxRecords;
	for _, record in ipairs(run.records) do
		lines[#lines + 1] = Serialize(record);
	end
	return table.concat(lines, "\n\n");
end

local function RestoreText()
	restoring = true;
	display:SetText(renderedText);
	restoring = false;
end

local function CreateViewer()
	viewer = CreateFrame("Frame", "GuildRepairDiagnosticsViewer", UIParent);
	viewer:Hide();
	viewer:SetSize(900, 600);
	viewer:SetPoint("CENTER");
	viewer:SetFrameStrata("DIALOG");
	viewer:SetClampedToScreen(true);
	viewer:SetMovable(true);
	CreateFrame("Frame", nil, viewer, "DialogBorderDarkTemplate");
	local header = CreateFrame("Frame", nil, viewer, "DialogHeaderTemplate");
	header:Setup("Guild Repair Diagnostics");
	header:EnableMouse(true);
	header:RegisterForDrag("LeftButton");
	header:SetScript("OnDragStart", function() viewer:StartMoving(); end);
	header:SetScript("OnDragStop", function() viewer:StopMovingOrSizing(); end);
	CreateFrame("Button", nil, viewer, "UIPanelCloseButtonDefaultAnchors");
	local hint = viewer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
	hint:SetPoint("TOPLEFT", 24, -48);
	hint:SetPoint("TOPRIGHT", -24, -48);
	hint:SetJustifyH("LEFT");
	hint:SetText("Click text, Ctrl+A / Ctrl+C. /ousrd show refreshes this view without recording evidence.");
	display = CreateFrame("Frame", nil, viewer, "ScrollingEditBoxTemplate");
	display:SetPoint("TOPLEFT", 24, -78);
	display:SetPoint("BOTTOMRIGHT", -24, 24);
	display:SetFontObject("GameFontHighlightSmall");
	display:SetTextInsets(6, 6, 6, 6);
	local background = display:CreateTexture(nil, "BACKGROUND");
	background:SetAllPoints();
	background:SetColorTexture(0.015, 0.015, 0.022, 0.92);
	local editBox = display:GetEditBox();
	editBox:SetAutoFocus(false);
	editBox:SetMultiLine(true);
	display:RegisterCallback("OnTextChanged", function(_, _, userInput)
		if userInput and not restoring then
			RestoreText();
		end
	end, viewer);
	display:RegisterCallback("OnKeyDown", function(_, box, key)
		if key == "A" and IsControlKeyDown() then
			box:HighlightText();
		end
	end, viewer);
end

local function Show()
	if not viewer then
		CreateViewer();
	end
	renderedText = EvidenceText();
	RestoreText();
	viewer:Show();
end

SLASH_GUILDREPAIRDIAGNOSTICS1 = "/ousrd";
SlashCmdList.GUILDREPAIRDIAGNOSTICS = function(input)
	local command, remainder = input:match("^%s*(%S*)%s*(.-)%s*$");
	command = command:lower();
	if command == "show" then
		Show();
		return;
	end
	local ok, message;
	if command == "start" then
		ok, message = ns.Start(remainder);
	elseif command == "stop" then
		ok, message = ns.Stop();
	elseif command == "clear" then
		ok, message = ns.Clear();
	else
		print("GuildRepairDiagnostics: /ousrd start <label> | stop | show | clear");
		return;
	end
	print("GuildRepairDiagnostics: " .. (ok and "" or "Refused: ") .. message);
end;
