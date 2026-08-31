-- luacheck: globals CreateFrame UIParent SlashCmdList InCombatLockdown
-- luacheck: globals SLASH_EDITBOXCOMPARISON1 SLASH_EDITBOXCOMPARISON2

local _, RetailUIResearch = ...;
local ADDON_NAME = "EditBoxComparison";

local WINDOW_WIDTH = 1040;
local WINDOW_HEIGHT = 780;
local SECTION_WIDTH = 480;

local eventSequence = 0;

local function PrintStatus(text)
	eventSequence = eventSequence + 1;
	print(string.format("|cff33ff99%s:|r #%02d %s", ADDON_NAME, eventSequence, text));
end

local function FormatValue(value)
	if value == nil then
		return "nil";
	end
	return tostring(value);
end

local function CreateText(parent, fontObject, text)
	local fontString = parent:CreateFontString(nil, "ARTWORK", fontObject);
	fontString:SetText(text);
	return fontString;
end

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

local function CreateSection(parent, x, y, height, titleText, detailText)
	local section = CreateFrame("Frame", nil, parent);
	section:SetSize(SECTION_WIDTH, height);
	section:SetPoint("TOPLEFT", x, y);

	local background = section:CreateTexture(nil, "BACKGROUND");
	background:SetAllPoints();
	background:SetColorTexture(0.025, 0.025, 0.035, 0.78);

	AddEdge(section, "TOPLEFT", "TOPRIGHT", nil, 1);
	AddEdge(section, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1);
	AddEdge(section, "TOPLEFT", "BOTTOMLEFT", 1, nil);
	AddEdge(section, "TOPRIGHT", "BOTTOMRIGHT", 1, nil);

	local title = CreateText(section, "GameFontNormal", titleText);
	title:SetPoint("TOPLEFT", 14, -10);

	local detail = CreateText(section, "GameFontDisableSmall", detailText);
	detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2);
	detail:SetWidth(SECTION_WIDTH - 28);
	detail:SetJustifyH("LEFT");

	return section;
end

local function CreateLabeledEditBox(parent, templateName, labelText, x, y, width)
	local label = CreateText(parent, "GameFontNormalSmall", labelText);
	label:SetPoint("TOPLEFT", x, y);

	local editBox = CreateFrame("EditBox", nil, parent, templateName);
	editBox:SetSize(width, 22);
	editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4);
	editBox:SetAutoFocus(false);
	return editBox;
end

local comparisonFrame = CreateFrame("Frame", "EditBoxComparisonFrame", UIParent);
comparisonFrame:Hide();
comparisonFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
comparisonFrame:SetPoint("CENTER");
comparisonFrame:SetFrameStrata("DIALOG");
comparisonFrame:SetClampedToScreen(true);
comparisonFrame:SetMovable(true);
comparisonFrame:EnableMouse(true);

CreateFrame("Frame", nil, comparisonFrame, "DialogBorderDarkTemplate");
local header = CreateFrame("Frame", nil, comparisonFrame, "DialogHeaderTemplate");
header:Setup("EditBox Comparison");
header:EnableMouse(true);
header:RegisterForDrag("LeftButton");
header:SetScript("OnDragStart", function()
	if not InCombatLockdown() then
		comparisonFrame:StartMoving();
	else
		PrintStatus("movement is intentionally disabled during combat.");
	end
end);
header:SetScript("OnDragStop", function()
	comparisonFrame:StopMovingOrSizing();
end);
CreateFrame("Button", nil, comparisonFrame, "UIPanelCloseButtonDefaultAnchors");

local subtitle = CreateText(
	comparisonFrame,
	"GameFontHighlightSmall",
	"Retail LIVE input diagnostics. Ordered events are printed to chat; use /editboxcomparison or /ebc."
);
subtitle:SetPoint("TOPLEFT", 24, -48);

local combatText = CreateText(comparisonFrame, "GameFontHighlightSmall", "");
combatText:SetPoint("TOPRIGHT", -24, -48);

local standardSection = CreateSection(
	comparisonFrame,
	24,
	-78,
	150,
	"1. InputBoxTemplate",
	"Native Enter/Escape behavior is unchanged; hooks record text and focus transitions."
);

local standardInput = CreateLabeledEditBox(
	standardSection,
	"InputBoxTemplate",
	"Standard Config-like input",
	14,
	-51,
	260
);
local standardState = CreateText(standardSection, "GameFontHighlightSmall", "");
standardState:SetPoint("TOPLEFT", 14, -102);
local standardEvent = CreateText(standardSection, "GameFontDisableSmall", "Latest: ready");
standardEvent:SetPoint("TOPLEFT", 14, -121);

local function UpdateStandardState()
	standardState:SetText(string.format(
		"Text: %q   Focus: %s",
		standardInput:GetText(),
		standardInput:HasFocus() and "yes" or "no"
	));
end

local function RecordStandard(eventText)
	standardEvent:SetText("Latest: " .. eventText);
	UpdateStandardState();
	PrintStatus("standard " .. eventText .. ".");
end

standardInput:HookScript("OnEnterPressed", function()
	RecordStandard("Enter pressed");
end);
standardInput:HookScript("OnEscapePressed", function()
	RecordStandard("Escape pressed");
end);
standardInput:HookScript("OnEditFocusGained", function()
	RecordStandard("focus gained");
end);
standardInput:HookScript("OnEditFocusLost", function()
	RecordStandard("focus lost");
end);
standardInput:HookScript("OnTextChanged", function(editBox, isUserInput)
	RecordStandard(string.format(
		"text changed userInput=%s text=%q",
		tostring(isUserInput),
		editBox:GetText()
	));
end);
UpdateStandardState();

local instructionsSection = CreateSection(
	comparisonFrame,
	24,
	-240,
	130,
	"2. InputBoxInstructionsTemplate",
	"The native Instructions FontString appears only while the actual value is empty."
);

local instructionsInput = CreateLabeledEditBox(
	instructionsSection,
	"InputBoxInstructionsTemplate",
	"Placeholder composition",
	14,
	-51,
	300
);
instructionsInput.Instructions:SetText("Type a value...");
local instructionsState = CreateText(instructionsSection, "GameFontHighlightSmall", "Text: \"\"   Focus: no");
instructionsState:SetPoint("TOPLEFT", 14, -102);

local function RecordInstructions(eventText)
	instructionsState:SetText(string.format(
		"Text: %q   Focus: %s   Latest: %s",
		instructionsInput:GetText(),
		instructionsInput:HasFocus() and "yes" or "no",
		eventText
	));
	PrintStatus("instructions " .. eventText .. ".");
end

instructionsInput:HookScript("OnEditFocusGained", function()
	RecordInstructions("focus gained");
end);
instructionsInput:HookScript("OnEditFocusLost", function()
	RecordInstructions("focus lost");
end);
instructionsInput:HookScript("OnTextChanged", function(editBox, isUserInput)
	RecordInstructions(string.format(
		"text changed userInput=%s text=%q",
		tostring(isUserInput),
		editBox:GetText()
	));
end);

local numericSection = CreateSection(
	comparisonFrame,
	24,
	-382,
	155,
	"3. NumericInputBoxTemplate",
	"Changed/finalized callbacks and inherited script hooks expose the actual event order."
);

local numericInput = CreateLabeledEditBox(
	numericSection,
	"NumericInputBoxTemplate",
	"Numeric callback field",
	14,
	-51,
	180
);
numericInput:SetNumber(5);
local numericState = CreateText(numericSection, "GameFontHighlightSmall", "");
numericState:SetPoint("TOPLEFT", 14, -102);
local numericEvent = CreateText(numericSection, "GameFontDisableSmall", "Latest: ready");
numericEvent:SetPoint("TOPLEFT", 14, -122);

local function UpdateNumericState()
	numericState:SetText(string.format(
		"Text: %q   GetNumber(): %s   Focus: %s",
		numericInput:GetText(),
		FormatValue(numericInput:GetNumber()),
		numericInput:HasFocus() and "yes" or "no"
	));
end

local function RecordNumeric(eventText)
	numericEvent:SetText("Latest: " .. eventText);
	UpdateNumericState();
	PrintStatus("numeric " .. eventText .. ".");
end

numericInput:SetOnValueChangedCallback(function(value, isUserInput)
	RecordNumeric(string.format(
		"value changed value=%s userInput=%s text=%q",
		FormatValue(value),
		tostring(isUserInput),
		numericInput:GetText()
	));
end);
numericInput:SetOnValueFinalizedCallback(function(value)
	RecordNumeric("finalized value=" .. FormatValue(value));
end);
numericInput:HookScript("OnEnterPressed", function()
	RecordNumeric("Enter pressed");
end);
numericInput:HookScript("OnEscapePressed", function()
	RecordNumeric("Escape pressed");
end);
numericInput:HookScript("OnEditFocusGained", function()
	RecordNumeric("focus gained");
end);
numericInput:HookScript("OnEditFocusLost", function()
	RecordNumeric("focus lost");
end);
UpdateNumericState();

local spinnerSection = CreateSection(
	comparisonFrame,
	24,
	-549,
	150,
	"4. NumericInputSpinnerTemplate",
	"Native range 0-10, clamp/highlight flags, step buttons, and mouse wheel remain intact."
);

local spinnerLabel = CreateText(spinnerSection, "GameFontNormalSmall", "Native spinner (step 1)");
spinnerLabel:SetPoint("TOPLEFT", 64, -51);
local spinnerInput = CreateFrame("EditBox", nil, spinnerSection, "NumericInputSpinnerTemplate");
spinnerInput:SetPoint("TOPLEFT", 64, -76);
spinnerInput.clampIfInputExceedsRange = true;
spinnerInput.highlightIfInputExceedsRange = true;
spinnerInput:SetMinMaxValues(0, 10);
spinnerInput:SetValue(5);
local spinnerState = CreateText(spinnerSection, "GameFontHighlightSmall", "");
spinnerState:SetPoint("TOPLEFT", 14, -105);
local spinnerEvent = CreateText(spinnerSection, "GameFontDisableSmall", "Latest: ready");
spinnerEvent:SetPoint("TOPLEFT", 14, -124);

local function UpdateSpinnerState()
	spinnerState:SetText(string.format(
		"Text: %q   GetNumber(): %s   GetValue(): %s   Focus: %s",
		spinnerInput:GetText(),
		FormatValue(spinnerInput:GetNumber()),
		FormatValue(spinnerInput:GetValue()),
		spinnerInput:HasFocus() and "yes" or "no"
	));
end

local function RecordSpinner(eventText)
	spinnerEvent:SetText("Latest: " .. eventText);
	UpdateSpinnerState();
	PrintStatus("spinner " .. eventText .. ".");
end

spinnerInput:SetOnValueChangedCallback(function(_spinner, value)
	RecordSpinner("value changed to " .. FormatValue(value));
end);
spinnerInput:HookScript("OnTextChanged", function(editBox, isUserInput)
	RecordSpinner(string.format(
		"text changed userInput=%s text=%q",
		tostring(isUserInput),
		editBox:GetText()
	));
end);
spinnerInput:HookScript("OnEnterPressed", function()
	RecordSpinner("Enter pressed");
end);
spinnerInput:HookScript("OnEscapePressed", function()
	RecordSpinner("Escape pressed");
end);
spinnerInput:HookScript("OnEditFocusGained", function()
	RecordSpinner("focus gained");
end);
spinnerInput:HookScript("OnEditFocusLost", function()
	RecordSpinner("focus lost");
end);
UpdateSpinnerState();

local numericModeSection = CreateSection(
	comparisonFrame,
	536,
	-78,
	130,
	"5. InputBoxTemplate + SetNumeric(true)",
	"No custom filtering: try signed, decimal, empty, and leading-zero input."
);

local numericModeInput = CreateLabeledEditBox(
	numericModeSection,
	"InputBoxTemplate",
	"Native numeric mode",
	14,
	-51,
	220
);
numericModeInput:SetNumeric(true);
local numericModeState = CreateText(numericModeSection, "GameFontHighlightSmall", "");
numericModeState:SetPoint("TOPLEFT", 14, -102);

local function RecordNumericMode(editBox, isUserInput)
	local eventText = string.format(
		"text=%q GetNumber()=%s userInput=%s",
		editBox:GetText(),
		FormatValue(editBox:GetNumber()),
		tostring(isUserInput)
	);
	numericModeState:SetText(eventText);
	if isUserInput then
		PrintStatus("SetNumeric " .. eventText .. ".");
	end
end

numericModeInput:HookScript("OnTextChanged", RecordNumericMode);
RecordNumericMode(numericModeInput, false);

local fullRangeSection = CreateSection(
	comparisonFrame,
	536,
	-220,
	130,
	"6. InputBoxTemplate + SetNumericFullRange(true)",
	"The API exists but its accepted grammar is undocumented; this field characterizes it."
);

local fullRangeInput = CreateLabeledEditBox(
	fullRangeSection,
	"InputBoxTemplate",
	"Native full-range numeric mode",
	14,
	-51,
	220
);
fullRangeInput:SetNumericFullRange(true);
local fullRangeState = CreateText(fullRangeSection, "GameFontHighlightSmall", "");
fullRangeState:SetPoint("TOPLEFT", 14, -102);

local function RecordFullRange(editBox, isUserInput)
	local eventText = string.format(
		"text=%q GetNumber()=%s userInput=%s",
		editBox:GetText(),
		FormatValue(editBox:GetNumber()),
		tostring(isUserInput)
	);
	fullRangeState:SetText(eventText);
	if isUserInput then
		PrintStatus("SetNumericFullRange " .. eventText .. ".");
	end
end

fullRangeInput:HookScript("OnTextChanged", RecordFullRange);
RecordFullRange(fullRangeInput, false);

local maxLettersSection = CreateSection(
	comparisonFrame,
	536,
	-362,
	140,
	"7. SetMaxLetters(5) / UTF-8",
	"GetNumLetters() is the native letter query; no Lua byte length is presented as characters."
);

local maxLettersInput = CreateLabeledEditBox(
	maxLettersSection,
	"InputBoxTemplate",
	"Try abcdef or alpha-beta-gamma-delta-epsilon-zeta",
	14,
	-51,
	300
);
maxLettersInput:SetMaxLetters(5);
local maxLettersState = CreateText(maxLettersSection, "GameFontHighlightSmall", "");
maxLettersState:SetPoint("TOPLEFT", 14, -102);

local function RecordMaxLetters(editBox, isUserInput)
	local eventText = string.format(
		"Text: %q   GetNumLetters(): %s / GetMaxLetters(): %s",
		editBox:GetText(),
		FormatValue(editBox:GetNumLetters()),
		FormatValue(editBox:GetMaxLetters())
	);
	maxLettersState:SetText(eventText);
	if isUserInput then
		PrintStatus("max letters " .. eventText .. ".");
	end
end

maxLettersInput:HookScript("OnTextChanged", RecordMaxLetters);
RecordMaxLetters(maxLettersInput, false);

local disabledSection = CreateSection(
	comparisonFrame,
	536,
	-514,
	150,
	"8 + 9. Disabled and display-only contrast",
	"The disabled field uses SetEnabled(false); the FontString is intentionally not an EditBox."
);

local disabledInput = CreateLabeledEditBox(
	disabledSection,
	"InputBoxTemplate",
	"Disabled input",
	14,
	-51,
	205
);
disabledInput:SetText("Disabled field");
disabledInput:SetEnabled(false);

local enabledInput = CreateLabeledEditBox(
	disabledSection,
	"InputBoxTemplate",
	"Enabled comparison",
	250,
	-51,
	205
);
enabledInput:SetText("Enabled field");

local disabledState = CreateText(disabledSection, "GameFontHighlightSmall", "");
disabledState:SetPoint("TOPLEFT", 14, -105);

local function UpdateDisabledState(eventText)
	disabledState:SetText(string.format(
		"Disabled: enabled=%s focus=%s   Latest: %s",
		tostring(disabledInput:IsEnabled()),
		disabledInput:HasFocus() and "yes" or "no",
		eventText
	));
end

local displayOnlyLabel = CreateText(disabledSection, "GameFontNormalSmall", "Display-only value:");
displayOnlyLabel:SetPoint("TOPLEFT", 14, -128);
local displayOnlyValue = CreateText(disabledSection, "GameFontHighlightSmall", "Example text");
displayOnlyValue:SetPoint("LEFT", displayOnlyLabel, "RIGHT", 7, 0);

disabledInput:HookScript("OnEditFocusGained", function()
	UpdateDisabledState("disabled focus gained");
	PrintStatus("disabled field unexpectedly gained focus.");
end);
disabledInput:HookScript("OnEditFocusLost", function()
	UpdateDisabledState("disabled focus lost");
	PrintStatus("disabled field focus lost.");
end);
UpdateDisabledState("ready");

local scaleSection = CreateSection(
	comparisonFrame,
	536,
	-676,
	88,
	"10-12. Scale, event log, and combat",
	"Scale applies only here. Chat carries ordered events; combat state appears above."
);

for index, scaleChoice in ipairs({
	{label = "75%", value = 0.75},
	{label = "100%", value = 1},
	{label = "125%", value = 1.25},
}) do
	local button = CreateFrame("Button", nil, scaleSection, "UIPanelButtonTemplate");
	button:SetSize(100, 24);
	button:SetPoint("TOPLEFT", 14 + ((index - 1) * 112), -52);
	button:SetText(scaleChoice.label);
	button:SetScript("OnClick", function()
		comparisonFrame:SetScale(scaleChoice.value);
		comparisonFrame:ClearAllPoints();
		comparisonFrame:SetPoint("CENTER");
		PrintStatus("UI scale changed to " .. scaleChoice.label .. ".");
	end);
end

local footer = CreateText(
	comparisonFrame,
	"GameFontDisableSmall",
	"Retail 12.1.0.69497 / 027d26c34. No SavedVariables, polling, secure frames, Settings, or read-only EditBox."
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
	elseif event == "PLAYER_REGEN_ENABLED" then
		UpdateCombatState(false);
	end
end);
UpdateCombatState(InCombatLockdown());

RetailUIResearch:RegisterSample({
	id = "editboxes",
	name = "EditBoxes",
	frame = comparisonFrame,
});

SLASH_EDITBOXCOMPARISON1 = "/editboxcomparison";
SLASH_EDITBOXCOMPARISON2 = "/ebc";
SlashCmdList.EDITBOXCOMPARISON = function()
	RetailUIResearch:ToggleSample("editboxes");
end;

PrintStatus("loaded. Use /editboxcomparison or /ebc to toggle the sample window.");
