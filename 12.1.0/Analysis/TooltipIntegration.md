# Tooltip Integration

## Live 12.1 Confirmation

**FACT:** Retail Live commit `eb941aad0` and final PTR commit `6e348870e` have identical AuraButton tooltip, shared tooltip-art, private-aura tooltip, UnitAura, and BuffFrame tooltip paths.

**LIVE CONCLUSION:** Managed AuraButton tooltips remain preferred. They pass the managed aura data directly to `ShowAuraTooltip`; item enchantments use `SetInventoryItem`. No new per-container tooltip API was added. Global AuraContainer styling remains shared, and suppressing OBB's legacy scan-index tooltip path on 12.1+ remains justified because indexed aura access is still restricted and the managed button already owns a native identity-safe tooltip path.

**HISTORICAL NOTE:** A late-PTR refinement moved periodic tooltip refresh from each AuraButton's `OnUpdate` to the shared forbidden `AuraButtonTooltipMixin`. This is an ownership/refresh implementation change, not a change to the addon-facing managed tooltip behavior.

**CURRENT SOURCE REVALIDATION:** Retail Live and PTR `12.1.0.69299` have byte-identical generated `TooltipInfoDocumentation.lua`. Live uses commit `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b`; PTR uses commit `fe17d3e3bd5d6b5a35816d13f1941aa8927cd2be`.

## Per-Button Behavior

**FACT:** AuraButton exposes tooltip anchor configuration and combat visibility policy:

- `GetTooltipAnchorPoint`
- `SetTooltipAnchorPoint`
- `ShouldHideTooltipInCombat`
- `SetHideTooltipInCombat`

**FACT:** The current default anchor is `ANCHOR_BOTTOMLEFT` with zero offsets. Tooltip hiding in combat defaults to false.

**FACT:** The native tooltip receives aura identity through the AuraButton rather than requiring addon code to call `GameTooltip:SetUnitAura` with an index.

**ANALYSIS:** This replaces a fragile frozen behavior: tooltip lookup by scan index can diverge after aura list changes and can be restricted when aura data is secret.

## Active Aura Structured Lookup

**BLIZZARD SOURCE FACT:** Retail 12.1 generated documentation defines:

```lua
C_TooltipInfo.GetUnitAuraByAuraInstanceID(
    unitToken: UnitTokenRestrictedForAddOns,
    auraInstanceID: number,
    filter?: AuraFilters
) -> data: TooltipData | nothing
```

The function is marked `MayReturnNothing`, `RequiresUnitAuraAccess`, `SecretWhenUnitAuraRestricted`, and `SecretArguments = "AllowedWhenUntainted"`. Its documentation also states that the effective filters always include at least the normally mutually exclusive `HELPFUL|HARMFUL` pair regardless of the supplied filter. The lookup uses aura-instance identity rather than an aura index (`TooltipInfoDocumentation.lua:1218-1236`).

**BLIZZARD SOURCE FACT:** Blizzard's current tooltip handler consumes `tooltipData.lines` in order with `ipairs` and renders readable `lineData.leftText` and `lineData.rightText` (`TooltipDataHandler.lua:309-349`). This structured result remains subject to the getter's unit-aura restrictions.

**RUNTIME EVIDENCE:** Guarded out-of-combat calls succeeded for active player HELPFUL auras Well Fed, Ethereal Augmentation, and Flask of Alchemical Chaos. Readable ordered lines contained combinations of the aura name, current effect text, and remaining duration.

**ANALYSIS:** Active-aura tooltip text can add current effect context that is absent from some spell names. In the tested sample, the Ethereal Augmentation tooltip did not identify the effect as an Augment Rune. Tooltip text therefore supplied useful diagnostics but not a complete formal category signal.

**RECOMMENDATION:** Treat this as restricted optional diagnostics: verify API availability, use `pcall`, check that returned values and individual line fields are readable/non-secret, and accept no result. Do not intentionally inspect secret values or imply that structured tooltip lookup bypasses UnitAura restrictions.

## Global Styling

**FACT:** `AuraContainerInbound` exposes:

- `SetTooltipNineSlice`
- `SetTooltipTextureSlice`
- `SetTooltipBackdrop`
- `ResetTooltipStyle`

**FACT:** The Mainline aura tooltip is hidden from the global environment, forbidden, and based on shared tooltip art/private-aura behavior.

**FACT:** Styling applies to the shared AuraContainer tooltip, not one OUS container.

**ANALYSIS:** Global styling has a broad blast radius. OUS should prefer native default styling unless product requirements justify changing every AuraContainer tooltip.

## Private Auras

**FACT:** Private auras use a separate source adapter and private-aura tooltip mixin. Their data does not flow through ordinary public aura scans.

**RECOMMENDATION:** Treat private tooltip behavior as framework-owned. Do not attempt to read or reproduce private aura content in OUS text.

## Validation Matrix

**TEST REQUIREMENT:** Verify anchors, screen-edge clamping, combat hiding, private aura behavior, item enchantment tooltip content, and global-style reset in open world, combat, dungeon, raid, and after reload.
