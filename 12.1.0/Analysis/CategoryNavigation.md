# Retail 12.1 Category Navigation

## 1. Scope and provenance

This research unit compares Blizzard's modern vertical category/navigation implementations in the Retail 12.1 Auction House and Settings UI. It is source research only: it does not change either Blizzard source mirror, any addon, or an existing research sample.

Primary evidence is the local Retail 12.1.0.69497 source mirror at commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`:

`D:\WowDEV\Reference\Blizzard\wow-ui-source\Interface`

The targeted comparison source is the local PTR 12.1.0.69497 mirror at commit `e9e8bf68cb7b4177566532f8da9373590759587d`. It was checked only for architectural differences after both Retail implementations were traced. Source observations are labelled **VERIFIED**. Design implications and addon guidance are labelled **INFERENCE**.

## 2. Reusability classification

- **A — current general-purpose:** current general-purpose Blizzard UI infrastructure with no feature-specific ownership assumption found in this trace.
- **B — current specialized:** a current specialized Blizzard component that may be usable when its declared dependencies and narrow contract are deliberately accepted.
- **C — legacy but supported:** an older component still present and supported by current source, but not the preferred modern architecture.
- **D — internal/not recommended:** feature-owned implementation with strong parent, data-model, event, or load-order coupling.
- **E — unresolved:** evidence is insufficient for a responsible recommendation.

This classification describes current source evidence, not a Blizzard compatibility guarantee.

## 3. Phase status

| Phase | Status |
|---|---|
| Phase 1 — Auction House | **COMPLETE — READ BACK AND SOURCE-VERIFIED** |
| Phase 2 — Settings | **COMPLETE — READ BACK AND SOURCE-VERIFIED** |
| Phase 3 — comparison and addon guidance | **COMPLETE — READ BACK AND SOURCE-VERIFIED** |

## 4. Phase 1 — Auction House

**Checkpoint status: PHASE 1 — COMPLETE.** The written checkpoint was read back in full and its template names, geometry, atlases, ScrollBox setup, data-provider behavior, mixin inheritance, selection callbacks, load ownership, and SharedXML inheritance were rechecked against the Retail source paths below.

### 4.1 Verified source map

The visible rail belongs to the load-on-demand `Blizzard_AuctionHouseUI` feature, not to a general navigation library.

- `Blizzard_AuctionHouseUI_Mainline.toc:4,26-28` declares the addon load-on-demand and loads the category-list Lua/XML as part of the Auction House feature.
- `Shared/Blizzard_AuctionHouseFrame.xml:4,76-81` creates `AuctionHouseFrame` from `PortraitFrameTemplate`. Its `CategoriesList` child inherits `AuctionHouseCategoriesListTemplate` and is anchored under the Auction House search bar on the frame's left side.
- `Mainline/Blizzard_AuctionHouseCategoriesList.xml:4-94` defines the row and list templates.
- `Mainline/Blizzard_AuctionHouseCategoriesList.lua:1-78` applies hierarchy-dependent row styling.
- `Shared/Blizzard_AuctionHouseCategoriesList.lua:4-179` owns flattening, selection, expansion, scrolling, and row interaction.
- `Shared/Blizzard_AuctionData.lua:15-51` creates the Auction House category model exposed through the feature-global `AuctionCategories` table.
- `Shared/Blizzard_AuctionHouseUtil.lua:51-55` defines `AuctionHouseSystemMixin:GetAuctionHouseFrame()`, used by the list to reach its parent Auction House frame.
- `Shared/Blizzard_AuctionHouseFrame.lua:653-680,799-829` consumes category selection in Auction House display and search flows.
- `Shared/Blizzard_AuctionHouseUI_Bootstrap.lua:1-43` loads the feature through the Auction House player-interaction lifecycle.
- `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1082-1087` and `.lua:679-694` define the inherited truncated-text tooltip helper.

### 4.2 Container and geometry — VERIFIED

`AuctionHouseCategoriesListTemplate` is a virtual frame with `AuctionHouseCategoriesListMixin` and a declared size of `168 x 438`.

Its composition is:

- `InsetFrameTemplate`-style layout through `layoutType="InsetFrameTemplate"` and a `NineSlice` child;
- an `auctionhouse-background-categories` background atlas;
- a `WowScrollBoxList` child inset from the container (`3, -6` at top-left and `-25, 2` at bottom-right);
- a `MinimalScrollBar` positioned beside the ScrollBox.

The main Auction House frame owns and positions this container. The category list is therefore not a self-positioning navigation shell.

### 4.3 Row template and hierarchy — VERIFIED

`AuctionCategoryButtonTemplate` is the only category-row template used by this rail. It is a virtual `Button`, declares `parentArray="FilterButtons"`, inherits the global `TruncatedTooltipScriptTemplate`, and has a fixed size of `132 x 21`.

There are no separate header, category, subcategory, and leaf templates in the traced implementation. Every displayed hierarchy level uses the same row initializer and the same template. Top-level categories are selectable controls that also govern expansion; they are not non-interactive section headers.

The row declares:

- a tertiary connector-line texture using `auctionhouse-nav-button-tertiary-filterline`;
- a normal texture using `auctionhouse-nav-button`;
- a manually controlled highlight texture using `auctionhouse-nav-button-highlight`;
- a manually controlled selected texture using `auctionhouse-nav-button-select` with additive blending;
- left-aligned button text with a `1, -1` shadow offset;
- `GameFontNormalSmall` as its declared normal font and `GameFontHighlightSmall` as its declared highlight font.

The feature's setup function then restyles that one template according to `info.type`:

| Hierarchy level | Text inset | Font treatment | Normal/selected/highlight treatment | Connector line |
|---|---:|---|---|---|
| Category | 8 px | `GameFontNormalSmall`; WoW Token category uses `GameFontNormalSmallBattleNetBlueLeft` | primary `auctionhouse-nav-button*` atlases | hidden |
| Subcategory | 18 px | `GameFontHighlightSmall` | secondary `auctionhouse-nav-button-secondary*` atlases | hidden |
| Sub-subcategory | 26 px | `GameFontHighlightSmall` | transparent normal state plus `auctionhouse-ui-row-select` / `auctionhouse-ui-row-highlight` | shown |

The implementation creates no per-row icon region. The special WoW Token category is distinguished by blue font styling rather than an icon.

### 4.4 Interaction and visual states — VERIFIED

Selection is represented by explicitly showing or hiding `SelectedTexture` from `info.selected`. Hover is also manual: `OnEnter` runs the inherited truncated-text tooltip behavior and shows `HighlightTexture`; `OnLeave` hides it. Mouse-down and mouse-up shift the text by one pixel to create a pressed effect.

No feature-specific disabled font, disabled texture, or disabled-row branch was found in the row XML or its setup/interaction functions. This is a statement about the traced Auction House category implementation, not about the capabilities of the base `Button` widget.

`TruncatedTooltipScriptTemplate` is defined in general SharedXML. Its mixin shows a tooltip only when the row's `Text` region reports that it is truncated.

### 4.5 Scroll architecture and data provider — VERIFIED

`AuctionHouseCategoriesListMixin:OnLoad()` creates a linear ScrollBox view with `CreateScrollBoxListLinearView()`. It registers one initializer for `AuctionCategoryButtonTemplate`, applies three pixels of left padding with zero element spacing, and connects the `WowScrollBoxList` to `MinimalScrollBar` through `ScrollUtil.InitScrollBoxListWithScrollBar()`.

The feature rebuilds a flat display list from the hierarchical `AuctionCategories` model:

1. every top-level category is appended;
2. only the selected top-level category contributes its subcategories;
3. only the selected subcategory contributes its sub-subcategories.

The module-level `EXPANDED_FILTERS` table supplies a new `CreateDataProvider(...)` result on refresh. `ScrollBoxConstants.RetainScrollPosition` is used when assigning it, and a forced selection can be scrolled into view. This produces one expanded path rather than independently expanded arbitrary branches.

### 4.6 Selection and feature coupling — VERIFIED

The list mixin is created from `AuctionHouseSystemMixin`. It stores `selectedCategoryIndex`, `selectedSubCategoryIndex`, and `selectedSubSubCategoryIndex`. A click toggles the relevant selection level, clears invalid descendant selection, calls `SetSelectedCategory()`, and rebuilds the flattened rows.

`SetSelectedCategory()` is not merely local visual state. It calls back through the parent Auction House frame, dispatches the Auction House category-selected event, and can alter the feature's display mode. The selected category indices are also used to derive Auction House filter data for queries.

`AuctionHouseSystemMixin:GetAuctionHouseFrame()` returns the mixin owner's parent. Consequently, the list assumes an Auction House parent implementing the expected event and display-mode surface. It also depends on feature globals and functions including `AuctionCategories` and the `AuctionFrameFilter_*` row scripts.

### 4.7 Reusability assessment

| Component or pattern | Class | Source-backed assessment |
|---|---:|---|
| `AuctionHouseCategoriesListTemplate` | D | Feature-local, load-on-demand template with an Auction House-derived mixin, parent-frame callbacks, Auction House globals, and Auction House selection/query semantics. Not recommended as an addon navigation dependency. |
| `AuctionCategoryButtonTemplate` | D | Feature-local row whose scripts and setup are supplied by Auction House code and whose visuals use Auction House-specific atlases. It is not a standalone general row contract. |
| Auction House navigation/background atlases | D | Feature visual assets found in the current implementation; their existence is not evidence of a supported cross-addon skin contract. |
| `WowScrollBoxList`, `MinimalScrollBar`, linear view/data-provider/ScrollUtil primitives | A | General Blizzard infrastructure. An addon can supply its own data, row template, selection model, and styling while using these primitives. |
| `TruncatedTooltipScriptTemplate` | A | General SharedXML helper with a narrow, caller-independent truncated-text behavior. |
| Auction House flatten-one-selected-path algorithm | Not classified | A clear engineering reference pattern rather than an exported component; its concrete implementation is tied to the Auction House data model. |

### 4.8 Phase 1 conclusion

**VERIFIED:** the Auction House rail is a feature-owned hierarchical ScrollBox. It uses one 132-by-21 button template at all depths, changes indentation and atlases according to hierarchy level, expands only the selected path, and routes selection into Auction House-owned state and events. It does not expose separate reusable header/leaf components or an icon-capable row contract.

**INFERENCE:** a Nightwatch-style addon should not replace its complete left navigation with `AuctionHouseCategoriesListTemplate` or `AuctionCategoryButtonTemplate`. The transferable portion is the composition pattern—general ScrollBox infrastructure plus addon-owned row visuals, data, selection, and hierarchy logic. Reproducing the Auction House look also creates avoidable reliance on feature atlases and load-on-demand ownership.

No sample-addon recommendation is made at this checkpoint. That decision requires the Settings trace and the Phase 3 comparison.

## 5. Phase 2 — Settings

**Checkpoint status: PHASE 2 — COMPLETE.** The written checkpoint was read back in full and its template split, geometry, state atlases, expansion flags, factory view, indentation, managed scrollbar, selection behavior, data provider, panel callbacks, registration entry points, and load ownership were rechecked against Retail source.

### 5.1 Verified source map and load ownership

The visual category rail is implemented in `Blizzard_Settings_Shared`, not in the small load-on-demand `Blizzard_Settings` addon.

- `Blizzard_Settings_Shared.toc:1-27` declares SharedXML and HelpPlate dependencies, allows both game and glue loading, and loads the category, list, panel, layout, registration, and inbound files. It has no `LoadOnDemand` declaration.
- `Blizzard_Settings/Blizzard_Settings.toc:1-5` is load-on-demand, but its only Lua file merely sets `SettingsAddonLoaded`; it does not own the visual rail.
- `Blizzard_SettingsPanel.xml:4-75` creates the concrete global `SettingsPanel` from `SettingsFrameTemplate`, then instantiates its left `CategoryList` from `SettingsCategoryListTemplate` and its right content container separately.
- `Blizzard_CategoryList.xml:5-95` defines the spacer, section-header, category-row, and list templates.
- `Blizzard_CategoryList.lua:4-478` owns the row factory, visual states, expansion, indentation, groups, selection, data provider, and scrollbar behavior.
- `Blizzard_Category.lua:1-136` defines the Settings category object, its parent/subcategory hierarchy, and its per-category expanded flag.
- `Blizzard_SettingsPanel.lua:49-110,780-925` connects category-list selection to Settings layouts, tabs, content display, and Settings events.
- `Blizzard_Settings.lua:118-170` exposes category creation, registration, layout registration, and open-to-category entry points.
- `Blizzard_SharedXMLBase/ButtonStateBehavior.lua:2-119` defines the general state behavior mixed into a Settings category row.

The three visual navigation templates are named virtual templates, but they live in the Settings feature namespace. The official list is the one concrete child of the global `SettingsPanel` found in the Retail source tree.

### 5.2 Container and geometry — VERIFIED

The concrete `SettingsPanel` is `920 x 724`. Its `CategoryList` is `199 x 569`, anchored at the left of the panel; the content container begins 16 pixels to its right. `SettingsCategoryListTemplate` itself does not declare an independent size or background shell.

The list template contains:

- a `WowScrollBoxList`;
- a `MinimalScrollBar`;
- no feature-specific NineSlice or background region of its own.

The ScrollBox's XML left anchor is temporarily offset by `-50` so the “new feature” label can extend without clipping. `OnLoad()` compensates with 50 pixels of view left padding. Managed scrollbar visibility changes the ScrollBox's right edge between `-16` and `0`, so the content expands when no scrollbar is shown.

The linear view uses zero top/bottom padding and two pixels of element spacing.

### 5.3 Separate row families — VERIFIED

Unlike Auction House, Settings uses three distinct element templates in one factory-driven list:

| Template | Type and geometry | Role and styling |
|---|---|---|
| `SettingsCategoryListHeaderTemplate` | virtual `Frame`, `175 x 30` | Non-selectable group header. `GameFontHighlightMedium` label at x=20; background cycles through `Options_CategoryHeader_1`, `_2`, and `_3`. |
| `SettingsCategoryListButtonTemplate` | virtual `Button`, `175 x 20` | Selectable category/subcategory row. Label begins at x=36; expandable rows show a 22-by-22 toggle at x=9. |
| `SettingsCategoryListSpacerTemplate` | virtual `Frame`, height 18 | Blank separation inserted between category groups. |

Game categories can receive the non-selectable group headers when their group has `groupText`. The AddOns category set deliberately skips those headers and sorts its categories alphabetically. Both sets can receive the inter-group spacer.

The category row provides no general caller-owned icon slot. Its non-text adornments are the expansion toggle and an optional `NewFeatureLabelTemplate` badge.

### 5.4 Selection, hover, expansion, and disabled state — VERIFIED

`SettingsCategoryListButtonMixin` derives from the general `ButtonStateBehaviorMixin` and renders these list-specific states:

- **selected:** `GameFontHighlight`, visible `Options_List_Active` texture;
- **unselected top-level:** `GameFontNormal`;
- **unselected child:** `GameFontHighlight`;
- **hovered and unselected:** visible `Options_List_Hover` texture;
- **unselected and not hovered:** state texture hidden.

The category row has no separate pushed atlas or pressed displacement. Its child toggle does have open/closed and pressed variants: `common-button-dropdown-open`, `common-button-dropdown-openpressed`, `common-button-dropdown-closed`, and `common-button-dropdown-closedpressed`.

No Settings-specific disabled visual, disabled font, or disabled category branch was found. The inherited general state behavior suppresses hover/mouse state changes when a button is disabled, but this row template does not declare an `OnEnable`/`OnDisable` script or a distinct disabled presentation.

Expansion belongs to each `SettingsCategoryMixin` object through `SetExpanded()` / `IsExpanded()`. The toggle changes only that category's expanded flag and rebuilds the list. The code does not collapse sibling branches, so multiple branches can remain expanded. Programmatic category selection expands every collapsed ancestor so the selected row becomes present.

### 5.5 Hierarchy, data provider, and selection ownership — VERIFIED

`CreateSection()` recursively emits category-button initializers. It starts at indent `0` and adds `10` for every nested level. The view's element-indent calculator applies that value to the row frame in addition to the row's fixed internal label/toggle geometry.

The list uses `ScrollBoxFactoryInitializerMixin` objects rather than one fixed element initializer. Header, spacer, and category factories all feed a flat `elementList`, which is wrapped by `CreateDataProvider(self.elementList)` and assigned with `ScrollBoxConstants.RetainScrollPosition`.

Selection is installed through `ScrollUtil.AddSelectionBehavior(self.ScrollBox)`. A selected row is scrolled to the nearest visible position. Clicking a category selects its factory initializer, triggers the list's `OnCategorySelected` callback, and plays the Settings selection sound. `SettingsPanel` registers for that callback and then clears/replaces its right-side content, updates current-category state, and triggers `Settings.CategoryChanged`.

The category-list module stores the selection behavior in one module-local `g_selectionBehavior`, not as a field on each list instance. A second independent instance would overwrite that shared reference. The row also hard-codes the global `SettingsPanel` when checking whether the category contains a new setting. These are direct source constraints on standalone reuse.

### 5.6 Registration lifecycle versus visual implementation — VERIFIED

The supported Settings registration surface creates `SettingsCategoryMixin` objects, assigns vertical or canvas layouts, and forwards registered categories into the concrete global `SettingsPanel`. Registering an addon category therefore causes Settings to render it through this navigation automatically.

That is **indirect visual use through the complete Settings lifecycle**, not independent reuse of the left-rail templates. Instantiating the visual list or row alone still requires Settings category objects, factory-initializer data, category-set semantics, selection state, and—in the row's new-feature path—the global `SettingsPanel` layout registry.

### 5.7 Reusability assessment

| Component or pattern | Class | Source-backed assessment |
|---|---:|---|
| `SettingsCategoryListTemplate` | D | Feature-owned list with Settings category sets, a module-local singleton selection behavior, Settings factory data, and Settings callbacks. It is not a safe independent navigation container. |
| `SettingsCategoryListButtonTemplate` | D | Feature-owned row requiring a Settings category initializer and shared selection behavior; its new-feature path directly consults global `SettingsPanel`. Not recommended as a standalone addon row. |
| `SettingsCategoryListHeaderTemplate` / spacer | D | Only Retail use found is the Settings list factory. The header depends on Settings initializer data and `Options_CategoryHeader_*` feature atlases; direct reuse has no source-backed ordinary-addon contract. |
| `Settings.CreateCategory`, `RegisterAddOnCategory`, and layout registration | B | Current specialized addon-facing route for participating in the Settings system. It is appropriate when the destination really is Settings, but it adopts Settings ownership and lifecycle. |
| `WowScrollBoxList`, `MinimalScrollBar`, factory initializers, data providers, selection behavior, and managed-scrollbar helpers | A | General infrastructure from which an addon can build an independently owned navigation list. |
| `ButtonStateBehaviorMixin` | A | General state helper. A caller must still supply its own row visuals and state renderer. |
| `Options_List_*`, `Options_CategoryHeader_*`, and Settings “new” visuals | D | Current Settings-owned appearance, not evidence of a general cross-addon navigation skin contract. |
| `SettingsFrameTemplate` | A | The navigation-independent Settings-style outer shell documented in `ButtonsAndFrames.md`; it does not make the category rail independently reusable. |

### 5.8 Phase 2 conclusion

**VERIFIED:** Settings has a richer list architecture than Auction House: separate non-selectable group headers, selectable hierarchical rows, spacers, independently expandable categories, factory initializers, selection behavior, and a managed `MinimalScrollBar`. The actual visual templates and selection model remain coupled to `SettingsPanel` and Settings category objects.

**INFERENCE:** an ordinary addon can legitimately obtain the native Settings navigation appearance by registering its configuration in Settings. It should not extract the category list merely to decorate an unrelated addon window. For an independent Nightwatch-style window, the general ScrollBox and selection primitives are the reusable architecture; the Settings row/header templates are reference implementations, not a safer replacement.

## 6. Phase 3 — comparison and addon guidance

**Checkpoint status: PHASE 3 — COMPLETE.** The comparison and recommendations were read back after both source-verified phase checkpoints. The shared-infrastructure conclusion was rechecked against both implementations, and the ten-file LIVE/PTR hash comparison was reviewed before completion.

### 6.1 Auction House versus Settings

| Question | Auction House | Settings |
|---|---|---|
| Visual role | Commerce-filter rail inside `AuctionHouseFrame`. | Category switcher for the concrete global `SettingsPanel`. |
| Container | `AuctionHouseCategoriesListTemplate`, feature-owned `168 x 438` inset/background composition. | `SettingsCategoryListTemplate`, instantiated as a `199 x 569` panel child with no independent shell. |
| Selectable rows | One `AuctionCategoryButtonTemplate`, `132 x 21`, dynamically restyled for three levels. | One `SettingsCategoryListButtonTemplate`, `175 x 20`, used recursively with element indentation. |
| Section headers | None; a top-level category is still selectable. | Separate non-selectable `SettingsCategoryListHeaderTemplate`, `175 x 30`, for grouped Game categories. |
| Spacing elements | No separate spacer template; zero element spacing. | Separate 18-pixel spacer plus two-pixel view element spacing. |
| Selection visual | Manually shown selected texture; hierarchy-specific Auction House atlases. | Selection behavior calls row state rendering; `Options_List_Active`. |
| Hover visual | Row scripts manually show/hide a hierarchy-specific highlight texture. | `ButtonStateBehaviorMixin` drives `Options_List_Hover` when unselected. |
| Disabled presentation | No feature-specific disabled path found. | No feature-specific disabled presentation found. |
| Hierarchy | Fixed category/subcategory/sub-subcategory model; only the selected path expands. | Recursive category model; per-category expanded flags allow multiple open branches. |
| Headers versus rows | Variants of one selectable row; no header family. | Separate header, selectable button, and spacer factories. |
| Icons/adornments | No icon slot; token category uses a different font color. | No general icon slot; expansion toggle and optional “new” badge only. |
| Scroll infrastructure | `WowScrollBoxList` + linear view + `MinimalScrollBar`. | Same generic ScrollBox/linear-view/MinimalScrollBar family, with factory and managed bar visibility helpers. |
| Data provider | Flat `EXPANDED_FILTERS` made from `AuctionCategories`; one row template initializer. | Flat factory-initializer list made from Settings groups/categories; header/button/spacer element types. |
| Selection ownership | Indices on the list; selection triggers Auction House frame event/display-mode behavior. | module-local selection behavior plus current category; selection drives `SettingsPanel` layout/content lifecycle. |
| Full-component coupling | High: load-on-demand Auction House feature, feature globals, parent callbacks, query semantics, feature atlases. | High: Settings categories and category sets, singleton selection reference, global `SettingsPanel`, layout/registration lifecycle, feature atlases. |
| Ordinary-addon direct reuse | D — not recommended. | D — not recommended outside the supported Settings registration route. |
| Maintenance risk | High if an addon loads or instantiates the feature templates; lower when only the general ScrollBox pattern is reproduced. | High if visual templates are extracted; normal/appropriate when an addon deliberately registers a real Settings category. |
| Standalone native-template sample | Misleading: it would need Auction House feature code/data or artificial shims. | Misleading as an unrelated-window component; registration would demonstrate Settings integration, not standalone navigation. |

### 6.2 Shared architecture — VERIFIED

The two implementations share general list infrastructure, not a common category-navigation component. Both use `WowScrollBoxList`, `CreateScrollBoxListLinearView`, `MinimalScrollBar`, `CreateDataProvider`, `ScrollUtil`, and a flat visible-element representation. They do not inherit a common navigation container, row template, category-header template, selection mixin, data model, or feature event contract.

Their conceptual resemblance—left rail, highlighted selection, hierarchical labels—is therefore visual/interaction similarity built from common ScrollBox primitives. It is not evidence that either feature template is a general Blizzard navigation family.

### 6.3 Nightwatch relevance

No Nightwatch implementation file was inspected and no Nightwatch file was changed.

**INFERENCE:** the current source evidence supports **keep the custom implementation** as the default outcome. Neither Blizzard feature offers a complete source-supported component that is technically preferable merely because it looks native. A future Nightwatch-specific review should preserve behavior and ask only:

1. Does the existing list need virtualization or managed scrollbar visibility badly enough to justify adopting `WowScrollBoxList` and `MinimalScrollBar`?
2. Can generic `ScrollUtil.AddSelectionBehavior` simplify selection without forcing Settings or Auction House ownership into the addon?
3. Are its category headers semantically non-selectable, making the Settings split of header/button/spacer a useful addon-owned reference pattern?
4. Does it need independent multi-branch expansion, a single selected expansion path, or no hierarchy at all?
5. Can its established row art and strong selected highlight remain addon-owned while only the generic scrolling/data-provider layer changes?

This leaves all requested future outcomes open in principle, but the present evidence rules out adopting either complete Blizzard feature family as the presumptive solution.

### 6.4 Future sample recommendation

**INFERENCE:** do not create a comparison sample that instantiates `AuctionHouseCategoriesListTemplate`, `AuctionCategoryButtonTemplate`, `SettingsCategoryListTemplate`, or `SettingsCategoryListButtonTemplate` as if they were ordinary reusable addon widgets. Such a sample would conceal the exact feature coupling this research found.

A future proof-of-concept is worthwhile only if Nightwatch later has a concrete scrolling, large-data, or selection-maintenance problem. Its useful scope would be:

- an addon-owned generic/custom row baseline;
- `WowScrollBoxList` with `MinimalScrollBar` and addon-owned data;
- optional general `ButtonStateBehaviorMixin` / selection behavior;
- addon-owned header, selectable-row, and highlight visuals.

That would test a reusable architecture, not compare misleading feature-local skins. No sample is warranted solely to reproduce the current Auction House or Settings appearance.

### 6.5 Strongest reusability conclusion

**VERIFIED:** the reusable Blizzard-native layer is the general ScrollBox/data-provider/scrollbar/state infrastructure (class A), plus the supported Settings registration surface when the UI genuinely belongs inside Settings (class B). The complete Auction House and Settings navigation templates are class D for independent ordinary-addon navigation.

**INFERENCE:** for an already successful independent addon rail, keep addon-owned navigation and consider generic primitives only when they solve an identified engineering problem. Native-looking feature templates are not automatically safer dependencies.

## 7. Targeted LIVE/PTR comparison

**COMPLETE.** LIVE and PTR are both the supplied Retail 12.1.0.69497 snapshots. SHA-256 comparison found all ten retained implementation files byte-identical:

- `Blizzard_AuctionHouseUI/Mainline/Blizzard_AuctionHouseCategoriesList.lua`
- `Blizzard_AuctionHouseUI/Mainline/Blizzard_AuctionHouseCategoriesList.xml`
- `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseCategoriesList.lua`
- `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.xml`
- `Blizzard_Settings_Shared/Blizzard_Category.lua`
- `Blizzard_Settings_Shared/Blizzard_CategoryList.lua`
- `Blizzard_Settings_Shared/Blizzard_CategoryList.xml`
- `Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`
- `Blizzard_Settings_Shared/Blizzard_SettingsPanel.xml`
- `Blizzard_Settings_Shared/Blizzard_Settings.lua`

No navigation-relevant LIVE/PTR difference exists in this targeted set. This does not claim that the complete source trees are identical.

## 8. Source index

Retail paths are relative to `Interface` in the local Retail source mirror.

- `AddOns/Blizzard_AuctionHouseUI/Blizzard_AuctionHouseUI_Mainline.toc`
- `AddOns/Blizzard_AuctionHouseUI/Mainline/Blizzard_AuctionHouseCategoriesList.lua`
- `AddOns/Blizzard_AuctionHouseUI/Mainline/Blizzard_AuctionHouseCategoriesList.xml`
- `AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionData.lua`
- `AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseCategoriesList.lua`
- `AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.lua`
- `AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseFrame.xml`
- `AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseUI_Bootstrap.lua`
- `AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseUtil.lua`
- `AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua`
- `AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`
- `AddOns/Blizzard_Settings/Blizzard_Settings.lua`
- `AddOns/Blizzard_Settings/Blizzard_Settings.toc`
- `AddOns/Blizzard_Settings_Shared/Blizzard_Category.lua`
- `AddOns/Blizzard_Settings_Shared/Blizzard_CategoryList.lua`
- `AddOns/Blizzard_Settings_Shared/Blizzard_CategoryList.xml`
- `AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua`
- `AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua`
- `AddOns/Blizzard_Settings_Shared/Blizzard_SettingsPanel.xml`
- `AddOns/Blizzard_Settings_Shared/Blizzard_Settings_Shared.toc`
- `AddOns/Blizzard_Settings_Shared/Mainline/Blizzard_SettingsPanelTemplates.xml`
- `AddOns/Blizzard_SharedXMLBase/ButtonStateBehavior.lua`
