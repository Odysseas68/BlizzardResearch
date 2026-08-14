# PTR Change Index

## Purpose

This index maps the immutable PTR source notes to the engineering analyses. Source wording remains in `../Source`; these documents interpret it separately.

| Source | Main changes | Analysis |
| --- | --- | --- |
| [PTR1](../Source/Midnight%2012.1.0%20PTR%20Changes%201.txt) | AuraContainer/AuraButton introduction, forbidden model | [AuraContainers](AuraContainers.md), [Security](CombatAndSecurityRestrictions.md) |
| [PTR2](../Source/Midnight%2012.1.0%20PTR%20Changes%202.txt) | Native dispel/tooltip presentation | [Tooltip](TooltipIntegration.md), [Implementation](BlizzardImplementationNotes.md) |
| [PTR3](../Source/Midnight%2012.1.0%20PTR%20Changes%203.txt) | UnitAura restrictions, ManagedAuraContainer | [Architecture](AuraContainerArchitecture.md), [Security](CombatAndSecurityRestrictions.md) |
| [PTR4](../Source/Midnight%2012.1.0%20PTR%20Changes%204.txt) | Groups, slots, automatic buttons, filters/sort/layout, enchants, private auras | [Filters](AuraFilters.md), [Sorting](AuraSorting.md), [Enchantments](AuraEnchantments.md), [API](APIChanges.md) |
| [PTR5](../Source/Midnight%2012.1.0%20PTR%20Changes%205.txt) | New filter tokens and conditional access restrictions | [Filters](AuraFilters.md), [Security](CombatAndSecurityRestrictions.md) |
| [PTR6](../Source/Midnight%2012.1.0%20PTR%20Changes%206.txt) | ApplicationBar, group mutation, layoutIndex, access introspection, sounds | [API](APIChanges.md), [Implementation](BlizzardImplementationNotes.md) |
| [PTR7](../Source/Midnight%2012.1.0%20PTR%20Changes%207.txt) | Columns, combat creation, tooltips, multiple dispel textures, access timing | [Architecture](AuraContainerArchitecture.md), [Tooltip](TooltipIntegration.md), [API](APIChanges.md) |
| [PTR5 Wishlist](../Source/12.1%20Auras%20remaining%20wishlist%20%28PTR%205%29.txt) | Requested gaps after PTR5 | [Open Questions](OpenQuestions.md) |

## Current Source Baseline

**FACT:** The current inspected implementation is Retail Live build `12.1.0.69299`, interface `120100`, commit `31c7f7b9c`. The previous completed Live audit was build `12.1.0.69273`, commit `eb941aad0`; no AuraContainer, PaperDoll enchantment, layout, or aura-documentation files changed between those revisions.

**OBSERVATION:** Several wishlist items were delivered by PTR6/PTR7: tooltip control, shared styling, ApplicationBar, dynamic group filters, combat creation, layout ordering, multiple dispel textures, false candidate values, sounds, and column-capable flow.

**OBSERVATION:** Remaining questions include group/slot enable controls, per-group units, caster display, item-enchantment grouping/filter parity, and exact restricted-runtime behavior.

## Live 12.1 Aura Architecture Audit

### Baseline

- **Current Live follow-up:** commit `31c7f7b9c`; `version.txt` = `12.1.0.69299`; Mainline interface `120100`; no aura-relevant changes from the completed Live audit.
- **Completed Live audit:** commit `eb941aad0`; `version.txt` = `12.1.0.69273`; Mainline interface `120100`.
- **PTR:** commit `6e348870e`; `version.txt` = `12.1.0.69273`.
- **Earlier documented checkpoints:** architecture build 68914 / `d3915c78a`; filtering build 69189 / `a520b6c27`.

**FACT:** Direct comparisons found no file differences between final Live and final PTR in `Blizzard_AuraContainer`, `Blizzard_BuffFrame`, all generated API documentation, `Blizzard_FrameXMLUtil`, `Blizzard_SharedXMLBase`, `Blizzard_SharedXML`, `Blizzard_UnitFrame/Shared`, `Blizzard_EditMode`, or `Blizzard_RestrictedAddOnEnvironment`.

### Material Changes

**LIVE VS FINAL PTR:** None. AuraContainer lifecycle, managed layout/self-sizing, AuraButton presentation, sorting, candidate filtering, tooltip behavior, security restrictions, BuffFrame ownership, and item enchantments are source-identical.

**OLDER PTR CHECKPOINT VS FINAL:** The late PTR series added disabled-container clearing for parsed auras and active enchantments, moved tooltip refresh ownership to the shared forbidden tooltip, routed addon-template frame creation through the global environment, refined default duration formatting, and added optional pandemic-region and stealable/always-show dispel presentation. These changes were already present by `a520b6c27`; no aura-relevant change occurred from that checkpoint to final PTR. They are additive or lifecycle hardening and do not invalidate the enabled managed BUFFS implementation.

### Non-Material Changes and Documentation Classification

- The large Live landing is branch synchronization, not an independent aura redesign relative to final PTR.
- Generated AuraContainer documentation is also identical between final PTR and Live. It documents `C_AuraContainerUtil` processors, option structures, and selected enums; it does not promote all template/mixin methods or private managed mixins into generated public namespace APIs.
- No new public layout-completion callback, active-button enumerator, container sizing method, or per-container tooltip API appeared.

### BUFFS Compatibility

**CONCLUSION:** The validated Phase B.2 architecture remains supported unchanged: ordinary position root -> self-sizing `CustomAuraContainer` -> container-owned `AuraButton` descendants. `SetIcon`, `SetSpellName`, `SetApplicationCount`, `SetDurationText`, `SetDurationBar`, native tooltip, right-click cancellation, retained/recycled buttons, one-shot dirty updates, and FlowLayout self-sizing remain intact.

The OBB sorting mappings remain valid:

```text
Default   -> AuraContainerSortMethod.Default        + AuraContainerSortDirection.Normal
Name      -> AuraContainerSortMethod.NameOnly       + AuraContainerSortDirection.Normal
Time Left -> AuraContainerSortMethod.ExpirationOnly + AuraContainerSortDirection.Reverse
```

The BUFFS filter compilation rule remains valid:

```text
whitelist non-empty -> includeSpellIDs = whitelist; excludeSpellIDs = nil
whitelist empty     -> includeSpellIDs = nil;       excludeSpellIDs = blacklist
```

Managed exclusion is evaluated before inclusion, so omitting the blacklist in whitelist mode remains required for legacy whitelist-wins parity.

### Security and Tooltips

**CONCLUSION:** Existing security conclusions are unchanged. Indexed, slot, instance-ID, and enumeration APIs retain UnitAura access restrictions; non-secret requirements remain; AuraButtons retain conditional tainted-access restrictions and forbidden parent/script/layout operations. Final source parity must not be described as proof that untested combat-time mutations are safe.

Managed AuraButton tooltips remain preferred. Ordinary auras use the native managed `ShowAuraTooltip` path and item enchantments use inventory-item tooltips. Legacy scan-index tooltip suppression on 12.1+ remains justified for OBB's managed path.

### BuffFrame Visibility

**SOURCE FACT:** `BuffFrame` and `DebuffFrame` inherit `AuraFrameEditModeTemplate`. The shared event listener registers `PLAYER_IN_COMBAT_CHANGED` and calls `UpdateShownState()` on each transition. `ShouldBeShown()` returns the Edit Mode visibility policy (`Always`, `InCombat`, or `Hidden`; default fallback true), and `UpdateShownState()` calls `SetShown(shouldBeShown)`.

**CONCLUSION:** A direct addon `BuffFrame:Hide()` does not change Blizzard's visibility policy. If the policy is `Always` (or falls back to true), the combat transition explicitly reasserts visibility, which matches the observed icons reappearing in combat and disappearing again when OBB reapplies its preference out of combat. This is Blizzard/Edit Mode ownership, not AuraContainer ownership or a state-driver finding.

**SUPPORTED SOURCE-BACKED OPTION:** The built-in Edit Mode visibility setting `Hidden` is the supported user-facing way to keep each aura frame hidden. The audited source exposes no documented addon-facing API whose contract is "disable the default BuffFrame" or safely rewrite another system's Edit Mode setting. Any programmatic OBB integration requires a separate runtime/product decision; source alone does not justify fighting `UpdateShownState()` with hooks or repeated hides.

### DEBUFFS Readiness

Detailed player-HARMFUL architecture, filtering, private-aura, presentation, sorting, legacy-compatibility, and prototype findings are maintained in [Managed Player HARMFUL Auras](AuraHarmful.md).

**SOURCE FACT:** A custom player DEBUFFS group uses the same long-lived managed container with unit `player`, a group filter string containing `HARMFUL`, and the ordinary group options/sort/layout surface. Public and private aura sources both feed the managed group pipeline.

**CONSTRAINT:** For harmful auras on an assistable unit such as `player`, `CanApplyIdentityCandidateFilters` skips both `includeSpellIDs` and `excludeSpellIDs` unless the spell's aura secrecy is `NeverSecret`. When identity maps are skipped, the aura is not rejected; non-identity candidate filters still run. Private harmful auras use the separate private source but the same filter and identity-eligibility logic. Tooltips remain native; cancellation behavior is the same AuraButton path, although harmful player auras generally are not cancelable. Sorting is unchanged.

**READINESS:** The Live managed HARMFUL architecture is ready for an isolated DEBUFFS prototype, but exact whitelist/blacklist parity is not generally available for player debuffs. Scope the next slice around broad managed HARMFUL display, native presentation/tooltips/sorting, never-secret identity-filter cases, and private/secret runtime validation before making a product decision about DEBUFFS list controls.

### Managed Item Enchantments

Detailed current-Live provider, presentation, naming, duration, tooltip, cancellation, sorting, filtering, layout, security, legacy-compatibility, architecture, and prototype findings are maintained in [Managed Item Enchantments](AuraEnchantments.md).

**SOURCE FACT:** Live provides native managed temporary weapon-enchantment support through `CustomAuraContainerSharedMixin:AddItemEnchantment` and the container-owned item-enchantment manager. It uses fixed player-owned main-hand/off-hand/ranged slots backed by `C_PaperDollInfo.GetTemporaryEnchantmentInfo`, produces AuraButton-compatible data, and participates in the custom container's FlowLayout with independent slot/duration sorting and layout options.

The native row exposes equipped-item icon and name, charges as applications, a snapshotted duration and expiration, inventory-item tooltip, and `C_PaperDollInfo.CancelTemporaryEnchantment` cancellation. It is clearly reusable by a `CustomAuraContainer`, but it bypasses aura groups, slots, and candidate filters; the displayed name is the equipped item name rather than a guaranteed enchantment name.

**VALIDATED LIVE STATUS:** A third independent `CustomAuraContainer` with MainHand/OffHand registrations now has a validated cold-login lifecycle using generation-based quiet-turn coalescing. Two genuine cold logins with MainHand Thalassian Phoenix Oil produced the managed row and timer automatically; reload, tested-context cancellation, fresh reapplication, and the native inventory tooltip also passed. OffHand runtime, simultaneous slots, Ranged, permanent entries, combat cancellation, broad enchant coverage, enchant-name resolution, and HELPFUL Food/Flask routing retain the exact limits and open requirements documented in the dedicated analysis.

## OUS Documents

- [Migration Guide](../OUS/BuffBarsMigrationGuide.md)
- [Impact Assessment](../OUS/BuffBarsImpactAssessment.md)
- [Open Questions](../OUS/BuffBarsOpenQuestions.md)
- [Prototype Plan](../OUS/PrototypePlan.md)
