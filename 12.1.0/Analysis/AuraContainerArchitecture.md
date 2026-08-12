# AuraContainer Architecture

## Evidence Snapshot

**FACT:** The current Retail PTR evidence is `wow-ui-source-ptr`, branch `ptr`, commit `d3915c78aba77a7a9be76acbfa35c674bbb6abe9`, build `12.1.0.68914` (2026-07-24).

**FACT:** The inspected comparison points are PTR commits `c9e817ab7` (68569), `3ea5134b1` (68675), `fa38386c8` (68824), and `d3915c78a` (68914). The live and ptr2 mirrors are `12.0.7.68887`; the beta mirror is the older `12.0.1.66220`. None contains the Retail `Blizzard_AuraContainer` addon.

**OBSERVATION:** The architecture described here is PTR evidence, not a Live API guarantee.

### Live 12.1 Confirmation

**FACT:** The final Retail Live mirror is commit `eb941aad0`, with `version.txt` reporting `12.1.0.69273` and Mainline interface `120100`. The final PTR mirror is commit `6e348870e`, also build `12.1.0.69273`.

**FACT:** Direct tree comparisons found no differences between these Live and PTR revisions in `Blizzard_AuraContainer`, `Blizzard_BuffFrame`, generated API documentation, `AuraUtil.lua`, `AnchorUtil.lua`, `MixinUtil.lua`, TargetFrame's shared aura implementation, Edit Mode, or the restricted addon environment.

**LIVE CONCLUSION:** The ownership model, dirty lifecycle, managed frame retention/release, FlowLayout self-sizing, hidden pooled-frame exclusion, and lack of a public post-layout callback or active-frame enumerator are unchanged. The Phase B.2 topology remains valid: ordinary position root -> self-sizing `CustomAuraContainer` -> container-owned `AuraButton` descendants.

**HISTORICAL NOTE:** Between the older architecture checkpoint `d3915c78a` (build 68914) and the later PTR checkpoint `a520b6c27` (build 69189), disabled managed containers were tightened to clear parsed auras and active item enchantments, AuraButton tooltip refresh ownership moved to the shared forbidden tooltip, frame creation was routed through the global environment for addon template/mixin resolution, and optional pandemic-region and dispel-presentation controls were added. No aura-relevant changes occurred from `a520b6c27` to final PTR `6e348870e`, and none of these late-PTR refinements invalidates the validated enabled BUFFS architecture.

## Overall Architecture

**FACT:** `Blizzard_AuraContainer.toc` enables `UseSecureEnvironment: 1`. Most implementation Lua executes in the secure addon environment. XML templates and the inbound bridge provide the creation and public-entry boundary.

**FACT:** The current system has four layers:

1. `AuraContainer` is the native object and lifecycle owner.
2. `ManagedAuraContainerMixin` performs source parsing, filtering, sorting, frame assignment, and layout invalidation.
3. `CustomAuraContainerMixin` exposes addon-facing group, slot, enchantment, processing, and flow-layout configuration.
4. `AuraButton` and its configured descendants render aura data through restricted native display APIs.

**ANALYSIS:** Blizzard has moved aura interpretation and secret-sensitive presentation behind secure/native boundaries. Addons declare policy and appearance; the framework owns observation, selection, and safe data propagation.

## Module Responsibilities

| Module | Responsibility | Ownership |
| --- | --- | --- |
| `Blizzard_AuraContainer.lua` | Base unit, enabled state, event registration, full/incremental refresh requests | Container lifecycle |
| `Blizzard_ManagedAuraContainer.lua` | Dirty-state pipeline, source parsing, frame reset/assignment, display refresh, layout rebuild | Managed execution pipeline |
| `Blizzard_CustomAuraContainer.lua` | Public custom-container API and processing policy | Addon configuration boundary |
| `Blizzard_AuraContainerGroups.lua` | Ordered groups, maximum counts, filters, sorting, per-group layout | Group policy and selected button lists |
| `Blizzard_AuraContainerSlots.lua` | Single-result placements with independent filters and sorting | Named fixed placements |
| `Blizzard_AuraContainerEnchantments.lua` | Player weapon-enchantment sources and layout | Synthetic item-enchantment entries |
| `Blizzard_AuraContainerSources.lua` | Public, private, enchantment, and edit-mode source adapters | Aura acquisition |
| `Blizzard_AuraContainerFrameProviders.lua` | AuraButton allocation, initialization, reuse, and access restrictions | Button pool and button identity |
| `Blizzard_AuraContainerFlowLayout.lua` | Public flow-option setters and dispatch to the owned FlowLayout object | Layout configuration and dispatch |
| `Blizzard_AuraContainerUtil.lua` | Filtering, sorting, validation, access restrictions, display helpers | Shared secure utilities |
| `Blizzard_AuraButton.lua` / `Blizzard_CustomAuraButton.lua` | Aura identity, tooltip/cancel behavior, descendant display configuration | Per-aura presentation |
| `Blizzard_AuraContainerInbound.lua` | Global tooltip styling bridge | Narrow insecure-to-secure entry point |

## Object Ownership

**FACT:** The container creates and owns AuraButtons through its frame provider. Addons no longer create a frame and attach it with the removed `AddAuraFrame` model.

**FACT:** AuraGroups and AuraSlots hold selection/layout policy, not independent source subscriptions. Sources are container-owned and feed the common managed pipeline.

**FACT:** Display components configured on an AuraButton must be descendants of that button. Once accepted they receive secret/change-parent restrictions and cannot be reparented.

**ANALYSIS:** Ownership is intentionally one-directional: container -> source/group/slot/provider -> AuraButton -> display descendants. This prevents addon code from moving sensitive objects across trust boundaries.

## Creation Lifecycle

1. **FACT:** XML creates an `AuraContainer` with `allowUntaintedCreation="true"`; PTR7 explicitly allows container creation during combat.
2. **FACT:** The custom mixin establishes configuration tables, provider state, and flow-layout defaults.
3. **FACT:** Addon code declares groups, slots, enchantments, processing policy, and an AuraButton initializer.
4. **FACT:** The provider allocates AuraButtons in batches of ten and invokes the initializer through `securecallfunction`.
5. **FACT:** Access restrictions are applied after initialization. Before login completion, application is deferred until `PLAYER_ENTERING_WORLD`, after the documented PLAYER_LOGIN setup window.
6. **FACT:** When enabled and visible, the container registers source events and schedules a full refresh.
7. **FACT:** `OnUpdate` drains dirty work once the frame is visible.

**ANALYSIS:** Initialization is the structural customization window. Runtime APIs remain usable when the button is accessible, but addons should not depend on post-creation reparenting or unrestricted combat-time access.

## Frame Creation Pipeline

**FACT:** The managed pipeline is:

`ParseAuras -> ResetAuraFrames -> RefreshAuraFrames -> RefreshDisplay -> RebuildLayoutGroups -> ApplyLayout`

**FACT:** Full parsing deduplicates identical filter strings. Incremental public aura updates process added, updated, and removed aura instance IDs. Private auras use a separate callback/query path. Enchantments are separate fixed sources.

**FACT:** Groups claim matching buttons in order until their maximum count. Slots select one matching candidate. Item enchantments are injected separately. The provider refreshes native button display after assignment.

**ANALYSIS:** This is a retained, invalidation-driven view engine. Addons configure the query and renderer but should not duplicate its cache or incremental event model unless a required feature cannot be expressed.

## AuraGroups

**FACT:** A group owns a filter string, candidate filters, sort method/direction, maximum button count, and layout options. `GetAuraGroupFrame(groupKey, frameIndex)` exposes provider-owned frames by allocation index; it is not an active-layout enumerator.

**FACT:** Current layout fields include `elementWidth`, `elementHeight`, `elementSpacing`, `lineSpacing`, `groupSpacing`, `groupLineSpacing`, `forceNewLine`, and `layoutIndex`.

**FACT:** Adding a group applies `UntrustedLayoutScriptExecution` to the container. Addon frames anchored to it may need the documented `DisableUntrustedLayoutScriptsTemplate` opt-in at creation.

**ANALYSIS:** Groups are best treated as declarative lanes. They are not independently movable units or per-unit scanners.

## AuraSlots

**FACT:** A slot has its own filter string, candidate filters, sorting, and fixed placement. It selects at most one aura.

**ANALYSIS:** Slots fit prominent single-aura placements. They are not a replacement for multi-row BuffBars groups.

## Enchantment Integration

**FACT:** Main-hand, off-hand, and ranged enchantment sources are player-owned synthetic entries. They bypass aura group parsing and candidate filters, have independent sorting/layout, and can hide permanent entries.

**FACT:** AuraButton cancellation calls `C_PaperDollInfo.CancelTemporaryEnchantment` for an enchantment entry.

**ANALYSIS:** OUS can retire its `GetWeaponEnchantInfo` synthesis if the public enchantment path exposes all required identity, timer, tooltip, and cancellation behavior in Live testing.

## Security Model

**FACT:** AuraButtons prohibit untrusted script execution, untrusted layout scripts, scripted input, always-propagated input, focus queries, parent changes, and removal of secret aspects.

**FACT:** `DenyTaintedAccessWhenAurasAreSecret` is conditional. A button can be accessible outside secret contexts and inaccessible to tainted execution while its aura is secret.

**FACT:** `HasAccessConstraints` describes whether an object has access restrictions; `CanBeAccessedInContext` describes current-context accessibility.

**FACT:** Public `C_UnitAuras` queries carry unit-aura access/secret constraints. PTR notes document restricted addon calls erroring in secret aura contexts.

**ANALYSIS:** Security is contextual rather than a simple secure/insecure split. Code that worked during load or in the open world is not proof that the same object/API is accessible in restricted combat.

## Public Boundary

**FACT:** The custom container exposes base lifecycle, group, slot, enchantment, processing-policy, and flow-layout methods. AuraButton exposes cancellation, tooltip, application bar/count, dispel textures/text, duration cooldown/text/bar, icon, and spell-name configuration.

**FACT:** `AuraContainerInbound` exposes global tooltip styling. Most mixin helpers, caches, comparators, source adapters, dirty flags, and provider internals are implementation details.

**RECOMMENDATION:** Addon designs should depend only on methods visible on the native object or documented inbound APIs. Do not couple to mixin tables, internal cache fields, or provider batch behavior.

## Stabilization Assessment

**OBSERVATION:** Groups, slots, enchantments, and the managed pipeline remained structurally consistent from build 68569 to 68914.

**OBSERVATION:** The same interval added FlowLayout, renamed layout APIs/options, expanded tooltip/dispel/application rendering, changed access timing, enabled combat creation, and tightened child ownership.

**ANALYSIS:** Blizzard appears to have stabilized the core ownership and managed-data model while still restructuring the public presentation/layout surface. The design direction is stable; exact API names and option schemas remain PTR-active.

**RECOMMENDATION:** Freeze architecture decisions now, but freeze implementation bindings only against the 12.1 Live source and in-game behavior.

## Dynamic Layout and Height Management

### Evidence Scope and Labels

**FACT:** This section verifies the `wow-ui-source-ptr` `ptr` branch at commit `d3915c78aba77a7a9be76acbfa35c674bbb6abe9`, build `12.1.0.68914`, interface `120100`, on 2026-07-24. The mirror build is recorded in `version.txt:1`; the local PTR client reports the same executable build. Interface `120100` is the Mainline interface number for 12.1.0 and is also the 12.1 interface accepted by the current OdysseusBuffBars TOC. These findings remain PTR evidence rather than a Live guarantee.

Labels in this section have strict meanings:

- **FACT:** Directly established by the current source or by the already-recorded isolated PTR prototype result.
- **INFERENCE:** A design conclusion derived from source, but not directly guaranteed as an addon contract.
- **RUNTIME TEST REQUIRED:** Source inspection cannot prove the behavior in every taint, secret-aura, combat, or anchor-propagation context.

### Verified Layout Lifecycle

**FACT:** Layout belongs to the container's private managed pipeline, while the position calculation is delegated to a private FlowLayout object:

1. `ManagedAuraContainerPrivateMixin:OnLoad_Intrinsic` installs six ordered dirty phases: parse auras, reset frames, refresh frame assignments, refresh frame display, rebuild layout groups, and apply layout (`Blizzard_ManagedAuraContainer.lua:52-64`).
2. An incremental `UNIT_AURA` update changes group membership and marks `AuraContainerDirtyMask.AuraFrameAssignments` when needed (`ManagedAuraContainerPrivateMixin:ProcessUnitAuraUpdate`, `Blizzard_ManagedAuraContainer.lua:321-380`). Full updates mark `FullAuraRebuild` (`Blizzard_ManagedAuraContainer.lua:322-327`).
3. `DirtyPhaseMixin:MarkDirty` changes the dirty state. `ManagedAuraContainerPrivateMixin:OnDirtyChanged` schedules `Enum.OnUpdateMode.RunWhenVisibleOnce`; the container's `OnUpdate` then calls `ProcessDirtyFlags` (`Blizzard_SharedXML/MixinUtil.lua:397-430`; `Blizzard_ManagedAuraContainer.lua:80-87`).
4. `DirtyPhaseMixin:ProcessDirtyFlags` processes downstream phases in order during the same pass (`Blizzard_SharedXML/MixinUtil.lua:413-430`). A changed frame assignment returns `ApplyLayout` from `ManagedAuraContainerPrivateMixin:ProcessAuraFrameRefreshResult` (`Blizzard_ManagedAuraContainer.lua:528-545`).
5. `CustomAuraContainerPrivateMixin:ApplyLayout` calls `ApplyFlowLayout` (`Blizzard_CustomAuraContainer.lua:648-650`), which invokes the owned layout's `Apply` method (`Blizzard_AuraContainerFlowLayout.lua:90-92`). `AnchorUtil.FlowLayoutMixin:Apply` delegates to `AnchorUtil.ApplyFlowLayout` (`Blizzard_SharedXMLBase/AnchorUtil.lua:602-604`).
6. `AnchorUtil.ApplyFlowLayout` positions every element, calculates consumed width and height, and calls `OnLayoutComplete` after all groups are processed (`Blizzard_SharedXMLBase/AnchorUtil.lua:637-746`). `CustomAuraContainerFlowLayoutMixin:OnLayoutComplete` applies the calculated size to the container with `secretwrap` (`Blizzard_CustomAuraContainer.lua:679-680`).

**FACT:** Aura-driven layout is automatic. Addon code does not need to call a layout function after managed aura changes. The maximum is only a ceiling: `AuraContainerAuraGroupManagerMixin:RefreshAuraGroup` selects `math.min(auras:Size(), maxFrameCount)` frames (`Blizzard_AuraContainerGroups.lua:198-214`).

**FACT:** There can be a deferred interval between the aura event and the next one-shot visible `OnUpdate`, during which the preceding display remains visible. Once dirty processing starts, release, acquisition, showing, assignment commit, positioning, and final sizing occur synchronously in the same ordered pass; the source contains no yield between those phases (`Blizzard_AuraContainerGroups.lua:198-285`; `Blizzard_SharedXML/MixinUtil.lua:413-430`).

### Active Button Tracking

**FACT:** The secure implementation maintains several explicit collections, but none is a supported public active-count API:

- Each `AuraContainerAuraGroupMixin` owns a dense, layout-ordered `framesByIndex` array and a `framesByAura` map keyed by unwrapped aura instance ID (`Blizzard_AuraContainerGroups.lua:332-378`). `framesByIndex` is the current displayed-frame list used by FlowLayout.
- The custom provider owns `ownedFrames`, an `activeFrames` set keyed by frame object, and an `availableFrames` stack (`AuraContainerCustomFrameProviderMixin:Init`, `Blizzard_AuraContainerFrameProviders.lua:24-42`). It exposes `IsFrameActive` internally but does not store an active integer count (`Blizzard_AuraContainerFrameProviders.lua:56-69`).
- The group separately stores accepted aura data in a priority table keyed by aura instance ID (`AuraContainerAuraGroupMixin:RebuildAuras`, `Blizzard_AuraContainerGroups.lua:484-493`). This collection can contain more auras than the displayed maximum.

**FACT:** `CustomAuraContainerSharedMixin:GetAuraGroupFrameCount` returns `frameProvider:GetOwnedFrameCount`, and `GetAuraGroupFrame` returns `GetOwnedFrame(frameIndex)` (`Blizzard_CustomAuraContainer.lua:331-353`). Because custom frames are allocated in batches of ten (`CustomAuraContainerConstants.FrameCreationBatchSize`, `Blizzard_AuraContainerShared.lua:95-103`), these methods expose provider capacity/allocation order, not the number or order of displayed auras.

**FACT:** No inbound CustomAuraContainer method exposes `framesByIndex`, `activeFrames`, `availableFrames`, or an active count. `GetAuraGroupFrame` and `GetAuraGroupFrameCount` are public through the template boundary, but they are not active-button enumeration APIs.

**FACT:** Every custom AuraButton is created with the container as parent and remains container-owned (`AuraContainerCustomFrameProviderMixin:CreateFrame`, `Blizzard_AuraContainerFrameProviders.lua:72-91`). Release clears the aura, hides the button, and pushes it onto `availableFrames`; it does not reparent it or clear its anchor (`Blizzard_AuraContainerFrameProviders.lua:112-125`). `CustomAuraButtonPrivateMixin:ApplyVisibility` also sets shown state from whether aura data exists (`Blizzard_CustomAuraButton.lua:522-524`).

**INFERENCE:** `GetChildren()` should include both active and inactive provider-owned AuraButtons because both remain direct children and the frame API's `GetChildren` entry has no visibility filter (`Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:323-334`). Hidden pooled frames therefore make raw child count unsuitable. This should not be promoted to a contract beyond the current implementation.

**INFERENCE:** Filtering owned frames with `IsShown()` can reflect current assignment in this build because assignment shows the frame and release hides it. It is nevertheless an implementation-dependent fallback, not an officially supported active enumerator. It also couples addon code to provider batching, button accessibility under secret-aura restrictions, and exact visibility implementation.

### Button Recycling

**FACT:** The current group refresh order is explicitly documented and implemented as retain, release, acquire, then commit (`AuraContainerAuraGroupManagerMixin:RefreshAuraGroup`, `Blizzard_AuraContainerGroups.lua:198-205`):

1. Retain frames whose aura-instance assignment remains visible. A dirty retained aura receives `UpdateAuraGroupFrame`, which calls `AuraButton:UpdateAuraInstance` (`Blizzard_AuraContainerGroups.lua:222-246`; `Blizzard_ManagedAuraContainer.lua:161-163`).
2. Release stale assignments before acquiring replacements (`Blizzard_AuraContainerGroups.lua:264-268`). The custom provider removes the active marker, calls `ClearAuraInstance`, hides the frame, and returns it to `availableFrames` (`Blizzard_AuraContainerFrameProviders.lua:112-125`).
3. Acquire frames for missing assignments, preferring available frames and allocating another batch only when necessary (`Blizzard_AuraContainerFrameProviders.lua:93-109`; `Blizzard_AuraContainerGroups.lua:270-280`).
4. Initialize the new aura state and show the frame through `ManagedAuraContainerPrivateMixin:InitializeAuraGroupFrame` (`Blizzard_ManagedAuraContainer.lua:156-159`).
5. Commit the dense `framesByIndex` and aura-instance map, then return a refresh result that drives layout (`Blizzard_AuraContainerGroups.lua:283-285`).
6. Apply FlowLayout and resize the container later in the same dirty pass (`Blizzard_ManagedAuraContainer.lua:533-560`).

**FACT:** New custom buttons receive a display update with no aura immediately after initialization (`AuraContainerCustomFrameProviderMixin:CreateFrame`, `Blizzard_AuraContainerFrameProviders.lua:72-90`); `ApplyVisibility` hides the no-aura button (`Blizzard_CustomAuraButton.lua:522-539`). Inactive preallocated and recycled buttons therefore do not enter the layout element list.

### Layout Completion Hooks

**FACT:** `CustomAuraContainerTemplate` exposes no post-layout callback, callback-registry event, `OnLayout` event, active-count notification, or layout-completion registration method. Its private `CustomAuraContainerFlowLayoutMixin:OnLayoutComplete(container, width, height, hasPlacedElement, lineCount)` only sets the container size (`Blizzard_CustomAuraContainer.lua:667-680`).

**FACT:** Adding an aura group applies `Enum.ForbiddenAspect.UntrustedLayoutScriptExecution` to the custom container specifically because groups resize it. Blizzard's source comment states that this disables `OnSizeChanged` and affects frames anchored to the container (`CustomAuraContainerSharedMixin:AddAuraGroup`, `Blizzard_CustomAuraContainer.lua:283-323`). The generated aspect documentation says the restriction covers layout scripts such as `OnSizeChanged` and propagates to children and anchored objects (`Blizzard_APIDocumentationGenerated/ForbiddenAspectConstantsDocumentation.lua:13-23`).

**FACT:** TargetFrame has a separate, consumer-specific callback that CustomAuraContainer does not inherit. `TargetFrameAuraContainerSharedMixin:SetAuraContainerAnchorsChangedCallback` stores one function (`Blizzard_UnitFrame/Shared/TargetFrameAuraContainer.lua:210-218`); `TargetFrameAuraContainerPrivateMixin:ApplyLayout` runs FlowLayout and then invokes it with no arguments through `securecall` (`Blizzard_UnitFrame/Shared/TargetFrameAuraContainer.lua:331-355`). TargetFrame registers this callback during its own initialization (`Blizzard_UnitFrame/Mainline/TargetFrame.lua:64-67`). It is not a general managed-container callback and is unavailable on `CustomAuraContainerTemplate`.

**FACT:** The private `ApplyLayout`, `ApplyFlowLayout`, `MarkDirty`, internal FlowLayout `OnLayoutComplete`, and private mixin methods are not part of `CustomAuraContainerInboundMixin`. Hooking or overriding them would cross the intended secure/private boundary (`Blizzard_CustomAuraContainer.lua:512-513`, `648-680`; `Blizzard_ManagedAuraContainer.lua:49-64`).

### Container and Host Sizing

**FACT:** CustomAuraContainer computes and sets its own size. It does not call `ResizeToBoundsRect`. No `ResizeToBoundsRect()` call exists anywhere in the examined PTR Interface source; the generated frame API marks that general method as protected (`Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua:1112-1119`).

**FACT:** Custom FlowLayout input consists of closures returning each group's dense `framesByIndex` list and, when configured, the active item-enchantment frame list (`CustomAuraContainerPrivateMixin:GetFlowLayoutGroupDescriptions`, `Blizzard_CustomAuraContainer.lua:557-590`). Empty groups contribute no spacing or forced line (`AnchorUtil.lua:612-636`). The algorithm uses only those elements to calculate bounds, excludes trailing element spacing, includes configured padding, and clamps both final dimensions to at least one pixel (`Blizzard_SharedXMLBase/AnchorUtil.lua:684-746`). Hidden pooled buttons are absent from these lists and do not affect container bounds.

**FACT:** For the current OBB Phase B vertical single-group configuration, with 16-pixel elements, 2-pixel element spacing, no FlowLayout padding, and no wrapping, the managed container's source-derived height is `1` when no element is displayed and `N * 16 + (N - 1) * 2` for `N > 0`. `N` is selected internally and capped at 30; addon code does not need to know it (`AnchorUtil.lua:708-746`; `OdysseusBuffBars_ManagedPrototype.lua:23-28`, `110-123`).

**FACT:** The container resizes only itself. It does not call `SetSize` or `SetHeight` on its parent. The present prototype's ordinary host remains static because it sets a maximum-derived host size and gives the container only a top-left anchor (`OdysseusBuffBars_ManagedPrototype.lua:83-107`).

**FACT:** Blizzard provides `DisableUntrustedLayoutScriptsTemplate` specifically so addon-created frames can opt into `UntrustedLayoutScriptExecution` at creation when they need to anchor to restricted layout objects (`Blizzard_SharedXMLBase/ForbiddenAspectTemplates.xml:4-22`). The CustomAuraContainer source points addons to that template for frames anchored to a self-resizing custom container (`Blizzard_CustomAuraContainer.lua:314-321`).

**INFERENCE:** The intended addon-facing way to consume secret-dependent container geometry is declarative anchor propagation through an opt-in frame, not reading a visible count or executing an insecure resize callback. The safest Phase B.2 topology is an independent position root, a self-sizing CustomAuraContainer anchored to that root, and—only if chrome/background must follow the stack—a separate frame created with `DisableUntrustedLayoutScriptsTemplate` and anchored between the independent root and the container's far edge. The container must not be anchored back to that size-following frame, which avoids an anchor dependency loop.

**RUNTIME TEST REQUIRED:** Verify the exact root/container/chrome anchor topology on PTR. Source comments establish the supported opt-in mechanism, but source inspection alone cannot prove that every proposed multi-anchor relationship remains accessible and taint-free during secret-aura combat updates.

### Combat Safety

**FACT:** Managed aura refresh and layout contain no `InCombatLockdown` or combat deferral branch. Visible enabled containers receive aura events, schedule their secure one-shot `OnUpdate`, release/acquire/show/hide managed buttons, reposition them, and set the secret-wrapped container size through the normal dirty pipeline (`Blizzard_AuraContainer.lua:157-178`; `Blizzard_ManagedAuraContainer.lua:80-103`, `321-380`, `516-560`; `Blizzard_CustomAuraContainer.lua:674-680`). This matches the project's already-observed combat-safe managed updates.

**FACT:** `AuraButton` itself forbids untrusted script execution and untrusted layout scripts, among other aspects (`Blizzard_AuraContainer/Blizzard_AuraButton.xml:16-24`). Adding a custom aura group adds the untrusted-layout-script restriction to the container (`Blizzard_CustomAuraContainer.lua:314-323`). These restrictions explain why addon callbacks and ad hoc re-anchoring are not equivalent to Blizzard's secure internal layout.

**FACT:** The generated resizing API marks `SetHeight`, `SetPoint`, and `SetSize` as protected functions with taint/secret constraints (`Blizzard_APIDocumentationGenerated/SimpleScriptRegionResizingAPIDocumentation.lua:123-178`). The source does not provide a general statement that an addon callback may call `SetHeight` on an ordinary host after managed layout in combat.

**INFERENCE:** A long-lived ordinary, non-secure position root is less risky than resizing or reconfiguring a protected/secure unit frame. However, that general WoW behavior is not enough to label a custom post-layout `SetHeight` path supported here, especially because CustomAuraContainer deliberately suppresses untrusted `OnSizeChanged` execution.

**RUNTIME TEST REQUIRED:** Confirm that the opt-in anchor-following chrome changes height during combat without blocked actions, taint, or inaccessible-object errors. Also query `IsProtected`/`CanChangeProtectedState` during the isolated test if useful; do not infer protection state solely from the word "protected" in generated API metadata.

### Blizzard Usage Examples

| Consumer | Layout and sizing | Parent/host behavior | Callback and Edit Mode behavior |
| --- | --- | --- | --- |
| `TargetFrameAuraContainerTemplate` | The only substantive Blizzard ManagedAuraContainer consumer found outside the framework. It owns Buff and Debuff groups, flows horizontally, wraps at configured line widths, forces the second non-empty group onto a new line, and self-sizes from displayed frames (`Blizzard_UnitFrame/Shared/TargetFrameAuraContainer.lua:227-255`, `290-329`, `427-458`). | The surrounding `TargetFrameTemplate` is a fixed 232 by 100 frame (`Blizzard_UnitFrame/Mainline/TargetFrame.xml:53-59`). The aura container changes its own size; the parent is not resized. | A TargetFrame-only no-argument callback reanchors the container and spell bar after layout (`TargetFrameAuraContainer.lua:331-355`; `Blizzard_UnitFrame/Mainline/TargetFrame.lua:530-590`). Managed containers can switch to the framework's edit-mode aura source on `AURA_DATA_PROVIDER_SWITCH`, but no CustomAuraContainer/Edit Mode parent-sizing example was found (`Blizzard_ManagedAuraContainer.lua:106-145`). |
| `CustomAuraContainerTemplate` | Public template and framework implementation; no Blizzard UI consumer of the template was found in the current mirror outside its definition. | Its generic FlowLayout always sizes the container itself (`Blizzard_CustomAuraContainer.lua:648-680`). | No generic post-layout callback. No Blizzard example demonstrates resizing an addon-owned parent host. |
| BuffFrame's `AuraContainerTemplate` | Older unrelated ordinary `Frame` with `AuraContainerMixin`, grid layout, and pre-created aura buttons (`Blizzard_BuffFrame/BuffFrameTemplates.xml:64-86`, `119-123`; `Blizzard_BuffFrame/BuffFrame.lua:43-86`, `172-178`). | BuffFrame/Edit Mode computes traditional icon-grid size and anchors separately. | This is a name collision, not the new intrinsic `AuraContainer`, and is not evidence for ManagedAuraContainer extension points. |
| Secure group-header creation support | `SecureGroupHeaders.lua` can create an `AuraContainer` from a header-supplied template (`Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua:110-115`). | No current source sets the `auraContainerTemplate` attribute, so no concrete managed layout or parent-sizing consumer was found. | Creation support only; not a post-layout example. |

**FACT:** No current Blizzard consumer resembles a vertically stacked custom bar list closely enough to copy wholesale. TargetFrame is the architectural precedent for self-sizing from the managed displayed-frame lists, but its specialized callback is not reusable by OBB.

### Supported Extension Points

| Capability | Classification | Evidence and limit |
| --- | --- | --- |
| `SetUnit`, `SetEnabled`, `AddAuraGroup` | Public through template/mixin usage | Exposed by inbound/shared mixins on `CustomAuraContainerTemplate`; the TOC deliberately loads templates globally for external creation (`Blizzard_AuraContainer.toc:8-13`; `Blizzard_AuraContainer.lua:22-54`; `Blizzard_CustomAuraContainer.lua:281-324`). Not listed as generated API functions. |
| Flow layout axis, anchor, growth, padding, maximum line size | Public through template/mixin usage | Inbound `AuraContainerFlowLayoutSharedMixin` setters mark layout dirty (`Blizzard_AuraContainerFlowLayout.lua:1-74`). |
| Per-group layout options | Public through template/mixin usage | `AddAuraGroup(..., options.layout)` and `SetAuraGroupLayout` validate layout fields and mark layout groups dirty (`Blizzard_CustomAuraContainer.lua:140-178`, `283-323`, `392-398`). |
| `GetAuraGroupFrame` / `GetAuraGroupFrameCount` | Public through template/mixin usage, capacity only | Returns provider-owned frames/count, not active layout state (`Blizzard_CustomAuraContainer.lua:331-353`). |
| Active `framesByIndex`, `framesByAura`, provider `activeFrames` | Internal implementation detail | Private group/provider collections; no inbound accessor (`Blizzard_AuraContainerGroups.lua:359-378`; `Blizzard_AuraContainerFrameProviders.lua:24-69`). |
| `MarkDirty`, `ProcessDirtyFlags`, `ApplyLayout`, `ApplyFlowLayout` | Internal implementation detail; not suitable for addon use | Private managed and FlowLayout mixins own scheduling and execution (`Blizzard_ManagedAuraContainer.lua:49-87`, `516-587`; `Blizzard_AuraContainerFlowLayout.lua:73-92`). |
| Custom post-layout handling | Not suitable for addon use | No CustomAuraContainer callback. `OnSizeChanged` is deliberately suppressed by a forbidden aspect; private `OnLayoutComplete` is not an inbound override point (`Blizzard_CustomAuraContainer.lua:314-323`, `667-680`). |
| Container size calculation | Internal implementation with externally observable anchor geometry | FlowLayout calculates bounds and the private completion method sets the container's native size. Addons should consume that geometry through compatible anchors, not read internal element lists (`AnchorUtil.lua:637-746`; `Blizzard_CustomAuraContainer.lua:679-680`). |
| `ResizeToBoundsRect` | Public/documented general frame API, but not suitable for AuraContainer sizing | It is protected, has no AuraContainer call site, and would operate independently of the verified managed FlowLayout path (`SimpleFrameAPIDocumentation.lua:1112-1119`). |
| `DisableUntrustedLayoutScriptsTemplate` | Public through template usage | Explicitly exposed for addon frames that must opt into restricted anchor propagation at creation (`ForbiddenAspectTemplates.xml:4-22`; `Blizzard_CustomAuraContainer.lua:314-321`). |

### Recommended OBB Phase B.2 Approach

**RECOMMENDATION:** Use the CustomAuraContainer's verified native FlowLayout size as the dynamic visible height. Do not calculate or copy the active aura count.

For the isolated Phase B.2 prototype:

1. Keep one long-lived ordinary position root responsible for saved location and the draggable/header surface. Its placement must remain independent of the restricted container's size.
2. Keep the `CustomAuraContainer` anchored below the header/root and retain the existing vertical flow, 250 by 16 element size, 2-pixel spacing, and maximum of 30. FlowLayout will set its height from zero through thirty displayed managed buttons; 30 remains a selection ceiling, not an allocated or visible height.
3. Remove the maximum-derived stack height from the visible presentation. Treat the resulting container height as framework-owned geometry to propagate through compatible anchors, not as a value to read or recompute from aura state.
4. If the prototype needs a background/border that encloses both header and active stack, use a separate size-following chrome frame created with `DisableUntrustedLayoutScriptsTemplate`. Anchor its near edge to the independent root and its far edge to the self-sized container. Do not parent/reanchor managed AuraButtons, do not anchor the container back to this chrome frame, and do not attach `OnSizeChanged` logic to the restricted anchor chain.
5. Let the managed event/dirty pipeline update layout in and out of combat. Do not call private layout or dirty methods manually.
6. PTR-test add/remove transitions, zero auras, one aura, more than ten, the thirty-button ceiling, combat updates, host/chrome bounds, root dragging, reload position, taint, and blocked-action logs before any production migration.

**FACT:** This approach satisfies the data constraints because it consumes only managed geometry. It performs no direct aura read, maintains no aura cache, adds no countdown or polling `OnUpdate`, creates no mirrored bars, and does not reparent buttons.

**INFERENCE:** The anchor-following chrome is the closest available generic equivalent to Blizzard's intent. The source explicitly provides the opt-in template for objects anchored to the self-resizing container, while exposing no count or callback alternative.

**RUNTIME TEST REQUIRED:** Phase B.2 should first prove the size-following anchor chain on the isolated prototype. If that test fails because the ordinary chrome cannot legally inherit the layout aspect or update during combat, stop and record the blocked result; do not fall back silently to scanning or polling.

### Rejected Approaches

1. **Generic post-layout callback plus active count — rejected.** CustomAuraContainer has no callback, and the TargetFrame callback is consumer-specific. No supported active count exists.
2. **Internal active collection/count — rejected.** `framesByIndex` and provider `activeFrames` are secure implementation details. `GetAuraGroupFrameCount` is owned capacity, not active count.
3. **`ResizeToBoundsRect` — rejected.** The managed implementation never uses it; FlowLayout already computes exact displayed bounds and sets the container size. The general helper is protected and adds no supported notification path.
4. **Enumerate children or owned frames and count `IsShown()` — rejected.** Hidden pooled children remain owned, allocation occurs in batches, active enumeration is not an API contract, and secret-aura access may make frame inspection context-sensitive.
5. **Hook or override layout completion — rejected.** The completion method belongs to a private secure FlowLayout mixin, CustomAuraContainer offers no hook, and untrusted layout scripts are explicitly disabled.
6. **Poll visibility or container height with addon `OnUpdate` — rejected.** Native FlowLayout is already event-driven and self-sizing. Polling would add latency and dependency on restricted state without gaining supported information.
7. **Recalculate from `UNIT_AURA` or direct aura scans — rejected.** This duplicates Blizzard's managed cache, conflicts with secret-aura restrictions, and violates the prototype's no-direct-access design.
8. **Call `ApplyLayout` or `MarkDirty` manually — rejected.** Both are private pipeline mechanisms; aura changes and public layout setters already schedule the correct pass.
9. **Set an ordinary host's height from a custom `OnSizeChanged` — rejected.** Adding a group deliberately disables untrusted layout scripts on the container and anchored chain. No source-backed callback makes this a supported combat path.

### Open Questions

1. **RUNTIME TEST REQUIRED:** Does a chrome frame created with `DisableUntrustedLayoutScriptsTemplate` and anchored to the CustomAuraContainer follow secret-dependent height changes in combat without taint or blocked actions?
2. **RUNTIME TEST REQUIRED:** Which exact non-circular root/container/chrome anchors preserve the existing draggable header and saved position while allowing the visual bounds to collapse to the container's one-pixel empty minimum?
3. **RUNTIME TEST REQUIRED:** Are the opt-in chrome and independent position root reported as protected or unable to change protected state in any tested combat context?
4. **RUNTIME TEST REQUIRED:** Does an empty helpful group need an OBB presentation minimum beyond the container's verified one-pixel FlowLayout minimum, and should only the header remain visible in that state?
5. **RUNTIME TEST REQUIRED:** Do add/remove/reuse transitions update the chrome in the same rendered frame as the secure layout pass across open-world, dungeon, and raid combat?
6. **OBSERVATION:** No generic CustomAuraContainer post-layout callback or active enumerator exists in build 68914. Re-audit these exact extension points against the final 12.1 Live source before freezing implementation bindings.

## Retail Files Inspected

- `Blizzard_AuraButton.lua` / `.xml`
- `Blizzard_AuraContainer.lua` / `.xml` / `.toc`
- `Blizzard_AuraContainerEnchantments.lua`
- `Blizzard_AuraContainerFlowLayout.lua`
- `Blizzard_AuraContainerFrameProviders.lua`
- `Blizzard_AuraContainerGroups.lua`
- `Blizzard_AuraContainerInbound.lua`
- `Blizzard_AuraContainerShared.lua`
- `Blizzard_AuraContainerSlots.lua`
- `Blizzard_AuraContainerSources.lua`
- `Blizzard_AuraContainerUtil.lua`
- `Blizzard_CustomAuraButton.lua` / `.xml`
- `Blizzard_CustomAuraContainer.lua` / `.xml`
- `Blizzard_ManagedAuraContainer.lua`
- `Blizzard_SharedXML/MixinUtil.lua`
- `Blizzard_SharedXMLBase/AnchorUtil.lua`
- `Blizzard_SharedXMLBase/ForbiddenAspectTemplates.xml`
- `Blizzard_UnitFrame/Shared/TargetFrameAuraContainer.lua` / `.xml`
- `Blizzard_UnitFrame/Mainline/TargetFrame.lua` / `.xml`
- `Blizzard_BuffFrame/BuffFrame.lua` / `BuffFrameTemplates.xml`
- `Blizzard_RestrictedAddOnEnvironment/SecureGroupHeaders.lua`
- Generated `AuraContainerShared`, `AuraContainerUtil`, `ForbiddenAspect`, `SimpleFrame`, and `SimpleScriptRegionResizing` API documentation

Supplementary Retail files included generated API documentation, `AuraUtil.lua`, `TargetFrame.lua`, `BuffFrame.lua`, `SecureAuraHeader` load metadata, tooltip templates, and the ManagedFrameSystem implementation. Classic implementation files were not part of the primary inspected list.

## Related Documents

- [AuraContainers](AuraContainers.md)
- [API Changes](APIChanges.md)
- [Combat and Security Restrictions](CombatAndSecurityRestrictions.md)
- [Blizzard Implementation Notes](BlizzardImplementationNotes.md)
