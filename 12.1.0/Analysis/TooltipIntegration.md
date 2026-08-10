# Tooltip Integration

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

