# Retail 12.1 ScrollBox Architecture

## 1. Scope, authority, and evidence labels

This document began as a source-only investigation of the modern scrollable-collection architecture shipped in World of Warcraft Retail. Section 26 now records the separately labeled results of the completed `ScrollBoxComparison` Retail LIVE runtime pass. It does not change or prescribe changes to a production addon.

Authoritative baseline:

- Retail LIVE source mirror: `D:\WowDEV\Reference\Blizzard\wow-ui-source`
- LIVE commit: `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
- installed client/source version: `12.1.0.69497`
- BlizzardResearch baseline: `570ffe63d0c6b2d0c1b64a7ac4af8078ae1023f5`

PTR source content was not consulted. The local PTR repository was checked only as Git metadata before research and was not opened or searched. Its current local commit did not match the stale expected metadata in the task, which supplied an additional reason not to treat it as evidence.

The requested existing path `12.1.0/Analysis/Sliders.md` does not exist at this baseline. The published slider document actually present and reviewed is `12.1.0/Analysis/SliderControls.md`. The other requested published analysis documents and `Samples/RetailUIResearch/` architecture were also reviewed and left unchanged.

Evidence labels used below:

- **SOURCE-VERIFIED FACT:** directly established by the cited LIVE Lua, XML, TOC, or generated API source.
- **LIVE-OBSERVED BEHAVIOR:** directly reported by the user from the isolated `ScrollBoxComparison` sample on the stated Retail LIVE client.
- **ASSUMPTION / INFERENCE:** a bounded interpretation of verified structure; not a Blizzard API guarantee.
- **RUNTIME QUESTION:** behavior that source inspection alone does not establish confidently.
- **ENGINEERING RECOMMENDATION:** proposed addon practice derived from the verified architecture; not a Blizzard mandate.

## 2. Executive answer: how Blizzard composes scrolling collections

**SOURCE-VERIFIED FACT:** the ordinary modern collection composition is not one all-inclusive ScrollBox widget. It is a cooperating set of independently configured pieces:

1. Create or inherit a clipped viewport, normally `WowScrollBoxList` for provider-backed collections.
2. Create a view, normally `CreateScrollBoxListLinearView(...)` or `CreateScrollBoxListGridView(...)`.
3. Configure the view's element initializer or factory and, when template dimensions are insufficient, its fixed extent or extent/size calculator.
4. Create an ordered data provider with `CreateDataProvider(...)` or, for a virtual integer range, `CreateIndexRangeDataProvider(...)`.
5. Create a visually complete modern scrollbar separately, most commonly `MinimalScrollBar`.
6. Bind the viewport, scrollbar, and view with `ScrollUtil.InitScrollBoxListWithScrollBar(...)`.
7. Assign data with `scrollBox:SetDataProvider(dataProvider[, retainScrollPosition])`.
8. Add selection, managed scrollbar visibility, resizable-child observation, or drag behavior only when the feature needs those separate behaviors.

`ScrollBoxBaseTemplate` supplies clipping and a moving `ScrollTarget`. The view owns layout, visible-range calculation, element acquisition, and extent calculations. `DataProviderMixin` owns ordered element data and emits mutation events. `ScrollBoxListViewMixin` owns a frame factory/pool and invokes element initialization after acquired frames have been sized and laid out. `ScrollUtil` connects controllers and supplies optional behaviors. A scrollbar does not create elements, and a data provider does not own visual selection.

**ENGINEERING RECOMMENDATION:** for an addon-owned homogeneous vertical picker, the minimum safe starting point is `WowScrollBoxList` + `CreateScrollBoxListLinearView` + one element initializer + `CreateDataProvider` + `MinimalScrollBar` + `ScrollUtil.InitScrollBoxListWithScrollBar`. Adopt factory, variable extent, selection, grid, or managed-visibility helpers only for a demonstrated requirement.

## 3. Core source map

All paths in this document are relative to `Interface/AddOns/` in the LIVE mirror.

| Concept | Authoritative file | Important definitions |
| --- | --- | --- |
| Load order | `Blizzard_SharedXML/Blizzard_SharedXML.toc:85-116` | data providers, ScrollUtil/controller/view files, ScrollBox, ScrollBar, and visual bar templates |
| Ordered provider | `Blizzard_SharedXML/DataProvider.lua:2-301` | `DataProviderMixin`, `CreateDataProvider` |
| Virtual integer provider | `Blizzard_SharedXML/IndexRangeDataProvider.lua:1-76` | `IndexRangeDataProviderMixin`, `CreateIndexRangeDataProvider` |
| Base viewport | `Blizzard_SharedXML/Shared/Scroll/ScrollBox.xml:20-50` | `ScrollBoxBaseTemplate` |
| List/static templates | `Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.xml:3-68` | `WowScrollBoxList`, `WowScrollBox`, scrollbar orientation templates, scrolling edit/font compositions |
| ScrollBox controller | `Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua:1-943` | `ScrollBoxBaseMixin`, `ScrollBoxListMixin`, `ScrollBoxMixin` |
| Base view | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxView.lua:2-138` | `ScrollBoxViewMixin` |
| List lifecycle | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxListView.lua:1-803` | provider binding, factory/pool, initializer/resetter, recycling |
| Linear views | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxLinearView.lua:1-304` | list/static linear mixins and factories |
| Biaxial sizing | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxBiaxalView.lua:1-203` | element size and size calculator |
| Grid view | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxGridView.lua:1-105` | `ScrollBoxListGridViewMixin`, list-grid factory |
| Range/stride math | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxStride.lua:1-152` | visible index calculation and row-stride extents |
| Padding | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxPadding.lua:1-87` | linear and biaxial padding objects |
| View anchoring | `Blizzard_SharedXML/Shared/Scroll/ScrollBoxViewUtil.lua:1-97` | stretch/anchor layout and range guard |
| Scroll controller | `Blizzard_SharedXML/Shared/Scroll/ScrollController.lua:1-211` | percentage, wheel, pan, direction, interpolation |
| Scrollbar behavior | `Blizzard_SharedXML/Shared/Scroll/ScrollBar.lua:1-429` | `ScrollBarMixin`, step/page/thumb state |
| Scrollbar structure | `Blizzard_SharedXML/Shared/Scroll/ScrollBar.xml:3-23` | `ScrollBarBaseTemplate` |
| Binding and behaviors | `Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua:1-1724` | controller binding, visibility, selection, callbacks, resize support |
| Minimal scrollbar | `Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.lua:1-65`, `.xml:3-139` | modern minimal vertical visual |
| Trim scrollbar | `Blizzard_SharedXML/Shared/Scroll/TrimScrollBar.lua:1-76`, `.xml:3-301` | vertical/horizontal trim visuals |
| Mainline themed bar | `Blizzard_SharedXML/Mainline/Scroll/OribosScrollBar.*` | Oribos/Soulbinds visual on modern controller |
| Frame pooling | `Blizzard_SharedXMLBase/FrameFactory.lua:1-63`; `Blizzard_SharedXMLBase/Pools.lua:519-537,661-685` | template-aware factory and hide/clear-anchor reset |
| Native ScrollFrame API | `Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua` | one-large-child intrinsic scrolling APIs |
| Current ScrollFrame wrapper | `Blizzard_SharedXML/SecureUIPanelTemplates.xml:24-39`; `.lua:1-34`; `Mainline/ScrollDefine.lua:1-4` | `ScrollFrameTemplate` creates a `MinimalScrollBar` |
| Explicit legacy paths | `Blizzard_SharedXML/SecureScrollTemplates.*`; `HybridScrollFrame.*`; `Blizzard_SharedXML.toc:229-231` | deprecated UIPanel/Faux/Hybrid infrastructure |

No generated `ScrollBox` API documentation file was found. ScrollBox's public surface in this snapshot is implemented in Lua mixins; the generated `SimpleScrollFrameAPI` applies to the native `ScrollFrame` widget, not to `WowScrollBoxList`.

## 4. Name and architecture audit

The following table prevents historical or conceptual names from being mistaken for current constructors.

| Requested/conceptual name | LIVE result | Kind/current equivalent |
| --- | --- | --- |
| `ScrollBox` | No exact global constructor/template named `ScrollBox` | Architecture name; base implementation is `ScrollBoxBaseMixin`/`ScrollBoxBaseTemplate` |
| `ScrollView` | No exact `ScrollView` symbol found | Current base is `ScrollBoxViewMixin` |
| `ScrollBoxList` | No exact template/global by this name | Current reusable template is `WowScrollBoxList`; behavior is `ScrollBoxListMixin` |
| `ScrollBoxLinearView` | Exists as `ScrollBoxLinearViewMixin` | Static-child view returned by `CreateScrollBoxLinearView` |
| `ScrollBoxListLinearView` | Exists as `ScrollBoxListLinearViewMixin` | Provider-backed view returned by `CreateScrollBoxListLinearView` |
| `ScrollBoxGrid` | No exact symbol found | Provider-backed grid is `ScrollBoxListGridViewMixin` |
| `ScrollBoxGridView` | No exact mixin/factory by this name | Current equivalent is `ScrollBoxListGridViewMixin` / `CreateScrollBoxListGridView` |
| `ScrollBoxLinearBaseView` | Exists as `ScrollBoxLinearBaseViewMixin` | Shared layout mixin used by both linear view families; not a factory |
| `CreateScrollBoxListLinearView` | Exists | Ordinary provider-backed linear collection factory |
| `CreateScrollBoxListGridView` | Exists | Provider-backed grid factory |
| `CreateScrollBoxLinearView` | Exists | Static, non-provider child layout for `WowScrollBox` |
| `CreateScrollBoxGridView` | Not found | Do not invent it; use the list-grid factory |
| `CreateScrollBoxListSequenceView` | Exists | More general biaxial sequence view; not needed for the first ordinary addon sample |
| `CreateScrollBoxListTreeListView` | Exists | Tree-aware linear view; specialized beyond the first sample |

**SOURCE-VERIFIED FACT:** `CreateScrollBoxListLinearView(top, bottom, left, right, spacing)` and `CreateScrollBoxListGridView(stride, top, bottom, left, right, horizontalSpacing, verticalSpacing)` return initialized Lua objects composed from the corresponding mixins. They do not create UI frames. The caller still configures an element factory/initializer and connects the view to a ScrollBox.

## 5. Reusable templates

### 5.1 Core viewport templates

#### `ScrollBoxBaseTemplate`

**SOURCE-VERIFIED FACT:** this virtual `Frame` sets `clipChildren="true"`, mixes in `ScrollBoxBaseMixin`, and creates required `DragDelegate`, `ScrollTarget`, and `Shadows` children. The `ScrollTarget` is an `EventFrame` deliberately given a `1 x 1` valid rectangle. The template handles load, size change, and mouse wheel. It defines no width/height and contains no scrollbar (`ScrollBox.xml:20-50`).

The target is repositioned as the scroll percentage changes; visible elements are anchored under it and clipped by the viewport. The view, not XML, calculates extents and lays out elements.

#### `WowScrollBoxList`

**SOURCE-VERIFIED FACT:** this virtual frame inherits `ScrollBoxBaseTemplate` and adds `ScrollBoxListMixin`. It adds no XML children, dimensions, scrollbar, element template, or layout. Its comment says it is intended for ScrollBoxes using a data provider (`ScrollTemplates.xml:3-10`).

This is the ordinary reusable host for lists and grids.

#### `WowScrollBox`

**SOURCE-VERIFIED FACT:** this virtual frame inherits the same base but adds `ScrollBoxMixin`. It is intended for static ScrollBoxes such as a single frame containing a font string (`ScrollTemplates.xml:12`). `ScrollBoxLinearViewMixin:ReparentScrollChildren` reparents only children marked `scrollable=true` into the moving target (`ScrollBoxLinearView.lua:251-302`). It has no provider or element pool.

`ScrollingEditBoxTemplate` and `ScrollingFontTemplate` demonstrate this static composition with a single scrollable edit-box/container child (`ScrollTemplates.xml:21-68`; `ScrollTemplates.lua:1-389`).

#### Practical collection mapping

| Addon-owned need | Source-backed starting composition |
| --- | --- |
| Ordinary vertical configuration list | `WowScrollBoxList` + list-linear view + template/fixed row extent + `MinimalScrollBar` |
| Compact media/list picker | Same composition with table element data, a complete idempotent row initializer, and external selected value |
| Large selectable list | Same composition with fixed identical extent where practical, provider-backed identity, and optional `ScrollUtil.AddSelectionBehavior` |
| Grid/icon collection | `WowScrollBoxList` + `CreateScrollBoxListGridView` + explicit element size/stride + `MinimalScrollBar` |

There is no more complete generic XML template that automatically chooses these policies. The repeated Blizzard pattern is to declare the viewport/bar geometry in consumer XML and configure/bind the reusable view/provider pieces in Lua.

### 5.2 Scrollbar templates

#### `VerticalScrollBarTemplate` / `HorizontalScrollBarTemplate`

These inherit `ScrollBarBaseTemplate` and `ScrollBarMixin`. The horizontal form sets `isHorizontal=true`. They are structural/controller bases, not complete visuals: `ScrollBarMixin:OnLoad` expects child keys `Track`, `Track.Thumb`, `Back`, and `Forward`, which the visual templates supply (`ScrollTemplates.xml:14-20`; `ScrollBar.lua:10-50`).

#### `MinimalScrollBar`

**SOURCE-VERIFIED FACT:** this complete vertical companion inherits `VerticalScrollBarTemplate`, is `8 x 560` before caller anchors override its height, and supplies the track, proportional thumb, and 17-by-11 back/forward steppers. Its minimum thumb extent is 23. Current Settings, Communities, Encounter Journal, and many unrelated consumers use it (`MinimalScrollBar.xml:15-139`).

It is the strongest generic visual default for ordinary addon-owned ScrollBoxes.

#### `WowTrimScrollBar` / `WowTrimHorizontalScrollBar`

**SOURCE-VERIFIED FACT:** these are complete modern `ScrollBarMixin` companions, `25 x 560` vertically and `560 x 25` horizontally, with trim/background/backplate artwork (`TrimScrollBar.xml:25-301`). They are loaded by SharedXML and are not source-marked deprecated.

A full LIVE consumer search found no use outside their definitions. Therefore availability is verified but current representative adoption is not. Do not recommend them solely because their names sound generic.

#### `OribosScrollBar`

This is a complete Mainline `VerticalScrollBarTemplate` visual (`10 x 560`) with Soulbinds/Oribos artwork. Current Covenant mission, Adventures combat-log, and Soulbinds consumers exist. Its controller pattern is current; its artwork is feature-themed and should not be copied as the generic addon default.

### 5.3 Composite and specialized templates

| Template | Verified composition | Reuse assessment |
| --- | --- | --- |
| `ScrollBoxSelectorTemplate` | `SelectorTemplate` + fixed-size `WowScrollBoxList` + `MinimalScrollBar`; creates a fixed-stride grid and an index-range provider | Current specialized shared selector. Use only when accepting its selector contract; primitives are clearer for the first sample. |
| `BottomPopupScrollBoxTemplate` | fixed `600 x 400` dialog-like shell containing list + minimal bar | Shared but presentation-heavy; only the Encounter Journal search popup inherits it in Mainline. Not a general list requirement. |
| `SettingsListTemplate` | Settings header, input blocker, list, minimal bar | Feature-owned Settings list; its factory data and layout lifecycle are not a generic addon list abstraction. |
| `SettingsCategoryListTemplate` | Settings category list + minimal bar | Feature-owned navigation surface; general primitives remain reusable. |
| `ScrollingEditBoxTemplate` | `WowScrollBox` + one multiline `EventEditBox` | Current static multiline composition, not a recycled collection. |
| `ScrollingFontTemplate` | `WowScrollBox` + one font-string container | Current static scrolling text composition. |

**SOURCE-VERIFIED FACT:** none of the core ScrollBox templates establishes a feature window shell. Addon code must provide parent, anchors/dimensions, and any border/background.

## 6. Views: layout and element-creation policy

### 6.1 List-linear view

`CreateScrollBoxListLinearView(...)` returns `ScrollBoxListLinearViewMixin`, composed from:

- `ScrollBoxListViewMixin`: provider, pool, visible range, lifecycle;
- `ScrollBoxListStrideMixin`: range and extent math;
- `ScrollBoxLinearBaseViewMixin`: linear anchoring, padding, spacing, optional indentation.

The view is vertical by default. Because it inherits `ScrollDirectionMixin`, callers may set a linear view horizontal before connection. In vertical mode the default layout clears root-element anchors, anchors each row at top-left, and also anchors top-right unless `SetElementStretchDisabled(true)` is used. Thus ordinary vertical rows stretch to the viewport's current content width (`ScrollBoxViewUtil.lua:29-52`).

Configuration paths:

```lua
local view = CreateScrollBoxListLinearView(top, bottom, left, right, spacing)
view:SetElementInitializer("MyRowTemplate", Initializer)
-- Optional when the template has no usable height or a deliberate override is wanted:
view:SetElementExtent(rowHeight)
-- Alternative for variable height:
view:SetElementExtentCalculator(ExtentCalculator)
```

`SetElementInitializer` is the simplest single-template path. `SetElementFactory` is the heterogeneous path: the factory chooses a template and initializer from each element's data.

### 6.2 Static linear view

`CreateScrollBoxLinearView(...)` returns `ScrollBoxLinearViewMixin`. It lays out already-created children with `scrollable=true`; it has no data provider, element factory, or pooling. It is the view expected by `WowScrollBox` and used by the scrolling edit/font compositions.

### 6.3 Grid view

`CreateScrollBoxListGridView(...)` returns `ScrollBoxListGridViewMixin`, composed from the list view, biaxial sizing, and stride math. It supports:

- fixed element size through `SetElementSize(width, height)`;
- per-element size through `SetElementSizeCalculator`;
- template-derived size when template metadata is complete;
- explicit fixed column stride through the factory's first argument or `SetStride`;
- width-derived stride only if `SetStrideExtent(extent)` is explicitly configured;
- top/bottom/left/right padding and separate horizontal/vertical spacing;
- alternate `GridLayoutMixin.Direction` values.

The default direction is `TopLeftToBottomRight`. Vertical-fill directions force `SetVirtualized(false)` because the current implementation cannot virtualize multiple non-contiguous visible ranges (`ScrollBoxGridView.lua:56-76`).

No `SetStrideExtent` consumer was found in the LIVE source tree. Representative Blizzard grids pass a fixed stride: Communities avatar picker uses six, Encounter Journal instance selection uses four, and Professions recipe flyout uses its declared maximum column count.

### 6.4 Other verified views

- `CreateScrollBoxListTreeListView(...)` supplies a tree-aware linear view and specialized safe scrolling/expansion behavior.
- `CreateScrollBoxListSequenceView(...)` supplies a biaxial sequence layout whose row length can vary.
- These are current, but neither is required to explain the ordinary list/grid composition or to build the first comparison sample.

## 7. Data providers

### 7.1 Normal provider

**SOURCE-VERIFIED FACT:** `CreateDataProvider(tbl)` creates a `DataProviderMixin`, initializes an empty `collection`, and inserts the supplied array in order (`DataProvider.lua:14-24,277-280`). Element values may be tables or other Lua values; no schema is imposed.

Verified operations include:

- append: `Insert(...)`, `InsertTable(...)`, `InsertTableRange(...)`;
- positional insert: `InsertAtIndex(elementData, insertIndex)`;
- removal: `Remove(...)`, `RemoveIndex`, `RemoveIndexRange`, predicate removals;
- replacement: `ReplaceAtIndex` (implemented as remove then insert);
- movement: `MoveElementDataToIndex`;
- reset: `Flush()`; there is no `Reset` method in this implementation;
- lookup: `Find`, `FindLast`, `FindIndex`, predicate variants;
- traversal: `Enumerate`, reverse enumeration, `ForEach`;
- ordering: `SetSortComparator`, `ClearSortComparator`, `Sort`;
- direct backing access: `GetCollection`.

Events are `OnSizeChanged`, `OnInsert`, `OnRemove`, `OnSort`, and `OnMove`. `InsertTable` emits per-element `OnInsert` events but one final `OnSizeChanged`. A comparator causes size-change notification to carry a pending-sort flag; the view defers that refresh and responds to the following `OnSort` instead (`DataProvider.lua:58-108`; `ScrollBoxListView.lua:323-348`).

No explicit begin/end batch API was found. `MoveElementDataToIndex` is implemented through public remove and insert operations and can therefore generate their intermediate callbacks in addition to `OnMove`.

### 7.2 Provider-to-view invalidation

The list view registers for provider `OnSizeChanged` and `OnSort`, not for `OnInsert`, `OnRemove`, or `OnMove` directly. Normal public size-changing operations trigger `OnSizeChanged`, so the view signals `OnDataChanged`; ScrollBox then performs an immediate full update. Sort triggers the same contents-changed path (`ScrollBoxListView.lua:314-354`; `ScrollBox.lua:724-727`).

**ENGINEERING RECOMMENDATION:** mutate through provider methods. Directly editing the table returned by `GetCollection()` or changing fields inside an existing element table emits no provider event. For visible-data-only changes, update the visible frame deliberately or call `ReinitializeFrames()`. For a structural/full rebind, assign a provider or call `Rebuild(retainScrollPosition)` with an understood lifecycle cost.

### 7.3 Virtual index provider

`CreateIndexRangeDataProvider(size)` represents values `1..size` without allocating one data table per entry. Its source explicitly cites ranges such as 20,000 macro icons. Its minimal API supports enumerate, size, set size, flush, find, and predicate lookup (`IndexRangeDataProvider.lua:1-76`).

The list view recognizes `IsVirtual()` and samples one element when building template metadata rather than enumerating the whole virtual provider (`ScrollBoxListView.lua:561-586`). This provider does not supply the normal mutation/sort API and its element data are numeric indices.

### 7.4 Selection ownership

Neither provider owns selection as part of its base contract. Intrusive selection can deliberately store `elementData.selected`; default extrusive selection is held by a separate `SelectionBehaviorMixin`. See section 13.

### 7.5 Minimum safe provider pattern

```lua
local view = CreateScrollBoxListLinearView(0, 0, 0, 0, 2)
view:SetElementInitializer("MyRowTemplate", function(row, elementData)
    row:Init(elementData)
end)

ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

local provider = CreateDataProvider(rows)
scrollBox:SetDataProvider(provider)
```

To replace all data, create and assign a new provider. To retain the current position request `ScrollBoxConstants.RetainScrollPosition`, understanding that exact visual retention after extent/viewport changes remains a runtime question. To empty the current provider, call `provider:Flush()` or `scrollBox:FlushDataProvider()`.

## 8. Element creation, initialization, reset, and recycling

### 8.1 Lifecycle order

**SOURCE-VERIFIED FACT:** each list view owns a `CreateFrameFactory()` and template-info cache (`ScrollBoxListView.lua:14-52`). For an element entering the visible range:

1. The element factory selects a frame template/native frame type and initializer.
2. `FrameFactoryMixin` acquires a newly created or pooled frame under `ScrollTarget` and returns a `new` flag.
3. The view calculates and applies root frame extent/size.
4. The view assigns `GetData`, `GetElementData`, `GetElementDataIndex`, `GetOrderIndex`, and narration index accessors.
5. The frame is shown and `OnAcquiredFrame(frame, elementData, new)` fires.
6. The view sorts and anchors all visible frames during layout.
7. Only after layout, the initializer runs as `initializer(frame, elementData)`.
8. `OnInitializedFrame(frame, elementData)` fires (`ScrollBoxListView.lua:356-424`; `ScrollBox.lua:762-795`).

This ordering intentionally allows an initializer to query its effective dimensions after layout.

On release:

1. the optional element resetter runs as `resetter(frame, oldElementData)`;
2. `OnReleasedFrame(frame, oldElementData)` fires;
3. the frame returns to its pool;
4. the pool resetter runs (default: hide and clear the root frame's anchors);
5. ScrollBox element-data/order/narration accessors are removed (`ScrollBoxListView.lua:450-466`; `FrameFactory.lua:14-45`; `Pools.lua:519-537`).

`SetElementResetter` is the element-data cleanup hook. `SetFrameFactoryResetter` replaces the pool-level resetter. They are different lifecycle points.

### 8.2 Recycling behavior

Only the currently required range is normally represented by frames. When the visible range changes, the view tries to keep a frame whose table-valued `elementData` identity remains present; it releases frames for data leaving the range and acquires frames for new data. A provider reassignment disables that identity recycling and releases/reacquires the range. If any currently visible element data are not tables, the optimized identity-recycling branch is disabled for that range (`ScrollBoxListView.lua:688-772`).

The same physical frame may therefore initialize multiple times for different element data. A retained frame/data pair may remain without a new initializer call. `ReinitializeFrames()` explicitly invokes initializers for all currently visible frames.

### 8.3 Stale-state rules

**ENGINEERING RECOMMENDATION:** treat every initializer as a complete render of all data-dependent state. At minimum, explicitly set both sides of every state that may differ between elements:

- text and font/color;
- texture/atlas, texcoords, vertex color, and visibility;
- checked/radio/selected/highlight state;
- enabled/disabled state and alpha/desaturation;
- tooltip data and any hover-only regions;
- child-region anchors that the initializer changes;
- any element-owned IDs, callbacks, or context fields.

Install invariant scripts, hooks, and child regions once in template `OnLoad`, or guard one-time setup with the acquisition `new` flag/a frame-local created flag. Reinstalling hooks or allocating child regions on every initializer defeats pooling and can duplicate behavior. If element types share one frame template but need different scripts, install/clear that variation in acquired/released callbacks or an element resetter.

Do not anchor the root element in its initializer; the view clears and owns its root anchors during each layout. The pool's default root reset does not prove that every child texture, check state, script, tooltip, or application field is reset. Blizzard's Settings and Achievement consumers supply explicit resetters when their row lifecycle requires one.

### 8.4 Public lifecycle utilities

`ScrollUtil.AddAcquiredFrameCallback`, `AddInitializedFrameCallback`, and `AddReleasedFrameCallback` register against list events. Acquired callbacks can use `new` for one-time physical-frame work; initialized callbacks run after layout; released callbacks support behavior cleanup. Each helper can optionally visit existing frames where its signature allows (`ScrollUtil.lua:14-52`).

## 9. Fixed and variable element extents

### 9.1 Fixed/template-derived extent

For a single element template, `SetElementInitializer` remembers the template. During view initialization, if no explicit extent/calculator exists and XML template information is available, the view reads the template's height for a vertical view or width for a horizontal view and sets that as the element extent (`ScrollBoxListView.lua:35-52`).

An explicit `view:SetElementExtent(extent)` is appropriate when using a native frame type such as `"Button"`, when template metadata has no positive dimension, or when a deliberate fixed row extent is required.

Fixed identical extents take the optimized stride calculation path. The source comments require identical extents for very large element ranges (10,000+) to avoid linear visible-index search costs (`ScrollBoxStride.lua:88-113`).

### 9.2 Variable extent

`SetElementExtentCalculator(function(dataIndex, elementData) ... end)` is genuinely supported. The view evaluates and caches a numeric extent for every provider element during extent recalculation. Heterogeneous template factories may also derive differing extents from each template's XML metadata (`ScrollBoxLinearView.lua:102-244`).

Settings uses a variable extent calculator because its initializer objects can return a custom extent or fall back to their selected template height. Encounter Journal uses a calculator for different header/item rows. Achievement UI calculates expanded/collapsed achievement heights and adds `ScrollUtil.AddResizableChildrenBehavior`.

**ENGINEERING RECOMMENDATION:** use a fixed/template-derived extent for homogeneous configuration rows and media pickers. Use variable extent only when row height is truly data-dependent. It adds whole-provider extent calculation/cache work and requires explicit invalidation when runtime child height changes.

### 9.3 Runtime dimension changes

`ScrollUtil.AddResizableChildrenBehavior` subscribes to compatible element `OnSizeChanged` callbacks and queues `scrollBox:FullUpdate()` for the next frame. Its own source lists limitations: it can be called during layout/acquire, invalidates all calculated extents rather than only the changed element, and cannot update immediately because of reentrancy (`ScrollUtil.lua:1594-1624`).

This one-shot internal `OnUpdate` is deferred invalidation, not addon polling. Ordinary provider-driven ScrollBox use requires no recurring addon-owned `OnUpdate`.

## 10. Lists versus grids

| Concern | Linear list | Grid |
| --- | --- | --- |
| Factory | `CreateScrollBoxListLinearView` | `CreateScrollBoxListGridView` |
| Main extent | element height vertically; width horizontally | row height; biaxial element width/height |
| Spacing | one extent-axis spacing | separate horizontal and vertical spacing |
| Cross-axis behavior | rows stretch across viewport by default | explicit/template-derived element size |
| Visible range | contiguous element range | contiguous row-stride range |
| Normal virtualization | supported | supported for default row-major directions |
| Vertical-fill directions | not applicable | force non-virtualized mode |
| Column count | not applicable | fixed stride unless `SetStrideExtent` is supplied |

**SOURCE-VERIFIED FACT:** when fixed stride is used, the visible begin/end calculations advance in stride-sized rows. The end index is rounded to the current row boundary and clamped to provider size. The final incomplete row therefore contains only remaining elements; no filler frames are generated (`ScrollBoxStride.lua:77-152`).

If `SetStrideExtent(extent)` is configured, `GetStride()` derives a count from the ScrollTarget width, element stride extent, and horizontal spacing. ScrollBox performs an immediate full update when a biaxial viewport or ScrollTarget changes size (`ScrollBoxGridView.lua:14-39`; `ScrollBox.lua:110-130`). No LIVE consumer of this width-derived mode was found, so its exact resize feel belongs in the runtime plan.

Representative fixed-stride consumers:

- Communities avatar picker: six-column `AvatarButtonTemplate`, `CreateIndexRangeDataProvider`.
- Encounter Journal instance selection: four columns, explicit padding/spacing, `EncounterInstanceButtonTemplate`.
- Professions recipe flyout: declared maximum columns.

## 11. Scrollbar integration

### 11.1 Binding is explicit

`ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)`:

1. establishes a one-to-one ScrollBox/ScrollBar registration;
2. propagates ScrollBox scroll, visible extent, pan extent, size, and allow-scroll state to the bar;
3. propagates scrollbar scroll and allow-scroll state back to the ScrollBox;
4. disables interpolation on both if either side cannot interpolate;
5. initializes the ScrollBox with the view;
6. initializes the bar from the resulting extent (`ScrollUtil.lua:55-147`).

The XML relationship alone does not bind a separately declared list and bar. `ScrollUtil.InitScrollBoxWithScrollBar` is the parallel entry point for static `WowScrollBox`; it is currently implemented identically but intentionally kept as a distinct public function. `RegisterScrollBoxWithScrollBar` is for the rarer already-initialized case.

### 11.2 Wheel, step, page, and thumb

The shared controller stores a saturated 0..1 percentage. Mouse wheel moves by the pan-extent percentage multiplied by the default wheel scalar 2.0. A scrollbar stepper moves one pan extent. Track presses page by approximately 95 percent of the visible page. Thumb position and proportional size derive from scroll/visible percentages; steppers disable at the corresponding ends (`ScrollController.lua:69-177`; `ScrollBar.lua:101-268`).

Interpolation defaults off in live templates and carries an XML warning that it is not intended for live use unless both sides enable it.

### 11.3 Visibility

A ScrollBar is not hidden automatically by default. Options are:

- `scrollBar:SetHideIfUnscrollable(true)`: hides the bar when the visible extent covers all content;
- `SetHideTrackIfThumbExceedsTrack(true)`: hides an unusable track state;
- `ScrollUtil.AddManagedScrollBarVisibilityBehavior(...)`: shows/hides the bar and can switch ScrollBox anchors so content expands into the vacant width.

Settings category/list views use managed visibility. The current `ScrollFrameTemplate` can set corresponding bar flags on the automatically created modern bar. The completed sample exercised simple `SetHideIfUnscrollable` behavior; managed anchor switching remains untested and must not be assumed from template inheritance.

## 12. `ScrollFrame` versus `ScrollBox`

| Question | `ScrollFrameTemplate` | `WowScrollBoxList` |
| --- | --- | --- |
| Content ownership | one caller-created scroll child | provider elements represented by acquired/recycled frames |
| Layout | caller sizes/anchors child content | view lays out visible elements |
| Data model | none | data provider |
| Frame count | normally full child composition exists | normally only visible range exists |
| Best fit | one dynamic configuration page, multiline/editable/static rich content | long/repeated lists, pickers, tables, grids |
| Scrollbar | current Mainline template creates `MinimalScrollBar` | companion is separate and explicitly bound |
| Dynamic collection changes | caller updates child and scroll-child geometry | provider events drive recomputation |
| Selection | caller-owned | optional separate ScrollUtil behavior |

**SOURCE-VERIFIED FACT:** `ScrollFrameTemplate` itself is current. Mainline `ScrollDefine.lua` selects `MinimalScrollBar`, and `ScrollFrame_OnLoad` creates and binds it with `ScrollUtil.InitScrollFrameWithScrollBar`. Many current consumers still inherit `ScrollFrameTemplate`, including multiline/detail/help views. The generated native API continues to document its scroll child/range/offset operations.

**SOURCE-VERIFIED FACT:** the older `UIPanelScrollFrameTemplate`, `UIPanelScrollBarTemplate`, FauxScrollFrame family, and their helper code are in `SecureScrollTemplates.*`, whose file-level comment explicitly marks every template/code path there deprecated and recommends ScrollBox or the current `ScrollFrameTemplate` when ScrollBox is unsuitable.

**ENGINEERING RECOMMENDATION:** do not convert one ordinary dynamic Config page to recycled rows merely to adopt a modern name. `ScrollFrameTemplate` remains the simpler architecture when the content is one owned layout whose controls all need to exist. Prefer ScrollBox when repeated collection elements, large data, grid layout, provider-driven mutation, or frame recycling are real benefits.

The static `WowScrollBox` sits between these categories: it uses the modern controller/target model but still scrolls existing children rather than provider-backed recycled elements.

## 13. Selection architecture

**SOURCE-VERIFIED FACT:** selection is not intrinsic to `ScrollBoxListMixin`, a view, or `DataProviderMixin`. `ScrollUtil.AddSelectionBehavior(scrollBox, ...flags)` creates a separate `SelectionBehaviorMixin` attached to that list (`ScrollUtil.lua:356-640`).

Flags:

- `Deselectable`: allows the only selected item to be deselected;
- `MultiSelect`: permits multiple selections;
- `Intrusive`: stores selection in `elementData.selected` instead of an external table.

Default selection is extrusive: the behavior owns a table keyed by element-data identity. Reassigning the provider clears those references to avoid leaks. Intrusive selection deliberately mutates table element data.

The behavior emits `OnSelectionChanged(elementData, selected)`, provides select/deselect/toggle and first/last/next/previous helpers, and can find selections from provider order. It does not paint a selected row. Consumers update a visible frame—for example, Settings calls `FindFrame(elementData)` and `button:SetSelected(selected)`—and decide whether a data rebuild is needed for selection-dependent extents.

Single versus multi-selection is therefore supported by this optional behavior, but keyboard/gamepad binding is feature-owned. No generic key handler was found connecting the next/previous methods to input.

## 14. Programmatic scrolling APIs

### 14.1 Base/controller APIs

| API | Owner | Verified purpose/caveat |
| --- | --- | --- |
| `GetScrollPercentage()` | `ScrollControllerMixin` | current saturated 0..1 controller position |
| `SetScrollPercentage(p, noInterpolation)` | `ScrollBoxBaseMixin` | updates position; optionally uses controller interpolation |
| `ScrollToBegin(noInterpolation)` / `ScrollToEnd(...)` | `ScrollBoxBaseMixin` | percentage 0 or 1 |
| `GetVisibleExtent()` / `GetDerivedExtent()` | `ScrollBoxBaseMixin` | viewport extent versus view-calculated content extent |
| `HasScrollableExtent()` | `ScrollBoxBaseMixin` | true when visible percentage is strictly between epsilon boundaries |
| `GetFrames()` / `GetFrameCount()` | `ScrollBoxBaseMixin` | currently acquired frames only, not all provider data |
| `FindFrame(elementData)` / `FindFrameByPredicate` | base/view | visible frames only |

### 14.2 Provider-backed list APIs

| API | Owner | Verified purpose/caveat |
| --- | --- | --- |
| `GetDataProvider()` | `ScrollBoxListMixin` | returns the view's assigned provider |
| `ForEachFrame` / `EnumerateFrames` | `ScrollBoxListMixin` | visible acquired frames only |
| `ForEachElementData` / provider enumerators | `ScrollBoxListMixin` | whole provider |
| `FindElementData(index)` | `ScrollBoxListMixin` | provider element at index |
| `FindElementDataIndex(elementData)` | `ScrollBoxListMixin` | identity lookup through provider |
| `ScrollToElementDataIndex(index, alignment, offset, noInterpolation)` | `ScrollBoxListMixin` | scrolls by calculated extents; index safety depends on view |
| `ScrollToElementData(elementData, alignment, offset, noInterpolation)` | `ScrollBoxListMixin` | preferred for tree-aware lookup because the view can prepare/expand ancestors |
| `ScrollToElementDataByPredicate(...)` | `ScrollBoxListMixin` | predicate version of the safer element-data path |
| `ScrollToNearest(index, offset, noInterpolation)` | `ScrollBoxListMixin` | chooses begin/end only if the element is outside the viewport |
| `ReinitializeFrames()` | `ScrollBoxListMixin` | reruns initializers for visible frames; does not replace provider |
| `Rebuild(retainScrollPosition)` | `ScrollBoxListMixin` | reassigns the current provider, causing full provider-reassignment lifecycle |

The source directly warns that numeric index scrolling can be wrong for collapsed/skipping tree views; check `IsScrollToDataIndexSafe()` or prefer element-data/predicate methods (`ScrollBox.lua:800-889`).

**SOURCE-VERIFIED CAUTION:** `ScrollToNearestByPredicate(predicate, offset, noInterpolation)` accepts three arguments but this snapshot forwards only the predicate, nearest alignment, and the third local argument into the callee's `offset` position. The supplied `offset` is not forwarded. This appears inconsistent with the adjacent wrapper signature. Avoid relying on its optional arguments until runtime/source correction clarifies the behavior; use `ScrollToElementDataByPredicate` explicitly.

## 15. Update and invalidation model

### 15.1 What triggers work

- `scrollBox:SetView(view)` flushes the old view, transfers an old provider if present, sets direction/target anchors, and performs a full update when replacing a view.
- `scrollBox:SetDataProvider(provider, retain)` attaches provider callbacks, signals reassignment/data change, normally scrolls to begin unless retention is requested, and updates immediately.
- Provider size changes and sorts signal contents changed and full update.
- Scrolling calls `Update()`, recalculates the visible data range, recycles/acquires as needed, lays out changed frames, then invokes initializers.
- A list viewport size change forces layout; biaxial viewport/target size changes force full extent recomputation.
- `FullUpdate()` recalculates view extent, adjusts scroll percentage against the old absolute derived offset where a range remains, updates visible frames, and emits `OnLayout`.
- `AddResizableChildrenBehavior` schedules a one-frame deferred full update for child-size changes.

`FullUpdate()` without the immediate flag temporarily installs a one-shot `OnUpdate`, removes it when run, and then updates. No persistent polling loop is part of the ordinary architecture (`ScrollBox.lua:119-194`).

### 15.2 Important non-triggers

- Editing a field inside an existing element-data table does not notify the provider.
- Direct mutation through `GetCollection()` does not notify the provider.
- `FullUpdate` does not promise to rerun an initializer for retained frames; a source FIXME explicitly distinguishes that expectation from `Rebuild`.
- Changing a view's extent policy alone is not documented as an automatic ScrollBox event; consumers that change it dynamically must trigger the appropriate refresh.

**ENGINEERING RECOMMENDATION:** use provider events for structure, `ReinitializeFrames` for a deliberate visible rerender, and `Rebuild`/provider reassignment for full identity/layout replacement. Do not add addon-owned polling.

## 16. Resize behavior

**SOURCE-VERIFIED FACT:** `ScrollBoxBaseTemplate` has `OnSizeChanged`. For non-biaxial views it calls `Update(forceLayout=true)`. This reanchors/stretches currently visible linear rows to the new width but does not by itself assert that text-wrapped row heights changed. Biaxial views receive immediate `FullUpdate` because viewport size can alter the displayed index range (`ScrollBox.lua:110-130`).

`FullUpdateInternal` records the old derived scroll offset, recalculates extents, and adjusts the new percentage to counter displacement when a nonzero range remains (`ScrollBox.lua:154-194`). This is evidence of an intent to retain apparent content offset across extent changes, not proof of every edge case.

For grids:

- fixed stride retains its declared column count as width changes;
- width-derived stride recalculates only when `SetStrideExtent` was configured;
- the full-update path recalculates the grid extent and visible range;
- managed scrollbar reanchoring can temporarily invalidate rects, and its source explicitly relies on the biaxial size-change full update to correct grid calculations (`ScrollUtil.lua:281-354`).

**LIVE-OBSERVED BEHAVIOR:** the implemented fixed-stride grid and explicit variable-extent rebuild remained coherent across the tested viewport bounds and root scales. Section 26 records the bounded results. Managed-anchor switching, width-derived stride, and automatic resizable-child behavior were not exercised.

No relevant `ResizeToBoundsRect` call or dependency was found in the generic ScrollBox implementation. Do not add it to the architecture without a concrete consumer requirement.

## 17. Representative LIVE consumers

### 17.1 Settings list — heterogeneous configuration rows

- Paths: `Blizzard_Settings_Shared/Blizzard_SettingsList.lua:38-149`, `.xml:4-63`.
- Template: `WowScrollBoxList` + `MinimalScrollBar` inside `SettingsListTemplate`.
- View: list-linear with padding/spacing.
- Factory: each Settings element initializer chooses its own template.
- Extent: initializer-provided extent or template-derived fallback.
- Resetter: calls each Settings initializer's resetter through `securecallfunction`.
- Provider: new `CreateDataProvider()` populated from visible initializers.
- Visibility: managed scrollbar behavior.
- Feature-specific pieces not to copy: Settings initializer objects, layout/search/defaults/input-blocker lifecycle, global `SettingsPanel`, secure wrappers around feature data.

### 17.2 Settings category list — selectable navigation

- Paths: `Blizzard_Settings_Shared/Blizzard_CategoryList.lua:190-241,470`, `.xml:4-29`.
- View: list-linear factory with element indentation.
- Selection: `ScrollUtil.AddSelectionBehavior`; consumer paints the visible selected frame and scrolls it nearest.
- Provider: flat factory-initializer list.
- Bar: `MinimalScrollBar` with managed visibility and alternate anchors.
- Do not copy: Settings category objects, module-local selection ownership, category-panel callbacks, feature row templates.

### 17.3 Auto-complete popup — compact list without a bar

- Paths: `Blizzard_AutoCompletePopupList/Blizzard_AutoCompletePopupList.lua:1-130`, `.xml:57-112`.
- Template: feature-sized popup containing `WowScrollBoxList`; no scrollbar child in the template. The Lua adjusts the popup height from its result count.
- View: list-linear with 1/3 padding and one-pixel spacing.
- Initializer: `AutoCompletePopupListResultTemplate`.
- Provider: result tables containing display and owner data.
- Selection/highlight: feature-owned numeric highlighted-result logic, not `SelectionBehaviorMixin`.
- Do not copy: talent/spell autocomplete callbacks, owner width assumption, popup-specific keyboard/highlight model.

### 17.4 Communities avatar picker — fixed grid

- Paths: `Blizzard_Communities/CommunitiesAvatarPickerDialog.lua:25-102`, `.xml:21-57`.
- Template: `WowScrollBoxList` + `MinimalScrollBar`.
- View: `CreateScrollBoxListGridView(6)`, explicit button size from template/picker and grid spacing.
- Provider: `CreateIndexRangeDataProvider` for avatar indices.
- Selection: feature-owned `avatarId` and selected texture; not generic selection behavior.
- Do not copy: club APIs, global dialog ownership, `SetAttribute` bridge, avatar texture calls.

### 17.5 Encounter Journal — mixed variable list and grid

- Paths: `Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.lua:325-418`; XML ScrollBox/MinimalScrollBar pairs near `:1407-1461`, `:1761-1771`, and `:1875-1955`.
- Boss/search lists: list-linear with one row template.
- Loot: factory chooses divider or item; extent calculator chooses heights.
- Instance collection: fixed four-column grid with padding/spacing.
- Bar: `MinimalScrollBar`.
- Do not copy: Encounter Journal globals, loot filters, feature element templates, the search popup shell.

### 17.6 Auction House item list — large recycled/table list

- Path: `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseItemList.lua:130-203` plus feature XML.
- View: list-linear factory.
- Provider: caller-owned auction results.
- Element template: selected auction line template.
- Extra behaviors: TableBuilder integration and alternate-row callbacks.
- Selection: feature callback/highlight state, not generic provider state.
- Do not copy: Auction House TableBuilder schema, row globals, search/result callbacks.

### 17.7 Oribos/Soulbinds scrollbar consumer

`OribosScrollBar` is used by Covenant mission templates, Adventures combat log, and Soulbinds conduit list. It verifies that another visual style can use the same current controller contract. It is a themed example, not a reason to choose its art for addon Config UI.

No current consumer of `WowTrimScrollBar` was found. That absence is recorded rather than silently treating the template as the current default.

## 18. Settings framework conclusion

**SOURCE-VERIFIED FACT:** Settings uses ScrollBox internally for both its left category list and its right settings-control list. Both use `WowScrollBoxList`, `CreateScrollBoxListLinearView`, `CreateDataProvider`, and `MinimalScrollBar`. The category list adds general selection/managed-visibility helpers; the settings list adds a heterogeneous factory, variable extent calculator, resetter, managed visibility, and resizable children.

The supported high-level Settings APIs register categories, layouts, and setting-backed controls. That lifecycle causes Settings to render the addon's registered controls inside its own ScrollBoxes. It does not expose a high-level constructor for an arbitrary addon-owned ScrollBox collection in an independent frame.

**ENGINEERING RECOMMENDATION:** use Settings registration when the UI belongs in Blizzard Settings. For an independent addon window, use the general SharedXML ScrollBox/view/provider/ScrollUtil pieces directly. Do not instantiate `SettingsListTemplate` or its row factory merely to obtain scrolling or styling.

## 19. Combat, secure, and taint source audit

### 19.1 Generic infrastructure

A focused search of the generic SharedXML ScrollBox, view, provider, controller, ScrollBar, and related XML files found:

- no `InCombatLockdown` check;
- no `SecureHandler` or `SecureActionButtonTemplate` inheritance;
- no protected template declaration;
- no combat-event gate;
- `secureexecuterange` around the initializer table in `ScrollBoxListViewMixin:InvokeInitializers`;
- `securecallfunction` around selection set/deselect entry points.

The secure-call helpers are source-visible execution/taint boundaries. They are not evidence that arbitrary addon callbacks or protected descendants are combat-safe.

The generated native `SimpleScrollFrameAPI` marks `SetHorizontalScroll`, `SetVerticalScroll`, and `SetScrollChild` as protected functions with untainted/secret-argument constraints. This is relevant to the separate intrinsic `ScrollFrame` path; it is not a generated ScrollBox contract.

### 19.2 Narrow operation classification

| Operation | Source-only classification |
| --- | --- |
| Scroll an existing ordinary addon-owned list | No generic source-visible combat gate; runtime validation required |
| Use its existing ordinary scrollbar/wheel | No generic source-visible combat gate; runtime validation required |
| Replace provider / acquire and release addon-owned rows | No generic combat gate, but creates/reparents/sizes frames through pools; runtime validation required |
| Resize/reanchor addon-owned ScrollBox | No generic combat gate; protected ancestry/geometry can change the result |
| Run initializer/selection callbacks | Callback action determines risk; secure wrappers are not blanket permission |
| Mutate protected Blizzard frames or perform protected downstream actions | Outside the generic guarantee; preserve normal combat/taint restrictions |

Representative ordinary Settings, AutoComplete, Communities avatar, and Auction House list source did not add a generic ScrollBox combat policy. Communities' `SetAttribute` usage belongs to its feature dialog bridge, not the grid primitive.

**ENGINEERING RECOMMENDATION:** keep a runtime sample entirely addon-owned, non-secure, and behaviorally inert. The completed sample tested scrolling, provider changes, selection, scaling, and pooling during actual combat; section 26 states the result narrowly. Never generalize that pass to secure actions, protected parents, production callbacks, or taint-sensitive downstream work.

## 20. Performance and lifecycle conclusions

**SOURCE-VERIFIED FACT:** ScrollBox separates a lightweight ordered model from layout and uses template-keyed frame pools. A virtualized view calculates only the visible data range, keeps/recycles table-identity frames where possible, releases other frames, lays out the active set, and initializes after layout. `CreateIndexRangeDataProvider` avoids allocating one data table per represented index. Fixed identical extents have a direct range calculation path.

This architecture explains Blizzard's repeated use for large lists and icon collections without asserting unmeasured performance numbers.

Common ways an addon can defeat the intended lifecycle:

- disabling virtualization for a large grid without a direction requirement;
- creating a child frame/texture/font string every initializer call;
- repeatedly adding hooks/scripts without cleanup or a one-time guard;
- using variable extent when a fixed extent suffices;
- performing expensive whole-provider work inside every row initializer;
- replacing the entire provider for a minor visible-state change;
- rebuilding from `OnUpdate` instead of model events;
- omitting complete state rendering and allowing recycled visual state to leak;
- using invalid one-pixel template extents, which can request excessive ranges—the source hard-errors at a 1000-element visible range guard (`ScrollBoxViewUtil.lua:70-94`).

**ENGINEERING RECOMMENDATION:** keep domain state in the provider/addon model, render rows idempotently, update through events, and let the view own root anchors and visible frame count.

## 21. Accessibility and input

### 21.1 Generic source support

- `ScrollBoxBaseTemplate` and `ScrollBarBaseTemplate` attach `OnMouseWheel` to `ScrollControllerMixin`.
- Wheel direction changes scroll by the configured pan percentage and wheel scalar.
- Scrollbar stepper buttons receive narration names for scroll up/down.
- Acquired list frames receive a default `NarrationGetIndexInfo` returning order and total unless their template already defines one.
- `SelectionBehaviorMixin` exposes next/previous selection methods.

### 21.2 Feature-owned or unresolved

No generic key-down, focus-ring, or gamepad binding was found in the list/grid ScrollBox infrastructure. The scrolling edit-box composition has keyboard/focus callbacks, but those belong to its edit-box wrapper rather than generic collection navigation. Consumers own row focus, click, keyboard/controller routing, activation, and selected-state narration.

**RUNTIME QUESTION:** the completed sample exercised ordinary mouse-wheel scrolling and the diagnostic EditBox focus/copy composition. Exhaustive focus behavior, keyboard navigation, gamepad/controller behavior, narration order, and accessibility of recycled custom rows require a separate validation design. Generic index narration does not make an arbitrary row fully narrated.

## 22. Deprecated and legacy classification

| Path | Classification | Evidence/conclusion |
| --- | --- | --- |
| `FauxScrollFrame*` | Explicitly deprecated | File-level source comment names every Faux variant and recommends ScrollBox/current ScrollFrame |
| `HybridScrollFrame*` | Explicitly deprecated | Same source comment; SharedXML TOC also says retained only for addons and legacy content |
| `UIPanelScrollBarTemplate` | Explicitly deprecated | Defined in `SecureScrollTemplates.xml`, whose comment marks all templates in that file deprecated |
| `UIPanelScrollFrameTemplate` and related classic helpers | Explicitly deprecated | Same file-level declaration |
| `ScrollFrameTemplate` | Current distinct use case | Defined outside the deprecated file; current consumers and current MinimalScrollBar construction remain |
| `ScrollUtil.InitScrollFrameWithScrollBar` | Current compatibility/composition utility | Binds a native ScrollFrame to a modern `ScrollBarMixin` companion |
| `WowTrimScrollBar` | Present/current, not marked deprecated | Loaded modern controller visual; no current consumer found in this snapshot |
| `MinimalScrollBar` | Current general default | Broad active consumers across unrelated Retail features |
| `OribosScrollBar` | Current specialized visual | Active feature consumers; themed rather than general |

Do not label `ScrollFrame` itself obsolete. Do not label an old-looking template deprecated without the source declaration. Conversely, `UIPanelScrollBarTemplate` is not merely old-looking here; its containing source explicitly deprecates it.

## 23. Production architecture mapping (research only)

### 23.1 OdysseusBuffBars

Read-only verification in `OdysseusBuffBars_Config.lua` found:

- general page: current `ScrollFrameTemplate` with one dynamic content frame;
- texture picker: `WowScrollBoxList` + fixed linear view + `MinimalScrollBar`;
- font picker: the same modern provider-backed picker architecture;
- Filter dialog: fixed reusable rows, manual offset, and `UIPanelScrollBarTemplate`;
- Override dialog: fixed reusable rows, manual offset, and `UIPanelScrollBarTemplate`.

**ENGINEERING ASSESSMENT:**

- Texture/font pickers are architecturally aligned with current Blizzard practice: homogeneous collection, fixed row extent, provider-backed visible-frame reuse, separate minimal bar.
- The General page is sensibly a `ScrollFrameTemplate`: it is one dynamic page, not a large repeated collection. Converting it would add lifecycle complexity without a verified benefit.
- Filter/Override dialogs already implement a small manual virtualized-list pattern with a fixed visible row set. That can remain functionally reasonable for bounded stable dialogs, but their exact scrollbar template is source-marked deprecated and the addon owns range, wheel, offset, and row refresh logic that ScrollBox could centralize.
- A future conversion of those two dialogs is an optional maintainability/consistency project, not an automatic requirement and not part of this research task. It should be justified by concrete lifecycle, accessibility, or maintenance benefit and validated in game.

### 23.2 Nightwatch

The prior CategoryNavigation conclusion remains unchanged. ScrollBox research confirms that the transferable general layer is `WowScrollBoxList` + addon-owned row/data/selection logic. It does not reveal a generic Auction-House-like navigation component that should replace Nightwatch's custom navigation wholesale.

If Nightwatch later has a long repeated/virtualized list requirement, general ScrollBox primitives are appropriate. Visual resemblance alone is not such a requirement.

### 23.3 Odysseus Utility Suite

Broad future applicability is limited to repeated long lists, compact data-backed pickers, heterogeneous settings-like collections, and icon grids. One-off dynamic pages and multiline/detail surfaces may remain better `ScrollFrameTemplate` or static `WowScrollBox` candidates. No OUS code was inspected or changed for this conclusion.

## 24. Runtime validation disposition

The completed sample resolved the following source-only questions for its tested compositions on Retail LIVE `12.1.0.69497`:

- direct addon creation of list-linear and grid `WowScrollBoxList` compositions with `MinimalScrollBar` rendered and operated correctly;
- fixed-provider insertion, removal, sorting, replacement, programmatic scrolling, and visible-frame reinitialization completed without errors or polling;
- physical frame release, pooled reacquisition, and rebinding to different element data were directly observed;
- complete initializer/resetter behavior prevented stale deterministic row state during recycling;
- external single selection remained associated with element-data identity across scrolling and recycling;
- explicit variable-extent rebuild with retained position remained in the same logical viewport region;
- fixed-stride grid layout, resizing, root scaling, and its incomplete final row remained coherent;
- the current one-child `ScrollFrameTemplate` contrast scrolled and resized correctly;
- the tested ordinary non-secure interactions operated during actual combat without Lua errors.

Section 26 supplies the detailed observations and qualifications. These questions remain untested or only partially exercised:

- `ScrollToNearestByPredicate` optional-argument behavior;
- width-derived `SetStrideExtent` behavior;
- automatic `ScrollUtil.AddResizableChildrenBehavior` invalidation;
- multi-selection and intrusive selection;
- tree and sequence views;
- drag/reorder and TableBuilder integration;
- managed-scrollbar anchor switching;
- exhaustive keyboard, gamepad, narration, and accessibility behavior;
- universal combat or taint guarantees.

## 25. Implemented `ScrollBoxComparison` scope

The module fits `Samples/RetailUIResearch/` as one isolated, eagerly registered sample with no per-module TOC, SavedVariables, production imports, secure infrastructure, or recurring `OnUpdate`.

Implemented compositions:

1. **Fixed-height linear collection**
   - `WowScrollBoxList`
   - `CreateScrollBoxListLinearView`
   - native `Button` with explicit fixed extent
   - `MinimalScrollBar`
   - `CreateDataProvider` with table elements
   - single external selection behavior

2. **Mixed/variable-height linear collection**
   - same host/bar
   - one extent calculator with deterministic expanded state
   - element resetter and explicit retained-position `Rebuild`
   - automatic resizable-child behavior intentionally omitted

3. **Fixed-size grid/icon collection**
   - `CreateScrollBoxListGridView` with a small fixed stride and explicit element size
   - incomplete final row
   - width-derived stride intentionally omitted

4. **One-child control comparison**
   - current `ScrollFrameTemplate` with one dynamic content frame
   - included to make the architectural boundary visible, not to benchmark performance

Visible diagnostics include:

- scroll percentage, fixed-list visible index range, provider size, and active frame count;
- acquired/initialized/released counters and physical frame IDs;
- `new` versus pooled acquisition;
- element-data identity and selected ID;
- root-scale operations and a combat-state label;
- event log for provider mutation, selection, scale/combat transitions, initialization, reset, acquisition, and release.

Controls provide insertion, removal, provider replacement, reversible sorting, scroll begin/end/to element, visible-frame reinitialization, explicit variable-row rebuild, resize, and scale. Domain callbacks remain inert. The implemented diagnostic history is bounded to 50 numbered entries and uses `ScrollingEditBoxTemplate` for user copy access while restoring its authoritative Lua-owned buffer after attempted edits.

Deliberately exclude:

- Settings row/category templates;
- Auction House, Encounter Journal, Communities, or other feature-owned rows/data;
- Tree/drag/reorder/table-builder behavior;
- legacy Faux/Hybrid/UIPanel scroll infrastructure;
- protected frames/actions and production-addon settings;
- SavedVariables, persistence, automated screenshot generation, or polling;
- an attempt to become a reusable ScrollBox framework.

## 26. Retail LIVE runtime validation

All observations in this section are **LIVE-OBSERVED BEHAVIOR** from the user-tested, addon-owned `ScrollBoxComparison` composition on Retail LIVE `12.1.0.69497`. They are not additional source guarantees. No Lua errors were observed during the supplied pass.

### 26.1 Harness and presentation

The approximately 280-pixel-wide launcher rendered as one vertical column with all six sample buttons visible. Its height derived from the launcher-entry count. `ScrollBoxComparison` opened correctly; the A/B/C/D quadrants and modern `MinimalScrollBar` companions rendered coherently without initialization errors. This validates the current small harness composition, not a general launcher framework.

### 26.2 Fixed linear provider-backed list

The 40-row fixed linear list rendered with only its visible physical-frame subset active. Repeated top-to-bottom-to-top scrolling worked. Physical frames were released, reacquired from the pool, and rebound to different table element data. Representative evidence showed frame 2 reset and released from row 10, then acquired as pooled for row 1 and initialized from the prior scalar ID 10 to row 1.

No stale visual state was observed. Alternate, disabled, emphasized, selected, and normal state remained associated with the correct element data. External single selection survived scrolling and recycling and therefore remained associated with element-data identity rather than a physical row frame in this test.

`Add Row`, `Remove Last`, reversible sorting, replacement with four fitting rows, replacement back to 40 rows, scroll begin/end, programmatic scrolling to a row, and visible-frame reinitialization all operated without errors.

### 26.3 Variable/mixed extents

The deterministic 28/44/64-pixel rows rendered correctly. Row 3 was repeatedly changed between 64 and 82 pixels, followed by the implemented `Rebuild(ScrollBoxConstants.RetainScrollPosition)` path. No overlap, gap, duplicate row, stale height, or scrollbar incoherence was observed.

In one recorded test, the viewport was approximately rows 8–12 at 67 percent with row 3 at 64 pixels. After expanding row 3 to 82 pixels and rebuilding, it remained in approximately the same logical region (rows 7–12) at 64 percent. The percentage changed because total scrollable extent changed. This is a successful retained-position result for this composition, not a universal guarantee for every variable-extent ScrollBox.

### 26.4 Fixed grid

All 31 synthetic tiles rendered correctly with the explicit four-column stride. Scrolling to 100 percent exposed the incomplete final row as tiles 29, 30, and 31 with no phantom fourth tile. No overlap or visible layout corruption was observed. The bar remained coherent, and the acquired visible-frame population adjusted as viewport dimensions changed.

Resizing across the tested bounds and root scaling at 75, 100, and 125 percent preserved the explicit four columns. This does not validate width-derived responsive stride; that experiment was intentionally omitted.

### 26.5 Current `ScrollFrameTemplate` contrast

The one-child `ScrollFrameTemplate` composition scrolled correctly by mouse wheel and scrollbar. Its continuous owned child remained coherent across resizing and 75/100/125-percent root scaling, and long paragraph text wrapped when its owned child width changed. It required no provider or recycling lifecycle.

This supports the engineering distinction established by source: current `ScrollFrameTemplate` remains appropriate for one continuous dynamic owned child, while ScrollBox is useful for repeated provider-backed collections where pooling and recycling provide value. `ScrollFrameTemplate` is not obsolete.

### 26.6 Diagnostic copy area

The `ScrollingEditBoxTemplate` diagnostic surface rendered and retained a maximum of 50 numbered entries. Clicking gave the text focus; Ctrl+A selected the history and Ctrl+C copied it. Attempted typing did not corrupt the authoritative Lua buffer. Enter and Escape lost or cleared focus as observed in this exact composition. That focus result is not generalized to every EditBox composition. Diagnostic numbering and chat-output semantics remained unchanged.

### 26.7 Resize and root scale

The sample resized coherently across representative bounds of approximately 1100×780 through 1360×960. Root scale changes at 75, 100, and 125 percent, including returning to 100 percent, worked. ScrollBox layout and bars stayed coherent; fixed-list acquisition/release adjusted with viewport dimensions, and the grid retained its configured four-column stride.

### 26.8 Combat result and limit

Source inspection found no generic ScrollBox combat gate. During actual Retail combat, the tested addon-owned non-secure ScrollBox/ScrollFrame interactions—including scrolling, fixed-list interaction and selection, harmless provider mutation, and root-scale controls—operated without a Lua error. Movement and resizing remained intentionally blocked by sample policy.

This isolated PASS does **not** establish that arbitrary ScrollBox callbacks, protected operations, secure-action compositions, runtime protected-frame reconfiguration, or taint-sensitive downstream work are universally safe during combat. Addons must evaluate their own protected-operation and taint context.

## 27. Final conclusions

**SOURCE-VERIFIED FACT:** Retail 12.1's general scrolling-collection architecture is `WowScrollBoxList` plus an explicit view, provider, element factory/initializer, and separately bound current scrollbar. Linear and grid views are real, provider-backed, and virtualized by default. Element frames are pooled and initialized after layout; reset/release are explicit lifecycle concepts. Fixed, template-derived, and variable extents are supported. Selection and managed scrollbar visibility are optional ScrollUtil behaviors rather than core provider state.

**SOURCE-VERIFIED FACT:** `ScrollFrameTemplate` remains current for one large owned child and now uses the modern `MinimalScrollBar`. The older `UIPanelScrollBarTemplate`, UIPanel/Faux, and Hybrid paths are explicitly deprecated; ScrollFrame itself is not.

**ENGINEERING RECOMMENDATION:** choose by content ownership:

- one dynamic page or multiline/static rich child: current `ScrollFrameTemplate` or static `WowScrollBox`;
- repeated list/picker/table: `WowScrollBoxList` + list-linear view;
- icon/tile collection: list-grid view;
- Settings category: supported Settings registration, not extracted Settings internals.

Keep element initialization idempotent, mutate through providers, use fixed extents when adequate, add optional behaviors only as needed, and preserve event-driven updates. The tested fixed/variable/grid/one-child compositions, pooling, selection, resize/scale, diagnostic copy, and narrow non-secure combat interactions passed as described in section 26. The unexercised APIs and behaviors listed in section 24, exhaustive accessibility/input coverage, and universal combat/taint behavior remain unresolved.

## 28. Primary source index

- `Interface/AddOns/Blizzard_SharedXML/Blizzard_SharedXML.toc`
- `Interface/AddOns/Blizzard_SharedXML/DataProvider.lua`
- `Interface/AddOns/Blizzard_SharedXML/IndexRangeDataProvider.lua`
- `Interface/AddOns/Blizzard_SharedXML/TreeListDataProvider.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBox.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBox.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxView.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxViewUtil.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxListView.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxLinearView.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxBiaxalView.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxGridView.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxSequenceView.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxTreeView.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxPadding.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBoxStride.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollController.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBar.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollBar.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/ScrollUtil.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/MinimalScrollBar.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/TrimScrollBar.lua`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Scroll/TrimScrollBar.xml`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/Scroll/OribosScrollBar.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/Scroll/OribosScrollBar.xml`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/ScrollDefine.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/Selector/Blizzard_ScrollBoxSelector.xml`
- `Interface/AddOns/Blizzard_SharedXML/Shared/Selector/Blizzard_ScrollBoxSelector.lua`
- `Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/SecureScrollTemplates.lua`
- `Interface/AddOns/Blizzard_SharedXML/SecureScrollTemplates.xml`
- `Interface/AddOns/Blizzard_SharedXML/HybridScrollFrame.lua`
- `Interface/AddOns/Blizzard_SharedXML/HybridScrollFrame.xml`
- `Interface/AddOns/Blizzard_SharedXMLBase/FrameFactory.lua`
- `Interface/AddOns/Blizzard_SharedXMLBase/Pools.lua`
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScrollFrameAPIDocumentation.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsList.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_SettingsList.xml`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_CategoryList.lua`
- `Interface/AddOns/Blizzard_Settings_Shared/Blizzard_CategoryList.xml`
- `Interface/AddOns/Blizzard_AutoCompletePopupList/Blizzard_AutoCompletePopupList.lua`
- `Interface/AddOns/Blizzard_AutoCompletePopupList/Blizzard_AutoCompletePopupList.xml`
- `Interface/AddOns/Blizzard_Communities/CommunitiesAvatarPickerDialog.lua`
- `Interface/AddOns/Blizzard_Communities/CommunitiesAvatarPickerDialog.xml`
- `Interface/AddOns/Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.lua`
- `Interface/AddOns/Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.xml`
- `Interface/AddOns/Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseItemList.lua`
