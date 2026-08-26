# Aura Filters

## Evidence Snapshot

**BLIZZARD SOURCE FACT:** This document was revalidated against Retail PTR `12.1.0.69189`, interface target `120100`, branch `ptr`, commit `a520b6c27bb897e6be2333b6cc2be36d52c7c11b` (2026-08-07). The relevant candidate-filter files are unchanged from the earlier researched build `12.1.0.68914`.

**OBB LEGACY FACT:** Compatibility behavior was traced in the Retail PTR working copy of OdysseusBuffBars through defaults, SavedVariables initialization, `OBB:RefreshAll()`, `Engine:Scan()`, group routing, filter evaluation, and the filter editor. The addon copy was read-only.

### Live 12.1 Confirmation

**BLIZZARD SOURCE FACT:** Retail Live commit `eb941aad0` (`12.1.0.69273`, interface `120100`) is identical to final PTR commit `6e348870e` for `Blizzard_AuraContainer`, `AuraUtil.lua`, generated UnitAura documentation, and the direct filtering dependencies. No aura-relevant change occurred after the document's `a520b6c27` PTR checkpoint.

**LIVE CONCLUSION:** Player HELPFUL candidate identity filtering and the OBB compilation rule remain valid unchanged. Player HARMFUL identity maps remain conditional: on an assistable unit such as `player`, both `includeSpellIDs` and `excludeSpellIDs` are skipped unless `C_Secrets.GetSpellAuraSecrecy(spellID)` is `NeverSecret`; skipping the maps does not reject the aura. Private auras enter the same managed group/slot pipeline through the separate private source and are subject to the same identity-eligibility rule.

**CURRENT SOURCE REVALIDATION:** Retail Live `12.1.0.69299`, branch `live`, commit `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b`, and Retail PTR `12.1.0.69299`, branch `ptr`, commit `fe17d3e3bd5d6b5a35816d13f1941aa8927cd2be`, have byte-identical generated `SpellDocumentation.lua`, `TooltipInfoDocumentation.lua`, and `UnitAuraDocumentation.lua`. The candidate-filter setter and group-reset implementation described below is also present in the current Live mirror.

**CURRENT LIVE FOLLOW-UP:** Retail Live build `12.1.0.69497`, branch `live`, commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`, contains a candidate-identity eligibility change that landed in build `12.1.0.69465`, commit `86017d5af966acb89d5d46747761c011eb0d783c`. Helpful identity filters are now always permitted for the active player, player-controlled units, group members, and their pets through `UnitIsPlayerControlledOrGroupMember(unitToken)`, even when `UnitCanAssist` can transiently return false in an edge case such as Mind Control. Remaining assistability checks now explicitly ignore immune and uninteractable restrictions so vehicles, teleport transitions, and similar states do not accidentally change identity-filter policy (`Blizzard_AuraContainerUtil.lua:11-46`).

**OBB IMPACT:** This hardens the existing player-HELPFUL BUFFS/`HelpfulEnhancements` candidate-filter contract. It does not change candidate-filter table shape, include/exclude precedence, group refresh, sorting, or setter lifecycle, and it requires no OBB code change.

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
| Helpful aura on the active player, a player-controlled unit, a group member, or its pet | Applied, including when ordinary assistability is transiently false |
| Harmful aura on an assistable unit | Skipped unless never-secret; immune/uninteractable state is ignored for this reaction test |
| Other helpful aura on a non-assistable unit | Skipped unless never-secret; immune/uninteractable state is ignored for this reaction test |
| Other helpful aura on an assistable unit | Applied |
| Harmful aura on a non-assistable unit | Applied |

See `Blizzard_AuraContainerUtil.lua:11-46`.

**BLIZZARD SOURCE FACT:** When identity filtering is not permitted, both `includeSpellIDs` and `excludeSpellIDs` are skipped; the aura is not automatically rejected. Non-identity candidate filters continue to run (`Blizzard_AuraContainerUtil.lua:38-57`).

**ANALYSIS:** This means the managed pipeline can apply configured spell-ID filters to eligible secret-aware aura data without exposing identity to addon Lua. For OBB's player BUFFS and `HelpfulEnhancements` groups, the explicit player/player-controlled/group-member exception now preserves identity matching across Mind Control and similar reaction edge cases. For player DEBUFFS, harmful auras on an assistable unit generally bypass identity maps unless the spell is never-secret; immune and uninteractable state no longer weakens that restriction.

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

## Spell Metadata and Semantic Classification

### Documented `C_Spell` Surface Investigated

**BLIZZARD SOURCE FACT:** The generated Retail 12.1 `C_Spell` documentation exposes the following metadata calls relevant to inspecting a known active-aura spell ID. `SpellIdentifier` accepts a spell ID, name, name plus subtext, or link where the individual entry documents that type.

| API and exact generated signature | Generated access/return restriction |
| --- | --- |
| `DoesSpellExist(spellIdentifier: SpellIdentifier) -> spellExists: bool` | `AllowedWhenUntainted` |
| `IsSpellDataCached(spellIdentifier: SpellIdentifier) -> isCached: bool` | `AllowedWhenUntainted` |
| `GetSpellName(spellIdentifier: SpellIdentifier) -> name: cstring \| nothing` | `AllowedWhenTainted`; may return nothing |
| `GetSpellDescription(spellIdentifier: SpellIdentifier) -> description: string \| nothing` | `AllowedWhenTainted`; may return nothing or an empty string while data is loading |
| `GetSpellSubtext(spellIdentifier: SpellIdentifier) -> subtext: string \| nothing` | `AllowedWhenTainted`; may return nothing or an empty string while data is loading |
| `GetBaseSpell(spellIdentifier: SpellIdentifier, spec: number = 0) -> baseSpellID: number` | `AllowedWhenTainted` |
| `GetOverrideSpell(spellIdentifier: SpellIdentifier, spec: number = 0, onlyKnown: bool = true, ignoreOverrideSpellID: number = 0) -> overrideSpellID: number` | `AllowedWhenUntainted` |
| `GetSpellInfo(spellIdentifier: SpellIdentifier) -> spellInfo: SpellInfo \| nothing` | `AllowedWhenTainted`; may return nothing |
| `GetSpellTexture(spellIdentifier: SpellIdentifier) -> iconID: fileID, originalIconID: fileID, conditionalIconID?: fileID \| nothing` | `AllowedWhenTainted`; may return nothing |
| `GetAuraStatChanges(spellID: number) -> healthChange: number, powerTypeChanges: table<PowerTypeChange>` | `AllowedWhenUntainted` |
| `GetSpellLevelLearned(spellIdentifier: SpellIdentifier) -> levelLearned: number` | `AllowedWhenTainted` |
| `GetSpellSkillLineAbilityRank(spellIdentifier: SpellIdentifier) -> rank: number \| nothing` | `AllowedWhenTainted`; may return nothing |
| `GetSpellMaxCumulativeAuraApplications(spellID: SpellIdentifier) -> cumulativeAura: number` | `AllowedWhenTainted`; result is secret when unit-aura access is restricted |

`SpellInfo` contains `name`, `iconID`, `originalIconID`, `castTime`, `minRange`, `maxRange`, and `spellID`. `PowerTypeChange` contains `powerType` and `amount` (`SpellDocumentation.lua:1100-1120`).

**BLIZZARD SOURCE FACT:** The classification-related predicates examined were:

| Exact generated signature | Secret-argument restriction |
| --- | --- |
| `IsConsumableSpell(spellIdentifier: SpellIdentifier) -> consumable: bool` | `AllowedWhenTainted` |
| `IsClassTalentSpell(spellIdentifier: SpellIdentifier) -> isAutoRepeat: bool` | `AllowedWhenTainted` |
| `IsPvPTalentSpell(spellIdentifier: SpellIdentifier) -> isAutoRepeat: bool` | `AllowedWhenTainted` |
| `IsExternalDefensive(spellID: number) -> isExternalDefensive: bool` | `AllowedWhenUntainted` |
| `IsPriorityAura(spellID: number) -> isHighPriority: bool` | `AllowedWhenUntainted` |
| `IsSelfBuff(spellID: number) -> hasSelfEffectsOnly: bool` | `AllowedWhenUntainted` |
| `IsSpellCrowdControl(spellIdentifier: SpellIdentifier) -> isCrowdControl: bool` | `AllowedWhenTainted` |
| `IsSpellDisabled(spellIdentifier: SpellIdentifier) -> disabled: bool` | `AllowedWhenTainted` |
| `IsSpellHarmful(spellIdentifier: SpellIdentifier) -> isHarmful: bool` | `AllowedWhenTainted` |
| `IsSpellHelpful(spellIdentifier: SpellIdentifier) -> isHelpful: bool` | `AllowedWhenTainted` |
| `IsSpellImportant(spellIdentifier: SpellIdentifier) -> isImportant: bool` | `AllowedWhenTainted` |
| `IsSpellPassive(spellIdentifier: SpellIdentifier) -> isPassive: bool` | `AllowedWhenTainted` |

The generated return-field names for `IsClassTalentSpell` and `IsPvPTalentSpell` are both currently `isAutoRepeat`; this document preserves that source label rather than silently correcting it.

### Tested Semantic Results

**RUNTIME EVIDENCE:** Out-of-combat inspection covered three active player HELPFUL aura spell IDs: `1232325` (Well Fed), `1234969` (Ethereal Augmentation), and `432021` (Flask of Alchemical Chaos). In that session, spell data existed and was cached; names and descriptions were readable and semantically useful; `IsSpellHelpful` and `IsSelfBuff` returned true; and `IsConsumableSpell` returned false.

**ANALYSIS:** `C_Spell.IsConsumableSpell()` must not be assumed to identify a currently active aura as originating from a consumable. It returned false for all three tested Food, Flask, and Augment-related aura spells. This does not establish that it returns false for every consumable or consumable-related spell.

**BLIZZARD SOURCE FACT:** No documented `C_Spell` entry containing or directly representing Food, Flask, Phial, or Augment Rune categorization was found in the generated Retail 12.1 spell documentation. This is an audit result for the examined namespace, not proof that semantic information cannot exist elsewhere in the client.

**ANALYSIS:** Readable spell names and descriptions can support addon-side semantic research, but string interpretation is not a Blizzard-supported formal classification system. Access must remain guarded, and unreadable, secret, missing, or still-loading values must not be forced.

**RUNTIME EVIDENCE:** A second character exposed different active IDs, `393438` (Draconic Augmentation) and `1233712` (Hearty Well Fed). Their readable semantic spell metadata was sufficient for the experimental classification path. This broadens the observed sample only; it does not establish universal coverage or zero false positives.

### Fishing bobber runtime boundary

**RUNTIME EVIDENCE:** `Limited Edition Rocket Bobber` appeared as an ordinary active player `HELPFUL` aura with spell ID `1222880`. It was readable through the normal unit-aura path and also appeared in Blizzard's default BuffFrame. Observed spell metadata used the same name and a description beginning `Replace your fishing bobber with a bobbing Limited Edition Rocket...`.

**BLIZZARD SOURCE FACT:** The managed public-aura source enumerates ordinary aura instance IDs with `C_UnitAuras.GetUnitAuraInstanceIDs` and fetches them with `C_UnitAuras.GetAuraDataByAuraInstanceID`. A current generated-documentation and Mainline implementation search found no `C_Fishing` namespace, Bobber/Lure classification API, or Bobber-specific AuraContainer source. The tested spell ID and display name do not appear in the UI source because spell records are client data rather than a Lua classifier (`Blizzard_AuraContainerSources.lua:27-38`; `UnitAuraDocumentation.lua:170-204,432-449`).

**ANALYSIS:** This proves only that the tested bobber replacement uses Blizzard's ordinary player-HELPFUL aura representation. It does not prove that every bobber toy produces an aura, that every such effect contains the localized word `bobber`, or that spell ID `1222880` is a permanent bobber database. Name/description matching remains a localization-sensitive addon heuristic, not a Blizzard category. Any product category built from it must not be documented as a native Bobber concept.

**REPRESENTATION DISTINCTION:** The tested bobber and lure were separate Blizzard representations. The bobber was an ordinary player `HELPFUL` aura in the normal aura/BuffFrame path. Bright Baubles was temporary-enchantment state on fishing profession equipment, readable through `C_PaperDollInfo.GetTemporaryEnchantmentInfo(28)` in that test; it was not observed as an ordinary player `HELPFUL` aura and remains outside the managed AuraContainer provider's fixed MainHand/OffHand/Ranged item-enchantment set. See [Managed Item Enchantments](AuraEnchantments.md).

### Identity and Duration Cautions

**RUNTIME EVIDENCE:** Bloom Skewers used item ID `242302`, while the observed active Well Fed aura used spell ID `1232325`. The item ID was not a valid substitute for the aura spell ID in `includeSpellIDs` or `excludeSpellIDs`.

**ANALYSIS:** A consumable item ID must not be assumed to equal the spell ID of its active aura. Managed aura candidate filters consume aura spell identities, not source-item identities.

**RUNTIME EVIDENCE:** Flask of Alchemical Chaos first displayed approximately 37 minutes remaining. Applying another flask extended the displayed remaining duration to approximately two hours.

**ANALYSIS:** Duration is runtime effect state that can reflect extension, repeated application, profession behavior, or other gameplay mechanics. It is not reliable Food, Flask, Phial, Augment, potion, or other consumable-category metadata and should not be used as a semantic classifier.

## Runtime Reconfiguration

**BLIZZARD SOURCE FACT:** `SetAuraGroupCandidateFilters(groupKey, candidateFilters)` is the reconfiguration path for an existing long-lived group. It copies and validates the new table, replaces the group's candidate filters, clears managed group membership, and calls `UpdateAllAuras()` (`Blizzard_CustomAuraContainer.lua:376-382`; `Blizzard_AuraContainerGroups.lua:420-427`).

**BLIZZARD SOURCE FACT:** Group recreation is not required. The group and its frame provider remain owned by the container; stale assignments are reclaimed during the subsequent managed refresh. Blizzard's private comment explicitly prefers reconfiguring filter attributes over clearing groups (`Blizzard_CustomAuraContainer.lua:527-536`).

**BLIZZARD SOURCE FACT:** Mutating the caller's original Lua map is not a refresh mechanism. Candidate options cross the inbound boundary through a copied table. Call the public setter with the complete newly compiled candidate-filter table.

**BLIZZARD SOURCE FACT:** `SetAuraGroupFilterString` separately changes the broad filter, rebuilds parse filters, and requests a full update (`Blizzard_CustomAuraContainer.lua:355-363`). Maximum count uses `SetAuraGroupMaxFrameCount` (`Blizzard_CustomAuraContainer.lua:366-373`).

**OBSERVATION:** The setters contain no `InCombatLockdown` branch and no explicit PLAYER_LOGIN-only gate.

**RUNTIME TEST REQUIRED:** Source inspection does not prove that tainted addon execution may call candidate/filter setters safely in combat or in every post-login restricted context. Test post-PLAYER_LOGIN mutation out of combat, then test combat calls separately.

**RECOMMENDATION:** Preserve OBB's conservative behavior initially: edit filters out of combat, call the managed setter immediately when allowed, and queue or block combat changes. Managed AuraButtons remain container-owned and must not be manually reordered or rebuilt.

### Live Dynamic Reassignment Evidence

**RUNTIME EVIDENCE:** On current Retail 12.1, already-active readable player HELPFUL auras initially displayed in one managed AuraGroup. After their spell IDs were added to another group's `includeSpellIDs`, added to the original group's `excludeSpellIDs`, and both complete candidate-filter tables were reapplied through the public managed-container setter, the existing aura rows moved to the selected group. The container was not recreated, duplicate presentation was not observed, and managed duration presentation remained correct.

**ANALYSIS:** This validates dynamic reclassification/reassignment for the tested player HELPFUL auras and configuration path. It does not establish the same behavior for every unit, aura source, restriction state, harmful aura, or private aura.

**RUNTIME EVIDENCE:** Repeated filter updates exercised growth, shrink, an empty set, repopulation, and an unchanged set, including the observed sequence `1 -> 0 -> 1 -> 2`. No stale routed row was observed in the tested cases. A session-only last-applied set suppressed redundant setter calls when the compiled set was unchanged.

**ANALYSIS:** The last-applied-set optimization is addon-side design guidance, not a Blizzard API requirement. The framework evidence is limited to the observed refresh/reassignment result after the public setters were called.

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
- Do not treat a managed container as an identity-discovery service. Any separate guarded discovery path remains addon-owned and subject to UnitAura restrictions.

**ANALYSIS:** The current experiment demonstrates that guarded out-of-combat HELPFUL rediscovery can drive public candidate-filter reconfiguration without polling. That does not create a managed identity-enumeration API or make direct enumeration safe in restricted contexts. Keep discovery separate from container-owned presentation and do not run a continuous scanner merely to feed an editor.

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
| Enhancement aura routing | Requires product change | No formal Food/Flask/Phial/Augment classifier; curated IDs remain exact, while readable semantic metadata is an addon-side experimental technique |
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

**UPDATED RECOMMENDATION:** For future managed player HELPFUL work:

1. Treat saved, manual, or curated numeric IDs as the exact configuration source where known.
2. If optional semantic discovery is used, keep it guarded, player-only, out of combat, and event-driven; do not poll or inspect restricted payloads.
3. Test empty lists, include-only, exclude-only, unchanged sets, and the same ID saved in both legacy lists.
4. Reconfigure the existing group out of combat through `SetAuraGroupCandidateFilters` with complete copied tables.
5. Continue verifying combat-secret, aura refresh, removal, reload, false-positive, and rollback behavior.
6. Do not extrapolate the player HELPFUL result to player HARMFUL, private auras, or native item-enchantment filtering.

## Open Questions and Live Resolutions

1. **RUNTIME TEST REQUIRED:** Does player-BUFFS include/exclude filtering continue correctly through secret-aura combat transitions without addon identity access?
2. **LIVE RUNTIME RESOLUTION:** Post-login out-of-combat candidate-filter reapplication reassigned already-active player HELPFUL rows without container recreation, observed duplication, stale rows, or incorrect managed duration presentation.
3. **RUNTIME TEST REQUIRED:** What happens if the setter is invoked during combat from tainted addon execution? Until tested, OBB should block or queue it.
4. **RUNTIME TEST REQUIRED:** How do private auras interact with configured identity maps for player groups?
5. **RUNTIME TEST REQUIRED:** Does `maxDuration = math.huge` provide reliable timed-only behavior through inbound validation and secret aura updates?
6. **PRODUCT DECISION:** Should player DEBUFFS preserve list controls as inactive/unsupported, restrict them to never-secret IDs, or adopt a different supported policy?
7. **PRODUCT DECISION:** Should enhancement routing remain curated-ID-only, incorporate guarded semantic metadata as an explicitly experimental addon-side technique, or use reduced initial parity?
8. **PRODUCT DECISION:** Which legacy discovered rows, if any, should be persisted before direct scanning is retired?
9. **SOURCE WATCH:** Re-audit identity eligibility, candidate fields, spell metadata, and runtime setters when the Retail source advances beyond `12.1.0.69497`.

**LIVE RESOLUTION:** Current Live preserves the documented candidate fields, setter refresh behavior, and include/exclude precedence while hardening identity eligibility for player/group HELPFUL auras and immune/uninteractable reaction edge cases. Runtime safety of tainted combat-time setter calls remains unproven and must not be inferred from source parity.

## References

### Blizzard Retail Source

- `Blizzard_AuraContainer/Blizzard_AuraContainer.toc`
- `Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua`
- `Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerShared.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerGroups.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerSlots.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerSources.lua`
- `Blizzard_AuraContainer/Blizzard_AuraButton.lua`
- `Blizzard_FrameXMLUtil/AuraUtil.lua`
- `Blizzard_APIDocumentationGenerated/SpellDocumentation.lua`
- `Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua`

### OdysseusBuffBars Read-Only Context

- `OdysseusBuffBars.lua`
- `OdysseusBuffBars_Auras.lua`
- `OdysseusBuffBars_Config.lua`
- `Documentation/ARCHITECTURE.md`
- `Documentation/MANAGED_AURACONTAINER_MIGRATION.md`
