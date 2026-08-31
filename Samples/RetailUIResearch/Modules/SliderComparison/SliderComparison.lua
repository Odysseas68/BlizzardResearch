-- luacheck: globals CreateFrame UIParent MinimalSliderWithSteppersMixin SlashCmdList
-- luacheck: globals SLASH_SLIDERCOMPARISON1 SLASH_SLIDERCOMPARISON2

local _, RetailUIResearch = ...;
local ADDON_NAME = "SliderComparison";

local MIN_VALUE = 0;
local MAX_VALUE = 100;
local INITIAL_VALUE = 50;
local VALUE_STEP = 5;
local STEP_COUNT = (MAX_VALUE - MIN_VALUE) / VALUE_STEP;

local function FormatValue(value)
	return string.format("Value: %d", value);
end

local function CreateText(parent, fontObject, text)
	local fontString = parent:CreateFontString(nil, "ARTWORK", fontObject);
	fontString:SetText(text);
	return fontString;
end

local function CreateBorder(frame)
	local background = frame:CreateTexture(nil, "BACKGROUND");
	background:SetAllPoints();
	background:SetColorTexture(0.035, 0.035, 0.045, 0.96);

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

local comparisonFrame = CreateFrame("Frame", "SliderComparisonFrame", UIParent);
comparisonFrame:Hide();
comparisonFrame:SetSize(760, 500);
comparisonFrame:SetPoint("CENTER");
comparisonFrame:SetFrameStrata("DIALOG");
comparisonFrame:SetClampedToScreen(true);
comparisonFrame:SetMovable(true);
comparisonFrame:EnableMouse(true);
comparisonFrame:RegisterForDrag("LeftButton");
comparisonFrame:SetScript("OnDragStart", comparisonFrame.StartMoving);
comparisonFrame:SetScript("OnDragStop", comparisonFrame.StopMovingOrSizing);
CreateBorder(comparisonFrame);

local title = CreateText(comparisonFrame, "GameFontNormalLarge", "Retail 12.1 Slider Comparison");
title:SetPoint("TOPLEFT", 20, -18);

local subtitle = CreateText(
	comparisonFrame,
	"GameFontHighlightSmall",
	"Range 0-100, initial 50, step 5. Drag this frame by its background."
);
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5);

local closeButton = CreateFrame("Button", nil, comparisonFrame, "UIPanelCloseButton");
closeButton:SetPoint("TOPRIGHT", -3, -3);
closeButton:SetScript("OnClick", function()
	comparisonFrame:Hide();
end);

local ROW_TOP = -80;
local ROW_HEIGHT = 78;

local function CreateRow(index, labelText, detailText)
	local row = CreateFrame("Frame", nil, comparisonFrame);
	row:SetPoint("TOPLEFT", 20, ROW_TOP - ((index - 1) * ROW_HEIGHT));
	row:SetPoint("RIGHT", comparisonFrame, "RIGHT", -20, 0);
	row:SetHeight(68);

	local label = CreateText(row, "GameFontNormal", labelText);
	label:SetPoint("TOPLEFT", 0, 0);

	local detail = CreateText(row, "GameFontDisableSmall", detailText);
	detail:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3);
	detail:SetWidth(210);
	detail:SetJustifyH("LEFT");

	local valueText = CreateText(row, "GameFontHighlight", FormatValue(INITIAL_VALUE));
	valueText:SetPoint("RIGHT", row, "RIGHT", 0, -8);

	return row, valueText;
end

local function SetButtonEnabled(button, enabled)
	button:SetEnabled(enabled);
end

do
	local row, valueText = CreateRow(
		1,
		"Ordinary baseline",
		"UISliderTemplate with addon-owned literal < and > buttons"
	);

	local slider = CreateFrame("Slider", nil, row, "UISliderTemplate");
	slider:SetSize(230, 20);
	slider:SetPoint("LEFT", row, "LEFT", 275, -8);
	slider:SetMinMaxValues(MIN_VALUE, MAX_VALUE);
	slider:SetValueStep(VALUE_STEP);
	slider:SetObeyStepOnDrag(true);

	local decrement = CreateFrame("Button", nil, row, "UIPanelButtonTemplate");
	decrement:SetSize(24, 22);
	decrement:SetPoint("RIGHT", slider, "LEFT", -6, 0);
	decrement:SetText("<");

	local increment = CreateFrame("Button", nil, row, "UIPanelButtonTemplate");
	increment:SetSize(24, 22);
	increment:SetPoint("LEFT", slider, "RIGHT", 6, 0);
	increment:SetText(">");

	local function Update(value)
		valueText:SetText(FormatValue(value));
		SetButtonEnabled(decrement, value > MIN_VALUE);
		SetButtonEnabled(increment, value < MAX_VALUE);
	end

	slider:SetScript("OnValueChanged", function(_, value)
		Update(value);
	end);
	decrement:SetScript("OnClick", function()
		slider:SetValue(slider:GetValue() - VALUE_STEP);
	end);
	increment:SetScript("OnClick", function()
		slider:SetValue(slider:GetValue() + VALUE_STEP);
	end);
	slider:SetValue(INITIAL_VALUE);
	Update(INITIAL_VALUE);
end

do
	local row, valueText = CreateRow(2, "Minimal bar", "MinimalSliderTemplate; no built-in steppers");

	local slider = CreateFrame("Slider", nil, row, "MinimalSliderTemplate");
	slider:SetSize(300, 19);
	slider:SetPoint("LEFT", row, "LEFT", 250, -8);
	slider:SetMinMaxValues(MIN_VALUE, MAX_VALUE);
	slider:SetValueStep(VALUE_STEP);
	slider:SetScript("OnValueChanged", function(_, value)
		valueText:SetText(FormatValue(value));
	end);
	slider:SetValue(INITIAL_VALUE);
end

do
	local row, valueText = CreateRow(
		3,
		"Minimal native steppers",
		"MinimalSliderWithSteppersTemplate; Settings' underlying shared control"
	);

	local control = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate");
	control:SetSize(330, 40);
	control:SetPoint("LEFT", row, "LEFT", 235, -8);
	control:Init(INITIAL_VALUE, MIN_VALUE, MAX_VALUE, STEP_COUNT, nil);
	control:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		valueText:SetText(FormatValue(value));
	end);
end

do
	local row, valueText = CreateRow(
		4,
		"SharedXML arrow composite",
		"SliderWithButtonsAndLabelTemplate; full button art states"
	);

	local control = CreateFrame("Frame", nil, row, "SliderWithButtonsAndLabelTemplate");
	control:SetSize(340, 40);
	control:SetPoint("LEFT", row, "LEFT", 225, -8);
	control:SetupSlider(MIN_VALUE, MAX_VALUE, INITIAL_VALUE, VALUE_STEP, "");
	control.Slider:HookScript("OnValueChanged", function(_, value)
		valueText:SetText(FormatValue(value));
	end);
end

do
	local row, valueText = CreateRow(
		5,
		"Slider plus exact entry",
		"SliderAndEditControlTemplate; numeric entry instead of steppers"
	);

	local control = CreateFrame("Frame", nil, row, "SliderAndEditControlTemplate");
	control:SetSize(210, 48);
	control:SetPoint("LEFT", row, "LEFT", 290, -7);
	control:SetupSlider(MIN_VALUE, MAX_VALUE, INITIAL_VALUE, VALUE_STEP, "Exact entry");
	control:SetCallback(function(value)
		valueText:SetText(FormatValue(value));
	end);
end

local footer = CreateText(
	comparisonFrame,
	"GameFontDisableSmall",
	"Runtime verified on Retail LIVE 12.1.0.69497. Use /slidercomparison to toggle."
);
footer:SetPoint("BOTTOMLEFT", 20, 16);

RetailUIResearch:RegisterSample({
	id = "sliders",
	name = "Sliders",
	frame = comparisonFrame,
});

SLASH_SLIDERCOMPARISON1 = "/slidercomparison";
SLASH_SLIDERCOMPARISON2 = "/sliders";
SlashCmdList.SLIDERCOMPARISON = function()
	RetailUIResearch:ToggleSample("sliders");
end;

print(string.format("%s loaded. Use /slidercomparison to toggle the comparison frame.", ADDON_NAME));
