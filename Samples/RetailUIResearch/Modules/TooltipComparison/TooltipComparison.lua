-- luacheck: globals CreateFrame GameTooltip GameTooltip_SetDefaultAnchor UIParent
-- luacheck: globals SlashCmdList InCombatLockdown IsControlKeyDown ScrollBoxConstants
-- luacheck: globals SLASH_TOOLTIPCOMPARISON1 SLASH_TOOLTIPCOMPARISON2

local _, RetailUIResearch = ...;
local ADDON_NAME = "TooltipComparison";

local WINDOW_WIDTH = 1180;
local WINDOW_HEIGHT = 820;
local PANEL_WIDTH = 554;
local LOG_LIMIT = 50;

local logEntries = {};
local logSequence = 0;
local logDisplay;
local restoringLogText = false;

local activeTestID;
local activeTrigger;
local activeOwner;
local activeContentMode;
local activeDataBackedTest = false;

local phase2Tooltip;
local activePhase2TestID;
local activePhase2Trigger;
local activePhase2Owner;

local function RefreshLog()
	if not logDisplay then
		return;
	end

	local authoritativeText = table.concat(logEntries, "\n");
	if logDisplay:GetText() ~= authoritativeText then
		restoringLogText = true;
		logDisplay:SetText(authoritativeText);
		restoringLogText = false;
	end
	logDisplay:GetScrollBox():ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation);
end

local function Record(testID, text, announce)
	logSequence = logSequence + 1;
	local message = string.format("#%03d [%s] %s", logSequence, testID, text);
	table.insert(logEntries, message);
	if #logEntries > LOG_LIMIT then
		table.remove(logEntries, 1);
	end
	RefreshLog();

	if announce then
		print(string.format("|cff33ff99%s:|r %s", ADDON_NAME, message));
	end
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

local function CreatePanel(parent, titleText, detailText)
	local panel = CreateFrame("Frame", nil, parent);

	local background = panel:CreateTexture(nil, "BACKGROUND");
	background:SetAllPoints();
	background:SetColorTexture(0.025, 0.025, 0.035, 0.78);

	AddEdge(panel, "TOPLEFT", "TOPRIGHT", nil, 1);
	AddEdge(panel, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1);
	AddEdge(panel, "TOPLEFT", "BOTTOMLEFT", 1, nil);
	AddEdge(panel, "TOPRIGHT", "BOTTOMRIGHT", 1, nil);

	local title = CreateText(panel, "GameFontNormal", titleText);
	title:SetPoint("TOPLEFT", 12, -10);

	local detail = CreateText(panel, "GameFontDisableSmall", detailText);
	detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2);
	detail:SetPoint("RIGHT", panel, "RIGHT", -12, 0);
	detail:SetJustifyH("LEFT");

	return panel;
end

local function CreateActionButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	button:SetSize(width, 25);
	button:SetText(text);
	return button;
end

local function CombatLabel()
	return InCombatLockdown() and "YES" or "NO";
end

local function ReleaseControlledTooltip(reason, announce)
	if not activeTestID then
		return;
	end

	local testID = activeTestID;
	local ownerMatches = activeOwner and GameTooltip:IsOwned(activeOwner);
	if ownerMatches then
		GameTooltip:Hide();
		GameTooltip:ClearLines();
		GameTooltip:ClearAllPoints();
	end

	Record(testID, string.format(
		"cleanup reason=%s ownerMatched=%s shownAfter=%s",
		reason,
		tostring(ownerMatches),
		tostring(GameTooltip:IsShown())
	), announce);

	activeTestID = nil;
	activeTrigger = nil;
	activeOwner = nil;
	activeContentMode = nil;
	activeDataBackedTest = false;
end

local function PrepareTest(testID, trigger, owner, ownerLabel, anchorMode, contentMode)
	ReleaseControlledTooltip("replaced by another sample test", false);
	activeTestID = testID;
	activeTrigger = trigger;
	activeOwner = owner;
	activeContentMode = contentMode;
	activeDataBackedTest = testID == "I1" or testID == "S1";
	Record(testID, string.format(
		"requested combat=%s owner=%s anchor=%s content=%s",
		CombatLabel(),
		ownerLabel,
		anchorMode,
		contentMode
	), true);
end

local function CompleteTest(testID, setterResult)
	local resultText = setterResult == nil and "n/a" or tostring(setterResult);
	Record(testID, string.format(
		"call sequence completed setterResult=%s shown=%s",
		resultText,
		tostring(GameTooltip:IsShown())
	), true);
end

local function AddManualContent(testID, title, ownerText, anchorText)
	GameTooltip:SetText(title, 1, 0.82, 0, 1, true);
	GameTooltip:AddLine("Ordinary addon-created trigger; manual tooltip content.", 1, 1, 1, true);
	GameTooltip:AddDoubleLine("Requested owner", ownerText, 0.75, 0.75, 0.75, 1, 1, 1);
	GameTooltip:AddDoubleLine("Requested anchor", anchorText, 0.75, 0.75, 0.75, 1, 1, 1);
	GameTooltip:AddLine("Visual placement is observed manually; no geometry is read.", 0.55, 0.82, 1, true);
	GameTooltip:Show();
	CompleteTest(testID);
end

local function BindPlacementTrigger(button, onEnter)
	button:SetScript("OnEnter", onEnter);
	button:SetScript("OnLeave", function(self)
		if activeTrigger == self then
			ReleaseControlledTooltip("trigger OnLeave", false);
		end
	end);
end

local function ReleasePhase2Tooltip(reason, announce)
	if not activePhase2TestID then
		return;
	end

	local testID = activePhase2TestID;
	local ownerMatches = activePhase2Owner and phase2Tooltip:IsOwned(activePhase2Owner);
	if ownerMatches then
		phase2Tooltip:Hide();
		phase2Tooltip:ClearLines();
		phase2Tooltip:ClearAllPoints();
	end

	Record(testID, string.format(
		"cleanup reason=%s ownerMatched=%s shownAfter=%s",
		reason,
		tostring(ownerMatches),
		tostring(phase2Tooltip:IsShown())
	), announce);

	activePhase2TestID = nil;
	activePhase2Trigger = nil;
	activePhase2Owner = nil;
end

local function PreparePhase2Test(testID, trigger, owner, ownerLabel, topology)
	ReleasePhase2Tooltip("replaced by another Phase 2A test", false);
	activePhase2TestID = testID;
	activePhase2Trigger = trigger;
	activePhase2Owner = owner;
	Record(testID, string.format(
		"requested combat=%s owner=%s topology=%s trigger=synthetic restricted-layout tooltip=TooltipComparisonPhase2Tooltip",
		CombatLabel(),
		ownerLabel,
		topology
	), true);
end

local function CompletePhase2Test(testID)
	Record(testID, string.format(
		"call sequence completed setterResult=n/a shown=%s",
		tostring(phase2Tooltip:IsShown())
	), true);
end

local function AddPhase2ManualContent(testID, title, ownerText, anchorText)
	phase2Tooltip:SetText(title, 1, 0.82, 0, 1, true);
	phase2Tooltip:AddLine("Dedicated addon-created tooltip; Phase 2A runtime result pending.", 1, 1, 1, true);
	phase2Tooltip:AddDoubleLine("Requested owner", ownerText, 0.75, 0.75, 0.75, 1, 1, 1);
	phase2Tooltip:AddDoubleLine("Requested anchor", anchorText, 0.75, 0.75, 0.75, 1, 1, 1);
	phase2Tooltip:AddLine("No geometry is read and no matched aspect is added.", 0.55, 0.82, 1, true);
	phase2Tooltip:Show();
	CompletePhase2Test(testID);
end

local function BindPhase2Trigger(trigger, onEnter)
	trigger:SetScript("OnEnter", onEnter);
	trigger:SetScript("OnLeave", function(self)
		if activePhase2Trigger == self then
			ReleasePhase2Tooltip("trigger OnLeave", false);
		end
	end);
end

local comparisonFrame = CreateFrame("Frame", "TooltipComparisonFrame", UIParent);
comparisonFrame:Hide();
comparisonFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
comparisonFrame:SetPoint("CENTER");
comparisonFrame:SetFrameStrata("DIALOG");
comparisonFrame:SetClampedToScreen(true);
comparisonFrame:SetMovable(true);
comparisonFrame:EnableMouse(true);

CreateFrame("Frame", nil, comparisonFrame, "DialogBorderDarkTemplate");
local header = CreateFrame("Frame", nil, comparisonFrame, "DialogHeaderTemplate");
header:Setup("Tooltip Comparison — Phase 1 / Phase 2A");
header:EnableMouse(true);
header:RegisterForDrag("LeftButton");
header:SetScript("OnDragStart", function()
	if not InCombatLockdown() then
		comparisonFrame:StartMoving();
	else
		Record("GLOBAL", "movement is intentionally disabled during combat", true);
	end
end);
header:SetScript("OnDragStop", function()
	comparisonFrame:StopMovingOrSizing();
end);
CreateFrame("Button", nil, comparisonFrame, "UIPanelCloseButtonDefaultAnchors");

local subtitle = CreateText(
	comparisonFrame,
	"GameFontHighlightSmall",
	"Phase 1 clean controls and Phase 2A synthetic restricted-layout tests. Visual evidence remains manual."
);
subtitle:SetPoint("TOPLEFT", 24, -48);

phase2Tooltip = CreateFrame(
	"GameTooltip",
	"TooltipComparisonPhase2Tooltip",
	UIParent,
	"SharedTooltipTemplate"
);
phase2Tooltip:Hide();

local combatText = CreateText(comparisonFrame, "GameFontHighlightSmall", "");
combatText:SetPoint("TOPRIGHT", -24, -48);

local scaleLabel = CreateText(comparisonFrame, "GameFontDisableSmall", "Root scale:");
scaleLabel:SetPoint("TOP", comparisonFrame, "TOP", 255, -47);

for index, scaleChoice in ipairs({
	{label = "75%", value = 0.75},
	{label = "100%", value = 1},
	{label = "125%", value = 1.25},
}) do
	local button = CreateActionButton(comparisonFrame, scaleChoice.label, 50);
	button:SetPoint("LEFT", scaleLabel, "RIGHT", 7 + ((index - 1) * 54), 0);
	button:SetScript("OnClick", function()
		ReleaseControlledTooltip("root scale changed", false);
		ReleasePhase2Tooltip("root scale changed", false);
		comparisonFrame:SetScale(scaleChoice.value);
		comparisonFrame:ClearAllPoints();
		comparisonFrame:SetPoint("CENTER");
		Record("GLOBAL", "root scale changed to " .. scaleChoice.label, true);
	end);
end

local phase1Button = CreateActionButton(comparisonFrame, "Phase 1", 100);
phase1Button:SetPoint("TOPLEFT", 24, -76);

local phase2Button = CreateActionButton(comparisonFrame, "Phase 2", 100);
phase2Button:SetPoint("LEFT", phase1Button, "RIGHT", 8, 0);

local phase1Page = CreateFrame("Frame", nil, comparisonFrame);
phase1Page:SetPoint("TOPLEFT", 24, -108);
phase1Page:SetPoint("TOPRIGHT", -24, -108);
phase1Page:SetHeight(388);

local phase2Page = CreateFrame("Frame", nil, comparisonFrame);
phase2Page:SetAllPoints(phase1Page);
phase2Page:Hide();

local function ShowPhasePage(page)
	if page == phase1Page then
		ReleasePhase2Tooltip("Phase 2A page hidden", false);
		phase2Page:Hide();
		phase1Page:Show();
		phase1Button:Disable();
		phase2Button:Enable();
	else
		phase1Page:Hide();
		phase2Page:Show();
		phase1Button:Enable();
		phase2Button:Disable();
	end
end

phase1Button:SetScript("OnClick", function()
	ShowPhasePage(phase1Page);
end);
phase2Button:SetScript("OnClick", function()
	ShowPhasePage(phase2Page);
end);
ShowPhasePage(phase1Page);

local placementPanel = CreatePanel(
	phase1Page,
	"Placement controls",
	"Five owner/anchor compositions. Hover buttons; no screen-coordinate getters are used."
);
placementPanel:SetPoint("TOPLEFT");
placementPanel:SetSize(PANEL_WIDTH, 388);

local placementCases = {
	{
		id = "P1",
		label = "1. Automatic ANCHOR_LEFT",
		detail = "Trigger owns tooltip; native automatic left placement.",
	},
	{
		id = "P2",
		label = "2. ANCHOR_NONE + SetPoint",
		detail = "Trigger owns tooltip; direct RIGHT-to-LEFT dependency, -8px.",
	},
	{
		id = "P3",
		label = "3. UIParent + ANCHOR_CURSOR",
		detail = "Independent owner and cursor placement; trigger only drives lifetime.",
	},
	{
		id = "P4",
		label = "4. UIParent owner + button point",
		detail = "Independent owner; direct positioning dependency on clean trigger.",
	},
	{
		id = "P5",
		label = "5. GameTooltip_SetDefaultAnchor",
		detail = "Trigger supplied as parent; helper selects the default container.",
	},
};

local placementButtons = {};
for index, caseInfo in ipairs(placementCases) do
	local y = -62 - ((index - 1) * 68);
	local button = CreateActionButton(placementPanel, caseInfo.label, 245);
	button:SetPoint("TOPLEFT", 14, y);
	placementButtons[index] = button;

	local detail = CreateText(placementPanel, "GameFontDisableSmall", caseInfo.detail);
	detail:SetPoint("LEFT", button, "RIGHT", 12, 0);
	detail:SetWidth(270);
	detail:SetJustifyH("LEFT");
end

BindPlacementTrigger(placementButtons[1], function(self)
	PrepareTest("P1", self, self, "trigger button", "ANCHOR_LEFT", "manual text");
	GameTooltip:SetOwner(self, "ANCHOR_LEFT");
	AddManualContent("P1", "Automatic ANCHOR_LEFT", "trigger button", "ANCHOR_LEFT");
end);

BindPlacementTrigger(placementButtons[2], function(self)
	PrepareTest("P2", self, self, "trigger button", "ANCHOR_NONE + SetPoint", "manual text");
	GameTooltip:SetOwner(self, "ANCHOR_NONE");
	GameTooltip:ClearAllPoints();
	GameTooltip:SetPoint("RIGHT", self, "LEFT", -8, 0);
	AddManualContent("P2", "ANCHOR_NONE + direct SetPoint", "trigger button", "RIGHT -> trigger LEFT");
end);

BindPlacementTrigger(placementButtons[3], function(self)
	PrepareTest("P3", self, UIParent, "UIParent", "ANCHOR_CURSOR", "manual text");
	GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR");
	AddManualContent("P3", "UIParent + ANCHOR_CURSOR", "UIParent", "ANCHOR_CURSOR");
end);

BindPlacementTrigger(placementButtons[4], function(self)
	PrepareTest("P4", self, UIParent, "UIParent", "ANCHOR_NONE + SetPoint to trigger", "manual text");
	GameTooltip:SetOwner(UIParent, "ANCHOR_NONE");
	GameTooltip:ClearAllPoints();
	GameTooltip:SetPoint("RIGHT", self, "LEFT", -8, 0);
	AddManualContent("P4", "UIParent owner + trigger point", "UIParent", "RIGHT -> trigger LEFT");
end);

BindPlacementTrigger(placementButtons[5], function(self)
	PrepareTest("P5", self, self, "trigger button", "GameTooltip_SetDefaultAnchor", "manual text");
	GameTooltip_SetDefaultAnchor(GameTooltip, self);
	AddManualContent("P5", "Blizzard default-anchor helper", "trigger button", "helper-selected container");
end);

local contentPanel = CreatePanel(
	phase1Page,
	"Data-backed content controls",
	"Enter a positive numeric ID, then hover Show. Both tests use UIParent + ANCHOR_CURSOR."
);
contentPanel:SetPoint("TOPRIGHT");
contentPanel:SetSize(PANEL_WIDTH, 388);

local function CreateIDTest(parent, y, testID, title, setterName)
	local titleText = CreateText(parent, "GameFontNormal", title);
	titleText:SetPoint("TOPLEFT", 14, y);

	local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate");
	input:SetSize(155, 24);
	input:SetPoint("TOPLEFT", 14, y - 29);
	input:SetAutoFocus(false);
	input:SetNumeric(true);
	input:SetMaxLetters(10);
	input:SetScript("OnEnterPressed", function(self)
		self:ClearFocus();
	end);
	input:SetScript("OnEscapePressed", function(self)
		self:ClearFocus();
	end);

	local trigger = CreateActionButton(parent, "Hover to show", 150);
	trigger:SetPoint("LEFT", input, "RIGHT", 12, 0);

	local status = CreateText(parent, "GameFontDisableSmall", "No ID supplied; runtime result pending.");
	status:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -7);
	status:SetWidth(510);
	status:SetJustifyH("LEFT");

	trigger:SetScript("OnEnter", function(self)
		local id = tonumber(input:GetText());
		if not id or id <= 0 or id ~= math.floor(id) then
			status:SetText("Enter a positive whole-number ID before hovering the trigger.");
			Record(testID, "request rejected: no valid positive whole-number ID", true);
			return;
		end

		PrepareTest(testID, self, UIParent, "UIParent", "ANCHOR_CURSOR", setterName .. " id=" .. id);
		GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR");
		local setterResult = GameTooltip[setterName](GameTooltip, id);
		local hasData = GameTooltip:GetPrimaryTooltipData() ~= nil;
		status:SetText(string.format(
			"Requested ID %d; setterResult=%s; primaryData=%s; shown=%s.",
			id,
			tostring(setterResult),
			tostring(hasData),
			tostring(GameTooltip:IsShown())
		));
		CompleteTest(testID, setterResult);
	end);

	trigger:SetScript("OnLeave", function(self)
		if activeTrigger == self then
			ReleaseControlledTooltip("trigger OnLeave", false);
		end
	end);

	return input, trigger, status;
end

CreateIDTest(contentPanel, -66, "I1", "Item-backed: SetItemByID", "SetItemByID");
CreateIDTest(contentPanel, -175, "S1", "Spell-backed: SetSpellByID", "SetSpellByID");

local contentNotes = CreateText(
    contentPanel,
    "GameFontDisableSmall",
    "The module does not hardcode IDs, request cold-cache conditions, or hook item/spell callback systems. "
        .. "TOOLTIP_DATA_UPDATE is logged only while one of these sample tests remains active "
        .. "and its data instance matches."
);
contentNotes:SetPoint("TOPLEFT", 14, -286);
contentNotes:SetWidth(526);
contentNotes:SetJustifyH("LEFT");
contentNotes:SetWordWrap(true);

local manualNotes = CreateText(
    contentPanel,
    "GameFontDisableSmall",
    "Placement rows exercise SetText, AddLine, and AddDoubleLine. "
        .. "Their visual position is intentionally not inferred by Lua."
);
manualNotes:SetPoint("TOPLEFT", contentNotes, "BOTTOMLEFT", 0, -16);
manualNotes:SetWidth(526);
manualNotes:SetJustifyH("LEFT");
manualNotes:SetWordWrap(true);

local phase2Panel = CreatePanel(
	phase2Page,
	"Phase 2A — synthetic restricted-layout trigger",
	"Three isolated addon-created test frames. Runtime outcomes remain pending until LIVE validation."
);
phase2Panel:SetAllPoints();

local function CreateRestrictedTrigger(parent, labelText, y)
	local background = parent:CreateTexture(nil, "ARTWORK");
	background:SetPoint("TOPLEFT", 18, y);
	background:SetSize(310, 42);
	background:SetColorTexture(0.12, 0.12, 0.16, 1);

	local label = CreateText(parent, "GameFontHighlightSmall", labelText);
	label:SetPoint("TOPLEFT", 32, y - 14);

	local trigger = CreateFrame("Frame", nil, parent, "DisableUntrustedLayoutScriptsTemplate");
	trigger:SetPoint("TOPLEFT", 18, y);
	trigger:SetSize(310, 42);
	trigger:EnableMouse(true);
	return trigger;
end

local restrictedTrigger1 = CreateRestrictedTrigger(phase2Panel, "R1. Restricted owner + ANCHOR_LEFT", -72);
local restrictedTrigger2 = CreateRestrictedTrigger(phase2Panel, "R2. Restricted owner + direct SetPoint", -150);
local restrictedTrigger3 = CreateRestrictedTrigger(phase2Panel, "R3. UIParent owner + restricted SetPoint", -228);

local phase2Descriptions = {
	"Owner is the restricted trigger; automatic ANCHOR_LEFT placement.",
	"Owner is the restricted trigger; ANCHOR_NONE, then tooltip RIGHT to trigger LEFT.",
	"Owner is UIParent; ANCHOR_NONE, then tooltip RIGHT to restricted trigger LEFT.",
};
for index, description in ipairs(phase2Descriptions) do
	local detail = CreateText(phase2Panel, "GameFontDisableSmall", description);
	detail:SetPoint("TOPLEFT", 350, -82 - ((index - 1) * 78));
	detail:SetWidth(740);
	detail:SetJustifyH("LEFT");
end

BindPhase2Trigger(restrictedTrigger1, function(self)
	PreparePhase2Test("R1", self, self, "synthetic restricted trigger", "ANCHOR_LEFT");
	phase2Tooltip:SetOwner(self, "ANCHOR_LEFT");
	AddPhase2ManualContent("R1", "Restricted owner + ANCHOR_LEFT", "restricted trigger", "ANCHOR_LEFT");
end);

BindPhase2Trigger(restrictedTrigger2, function(self)
	PreparePhase2Test("R2", self, self, "synthetic restricted trigger", "ANCHOR_NONE + SetPoint");
	phase2Tooltip:SetOwner(self, "ANCHOR_NONE");
	phase2Tooltip:ClearAllPoints();
	phase2Tooltip:SetPoint("RIGHT", self, "LEFT", -8, 0);
	AddPhase2ManualContent("R2", "Restricted owner + direct SetPoint", "restricted trigger", "RIGHT -> trigger LEFT");
end);

BindPhase2Trigger(restrictedTrigger3, function(self)
	PreparePhase2Test("R3", self, UIParent, "UIParent", "ANCHOR_NONE + SetPoint to restricted trigger");
	phase2Tooltip:SetOwner(UIParent, "ANCHOR_NONE");
	phase2Tooltip:ClearAllPoints();
	phase2Tooltip:SetPoint("RIGHT", self, "LEFT", -8, 0);
	AddPhase2ManualContent("R3", "UIParent owner + restricted SetPoint", "UIParent", "RIGHT -> restricted trigger LEFT");
end);

local phase2Notes = CreateText(
	phase2Panel,
	"GameFontDisableSmall",
	"Phase 2A does not add a matching forbidden aspect to the dedicated tooltip. "
		.. "Phase 2B, native AuraButton topology, and any production integration remain deferred."
);
phase2Notes:SetPoint("BOTTOMLEFT", 18, 18);
phase2Notes:SetPoint("RIGHT", -18, 0);
phase2Notes:SetJustifyH("LEFT");
phase2Notes:SetWordWrap(true);

local diagnosticPanel = CreatePanel(
	comparisonFrame,
	"Bounded tooltip diagnostics",
	"Newest 50 numbered observations. Click the text, then Ctrl+A / Ctrl+C; accidental edits are restored."
);
diagnosticPanel:SetPoint("TOPLEFT", 24, -508);
diagnosticPanel:SetPoint("BOTTOMRIGHT", -24, 38);

logDisplay = CreateFrame("Frame", nil, diagnosticPanel, "ScrollingEditBoxTemplate");
logDisplay:SetPoint("TOPLEFT", 12, -54);
logDisplay:SetPoint("BOTTOMRIGHT", -132, 12);
logDisplay:SetFontObject("GameFontDisableSmall");
logDisplay:SetTextInsets(6, 6, 6, 6);

local logBackground = logDisplay:CreateTexture(nil, "BACKGROUND");
logBackground:SetAllPoints();
logBackground:SetColorTexture(0.015, 0.015, 0.022, 0.9);
AddEdge(logDisplay, "TOPLEFT", "TOPRIGHT", nil, 1);
AddEdge(logDisplay, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1);
AddEdge(logDisplay, "TOPLEFT", "BOTTOMLEFT", 1, nil);
AddEdge(logDisplay, "TOPRIGHT", "BOTTOMRIGHT", 1, nil);

local logEditBox = logDisplay:GetEditBox();
logEditBox:SetAutoFocus(false);
logEditBox:SetMultiLine(true);
logDisplay:RegisterCallback("OnTextChanged", function(_, _, isUserInput)
	if isUserInput and not restoringLogText then
		RefreshLog();
	end
end, comparisonFrame);
logDisplay:RegisterCallback("OnKeyDown", function(_, editBox, key)
	if key == "A" and IsControlKeyDown() then
		editBox:HighlightText();
	end
end, comparisonFrame);

local clearLogButton = CreateActionButton(diagnosticPanel, "Clear Log", 100);
clearLogButton:SetPoint("TOPRIGHT", -14, -60);
clearLogButton:SetScript("OnClick", function()
	logEntries = {};
	logSequence = 0;
	RefreshLog();
	print(string.format("|cff33ff99%s:|r diagnostic history cleared.", ADDON_NAME));
end);

local footer = CreateText(
	comparisonFrame,
	"GameFontDisableSmall",
	"Retail 12.1.0.69587 / 8ea15b61e. Phase 1 complete; Phase 2A runtime pending; "
		.. "no SavedVariables or polling."
);
footer:SetPoint("BOTTOMLEFT", 24, 12);

local function UpdateCombatState(inCombat)
	if inCombat then
		combatText:SetText("Combat: YES");
		combatText:SetTextColor(1, 0.35, 0.25);
	else
		combatText:SetText("Combat: NO");
		combatText:SetTextColor(0.35, 1, 0.45);
	end
end

comparisonFrame:RegisterEvent("PLAYER_REGEN_DISABLED");
comparisonFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
comparisonFrame:RegisterEvent("TOOLTIP_DATA_UPDATE");
comparisonFrame:SetScript("OnEvent", function(_, event, dataInstanceID)
	if event == "PLAYER_REGEN_DISABLED" then
		UpdateCombatState(true);
		Record("COMBAT", "PLAYER_REGEN_DISABLED; no tooltip test was started automatically", true);
	elseif event == "PLAYER_REGEN_ENABLED" then
		UpdateCombatState(false);
		Record("COMBAT", "PLAYER_REGEN_ENABLED", true);
	elseif event == "TOOLTIP_DATA_UPDATE" and activeDataBackedTest then
		local matches = dataInstanceID == nil or GameTooltip:HasDataInstanceID(dataInstanceID);
		if matches then
			Record(activeTestID or "DATA", string.format(
				"TOOLTIP_DATA_UPDATE observed while content=%s dataInstanceID=%s; no Async attribution claimed",
				activeContentMode,
				tostring(dataInstanceID)
			), false);
		end
	end
end);
UpdateCombatState(InCombatLockdown());

comparisonFrame:SetScript("OnShow", function()
	Record("GLOBAL", "sample opened; Phase 1 complete and Phase 2A runtime pending", true);
end);

comparisonFrame:SetScript("OnHide", function()
	ReleaseControlledTooltip("sample closed", false);
	ReleasePhase2Tooltip("sample closed", false);
	Record("GLOBAL", "sample closed; controlled tooltip cleanup requested", false);
end);

RefreshLog();

RetailUIResearch:RegisterSample({
	id = "tooltips",
	name = "Tooltips",
	frame = comparisonFrame,
});

SLASH_TOOLTIPCOMPARISON1 = "/tooltipcomparison";
SLASH_TOOLTIPCOMPARISON2 = "/ttc";
SlashCmdList.TOOLTIPCOMPARISON = function()
	RetailUIResearch:ToggleSample("tooltips");
end;

Record("GLOBAL", "Phase 1 / Phase 2A module loaded; use /tooltipcomparison or /ttc", false);
