# Aura Filters

## Evidence Snapshot

**BLIZZARD SOURCE FACT:** This document was revalidated against Retail PTR `12.1.0.69189`, interface target `120100`, branch `ptr`, commit `a520b6c27bb897e6be2333b6cc2be36d52c7c11b` (2026-08-07). The relevant candidate-filter files are unchanged from the earlier researched build `12.1.0.68914`.

**OBB LEGACY FACT:** Compatibility behavior was traced in the Retail PTR working copy of OdysseusBuffBars through defaults, SavedVariables initialization, `OBB:RefreshAll()`, `Engine:Scan()`, group routing, filter evaluation, and the filter editor. The addon copy was read-only.

### Live 12.1 Confirmation

**BLIZZARD SOURCE FACT:** Retail Live commit `eb941aad0` (`12.1.0.69273`, interface `120100`) is identical to final PTR commit `6e348870e` for `Blizzard_AuraContainer`, `AuraUtil.lua`, generated UnitAura documentation, and the direct filtering dependencies. No aura-relevant change occurred after the document's `a520b6c27` PTR checkpoint.

**LIVE CONCLUSION:** Player HELPFUL candidate identity filtering and the OBB compilation rule remain valid unchanged. Player HARMFUL identity maps remain conditional: on an assistable unit such as `player`, both `includeSpellIDs` and `excludeSpellIDs` are skipped unless `C_Secrets.GetSpellAuraSecrecy(spellID)` is `NeverSecret`; skipping the maps does not reject the aura. Private auras enter the same managed group/slot pipeline through the separate private source and are subject to the same identity-eligibility rule.

## Filter Layers

**BLIZZARD SOURCE FACT:** The current framework has three selection layers:

1. Filter strings choose broad aura categories at the source query.
2. The optional processing policy classifies or excludes auras.
3. Candidate filters accept or reject individual candidates for a group or slot.

Candidate filters are applied after the filter string (`Blizzard_AuraContainer/Blizzard_AuraContainerGroups.lua:503-516`; `Blizzard_AuraContainerSlots.lua:356-370`).

**ANALYSIS:** Compose the layers from broadest to narrowest. This reduces duplicate parsing and keeps secret-sensitive decisions inside Blizzard's managed secure code.

## Filter Strings

**BLIZZARD SOURCE FACT:** Current Retail PTR tokens are:

`HELPFUL`, `HARMFUL`, `PLAYER`, `RAID`, `CANCELABLE`, `INCLUDE_NAME_PLATE_ONLY`, `MAW`, `EXTERNAL_DEFENSIVE`, `CROWD_CONTROL`, `RAID_IN_COMBAT`, `RAID_PLAYER_DISPELLABLE`, `BIG_DEFENSIVE`, `IMPORTANT`, and `DISPELLABLE` (`Blizzard_FrameXMLUtil/AuraUtil.lua:270-288`).

**BLIZZARD SOURCE FACT:** Tokens may be separated with `|` or spaces. `!` negates supported tokens. `NOT_CANCELABLE` is deprecated in favor of `!CANCELABLE`. Negation is ignored for `INCLUDE_NAME_PLATE_ONLY` and `MAW`; a bare `!` is invalid (`AuraUtil.lua:290-319`).

**ANALYSIS:** `HELPFUL` and `HARMFUL` are the direct managed equivalents of OBB's broad Buffs and Debuffs group filters. `DISPELLABLE`, `IMPORTANT`, and raid filters are optional product policies, not replacements for OBB spell-ID lists.

## Odysseus BuffBars Legacy Filter Semantics

### Storage

**OBB LEGACY FACT:** Filters are stored per group under:

```text
OdysseusBuffBarsDB.groups[n].filters.whitelist[spellID] = true
OdysseusBuffBarsDB.groups[n].filters.blacklist[spellID] = true
```

Defaults create both maps for BUFFS, DEBUFFS, and ENCHANTMENTS, and load-time migration fills missing maps (`OdysseusBuffBars.lua:17-40`, `48-70`, `78-101`, `222-226`).

**OBB LEGACY FACT:** Entries are numeric spell-ID keys with truthy values. Names and icons are editor metadata only; they are not matching keys. Manual editor input is converted with `tonumber` before it is inserted (`OdysseusBuffBars_Config.lua:815-829`, `835-849`).

### Whitelist Mode and Precedence

**OBB LEGACY FACT:** There is no separate whitelist-enabled setting. Whitelist mode is enabled implicitly when the whitelist contains at least one enabled numeric spell ID (`OdysseusBuffBars_Auras.lua:131-154`).

**OBB LEGACY FACT:** When whitelist mode is active, OBB returns the whitelist membership result immediately and never evaluates the blacklist. Therefore, a spell present in both lists is displayed. When the whitelist is empty, the blacklist excludes matching IDs and all other IDs pass (`OdysseusBuffBars_Auras.lua:143-161`).

**OBB LEGACY FACT:** If the current aura record has no readable numeric `spellID`, legacy filtering returns true before either map is consulted. The lists are spell-ID-first, not a guarantee that unidentified auras are hidden (`OdysseusBuffBars_Auras.lua:147-150`).

### Routing and Discovery Order

**OBB LEGACY FACT:** Overrides and enhancement classification route an aura to a group before whitelist/blacklist evaluation. `Engine:Scan()` calls `ShouldIncludeAuraForGroup` before `RememberFilterAura` and before `ShouldPassGroupFilters` (`OdysseusBuffBars_Auras.lua:110-129`, `426-431`).

**OBB LEGACY FACT:** The discovery cache is populated after group routing but before list filtering. This keeps a routed aura in the editor even after a whitelist or blacklist hides it. Synthetic weapon enchantments are also remembered before their group filter is applied (`OdysseusBuffBars_Auras.lua:164-185`, `453-458`).

**OBB LEGACY FACT:** `OBB.filterAuraRows[groupID]` is an in-memory history cache. The editor merges it with currently displayed `OBB.auraData[groupID]` and all SavedVariables list entries, de-duplicates by numeric spell ID, and sorts ascending by spell ID. Saved but unseen IDs remain as `Saved spell`; manual entry remains available (`OdysseusBuffBars_Config.lua:277-327`, `880-950`).

## Managed Candidate Filter API

### Addon-Facing Surface

| Mechanism | Exact surface | Classification |
| --- | --- | --- |
| Add group with filters | `AddAuraGroup(groupKey, filterString, options)`, with `options.candidateFilters` | Addon-facing template/mixin API |
| Change broad group filter | `SetAuraGroupFilterString(groupKey, filterString)` | Addon-facing template/mixin API |
| Change group candidates | `SetAuraGroupCandidateFilters(groupKey, candidateFilters)` | Addon-facing template/mixin API |
| Change maximum count | `SetAuraGroupMaxFrameCount(groupKey, maxFrameCount)` | Addon-facing template/mixin API |
| Add slot with filters | `AddAuraSlot(slotKey, filterString, options)`, with `options.candidateFilters` | Addon-facing template/mixin API |
| Change slot candidates | `SetAuraSlotCandidateFilters(slotKey, candidateFilters)` | Addon-facing template/mixin API |
| Group/slot `SetCandidateFilters` | Private group/slot object method | Blizzard-internal implementation detail |
| `DoesAuraPassCandidateFilters` | Secure implementation function | Blizzard-internal; unsuitable for direct addon use |
| `GetAuras`, `GetCandidates`, `GetAuraInstance` | Private managed/button state | Blizzard-internal; unsuitable for addon discovery |

The public group construction and setter paths are defined on `CustomAuraContainerSharedMixin` and included in `CustomAuraContainerInboundMixin` (`Blizzard_CustomAuraContainer.lua:281-324`, `355-382`, `400-440`, `512-513`). They are template/mixin APIs rather than generated `C_` namespace functions.

### Candidate Filter Fields

**BLIZZARD SOURCE FACT:** Supported identity/dispel maps are:

- `includeSpellIDs`
- `excludeSpellIDs`
- `includeDispelTypes`
- `excludeDispelTypes`

Each is a table or nil (`Blizzard_CustomAuraContainer.lua:72-101`). Map membership is tested by key; OBB-compatible maps should use numeric spell-ID keys with `true` values.

**BLIZZARD SOURCE FACT:** Scalar/classification fields are:

- `maxDuration`: inclusive upper bound on original maximum duration; any non-nil value rejects permanent auras.
- `processedAuraType`: requires the `ProcessAura` processing policy.

See `Blizzard_CustomAuraContainer.lua:103-117` and `Blizzard_AuraContainerUtil.lua:101-106`.

**BLIZZARD SOURCE FACT:** Fixed boolean filters accept `true`, `false`, or nil:

- `isFromPlayerOrPlayerPet`
- `isRoleAura`
- `isPriorityAura`
- `isStealable`
- `nameplateShowAll`
- `nameplateShowPersonal`
- `canApplyAura`
- `isBossAura`
- `isBossOrRoleAura`

See `Blizzard_CustomAuraContainer.lua:119-137` and `Blizzard_AuraContainerUtil.lua:73-114`.

**BLIZZARD SOURCE FACT:** Candidate filters do not accept an addon predicate function. The surface is the fixed option table above. Internal mixin overrides are not an addon extension point.

## Spell-ID Include and Exclude

### Native Semantics

**BLIZZARD SOURCE FACT:** `includeSpellIDs` can display only configured spell IDs when identity filtering is permitted. A non-nil empty include map rejects every identity-eligible aura because no spell ID can be present in it (`Blizzard_AuraContainerUtil.lua:50-54`).

**BLIZZARD SOURCE FACT:** `excludeSpellIDs` rejects configured spell IDs when identity filtering is permitted (`Blizzard_AuraContainerUtil.lua:43-48`).

**BLIZZARD SOURCE FACT:** Include and exclude maps may coexist. Validation accepts both. Exclusion is evaluated first, so a spell present in both maps is rejected (`Blizzard_CustomAuraContainer.lua:79-90`; `Blizzard_AuraContainerUtil.lua:43-54`).

### Whitelist Mapping

**ANALYSIS:** Exact OBB whitelist precedence for an identity-eligible aura is achieved by supplying only:

```lua
candidateFilters = {
    includeSpellIDs = sanitizedWhitelist,
}
```

Do not also pass the legacy blacklist while whitelist mode is active. Raw transmission of both SavedVariables maps would change the conflict result from legacy whitelist-wins to managed exclude-wins.

**ANALYSIS:** When the legacy whitelist is empty, omit `includeSpellIDs` entirely. Passing `{}` would mean show none, while legacy OBB treats an empty whitelist as whitelist mode disabled.

### Blacklist Mapping

**ANALYSIS:** When the legacy whitelist has no enabled numeric entries, exact OBB blacklist semantics for an identity-eligible aura are expressed by:

```lua
candidateFilters = {
    excludeSpellIDs = sanitizedBlacklist,
}
```

An empty blacklist may be omitted. The translation layer should sanitize SavedVariables to enabled numeric keys and construct a fresh managed options table.

## Secret Aura Compatibility

**BLIZZARD SOURCE FACT:** `Blizzard_AuraContainer.toc` loads implementation Lua in a secure environment while exposing XML templates globally for external creation (`Blizzard_AuraContainer.toc:7-12`). Public and private aura sources obtain aura data inside that managed environment (`Blizzard_AuraContainerSources.lua:27-61`). Candidate selection then runs in the managed group/slot pipeline before frame assignment (`Blizzard_AuraContainerGroups.lua:143-161`, `503-516`).

**BLIZZARD SOURCE FACT:** Configured include/exclude maps are copied inbound with `securecopy`, validated, and consumed internally. The addon does not need to read the candidate aura's spell ID to perform a permitted managed match (`Blizzard_CustomAuraContainer.lua:225-239`, `376-382`).

**BLIZZARD SOURCE FACT:** Identity filters are conditionally permitted by `CanApplyIdentityCandidateFilters`:

| Aura/unit relationship | Identity include/exclude behavior |
| --- | --- |
| Spell secrecy is `NeverSecret` | Applied on any unit |
| Harmful aura on an assistable unit | Skipped unless never-secret |
| Helpful aura on a non-assistable unit | Skipped unless never-secret |
| Helpful aura on an assistable unit | Applied |
| Harmful aura on a non-assistable unit | Applied |

See `Blizzard_AuraContainerUtil.lua:11-36`.

**BLIZZARD SOURCE FACT:** When identity filtering is not permitted, both `includeSpellIDs` and `excludeSpellIDs` are skipped; the aura is not automatically rejected. Non-identity candidate filters continue to run (`Blizzard_AuraContainerUtil.lua:38-57`).

**ANALYSIS:** This means the managed pipeline can apply configured spell-ID filters to eligible secret-aware aura data without exposing identity to addon Lua. For OBB's player BUFFS group, helpful auras are on an assistable unit and the source path permits identity matching. For player DEBUFFS, harmful auras on an assistable unit generally bypass identity maps unless the spell is never-secret.

**RUNTIME TEST REQUIRED:** Verify real PTR secret-aura cases for player helpful auras, player harmful auras, and private auras. Source proves where evaluation occurs and when identity maps are eligible; it does not prove every encounter aura's runtime field/secrecy behavior.

**RECOMMENDATION:** Never restore direct aura scanning, AuraButton identity reads, or private managed-state access to compensate when Blizzard intentionally skips an identity filter.

## Filter Interaction Cases

| Case | Legacy OBB | Managed source behavior | Compatibility action |
| --- | --- | --- | --- |
| Whitelist enabled and empty | No separate enabled state; empty means disabled | Empty `includeSpellIDs` rejects all eligible identities | Omit `includeSpellIDs` |
| Same ID in both lists | Whitelist wins and aura displays | Exclude is evaluated first and aura is hidden | In whitelist mode, omit blacklist |
| Timeless aura | Spell-ID map applies when ID is readable | Identity map is independent of duration; `maxDuration` would reject permanent auras | Do not add `maxDuration` for ordinary list parity |
| Secret aura | Unreadable/missing numeric ID bypasses legacy lists | Managed identity map applies or is skipped according to source eligibility | Accept managed policy; PTR-test required |
| Private aura | Legacy direct scanner is not a valid parity authority | Private source enters the managed filter pipeline; exact identity eligibility is unresolved | Framework-owned; PTR-test required |
| Native item enchantment | Synthetic legacy row is filtered using its numeric enchant ID field | `AddItemEnchantment` options have no candidate filters; entries bypass aura groups | Requires product change |
| Same aura in multiple groups | Legacy scans/evaluates each group separately | Each managed group owns independent filter string and candidate maps; group loop is non-exclusive | Supported; validate duplicate display policy |

## Runtime Reconfiguration

**BLIZZARD SOURCE FACT:** `SetAuraGroupCandidateFilters(groupKey, candidateFilters)` is the reconfiguration path for an existing long-lived group. It copies and validates the new table, replaces the group's candidate filters, clears managed group membership, and calls `UpdateAllAuras()` (`Blizzard_CustomAuraContainer.lua:376-382`; `Blizzard_AuraContainerGroups.lua:420-427`).

**BLIZZARD SOURCE FACT:** Group recreation is not required. The group and its frame provider remain owned by the container; stale assignments are reclaimed during the subsequent managed refresh. Blizzard's private comment explicitly prefers reconfiguring filter attributes over clearing groups (`Blizzard_CustomAuraContainer.lua:527-536`).

**BLIZZARD SOURCE FACT:** Mutating the caller's original Lua map is not a refresh mechanism. Candidate options cross the inbound boundary through a copied table. Call the public setter with the complete newly compiled candidate-filter table.

**BLIZZARD SOURCE FACT:** `SetAuraGroupFilterString` separately changes the broad filter, rebuilds parse filters, and requests a full update (`Blizzard_CustomAuraContainer.lua:355-363`). Maximum count uses `SetAuraGroupMaxFrameCount` (`Blizzard_CustomAuraContainer.lua:366-373`).

**OBSERVATION:** The setters contain no `InCombatLockdown` branch and no explicit PLAYER_LOGIN-only gate.

**RUNTIME TEST REQUIRED:** Source inspection does not prove that tainted addon execution may call candidate/filter setters safely in combat or in every post-login restricted context. Test post-PLAYER_LOGIN mutation out of combat, then test combat calls separately.

**RECOMMENDATION:** Preserve OBB's conservative behavior initially: edit filters out of combat, call the managed setter immediately when allowed, and queue or block combat changes. Managed AuraButtons remain container-owned and must not be manually reordered or rebuilt.

## Filter Editor and Discovery Implications

**BLIZZARD SOURCE FACT:** No addon-facing managed API enumerates active candidate spell IDs or names. `GetAuraGroupFrame` and `GetAuraGroupFrameCount` expose provider-owned frames/capacity, not active aura identity. `AuraButtonPrivateMixin:GetAuraInstance`, group `GetAuras`, source `GetAllAuraInstanceIDs`, and managed caches are private implementation details.

**BLIZZARD SOURCE FACT:** Direct `C_UnitAuras` enumeration remains guarded by `RequiresUnitAuraAccess` and secret predicates in generated documentation. It is not a reliable managed filter-editor discovery service (`Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua:170-210`, `432-454`).

**ANALYSIS:** The legacy `filterAuraRows` discovery cache cannot be populated with exact parity after a group becomes managed unless Blizzard adds a supported identity/history surface. Enumerating container children, reading private AuraButton identity, or restoring a second direct scan would violate the managed architecture.

**RECOMMENDATION:** Preserve the editor product concept with safe data sources:

- Retain existing SavedVariables whitelist and blacklist IDs.
- Keep manual numeric spell-ID entry.
- Resolve optional display names/icons from the entered ID through ordinary spell metadata only when permitted; do not require live aura identity.
- Add curated filter entries where useful.
- Keep already-known legacy rows only if they are deliberately persisted; the current `filterAuraRows` cache itself is runtime-only.
- Use no automatic live discovery for a fully managed group until Blizzard exposes a supported API.

**ANALYSIS:** Out-of-combat direct enumeration could be retained only as an explicitly temporary compatibility tool while the legacy scanner still owns that group. It should not become part of the final managed architecture and must not run merely to feed the editor.

## OBB Compatibility Matrix

| OBB behavior | Managed assessment | Notes |
| --- | --- | --- |
| HELPFUL/HARMFUL base filter | Exact native parity | Use group filter strings |
| Player BUFFS whitelist | Possible with managed configuration | Exact for identity-eligible helpful player auras; PTR validate secret cases |
| Player BUFFS blacklist | Possible with managed configuration | Use exclude-only map when whitelist is empty |
| Player DEBUFFS whitelist/blacklist | Unsupported / unresolved | Harmful auras on assistable units skip identity maps unless never-secret |
| Whitelist + blacklist conflict | Exact native parity through translation | Do not send blacklist while legacy whitelist mode is active |
| Timed-only | Requires PTR validation | Source permits `maxDuration = math.huge`, which rejects duration zero; verify inbound/runtime behavior |
| Timeless-only | Unsupported / unresolved | No minimum-duration or permanent-only candidate field |
| Maximum bars | Exact native parity | `SetAuraGroupMaxFrameCount` |
| Enhancement aura routing | Requires product change | No name predicate; use curated IDs or explicit groups |
| Native item enchantment filtering | Unsupported / unresolved | Item enchantments bypass group candidate filters |
| Spell-name heuristic filtering | Requires product change | No addon predicate/name candidate field |
| Per-group SavedVariables lists | Exact native parity | Preserve storage; compile to managed maps |
| Filter discovery/history cache | Requires product change | No supported managed identity enumerator |
| Private aura identity filtering | Requires PTR validation | Same secure pipeline, but exact runtime eligibility is unresolved |

## Recommended Managed Filtering Design

**RECOMMENDATION:** Preserve the existing per-group SavedVariables and editor tabs, but compile each group's effective managed candidate table instead of passing both maps directly:

```text
sanitize enabled numeric IDs

if whitelist has entries:
    includeSpellIDs = whitelist
    excludeSpellIDs = nil
else:
    includeSpellIDs = nil
    excludeSpellIDs = blacklist when non-empty
```

Apply the result with `SetAuraGroupCandidateFilters(groupKey, candidateFilters)` on the long-lived container. Keep broad `HELPFUL`/`HARMFUL` selection in the filter string and maximum bars in its dedicated setter.

**RECOMMENDATION:** The next implementation slice should be an isolated PTR extension of the already-managed player BUFFS prototype:

1. Use saved/manual numeric IDs only; do not add discovery scanning.
2. Test empty lists, include-only, exclude-only, and the same ID saved in both legacy lists.
3. Reconfigure the existing group out of combat through `SetAuraGroupCandidateFilters`.
4. Verify ordinary, combat-secret, aura refresh, removal, reload, and rollback behavior.
5. Do not migrate player DEBUFFS or native item enchantment filtering until their documented gaps have a product decision.

## Open PTR Questions

1. **RUNTIME TEST REQUIRED:** Does player-BUFFS include/exclude filtering continue correctly through secret-aura combat transitions without addon identity access?
2. **RUNTIME TEST REQUIRED:** Does post-PLAYER_LOGIN out-of-combat `SetAuraGroupCandidateFilters` immediately release/reassign the expected managed buttons without taint?
3. **RUNTIME TEST REQUIRED:** What happens if the setter is invoked during combat from tainted addon execution? Until tested, OBB should block or queue it.
4. **RUNTIME TEST REQUIRED:** How do private auras interact with configured identity maps for player groups?
5. **RUNTIME TEST REQUIRED:** Does `maxDuration = math.huge` provide reliable timed-only behavior through inbound validation and secret aura updates?
6. **PRODUCT DECISION:** Should player DEBUFFS preserve list controls as inactive/unsupported, restrict them to never-secret IDs, or adopt a different supported policy?
7. **PRODUCT DECISION:** Should legacy enhancement routing use curated spell IDs, manual groups, or reduced initial parity?
8. **PRODUCT DECISION:** Which legacy discovered rows, if any, should be persisted before direct scanning is retired?
9. **SOURCE WATCH:** Re-audit identity eligibility, candidate fields, and runtime setters against the final 12.1 Live source.

**LIVE RESOLUTION:** Final Live preserves the documented identity eligibility, candidate fields, setter refresh behavior, and include/exclude precedence. Runtime safety of tainted combat-time setter calls remains unproven and must not be inferred from source parity.

## References

### Blizzard Retail PTR

- `Blizzard_AuraContainer/Blizzard_AuraContainer.toc`
- `Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua`
- `Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerShared.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerGroups.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerSlots.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerSources.lua`
- `Blizzard_AuraContainer/Blizzard_AuraButton.lua`
- `Blizzard_FrameXMLUtil/AuraUtil.lua`
- `Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua`

### OdysseusBuffBars Read-Only Context

- `OdysseusBuffBars.lua`
- `OdysseusBuffBars_Auras.lua`
- `OdysseusBuffBars_Config.lua`
- `Documentation/ARCHITECTURE.md`
- `Documentation/MANAGED_AURACONTAINER_MIGRATION.md`
