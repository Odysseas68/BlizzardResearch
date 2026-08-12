# AuraContainers

## Summary

**FACT:** Across PTR1-PTR7, Blizzard replaced addon-owned aura scanning/frame attachment with a secure, container-owned model built from AuraButtons, groups, slots, source adapters, native filtering/sorting, and managed layout.

**ANALYSIS:** The trend is not merely API deprecation. It is a transfer of secret-sensitive dataflow and object ownership from addon Lua to Blizzard-controlled execution.

## Live 12.1 Confirmation

**FACT:** Retail Live commit `eb941aad0` (`12.1.0.69273`, interface `120100`) and final PTR commit `6e348870e` have identical aura-relevant source trees.

**LIVE CONCLUSION:** Container ownership, managed parsing, group/slot/enchantment selection, AuraButton creation and presentation, and secure/native data propagation reached Live without an architectural break. The earlier recommendation to wait for Live was a PTR-stage gate; the source gate is now satisfied for the already-validated managed BUFFS slice. Runtime validation remains required for new feature slices and for any untested restricted context.

## Source Documents

- [PTR Changes 1](../Source/Midnight%2012.1.0%20PTR%20Changes%201.txt)
- [PTR Changes 2](../Source/Midnight%2012.1.0%20PTR%20Changes%202.txt)
- [PTR Changes 3](../Source/Midnight%2012.1.0%20PTR%20Changes%203.txt)
- [PTR Changes 4](../Source/Midnight%2012.1.0%20PTR%20Changes%204.txt)
- [PTR Changes 5](../Source/Midnight%2012.1.0%20PTR%20Changes%205.txt)
- [PTR Changes 6](../Source/Midnight%2012.1.0%20PTR%20Changes%206.txt)
- [PTR Changes 7](../Source/Midnight%2012.1.0%20PTR%20Changes%207.txt)
- [PTR5 Wishlist](../Source/12.1%20Auras%20remaining%20wishlist%20%28PTR%205%29.txt)

## Timeline

### PTR1

**FACT:** Introduced AuraContainer, AuraButton, Private Script Objects, Forbidden Partitions/Aspects, and the original manual `AddAuraFrame` concept. UnitAura restrictions were announced.

**ANALYSIS:** This established the security vocabulary and a native aura object, but still assumed substantial addon frame ownership.

### PTR2

**FACT:** Added dispel border/symbol and tooltip facilities and expanded Forbidden Aspect behavior.

**ANALYSIS:** Native presentation began replacing unsafe extraction of aura values into addon text and textures.

### PTR3

**FACT:** Applied most UnitAura restrictions, introduced `ManagedAuraContainer`, converted TargetFrame, and previewed automatic button creation/filtering/sorting.

**ANALYSIS:** The managed model became the preferred migration direction.

### PTR4

**FACT:** Removed `AddAuraFrame`; introduced AuraGroups, AuraSlots, automatic AuraButton creation, candidate filters, native sort/layout, private auras, item enchantments, cancel behavior, negated filters, and Mainline removal of `SecureAuraHeaderTemplate`.

**ANALYSIS:** This was the architectural break from addon-owned aura enumeration.

### PTR5

**FACT:** Restored `IMPORTANT`, added `DISPELLABLE`, expanded `RAID_PLAYER_DISPELLABLE`, and made initialized AuraButtons conditionally inaccessible to addons when auras are secret.

**ANALYSIS:** Blizzard hardened access without making buttons permanently inaccessible in ordinary contexts.

### PTR6

**FACT:** Added group frame access, dynamic filter strings, ApplicationBar, color maps/curves, `layoutIndex`, tooltip spell-ID diagnostics, aura sounds, access introspection, non-secret spell-ID identity filtering, and enchantment cancellation. Addon-created AuraButtons and configured children became non-reparentable.

**ANALYSIS:** PTR6 broadened declarative rendering while closing ownership escape hatches.

### PTR7

**FACT:** Added column flow, combat-time container creation, per-button tooltip anchors and combat hiding, global tooltip styling, `AuraInstanceIDOnly` sorting, multiple dispel textures, `ResizeToBoundsRect`, post-login access enforcement, and stronger child reparent restrictions.

**ANALYSIS:** PTR7 resolved many PTR5 wishlist gaps but also refactored layout and access timing, evidence that the public surface was still moving.

## Core API Evolution

**FACT:** Current source uses `Get/SetFlowLayoutAxis`, `Get/SetFlowLayoutAnchorPoint`, `Get/SetFlowLayoutGrowthDirection`, `Get/SetFlowLayoutPadding`, `Get/SetFlowLayoutMaximumLineSize`, and `ResetFlowLayoutOptions`.

**FACT:** Earlier `AuraLayout*` methods and `RowWidth` terminology are superseded in build 68914. Group fields also changed from X/Y/row terminology to element, line, group, and group-line spacing.

**RECOMMENDATION:** Treat earlier PTR API spellings as historical. Bind prototypes to the exact build under test and re-audit at Live.

## Security Model

**FACT:** AuraButton identity and display descendants are protected by Forbidden Aspects and conditional tainted-access restrictions. UnitAura APIs can be unavailable or return secret values in restricted contexts.

**ANALYSIS:** A migration that keeps direct scans as its primary engine preserves the exact risk Blizzard is removing. Native groups, filters, sorting, and display components should be the default path.

## Managed Layout Model

**FACT:** Groups and enchantments are ordered by `layoutIndex`; registration order is the fallback. FlowLayout supports horizontal/vertical primary axes, growth directions, wrapping by maximum line size, padding, and automatic container resizing.

**FACT:** AuraSlots remain explicit fixed placements rather than flow groups.

**ANALYSIS:** The container can generate rows or columns of AuraButtons, but it does not provide OUS movable group anchors, chained group placement, settings UI, or bar-specific visual semantics.

## Filtering and Sorting

**FACT:** Filter strings provide broad Blizzard categories; candidate filters refine each candidate by spell identity, dispel type, duration, processed aura type, and boolean aura traits. Native sorts include default, defensive, debuff, important, expiration, name, and instance-ID variants.

**ANALYSIS:** Most frozen BuffBars whitelist/blacklist and time/name sort policy maps directly. Consumable/enhancement name heuristics do not.

## Migration Impact

**RECOMMENDATION:** Addon authors should:

- Let the container own aura discovery and AuraButton creation.
- Express broad selection through filter strings and exact selection through candidate filters.
- Use native sorting instead of comparing secret fields in Lua.
- Build visual descendants in the initialization callback and avoid reparenting.
- Treat direct UnitAura access as optional diagnostics/fallback only when explicitly permitted.
- Validate combat, instance, private-aura, tooltip, cancellation, and login timing behavior in game.

## OUS / BuffBars Impact

**OBSERVATION:** The frozen reference directly scans by index, caches by aura instance ID, requests duration objects, obtains sorted IDs, synthesizes weapon enchantments, builds ordinary bars, and overlays secure cancel buttons.

**ANALYSIS:** The likely 12.1 boundary is:

- **Replace:** direct scans, local sorting, aura-button lifecycle, secret-field fallback caches, and synthetic enchantment discovery where native coverage is sufficient.
- **Adapt:** whitelist/blacklist, routing rules, duration/application/dispel presentation, tooltip, and cancellation into framework configuration.
- **Retain:** SavedVariables policy, settings UI, movable group placement, bar styling, cross-group design, and Blizzard-frame visibility preference.

**RECOMMENDATION:** Keep production BuffBars postponed until 12.1 Live. Use a separate PTR prototype to prove feature parity before any OUS code is designed.

**LIVE STATUS:** This historical PTR recommendation has been satisfied for the managed player-BUFFS prototype: final Live matches final PTR source, and the listed BUFFS behaviors were already validated on PTR. It does not automatically clear DEBUFFS, BuffFrame automation, or enchantment parity, which retain the specific constraints documented in the Live audit.

## Open Questions

- Can one container/group model satisfy independent movable OUS groups without awkward parent restrictions?
- Are all required native methods callable from addon code in restricted combat after login?
- Does item-enchantment data expose enough information for OUS labels, tooltips, sorting, and filters?
- Can consumable routing avoid name inspection using stable spell-ID policy alone?
- Does tooltip combat hiding meet OUS expectations across all restricted content?

## References

- [Architecture](AuraContainerArchitecture.md)
- [Filters](AuraFilters.md)
- [Sorting](AuraSorting.md)
- [Migration Guide](../OUS/BuffBarsMigrationGuide.md)
