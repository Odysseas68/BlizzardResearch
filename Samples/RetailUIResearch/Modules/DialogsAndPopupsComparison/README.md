# Dialogs / Popups Comparison

## Purpose and validation status

`DialogsAndPopupsComparison` is the focused Dialogs / Popups runtime module in the `RetailUIResearch` harness. It compares behavior and ownership across four harmless compositions; it is not a dialog library, product workflow, or production recommendation.

The implementation and source analysis use Retail LIVE `12.1.0.69497` and source commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`. The authoritative analysis is [DialogsAndPopups.md](../../../../12.1.0/Analysis/DialogsAndPopups.md). PTR and third-party addon source were not consulted.

Static/source validation and the supplied Retail LIVE runtime pass are complete. Runtime results below are narrow observations from this isolated addon-owned non-secure sample. They are not universal guarantees for arbitrary StaticPopup definitions, production callbacks, protected operations, secure actions, combat-time reconfiguration, or taint-sensitive downstream work.

## Four cases and verified runtime behavior

### A. Registered StaticPopup confirmation

The module registers `RETAIL_UI_RESEARCH_DIALOG_CONFIRMATION` and calls `StaticPopup_Show` with two harmless formatting arguments and a caller-owned data table. It selects indexed callback dispatch with `selectCallbackByIndex = true`.

Verified Retail LIVE behavior:

- the tested sequences used `StaticPopup1`, numbered-frame index 1;
- clicked Accept: `OnAccept(reason=clicked)` -> `OnHide`;
- clicked Cancel: `OnCancel(reason=clicked)` -> `OnHide`;
- direct `StaticPopup_Hide`: `OnHide` only;
- Escape did not dismiss this tested definition;
- a true duplicate while visible reused `StaticPopup1` and produced old `OnHide` -> old `OnCancel(reason=override)` -> new `OnShow`;
- accepting the replacement produced new `OnAccept(reason=clicked)` -> `OnHide`.

Direct Hide therefore did not synthesize Accept or Cancel, and duplicate override ordering differed from clicked Cancel.

### B. StaticPopup EditBox prompt

The second registration uses StaticPopup's native `hasEditBox` composition, instruction text, width, and maximum-letter fields. `OnShow` explicitly calls `SetFocus()`.

Verified Retail LIVE behavior:

- `OnShow` diagnostics reported `focusBefore=true` and `focusAfter=true`;
- clicked Accept: EditBox content -> `OnAccept(reason=clicked)` -> `OnHide`;
- clicked Cancel: `OnCancel(reason=clicked)` -> `OnHide`;
- Enter: `EditBoxOnEnterPressed` -> `OnAccept(reason=clicked)` -> `OnHide`;
- focused Escape: `EditBoxOnEscapePressed` -> Blizzard's direct-Hide path -> `OnHide`, with no `OnCancel`;
- direct `StaticPopup_Hide`: `OnHide` only.

After the sample explicitly requested `ClearFocus`, Escape still reached the EditBox Escape handler in the supplied test. The source investigation did not explain that result, so it remains unresolved and must not be generalized to other StaticPopup EditBoxes.

### C. Addon-owned non-modal DIALOG frame

Case C is an ordinary non-secure child of the sample root. It uses `DIALOG` strata with `DialogBorderDarkTemplate` and `DialogHeaderTemplate`; the addon explicitly owns Okay, Cancel, close, Direct Hide, show, and hide behavior.

Verified Retail LIVE behavior:

- strata `DIALOG`, frame level 41, parented to the sample;
- background sample controls remained clickable;
- action-bar abilities remained usable;
- Okay, Cancel, close-button, and Direct Hide semantics remained addon-owned;
- no automatic Escape-close behavior was registered.

`DIALOG` strata alone supplied no acceptance, cancellation, Escape, modality, or gameplay-input policy. Normal Blizzard Escape handling continued independently; opening the Game Menu in one test was not an intrinsic Case C behavior.

### D. StaticPopup fullScreenCover comparison

Two matching harmless registrations compare an uncovered StaticPopup with `fullScreenCover = true`. The sample does not create its own blocker.

Verified no-cover behavior:

- `StaticPopup1`, `cover=false`;
- background sample controls remained clickable;
- clicked Accept and Cancel followed the normal callback/Hide order;
- Escape did not dismiss the tested definition;
- normal action keybinds were unavailable while the popup was shown;
- direct mouse clicks on the same usable action-bar abilities worked normally.

Verified covered behavior:

- `cover=true` visibly greyed/covered the screen;
- the cover blocked background interaction;
- native Accept and Cancel worked;
- Escape did not dismiss the tested definition.

`fullScreenCover` therefore provides real mouse/keyboard interception and background blocking. It is not the cause of the uncovered popup's action-keybind behavior, and it does not establish a separate global action-disable state.

## Action-input conclusion

The controlled follow-up separated two activation paths for an uncovered StaticPopup:

- normal action-bar keybind: unavailable while the tested popup was shown;
- direct mouse click on the same usable action button: worked normally.

This result agrees with the verified source composition: `StaticPopupBaseTemplate` is keyboard-enabled, keyboard propagation defaults to false, and the tested A/D definitions use `enterClicksFirstButton`, which installs `StaticPopup_OnKeyDown`. That handler selectively processes popup-related keys and does not redispatch ordinary action bindings.

This is a source-supported explanation for the tested normal keybind suppression. It does not mean StaticPopup globally disables actions, and it does not prove every possible keyboard, click-cast, gamepad, or engine input route behaves identically.

## Scale validation

The root scale buttons were switched repeatedly and produced:

| Root scale | Effective scale |
| --- | --- |
| 75% | 0.480 |
| 100% | 0.640 |
| 125% | 0.800 |

Case C inherits the sample-owned root scale. StaticPopup remains global/UIParent-owned and does not inherit that hierarchy. Changing the sample root to 75% while D no-cover was visible did not make the popup sample-owned or scale it through the sample root.

Nothing is persisted. The sample is not resizable.

## Narrow actual-combat validation

The supplied actual-combat pass successfully exercised:

- A: Show, Accept, Hide;
- B: Show, EditBox input, Enter, Accept, Hide;
- C: Show and Hide/Okay behavior across the combat sequence;
- D no-cover: Show, Accept, Hide.

No Lua error or protected-action report was observed from those harmless operations. The supplied combat log did not separately test D with `fullScreenCover = true`.

This is narrow empirical evidence only. It does not establish universal combat safety for arbitrary definitions, production callbacks, protected-frame operations, secure actions, runtime reconfiguration, or taint-sensitive downstream work.

## Diagnostics and controls

The newest 40 events are retained in a numbered, case-labeled `ScrollingEditBoxTemplate` log. Click it and use Ctrl+A / Ctrl+C to copy the history. Accidental edits are restored from the module-owned buffer. Explicit actions and lifecycle callbacks also print to chat.

Diagnostics include callback order, case identifier, caller data, frame name/index, shown and visible state, strata/level, intentional prompt text, focus state, root/effective scale, and combat entry/exit.

There is no addon-owned `OnUpdate`, polling, broad global hook, action-bar instrumentation, protected click simulation, or secure infrastructure.

## Source/runtime classification

### VERIFIED LIVE SOURCE BEHAVIOR

- StaticPopup is the current general confirmation/prompt service and uses four reusable numbered frames.
- `StaticPopup_OnShow` installs `StaticPopup_OnKeyDown` for the tested `enterClicksFirstButton` definitions.
- `propagateKeyboardInput` defaults to false unless explicitly enabled.
- direct Hide, clicked cancellation, EditBox Escape, and duplicate override are distinct lifecycle paths.
- `fullScreenCover` owns an explicit mouse- and keyboard-enabled cover frame.
- `DIALOG` strata, `FULLSCREEN_DIALOG`, `exclusive`, and `UISpecialFrames` do not independently create generic modality.
- no inspected StaticPopup/action-button path installs a global action-disable flag.

### VERIFIED RUNTIME OBSERVATIONS

- the A/B/C/D lifecycle, action-input, scale, and narrow combat results recorded above;
- sample-owned background interaction remained available for C and D no-cover;
- the covered D composition blocked the background;
- the user-authored screenshot exists as the default LIVE visual reference.

### SOURCE-SUPPORTED INFERENCE

The tested uncovered StaticPopup's normal action-keybind suppression is explained by its keyboard-enabled, non-propagating handler path. Successful direct action-button mouse activation confirms that this is an input-route distinction, not a global action disable.

### UNRESOLVED

- Case B's post-`ClearFocus` Escape routing;
- D covered during actual combat;
- timeout and all-four-slot exhaustion behavior;
- `multiple = true` duplicate behavior in this sample;
- exhaustive keyboard, click-cast, gamepad, narration, and accessibility behavior;
- arbitrary production callback, protected-operation, and taint behavior.

## Screenshot

`DialogsAndPopupsComparison.png` is the user-authored Retail LIVE visual reference for this module. It is 1066x740 pixels and captures the default comparison window at 75% root scale, out of combat, with all four research panels and the bounded diagnostic log visible. No StaticPopup or Case C dialog is open in the captured state.

## Commands and boundaries

- `/dialogsandpopupscomparison`
- `/dapc`
- Registered as `dialogs-popups` through `RetailUIResearch:RegisterSample`
- Initially hidden; Core owns open/toggle coordination
- No independent `PLAYER_LOGIN` event or auto-open
- No SavedVariables, per-module TOC, persistence, polling, secure templates, protected gameplay calls, third-party detection, or production integration
