# Button and Frame Comparison

## Purpose

This is the independently owned Buttons & Frames module in the `RetailUIResearch` harness for visually comparing retained Blizzard-native button and frame/dialog designs on Retail 12.1. It is not production OdysseusBuffBars or OdysseusUtilitySuite code.

The implementation follows [ButtonsAndFrames.md](../../../../12.1.0/Analysis/ButtonsAndFrames.md). It does not use SavedVariables, secure frames, polling, aura APIs, Settings categories, or production-addon dependencies.

## Source baseline

- Retail build: `12.1.0.69497`
- LIVE source: commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
- PTR source: commit `e9e8bf68cb7b4177566532f8da9373590759587d`
- Targeted comparison: all 17 retained-candidate implementation files were byte-identical between LIVE and PTR.

## Installation and opening

1. Manually copy the complete `RetailUIResearch` directory into `_retail_/Interface/AddOns/`.
2. Start Retail LIVE or reload the UI.
3. The `RetailUIResearch` launcher opens automatically; click `Buttons & Frames`.
4. Use `/buttonframecomparison` or `/bbfsample` as compatibility shortcuts.
5. Drag the neutral outer window by its background to reposition it for screenshots.

Do not install the module directory as a separate addon; its standalone TOC was retired.

## Button candidates

All five examples remain visible together:

1. `UIPanelButtonTemplate` — **CURRENT GENERAL-PURPOSE (A)**
2. `SharedButtonSmallTemplate` — **CURRENT GENERAL-PURPOSE (A)**
3. `SquareIconButtonTemplate` — **CURRENT GENERAL-PURPOSE (A)**
4. `MinimalTabTemplate` pair using `CreateRadioButtonGroup()` — **CURRENT SPECIALIZED (B)**
5. `SharedGoldRedButtonSmallTemplate` — visibly labeled **Legacy / Old GoldRed** for historical visual comparison; its research classification remains **CURRENT SPECIALIZED (B)**.

`CommonSquareIconButtonTemplate` is intentionally not used. The research classifies it **E — UNCERTAIN** for normal in-game addon use; `SquareIconButtonTemplate` is the retained source-supported sample.

Hover and press the interactive examples to inspect their real states. `Show disabled` disables all five candidates together; `Restore enabled` returns them to interactive state.

## Frame Style dropdown

The `Frame Style` control is a real `WowStyle1DropdownTemplate`. It directly selects one of four separately instantiated shells; it does not re-theme a generic frame and has no Previous/Next controls.

1. `UIPanelDialogTemplate` — **LEGACY BUT SUPPORTED (C)**
2. `DialogBorderDarkTemplate + DialogHeaderTemplate` — **CURRENT GENERAL-PURPOSE (A)**
3. `SettingsFrameTemplate` — **CURRENT GENERAL-PURPOSE (A)**
4. `ButtonFrameTemplate` — **CURRENT GENERAL-PURPOSE (A)**

Only one shell is shown at a time. The default is `UIPanelDialogTemplate`. Each shell contains the title `Blizzard Frame Sample`, the body `Sample content for visual comparison.`, and an `OK` action as its native layout permits. Native shell close controls hide the selected shell; choose another style, or toggle the main window off and on, to show a shell again.

## Dependencies

The root `RetailUIResearch.toc` declares:

```text
## Dependencies: Blizzard_SharedXML, Blizzard_Settings_Shared
```

`Blizzard_SharedXML` supplies the retained button, tab, dialog, portrait, and panel families. Its existing dependency on `Blizzard_Menu` makes `WowStyle1DropdownTemplate` available.

`Blizzard_Settings_Shared` supplies `SettingsFrameTemplate`. The sample instantiates only that visual shell; it does not load `Blizzard_Settings`, register a category, create Settings objects, or adopt the Settings list/footer lifecycle.

If a template is unavailable despite these declared dependencies, its button slot or frame selection reports the creation failure instead of substituting another visual.

## LIVE visual test and screenshot workflow

On Retail LIVE `12.1.0.69497`:

1. Confirm the window opens without a Lua error and can be moved and closed.
2. Confirm all five button examples and their exact labels are visible simultaneously.
3. Hover and press each interactive candidate, then use `Show disabled` and inspect disabled artwork.
4. Select both Minimal tabs and confirm only one remains selected.
5. Confirm the GoldRed entry is visibly labeled `Legacy / Old GoldRed`.
6. Open `Frame Style` and jump directly to each of the four exact entries.
7. Confirm each selection hides the previous shell and shows a visibly distinct real shell.
8. Confirm every shell shows the same title, body text, and `OK` action as its native layout permits.
9. Inspect native border/background, title/header, close-button treatment, padding, portrait, and inset differences.
10. Confirm `SettingsFrameTemplate` works without opening or registering anything in Blizzard Settings.
11. Capture one screenshot per useful shell state with the button section and exact template labels still visible.

Do not add placeholder or generated screenshots. The user will add real LIVE captures after testing.
