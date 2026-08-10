# Managed Frame System

## Terminology

**FACT:** `ManagedAuraContainer` and Blizzard's `ManagedFrameSystem` are separate systems.

- `ManagedAuraContainer` manages aura sources, selection, AuraButtons, display, and layout.
- `ManagedFrameSystem` manages screen/UI frame registration and placement through managed frame templates and layout containers.

## Relationship

**OBSERVATION:** No direct dependency from `CustomAuraContainer` to `ManagedFrameSystem` was found in the current Retail PTR source.

**OBSERVATION:** `ResizeToBoundsRect` is a protected generic Frame API. The custom AuraContainer flow-layout code computes and applies its own bounds and does not call it.

**ANALYSIS:** An addon does not need to enroll a CustomAuraContainer in ManagedFrameSystem merely to use AuraGroups, slots, or FlowLayout.

## Edit Mode

**FACT:** The aura source layer can switch to an AuraUtil fake provider for edit/preview behavior through `AURA_DATA_PROVIDER_SWITCH`.

**ANALYSIS:** This supports container preview data but does not, by itself, define OUS Edit Mode ownership or register OUS frames with Blizzard's layout manager.

## OUS Guidance

**RECOMMENDATION:** Keep OUS movable-frame placement independent unless a later product decision explicitly integrates Blizzard Edit Mode. Test the AuraContainer as a child of an OUS-owned movable frame, with the parent at scale 1 and dimensions/children scaled according to Engineering Library policy.

