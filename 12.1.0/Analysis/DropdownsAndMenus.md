# Retail Dropdowns and Menus — WoW 12.1.0

## 1. Scope and source baseline

This is a LIVE-first, source-only investigation of dropdown and menu controls available to normal third-party Retail addons. It does not change Blizzard source, production addons, or samples.

- Retail client baseline: `12.1.0.69497`
- LIVE source: `D:\WowDEV\Reference\Blizzard\wow-ui-source`
- LIVE source commit verified for this investigation: `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
- PTR consulted: no. LIVE exposed no concrete compatibility question requiring PTR evidence.
- Research date: 2026-08-31

Source paths below are relative to the LIVE source root unless stated otherwise.

## 2. Executive summary

### VERIFIED SOURCE FACTS

- The current general menu system is `Blizzard_Menu`. Its TOC marks it `LoadFirst: 1`, allows both game environments, and depends only on `Blizzard_SharedXMLBase` (`Interface/AddOns/Blizzard_Menu/Blizzard_Menu.toc:1-21`).
- `DropdownButton` is an intrinsic frame type backed by `DropdownButtonMixin`; there is no exact `DropdownButtonTemplate` identifier (`Blizzard_Menu/DropdownButton.xml:3-17`).
- The normal modern pattern is a `DropdownButton` inheriting a visual template such as `WowStyle1DropdownTemplate`, then `dropdown:SetupMenu(function(dropdown, rootDescription) ... end)`.
- Menu content is expressed as descriptions: `CreateRadio`, `CreateCheckbox`, `CreateButton`, `CreateTitle`, `CreateDivider`, `CreateSpacer`, and related helpers. A description becomes a submenu when child descriptions are added to it; there is no `CreateSubmenu` or `CreateSubMenu` API.
- `MenuUtil.CreateContextMenu(ownerRegion, generator, ...)` uses the same description system and opens at the cursor.
- Blizzard's own migration guide calls `Blizzard_Menu` a complete replacement for `UIDropDownMenu`, says Blizzard uses were converted, and explicitly says `UIDropDownMenu` is deprecated (`Blizzard_Menu/11_0_0_MenuImplementationGuide.lua:1-7`).
- Legacy `UIDropDownMenu` source and templates remain loaded in SharedXML, but active Mainline use found in this pass is vestigial or incidental rather than representative of new menu construction. `EasyMenu` is absent from the current LIVE source.
- Blizzard Settings uses the modern menu system underneath a specialized setting-backed control and `WowStyle2DropdownTemplate`.

### ENGINEERING RECOMMENDATION / INFERENCE

For a new addon-owned configuration frame, use `DropdownButton` with `WowStyle1DropdownTemplate` and `SetupMenu`. Keep the selected value in addon state; have `IsSelected` and responder callbacks read and update that state. Use the same description model for dynamic content, radio choices, checkbox filters, and submenus. Use `MenuUtil.CreateContextMenu` for cursor-positioned context menus. Use `Settings.CreateDropdown` when deliberately registering controls in Blizzard Settings, not merely to borrow a visual.

Avoid starting new code on `UIDropDownMenu`; use it only for a compatibility obligation tied to older code or environments. No current LIVE `EasyMenu` implementation was found to recommend.

## 3. System inventory

| System or identifier | LIVE status | Definition / evidence | Practical role |
|---|---|---|---|
| `Blizzard_Menu` | Present, current | `Blizzard_Menu/Blizzard_Menu.toc:1-21` | Shared modern dropdown/context-menu framework |
| `DropdownButton` | Present, intrinsic | `Blizzard_Menu/DropdownButton.xml:3-17` | Clickable owner that generates and anchors a menu |
| `DropdownButtonMixin` | Present | `Blizzard_Menu/DropdownButton.lua:69-306` | Setup, generation, opening, callbacks, and refresh behavior |
| `DropdownButtonTemplate` | **Absent as an exact identifier** | Exact-name source search | Do not name this as a template |
| `WowStyle1DropdownTemplate` | Present | `Blizzard_Menu/Mainline/MenuTemplates.xml:3-39` | Ordinary text-select dropdown |
| `WowStyle1ArrowDropdownTemplate` | Present | `Blizzard_Menu/Mainline/MenuTemplates.xml:41-64` | Compact arrow-only opener |
| `WowStyle1FilterDropdownTemplate` | Present | `Blizzard_Menu/Mainline/MenuTemplates.xml:66-117` | Fixed-label filter menu with reset support |
| `WowStyle2DropdownTemplate` | Present | `Blizzard_Menu/MenuTemplates.xml:4-53` | Centered modern style used by Settings and selected feature UIs |
| `WowStyle2FilterDropdownTemplate` | **Absent** | Exact-name source search | Do not invent this variant |
| `MenuUtil` | Present, global | `Blizzard_Menu/MenuUtil.lua` | Root descriptions, context menus, inserters, tooltips, helpers |
| `MenuResponse` | Present, global | `Blizzard_Menu/MenuConstants.lua:11-23` | Open/refresh/close response policy |
| `CreateRadio`, `CreateCheckbox`, `CreateButton`, titles/separators | Present | `Blizzard_Menu/MenuUtil.lua:198-274` | Standard description constructors |
| `CreateSubmenu` / `CreateSubMenu` | **Absent** | Exact-name source search | Add children to an element description instead |
| `UIDropDownMenu` / `UIDropDownMenuTemplate` | Present, explicitly deprecated | `Blizzard_SharedXML/Mainline/UIDropDownMenu.lua`; `UIDropDownMenuTemplates.xml:146`; migration guide | Legacy compatibility architecture |
| `EasyMenu` | **Absent** | Case-insensitive full LIVE source search | No current source-backed Retail option |
| Settings dropdown controls | Present, specialized | `Blizzard_Settings_Shared/Blizzard_SettingControls.*`; `Blizzard_Settings.lua` | Settings registration and setting-backed controls |

`Blizzard_Menu` is loaded globally early and is not a feature-on-demand subsystem. That makes its public globals and templates materially different from feature-owned controls whose addons may not be loaded.

## 4. Modern menu architecture

### 4.1 Creation and attachment

The intrinsic frame type is declared as:

```lua
local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
dropdown:SetupMenu(function(dropdown, rootDescription)
    -- Add element descriptions here.
end)
```

This construction form is shown in the Blizzard migration guide (`Blizzard_Menu/11_0_0_MenuImplementationGuide.lua:91-110`). A current code-created callsite uses `FrameUtil.CreateFrame(nil, self, "WowStyle1DropdownTemplate")` (`Blizzard_DebugTools/Blizzard_TexelSnappingVisualizer.lua:33`), while many other consumers inherit it in XML.

`SetupMenu(generator)` is the primary registration point. The implementation documents the generator as `function(dropdown, rootDescription) ... end` and stores it (`DropdownButton.lua:233-249`). If the dropdown is shown, generation occurs immediately so selected text can update; otherwise it is deferred to `OnShow`.

Every `OpenMenu` regenerates the root description before opening, expressly to avoid stale menu state (`DropdownButton.lua:108-124`). Generation creates the default root description, calls the generator through `securecallfunction`, and registers the result (`DropdownButton.lua:251-264`).

### 4.2 Generator and responder signatures

Signatures were verified from implementation, not inferred from naming:

- Dropdown generator: `generator(ownerRegion, rootDescription, ...extraContext)`; for `SetupMenu`, `ownerRegion` is the dropdown (`Menu.lua:2634-2636`; `DropdownButton.lua:251-263`).
- Context generator: the same signature. `MenuUtil.CreateContextMenu(ownerRegion, generator, ...)` forwards additional arguments after the root description (`MenuUtil.lua:151-161`).
- `isSelected`: `isSelected(data)` (`Menu.lua:690-700`).
- Button, radio, and checkbox responder: `responder(data, menuInputData, menuProxy)` (`Menu.lua:885-893`). `menuInputData.context` identifies the menu input context and `menuInputData.buttonName` identifies the input button.
- A description callback is therefore **not** an owner-first CallbackRegistry callback.

`DropdownButtonMixin` itself is a `CallbackRegistryMixin` and declares `OnUpdate`, `OnMenuOpen`, and `OnMenuClose` events (`DropdownButton.lua:69-77`). Those registrations follow CallbackRegistry semantics: when no explicit owner is supplied, the registered owner token is passed first (`Blizzard_SharedXMLBase/CallbackRegistry.lua:112-139,184-214`). A real Settings registration consequently defines `OnMenuOpen(dropdown)` and `OnMenuClose(dropdown, menu, closeReason)` (`Blizzard_Settings_Shared/Blizzard_SettingControls.lua:743-758`).

This creates the main callback trap:

| Callback family | First arguments |
|---|---|
| `SetupMenu` / context generator | `ownerRegion, rootDescription, ...` |
| Description `isSelected` | `data` |
| Description responder | `data, menuInputData, menuProxy` |
| `DropdownButton:RegisterCallback(...)` without explicit owner | callback owner (normally dropdown), then event arguments |

### 4.3 Description construction and submenus

`MenuUtil.CreateRootMenuDescription` creates a root and merges the standard inserter functions onto it (`MenuUtil.lua:133-136,263-276`). The normal constructors are:

- `rootDescription:CreateTitle(text[, color])`
- `rootDescription:CreateButton(text, responder[, data])`
- `rootDescription:CreateCheckbox(text, isSelected, setSelected[, data])`
- `rootDescription:CreateRadio(text, isSelected, setSelected[, data])`
- `rootDescription:CreateDivider()`
- `rootDescription:CreateSpacer([extent])`

There is no dedicated submenu constructor. Any element description with children can open a submenu (`Menu.lua:413-414`). The source guide uses:

```lua
local submenu = rootDescription:CreateButton("My Submenu")
submenu:CreateButton("Enable", SetEnabled, true)
submenu:CreateButton("Disable", SetEnabled, false)
```

See `Blizzard_Menu/11_0_0_MenuImplementationGuide.lua:24-32`.

### 4.4 State ownership and selection

The menu description delegates domain state to callbacks; the dropdown is not a general selected-value store.

- `CreateRadio` stores an `isSelected` function, a responder, and caller data (`MenuTemplates.lua:345-356`).
- `CreateCheckbox` does the same and defaults its response to `MenuResponse.Refresh` (`MenuTemplates.lua:330-342`).
- `IsSelected()` calls `isSelected(data)` each time it is evaluated (`Menu.lua:690-700`).
- The responder updates the external setting/model. The framework then applies its response policy.

`MenuResponse` values are (`MenuConstants.lua:11-23`):

- `Open`: leave the menu open and unchanged.
- `Refresh`: reinitialize all menu frames.
- `Close`: close only the leafmost menu.
- `CloseAll`: close the complete menu chain.

Checkboxes default to `Refresh`, which supports visible multi-selection. Radios have no special default response and ordinarily close through general response handling. A responder may return a `MenuResponse` to override the default.

### 4.5 Dynamic generation, refresh, and reuse

- The root generator runs when a shown dropdown is set up, on deferred show when necessary, and immediately before each open.
- Thus a generator that reads current data naturally rebuilds the menu for every opening.
- `Refresh` reinitializes the open menu's frames from the current description; it does not inherently rerun the root generator.
- `dropdown:EnableRegenerateOnResponse()` opts into rerunning the generator after responses (`DropdownButton.lua:294-304`).
- Registering a new description while the menu is open reinitializes the menu without closing it (`DropdownButton.lua:178-201`).

For ordinary addon data, reconstruct descriptions from current state on each open. Use regenerate-on-response only when a response changes the menu's structure, not merely a checkbox mark.

### 4.6 Displayed text

The selection-text mixin supports:

- `SetDefaultText(text)`
- `SetSelectionTranslator(translator)`
- `SetSelectionText(selectionFunc)`
- `OverrideText(text)`
- `UpdateToMenuSelections(...)`

See `Blizzard_Menu/MenuTemplates.lua:724-795`. The default behavior derives text from selected element descriptions and concatenates multiple selected labels unless the description requests otherwise. The selected domain value remains in external state; displayed text is a projection of selected descriptions, not proof that the dropdown owns a value.

`WowStyle1FilterDropdownTemplate` intentionally presents the fixed `FILTER` label rather than acting like an ordinary selection-text control (`Mainline/MenuTemplates.xml:66-81`; `MenuTemplates.lua:948-1001`).

### 4.7 Enabled state and tooltips

Descriptions support enabled and selectable predicates. `SetEnabled` accepts a boolean or function (`Menu.lua:830-847`), and functional element state is polled at the framework interval of 0.2 seconds (`MenuConstants.lua:7`; `MenuTemplates.lua:177-180`). `CanSelect` also fails when an element is disabled (`Menu.lua:702-710`).

The description inserter surface includes `SetTooltip(initializer)` and `SetTitleAndTextTooltip(title, text)` (`MenuUtil.lua:282-327`). Current Achievements code demonstrates `radio:SetTooltip(function(tooltip, elementDescription) ... end)` (`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua:276-285`).

## 5. Dropdown template comparison

| Template | Source-defined appearance | Text behavior | Normal fit | Source-supported direct use |
|---|---|---|---|---|
| `WowStyle1DropdownTemplate` | 120x25; `common-dropdown-textholder`; visible right arrow; left-aligned `GameFontHighlight` | Selected-description text | Strongest ordinary compact select candidate | Yes; widespread XML inheritance and direct frame creation |
| `WowStyle1ArrowDropdownTemplate` | 25x25; arrow only | No ordinary selection text region | Toolbar or compact menu opener | Yes, but specialized by presentation |
| `WowStyle1FilterDropdownTemplate` | 135x18; `common-dropdown-b-button`; fixed `FILTER`; resize-to-text padding 60; reset button | Fixed filter label | Multi-filter opener, not a normal value select | Yes; widespread filter-menu use |
| `WowStyle2DropdownTemplate` | 122x25; `common-dropdown-c-button`; centered `GameFontNormal`; hover arrow; reset button retained for an exceptional Trading Post use | Selected-description text | Settings/customization-style control | Yes; modern but visually specialized |

Definitions: `Blizzard_Menu/Mainline/MenuTemplates.xml:3-117` and `Blizzard_Menu/MenuTemplates.xml:4-53`.

Style 1 menus use `MenuStyle1Mixin` (`Blizzard_Menu/Mainline/MenuTemplates.lua:51-85`). Style 2 sets `menuMixin=MenuStyle2Mixin` and therefore carries its corresponding background/inset style (`MenuTemplates.xml:4-8`; `MenuTemplates.lua:1133-1153`).

The Style 2 implementation comment identifies it with Settings and Character Creation/Customization (`MenuTemplates.lua:1003-1008`). Current source also uses it in unrelated newer features including Damage Meter and Housing, so it is not private to Settings. Nevertheless, Style 1 is the clearer general-purpose visual for a compact addon configuration page because it is the ordinary selectable dropdown used across many unrelated Mainline features. Use Style 2 when its centered Settings-like visual is intentionally desired.

No `WowStyle2FilterDropdownTemplate` exists. Do not infer one from the parallel naming.

## 6. Representative current Blizzard usage

### 6.1 AddOn List — ordinary dynamic single-select

- Template: `WowStyle1DropdownTemplate` (`Blizzard_AddOnList/AddonList.xml:126`).
- Population: dynamic radio descriptions for all characters/current character (`AddonList.lua:628-654`).
- State: file-level `addonCharacter`; `IsSelected(character)` compares it and `SetSelected(character)` changes it, then updates the list (`AddonList.lua:614-621`).
- Reusability: strong general example. It demonstrates external state, caller data, and rebuild from current character data.

### 6.2 Achievements — radio choices with per-entry tooltip

- Template: `WowStyle1FilterDropdownTemplate` (`Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.xml:1702`).
- Population: iterates `AchievementFrameFilters` into radios (`Blizzard_AchievementUI.lua:276-285`).
- State: selected filter function held outside the dropdown.
- Callback model: standard `isSelected(data)` / responder `(data, ...)`, plus a description tooltip initializer.
- Reusability: strong example for tooltipped radios; the filter-button presentation is use-case-specific.

### 6.3 Auction House — dynamic checkbox menu and custom element

- Template: `AuctionHouseFilterButtonTemplate`, derived from `WowStyle1FilterDropdownTemplate` (`Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSearchBar.xml:19`).
- Population: current auction filter groups become titled checkbox sections (`Blizzard_AuctionHouseSearchBar.lua:140-174`).
- Custom content: `CreateTemplate("LevelRangeFrameTemplate")` with an initializer adds a live range editor (`:143-163`).
- State: `g_auctionHouseFilters`; checkbox queries and responders read/update it (`:130-137,165-170`).
- Reusability: the checkbox-description pattern is general; its custom level-range frame and auction state are feature-specific.

### 6.4 Mount Journal — checkboxes, submenu, and context menu

- Template: `WowStyle1FilterDropdownTemplate` (`Blizzard_Collections/Mainline/Blizzard_MountCollection.xml:413`).
- Filter menu: top-level checkboxes, titles, spacer, dynamically enumerated type filters, and a Sources submenu (`Blizzard_MountCollection.lua:218-259`).
- Submenu: `local sourceSubmenu = rootDescription:CreateButton(SOURCES)`, followed by child buttons and checkboxes (`:250-258`).
- Context menu: a shared generator receives `(owner, rootDescription, index)`, derives state for the selected mount, creates buttons, and applies `SetEnabled` (`:262-307`). Right-click callsites pass the clicked region and list index to `MenuUtil.CreateContextMenu` (`:914-940`).
- Reusability: strong general examples for nested descriptions and context arguments; mount operations are feature-specific.

### 6.5 Settings — registered setting-backed dropdown

- API: `Settings.CreateDropdown(category, setting, options, tooltip)` creates and adds a dropdown initializer (`Blizzard_Settings_Shared/Blizzard_Settings.lua:373-375,409-412`).
- A source example builds options with `Settings.CreateControlTextContainer`, registers a proxy setting, and creates the dropdown (`Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua:148-186`).
- Current Accessibility code uses the same pattern with a callable options provider (`Blizzard_SettingsDefinitions_Frame/Accessibility.lua:102-114`).
- Reusability: appropriate when the addon is intentionally registering a Blizzard Settings category/control; not a reason to import Settings layout internals into an arbitrary addon frame.

## 7. Settings integration

### VERIFIED SOURCE FACTS

Settings wraps the general menu infrastructure rather than maintaining a separate menu engine:

1. `Settings.CreateDropdown` creates a `SettingsDropdownControlTemplate` initializer and adds it to a Settings layout (`Blizzard_Settings.lua:373-375,409-412`).
2. `SettingsDropdownControlMixin` creates `SettingsDropdownWithButtonsTemplate`, sizes the dropdown to 220, registers menu-open/close callbacks, integrates narration/tooltips, builds the menu, and manages steppers (`Blizzard_SettingControls.lua:723-795`).
3. `SettingsDropdownWithButtonsTemplate` derives from `Metal2DropdownWithSteppersAndLabelTemplate`, whose child is a `DropdownButton` inheriting `WowStyle2DropdownTemplate` (`Blizzard_SettingControls.xml:170-190`).
4. `Settings.CreateDropdownOptionInserter` converts option data into modern highlight-radio or checkbox descriptions backed by a Setting (`Blizzard_Settings.lua:488-543`).
5. `Settings.InitDropdown` calls the same `dropdown:SetupMenu(...)` API (`Blizzard_Settings.lua:546-573`).

Settings-specific inputs include a registered `Setting`, category/layout ownership, an options provider, Settings initializer data, Settings tooltip behavior, narration, and optional stepper behavior. Those pieces are coupled to Settings infrastructure.

### ENGINEERING RECOMMENDATION / INFERENCE

- If the control belongs in Blizzard's Settings panel, register the addon category/setting and use `Settings.CreateDropdown`.
- If the control belongs in an addon-owned panel or companion dialog, use a general `DropdownButton` visual directly. Do not instantiate `SettingsDropdownControlTemplate` merely for its appearance.
- `WowStyle2DropdownTemplate` itself is globally available through `Blizzard_Menu` and can reasonably be used independently when its look is wanted; the Settings control wrapper is the coupled part.

## 8. Context menus

`MenuUtil.CreateContextMenu(ownerRegion, generator, ...)` is the source-supported reusable entry point (`MenuUtil.lua:139-167`). It:

1. substitutes the appropriate top-level parent if no owner is given;
2. creates a root description using the owner's/default context-menu mixin;
3. populates it with `generator(ownerRegion, rootDescription, ...)`;
4. opens it through the menu manager.

The menu manager anchors the root menu at the cursor with `InputUtil.AnchorRegionToCursor(menuFrame, "TOPLEFT")` (`Menu.lua:2510-2526`). The owner is used so hiding the owner closes the menu; the migration guide also documents that lifecycle (`11_0_0_MenuImplementationGuide.lua:76-83`). Context and dropdown menus share the same element descriptions, responders, nested-menu behavior, and menu manager.

This API is global, part of globally loaded `Blizzard_Menu`, and repeatedly used across unrelated Blizzard features. It is therefore a source-supported candidate for normal addons.

## 9. Legacy `UIDropDownMenu` and `EasyMenu`

### 9.1 `UIDropDownMenu`

The legacy implementation and templates still exist and are loaded:

- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.xml`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenuTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenuTemplates.xml`
- TOC loading: `Blizzard_SharedXML/Blizzard_SharedXML.toc:205-208`

Legacy globals such as `UIDropDownMenu_Initialize`, `UIDropDownMenu_CreateInfo`, `UIDropDownMenu_AddButton`, `ToggleDropDownMenu`, and `CloseDropDownMenus` remain. `UIDropDownMenuTemplate` is still declared in `UIDropDownMenuTemplates.xml:146`.

Its status is not merely inferred from age. Blizzard's own 11.0 migration guide explicitly states that `Blizzard_Menu` is the complete replacement, Blizzard uses were converted, and `UIDropDownMenu` is deprecated (`Blizzard_Menu/11_0_0_MenuImplementationGuide.lua:1-7`).

Focused Mainline search found:

- one hidden `UIDropDownMenuTemplate` child in `Blizzard_PVPUI/Mainline/Blizzard_PVPUI.xml:846`, with active PVP dropdowns elsewhere using `WowStyle1DropdownTemplate` and `SetupMenu`;
- `Blizzard_SettingsDefinitions_Frame/Mainline/ColorblindOverrides.lua:118` creating a legacy info table for `ColorPickerFrame:SetupColorPickerAndShow`, not building a dropdown menu;
- no clean active Mainline `UIDropDownMenu` menu consumer representative of new Blizzard practice.

Classic-family files may still use the legacy system; that does not make it the current Retail Mainline architecture.

### 9.2 `EasyMenu`

A case-insensitive full LIVE repository search found no `EasyMenu` identifier. Therefore this source snapshot provides neither an implementation nor a current Blizzard callsite to support it as a Retail recommendation.

### 9.3 Engineering disposition

Use legacy `UIDropDownMenu` only when maintaining existing legacy code, sharing code with an environment that requires it, or integrating with another legacy surface that cannot reasonably be migrated. For a new Retail-only addon control, use `Blizzard_Menu`.

## 10. Combat, taint, ownership, and layering

### VERIFIED SOURCE FACTS

- Focused search in `Blizzard_Menu` found no `InCombatLockdown`, `PLAYER_REGEN_*`, or explicit combat gate.
- The framework uses secure proxies and `securecallfunction` at multiple boundaries. This is implementation structure, not a guarantee that arbitrary addon callbacks or owner frames are combat-safe.
- Menus default to `FULLSCREEN_DIALOG` strata. If the owner is on `TOOLTIP`, the menu is raised to `TOOLTIP` (`Menu.lua:2137-2151`).
- Menu frame level is owner level plus 500 to clear NineSlice layers, or 9500 without a usable owner, then adjusted by menu depth (`Menu.lua:2405-2418`).
- Context-menu ownership determines hide-to-close behavior. Dropdowns retain their generator/description while menu frames are managed and recycled by the framework.
- The root dropdown generator is called through `securecallfunction`.

### UNKNOWN / REQUIRES RUNTIME VALIDATION

- Whether opening, rebuilding, or responding to each proposed addon menu remains harmless during combat for the addon's exact owner frame and callback actions.
- Whether interacting with protected or forbidden owner regions changes availability or taint behavior.
- Whether a menu opened from a custom high-strata modal/dialog always layers and clamps as intended at every UI scale and screen edge.
- Whether addon-provided custom menu templates/initializers remain visually stable when menus are pooled and reinitialized.

### ENGINEERING RECOMMENDATION / INFERENCE

- Treat the dropdown or clicked region as the stable owner; do not retain pooled menu frames as addon state.
- Do not assume frame identity or lifetime beyond documented callback arguments.
- Keep domain selection state outside menu descriptions and rebuild descriptions from the current model.
- Do not mutate protected gameplay state from a responder in combat unless that operation is independently known to be allowed.
- Test dialog-hosted menus at normal and elevated frame strata, near all screen edges, and with UI scale changes.
- Explicitly test combat rather than interpreting the absence of a framework combat check as permission.

## 11. Third-party addon engineering assessment

1. **New addon-owned single-select:** `CreateFrame("DropdownButton", ..., "WowStyle1DropdownTemplate")`, `SetupMenu`, and radio descriptions. Keep the selected value in addon state.
2. **Dynamic dropdown:** use the same control; have the generator enumerate current data. It is regenerated immediately before every open.
3. **Radio selections:** `CreateRadio(label, isSelected, setSelected, data)`.
4. **Checkbox/multi-select menu:** `CreateCheckbox(...)`; its default `Refresh` response keeps the menu useful for repeated filtering. Use `WowStyle1FilterDropdownTemplate` when a fixed Filter presentation is appropriate.
5. **Nested choices:** create a normal element description, usually `CreateButton`, then add child descriptions to it.
6. **Right-click/context menu:** `MenuUtil.CreateContextMenu(clickedRegion, generator, ...context)`.
7. **Legacy:** do not choose `UIDropDownMenu` for new Retail-only work. No current `EasyMenu` exists in this source snapshot.
8. **Blizzard Settings:** use `Settings.CreateDropdown` when intentionally registering setting-backed controls in a Settings category.
9. **Compact custom Config pages:** `WowStyle1DropdownTemplate` is the strongest ordinary select; `WowStyle1FilterDropdownTemplate` is strongest for filter menus. `WowStyle2DropdownTemplate` is viable when the centered Settings-like style is intentional.
10. **Before production:** validate combat behavior, owner hiding, menu reopening after model changes, checkbox refresh, dynamic structural regeneration, text synchronization, high-strata dialog layering, screen-edge anchoring, scale, narration, and keyboard/controller interaction.

Common pitfalls:

- inventing `DropdownButtonTemplate`, `WowStyle2FilterDropdownTemplate`, or `CreateSubmenu`;
- treating generator, responder, and CallbackRegistry signatures as interchangeable;
- expecting the dropdown to own the selected domain value;
- changing data without ensuring the description/text is regenerated or updated;
- using the fixed-label Filter variant for an ordinary selected-value field;
- retaining framework-owned menu frames;
- assuming source-level secure calls establish combat safety for addon actions.

## 12. LIVE runtime validation

The standalone `Samples/DropdownMenuComparison` addon was installed and exercised on Retail LIVE. It loaded and opened without a Lua error.

### RUNTIME EVIDENCE

- `WowStyle1DropdownTemplate` rendered correctly. Alpha, Beta, and Gamma behaved as exclusive radios; selected text and addon-owned summary state updated and remained correct when the menu reopened.
- `WowStyle2DropdownTemplate` worked through direct addon-owned creation without Settings registration. Its radios, selected text, and state-on-reopen behavior passed.
- One persistent Style 1 frame regenerated across all three dynamic datasets through `SetupMenu`. Dataset changes, selection normalization, visible selected text, and radio state were correct.
- `WowStyle1FilterDropdownTemplate` supported independent multi-select checkboxes, with the addon-owned summary remaining synchronized.
- A normal description with children produced the nested Rendering menu. Compact, Normal, and Large child radios worked without any `CreateSubmenu` API.
- `MenuUtil.CreateContextMenu` opened on right-click; both harmless actions worked and the disabled item remained disabled.
- In the isolated non-secure sample, Style 1 and Style 2 selection, dynamic selection and regeneration, checkbox toggles, context-menu opening, and context actions all worked in combat without errors or blocks.
- The sample's combat indicator was retested successfully after mapping `PLAYER_REGEN_DISABLED` directly to the in-combat state and `PLAYER_REGEN_ENABLED` directly to the out-of-combat state. `InCombatLockdown()` remains only as the drag guard.

The combat result is intentionally narrow. It does **not** establish that arbitrary configuration changes, protected actions, secure frames, downstream callbacks, or unrelated addon code are universally combat-safe or taint-free.

### ENGINEERING OBSERVATIONS / INFERENCE

- Style 1 was compact and traditional: selected text was left aligned and the arrow remained a separate visual affordance. It was the strongest fit for dense addon configuration UI.
- Style 2 was broader and more prominent, with centered gold button-like text. It is directly reusable, but its stronger visual weight should be chosen deliberately.
- The Filter variant's fixed label suited a multi-select action rather than an ordinary value field.
- Once opened, the generated menu presentation was broadly common across the owner-button styles; the most meaningful visual difference was the closed owner control.

### REMAINING OPTIONAL VALIDATION

Right- and bottom-edge behavior, cross-dialog layering, keyboard interaction, gamepad interaction, and narration were not exhaustively validated. These remain useful follow-up checks for a production host frame, but they do not block the architectural recommendation or this sample publication.

These are runtime observations from LIVE, not PTR findings. PTR was not consulted.

## 13. Completed sample

The focused `Samples/DropdownMenuComparison` addon now accompanies this research. It contains:

1. `WowStyle1DropdownTemplate` with radios;
2. a persistent dynamic Style 1 dropdown that regenerates from external state;
3. `WowStyle2DropdownTemplate` for direct-use visual and text comparison;
4. `WowStyle1FilterDropdownTemplate` with independent checkboxes;
5. one child-description submenu;
6. one `MenuUtil.CreateContextMenu` example with enabled and disabled actions;
7. an event-driven combat indicator and an out-of-combat-only drag guard.

The sample intentionally excludes legacy `UIDropDownMenu`, Settings registration, SavedVariables, secure templates, and gameplay actions. Its README records the completed LIVE results, two sample-only bug corrections, the combat caveat, and remaining optional follow-up checks.

## 14. Verified facts versus engineering inference

### VERIFIED

- The definitions, inheritance, dimensions, callback invocation, regeneration behavior, description constructors, response defaults, context anchoring, Settings wrapping, legacy files, explicit deprecation statement, and representative callsites cited above are present in LIVE commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`.
- Exact identifiers absent from this snapshot: `DropdownButtonTemplate`, `WowStyle2FilterDropdownTemplate`, `CreateSubmenu`, `CreateSubMenu`, and `EasyMenu`.
- No explicit combat gate was found in `Blizzard_Menu`.

### ENGINEERING INFERENCE

- Style 1 is the strongest default for compact addon-owned configuration UI because its implementation and broad unrelated usage match ordinary selection controls.
- Style 2 is reusable but should be chosen deliberately for its visual family rather than assumed to be the universal newer replacement.
- The legacy system should be retained only for concrete compatibility constraints.
- The isolated sample runtime supports the recommended ordinary addon-owned patterns, including its tested inert combat interactions. Production-specific combat actions, taint, dialog layering, and full input-mode behavior still require validation in their actual host.

## 15. Final conclusions

The modern Retail answer is the globally loaded `Blizzard_Menu` description framework. A normal addon uses the intrinsic `DropdownButton`, normally with `WowStyle1DropdownTemplate`, and attaches a generator with `SetupMenu`. The generator rebuilds descriptions from current external state. Radios and checkboxes query and update that state through verified description callback signatures; submenus are descriptions containing children. Context menus use `MenuUtil.CreateContextMenu` and the same model.

The completed LIVE comparison sample confirmed direct Style 1, Style 2, Filter, dynamic, nested, and context-menu behavior in an addon-owned non-secure frame. Style 1 remains the practical default for dense configuration UI; Style 2 is a valid, more prominent centered alternative. The successful isolated combat pass does not broaden into a guarantee for protected actions, secure frames, arbitrary callbacks, or taint behavior.

Blizzard Settings does not replace this framework: it wraps it with registered Setting objects, initializer/layout ownership, narration, tooltips, steppers, and a Style 2 visual. Use that wrapper for intentional Settings integration and the general dropdown directly for addon-owned panels.

`UIDropDownMenu` remains in the shipped source but is explicitly deprecated by Blizzard's migration guide. `EasyMenu` is absent. Neither is the source-supported starting point for new Retail-only code.

## 16. Primary source index

- `Interface/AddOns/Blizzard_Menu/Blizzard_Menu.toc`
- `Interface/AddOns/Blizzard_Menu/DropdownButton.lua`
- `Interface/AddOns/Blizzard_Menu/DropdownButton.xml`
- `Interface/AddOns/Blizzard_Menu/Menu.lua`
- `Interface/AddOns/Blizzard_Menu/MenuConstants.lua`
- `Interface/AddOns/Blizzard_Menu/MenuTemplates.lua`
- `Interface/AddOns/Blizzard_Menu/MenuTemplates.xml`
- `Interface/AddOns/Blizzard_Menu/MenuUtil.lua`
- `Interface/AddOns/Blizzard_Menu/Mainline/MenuTemplates.lua`
- `Interface/AddOns/Blizzard_Menu/Mainline/MenuTemplates.xml`
- `Interface/AddOns/Blizzard_Menu/Mainline/MenuVariants.lua`
- `Interface/AddOns/Blizzard_Menu/11_0_0_MenuImplementationGuide.lua`
- `Interface/AddOns/Blizzard_SharedXMLBase/CallbackRegistry.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenu.xml`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenuTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/UIDropDownMenuTemplates.xml`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.xml`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua`
- `Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Accessibility.lua`
- `Interface/AddOns/Blizzard_AddOnList/AddonList.lua`
- `Interface/AddOns/Blizzard_AddOnList/AddonList.xml`
- `Interface/AddOns/Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua`
- `Interface/AddOns/Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.xml`
- `Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSearchBar.lua`
- `Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSearchBar.xml`
- `Interface/AddOns/Blizzard_Collections/Mainline/Blizzard_MountCollection.lua`
- `Interface/AddOns/Blizzard_Collections/Mainline/Blizzard_MountCollection.xml`
