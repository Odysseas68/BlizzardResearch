# Retail Dialogs and Popups — WoW 12.1.0

## 1. Scope, authority, and evidence labels

This document maps the current Retail architecture for ordinary confirmation dialogs, text-entry prompts, alert-style popups, modal and non-modal windows, and related reusable visual primitives. It combines source research with the completed bounded `DialogsAndPopupsComparison` runtime evidence. It does not change any production addon.

The authoritative source baseline is Retail LIVE `12.1.0.69497`, local source commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`. PTR and third-party addon source were not consulted.

Evidence is labeled as follows:

- **VERIFIED LIVE SOURCE BEHAVIOR** / **SOURCE-VERIFIED FACT**: directly established by the cited LIVE Lua/XML.
- **VERIFIED RUNTIME OBSERVATION**: directly reported by the supplied Retail LIVE test results.
- **SOURCE-SUPPORTED INFERENCE**: an explanation supported by source and runtime evidence but not explicitly declared as policy by Blizzard.
- **UNRESOLVED** / **RUNTIME QUESTION**: behavior the inspected source and completed bounded runtime pass do not settle.
- **ENGINEERING ASSESSMENT**: a design conclusion drawn from the evidence, not a Blizzard guarantee.

The systems are related by lifecycle and layering, yet the document deliberately preserves four separate categories: the registered `StaticPopup` service, feature-owned special dialogs, visual shells, and notification/toast systems. Treating them as one abstraction would be inaccurate.

## 2. Executive answer

### SOURCE-VERIFIED FACTS

- Retail still actively uses `StaticPopupDialogs`, `StaticPopup_Show`, and four reusable numbered frames, `StaticPopup1` through `StaticPopup4`.
- `StaticPopup` is the only broadly shared registered confirmation/prompt service found. It supports ordinary buttons, rich lifecycle callbacks, timeouts, EditBox, dropdown, money, item, progress, alert-icon, and optional fullscreen-cover compositions.
- No `StaticPopupMixin` exists in the inspected LIVE source. The numbered frames inherit `StaticPopupTemplate` and use `GameDialogMixin`; supporting mixins include `StaticPopupEditBoxMixin` and `StaticPopupElementMixin`.
- No `DialogManager`, `GenericDialog`, generic `MessageBox`, or newer universal registration framework was found that replaces `StaticPopup` for addon-style confirmations.
- `StaticPopupSpecial_Show` and `StaticPopupSpecial_Hide` let feature-owned frames participate in popup ordering, Escape handling, and exclusivity. They do not supply a definition table, buttons, data contract, accept/cancel semantics, reset policy, or modal blocker.
- `DialogHeaderTemplate` and the `DialogBorder*Template` family are current reusable presentation primitives. `ButtonFrameTemplate`, `PortraitFrameTemplate`, `SettingsFrameTemplate`, and `UIPanelDialogTemplate` are also frame shells, not dialog lifecycle frameworks.
- `DIALOG` and `FULLSCREEN_DIALOG` are layering choices. Neither value itself creates modality or cancellation semantics.
- In-game `StaticPopup` can request an explicit `fullScreenCover`: a shaded, mouse-enabled, keyboard-enabled cover frame behind the popup. Ordinary popups do not enable it automatically.
- `UISpecialFrames` is a name list consumed by `CloseSpecialWindows`; its generic action is `frame:Hide()`. It does not provide accept/cancel semantics.
- Alert frames and event toasts are queued/pooled notification systems. Some are clickable, but they are not confirmation or prompt frameworks.

### ENGINEERING ASSESSMENT

- `StaticPopup` remains a valid candidate for compact, transient confirmation and small prompt workflows. Its age is not evidence of deprecation; current Mainline features still define and show it extensively.
- Use an addon-owned companion frame when the interaction is multi-step, persistent, spatially coupled to configuration, or needs richer state than a transient popup. Do not replace a working companion window merely because `StaticPopup` exists.
- Use shared dialog borders/headers for presentation only when the addon owns lifecycle and data. Do not infer cancellation, Escape, blocking, or cleanup from the visual template.
- Treat feature-owned Edit Mode, Calendar, talent, housing, auction, and Settings compositions as examples of architecture, not general APIs to inherit blindly.

## 3. Current system inventory

| Family | Current role | General-purpose? | Owns accept/cancel lifecycle? | Owns modality? |
|---|---|---:|---:|---:|
| `StaticPopupDialogs` + `StaticPopup_Show` | Registered confirmations, prompts, notices, timed and rich popups | Yes, within its contract | Yes, definition-driven | Optional `fullScreenCover`, not automatic |
| Generic wrappers (`StaticPopup_ShowCustomGenericConfirmation`, `StaticPopup_ShowCustomGenericInputBox`, `StaticPopup_ShowGenericDropdown`) | Small caller-data-driven common cases | Yes | Yes, fixed wrapper contracts | No by default |
| `StaticPopupSpecial_*` | Coordinates separately constructed popup-like frames | Limited coordinator only | No; feature owns it | No generic blocker |
| `DialogHeaderTemplate`, `DialogBorder*Template` | Header and NineSlice-backed presentation | Yes, visual only | No | No |
| `ButtonFrameTemplate`, `PortraitFrameTemplate`, `SettingsFrameTemplate` | Full window/configuration shells | Reusable shells | No generic accept/cancel | No |
| Edit Mode/layout dialogs | Layout name/import/unsaved-change workflows | Feature-owned | Yes, feature-owned | No universal facility |
| Calendar modal dialogs | Calendar-owned modal stack and blockers | Feature-owned | Feature-owned | Yes, inside Calendar only |
| Alert frames and event toasts | Transient notifications/rewards/status | Notification systems | No confirmation contract | No |

## 4. StaticPopup ownership and construction

### 4.1 Load ownership

`Blizzard_StaticPopup/Blizzard_StaticPopup.toc` loads the registry and shared functions in `StaticPopup.lua`, then `SharedTemplates.lua` and `SharedDialogDefs.lua`. The in-game presentation comes from `Blizzard_StaticPopup_Game`, whose TOC depends on `Blizzard_StaticPopup` and loads game definitions, `GameDialog.lua`, and `GameDialog.xml`.

`StaticPopupDialogs` is a global definition table. A definition can be assigned directly or passed to `StaticPopup_AddDefinition(which, definition)`. Direct table assignment remains the dominant pattern in current Blizzard source; the helper exists but has no located internal consumer beyond its declaration.

### 4.2 Four reusable frames

`GameDialog.xml` creates exactly four ordinary pool frames:

- `StaticPopup1`
- `StaticPopup2`
- `StaticPopup3`
- `StaticPopup4`

Each inherits the virtual `StaticPopupTemplate`, which combines `StaticPopupBaseTemplate`, `ResizeLayoutFrame`, and `GameDialogMixin`. The base is top-level, mouse-enabled, keyboard-enabled, and hyperlink-enabled. `StaticPopup_SetUpPosition` reparents a shown popup to the appropriate top-level parent, sets `DIALOG` strata, and stacks non-fixed dialogs from the top of that parent.

Reserved frames supplied through `GetReservedDialogFrame` and arbitrary feature frames shown through `StaticPopupSpecial_Show` are separate from the four ordinary free-frame search slots.

### 4.3 Main show and hide functions

The current ordinary entry point is:

```lua
StaticPopup_Show(which, text_arg1, text_arg2, data, insertedFrame, customOnHideScript)
```

It returns the selected dialog or `nil`. The related hide/query surface includes:

```lua
StaticPopup_Hide(which, data)
StaticPopup_FindVisible(which, data)
StaticPopup_Visible(which)
StaticPopup_HideAllExcept(which)
StaticPopup_HideAll()
StaticPopup_IsAnyDialogShown()
```

`StaticPopup_Show` errors when `which` has no definition, when a definition supplies both `OnAccept` and `OnButton1`, or when it supplies both `OnCancel` and `OnButton2`. An `editBoxSecureText` definition also errors when shown from a tainted context.

`text_arg1` and `text_arg2` format the definition text in the normal path. `data` is assigned directly to `dialog.data`; it is not copied. `insertedFrame` is reparented to the popup and shown, then hidden and parented to `nil` on release. `customOnHideScript` is retained for the current showing and cleared after it runs.

## 5. Definition contract

There is no single schema declaration. The current contract is the set of fields consumed by `StaticPopup.lua`, `GameDialog.lua`, and live definitions.

### 5.1 Text and buttons

Core current fields include:

- `text`, `subText`, `normalSizedSubText`, `subtextIsTimer`, and `timeFormatter`;
- `button1` through `button4`, plus `extraButton`;
- `DisplayButton1` through `DisplayButton4` for conditional visibility;
- `button1Pulse` through the corresponding numbered button pulse fields;
- `wide`, `wideText`, `height`, and `closeButton`/`closeButtonIsHide`;
- `showAlert`, `showAlertGear`, `customAlertIcon`, and `alertIconIsAtlas`.

`showAlert` changes the icon/presentation; it does not change the callback model or make the dialog modal.

The primary callbacks are `OnAccept`, `OnCancel`, `OnShow`, `OnHide`, and `OnUpdate`. Current definitions can instead use indexed handlers `OnButton1` through `OnButton4`, `OnAlt`, and `OnExtraButton`. `selectCallbackByIndex` selects the newer indexed dispatch branch; the other branch is explicitly retained temporarily for backward compatibility.

Hyperlink-capable text can delegate `OnHyperlinkClick`, `OnHyperlinkEnter`, and `OnHyperlinkLeave` through the definition.

### 5.2 Timing and dynamic content

Current timing fields include:

- `timeout` — initialized into `dialog.timeleft`; `0` means no countdown;
- `timeoutInformationalOnly` — reaches zero without cancelling/hiding;
- `GetExpirationText` and `GetExpirationSubText` — dynamic countdown text;
- `StartDelay` and `acceptDelay` — delay first-button activation;
- `OnAcceptDelayExpired`;
- `progressBar` together with `StaticPopup_SetProgressBarTime`;
- `sound` and `hideSound`.

The template has an intrinsic `OnUpdate` that services these features and then invokes definition `OnUpdate(dialog, elapsed, dialog.data)`. `StaticPopup_UpdateAll` also advances ordinary dialogs that are shown but not visible while the larger UI is hidden. This polling is Blizzard's intrinsic implementation; it is not a recommendation for addon-owned dialog polling.

When a non-informational timeout expires, the system hides and invokes `OnCancel(dialog, data, "timeout")` if supplied.

### 5.3 Visibility, coexistence, and policy fields

Current system policy fields include:

- `whileDead`;
- `interruptCinematic`;
- `hideOnEscape`, `noCancelOnEscape`, `escapeHides`, `enterClicksFirstButton`, and `ignoreKeys`;
- `exclusive`;
- `multiple` and `noCancelOnReuse`;
- `cancels`;
- `cancelIfNotAllowedWhileDead` and `cancelIfNotAllowedWhileLoggingOut`;
- `notClosableByLogout` and `explicitAcknowledge`;
- `fullScreenCover`;
- `GetReservedDialogFrame` and `AnchorDialogFrame`;
- `selectCallbackByIndex`.

`preferredIndex`, a name seen in historical discussions of this system, does not occur anywhere in the inspected LIVE source and is not a current field for this baseline.

The in-game show-condition hook rejects a definition while the player is dead or a ghost unless `whileDead` is true. The shared hook rejects shows during a cinematic unless `interruptCinematic` is true. A rejected show follows the failed-show cancellation path with `OnCancel(nil, data)` when that callback exists. `exclusive` closes the first currently tracked exclusive popup before the new one is allocated; `cancels` targets shown definitions with the named `which`. These are coexistence policies, not transaction rollback or modality.

## 6. Identity, duplicate behavior, allocation, and reuse

### 6.1 Identity

`which` is the definition/identity key. For a normal definition, `StaticPopup_FindVisible` matches any shown dialog with the same `which`. When `multiple` is true, it matches only when both `which` and `dialog.data == data` match.

Consequences:

- without `multiple`, a second show of the same `which` targets the existing popup even if new `data` differs;
- with `multiple`, different data identities can occupy separate numbered frames;
- with `multiple`, showing the same `which` with the same data reference targets the existing popup.

This comparison is Lua equality on the supplied value/reference. The framework does not create a separate caller key or deep-copy table data.

`StaticPopup_FindVisible(which, data)` returns the matching frame. `StaticPopup_Visible(which)` securely searches by `which` and returns the frame name and frame. `StaticPopup_Show` itself also returns the selected frame, allowing a caller to attach feature state when necessary.

### 6.2 Duplicate replacement

When the system finds an existing matching dialog, it normally uses `CancelAndHideDialog`: the frame hides first, including its `OnHide` lifecycle, and the definition's cancel callback then runs with reason `"override"`. With `noCancelOnReuse`, it hides without invoking cancellation. The new call then overwrites `which`, `dialogInfo`, `data`, timeout/configuration fields, inserted-frame ownership, and the custom hide script before `Init` and `Show`.

Replacement is therefore not a neutral refresh by default. Callers must decide whether override cancellation is appropriate and must not assume the old owner remains active.

### 6.3 Slot exhaustion

If no matching popup is reused, `StaticPopup_Show` takes the first hidden frame in the four-frame list. If none is free, it calls the requested definition's `OnCancel(nil, data)` when present and returns `nil`.

The caller must handle a `nil` return when the operation cannot simply disappear. `PaperDollFrame.lua`, for example, checks the returned frame for equipment-set overwrite and emits an error when no dialog was available.

### 6.4 Reset boundaries

`GameDialogMixin:Init` explicitly refreshes text, buttons, edit-box visibility/options, dropdown visibility, money/item frames, alert icon, delays, extra button, progress bar, cover, spinner/overlay, layout, and inserted-frame placement. On hide, the system runs the custom hide script and definition `OnHide`, clears the EditBox text and secure-text state, releases the inserted frame, removes the key script when applicable, and collapses the shown-dialog list.

This is not an unconditional wipe of every Lua field a consumer may attach. Current consumers sometimes clean feature fields in their own `OnHide`; the equipment-set overwrite definition clears both `dialog.data` and `dialog.selectedIcon`. Addon callers that attach extra frame fields remain responsible for resetting them.

## 7. Acceptance, cancellation, direct Hide, and callback signatures

### 7.1 Buttons

In the `selectCallbackByIndex` branch, the selected button handler receives `(dialog, dialog.data, "clicked")`. A truthy return keeps the popup open; otherwise it hides if the callback did not replace `dialog.which`.

In the compatibility branch:

- button 1 calls `OnAccept` or `OnButton1` as `(dialog, dialog.data, dialog.data2)`;
- button 3 calls `OnAlt(dialog, dialog.data, "clicked")`;
- the extra button calls `OnExtraButton(dialog, dialog.data, dialog.data2)`;
- the other ordinary button path calls `OnCancel(dialog, dialog.data, "clicked")`.

A truthy accept/cancel return keeps the popup open in that branch. Definitions should follow the dispatch style they select rather than assuming every callback has the same third argument.

### 7.2 Direct Hide

`StaticPopup_Hide`, `dialog:Hide()`, `StaticPopup_HideAllExcept`, and ordinary `StaticPopup_HideAll` do not synthesize `OnAccept` or `OnCancel`. They do run the frame's hide lifecycle and therefore definition `OnHide`.

Cancellation occurs only on paths that explicitly call it: cancel-button dispatch, the registered StaticPopup Escape handler when allowed, timeout, duplicate override, `cancels`/exclusive override, failed show conditions or slot allocation, and other named cancellation branches.

The framework's source-visible ordering is not symmetrical:

- button dispatch invokes the selected callback, then hides unless the callback keeps the popup open;
- `StaticPopup_EscapePressed` invokes `OnCancel`, then hides;
- `CancelAndHideDialog` paths such as timeout, duplicate override, `cancels`, and exclusive replacement hide first, then invoke `OnCancel` with the applicable reason;
- failed show conditions and slot exhaustion can invoke `OnCancel(nil, data)` without showing or hiding a frame.

Feature `OnHide` code can therefore run before `OnCancel` on `CancelAndHideDialog` paths. A definition that clears attached state in `OnHide` must account for that ordering.

Therefore:

> Hide is lifecycle teardown, not an alias for cancel.

No framework-level rollback of caller-owned state occurs. If a caller performs live preview or stages destructive state, its callbacks must own commit, restoration, and cleanup.

### 7.3 Generic wrappers have narrower signatures

`StaticPopup_ShowCustomGenericConfirmation(customData, insertedFrame)` uses `GENERIC_CONFIRMATION`. Its data keys include `text`, optional formatting arguments, `callback`, `cancelCallback`, custom button labels, `showAlert`, and `referenceKey`. The accept and cancel callbacks are invoked without popup/data arguments by that wrapper definition.

`StaticPopup_IsCustomGenericConfirmationShown(referenceKey)` searches shown generic confirmations by `dialog.data.referenceKey`.

`StaticPopup_ShowCustomGenericInputBox(customData, insertedFrame)` uses `GENERIC_INPUT_BOX`. Its accepted text is passed to `data.callback(text)`; the cancel callback receives no arguments.

`StaticPopup_ShowGenericDropdown` supplies a current menu-system radio dropdown. It can commit immediately or expose Accept/Cancel depending on `requiresConfirmation`.

## 8. EditBox, money, dropdown, and item compositions

### 8.1 EditBox

`hasEditBox` reveals the built-in `StaticPopupTemplate` EditBox. Current supporting fields include:

- `editBoxInstructions`;
- `editBoxWidth`;
- `maxLetters` and `countInvisibleLetters`;
- `editBoxSecureText`;
- `autoCompleteSource` and `autoCompleteArgs`;
- `EditBoxOnEnterPressed`, `EditBoxOnEscapePressed`, and `EditBoxOnTextChanged`.

The control inherits `AutoCompleteEditBoxTemplate`, `TooltipBackdropTemplate`, and `UserScaledFrameTemplate`; its `Instructions` FontString is separate from the editing value. This composition agrees with the separate EditBox research and does not change the caller's validation responsibilities.

`StaticPopupEditBoxMixin:OnTextChanged(userInput)` uses the flag only for autocomplete dispatch; the definition's `EditBoxOnTextChanged` receives `(editBox, data)` without `userInput`. Definitions that need a direct-user/programmatic distinction cannot obtain it through that definition callback alone.

The standard confirmation handler enables button 1 when the EditBox matches expected text. The standard non-empty handler enables it for non-empty text. These helpers validate only those narrow conditions.

The generic input definition does not source-visibly call `SetFocus` in its `OnShow`; feature definitions often do so explicitly. Exact initial-focus behavior needs runtime validation.

### 8.2 Enter and Escape inside the EditBox

The EditBox's Enter script delegates to the definition and does not automatically click button 1 unless that handler implements the action. `GENERIC_INPUT_BOX` explicitly calls its callback and hides when button 1 is enabled.

`StaticPopup_StandardEditBoxOnEscapePressed` directly hides the parent. It does not call `OnCancel`. This differs from `StaticPopup_EscapePressed`, which normally calls `OnCancel` before hiding. Focused-EditBox Escape and global popup Escape must not be described as equivalent without runtime ordering evidence.

### 8.3 Money, item, dropdown, and inserted content

The current template still implements:

- `hasMoneyFrame` for display;
- `hasMoneyInputFrame` for entry, with optional `EditBoxOnEnterPressed` wiring;
- `hasItemFrame`, including caller-supplied display data or an `itemFrameCallback`;
- `hasDropdown` using `WowStyle1DropdownTemplate`;
- a caller-supplied `insertedFrame`;
- `progressBar`.

These are active compatibility-rich capabilities, not proof that every new addon prompt should use them. A complex editor may be clearer and safer as an addon-owned frame.

## 9. Escape and Enter architecture

### 9.1 StaticPopup's registered Escape route

`GameDialog.lua` registers `StaticPopup_EscapePressed` with `GameMenuEscPriority.Dialog`, the earliest listed game-menu Escape priority. It iterates shown dialogs in reverse order and processes every dialog whose `hideOnEscape` field is true.

For an ordinary registered popup, it calls `OnCancel(dialog, data, "clicked")` unless `noCancelOnEscape` is set, then hides. For a special popup without a definition, it calls `StaticPopupSpecial_Hide`.

This means `hideOnEscape` is not merely presentation: in the ordinary StaticPopup route it normally carries cancel semantics. `noCancelOnEscape` deliberately separates hide from cancel.

### 9.2 Frame OnKeyDown route

`StaticPopup_OnShow` installs `StaticPopup_OnKeyDown` in-game only when `enterClicksFirstButton` is set (or at the glue screen). Enter then selects the first shown/enabled button. The same handler maps the game-menu binding to `StaticPopup_OnEscapeKeyDown`; in-game, that helper only directly hides when `escapeHides` is set. It does not invoke ordinary `OnCancel` there.

The global priority handler and the frame key handler are distinct source paths. In the tested A/D definitions, runtime behavior agreed with the non-propagating frame-handler route: ordinary action keybinds and the game-menu binding did not continue to their normal handlers while the popup was shown. Case B's post-`ClearFocus` routing remains unresolved.

### 9.3 `UISpecialFrames` and `CloseSpecialWindows`

`UISpecialFrames` is a global table of frame names. `CloseSpecialWindows` iterates it, looks up each global frame, and calls `Hide()` on shown entries. `CloseAllWindows` securely invokes that function and is registered later in the Escape cascade through `GameMenuEscPriority.AddOnPost`.

What this guarantees:

- a named, globally accessible frame can participate in generic window closing;
- the operation is Hide;
- `OnHide` scripts still run normally.

What it does not guarantee:

- acceptance or cancellation;
- a callback reason;
- modal input blocking;
- focus restoration;
- ordering based on frame strata;
- deterministic order among entries, because the implementation uses `pairs`;
- closure of only one special frame.

For `RegisterGameMenuEscHandler`, priority controls cross-bucket order and registration order controls handlers within the same priority. The source comment explicitly warns not to rely on order inside the general AddOn bucket.

## 10. Modality and input blocking

### 10.1 Ordinary StaticPopup is not automatically modal

The normal numbered frame is top-level, mouse-enabled, keyboard-enabled, and placed on `DIALOG` strata. None of those properties alone blocks interaction with the rest of the interface or gameplay.

`exclusive` is also not modality. It closes one already shown exclusive popup before showing another; it does not disable unrelated controls or prevent input outside the popup.

### 10.2 `fullScreenCover`

Every current in-game `StaticPopupTemplate` contains `CoverFrame`, which is:

- stretched to the current appropriate top-level parent;
- `HIGH` strata;
- mouse-enabled and keyboard-enabled;
- rendered with a half-opacity black background;
- shown only when the definition sets `fullScreenCover`.

Its key handler can directly hide the parent for Escape when initialized with `hideOnEscape`; its key-up handler is `nop`. Settings reset/discard/timed confirmation definitions use this cover.

This is a real reusable input-interception composition in the StaticPopup system. Runtime confirmed that the tested covered composition blocked interaction with the background sample. The uncovered comparison separately blocked normal action keybinds while allowing direct action-button mouse clicks, so `fullScreenCover` is not the cause of that keyboard behavior and does not establish a global action-disable state.

The separate `cover` field is glue-screen behavior using `GlueParent`'s blocking frame. `StaticPopup_OnHide` explicitly notes there is no corresponding generic glue modal-frame implementation in-game. Do not conflate `cover` with the in-game `fullScreenCover`.

### 10.3 Feature-owned modal implementations

Some features build their own blockers rather than using a universal manager. Calendar is a clear example:

- `CalendarModalDialogTemplate` pushes/pops a Calendar-owned modal stack on show/hide;
- `CalendarFrame_PushModal` reparents a dummy below the top modal;
- Calendar shows `CalendarFrameModalOverlay` and `CalendarEventFrameBlocker`;
- underlying Calendar controls are explicitly disabled or updated.

The AddOn List's glue-side `AddonDialog` similarly uses a full-screen, mouse/keyboard-enabled `DIALOG` frame and feature-owned key behavior. These are specialized designs, not reusable global dialog contracts.

### 10.4 Focused LIVE gameplay-input investigation

This subsection combines the completed controlled `DialogsAndPopupsComparison` runtime observations with a focused follow-up through the same LIVE source baseline. It records narrow tested behavior, not a universal dialog, combat, keyboard, or protected-action guarantee.

#### VERIFIED RUNTIME OBSERVATIONS

- Cases A, B, and both D variants used `StaticPopup1` in the supplied sequences.
- Case C's ordinary addon-owned `DIALOG` frame left action-bar spell activation available and left uncovered sample controls clickable.
- With an uncovered A/D StaticPopup shown, a normal action-bar keybind was unavailable while a direct mouse click on the same usable action-bar ability worked normally. The popup therefore did not globally disable that action.
- The D no-cover StaticPopup also left underlying sample controls clickable. Its keyboard behavior therefore did not require a fullscreen mouse blocker.
- The D `fullScreenCover` variant visibly added a grey fullscreen cover and blocked the background composition. That explicit blocking is separate from the uncovered popup's keyboard capture.
- A and D did not dismiss on Escape in the tested definitions. B's Escape reached its dedicated EditBox handler and direct-hide path, including after the sample's explicit `ClearFocus` probe.
- Case A duplicate replacement reused `StaticPopup1`: old `OnHide`, old `OnCancel(reason=override)`, then new `OnShow`; later acceptance produced new `OnAccept(reason=clicked)` then `OnHide`. Direct Hide produced `OnHide` only, while clicked Cancel produced `OnCancel(reason=clicked)` then `OnHide`.
- Case B produced the tested Enter sequence `EditBoxOnEnterPressed` -> `OnAccept(reason=clicked)` -> `OnHide`; focused Escape used `EditBoxOnEscapePressed` -> direct Hide -> `OnHide`, without `OnCancel`.
- Case C's Okay, Cancel, close, Direct Hide, and lack of automatic Escape-close behavior remained explicitly addon-owned. `DIALOG` strata supplied none of those semantics.

#### VERIFIED LIVE SOURCE BEHAVIOR

The StaticPopup frame and the tested definition fields expose a concrete keyboard-routing difference from Case C:

- `StaticPopupBaseTemplate` is top-level, mouse-enabled, and explicitly `enableKeyboard="true"`.
- It does not set `propagateKeyboardInput`. `Blizzard_SharedXML/UI.xsd` defines that frame attribute's default as `false`; the separate `InsecureKeyboardInputPropagatorTemplate` opts into `propagateKeyboardInput="true"` explicitly.
- `StaticPopup_OnShow` installs `StaticPopup_OnKeyDown` in-game when a definition sets `enterClicksFirstButton`. The tested A, D no-cover, and D covered definitions all set that field.
- `StaticPopup_OnKeyDown` recognizes the `TOGGLEGAMEMENU` binding, Screenshot, and literal Enter. It explicitly reruns only the Screenshot binding. It does not call `RunBinding` for ordinary action keys.
- On the `TOGGLEGAMEMENU` route, `StaticPopup_OnEscapeKeyDown` checks `escapeHides`, not `hideOnEscape`. The tested definitions set `hideOnEscape = true` but do not set `escapeHides`, so that frame-key route performs no hide or cancel callback.
- The separately registered `StaticPopup_EscapePressed` cascade does use `hideOnEscape`, normally calling `OnCancel(..., "clicked")` and then hiding. That handler can only participate after the normal game-menu binding reaches `ToggleGameMenu`.
- The built-in prompt EditBox delegates Enter and Escape to its definition. In tested Case B, OnShow explicitly focuses that EditBox, Enter dispatches button 1, and Escape delegates to `StaticPopup_StandardEditBoxOnEscapePressed`, which directly hides the parent.

The source-visible action paths remain separate:

- a normal action binding invokes `ActionButtonDown` / `ActionButtonUp`, which call `SecureActionButton_OnClick` through `TryUseActionButton`;
- a direct action-button mouse click reaches `ActionBarActionButtonMixin:OnClick`, which calls `SecureActionButton_OnClick` with `isKeyPress = false`;
- the secure action handler ultimately calls `UseAction` for an action slot.

No inspected action-binding, action-button, secure-action-button, or `UseAction` Lua path checks `StaticPopup_IsAnyDialogShown`, a popup key, `shownDialogFrames`, `UISpecialFrames`, `DIALOG` strata, or `fullScreenCover`. Conversely, StaticPopup show/hide does not install override bindings, disable action buttons, call an action-bar suppression API, or register global mouse events.

The only located Mainline gameplay use of `StaticPopup_IsAnyDialogShown` is in `GameEvent.HandleCurrentSpellCastChanged`. It conditionally hides a named set of enchant/trade/follower popups after spell-target state changes; it does not prevent an action from activating.

Direct `StaticPopup_Hide` is synchronous in the source-visible lifecycle. Hiding runs `StaticPopup_OnHide`, removes the dynamically installed parent `OnKeyDown` script when `enterClicksFirstButton` supplied it, clears EditBox state, releases inserted content, and collapses the shown-dialog list. A shown cover disappears with its parent. There is no separate action-bar-disable flag to reverse later.

`fullScreenCover` adds real input structure, not only shading. `CoverFrame` spans the appropriate top-level parent, is mouse- and keyboard-enabled, has the same schema-default non-propagating keyboard state, and owns OnKeyDown/OnKeyUp scripts. Its OnKeyDown can directly hide the parent for literal Escape when initialized with `hideOnEscape`. It does not set a global action-bar state.

#### SOURCE-SUPPORTED INFERENCE

For the tested **normal action keybinding**, the A/D definitions now have a concrete source-backed explanation: their shown StaticPopup installs a keyboard handler on a keyboard-enabled frame whose keyboard propagation is false by default, and the handler does not redispatch ordinary action bindings. The successful direct mouse activation confirms that this is an input-route distinction rather than a global action-bar disable. The observed A/D Escape no-op further corroborates the frame route: `TOGGLEGAMEMENU` can reach `StaticPopup_OnKeyDown`, find no `escapeHides`, and stop before the later `StaticPopup_EscapePressed` cascade that would have honored `hideOnEscape`.

This is a source-supported input-routing inference rather than a claim that StaticPopup contains an explicit “disable gameplay actions” policy. The source shows keyboard capture and selective handling; it does not name or toggle a gameplay-action-suppression state.

Case B can reproduce the same practical keybinding result through focused EditBox input, but its exact post-`ClearFocus` routing remains unresolved. Source verifies the dedicated EditBox Enter/Escape handlers and the parent frame's keyboard-enabled composition; it does not explain from Lua alone why the supplied unfocused Escape still reached `EditBoxOnEscapePressed` in that test.

Case C supplies the negative control: its addon-owned frame has `DIALOG` strata but does not enable keyboard input, install a parent key handler, focus an EditBox, or add a cover. Its successful gameplay activation is therefore consistent with the source distinction. `DIALOG` itself is not the mechanism.

#### RESOLVED RUNTIME DISTINCTION

The controlled follow-up separated the activation methods. With an uncovered StaticPopup shown, the normal action keybind was unavailable and a direct mouse click on the same usable action worked. Together with the source-visible non-propagating keyboard handler, this resolves the tested A/D behavior without inventing a global gameplay-action-disable flag.

This does not prove that every possible keyboard binding, click-cast path, gamepad route, or engine input composition behaves identically. Case B's post-`ClearFocus` Escape result also remains unresolved.

#### VERIFIED SCALE OBSERVATIONS

- The addon-owned sample root reported effective scale `0.480` at 75%, `0.640` at 100%, and `0.800` at 125%; switching repeatedly among these values worked.
- Case C inherits the sample-root hierarchy and therefore its root scaling.
- StaticPopup remains global/UIParent-owned. It did not become sample-owned or inherit the sample-root scale, including when the root was changed to 75% while D no-cover remained visible.

#### VERIFIED NARROW COMBAT OBSERVATIONS

- During actual combat, the user successfully exercised harmless Show/Accept/Hide behavior for A; Show/EditBox input/Enter/Accept/Hide for B; Show and Hide/Okay behavior for C; and Show/Accept/Hide for D no-cover.
- No Lua error or protected-action report was observed from those supplied operations.
- The supplied combat log did not separately test D with `fullScreenCover = true`.
- This evidence applies only to the isolated non-secure sample controls and diagnostic callbacks. It does not establish universal combat safety for production callbacks, protected-frame operations, secure actions, runtime reconfiguration, or taint-sensitive downstream work.

#### COLOR PICKER CONNECTION

No shared source mechanism was established with the earlier Color Picker symptom.

- Mainline `ColorPickerFrame` registers `GLOBAL_MOUSE_DOWN` while visible and hides/cancels on a mouse-down outside its ancestry. StaticPopup does not use that event.
- `ColorPickerFrame` is mouse-enabled but its Mainline XML does not explicitly enable keyboard input or set keyboard propagation. Its hex EditBox has `autoFocus="false"`.
- Color Picker has an OnKeyDown method for `TOGGLEGAMEMENU`, but the inspected XML does not expose the always-keyboard-enabled, `enterClicksFirstButton`-installed handler composition used by tested A/D StaticPopups.
- `UISpecialFrames` gives Color Picker generic Hide-on-Escape participation; it is not consulted by the action-binding/action-button paths inspected here.

The similar runtime symptom is therefore insufficient to unify the causes. Color Picker's action-activation observation remains separately unresolved, and no Color Picker documentation change is justified by this pass.

#### SECURITY, COMBAT, AND TAINT BOUNDARIES

- StaticPopup's ordinary frame and the sample callbacks are non-secure, while action buttons and their activation path use secure/protected infrastructure. Those are distinct facts.
- The identified keyboard-routing composition is not conditioned on combat in the inspected source. The narrow actual-combat runtime pass succeeded for A, B, C, and D no-cover operations listed above; D covered and arbitrary production callbacks remain untested.
- No evidence from this pass attributes the observed restriction to taint, combat lockdown, or a blocked protected call. No supplied taint or blocked-action report accompanies these observations.
- `editBoxSecureText` retains its separate source guard and is not used by the tested sample.

## 11. Frame strata, levels, and visual shells

### 11.1 StaticPopup layering

Non-fixed StaticPopups are parented to the appropriate top-level parent, assigned `DIALOG`, sorted by stable frame/fallback IDs, and vertically stacked. Reserved/anchored popups can use feature positioning. A definition may set different strata in `OnShow`, but that is feature policy.

`FULLSCREEN_DIALOG` appears in stores, menus, model previews, developer UI, tutorials, and other unrelated features. Its presence means “draw in this strata,” not “behave as a modal dialog.”

### 11.2 Shared dialog presentation

`DialogHeaderTemplate` owns only header text and width. `DialogBorderNoCenterTemplate` is a `NineSlicePanelTemplate` with `layoutType = "Dialog"`; `DialogBorderTemplate`, `DialogBorderDarkTemplate`, `DialogBorderTranslucentTemplate`, and `DialogBorderOpaqueTemplate` add different backgrounds.

They do not provide:

- show/queue/reuse policy;
- accept/cancel buttons;
- caller data;
- Escape/Enter handling;
- modal blocking;
- focus management;
- cleanup.

An ordinary addon-owned `Frame` can compose these visual pieces and must implement every behavioral concern itself.

### 11.3 Larger window shells

`ButtonFrameTemplate`, portrait-frame variants, and `SettingsFrameTemplate` remain current full-window shells. They are appropriate for larger tools and configuration surfaces, but their close buttons and decoration do not create transactional semantics. `UIPanelDialogTemplate` is an older border composition with only one located current consumer (`ScriptErrorsFrame`); it likewise supplies no lifecycle framework.

## 12. Modern and specialized dialog families

### 12.1 `StaticPopupSpecial_*`

`StaticPopupSpecial_Show(dialog)` marks a separately created frame as special, assigns an ordering fallback ID, applies exclusive-popup handling, positions it in the shared shown-dialog stack, and shows it. `StaticPopupSpecial_Hide` hides and removes it from that stack.

The special frame must define its own `hideOnEscape`/`exclusive` values and its own buttons, callbacks, state, focus, reset, and visuals. Special frames do not consume one of the four ordinary numbered slots, and the shared update loop deliberately excludes them.

This is a useful coordination primitive but not a complete general dialog framework.

### 12.2 Edit Mode and layout dialogs

`EditModeBaseDialogMixin` provides modes, layout-manager data, button/edit handlers, validation, manager-exit callbacks, and accept/cancel callbacks. Its XML templates are `DIALOG` frames with `DialogBorderTemplate`, EditBoxes, checkboxes, and buttons. It shows them with `StaticPopupSpecial_Show`.

Cooldown Viewer inherits the Edit Mode layout/import templates and overrides layout-manager behavior, demonstrating limited reuse for a closely related layout workflow. The base contract still assumes layout managers, character/account layout types, Edit Mode event naming, and specific controls. It is not a neutral addon-facing confirmation framework.

### 12.3 Talent, housing, auction, communities, and other dialogs

Current features frequently define their own mixins and templates. Class talent loadout create/edit/import dialogs, housing confirmations, auction purchase dialogs, communities dialogs, and channel creation each own state and lifecycle appropriate to that feature. Some join the special-popup stack; others simply show/hide under a feature parent.

These demonstrate that “newer” does not mean “general-purpose.” Copying or inheriting a feature's dialog solely for its appearance imports undocumented ownership assumptions and dependencies.

## 13. Representative current consumer patterns

### 13.1 Settings reset, discard, and timed revert

`Blizzard_Settings_Shared/Blizzard_Dialogs.lua` defines four ordinary StaticPopups:

- apply defaults;
- confirm discard;
- timed confirmation/revert;
- reset default keybindings.

They use `fullScreenCover`; the discard dialog uses indexed button callbacks, and the timed dialog owns duration in frame state and resets it in `OnHide`. This is current evidence for StaticPopup as a serious confirmation mechanism, not only a historical compatibility layer.

### 13.2 Equipment-set overwrite

`GameDialogDefs.lua` defines `CONFIRM_OVERWRITE_EQUIPMENT_SET`. `PaperDollFrame.lua` supplies the equipment-set ID as `data`, checks the returned popup, and attaches `selectedIcon` to the returned frame. Mainline overrides `OnAccept`; `OnHide` clears attached fields. This illustrates both caller data/reference ownership and the need for explicit feature cleanup.

### 13.3 Text-entry destructive confirmation

`Blizzard_HousingBlueprint/Blizzard_HousingBlueprintUtils.lua` defines `CONFIRM_BLUEPRINT_DELETE` with `hasEditBox`, disables Accept until exact confirmation text matches, focuses the field on show, and owns close callbacks. It uses indexed handlers plus dedicated Enter/Escape behavior.

This is current proof that StaticPopup text-entry confirmation remains supported. It also shows that focus, validation, and cleanup are definition responsibilities.

### 13.4 Generic name input

`Blizzard_SharedXML/Shared/LoadSystem/LoadSystemTemplates.lua` uses `StaticPopup_ShowCustomGenericInputBox` to create a named entry. The wrapper callback receives the entered string and the load system owns the resulting object. This is the smallest current general input pattern.

### 13.5 Talent loadout editor plus nested destructive popup

Class talents use custom `ClassTalentLoadoutDialogTemplate` frames and `StaticPopupSpecial_Show` for richer loadout editing. When Delete is selected, that feature dialog hides and shows the ordinary registered `LOADOUT_CONFIRM_DELETE_DIALOG` StaticPopup.

This layered choice is instructive: a richer editor stays feature-owned, while the final destructive yes/no operation uses StaticPopup.

## 14. Alert and toast distinction

`AlertFrame` creates queued/pool-backed subsystems for achievements, loot, scenario completion, mounts, pets, toys, housing items, and other notifications. `EventToastManagerFrame` consumes `C_EventToastManager` data and pools presentation templates by `Enum.EventToastDisplayType`.

These systems manage display queues, coalescing, animation, anchoring, automatic dismissal, and optional click actions. They do not expose the StaticPopup definition contract, accept/cancel pairing, caller-data rollback, text entry, default button, or destructive-action confirmation semantics.

Therefore:

- notification/toast: announces an event or transient state;
- confirmation dialog: asks the user to decide before an operation;
- prompt: collects a bounded value and has explicit commit/cancel behavior;
- configuration window: owns a longer-lived editing session.

An alert must not be recommended as a confirmation dialog merely because it displays prominent temporary UI.

## 15. Combat, security, and taint

### SOURCE-VERIFIED FACTS

- The generic `StaticPopup_Show` path has no blanket `InCombatLockdown()` check.
- The ordinary template is not a secure action button and does not inherit a secure handler template.
- Definitions and feature callbacks may call arbitrary APIs; their safety is independent of the popup's visual shell.
- `editBoxSecureText` is explicitly guarded: `StaticPopup_Show` rejects it when the call is not secure, and the EditBox secure-text state is cleared on hide.
- Some individual definitions check combat or other gameplay state because their operations require it. Those checks are feature policy, not generic framework policy.
- `fullScreenCover` can intercept input while visible, which is separate from protected-action safety.

### ENGINEERING ASSESSMENT

Absence of a generic combat guard proves only that the framework does not categorically refuse all shows. It does not prove that every definition, callback, inserted frame, protected operation, or tainted call path is safe in combat.

For addon research, test the isolated non-secure popup separately from the work performed by Accept/Cancel. Production callbacks should preserve the addon's conservative combat policy and defer protected or taint-sensitive downstream operations when required.

### VERIFIED LIVE RUNTIME EVIDENCE

The isolated sample's harmless non-secure controls and diagnostics operated during actual combat for A, B, C, and D no-cover in the supplied sequences, without a reported Lua or protected-action error. D with `fullScreenCover = true` was not separately combat-tested. This is narrow empirical evidence for those operations, not a universal framework or production-callback safety guarantee.

## 16. Accessibility, keyboard, gamepad, and focus

### SOURCE-VERIFIED FACTS

- `StaticPopup_OnShow` asks `NarrationUtil.RegionToNarrationInfo` for notification narration and triggers `Narration.Speak` when narration information is returned.
- `StaticPopupDialogNarrationMixin` defines dialog context and optional subtext description, but its only located concrete composition is the glue dialog mixin; the in-game `GameDialogMixin` does not inherit it.
- The ordinary frame is keyboard-enabled. Explicit in-game key handling is installed for `enterClicksFirstButton`; the cover has its own Escape handler.
- The game-menu Escape system is priority ordered.
- The StaticPopup implementation has no specific gamepad button/stick handler.
- Money input explicitly focuses its gold field on show. Other definitions may focus their EditBox themselves.

### RUNTIME QUESTIONS

- What exactly is narrated for ordinary in-game popups, their subtext, and their buttons?
- Why did Case B's Escape still reach its EditBox handler after the sample requested `ClearFocus`?
- How do focus and propagation behave in definitions beyond the tested A/B/D compositions?
- How do gamepad cursor mode and focus move among buttons and input fields?
- How do `fullScreenCover` input routes behave during actual combat and across untested keyboard/gamepad paths?

## 17. Current, compatibility, and historical findings

### Current and active

- `StaticPopupDialogs`, `StaticPopup_Show`, the four `StaticPopupN` frames, `StaticPopupTemplate`, and `GameDialogMixin` are loaded current Mainline infrastructure with many current consumers.
- Generic confirmation/input/dropdown wrappers are current and have current consumers.
- `StaticPopupSpecial_*` is current and widely used by feature-owned frames.
- `DialogHeaderTemplate` and `DialogBorder*Template` are current shared visual primitives.

### Compatibility-sensitive

- `StaticPopup_OnClick` labels its non-`selectCallbackByIndex` branch as temporarily retained for backward compatibility. That comment applies to the dispatch branch, not to the entire StaticPopup service.
- The built-in money/item/edit/dropdown surface is broad and mixes long-standing compatibility with current consumers. Use only the subset a new workflow needs.
- `UIPanelDialogTemplate` has very limited located current use and is only a visual border template.

### Not current in this baseline

- `preferredIndex` is absent.
- `StaticPopupMixin`, `DialogManager`, `GenericDialog`, and a generic `MessageBox` implementation are absent.
- No source evidence marks the overall StaticPopup API deprecated.

Age, naming, or visual style is not a valid deprecation test. Current definitions and callers are stronger evidence.

## 18. Completed `DialogsAndPopupsComparison`

The consolidated `RetailUIResearch` module implements and LIVE-tests four bounded cases:

1. **Registered StaticPopup confirmation** — verified clicked Accept/Cancel ordering, direct-Hide distinction, Escape no-op in the tested definition, and same-frame duplicate override ordering.
2. **Registered StaticPopup EditBox prompt** — verified explicit focus, text entry, Enter acceptance, focused Escape direct Hide without `OnCancel`, button Cancel, and Direct Hide. The post-`ClearFocus` Escape route remains unexplained.
3. **Addon-owned non-modal `DIALOG` frame** — verified addon-owned lifecycle, background/sample interaction, action availability, and lack of automatic Escape-close semantics.
4. **StaticPopup cover comparison** — verified uncovered background interaction versus explicit `fullScreenCover` blocking.

The controlled action test separated normal keybind activation from direct action-button mouse clicks for an uncovered StaticPopup. Scale testing covered 75%, 100%, and 125%. Narrow actual-combat testing covered A, B, C, and D no-cover, but not D covered.

The compact module intentionally does not test timeout, all-four-slot exhaustion, `multiple = true`, exhaustive keyboard/gamepad/narration behavior, or arbitrary production callbacks. Feature-owned Edit Mode and Calendar dialogs remain outside scope because their dependencies would test those features rather than the general addon-facing choices.

## 19. Production-addon implications — research only

### 19.1 Odysseus BuffBars

- Compact Filter or Override companion editors should remain addon-owned when they require multiple controls, live preview, spatial continuity, or persistent editing context.
- A final reset/delete confirmation may be a reasonable StaticPopup candidate if it owns a unique definition key, treats the passed data as authoritative caller context, and performs explicit cleanup.
- Do not infer combat safety for filter application from the popup's ability to show.

### 19.2 Odysseus Utility Suite

- Small destructive confirmations and one-value prompts are plausible StaticPopup uses.
- Import/Export should use a dedicated addon-owned window for multiline data, validation, preview, and error reporting; StaticPopup's small EditBox contract is not a full import editor.
- Settings-style fullScreen covers show how Blizzard blocks a transaction, but OUS should use blocking only where interaction truly must be serialized.
- Account for StaticPopup keyboard capture when normal action keybind availability matters; the tested uncovered popup still allowed direct action-button mouse clicks and did not globally disable actions.

### 19.3 Nightwatch

- StaticPopup is relevant only for an explicit destructive/reset confirmation or a small prompt.
- Normal monitoring/status output belongs in Nightwatch's existing UI or a notification surface, not a blocking confirmation.

### 19.4 Future Odysseus ColorLab Plus

- The global `ColorPickerFrame` remains a separate singleton with caller-owned state, as documented in `ColorPicker.md`.
- ColorLab Plus may use an addon-owned editing surface and invoke the native color picker without nesting ownership inside StaticPopup.
- A StaticPopup could confirm destructive palette deletion or request a short name, but should not own the full color-editing session.
- If a popup and `ColorPickerFrame` can be visible together, runtime must test Escape priority, outside interaction, layering, and which owner performs cancellation.

## 20. Unresolved runtime questions

Source and the completed bounded runtime pass do not settle:

- timeout ordering and other untested callback branches;
- whether all four numbered frames are available to addons under ordinary gameplay conditions and how slot exhaustion presents in practice;
- initial keyboard focus for the generic input wrapper;
- Case B's post-`ClearFocus` keyboard routing and why its supplied Escape still reached the EditBox handler;
- actual narration content and button focus order;
- gamepad navigation/default-button behavior;
- exhaustive keyboard, click-cast, and other engine input routes beyond the tested normal keybind/direct-mouse distinction;
- actual-combat behavior of D with `fullScreenCover = true`;
- taint/protected-operation behavior of any production callback, which must be tested separately from the popup shell.

## 21. Final conclusions

1. Retail's general confirmation/prompt service is still StaticPopup; it is old, current, and actively used.
2. The service is a four-frame reusable registry with exact identity/reuse/slot-failure behavior, not an unlimited frame factory.
3. Caller data is referenced, not copied. Commit, rollback, and feature cleanup remain caller-owned.
4. Accept, cancel, direct Hide, Escape, timeout, and override are distinct paths. They must not be collapsed into one “close” semantic.
5. `StaticPopupSpecial_*` coordinates feature-owned frames but does not make them generic dialogs.
6. Shared dialog borders and larger frame templates are presentation shells, not behavior frameworks.
7. `DIALOG`, `FULLSCREEN_DIALOG`, `exclusive`, and `UISpecialFrames` do not themselves establish modality.
8. `fullScreenCover` is the current generic in-game StaticPopup blocking composition. Runtime verified explicit background blocking, while the uncovered control proved that normal action-keybind capture is a separate StaticPopup keyboard-routing behavior and not a global action disable.
9. Alert/toast systems are notifications, not confirmation or prompt APIs.
10. Future addon architecture should choose among StaticPopup, an addon-owned companion frame, or a notification system based on lifecycle and ownership—not visual resemblance or API age.

## 22. Primary LIVE source index

### StaticPopup core

- `Interface/AddOns/Blizzard_StaticPopup/Blizzard_StaticPopup.toc`
- `Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua`
- `Interface/AddOns/Blizzard_StaticPopup/SharedTemplates.lua`
- `Interface/AddOns/Blizzard_StaticPopup/SharedDialogDefs.lua`
- `Interface/AddOns/Blizzard_StaticPopup_Game/Blizzard_StaticPopup_Game.toc`
- `Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.lua`
- `Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.xml`
- `Interface/AddOns/Blizzard_StaticPopup_Game/GameDialogDefs.lua`
- `Interface/AddOns/Blizzard_StaticPopup_Game/Mainline/GameDialog.lua`
- `Interface/AddOns/Blizzard_StaticPopup_Game/Mainline/GameDialogDefs.lua`
- `Interface/AddOns/Blizzard_StaticPopup_Game/Mainline/StaticPopupSpecial.xml`

### Escape, shells, and modality

- `Interface/AddOns/Blizzard_GameMenuEsc/Blizzard_GameMenuEsc.lua`
- `Interface/AddOns/Blizzard_Game/Shared/Game.lua`
- `Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Dialog/DialogTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Dialog/DialogTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/SharedBasicControls.xml`
- `Interface/AddOns/Blizzard_Calendar/Mainline/Blizzard_Calendar.lua`
- `Interface/AddOns/Blizzard_Calendar/Mainline/Blizzard_CalendarTemplates.xml`

### Gameplay input routing

- `Interface/AddOns/Blizzard_ActionBar/Shared/ActionButton.lua`
- `Interface/AddOns/Blizzard_FrameXML/Bindings_Standard.xml`
- `Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua`
- `Interface/AddOns/Blizzard_FrameXML/SecureTemplatesBase.xml`
- `Interface/AddOns/Blizzard_SharedXML/UI.xsd`
- `Interface/AddOns/Blizzard_Game/Mainline/EventImplementation.lua`
- `Interface/AddOns/Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.lua`
- `Interface/AddOns/Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.xml`

### Specialized systems and representative consumers

- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Dialogs.lua`
- `Interface/AddOns/Blizzard_EditMode/Shared/EditModeDialogs.lua`
- `Interface/AddOns/Blizzard_EditMode/Shared/EditModeDialogs.xml`
- `Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerSettingsDialogs.lua`
- `Interface/AddOns/Blizzard_CooldownViewer/CooldownViewerSettingsDialogs.xml`
- `Interface/AddOns/Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentLoadoutDialogTemplates.xml`
- `Interface/AddOns/Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentLoadoutEditDialog.lua`
- `Interface/AddOns/Blizzard_HousingBlueprint/Blizzard_HousingBlueprintUtils.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/LoadSystem/LoadSystemTemplates.lua`
- `Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua`
- `Interface/AddOns/Blizzard_AddOnList/AddonList.lua`
- `Interface/AddOns/Blizzard_AddOnList/AddonList.xml`

### Notifications

- `Interface/AddOns/Blizzard_FrameXML/Mainline/AlertFrames.lua`
- `Interface/AddOns/Blizzard_FrameXML/Mainline/AlertFrames.xml`
- `Interface/AddOns/Blizzard_FrameXML/Mainline/AlertFrameSystems.lua`
- `Interface/AddOns/Blizzard_FrameXML/Mainline/AlertFrameSystems.xml`
- `Interface/AddOns/Blizzard_FrameXML/EventToastManager.lua`
- `Interface/AddOns/Blizzard_FrameXML/EventToastManager.xml`
