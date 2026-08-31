# Retail Checkboxes and Radio Buttons — WoW 12.1.0

## 1. Scope and source baseline

This is a LIVE-first source investigation of standalone checkbox and radio-choice controls available to normal third-party Retail addons. It does not treat `Blizzard_Menu` checkbox/radio descriptions as standalone frames, does not modify a production addon or Blizzard source, and does not create a runtime sample.

- BlizzardResearch baseline: `ad00af647098ef61e59e5f5caa8dea2690909291`
- Retail client/source baseline: `12.1.0.69497`
- LIVE source: `D:\WowDEV\Reference\Blizzard\wow-ui-source`
- LIVE branch and commit: `live`, `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
- LIVE commit description/date: `12.1.0 (69497)`, 2026-08-25
- PTR consulted: no. LIVE exposed no concrete compatibility question that required PTR evidence.
- Research date: 2026-08-31

Source paths below are relative to the LIVE source root unless stated otherwise. Current Mainline code is primary; Classic-family files are not used to establish the recommendations.

## 2. Executive summary

### VERIFIED SOURCE FACTS

- Standalone checkbox and circular radio visuals are both intrinsic `CheckButton` frames. The generated `SimpleCheckboxAPI` exposes `GetChecked`, `SetChecked`, checked-texture access, and disabled-checked-texture access (`Blizzard_APIDocumentationGenerated/SimpleCheckboxAPIDocumentation.lua:1-94`).
- `UICheckButtonTemplate` is the broad shared labeled checkbox. It inherits `UICheckButtonArtTemplate`, is `32 x 32`, supplies a `Text` FontString, needs no mixin or initializer, and remains widely used across unrelated current Mainline features (`Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:42-64`).
- `MinimalCheckboxTemplate` is the shared compact minimal-art checkbox. It is `30 x 29`, has no label or behavior mixin, and is used by the current AddOn List (`CheckButtonTemplates.xml:66-76`; `Blizzard_AddOnList/AddonList.xml:131-145`).
- `UIRadioButtonTemplate` is the reusable shared circular radio visual. It is a `16 x 16` `CheckButton` with a label FontString and normal, highlight, and checked slices from `UI-RadioButton` (`CheckButtonTemplates.xml:4-24`).
- A `UIRadioButtonTemplate` does **not** enforce mutual exclusion. Current consumers explicitly set the clicked choice and clear its sibling(s).
- `CreateRadioButtonGroup()` does enforce a one-selected-button group, but it requires buttons implementing `SelectableButtonMixin`; it is not an intrinsic group controller for `UIRadioButtonTemplate` CheckButtons (`Blizzard_SharedXML/ButtonGroup.lua:1-4,172-235`; `SelectableButton.*`).
- Plain shared checkbox/radio templates do not provide semantic persistence. The intrinsic frame owns only its checked bit; current consumers synchronize that bit with their own model, CVar, API, or setting.
- `Settings.CreateCheckbox` creates a registered boolean-setting control. Settings exclusive choices normally use `Settings.CreateDropdown` options rendered as menu radio descriptions; there is no standalone `SettingsRadioControlTemplate` in this source snapshot.
- Exact standalone frame/template identifiers absent from LIVE source: `CheckButtonTemplate`, an intrinsic `<RadioButton>` element, and `RadioButtonTemplate`. `UICheckButtonTemplate`, `UIRadioButtonTemplate`, and `UIRadialButtonTemplate` are the real template identifiers.

### ENGINEERING RECOMMENDATIONS / INFERENCES

- For a normal addon-owned boolean, use `CreateFrame("CheckButton", ..., "UICheckButtonTemplate")`. It is the strongest general-purpose default because it is shared, self-contained, labeled, initialization-free, and broadly used.
- For a denser modern visual, use `MinimalCheckboxTemplate` and add an addon-owned label and deliberate hit region. It is a compact art control, not a complete labeled setting row.
- For a small conventional radio group, use `UIRadioButtonTemplate`, keep one selected domain value in addon state, and refresh every sibling's `SetChecked` state after selection. Do not rely on visual radio buttons to exclude one another.
- Make the label area clickable. A FontString outside a checkbox does not enlarge the intrinsic hit area by itself; current Blizzard code either extends `HitRectInsets` or forwards a row/label click to `checkbox:Click()`.
- Use `CreateRadioButtonGroup` only when the choices are `SelectableButtonMixin`-based buttons such as tabs/cards, not as a drop-in group for `UIRadioButtonTemplate`.
- Use Settings checkbox/dropdown APIs only when intentionally registering controls in Blizzard Settings. Do not instantiate Settings control wrappers merely to borrow their appearance.

## 3. System inventory

| Identifier/system | LIVE status | Definition/ownership | Practical role |
|---|---|---|---|
| `CheckButton` | Present, intrinsic | `SimpleCheckboxAPI`; XML frame type | Stateful clickable widget with checked bit and checked textures |
| `CheckButtonTemplate` | **Absent exact identifier** | Exact-name LIVE search | Do not invent this template name |
| `UICheckButtonArtTemplate` | Present, shared | `Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml:42-48` | Standard checkbox art without size or label |
| `UICheckButtonTemplate` | Present, shared | same file `:50-64` | Broad standard labeled checkbox |
| `MinimalCheckboxArtTemplate` | Present, shared | same file `:66-72` | Minimal atlas art without size or label |
| `MinimalCheckboxTemplate` | Present, shared | same file `:74-76` | Compact art-only checkbox |
| `UIRadioButtonTemplate` | Present, shared | same file `:4-24` | Conventional circular radio visual; no group semantics |
| `UIRadialButtonTemplate` | Present, shared | same file `:26-40` | Atlas-based yellow radial-tick visual; current direct use found only in Character Services glue UI |
| intrinsic `<RadioButton>` / `RadioButtonTemplate` | **Absent exact identifiers** | Exact-name LIVE XML search | Radio visuals are specialized `CheckButton` templates instead |
| `SelectableButtonTemplate` | Present, shared | `Blizzard_SharedXML/SelectableButton.xml:3-8` | Generic selected/unselected Button behavior, no visual art |
| `CreateRadioButtonGroup` | Present, shared | `Blizzard_SharedXML/ButtonGroup.lua:187-232` | Exclusivity controller for `SelectableButtonMixin` buttons |
| `ResizeCheckButtonTemplate` | Present, shared specialized | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.*` | Resizing labeled wrapper with callback, tooltip, disabled label font, and narration; current use is mostly glue/login flow |
| `NineSliceCheckButtonTemplate` | Present, shared specialized | `SharedUIPanelTemplates.xml:1232-1292` | Caller-configured NineSlice selected-button base; not an ordinary boolean field |
| `SettingsCheckboxTemplate` | Present, Settings-owned | `Blizzard_Settings_Shared/Blizzard_SettingControls.*` | Minimal checkbox with Settings callback/tooltip lifecycle |
| `SettingsCheckboxControlTemplate` | Present, Settings-owned | same XML `:107-112` | Complete 280x26 registered-setting row |
| `ChatConfigCheckButtonTemplate` | Present, feature-owned | `Blizzard_ChatFrame/Mainline/ChatConfigFrame.xml:73-134` | Active Chat configuration checkbox with expanded label hit area |
| `OptionsBaseCheckButtonTemplate` family | Present, source-marked deprecated | `Blizzard_FrameXML/DeprecatedTemplates.xml:5-35` | Older Interface Options compatibility templates; no active exact consumers found |

`Blizzard_SharedXML` loads `Shared/Button/CheckButtonTemplates.xml` and `ButtonGroup.lua` and declares its dependencies in its TOC (`Blizzard_SharedXML/Blizzard_SharedXML.toc:1-3,62-63`). A standalone addon can declare `## Dependencies: Blizzard_SharedXML` for an explicit load-order contract. Feature-owned templates should not be borrowed by loading a large feature addon.

## 4. Standalone checkbox architecture

### 4.1 Intrinsic state and API

`CheckButton` extends ordinary button behavior with a checked bit and two checked-art channels. The generated API establishes:

- `GetChecked()` returns a non-nil boolean;
- `SetChecked([checked=false])` sets the widget's checked bit;
- `GetCheckedTexture` / `SetCheckedTexture` access checked art;
- `GetDisabledCheckedTexture` / `SetDisabledCheckedTexture` access disabled-while-checked art.

`SetChecked` and the texture setters accept secret arguments only when untainted in this 12.1 API definition (`SimpleCheckboxAPIDocumentation.lua:49-78`). This does not make a normal checkbox a secure action button; it is a 12.1 argument-safety annotation.

The intrinsic checked bit is presentation state, not an addon database. Current consumers commonly:

1. call `SetChecked(modelValue)` on show/refresh;
2. read the post-click `GetChecked()` value in `OnClick`;
3. update the external model/API;
4. refresh again when external state changes.

Programmatic `SetChecked` is used for synchronization without treating it as a user click. Settings, for example, calls `SetChecked(value)` when a Setting changes and handles user input only through its separately installed `OnClick` script (`Blizzard_SettingControls.lua:553-568,602-617`).

### 4.2 `UICheckButtonTemplate`

`UICheckButtonArtTemplate` supplies:

- unchecked/normal: `Interface\Buttons\UI-CheckBox-Up`;
- pushed: `UI-CheckBox-Down`;
- highlight: `UI-CheckBox-Highlight`, additive;
- checked: `UI-CheckBox-Check`;
- disabled checked: `UI-CheckBox-Check-Disabled`.

`UICheckButtonTemplate` adds a `32 x 32` size and `GameFontNormalSmall` FontString anchored two pixels back from the button's right edge. The FontString has `parentKey="Text"`. Its load script also creates the lowercase `button.text` alias strictly for addon backward compatibility (`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:990-994`).

The template has no behavior mixin, `OnClick`, tooltip handler, narration hook, sound, or domain callback. Direct use requires only normal `CheckButton` creation and caller scripts:

```lua
local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
checkbox.Text:SetText("Enable feature")
checkbox:SetChecked(model.enabled)
checkbox:SetScript("OnClick", function(button, buttonName, down)
    model.enabled = button:GetChecked()
end)
```

The `buttonName` and `down` arguments are standard Button-script arguments. Current Settings code installs exactly `function(button, buttonName, down)` and obtains the new boolean with `button:GetChecked()` (`Blizzard_SettingControls.lua:553-559`).

### 4.3 `MinimalCheckboxTemplate`

`MinimalCheckboxArtTemplate` uses current atlas art:

- normal/pushed/highlight: `checkbox-minimal` (highlight is additive);
- checked: `checkmark-minimal`;
- disabled checked: `checkmark-minimal-disabled`.

`MinimalCheckboxTemplate` adds only a `30 x 29` size. It has no FontString, scripts, mixin, tooltip, or initialization method (`CheckButtonTemplates.xml:66-76`).

The current AddOn List uses it for `ForceLoad`, adds a separate FontString, synchronizes it from `C_AddOns.IsAddonVersionCheckEnabled()` on show, and writes back through `C_AddOns.SetAddonVersionCheck()` from `OnClick` (`Blizzard_AddOnList/AddonList.xml:131-145`; `AddonList.lua:273-285`). This is strong evidence for direct addon-owned use, but not for automatic label behavior.

### 4.4 Higher-level labeled checkbox families

Blizzard uses different wrappers when a subsystem needs more than a box and text:

- `ResizeCheckButtonTemplate` is an outer `ResizeLayoutFrame` containing a `UICheckButtonTemplate` child and a large label. `SetCallback` receives `function(checked, isUserInput)`; `SetControlChecked(checked, isUserInput)` can invoke that callback programmatically; it also changes label fonts when disabled, supports tooltip text, and assigns checkbox narration (`SharedUIPanelTemplates.xml:1300-1346`; `.lua:996-1143`). Its current consumers are Character Create, Account Login, and Login Warning dialogs, so it is specialized rather than the compact Config default.
- `ChatConfigCheckButtonTemplate` owns the standard checkbox textures, a label, tooltip hooks, sound, and a feature callback `self.func(self, checked)`. It extends its right hit rectangle by 145 pixels (`ChatConfigFrame.xml:73-121`). It is active, but belongs to `Blizzard_ChatFrame` rather than general SharedXML.
- `BankPanelCheckboxTemplate` is a modern minimal labeled checkbox with feature-specific bank setting flags and truncated-tooltip behavior (`Blizzard_UIPanels_Game/Mainline/BankFrame.xml:3-37`). It is useful evidence for the composition pattern, not a general dependency.
- `SettingsCheckboxControlTemplate` is a registered-setting row and is covered separately below.

There is therefore no single universal higher-level labeled checkbox used everywhere. Blizzard chooses a bare/shared template plus feature code, a feature wrapper, or a Settings initializer according to ownership.

## 5. Labels and click behavior

### VERIFIED SOURCE FACTS

- `UICheckButtonTemplate.Text` and `UIRadioButtonTemplate.text` are FontStrings anchored outside the box/circle. Neither template extends its hit rectangle and neither FontString declares mouse scripts.
- Therefore the visual label is not automatically a second clickable control and does not by itself enlarge the CheckButton's mouse region.
- Current Chat Config checkbox templates use negative right `HitRectInsets` to include their label area (`ChatConfigFrame.xml:109-134`).
- `RaidFrameAllAssistCheckButton` likewise extends its right hit rectangle by 30 pixels around a `UICheckButtonTemplate` label (`Blizzard_RaidFrame/Mainline/RaidFrame.xml:145-170`).
- Settings places a tooltip/row region across the label area and forwards `OnMouseUp` to `self.Checkbox:Click()` only when the checkbox is enabled (`Blizzard_SettingControls.lua:572-585`).
- Character Services radio choices extend a `UIRadialButtonTemplate` hit rectangle 220 pixels to the right, covering their compound visual choice rows (`Blizzard_GlueXML/Mainline/CharacterServices.xml:47-115,117-163`).

### ENGINEERING RECOMMENDATION / INFERENCE

A labeled boolean or radio choice should normally make the text area clickable. For a compact addon-owned row, the simplest source-backed pattern is one CheckButton with a deliberately expanded hit rectangle covering its addon-owned label. A full-row overlay that calls `checkbox:Click()` is also source-backed and can simplify dynamic layout. Avoid creating two independent toggle paths that can drift in enabled state or callback behavior.

## 6. Disabled, highlight, tooltip, and narration states

### 6.1 Checkbox visuals

Both shared checkbox art families define an explicit disabled-checked texture. Neither defines a distinct disabled-unchecked texture in the template. The ordinary unchecked box is the normal texture; exact engine treatment of that texture when disabled is not separately specified by these XML templates.

Disabling the CheckButton governs interaction, but label appearance is caller-owned unless a wrapper handles it. The Reputation detail panel demonstrates this explicitly: it calls `SetEnabled`, then selects `NORMAL_FONT_COLOR` or `GRAY_FONT_COLOR` for the adjacent label (`Blizzard_UIPanels_Game/Mainline/ReputationFrame.lua:731-741`).

Settings handles the row as a unit: `DisplayEnabled` grays its text and desaturates the hierarchy, while `SettingsCheckboxControlMixin:EvaluateState` sets the child checkbox enabled state (`Blizzard_SettingControls.lua:284-294,625-643`). `ResizeCheckButtonMixin` switches between configurable enabled and disabled label fonts (`SharedUIPanelTemplates.lua:1102-1143`).

### 6.2 Radio visuals

`UIRadioButtonTemplate` defines no pushed texture, disabled texture, or disabled-checked texture. It defines normal, additive highlight, and checked slices only. `UIRadialButtonTemplate` similarly defines normal, highlight, and checked atlases only (`CheckButtonTemplates.xml:4-40`). A caller can disable these CheckButtons, but the templates do not promise a distinct disabled selected mark or automatic gray label.

Chat Config supplies a real disabled-radio example: its By Source and By Target radio controls are enabled only when line coloring is enabled, and the same refresh explicitly sets which sibling is checked (`ChatConfigFrame.lua:1250-1261`). Exact disabled label/selected visual quality remains a reasonable runtime comparison question.

### 6.3 Tooltip and accessibility hooks

Plain `UICheckButtonTemplate`, `MinimalCheckboxTemplate`, `UIRadioButtonTemplate`, and `UIRadialButtonTemplate` have no intrinsic tooltip or narration mixin. Consumers add `OnEnter`/`OnLeave` tooltips when needed. Auction House and Reputation are representative (`Blizzard_AuctionHouseItemSellFrame.lua:18-29`; `ReputationFrame.lua:818-848`).

Settings and `ResizeCheckButtonTemplate` add explicit support:

- Settings uses `DefaultTooltipMixin`, forwards narration from its child checkbox/tooltip region, and derives checkbox narration context through `NarrationUtil.GetCheckboxContext` (`Blizzard_SettingControls.lua:540-579,441-447`).
- `ResizeCheckButtonMixin` provides tooltip text and assigns `NarrationGetName`/`NarrationGetContext` to its child checkbox (`SharedUIPanelTemplates.lua:1013-1031,1060-1069,1120-1131`).

These are wrapper capabilities, not implicit behavior of a bare shared CheckButton.

## 7. Standalone radio architecture

### 7.1 `UIRadioButtonTemplate`

The only broadly used shared conventional radio-circle template is `UIRadioButtonTemplate`. It is still a `CheckButton`, not a separate `RadioButton` frame type. Its `UI-RadioButton` texture is divided into:

- normal/unchecked: texture coordinates `0` to `0.25`;
- checked: `0.25` to `0.5`;
- highlight: `0.5` to `0.75`, additive.

The template is `16 x 16` and adds a `GameFontNormalSmall` label five pixels to its right (`CheckButtonTemplates.xml:4-24`). It has no mixin, scripts, value field, or group registration.

`UIRadialButtonTemplate` is an `18 x 18` atlas-based alternative with a yellow selected mark. The only direct consumer found outside its definition is Character Services glue UI. That narrow usage does not establish it as the default in-game addon control (`CheckButtonTemplates.xml:26-40`; `CharacterServices.xml:47-163`).

### 7.2 Mutual exclusion is not intrinsic

Real `UIRadioButtonTemplate` consumers manage exclusivity outside the template:

- Mail's `SendMailRadioButton_OnClick(index)` explicitly sets one radio true and the other false (`Blizzard_MailFrame/MailFrame.xml:3-9,741-758`; `MailFrame.lua:1140-1150`).
- Chat Config writes `lineColorPriority`, rebuilds the display, and explicitly checks By Source while clearing By Target or vice versa (`ChatConfigFrame.xml:1149-1182`; `ChatConfigFrame.lua:1250-1261`).
- Communities stores a notification filter in its row mixin, then sets Show Notifications checked only for `All` and Hide Notifications checked only for `None` (`Blizzard_Communities/CommunitiesStreams.xml:5-21,46-61`; `CommunitiesStreams.lua:233-240`).
- Garrison Recruiter explicitly sets `Radio1` and `Radio2` to opposite values when loading or changing its ability/trait choice (`Blizzard_GarrisonUI/Mainline/Blizzard_GarrisonRecruiterUI.xml:3-14,225-240`; `.lua:69-87,158-164`).

These callsites also prevent a selected radio from remaining unchecked after clicking it again: their domain value is authoritative and their refresh reapplies one selected choice.

### 7.3 `CreateRadioButtonGroup` is a separate system

`SelectableButtonTemplate` is an ordinary `Button` mixed with `SelectableButtonMixin`. The mixin keeps `self.selected`, toggles it from `OnClick`, supports a selection-change interrupt, and delegates visual changes to derived `SetSelectedState`/`OnSelected` implementations (`Blizzard_SharedXML/SelectableButton.xml:3-8`; `.lua:1-50`).

`CreateRadioButtonGroup()` constructs `RadioButtonGroupMixin`. The group:

- wraps each member's existing `OnClick` script;
- requires the member to expose `IsSelected` and `SetSelected`;
- prevents unselecting the last selected member;
- deselects every selected sibling when a new button is selected;
- fires `ButtonGroupBaseMixin.Event.Selected` or `Unselected` with `(button, buttonIndex)` after CallbackRegistry owner dispatch (`ButtonGroup.lua:36-60,140-180,187-232`).

This helper is used for selectable tabs/cards in Settings, Graphics, Catalog Shop, Game Mode Select, Perks Program, talents, and Soulbinds. Settings Panel, for example, adds its Game/AddOns tabs and registers `OnTabSelected(tab, tabIndex)` (`Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua:49-60,107-110`).

`UIRadioButtonTemplate` supplies `GetChecked`/`SetChecked`, not `IsSelected`/`SetSelected`, and does not inherit `SelectableButtonTemplate`. Therefore `CreateRadioButtonGroup` is not directly compatible with the conventional radio-circle template. Mixing these systems without an explicit adapter is not source-supported by the inspected examples.

## 8. State and callback semantics

| Control path | User callback/script | State delivered | Programmatic synchronization |
|---|---|---|---|
| Plain `CheckButton` | `OnClick(self, buttonName, down)` | Read post-click `self:GetChecked()` | `SetChecked(boolean)` |
| Feature checkbox mixin | Feature-defined method/function | Commonly reads `self:GetChecked()` or receives `(self, checked)` | Feature refresh calls `SetChecked` |
| `SettingsCheckboxTemplate` | Internal `OnClick(button, buttonName, down)` | Triggers `OnValueChanged` with `button:GetChecked()` | `SetValue` / `SetChecked` |
| `SettingsCheckboxControlTemplate` | CallbackRegistry to control mixin | `OnCheckboxValueChanged(value)` after owner dispatch | Setting change callback calls `SetChecked(value)` |
| `ResizeCheckButtonTemplate` | `onBoxToggled(checked, isUserInput)` | Boolean plus explicit origin flag | `SetControlChecked(checked, isUserInput)` |
| `UIRadioButtonTemplate` | Plain `OnClick` | No domain value supplied by template; caller associates ID/value/data | Caller sets every sibling's checked state |
| `RadioButtonGroupMixin` | CallbackRegistry Selected/Unselected | `(button, buttonIndex)` after callback owner | `SelectAtIndex`, `UnselectAtIndex`, `SetSelectedAtIndex` |

The plain intrinsic click contract is source-backed by consumers that immediately read `GetChecked()` and write external state without first calling `SetChecked`: AddOn List (`AddonList.lua:276-285`), Auction House (`Blizzard_AuctionHouseItemSellFrame.lua:31-38`), Raid (`RaidFrame.xml:163-170`), and Reputation (`ReputationFrame.lua:810-838`). In those callsites, `GetChecked()` is the new post-click state.

CallbackRegistry does not participate in `UICheckButtonTemplate`, `MinimalCheckboxTemplate`, `UIRadioButtonTemplate`, or `UIRadialButtonTemplate` themselves. It participates in `SettingsCheckboxMixin` and `ButtonGroupBaseMixin`. This matters because CallbackRegistry registrations include an owner argument before event payload; plain frame scripts do not.

## 9. Representative current Blizzard usage

| Feature | Control | State ownership and click model | Label/disabled behavior | Assessment |
|---|---|---|---|---|
| AddOn List | `MinimalCheckboxTemplate` Force Load | `C_AddOns` state synchronized on show; `OnClick` reads `GetChecked` and writes API state | Separate FontString; no wrapper behavior | Strong compact direct-use example |
| Auction House item sell | `UICheckButtonTemplate` Buyout Mode | Parent sell-frame state; mixin reads `GetChecked` | Uses template `Text`; consumer tooltip | Strong ordinary labeled example |
| Raid frame | `UICheckButtonTemplate` All Assist | `OnClick` sends `GetChecked()` to `C_PartyInfo` | Expanded hit rect includes short label; disabled tooltip remains available via `motionScriptsWhileDisabled` | Strong clickable-label and disabled-tooltip example |
| Reputation detail | `UICheckButtonTemplate` inactive/watch choices | Reputation APIs are authoritative; refresh calls `SetChecked` | Caller explicitly grays disabled labels and adds tooltip mixins | Strong disabled checkbox example |
| Chat Config | Feature checkbox templates plus `UIRadioButtonTemplate` | Feature tables own booleans/exclusive value; refresh reapplies states | Feature label hit rectangles; radio choices enabled conditionally | Current but feature-specific configuration architecture |
| Mail | `SendMailRadioButtonTemplate` -> `UIRadioButtonTemplate` | Button ID selects Send Money/COD; function explicitly sets both radios | Base radio label | Clean manual-exclusivity example |
| Communities | Feature radio template -> `UIRadioButtonTemplate` | Row's notification filter is authoritative; refresh sets both radios | Parent-row highlight forwarding | Clean two-choice model example |
| Garrison Recruiter | Feature radio template -> `UIRadioButtonTemplate` | Ability/trait selection; functions set opposite checked values | Feature-owned label FontString | Current older-feature manual group example |
| Settings definitions | `Settings.CreateCheckbox` | registered Setting object owns value and propagation | complete row, clickable label region, tooltip, disable evaluation, narration | Correct for intentional Settings integration |
| Settings panel tabs | `CreateRadioButtonGroup` + selectable tabs | group owns selected button; category set changes from selected tab | tab-specific visuals, not circles | Strong group-helper example, not a setting radio row |

## 10. Blizzard Settings integration

### 10.1 Boolean settings

`Settings.CreateCheckbox(category, setting, tooltip)` calls `Settings.CreateCheckboxInitializer`, which asserts a boolean Setting and creates a `SettingsCheckboxControlTemplate` initializer before adding it to the category layout (`Blizzard_Settings_Shared/Blizzard_Settings.lua:358-365,382-394`).

The full control path is:

1. a `280 x 26` `SettingsCheckboxControlTemplate` row inherits `SettingsListElementTemplate`;
2. its `OnLoad` creates a `SettingsCheckboxTemplate` child directly;
3. `Init(initializer)` reads the registered Setting value and initializes the child;
4. the child click triggers `SettingsCheckboxMixin.Event.OnValueChanged` with the new boolean;
5. the control optionally intercepts/reverts it, otherwise calls `setting:SetValue(value)`;
6. Setting change callbacks synchronize the child back with `SetChecked(value)` (`Blizzard_SettingControls.xml:80-112`; `.lua:540-647`).

The row owns text, tooltip hover/click coverage, disable evaluation, narration forwarding, search/initializer metadata, and layout integration. `SettingsCheckboxTemplate` itself uses the same `checkbox-minimal` / `checkmark-minimal` atlas family as the shared minimal checkbox, with a Settings hover background and a Settings-specific CallbackRegistry/tooltip mixin.

### 10.2 Exclusive settings

No standalone Settings radio-row template was found. `Settings.ControlType.Radio` belongs to option data for Settings dropdowns. `SettingsControlTextContainerMixin:Add` creates Radio option data; the dropdown inserter turns it into `CreateHighlightRadio`, compares `setting:GetValue()` with `optionData.value`, and calls `setting:SetValue(optionData.value)` on selection (`Blizzard_Settings.lua:244-263,488-533`).

Thus intentional Settings integration normally uses:

- `Settings.CreateCheckbox` for a boolean;
- `Settings.CreateDropdown` with radio option descriptions for one-of-many values.

The `CreateRadioButtonGroup` calls inside Settings are UI navigation/tab groups, not setting-backed standalone radio controls.

### 10.3 Direct-use boundary

`SettingsCheckboxTemplate` is technically created directly by Settings code and has a clear `Init(value, initTooltip)` contract, but its mixin and consumers belong to `Blizzard_Settings_Shared`. A custom addon-owned Config frame that wants minimal checkbox art can use `MinimalCheckboxTemplate` without importing registered-setting, initializer, callback-container, tooltip, narration, and category-layout assumptions. Use the Settings control only when the control genuinely participates in Settings.

## 11. Legacy and older patterns

- `OptionsBaseCheckButtonTemplate`, `OptionsSmallCheckButtonTemplate`, `InterfaceOptionsCheckButtonTemplate`, and `InterfaceOptionsBaseCheckButtonTemplate` still load through `Blizzard_FrameXML`, but their authoritative definitions are in `Blizzard_FrameXML/DeprecatedTemplates.xml:5-35`. Exact-name LIVE searches found no consumer beyond those definitions. These are source-marked deprecated and should not start new Retail-only code.
- `ChatConfigCheckButtonTemplate` is not deprecated. It remains actively used by Chat Config, but it is feature-owned and imports chat-specific callbacks, sound, tooltip fields, and fixed hit widths. Avoid it as a general addon dependency for coupling reasons, not because it is obsolete.
- `UICheckButtonTemplate` and `UIRadioButtonTemplate` use long-standing texture families, but they are not source-marked deprecated and remain actively used. Do not equate old visual language with deprecation.
- `UIRadialButtonTemplate` and `ResizeCheckButtonTemplate` are current shared definitions with narrow consumers. Their specialized use is insufficient evidence to replace the broad defaults.
- `NineSliceCheckButtonTemplate` needs caller-provided atlas/layout key values and was already classified as unresolved for ordinary reuse in `ButtonsAndFrames.md`; it represents checkable NineSlice controls, not normal boolean fields.

## 12. Template comparison

| Candidate | Visual/default size | Label/click area | Checked/disabled/highlight | Initialization/callback | Direct custom Config suitability |
|---|---|---|---|---|---|
| `UICheckButtonTemplate` | Standard checkbox, `32 x 32` | Built-in `Text`; label lies outside default box hit area | Full normal/pushed/highlight/checked; disabled-checked art | None; plain `OnClick` | **Strongest general-purpose checkbox** |
| `MinimalCheckboxTemplate` | Minimal atlas, `30 x 29` | No label | Normal/pushed/highlight; checked and disabled-checked art | None; plain `OnClick` | **Strong compact art choice** with custom label/row |
| `SettingsCheckboxTemplate` | Minimal atlas plus Settings hover, `30 x 29` | Label belongs to outer Settings row | Checked/disabled-checked; row desaturates when disabled | Requires `Init`; CallbackRegistry event | Use inside Settings; prefer shared minimal art elsewhere |
| `ResizeCheckButtonTemplate` | Standard checkbox plus large resizing label | Outer label; child button remains click target | Wrapper changes disabled label font | `onBoxToggled(checked, isUserInput)` | Specialized; not compact default |
| `UIRadioButtonTemplate` | Conventional circle, `16 x 16` | Built-in `text`; no automatic expanded hit area | Normal/highlight/checked; no disabled-specific art | None; plain `OnClick`; caller groups | **Strongest conventional radio candidate** |
| `UIRadialButtonTemplate` | Atlas radial tick, `18 x 18` | Built-in `text`; consumer expands hit area | Normal/highlight/yellow checked; no disabled-specific art | None; caller groups | Specialized alternative; sparse glue use |
| `SelectableButtonTemplate` + radio group | No art; derived button decides size/style | Derived template | Derived template implements selected visuals | CallbackRegistry `(button, index)` | Good for exclusive tabs/cards, not radio circles |
| Deprecated Options templates | Standard checkbox, `26 x 26` | older built-in labels | standard checkbox states, sound script | old Interface Options pattern | Avoid for new Retail-only code |

## 13. Combat, taint, and frame safety

### VERIFIED SOURCE FACTS

- The shared checkbox/radio templates do not inherit `SecureActionButtonTemplate`, set secure action attributes, or perform protected gameplay actions.
- `SelectableButtonMixin`, `ButtonGroup.lua`, and the inspected Settings checkbox control contain no `InCombatLockdown`, `PLAYER_REGEN_*`, or explicit combat gate.
- The only `protected` matches in the inspected Settings path are kiosk-mode flags, not secure-frame or combat-lockdown behavior.
- The generated API annotates `SetChecked`, `SetCheckedTexture`, and `SetDisabledCheckedTexture` secret arguments as `AllowedWhenUntainted`; this is distinct from a secure-action inheritance claim.

### ENGINEERING RECOMMENDATION / INFERENCE

The ordinary controls themselves are non-secure UI widgets in the inspected definitions. That does not make every callback or downstream configuration action combat-safe. A callback may reconfigure protected frames, invoke restricted APIs, propagate secrets, or create taint through unrelated code. The conservative production policy remains: do not encourage configuration changes during combat merely because the checkbox or radio can be clicked. Evaluate or defer the downstream operation independently.

## 14. Third-party addon engineering assessment

### VERIFIED SOURCE FACTS

1. **Normal boolean checkbox:** `CheckButton` + `UICheckButtonTemplate` is the broad current shared implementation.
2. **Compact minimal checkbox:** `MinimalCheckboxTemplate` is a direct shared art control with a current AddOn List consumer.
3. **Labeled checkbox:** `UICheckButtonTemplate` owns a label FontString, but the label does not automatically enlarge the mouse area.
4. **Clickable label:** current source expands `HitRectInsets` or forwards a row click to `checkbox:Click()`.
5. **Conventional radio:** `UIRadioButtonTemplate` is the shared circular radio visual.
6. **Mutual exclusion:** `UIRadioButtonTemplate` does not provide it. Current callers explicitly own the selected value and set every sibling.
7. **Group helper:** `CreateRadioButtonGroup` enforces exclusivity only for `SelectableButtonMixin` members and reports button plus index.
8. **Disabled checkbox:** the shared checkbox art has disabled-checked art; callers own disabled label treatment.
9. **Disabled radio:** the shared radio templates have no disabled-specific texture declaration.
10. **Settings:** boolean rows use `Settings.CreateCheckbox`; exclusive settings normally use a dropdown with radio descriptions.
11. **Menu descriptions:** `rootDescription:CreateCheckbox/CreateRadio` are declarative `Blizzard_Menu` elements, not standalone CheckButton frames, and have different predicate/responder signatures.

### ENGINEERING RECOMMENDATIONS / INFERENCES

1. Use `UICheckButtonTemplate` for the ordinary addon-owned boolean default.
2. Use `MinimalCheckboxTemplate` when compact minimal art is an intentional Config-page choice; add explicit label, tooltip, enabled font/color, and hit area.
3. Make labels clickable through one shared interaction region, preferably the CheckButton's extended hit rectangle for a simple row.
4. Use `UIRadioButtonTemplate` for a small conventional one-of-three group. Store the selected value once in the addon model, and centralize `SetChecked(button.value == selectedValue)` across the group.
5. Do not let each radio own an independent boolean; that permits zero or multiple choices and makes persistence ambiguous.
6. For selectable tabs/cards, use `SelectableButtonTemplate` derivatives with `CreateRadioButtonGroup` rather than imitating circular radios.
7. When disabling a choice, disable the actual CheckButton and deliberately update its label/tooltip presentation. Do not rely on checked art alone to communicate disabled state.
8. Use Settings APIs for intentional Settings categories. Do not create `SettingsCheckboxControlTemplate` directly in a custom dialog.
9. Avoid source-marked deprecated Options templates and feature-owned Chat/Bank checkbox templates in new Retail-only shared code.
10. Keep menu-description controls architecturally separate: use them inside generated dropdown/context menus, not as a substitute for persistent standalone frame controls.

## 15. Recommended runtime validation

Source is sufficient for the architectural recommendation, but a small LIVE comparison would resolve presentation/input questions that source does not fully guarantee:

- direct addon creation of `UICheckButtonTemplate`, `MinimalCheckboxTemplate`, and `UIRadioButtonTemplate`;
- checked/unchecked and enabled/disabled appearance, especially disabled-unchecked checkbox and disabled-selected radio;
- exact default label hit testing versus an expanded hit rectangle;
- dynamic label width and localization-safe hit regions;
- one three-choice radio group proving caller-owned normalization and no unselected state;
- mouse, keyboard, gamepad, and narration behavior for bare controls versus an addon-supplied row;
- tooltip behavior while disabled with and without `motionScriptsWhileDisabled`;
- visual density at normal and alternate UI scales;
- inert click/state updates during combat, with no protected downstream action.

Production actions should be tested separately from inert control interaction.

## 16. Sample decision

**A. Sample recommended, but not created in this task.**

A focused `CheckboxRadioComparison` addon would materially answer the remaining visual and input questions. Its justified scope is:

1. `UICheckButtonTemplate` with built-in label;
2. `MinimalCheckboxTemplate` with addon-owned label;
3. checked and unchecked enabled/disabled rows;
4. default versus expanded label hit regions;
5. three `UIRadioButtonTemplate` choices backed by one external selected value;
6. one disabled radio choice;
7. optional `SettingsCheckboxTemplate` visual-only comparison only if the sample explicitly loads `Blizzard_Settings_Shared` and labels that coupling;
8. keyboard, gamepad, narration, combat, and UI-scale observation notes.

The sample should not include deprecated Options templates, feature-owned Chat/Bank templates, menu-description radios/checkboxes, protected actions, or Settings registration unless that registration itself becomes a separate research question.

## 17. Verified facts versus engineering inference

### VERIFIED

- Every template, mixin, helper, callback path, generated API, Settings path, and representative callsite cited above exists in LIVE commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`.
- `UICheckButtonTemplate` and `UIRadioButtonTemplate` are ordinary shared CheckButton templates with no initializer or semantic persistence.
- `UIRadioButtonTemplate` has no group relationship; current consumers explicitly enforce exclusivity.
- `CreateRadioButtonGroup` requires `SelectableButtonMixin` members and fires Selected/Unselected events with button and index.
- Settings has a checkbox control and uses menu radio descriptions for exclusive option dropdowns; no standalone Settings radio control template was found.
- The older Interface Options checkbox family is defined in `DeprecatedTemplates.xml` and had no exact external consumer in the focused LIVE search.
- No explicit combat gate or secure-action inheritance was found in the core controls.

### ENGINEERING INFERENCE

- `UICheckButtonTemplate` is the safest general default because its broad current Mainline use outweighs its older texture language.
- `MinimalCheckboxTemplate` is the best compact visual candidate when the addon is willing to own the entire row contract.
- `UIRadioButtonTemplate` is the best conventional radio candidate despite manual group management because no stronger shared in-game circular-radio architecture exists in this snapshot.
- Clickable labels, explicit disabled label styling, centralized model state, and conservative combat policy are production-quality addon decisions supported by multiple Blizzard patterns, not intrinsic template guarantees.
- A small sample is worthwhile for visuals and input behavior, but source has already settled the ownership and callback architecture.

## 18. LIVE runtime validation

### Validation scope

The consolidated `RetailUIResearch` harness and its `CheckboxRadioComparison` module were subsequently tested by the user on Retail LIVE `12.1.0.69497`. No implementation change was required during this documentation checkpoint.

### Harness behavior observed on LIVE

- Login/reload completed without a Lua error. Only the `RetailUIResearch` launcher opened; none of the four module windows auto-opened.
- Sliders, Buttons & Frames, Dropdowns & Menus, and Checkboxes & Radios all opened from the launcher.
- Selecting another module hid the previously selected module.
- Closing a module with its close button left the launcher usable, and its launcher button reopened the same module correctly.
- All retained module slash commands continued to open/toggle their module through the Core visibility coordinator, including closing an already visible module through their retained toggle semantics.

### Checkbox and radio behavior observed on LIVE

- `UICheckButtonTemplate` interactive unchecked/checked state and the adjacent state display updated correctly. The initially checked enabled example toggled correctly, and disabled examples remained inert.
- `MinimalCheckboxTemplate` toggled correctly with its natural compact hit behavior preserved; its disabled examples remained inert.
- The ordinary separate-label example retained a checkbox-only hit target. The `SetHitRectInsets` example made its expanded label area clickable and toggled the same checkbox as intended.
- Alpha, Beta, and Gamma `UIRadioButtonTemplate` choices remained mutually exclusive through the addon-owned `selectedRadio` value and explicit sibling `SetChecked()` refresh. Exactly one normal choice remained selected, and disabled Delta remained inert.
- Root-frame scale changes to 75%, 100%, and 125%, including repeated switching, completed correctly.
- No Lua errors or blocked-action output were observed during the supplied runtime test.

### Isolated combat observation

The combat-state diagnostic changed correctly during actual combat. The isolated non-secure controls and inert/sample-local callbacks remained interactive for the tested root-frame scale changes, standard and initially checked checkbox toggles, radio selection, `MinimalCheckboxTemplate` toggling, checkbox-only target toggling, and expanded clickable-label toggling.

This does **not** establish that arbitrary production configuration callbacks, protected-frame operations, secure actions, runtime frame reconfiguration, or taint-sensitive downstream work are safe during combat. Those operations still require evaluation in their actual production ownership and execution paths.

### Evidence classification after runtime validation

- **Source verified:** template definitions, plain `OnClick(self, buttonName, down)` dispatch, post-click `GetChecked()` state, label hit-area ownership, external radio-domain ownership, `CreateRadioButtonGroup` compatibility boundaries, Settings routes, and deprecated Options-template status.
- **LIVE observed:** the specific harness navigation, visual states, hit targets, explicit radio synchronization, fixed root-frame scaling, and isolated combat interactions listed above.
- **Engineering recommendations:** use `UICheckButtonTemplate` as the strongest general checkbox, `MinimalCheckboxTemplate` as the compact alternative, and `UIRadioButtonTemplate` with one externally owned selected value for conventional small radio groups. Preserve conservative production combat policy.

Keyboard, gamepad, and narration behavior was not exhaustively runtime validated. Bare shared controls still do not imply the higher-level accessibility and navigation infrastructure supplied by Settings-owned wrappers.

The module screenshot `Samples/RetailUIResearch/Modules/CheckboxRadioComparison/CheckboxRadioComparison.png` is the user-authored Retail LIVE visual/runtime reference.

## 19. Final conclusions

Modern Retail standalone checkbox/radio UI is simpler than the menu-description system. The reusable foundation remains the intrinsic `CheckButton`. `UICheckButtonTemplate` is the strongest full ordinary checkbox; `MinimalCheckboxTemplate` is a compact art-only alternative. Both expose widget checked state, while addon state owns meaning and persistence.

For conventional exclusive choices, `UIRadioButtonTemplate` supplies only the visual and intrinsic checked bit. The addon must own one selected value and refresh all siblings. Blizzard's `CreateRadioButtonGroup` is real and reusable, but it controls `SelectableButtonMixin` buttons such as tabs/cards rather than `UIRadioButtonTemplate` circles.

Blizzard Settings adds a complete setting/initializer/layout/callback/narration lifecycle. Use `Settings.CreateCheckbox` for registered booleans and Settings dropdown radio options for registered exclusive values. For an addon-owned Config frame, use the shared controls directly and implement a coherent row, clickable label, disabled presentation, tooltip, and external state model.

The source-marked deprecated Options checkbox templates should not begin new Retail-only code. Feature-owned Chat, Bank, Character Services, and other wrappers demonstrate useful patterns but should not become cross-feature dependencies.

## 20. Primary source index

- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleCheckboxAPIDocumentation.lua`
- `Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML.toc`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/SelectableButton.lua`
- `Interface/AddOns/Blizzard_SharedXML/SelectableButton.xml`
- `Interface/AddOns/Blizzard_SharedXML/ButtonGroup.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.xml`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`
- `Interface/AddOns/Blizzard_SettingsDefinitions_Shared/Graphics.lua`
- `Interface/AddOns/Blizzard_FrameXML/DeprecatedTemplates.lua`
- `Interface/AddOns/Blizzard_FrameXML/DeprecatedTemplates.xml`
- `Interface/AddOns/Blizzard_AddOnList/AddonList.lua`
- `Interface/AddOns/Blizzard_AddOnList/AddonList.xml`
- `Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseItemSellFrame.lua`
- `Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseItemSellFrame.xml`
- `Interface/AddOns/Blizzard_RaidFrame/Mainline/RaidFrame.xml`
- `Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ReputationFrame.lua`
- `Interface/AddOns/Blizzard_UIPanels_Game/Mainline/ReputationFrame.xml`
- `Interface/AddOns/Blizzard_ChatFrame/Mainline/ChatConfigFrame.lua`
- `Interface/AddOns/Blizzard_ChatFrame/Mainline/ChatConfigFrame.xml`
- `Interface/AddOns/Blizzard_MailFrame/MailFrame.lua`
- `Interface/AddOns/Blizzard_MailFrame/MailFrame.xml`
- `Interface/AddOns/Blizzard_Communities/CommunitiesStreams.lua`
- `Interface/AddOns/Blizzard_Communities/CommunitiesStreams.xml`
- `Interface/AddOns/Blizzard_GarrisonUI/Mainline/Blizzard_GarrisonRecruiterUI.lua`
- `Interface/AddOns/Blizzard_GarrisonUI/Mainline/Blizzard_GarrisonRecruiterUI.xml`
- `Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.xml`
- `Interface/AddOns/Blizzard_GlueXML/Mainline/CharacterServices.xml`
