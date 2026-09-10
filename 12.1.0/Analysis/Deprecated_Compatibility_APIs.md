# Retail Deprecated and Compatibility APIs — WoW 12.1.0

## 1. Purpose and scope

This document synthesizes the completed Retail Deprecated and Compatibility APIs investigation: the physical/load architecture audit, runtime fallback check, and the bounded Item/Inventory/Equipment, Aura/Unit, Spell/Action, and UI/Framework audits.

The authoritative scope is Retail/Mainline plus Shared code that Retail loads, references, inherits, or depends on. Classic, TBC, Cata, Mists, Wrath, Vanilla, and other non-Retail implementations are out of scope except for a minimal provenance check needed to reject a non-Retail implementation. Their behavior must not be imported as Retail semantics.

This is representative engineering guidance, not a catalogue of every historical global. Its conclusions apply to the captured source and user-tested runtime below and are not promises about future Blizzard builds.

## 2. Evidence model

- **VERIFIED SOURCE FACT:** directly established by the captured LIVE Blizzard Lua, XML, TOC, or generated API documentation.
- **USER-VERIFIED RUNTIME FACT:** directly observed by the user in Retail WoW.
- **SOURCE-SUPPORTED INFERENCE:** a strong engineering interpretation of the inspected source, not an explicit Blizzard contract.
- **UNKNOWN:** the available source and runtime evidence do not establish the answer.

Physical presence, TOC listing, execution, fallback installation, symbol availability, and current Blizzard use are reported separately. An old name, deprecated filename, migration guide, zero static callers, or modern alternative does not by itself establish removal.

## 3. Source and runtime snapshot

### LIVE source

- Repository: `D:\WowDEV\Reference\Blizzard\wow-ui-source`
- Branch: `live`
- Commit: `8ea15b61e45c0ed4eba01439c90757f86eb78d34`
- Commit description/build: `12.1.0 (69587)`
- Research checkpoint: September 2026

The source checkout contained the pre-existing untracked `.codex/` directory and was not modified. PTR source was not used for this synthesis.

### Runtime scope

**USER-VERIFIED RUNTIME FACT:** the user tested the current Retail 12.1.0 environment represented by this research. Runtime results establish only that tested client/environment, not future availability.

## 4. Retail compatibility load architecture

### Physical inventory

**VERIFIED SOURCE FACT:** `Interface/AddOns` contains exactly 26 directories whose names begin `Blizzard_Deprecated`, plus `Deprecated_PaperDoll`, for 27 deprecated-named directories total. None of those packages declares `LoadOnDemand: 1`.

`Blizzard_Deprecated_ArenaUI` is the important structural exception to a simple API-shim model: it retains substantial Lua/XML UI implementation rather than only a short alias list.

### Fallback-gated packages

Many API shim files begin with:

```lua
if not GetCVarBool("loadDeprecationFallbacks") then
	return
end
```

When the gate is false, the file can be physically present and TOC-listed while its compatibility body installs nothing. The versioned files under `Blizzard_Deprecated` are cumulative compatibility layers. A version in a filename identifies a change/deprecation epoch, not a known expiration date.

### Compatibility outside deprecated-named packages

High-value compatibility also exists in normally loaded framework packages:

- `Blizzard_SharedXMLBase/Compat.lua`
- `Blizzard_FrameXML/DeprecatedTemplates.lua` and `.xml`
- `Blizzard_SharedXML/Backdrop.lua` and `.xml`
- `Blizzard_SharedXML/TimeUtil.lua`
- `Blizzard_SharedXML/HybridScrollFrame.lua` and `.xml`
- `Blizzard_SharedXML/SecureScrollTemplates.lua` and `.xml`
- `Blizzard_SharedXML/Mainline/UIDropDownMenu.lua` and templates
- `Blizzard_FrameXMLUtil/AuraUtil.lua`
- `Blizzard_FrameXML/SecureTemplates.lua`
- `Blizzard_StaticPopup/StaticPopup.lua`
- method, property, and template aliases
- `Blizzard_Settings_Shared/Blizzard_Deprecated.lua`, which is an empty placeholder

These facilities can be ungated compatibility, full retained subsystems, current infrastructure, or placeholders. Directory placement alone does not classify them.

### Transformation taxonomy

The completed audits found:

- direct aliases;
- renamed aliases;
- thin forwarders;
- argument adapters;
- identifier translation;
- struct-to-tuple projections;
- default reconstruction;
- field suppression;
- enum translation;
- method aliases;
- property aliases;
- template aliases;
- callback protocol adapters;
- secure attribute adapters;
- no-op/placeholder files;
- full retained legacy subsystems;
- current native legacy-shaped APIs with no direct replacement.

## 5. Runtime fallback availability

**USER-VERIFIED RUNTIME FACT:** the user ran:

```lua
/run print("loadDeprecationFallbacks =", GetCVar("loadDeprecationFallbacks"), GetCVarBool("loadDeprecationFallbacks"))
```

Observed:

```text
loadDeprecationFallbacks = 1 true
```

The same environment confirmed these representative names as functions:

- `GetWeaponEnchantInfo`
- `GetItemInfo`
- `GetInventorySlotInfo`
- `GetActionCooldown`
- `SecondsToTime`
- `UIDropDownMenu_CreateInfo`

This establishes that the compatibility packages load in this environment, the fallback CVar is enabled, and representative fallback/current helpers are installed. It does not establish that every historical API is installed. The Aura/Unit and Spell runtime closures below demonstrate that distinction.

## 6. Transformation patterns at a glance

| Representative | Load class | Implementation class | Important semantic boundary |
| --- | --- | --- | --- |
| `GetItemIcon` | Fallback-gated | Direct alias to `C_Item.GetItemIconByID` | ItemInfo domain, not ItemLocation |
| `GetWeaponEnchantInfo` | Fallback-gated | Struct-to-fixed-tuple projection | Drops `hasExpirationTime` |
| `AuraUtil.UnpackAuraData` | Ungated current helper | Struct-to-tuple projection | Drops identity/classification fields; flattens points |
| `IsSpellKnown` | Fallback-gated | Boolean-to-enum/override adapter | Player/Pet bank and override policy |
| `GetActionCooldown` | Fallback-gated | Struct-to-tuple projection | Drops four modern cooldown fields |
| `GetActionInfo` | Current native/global | No established direct replacement | Not a fallback dependency |
| `getn` / `tinsert` | Ungated compatibility | Direct aliases | Mechanically replaceable, but still used |
| Global trigonometric helpers | Ungated compatibility | Unit-conversion wrappers | Degrees versus radians |
| `BackdropTemplate` | Ungated current template | Compatibility mixin plus NineSlice implementation | Methods and geometry depend on composition |
| `SecondsToTimeAbbrev` | Ungated current/deprecated helper | Legacy formatter | Returns format token plus number |
| Hybrid/Faux scroll | Ungated retained subsystem | Full legacy system | ScrollBox migration is architectural |
| UIDropDownMenu | Ungated retained subsystem | Full legacy system | Blizzard_Menu migration is architectural |
| StaticPopup legacy path | Ungated current infrastructure | Callback/data protocol adapter | `data2` and close-result semantics |
| Secure `bag`/`slot` | Ungated secure path | Attribute adapter | Resolves local `item`; does not rewrite attributes |

## 7. Item, inventory, and equipment

### Alias families

**VERIFIED SOURCE FACT:** `Blizzard_DeprecatedItemScript/Deprecated_ItemScript.lua` installs 47 globals as direct assignments to `C_Item`. `Blizzard_DeprecatedItemSocketInfo/Deprecated_ItemSocketInfo.lua` installs 13 globals as direct assignments to `C_ItemSocketInfo`. `Deprecated_PaperDoll/Deprecated_PaperDoll.lua` installs one direct assignment to `C_PaperDollInfo`.

All representative compatibility globals audited in these families are fallback-gated.

A direct assignment adds no Lua-side argument conversion, return conversion, default reconstruction, or cache handling. Migration still must preserve the exact right-hand-side target and its argument domain.

Canonical example:

```lua
GetItemIcon = C_Item.GetItemIconByID
```

`C_Item.GetItemIconByID` consumes ItemInfo. `C_Item.GetItemIcon` consumes ItemLocation. Similar names do not make those calls interchangeable.

**Engineering implication:** for a fallback alias, start from the actual assignment rather than constructing a modern name. Preserve legacy nil and cache behavior at each call site.

## 8. Temporary enchant compatibility

### `GetWeaponEnchantInfo`

**VERIFIED SOURCE FACT:** `Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua` iterates MainHand, OffHand, and Ranged and calls `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)`.

For each slot it emits four fixed positions:

```text
true, remainingTimeMs, chargesRemaining, enchantID
```

When no record exists it emits `false` followed by three nil positions. An explicit unpack range preserves the complete legacy 12-position tuple despite the nil gaps.

Modern `TemporaryItemEnchantInfo` contains:

- `enchantID`
- `remainingTimeMs`
- `chargesRemaining`
- `hasExpirationTime`

The legacy tuple drops `hasExpirationTime`. Current Blizzard BuffFrame code consumes that field, demonstrating that it is operationally meaningful. The modern structure does not establish an enchant display name.

### `CancelItemTempEnchantment`

The wrapper maps:

- `1` → MainHand
- `2` → OffHand
- `3` → Ranged

It then calls `C_PaperDollInfo.CancelTemporaryEnchantment(slot)`. A nil or invalid index makes no modern call.

The source does not establish a universal combat/security guarantee for every calling composition.

## 9. Aura and Unit compatibility

### Modern structure and identity

**VERIFIED SOURCE FACT:** current `C_UnitAuras` functions return `AuraData`. Current Blizzard update architecture uses `auraInstanceID`, `UNIT_AURA` update information, full updates, added AuraData records, updated instance IDs, and removed instance IDs.

Current code uses `auraInstanceID` as operational identity. The inspected source does not define a formal lifetime or reuse guarantee beyond that use.

### Current tuple bridge

`Blizzard_FrameXMLUtil/AuraUtil.lua` implements `AuraUtil.UnpackAuraData` as a current compatibility bridge. Its exact tuple is:

1. `name`
2. `icon`
3. `applications`
4. `dispelName`
5. `duration`
6. `expirationTime`
7. `sourceUnit`
8. `isStealable`
9. `nameplateShowPersonal`
10. `spellId`
11. `canApplyAura`
12. `isBossAura`
13. `isFromPlayerOrPlayerPet`
14. `nameplateShowAll`
15. `timeMod`
16. and later: unpacked `auraData.points`

It omits:

- `auraInstanceID`
- `isHelpful`
- `isHarmful`
- `isRaid`
- `isNameplateOnly`

It also flattens the `points` collection. This is a current, explicit example of a compatibility tuple discarding structured identity and classification data.

### Filter compatibility

The exact not-cancelable token is constructed as:

```lua
AuraUtil.AuraFilters.NotCancelable = AuraUtil.AuraFilterNegationPrefix .. AuraUtil.AuraFilters.Cancelable
```

The result is `!CANCELABLE`, not `NOT_CANCELABLE`.

`RAID`, `RAID_PLAYER_DISPELLABLE`, `DISPELLABLE`, and `IMPORTANT` are distinct filter concepts and must not be conflated.

### Runtime closure

**USER-VERIFIED RUNTIME FACT:** the user ran:

```lua
/run print("UnitAura:",type(UnitAura),"UnitBuff:",type(UnitBuff),"UnitDebuff:",type(UnitDebuff))
```

Observed:

```text
UnitAura: nil
UnitBuff: nil
UnitDebuff: nil
```

For this Retail environment, source found no Retail Lua implementation, generated legacy declaration, or first-party caller, and runtime confirms all three globals are absent. Classic implementations are not Retail semantics.

## 10. Spell and Action compatibility

### Identifier domains

`C_Spell` consumes SpellIdentifier-style spell identity. `C_SpellBook` consumes spellbook positions and banks. Action slots form a third domain. Spell ID, spell name, spellbook index, and action slot must not be interchanged merely because each can be represented by a number or string.

A modern SpellIdentifier can accept a spell ID, name, name plus subtext, or spell link. `C_Spell.DoesSpellExist` and `C_Spell.IsSpellDataCached` answer separate questions: existence does not prove metadata cache readiness.

### SpellBook traps

Historical `GetSpellBookItemInfo` must not automatically become `C_SpellBook.GetSpellBookItemInfo` when the caller wanted the historical type tuple. Blizzard's transition guide identifies `C_SpellBook.GetSpellBookItemType` as the direct type-information replacement.

Fallback `IsSpellKnown` translates the historical Pet/Player choice into a spell-bank enum and excludes overrides. `IsSpellKnownOrOverridesKnown` performs the corresponding bank translation while including overrides. Those policies are intentional semantic adapters.

### Spell multi-return trap

**VERIFIED SOURCE FACT:** `C_Spell.GetSpellTexture(...)` returns:

1. `iconID`
2. `originalIconID`
3. nilable `conditionalIconID`

A mechanical replacement of code expecting one value can change Lua behavior when the call is the final expression in an argument list or return list. This is a migration hazard, not a defect in the modern API.

### Spell runtime closure

**USER-VERIFIED RUNTIME FACT:** after the source audit, the user ran:

```lua
/run for _,n in ipairs({"GetSpellInfo","GetSpellCooldown","GetSpellCharges","GetSpellBookItemInfo"}) do print(n,type(_G[n])) end
```

Observed:

```text
GetSpellInfo nil
GetSpellCooldown nil
GetSpellCharges nil
GetSpellBookItemInfo nil
```

For this Retail environment, no Retail Lua fallback implementation, generated legacy declaration, or current first-party caller was found, and runtime confirms all four globals are absent. Their availability is not pending or unknown. Modern migration must select `C_Spell` or `C_SpellBook` from the actual identifier domain; Classic tuple behavior must not be borrowed.

### Action cooldown projection

Fallback `GetActionCooldown(actionID)` calls `C_ActionBar.GetActionCooldown(actionID)` and returns:

- `startTime`
- `duration`
- `isEnabled`
- `modRate`

Modern `SpellCooldownInfo` also contains:

- `isActive`
- `activeCategory`
- `timeUntilEndOfStartRecovery`
- `isOnGCD`

Those four fields are suppressed by the compatibility projection. The wrapper synthesizes no defaults.

### Action charge projection

Fallback `GetActionCharges(actionID)` returns:

- `currentCharges`
- `maxCharges`
- `cooldownStartTime`
- `cooldownDuration`
- `chargeModRate`

Modern `SpellChargeInfo` additionally contains `isActive`, which the compatibility tuple drops. `GetActionLossOfControlCooldown` is likewise a lossy structured-data projection.

### `GetActionInfo` exception

**VERIFIED SOURCE FACT:** no Lua compatibility definition and no `C_ActionBar.GetActionInfo` replacement were found, while current Retail/Shared Blizzard code calls global `GetActionInfo` extensively.

Classification:

**CURRENT NATIVE / LEGACY-SHAPED API WITH NO ESTABLISHED DIRECT REPLACEMENT**

Its complete engine contract is not inferred beyond source-visible caller behavior. This is a direct counterexample to treating every global-looking API as a migration target.

## 11. UI and framework compatibility

### Lua compatibility globals

`Blizzard_SharedXMLBase/Compat.lua` is loaded normally and ungated.

Mechanical aliases include:

- `getn` → `table.getn`
- `tinsert` → `table.insert`
- `gmatch` → `string.gmatch`

Behavior-sensitive wrappers include:

- global `sin`, `cos`, and `tan`, which accept degrees and convert to radians;
- global `asin`, `acos`, `atan`, and `atan2`, which return degrees.

Fallback-gated `getglobal` returns `_G[var]`. Fallback-gated `setglobal` may call `forceinsecure()` before writing `_G[var]`; security provenance can therefore make plain assignment non-equivalent.

### Backdrop

`BackdropTemplate` is a current virtual template applying `BackdropTemplateMixin`. Arbitrary frames do not automatically receive its methods.

`SetBackdrop` retains the caller's table reference, clears for nil or a table with no background/edge file, and applies NineSlice-based textures. `GetBackdrop` returns a copy and reconstructs historical defaults, including empty file strings, tile defaults, edge size, and zeroed insets.

Backdrop texture-coordinate calculation reads width, height, effective scale, and edge/tile sizes and performs arithmetic when the frame size changes.

**SOURCE-SUPPORTED INFERENCE:** backdrop behavior is composition-sensitive when geometry values are forbidden or secret.

The earlier OUS FlightMaster incident demonstrated one composition-specific failure. It does not establish that `BackdropTemplate` is globally unsafe. Current Blizzard code continues to use the template.

### Deprecated templates

`Blizzard_FrameXML/DeprecatedTemplates.xml` normally loads representative option checkbutton, slider, tab, and list templates. Some are simple inheritance aliases; others contain fixed size, anchoring, art, sound, or script behavior. No external current Retail consumer was found in the bounded search.

Template replacement is mechanical only when the complete inheritance and behavior are equivalent. A compatibility filename does not establish a removal date.

### Time helpers

`SecondsToTime` is source-marked deprecated and names `SecondsFormatter` as the intended replacement, but Blizzard still calls it extensively. Its behavior includes localization, unit thresholds, rounding, maximum term count, and multi-unit formatting.

`SecondsToTimeAbbrev` remains used and returns a localized format token plus a numeric value; it does not return one completed display string. Migration must preserve that return shape and formatting behavior.

### Hybrid and Faux scrolling

Hybrid/Faux systems remain normally loaded. Source explicitly describes them as deprecated and retained for addons and legacy content, with ScrollBox or newer ScrollFrame infrastructure as the migration direction. No external Retail first-party consumer was found in the bounded search.

Migration can change element/button ownership, pooling and reuse, integral versus pixel offsets, dynamic-height handling, scrollbar behavior, and saved scroll state. It is architectural rather than a symbol substitution.

Despite its filename, the inspected `SecureScrollTemplates` code does not establish protected secure-action behavior. Security must not be inferred from the filename.

### UIDropDownMenu

Mainline UIDropDownMenu remains normally loaded and is not controlled by `loadDeprecationFallbacks`. It is a full retained legacy subsystem installed alongside current `Blizzard_Menu`.

Blizzard's Menu transition guide identifies `Blizzard_Menu` as the replacement direction and explains that no compatibility shim bridges the fundamentally different models. No current first-party dropdown-menu consumer was found in the bounded search. One current `UIDropDownMenu_CreateInfo` call remains, but uses its `{}` return only as a Color Picker info table allocator.

Normal loading does not mean UIDropDownMenu is recommended for new UI, while deprecation does not mean it is absent. Migration to generator functions and menu descriptions is architectural.

### StaticPopup

StaticPopup is current infrastructure. `StaticPopup_Show`, `StaticPopup_Hide`, and `StaticPopupDialogs` have extensive current Blizzard use.

Current index-selected and legacy fixed-callback paths coexist. In the legacy path, accept/extra callbacks can receive `dialog.data2`, and callback return values can keep the popup open. `data2` is not a `StaticPopup_Show` parameter; callers that need it assign `dialog.data2` after Show. The base Show/Hide lifecycle does not initialize or clear that field.

StaticPopup is not a deprecated fallback, and no universal replacement was established.

### Property, method, and template aliases

Current checkbutton XML exposes `parent.Text` and installs `parent.text` as a compatibility alias during the font string's OnLoad. Both initially reference the same FontString; the assignment is not synchronized if either field is later replaced.

CustomAuraButton provides direct aliases:

- `GetAuraSymbol` → `GetDispelTypeText`
- `SetAuraSymbol` → `SetDispelTypeText`
- `ClearAuraSymbol` → `ClearDispelTypeText`

Its singular AuraBorder methods are wrappers over the first member of a dispel-texture collection. `SetAuraBorder` clears the collection before adding one texture, so this is behavior-sensitive rather than a direct rename.

### Secure item attributes

Inside secure item action handling, the modern `item` attribute is read first. Only when absent does the handler inspect legacy `bag` and `slot`, construct a local `"bag slot"` or slot target, and continue through the normal item parser/use path.

The adapter does not rewrite frame attributes. Migration must preserve the complete resolved item target, not merely rename one attribute.

### Placeholder

`Blizzard_Settings_Shared/Blizzard_Deprecated.lua` is normally TOC-loaded but contains only a comment and has no executable behavior. Its retention purpose is **UNKNOWN**. This demonstrates that physical presence plus normal loading does not necessarily mean an active shim.

## 12. Security and restricted boundaries

Security findings must remain API- and composition-specific.

- Aura documentation includes unit-aura access requirements, conditional secret contents, and restrictions on some cancellation/query paths.
- Cooldown and charge APIs can produce secret contents under cooldown restrictions; spell, spellbook, and action functions have different taint conditions.
- Backdrop layout reads geometry and scale but does not supply a universal secrecy guard.
- StaticPopup uses restricted/forbidden infrastructure and rejects tainted display for secure-text definitions.
- UIDropDownMenu uses secure calls and an attribute delegate around potentially tainted state.
- Secure item compatibility executes inside the secure action path.

These do not collapse into one combat rule. Keep distinct:

- taint;
- secret values;
- forbidden aspects;
- protected actions;
- secure attributes;
- restricted API access;
- combat lockdown;
- layout dependencies;
- cache/data availability.

No universal “safe in combat” or “unsafe in combat” classification is supported.

## 13. Current caller evidence

Static counts are approximate lexical search results over Retail/Mainline and Retail-relevant Shared Lua/XML. Definitions, generated documentation, comments where distinguishable, and non-Retail variants were excluded. Counts show migration direction; zero callers do not establish removal or runtime absence.

Representative results:

| Symbol/facility | Approximate current evidence |
| --- | ---: |
| `tinsert` | more than 200 calls |
| `getn` | about 16 calls |
| direct `BackdropTemplate` consumers | at least 15 |
| `SecondsToTime` | about 70 calls |
| `SecondsToTimeAbbrev` | about 5 calls |
| `StaticPopup_Show` | more than 400 calls |
| `GetActionInfo` | about 38 calls |
| `UIDropDownMenu` current menu consumers | none found |
| Hybrid/Faux external Retail consumers | none found |

Current Blizzard code widely uses `C_Spell`, `C_SpellBook`, and `C_ActionBar`, while no current callers were found for the four runtime-absent spell globals.

## 14. Cross-domain migration decision guide

For any old-looking Retail API, helper, or template:

1. **Establish presence and load path.** Is it physically present and actually loaded for Retail?
2. **Classify installation.** Is it fallback-gated, ungated compatibility, current infrastructure, native, a retained subsystem, or a placeholder?
3. **Trace implementation.** Is it an exact alias, renamed alias, wrapper, projection, argument adapter, template/method/property alias, callback protocol, secure adapter, or full subsystem?
4. **Resolve the exact target and identifier domain.** Distinguish item identity/location, spell identity, spellbook position, action slot, inventory slot, and secure attribute target.
5. **Compare semantics.** Check arguments, return count/shape, nil/default behavior, cache state, identity, layout, callbacks, security, and retained state.
6. **Check current Blizzard use.** Active first-party use changes the classification but is not a future guarantee.
7. **Use runtime only for a material unresolved native-availability question.** Do not request tests for source-established behavior.
8. **Then classify the call:** low-risk compatibility, migration recommended, behavior-sensitive adapter, current legacy infrastructure, no direct replacement, absent, or unknown.

“Deprecated” alone is never sufficient justification for a mechanical rewrite.

## 15. Addon engineering implications

These are evidence-supported candidates, not automatic coding rules:

- Prefer exact modern namespaces for new Retail code when argument and return semantics are equivalent.
- Verify identifier domain before migration; similar names and integer values are insufficient.
- Prefer modern structured data when its additional fields matter to behavior.
- Preserve nil, default, cache, and multi-return behavior intentionally.
- Use `auraInstanceID` as operational modern aura identity where the API supplies it, without inventing a lifetime guarantee.
- Do not mistake `AuraUtil.UnpackAuraData` for a lossless AuraData conversion.
- Preserve `hasExpirationTime` when temporary-enchant behavior depends on it.
- Distinguish compatibility-only systems from current older infrastructure.
- Do not mechanically migrate StaticPopup.
- Treat UIDropDownMenu and Hybrid/Faux-to-ScrollBox migrations as architectural.
- Treat Backdrop risk as composition-specific rather than globally unsafe.
- Preserve complete secure attribute semantics.
- Keep access, secrecy, taint, protected execution, layout restrictions, combat, and cache readiness separate.

No OUS, OBB, or other addon change follows automatically from this research.

## 16. False-positive and research traps

- Physical presence is not runtime availability.
- TOC listing does not mean a fallback-gated body executed.
- Enabled fallbacks do not install every historical global.
- Shared code is not automatically Retail-relevant.
- A Classic implementation is not Retail semantics.
- Generated documentation is not proof of runtime installation.
- A migration guide is not a runtime implementation.
- A versioned filename is not a removal date.
- Zero static callers does not mean removed.
- The same function name does not prove the same argument domain.
- The same function name does not prove the same return contract.
- A tuple is not equivalent to a structured record.
- An integer is not necessarily the same identifier type.
- A newer subsystem does not imply mechanical migration.
- Deprecated does not mean unused.
- Current first-party use is not a future guarantee.
- A placeholder file is not an active shim.
- XML inheritance is not always an exact alias.
- A property alias is not synchronized state.
- Source-visible restrictions do not establish universal combat behavior.
- A composition-specific Backdrop failure does not establish blanket unsafety.
- A `Secure*` filename does not itself establish protected action semantics.

## 17. Unknowns and boundaries

The research deliberately leaves these as **UNKNOWN** or not established:

- future removal builds;
- universal combat behavior;
- dynamic `_G` callers missed by static search;
- every external addon dependency;
- complete native contracts not described by source, including all `GetActionInfo` returns;
- a formal auraInstanceID lifetime/reuse guarantee;
- every composition that can produce secret or forbidden layout values;
- future Blizzard direction beyond the captured snapshot;
- the exact retention purpose of empty placeholder files.

These are not unknown in the user-tested Retail environment:

- `UnitAura`, `UnitBuff`, and `UnitDebuff` are absent.
- `GetSpellInfo`, `GetSpellCooldown`, `GetSpellCharges`, and `GetSpellBookItemInfo` are absent.
- `loadDeprecationFallbacks` is enabled.

## 18. Final conclusions

Retail compatibility is not one deprecated namespace. It is a layered system containing fallback-gated API shims, ungated foundational aliases, structured-data projections, identifier adapters, framework templates, secure attribute bridges, retained legacy subsystems, current older infrastructure, native exceptions, and empty placeholders.

The safest migration rule is to trace the actual installed implementation and compare its complete contract with the exact modern target. Direct aliases can be straightforward, while projections, identifier changes, multi-return APIs, callbacks, layouts, and secure attributes require semantic or architectural work.

The captured runtime confirms that fallback enablement is selective: representative compatibility globals are installed, while three historical Aura/Unit globals and four historical Spell/SpellBook globals are absent. Current first-party use also prevents simplistic classification: StaticPopup, BackdropTemplate, old time helpers, Lua compatibility aliases, and `GetActionInfo` remain operationally relevant.

Compatibility status, deprecation status, current use, and future support are separate facts. This document records the first three for the captured Retail 12.1.0 environment and makes no unsupported prediction about the fourth.

## 19. Primary source index

All paths are relative to the captured `wow-ui-source/Interface/AddOns` tree unless noted otherwise.

- `Blizzard_Deprecated/Blizzard_Deprecated.toc`
- `Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua`
- `Blizzard_Deprecated/11_0_0_SpellBookAPITransitionGuide.lua`
- `Blizzard_DeprecatedItemScript/Deprecated_ItemScript.lua`
- `Blizzard_DeprecatedItemSocketInfo/Deprecated_ItemSocketInfo.lua`
- `Deprecated_PaperDoll/Deprecated_PaperDoll.lua`
- `Blizzard_DeprecatedActionBar/Deprecated_ActionBar.lua`
- `Blizzard_DeprecatedSpellBook/Deprecated_SpellBook.lua`
- `Blizzard_DeprecatedSpellScript/Deprecated_SpellScript.lua`
- `Blizzard_FrameXMLUtil/AuraUtil.lua`
- `Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua`
- `Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua`
- `Blizzard_APIDocumentationGenerated/SpellDocumentation.lua`
- `Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua`
- `Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua`
- `Blizzard_APIDocumentationGenerated/ActionBarFrameDocumentation.lua`
- `Blizzard_SharedXMLBase/Compat.lua`
- `Blizzard_SharedXML/Backdrop.lua` and `.xml`
- `Blizzard_SharedXML/TimeUtil.lua`
- `Blizzard_SharedXML/HybridScrollFrame.lua` and `.xml`
- `Blizzard_SharedXML/SecureScrollTemplates.lua` and `.xml`
- `Blizzard_SharedXML/Mainline/UIDropDownMenu.lua` and related templates
- `Blizzard_Menu/11_0_0_MenuImplementationGuide.lua`
- `Blizzard_StaticPopup/StaticPopup.lua`
- `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua`
- `Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml`
- `Blizzard_FrameXML/DeprecatedTemplates.lua` and `.xml`
- `Blizzard_FrameXML/SecureTemplates.lua`
- `Blizzard_Settings_Shared/Blizzard_Deprecated.lua`
