-- luacheck: globals CreateFrame UIParent MenuUtil SlashCmdList InCombatLockdown
-- luacheck: globals SLASH_DROPDOWNMENUCOMPARISON1 SLASH_DROPDOWNMENUCOMPARISON2

local ADDON_NAME = ...;

local WINDOW_WIDTH = 920;
local WINDOW_HEIGHT = 620;
local SECTION_WIDTH = 426;
local SECTION_HEIGHT = 145;

local CHOICES = {"Alpha", "Beta", "Gamma"};
local RENDERING_CHOICES = {"Compact", "Normal", "Large"};
local DYNAMIC_DATASETS = {
	{"One", "Two", "Three"},
	{"Red", "Green"},
	{"Small", "Medium", "Large", "Huge"},
};
local CHECKBOX_OPTIONS = {
	{key = "names", label = "Show Names"},
	{key = "durations", label = "Show Durations"},
	{key = "icons", label = "Show Icons"},
};

local state = {
	style1Selection = "Alpha",
	style2Selection = "Alpha",
	dynamicDataset = 1,
	dynamicSelection = "One",
	checkboxes = {
		names = true,
		durations = false,
		icons = true,
	},
	rendering = "Normal",
};

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

local function CreateSection(parent, x, y, titleText, detailText)
	local section = CreateFrame("Frame", nil, parent);
	section:SetSize(SECTION_WIDTH, SECTION_HEIGHT);
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

local comparisonFrame = CreateFrame("Frame", "DropdownMenuComparisonFrame", UIParent);
comparisonFrame:Hide();
comparisonFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
comparisonFrame:SetPoint("CENTER");
comparisonFrame:SetFrameStrata("DIALOG");
comparisonFrame:SetClampedToScreen(true);
comparisonFrame:SetMovable(true);
comparisonFrame:EnableMouse(true);
comparisonFrame:RegisterForDrag("LeftButton");
comparisonFrame:SetScript("OnDragStart", function(self)
	if not InCombatLockdown() then
		self:StartMoving();
	else
		PrintStatus("Movement is intentionally disabled during combat.");
	end
end);
comparisonFrame:SetScript("OnDragStop", comparisonFrame.StopMovingOrSizing);

CreateFrame("Frame", nil, comparisonFrame, "DialogBorderDarkTemplate");
local header = CreateFrame("Frame", nil, comparisonFrame, "DialogHeaderTemplate");
header:Setup("Dropdown Menu Comparison");
CreateFrame("Button", nil, comparisonFrame, "UIPanelCloseButtonDefaultAnchors");

local subtitle = CreateText(
	comparisonFrame,
	"GameFontHighlightSmall",
	"Retail LIVE source-backed controls. Drag the window background; use /dropdownmenucomparison or /dmc."
);
subtitle:SetPoint("TOPLEFT", 24, -48);

local combatText = CreateText(comparisonFrame, "GameFontHighlightSmall", "");
combatText:SetPoint("TOPRIGHT", -24, -48);

local styleSection = CreateSection(
	comparisonFrame,
	24,
	-78,
	"1 + 6. Single-select and style comparison",
	"The two controls use the same choices but independent addon-owned state."
);

local style1Label = CreateText(styleSection, "GameFontNormalSmall", "Style 1");
style1Label:SetPoint("TOPLEFT", 14, -60);

local style1Dropdown = CreateFrame("DropdownButton", nil, styleSection, "WowStyle1DropdownTemplate");
style1Dropdown:SetSize(180, 25);
style1Dropdown:SetPoint("TOPLEFT", 14, -78);
style1Dropdown:SetDefaultText("Choose a value");

local style1Summary = CreateText(styleSection, "GameFontHighlightSmall", "Selected: Alpha");
style1Summary:SetPoint("TOPLEFT", style1Dropdown, "BOTTOMLEFT", 0, -5);

local function IsStyle1Selected(value)
	return state.style1Selection == value;
end

local function SetStyle1Selected(value)
	state.style1Selection = value;
	style1Summary:SetText("Selected: " .. value);
	PrintStatus("Style 1 selection changed to " .. value .. ".");
end

style1Dropdown:SetupMenu(function(_dropdown, rootDescription)
	for _, value in ipairs(CHOICES) do
		rootDescription:CreateRadio(value, IsStyle1Selected, SetStyle1Selected, value);
	end
end);

local style2Label = CreateText(styleSection, "GameFontNormalSmall", "Style 2");
style2Label:SetPoint("TOPLEFT", 218, -60);

local style2Dropdown = CreateFrame("DropdownButton", nil, styleSection, "WowStyle2DropdownTemplate");
style2Dropdown:SetSize(180, 25);
style2Dropdown:SetPoint("TOPLEFT", 218, -78);
style2Dropdown:SetDefaultText("Choose a value");

local style2Summary = CreateText(styleSection, "GameFontHighlightSmall", "Selected: Alpha");
style2Summary:SetPoint("TOPLEFT", style2Dropdown, "BOTTOMLEFT", 0, -5);

local function IsStyle2Selected(value)
	return state.style2Selection == value;
end

local function SetStyle2Selected(value)
	state.style2Selection = value;
	style2Summary:SetText("Selected: " .. value);
	PrintStatus("Style 2 selection changed to " .. value .. ".");
end

style2Dropdown:SetupMenu(function(_dropdown, rootDescription)
	for _, value in ipairs(CHOICES) do
		rootDescription:CreateRadio(value, IsStyle2Selected, SetStyle2Selected, value);
	end
end);

local dynamicSection = CreateSection(
	comparisonFrame,
	24,
	-235,
	"2. Dynamic regeneration",
	"Cycle the dataset, then open the same dropdown frame to inspect fresh options."
);

local dynamicDropdown = CreateFrame("DropdownButton", nil, dynamicSection, "WowStyle1DropdownTemplate");
dynamicDropdown:SetSize(170, 25);
dynamicDropdown:SetPoint("TOPLEFT", 14, -68);
dynamicDropdown:SetDefaultText("Choose dynamic value");

local dynamicSummary = CreateText(dynamicSection, "GameFontHighlightSmall", "");
dynamicSummary:SetPoint("TOPLEFT", 14, -103);
dynamicSummary:SetWidth(SECTION_WIDTH - 28);
dynamicSummary:SetJustifyH("LEFT");

local function UpdateDynamicSummary(normalized)
	local suffix = normalized and " (selection normalized)" or "";
	dynamicSummary:SetText(string.format(
		"Dataset %d — selected: %s%s",
		state.dynamicDataset,
		state.dynamicSelection,
		suffix
	));
end

local function IsDynamicSelected(value)
	return state.dynamicSelection == value;
end

local function SetDynamicSelected(value)
	state.dynamicSelection = value;
	UpdateDynamicSummary(false);
	PrintStatus(string.format("Dynamic dataset %d selection changed to %s.", state.dynamicDataset, value));
end

dynamicDropdown:SetupMenu(function(_dropdown, rootDescription)
	local options = DYNAMIC_DATASETS[state.dynamicDataset];
	for _, value in ipairs(options) do
		rootDescription:CreateRadio(value, IsDynamicSelected, SetDynamicSelected, value);
	end
end);

local function ContainsValue(values, wanted)
	for _, value in ipairs(values) do
		if value == wanted then
			return true;
		end
	end
	return false;
end

local changeDatasetButton = CreateFrame("Button", nil, dynamicSection, "UIPanelButtonTemplate");
changeDatasetButton:SetSize(190, 24);
changeDatasetButton:SetPoint("LEFT", dynamicDropdown, "RIGHT", 14, 0);
changeDatasetButton:SetText("Change Dynamic Options");
changeDatasetButton:SetScript("OnClick", function()
	state.dynamicDataset = (state.dynamicDataset % #DYNAMIC_DATASETS) + 1;
	local options = DYNAMIC_DATASETS[state.dynamicDataset];
	local normalized = not ContainsValue(options, state.dynamicSelection);
	if normalized then
		state.dynamicSelection = options[1];
	end
	UpdateDynamicSummary(normalized);
	PrintStatus(string.format(
		"Dynamic options changed to dataset %d; open the dropdown to regenerate it.",
		state.dynamicDataset
	));
end);
UpdateDynamicSummary(false);

local checkboxSection = CreateSection(
	comparisonFrame,
	24,
	-392,
	"3. Checkbox menu + filter style",
	"The fixed-label Filter control exposes independent checkbox descriptions."
);

local checkboxDropdown = CreateFrame(
	"DropdownButton",
	nil,
	checkboxSection,
	"WowStyle1FilterDropdownTemplate"
);
checkboxDropdown:SetPoint("TOPLEFT", 14, -72);

local checkboxSummary = CreateText(checkboxSection, "GameFontHighlightSmall", "");
checkboxSummary:SetPoint("LEFT", checkboxDropdown, "RIGHT", 18, 0);
checkboxSummary:SetWidth(235);
checkboxSummary:SetJustifyH("LEFT");

local function UpdateCheckboxSummary()
	local enabled = {};
	for _, option in ipairs(CHECKBOX_OPTIONS) do
		if state.checkboxes[option.key] then
			table.insert(enabled, (option.label:gsub("^Show ", "")));
		end
	end
	checkboxSummary:SetText("Enabled: " .. (#enabled > 0 and table.concat(enabled, ", ") or "None"));
end

local function IsCheckboxSelected(key)
	return state.checkboxes[key];
end

local function ToggleCheckbox(key)
	state.checkboxes[key] = not state.checkboxes[key];
	UpdateCheckboxSummary();
	PrintStatus(string.format("%s is now %s.", key, state.checkboxes[key] and "enabled" or "disabled"));
end

checkboxDropdown:SetupMenu(function(_dropdown, rootDescription)
	for _, option in ipairs(CHECKBOX_OPTIONS) do
		rootDescription:CreateCheckbox(option.label, IsCheckboxSelected, ToggleCheckbox, option.key);
	end
end);
UpdateCheckboxSummary();

local nestedSection = CreateSection(
	comparisonFrame,
	470,
	-78,
	"4. Nested menu",
	"Rendering is a normal button description whose children are radio descriptions."
);

local nestedDropdown = CreateFrame("DropdownButton", nil, nestedSection, "WowStyle1DropdownTemplate");
nestedDropdown:SetSize(180, 25);
nestedDropdown:SetPoint("TOPLEFT", 14, -70);
nestedDropdown:SetDefaultText("Choose rendering");

local nestedSummary = CreateText(nestedSection, "GameFontHighlightSmall", "Rendering: Normal");
nestedSummary:SetPoint("LEFT", nestedDropdown, "RIGHT", 18, 0);

local function IsRenderingSelected(value)
	return state.rendering == value;
end

local function SetRenderingSelected(value)
	state.rendering = value;
	nestedSummary:SetText("Rendering: " .. value);
	PrintStatus("Nested rendering selection changed to " .. value .. ".");
end

nestedDropdown:SetupMenu(function(_dropdown, rootDescription)
	local rendering = rootDescription:CreateButton("Rendering");
	for _, value in ipairs(RENDERING_CHOICES) do
		rendering:CreateRadio(value, IsRenderingSelected, SetRenderingSelected, value);
	end
end);

local contextSection = CreateSection(
	comparisonFrame,
	470,
	-235,
	"5. Context menu",
	"Right-click the ordinary button. Blizzard_Menu owns and anchors the menu."
);

local function ContextMenuGenerator(_owner, rootDescription, sourceLabel)
	rootDescription:CreateTitle("Research context menu");
	rootDescription:CreateButton("Context Action A", function(label)
		PrintStatus("Context Action A from " .. label .. ".");
	end, sourceLabel);
	rootDescription:CreateButton("Context Action B", function(label)
		PrintStatus("Context Action B from " .. label .. ".");
	end, sourceLabel);

	local disabled = rootDescription:CreateButton("Disabled Example");
	disabled:SetEnabled(false);
end

local contextButton = CreateFrame("Button", nil, contextSection, "UIPanelButtonTemplate");
contextButton:SetSize(250, 26);
contextButton:SetPoint("TOPLEFT", 14, -70);
contextButton:SetText("Right-click for Context Menu");
contextButton:RegisterForClicks("LeftButtonUp", "RightButtonUp");
contextButton:SetScript("OnClick", function(self, mouseButton)
	if mouseButton == "RightButton" then
		MenuUtil.CreateContextMenu(self, ContextMenuGenerator, "the context test button");
	else
		PrintStatus("Right-click this button to open the context menu.");
	end
end);

local contextHint = CreateText(contextSection, "GameFontDisableSmall", "Actions only print to chat.");
contextHint:SetPoint("TOPLEFT", contextButton, "BOTTOMLEFT", 0, -7);

local observationSection = CreateSection(
	comparisonFrame,
	470,
	-392,
	"Manual runtime observations",
	"No combat result is claimed until this sample is tested in Retail."
);

local observationText = CreateText(
	observationSection,
	"GameFontHighlightSmall",
	"Move near right/bottom edges and reopen every menu.\n"
		.. "Repeat with another dialog visible and while manually in combat."
);
observationText:SetPoint("TOPLEFT", 14, -68);
observationText:SetWidth(SECTION_WIDTH - 28);
observationText:SetJustifyH("LEFT");

local footer = CreateText(
	comparisonFrame,
	"GameFontDisableSmall",
	"Retail 12.1.0.69497 / 027d26c34. No SavedVariables, polling, secure templates, or Settings registration."
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

comparisonFrame:RegisterEvent("PLAYER_LOGIN");
comparisonFrame:RegisterEvent("PLAYER_REGEN_DISABLED");
comparisonFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
comparisonFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_REGEN_DISABLED" then
		UpdateCombatState(true);
	elseif event == "PLAYER_REGEN_ENABLED" then
		UpdateCombatState(false);
	elseif event == "PLAYER_LOGIN" then
		UpdateCombatState(false);
		self:Show();
	end
end);

SLASH_DROPDOWNMENUCOMPARISON1 = "/dropdownmenucomparison";
SLASH_DROPDOWNMENUCOMPARISON2 = "/dmc";
SlashCmdList.DROPDOWNMENUCOMPARISON = function()
	comparisonFrame:SetShown(not comparisonFrame:IsShown());
end;

PrintStatus("loaded. Use /dropdownmenucomparison or /dmc to toggle the sample window.");
