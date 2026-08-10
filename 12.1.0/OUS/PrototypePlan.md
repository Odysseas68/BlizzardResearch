# BuffBars 12.1 Prototype Plan

## Purpose

Define a disposable, separate prototype that tests the Retail 12.1 AuraContainer contract before any OdysseusUtilitySuite integration. This document does not authorize implementation in an addon repository.

## Entry Gate

- 12.1 Live client/source available, or an explicitly approved PTR test cycle
- Current AuraContainer API re-audited against [API Changes](../Analysis/APIChanges.md)
- Prototype location approved outside production OUS
- Required in-game test characters/content available

## Stage 1: Lifecycle and Access

**Goal:** Prove container creation, initialization, login timing, enable/disable, unit assignment, and access introspection.

**Pass:** No forbidden/taint errors during reload, login, combat entry/exit, or visibility changes.

## Stage 2: Baseline Aura Bars

**Goal:** Render player HELPFUL and HARMFUL groups using native icon, spell name, application count, duration text, and duration bar.

**Pass:** Timed and timeless auras update correctly without direct UnitAura scanning.

## Stage 3: Filtering and Sorting

**Goal:** Prove filter strings, whitelist, blacklist, max count, and Default/NameOnly/ExpirationOnly ordering.

**Pass:** Results remain correct in restricted combat; no secret-value Lua operations are required.

## Stage 4: OUS Layout Contract

**Goal:** Put containers under OUS-style movable parents, keep parents at scale 1 where practical, and scale dimensions/spacing/fonts/children.

**Pass:** No anchor drift, overlap, forbidden-layout errors, or combat resize failures at tested UI scales.

## Stage 5: Interaction

**Goal:** Prove native tooltips, tooltip combat policy, buff cancellation, and button mouse behavior.

**Pass:** Correct tooltip/cancel target before and after aura reordering, including timeless cancellable buffs.

## Stage 6: Enchantments and Private Auras

**Goal:** Test main/off-hand enchantment display/cancel and framework-owned private aura behavior.

**Pass:** Native data is sufficient for the approved baseline; no synthetic scan is needed for required features.

## Stage 7: Stress and Compatibility

**Goal:** Test high aura counts, rapid updates, reloads, Edit Mode transitions, Blizzard-frame visibility preference, and interactions with common UI scale/layout changes.

**Pass:** No Lua errors, taint, stale bars, anchor drift, or persistent tooltip/cancel mismatch.

## Instrumentation

**RECOMMENDATION:** Record build/commit, scenario, unit/filter/group configuration, access-state results, first full stack trace, screenshots only when useful for visual evidence, and an explicit pass/fail per gate. Do not log secret aura values.

## Exit Decision

- **Proceed:** All required baseline gates pass on 12.1 Live.
- **Revise:** Public framework supports the goal but OUS ownership/layout must change.
- **Defer:** Required behavior is missing or unstable.
- **Reject direct port:** The frozen scanner is never the automatic fallback merely because the prototype fails.

## Production Handoff

Only after a proceed decision:

1. Update OUS architecture documentation.
2. Define public module helpers and SavedVariables schema.
3. Plan small implementation patches.
4. Add addon code only under addon-repository guidance.
5. Run Lua/static validation and the full in-game matrix.

