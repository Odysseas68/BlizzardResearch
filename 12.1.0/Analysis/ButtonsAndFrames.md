# Retail 12.1 Button and Frame/Dialog Controls

## 1. Scope and source provenance

This document inventories representative Blizzard-native button and frame/dialog controls that are relevant to ordinary third-party addon configuration UI. It is a source audit and sample-planning document only. It does not modify OdysseusBuffBars or OdysseusUtilitySuite, and it does not create or install a sample addon.

The authoritative local mirrors inspected were:

- LIVE: `D:\WowDEV\Reference\Blizzard\wow-ui-source`
  - branch `live`
  - commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
  - commit description `12.1.0 (69497)` dated 2026-08-25
  - `version.txt`: `12.1.0.69497`
- PTR: `D:\WowDEV\Reference\Blizzard\wow-ui-source-ptr`
  - branch `ptr`
  - commit `e9e8bf68cb7b4177566532f8da9373590759587d`
  - commit description `12.1.0 (69497)` dated 2026-08-24
  - `version.txt`: `12.1.0.69497`

The installed client's active Retail (`wow`) and test (`wowt`) records in `.build.info` also report `12.1.0.69497`. The LIVE mirror therefore matches the active Retail client installed on this machine. No fetch, pull, or other mirror update was performed. This establishes current local parity; it does not independently establish that no later public build exists elsewhere.

The LIVE mirror had a pre-existing untracked `.codex/` directory. The PTR mirror reported no changes. Neither mirror was modified.

The BlizzardResearch repository started clean on `main` at `64fe9b2262bc01293a565758726a1cfadeb43be9`, equal to `origin/main`.

This work deliberately does not repeat the completed slider and scrollbar analysis in [SliderControls.md](SliderControls.md). Scroll-related source was consulted only where it established a general button-state pattern.

## 2. Classification and availability model

### 2.1 Classification

- **A — CURRENT GENERAL-PURPOSE:** actively used and reasonably reusable by a third-party addon.
- **B — CURRENT SPECIALIZED:** actively used, but coupled to a Blizzard subsystem or a specific semantic role.
- **C — LEGACY BUT SUPPORTED:** older construction or visual language that remains present and usable.
- **D — INTERNAL / NOT RECOMMENDED:** technically present, but framework ownership, global instances, or specialized behavior make it a poor general dependency.
- **E — UNCERTAIN:** the source does not establish a normal, supported third-party use path.

Classification is based on definitions, inheritance, TOCs, initialization paths, and current Retail use sites. The existence of a global template or mixin alone is not treated as proof of general addon suitability.

### 2.2 Availability groups

**Broad shared controls**

- `Blizzard_SharedXML` is not load-on-demand. Its TOC loads the button, NineSlice, dialog, panel, portrait, and resize sources cited below. A standalone addon can declare `## Dependencies: Blizzard_SharedXML` for an explicit load-order contract.
- `Blizzard_UIPanelTemplates` is `DefaultState: enabled`, Mainline/game-only, and depends on `Blizzard_SharedXMLGame`. It is also a dependency of `Blizzard_FrameXML`. Its `BasicFrameTemplate` family is available, but is older manual-texture construction.

**Settings shared controls**

- `Blizzard_Settings_Shared` is not load-on-demand. It depends on `Blizzard_SharedXML` and defines `SettingsFrameTemplate` plus the Settings registration/control lifecycle.
- `Blizzard_Settings` itself is load-on-demand, but it is tracking/definition content rather than the source of the reusable visual shell. Loading `Blizzard_Settings` is not required to instantiate `SettingsFrameTemplate` or the SharedXML button families.

**Feature-owned controls**

- A template defined inside a load-on-demand feature addon can generally be made available only by loading or depending on that feature addon. `C_AddOns.LoadAddOn` is appropriate only when that addon's metadata and current state permit it.
- Loading a large Blizzard feature merely to borrow an internal control is not recommended. It imports lifecycle assumptions and can create globals or UI state unrelated to the addon's configuration dialog.

## 3. Executive inventory

| Candidate | Classification | Definition | Practical conclusion |
| --- | --- | --- | --- |
| `UIPanelButtonTemplate` | A | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml` plus `SecureUIPanelTemplates.xml` | Current standard action button; old visual language, but still used by Settings and many Retail systems. |
| `SharedButton*Template` | A | `Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.*` | Current red atlas-based three-slice action family with several fixed size/font variants. |
| `SharedGoldRedButton*Template` | B | same files | Current gold-accented specialized variant for elevated/special actions; not a semantic destructive template. |
| `SquareIconButtonTemplate` | A | `Blizzard_SharedXML/Shared/Button/IconButtonTemplate.*` | Current in-game square icon button; caller supplies the icon and click behavior. |
| `CommonSquareIconButtonTemplate` | E | same files | Atlas-backed derivative whose only direct current inheritance found is in character-select glue UI, not an in-game Retail addon. |
| `UIPanelCloseButton` | A | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.*` | Current shared 24-pixel close control with complete visual states and standard hide behavior. |
| `MinimalTabTemplate` | B | `Blizzard_SharedXML/Shared/Tabs/MinimalTab.*` | Reusable modern Settings-style selected tab; semantically a tab, not a general action button. |
| `UIPanelDynamicResizeButtonTemplate` | A | `Blizzard_SharedXML/Shared/Button/UIPanelButtonTemplates.*` | Standard button that widens on load for localized text; no distinct visual design. |
| `NineSliceCheckButtonTemplate` | E | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.*` | A genuine stateful NineSlice check-button base, but no current Retail use site was found and it needs caller-provided layout/atlas configuration. |
| `DefaultPanelTemplate` / `DefaultPanelFlatTemplate` | A | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.*` | Current title-bearing NineSlice panel shells; caller supplies close button and interaction behavior. |
| `SettingsFrameTemplate` | A | `Blizzard_Settings_Shared/Mainline/Blizzard_SettingsPanelTemplates.xml` | Exact modern Settings-style shell; visually independent of Settings registration and reused by Photo Sharing. |
| `DialogBorder*Template` + `DialogHeaderTemplate` | A | `Blizzard_SharedXML/Shared/Dialog/DialogTemplates.*` | Current composable dialog shell/header family with normal, dark, translucent, and opaque backgrounds. |
| `ButtonFrameTemplate` / `PortraitFrameTemplate` | A | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.*`, `PortraitFrame.lua` | Widely used full Blizzard window family with title, close button, portrait, and optional inset/button area. |
| `BasicFrameTemplate*` | C | `Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml` | Supported manual-texture title/close shell; current use is sparse and the construction predates shared NineSlice panels. |
| `UIPanelDialogTemplate` | C | `Blizzard_SharedXML/SharedBasicControls.xml` | Manual anchored-texture dialog with title and close button; only one current Retail use site was found. |
| `StaticPopupTemplate` | D | `Blizzard_StaticPopup_Game/GameDialog.*` | Framework-owned popup instance/pool lifecycle, keyboard behavior, scaling, and dialog data; use `StaticPopup_Show` rather than direct template creation. |
| `BaseNineSliceDialog` | D | `Blizzard_SharedXML/SharedBasicControls.*` | Glue-announcement shell with fixed texture kits, underlay, CVar close behavior, and UIParent positioning. |

## 4. Button research

### 4.1 `UIPanelButtonTemplate` — A, current general-purpose

**Definition and inheritance**

- `Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.xml:39-86`
  - `UIPanelButtonNoTooltipTemplate`
  - `UIButtonFitToTextBehaviorMixin`
  - intrinsic size `40 x 22`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:315-320`
  - `UIPanelButtonTemplate`
  - inherits `UIPanelButtonNoTooltipTemplate`
  - adds `UIPanelButtonMixin`
- `Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.lua:36-91`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:215-241`

The `SecureUIPanelTemplates` filename does not make this a protected action button. The definition does not inherit a secure action template, register protected attributes, or call a restricted gameplay API.

**Artwork and states**

- Normal, pushed, and disabled states use slices of `Interface\Buttons\UI-Panel-Button-Up`, `-Down`, and `-Disabled`.
- Hover uses `UIPanelButtonHighlightTexture` from `UI-Panel-Button-Highlight`.
- Normal, highlight, and disabled font objects are declared.
- It has no persistent selected/toggled state. Use a CheckButton/SelectableButton-derived control when the semantic state must persist.

**Sizing and setup**

- The base is `40 x 22`; normal use sites set a wider caller-supplied width.
- `SetTextToFit(text)` or `FitToText()` explicitly sizes to text plus the default 40-pixel padding. Ordinary `SetText()` does not invoke those methods.
- `UIPanelDynamicResizeButtonTemplate` adds an `OnLoad` calculation that can widen, but never shrink, based on text plus 40 pixels. It is useful for localization, but looks identical.
- `UIPanelButtonHeightScaledTemplate` adjusts the side-slice widths for a caller-supplied height. Its own source warns that larger sizes can look bad.

**Current use and suitability**

The Settings action row constructs this exact template in `Blizzard_SettingControls.lua:830-864`. Settings Close, Apply, and Defaults buttons also use it. A focused current-use search found broad Mainline use across Blizzard UI, so it is not obsolete even though its art is traditional.

No load-on-demand feature is required beyond SharedXML. It is suitable for ordinary non-secure configuration actions.

### 4.2 `SharedButton*Template` / `ThreeSliceButtonTemplate` — A, current general-purpose

**Definition and inheritance**

- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml:4-95`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.lua:2-111`
- `ThreeSliceButtonMixin = CreateFromMixins(UIButtonMixin)`

Variants are:

| Template | Default size | Font role |
| --- | --- | --- |
| `SharedButtonTemplate` | `200 x 30` | normal |
| `SharedButtonLargeTemplate` | `200 x 30` | larger text |
| `SharedButtonSmallTemplate` | `138 x 28` | normal |
| `SharedButtonExtraSmallTemplate` | `50 x 20` | small |

**Artwork and states**

- The family uses the `128-RedButton` atlas kit.
- Left, tiled center, and right pieces have normal, `-Pressed`, and `-Disabled` variants.
- Highlight uses `128-RedButton-Highlight`.
- The mixin reads atlas metadata with `C_Texture.GetAtlasInfo`, scales the end caps from the button height, and clips them if the caller makes the button narrower than both caps.
- It has no persistent selected state.

**Sizing and setup**

- Each named variant has an intrinsic default size, but callers may change it.
- Text does not automatically resize the button. The caller should choose a suitable variant or set width explicitly.
- The template controls visual mouse states. It does not wire `UIButtonMixin:OnClick`; callers normally attach an `OnClick` script.

**Current use and suitability**

Current Retail use includes AddOn List OK/Cancel/Enable/Disable, cinematic dialog actions, encounter UI, Transmog, Raid UI, shopping/cart flows, and new Housing flows. This is the strongest genuinely newer alternative to the older UIPanel action-button look.

The red palette is a general Blizzard action-button theme, not a destructive semantic. AddOn List uses `SharedButtonSmallTemplate` for both OK and Cancel, which disproves any safe “red means delete” rule.

### 4.3 `SharedGoldRedButton*Template` — B, current specialized with special-action styling

**Definition**

- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml:97-131`
- Same `ThreeSliceButtonMixin` and state logic as the red family.

Variants include `SharedGoldRedButtonTemplate`, `SharedGoldRedButtonLargeTemplate`, `SharedGoldRedButtonSmallTemplate`, and `SharedGoldRedButtonExtraLargeTemplate`. The atlas kit is `128-GoldRedButton`.

Current uses include the Plunderstorm store, Catalog Shop, reward-track skip, and the Reputation “View Renown” action. The family communicates elevated or special emphasis, but the source does not define it as destructive.

Blizzard also uses action-specific `UIButtonTemplate` art kits such as `128-RedButton-Delete` in shopping-cart and Perks code. Those are atlas conventions on specialized controls, not a globally defined `DestructiveButtonTemplate`. A general sample should not claim semantic destructive support from those assets alone.

### 4.4 `SquareIconButtonTemplate` and `CommonSquareIconButtonTemplate`

**Definition and inheritance**

- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/IconButtonTemplate.lua`
- `IconButtonTemplate` inherits `UIButtonTemplate` and adds `IconButtonMixin`.
- `SquareIconButtonTemplate` inherits `IconButtonTemplate`; default `32 x 32`, icon `16 x 16`.
- `CommonSquareIconButtonTemplate` inherits `SquareIconButtonTemplate`; default `48 x 48`, icon `24 x 24`, with a 6-pixel hit inset.

**Artwork and setup**

- `SquareIconButtonTemplate` uses the older `UI-SquareButton-Up/Down/Disabled` files and `UI-Common-MouseHilight`.
- `CommonSquareIconButtonTemplate` replaces the chrome with `common-button-square-gray-up` and `common-button-square-gray-down` atlases. Its highlight covers the icon region at 40% alpha.
- Supply `icon`/`iconAtlas` as key values in XML, or call `SetIcon(texture)` / `SetAtlas(atlas, useAtlasSize)` after creation.
- Supply the click handler with `SetOnClickHandler` or an ordinary script.
- `SetEnabledState(enabled)` desaturates the icon as well as enabling/disabling the button. Calling only the native `Disable()` changes the background through the declared disabled texture but does not run that explicit icon-desaturation helper.

**States and current use**

Normal, hover, pushed, and disabled background states exist. The icon is displaced while pressed. There is no persistent selected state.

Current in-game Retail use of `SquareIconButtonTemplate` includes Auction House favorite search, Friends contacts menu, Professions favorite search, and the shared `RefreshButtonTemplate`. It is classified **A — current general-purpose** and is the source-supported icon-only sample candidate.

The only direct current inheritance of `CommonSquareIconButtonTemplate` found outside its definition is `CharacterSelectRotateButtonTemplate` in Mainline character-select glue UI. Although the template is defined in broadly loaded SharedXML, the source does not establish it as a normal in-game Retail control. It is therefore classified **E — uncertain** for an addon sample and is documented but not proposed.

### 4.5 `UIPanelCloseButton` — A, current general-purpose

**Definition**

- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:134-157`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:137-180`

The visual base `UIPanelCloseButtonNoScripts` is `24 x 24` and supplies complete `RedButton-Exit` normal, pushed, disabled, and highlight atlases. `UIPanelCloseButton` adds `UIPanelCloseButton_OnClick`; `UIPanelCloseButtonDefaultAnchors` also anchors at the parent's top right.

The standard click path invokes optional `parent.onCloseCallback` and then `HideUIPanel(parent)`. Use `UIPanelCloseButtonNoScripts` when the parent needs a different close lifecycle.

This remains ubiquitous across current Retail. The proposed frame examples already expose it, so a separate close-button-only row is unnecessary in the eventual comparison sample.

### 4.6 `MinimalTabTemplate` — B, current specialized but directly reusable for tabs

**Definition and inheritance**

- `Interface/AddOns/Blizzard_SharedXML/SelectableButton.xml` / `.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Tabs/MinimalTab.xml` / `.lua`
- `MinimalTabTemplate` inherits `SelectableButtonTemplate` and uses `MinimalTabMixin`.

It defaults to `100 x 37`, sets its text from `tabText`, and automatically sets width to text width plus 40 pixels. It uses `Options_Tab_*` normal/over atlases and `Options_Tab_Active_*` selected atlases. `SelectableButtonMixin` owns the persistent selected boolean; `CreateRadioButtonGroup()` is the current helper when exactly one tab should remain selected.

The current use sites are Settings Game/AddOns tabs and the Graphics Base/Raid tabs. It is not a general push button, but it is directly reusable from SharedXML for a tab strip and is the relevant modern Settings selected-state example.

### 4.7 Text-plus-icon patterns

No complete, general SharedXML action template was found that simultaneously supplies a standard text label, icon region, automatic layout, and modern action-button chrome.

`UIMenuButtonStretchTemplate` has a text region and its mixin will move an optional `Icon` while pressed, but the base template does not create that icon. `UIResettableDropdownButtonTemplate` adds a specific dropdown arrow and reset behavior, so it is not a general text-plus-icon action control. Blizzard feature code frequently composes its own icon region or mixes `UIButtonTemplate` into another base.

For a normal addon, an addon-owned icon texture anchored beside the text of a reusable shared button is less coupled than importing a feature-specific composite. No text-plus-icon candidate is proposed for the first sample.

### 4.8 NineSlice-backed buttons

`NineSliceCheckButtonTemplate` genuinely exists in `SharedUIPanelTemplates.xml:1232-1292`, with `NineSliceCheckButtonMixin` in the companion Lua. It maintains separate Normal, Pushed, Highlight, and Checked NineSlice children and switches their visibility for mouse and checked states.

However:

- no current Retail use site outside its own definition was found;
- the caller must supply a layout type and normal/pushed/highlight/checked atlas keys with a compatible corner layout;
- its source does not add a disabled visual state;
- it is a CheckButton base, not a text action button.

It is therefore classified **E — uncertain** and omitted from the proposed sample. The mere presence of the template is not enough to call it a supported modern general-purpose button family.

## 5. Frame and dialog research

### 5.1 `DefaultPanelTemplate` and `DefaultPanelFlatTemplate` — A

**Definition and inheritance**

- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:404-536`
- `Interface/AddOns/Blizzard_SharedXML/PortraitFrame.lua:2-30`
- Both inherit `DefaultPanelBaseTemplate`, which uses `DefaultPanelMixin = CreateFromMixins(TitledPanelMixin)`.

**Supplied structure**

- Default size: `338 x 424`.
- `TitleContainer.TitleText` is supplied automatically.
- `NineSlice` is supplied automatically with `layoutType="ButtonFrameTemplateNoPortrait"`.
- `DefaultPanelTemplate` adds a tiled rock background and top streaks.
- `DefaultPanelFlatTemplate` adds `FlatPanelBackgroundTemplate`, which uses atlas corners plus colored flat textures.
- Neither variant supplies a close button, drag bar, parent, strata, or show/hide policy. The caller provides those pieces.

Current uses include Help, Hero Talents selection, Housing, Photo Sharing, Group Loot, Professions dialogs, and customer-order views. The flat variant is also the base of the reusable `ScrollingFlatPanelTemplate`.

These are good low-coupling configuration shells. Their NineSlice child uses the standard high decorative frame-level convention; callers should set their own top-level strata and should not assume the template makes a movable or top-level window.

### 5.2 `SettingsFrameTemplate` — A, exact Settings-style shell with a Settings-shared dependency

**Definition**

- `Interface/AddOns/Blizzard_Settings_Shared/Mainline/Blizzard_SettingsPanelTemplates.xml:4-30`
- TOC: `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings_Shared.toc`

The template has no mixin and no Settings data lifecycle. It supplies:

- `Bg`, inheriting `FlatPanelBackgroundTemplate`;
- a `NineSlicePanelTemplate` border using `ButtonFrameTemplateNoPortrait`;
- `NineSlice.Text` as the title;
- `ClosePanelButton`, inheriting `UIPanelCloseButtonDefaultAnchors`.

It does not provide a size, parent, frame strata, movement, resizing, category list, footer, or action buttons. The caller supplies those.

**Independent-use evidence**

`SettingsPanel` inherits the shell and then supplies the category list, search box, footer buttons, and framework mixin. Separately, `Blizzard_PhotoSharing/Blizzard_PhotoSharing.xml:3` inherits the same shell with its own `PhotoSharingMixin` and no Settings category lifecycle. That second use establishes that the visual template is not intrinsically coupled to Settings registration.

An addon should declare `Blizzard_Settings_Shared` as a dependency if it directly uses this template. It does not need to load the load-on-demand `Blizzard_Settings` addon.

### 5.3 `DialogBorder*Template` and `DialogHeaderTemplate` — A, composable current dialog family

**Definition**

- `Interface/AddOns/Blizzard_SharedXML/Shared/Dialog/DialogTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Dialog/DialogTemplates.lua`

`DialogBorderNoCenterTemplate` inherits `NineSlicePanelTemplate`, uses parent level, fills its parent, and sets the `Dialog` layout. Four center variants are available:

- `DialogBorderTemplate`: tiled `UI-DialogBox-Background`;
- `DialogBorderDarkTemplate`: tiled `UI-DialogBox-Background-Dark`;
- `DialogBorderTranslucentTemplate`: black color texture at alpha 0.8;
- `DialogBorderOpaqueTemplate`: opaque black color texture.

The parent owns the actual size, strata, interaction, title, and close behavior. The border alone has no intrinsic size because it fills the parent.

`DialogHeaderTemplate` is a separate atlas-backed header. It defaults to `200 x 39`, anchors above the parent, uses the `UI-Frame-DiamondMetal-Header-*` atlases, and automatically adjusts its width to text width plus 64 pixels through `DialogHeaderMixin:Setup(text)`.

This family is actively used in Calendar, Communities, Edit Mode, Group Finder, Color Picker, Rating, Quick Keybind, current talent dialogs, and other Retail interfaces. It is an excellent compact-dialog candidate. A sample should compose an addon-owned frame with `DialogBorderDarkTemplate`, `DialogHeaderTemplate`, and `UIPanelCloseButtonDefaultAnchors`.

### 5.4 `ButtonFrameTemplate` and portrait families — A, current general-purpose traditional window

**Definition and inheritance**

- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:544-708`
- `Interface/AddOns/Blizzard_SharedXML/PortraitFrame.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:48-135`

`PortraitFrameBaseTemplate` supplies:

- default size `338 x 424`;
- `NineSlice` border using `PortraitFrameTemplate` layout;
- `PortraitContainer.portrait` and a circular mask;
- `TitleContainer.TitleText`;
- `PortraitFrameMixin` methods for title, portrait, border, and frame-level management.

`PortraitFrameTemplate` adds a close button. `PortraitFrameFlatTemplate` uses the flat background family and a close button.

`ButtonFrameTemplate` inherits the portrait base, adds the rock background/top streaks, a close button, and an `InsetFrameTemplate` content area. Helper functions change the inset for a bottom button bar or attic and can hide/show the portrait by switching NineSlice layouts. The template does not itself create footer action buttons; `MagicButtonTemplate` is the companion `80 x 22` UIPanel-style footer button.

This family remains pervasive in current Retail. AddOn List, Cooldown Viewer Settings, Friends, Character, Mail, Merchant, Professions Book, Housing Model Preview, and Social UI include direct `ButtonFrameTemplate` consumers. Auction House, Collections, Encounter Journal, and the main Professions window instead use related `PortraitFrameTemplate` branches; they share the portrait-frame foundation but do not inherit `ButtonFrameTemplate` itself. The focused usage audit below preserves that distinction.

The templates do not set a parent or top-level strata. Decorative children use the established approximately 400/500/510 frame-level convention; `PortraitFrameMixin:SetFrameLevelsFromBaseLevel` is available when the caller needs an explicit base.

#### 5.4.1 `ButtonFrameTemplate` usage in Retail 12.1

##### Authoritative definition and supplied structure

The authoritative Mainline definition is `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:544-708`. Behavior is split between `Interface/AddOns/Blizzard_SharedXML/PortraitFrame.lua:2-130` and `Mainline/SharedUIPanelTemplates.lua:48-135`; its NineSlice layouts are in `Mainline/NineSliceLayouts.lua:17-79`.

`ButtonFrameTemplate` has no dedicated `ButtonFrameMixin`. Its mixin comes from this chain:

```text
PortraitFrameBaseTemplate [PortraitFrameMixin -> TitledPanelMixin]
|-- PortraitFrameTexturedBaseTemplate
|   `-- PortraitFrameTemplateNoCloseButton
|       `-- PortraitFrameTemplate
|           `-- PortraitFrameTemplateMinimizable
|-- PortraitFrameFlatBaseTemplate
|   `-- PortraitFrameFlatTemplate
`-- ButtonFrameBaseTemplate
    `-- ButtonFrameTemplate
        |-- ButtonFrameTemplateMinimizable
        |-- SocialUIIgnoreListFrameTemplate
        |-- CurrencyTransferMenuTemplate
        `-- CurrencyTransferLogTemplate
```

The two top-level branches are related, but neither `PortraitFrameTemplate` nor `ButtonFrameTemplate` inherits the other. Both ultimately inherit `PortraitFrameBaseTemplate`. This is why windows can share title, portrait, close-button, and metal-border language without being `ButtonFrameTemplate` consumers.

`PortraitFrameBaseTemplate` supplies the default `338 x 424` size, `NineSlice`, `PortraitContainer.portrait` with a circular mask, and `TitleContainer.TitleText`. `ButtonFrameBaseTemplate` adds the tiled rock background, top streaks, and `UIPanelCloseButtonDefaultAnchors`. `ButtonFrameTemplate` adds the intrinsic `Inset`, an `InsetFrameTemplate` anchored from `(4, -60)` to `(-6, 26)`.

The caller still owns the parent, top-level strata, placement, movement, title text, portrait texture, feature content, show/hide policy, and action buttons. The inherited size is only a default. A consumer may replace it, as the comparison sample does.

##### Direct, indirect, and related use

An exact Mainline XML inheritance scan, excluding Classic-version directories, found 44 records inheriting the exact `ButtonFrameTemplate` token: four virtual derivatives and 40 concrete declarations. Some concrete records are glue UI, anonymous child frames, or the source example, so the count is evidence of breadth rather than 40 distinct major Retail feature windows. No Lua `CreateFrame(..., "ButtonFrameTemplate")` construction was found; concrete construction in this source snapshot is declared in XML. Lua occurrences predominantly configure title/portrait state or call the shared attic/button-bar/portrait helpers. Comments and `ExampleButtonFrame` were not counted as representative feature use.

Representative verified consumers are:

| Relationship | Concrete consumer | Source-backed role and additions |
| --- | --- | --- |
| direct `ButtonFrameTemplate` | `MerchantFrame` | `Blizzard_UIPanels_Game/Mainline/MerchantFrame.xml:91`; vendor item grid, buyback presentation, repair controls, and merchant bottom art are consumer-owned. Lua sets the NPC/buyback title and portrait. |
| direct `ButtonFrameTemplate` | `CharacterFrame` | `Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml:147`; character subframes and extra inset are consumer-owned. Lua hides the button bar and updates title and portrait by selected subframe. |
| direct `ButtonFrameTemplate` | `AddonList` | `Blizzard_AddOnList/AddonList.xml:120`; its mixin sets the title and deliberately calls `ButtonFrameTemplate_HidePortrait`. |
| direct `ButtonFrameTemplate` | `CooldownViewerSettings` | `Blizzard_CooldownViewer/CooldownViewerSettings.xml:153`; the consumer anchors its scrolling content to the inherited `Inset`, sets its title, and supplies a specialization portrait. This is current configuration-window evidence. |
| direct `ButtonFrameTemplate` | `FriendsFrame`, `MailFrame`, `OpenMailFrame` | `Blizzard_FriendsFrame/Mainline/FriendsFrame.xml:478` and `Blizzard_MailFrame/MailFrame.xml:274,877`; these use the shared shell while supplying tabs, lists, mail content, titles, portraits, and button-bar state. |
| direct `ButtonFrameTemplate` | `ProfessionsBookFrame` | `Blizzard_ProfessionsBook/Blizzard_ProfessionsBook.xml:325`; Lua supplies the Spellbook portrait/title and hides both attic and button bar. |
| indirect through `ButtonFrameTemplateMinimizable` | `CommunitiesFrame`, `DressUpFrame` | `Blizzard_Communities/CommunitiesFrame.xml:304` and `Blizzard_UIPanels_Game/Mainline/DressUpFrames.xml:272`. The derivative only changes the NineSlice layout key; each feature separately adds minimization behavior/control. |
| indirect through feature templates | Social UI ignore list and currency transfer menu/log | `SocialUIIgnoreListFrameTemplate`, `CurrencyTransferMenuTemplate`, and `CurrencyTransferLogTemplate` inherit `ButtonFrameTemplate`; their concrete instances are in `Blizzard_SocialUI/Mainline/SocialUI.xml:45`, `Blizzard_TokenUI/Blizzard_CurrencyTransfer.xml:297`, and `Blizzard_TokenUI/Blizzard_TokenUI.xml:179`. |

`ButtonFrameTemplateMinimizable` should not be read as a complete minimizable window by itself. Its XML contribution is the `PortraitFrameTemplateMinimizable` layout key. `MaximizeMinimizeButtonFrameTemplate` and its mixin are separate shared components that concrete consumers add and initialize.

##### Auction House, Merchant, and other familiar major windows

**AUCTION HOUSE — VERIFIED:** the main `AuctionHouseFrame` directly inherits `PortraitFrameTemplate` in `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.xml:4`. It does not directly or indirectly inherit `ButtonFrameTemplate`. Its own XML adds an independent money inset, tabs, search/category/results areas, and buy/sell/auction panes. Its Lua sets the NPC portrait and title through the shared `PortraitFrameMixin`. It therefore uses the related portrait-frame family, not the ButtonFrame inset/footer branch. A nested `GameTimeTutorial` in the WoW Token UI does inherit `ButtonFrameTemplate`, but that does not change the main Auction House conclusion.

**MERCHANT / VENDOR — VERIFIED:** the main `MerchantFrame` directly inherits `ButtonFrameTemplate` in `Blizzard_UIPanels_Game/Mainline/MerchantFrame.xml:91`. `MerchantFrame.lua:268-269` uses the inherited title and portrait methods for the current NPC; lines 507-508 swap them for buyback. The vendor grid, specialized bottom border, repair/sell-junk controls, paging, and buyback content are consumer additions. The user's association between the sample and the Merchant shell is therefore directly source-backed.

**COLLECTIONS AND ENCOUNTER JOURNAL — VERIFIED RELATED FAMILY:** `CollectionsJournal` and `EncounterJournal` directly inherit `PortraitFrameTemplate`, not `ButtonFrameTemplate`, in `Blizzard_Collections/Mainline/Blizzard_Collections.xml:14` and `Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.xml:1333`.

**PROFESSIONS — VERIFIED MIXED USE:** the main `ProfessionsFrame` inherits `PortraitFrameTemplateNoCloseButton, TabSystemOwnerTemplate` in `Blizzard_Professions/Blizzard_ProfessionsFrame.xml:7`; its nested `MinimizedSearchResults` directly inherits `ButtonFrameTemplate` at line 178 of `Blizzard_ProfessionsCrafting.xml`. The separate `ProfessionsBookFrame` is a direct ButtonFrame consumer. “Professions uses ButtonFrameTemplate” is therefore true only for specific windows, not the main modern crafting shell.

**CHARACTER — VERIFIED:** the main `CharacterFrame` directly inherits `ButtonFrameTemplate`. This is direct evidence that the template supports a major multi-page feature window, not merely small dialogs.

##### Portrait, title, inset, attic, and footer behavior

- **Portrait:** the portrait texture region and circular mask are intrinsic, but the texture is caller-supplied and the portrait is optional in practice. `PortraitFrameMixin` provides asset, unit, bag, raw texture, atlas, class, and specialization helpers. `ButtonFrameTemplate_HidePortrait` switches to the `ButtonFrameTemplateNoPortrait` NineSlice layout, hides the portrait, shifts background/inset left anchors, and expands the title anchors from portrait-aware `(58, -24)` offsets to `(0, 0)`. `ShowPortrait` reverses those changes. AddOn List is a concrete hide-portrait example.
- **Title:** the title region and `SetTitle`/format/color/offset helpers are intrinsic; title text is caller-supplied. Portrait visibility changes the standard title placement through the helpers above.
- **Inset:** the marble-background NineSlice `InsetFrameTemplate` is intrinsic to `ButtonFrameTemplate`, not to the sibling `PortraitFrameTemplate`. Consumers commonly anchor their content to it, replace its visual contents, add extra insets, or change its top/bottom anchors with shared helpers.
- **Attic:** “attic” is helper terminology for the tall top content offset. `ShowAttic` uses a 60-pixel top inset and shows top streaks; `HideAttic` moves the inset to 24 pixels and hides the streaks. It is behavior around inherited regions, not an additional child frame named Attic.
- **Bottom/footer:** the default inset ends 26 pixels above the bottom, leaving space for buttons. `ShowButtonBar` restores that 26-pixel offset; `HideButtonBar` moves it to 4 pixels. The template creates no footer container and no action button. `MagicButtonTemplate` is a separate `80 x 22` companion whose `OnLoad` normalizes bottom-corner and adjacent-button spacing.

In the LIVE-tested `ButtonFrameComparison` sample, the real template supplied the NineSlice metal border, portrait region/mask, title region, close button, rock background/top streaks, intrinsic inset, and default footer reservation. The sample supplied the parent/position, its overriding `600 x 330` size, title text, gear portrait texture, body content, click handler, and the separate `MagicButtonTemplate` labeled `OK`. The screenshot therefore shows real ButtonFrame chrome plus explicit sample configuration; the `OK` button is not automatically created by `ButtonFrameTemplate`.

##### Structural comparison with `SettingsFrameTemplate`

`SettingsFrameTemplate` is a lighter flat shell: flat background, no-portrait `ButtonFrameTemplateNoPortrait` NineSlice layout, title string, and close button. It has no portrait mixin, default size, content inset, attic convention, or reserved bottom button area. Its consumers construct their own content/footer architecture. `ButtonFrameTemplate` supplies substantially more traditional feature-window structure: a default size, portrait-aware title/border, rock background, inset, and standard top/bottom spacing helpers.

Concrete use matches that structural difference. Photo Sharing proves `SettingsFrameTemplate` can be an independent modern flat window, while Merchant, Character, Friends, Mail, AddOn List, Cooldown Viewer Settings, Communities, and other features demonstrate ButtonFrame-family use for richer standalone feature, browser, social, and configuration windows.

##### Edit Mode and the dialog-border family

**VERIFIED:** the visual association is family-level, not an exact template match. Edit Mode's ordinary layout dialogs compose `DialogBorderTemplate` with their own `FontString` titles in `Blizzard_EditMode/Shared/EditModeDialogs.xml:28-62`. `EditModeSystemSettingsDialog` uses `DialogBorderTranslucentTemplate` plus its own title and `UIPanelCloseButton` at lines 254-285. `EditModeManagerFrame` likewise uses `DialogBorderTranslucentTemplate`, its own title, and close button in `EditModeManager.xml:4-50`.

No `DialogBorderDarkTemplate` or `DialogHeaderTemplate` use was found inside `Blizzard_EditMode`. The comparison sample's `DialogBorderDarkTemplate + DialogHeaderTemplate` shell therefore uses the same current shared dialog-border visual system, but it is not the exact Edit Mode composition.

##### Practical role: verified facts and engineering implications

**VERIFIED:** direct consumers demonstrate that `ButtonFrameTemplate` supports substantial standalone feature windows, multi-page browsers, social/mail interfaces, a vendor, and at least one current configuration window. Its supplied portrait-aware border, inset, and optional top/bottom reservations make it more than a bare dialog border. Direct Merchant and Character use source-back the user's association with major Blizzard feature windows. Auction House, Collections, Encounter Journal, and the main Professions frame show that closely related major windows may instead stop at the sibling PortraitFrame branch.

**INFERENCE FOR ADDON DESIGN:** `ButtonFrameTemplate` is a strong candidate when an addon wants a traditional, content-heavy Blizzard feature-window identity with a portrait and bounded inset. It is heavier than necessary for a compact modal dialog and visually more traditional than `SettingsFrameTemplate`. This is an engineering interpretation of current consumers, not a Blizzard compatibility guarantee or a requirement that feature windows use this family.

For future sample, OdysseusBuffBars, or OdysseusUtilitySuite evaluation, keep the distinction concrete: the existing sample correctly exposes the full default ButtonFrame branch; a compact configuration surface may still be better served by `SettingsFrameTemplate`, `DefaultPanel*`, or the dialog-border family. Any production choice should be based on desired structure and LIVE validation, not resemblance alone. No production addon change is made or implied by this research.

### 5.5 `BasicFrameTemplate` / `BasicFrameTemplateWithInset` — C

**Definition**

- `Interface/AddOns/Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml:508-663`
- TOC: `Interface/AddOns/Blizzard_UIPanelTemplates/Blizzard_UIPanelTemplates_Mainline.toc`

This is an empty manual-texture frame with title bar and close button. `BasicFrameTemplate` adds rock/title backgrounds; `BasicFrameTemplateWithInset` adds individually anchored inset corners and edges. It has no NineSlice, Backdrop, mixin, default size, parent, strata, or resizing behavior.

Current direct use is sparse: Guild Bank uses `BasicFrameTemplate`, and Taxi uses `BasicFrameTemplateWithInset`. It remains supported and globally available through the enabled UIPanelTemplates addon, but the shared DefaultPanel/ButtonFrame families are better first choices for new general addon UI.

### 5.6 `UIPanelDialogTemplate` — C

**Definition**

- `Interface/AddOns/Blizzard_SharedXML/SharedBasicControls.xml:49-142`

This template manually anchors eight border textures, a title background, an interior background, `Title`, and a `UIPanelCloseButton`. It avoids both BackdropTemplate and NineSlice, but has no default size, mixin, parent, strata, or resize behavior.

Only the current Script Errors frame was found inheriting it. It is useful as a legacy/manual-texture comparison, not as the recommended new architecture.

### 5.7 `PanelResizeButtonTemplate` — A, reusable behavior component

**Definition**

- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1561-1572`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua:1493-1636`

This is a `16 x 16` bottom-right size-grabber with normal, highlight, and pushed files. Call:

`ResizeButton:Init(target, minWidth, minHeight, maxWidth, maxHeight, rotationDegrees)`

The target must be resizable. The mixin calls `StartSizing("BOTTOMRIGHT", true)`, enforces min/max bounds only while its own resize is active, stops sizing on mouse-up, and supports resize callbacks.

The only direct current use found is Blizzard EventTrace, so the visual is old chat-size-grabber art. The implementation is nevertheless a small, general SharedXML component and suitable for an optional resizable sample shell.

### 5.8 Static popups and other rejected shells

**`StaticPopupTemplate` — D**

`Blizzard_StaticPopup_Game/GameDialog.xml` defines a resize-layout popup with `GameDialogMixin`, user-scaled elements, up to five framework buttons, keyboard/mouse behavior, global popup instances, and StaticPopup data. Third-party addons should use the public `StaticPopupDialogs`/`StaticPopup_Show` workflow when they need an actual popup, not directly create the internal template to obtain its visual style.

**`BaseNineSliceDialog` — D**

Despite its generic name, `SharedBasicControls.xml:242-350` hardcodes a `586` width, minimum `442` height, a full-screen underlay, glue-announcement texture kits, UIParent top positioning, parchment contents, and optional CVar write on close. Its only inheriting use is the glue announcement dialog.

**Feature-owned dialog templates — B or D**

Edit Mode, talent loadout, Professions quality, Calendar, and other subsystems define useful-looking composites, but their mixins call subsystem managers or require feature data. Their shared ingredients are already available as `DialogBorder*`, `DialogHeaderTemplate`, `DefaultPanel*`, shared buttons, and close buttons. The first general comparison sample should demonstrate those ingredients rather than load feature addons.

## 6. BackdropTemplate and NineSlice review

### 6.1 VERIFIED SOURCE BEHAVIOR

`BackdropTemplate` remains supported and used. A focused current-use search found direct generic `BackdropTemplate` inheritance in Achievement UI, AuraContainer tooltip support, tutorial/callout frames, Color Picker's opacity slider, Quest Timer, Social Toast, Party frame background, and other specialized surfaces. Tooltip-derived backdrops account for many additional uses in calendars, communities, previews, and tooltips.

Backdrop has therefore not been globally removed or deprecated. Its current implementation is itself built on `NineSliceUtil.ApplyLayout`.

The important implementation detail is in `Blizzard_SharedXML/Backdrop.lua:189-251`:

- `OnSizeChanged` calls `SetupTextureCoordinates()`;
- that method reads `GetWidth()`, `GetHeight()`, and `GetEffectiveScale()`;
- it performs division and repeat calculations for edge and center texture coordinates;
- `SetBackdrop` is explicitly labeled a backward-compatibility API in the source.

By contrast, `NineSlice.lua` applies atlas pieces and establishes anchors between corners, edges, and center. The generic NineSlice setup path does not read the owning frame's width, height, effective scale, or rectangle. The frame solver sizes the anchored pieces.

Manual frame families such as `BasicFrameTemplate` and `UIPanelDialogTemplate` similarly rely on predeclared anchored textures rather than Backdrop's size-dependent UV recalculation.

### 6.2 Current direction

Blizzard uses all three approaches, but the representative reusable modern shells are predominantly:

- NineSlice border plus background textures: DefaultPanel, PortraitFrame, ButtonFrame, DialogBorder, SettingsFrame;
- atlas-backed/manual anchored backgrounds: FlatPanelBackground, Settings background, UIPanelDialog, BasicFrame;
- Backdrop-derived construction mainly for generic colored/tiled surfaces, tooltips, callouts, and retained compatibility.

The source does not establish a universal “Backdrop bad, NineSlice safe” rule. It does establish that Backdrop performs more geometry-dependent Lua arithmetic whenever its size changes.

### 6.3 ENGINEERING CAUTION / INFERENCE

For an ordinary addon-owned, non-secure configuration window whose geometry is ordinary numbers, BackdropTemplate, NineSlice, and manually anchored textures are all practical. No source evidence shows that merely using BackdropTemplate on such a frame creates taint.

For geometry that could become restricted or secret, BackdropTemplate deserves extra caution because its size-change path consumes width, height, and effective scale in Lua arithmetic. Generic NineSlice and pre-anchored textures avoid that specific read-and-calculate path. This is an engineering risk distinction, not proof that NineSlice can never encounter restricted geometry or that Backdrop always fails.

The prior FlightMaster custom-tooltip geometry failure in OdysseusUtilitySuite is runtime evidence for that specific frame path, not evidence that ordinary addon-owned Backdrop frames are generally unsafe. This report does not promote that isolated observation into a permanent compatibility rule.

The simplest low-coupling choice for ordinary Config UI is a shared shell that already composes its own NineSlice/background (`DefaultPanel*`, `SettingsFrameTemplate`, or `DialogBorder*`) rather than custom Backdrop code.

## 7. Modern Settings UI findings

### 7.1 Reusable visual pieces

- **Window shell:** `SettingsFrameTemplate` is independently visual and reusable with `Blizzard_Settings_Shared` available.
- **Action buttons:** Settings constructs ordinary `UIPanelButtonTemplate` controls. There is no separate modern Settings push-button family.
- **Tabs:** `MinimalTabTemplate` is a shared selectable control and can be reused without Settings registration.
- **Slider:** Settings constructs `MinimalSliderWithSteppersTemplate` from SharedXML; already covered in [SliderControls.md](SliderControls.md).
- **Header visuals:** the settings list uses a large font string and `Options_HorizontalDivider`; section headers are `SettingsListSectionHeaderTemplate`.
- **Checkbox/dropdown companions:** the visible controls exist, but Settings row templates are tied to initializer, Setting, tooltip, narration, callback, search, and enabled-state lifecycles.

### 7.2 Coupled pieces

`SettingsCategoryListTemplate`, `SettingsListTemplate`, `SettingsListSectionHeaderTemplate`, `SettingButtonControlTemplate`, checkbox/dropdown rows, and footer/apply behavior are not standalone visual constructors. Their mixins expect Settings categories, element initializers, data providers, predicates, callbacks, search state, or global `SettingsPanel` ownership.

Using Settings registration is appropriate when the goal is a real addon category inside Blizzard Settings. It is unnecessary when the goal is merely a Blizzard-looking independent configuration window.

The key practical result is: use `SettingsFrameTemplate` or its SharedXML ingredients for the shell, use the shared underlying controls directly, and do not import the Settings category/list lifecycle merely for styling.

## 8. Combat and security considerations

No recommended button or frame template inherits `SecureActionButtonTemplate`, registers protected action attributes, or calls a restricted gameplay action. The source therefore supports ordinary non-secure addon use.

Practical limits still apply:

- do not parent the sample to protected Blizzard gameplay frames;
- do not mutate protected Blizzard-owned frame geometry in combat;
- prefer `UIPanelCloseButtonNoScripts` plus an addon-owned hide handler if `HideUIPanel` semantics are not wanted;
- treat feature-owned secure mixins and global popup instances as subsystem interfaces, not reusable visual parts;
- use a static atlas/texture for a portrait sample rather than introducing unit-dependent behavior that is irrelevant to the visual comparison.

The proposed standalone sample can remain entirely addon-owned, non-secure, and independent of combat events.

## 9. LIVE/PTR comparison

The local PTR mirror exists, but it reports the same build as LIVE: `12.1.0.69497`. LIVE is commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`; PTR is commit `e9e8bf68cb7b4177566532f8da9373590759587d`.

A targeted SHA-256 comparison was nevertheless performed for the files defining every retained core or optional sample family: `UIPanelButtonTemplate`, the red and GoldRed three-slice families, `SquareIconButtonTemplate`, `MinimalTabTemplate` and its selectable base, `UIPanelCloseButton`, `UIPanelDialogTemplate`, the dialog border/header family, `SettingsFrameTemplate`, and `ButtonFrameTemplate`/portrait behavior.

| Retained candidate family | Targeted definition/behavior files | LIVE vs PTR |
| --- | --- | --- |
| `UIPanelButtonTemplate` | `SecureUIPanelTemplates.xml/.lua`, `Mainline/SharedUIPanelTemplates.xml/.lua` | identical |
| red and optional GoldRed `SharedButton*` | `Shared/Button/ThreeSliceButtonTemplate.xml/.lua` | identical |
| `SquareIconButtonTemplate` | `Shared/Button/IconButtonTemplate.xml/.lua` | identical |
| `MinimalTabTemplate` | `SelectableButton.xml/.lua`, `Shared/Tabs/MinimalTab.xml/.lua` | identical |
| shared close-button behavior | `Mainline/SharedUIPanelTemplates.xml/.lua` | identical |
| `UIPanelDialogTemplate` | `SharedBasicControls.xml` | identical |
| `DialogBorder*` / `DialogHeaderTemplate` | `Shared/Dialog/DialogTemplates.xml/.lua` | identical |
| `SettingsFrameTemplate` | `Blizzard_Settings_Shared/Mainline/Blizzard_SettingsPanelTemplates.xml` | identical |
| `ButtonFrameTemplate` / portrait behavior | `Mainline/SharedUIPanelTemplates.xml/.lua`, `PortraitFrame.lua` | identical |

The comparison covered 17 implementation files across `Blizzard_SharedXML` and `Blizzard_Settings_Shared`. Result: **17 identical, 0 different**. No retained candidate has a LIVE/PTR source difference in these local same-build mirrors, and no newer PTR-only button or frame control is claimed.

## 10. Proposed standalone comparison sample

Do not create this sample in the current task. The next task should create one small addon under `Samples/ButtonFrameComparison` with a single toggle command and no SavedVariables or production-addon dependency.

### 10.1 Button comparison: four core entries plus one optional emphasis variant

1. **Standard action:** `UIPanelButtonTemplate`
   - establishes the still-current traditional baseline used by Settings;
   - show normal, hover, pushed, and disabled states.
2. **Current red three-slice:** `SharedButtonSmallTemplate`
   - demonstrates the newer atlas-based current action family in a compact size.
3. **Current square icon:** `SquareIconButtonTemplate`
   - use one globally available neutral atlas and expose normal, hover, pushed, and disabled states.
4. **Selected tabs:** a two-button `MinimalTabTemplate` pair managed by `CreateRadioButtonGroup()`
   - demonstrates the persistent selected state and exact modern Settings tab language.

Optional fifth entry: `SharedGoldRedButtonSmallTemplate`. It is source-supported and current, but should remain only if the LIVE screenshot shows a comparison-relevant difference from the ordinary red three-slice family. Do not label it destructive.

Close buttons should be visible on the frame examples rather than consuming a separate button row. Do not add a fake text-plus-icon template or a NineSlice check button to the first sample.

### 10.2 Frame/dialog comparison: four meaningful shells

1. **Legacy/manual dialog:** `UIPanelDialogTemplate`
   - title and close button included;
   - provides a clear older manual-texture baseline.
2. **Compact current dark dialog:** addon-owned Frame containing `DialogBorderDarkTemplate`, `DialogHeaderTemplate`, and `UIPanelCloseButtonDefaultAnchors`
   - demonstrates the current composable dialog family.
3. **Exact modern Settings shell:** `SettingsFrameTemplate`
   - title through `NineSlice.Text`, built-in close button, caller-supplied size;
   - optionally add `PanelResizeButtonTemplate` to demonstrate general resizable behavior without adopting Settings categories.
4. **Traditional complete window:** `ButtonFrameTemplate`
   - static sample portrait, title, close button, inset, and one `MagicButtonTemplate` footer action;
   - demonstrates a full Blizzard feature-window family rather than another bare border.

`DefaultPanelTemplate` and `DefaultPanelFlatTemplate` should remain documented alternatives, but are omitted from the first visual sample because the Settings shell and ButtonFrame already demonstrate their major flat/full-panel architectural differences. StaticPopup, feature-owned Settings rows, BaseNineSliceDialog, and NineSliceCheckButton are intentionally omitted.

### 10.3 Sample constraints for the next task

- one `.toc`, one Lua file, and one README unless XML materially improves clarity;
- explicit dependency on `Blizzard_SharedXML`; add `Blizzard_Settings_Shared` only for the Settings shell;
- no OBB/OUS imports, libraries, SavedVariables, sliders, or scrollbars;
- no copy into the Retail AddOns directory by Codex;
- all frames addon-owned and non-secure;
- labels should name the exact template/family and classification;
- provide a disabled-state toggle and a simple click/readout so visual states can be inspected;
- user manually copies to Retail, tests on LIVE, and supplies the real screenshot afterward.

## 11. Uncertainties requiring runtime validation

- Exact on-screen atlas appearance and pixel scaling at the user's UI scale.
- Whether the GoldRed and ordinary red three-slice variants are visually distinct enough to keep both in the final sample.
- Whether `SettingsFrameTemplate` and the compact dark dialog feel sufficiently different at the same sample size.
- The preferred neutral icon texture or atlas for `SquareIconButtonTemplate`.
- Resizing feel and minimum practical dimensions for the Settings shell.
- Any visual clipping caused by unusually long localized sample labels.

These are visual/runtime questions. The source establishes the construction and dependencies, but should not substitute for the planned LIVE screenshot comparison.

## 12. Primary source index

- `Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML.toc`
- `Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/PortraitFrame.lua`
- `Interface/AddOns/Blizzard_SharedXML/NineSlice.lua`
- `Interface/AddOns/Blizzard_SharedXML/Backdrop.xml`
- `Interface/AddOns/Blizzard_SharedXML/Backdrop.lua`
- `Interface/AddOns/Blizzard_SharedXML/ButtonGroup.lua`
- `Interface/AddOns/Blizzard_SharedXML/SelectableButton.xml`
- `Interface/AddOns/Blizzard_SharedXML/SelectableButton.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/UIButtonTemplate.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/UIButtonTemplate.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/ThreeSliceButtonTemplate.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/IconButtonTemplate.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/UIPanelButtonTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Button/UIPanelButtonTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Tabs/MinimalTab.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Tabs/MinimalTab.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Dialog/DialogTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Dialog/DialogTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/SharedBasicControls.xml`
- `Interface/AddOns/Blizzard_SharedXML/SharedBasicControls.lua`
- `Interface/AddOns/Blizzard_UIPanelTemplates/Blizzard_UIPanelTemplates_Mainline.toc`
- `Interface/AddOns/Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings_Shared.toc`
- `Interface/AddOns/Blizzard_Settings_Shared/Mainline/Blizzard_SettingsPanelTemplates.xml`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.xml`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsList.xml`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.xml`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingControls.lua`
- `Interface/AddOns/Blizzard_Settings/Blizzard_Settings.toc`
- `Interface/AddOns/Blizzard_PhotoSharing/Blizzard_PhotoSharing.xml`
- `Interface/AddOns/Blizzard_StaticPopup_Game/Blizzard_StaticPopup_Game.toc`
- `Interface/AddOns/Blizzard_StaticPopup_Game/GameDialog.xml`
