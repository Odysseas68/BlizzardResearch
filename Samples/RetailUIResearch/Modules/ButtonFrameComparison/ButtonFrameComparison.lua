-- luacheck: globals CreateFrame UIParent CreateRadioButtonGroup SlashCmdList
-- luacheck: globals SLASH_BUTTONFRAMECOMPARISON1 SLASH_BUTTONFRAMECOMPARISON2

local _, RetailUIResearch = ...;
local ADDON_NAME = "ButtonFrameComparison";

local WINDOW_WIDTH = 1120;
local WINDOW_HEIGHT = 820;
local SHELL_WIDTH = 600;
local SHELL_HEIGHT = 330;
local SAMPLE_ICON = "Interface\\Icons\\INV_Misc_Gear_01";

local function CreateText(parent, fontObject, text)
	local fontString = parent:CreateFontString(nil, "ARTWORK", fontObject);
	fontString:SetText(text);
	return fontString;
end

local function CreateNeutralContainer(frame)
	local background = frame:CreateTexture(nil, "BACKGROUND");
	background:SetAllPoints();
	background:SetColorTexture(0.025, 0.025, 0.035, 0.97);

	local function AddEdge(point1, point2, width, height)
		local edge = frame:CreateTexture(nil, "BORDER");
		edge:SetColorTexture(0.35, 0.35, 0.42, 1);
		edge:SetPoint(point1);
		edge:SetPoint(point2);
		if width then
			edge:SetWidth(width);
		end
		if height then
			edge:SetHeight(height);
		end
	end

	AddEdge("TOPLEFT", "TOPRIGHT", nil, 1);
	AddEdge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1);
	AddEdge("TOPLEFT", "BOTTOMLEFT", 1, nil);
	AddEdge("TOPRIGHT", "BOTTOMRIGHT", 1, nil);
end

local comparisonFrame = CreateFrame("Frame", "ButtonFrameComparisonFrame", UIParent);
comparisonFrame:Hide();
comparisonFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
comparisonFrame:SetPoint("CENTER");
comparisonFrame:SetFrameStrata("DIALOG");
comparisonFrame:SetClampedToScreen(true);
comparisonFrame:SetMovable(true);
comparisonFrame:EnableMouse(true);
comparisonFrame:RegisterForDrag("LeftButton");
comparisonFrame:SetScript("OnDragStart", comparisonFrame.StartMoving);
comparisonFrame:SetScript("OnDragStop", comparisonFrame.StopMovingOrSizing);
CreateNeutralContainer(comparisonFrame);

local title = CreateText(comparisonFrame, "GameFontNormalLarge", "Retail 12.1 Buttons + Frames Comparison");
title:SetPoint("TOPLEFT", 20, -18);

local subtitle = CreateText(
	comparisonFrame,
	"GameFontHighlightSmall",
	"All controls are real Blizzard templates. Drag this neutral outer window by its background."
);
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5);

local closeButton = CreateFrame("Button", nil, comparisonFrame, "UIPanelCloseButton");
closeButton:SetPoint("TOPRIGHT", -3, -3);
closeButton:SetScript("OnClick", function()
	comparisonFrame:Hide();
end);

local buttonSectionTitle = CreateText(comparisonFrame, "GameFontNormal", "BUTTONS");
buttonSectionTitle:SetPoint("TOPLEFT", 20, -66);

local buttonHint = CreateText(
	comparisonFrame,
	"GameFontDisableSmall",
	"Hover and press the interactive controls; use the state control to inspect disabled artwork."
);
buttonHint:SetPoint("LEFT", buttonSectionTitle, "RIGHT", 10, 0);

local statusText = CreateText(comparisonFrame, "GameFontHighlightSmall", "Ready for visual comparison.");
statusText:SetPoint("BOTTOMLEFT", 20, 16);
statusText:SetWidth(WINDOW_WIDTH - 40);
statusText:SetJustifyH("LEFT");

local function SetStatus(text)
	statusText:SetText(text);
end

local enableHandlers = {};

local function RegisterEnableHandler(handler)
	table.insert(enableHandlers, handler);
end

local function CreateButtonSlot(x, templateName, classification)
	local slot = CreateFrame("Frame", nil, comparisonFrame);
	slot:SetSize(205, 140);
	slot:SetPoint("TOPLEFT", x, -92);

	local name = CreateText(slot, "GameFontNormalSmall", templateName);
	name:SetPoint("TOPLEFT");
	name:SetWidth(200);
	name:SetJustifyH("LEFT");

	local class = CreateText(slot, "GameFontDisableSmall", classification);
	class:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3);
	class:SetWidth(200);
	class:SetJustifyH("LEFT");

	return slot;
end

local function ShowCandidateFailure(slot, templateName, errorText)
	local failure = CreateText(slot, "GameFontRedSmall", "Unavailable: " .. templateName);
	failure:SetPoint("TOPLEFT", 0, -52);
	failure:SetWidth(190);
	failure:SetJustifyH("LEFT");
	failure:SetText(failure:GetText() .. "\n" .. tostring(errorText));
end

local function TryCreateButton(slot, templateName)
	local success, buttonOrError = pcall(CreateFrame, "Button", nil, slot, templateName);
	if not success then
		ShowCandidateFailure(slot, templateName, buttonOrError);
		return nil;
	end
	return buttonOrError;
end

do
	local slot = CreateButtonSlot(20, "UIPanelButtonTemplate", "CURRENT GENERAL-PURPOSE (A)");
	local button = TryCreateButton(slot, "UIPanelButtonTemplate");
	if button then
		button:SetSize(165, 24);
		button:SetPoint("TOPLEFT", 0, -54);
		button:SetText("Standard Action");
		button:SetScript("OnClick", function()
			SetStatus("UIPanelButtonTemplate clicked.");
		end);
		RegisterEnableHandler(function(enabled)
			button:SetEnabled(enabled);
		end);
	end
end

do
	local slot = CreateButtonSlot(235, "SharedButtonSmallTemplate", "CURRENT GENERAL-PURPOSE (A)");
	local button = TryCreateButton(slot, "SharedButtonSmallTemplate");
	if button then
		button:SetPoint("TOPLEFT", 0, -50);
		button:SetText("Current Action");
		button:SetScript("OnClick", function()
			SetStatus("SharedButtonSmallTemplate clicked.");
		end);
		RegisterEnableHandler(function(enabled)
			button:SetEnabled(enabled);
		end);
	end
end

do
	local slot = CreateButtonSlot(450, "SquareIconButtonTemplate", "CURRENT GENERAL-PURPOSE (A)");
	local button = TryCreateButton(slot, "SquareIconButtonTemplate");
	if button then
		button:SetPoint("TOPLEFT", 0, -49);
		button:SetIcon(SAMPLE_ICON);
		button:SetOnClickHandler(function()
			SetStatus("SquareIconButtonTemplate clicked.");
		end);
		RegisterEnableHandler(function(enabled)
			button:SetEnabledState(enabled);
		end);
	end
end

do
	local slot = CreateButtonSlot(665, "MinimalTabTemplate (pair)", "CURRENT SPECIALIZED (B)");
	local firstTab = TryCreateButton(slot, "MinimalTabTemplate");
	local secondTab = TryCreateButton(slot, "MinimalTabTemplate");
	if firstTab and secondTab then
		local function SetTabText(tab, text)
			tab.Text:SetText(text);
			tab:SetWidth(tab.Text:GetStringWidth() + 40);
		end

		SetTabText(firstTab, "First");
		SetTabText(secondTab, "Second");
		firstTab:SetPoint("TOPLEFT", -5, -44);
		secondTab:SetPoint("LEFT", firstTab, "RIGHT", -10, 0);

		local tabGroup = CreateRadioButtonGroup();
		tabGroup:AddButtons({firstTab, secondTab});
		tabGroup:SelectAtIndex(1);

		firstTab:HookScript("OnClick", function()
			SetStatus("MinimalTabTemplate selected: First.");
		end);
		secondTab:HookScript("OnClick", function()
			SetStatus("MinimalTabTemplate selected: Second.");
		end);
		RegisterEnableHandler(function(enabled)
			firstTab:SetEnabled(enabled);
			secondTab:SetEnabled(enabled);
		end);
	else
		if firstTab then
			firstTab:Hide();
		end
		if secondTab then
			secondTab:Hide();
		end
	end
end

do
	local slot = CreateButtonSlot(
		880,
		"SharedGoldRedButtonSmallTemplate",
		"Legacy / Old GoldRed • CURRENT SPECIALIZED (B)"
	);
	local button = TryCreateButton(slot, "SharedGoldRedButtonSmallTemplate");
	if button then
		button:SetPoint("TOPLEFT", 0, -50);
		button:SetText("Legacy / Old");
		button:SetScript("OnClick", function()
			SetStatus("Legacy / Old GoldRed comparison clicked.");
		end);
		RegisterEnableHandler(function(enabled)
			button:SetEnabled(enabled);
		end);
	end
end

local samplesEnabled = true;
local stateButton = CreateFrame("Button", nil, comparisonFrame, "UIPanelButtonTemplate");
stateButton:SetSize(130, 22);
stateButton:SetPoint("TOPRIGHT", -20, -62);
stateButton:SetText("Show disabled");
stateButton:SetScript("OnClick", function(self)
	samplesEnabled = not samplesEnabled;
	for _, handler in ipairs(enableHandlers) do
		handler(samplesEnabled);
	end
	self:SetText(samplesEnabled and "Show disabled" or "Restore enabled");
	SetStatus(
		samplesEnabled
		and "Button samples restored to enabled state."
		or "Button samples are disabled for visual inspection."
	);
end);

local separator = comparisonFrame:CreateTexture(nil, "BORDER");
separator:SetColorTexture(0.35, 0.35, 0.42, 1);
separator:SetPoint("TOPLEFT", 20, -242);
separator:SetPoint("TOPRIGHT", -20, -242);
separator:SetHeight(1);

local frameSectionTitle = CreateText(comparisonFrame, "GameFontNormal", "FRAME / DIALOG SHELLS");
frameSectionTitle:SetPoint("TOPLEFT", 20, -262);

local dropdownLabel = CreateText(comparisonFrame, "GameFontHighlight", "Frame Style");
dropdownLabel:SetPoint("TOPLEFT", 20, -292);

local shellClassification = CreateText(comparisonFrame, "GameFontDisableSmall", "");
shellClassification:SetPoint("TOPLEFT", 20, -330);
shellClassification:SetWidth(WINDOW_WIDTH - 40);
shellClassification:SetJustifyH("LEFT");

local shellHost = CreateFrame("Frame", nil, comparisonFrame);
shellHost:SetSize(640, 360);
shellHost:SetPoint("TOP", comparisonFrame, "TOP", 0, -370);

local function AddStandardContent(shell, contentParent, buttonTemplate)
	local body = CreateText(contentParent, "GameFontHighlight", "Sample content for visual comparison.");
	body:SetPoint("CENTER", contentParent, "CENTER", 0, 20);

	local okButton = CreateFrame("Button", nil, shell, buttonTemplate or "UIPanelButtonTemplate");
	okButton:SetSize(100, 22);
	okButton:SetText("OK");
	okButton:SetScript("OnClick", function()
		SetStatus("OK clicked in the active frame shell.");
	end);
	return okButton;
end

local shellEntries = {
	{
		name = "UIPanelDialogTemplate",
		classification = "LEGACY BUT SUPPORTED (C)",
		create = function()
			local shell = CreateFrame("Frame", nil, shellHost, "UIPanelDialogTemplate");
			shell:Hide();
			shell:SetSize(SHELL_WIDTH, SHELL_HEIGHT);
			shell:SetPoint("CENTER");
			shell.Title:SetText("Blizzard Frame Sample");
			local okButton = AddStandardContent(shell, shell);
			okButton:SetPoint("BOTTOM", 0, 28);
			return shell;
		end,
	},
	{
		name = "DialogBorderDarkTemplate + DialogHeaderTemplate",
		classification = "CURRENT GENERAL-PURPOSE (A)",
		create = function()
			local shell = CreateFrame("Frame", nil, shellHost);
			shell:Hide();
			shell:SetSize(SHELL_WIDTH, SHELL_HEIGHT);
			shell:SetPoint("CENTER");
			CreateFrame("Frame", nil, shell, "DialogBorderDarkTemplate");
			local header = CreateFrame("Frame", nil, shell, "DialogHeaderTemplate");
			header:Setup("Blizzard Frame Sample");
			CreateFrame("Button", nil, shell, "UIPanelCloseButtonDefaultAnchors");
			local okButton = AddStandardContent(shell, shell);
			okButton:SetPoint("BOTTOM", 0, 28);
			return shell;
		end,
	},
	{
		name = "SettingsFrameTemplate",
		classification = "CURRENT GENERAL-PURPOSE (A)",
		create = function()
			local shell = CreateFrame("Frame", nil, shellHost, "SettingsFrameTemplate");
			shell:Hide();
			shell:SetSize(SHELL_WIDTH, SHELL_HEIGHT);
			shell:SetPoint("CENTER");
			shell.NineSlice.Text:SetText("Blizzard Frame Sample");
			local okButton = AddStandardContent(shell, shell);
			okButton:SetPoint("BOTTOM", 0, 28);
			return shell;
		end,
	},
	{
		name = "ButtonFrameTemplate",
		classification = "CURRENT GENERAL-PURPOSE (A)",
		create = function()
			local shell = CreateFrame("Frame", nil, shellHost, "ButtonFrameTemplate");
			shell:Hide();
			shell:SetSize(SHELL_WIDTH, SHELL_HEIGHT);
			shell:SetPoint("CENTER");
			shell:SetTitle("Blizzard Frame Sample");
			shell:SetPortraitTextureRaw(SAMPLE_ICON);
			local okButton = AddStandardContent(shell, shell.Inset, "MagicButtonTemplate");
			okButton:ClearAllPoints();
			okButton:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -6, 4);
			return shell;
		end,
	},
};

for _, entry in ipairs(shellEntries) do
	local success, shellOrError = pcall(entry.create);
	if success then
		entry.frame = shellOrError;
		entry.frame:Hide();
	else
		entry.error = tostring(shellOrError);
	end
end

local selectedShellIndex = 1;
local frameStyleDropdown;

local function ShowShell(index)
	for _, entry in ipairs(shellEntries) do
		if entry.frame then
			entry.frame:Hide();
		end
	end

	selectedShellIndex = index;
	local entry = shellEntries[index];
	shellClassification:SetText(entry.name .. " — " .. entry.classification);
	if entry.frame then
		entry.frame:Show();
		SetStatus("Showing " .. entry.name .. ".");
	else
		SetStatus("Unavailable: " .. entry.name .. " — " .. (entry.error or "unknown creation failure"));
	end

	if frameStyleDropdown then
		frameStyleDropdown:Update();
	end
end

frameStyleDropdown = CreateFrame("DropdownButton", nil, comparisonFrame, "WowStyle1DropdownTemplate");
frameStyleDropdown:SetSize(420, 32);
frameStyleDropdown:SetPoint("LEFT", dropdownLabel, "RIGHT", 12, 0);
frameStyleDropdown:SetDefaultText("Select frame style");
frameStyleDropdown:SetupMenu(function(_, rootDescription)
	local function IsSelected(index)
		return selectedShellIndex == index;
	end

	local function SetSelected(index)
		ShowShell(index);
	end

	for index, entry in ipairs(shellEntries) do
		rootDescription:CreateRadio(entry.name, IsSelected, SetSelected, index);
	end
end);

comparisonFrame:SetScript("OnShow", function()
	local entry = shellEntries[selectedShellIndex];
	if entry and entry.frame then
		entry.frame:Show();
	end
end);

ShowShell(selectedShellIndex);

RetailUIResearch:RegisterSample({
	id = "buttons-frames",
	name = "Buttons & Frames",
	frame = comparisonFrame,
});

SLASH_BUTTONFRAMECOMPARISON1 = "/buttonframecomparison";
SLASH_BUTTONFRAMECOMPARISON2 = "/bbfsample";
SlashCmdList.BUTTONFRAMECOMPARISON = function()
	RetailUIResearch:ToggleSample("buttons-frames");
end;

print(string.format(
	"%s loaded. Use /buttonframecomparison or /bbfsample to toggle the comparison window.",
	ADDON_NAME
));
