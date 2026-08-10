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

## Layout

- **QUESTION:** Can independently movable OUS groups be represented cleanly by separate containers, or can one container expose enough group frames without restricted anchor conflicts?
- **QUESTION:** How do flow wrapping, group auto-size, and OUS parent dimension scaling interact at non-default UI scales?
- **QUESTION:** Is `ResizeToBoundsRect` relevant to addon consumers, or only a generic protected helper?

## Enchantments

- **QUESTION:** Can item enchantments participate in ordinary groups/candidate filters?
- **QUESTION:** Are enchantment name, icon, duration, charges, tooltip, and cancellation all sufficient for BuffBars parity?
- **QUESTION:** What is the purpose of the ranged slot on current Retail equipment paths?

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

