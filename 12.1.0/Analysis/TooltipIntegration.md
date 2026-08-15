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

## Fishing Profession-Tool Inventory Tooltip

**VERIFIED FROM GENERATED API DOCUMENTATION:** `C_TooltipInfo.GetInventoryItem(unit: UnitToken, slot: luaIndex, hideUselessStats?: bool) -> data: TooltipData | nothing` is `MayReturnNothing` and `SecretArguments = AllowedWhenUntainted` (`TooltipInfoDocumentation.lua:389-405`). The generated `TooltipDataLineType` enum contains `ItemEnchantmentPermanent = 15` and `GemSocketEnchantment = 30`, but no explicit TemporaryEnchantment or FishingLure line type (`TooltipInfoSharedDocumentation.lua:27-83`).

**VERIFIED FROM BLIZZARD IMPLEMENTATION SOURCE:** The profession fishing-tool button inherits the normal PaperDoll item-slot path. Its hover presentation ultimately calls `tooltip:SetInventoryItem("player", equipmentSlot)`, so slot `28` has a supported inventory-tooltip path independent of managed AuraContainer item-enchantment registration (`Blizzard_ProfessionsCrafting.xml:86-120,320-328`; `PaperDollFrame.lua:1761-1775`; `ItemUtil.lua:386-405`).

**RUNTIME EVIDENCE:** While the tested Bright Baubles lure was active on fishing tool slot `28`, `C_TooltipInfo.GetInventoryItem("player", 28)` contained a readable line equivalent to:

```text
Fishing Lure (+7 Fishing Skill) (8 min)
```

The observed lure line had numeric line type `0`, corresponding to `TooltipDataLineType.None`; this is not a formal FishingLure classification. The structured result did not expose the original applied item name `Bright Baubles`.

**ANALYSIS:** Inventory-tooltip inspection can confirm a human-readable active fishing-lure effect and remaining time, but the tested structure cannot recover the source lure item's identity. Use structured line data before considering text extraction, and keep any interpretation of the generic localized text explicitly heuristic.

## Restricted-Layout Tooltip Ownership

**VERIFIED FROM BLIZZARD SOURCE:** Adding an AuraGroup applies `UntrustedLayoutScriptExecution` to the self-sizing custom container. The generated forbidden-aspect contract says this aspect propagates to children and anything anchored to the restricted object. Blizzard directs addon-created dependent frames to opt in with `DisableUntrustedLayoutScriptsTemplate` when they must participate in that anchor chain (`Blizzard_CustomAuraContainer.lua:314-321`; `ForbiddenAspectConstantsDocumentation.lua:13-23`; `ForbiddenAspectTemplates.xml:4-22`).

**RUNTIME EVIDENCE:** An otherwise ordinary addon-owned row was positioned relative to and depended on restricted, self-sizing managed-container geometry. Using it as the owner in `GameTooltip:SetOwner(dependentRow, ...)` produced:

```text
GameTooltip:SetOwner(): Anchoring disallowed as dependent object would inherit forbidden aspects: UntrustedLayoutScriptExecution
```

This does not mean ordinary addon frames generally cannot own tooltips. The observed condition was the row's restricted layout dependency.

**RUNTIME WORKAROUND:** Owning the tooltip from independent `UIParent` with `ANCHOR_CURSOR`, then applying `GameTooltip:SetInventoryItem("player", fishingToolSlot)`, displayed the fishing-rod inventory tooltip without another observed forbidden-layout error:

```lua
GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
GameTooltip:SetInventoryItem("player", fishingToolSlot)
```

This is the tested workaround for that dependency topology, not a universal tooltip-owner requirement. See [Combat and Security Restrictions](CombatAndSecurityRestrictions.md).

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
