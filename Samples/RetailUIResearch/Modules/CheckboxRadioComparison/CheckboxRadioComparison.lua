-- luacheck: globals CreateFrame UIParent SlashCmdList InCombatLockdown
-- luacheck: globals SLASH_CHECKBOXRADIOCOMPARISON1 SLASH_CHECKBOXRADIOCOMPARISON2

local _, RetailUIResearch = ...;
local ADDON_NAME = "CheckboxRadioComparison";

local WINDOW_WIDTH = 860;
local WINDOW_HEIGHT = 720;
local SECTION_WIDTH = 394;

local function PrintStatus(text)
	print(string.format("|cff33ff99%s:|r %s", ADDON_NAME, text));
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
	title:SetPoint("TOPLEFT", 14, -12);

	local detail = CreateText(section, "GameFontDisableSmall", detailText);
	detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3);
	detail:SetWidth(SECTION_WIDTH - 28);
	detail:SetJustifyH("LEFT");

	return section;
end

local function CreateAddonLabeledCheckButton(parent, templateName, labelText, x, y)
	local checkbox = CreateFrame("CheckButton", nil, parent, templateName);
	checkbox:SetPoint("TOPLEFT", x, y);

	local label = CreateText(parent, "GameFontNormalSmall", labelText);
	label:SetPoint("LEFT", checkbox, "RIGHT", 3, 0);

	return checkbox, label;
end

local comparisonFrame = CreateFrame("Frame", "CheckboxRadioComparisonFrame", UIParent);
comparisonFrame:Hide();
comparisonFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
comparisonFrame:SetPoint("CENTER");
comparisonFrame:SetFrameStrata("DIALOG");
comparisonFrame:SetClampedToScreen(true);
comparisonFrame:SetMovable(true);
comparisonFrame:EnableMouse(true);

CreateFrame("Frame", nil, comparisonFrame, "DialogBorderDarkTemplate");
local header = CreateFrame("Frame", nil, comparisonFrame, "DialogHeaderTemplate");
header:Setup("Checkbox and Radio Comparison");
header:EnableMouse(true);
header:RegisterForDrag("LeftButton");
header:SetScript("OnDragStart", function()
	if not InCombatLockdown() then
		comparisonFrame:StartMoving();
	else
		PrintStatus("Movement is intentionally disabled during combat.");
	end
end);
header:SetScript("OnDragStop", function()
	comparisonFrame:StopMovingOrSizing();
end);
CreateFrame("Button", nil, comparisonFrame, "UIPanelCloseButtonDefaultAnchors");

local subtitle = CreateText(
	comparisonFrame,
	"GameFontHighlightSmall",
	"Retail LIVE source-backed controls. Drag the title; use /checkboxradiocomparison or /crc."
);
subtitle:SetPoint("TOPLEFT", 24, -48);

local combatText = CreateText(comparisonFrame, "GameFontHighlightSmall", "");
combatText:SetPoint("TOPRIGHT", -24, -48);

local standardSection = CreateSection(
	comparisonFrame,
	24,
	-78,
	205,
	"1. UICheckButtonTemplate states",
	"Plain OnClick reads the post-click GetChecked() state; disabled rows remain inert."
);

local standardCheckbox = CreateAddonLabeledCheckButton(
	standardSection,
	"UICheckButtonTemplate",
	"Enabled unchecked (interactive)",
	14,
	-65
);
standardCheckbox:SetChecked(false);
local standardState = CreateText(standardSection, "GameFontHighlightSmall", "State: Unchecked");
standardState:SetPoint("TOPLEFT", 230, -73);
standardCheckbox:SetScript("OnClick", function(button, _buttonName, _down)
	local checked = button:GetChecked();
	standardState:SetText(checked and "State: Checked" or "State: Unchecked");
	PrintStatus("standard checkbox is now " .. (checked and "checked." or "unchecked."));
end);

local enabledChecked = CreateAddonLabeledCheckButton(
	standardSection,
	"UICheckButtonTemplate",
	"Enabled checked (interactive)",
	14,
	-99
);
enabledChecked:SetChecked(true);
enabledChecked:SetScript("OnClick", function(button)
	PrintStatus("enabled checked example is now " .. (button:GetChecked() and "checked." or "unchecked."));
end);

local disabledUnchecked, disabledUncheckedLabel = CreateAddonLabeledCheckButton(
	standardSection,
	"UICheckButtonTemplate",
	"Disabled unchecked",
	14,
	-133
);
disabledUnchecked:SetChecked(false);
disabledUnchecked:SetEnabled(false);
disabledUncheckedLabel:SetTextColor(0.5, 0.5, 0.5);

local disabledChecked, disabledCheckedLabel = CreateAddonLabeledCheckButton(
	standardSection,
	"UICheckButtonTemplate",
	"Disabled checked",
	214,
	-133
);
disabledChecked:SetChecked(true);
disabledChecked:SetEnabled(false);
disabledCheckedLabel:SetTextColor(0.5, 0.5, 0.5);

local hitSection = CreateSection(
	comparisonFrame,
	24,
	-295,
	155,
	"2. Label hit behavior",
	"Click each text label. Only the expanded-hit-row label should toggle its checkbox."
);

local checkboxOnly = CreateAddonLabeledCheckButton(
	hitSection,
	"UICheckButtonTemplate",
	"Checkbox-only hit target",
	14,
	-68
);
checkboxOnly:SetScript("OnClick", function(button)
	PrintStatus("checkbox-only target is now " .. (button:GetChecked() and "checked." or "unchecked."));
end);

local clickableLabelCheckbox = CreateAddonLabeledCheckButton(
	hitSection,
	"UICheckButtonTemplate",
	"Clickable label via expanded hit rectangle",
	14,
	-105
);
clickableLabelCheckbox:SetHitRectInsets(0, -235, 0, 0);
clickableLabelCheckbox:SetScript("OnClick", function(button)
	PrintStatus("clickable-label checkbox is now " .. (button:GetChecked() and "checked." or "unchecked."));
end);

local minimalSection = CreateSection(
	comparisonFrame,
	24,
	-462,
	187,
	"3. MinimalCheckboxTemplate",
	"Compact native art with addon-owned labels; the interactive row keeps its natural hit target."
);

local minimalCheckbox = CreateAddonLabeledCheckButton(
	minimalSection,
	"MinimalCheckboxTemplate",
	"Minimal interactive",
	14,
	-66
);
minimalCheckbox:SetChecked(false);
local minimalState = CreateText(minimalSection, "GameFontHighlightSmall", "State: Unchecked");
minimalState:SetPoint("TOPLEFT", 225, -74);
minimalCheckbox:SetScript("OnClick", function(button)
	local checked = button:GetChecked();
	minimalState:SetText(checked and "State: Checked" or "State: Unchecked");
	PrintStatus("minimal checkbox is now " .. (checked and "checked." or "unchecked."));
end);

local minimalDisabledUnchecked, minimalDisabledUncheckedLabel = CreateAddonLabeledCheckButton(
	minimalSection,
	"MinimalCheckboxTemplate",
	"Disabled unchecked",
	14,
	-103
);
minimalDisabledUnchecked:SetChecked(false);
minimalDisabledUnchecked:SetEnabled(false);
minimalDisabledUncheckedLabel:SetTextColor(0.5, 0.5, 0.5);

local minimalDisabledChecked, minimalDisabledCheckedLabel = CreateAddonLabeledCheckButton(
	minimalSection,
	"MinimalCheckboxTemplate",
	"Disabled checked",
	214,
	-103
);
minimalDisabledChecked:SetChecked(true);
minimalDisabledChecked:SetEnabled(false);
minimalDisabledCheckedLabel:SetTextColor(0.5, 0.5, 0.5);

local minimalHint = CreateText(
	minimalSection,
	"GameFontDisableSmall",
	"The label does not enlarge the MinimalCheckboxTemplate hit area in this example."
);
minimalHint:SetPoint("TOPLEFT", 14, -148);
minimalHint:SetWidth(SECTION_WIDTH - 28);
minimalHint:SetJustifyH("LEFT");

local radioSection = CreateSection(
	comparisonFrame,
	442,
	-78,
	250,
	"4 + 5. UIRadioButtonTemplate group",
	"One addon-owned value drives every sibling; Delta is a native disabled CheckButton."
);

local selectedRadio = "Alpha";
local radioButtons = {};
local radioSummary = CreateText(radioSection, "GameFontHighlightSmall", "Selected: Alpha");
radioSummary:SetPoint("TOPLEFT", 14, -214);

local function RefreshRadioButtons()
	for _, radio in ipairs(radioButtons) do
		radio:SetChecked(radio.value == selectedRadio);
	end
	radioSummary:SetText("Selected: " .. selectedRadio);
end

for index, value in ipairs({"Alpha", "Beta", "Gamma"}) do
	local radio = CreateAddonLabeledCheckButton(
		radioSection,
		"UIRadioButtonTemplate",
		value,
		16,
		-65 - ((index - 1) * 37)
	);
	radio.value = value;
	radio:SetHitRectInsets(0, -70, 0, 0);
	radio:SetScript("OnClick", function(button)
		selectedRadio = button.value;
		RefreshRadioButtons();
		PrintStatus("selected radio changed to " .. selectedRadio .. ".");
	end);
	table.insert(radioButtons, radio);
end

local disabledRadio, disabledRadioLabel = CreateAddonLabeledCheckButton(
	radioSection,
	"UIRadioButtonTemplate",
	"Delta (Disabled)",
	16,
	-176
);
disabledRadio.value = "Delta";
disabledRadio:SetChecked(false);
disabledRadio:SetEnabled(false);
disabledRadioLabel:SetTextColor(0.5, 0.5, 0.5);
table.insert(radioButtons, disabledRadio);
RefreshRadioButtons();

local scaleSection = CreateSection(
	comparisonFrame,
	442,
	-340,
	145,
	"6. Root-frame scale",
	"Fixed research choices scale and recenter this sample only; nothing is persisted."
);

local scaleText = CreateText(scaleSection, "GameFontHighlightSmall", "Current scale: 100%");
scaleText:SetPoint("TOPLEFT", 14, -105);

for index, scaleChoice in ipairs({
	{label = "75%", value = 0.75},
	{label = "100%", value = 1},
	{label = "125%", value = 1.25},
}) do
	local button = CreateFrame("Button", nil, scaleSection, "UIPanelButtonTemplate");
	button:SetSize(100, 24);
	button:SetPoint("TOPLEFT", 14 + ((index - 1) * 118), -67);
	button:SetText(scaleChoice.label);
	button:SetScript("OnClick", function()
		comparisonFrame:SetScale(scaleChoice.value);
		comparisonFrame:ClearAllPoints();
		comparisonFrame:SetPoint("CENTER");
		scaleText:SetText("Current scale: " .. scaleChoice.label);
		PrintStatus("UI scale changed to " .. scaleChoice.label .. ".");
	end);
end

local observationSection = CreateSection(
	comparisonFrame,
	442,
	-497,
	152,
	"7 + 8. Runtime observations",
	"Bare shared controls do not add Settings accessibility infrastructure."
);

local observationText = CreateText(
	observationSection,
	"GameFontHighlightSmall",
	"Observe native mouse, keyboard, gamepad, and narration behavior as exposed.\n"
		.. "During combat, test these inert controls; no production callback safety is implied."
);
observationText:SetPoint("TOPLEFT", 14, -67);
observationText:SetWidth(SECTION_WIDTH - 28);
observationText:SetJustifyH("LEFT");

local footer = CreateText(
	comparisonFrame,
	"GameFontDisableSmall",
	"Retail 12.1.0.69497 / 027d26c34. No SavedVariables, polling, secure frames, or Settings registration."
);
footer:SetPoint("BOTTOMLEFT", 24, 17);

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
	id = "checkboxes-radios",
	name = "Checkboxes & Radios",
	frame = comparisonFrame,
});

SLASH_CHECKBOXRADIOCOMPARISON1 = "/checkboxradiocomparison";
SLASH_CHECKBOXRADIOCOMPARISON2 = "/crc";
SlashCmdList.CHECKBOXRADIOCOMPARISON = function()
	RetailUIResearch:ToggleSample("checkboxes-radios");
end;

PrintStatus("loaded. Use /checkboxradiocomparison or /crc to toggle the sample window.");
