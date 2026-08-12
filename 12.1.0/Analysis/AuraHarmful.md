# Managed Player HARMFUL Auras

## 1. Scope and Verified Build

This document defines the Retail 12.1 managed AuraContainer contract for an isolated OdysseusBuffBars DEBUFFS prototype:

```text
unit = "player"
aura kind = HARMFUL
```

The Live mirror was verified before this trace:

- Retail build: `12.1.0.69273`
- Mainline interface: `120100`
- Live source revision: `eb941aad028d73ddc69e3e8ef4da709f4d3cd744`
- Completed Live audit: `a07fb6de71e915416fe379af9e92565ef7e1df9b`

`version.txt` and `git rev-parse HEAD` in the Live mirror confirm the build and revision. Interface `120100` remains the verified Live-audit value and is also present in the active OBB manifest. This research uses Live source as authoritative; PTR history remains unchanged.

**CONCLUSION:** A broad managed player-HARMFUL container is supported and can use the validated BUFFS ownership, presentation, sorting, and self-sizing architecture. General spell-ID whitelist/blacklist parity is not supported for player HARMFUL auras.

## 2. Managed HARMFUL Architecture

### Supported custom-container contract

The minimal declaration is the BUFFS structure with the group filter changed to `HARMFUL`:

```text
ordinary OBB position root
└─ AuraContainer created from CustomAuraContainerTemplate
   └─ one aura group: key chosen by OBB, filterString = "HARMFUL"
      └─ container-created CustomAuraButtonTemplate frames
```

Required configuration:

| Area | Contract |
| --- | --- |
| Frame creation | `CreateFrame("AuraContainer", ..., root, "CustomAuraContainerTemplate")` |
| Unit | `SetUnit("player")` |
| Aura source | Do not supply one. The managed container internally selects its public-plus-private source list. |
| Group | `AddAuraGroup(groupKey, "HARMFUL", options)` |
| Candidate filters | `nil` or no identity maps for the first prototype |
| Sort | `AuraContainerSortMethod` plus `AuraContainerSortDirection` in group options |
| Button creation | `initializeFrame` configures container-created `CustomAuraButtonTemplate` descendants |
| Presentation | Bind descendant regions with `SetIcon`, `SetSpellName`, `SetApplicationCount`, `SetDurationText`, and `SetDurationBar` |
| Group layout | `layout.elementWidth`, `elementHeight`, `elementSpacing`, and related group layout options |
| Container layout | `SetFlowLayoutAxis`, `SetFlowLayoutAnchorPoint`, `SetFlowLayoutGrowthDirection`, `SetFlowLayoutPadding`, and `SetFlowLayoutMaximumLineSize` |
| Lifecycle | Configure while disabled, then show and `SetEnabled(true)` after setup |

`CustomAuraContainerSharedMixin:AddAuraGroup` validates the filter/options, creates a custom frame provider, preallocates a batch, registers the group, applies untrusted-layout restrictions, and triggers a refresh (`Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua:283-324`). The provider always prepends `CustomAuraButtonTemplate`, creates `AuraButton` frames under the container, and invokes the addon initializer before access restrictions are applied (`Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua:24-94`). Unit and enabled state are supported shared methods (`Blizzard_AuraContainer/Blizzard_AuraContainer.lua:24-46`). Flow-layout setters are exposed by `AuraContainerFlowLayoutSharedMixin` (`Blizzard_AuraContainer/Blizzard_AuraContainerFlowLayout.lua:7-66`).

### Public, supported-template, and private boundaries

- **Documented public API:** generated `C_AuraContainerUtil` option processors and the generated `Enum.CustomAuraButton*` option enums/structures. These validate presentation option tables; for example, dispel text/texture and application-bar schemas are in `Blizzard_APIDocumentationGenerated/AuraContainerUtilDocumentation.lua:56-143,226-284` and presentation enums are in `Blizzard_APIDocumentationGenerated/AuraContainerSharedDocumentation.lua:6-30`.
- **Supported template/mixin surface:** `CustomAuraContainerTemplate`, its inbound public partition, `CustomAuraButtonTemplate`, and inbound methods such as `AddAuraGroup`, `SetUnit`, flow-layout setters, and the presentation setters. The XML explicitly exposes secure delegates into the public partition (`Blizzard_AuraContainer/Blizzard_CustomAuraContainer.xml:4-15`; `Blizzard_AuraContainer/Blizzard_CustomAuraButton.xml:4-15`).
- **Blizzard internal/private implementation:** `ManagedAuraContainerPrivateMixin`, source providers, group managers, secure caches, priority tables, frame assignment, and layout dirty phases. Addon code must not call or inspect those internals.

**CONCLUSION:** The first HARMFUL prototype should be a second isolated managed frame, not a second group inserted into the validated BUFFS prototype. Isolation tests the DEBUFFS security behavior without coupling two research slices.

## 3. Secret, NeverSecret, and Private Classification

### Two independent axes

Retail 12.1 has two related but distinct classifications:

1. **Public aura data secrecy.** A public aura may yield readable or secret values depending on its base secrecy and current restriction context. `Enum.SecrecyLevel` defines `NeverSecret`, `AlwaysSecret`, and `ContextuallySecret` (`Blizzard_APIDocumentationGenerated/SecretWrapperConstantsDocumentation.lua:6-16`). `C_Secrets.GetSpellAuraSecrecy` returns the spell's *base* aura secrecy (`Blizzard_APIDocumentationGenerated/SecretPredicateAPIDocumentation.lua:45-58`). Public instance lookup is marked `SecretWhenUnitAuraRestricted` (`Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua:170-184`).
2. **Private aura source.** Private auras are discovered through a separate `C_UnitAurasPrivate` provider and marked `auraData.isPrivate = true`; this is not another `SecrecyLevel` (`Blizzard_AuraContainer/Blizzard_AuraContainerSources.lua:21-24,40-61`).

“Ordinary/readable” is therefore not a permanent enum value. It means a public aura whose returned field is accessible in the current context. Addon code may test a value with the platform's secret-value access predicates, but it must not infer future accessibility or assume that the managed framework's internal use makes the value public.

### Pipeline order

The managed pipeline is:

```text
public/private candidate discovery
→ source metadata (`auraType`, `isPrivate`)
→ filter-string eligibility (`HARMFUL`)
→ candidate filters
   → spell-ID identity eligibility gate
   → remaining non-identity filters
→ group priority table / sorting
→ retained, released, or acquired AuraButton assignment
→ managed presentation and tooltip
→ FlowLayout and container size
```

Evidence:

- The public provider enumerates `C_UnitAuras.GetUnitAuraInstanceIDs`; the private provider enumerates `C_UnitAurasPrivate.GetAllPrivateAuraInstanceIDs` and defers filter-string evaluation (`Blizzard_AuraContainer/Blizzard_AuraContainerSources.lua:27-61`).
- Full parses iterate every selected source and deduplicated filter, fetch/prepare aura data, then send it to each registered group/slot (`Blizzard_AuraContainer/Blizzard_ManagedAuraContainer.lua:502-528`).
- Group membership applies the filter string before candidate filters (`Blizzard_AuraContainer/Blizzard_AuraContainerGroups.lua:503-516`). Public filter strings use `C_UnitAuras.IsAuraFilteredOutByInstanceID`; private ones use the corresponding private API (`Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:3-9`).
- Accepted auras enter the secure associative priority table and can move priority on update (`Blizzard_AuraContainer/Blizzard_AuraContainerGroups.lua:143-161,484-493`).
- Managed assignment retains existing frames, releases stale frames, acquires missing frames, and commits a dense active list (`Blizzard_AuraContainer/Blizzard_AuraContainerGroups.lua:198-285`).

### Identity-filter eligibility

`CanApplyIdentityCandidateFilters` is the decisive predicate:

1. If `auraData.spellId` exists and its base aura secrecy is `NeverSecret`, return true.
2. Otherwise, if the aura is HARMFUL and the unit is assistable by the player, return false.
3. Otherwise, apply the corresponding HELPFUL/non-assistable restriction or return true.

This is explicit in `Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:11-36`. For `unit="player"`, `UnitCanAssist("player", "player")` is true, so a HARMFUL aura is identity-filterable only through the `NeverSecret` exception.

**IMPORTANT:** The predicate does not test combat, current secret-value accessibility, or whether an aura is presently returning secret fields. It tests base spell secrecy, aura kind, and unit reaction. A ContextuallySecret player debuff that is readable out of combat still skips spell-ID maps. The same aura does not become filterable or non-filterable merely because combat/restriction state changes; its presentation values may transition, but this identity gate does not.

## 4. Filtering Behavior

### Exact include/exclude control flow

`DoesAuraPassCandidateFilters` returns true immediately when there are no candidate filters. When filters exist, it evaluates `excludeSpellIDs` and then `includeSpellIDs` only inside the identity-eligible branch. If the branch is skipped, execution continues to other candidate filters and ultimately returns true when none of them reject the aura (`Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:38-116`).

For the identity maps themselves:

| Player HARMFUL category | `includeSpellIDs` | `excludeSpellIDs` | Result when identity stage is skipped |
| --- | --- | --- | --- |
| Public `ContextuallySecret` aura, currently readable | Not evaluated | Not evaluated | Accepted by the identity stage |
| Public `ContextuallySecret` aura, currently secret | Not evaluated | Not evaluated | Accepted by the identity stage |
| Public `AlwaysSecret` aura | Not evaluated | Not evaluated | Accepted by the identity stage |
| Public or private `NeverSecret` aura with a spell ID | Evaluated | Evaluated | Not skipped; normal map results apply |
| Private HARMFUL aura not qualifying as `NeverSecret` | Not evaluated | Not evaluated | Accepted by the identity stage |

For a `NeverSecret` aura:

- A listed exclusion rejects it.
- If an include map exists, an ID absent from it is rejected.
- Exclusion runs before inclusion, so if both maps are supplied and both contain the ID, exclusion wins.

For a non-`NeverSecret` player HARMFUL aura:

- Whitelist mode leaks through unmatched auras because the include map is never consulted.
- Blacklist mode cannot suppress the aura because the exclude map is never consulted.
- The aura may still be rejected by the `HARMFUL` filter string or by another configured non-identity candidate filter.

The custom-surface comment says spell-ID matching is permitted for helpful auras on assistable units and harmful auras on non-assistable units (`Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua:79-90`). The later implementation adds the explicit `NeverSecret` exception. This exception is intended to permit filtering noisy friendly-unit debuffs such as Exhaustion/Sated (`Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:12-24`).

**CONCLUSION:** Do not compile the legacy DEBUFFS whitelist or blacklist into the first broad managed HARMFUL group. The controls would claim a scope the managed identity policy intentionally denies.

## 5. Legacy OBB Compatibility

### Existing semantics

The active OBB defaults DEBUFFS to `unit="player"`, `filter="HARMFUL"`, with `filters.whitelist` and `filters.blacklist` maps (`OdysseusBuffBars.lua:48-70`). The same SavedVariables shape is used by BUFFS, DEBUFFS, and ENCHANTMENTS, and initialization preserves both maps (`OdysseusBuffBars.lua:20-107,222-226`).

Legacy evaluation is spell-ID-first:

- If the whitelist contains any enabled numeric ID, it exclusively decides the result.
- Only when the whitelist is empty does the blacklist reject listed IDs.
- Therefore whitelist wins when an ID appears in both maps.
- An unreadable/non-numeric spell ID currently passes the legacy filter.

See `OdysseusBuffBars_Auras.lua:131-162`. Discovery reads `GetAuraDataByIndex`, builds readable/cached rows, calls `RememberFilterAura` before the list filter, and then applies the whitelist/blacklist (`OdysseusBuffBars_Auras.lua:368-435`). The row cache requires a readable numeric spell ID and only stores a readable name when available (`OdysseusBuffBars_Auras.lua:164-185`). The editor also merges cached, current, and saved numeric-ID rows (`OdysseusBuffBars_Config.lua:288-337`).

### Compatibility matrix

| Legacy feature | Managed HARMFUL equivalent | Parity | Reason |
| --- | --- | --- | --- |
| Broad `player` / `HARMFUL` acquisition | One managed `HARMFUL` group on `unit="player"` | Exact | Same unit/kind policy; managed sources own acquisition. |
| Numeric-ID storage | Retain `filters.whitelist` / `filters.blacklist` maps | Exact storage only | Saved values remain valid data even when runtime filtering cannot apply them. |
| Non-empty whitelist is exclusive | `includeSpellIDs` | Partial | Exact only for `NeverSecret` HARMFUL spells; other player debuffs skip the map and leak through. |
| Blacklist hides listed IDs | `excludeSpellIDs` | Partial | Exact only for `NeverSecret` HARMFUL spells; other player debuffs skip the map. |
| Whitelist wins over blacklist | Compile only include when whitelist is non-empty | Exact for eligible IDs | Managed exclusion otherwise runs first; omitting blacklist preserves legacy precedence, as with BUFFS. |
| Current/previous aura discovery rows | No managed active-identity enumerator | Unavailable generally | Managed buttons are deliberately not an addon-readable aura database; restricted direct enumeration is not a safe substitute. |
| Manual saved-ID rows | Existing SavedVariables/editor rows | Exact storage/UI | Does not require a currently readable aura identity. |
| Readable name/icon history | No managed discovery feed | Partial/unavailable | Existing cached readable data can remain, but managed HARMFUL does not provide a supported history stream. |

## 6. Private Harmful Auras

`ManagedAuraContainerPrivateMixin:ShouldIncludePrivateAuraSource` returns true. Real-data containers therefore select `AuraContainerAuraSourceLists.PublicAndPrivate` and register private-aura updates whenever they have groups or slots (`Blizzard_AuraContainer/Blizzard_ManagedAuraContainer.lua:120-158`). The source list contains both providers (`Blizzard_AuraContainer/Blizzard_AuraContainerSources.lua:85-100`).

Consequences for a broad custom `HARMFUL` group:

- Private HARMFUL auras automatically participate; the addon does not add another source, group, slot, or anchor.
- The private provider gets instance IDs and aura data through `C_UnitAurasPrivate`, marks the data private, and uses the private filter-string predicate (`Blizzard_AuraContainer/Blizzard_AuraContainerSources.lua:40-61`; `Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:3-8`).
- The same group priority table, comparator, frame provider, AuraButton assignment, and FlowLayout are used. A custom container does not create a distinct private-aura button template.
- The same presentation bindings run, but the framework supplies whatever restricted/private values it is allowed to render. Source inspection does not prove the exact name/icon/count/duration visible for every private aura.
- The same identity eligibility function runs. A private player HARMFUL aura with an internally available `NeverSecret` spell ID can take the identity-map branch; otherwise the identity maps are skipped.
- Native tooltip code detects `auraData.isPrivate` and routes to the private tooltip accessor.

TargetFrame is a concrete managed consumer: it registers a debuff group and explicitly accepts private harmful auras (`Blizzard_UnitFrame/Shared/TargetFrameAuraContainer.lua:240-250,378-410`). BuffFrame and CompactUnitFrame still demonstrate the older/separate `AddPrivateAuraAnchor` model (`Blizzard_BuffFrame/BuffFrame.lua:1246-1261`; `Blizzard_UnitFrame/Shared/CompactUnitFrame.lua:2287-2332`). Those consumers do not override the custom-container behavior.

**DETECTION BOUNDARY:** The custom API exposes provider-capacity frames, not a supported active-aura identity list. Private source state and managed caches are internal. Addon Lua should not attempt to detect “a private aura is present” through private collections, button data, or frame-count inference. Visual container growth is not identity access.

**RUNTIME REQUIRED:** Verify that an actual player private HARMFUL aura enters the broad group and that its presentation, ordering, tooltip, addition/removal, and restricted-combat transitions behave as expected.

## 7. Presentation

The five BUFFS bindings are directly usable for HARMFUL AuraButtons:

| Binding | Classification | Evidence |
| --- | --- | --- |
| `SetIcon` | Directly usable | Registers a descendant texture; secure update applies aura icon/fallback (`Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua:219-230,551-556`; helper at `Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:213-229`). |
| `SetSpellName` | Directly usable | Registers a secret-aspected FontString; secure update applies name/empty fallback (`Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua:263-280,559-564`; helper at `Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:231-253`). |
| `SetApplicationCount` | Directly usable | Registers secret text/shown aspects and managed count formatting (`Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua:55-73,351-369`). |
| `SetDurationText` | Directly usable | Builds a duration binding with secret text/color/alpha aspects (`Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua:154-198,524-529`). |
| `SetDurationBar` | Directly usable | Registers a secret bar value and managed timer direction/interpolation (`Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua:200-217,532-539`). |

HARMFUL-oriented optional presentation:

| Capability | Classification | Contract |
| --- | --- | --- |
| Dispel/debuff texture or border | Managed; additional configuration | `AddDispelTypeTexture(texture, options)` supports built-in Border, BorderWithIcon, Icon, PreserveAsset, or CustomAsset styles. Defaults show harmful, not helpful, auras. |
| Dispel/debuff text/symbol | Managed; additional configuration | `SetDispelTypeText(fontString, options)` can show Blizzard symbols or configured text. |
| Custom dispel color | Managed; additional configuration | Texture options accept `customDispelColorMap` or `customDispelColorCurve`; the secure update may call `C_UnitAuras.GetAuraDispelTypeColor`. |
| Application bar | Directly usable but optional | `SetApplicationBar(statusBar, {maxApplications=...})` binds stacks to a StatusBar. |
| Pandemic/expiration region | Managed; requires descendant regions | `AddPandemicRegion(region)` toggles regions from refresh/base-duration calculations. It is not a general “low time” color API. |
| Arbitrary aura-driven custom bar colors | Not generally available | Only documented native bindings/curves may consume restricted values. Addon Lua must not read secret debuff identity/type/time to choose arbitrary colors. |

The dispel APIs and secure show/style/color path are implemented at `Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua:75-132,372-509`; the generated schemas are at `Blizzard_APIDocumentationGenerated/AuraContainerUtilDocumentation.lua:243-284`. ApplicationBar is at `Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua:36-53,338-348`. Pandemic regions are at `Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua:236-261,567-640`.

**PROTOTYPE GUIDANCE:** Configure only the five already-validated bindings first. Defer dispel decoration, application bars, pandemic regions, and custom colors so the prototype tests architecture and security rather than visual policy.

## 8. Tooltips

Native AuraButton tooltip handling is the supported path for all managed HARMFUL rows:

- Hover uses the shared forbidden `AuraButtonTooltip` and calls `tooltip:ShowAuraTooltip(unitToken, auraData)` for aura data (`Blizzard_AuraContainer/Blizzard_AuraButton.lua:177-208`).
- The tooltip mixes in `PrivateAurasTooltipMixin` (`Blizzard_AuraContainer/Blizzard_AuraButton.lua:243-260`; `Blizzard_AuraContainer/Mainline/Blizzard_AuraButtonTooltip.xml:3-16`).
- `ShowAuraTooltip` selects `SetUnitPrivateAura` for private data and `SetUnitAuraByAuraInstanceID` otherwise (`Blizzard_PrivateAurasUI/Shared/PrivateAurasTooltip.lua:1-14`).
- `SetHideTooltipInCombat(true)` is optional policy, not a HARMFUL requirement (`Blizzard_AuraContainer/Blizzard_AuraButton.lua:62-68,177-182`).

**CONCLUSION:** Ordinary, secret/restricted, and private HARMFUL auras use the same native managed tooltip entry point; private data branches inside the tooltip. No HARMFUL-specific registration and no indexed `GameTooltip:SetUnitAura` fallback are required. Exact secret/private tooltip contents remain a Live runtime test.

## 9. Cancellation

Player HARMFUL auras are normally not user-cancellable. The generic AuraButton supports `SetCancelAuraButtons`, but its click handler does not branch on helpful/harmful: after matching a configured click token it calls restricted `C_UnitAuras.CancelAuraByInstanceID` for any ordinary aura (`Blizzard_AuraContainer/Blizzard_AuraButton.lua:3-30,90-103,228-240`). The generated API marks cancellation as requiring UnitAura access and having restrictions (`Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua:84-95`).

Thus:

- Registering `RightButtonDown` on a HARMFUL group creates a cancellation attempt with no useful normal outcome.
- Blizzard's restricted cancellation API remains the enforcement boundary; the Lua wrapper does not expose a `CanCancel` predicate.
- The DEBUFFS prototype should omit `SetCancelAuraButtons` entirely.
- Preserve only normal mouse hover/native tooltip behavior. No HARMFUL-specific replacement interaction was found.

## 10. Sorting

The validated OBB mappings remain valid for player HARMFUL:

```text
Default   -> AuraContainerSortMethod.Default        + AuraContainerSortDirection.Normal
Name      -> AuraContainerSortMethod.NameOnly       + AuraContainerSortDirection.Normal
Time Left -> AuraContainerSortMethod.ExpirationOnly + AuraContainerSortDirection.Reverse
```

`AuraContainerSortMethod` and direction values are defined/exported in `Blizzard_AuraContainer/Blizzard_AuraContainerShared.lua:40-57,256-266`. `AuraContainerUtil` maps them to `AuraUtil` comparators and implements Reverse by swapping operands (`Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua:119-143`).

Comparator behavior:

- `Default` prefers player-cast, priority, and applicable auras, then uses `auraInstanceID` (`Blizzard_FrameXMLUtil/AuraUtil.lua:140-156`).
- `NameOnly` compares `name` (nil becomes empty string), then `auraInstanceID` (`Blizzard_FrameXMLUtil/AuraUtil.lua:256-264`).
- `ExpirationOnly` places permanent/timeless auras after timed auras in Normal direction, compares expiration time, then `auraInstanceID` (`Blizzard_FrameXMLUtil/AuraUtil.lua:132-138,221-230`). Reverse therefore puts permanent auras first and longer/later expiration before shorter/earlier expiration, matching the validated BUFFS mapping.

These comparators run inside Blizzard's managed secure group/priority-table implementation, before addons receive any button presentation. Blizzard can compare restricted names and expiration values internally without making them readable to addon Lua. The existence of a stable visual order does not authorize reading the values or inferring exact private identity. Restricted-combat NameOnly/ExpirationOnly behavior, especially private-aura tie cases, should still be exercised in Live runtime tests.

## 11. Combat Lifecycle and Dynamic Sizing

The BUFFS Phase B.2 architecture applies unchanged:

```text
ordinary position root
└─ self-sizing CustomAuraContainer
   └─ managed HARMFUL AuraButtons
```

The managed container independently receives public and private updates. Incremental adds, changes, and removals prepare/cache data, update group membership, and mark frame assignment work dirty (`Blizzard_AuraContainer/Blizzard_ManagedAuraContainer.lua:100-114,331-390`). Dirty work runs through the managed one-shot lifecycle; frame assignment changes trigger layout (`Blizzard_AuraContainer/Blizzard_ManagedAuraContainer.lua:542-559`).

Group refresh retains useful frames, releases stale frames before acquisition, and builds a dense active list (`Blizzard_AuraContainer/Blizzard_AuraContainerGroups.lua:198-285`). Released custom buttons have their aura cleared and are hidden while remaining pooled (`Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua:102-128`). Custom layout reads `auraGroup:GetFramesByIndex()`, not all owned children, and then sets the container to the calculated bounds (`Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua:557-630,640-680`). Hidden pooled buttons therefore do not affect size.

**CONCLUSION:** Grow/shrink, pooling, hidden-frame exclusion, public/private additions/removals, and combat updates are framework-owned. OBB needs no addon-owned `UNIT_AURA` scanner and must not enumerate children to size the frame. The ordinary root remains independently movable; the managed container owns its own dimensions.

Source inspection does not replace runtime proof for:

- secret-value transitions during restricted combat,
- private aura addition/removal,
- root/container anchor propagation while in combat,
- empty-container one-pixel bounds,
- scale and chrome behavior,
- settings mutations attempted after access restrictions are applied.

## 12. Configuration Implications

| Concern | Conclusion |
| --- | --- |
| Storage compatibility | Keep numeric `filters.whitelist` and `filters.blacklist` maps. Do not delete or migrate saved IDs merely because the first prototype cannot apply them generally. |
| Runtime filtering capability | IDs reliably control only identity-eligible HARMFUL auras, principally the `NeverSecret` exception on `player`. They cannot control all player debuffs. |
| Discovery capability | Managed AuraContainer exposes no supported active HARMFUL identity enumeration. `GetAuraGroupFrameCount` is provider allocation capacity, not active count (`Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua:331-352`; provider counts at `Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua:52-62`). |
| Direct API fallback | `C_UnitAuras.GetUnitAuraInstanceIDs` requires UnitAura access, and returned aura data from `GetUnitAuras` has conditional secret contents (`Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua:432-469`). It is not a general restricted-combat discovery solution. |
| UI compatibility | The editor can retain manual/saved rows and previously readable cached labels. It must not claim those controls filter every managed player HARMFUL aura. |

Discovery/history cannot safely learn every harmful spell ID under 12.1. The legacy scanner already depends on readable IDs and names, and the managed framework does not publish its secure candidate cache. The first prototype should intentionally ignore DEBUFFS whitelist/blacklist controls while preserving their SavedVariables untouched.

## 13. Prototype Recommendation

### Minimal first Live DEBUFFS prototype

Include:

1. A second isolated ordinary position root and `CustomAuraContainerTemplate`.
2. `SetUnit("player")`.
3. One broad `HARMFUL` aura group with no candidate identity maps.
4. The five validated managed presentation bindings: icon, name, application count, duration text, and duration bar.
5. The existing Default / NameOnly / ExpirationOnly sort mappings.
6. Native AuraButton tooltip behavior.
7. Managed self-sizing, pooling, and framework-owned public/private updates.

Omit:

- whitelist and blacklist application,
- right-click cancellation,
- a separate private-aura group/source/anchor,
- dispel decoration,
- application bars and pandemic regions,
- custom aura-driven colors,
- new persistence or SavedVariables changes,
- production OBB integration.

Private auras should not be disabled or specially added: allow the managed container's default public-plus-private source list to exercise them naturally. “Omit private auras” here means omit custom private-aura code, not attempt to exclude the default source.

### Required Live runtime matrix

- Open world, training-dummy combat, dungeon, and raid restriction states.
- A ContextuallySecret player debuff observed readable and restricted, confirming it remains broadly displayed and is never treated as proof of accessible identity.
- Known `NeverSecret` player HARMFUL cases to verify include/exclude behavior in a later focused filter test, separate from the broad prototype.
- Real private player HARMFUL application/removal, visual binding results, tooltip, and sorting.
- Default and NameOnly sorting, plus broader ExpirationOnly/Reverse coverage with timed, timeless, secret, and private candidates.
- Rapid add/update/remove churn, frame reuse, empty-to-populated sizing, and combat anchor propagation.
- Tooltip behavior both with and without `SetHideTooltipInCombat(true)` policy.
- Login/reload setup timing and post-login access restrictions.

**PRE-VALIDATION RECOMMENDATION (NOW EXERCISED):** Proceed to an isolated broad managed player-HARMFUL prototype only. Treat it as a security/lifecycle proof, not filter parity or production integration. Preserve DEBUFFS saved filter data for compatibility, but do not wire it to the prototype until product behavior for the intentional identity-filter limitation is decided.

## 14. Initial Retail Live Runtime Validation

### Validated behavior

**RUNTIME EVIDENCE:** The first isolated OdysseusBuffBars managed DEBUFFS prototype was tested on Retail Live `12.1.0.69273`. The broad `player` / `HARMFUL` group displayed ordinary player debuffs, including multiple simultaneous harmful auras. Harmful auras added, refreshed, expired, and disappeared correctly while already in combat.

**RUNTIME EVIDENCE:** Managed icon, spell-name, application-count, duration-text, and duration-StatusBar bindings displayed and updated correctly. Dynamic grow/shrink behavior worked, and `AuraContainerSortMethod.ExpirationOnly` with `AuraContainerSortDirection.Reverse` produced the expected Time Left ordering in combat. The existing managed BUFFS prototype continued functioning alongside DEBUFFS.

Observed screenshot examples included `Temporal Displacement`, `Creeping Void`, and `Dusk Frights`; `Creeping Void` displayed an application count. These screenshots demonstrate presentation only. They do not establish whether any observed aura was secret, restricted, `NeverSecret`, or private.

No Lua errors, taint errors, or blocked-action errors attributable to OdysseusBuffBars were observed during this validation.

### Remaining targeted validation

The following remain unvalidated:

- real private player-HARMFUL aura behavior, including presentation, ordering, tooltip, and add/remove transitions;
- explicit runtime validation of Default sorting;
- explicit runtime validation of NameOnly sorting;
- native managed DEBUFF tooltip behavior in combat;
- any conclusion that depends on identifying whether a particular encountered harmful aura was secret or otherwise restricted;
- the focused `NeverSecret` include/exclude cases and the broader lifecycle cases still listed in the runtime matrix above.

**STATUS:** Core managed player-HARMFUL runtime behavior validated on Retail Live; private-aura and remaining targeted behavior tests pending.
