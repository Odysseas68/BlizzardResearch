-- luacheck: globals CreateFrame UIParent SlashCmdList SLASH_RETAILUIRESEARCH1

local ADDON_NAME, RetailUIResearch = ...;

local LAUNCHER_WIDTH = 280;
local BUTTON_WIDTH = 220;
local BUTTON_HEIGHT = 26;
local BUTTON_SPACING = 8;
local BUTTON_TOP = 82;
local FOOTER_HEIGHT = 48;

local function CreateText(parent, fontObject, text)
	local fontString = parent:CreateFontString(nil, "ARTWORK", fontObject);
	fontString:SetText(text);
	return fontString;
end

local launcherFrame = CreateFrame("Frame", "RetailUIResearchLauncherFrame", UIParent);
launcherFrame:Hide();
launcherFrame:SetFrameStrata("DIALOG");
launcherFrame:SetClampedToScreen(true);
launcherFrame:SetMovable(true);

CreateFrame("Frame", nil, launcherFrame, "DialogBorderDarkTemplate");
local header = CreateFrame("Frame", nil, launcherFrame, "DialogHeaderTemplate");
header:Setup("Retail UI Research");
header:EnableMouse(true);
header:RegisterForDrag("LeftButton");
header:SetScript("OnDragStart", function()
	launcherFrame:StartMoving();
end);
header:SetScript("OnDragStop", function()
	launcherFrame:StopMovingOrSizing();
end);
CreateFrame("Button", nil, launcherFrame, "UIPanelCloseButtonDefaultAnchors");

local subtitle = CreateText(
	launcherFrame,
	"GameFontHighlightSmall",
	"Retail LIVE research harness. Open one independently owned sample."
);
subtitle:SetPoint("TOP", 0, -48);
subtitle:SetWidth(LAUNCHER_WIDTH - 32);
subtitle:SetJustifyH("CENTER");

local sampleButtons = {
	{id = "sliders", label = "Sliders"},
	{id = "buttons-frames", label = "Buttons & Frames"},
	{id = "dropdowns-menus", label = "Dropdowns & Menus"},
	{id = "checkboxes-radios", label = "Checkboxes & Radios"},
	{id = "editboxes", label = "EditBoxes"},
	{id = "scrollbox", label = "ScrollBox"},
	{id = "color-picker", label = "Color Picker"},
	{id = "dialogs-popups", label = "Dialogs / Popups"},
};

local launcherHeight = BUTTON_TOP
	+ (#sampleButtons * BUTTON_HEIGHT)
	+ ((#sampleButtons - 1) * BUTTON_SPACING)
	+ FOOTER_HEIGHT;
launcherFrame:SetSize(LAUNCHER_WIDTH, launcherHeight);
launcherFrame:SetPoint("CENTER", 0, 250);

for index, buttonInfo in ipairs(sampleButtons) do
	local button = CreateFrame("Button", nil, launcherFrame, "UIPanelButtonTemplate");
	button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT);
	button:SetPoint("TOP", 0, -BUTTON_TOP - ((index - 1) * (BUTTON_HEIGHT + BUTTON_SPACING)));
	button:SetText(buttonInfo.label);
	button:SetScript("OnClick", function()
		if not RetailUIResearch:OpenSample(buttonInfo.id) then
			print(string.format("%s: sample is unavailable: %s", ADDON_NAME, buttonInfo.label));
		end
	end);
end

local hint = CreateText(
	launcherFrame,
	"GameFontDisableSmall",
	"The launcher remains open; selecting another sample hides the previously selected sample."
);
hint:SetPoint("BOTTOM", 0, 18);
hint:SetWidth(LAUNCHER_WIDTH - 32);
hint:SetJustifyH("CENTER");

launcherFrame:RegisterEvent("PLAYER_LOGIN");
launcherFrame:SetScript("OnEvent", function(self, event)
	self:UnregisterEvent(event);
	self:Show();
end);

SLASH_RETAILUIRESEARCH1 = "/retailuiresearch";
SlashCmdList.RETAILUIRESEARCH = function()
	launcherFrame:SetShown(not launcherFrame:IsShown());
end;
