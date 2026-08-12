# Tooltip Integration

## Live 12.1 Confirmation

**FACT:** Retail Live commit `eb941aad0` and final PTR commit `6e348870e` have identical AuraButton tooltip, shared tooltip-art, private-aura tooltip, UnitAura, and BuffFrame tooltip paths.

**LIVE CONCLUSION:** Managed AuraButton tooltips remain preferred. They pass the managed aura data directly to `ShowAuraTooltip`; item enchantments use `SetInventoryItem`. No new per-container tooltip API was added. Global AuraContainer styling remains shared, and suppressing OBB's legacy scan-index tooltip path on 12.1+ remains justified because indexed aura access is still restricted and the managed button already owns a native identity-safe tooltip path.

**HISTORICAL NOTE:** A late-PTR refinement moved periodic tooltip refresh from each AuraButton's `OnUpdate` to the shared forbidden `AuraButtonTooltipMixin`. This is an ownership/refresh implementation change, not a change to the addon-facing managed tooltip behavior.

## Per-Button Behavior

**FACT:** AuraButton exposes tooltip anchor configuration and combat visibility policy:

- `GetTooltipAnchorPoint`
- `SetTooltipAnchorPoint`
- `ShouldHideTooltipInCombat`
- `SetHideTooltipInCombat`

**FACT:** The current default anchor is `ANCHOR_BOTTOMLEFT` with zero offsets. Tooltip hiding in combat defaults to false.

**FACT:** The native tooltip receives aura identity through the AuraButton rather than requiring addon code to call `GameTooltip:SetUnitAura` with an index.

**ANALYSIS:** This replaces a fragile frozen behavior: tooltip lookup by scan index can diverge after aura list changes and can be restricted when aura data is secret.

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
