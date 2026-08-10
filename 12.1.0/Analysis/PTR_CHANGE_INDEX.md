# PTR Change Index

## Purpose

This index maps the immutable PTR source notes to the engineering analyses. Source wording remains in `../Source`; these documents interpret it separately.

| Source | Main changes | Analysis |
| --- | --- | --- |
| [PTR1](../Source/Midnight%2012.1.0%20PTR%20Changes%201.txt) | AuraContainer/AuraButton introduction, forbidden model | [AuraContainers](AuraContainers.md), [Security](CombatAndSecurityRestrictions.md) |
| [PTR2](../Source/Midnight%2012.1.0%20PTR%20Changes%202.txt) | Native dispel/tooltip presentation | [Tooltip](TooltipIntegration.md), [Implementation](BlizzardImplementationNotes.md) |
| [PTR3](../Source/Midnight%2012.1.0%20PTR%20Changes%203.txt) | UnitAura restrictions, ManagedAuraContainer | [Architecture](AuraContainerArchitecture.md), [Security](CombatAndSecurityRestrictions.md) |
| [PTR4](../Source/Midnight%2012.1.0%20PTR%20Changes%204.txt) | Groups, slots, automatic buttons, filters/sort/layout, enchants, private auras | [Filters](AuraFilters.md), [Sorting](AuraSorting.md), [API](APIChanges.md) |
| [PTR5](../Source/Midnight%2012.1.0%20PTR%20Changes%205.txt) | New filter tokens and conditional access restrictions | [Filters](AuraFilters.md), [Security](CombatAndSecurityRestrictions.md) |
| [PTR6](../Source/Midnight%2012.1.0%20PTR%20Changes%206.txt) | ApplicationBar, group mutation, layoutIndex, access introspection, sounds | [API](APIChanges.md), [Implementation](BlizzardImplementationNotes.md) |
| [PTR7](../Source/Midnight%2012.1.0%20PTR%20Changes%207.txt) | Columns, combat creation, tooltips, multiple dispel textures, access timing | [Architecture](AuraContainerArchitecture.md), [Tooltip](TooltipIntegration.md), [API](APIChanges.md) |
| [PTR5 Wishlist](../Source/12.1%20Auras%20remaining%20wishlist%20%28PTR%205%29.txt) | Requested gaps after PTR5 | [Open Questions](OpenQuestions.md) |

## Current Source Baseline

**FACT:** The latest inspected implementation is Retail PTR build `12.1.0.68914`, commit `d3915c78a`.

**OBSERVATION:** Several wishlist items were delivered by PTR6/PTR7: tooltip control, shared styling, ApplicationBar, dynamic group filters, combat creation, layout ordering, multiple dispel textures, false candidate values, sounds, and column-capable flow.

**OBSERVATION:** Remaining questions include group/slot enable controls, per-group units, caster display, item-enchantment grouping/filter parity, and exact restricted-runtime behavior.

## OUS Documents

- [Migration Guide](../OUS/BuffBarsMigrationGuide.md)
- [Impact Assessment](../OUS/BuffBarsImpactAssessment.md)
- [Open Questions](../OUS/BuffBarsOpenQuestions.md)
- [Prototype Plan](../OUS/PrototypePlan.md)

