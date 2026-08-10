# Combat and Security Restrictions

## Execution Boundary

**FACT:** `Blizzard_AuraContainer` Lua executes with `UseSecureEnvironment: 1`. Addon configuration enters through native object APIs and narrow inbound functions.

**FACT:** Secure execution does not mean every object is permanently protected. AuraButtons can have conditional restrictions that activate when auras are secret.

## AuraButton Forbidden Aspects

**FACT:** The template forbids untrusted script execution, untrusted layout script execution, scripted input, always-propagated input, focus queries, parent changes, and removal of secret aspects.

**FACT:** Configured display descendants inherit change-parent and secret-aspect restrictions. They must belong to the AuraButton hierarchy and cannot be moved elsewhere after configuration.

## Access Timing

**FACT:** The provider invokes addon initialization before applying conditional aura-secrecy restrictions.

**FACT:** PTR7 permits native AuraButton APIs during addon load through `PLAYER_LOGIN`; restrictions are deferred and applied at `PLAYER_ENTERING_WORLD` when necessary.

**ANALYSIS:** Load-time success is a setup allowance, not evidence of combat-time access. Runtime mutation should be tested under `CanBeAccessedInContext` conditions.

## Combat Creation

**FACT:** PTR7 states AuraContainers can be created during combat. Current XML permits untainted creation.

**OBSERVATION:** Creation permission does not erase the button/access/layout restrictions that apply after creation.

**RECOMMENDATION:** Create and configure long-lived OUS structures outside combat by default. Test combat creation only as a resilience case, not as the primary lifecycle.

## UnitAura Restrictions

**FACT:** Generated metadata marks index, slot, and instance-ID aura access with unit-aura access constraints and secret results under restriction. `GetUnitAuraInstanceIDs` requires UnitAura access. Spell-name lookup requires a non-secret aura.

**FACT:** PTR notes document addon errors when restricted UnitAura calls are made in secret contexts.

**ANALYSIS:** Direct scanning cannot be considered a supported primary engine merely because calls remain available in open-world tests.

## Introspection APIs

**FACT:** `HasAccessConstraints` reports whether an object has forbidden or conditional restrictions. `CanBeAccessedInContext` reports accessibility from the current execution context.

**RECOMMENDATION:** Use these for diagnostics and guarded optional behavior. Do not use them to reconstruct secret aura data outside the container.

## Layout Restrictions

**FACT:** Adding an AuraGroup applies `UntrustedLayoutScriptExecution` to the container. The source comment directs addon frames anchored to it to opt in using `DisableUntrustedLayoutScriptsTemplate` at creation.

**TEST REQUIREMENT:** Prototype movable-parent, anchored-child, scale, group resize, and combat refresh behavior before selecting the OUS frame hierarchy.

## SecureAuraHeaderTemplate

**FACT:** `SecureAuraHeaderTemplate` is not loaded for Mainline; its files are Classic-gated. `SecureGroupHeaderTemplate` remains available for secure unit-frame scenarios.

**ANALYSIS:** New Retail aura work should not revive a SecureAuraHeader-based design.

