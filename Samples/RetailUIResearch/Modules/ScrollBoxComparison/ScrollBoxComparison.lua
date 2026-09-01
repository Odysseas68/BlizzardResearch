-- luacheck: globals CreateFrame UIParent SlashCmdList InCombatLockdown IsControlKeyDown
-- luacheck: globals ScrollUtil ScrollBoxConstants BaseScrollBoxEvents ScrollBoxListMixin
-- luacheck: globals SelectionBehaviorMixin
-- luacheck: globals CreateDataProvider CreateScrollBoxListLinearView CreateScrollBoxListGridView
-- luacheck: globals SLASH_SCROLLBOXCOMPARISON1 SLASH_SCROLLBOXCOMPARISON2

local _, RetailUIResearch = ...;
local ADDON_NAME = "ScrollBoxComparison";

local WINDOW_WIDTH = 1240;
local WINDOW_HEIGHT = 900;
local MIN_WINDOW_WIDTH = 1100;
local MIN_WINDOW_HEIGHT = 780;
local MAX_WINDOW_WIDTH = 1360;
local MAX_WINDOW_HEIGHT = 960;
local MAX_DIAGNOSTIC_HISTORY = 50;

local eventSequence = 0;
local eventLog = {};
local eventLogDisplay;
local restoringEventLogText = false;

local function RefreshEventLog()
	if eventLogDisplay then
		local authoritativeText = table.concat(eventLog, "\n");
		if eventLogDisplay:GetText() ~= authoritativeText then
			restoringEventLogText = true;
			eventLogDisplay:SetText(authoritativeText);
			restoringEventLogText = false;
		end
		eventLogDisplay:GetScrollBox():ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation);
	end
end

local function RecordEvent(text, announce)
	eventSequence = eventSequence + 1;
	local message = string.format("#%03d %s", eventSequence, text);
	table.insert(eventLog, message);
	if #eventLog > MAX_DIAGNOSTIC_HISTORY then
		table.remove(eventLog, 1);
	end
	RefreshEventLog();

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

local function CreateActionButton(parent, text, width, callback)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate");
	button:SetSize(width, 22);
	button:SetText(text);
	button:SetScript("OnClick", callback);
	return button;
end

local comparisonFrame = CreateFrame("Frame", "ScrollBoxComparisonFrame", UIParent);
comparisonFrame:Hide();
comparisonFrame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
comparisonFrame:SetPoint("CENTER");
comparisonFrame:SetFrameStrata("DIALOG");
comparisonFrame:SetClampedToScreen(true);
comparisonFrame:SetMovable(true);
comparisonFrame:SetResizable(true);
comparisonFrame:SetResizeBounds(
	MIN_WINDOW_WIDTH,
	MIN_WINDOW_HEIGHT,
	MAX_WINDOW_WIDTH,
	MAX_WINDOW_HEIGHT
);
comparisonFrame:EnableMouse(true);

CreateFrame("Frame", nil, comparisonFrame, "DialogBorderDarkTemplate");
local header = CreateFrame("Frame", nil, comparisonFrame, "DialogHeaderTemplate");
header:Setup("ScrollBox Comparison");
header:EnableMouse(true);
header:RegisterForDrag("LeftButton");
header:SetScript("OnDragStart", function()
	if not InCombatLockdown() then
		comparisonFrame:StartMoving();
	else
		RecordEvent("movement is intentionally disabled during combat", true);
	end
end);
header:SetScript("OnDragStop", function()
	comparisonFrame:StopMovingOrSizing();
end);
CreateFrame("Button", nil, comparisonFrame, "UIPanelCloseButtonDefaultAnchors");

local subtitle = CreateText(
	comparisonFrame,
	"GameFontHighlightSmall",
	"Provider, view, pooling, selection, grid, and one-child ScrollFrame diagnostics."
);
subtitle:SetPoint("TOPLEFT", 24, -48);

local combatText = CreateText(comparisonFrame, "GameFontHighlightSmall", "");
combatText:SetPoint("TOPRIGHT", -24, -48);

local scaleLabel = CreateText(comparisonFrame, "GameFontDisableSmall", "Root scale:");
scaleLabel:SetPoint("TOP", comparisonFrame, "TOP", 250, -47);

for index, scaleChoice in ipairs({
	{label = "75%", value = 0.75},
	{label = "100%", value = 1},
	{label = "125%", value = 1.25},
}) do
	local button = CreateActionButton(comparisonFrame, scaleChoice.label, 50, function()
		comparisonFrame:SetScale(scaleChoice.value);
		comparisonFrame:ClearAllPoints();
		comparisonFrame:SetPoint("CENTER");
		RecordEvent("root scale changed to " .. scaleChoice.label, true);
	end);
	button:SetPoint("LEFT", scaleLabel, "RIGHT", 7 + ((index - 1) * 54), 0);
end

local fixedPanel = CreatePanel(
	comparisonFrame,
	"A. Fixed linear provider-backed ScrollBox",
	"40 deterministic rows; click an enabled row to test external single selection."
);
fixedPanel:SetPoint("TOPLEFT", 24, -76);
fixedPanel:SetPoint("BOTTOMRIGHT", comparisonFrame, "CENTER", -6, 8);

local variablePanel = CreatePanel(
	comparisonFrame,
	"B. Variable/mixed extent linear ScrollBox",
	"Deterministic 28/44/64px rows; toggle row 3 and rebuild with position retention."
);
variablePanel:SetPoint("TOPLEFT", comparisonFrame, "LEFT", 24, -4);
variablePanel:SetPoint("BOTTOMRIGHT", comparisonFrame, "BOTTOM", -6, 32);

local gridPanel = CreatePanel(
	comparisonFrame,
	"C. Fixed four-column grid",
	"31 synthetic tiles exercise virtualization and an incomplete final row."
);
gridPanel:SetPoint("TOPLEFT", comparisonFrame, "TOP", 6, -76);
gridPanel:SetPoint("BOTTOMRIGHT", comparisonFrame, "RIGHT", -24, 8);

local contrastPanel = CreatePanel(
	comparisonFrame,
	"D. Current ScrollFrameTemplate contrast",
	"One owned continuous child; no provider, factory, element pool, or virtualization."
);
contrastPanel:SetPoint("TOPLEFT", comparisonFrame, "CENTER", 6, -4);
contrastPanel:SetPoint("BOTTOMRIGHT", -24, 32);

-- Fixed linear list ---------------------------------------------------------

local fixedStatus = CreateText(fixedPanel, "GameFontHighlightSmall", "");
fixedStatus:SetPoint("TOPLEFT", 12, -50);
fixedStatus:SetPoint("RIGHT", fixedPanel, "RIGHT", -12, 0);
fixedStatus:SetJustifyH("LEFT");

local fixedScrollBox = CreateFrame("Frame", nil, fixedPanel, "WowScrollBoxList");
fixedScrollBox:SetPoint("TOPLEFT", 12, -70);
fixedScrollBox:SetPoint("BOTTOMRIGHT", -34, 72);

local fixedScrollBar = CreateFrame("EventFrame", nil, fixedPanel, "MinimalScrollBar");
fixedScrollBar:SetPoint("TOPLEFT", fixedScrollBox, "TOPRIGHT", 7, -2);
fixedScrollBar:SetPoint("BOTTOMLEFT", fixedScrollBox, "BOTTOMRIGHT", 7, 2);
fixedScrollBar:SetHideIfUnscrollable(true);

local fixedDataProvider;
local fixedSelectionBehavior;
local fixedSelectedID;
local fixedFrameIdentity = 0;
local fixedSortDescending = false;
local compactReplacement = false;
local nextFixedID = 41;

local function CreateFixedElement(id)
	return {
		id = id,
		label = string.format("Research Row %02d", id),
		status = id % 4 == 0 and "disabled" or (id % 3 == 0 and "alternate" or "normal"),
		disabled = id % 4 == 0,
	};
end

local function CreateFixedElements(firstID, count)
	local elements = {};
	for offset = 0, count - 1 do
		table.insert(elements, CreateFixedElement(firstID + offset));
	end
	return elements;
end

local function ApplyFixedVisual(row, elementData)
	local selected = fixedSelectionBehavior and fixedSelectionBehavior:IsElementDataSelected(elementData);
	local emphasized = elementData.id % 5 == 0;

	row.IDText:SetText(string.format("#%02d", elementData.id));
	row.LabelText:SetText(elementData.label);
	row.StatusText:SetText(elementData.status);
	row.Icon:SetShown(elementData.id % 3 == 0);
	row.Icon:SetColorTexture(0.25, 0.65, 1, 0.9);
	row.Selected:SetShown(selected);
	row.Emphasis:SetShown(emphasized and not selected);
	row:SetEnabled(not elementData.disabled);
	row:SetAlpha(elementData.disabled and 0.48 or 1);
end

local function InitializeFixedRow(row, elementData)
	if not row.sampleCreated then
		row.sampleCreated = true;
		row:RegisterForClicks("LeftButtonUp");

		row.Base = row:CreateTexture(nil, "BACKGROUND");
		row.Base:SetAllPoints();
		row.Base:SetColorTexture(0.055, 0.055, 0.07, 0.96);

		row.Emphasis = row:CreateTexture(nil, "BORDER");
		row.Emphasis:SetAllPoints();
		row.Emphasis:SetColorTexture(0.16, 0.12, 0.04, 0.75);

		row.Selected = row:CreateTexture(nil, "BORDER");
		row.Selected:SetAllPoints();
		row.Selected:SetColorTexture(0.15, 0.42, 0.68, 0.72);

		row.Icon = row:CreateTexture(nil, "ARTWORK");
		row.Icon:SetSize(12, 12);
		row.Icon:SetPoint("LEFT", 6, 0);

		row.IDText = CreateText(row, "GameFontNormalSmall", "");
		row.IDText:SetPoint("LEFT", 23, 0);
		row.IDText:SetWidth(40);
		row.IDText:SetJustifyH("LEFT");

		row.LabelText = CreateText(row, "GameFontHighlightSmall", "");
		row.LabelText:SetPoint("LEFT", row.IDText, "RIGHT", 3, 0);
		row.LabelText:SetWidth(170);
		row.LabelText:SetJustifyH("LEFT");

		row.StatusText = CreateText(row, "GameFontDisableSmall", "");
		row.StatusText:SetPoint("RIGHT", -6, 0);
		row.StatusText:SetWidth(72);
		row.StatusText:SetJustifyH("RIGHT");

		row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD");
		row:SetScript("OnClick", function(button)
			local data = button:GetElementData();
			if data and not data.disabled then
				fixedSelectionBehavior:SelectElementData(data);
			end
		end);
	end

	local previousID = row.samplePreviousElementID;
	row.samplePreviousElementID = elementData.id;
	ApplyFixedVisual(row, elementData);
	RecordEvent(string.format(
		"fixed init frame %d: %s -> row %d",
		row.sampleFrameID or 0,
		previousID and tostring(previousID) or "none",
		elementData.id
	), false);
end

local fixedView = CreateScrollBoxListLinearView(0, 0, 0, 0, 2);
fixedView:SetElementExtent(26);
fixedView:SetElementInitializer("Button", InitializeFixedRow);
fixedView:SetElementResetter(function(row, oldElementData)
	RecordEvent(string.format(
		"fixed reset frame %d from row %d",
		row.sampleFrameID or 0,
		oldElementData.id
	), false);
	row.IDText:SetText("");
	row.LabelText:SetText("");
	row.StatusText:SetText("");
	row.Icon:Hide();
	row.Selected:Hide();
	row.Emphasis:Hide();
	row:SetEnabled(true);
	row:SetAlpha(1);
	row.samplePreviousElementID = oldElementData.id;
end);

ScrollUtil.InitScrollBoxListWithScrollBar(fixedScrollBox, fixedScrollBar, fixedView);
fixedSelectionBehavior = ScrollUtil.AddSelectionBehavior(fixedScrollBox);

local function UpdateFixedStatus()
	local firstIndex = fixedScrollBox:GetDataIndexBegin();
	local lastIndex = fixedScrollBox:GetDataIndexEnd();
	fixedStatus:SetText(string.format(
		"Rows: %d   Visible Frames: %d   Range: %s-%s   Scroll: %d%%   Selected: %s",
		fixedDataProvider and fixedDataProvider:GetSize() or 0,
		fixedScrollBox:GetFrameCount(),
		firstIndex and tostring(firstIndex) or "-",
		lastIndex and tostring(lastIndex) or "-",
		math.floor((fixedScrollBox:GetScrollPercentage() * 100) + 0.5),
		fixedSelectedID and tostring(fixedSelectedID) or "none"
	));
end

ScrollUtil.AddAcquiredFrameCallback(fixedScrollBox, function(_, row, elementData, new)
	if new or not row.sampleFrameID then
		fixedFrameIdentity = fixedFrameIdentity + 1;
		row.sampleFrameID = fixedFrameIdentity;
	end
	RecordEvent(string.format(
		"fixed acquire frame %d for row %d (%s)",
		row.sampleFrameID,
		elementData.id,
		new and "new" or "pooled"
	), false);
end, comparisonFrame);

ScrollUtil.AddInitializedFrameCallback(fixedScrollBox, function(_, row, elementData)
	RecordEvent(string.format(
		"fixed initialized frame %d for row %d",
		row.sampleFrameID or 0,
		elementData.id
	), false);
end, comparisonFrame);

ScrollUtil.AddReleasedFrameCallback(fixedScrollBox, function(_, row, elementData)
	RecordEvent(string.format(
		"fixed released frame %d from row %d",
		row.sampleFrameID or 0,
		elementData.id
	), false);
end, comparisonFrame);

fixedSelectionBehavior:RegisterCallback(
	SelectionBehaviorMixin.Event.OnSelectionChanged,
	function(_, elementData, selected)
		if selected then
			fixedSelectedID = elementData.id;
		elseif fixedSelectedID == elementData.id then
			fixedSelectedID = nil;
		end

		local row = fixedScrollBox:FindFrame(elementData);
		if row then
			ApplyFixedVisual(row, elementData);
		end
		UpdateFixedStatus();
		RecordEvent(string.format(
			"selection row %d -> %s",
			elementData.id,
			selected and "selected" or "deselected"
		), selected);
	end,
	comparisonFrame
);

fixedScrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, function()
	UpdateFixedStatus();
end, comparisonFrame);
fixedScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, function()
	UpdateFixedStatus();
end, comparisonFrame);

local function SetFixedProvider(elements, operation)
	fixedDataProvider = CreateDataProvider(elements);
	fixedSelectedID = nil;
	fixedSortDescending = false;
	fixedScrollBox:SetDataProvider(fixedDataProvider);
	UpdateFixedStatus();
	RecordEvent(operation, true);
end

local fixedButtons = {};
fixedButtons[1] = CreateActionButton(fixedPanel, "Add Row", 108, function()
	fixedDataProvider:Insert(CreateFixedElement(nextFixedID));
	RecordEvent("fixed provider inserted row " .. nextFixedID, true);
	nextFixedID = nextFixedID + 1;
	UpdateFixedStatus();
end);
fixedButtons[2] = CreateActionButton(fixedPanel, "Remove Last", 108, function()
	local size = fixedDataProvider:GetSize();
	if size > 0 then
		local removed = fixedDataProvider:Find(size);
		if fixedSelectionBehavior:IsElementDataSelected(removed) then
			fixedSelectionBehavior:DeselectElementData(removed);
		end
		fixedDataProvider:RemoveIndex(size);
		RecordEvent("fixed provider removed row " .. removed.id, true);
		UpdateFixedStatus();
	end
end);
fixedButtons[3] = CreateActionButton(fixedPanel, "Replace Data", 108, function()
	compactReplacement = not compactReplacement;
	if compactReplacement then
		SetFixedProvider(CreateFixedElements(201, 4), "fixed provider replaced with 4 fitting rows");
	else
		SetFixedProvider(CreateFixedElements(1, 40), "fixed provider replaced with 40 rows");
	end
end);
fixedButtons[4] = CreateActionButton(fixedPanel, "Reverse Sort", 108, function()
	fixedSortDescending = not fixedSortDescending;
	fixedDataProvider:SetSortComparator(function(left, right)
		if fixedSortDescending then
			return left.id > right.id;
		end
		return left.id < right.id;
	end);
	RecordEvent("fixed provider sorted " .. (fixedSortDescending and "descending" or "ascending"), true);
	UpdateFixedStatus();
end);
fixedButtons[5] = CreateActionButton(fixedPanel, "Scroll Begin", 108, function()
	fixedScrollBox:ScrollToBegin(ScrollBoxConstants.NoScrollInterpolation);
	RecordEvent("fixed list scrolled to begin", true);
end);
fixedButtons[6] = CreateActionButton(fixedPanel, "Scroll End", 108, function()
	fixedScrollBox:ScrollToEnd(ScrollBoxConstants.NoScrollInterpolation);
	RecordEvent("fixed list scrolled to end", true);
end);
fixedButtons[7] = CreateActionButton(fixedPanel, "Scroll Row 17", 108, function()
	local targetIndex = math.min(17, fixedDataProvider:GetSize());
	if targetIndex > 0 then
		fixedScrollBox:ScrollToElementDataIndex(
			targetIndex,
			ScrollBoxConstants.AlignCenter,
			0,
			ScrollBoxConstants.NoScrollInterpolation
		);
		RecordEvent("fixed list scrolled to provider index " .. targetIndex, true);
	end
end);
fixedButtons[8] = CreateActionButton(fixedPanel, "Reinitialize", 108, function()
	fixedScrollBox:ReinitializeFrames();
	RecordEvent("fixed visible frames reinitialized", true);
end);

for index, button in ipairs(fixedButtons) do
	local column = (index - 1) % 4;
	local row = math.floor((index - 1) / 4);
	button:SetPoint("BOTTOMLEFT", 12 + (column * 116), 40 - (row * 28));
end

SetFixedProvider(CreateFixedElements(1, 40), "fixed provider initialized with 40 rows");

-- Variable extent list -----------------------------------------------------

local variableStatus = CreateText(variablePanel, "GameFontHighlightSmall", "");
variableStatus:SetPoint("TOPLEFT", 12, -50);
variableStatus:SetPoint("RIGHT", variablePanel, "RIGHT", -12, 0);
variableStatus:SetJustifyH("LEFT");

local variableScrollBox = CreateFrame("Frame", nil, variablePanel, "WowScrollBoxList");
variableScrollBox:SetPoint("TOPLEFT", 12, -70);
variableScrollBox:SetPoint("BOTTOMRIGHT", -34, 48);

local variableScrollBar = CreateFrame("EventFrame", nil, variablePanel, "MinimalScrollBar");
variableScrollBar:SetPoint("TOPLEFT", variableScrollBox, "TOPRIGHT", 7, -2);
variableScrollBar:SetPoint("BOTTOMLEFT", variableScrollBox, "BOTTOMRIGHT", 7, 2);
variableScrollBar:SetHideIfUnscrollable(true);

local variableElements = {};
local variableExtents = {28, 44, 64};
for index = 1, 15 do
	local extent = variableExtents[((index - 1) % #variableExtents) + 1];
	table.insert(variableElements, {
		id = index,
		extent = extent,
		text = extent == 64
			and string.format("Mixed row %d\nTwo-line diagnostic content (%dpx)", index, extent)
			or string.format("Mixed row %d — %dpx", index, extent),
	});
end

local variableDataProvider = CreateDataProvider(variableElements);

local function InitializeVariableRow(row, elementData)
	if not row.sampleCreated then
		row.sampleCreated = true;
		row.Background = row:CreateTexture(nil, "BACKGROUND");
		row.Background:SetAllPoints();
		row.Text = CreateText(row, "GameFontHighlightSmall", "");
		row.Text:SetPoint("TOPLEFT", 8, -5);
		row.Text:SetPoint("BOTTOMRIGHT", -8, 5);
		row.Text:SetJustifyH("LEFT");
		row.Text:SetJustifyV("TOP");
		row.Text:SetWordWrap(true);
	end
	row.Background:SetColorTexture(
		elementData.extent == 64 and 0.09 or 0.05,
		0.06,
		elementData.extent == 28 and 0.10 or 0.14,
		0.96
	);
	row.Text:SetText(elementData.text);
end

local variableView = CreateScrollBoxListLinearView(0, 0, 0, 0, 3);
variableView:SetElementExtentCalculator(function(_, elementData)
	return elementData.extent;
end);
variableView:SetElementInitializer("Button", InitializeVariableRow);
variableView:SetElementResetter(function(row)
	row.Text:SetText("");
	row.Background:SetColorTexture(0, 0, 0, 0);
end);
ScrollUtil.InitScrollBoxListWithScrollBar(variableScrollBox, variableScrollBar, variableView);
variableScrollBox:SetDataProvider(variableDataProvider);

local function UpdateVariableStatus()
	variableStatus:SetText(string.format(
		"Rows: %d   Visible Frames: %d   Scroll: %d%%   Row 3: %dpx",
		variableDataProvider:GetSize(),
		variableScrollBox:GetFrameCount(),
		math.floor((variableScrollBox:GetScrollPercentage() * 100) + 0.5),
		variableDataProvider:Find(3).extent
	));
end

variableScrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, function()
	UpdateVariableStatus();
end, comparisonFrame);
variableScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, function()
	UpdateVariableStatus();
end, comparisonFrame);

local toggleVariableButton = CreateActionButton(variablePanel, "Toggle Row 3 Height + Rebuild", 230, function()
	local elementData = variableDataProvider:Find(3);
	local expanded = elementData.extent ~= 82;
	elementData.extent = expanded and 82 or 64;
	elementData.text = expanded
		and "Mixed row 3 expanded\nThe extent calculator now returns 82px.\nRebuild retains the requested scroll position."
		or "Mixed row 3\nTwo-line diagnostic content (64px)";
	variableScrollBox:Rebuild(ScrollBoxConstants.RetainScrollPosition);
	UpdateVariableStatus();
	RecordEvent("variable row 3 changed to " .. elementData.extent .. "px; list rebuilt", true);
end);
toggleVariableButton:SetPoint("BOTTOMLEFT", 12, 14);
UpdateVariableStatus();

-- Fixed grid ---------------------------------------------------------------

local gridStatus = CreateText(gridPanel, "GameFontHighlightSmall", "");
gridStatus:SetPoint("TOPLEFT", 12, -50);
gridStatus:SetPoint("RIGHT", gridPanel, "RIGHT", -12, 0);
gridStatus:SetJustifyH("LEFT");

local gridScrollBox = CreateFrame("Frame", nil, gridPanel, "WowScrollBoxList");
gridScrollBox:SetPoint("TOPLEFT", 12, -70);
gridScrollBox:SetPoint("BOTTOMRIGHT", -34, 14);

local gridScrollBar = CreateFrame("EventFrame", nil, gridPanel, "MinimalScrollBar");
gridScrollBar:SetPoint("TOPLEFT", gridScrollBox, "TOPRIGHT", 7, -2);
gridScrollBar:SetPoint("BOTTOMLEFT", gridScrollBox, "BOTTOMRIGHT", 7, 2);
gridScrollBar:SetHideIfUnscrollable(true);

local gridElements = {};
for index = 1, 31 do
	table.insert(gridElements, {id = index});
end
local gridDataProvider = CreateDataProvider(gridElements);

local function InitializeGridTile(tile, elementData)
	if not tile.sampleCreated then
		tile.sampleCreated = true;
		tile.Background = tile:CreateTexture(nil, "BACKGROUND");
		tile.Background:SetAllPoints();
		tile.Number = CreateText(tile, "GameFontNormalLarge", "");
		tile.Number:SetPoint("CENTER", 0, 4);
		tile.Detail = CreateText(tile, "GameFontDisableSmall", "");
		tile.Detail:SetPoint("BOTTOM", 0, 4);
	end
	local channel = ((elementData.id - 1) % 4) / 10;
	tile.Background:SetColorTexture(0.08 + channel, 0.12, 0.22 - (channel / 2), 0.96);
	tile.Number:SetText(elementData.id);
	tile.Detail:SetText("tile");
end

local gridView = CreateScrollBoxListGridView(4, 0, 0, 0, 0, 5, 5);
gridView:SetElementSize(82, 54);
gridView:SetElementInitializer("Button", InitializeGridTile);
gridView:SetElementResetter(function(tile)
	tile.Number:SetText("");
	tile.Detail:SetText("");
	tile.Background:SetColorTexture(0, 0, 0, 0);
end);
ScrollUtil.InitScrollBoxListWithScrollBar(gridScrollBox, gridScrollBar, gridView);
gridScrollBox:SetDataProvider(gridDataProvider);

local function UpdateGridStatus()
	gridStatus:SetText(string.format(
		"Items: %d   Visible Frames: %d   Columns: 4 (configured stride)   Scroll: %d%%",
		gridDataProvider:GetSize(),
		gridScrollBox:GetFrameCount(),
		math.floor((gridScrollBox:GetScrollPercentage() * 100) + 0.5)
	));
end

gridScrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, function()
	UpdateGridStatus();
end, comparisonFrame);
gridScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnDataRangeChanged, function()
	UpdateGridStatus();
end, comparisonFrame);
UpdateGridStatus();

-- ScrollFrame contrast and shared diagnostics -----------------------------

local contrastScrollFrame = CreateFrame("ScrollFrame", nil, contrastPanel, "ScrollFrameTemplate");
contrastScrollFrame:SetPoint("TOPLEFT", 12, -66);
contrastScrollFrame:SetPoint("TOPRIGHT", -34, -66);
contrastScrollFrame:SetHeight(132);
contrastScrollFrame.ScrollBar:SetHideIfUnscrollable(true);

local contrastContent = CreateFrame("Frame", nil, contrastScrollFrame);
contrastContent:SetSize(500, 300);
contrastScrollFrame:SetScrollChild(contrastContent);

local contrastLines = {
	"One continuous addon-owned child",
	"• every line exists at once",
	"• caller owns child height and layout",
	"• no data provider or row identity",
	"• no pooled acquisition/release lifecycle",
	"• current ScrollFrameTemplate supplies a MinimalScrollBar",
	"",
	"This remains sensible for a dynamic configuration page, help text, or another single composed surface.",
};

local previousLine;
for _, text in ipairs(contrastLines) do
	local line = CreateText(contrastContent, "GameFontHighlightSmall", text);
	line:SetPoint("LEFT", 8, 0);
	line:SetPoint("RIGHT", -8, 0);
	line:SetJustifyH("LEFT");
	line:SetWordWrap(true);
	if previousLine then
		line:SetPoint("TOP", previousLine, "BOTTOM", 0, -8);
	else
		line:SetPoint("TOP", 0, -8);
	end
	previousLine = line;
end

contrastScrollFrame:SetScript("OnSizeChanged", function(_, width)
	contrastContent:SetWidth(math.max(1, width - 4));
end);

local logLabel = CreateText(
	contrastPanel,
	"GameFontNormalSmall",
	"Latest numbered diagnostics"
);
logLabel:SetPoint("TOPLEFT", 12, -212);

local logHint = CreateText(contrastPanel, "GameFontDisableSmall", "Click text, Ctrl+A, Ctrl+C to copy");
logHint:SetPoint("LEFT", logLabel, "RIGHT", 10, 0);

eventLogDisplay = CreateFrame("Frame", nil, contrastPanel, "ScrollingEditBoxTemplate");
eventLogDisplay:SetPoint("TOPLEFT", logLabel, "BOTTOMLEFT", 0, -6);
eventLogDisplay:SetPoint("BOTTOMRIGHT", contrastPanel, "BOTTOMRIGHT", -12, 35);
eventLogDisplay:SetFontObject("GameFontDisableSmall");
eventLogDisplay:SetTextInsets(6, 6, 6, 6);

local eventLogBackground = eventLogDisplay:CreateTexture(nil, "BACKGROUND");
eventLogBackground:SetAllPoints();
eventLogBackground:SetColorTexture(0.015, 0.015, 0.022, 0.9);
AddEdge(eventLogDisplay, "TOPLEFT", "TOPRIGHT", nil, 1);
AddEdge(eventLogDisplay, "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1);
AddEdge(eventLogDisplay, "TOPLEFT", "BOTTOMLEFT", 1, nil);
AddEdge(eventLogDisplay, "TOPRIGHT", "BOTTOMRIGHT", 1, nil);

local eventLogEditBox = eventLogDisplay:GetEditBox();
eventLogEditBox:SetAutoFocus(false);
eventLogEditBox:SetMultiLine(true);
eventLogDisplay:RegisterCallback("OnTextChanged", function(_, _, isUserInput)
	if isUserInput and not restoringEventLogText then
		RefreshEventLog();
	end
end, comparisonFrame);
eventLogDisplay:RegisterCallback("OnKeyDown", function(_, editBox, key)
	if key == "A" and IsControlKeyDown() then
		editBox:HighlightText();
	end
end, comparisonFrame);
RefreshEventLog();

local resizeHint = CreateText(
	contrastPanel,
	"GameFontDisableSmall",
	"Drag the bottom-right Resize button out of combat; dimensions are not persisted."
);
resizeHint:SetPoint("BOTTOMLEFT", 12, 12);

local resizeHandle = CreateActionButton(comparisonFrame, "Resize", 62, function() end);
resizeHandle:SetPoint("BOTTOMRIGHT", -8, 7);
resizeHandle:RegisterForClicks("LeftButtonUp");
resizeHandle:SetScript("OnMouseDown", function(_, mouseButton)
	if mouseButton ~= "LeftButton" then
		return;
	end
	if InCombatLockdown() then
		RecordEvent("resizing is intentionally disabled during combat", true);
		return;
	end
	comparisonFrame:StartSizing("BOTTOMRIGHT");
end);
resizeHandle:SetScript("OnMouseUp", function(_, mouseButton)
	if mouseButton == "LeftButton" then
		comparisonFrame:StopMovingOrSizing();
		RecordEvent(string.format(
			"resize finished at %dx%d",
			math.floor(comparisonFrame:GetWidth() + 0.5),
			math.floor(comparisonFrame:GetHeight() + 0.5)
		), true);
	end
end);

comparisonFrame:SetScript("OnSizeChanged", function()
	UpdateFixedStatus();
	UpdateVariableStatus();
	UpdateGridStatus();
end);

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
		RecordEvent("entered combat; isolated non-secure controls remain available for testing", true);
	elseif event == "PLAYER_REGEN_ENABLED" then
		UpdateCombatState(false);
		RecordEvent("left combat", true);
	end
end);
UpdateCombatState(InCombatLockdown());

comparisonFrame:SetScript("OnShow", function()
	UpdateFixedStatus();
	UpdateVariableStatus();
	UpdateGridStatus();
	RecordEvent("sample opened", true);
end);

RetailUIResearch:RegisterSample({
	id = "scrollbox",
	name = "ScrollBox",
	frame = comparisonFrame,
});

SLASH_SCROLLBOXCOMPARISON1 = "/scrollboxcomparison";
SLASH_SCROLLBOXCOMPARISON2 = "/sbc";
SlashCmdList.SCROLLBOXCOMPARISON = function()
	RetailUIResearch:ToggleSample("scrollbox");
end;

RecordEvent("module loaded; use /scrollboxcomparison or /sbc", false);
