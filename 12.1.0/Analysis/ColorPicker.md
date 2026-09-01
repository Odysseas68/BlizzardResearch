# Retail Color Picker — WoW 12.1.0

## 1. Scope and source baseline

This is a focused, LIVE-first investigation of the current Retail Color Picker contract available to ordinary third-party addons. The initial source pass established the reusable opening, value, callback, singleton, swatch, Settings, and dismissal behavior; the completed native runtime pass now records observed callback, ownership, stale-alpha, scale, layering, dismissal, and qualified combat behavior. It does not change a production addon.

- Retail client/source baseline: `12.1.0.69497`
- LIVE source root: `D:\WowDEV\Reference\Blizzard\wow-ui-source`
- LIVE source commit: `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
- BlizzardResearch baseline: `617819c53b115be9ec02fd9d0b476727b4b102d5`
- PTR consulted: no. LIVE exposed no concrete future-compatibility question requiring PTR evidence.
- ColorPickerPlus consulted: no. Its source and behavior remain outside the native source/runtime investigation.

Source paths below are relative to `Interface/AddOns/` in the LIVE mirror. Mainline definitions and consumers are authoritative.

Evidence labels:

- **SOURCE-VERIFIED FACT:** directly established by the cited LIVE Lua, XML, TOC, or generated API source.
- **RETAIL LIVE RUNTIME OBSERVATION:** behavior observed by the user in the native test on Retail `12.1.0.69497`; it is not promoted into an undocumented API guarantee.
- **ENGINEERING RECOMMENDATION / INFERENCE:** bounded addon guidance derived from the source, not a Blizzard guarantee.
- **RUNTIME QUESTION:** behavior whose exact client result is not established by the inspected Lua/XML contract.

## 2. Executive answer

### SOURCE-VERIFIED FACTS

- Retail creates one named global `ColorPickerFrame` under `UIParent`. It is a top-level, movable, clamped, initially hidden `Frame` with `ColorPickerFrameMixin` and `DIALOG` frame strata (`Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.xml:75-210`).
- There is no reusable virtual `ColorPickerFrameTemplate` in Mainline. The supported current pattern is to configure the global instance with `ColorPickerFrame:SetupColorPickerAndShow(info)` (`Mainline/ColorPickerFrame.lua:91-105`).
- The required color input is normalized `r`, `g`, and `b`. The caller supplies a no-argument `swatchFunc` that reads the current result with `ColorPickerFrame:GetColorRGB()`.
- Optional opacity uses `hasOpacity`, `opacity`, and a no-argument `opacityFunc`. The `opacity` value is passed directly to intrinsic `SetColorAlpha`; it is not inverted. Current consumer evidence treats `1` as fully opaque and `0` as transparent.
- Initial `r`, `g`, `b`, and `opacity` are copied into `previousValues = {r, g, b, a}`. Cancel dispatches `cancelFunc(previousValues)` when supplied. The picker itself does not restore caller-owned state.
- Color and alpha changes are live-preview callbacks. Okay calls the live callbacks again and hides; there is no separate `okayFunc` or commit callback.
- Cancel, outside click, and the picker Escape-binding path invoke cancellation before hiding. Calling `ColorPickerFrame:Hide()` directly only runs `OnHide`; it does not accept or cancel.
- The frame is a singleton. Every setup overwrites its callback fields, previous values, extra information, and optional external swatch reference. No ownership queue or per-caller picker object exists.
- `ColorSwatchTemplate` is a separate, reusable 16x16 SharedXMLBase visual with `ColorSwatchMixin:SetColor` and `SetColorRGB`. It does not open the picker or own value persistence; callers provide click behavior.
- Blizzard Settings has a supported `Settings.CreateColorSwatch` / `Settings.SetupCVarColorSwatch` control. It wraps the same global picker. It is appropriate for Settings categories, while addon-owned windows can use `ColorSwatchTemplate` plus the global picker directly.

### ENGINEERING RECOMMENDATION

For an ordinary addon-owned setting, keep the authoritative RGBA value in addon state, own a small clickable swatch, and open the global picker with a fresh info table. Treat `swatchFunc` and `opacityFunc` as live preview; restore the captured original value in `cancelFunc`; let Okay leave the previewed value committed. Do not retain or reparent the global picker, do not assume callback fields are cleared on hide, and do not open it for a second logical owner without resolving the first owner's preview state.

### RETAIL LIVE RUNTIME SUMMARY

- The global singleton opened and operated for RGB and RGB-plus-opacity callers on Retail `12.1.0.69497`.
- Reconfiguring it for caller B while caller A remained visible replaced the active setup without an intervening `OnHide` and without automatically cancelling A.
- Setup itself dispatched live callbacks in the tested composition. Opacity setup exposed an intermediate alpha of `1.0` before the requested `0.55` was later observed.
- RGB and opacity changes both caused `swatchFunc` and `opacityFunc` to fire, sometimes frequently and with repeated identical values. They did not behave as independent per-property notifications.
- RGB-only caller A observed a stale singleton alpha of approximately `0.842` after opacity caller B. That value persisted across later openings and sample-scale changes; it was not adopted as A's state.
- Okay, Cancel, Escape, outside click, and direct Hide matched the source-derived acceptance/dismissal distinctions in the supplied test.
- Root-scale and layering checks passed. Actual-combat opening and ordinary non-secure picker interaction were a qualified PASS, but normal action-bar ability activation was unavailable while the picker was visible. LIVE source inspection did not establish the exact cause of that gameplay-input limitation.

## 3. Core architecture and load ownership

### 3.1 Addon and global instance

`Blizzard_ColorPickerFrame_Mainline.toc` declares:

- `DefaultState: enabled`;
- `AllowLoad: game` and `AllowLoadGameType: mainline`;
- dependencies on `Blizzard_FrameXMLBase`, `Blizzard_UIPanelTemplates`, and `Blizzard_GameMenuEsc`;
- load order: shared Escape helper, Mainline Lua, then Mainline XML.

The Mainline XML declares one non-virtual frame named `ColorPickerFrame`. This creates the global singleton. It is not a constructor template for producing independent picker instances.

`ColorPickerFrame` is also listed in `UISpecialFrames` (`Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:20-25`). That integrates the named global into UI-level special-frame handling; it does not give an addon ownership of the frame.

### 3.2 Internal composition

The frame contains:

- `DialogBorderTemplate` border;
- `DialogHeaderTemplate` header and a `PanelDragBarTemplate` drag surface;
- one intrinsic `ColorSelect` with wheel, value strip, alpha strip, and their thumbs;
- current and original RGB swatch textures;
- a 73x22 `InputBoxInstructionsTemplate` hex field;
- ordinary `UIPanelButtonTemplate` Okay and Cancel buttons.

The `ColorSelect` intrinsic provides `GetColorRGB`, `SetColorRGB`, `GetColorAlpha`, `SetColorAlpha`, and HSV methods in `Blizzard_APIDocumentationGenerated/SimpleColorSelectAPIDocumentation.lua`. The reusable public-facing mixin forwards only current RGB and alpha getters; it does not expose its own HSV wrapper.

### 3.3 Supported opening function

Current unrelated Mainline consumers consistently call:

```lua
ColorPickerFrame:SetupColorPickerAndShow(info)
```

The method stores the info fields, updates the original swatch and hex field, applies initial RGB to the intrinsic selector, and calls `Show()` (`ColorPickerFrame.lua:91-105`). No other general `OpenColorPicker` or `ShowColorPicker` helper was found. Functions with `OpenColorPicker` in their names are consumer-owned wrappers.

An addon should use a fresh plain Lua table. `UIDropDownMenu_CreateInfo()` still appears in one current Settings definition as a convenient table allocator, but it belongs to the explicitly deprecated `UIDropDownMenu` system and is not required by `SetupColorPickerAndShow`.

## 4. Exact setup information contract

The current mixin reads these fields:

| Info field | Required status from implementation | Meaning |
|---|---|---|
| `r`, `g`, `b` | Required for valid setup | Initial normalized RGB and captured previous RGB |
| `swatchFunc` | Effectively required | No-argument live/Okay callback; Okay calls it unconditionally |
| `hasOpacity` | Optional | Truthy value displays and configures the alpha strip |
| `opacity` | Required when `hasOpacity` is truthy | Initial intrinsic alpha; captured as `previousValues.a` |
| `opacityFunc` | Optional | No-argument live/Okay callback for alpha-aware callers |
| `cancelFunc` | Optional | Called as `cancelFunc(previousValues)` on supported cancel paths |
| `extraInfo` | Optional | Opaque caller data retrievable with `GetExtraInfo()` |
| `swatch` | Optional | External object updated live through `swatch:SetColorRGB(r, g, b)` |

There is no schema validator. Missing or malformed required values fail only when the implementation uses them. In particular, the Okay handler calls `self.swatchFunc()` without a nil check, so a normal supported setup must provide it.

Recommended minimal RGB setup:

```lua
local original = {r = model.r, g = model.g, b = model.b}

ColorPickerFrame:SetupColorPickerAndShow({
    r = original.r,
    g = original.g,
    b = original.b,
    swatchFunc = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        PreviewAndStoreRGB(r, g, b)
    end,
    cancelFunc = function(previousValues)
        RestoreAndStoreRGB(previousValues.r, previousValues.g, previousValues.b)
    end,
})
```

Opacity-aware setup adds `hasOpacity = true`, normalized `opacity`, and `opacityFunc` reading `GetColorAlpha()`.

## 5. Color representation

### 5.1 RGB

Current callers supply `r`, `g`, and `b` from `ColorMixin:GetRGB()` or APIs that already return normalized color channels. `ColorUtil.CreateColorFromBytes` explicitly converts byte channels by dividing by 255, while hex parsing also divides each byte by 255 (`Blizzard_SharedXML/ColorUtil.lua:5-58`). This establishes normalized 0–1 channels as the current practical contract.

The generated `SimpleColorSelectAPI` types RGB as numbers but does not document clamping or out-of-range normalization. The Lua setup path performs no explicit clamp.

**ENGINEERING RECOMMENDATION:** supply finite normalized values in `[0, 1]`. Convert byte colors deliberately rather than passing 0–255 values. Do not depend on undocumented out-of-range behavior.

The old `UIDropDownMenu.lua` info comment labels its swatch RGB fields as 1–255, but the same legacy structure is passed directly to current normalized picker APIs and conflicts with current consumer practice. It is not authoritative guidance for new Color Picker code.

### 5.2 Hex

The built-in hex field represents only six RGB digits. It strips non-hex characters on text change. On Enter it substitutes `ffffff` for empty text or repeats the supplied character sequence until six characters are present, appends `ff` only to construct an RGBA color object, then applies RGB to the picker (`ColorPickerFrame.lua:119-159`).

Editing the built-in hex field does not provide an alpha/opacity text interface. The sample's derived hex readout is therefore labeled as comparison/diagnostic UI, not as a different native contract.

### 5.3 Alpha, opacity, and transparency

The source uses three related terms:

- setup field and visual label: `opacity` / `OPACITY`;
- intrinsic method and getter wrapper: alpha (`SetColorAlpha`, `GetColorAlpha`);
- visual endpoint meaning: `1` fully shown/opaque, `0` transparent, confirmed by the Mainline legacy info comment and Chat Frame consumer behavior.

`SetupColorPickerAndShow` stores `info.opacity`, and `OnShow` passes it directly to `self.Content.ColorPicker:SetColorAlpha(self.opacity)`. There is no `1 - opacity` conversion. Therefore the current caller-facing opacity value is numerically the same as conventional alpha:

```text
alpha = opacity
transparency amount = 1 - alpha
```

Chat Frame supplies its current window alpha as `opacity`, reads `GetColorAlpha()`, and applies that result as window alpha (`Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua:484-495,896-903`). Cancel restores `previousValues.a` directly (`:927-934`).

**ENGINEERING RECOMMENDATION:** name addon state `alpha` or `opacity` consistently and document that `1` means opaque. If a product exposes a user-facing transparency percentage where 100% means invisible, convert explicitly at the product boundary.

When `hasOpacity` is false, `OnShow` hides the alpha strip and reduces the picker width. It does not reset the singleton's intrinsic alpha value. RGB-only callers should not read or persist `GetColorAlpha()` as meaningful output.

## 6. Callback and dismissal lifecycle

### 6.1 Live intrinsic selection handler

`OnLoad` installs one `OnColorSelect` handler on the intrinsic selector. When that handler runs, source order is:

1. update the picker's current RGB swatch;
2. update the built-in hex field;
3. call `swatchFunc()` when present;
4. update optional `info.swatch` through `SetColorRGB`;
5. call `opacityFunc()` when present.

Both callbacks receive no arguments. They read current values from the global frame.

**RETAIL LIVE RUNTIME OBSERVATION:** both callbacks fired for RGB changes and both fired for opacity changes in the tested RGB-plus-opacity composition. They could fire at high frequency and repeatedly with identical values. `SetupColorPickerAndShow` also dispatched callbacks before `OnShow`; one opacity-enabled setup exposed alpha `1.0` before the requested `0.55` was applied and observed later. The Lua order above remains source-verified once `OnColorSelect` runs, but exact intrinsic dispatch count and setup ordering are runtime behavior, not a stable per-property notification contract.

### 6.2 Okay

The Okay button performs:

1. `swatchFunc()` unconditionally;
2. `opacityFunc()` when present;
3. the standard checkbox sound;
4. `Hide()`.

There is no separate accept callback and no values are passed. The model is live preview plus final callback repetition. A caller that writes authoritative state from the live callbacks has already applied the value before Okay; Okay leaves that value in place.

**RETAIL LIVE RUNTIME OBSERVATION:** Okay invoked the relevant live callback or callbacks again and then hid the picker.

### 6.3 Cancel button

The Cancel button performs:

1. `cancelFunc(previousValues)` when present;
2. the standard checkbox sound;
3. `Hide()`.

The table contains the setup-time `r`, `g`, `b`, and `a = opacity`. The frame does not call `SetColorRGB`/`SetColorAlpha` to restore the selection, and it does not restore caller data automatically.

**RETAIL LIVE RUNTIME OBSERVATION:** Cancel invoked the caller's `cancelFunc` with the captured previous state, the sample restored its caller-owned state, and the picker hid.

### 6.4 Outside click and Escape-binding path

While shown, the frame registers `GLOBAL_MOUSE_DOWN`. A mouse down outside its ancestry calls `cancelFunc(previousValues)` when present and hides the frame. This path does not play the button sound.

`OnKeyDown` compares `GetBindingFromClick(key)` with `TOGGLEGAMEMENU`; when they match, it likewise calls cancel and hides without the button sound.

**RETAIL LIVE RUNTIME OBSERVATION:** Escape and an outside mouse click both followed cancellation behavior and hid the picker. Some attempted outside interactions during combat visibly took this native outside-click route.

### 6.5 Programmatic hide

`OnHide` only unregisters `GLOBAL_MOUSE_DOWN`. It does not invoke live, accept, or cancel callbacks and does not clear stored fields.

**ENGINEERING RECOMMENDATION:** if addon code needs to dismiss the picker programmatically, decide explicitly whether that operation means commit or rollback and perform the corresponding model action before `Hide()`. Do not assume hiding equals Cancel.

**RETAIL LIVE RUNTIME OBSERVATION:** the sample-requested direct `ColorPickerFrame:Hide()` hid the picker without artificially invoking accept or cancel.

## 7. Previous/original color handling

The setup-time current value is also the previous/original value. There is no separate `previousColor` field:

```lua
self.previousValues = { r = info.r, g = info.g, b = info.b, a = info.opacity }
```

`GetPreviousValues()` returns those four values as multiple returns. `cancelFunc` instead receives the stored table as its one argument. Current consumers demonstrate both styles:

- Chat Frame accepts the table parameter directly.
- Settings and Colorblind override closures ignore the argument and call `GetPreviousValues()`.

The built-in `ColorSwatchOriginal` is updated from setup RGB and remains a visual comparison. It has no click-to-restore script. It displays RGB only; restoration policy remains caller-owned.

If `info.swatch` is supplied, the picker updates that external swatch during live selection. It does not automatically set it back on Cancel. The caller's cancel path must restore the external model/swatch, directly or through its normal setting-refresh callback.

## 8. Singleton behavior and ownership hazards

Each call to `SetupColorPickerAndShow` overwrites:

- `swatchFunc`;
- `hasOpacity`, `opacityFunc`, and `opacity`;
- `previousValues`;
- `cancelFunc`;
- `extraInfo`;
- `swatch`;
- the displayed original RGB, hex RGB, and current selector RGB.

The method does not cancel an existing caller, retain a stack, queue ownership, or clear old fields first. `OnHide` also does not clear callback closures. Stored callbacks and objects can therefore remain referenced until a later setup replaces them.

Consequences for addons:

- do not treat the global picker as owned permanently by one swatch;
- do not retain callback ownership assumptions after another caller can open it;
- do not open it for caller B while caller A has uncommitted live preview without explicitly resolving A;
- do not rely on hide to release callback-captured objects immediately;
- do not cache current RGB/alpha as though it belonged to a particular caller after ownership changes.

**RETAIL LIVE RUNTIME OBSERVATION:** caller A opened the singleton, then caller B setup was invoked while the same frame remained visible. B immediately replaced the active callback/setup fields without an intervening `OnHide`; A was not automatically cancelled. This was reconfiguration of one visible global frame, not closure of A followed by creation or opening of a second picker.

## 9. Swatches and caller integration

### 9.1 `ColorSwatchTemplate`

`Blizzard_SharedXMLBase/ColorSwatch.xml` defines a virtual 16x16 `ColorSwatchTemplate` with:

- 14x14 hover-colored background;
- 12x12 black inner border;
- 10x10 color texture;
- `ColorSwatchMixin:SetColor(color)` and `SetColorRGB(r, g, b)`;
- hover border changes and pixel-snapped sizing.

The base template is a `Frame`, not a complete input button. It has no `OnClick`, no value model, no picker call, no label, no alpha indicator, and no persistence. Settings explicitly creates a `Button` inheriting the template to make it clickable (`Blizzard_SettingControls.xml:98-105`). An addon can use the same composition or own an equivalent button containing the generic visual.

### 9.2 Menu color swatches

Modern `Blizzard_Menu` descriptions provide `CreateColorSwatch(text, callback, colorInfo)`. The element attaches `ColorSwatchTemplate`, colors it from `colorInfo.r/g/b`, and passes `colorInfo` as responder data (`Blizzard_Menu/MenuTemplates.lua:536-550`; `MenuUtil.lua:248-253`). The responder still decides whether to call `SetupColorPickerAndShow`.

This is a useful menu integration, not a general standalone Color Picker constructor.

### 9.3 Strongest general addon pattern

For an addon-owned configuration window:

1. create an addon-owned clickable swatch, optionally using `ColorSwatchTemplate`;
2. read the current authoritative model value on each click;
3. build a fresh info table;
4. update the model and swatch from live callbacks;
5. restore the setup-time value from `cancelFunc`;
6. avoid retaining any Color Picker child frame as addon state.

## 10. UI structure and layering

The global picker is:

- parented to `UIParent`;
- top-level;
- `DIALOG` strata;
- movable through its header drag bar;
- clamped to screen;
- centered by default;
- 388x210 with opacity, 331x210 without it;
- hidden until configured.

It behaves like a global dialog/popup rather than an embedded child control. Outside clicks cancel it, and the caller does not parent it to a configuration panel. Because it is independent of the opening swatch's parent, hiding the caller's window does not itself establish commit/cancel semantics.

The source does not expose an owner-frame field, automatic anchor-to-swatch behavior, or per-caller frame-level adjustment. Addon configuration dialogs should let the global picker use its own placement and verify that its DIALOG strata is appropriate relative to any unusually elevated companion window.

**RETAIL LIVE RUNTIME OBSERVATION:** the picker reported `DIALOG` strata and frame level `124`. With sample root scales of 75%, 100%, and 125%, picker effective scale remained `0.640`, while sample effective scale was respectively `0.480`, `0.640`, and `0.800`. The UIParent-owned picker remained independently positioned and usable, with no obvious clipping or interaction-blocking layering defect. Stale singleton alpha persisted across these scale changes.

## 11. Settings integration

### 11.1 Public Settings color control

Current Settings exposes:

- `Settings.CreateColorSwatchInitializer(setting, options, tooltip)`;
- `Settings.CreateColorSwatch(category, setting, tooltip, options)`;
- `Settings.SetupCVarColorSwatch(category, variable, label, tooltip)`.

`SettingsColorSwatchControlTemplate` owns a `SettingsColorSwatchTemplate`, which is a clickable `ColorSwatchTemplate` plus Settings callback/tooltip behavior (`Blizzard_Settings_Shared/Blizzard_SettingControls.xml:98-105,135-140`).

On click, the Settings mixin creates a plain info table, supplies `info.swatch`, reads RGB from the setting's color string, and uses `SetupColorPickerAndShow`. Live changes generate an opaque hex color string and trigger Settings `OnValueChanged`; Cancel regenerates the prior RGB string (`Blizzard_SettingControls.lua:924-1047`).

The standard Settings wrapper is RGB-only. It supplies neither `hasOpacity` nor `opacityFunc`.

### 11.2 Settings recommendation

- If the setting belongs in a registered Blizzard Settings category, use `Settings.CreateColorSwatch` or `Settings.SetupCVarColorSwatch` and its expected color-string setting model.
- If the control belongs in an addon-owned window, use the generic swatch visual plus `ColorPickerFrame` directly.
- Do not instantiate `SettingsColorSwatchControlTemplate` outside its initializer/setting/layout lifecycle merely to borrow presentation.

Settings therefore has a reusable color-setting API, unlike its lack of a native EditBox value control. It still wraps the same global singleton rather than creating an independent picker.

## 12. Representative current consumers

### 12.1 Settings color swatch — ordinary RGB

`SettingsColorSwatchMixin` is the strongest framework example. It owns its swatch, captures current RGB from its setting, live-updates the setting from `GetColorRGB()`, and restores setup-time RGB on Cancel. It also passes `info.swatch` for immediate visual update.

### 12.2 Raid frame health colors — custom Settings integration

`Blizzard_SettingsDefinitions_Frame/Mainline/InterfaceOverrides.lua:47-85` demonstrates a Settings checkbox-with-swatch composition. The consumer owns the click callback, obtains RGB from a CVar color string, sets the CVar during `swatchFunc`, restores previous RGB during `cancelFunc`, and opens the global picker. No opacity is used.

### 12.3 Chat window background — RGB plus opacity

`Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua:484-498,896-934` supplies RGB, current chat alpha as `opacity`, both live callbacks, Cancel, and `hasOpacity = 1`. RGB and alpha are applied independently. Cancel restores the `previousValues` table directly.

This is the strongest current alpha/opacity example and confirms that the picker field named opacity is used as actual frame alpha.

### 12.4 Chat Config — RGB and `extraInfo`

`Blizzard_ChatFrame/Mainline/ChatConfigFrame.lua:1459-1577` uses multiple RGB-only setups. One stores a message-type table in `extraInfo`; its live and cancel callbacks retrieve that data with `GetExtraInfo()` and apply the current or previous RGB to several chat types.

The consumer demonstrates that `extraInfo` is opaque caller context, not picker-owned color state.

## 13. Combat, security, and taint

### SOURCE-VERIFIED FACTS

- `ColorPickerFrame` is an ordinary `Frame` containing an intrinsic `ColorSelect`, EditBox, and ordinary buttons.
- It does not inherit `SecureActionButtonTemplate`, a SecureHandler template, or protected-action infrastructure.
- Focused search found no `InCombatLockdown`, `PLAYER_REGEN_*`, or source-visible combat gate in the Mainline picker, generic swatch, or Settings swatch paths.
- The generated intrinsic setters carry secret-argument restrictions, including `SetColorRGB`, `SetColorAlpha`, and `SetColorHSV`. This is API safety metadata, not a general protected-frame contract.

### ENGINEERING RECOMMENDATION / INFERENCE

The source shows no generic combat prohibition on opening or interacting with the ordinary picker. It does not prove that arbitrary callbacks are safe in combat. A `swatchFunc`, `opacityFunc`, or `cancelFunc` may perform protected operations, mutate protected descendants, or enter a taint-sensitive subsystem.

The completed sample tested only addon-owned non-secure preview state during actual combat and reports the result narrowly below. Production addons must evaluate the operations performed by their callbacks independently.

### RETAIL LIVE RUNTIME OBSERVATION — QUALIFIED COMBAT RESULT

During actual combat, both callers opened through `SetupColorPickerAndShow`, native callbacks executed, Cancel and outside-click cancellation worked, and the picker hid normally. The supplied test produced no Lua error, protected-action error, or obvious taint error.

This is a qualified PASS only for opening and ordinary non-secure picker interaction. While the picker was visible, the user could not activate a normal action-bar ability; dismissing it restored gameplay interaction. This separate gameplay-input limitation prevents describing the result simply as “combat-safe.” It does not establish that arbitrary production callbacks, protected-frame operations, secure actions, or taint-sensitive downstream work are safe.

## 14. Current versus older patterns

### Current

- global `ColorPickerFrame`;
- `ColorPickerFrameMixin`;
- fresh info table;
- `SetupColorPickerAndShow(info)`;
- current values through `GetColorRGB()` / `GetColorAlpha()`;
- restoration through `cancelFunc(previousValues)` or `GetPreviousValues()`.

### Older or unsuitable starting points

- `UIDropDownMenu_CreateInfo()` is not required. The legacy dropdown system is explicitly deprecated by Blizzard's menu migration guide even though one current consumer still uses its table factory.
- `UIDropDownMenuButton_OpenColorPicker` is a compatibility bridge from a legacy dropdown color-swatch button, not the general opening API for new addon code.
- Assigning imagined fields such as `ColorPickerFrame.func` is not the current Mainline contract; no such field is read by the current mixin.
- `OpacityFrame` is a separate global opacity-only popup still used by selected Mainline features. It is not the Color Picker's alpha strip and should not be combined with or substituted for `SetupColorPickerAndShow` without a concrete feature requirement.

No source deprecation marker was found on `ColorPickerFrame`, `SetupColorPickerAndShow`, `ColorSwatchTemplate`, or the Settings color-swatch API.

## 15. Accessibility and input surface

Source-visible input behavior is limited but identifiable:

- color-wheel, value-strip, and alpha-strip selection is provided by the intrinsic `ColorSelect` mouse surface;
- the header uses a standard drag bar;
- Okay and Cancel use ordinary panel-button templates;
- the hex field inherits `InputBoxInstructionsTemplate`, including its edit-field narration/focus behavior, and sanitizes input in the picker mixin;
- the picker declares an `OnKeyDown` Escape-binding path;
- outside mouse down cancels;
- no picker-specific narration mixin, gamepad mapping, explicit focus traversal, or custom accessibility description was found.

Do not infer full keyboard, gamepad, controller, or narration behavior from the presence of standard child controls. Those behaviors require runtime validation.

### Focused LIVE-source readback for the gameplay-input observation

**SOURCE-VERIFIED FACTS:**

- Mainline `ColorPickerFrame` is a UIParent-owned top-level frame with `enableMouse="true"`, `DIALOG` strata, and no fullscreen blocker. Its XML does not specify `enableKeyboard` or `propagateKeyboardInput`; the shared XML schema defaults both attributes to false (`Blizzard_SharedXML/UI.xsd:825-845`). No Mainline picker Lua calls `EnableKeyboard`, `SetPropagateKeyboardInput`, action-bar binding APIs, or combat APIs.
- The frame nevertheless declares an `OnKeyDown` method that only tests whether `GetBindingFromClick(key)` maps to `TOGGLEGAMEMENU`; no arbitrary action-key branch appears in that method.
- On show it registers the synchronous `GLOBAL_MOUSE_DOWN` event. A mouse down outside the picker ancestry invokes `cancelFunc(previousValues)` and hides. This source chain directly explains the observed outside-click cancellation and dismissal.
- `ColorPickerFrame` appears in `UISpecialFrames`. The inspected `CloseSpecialWindows` implementation only hides shown frames in that list; it does not install a modal input blocker or action-bar gate.
- The built-in hex control is an `InputBoxInstructionsTemplate` EditBox with `autoFocus="false"`, so the XML does not request focus merely from opening. If manually focused, it is a possible keyboard-focus participant. Its picker-specific Enter handler applies RGB but does not call `ClearFocus`; inherited Escape behavior clears EditBox focus. The global left-mouse handler also contains a general current-keyboard-focus clearing path.
- Focused action-bar source search found no branch conditioned on `ColorPickerFrame`, `UISpecialFrames`, or picker visibility. No combat-specific branch was found in the picker, generic swatch, or Settings wrapper paths.

**RETAIL LIVE RUNTIME OBSERVATION:** during actual combat the user could interact with the picker but could not activate a normal action-bar ability until the picker was dismissed. Some attempted outside interactions caused the synchronous outside-click cancellation route.

**REASONABLE INFERENCE:** the proven outside-mouse cancellation can explain why an attempted mouse interaction first dismissed the picker. If the hex EditBox had focus, focus capture is another plausible explanation for a keybound action not firing. The supplied runtime evidence does not identify whether the failed ability attempt was a mouse click, a keybind, or occurred with hex focus, and the Lua/XML source does not state that `GLOBAL_MOUSE_DOWN` consumes the underlying secure action.

**UNRESOLVED:** LIVE source does not establish the exact cause of the action-bar activation failure. It therefore cannot presently be classified as a ColorPicker-specific modal rule, a broader input/focus dispatch behavior, a combat-only rule, or a sample-specific interaction. A narrow follow-up should separately test mouse activation and keybind activation, with and without hex-field focus, both in and out of combat, and observe `ColorPickerFrame:IsKeyboardEnabled()`, `GetPropagateKeyboardInput()`, and the current keyboard focus. No sample behavior should be changed until that distinction is reproduced.

## 16. Third-party visual augmentation contract

Without inspecting any third-party implementation, a visual augmentation or replacement that intends to remain compatible with native callers would need to preserve at least:

- the global singleton identity or an equivalent transparent interception point;
- `SetupColorPickerAndShow(info)` and all currently consumed info fields;
- normalized RGB input/output;
- `opacity` as non-inverted alpha with `1` opaque;
- no-argument live `swatchFunc` and `opacityFunc` behavior;
- caller-provided `cancelFunc(previousValues)` restoration responsibility;
- `GetColorRGB`, `GetColorAlpha`, `GetPreviousValues`, and `GetExtraInfo`;
- live update of optional `info.swatch` where native callers expect it;
- current Okay, Cancel, outside-click, Escape, and programmatic-hide distinctions;
- singleton replacement behavior and the lack of per-caller persistent ownership.

Native callers should avoid assumptions about internal child names, physical frame layout, exact callback frequency during dragging, or long-lived ownership beyond the public mixin methods and supplied callbacks. They should also avoid depending on the picker to restore application state automatically.

This section does not assess ColorPickerPlus compatibility, recommend a shim, or treat third-party code as architecture authority.

## 17. Recommended general addon usage pattern

1. Store authoritative color state outside the picker as normalized RGB and optional alpha.
2. Use an addon-owned clickable swatch; `ColorSwatchTemplate` is the current generic native visual.
3. On click, capture the current model value and construct a fresh info table.
4. Always provide valid `r`, `g`, `b`, and `swatchFunc`.
5. For alpha, add `hasOpacity = true`, `opacity = alpha`, and `opacityFunc`; keep `1 = opaque` explicit in product naming.
6. Apply harmless live preview from `GetColorRGB()` / `GetColorAlpha()`.
7. Restore the captured model and swatch in `cancelFunc(previousValues)`.
8. Treat Okay as confirmation of the already previewed value, not as a unique commit callback.
9. Define programmatic dismissal semantics before calling `Hide()`.
10. Coordinate singleton ownership so a second caller cannot silently orphan the first caller's preview.
11. Use `Settings.CreateColorSwatch` when deliberately registering a Blizzard Settings control.
12. Test combat, layering, input, and repeated-caller behavior in the actual host before production adoption.

## 18. `ColorPickerComparison` runtime validation

The compact module exercised:

1. **RGB caller** — addon-owned native swatch, normalized initial RGB, live preview, Okay, Cancel, outside click, Escape, and direct Hide diagnostics.
2. **RGB plus opacity caller** — explicit alpha initial value, live RGB/alpha readouts, `1 = opaque` labeling, Cancel restoration, and alpha-strip visibility.
3. **Two independent callers** — different initial values/callback identities, sequential use, and deliberate setup-while-visible test to characterize singleton replacement.
4. **Lifecycle log** — bounded numbered diagnostics for setup, live RGB, live alpha, optional external swatch update, Okay, Cancel, outside dismissal, Escape, show, and hide.
5. **Value display** — normalized RGB/alpha plus optional derived `RRGGBB`/`RRGGBBAA` readout for comparison only; do not replace native semantics.
6. **Layout** — ordinary addon dialog, root scale checks, dragging/clamping, and layering relative to the launcher/companion frame.
7. **Combat** — addon-owned non-secure preview/restore operations during actual combat, with the qualified result and gameplay-input limitation recorded above.

The sample retained its research boundaries: no Settings registration, production SavedVariables, ColorPickerPlus code, protected actions, palette system, or reusable Color Picker framework.

## 19. Remaining questions

- exact callback counts for every possible wheel, value, alpha, and hex interaction beyond the supplied sequences;
- whether already-visible RGB-to-opacity and opacity-to-RGB reconfiguration always refreshes every native layout element, beyond the observed ownership replacement;
- the exact input-dispatch cause of action-bar activation being unavailable while the picker was visible, including mouse versus keybind, hex focus, and in-combat versus out-of-combat behavior;
- exhaustive keyboard, gamepad, narration, focus, and accessibility behavior;
- any intrinsic clamping/normalization for out-of-range or non-finite channels, which callers should avoid regardless.

The documented runtime results apply only to the supplied Retail LIVE test composition.

## 20. Primary source index

Core definitions:

- `Blizzard_ColorPickerFrame/Blizzard_ColorPickerFrame_Mainline.toc`
- `Blizzard_ColorPickerFrame/Shared/ColorPickerFrame.lua`
- `Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.lua`
- `Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.xml`
- `Blizzard_APIDocumentationGenerated/SimpleColorSelectAPIDocumentation.lua`
- `Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua`
- `Blizzard_APIDocumentationGenerated/SystemDocumentation.lua`
- `Blizzard_SharedXML/ColorUtil.lua`
- `Blizzard_SharedXML/UI.xsd`
- `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml`
- `Blizzard_SharedXMLBase/Color.lua`
- `Blizzard_SharedXMLBase/ColorSwatch.lua`
- `Blizzard_SharedXMLBase/ColorSwatch.xml`
- `Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua`
- `Blizzard_Game/Mainline/EventImplementation.lua`
- `Blizzard_Game/Mainline/EventRouting.lua`
- `Blizzard_GameMenuEsc/Blizzard_GameMenuEsc.lua`

Settings and menu integration:

- `Blizzard_Settings_Shared/Blizzard_Settings.lua`
- `Blizzard_Settings_Shared/Blizzard_SettingControls.lua`
- `Blizzard_Settings_Shared/Blizzard_SettingControls.xml`
- `Blizzard_SettingsDefinitions_Frame/Mainline/InterfaceOverrides.lua`
- `Blizzard_SettingsDefinitions_Frame/Mainline/ColorblindOverrides.lua`
- `Blizzard_Menu/MenuTemplates.lua`
- `Blizzard_Menu/MenuUtil.lua`

Representative consumers and compatibility context:

- `Blizzard_ChatFrameBase/Mainline/FloatingChatFrame.lua`
- `Blizzard_ChatFrame/Mainline/ChatConfigFrame.lua`
- `Blizzard_SharedXML/Mainline/UIDropDownMenu.lua`
- `Blizzard_SharedXML/Mainline/UIDropDownMenuTemplates.xml`
