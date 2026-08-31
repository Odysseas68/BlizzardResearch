-- luacheck: globals CreateFrame UIParent SlashCmdList SLASH_RETAILUIRESEARCH1

local ADDON_NAME, RetailUIResearch = ...;

local function CreateText(parent, fontObject, text)
	local fontString = parent:CreateFontString(nil, "ARTWORK", fontObject);
	fontString:SetText(text);
	return fontString;
end

local launcherFrame = CreateFrame("Frame", "RetailUIResearchLauncherFrame", UIParent);
launcherFrame:Hide();
launcherFrame:SetSize(730, 150);
launcherFrame:SetPoint("CENTER", 0, 310);
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
	"Unofficial third-party Retail LIVE research harness. Open one independently owned sample."
);
subtitle:SetPoint("TOP", 0, -48);

local sampleButtons = {
	{id = "sliders", label = "Sliders"},
	{id = "buttons-frames", label = "Buttons & Frames"},
	{id = "dropdowns-menus", label = "Dropdowns & Menus"},
	{id = "checkboxes-radios", label = "Checkboxes & Radios"},
	{id = "editboxes", label = "EditBoxes"},
};

for index, buttonInfo in ipairs(sampleButtons) do
	local button = CreateFrame("Button", nil, launcherFrame, "UIPanelButtonTemplate");
	button:SetSize(130, 26);
	button:SetPoint("TOPLEFT", 20 + ((index - 1) * 140), -82);
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

launcherFrame:RegisterEvent("PLAYER_LOGIN");
launcherFrame:SetScript("OnEvent", function(self, event)
	self:UnregisterEvent(event);
	self:Show();
end);

SLASH_RETAILUIRESEARCH1 = "/retailuiresearch";
SlashCmdList.RETAILUIRESEARCH = function()
	launcherFrame:SetShown(not launcherFrame:IsShown());
end;
