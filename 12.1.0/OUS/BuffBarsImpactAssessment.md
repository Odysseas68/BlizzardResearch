# BuffBars Impact Assessment

## Executive Assessment

**ANALYSIS:** The AuraContainer framework is a favorable long-term foundation for BuffBars because it directly addresses the 12.0.x proof-of-concept's largest liabilities: secret aura access, local identity caches, structural combat deferral, manual sort queries, index-based tooltips, and secure cancellation overlays.

**ANALYSIS:** It is not a drop-in port. OUS must rebuild the aura engine boundary around Blizzard-owned AuraButtons while preserving its own bar UX and configuration model.

## Impact by Area

### BuffBars

**Opportunity:** Native source/filter/sort/display behavior can substantially reduce secret-sensitive addon code.

**Risk:** Movable groups, chained placement, timed/timeless selection, and consumable routing are not proven by source inspection alone.

**Recommendation:** Keep implementation postponed until 12.1 Live and require a separate prototype.

### Future Aura Modules

**Opportunity:** Groups, slots, private aura handling, application bars, multiple dispel textures, and item enchantments support future compact aura surfaces beyond BuffBars.

**Risk:** Shared global tooltip style and container-level ownership could create cross-module coupling if wrapped carelessly.

**Recommendation:** If the prototype succeeds, define one small OUS aura-framework adapter rather than duplicating setup across modules.

## Architecture Consequences

**ANALYSIS:** The old proposed `BuffBars_Auras.lua` scanner should not be ported as-is. Its policy concepts may survive, but its acquisition/cache responsibilities belong to AuraContainer.

**ANALYSIS:** The visual layer can remain OUS-specific if bar textures, text, and status components are direct AuraButton descendants configured through native APIs.

**ANALYSIS:** Independent movable groups may favor one CustomAuraContainer per OUS group. A single container is more efficient conceptually but may complicate independent anchors and unit/filter policy. This remains a prototype decision.

## Security Consequences

- Runtime object access can change with aura secrecy.
- Load-time configuration remains a deliberate setup window.
- Child components cannot be reparented after configuration.
- Group layout introduces untrusted-layout restrictions.
- UnitAura calls cannot be the assumed fallback in restricted content.

## Product Consequences

**OBSERVATION:** Most visible baseline features have a native analog. The uncertain areas are policy-heavy rather than renderer-heavy.

**RECOMMENDATION:** Define a minimum viable 12.1 BuffBars release around:

- Player buffs and debuffs
- Native time/name/default sorting
- Max bars
- Native icon/name/count/duration
- Basic whitelist/blacklist where supported
- Movable OUS presentation
- Tooltip and cancellation parity

Consumable auto-routing, advanced overrides, global tooltip skins, sounds, and optional ApplicationBar enhancements should not block the first architecture proof.

## Risk Rating

| Risk | Severity | Why |
| --- | --- | --- |
| Late PTR API churn | High | Flow/presentation APIs changed through PTR7 |
| Restricted combat access | High | Source inspection cannot prove addon runtime behavior |
| Movable frame integration | High | Forbidden layout rules can affect OUS anchors |
| Filter identity constraints | Medium-high | Spell-ID policy depends on secrecy/unit relationship |
| Enchantment parity | Medium | Native path exists but detailed output is untested |
| Visual parity | Medium | Native descendants are flexible but need practical skin tests |
| Performance | Medium-low | Managed dedup/incremental model is favorable; addon overhead unmeasured |

## Decision

**RECOMMENDATION:** Architecture research is mature enough to design a prototype, but not to implement BuffBars in the production addon. The release gate remains 12.1 Live source confirmation plus in-game prototype acceptance.

