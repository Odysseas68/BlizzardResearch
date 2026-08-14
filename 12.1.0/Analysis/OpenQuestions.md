# Open Questions

## Framework Contract

- **FACT:** Core ownership is clear; exact public layout/presentation names changed late in PTR.
- **QUESTION:** Which methods/options ship unchanged in 12.1 Live?
- **VALIDATION:** Diff Live `Blizzard_AuraContainer` and generated docs against PTR build 68914.

## Access and Combat

- **QUESTION:** Which AuraButton configuration methods remain callable from addon code after login in open world, combat, dungeon, and raid contexts?
- **QUESTION:** Does `CanBeAccessedInContext` provide sufficient diagnostics without itself becoming inaccessible?
- **VALIDATION:** Exercise each required runtime mutation before/after PLAYER_LOGIN and in restricted combat.

## Filtering

- **QUESTION:** What exact spell-ID identity-filter combinations are accepted for player helpful/harmful auras in restricted contexts?
- **QUESTION:** Is there a supported timeless-only selector?
- **QUESTION:** Can group/slot sources be enabled or disabled without rebuilding configuration?
- **UNVERIFIED EXTERNAL RESEARCH LEAD:** Independently investigate the current Live managed AuraContainer contract and OBB applicability corresponding to reported self-cast and maximum-duration filtering. An external aura-addon developer, Elkano (ElkBuffBars), stated that the 12.1 rewrite expects to retain those filters while most legacy filters are no longer available. This is not Blizzard documentation, does not establish API names or implementation details, and must be verified independently against current Blizzard Live source before OBB uses it.
- **LOW-PRIORITY UNVERIFIED EXTERNAL OBSERVATION:** The same statement reports that buffs, debuffs, and temporary enchantments are no longer mixed. Treat this only as a lead about another addon's design; the separate managed paths documented in this repository rest on independent Blizzard-source research, not this statement.

## Layout

- **QUESTION:** Can independently movable OUS groups be represented cleanly by separate containers, or can one container expose enough group frames without restricted anchor conflicts?
- **QUESTION:** How do flow wrapping, group auto-size, and OUS parent dimension scaling interact at non-default UI scales?
- **QUESTION:** Is `ResizeToBoundsRect` relevant to addon consumers, or only a generic protected helper?

## Enchantments

- **RESOLVED SOURCE FACT:** Item enchantments use a parallel managed provider/frame path and do not participate in AuraGroups, AuraSlots, parsing, or candidate filters. See [Managed Item Enchantments](AuraEnchantments.md).
- **RESOLVED SOURCE FACT:** Native icon, equipped-item name, charges, duration, inventory tooltip, cancellation target, sorting, and self-sizing are supported. An enchantment-specific display name and aura-style filtering are not.
- **RESOLVED RUNTIME FACT:** Thalassian Phoenix Oil cold-logins exposed the record as present-incomplete on inventory callback 1 but only timed-ready at callback ordinals 69, 105, or 430. `UNIT_INVENTORY_CHANGED` is useful startup activity evidence, not a readiness contract or stable ordinal; fixed callback counts are rejected. See [Managed Item Enchantments](AuraEnchantments.md).
- **VALIDATED LIVE LIFECYCLE:** The generation-based `C_Timer.After(0)` quiet-turn coalescer passed two genuine cold character logins with Phoenix Oil active on MainHand. The managed row and timer appeared automatically without manual refresh, stale zero-duration state, or duplication. Reload, native cancellation in the tested context, fresh reapplication, and the native inventory tooltip also passed. The validated prototype performs no PaperDoll inspection, polling, fixed delay, fixed callback counting, synthetic fallback, or per-event managed refresh.
- **COMPARATIVE RESEARCH LEAD:** The original ElkBuffBars r223 alpha is available locally at `D:\WoWDEV\Reference\ThirdParty\ElkBuffBars-r223-alpha\`. Initial in-game observation found a very early alpha with BUFFS display available, no settings UI observed, and no temporary enchantments exposed in the tested alpha. It therefore provided no runtime comparison for this startup issue. Its source was not audited here; infer no implementation details without a future audit.
- **RUNTIME QUESTION:** Validate OffHand, simultaneous MainHand/OffHand, Ranged where usable, permanent/zero-duration results, broader temporary-enchantment coverage, and cancellation in combat. The tested MainHand native inventory tooltip works, but exact tooltip contents do not provide a supported enchant-name resolver.
- **RUNTIME QUESTION:** Which current Retail runtime, if any, can practically exercise the declared ranged slot `18` provider?
- **NEXT RESEARCH TOPIC:** Decide how managed OBB should route Food, Flask, and similar HELPFUL enhancement auras. Legacy OBB places them in ENCHANTMENTS; the managed prototype naturally exposes them through BUFFS. This is separate from native MainHand/OffHand item-enchantment lifecycle and requires an explicit routing/presentation policy.

## Presentation

- **QUESTION:** Is the no-dispel custom text key `""` or `"None"`? Generated documentation and helper behavior appear inconsistent.
- **QUESTION:** Are application/dispel/duration child APIs stable across secret transitions without addon refresh?
- **QUESTION:** Does global tooltip styling create compatibility concerns with other addons using AuraContainer?

## Private Auras

- **QUESTION:** What visual information is intentionally available for private auras in a custom container?
- **RECOMMENDATION:** Accept framework behavior; do not design OUS logic around private aura identity.

## Product Policy

- **QUESTION:** Should OUS preserve consumable auto-classification, replace it with curated spell-ID presets, or omit it initially?
- **QUESTION:** Should BuffBars remain separate movable groups, or adopt one coordinated layout surface?
- **QUESTION:** Which frozen features are required for the first 12.1 release versus later parity?
