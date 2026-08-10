# BuffBars Migration Guide

## Scope

This document maps the frozen Retail 12.0.x `OdysseusBuffBarsTest` behavior to the Retail 12.1 AuraContainer framework. It is planning evidence only; no addon implementation is authorized.

## Migration Principle

**RECOMMENDATION:** Preserve user-visible behavior where it remains valuable, not the obsolete direct-scanning implementation. Prefer the secure framework for aura dataflow and retain OUS ownership of product policy, settings, and bar presentation.

## Feature Mapping

| Frozen feature | Existing approach | Closest 12.1 mechanism | Reuse | Replace | Retire | Rewrite | Risk | Confidence | Required validation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Aura discovery | `GetAuraDataByIndex` loop | Managed sources and groups | No | Yes | Direct scan | Container declaration | High if direct path remains | High | Restricted combat receives complete updates |
| Incremental identity | Cache by `auraInstanceID` | Managed secure cache/events | No | Yes | Local fallback cache | None unless UI policy needs metadata | Medium | High | Add/update/remove behavior across combat |
| Helpful/harmful groups | Separate filter scans | Group filter strings | Policy | Engine | Duplicate scans | Group setup | Low | High | HELPFUL/HARMFUL parity |
| Whitelist | Lua spell-ID table | `includeSpellIDs` | Saved data | Evaluation | Lua pass | Candidate filter translation | Medium | Medium | Allowed identity filters in combat |
| Blacklist | Lua spell-ID table | `excludeSpellIDs` | Saved data | Evaluation | Lua pass | Candidate filter translation | Medium | Medium | Allowed identity filters in combat |
| Hidden override | Lua spell-ID override | Exclude IDs | Saved data | Evaluation | Duplicate hidden pass | Merge policy into group filters | Medium | Medium | Conflicts with whitelist/routing |
| BUFFS/ENCHANTMENTS routing | Name/ID classification | Multiple groups + candidate IDs; native enchants separate | User policy | Aura selection | Name heuristics where possible | Curated stable-ID routing | High | Medium-low | Secret combat and unknown consumables |
| Enhancement name heuristics | Lowercase/read aura name | No name candidate filter | No | No direct equivalent | Prefer retirement | Curated presets/manual routing | High | High | Product decision required |
| Time-left sort | `GetUnitAuraInstanceIDs(ExpirationOnly, Reverse)` | Group native sort | User setting | Engine | Frozen adapter | Map label/direction | Low | High | Shortest/longest order examples |
| Name sort | Native sorted IDs | `NameOnly` | User setting | Engine | Frozen adapter | Map label | Low | High | Locale behavior |
| Default sort | Native sorted IDs | `Default` | User setting | Engine | Frozen adapter | Map label | Low | High | User-visible ordering |
| Timed/timeless toggles | Lua `expires` checks | Partial candidate capabilities | Setting intent | Maybe | Secret expiration inspection | Separate declarative groups if possible | High | Low | Find supported timeless selector |
| Maximum bars | Lua rendering cap | Group max frame count | Setting | Engine | Lua truncation | Map value | Low | High | Dynamic updates and zero value |
| Bar pool | Addon frames reused | AuraButton provider pool | Visual descendants | Button identity/pool | OUS aura-frame pool | AuraButton initializer | Medium | High | Creation/reuse and settings refresh |
| Bar dimensions | Ordinary frames | Group element width/height | Values | Layout engine | Manual row positions inside container | Map to group layout | Medium | Medium | Resize, wrapping, scale, long text |
| Movable groups | OUS group frames and chains | No product-level equivalent | Yes | No | Combat anchor rebuilds | OUS parent hierarchy around containers | High | Medium-low | Forbidden layout and anchor behavior |
| Grow up/down | Manual anchor direction | Flow/group layout | Setting intent | Layout | Manual bar anchoring | Map growth options | Medium | Medium | Separate group/container strategy |
| Icon | Addon texture from aura data | `SetIcon` display component | Visual design | Data feed | Secret icon extraction | Configure descendant texture | Medium | High | Secret transition, fallback behavior |
| Spell name | Addon FontString | `SetSpellName` | Visual design | Data feed | Name cache/fallback | Configure descendant text | Medium | High | Secret combat and truncation |
| Stack count | Addon FontString | ApplicationCount | Visual design | Data feed | Count comparison/formatting | Configure native formatter | Medium | High | Zero/one/many and secret values |
| Duration text | Duration object + formatter | DurationText | Formatter intent | Data binding | Addon OnUpdate formatting | Configure native duration text | Medium | High | Timeless, sub-minute, long durations |
| Duration fill | StatusBar timer duration | DurationBar | Art/behavior intent | Data binding | Addon timer management | Configure native duration bar | Medium | High | Direction and timeless state |
| Cooldown display | Not primary | DurationCooldown | Optional | Native | N/A | Optional later | Low | High | Only if adopted |
| Dispel indicator | Limited/custom | Dispel text/textures | Visual design | Data binding | Secret dispel inspection | Configure style/map | Medium | High | Multiple dispel types and no-type key |
| Application bar | Not present | ApplicationBar | No | Native | N/A | Optional enhancement | Medium | Medium | Interpolation/max behavior |
| Tooltips | `SetUnitAura` by scan index | Native AuraButton tooltip | Anchor preference | Identity/data | Index tooltip path | Set anchor/hide policy | High if old path remains | High | Combat/private/enchant tooltips |
| Buff cancellation | Secure overlay with aura index | `SetCancelAuraButtons` | Right-click UX | Secure action | Overlay buttons/index attributes | Native cancellation setup | High | Medium-high | Combat and timeless forms |
| Enchant cancellation | Secure target-slot overlay | Native enchant cancellation | Right-click UX | Secure action | Target-slot overlay | Native enchant entry | Medium | Medium | Main/off-hand behavior |
| Weapon enchant scan | `GetWeaponEnchantInfo` synthetic rows | `AddItemEnchantment` | Display policy | Source | Synthetic rows | Configure native entries | Medium | Medium | Charges, labels, icons, timers, tooltips |
| Private auras | Not directly supported | Private source/tooltip | No | Framework | Any extraction attempt | Accept native behavior | High | High | Confirm expected limited display |
| Sounds | None | `AddAuraSound` | No | Native optional | N/A | Defer | Low | Medium | Live API and user value |
| Hide Blizzard frames | OUS preference/retry | Separate from AuraContainer | Yes | No | Frame harvesting (already rejected) | Keep independent policy | Medium | High | Edit Mode and combat behavior |
| Settings/config | Native addon UI and SavedVariables | No replacement | Yes | No | Direct engine internals | Bind through OUS public helpers | Medium | High | Reload, defaults, migration |

## Proposed Ownership Boundary

### Framework-Owned

- Public/private/enchantment source observation
- Aura identity and AuraButton lifecycle
- Secret-sensitive filtering and sorting
- Duration, application, dispel, icon, name, tooltip, and cancellation data binding
- Incremental refresh and secure caches

### OUS-Owned

- SavedVariables schema and migration
- User-facing group definitions and presets
- Bar visual composition and typography
- Movable parent frames, group relationships, and configuration UI
- Product decisions for overrides, consumables, and Blizzard-frame visibility

## Migration Order

1. Prove one player HELPFUL container with native name/icon/duration/count.
2. Add HARMFUL and native sorting.
3. Prove whitelist/blacklist candidate filters under restricted combat.
4. Prove OUS bar descendants and movable parent behavior.
5. Prove tooltips and cancellation.
6. Prove item enchantments.
7. Decide routing/timed/timeless gaps.
8. Compare full parity and only then design production module boundaries.

**RECOMMENDATION:** A failed required gate returns the design to research. It does not justify silently falling back to direct restricted scans.

