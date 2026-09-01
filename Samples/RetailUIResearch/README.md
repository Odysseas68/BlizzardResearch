# RetailUIResearch

`RetailUIResearch` is an unofficial third-party development and research harness for the repository's six Retail LIVE-validated UI-control modules. They can be installed and opened from one small launcher without duplicating addon metadata or auto-opening every research window.

This is a test harness, not production addon infrastructure. Patterns demonstrated by a module should not be copied into a production addon without considering its corresponding research conclusions, combat behavior, taint risks, ownership model, and product requirements.

## Architecture

The root addon contains one TOC, a deliberately small `Core.lua`, and `Launcher.lua`. Each directory under `Modules/` retains its own Lua implementation, README, and any user-authored LIVE screenshot.

Each module eagerly creates and owns its existing root sample frame and local research state, then registers metadata containing an ID, display name, and frame with `RetailUIResearch:RegisterSample`. Eager creation minimizes changes to the previously LIVE-validated initialization and callback paths. Core coordinates visibility only: opening a sample hides the previously selected sample, and reopening a hidden sample shows its existing frame and state.

Core does not provide Blizzard-control wrappers, and modules do not call implementation helpers from sibling modules.

## Retail LIVE harness validation

The consolidated harness was tested by the user on Retail LIVE `12.1.0.69497`.

- On login/reload, only the launcher opened; no module window auto-opened.
- All six modules opened from their launcher buttons. EditBoxComparison and ScrollBoxComparison completed their supplied LIVE runtime tests out of combat and during actual combat.
- Selecting another module hid the previously selected module.
- Closing a module left the launcher usable, and clicking its launcher button reopened it.
- Retained module slash commands opened/toggled the correct module through Core and participated in the one-sample-at-a-time behavior.
- No Lua errors were observed during the supplied harness test.

## Launcher and commands

The launcher opens after `PLAYER_LOGIN`, remains available while a sample is open, and uses a compact vertical stack of six ordinary `UIPanelButtonTemplate` buttons. Its height derives from the number of launcher entries, so later modules extend the same column without redesigning the window:

- Sliders
- Buttons & Frames
- Dropdowns & Menus
- Checkboxes & Radios
- EditBoxes
- ScrollBox

Use `/retailuiresearch` to toggle the launcher. The existing compatibility/debug commands remain available and route through the same visibility coordinator:

- `/slidercomparison` or `/sliders`
- `/buttonframecomparison` or `/bbfsample`
- `/dropdownmenucomparison` or `/dmc`
- `/checkboxradiocomparison` or `/crc`
- `/editboxcomparison` or `/ebc`
- `/scrollboxcomparison` or `/sbc`

## Modules and evidence ownership

- `Modules/SliderComparison/`
- `Modules/ButtonFrameComparison/`
- `Modules/DropdownMenuComparison/`
- `Modules/CheckboxRadioComparison/`
- `Modules/EditBoxComparison/`
- `Modules/ScrollBoxComparison/`

Every module README remains authoritative for that sample's purpose, source baseline, runtime findings, limitations, and test procedure. All six validated modules retain their user-authored LIVE screenshots beside their Lua and README. `ScrollBoxComparison` completed its supplied fixed-list, variable-extent, grid, one-child ScrollFrame, resize/scale, diagnostic-copy, and narrow non-secure combat tests. Keyboard, gamepad, narration, and accessibility behavior was not exhaustively validated.

Detailed source-backed research documents remain under `12.1.0/Analysis/`.

## Boundaries

- Retail LIVE-first research policy
- No SavedVariables or persistent launcher/module state
- No polling or `OnUpdate` introduced by the harness
- No secure-frame infrastructure introduced by the harness
- No production-addon dependency or integration
- No PTR source consultation for this migration

Install the complete `RetailUIResearch` directory as one addon under `_retail_/Interface/AddOns/`. Do not install module directories as separate addons; their former standalone TOCs were retired during consolidation.
