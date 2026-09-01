-- luacheck: globals ColorPickerFrame CreateFrame GetBindingFromClick InCombatLockdown UIParent
-- luacheck: globals SlashCmdList SLASH_COLORPICKERCOMPARISON1 SLASH_COLORPICKERCOMPARISON2

local _, RetailUIResearch = ...;
local ADDON_NAME = "ColorPickerComparison";

local WINDOW_WIDTH = 920;
local WINDOW_HEIGHT = 650;
local LOG_LIMIT = 12;

local logEntries = {};
local logSequence = 0;
local activeCaller;
local sampleOwnsPicker = false;
local pendingDismissal;
local postHideCaller;

local function CreateText(parent, fontObject, text)
	local fontString = parent:CreateFontString(nil, "ARTWORK", fontObject);
	fontString:SetText(text);
	return fontString;
end

local function FormatAlpha(alpha)
	if alpha == nil then
		return "nil";
	end
	return string.format("%.3f", alpha);
end

local function FormatRGBA(r, g, b, a)
	return string.format(
		"r=%.3f g=%.3f b=%.3f a=%s",
		r,
		g,
		b,
		FormatAlpha(a)
	);
end

local function ColorByte(value)
	return math.floor((value * 255) + 0.5);
end

local function FormatHex(caller)
	local rgb = string.format(
		"%02X%02X%02X",
		ColorByte(caller.r),
		ColorByte(caller.g),
		ColorByte(caller.b)
	);
	if caller.hasOpacity then
		return rgb .. string.format("%02X", ColorByte(caller.a));
	end
	return rgb;
end

local logText;

local function RefreshLog()
	if #logEntries == 0 then
		logText:SetText("No diagnostic events recorded.");
	else
		logText:SetText(table.concat(logEntries, "\n"));
	end
end

local function Record(text)
	logSequence = logSequence + 1;
	local entry = string.format("#%02d %s", logSequence, text);
	table.insert(logEntries, entry);
	if #logEntries > LOG_LIMIT then
		table.remove(logEntries, 1);
	end
	RefreshLog();
	print(string.format("|cff33ff99%s:|r %s", ADDON_NAME, entry));
end

local comparisonFrame = CreateFrame("Frame", "ColorPickerComparisonFrame", UIParent);
comparisonFrame:Hide();
comparisonFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
comparisonFrame:SetPoint("CENTER");
comparisonFrame:SetFrameStrata("DIALOG");
comparisonFrame:SetClampedToScreen(true);
comparisonFrame:SetMovable(true);
comparisonFrame:EnableMouse(true);

CreateFrame("Frame", nil, comparisonFrame, "DialogBorderDarkTemplate");
local header = CreateFrame("Frame", nil, comparisonFrame, "DialogHeaderTemplate");
header:Setup("Color Picker Comparison");
header:EnableMouse(true);
header:RegisterForDrag("LeftButton");
header:SetScript("OnDragStart", function()
	if not InCombatLockdown() then
		comparisonFrame:StartMoving();
	else
		Record("movement is intentionally disabled during combat");
	end
end);
header:SetScript("OnDragStop", function()
	comparisonFrame:StopMovingOrSizing();
end);
CreateFrame("Button", nil, comparisonFrame, "UIPanelCloseButtonDefaultAnchors");

local subtitle = CreateText(
	comparisonFrame,
	"GameFontHighlightSmall",
	"Native global ColorPickerFrame contract; caller state and bounded diagnostics remain addon-owned."
);
subtitle:SetPoint("TOPLEFT", 24, -48);

local combatText = CreateText(comparisonFrame, "GameFontHighlightSmall", "");
combatText:SetPoint("TOPRIGHT", -24, -48);

local function AddEdge(frame, point1, point2, width, height)
	local edge = frame:CreateTexture(nil, "BORDER");
	edge:SetColorTexture(0.28, 0.28, 0.34, 1);
	edge:SetPoint(point1);
	edge:SetPoint(point2);
	if width then
		edge:SetWidth(width);
	end
	if height then
		edge:SetHeight(height);
	end
end

local function CreateSection(parent, x, y, width, height, titleText, detailText)
	local section = CreateFrame("Frame", nil, parent);
	section:SetSize(width, height);
	section:SetPoint("TOPLEFT", x, y);

	local background = section:CreateTexture(nil, "BACKGROUND");
	background:SetAllPoints();
	background:SetColorTexture(0.025, 0.025, 0.035, 0.78);

	AddEdge(section, "TOPLEFT", "TOPRIGHT", nil, 1);
	AddEdge(section, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1);
	AddEdge(section, "TOPLEFT", "BOTTOMLEFT", 1, nil);
	AddEdge(section, "TOPRIGHT", "BOTTOMRIGHT", 1, nil);

	local title = CreateText(section, "GameFontNormal", titleText);
	title:SetPoint("TOPLEFT", 14, -12);

	local detail = CreateText(section, "GameFontDisableSmall", detailText);
	detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3);
	detail:SetWidth(width - 28);
	detail:SetJustifyH("LEFT");

	return section;
end

local callers = {
	{
		id = "A",
		name = "A. RGB",
		r = 0.18,
		g = 0.62,
		b = 0.92,
		hasOpacity = false,
	},
	{
		id = "B",
		name = "B. RGB + Opacity",
		r = 0.92,
		g = 0.32,
		b = 0.22,
		a = 0.55,
		hasOpacity = true,
	},
};

local function UpdateCaller(caller)
	caller.swatch:SetColorRGB(caller.r, caller.g, caller.b);
	caller.preview:SetColorTexture(caller.r, caller.g, caller.b, caller.a or 1);

	local text = string.format(
		"RGB: %.3f, %.3f, %.3f    Hex: #%s",
		caller.r,
		caller.g,
		caller.b,
		FormatHex(caller)
	);
	if caller.hasOpacity then
		text = text .. string.format("\nOpacity/alpha: %.3f (1 = opaque)", caller.a);
	else
		text = text .. "\nRGB-only caller: picker alpha is diagnostic, not caller state.";
	end
	caller.valueText:SetText(text);
end

local function RestoreCaller(caller, previousValues)
	caller.r = previousValues.r;
	caller.g = previousValues.g;
	caller.b = previousValues.b;
	if caller.hasOpacity then
		caller.a = previousValues.a;
	end
	UpdateCaller(caller);
end

local OpenCaller;

local function CreateCallerSection(caller, x)
	local detail = caller.hasOpacity
		and "Native RGB plus opacity setup. Live callbacks update this caller-owned preview/state."
		or "Native RGB-only setup. Read the singleton alpha only as a stale-alpha probe.";
	local section = CreateSection(comparisonFrame, x, -78, 424, 182, caller.name, detail);

	local previewBackground = section:CreateTexture(nil, "BACKGROUND", nil, 1);
	previewBackground:SetSize(94, 66);
	previewBackground:SetPoint("TOPLEFT", 14, -72);
	previewBackground:SetColorTexture(0.12, 0.12, 0.12, 1);

	caller.preview = section:CreateTexture(nil, "ARTWORK");
	caller.preview:SetSize(86, 58);
	caller.preview:SetPoint("CENTER", previewBackground);

	caller.swatch = CreateFrame("Button", nil, section, "ColorSwatchTemplate");
	caller.swatch:SetPoint("TOPLEFT", 126, -73);
	caller.swatch:SetScript("OnClick", function()
		OpenCaller(caller);
	end);

	local swatchLabel = CreateText(section, "GameFontNormalSmall", "Click native swatch to open");
	swatchLabel:SetPoint("LEFT", caller.swatch, "RIGHT", 7, 0);

	caller.valueText = CreateText(section, "GameFontHighlightSmall", "");
	caller.valueText:SetPoint("TOPLEFT", 126, -103);
	caller.valueText:SetWidth(280);
	caller.valueText:SetJustifyH("LEFT");

	local openButton = CreateFrame("Button", nil, section, "UIPanelButtonTemplate");
	openButton:SetSize(138, 24);
	openButton:SetPoint("BOTTOMRIGHT", -14, 12);
	openButton:SetText("Open caller " .. caller.id);
	openButton:SetScript("OnClick", function()
		OpenCaller(caller);
	end);

	UpdateCaller(caller);
end

CreateCallerSection(callers[1], 24);
CreateCallerSection(callers[2], 472);

local diagnosticSection = CreateSection(
	comparisonFrame,
	24,
	-276,
	872,
	258,
	"Bounded lifecycle diagnostics",
	"The newest 12 events also print to chat. Labels record observations; they do not assume callback order."
);

logText = CreateText(diagnosticSection, "GameFontHighlightSmall", "");
logText:SetPoint("TOPLEFT", 14, -54);
logText:SetWidth(844);
logText:SetHeight(165);
logText:SetJustifyH("LEFT");
logText:SetJustifyV("TOP");

local clearButton = CreateFrame("Button", nil, diagnosticSection, "UIPanelButtonTemplate");
clearButton:SetSize(110, 24);
clearButton:SetPoint("BOTTOMRIGHT", -14, 12);
clearButton:SetText("Clear Log");
clearButton:SetScript("OnClick", function()
	logEntries = {};
	logSequence = 0;
	RefreshLog();
	print(string.format("|cff33ff99%s:|r diagnostic history cleared.", ADDON_NAME));
end);

local lifecycleHint = CreateText(
	diagnosticSection,
	"GameFontDisableSmall",
	"While open, use the two buttons attached above the picker for a true direct Hide() or visible-owner replacement."
);
lifecycleHint:SetPoint("BOTTOMLEFT", 14, 18);

local controlsSection = CreateSection(
	comparisonFrame,
	24,
	-542,
	872,
	92,
	"Root scale and layering",
	"Scale changes only this sample. Open either caller afterward and compare logged sample/picker effective scales."
);

for index, scaleChoice in ipairs({
	{label = "75%", value = 0.75},
	{label = "100%", value = 1},
	{label = "125%", value = 1.25},
}) do
	local button = CreateFrame("Button", nil, controlsSection, "UIPanelButtonTemplate");
	button:SetSize(92, 24);
	button:SetPoint("BOTTOMLEFT", 14 + ((index - 1) * 104), 10);
	button:SetText(scaleChoice.label);
	button:SetScript("OnClick", function()
		comparisonFrame:SetScale(scaleChoice.value);
		comparisonFrame:ClearAllPoints();
		comparisonFrame:SetPoint("CENTER");
		Record("sample root scale set to " .. scaleChoice.label .. "; global picker scale unchanged by this call");
	end);
end

local layeringText = CreateText(
	controlsSection,
	"GameFontDisableSmall",
	"Source: ColorPickerFrame is UIParent-owned, top-level, DIALOG; this sample is a separate DIALOG frame."
);
layeringText:SetPoint("BOTTOMRIGHT", -14, 16);

local diagnosticBar = CreateFrame("Frame", nil, ColorPickerFrame);
diagnosticBar:SetSize(340, 28);
diagnosticBar:SetPoint("BOTTOM", ColorPickerFrame, "TOP", 0, 6);
diagnosticBar:SetFrameLevel(ColorPickerFrame:GetFrameLevel() + 5);
diagnosticBar:Hide();

local directHideButton = CreateFrame("Button", nil, diagnosticBar, "UIPanelButtonTemplate");
directHideButton:SetSize(164, 24);
directHideButton:SetPoint("LEFT");
directHideButton:SetText("Diagnostic: direct Hide()");
directHideButton:SetScript("OnClick", function()
	if ColorPickerFrame:IsShown() and sampleOwnsPicker then
		pendingDismissal = "sample-requested direct Hide()";
		Record(activeCaller.id .. " requested ColorPickerFrame:Hide() directly");
		ColorPickerFrame:Hide();
	end
end);

local switchCallerButton = CreateFrame("Button", nil, diagnosticBar, "UIPanelButtonTemplate");
switchCallerButton:SetSize(164, 24);
switchCallerButton:SetPoint("RIGHT");
switchCallerButton:SetText("Switch caller while visible");
switchCallerButton:SetScript("OnClick", function()
	if activeCaller == callers[1] then
		OpenCaller(callers[2]);
	else
		OpenCaller(callers[1]);
	end
end);

OpenCaller = function(caller)
	local pickerWasShown = ColorPickerFrame:IsShown();
	local r = caller.r;
	local g = caller.g;
	local b = caller.b;
	local a = caller.hasOpacity and caller.a or nil;

	pendingDismissal = nil;
	postHideCaller = nil;
	activeCaller = caller;
	sampleOwnsPicker = true;
	diagnosticBar:Show();

	Record(string.format(
		"%s setup%s initial %s",
		caller.id,
		pickerWasShown and " while picker already visible" or "",
		FormatRGBA(r, g, b, a)
	));

	local info = {
		r = r,
		g = g,
		b = b,
		hasOpacity = caller.hasOpacity,
		opacity = a,
		extraInfo = caller.id,
		swatchFunc = function()
			local currentR, currentG, currentB = ColorPickerFrame:GetColorRGB();
			local currentA = ColorPickerFrame:GetColorAlpha();
			caller.r = currentR;
			caller.g = currentG;
			caller.b = currentB;
			UpdateCaller(caller);
			Record(caller.id .. " swatchFunc picker " .. FormatRGBA(currentR, currentG, currentB, currentA));
		end,
		cancelFunc = function(previousValues)
			Record(caller.id .. " cancelFunc previous " .. FormatRGBA(
				previousValues.r,
				previousValues.g,
				previousValues.b,
				previousValues.a
			));
			RestoreCaller(caller, previousValues);
		end,
	};

	if caller.hasOpacity then
		info.opacityFunc = function()
			local currentR, currentG, currentB = ColorPickerFrame:GetColorRGB();
			local currentA = ColorPickerFrame:GetColorAlpha();
			caller.a = currentA;
			UpdateCaller(caller);
			Record(caller.id .. " opacityFunc picker " .. FormatRGBA(currentR, currentG, currentB, currentA));
		end;
	end

	ColorPickerFrame:SetupColorPickerAndShow(info);
	Record(string.format(
		"%s setup returned shown=%s extraInfo=%s picker alpha=%s",
		caller.id,
		tostring(ColorPickerFrame:IsShown()),
		tostring(ColorPickerFrame:GetExtraInfo()),
		FormatAlpha(ColorPickerFrame:GetColorAlpha())
	));
end

ColorPickerFrame.Footer.OkayButton:HookScript("PreClick", function()
	if sampleOwnsPicker then
		pendingDismissal = "Okay button";
		Record(activeCaller.id .. " native Okay PreClick observed");
	end
end);

ColorPickerFrame.Footer.CancelButton:HookScript("PreClick", function()
	if sampleOwnsPicker then
		pendingDismissal = "Cancel button";
		Record(activeCaller.id .. " native Cancel PreClick observed");
	end
end);

ColorPickerFrame:HookScript("OnShow", function(self)
	if sampleOwnsPicker then
		diagnosticBar:Show();
		Record(string.format(
			"picker OnShow owner=%s strata=%s level=%d pickerScale=%.3f sampleScale=%.3f",
			activeCaller.id,
			self:GetFrameStrata(),
			self:GetFrameLevel(),
			self:GetEffectiveScale(),
			comparisonFrame:GetEffectiveScale()
		));
	else
		postHideCaller = nil;
		diagnosticBar:Hide();
	end
end);

ColorPickerFrame:HookScript("OnHide", function()
	if sampleOwnsPicker then
		Record(string.format(
			"picker OnHide owner=%s pending=%s",
			activeCaller.id,
			pendingDismissal or "unclassified native path"
		));
		if pendingDismissal then
			postHideCaller = nil;
		else
			postHideCaller = activeCaller;
		end
		sampleOwnsPicker = false;
		pendingDismissal = nil;
	end
end);

ColorPickerFrame:HookScript("OnKeyDown", function(_, key)
	if postHideCaller and GetBindingFromClick(key) == "TOGGLEGAMEMENU" then
		Record(postHideCaller.id .. " Escape-binding route observed after native handler");
		postHideCaller = nil;
	end
end);

ColorPickerFrame:HookScript("OnEvent", function(_, event)
	if postHideCaller and event == "GLOBAL_MOUSE_DOWN" then
		Record(postHideCaller.id .. " outside-click route observed after native handler");
		postHideCaller = nil;
	end
end);

local footer = CreateText(
	comparisonFrame,
	"GameFontDisableSmall",
	"Source baseline 12.1.0.69497 / 027d26c34. Runtime validation pending; no SavedVariables or polling."
);
footer:SetPoint("BOTTOMLEFT", 24, 8);

local function UpdateCombatState(inCombat)
	if inCombat then
		combatText:SetText("Combat state: In Combat");
		combatText:SetTextColor(1, 0.35, 0.25);
	else
		combatText:SetText("Combat state: Out of Combat");
		combatText:SetTextColor(0.35, 1, 0.45);
	end
end

comparisonFrame:RegisterEvent("PLAYER_REGEN_DISABLED");
comparisonFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
comparisonFrame:SetScript("OnEvent", function(_self, event)
	if event == "PLAYER_REGEN_DISABLED" then
		UpdateCombatState(true);
		Record("entered combat; no automated picker action performed");
	elseif event == "PLAYER_REGEN_ENABLED" then
		UpdateCombatState(false);
		Record("left combat");
	end
end);
UpdateCombatState(InCombatLockdown());
RefreshLog();

RetailUIResearch:RegisterSample({
	id = "color-picker",
	name = "Color Picker",
	frame = comparisonFrame,
});

SLASH_COLORPICKERCOMPARISON1 = "/colorpickercomparison";
SLASH_COLORPICKERCOMPARISON2 = "/cpc";
SlashCmdList.COLORPICKERCOMPARISON = function()
	RetailUIResearch:ToggleSample("color-picker");
end;

print(string.format("%s loaded. Use /colorpickercomparison or /cpc to toggle the sample window.", ADDON_NAME));
