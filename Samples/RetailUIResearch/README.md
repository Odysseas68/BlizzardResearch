# RetailUIResearch

`RetailUIResearch` is an unofficial third-party development and research harness for nine Retail LIVE-tested UI-control modules and one focused Async item-callback diagnostic retained from the completed investigation. They can be installed and opened from one small launcher without duplicating addon metadata or auto-opening every research window.

This is a test harness, not production addon infrastructure. Patterns demonstrated by a module should not be copied into a production addon without considering its corresponding research conclusions, combat behavior, taint risks, ownership model, and product requirements.

## Architecture

The root addon contains one TOC, a deliberately small `Core.lua`, `Launcher.lua`, and an Async diagnostic bootstrap that installs the passive observers before Core. Each directory under `Modules/` retains its own Lua implementation, README, and any user-authored LIVE screenshot.

Each module eagerly creates and owns its existing root sample frame and local research state, then registers metadata containing an ID, display name, and frame with `RetailUIResearch:RegisterSample`. Eager creation minimizes changes to the previously LIVE-validated initialization and callback paths. Core coordinates visibility only: opening a sample hides the previously selected sample, and reopening a hidden sample shows its existing frame and state.

Core does not provide Blizzard-control wrappers, and modules do not call implementation helpers from sibling modules.

## Retail LIVE harness validation

The consolidated harness was tested by the user on Retail LIVE `12.1.0.69497`.

- On login/reload, only the launcher opened; no module window auto-opened.
- All six modules present at consolidation opened from their launcher buttons. EditBoxComparison and ScrollBoxComparison completed their supplied LIVE runtime tests out of combat and during actual combat. ColorPickerComparison was added afterward and completed its native lifecycle, singleton, scale/layering, and qualified actual-combat runtime pass. DialogsAndPopupsComparison subsequently completed its callback-order, keyboard-versus-mouse, cover, scale, and narrow actual-combat runtime pass.
- TooltipComparison completed its experimental sequence on Retail LIVE `12.1.0.69587`. Phase 1 established the ordinary P controls and data-backed I1/S1 paths; Phase 2A established the unmatched restricted R rejections; Phase 2B established the creation-time matched M successes. Combat and scale evidence remains bounded by the module README's exact non-Cartesian coverage. The final gap audit found no justified Phase 2C.
- Selecting another module hid the previously selected module.
- Closing a module left the launcher usable, and clicking its launcher button reopened it.
- Retained module slash commands opened/toggled the correct module through Core and participated in the one-sample-at-a-time behavior.
- No Lua errors were observed during the supplied harness test.

## Launcher and commands

The launcher opens after `PLAYER_LOGIN`, remains available while a sample is open, and uses a compact vertical stack of ordinary `UIPanelButtonTemplate` buttons. Its height derives from the number of launcher entries, so later modules extend the same column without redesigning the window:

- Async Item Callbacks
- Sliders
- Buttons & Frames
- Dropdowns & Menus
- Checkboxes & Radios
- EditBoxes
- ScrollBox
- Color Picker
- Dialogs / Popups
- Tooltips

Use `/retailuiresearch` to toggle the launcher. The existing compatibility/debug commands remain available and route through the same visibility coordinator:

- `/slidercomparison` or `/sliders`
- `/buttonframecomparison` or `/bbfsample`
- `/dropdownmenucomparison` or `/dmc`
- `/checkboxradiocomparison` or `/crc`
- `/editboxcomparison` or `/ebc`
- `/scrollboxcomparison` or `/sbc`
- `/colorpickercomparison` or `/cpc`
- `/dialogsandpopupscomparison` or `/dapc`
- `/tooltipcomparison` or `/ttc`
- `/asyncitemcallbacks` or `/aicd`

## Modules and evidence ownership

- `Modules/SliderComparison/`
- `Modules/ButtonFrameComparison/`
- `Modules/DropdownMenuComparison/`
- `Modules/CheckboxRadioComparison/`
- `Modules/EditBoxComparison/`
- `Modules/ScrollBoxComparison/`
- `Modules/ColorPickerComparison/`
- `Modules/DialogsAndPopupsComparison/`
- `Modules/TooltipComparison/`
- `Modules/AsyncItemCallbacksDiagnostic/`

Every module README remains authoritative for that sample's purpose, source baseline, runtime findings, limitations, and test procedure. The completed modules retain their user-authored LIVE visual references beside their Lua and README; `ColorPickerComparison` retains two screenshots and `DialogsAndPopupsComparison.png` is the Dialogs / Popups default-window reference. `TooltipComparison` has completed its Phase-1 implementation, primary LIVE clean-control runtime pass, representative P1-P5/I1/S1 screenshot capture, and static validation. Its separate Phase-2A synthetic restricted-layout surface completed its LIVE pass at 100% scale out of combat: R1 and R2 were rejected at `SetOwner`, while R3 established `UIParent` ownership and was rejected at the restricted-relative `SetPoint`; all three errors named `UntrustedLayoutScriptExecution`. Phase 2B adds a second dedicated tooltip carrying the matching synthetic condition through creation-time template composition. M1-M3 passed at 100% scale out of combat and in a genuine-combat pass, with visible tooltips, successful cleanup, and no Lua or forbidden-layout errors; root scale was also changed among 75%, 100%, and 125% during combat without error, but exact per-test coverage differed by scale and was not a complete Cartesian matrix. Three Phase-2B screenshots are preserved with the module. This controlled result is not identical to Blizzard's dynamic aspect-copying path, does not establish a universal replacement, and does not authorize an OBB change. The final gap audit found no justified Phase 2C, so TooltipComparison experimental research is complete. Tabs source research subsequently completed without a runtime phase; the sample's Phase 1 / Phase 2 selectors remain ordinary buttons and provide no evidence about native tab APIs. `ColorPickerComparison` records a qualified combat result and an unresolved gameplay-input observation. `ScrollBoxComparison` completed its supplied fixed-list, variable-extent, grid, one-child ScrollFrame, resize/scale, diagnostic-copy, and narrow non-secure combat tests. `DialogsAndPopupsComparison` verified that an uncovered StaticPopup blocked the tested normal action keybind while direct mouse activation of the same usable action worked, that `fullScreenCover` separately blocked background interaction, that sample-owned and UIParent-owned scaling remained distinct, and that harmless A/B/C/D-no-cover operations worked in the supplied narrow combat pass. Keyboard, gamepad, narration, and accessibility behavior was not exhaustively validated.

`AsyncItemCallbacksDiagnostic` is not a UI-control comparison or a production fix. Its first version remained compatible with reproduction of the original failure; V2 captured an unidentified sole pre-fire callback, and V3 now snapshots pre-hook callback state and installs bounded passive observers from the first addon file for the equipped-weapon fresh-client-launch investigation. Its module README defines the evidence, screenshot, and safety limits.

Detailed source-backed research documents remain under `12.1.0/Analysis/`.

## Native UI research roadmap

- Checkboxes & Radios — **COMPLETE**
- EditBoxes — **COMPLETE**
- ScrollBox — **COMPLETE**
- Color Picker — **COMPLETE**
- Dialogs / Popups — **COMPLETE**
- Tooltips — **COMPLETE**
- Tabs — **COMPLETE** (source research; no runtime comparison required)
- Deprecated & Compatibility APIs — **COMPLETE** (source and bounded runtime research; no comparison module required)

## Boundaries

- Retail LIVE-first research policy
- No SavedVariables or persistent launcher/module state
- No polling or `OnUpdate` introduced by the harness
- No secure-frame infrastructure introduced by the harness
- No production-addon dependency or integration
- No PTR source consultation for this migration

Install the complete `RetailUIResearch` directory as one addon under `_retail_/Interface/AddOns/`. Do not install module directories as separate addons; their former standalone TOCs were retired during consolidation.
