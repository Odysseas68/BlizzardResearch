# Blizzard Implementation Notes

## Current Snapshot

**FACT:** Primary source: Retail PTR branch `ptr`, commit `d3915c78a`, build `12.1.0.68914`.

**OBSERVATION:** Retail live (`12.0.7.68887`), ptr2 (`12.0.7.68887`), and the older beta snapshot (`12.0.1.66220`) do not contain the new Retail `Blizzard_AuraContainer` addon. Comparisons to those mirrors show pre-framework behavior, not alternate 12.1 implementations.

## Source Pipeline

**FACT:** Public unit auras come from `C_UnitAuras`; private auras come from `C_UnitAurasPrivate`; item enchantments come from a dedicated source; edit/preview uses an AuraUtil provider switch.

**FACT:** Static registrations are retained. Dynamic unit/private/enchantment events are registered only while the container is visible and enabled.

**FACT:** Full refreshes parse each exact filter string once. Incremental UNIT_AURA updates process added, updated, and removed identities against secure caches.

## Provider Behavior

**FACT:** The custom provider allocates AuraButtons in batches of ten, initializes each through `securecallfunction`, applies access restrictions, and asks the button to refresh native display.

**ANALYSIS:** Batch size, cache shapes, dirty flags, and source object fields are implementation details. Addons should not assume or inspect them.

## FlowLayout Refactor

**FACT:** Build 68914 contains `Blizzard_AuraContainerFlowLayout.lua`. It uses `AnchorUtil.FlowLayoutMixin`, supports horizontal or vertical primary axes, wraps by maximum line size, and auto-sizes the container after layout.

**FACT:** This supersedes earlier row-specific `AuraLayout*` APIs and X/Y spacing fields.

**OBSERVATION:** Groups, slots, enchantments, and the managed pipeline changed far less than the layout/presentation surface across builds 68569-68914.

## AuraButton Presentation

**FACT:** Configurable descendants include icon, spell name, duration cooldown/text/bar, application count/bar, dispel text, and one or more dispel textures.

**FACT:** Dispel textures support Border, BorderWithIcon, Icon, PreserveAsset, and CustomAsset styles plus custom texture/color maps and color curves.

**FACT:** `AuraBorder` and `AuraSymbol` methods remain only as deprecated aliases for the first dispel texture and dispel text.

## Aura Sounds

**FACT:** PTR6 renamed the sound facility to `AddAuraSound`; source notes describe add/remove aura sound support.

**OBSERVATION:** Sound semantics were not required by the frozen BuffBars baseline and should remain optional prototype scope.

## Blizzard Consumers

**FACT:** TargetFrame on current PTR uses the ManagedAuraContainer path and current flow layout.

**FACT:** BuffFrame still contains an older, separately named `AuraContainerMixin` built from ordinary frames/buttons. It is not the new native AuraContainer object.

**ANALYSIS:** Name similarity can mislead source searches. The new framework should be identified by `Blizzard_AuraContainer` dependencies and native object methods, not by any `AuraContainerMixin` symbol.

## ManagedFrameSystem

**OBSERVATION:** No direct integration between CustomAuraContainer and ManagedFrameSystem was found. `ResizeToBoundsRect` is present in generated Frame APIs but is not used by the AuraContainer implementation inspected.

## Known Documentation Discrepancy

**OBSERVATION:** Generated options for custom dispel text describe an empty-string key for no dispel type, while the implementation helper looks up `"None"`.

**TEST REQUIREMENT:** Resolve this discrepancy against 12.1 Live source/runtime before documenting a custom map contract.

