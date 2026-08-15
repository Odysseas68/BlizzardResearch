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
- **RESOLVED SOURCE FACT:** Current Retail 12.1 generated `C_Spell` documentation exposes general spell metadata and predicates but no direct Food, Flask, Phial, or Augment Rune aura categorizer. `IsConsumableSpell` returned false for the three tested consumable-related aura spells, so it cannot be assumed to classify an active aura by its source item. See [Aura Filters](AuraFilters.md).
- **RESOLVED RUNTIME FACT:** Reapplying public candidate filters reassigned already-active readable player HELPFUL rows between managed groups without container recreation, observed duplicates, stale rows, or incorrect duration presentation. This does not resolve combat-time setter safety, harmful/private parity, or every restriction state.
- **RESOLVED RUNTIME FACT:** Guarded out-of-combat semantic rediscovery plus combat deferral/retry worked without polling in the tested scenario. `UNIT_AURA` was treated as a dirty signal; its restricted payload was not used for classification. See [Combat and Security Restrictions](CombatAndSecurityRestrictions.md).
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
- **RESOLVED RESEARCH FINDING:** Food, Flask/Phial, and Augment-related effects in this experiment were ordinary HELPFUL aura spell identities, separate from native MainHand/OffHand temporary-item-enchantment providers. The generated spell namespace supplied useful readable names/descriptions but no formal category API. Routing and presentation remain addon policy.
- **OPEN RESEARCH QUESTION:** Temporary weapon-enchantment display-name resolution remains separate and unresolved; do not infer that semantic HELPFUL-aura metadata resolves the opaque temporary-enchantment ID domain.

### Fishing effects and profession equipment

- **RESOLVED RUNTIME FACT, TESTED BOBBER ONLY:** `Limited Edition Rocket Bobber` appeared as an ordinary player `HELPFUL` aura with spell ID `1222880` through the normal aura/BuffFrame path. No formal Bobber classifier was found. It remains unresolved whether every bobber toy/effect uses an aura or comparable localized metadata. See [Aura Filters](AuraFilters.md).
- **RESOLVED RUNTIME FACT, TESTED FISHING CLIENT:** `C_TradeSkillUI.GetProfessionSlots(Enum.Profession.Fishing)` returned `28`, `29`, and `30`; slot `28` was the fishing tool. Blizzard source independently defines `FishingToolSlot` as `28`. Do not generalize these values to other professions.
- **RESOLVED RUNTIME FACT, TESTED LURE ONLY:** Bright Baubles (item `6532`) produced `TemporaryItemEnchantInfo` on fishing slot `28` through `C_PaperDollInfo.GetTemporaryEnchantmentInfo`; the observed opaque enchant ID was `265`, timed remaining state decreased, natural expiration returned the query to nil, and reapplication restored it. This resolves direct API exposure for the tested lure, not every lure or profession enchant. See [Managed Item Enchantments](AuraEnchantments.md).
- **RESOLVED ARCHITECTURAL FACT:** The public PaperDoll getter can expose the fishing-tool temporary enchant while managed AuraContainer cannot register it. The managed provider's closed MainHand/OffHand/Ranged enum and event path remain unchanged.
- **NARROWED TOOLTIP RESULT:** Slot `28` structured inventory tooltip data exposed generic localized text equivalent to `Fishing Lure (+7 Fishing Skill) (8 min)` as line type `0`, but did not expose the original `Bright Baubles` item identity. Reliable source-item-name resolution remains open. See [Tooltip Integration](TooltipIntegration.md).
- **OPEN RUNTIME QUESTION:** Does restricted `C_PaperDollInfo.CancelTemporaryEnchantment(28)` support profession-tool lure cancellation? Generated documentation speaks broadly about inventory-slot items, but does not explicitly guarantee arbitrary profession slots; inspected Blizzard callers cover only MainHand, OffHand, and Ranged. Do not claim support until tested deliberately.
- **OPEN EVENT QUESTION:** No generated event contract was found that guarantees notification specifically when a profession-tool temporary enchant is applied or naturally expires. Determine which change events are reliable in broader runtime testing; expected-expiration rechecks remain an implementation technique, not a Blizzard-required event recipe.

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
