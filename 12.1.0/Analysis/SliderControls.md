# Retail 12.1 Slider Controls

## 1. Scope and source provenance

This document records a source audit and focused Retail LIVE runtime comparison of horizontal slider controls that are relevant to ordinary third-party addon configuration UI. It does not modify OdysseusBuffBars or OdysseusUtilitySuite.

The authoritative local mirrors inspected were:

- Live: `D:\WowDEV\Reference\Blizzard\wow-ui-source`
  - branch `live`
  - commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
  - `version.txt`: `12.1.0.69497`
- PTR: `D:\WowDEV\Reference\Blizzard\wow-ui-source-ptr`
  - branch `ptr`
  - commit `e9e8bf68cb7b4177566532f8da9373590759587d`
  - `version.txt`: `12.1.0.69497`

The Live mirror had a pre-existing untracked `.codex/` directory. The PTR mirror had no reported changes. Neither mirror was modified.

The research repository baseline was clean at `5fcf754e7e364c403c10b6569075b1d61fbc4364` on `main`, with `HEAD` equal to `origin/main`.

## 2. Classification key

- **A — Directly reusable:** an ordinary addon can instantiate the control from loaded SharedXML and initialize it without adopting another Blizzard feature framework.
- **B — Reusable with setup/dependencies:** usable by an ordinary addon, but only after documented framework registration or an additional Blizzard module dependency.
- **C — Artwork reusable:** the complete control is coupled, but the source identifies standalone texture files or atlas names that can be applied to addon-owned, non-secure widgets.
- **D — Not appropriate:** specialized, deprecated, global-instance, or framework-owned behavior makes direct third-party reuse inappropriate for this purpose.

Classification is based on actual XML inheritance, TOC dependencies, and Lua initialization paths. It is not based only on the existence of a mixin.

## 3. Primary reusable controls

### 3.1 `UISliderTemplate` and `UISliderTemplateWithLabels` — A

**Source**

- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:330-365`
- `Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML.toc`

**Verified facts**

- `UISliderTemplate` is a virtual horizontal `Slider` with mouse input.
- Its bar is a `NineSlicePanelTemplate` using `layoutTextureKit="SliderBar"`.
- Its thumb uses `Interface\Buttons\UI-SliderBar-Button-Horizontal` at an explicit `32 x 32` size.
- The template does not set a slider width, height, range, step, value, callback, or label. The addon must provide them.
- `UISliderTemplateWithLabels` adds top, low, and high font strings but no value-management logic.
- No protected attribute, secure template, restricted API, or feature-owned data object appears in these definitions.

**State handling**

The XML declares one static NineSlice bar and one thumb texture. It does not declare separate normal, highlight, pushed, or disabled artwork. The native Slider widget still owns input and enabled state, but alternate visual-state assets are not defined by this template.

**Practicality**

This is the ordinary baseline. It is directly usable, but it does not solve stepper presentation; addon code must add and manage decrement/increment buttons.

### 3.2 `MinimalSliderTemplate` — A

**Source**

- `Interface/AddOns/Blizzard_SharedXML/Shared/Slider/MinimalSlider.xml:3-31`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Slider/MinimalSlider.lua:1-31`
- `Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML.toc:90-91`

**Verified facts**

- The template is a virtual horizontal `Slider` using `MinimalSliderMixin` and `NarrationSliderMixin`.
- Default size is `200 x 19`.
- `obeyStepOnDrag` defaults to true and `MinimalSliderMixin:OnLoad()` forwards it to `SetObeyStepOnDrag`.
- Bar atlases are `Minimal_SliderBar_Left`, `_Minimal_SliderBar_Middle`, and `Minimal_SliderBar_Right`.
- The thumb atlas is `Minimal_SliderBar_Button` with `useAtlasSize="true"`.
- The source mirror does not contain the numeric atlas metadata for these atlases. Their exact pixel extents therefore require an in-game `C_Texture.GetAtlasInfo` check and are not asserted here.
- Range, step, value, and `OnValueChanged` remain the caller's responsibility.

**State handling**

No separate normal, highlight, pushed, or disabled atlas is declared for the bar or thumb. `Release()` only removes the value-changed script.

**Practicality**

This is the modern minimal bar and thumb without steppers. It is directly reusable from SharedXML.

### 3.3 `MinimalSliderWithSteppersTemplate` — A and recommended

**Source**

- `Interface/AddOns/Blizzard_SharedXML/Shared/Slider/MinimalSlider.xml:34-94`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Slider/MinimalSlider.lua:33-260`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.lua:650-719`
- `Interface/AddOns/Blizzard_EditMode/Shared/EditModeTemplates.xml:109-130`
- `Interface/AddOns/Blizzard_SettingsDefinitions_Shared/Graphics.xml:37-130`

**Verified creation path**

`SettingsSliderControlMixin:OnLoad()` does not build a Settings-only slider implementation. It calls:

```lua
CreateFrame("Frame", nil, self, "MinimalSliderWithSteppersTemplate")
```

The same SharedXML template is inherited by Settings advanced controls and Edit Mode controls. The reusable implementation itself lives in `Blizzard_SharedXML`, not in `Blizzard_Settings` or `Blizzard_EditMode`.

**Dimensions and artwork**

- Default outer frame: `250 x 40`.
- Inner slider: `MinimalSliderTemplate`; the outer XML anchors it from `TOPLEFT x=19` to `BOTTOMRIGHT x=-19`.
- Back button: `11 x 19`, atlas `Minimal_SliderBar_Button_Left`, four pixels left of the slider.
- Forward button: `9 x 18`, atlas `Minimal_SliderBar_Button_Right`, four pixels right of the slider.
- The inherited minimal slider uses the bar/thumb atlases listed in section 3.2.
- Optional left, right, top, minimum, and maximum labels use `GameFontNormal` and start hidden.

**Initialization and callbacks**

The required call is:

```lua
control:Init(value, minValue, maxValue, steps, formatters)
```

`steps` is a count, not a step size. The mixin computes `(maxValue - minValue) / steps`, assigns range/value, installs its own slider `OnValueChanged` script, formats optional labels, and updates stepper enabled states. Consumers can register `OnValueChanged`, `OnInteractStart`, and `OnInteractEnd` callbacks through the inherited `CallbackRegistryMixin`.

`CallbackRegistryMixin` invokes ordinary function callbacks as `func(owner, ...)`. A direct anonymous value callback must therefore accept the callback owner before the value:

```lua
control:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
	-- Use value here.
end)
```

Blizzard-owned Settings and Edit Mode call sites express the same contract by registering an object method with that object as the callback owner; the method receives `self` first and the slider value second.

The Back and Forward buttons call `OnStepperClicked`; each applies one native slider step and plays `SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON`.

**State handling**

- At a range endpoint, the corresponding stepper is disabled, alpha is set to `0.5`, and the button hierarchy is desaturated.
- Disabling the complete control sets the slider thumb alpha to `0.7`, colors labels gray, disables the slider, and disables/desaturates both steppers.
- The XML uses one atlas per stepper. It does not define separate hover or pushed artwork.
- Slider press/hover state is used to emit interaction-start/end callbacks; the source does not use that state to swap art.

**Dependencies and security**

- Direct dependency: `Blizzard_SharedXML`, whose TOC loads the minimal-slider Lua before its XML and itself depends on the narration/shared support used by the mixins.
- It does not require `Blizzard_Settings`, a Settings category, a Setting object, SavedVariables, Ace, or a data provider.
- No secure template, protected attribute, restricted API, or combat-only operation appears in the template/mixin path.
- The source evidence and focused LIVE runtime result support ordinary non-secure addon use.

**Conclusion**

This directly answers the OBB design question: OBB can later use Blizzard's genuine minimal slider/stepper presentation without importing the Settings registration/layout subsystem. The standalone sample has now validated this control on LIVE; OBB itself has not been modified.

### 3.4 `SliderWithButtonsAndLabelTemplate` — A

**Source**

- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1376-1450`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:1161-1206`

**Verified facts**

- This is a SharedXML `ResizeLayoutFrame` using `SliderWithButtonsAndLabelMixin`.
- `SetupSlider(minValue, maxValue, value, valueStep, label)` supplies all required state.
- The slider is `300 x 20` at scale `0.7`, so its nominal visual extent is `210 x 14` before parent scaling.
- Slider artwork is `common-slider-track` and `common-slider-thumb`.
- Both buttons are `32 x 32`.
- Increment assets are `UI-SpellbookIcon-NextPage-Up`, `-Down`, and `-Disabled` plus `UI-Common-MouseHilight`.
- Decrement assets are the corresponding `UI-SpellbookIcon-PrevPage-*` files plus the same highlight texture.
- The mixin enables/disables buttons at the range endpoints and advances by the configured value step.

**State handling**

This is the only generic SharedXML slider/stepper candidate found with explicit normal, highlight, pushed, and disabled button artwork. Its visual language is the larger, older spellbook-arrow style rather than the current minimal Settings style.

**Practicality**

It is directly reusable and is useful as a comparison row, but it is visually much heavier than OBB's intended micro-adjustment controls.

### 3.5 `SliderAndEditControlTemplate` — A

**Source**

- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1582-1629`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:1208-1239`

**Verified facts**

- This SharedXML composite combines a `NumericInputBoxTemplate` (`30 x 22`) with a `UISliderTemplate` (`120 x 20`).
- It uses the same `SetupSlider` contract, mirrors slider values into the edit box, clamps finalized edit-box input, and accepts a callback through `SetCallback`.
- It has no decrement/increment buttons.

**Practicality**

It is directly reusable and provides exact micro-adjustment by numeric entry rather than steppers. It is included in the sample as an alternative interaction model, not as the answer to the arrow-button question.

## 4. Settings framework slider — B

### `Settings.CreateSlider` / `Settings.CreateSliderOptions`

**Source**

- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua:299-314, 368-405`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.lua:650-719`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.xml:114-121`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_ImplementationReadme.lua:122-143`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings_Shared.toc`

**Verified facts**

- `Settings.CreateSliderOptions(minValue, maxValue, rate)` stores the range and converts the requested rate to a step count.
- `Settings.CreateSlider(category, setting, options, tooltip)` creates a Settings initializer and adds it to a Settings category layout.
- The setting must have numeric variable type.
- The instantiated row is `SettingsSliderControlTemplate` (`280 x 26`), which creates a `MinimalSliderWithSteppersTemplate` at width 250 and binds it to the Setting object, tooltip, narration, enabled state, and initializer lifecycle.
- Ordinary addons can use the Settings registration framework for an addon category. That is supported framework use, but it is not a standalone custom-frame constructor.

**Classification rationale**

`Settings.CreateSlider` is **B** when the desired destination is an addon category inside Blizzard Settings. Directly creating `SettingsSliderControlTemplate` outside its initializer/layout/Setting lifecycle is **D**. Its visual control does not need to be copied or imitated because the underlying `MinimalSliderWithSteppersTemplate` is independently reusable as category A.

## 5. Specialized and omitted implementations

| Control | Source | Classification | Reason for omission from the sample |
| --- | --- | --- | --- |
| `PropertySliderTemplate` | `Blizzard_SharedXML/PropertySlider.xml` and `.lua` | C | It is visually `UISliderTemplate` plus `PropertyBindingMixin`/accessor/mutator behavior. No distinct slider art is gained. |
| `UserScaledSliderTemplate` | `Blizzard_AccessibilityTemplates/UserScaledSliderTemplates.xml` | B | It is a label/slider wrapper requiring `Blizzard_AccessibilityTemplates`; its actual slider is the ordinary `UISliderTemplate`. |
| `SettingsSliderControlTemplate` | `Blizzard_Settings_Shared/Blizzard_SettingControls.*` | D directly; underlying art A | Requires Settings initializer, Setting object, callback handles, tooltip, and layout lifecycle. |
| `SettingsCheckboxSliderControlTemplate` | same Settings files | D directly; underlying art A | Adds a second Setting object and checkbox/control lifecycle but uses the same minimal stepper. |
| `SettingsAdvancedSliderTemplate` and wide/checkbox variants | `Blizzard_SettingsDefinitions_Shared/Graphics.xml` and `.lua` | D directly; underlying art A | Graphics-page wrappers bind Settings data and CVars; visual slider is still the shared minimal stepper. |
| `EditModeSettingSliderTemplate` and grid-spacing slider | `Blizzard_EditMode/Shared/EditModeTemplates.*`, `EditModeManager.*` | D directly; underlying art A | Call Edit Mode dialogs/managers and require Edit Mode setting data. Visual slider is the shared minimal stepper. |
| `CustomizationOptionSliderTemplate` | `Blizzard_CustomizationUI/Blizzard_CustomizationOptionTemplates.*` | D directly; base composite A | Requires customization option data and `CustomizationFrameWithTooltipTemplate`; it inherits the generic `SliderWithButtonsAndLabelTemplate`. |
| `UnitPopupSliderTemplate` | `Blizzard_UnitPopup/UnitPopupSlider.*` | D | Property-bound UnitPopup specialization with no new visual design. |
| `OptionsSliderTemplate` | `Blizzard_FrameXML/DeprecatedTemplates.xml` | D | Explicitly located in deprecated templates; it only fixes `UISliderTemplateWithLabels` to `144 x 17`. |
| `OpacityFrameSlider` | `Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.xml` | D | A named global vertical color-picker slider (`16 x 128`, `32 x 32` vertical thumb), not a reusable virtual template. |
| `ScaleControlFrameTemplate` | `Blizzard_TransformManipulator/Blizzard_ScaleControlFrame.*` | D full control; C artwork | Housing-specific mixin calls `C_HousingExpertMode`, uses housing scale-bar assets, and has specialized fill/default-scale behavior. Its arrows are `13 x 13` and use `common-icon-backarrow` / `common-icon-forwardarrow`; those generic atlases can inform an addon-owned design, but the complete control is inappropriate. |
| `MinimalScrollBar` | `Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.*` | C for artwork context | It is a vertical scroll controller, not a value slider. Buttons are `17 x 11` and use dedicated top/bottom normal/over/down atlases. Reusing them as horizontal slider steppers would require an addon-owned reinterpretation not demonstrated by Blizzard source. |

### MinimalScrollBar state evidence

The scrollbar was inspected only because it demonstrates Blizzard's current minimal button-state pattern. `MinimalScrollBarStepperScriptsMixin` derives from `ButtonStateBehaviorMixin`, selects normal/over/down atlases, displaces its texture by `(1, -1)` while pressed, and desaturates when disabled. These mechanics are specific to the scrollbar template and are not inherited by `MinimalSliderWithSteppersTemplate`.

## 6. LIVE/PTR comparison

Live and PTR both report build `12.1.0.69497`, at the distinct revisions listed in section 1. SHA-256 comparison found the following 24 relevant files byte-identical:

- `Blizzard_SharedXML/Shared/Slider/MinimalSlider.lua` and `.xml`
- `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua` and `.xml`
- `Blizzard_SharedXML/PropertySlider.lua` and `.xml`
- `Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.lua` and `.xml`
- `Blizzard_SharedXML/Blizzard_SharedXML.toc`
- `Blizzard_Settings_Shared/Blizzard_Settings.lua`
- `Blizzard_Settings_Shared/Blizzard_SettingControls.lua` and `.xml`
- `Blizzard_Settings_Shared/Blizzard_Settings_Shared.toc`
- `Blizzard_SettingsDefinitions_Shared/Graphics.lua` and `.xml`
- `Blizzard_EditMode/Shared/EditModeTemplates.lua` and `.xml`
- `Blizzard_AccessibilityTemplates/UserScaledSliderTemplates.xml`
- `Blizzard_FrameXML/DeprecatedTemplates.xml`
- `Blizzard_TransformManipulator/Blizzard_ScaleControlFrame.lua` and `.xml`
- `Blizzard_UnitPopup/UnitPopupSlider.lua` and `.xml`
- `Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.xml`

No meaningful Live/PTR difference was found in the slider/template surface audited here.

## 7. Sample selection

`Samples/SliderComparison` demonstrates only controls whose complete implementation is reusable from `Blizzard_SharedXML`:

1. `UISliderTemplate` plus addon-owned literal `<` and `>` baseline buttons.
2. `MinimalSliderTemplate` without steppers.
3. `MinimalSliderWithSteppersTemplate` using its native `Init` and callback contract.
4. `SliderWithButtonsAndLabelTemplate` using `SetupSlider`.
5. `SliderAndEditControlTemplate` using `SetupSlider` and `SetCallback`.

Every row uses the equivalent range `0-100`, current value `50`, and step `5`. Settings, Edit Mode, customization, scrollbar, and housing-owned wrappers are intentionally omitted rather than faked.

## 8. LIVE runtime evidence

### Test environment

- World of Warcraft Retail LIVE
- Build `12.1.0.69497`
- Standalone addon: `Samples/SliderComparison`

The user manually copied the sample into the Retail AddOns directory and tested it in game. All five comparison rows displayed successfully.

### `MinimalSliderWithSteppersTemplate` result

**RUNTIME EVIDENCE:** The directly created SharedXML control displayed initial value 50, its native left/right steppers worked, values advanced by the configured step of 5, normal slider interaction worked, and no Lua error occurred. The sample required neither the Blizzard Settings subsystem nor custom stepper handlers.

Classification **A — directly reusable** is therefore retained and runtime-supported for the tested standalone scenario.

### Initial callback/readout bug and correction

The first test displayed value 50 initially, then displayed 487 after either native stepper was clicked. Further clicks continued displaying 487, with no Lua error.

**SOURCE-BACKED ROOT CAUSE:** The slider itself was functioning correctly. `Init(50, 0, 100, 20, nil)` set the native step to `(100 - 0) / 20 = 5`. `MinimalSliderWithSteppersMixin` passed the changed slider value to `CallbackRegistryMixin:TriggerEvent`, but CallbackRegistry invokes ordinary function callbacks as `func(owner, ...)`. The sample had registered `function(value)`, so its readout formatted CallbackRegistry's generated owner ID—487 in that runtime session—instead of the second argument containing the slider value.

The sample callback was corrected from:

```lua
function(value)
```

to:

```lua
function(_, value)
```

No clamp, Settings object, replacement arrow handler, or other workaround was added. After this correction, the user retested on the same LIVE build and confirmed correct stepper and slider behavior.

### Screenshot and visual observations

`Samples/SliderComparison/SliderComparison.png` is the real screenshot from the successful LIVE comparison. It shows all five tested rows in the standalone comparison frame.

The user's visual preference is `MinimalSliderWithSteppersTemplate` because it is modern, compact, and visually consistent with current Blizzard UI. The sample's nearly borderless dark comparison frame was also positively received as a clean UI presentation. That frame observation is a future UI reference only, not an OBB design requirement.

### Verified source facts

- All five demonstrated controls are defined by `Blizzard_SharedXML` and have direct initialization paths that do not require Settings data.
- None of those paths declares secure/protected behavior or calls a restricted gameplay API.
- The sample is non-secure, does not register combat events, and does not interact with protected game frames.

### Not established by this test

- Actual atlas pixel dimensions returned by `C_Texture.GetAtlasInfo` for the minimal/common atlases.
- Untested interaction modes or contexts such as narration, keyboard control, combat, or other UI scales.
- Production integration behavior inside OBB, which was not modified or tested.

## 9. Recommendation

The preferred candidate for a future OBB slider implementation is `MinimalSliderWithSteppersTemplate`. It is the genuine visual control used by current Settings sliders, yet its implementation is independently housed in SharedXML. The standalone LIVE test verified direct creation, initial value, step-5 native buttons, normal slider interaction, and the absence of a Settings dependency or custom stepper logic.

Any future OBB implementation should preserve the verified `Init` step-count contract and CallbackRegistry owner-first callback signature. This research records a preferred candidate; it does not state that OBB has been modified.
