# BuffBars Open Questions

## Must Resolve Before Production Design

1. Can AuraButton descendants reproduce the required horizontal bar layout without forbidden-layout errors?
2. Should each movable OUS group own one container, or should one container coordinate all groups?
3. Can group frames be safely anchored under OUS movable parents during combat and resizing?
4. Do native filters express timed-only and timeless-only views?
5. Do whitelist/blacklist spell-ID filters work for the intended player aura combinations in restricted content?
6. Can settings changes be applied safely at runtime, and which must be deferred until combat ends?
7. Does native item-enchantment integration expose enough data for baseline parity?
8. Does native cancellation cover ordinary buffs, timeless forms, and temporary weapon enchants exactly as needed?
9. Do native tooltips remain useful when configured to hide in combat or when auras are private/secret?
10. Which API names and option structures survive unchanged into 12.1 Live?

## Product Decisions

- Preserve, redesign, or retire automatic consumable/enhancement classification?
- Preserve arbitrary chained group anchoring, or simplify placement?
- Include advanced overrides in the first release, or stage them after baseline parity?
- Keep the Blizzard-frame visibility option independent from BuffBars enablement?
- Use ApplicationBar and aura sounds, or defer them as enhancements?

## Evidence Needed

- 12.1 Live source diff against PTR build 68914
- Login/load timing trace
- Open-world and training-dummy combat
- Dungeon and raid restricted combat
- Private aura encounter/sample
- Player buff/debuff whitelist and blacklist cases
- Main-hand and off-hand temporary enchant cases
- UI scale, frame scale, resize, and anchor-chain cases
- Reload and SavedVariables migration cases

## Explicit Non-Assumptions

**ASSUMPTION:** None of the following are considered proven by source inspection:

- That every public-looking method is callable by addon code in all contexts
- That combat-time creation implies unrestricted combat-time configuration
- That generated API documentation exactly matches runtime behavior
- That one-container or multi-container ownership is superior for OUS
- That PTR behavior will ship unchanged

