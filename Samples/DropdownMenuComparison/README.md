# Dropdown Menu Comparison

## Purpose

This is a focused standalone Retail LIVE research addon for validating the modern Blizzard dropdown and menu architecture documented in [DropdownsAndMenus.md](../../12.1.0/Analysis/DropdownsAndMenus.md).

It is not production framework code and has no dependency on OdysseusBuffBars, OdysseusUtilitySuite, Nightwatch, Blizzard Settings registration, or another addon. It uses no SavedVariables, libraries, secure templates, gameplay automation, polling, or `OnUpdate` loop.

## Source baseline

- Retail client: `12.1.0.69497`
- LIVE source: `D:\WowDEV\Reference\Blizzard\wow-ui-source`
- LIVE source commit: `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
- PTR: not consulted and not part of this task

`DropdownMenuComparison.png` is the Retail LIVE default-window screenshot and visual reference for this sample.

## Installation and opening

1. Manually copy the complete `DropdownMenuComparison` directory into `_retail_/Interface/AddOns/`.
2. Start Retail LIVE or reload the UI.
3. The comparison window opens on `PLAYER_LOGIN`.
4. Use `/dropdownmenucomparison` or `/dmc` to toggle it.
5. Drag the window background while out of combat to reposition it. Position is intentionally not saved.

The TOC declares only `Blizzard_SharedXML`. That shared addon depends on globally loaded `Blizzard_Menu` and supplies the established `DialogBorderDarkTemplate`, `DialogHeaderTemplate`, ordinary button templates, and close button used by the sample shell.

## Controls included

### 1. Standard single-select and Style 1

The Style 1 control is created as an intrinsic `DropdownButton` inheriting `WowStyle1DropdownTemplate`. Its `SetupMenu` generator adds Alpha, Beta, and Gamma as radio descriptions.

The selected string is stored in the sample's local `state.style1Selection`; the dropdown does not own the domain value. Selecting a radio updates the local state, the adjacent summary, the dropdown's selected-description text, and chat output.

### 2. Dynamic regeneration

One persistent `WowStyle1DropdownTemplate` cycles among:

1. One, Two, Three
2. Red, Green
3. Small, Medium, Large, Huge

`Change Dynamic Options` changes only addon-owned dataset state. It does not rebuild the dropdown frame or cache a menu frame. The `SetupMenu` generator reads the current dataset when Blizzard regenerates the description immediately before the next opening.

If the previous selection is absent from the new dataset, the button handler explicitly normalizes addon-owned selection state to the first new option. The adjacent summary immediately reports the new dataset and normalized value. Opening the dropdown then tests Blizzard's required fresh generation and displayed-text update.

### 3. Checkbox menu and filter style

`WowStyle1FilterDropdownTemplate` provides the source-defined fixed Filter presentation. Its menu contains independent checkbox descriptions for Names, Durations, and Icons.

The booleans live in `state.checkboxes`. Each `isSelected(data)` predicate reads one boolean and each responder toggles it. Blizzard's checkbox description supplies the normal `MenuResponse.Refresh` default, allowing the open menu to reflect repeated changes. The adjacent summary is addon-owned and does not pretend the filter dropdown has a single internal value.

### 4. Nested menu

The nested control does not call or invent `CreateSubmenu`. Its generator creates a normal button description named Rendering, then adds Compact, Normal, and Large radio descriptions as that description's children. `state.rendering` owns the selected value.

### 5. Context menu

The ordinary button registers left- and right-button clicks. A right-click calls:

```lua
MenuUtil.CreateContextMenu(owner, generator, contextData)
```

The context generator creates two harmless chat-print actions and one disabled entry. It does not create, position, cache, or retain a menu frame; Blizzard_Menu owns the context menu and anchors it at the cursor.

### 6. Style 2 comparison

The second side-by-side single-select directly creates a `DropdownButton` inheriting `WowStyle2DropdownTemplate`. This does not require a Setting, Settings category, initializer, or `Blizzard_Settings_Shared` dependency.

This direct use is supported by the common Blizzard_Menu template and current non-Settings use such as `Blizzard_DamageMeter/DamageMeterSessionWindow.xml`, whose Style 2 dropdown is populated with ordinary `SetupMenu` radio descriptions. Style 1 and Style 2 use the same three labels but intentionally keep independent state so each control's displayed text can be observed without cross-control synchronization code.

## Callback signatures verified from LIVE source

The sample avoids `DropdownButton:RegisterCallback` because no CallbackRegistry event is needed.

The callbacks it does use follow these verified dispatch rules:

| Callback | LIVE invocation | Sample behavior |
|---|---|---|
| Dropdown `SetupMenu` generator | `generator(dropdown, rootDescription)` | Ignores the dropdown and inserts descriptions into the root |
| Context generator | `generator(ownerRegion, rootDescription, ...context)` | Receives the right-click owner and forwarded context string |
| Radio/checkbox predicate | `isSelected(data)` | Reads addon-owned state using the supplied value/key |
| Radio/checkbox/button responder | `responder(data, menuInputData, menuProxy)` | Intentionally consumes only `data`; Lua ignores unused trailing arguments |

Implementation evidence:

- `Blizzard_Menu/DropdownButton.lua:233-263`
- `Blizzard_Menu/Menu.lua:690-700,885-893,2634-2636`
- `Blizzard_Menu/MenuTemplates.lua:330-356`
- `Blizzard_Menu/MenuUtil.lua:151-161,198-274`

## Verified from source

- `DropdownButton` is an intrinsic frame type.
- `WowStyle1DropdownTemplate`, `WowStyle1FilterDropdownTemplate`, and `WowStyle2DropdownTemplate` are virtual templates for that intrinsic type.
- A dropdown regenerates its menu before each opening.
- Radio and checkbox state is queried through caller-provided predicates.
- Checkbox descriptions default to `MenuResponse.Refresh`.
- A description with child descriptions becomes a submenu.
- `MenuUtil.CreateContextMenu` uses the same description architecture and delegates cursor anchoring to Blizzard_Menu.
- Style 2 is usable outside Blizzard Settings; this sample uses no Settings machinery.
- No explicit `Blizzard_Menu` combat gate was found during the source research.

These source facts were subsequently exercised by the focused LIVE runtime pass below.

## Completed LIVE runtime results

The installed sample loaded and opened without a Lua error.

- **Style 1 — PASS:** the control rendered correctly; Alpha, Beta, and Gamma behaved as exclusive radios; selected text and the adjacent summary updated and remained correct on reopen.
- **Style 2 — PASS:** direct addon-owned creation worked without Settings registration. Radios, selected text, and state on reopen all worked. Visually it was broader and more prominent than Style 1, with centered gold button-like text.
- **Dynamic regeneration — PASS:** the same persistent frame regenerated through all three datasets via `SetupMenu`. Dataset changes, selection normalization, selected text, and radio state were correct.
- **Checkbox/filter — PASS:** Names, Durations, and Icons toggled independently as multi-select checkboxes, and the addon-owned summary stayed synchronized.
- **Nested choices — PASS:** the Rendering child description exposed Compact, Normal, and Large radios without `CreateSubmenu`; child selection text and state worked.
- **Context menu — PASS:** right-click opened `MenuUtil.CreateContextMenu`; Action A and Action B worked, and Disabled Example remained disabled.
- **Combat indicator — PASS after correction:** the label changed into and out of combat through direct event-to-state mapping.

### Visual observations

- Style 1 was compact and traditional, with left-aligned selected text and a separate arrow. It was the strongest fit for a dense addon Config page.
- Style 2 had a broader, centered gold button-like presentation and greater visual prominence.
- The Filter control's fixed label suited a multi-select action rather than a single selected-value field.
- The generated menu presentation was broadly common across the owner styles; the main visual difference was the closed owner control.

### Isolated combat pass

While in combat, Style 1 and Style 2 selection, dynamic selection and regeneration, checkbox toggles, context-menu opening, and both context actions all worked without an error or block in this non-secure sample.

This result is deliberately narrow. It does **not** mean arbitrary configuration changes, protected actions, secure frames, downstream callbacks, unrelated owner frames, or taint-sensitive production code are universally safe in combat. Any real addon action must be validated in its actual owner and execution path.

### Sample-only bug corrections

- The initial login error came from using `string.gsub` as the final expression passed to `table.insert`. Because `string.gsub` returns both the transformed string and a replacement count, Lua expanded the call into the three-argument `table.insert(table, position, value)` form and supplied a string where the numeric position belongs. Parenthesizing the `gsub` expression forced a single return value. No other `table.insert` call had this issue.
- The first combat-state label used a general state query in the event path. It was replaced with direct mapping: `PLAYER_REGEN_DISABLED` calls `UpdateCombatState(true)`, `PLAYER_REGEN_ENABLED` calls `UpdateCombatState(false)`, and `PLAYER_LOGIN` initializes `UpdateCombatState(false)`. `InCombatLockdown()` remains only in the drag guard. The indicator was retested successfully.

Both corrections belong to the sample harness; neither changes or qualifies the underlying Blizzard_Menu architecture.

## Controls intentionally omitted

- `UIDropDownMenu` and `UIDropDownMenuTemplate`: Blizzard's migration guide explicitly marks the architecture deprecated, and this sample has no unresolved legacy question.
- `EasyMenu`: absent from the current LIVE source.
- Blizzard Settings controls: not needed for addon-owned frames and would introduce registered Setting/initializer/layout lifecycle irrelevant to this probe.
- `WowStyle1ArrowDropdownTemplate`: its arrow-only presentation does not answer an additional state or lifecycle question.
- A separate filter system: the checkbox test already provides the small, source-supported fixed-label Filter visual comparison.
- Custom menu anchors, flipping, clamping, and strata changes: those are Blizzard behaviors this sample is intended to observe.
- SavedVariables and position persistence: deliberately unnecessary for a disposable comparison sample.

## Optional follow-up checklist

The core comparison and isolated combat interaction pass are complete. The following environment-dependent checks remain useful for a production host but are not publication blockers.

### Screen-edge and layering

1. Move the window near the right screen edge.
2. Open Style 1, Style 2, dynamic, filter, and nested menus; observe direction, clamping, and submenu placement.
3. Right-click the context button near the right edge and observe cursor anchoring.
4. Move the window near the bottom edge and repeat.
5. Open another Blizzard dialog or addon frame and repeat the menu tests.
6. Confirm menus appear above the owning comparison window without interlacing with its border/header.
7. Repeat at the user's normal UI scale and at one deliberately different scale if practical.

The sample deliberately implements no custom flipping, anchor correction, menu strata, or frame-level workaround.

### Remaining optional validation

- Right- and bottom-edge root/submenu behavior at multiple positions and UI scales.
- Context owner-hide lifecycle under additional host-window arrangements.
- Menu strata/frame-level behavior across other Blizzard and addon dialogs.
- Keyboard, gamepad, and narration behavior.
- Production-specific taint behavior when unrelated protected Blizzard frames are visible.

Do not convert observations into production compatibility rules until they have been reproduced and documented.
