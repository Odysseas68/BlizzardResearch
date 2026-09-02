-- luacheck: globals ACCEPT CANCEL CreateFrame InCombatLockdown IsControlKeyDown OKAY
-- luacheck: globals ScrollBoxConstants SlashCmdList StaticPopupDialogs StaticPopup_FindVisible
-- luacheck: globals StaticPopup_Hide StaticPopup_OnClick StaticPopup_Show
-- luacheck: globals StaticPopup_StandardEditBoxOnEscapePressed UIParent
-- luacheck: globals SLASH_DIALOGSANDPOPUPSCOMPARISON1 SLASH_DIALOGSANDPOPUPSCOMPARISON2

local _, RetailUIResearch = ...;
local ADDON_NAME = "DialogsAndPopupsComparison";

local WINDOW_WIDTH = 1180;
local WINDOW_HEIGHT = 820;
local LOG_LIMIT = 40;

local CONFIRMATION_KEY = "RETAIL_UI_RESEARCH_DIALOG_CONFIRMATION";
local EDITBOX_KEY = "RETAIL_UI_RESEARCH_DIALOG_EDITBOX";
local ORDINARY_POPUP_KEY = "RETAIL_UI_RESEARCH_DIALOG_NO_COVER";
local COVERED_POPUP_KEY = "RETAIL_UI_RESEARCH_DIALOG_FULL_SCREEN_COVER";

local logEntries = {};
local logSequence = 0;
local logDisplay;
local restoringLogText = false;
local requestSequence = 0;

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

local function Record(caseID, text, announce)
	logSequence = logSequence + 1;
	local entry = string.format("#%03d [%s] %s", logSequence, caseID, text);
	table.insert(logEntries, entry);
	if #logEntries > LOG_LIMIT then
		table.remove(logEntries, 1);
	end
	RefreshLog();

	if announce ~= false then
		print(string.format("|cff33ff99%s:|r %s", ADDON_NAME, entry));
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
	detail:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3);
	detail:SetPoint("RIGHT", panel, "RIGHT", -12, 0);
	detail:SetJustifyH("LEFT");
	detail:SetWordWrap(true);

	return panel;
end

local function CreateActionButton(parent, text, width, callback)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	button:SetSize(width, 24);
	button:SetText(text);
	button:SetScript("OnClick", callback);
	return button;
end

local function DescribeDialog(dialog)
	if not dialog then
		return "frame=nil";
	end

	return string.format(
		"frame=%s index=%s shown=%s visible=%s strata=%s level=%d",
		tostring(dialog:GetName()),
		tostring(dialog:GetID()),
		tostring(dialog:IsShown()),
		tostring(dialog:IsVisible()),
		dialog:GetFrameStrata(),
		dialog:GetFrameLevel()
	);
end

local function DescribeData(data)
	if type(data) ~= "table" then
		return "data=" .. tostring(data);
	end

	return string.format(
		"data.request=%s data.action=%s",
		tostring(data.request),
		tostring(data.action)
	);
end

local function NewData(action)
	requestSequence = requestSequence + 1;
	return {
		request = requestSequence,
		action = action,
	};
end

local function RecordPopup(caseID, eventName, dialog, data, suffix)
	local text = string.format(
		"%s; %s; %s",
		eventName,
		DescribeDialog(dialog),
		DescribeData(data)
	);
	if suffix then
		text = text .. "; " .. suffix;
	end
	Record(caseID, text);
end

StaticPopupDialogs[CONFIRMATION_KEY] = {
	text = "Confirm harmless research action?\nCaller arguments: %s / %s",
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	enterClicksFirstButton = true,
	selectCallbackByIndex = true,
	OnShow = function(dialog, data)
		RecordPopup("A", "OnShow", dialog, data, string.format(
			"args=%s/%s",
			tostring(data and data.arg1),
			tostring(data and data.arg2)
		));
	end,
	OnAccept = function(dialog, data, reason)
		RecordPopup("A", "OnAccept", dialog, data, "reason=" .. tostring(reason));
	end,
	OnCancel = function(dialog, data, reason)
		RecordPopup("A", "OnCancel", dialog, data, "reason=" .. tostring(reason));
	end,
	OnHide = function(dialog, data)
		RecordPopup("A", "OnHide", dialog, data);
	end,
};

StaticPopupDialogs[EDITBOX_KEY] = {
	text = "Type harmless research text, then test Accept, Cancel, Enter, or Escape.",
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	hasEditBox = true,
	selectCallbackByIndex = true,
	editBoxInstructions = "Harmless research text",
	editBoxWidth = 260,
	maxLetters = 64,
	OnShow = function(dialog, data)
		local editBox = dialog:GetEditBox();
		local focusBefore = editBox:HasFocus();
		editBox:SetFocus();
		RecordPopup("B", "OnShow", dialog, data, string.format(
			"focusBefore=%s focusAfter=%s",
			tostring(focusBefore),
			tostring(editBox:HasFocus())
		));
	end,
	OnAccept = function(dialog, data, reason)
		RecordPopup("B", "OnAccept", dialog, data, string.format(
			"reason=%s text=%q",
			tostring(reason),
			dialog:GetEditBoxText()
		));
	end,
	OnCancel = function(dialog, data, reason)
		RecordPopup("B", "OnCancel", dialog, data, "reason=" .. tostring(reason));
	end,
	OnHide = function(dialog, data)
		RecordPopup("B", "OnHide", dialog, data, "text=" .. string.format("%q", dialog:GetEditBoxText()));
	end,
	EditBoxOnEnterPressed = function(editBox, data)
		local dialog = editBox:GetParent();
		RecordPopup("B", "EditBoxOnEnterPressed", dialog, data, "text=" .. string.format("%q", editBox:GetText()));
		StaticPopup_OnClick(dialog, 1);
	end,
	EditBoxOnEscapePressed = function(editBox, data)
		local dialog = editBox:GetParent();
		RecordPopup("B", "EditBoxOnEscapePressed", dialog, data, "delegating to direct-hide standard handler");
		StaticPopup_StandardEditBoxOnEscapePressed(editBox);
	end,
};

StaticPopupDialogs[ORDINARY_POPUP_KEY] = {
	text = "Harmless StaticPopup %s comparison. Test background input, Escape, Accept, and Cancel.",
	button1 = OKAY,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	enterClicksFirstButton = true,
	selectCallbackByIndex = true,
	OnShow = function(dialog, data)
		RecordPopup("D-no-cover", "OnShow", dialog, data, "cover=false");
	end,
	OnAccept = function(dialog, data, reason)
		RecordPopup("D-no-cover", "OnAccept", dialog, data, "reason=" .. tostring(reason) .. " cover=false");
	end,
	OnCancel = function(dialog, data, reason)
		RecordPopup("D-no-cover", "OnCancel", dialog, data, "reason=" .. tostring(reason) .. " cover=false");
	end,
	OnHide = function(dialog, data)
		RecordPopup("D-no-cover", "OnHide", dialog, data, "cover=false");
	end,
};

StaticPopupDialogs[COVERED_POPUP_KEY] = {
	text = "Harmless StaticPopup %s comparison. Test background input, Escape, Accept, and Cancel.",
	button1 = OKAY,
	button2 = CANCEL,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	enterClicksFirstButton = true,
	selectCallbackByIndex = true,
	fullScreenCover = true,
	OnShow = function(dialog, data)
		RecordPopup("D-cover", "OnShow", dialog, data, "cover=true");
	end,
	OnAccept = function(dialog, data, reason)
		RecordPopup("D-cover", "OnAccept", dialog, data, "reason=" .. tostring(reason) .. " cover=true");
	end,
	OnCancel = function(dialog, data, reason)
		RecordPopup("D-cover", "OnCancel", dialog, data, "reason=" .. tostring(reason) .. " cover=true");
	end,
	OnHide = function(dialog, data)
		RecordPopup("D-cover", "OnHide", dialog, data, "cover=true");
	end,
};

local comparisonFrame = CreateFrame("Frame", "DialogsAndPopupsComparisonFrame", UIParent);
comparisonFrame:Hide();
comparisonFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
comparisonFrame:SetPoint("CENTER");
comparisonFrame:SetFrameStrata("DIALOG");
comparisonFrame:SetClampedToScreen(true);
comparisonFrame:SetMovable(true);
comparisonFrame:EnableMouse(true);

CreateFrame("Frame", nil, comparisonFrame, "DialogBorderDarkTemplate");
local header = CreateFrame("Frame", nil, comparisonFrame, "DialogHeaderTemplate");
header:Setup("Dialogs / Popups Comparison");
header:EnableMouse(true);
header:RegisterForDrag("LeftButton");
header:SetScript("OnDragStart", function()
	if not InCombatLockdown() then
		comparisonFrame:StartMoving();
	else
		Record("GLOBAL", "movement is intentionally disabled during combat");
	end
end);
header:SetScript("OnDragStop", function()
	comparisonFrame:StopMovingOrSizing();
end);
CreateFrame("Button", nil, comparisonFrame, "UIPanelCloseButtonDefaultAnchors");

local subtitle = CreateText(
	comparisonFrame,
	"GameFontHighlightSmall",
	"Behavior probes for registered StaticPopup, its EditBox/cover compositions, and an addon-owned DIALOG frame."
);
subtitle:SetPoint("TOPLEFT", 24, -48);

local combatText = CreateText(comparisonFrame, "GameFontHighlightSmall", "");
combatText:SetPoint("TOPRIGHT", -24, -48);

local scaleLabel = CreateText(comparisonFrame, "GameFontDisableSmall", "Root scale:");
scaleLabel:SetPoint("TOP", comparisonFrame, "TOP", 285, -48);

for index, scaleChoice in ipairs({
	{label = "75%", value = 0.75},
	{label = "100%", value = 1},
	{label = "125%", value = 1.25},
}) do
	local button = CreateActionButton(comparisonFrame, scaleChoice.label, 50, function()
		comparisonFrame:SetScale(scaleChoice.value);
		comparisonFrame:ClearAllPoints();
		comparisonFrame:SetPoint("CENTER");
		Record("GLOBAL", string.format(
			"sample root scale=%s effectiveScale=%.3f; StaticPopup remains UIParent/global-owned",
			scaleChoice.label,
			comparisonFrame:GetEffectiveScale()
		));
	end);
	button:SetPoint("LEFT", scaleLabel, "RIGHT", 7 + ((index - 1) * 54), 0);
end

local confirmationPanel = CreatePanel(
	comparisonFrame,
	"A. Registered StaticPopup confirmation",
	"Unique research key. Manually use native Accept/Cancel, Escape, duplicate replacement, and direct Hide."
);
confirmationPanel:SetPoint("TOPLEFT", 24, -78);
confirmationPanel:SetSize(556, 198);

local function ShowConfirmation(action)
	local data = NewData(action);
	data.arg1 = "argument-one";
	data.arg2 = action;
	local existing = StaticPopup_FindVisible(CONFIRMATION_KEY);
	Record("A", string.format(
		"StaticPopup_Show requested; %s; new %s",
		DescribeDialog(existing),
		DescribeData(data)
	));
	local dialog = StaticPopup_Show(CONFIRMATION_KEY, data.arg1, data.arg2, data);
	Record("A", "StaticPopup_Show returned; " .. DescribeDialog(dialog));
end

local showConfirmationButton = CreateActionButton(confirmationPanel, "Show Confirmation", 156, function()
	ShowConfirmation("initial-show");
end);
showConfirmationButton:SetPoint("BOTTOMLEFT", 12, 44);

local showDuplicateButton = CreateActionButton(confirmationPanel, "Show Duplicate", 156, function()
	ShowConfirmation("duplicate-show");
end);
showDuplicateButton:SetPoint("LEFT", showConfirmationButton, "RIGHT", 8, 0);

local hideConfirmationButton = CreateActionButton(confirmationPanel, "Direct Hide", 156, function()
	local dialog = StaticPopup_FindVisible(CONFIRMATION_KEY);
	Record("A", "StaticPopup_Hide requested; " .. DescribeDialog(dialog));
	StaticPopup_Hide(CONFIRMATION_KEY);
end);
hideConfirmationButton:SetPoint("LEFT", showDuplicateButton, "RIGHT", 8, 0);

local confirmationHint = CreateText(
	confirmationPanel,
	"GameFontDisableSmall",
	"Duplicate test: show the confirmation, then click Show Duplicate behind it. "
		.. "Direct Hide should produce teardown without Accept/Cancel."
);
confirmationHint:SetPoint("BOTTOMLEFT", 12, 14);
confirmationHint:SetWidth(528);
confirmationHint:SetJustifyH("LEFT");

local editBoxPanel = CreatePanel(
	comparisonFrame,
	"B. StaticPopup EditBox prompt",
	"Uses StaticPopup's built-in EditBox. OnShow intentionally focuses it; Enter uses native button dispatch."
);
editBoxPanel:SetPoint("TOPRIGHT", -24, -78);
editBoxPanel:SetSize(556, 198);

local showPromptButton = CreateActionButton(editBoxPanel, "Show Prompt", 122, function()
	local data = NewData("editbox-show");
	Record("B", "StaticPopup_Show requested; " .. DescribeData(data));
	local dialog = StaticPopup_Show(EDITBOX_KEY, nil, nil, data);
	Record("B", "StaticPopup_Show returned; " .. DescribeDialog(dialog));
end);
showPromptButton:SetPoint("BOTTOMLEFT", 12, 44);

local clearPromptFocusButton = CreateActionButton(editBoxPanel, "Clear Focus", 122, function()
	local dialog = StaticPopup_FindVisible(EDITBOX_KEY);
	if dialog then
		local editBox = dialog:GetEditBox();
		editBox:ClearFocus();
		RecordPopup("B", "ClearFocus requested", dialog, dialog.data, "focus=" .. tostring(editBox:HasFocus()));
	else
		Record("B", "ClearFocus requested; frame=nil");
	end
end);
clearPromptFocusButton:SetPoint("LEFT", showPromptButton, "RIGHT", 8, 0);

local hidePromptButton = CreateActionButton(editBoxPanel, "Direct Hide", 122, function()
	local dialog = StaticPopup_FindVisible(EDITBOX_KEY);
	Record("B", "StaticPopup_Hide requested; " .. DescribeDialog(dialog));
	StaticPopup_Hide(EDITBOX_KEY);
end);
hidePromptButton:SetPoint("LEFT", clearPromptFocusButton, "RIGHT", 8, 0);

local promptProbeButton = CreateActionButton(editBoxPanel, "Background Probe", 122, function()
	Record("B", "background sample control clicked while prompt state was user-controlled");
end);
promptProbeButton:SetPoint("LEFT", hidePromptButton, "RIGHT", 8, 0);

local editBoxHint = CreateText(
	editBoxPanel,
	"GameFontDisableSmall",
	"Type only harmless research text. Compare focused Escape, unfocused Escape, Enter, native Cancel, and Direct Hide."
);
editBoxHint:SetPoint("BOTTOMLEFT", 12, 14);
editBoxHint:SetWidth(528);
editBoxHint:SetJustifyH("LEFT");

local ownedPanel = CreatePanel(
	comparisonFrame,
	"C. Addon-owned non-modal DIALOG frame",
	"DIALOG is layering only. This ordinary non-secure child has no blocker and no registered Escape handler."
);
ownedPanel:SetPoint("TOPLEFT", 24, -290);
ownedPanel:SetSize(556, 198);

local ownedDialog = CreateFrame(
	"Frame",
	"RetailUIResearchAddonOwnedDialog",
	comparisonFrame
);
ownedDialog:Hide();
ownedDialog:SetSize(440, 220);
ownedDialog:SetPoint("CENTER", comparisonFrame, "CENTER", 0, 120);
ownedDialog:SetFrameStrata("DIALOG");
ownedDialog:SetFrameLevel(comparisonFrame:GetFrameLevel() + 40);
ownedDialog:SetClampedToScreen(true);
ownedDialog:EnableMouse(true);

CreateFrame("Frame", nil, ownedDialog, "DialogBorderDarkTemplate");
local ownedHeader = CreateFrame("Frame", nil, ownedDialog, "DialogHeaderTemplate");
ownedHeader:Setup("Addon-owned DIALOG");

local ownedBody = CreateText(
	ownedDialog,
	"GameFontHighlight",
	"This frame looks dialog-like, but every close path below is explicitly addon-owned. "
		.. "Uncovered sample controls remain independent."
);
ownedBody:SetPoint("TOPLEFT", 30, -62);
ownedBody:SetPoint("TOPRIGHT", -30, -62);
ownedBody:SetJustifyH("CENTER");
ownedBody:SetWordWrap(true);

local ownedCloseReason;
local function CloseOwnedDialog(reason)
	ownedCloseReason = reason;
	Record("C", reason .. " callback requested ownedDialog:Hide()");
	ownedDialog:Hide();
end

local ownedOkayButton = CreateActionButton(ownedDialog, OKAY, 110, function()
	CloseOwnedDialog("Okay");
end);
ownedOkayButton:SetPoint("BOTTOMRIGHT", ownedDialog, "BOTTOM", -8, 24);

local ownedCancelButton = CreateActionButton(ownedDialog, CANCEL, 110, function()
	CloseOwnedDialog("Cancel");
end);
ownedCancelButton:SetPoint("BOTTOMLEFT", ownedDialog, "BOTTOM", 8, 24);

local ownedCloseButton = CreateFrame("Button", nil, ownedDialog, "UIPanelCloseButtonDefaultAnchors");
ownedCloseButton:HookScript("PreClick", function()
	ownedCloseReason = "close button";
	Record("C", "close button PreClick; native close-button script remains unchanged");
end);

ownedDialog:SetScript("OnShow", function(self)
	ownedCloseReason = nil;
	Record("C", string.format(
		"OnShow; %s; parent=%s effectiveScale=%.3f",
		DescribeDialog(self),
		tostring(self:GetParent():GetName()),
		self:GetEffectiveScale()
	));
end);
ownedDialog:SetScript("OnHide", function(self)
	Record("C", string.format(
		"OnHide; %s; explicitReason=%s",
		DescribeDialog(self),
		tostring(ownedCloseReason)
	));
	ownedCloseReason = nil;
end);

local showOwnedButton = CreateActionButton(ownedPanel, "Show DIALOG", 122, function()
	Record("C", "show requested; DIALOG strata does not add modality");
	ownedDialog:Show();
end);
showOwnedButton:SetPoint("BOTTOMLEFT", 12, 44);

local ownedDirectHideButton = CreateActionButton(ownedPanel, "Direct Hide", 122, function()
	CloseOwnedDialog("Direct Hide");
end);
ownedDirectHideButton:SetPoint("LEFT", showOwnedButton, "RIGHT", 8, 0);

local ownedBackgroundProbe = CreateActionButton(ownedPanel, "Background Probe", 146, function()
	Record("C", "background sample control clicked; addon-owned DIALOG supplied no blocker");
end);
ownedBackgroundProbe:SetPoint("LEFT", ownedDirectHideButton, "RIGHT", 8, 0);

local ownedHint = CreateText(
	ownedPanel,
	"GameFontDisableSmall",
	"Use Okay, Cancel, close, Direct Hide, Escape, and the uncovered Background Probe to attribute behavior."
);
ownedHint:SetPoint("BOTTOMLEFT", 12, 14);
ownedHint:SetWidth(528);
ownedHint:SetJustifyH("LEFT");

local coverPanel = CreatePanel(
	comparisonFrame,
	"D. StaticPopup fullScreenCover comparison",
	"The definitions differ only by fullScreenCover=true. Neither callback performs gameplay work."
);
coverPanel:SetPoint("TOPRIGHT", -24, -290);
coverPanel:SetSize(556, 198);

local showOrdinaryPopupButton = CreateActionButton(coverPanel, "Show No Cover", 156, function()
	local data = NewData("no-cover-show");
	Record("D-no-cover", "StaticPopup_Show requested; " .. DescribeData(data));
	local dialog = StaticPopup_Show(ORDINARY_POPUP_KEY, "without cover", nil, data);
	Record("D-no-cover", "StaticPopup_Show returned; " .. DescribeDialog(dialog));
end);
showOrdinaryPopupButton:SetPoint("BOTTOMLEFT", 12, 44);

local showCoveredPopupButton = CreateActionButton(coverPanel, "Show fullScreenCover", 174, function()
	local data = NewData("covered-show");
	Record("D-cover", "StaticPopup_Show requested; " .. DescribeData(data));
	local dialog = StaticPopup_Show(COVERED_POPUP_KEY, "with fullScreenCover", nil, data);
	Record("D-cover", "StaticPopup_Show returned; " .. DescribeDialog(dialog));
end);
showCoveredPopupButton:SetPoint("LEFT", showOrdinaryPopupButton, "RIGHT", 8, 0);

local coverBackgroundProbe = CreateActionButton(coverPanel, "Background Probe", 146, function()
	Record("D", "background sample control clicked");
end);
coverBackgroundProbe:SetPoint("LEFT", showCoveredPopupButton, "RIGHT", 8, 0);

local coverHint = CreateText(
	coverPanel,
	"GameFontDisableSmall",
	"Dismiss one popup before opening the other. Compare this probe, outside mouse input, Escape, "
		.. "action-bar mouse, and keybind input."
);
coverHint:SetPoint("BOTTOMLEFT", 12, 14);
coverHint:SetWidth(528);
coverHint:SetJustifyH("LEFT");

local diagnosticPanel = CreatePanel(
	comparisonFrame,
	"Bounded callback and input diagnostics",
	"Newest 40 numbered entries. Click the text, then Ctrl+A / Ctrl+C to copy; accidental edits are restored."
);
diagnosticPanel:SetPoint("TOPLEFT", 24, -502);
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

local clearLogButton = CreateActionButton(diagnosticPanel, "Clear Log", 100, function()
	logEntries = {};
	logSequence = 0;
	RefreshLog();
	print(string.format("|cff33ff99%s:|r diagnostic history cleared.", ADDON_NAME));
end);
clearLogButton:SetPoint("TOPRIGHT", -14, -60);

local diagnosticProbeButton = CreateActionButton(diagnosticPanel, "Global Probe", 100, function()
	Record("GLOBAL", "background Global Probe clicked");
end);
diagnosticProbeButton:SetPoint("TOP", clearLogButton, "BOTTOM", 0, -10);

local footer = CreateText(
	comparisonFrame,
	"GameFontDisableSmall",
	"Source baseline 12.1.0.69497 / 027d26c34. Runtime validation pending; no SavedVariables, polling, or secure actions."
);
footer:SetPoint("BOTTOMLEFT", 24, 12);

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
comparisonFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		UpdateCombatState(true);
		Record("COMBAT", "PLAYER_REGEN_DISABLED; no automated popup action performed");
	elseif event == "PLAYER_REGEN_ENABLED" then
		UpdateCombatState(false);
		Record("COMBAT", "PLAYER_REGEN_ENABLED");
	end
end);
UpdateCombatState(InCombatLockdown());

comparisonFrame:SetScript("OnShow", function(self)
	Record("GLOBAL", string.format(
		"sample opened; root scale=%.2f effectiveScale=%.3f strata=%s level=%d",
		self:GetScale(),
		self:GetEffectiveScale(),
		self:GetFrameStrata(),
		self:GetFrameLevel()
	));
end);

comparisonFrame:SetScript("OnHide", function()
	if ownedDialog:IsShown() then
		ownedCloseReason = "sample root hidden";
		ownedDialog:Hide();
	end
	StaticPopup_Hide(CONFIRMATION_KEY);
	StaticPopup_Hide(EDITBOX_KEY);
	StaticPopup_Hide(ORDINARY_POPUP_KEY);
	StaticPopup_Hide(COVERED_POPUP_KEY);
end);

RefreshLog();

RetailUIResearch:RegisterSample({
	id = "dialogs-popups",
	name = "Dialogs / Popups",
	frame = comparisonFrame,
});

SLASH_DIALOGSANDPOPUPSCOMPARISON1 = "/dialogsandpopupscomparison";
SLASH_DIALOGSANDPOPUPSCOMPARISON2 = "/dapc";
SlashCmdList.DIALOGSANDPOPUPSCOMPARISON = function()
	RetailUIResearch:ToggleSample("dialogs-popups");
end;

Record("GLOBAL", "module loaded; use /dialogsandpopupscomparison or /dapc", false);
