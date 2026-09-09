# Retail Tabs — WoW 12.1.0

## 1. Scope, source provenance, and evidence labels

This document records the completed source-only investigation of current Retail tab infrastructure. It covers reusable tab systems, representative Mainline consumers, initialization and selection, page ownership, visuals, sizing, overflow, input, security, and likely addon applicability. It does not implement or report a runtime comparison.

The authoritative source baseline is the local Retail LIVE mirror:

- repository: `D:\WowDEV\Reference\Blizzard\wow-ui-source`
- branch: `live`
- commit: `8ea15b61e45c0ed4eba01439c90757f86eb78d34`
- commit description/build: `12.1.0 (69587)`

The source checkout contained the pre-existing untracked `.codex/` directory and was not modified. PTR source was not used.

Evidence is labeled as follows:

- **VERIFIED SOURCE FACT:** directly established by the cited LIVE Lua/XML or TOC.
- **SOURCE-SUPPORTED INFERENCE:** an engineering conclusion supported by the inspected source, not a stated Blizzard guarantee.
- **UNKNOWN / RUNTIME REQUIRED:** a bounded question that static source does not settle. No such question in this investigation requires a standalone experiment.

There are no **VERIFIED RUNTIME RESULT** findings for Tabs. No Tabs runtime test or screenshot was produced.

## 2. Executive conclusion

**VERIFIED SOURCE FACT:** Retail does not use one exclusive tab API. Several legitimate systems coexist:

- the shared `TabSystemTemplate` / `TabSystemOwnerTemplate` framework;
- the older procedural but actively used Mainline `PanelTemplates` family;
- the specialized Settings-style `MinimalTabTemplate` plus `RadioButtonGroup` pattern;
- feature-specific managers and side-tab implementations.

**SOURCE-SUPPORTED INFERENCE:** for a new ordinary multi-page interface, `TabSystemTemplate` plus `TabSystemOwnerTemplate` is the strongest current structured source pattern. `PanelTemplates` remains valid for numbered/XML tab sets whose application explicitly owns page switching. `MinimalTabTemplate` is a specialized choice selector rather than the general navigation framework.

`TabSystem` has not universally superseded `PanelTemplates`, and current source does not justify migrating an existing working interface merely because `TabSystemOwner` is more structured.

## 3. System inventory and classification

| Mechanism | Classification | Source conclusion |
| --- | --- | --- |
| `TabSystemTemplate`, `TabSystemMixin`, and tab-button templates | **SHARED AND USED BY MAINLINE** | Shared pooled tab strip used by current Retail features. |
| `TabSystemOwnerTemplate`, `TabSystemOwnerMixin`, `TabSystemTrackerMixin` | **SHARED AND USED BY MAINLINE** | Adds logical selection, callbacks, and automatic visibility for registered elements. |
| Mainline `PanelTemplates_*`, `PanelTabButtonTemplate`, `PanelTopTabButtonTemplate` | **CURRENT MAINLINE** | Older procedural family with many active Retail consumers; not deprecated by current evidence. |
| `MinimalTabTemplate`, `MinimalTabMixin`, and `RadioButtonGroup` | **CURRENT SPECIALIZED** | Settings-style selected tabs; the group owns exclusivity while application callbacks own behavior. |
| Feature-specific managers and side tabs | **CURRENT SPECIALIZED** | Valid current implementations coupled to their feature rather than a general framework. |
| `ScrollableTabsContainerTemplate` / `ScrollableTabsContainerMixin` | **PRESENT BUT CURRENT RETAIL USAGE NOT VERIFIED** | Mainline-only SharedXML component; no consumer outside its definition was found. |
| Classic Auction House and TBC Guild Bank tab templates | **CLASSIC-ONLY** | Family-specific code and not evidence for current Retail. |
| `TabGroupMixin` | Not a visual page-tab system | Tab/Shift-Tab focus traversal among focusable frames and subgroups. |

No important general Retail tab mechanism found here qualified as purely **LEGACY / COMPATIBILITY**.

## 4. Definitions and availability

### 4.1 TabSystem and owner

**VERIFIED SOURCE FACT:** `Blizzard_SharedXML.toc:123-128` loads `ScrollableTabsContainer` for Mainline and loads the `TabSystem` templates and owner for game types other than Vanilla/TBC.

Primary definitions:

- `Interface/AddOns/Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/TabSystem/TabSystemOwner.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/TabSystem/TabSystemOwner.xml`

The XML defines:

- `TabSystemButtonArtTemplate`
- `TabSystemButtonTemplate`
- `TabSystemTopButtonTemplate`
- `TabSystemTemplate`, inheriting `HorizontalLayoutFrame`
- `TabSystemOwnerTemplate`

### 4.2 PanelTemplates

**VERIFIED SOURCE FACT:** Mainline resolves the family-specific SharedXML files loaded by `Blizzard_SharedXML.toc:184,186`:

- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`

Relevant definitions include `PanelTabButtonMixin`, `PanelTopTabButtonMixin`, `PanelTabButtonTemplate`, `PanelTopTabButtonTemplate`, and the `PanelTemplates_*` helper functions.

### 4.3 Specialized and supporting systems

- `Interface/AddOns/Blizzard_SharedXML/Shared/Tabs/MinimalTab.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Tabs/MinimalTab.xml`
- `Interface/AddOns/Blizzard_SharedXML/ScrollableTabsContainer.lua`
- `Interface/AddOns/Blizzard_SharedXML/ScrollableTabsContainer.xml`
- `Interface/AddOns/Blizzard_SharedXML/TabGroup.lua`

**VERIFIED SOURCE FACT:** no corresponding generated native tab `C_*` API documentation was found. These systems are Lua mixins, XML virtual templates, and ordinary frame helpers rather than a generated native tab API contract.

## 5. Representative current Mainline consumers

### 5.1 Professions — owner-controlled TabSystem

**VERIFIED SOURCE FACT:** `Blizzard_Professions/Blizzard_ProfessionsFrame.xml:5-21` declares a custom `TabSystemButtonTemplate`, a frame inheriting `TabSystemOwnerTemplate`, and a child `TabSystemTemplate`.

`Blizzard_Professions/Blizzard_ProfessionsFrame.lua:35-43` initializes the owner, calls `SetTabSystem`, and dynamically adds Recipes, Specializations, and Orders with their corresponding page frames. Its feature-specific `SetTab` path eventually calls `TabSystemOwnerMixin.SetTab` and emits `ProfessionsFrame.TabSet` (`:349-461`). That event is application behavior, not a generic TabSystem event.

### 5.2 PlayerSpells — owner-controlled pages

**VERIFIED SOURCE FACT:** `Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.xml:5-20` declares the owner/system composition. `Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.lua:13-16` adds Specialization, Talents, and Spellbook pages. Later feature logic explicitly chooses the appropriate tab; the framework does not select the first one automatically.

### 5.3 Bank — logical states can share one panel

**VERIFIED SOURCE FACT:** `Blizzard_UIPanels_Game/Mainline/BankFrame.xml:673-694` declares `TabSystemOwnerTemplate` and `TabSystemTemplate`. `BankFrame.lua:22-40` adds Character Bank and Account Bank while registering the same `BankPanel` for both. Its override changes the panel's bank type before calling `TabSystemOwnerMixin.SetTab`.

`BankFrame.lua:59-65` explicitly selects the first visible available tab. This proves that logical tab states do not require distinct page-frame objects and that initial selection remains application-owned.

### 5.4 Collections — PanelTemplates plus explicit pages

**VERIFIED SOURCE FACT:** `Blizzard_Collections/Mainline/Blizzard_Collections.xml:5` derives its tab button from `PanelTabButtonTemplate`. `Blizzard_Collections.lua:3-52` calls `PanelTemplates_SetTab`, explicitly shows exactly the selected journal page, updates the title, and emits `CollectionsJournal.TabSet`.

### 5.5 CharacterFrame — PanelTemplates plus ShowSubFrame

**VERIFIED SOURCE FACT:** `Blizzard_UIPanels_Game/Mainline/CharacterFrame.lua:98-105` explicitly configures the tab count and initial tab. `ToggleCharacter` separately calls `PanelTemplates_SetTab` and `ShowSubFrame` (`:24-44`). Visual selection and content visibility are separate responsibilities.

### 5.6 Settings — MinimalTab plus radio group

**VERIFIED SOURCE FACT:** `Blizzard_Settings_Shared/Blizzard_SettingsPanel.xml:26-44` declares Game and AddOns `MinimalTabTemplate` buttons. `Blizzard_SettingsPanel.lua:49-60,107-110` creates a radio-button group, adds both tabs, explicitly selects index 1, and changes the category set from the group callback.

Advanced Graphics uses narrated Base/Raid minimal tabs. `Blizzard_SettingsDefinitions_Shared/Graphics.lua:406-415` provides `SettingsTabNarrationMixin`, while `:419-463` creates the radio group and explicitly shows the selected controls.

Other current TabSystem consumers include Transmog, the Mainline Friends header, Spellbook categories, House Editor, Housing Cornerstone, Housing Dashboard, and Housing Bulletin Board. Current Mainline `PanelTemplates_SetTab` consumers additionally include Encounter Journal, Auction House, Friends, Merchant, Guild Bank, Inspect, Mail, Raid, PVP, and Group Finder.

## 6. Creation and initialization lifecycle

### 6.1 TabSystem

**VERIFIED SOURCE FACT:** `TabSystemMixin:OnLoad` creates an empty tab array and a button frame pool (`TabSystemTemplates.lua:207-210`). `AddTab(tabText)`:

1. assigns the sequential one-based ID `#tabs + 1`;
2. acquires a pooled button;
3. assigns the ID to `layoutIndex`;
4. initializes the button with the ID and text;
5. shows it and marks the layout dirty (`:212-220`).

`TabSystemOwnerMixin:OnLoad` creates its internal tracker. `SetTabSystem` stores the system and wires its selected callback to the owner's `SetTab`. `AddNamedTab(name, ...)` adds the visual tab and associates any supplied elements with that ID (`TabSystemOwner.lua:74-87`).

The first tab is not selected automatically. Current features explicitly call `SetTab` when their application state is ready.

A raw `TabSystemTemplate` can be used without an owner, but it must receive `SetTabSelectedCallback` before `SetTab`: `TabSystemMixin:SetTab` invokes `self.tabSelectedCallback` without a nil guard (`TabSystemTemplates.lua:223-231`).

The frame-pool path remains available after initial setup; no finalized or sealed state prevents later additions.

### 6.2 PanelTemplates

**VERIFIED SOURCE FACT:** buttons are commonly XML-declared with IDs and a `Tabs` parent array or conventional parent/name lookup. The owning frame calls `PanelTemplates_SetNumTabs`, supplies or updates label text, and explicitly calls `PanelTemplates_SetTab` for the initial selection.

### 6.3 MinimalTab

**VERIFIED SOURCE FACT:** XML supplies `tabText`. `MinimalTabMixin:OnLoad` sets the label and initial width. The owner registers the buttons with a `RadioButtonGroup`, explicitly selects an index, and registers the application callback.

## 7. Selection and page ownership

### 7.1 TabSystem visual state

**VERIFIED SOURCE FACT:** clicking a `TabSystemButtonMixin` calls `tabSystem:SetTab(tabID, true)`. `TabSystemMixin:SetTab` calls `(tabID, isUserAction)` on its selected callback; a truthy return suppresses automatic visual selection. Otherwise `SetTabVisuallySelected` stores `selectedTabID` and updates every button (`TabSystemTemplates.lua:104-114,223-239`).

### 7.2 TabSystemOwner logical state and pages

**VERIFIED SOURCE FACT:** the owner's tracker stores its logical tab ID, hides or shows all registered elements according to the selected tab's element set, invokes a per-tab callback, and supports a deselection callback (`TabSystemOwner.lua:30-57`). The owner then applies visual selection (`:98-101`).

Thus:

- `TabSystemOwner` can automatically manage registered page visibility.
- bare `TabSystem` manages selection visuals and callback dispatch but does not own pages.
- owner-managed logical states may share the same page frame, as Bank demonstrates.

### 7.3 PanelTemplates and MinimalTab

**VERIFIED SOURCE FACT:** `PanelTemplates_SetTab` stores `frame.selectedTab` and calls `PanelTemplates_UpdateTabs`; it does not show or hide application pages (`SharedUIPanelTemplates.lua:354-385`).

`MinimalTabTemplate` supplies selected visuals through `SelectableButtonTemplate`. `RadioButtonGroup` owns exclusive selection and emits its selected callback; the application performs the resulting category or page work.

## 8. Visual, enabled, and label states

**VERIFIED SOURCE FACT:** ordinary `TabSystem` and `PanelTemplates` tabs use left, middle, and right atlas textures. They do not use NineSlice for the tab art.

For both families:

- selected state shows active textures, changes font/text position, and disables the selected button;
- unselected state restores normal textures and enables the button;
- hover uses additive highlight textures;
- top-tab variants change the art orientation and offsets.

`TabSystem` additionally supports force-disabled state, disabled-colored labels, optional error explanations, notification markers, and tooltips for explicit help text or truncated labels (`TabSystemTemplates.lua:76-176`).

`PanelTemplates` records disabled state in `tab.isDisabled`, applies its disabled font/art state, and shows a tooltip when the label is truncated (`SharedUIPanelTemplates.lua:243-273,473-577`).

Neither general family assigns distinct first/middle/last semantic button types.

## 9. Sizing and layout

### 9.1 TabSystem

**VERIFIED SOURCE FACT:** `TabSystemButtonMixin:UpdateTabWidth` combines side-texture widths, fixed side spacing, label width, optional text padding, and optional minimum/maximum constraints. It sets both the label and button width (`TabSystemTemplates.lua:154-176`).

`TabSystemTemplate` inherits `HorizontalLayoutFrame`; added buttons receive sequential `layoutIndex` values. The layout orders children horizontally and applies the configured spacing, which defaults to one pixel (`TabSystemTemplates.xml:110-130`; `LayoutFrame.lua:370-444`).

### 9.2 PanelTemplates

**VERIFIED SOURCE FACT:** `PanelTemplates_TabResize` calculates label width plus side/padding widths and supports absolute, minimum, and maximum sizing (`SharedUIPanelTemplates.lua:388-427`). `PanelTemplates_SetNumTabs` records the count and anchors every later tab from the preceding tab's `TOPRIGHT` with a three-pixel gap (`:460-470`).

`PanelTemplates_ResizeTabsToFit` restores the selected tab's natural width, then divides the remaining width equally among other tabs when the strip is too wide or already truncated (`:429-458`).

### 9.3 MinimalTab and geometry qualification

**VERIFIED SOURCE FACT:** `MinimalTabMixin:OnLoad` sizes the button to the label's string width plus 40 pixels. Owners anchor adjacent tabs explicitly.

All three implementations read ordinary frame, texture, or font-string dimensions into Lua. This establishes their sizing logic for their ordinary controls; it does not generalize those geometry operations to arbitrary restricted frame hierarchies.

## 10. Overflow and large tab sets

**VERIFIED SOURCE FACT:** ordinary `TabSystem` supports maximum tab width and label truncation with a tooltip, but no generic wrapping, overflow menu, or scrolling integration was found.

`PanelTemplates` supports resize-to-fit, truncation, and truncation tooltips. Individual features may hide or reanchor tabs, but that is application behavior rather than a generic overflow controller.

`ScrollableTabsContainerMixin` implements:

- an arbitrary pooled tab template and initializer;
- horizontal anchoring and clipping through a `clipChildren` contents frame;
- mouse-wheel scrolling;
- `ScrollIntoView`;
- optional external left/right control widths and visibility callbacks.

**VERIFIED SOURCE FACT:** the component is Mainline-only, but no consumer outside its definition was found in the researched snapshot.

**SOURCE-SUPPORTED INFERENCE:** it must not be presented as a proven current companion to `TabSystem` or as the default Retail overflow solution. No generic wrapping or overflow-menu implementation was established.

## 11. Input and accessibility

**VERIFIED SOURCE FACT:** the generic `TabSystem`, `PanelTemplates`, and `MinimalTab` definitions provide ordinary mouse click/hover behavior. Their generic definitions contain no arrow-key selection, next/previous-tab command, gamepad/controller selection, focus-navigation, or hotkey guarantee.

`ScrollableTabsContainer` explicitly handles mouse-wheel scrolling. Advanced Graphics adds `SettingsTabNarrationMixin`, which narrates the label and its index/count context.

`TabGroupMixin` is separate: it handles Tab/Shift-Tab focus traversal among focusable frames and nested groups. It does not select or render visual tabs (`Blizzard_SharedXML/TabGroup.lua:1-77`).

**UNKNOWN / RUNTIME REQUIRED:** feature-specific input behavior may exist beyond these generic definitions. It cannot be inferred as a general framework guarantee.

## 12. Combat, security, and taint

**VERIFIED SOURCE FACT:** the inspected generic tab definitions contain no:

- secure or protected template inheritance;
- combat-lockdown checks;
- secret-value handling;
- forbidden-aspect logic;
- `UntrustedScriptExecution`;
- `UntrustedLayoutScriptExecution`;
- secure-action behavior.

They construct ordinary `Frame` and `Button` objects and use ordinary texture, font, callback, and layout operations.

**SOURCE-SUPPORTED INFERENCE:** ordinary addon-owned tabs do not introduce a tab-specific forbidden-layout or taint concern. A tab placed inside, or anchored into, a separately protected or restricted hierarchy remains subject to that composition's rules. This is not a universal combat-safety guarantee.

No Tabs combat test was performed.

## 13. Addon applicability

**SOURCE-SUPPORTED INFERENCE:** the three active candidates are reproducible by addon code without a Blizzard feature-specific owner:

- **TabSystem:** use the shared owner/system templates, call `SetTabSystem`, add tabs or named page elements, and explicitly call the initial `SetTab`. A bare system instead needs its own selected callback and page logic.
- **PanelTemplates:** create `PanelTabButtonTemplate` buttons with IDs and use the global `PanelTemplates_*` helpers; the addon remains responsible for content visibility.
- **MinimalTab:** use the shared template with a `RadioButtonGroup` and application selection/content callbacks.

The inspected dependencies are shared templates, global Lua mixins/helpers, frame pools, closures, and ordinary frame methods. No private generated method or mandatory Blizzard feature-owner type was found.

These are source-visible Blizzard Lua/XML UI facilities, not a documented stable native `C_*` API contract. Normal build-to-build compatibility validation remains appropriate.

## 14. Tab-specific legacy and compatibility boundary

**VERIFIED SOURCE FACT:** `PanelTemplates` is older procedural infrastructure, but current Mainline call sites prove it remains active. It is not classified as deprecated by this evidence.

Classic Auction House and TBC Guild Bank templates are family-specific and cannot establish Retail use. No history archaeology was needed because current Mainline definitions and consumers answer the tab-specific classification question directly.

This conclusion does not perform or pre-empt the separate Deprecated & Compatibility APIs audit.

## 15. Engineering implications and bounded unknowns

### 15.1 Future OUS/OBB implications

**SOURCE-SUPPORTED INFERENCE:** a future new OUS2 or OBB multi-page UI could consider `TabSystemOwner` when automatic page visibility, dynamic tabs, shared sizing, and owner callbacks fit the design. Bare `TabSystem` still requires application logic.

Existing `PanelTemplates` or ordinary selector-button interfaces should not be replaced without a separate design decision. `MinimalTab` is best treated as a specialized Settings-style choice selector. TooltipComparison's Phase selectors are ordinary buttons and were not used as Tabs evidence.

### 15.2 Bounded unknowns

**UNKNOWN / RUNTIME REQUIRED:** static source does not establish:

- exact rendered widths and truncation for every locale and UI scale;
- behavior of unusually large addon tab sets in constrained layouts;
- whether `ScrollableTabsContainer` is unused, future-facing, or consumed through a path absent from this snapshot;
- feature-specific input/controller behavior outside the generic definitions.

These unknowns do not block the architectural classification or justify a standalone runtime module.

## 16. Runtime decision and research closure

**SOURCE-SUPPORTED INFERENCE:** no `TabsComparison` runtime experiment is justified. Static LIVE source establishes the material questions:

- instantiation dependencies;
- initialization lifecycle;
- explicit initial-selection requirement;
- callback flow;
- visual and disabled state;
- content ownership and automatic versus explicit page switching;
- sizing and layout;
- likely addon applicability;
- absence of intrinsic generic restricted-layout machinery.

A standalone module that merely demonstrates clicking tabs or switching pages would duplicate established source behavior. A future production implementation should receive normal runtime validation in its actual composition; that does not require a separate research experiment now.

Tabs source research is **COMPLETE**:

- no runtime phase is required;
- no `TabsComparison` module was created;
- no Tabs runtime screenshots are required or present;
- the remaining unknowns are bounded;
- the next native UI roadmap topic is **Deprecated & Compatibility APIs**.

## 17. Primary LIVE source index

### Shared definitions

- `Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML.toc`
- `Interface/AddOns/Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/TabSystem/TabSystemTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/TabSystem/TabSystemOwner.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/TabSystem/TabSystemOwner.xml`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Tabs/MinimalTab.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Tabs/MinimalTab.xml`
- `Interface/AddOns/Blizzard_SharedXML/ScrollableTabsContainer.lua`
- `Interface/AddOns/Blizzard_SharedXML/ScrollableTabsContainer.xml`
- `Interface/AddOns/Blizzard_SharedXML/TabGroup.lua`
- `Interface/AddOns/Blizzard_SharedXML/LayoutFrame.lua`

### Representative Mainline consumers

- `Interface/AddOns/Blizzard_Professions/Blizzard_ProfessionsFrame.lua`
- `Interface/AddOns/Blizzard_Professions/Blizzard_ProfessionsFrame.xml`
- `Interface/AddOns/Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.lua`
- `Interface/AddOns/Blizzard_PlayerSpells/Blizzard_PlayerSpellsFrame.xml`
- `Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.lua`
- `Interface/AddOns/Blizzard_UIPanels_Game/Mainline/BankFrame.xml`
- `Interface/AddOns/Blizzard_Collections/Mainline/Blizzard_Collections.lua`
- `Interface/AddOns/Blizzard_Collections/Mainline/Blizzard_Collections.xml`
- `Interface/AddOns/Blizzard_UIPanels_Game/Mainline/CharacterFrame.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.xml`
- `Interface/AddOns/Blizzard_SettingsDefinitions_Shared/Graphics.lua`
- `Interface/AddOns/Blizzard_SettingsDefinitions_Shared/Graphics.xml`
- `Interface/AddOns/Blizzard_ChatFrame/Mainline/ChatConfigFrame.lua`
- `Interface/AddOns/Blizzard_ChatFrame/Mainline/ChatConfigFrame.xml`
