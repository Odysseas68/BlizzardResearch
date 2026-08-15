# Managed Item Enchantments

## 1. Scope and Verified Build

This document defines the Retail 12.1 managed AuraContainer contract for the temporary-weapon-enchantment portion of OdysseusBuffBars `ENCHANTMENTS`. It is research and migration guidance only. No addon or Blizzard source was modified.

The current Live installation and source mirror were reverified before this trace:

- Retail build: `12.1.0.69299`
- Mainline interface: `120100`
- Live source revision: `31c7f7b9cc79e56c986b365c06a6afbcf3c9177b`
- Live source commit date: `2026-08-13`
- Previous completed aura audit: build `12.1.0.69273`, revision `eb941aad028d73ddc69e3e8ef4da709f4d3cd744`

`version.txt`, the active installation's `.build.info`, and `Wow.exe` all report `12.1.0.69299`. The active OBB manifest still accepts interface `120100`. A direct diff from the previous Live audit revision to the current source found no changes in `Blizzard_AuraContainer`, `Blizzard_BuffFrame`, AuraContainer generated documentation, PaperDollInfo documentation, FlowLayout, or their aura dependencies. The only generated-documentation changes in that range are unrelated Discord API changes.

**LIVE CONCLUSION:** Retail 12.1 supports native, managed temporary weapon-enchantment rows. OBB can replace its synthetic weapon-enchantment records with container-owned `CustomAuraButtonTemplate` frames. These rows are not AuraGroups, cannot use aura candidate filters, and do not expose an enchantment-specific display name.

## 2. Native Architecture

Blizzard describes item enchantments as fixed player-owned display sources. The exact managed path is:

```text
C_PaperDollInfo.GetTemporaryEnchantmentInfo(inventorySlot)
-> AuraContainerItemEnchantmentManagerMixin
-> one AuraContainerItemEnchantmentMixin object per registered slot
-> one fixed container-owned CustomAuraButtonTemplate frame per slot
-> AuraButton-compatible item-enchantment data
-> CustomAuraButton managed presentation
-> item-enchantment FlowLayout element list
-> native tooltip/cancellation
-> clear and hide when inactive
```

Source: `Blizzard_AuraContainerEnchantments.lua:2-7,25-70,178-231,234-353`; `Blizzard_CustomAuraContainer.lua:450-468,557-593,652-664`; `Blizzard_ManagedAuraContainer.lua:250-329`.

### Addon-facing surface

`CustomAuraContainerTemplate` exposes these supported template/mixin methods:

- `AddItemEnchantment(itemEnchantmentSlot, options)`
- `SetItemEnchantmentSortMethod(sortMethod, sortDirection)`
- `SetItemEnchantmentLayout(layoutOptions)`
- `ResetItemEnchantmentLayout()`
- ordinary container lifecycle methods, including `SetEnabled`
- ordinary FlowLayout setters

`AddItemEnchantment` has the exact signature:

```text
AddItemEnchantment(itemEnchantmentSlot, options)
```

The first argument must be one `AuraContainerItemEnchantmentSlot` value. The options table is copied inbound and supports only:

```text
templateNames   table or nil
initializeFrame function or nil
hidePermanent  boolean or nil; default false
```

Source: `Blizzard_CustomAuraContainer.lua:197-223,259-264,450-485`; defaults at `Blizzard_AuraContainerShared.lua:238-248`.

`AddItemEnchantment` returns the created `AuraButton`. It always inherits `CustomAuraButtonTemplate` before any addon templates. Its initializer runs through `securecallfunction` before conditional access restrictions are applied (`Blizzard_AuraContainerFrameProviders.lua:24-42,75-94`).

### API classification

- `C_PaperDollInfo.GetTemporaryEnchantmentInfo` and `C_PaperDollInfo.CancelTemporaryEnchantment` are generated namespace APIs (`PaperDollInfoDocumentation.lua:35-45,217-231,482-490`).
- `CustomAuraContainerTemplate`, `CustomAuraButtonTemplate`, `AddItemEnchantment`, the enchantment sort/layout setters, and AuraButton display setters are supported addon-facing template/mixin surfaces exposed through secure inbound delegates. They are not generated `C_` namespace functions (`Blizzard_CustomAuraContainer.xml:4-15`; `Blizzard_CustomAuraButton.xml:4-15`; `Blizzard_CustomAuraContainer.lua:512-513`).
- Managers, item-enchantment objects, active arrays, aura data, provider objects, dirty masks, and FlowLayout completion are Blizzard-private implementation details.

### Registration and enablement

One `AddItemEnchantment` call represents one slot. Main hand, off hand, and ranged are enum values handled by one manager; they are not three provider classes.

Registration does not have a construction-only or `PLAYER_LOGIN` assertion. A missing slot may therefore be added later, but the public surface is additive only:

- adding the same slot twice asserts;
- no public unregister/clear method exists;
- no public setter changes `hidePermanent`, templates, or the initializer after registration;
- there is no per-provider enabled flag.

The container's `SetEnabled(false)` disables all of its registered item-enchantment displays, unregisters dynamic events, and clears active enchantment data/frames. `SetEnabled(true)` refreshes them again (`Blizzard_AuraContainer.lua:24-33,157-182`; `Blizzard_ManagedAuraContainer.lua:43-56`). Hiding the container unregisters dynamic events and makes the parent-owned presentation invisible, but does not take the disabled-state branch that clears the active enchantment arrays. Showing it registers events and refreshes again.

Each call creates a separate custom frame provider with batch size one and immediately acquires its one frame. Enchantment inactivity calls `ClearAuraInstance()` and `Hide()` on that fixed frame; it does not release the frame back through the provider. Reapplication reuses the same slot frame. Even the private clear-all path clears data/visibility rather than destroying the frame. There is no addon-facing release operation (`Blizzard_CustomAuraContainer.lua:450-468,652-664`; `Blizzard_AuraContainerEnchantments.lua:73-95,143-175,190-231`).

**COMBAT CLASSIFICATION:** Source contains no `InCombatLockdown` branch in `AddItemEnchantment`, the sort/layout setters, or registration internals. This absence is not proof that tainted addon execution may safely add or reconfigure providers in combat. Configure a long-lived container and both normal weapon slots before combat. Treat combat-time registration and reconfiguration as runtime-test requirements, not supported facts.

## 3. Providers and Slots

| Managed slot | Enum value | Inventory constant | Inventory slot | Default slot order |
| --- | ---: | --- | ---: | ---: |
| Main hand | `AuraContainerItemEnchantmentSlot.MainHand` (`0`) | `INVSLOT_MAINHAND` | `16` | `1` |
| Off hand | `AuraContainerItemEnchantmentSlot.OffHand` (`1`) | `INVSLOT_OFFHAND` | `17` | `2` |
| Ranged | `AuraContainerItemEnchantmentSlot.Ranged` (`2`) | `INVSLOT_RANGED` | `18` | `3` |

Source: `Blizzard_AuraContainerShared.lua:9-28`; `Blizzard_FrameXMLBase/Constants.lua:167-178`.

For each registered slot, `AuraContainerUtil.GetItemEnchantmentInfo` maps the enum to its inventory slot and calls:

```text
C_PaperDollInfo.GetTemporaryEnchantmentInfo(inventorySlot)
```

The API returns nothing when that slot has no active temporary enchantment. Otherwise it returns `TemporaryItemEnchantInfo`:

```text
enchantID
remainingTimeMs
chargesRemaining
hasExpirationTime
```

Source: `Blizzard_AuraContainerUtil.lua:146-158`; `PaperDollInfoDocumentation.lua:217-231,482-490`.

### Lifecycle by condition

| Condition | Managed result |
| --- | --- |
| No enchantment | The slot object becomes inactive; its AuraButton is cleared and hidden. |
| Enchantment applied | The slot object becomes active; data is assigned to its fixed AuraButton and the button is shown. |
| Enchantment removed | Data and duration are cleared; the fixed button is hidden and disappears from FlowLayout input. |
| Enchantment refreshed | A higher `remainingTimeMs`, changed enchant ID, changed expiration mode, or previously inactive state triggers reassignment and duration reset. |
| Charges change | Current values are rebuilt and managed presentation updates; charge change alone does not require a new frame assignment. |
| Equipped weapon changes | `WEAPON_SLOT_CHANGED` refreshes every registered slot; icon and item name are read again from the current equipment slot. |
| Enchant state changes | `WEAPON_ENCHANT_CHANGED` refreshes every registered slot. |
| Container disabled | Dynamic events are unregistered and active enchantment data/frames are cleared. |
| Container hidden while enabled | Dynamic events are unregistered; the container is invisible, but active arrays are retained/refreshed rather than cleared through the disabled branch. |

Source: `Blizzard_AuraContainer.lua:71-92,107-142`; `Blizzard_AuraContainerEnchantments.lua:178-231,286-335`; `Blizzard_ManagedAuraContainer.lua:43-56,250-329`.

Main-hand and off-hand registrations keep independent state, frames, inventory slots, tooltips, and cancellation targets. This source structure supports independent dual-wield behavior. Live dual-wield add/refresh/remove/cancel still requires runtime confirmation.

### Ranged practicality

The managed API declares and supports the ranged enum and always maps it to slot `18`. It does not call `C_PaperDollInfo.IsRangedSlotShown()` before querying that slot. When slot `18` has no temporary enchantment, the ranged frame remains hidden.

Other current Retail source retains slot `18` for compatibility. The general secure `cancelaura` action adds ranged only when `C_PaperDollInfo.IsRangedSlotShown()` is true (`Blizzard_FrameXML/SecureTemplates.lua:463-482`). No audited Mainline source proves that an ordinary modern Retail class can equip and temporarily enchant a separate ranged-slot item. Treat ranged as declared compatibility coverage and test it only in a runtime where `IsRangedSlotShown()` and slot `18` are actually usable.

## 4. Relationship to AuraGroups

Blizzard's source is explicit: item enchantments are AuraButton-compatible data but do not participate in aura parsing, candidate filters, AuraGroups, or AuraSlots (`Blizzard_AuraContainerEnchantments.lua:2-5`).

| Architecture feature | HELPFUL/HARMFUL AuraGroups | Item enchantments |
| --- | --- | --- |
| Source | Public/private unit-aura providers | Fixed `C_PaperDollInfo` inventory-slot query |
| Registration | `AddAuraGroup(groupKey, filterString, options)` | `AddItemEnchantment(slot, options)` |
| Aura parsing | Yes | No |
| Filter string | Yes | No |
| Candidate filters | Yes | No |
| Processing policy | May add metadata | No participation |
| Group `maxFrameCount` | Yes | No |
| AuraGroup sort method | Yes | No |
| AuraGroup `framesByIndex` | Yes | No |
| Frame ownership | Pooled provider frames | One fixed acquired frame per registered slot |
| Managed display | `AuraButton` | Same `AuraButton` presentation path |
| FlowLayout | Group's dense active frame list | Parallel active item-enchantment frame list |

Item enchantments do not use an AuraGroup's `framesByIndex`. The manager maintains its own `activeItemEnchantments` and `activeItemEnchantmentFrames` arrays, sorts those arrays, and supplies the active frame array as one separate FlowLayout group description (`Blizzard_AuraContainerEnchantments.lua:27-36,157-175`; `Blizzard_CustomAuraContainer.lua:557-593`).

**CONCLUSION:** OBB may present BUFFS, DEBUFFS, and ENCHANTMENTS as equivalent product groups, but Blizzard does not model them as three AuraGroups. Native ENCHANTMENTS is a parallel managed item-provider path inside a `CustomAuraContainer`.

This independently aligns with the unverified external observation recorded in `OpenQuestions.md` that another addon no longer mixes buffs, debuffs, and temporary enchantments. The Blizzard source above is the evidence; the external observation is not.

## 5. Managed Presentation

`AddItemEnchantment` creates a separate `AuraButton` from `CustomAuraButtonTemplate`, not an ordinary AuraGroup pool row and not an enchantment-specific template (`Blizzard_CustomAuraContainer.lua:450-468,652-664`; `Blizzard_AuraContainerFrameProviders.lua:24-42,75-94`).

The item-enchantment object creates this AuraButton-compatible data internally:

```text
auraType = ItemEnchantment
auraInstanceID = nil
itemEnchantmentSlot
inventorySlot
itemEnchantmentID
applications
duration
expirationTime
```

Source: `Blizzard_AuraContainerEnchantments.lua:337-353`.

The ordinary custom-button bindings therefore work:

| Presentation | Supported surface | Exact native value |
| --- | --- | --- |
| Icon | `SetIcon(texture)` | Equipped item texture from `GetInventoryItemTexture("player", inventorySlot)`; question mark fallback |
| Primary name text | `SetSpellName(fontString)` | Equipped item name from `Item:CreateFromEquipmentSlot(inventorySlot):GetItemName()` |
| Charge text | `SetApplicationCount(fontString, options)` | `chargesRemaining` as applications |
| Charge bar | `SetApplicationBar(statusBar, options)` | Same applications value, if OBB chooses this optional presentation |
| Duration text | `SetDurationText(fontString, options)` | Blizzard `DurationTextBinding` over the AuraButton-owned duration object |
| Duration bar | `SetDurationBar(statusBar, options)` | Blizzard timer StatusBar over the same duration object |
| Duration cooldown | `SetDurationCooldown(cooldown)` | Optional native cooldown binding |
| Expiration | No addon-readable binding | Used internally to configure the duration object |
| Tooltip | AuraButton hover | Inventory-item tooltip for the registered slot |
| Cancellation | `SetCancelAuraButtons(clickTokens)` | Cancels the registered inventory slot |

Source: icon/name helpers at `Blizzard_AuraContainerUtil.lua:213-253`; display setters and application behavior at `Blizzard_CustomAuraButton.lua:36-73,135-217,219-280,338-369,511-565`; duration object at `Blizzard_AuraButton.lua:73-78,121-170`.

Addon Lua may create and style direct AuraButton descendants during `initializeFrame`: dimensions, anchors, fonts, textures, StatusBar art/color, static labels, and the documented display bindings remain addon-owned. Aura-driven values should be supplied through the native setters. Addon code should not inspect private aura data or manager tables.

The registration slot itself is non-secret static configuration. OBB may add an addon-owned static `Main hand` or `Off hand` label in the corresponding initializer. That label is not an enchantment-name binding.

## 6. Name Semantics

The native managed row does not expose an enchantment-specific display name.

`SetSpellName` first uses `auraData.name`; item-enchantment data has no `name`. It then sees `inventorySlot`, constructs an Item object for that equipment slot, and displays the equipped item's name. If sparse item data is not loaded, it registers a continuation that calls `AuraButton:UpdateAuraDisplay()` after the item loads (`Blizzard_AuraContainerUtil.lua:231-253`).

Therefore:

- Managed primary text exposes the equipped item name.
- It does not expose both item name and enchantment name.
- `TemporaryItemEnchantInfo.enchantID` is available from the public PaperDoll getter.
- The private managed data carries the same value as `itemEnchantmentID`, but AuraButton has no public accessor for that data.
- No audited generated API maps a temporary enchantment ID to an enchantment display name.
- No managed setter binds an enchantment name.
- The managed item-enchantment data contains the inventory slot but no equipped item ID or item link; item name and tooltip are resolved from the slot at display time.

The inventory tooltip may display temporary-enchantment details as part of the equipped item tooltip, but exact lines/content are a runtime result, not a source-guaranteed text API.

**CONCLUSION:** Do not parse tooltip lines, manufacture an item link, parse an item link's enchant field, treat `enchantID` as a spell ID, or invent a lookup table to obtain a row label. These are not supported name-resolution mechanisms in the audited contract. For the first prototype, use the native equipped-item name and native inventory tooltip. If product policy requires slot identity, add a static registration-derived slot label.

Legacy OBB currently displays `Main-hand Enchant` or `Off-hand Enchant`, not an enchantment-specific name. Native item-name presentation is therefore a deliberate product change unless OBB retains a separate static slot label.

### Name Resolution Audit

**IDENTIFIER CONTRACT:** `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)` returns `TemporaryItemEnchantInfo.enchantID` as a plain `number`. Generated documentation does not classify it as a `SpellIdentifier`, item ID, effect ID, recipe ID, or public `SpellItemEnchantment` database key. Managed implementation renames the value `itemEnchantmentID` in private AuraButton-compatible data and otherwise uses it only to detect replacement/refresh. The exact supported interpretation is therefore an opaque numeric temporary item-enchantment identity, not a spell ID (`PaperDollInfoDocumentation.lua:217-231,482-490`; `Blizzard_AuraContainerEnchantments.lua:286-347`).

**DIRECT RESOLVER:** A complete current-Live implementation and generated-documentation search found no `GetEnchantName`, `GetItemEnchantmentInfo(enchantID)`, `C_Item.GetEnchant...`, `C_PaperDollInfo.Get...Name`, or equivalent addon-facing resolver. The generated `C_Item` enchant-related entries concern applying/binding enchants or testing an active enchanting spell; none accepts `TemporaryItemEnchantInfo.enchantID`. No Lua table in the Live UI source maps temporary enchant IDs to localized names, spells, or consumable items.

**SPELL LOOKUP:** `C_Spell.GetSpellName` accepts a documented `SpellIdentifier`. The PaperDoll result is documented only as a number, and no Blizzard Live consumer passes `enchantID` to `C_Spell.GetSpellName`, `C_Spell.GetSpellInfo`, or a spell-mapping table. Numeric coincidence for a particular enchant would not establish an ID-domain contract. OBB must not treat `enchantID` as `spellID` for name lookup (`SpellDocumentation.lua:477-492`).

**STRUCTURED TOOLTIP DATA:** `C_TooltipInfo.GetInventoryItem("player", slot)` is a documented structured-tooltip entry point, but it returns generic `TooltipData`, not an enchantment-name structure. Its enchant-named line enums cover permanent item enchantments and gem-socket enchantments; there is no temporary-enchantment line type or documented `enchantID`/`enchantName` field. Generic tooltip arguments can carry strings, but selecting or trimming rendered localized text is still tooltip-text parsing. Blizzard's managed button and legacy BuffFrame simply call `SetInventoryItem` and display the tooltip; no Blizzard consumer parses its lines to obtain a temporary-enchantment name (`TooltipInfoDocumentation.lua:389-405`; `TooltipInfoSharedDocumentation.lua:27-83,161-172`; `Blizzard_AuraButton.lua:205-206`; `Blizzard_BuffFrame/BuffFrame.lua:888-896`). Use the native tooltip for hover presentation, not as a row-name data source.

**ITEM LINKS:** The generic item-hyperlink schema contains an `enchantID` component, but audited source does not prove that an equipped-item link's component is the current temporary PaperDoll enchant ID. More importantly, no supported item API resolves that link component to an enchantment display name: `C_Item.GetItemInfo` returns the item name/link and item metadata, while Blizzard's shared link helper extracts only the item ID and raw stripped link. Raw field parsing would add an undocumented equality assumption and still provide no localized-name resolver (`Blizzard_PTRFeedback/Blizzard_Reports.lua:386`; `ItemDocumentation.lua:604-656`; `Blizzard_SharedXML/LinkUtil.lua:79-100,123-127`).

**LEGACY AND BLIZZARD CONSUMERS:** Deprecated `GetWeaponEnchantInfo()` is only a compatibility wrapper over the PaperDoll getter and returns the same numeric ID without a name. Current BuffFrame ignores the ID entirely and presents icon, charges, duration, inventory tooltip, and cancellation. AuraContainer uses the ID for assignment/change detection but presents the equipped item name. Restricted SecureAuraHeader checks only whether a slot has an enchantment. No current Blizzard UI consumer resolves or displays the actual temporary-enchantment name as row text (`Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua:28-65`; `Blizzard_BuffFrame/BuffFrame.lua:667-693,881-895,1059-1070`).

**SUPPORTED OBB CHOICES, BEST TO WORST:**

1. Use the native equipped-item name through `SetSpellName`; this is localized, managed, and the best first-prototype row text.
2. Use addon-owned static registration labels such as `Main-hand Enchant` and `Off-hand Enchant`; this is stable and preserves legacy presentation, but is not the actual enchantment name.
3. Let the native inventory tooltip show whatever temporary-enchantment detail the client renders; this is presentation, not a programmatic name resolver, and exact content remains a runtime observation.
4. Reject tooltip text scraping, hardcoded enchant-ID tables, raw item-link parsing, and `enchantID == spellID` assumptions as unsupported workarounds.

**RESOLVED CONCLUSION:** Retail 12.1.0.69299 provides no supported and stable path from `TemporaryItemEnchantInfo.enchantID` to the actual localized temporary-enchantment display name. The validated managed path uses the native equipped-item name and may optionally add a static slot label later. It should not add a name-resolution layer or treat actual enchantment-name text as an unresolved startup-lifecycle requirement.

## 7. Duration and Charges

`C_PaperDollInfo.GetTemporaryEnchantmentInfo` exposes remaining time, not original/base duration. Blizzard snapshots a duration when it believes the enchantment was first applied, replaced, or refreshed, then retains that duration until the next reset (`Blizzard_AuraContainerEnchantments.lua:306-323`).

Reassignment/reset occurs when:

- the slot was inactive;
- `enchantID` changed;
- `hasExpirationTime` changed; or
- the new `remainingTimeMs` is greater than the previously observed value.

The last rule treats an increase as a refresh. A normal decreasing update retains the original snapshot (`Blizzard_AuraContainerEnchantments.lua:286-303`).

Each AuraButton creates one stable `C_DurationUtil.CreateDuration()` object on load. Assignment, retained update, disappearance, reappearance, and refresh reconfigure that same object; they do not replace it. Timed entries use `SetTimeFromEnd(expirationTime, duration, timeMod)`. Non-expiring or cleared entries use a zero time span (`Blizzard_AuraButton.lua:73-78,121-170`).

The countdown and StatusBar remain Blizzard-owned after configuration. OBB does not need an enchantment polling `OnUpdate`.

Charges map directly to `applications`:

- default `SetApplicationCount` text is blank for zero and one;
- default text shows the numeric value only when applications are greater than one;
- supplying a supported numeric formatter can render zero/one explicitly;
- `SetApplicationBar` can represent the same value if a maximum is supplied.

On clear/reuse, aura data becomes nil, application text becomes empty, the duration becomes zero, icon/name fallbacks are reapplied, and the frame is hidden. The fixed frame therefore clears stale values through the same managed display path (`Blizzard_CustomAuraButton.lua:321-369,511-591`; `Blizzard_ManagedAuraContainer.lua:254-265`).

## 8. Tooltips

The native AuraButton tooltip path is:

```text
AuraButton OnEnter
-> shared forbidden AuraContainer tooltip
-> tooltip:SetOwner(auraButton, configured anchor/offsets)
-> tooltip:SetInventoryItem("player", inventorySlot)
```

Source: `Blizzard_AuraButton.lua:177-225`.

The owner is the AuraButton. Default anchoring is `ANCHOR_BOTTOMLEFT`; `SetTooltipAnchorPoint` may change it. `SetHideTooltipInCombat(false)` is the default, so the source intends the tooltip to remain available in combat unless the addon opts out (`Blizzard_AuraButton.lua:32-68,177-183`; `Blizzard_AuraButton.xml:9-14`).

The tooltip is an equipped-item tooltip. It is source-proven to identify the inventory item, not to return a separate enchantment tooltip object or enchantment-name value. Runtime testing must confirm which temporary-enchantment line(s) are displayed for actual oils/stones and whether those lines update immediately on refresh/removal.

This path is different from BUFFS/DEBUFFS, where ordinary or private aura data goes to `ShowAuraTooltip`. Secret and private aura tooltip rules are not involved in the item-enchantment branch.

OBB should use the native AuraButton tooltip registration. It should not add its own `GameTooltip:SetInventoryItem` hover script, even though the native implementation ultimately calls that API internally.

## 9. Cancellation

Cancellation is configured on the AuraButton with:

```text
SetCancelAuraButtons("RightButtonDown")
```

`SetCancelAuraButtons` parses click tokens, registers them through `RegisterForClicks`, and the intrinsic AuraButton click handler constructs the actual `button + Down/Up` token. For item-enchantment data it calls:

```text
C_PaperDollInfo.CancelTemporaryEnchantment(auraData.inventorySlot)
```

Source: `Blizzard_AuraButton.lua:3-30,90-103,228-240`.

`C_PaperDollInfo.CancelTemporaryEnchantment(slot)` is generated documentation with `HasRestrictions = true` and `SecretArguments = AllowedWhenUntainted` (`PaperDollInfoDocumentation.lua:35-45`). The intrinsic AuraButton is the native managed input path and forbids scripted input (`Blizzard_AuraButton.xml:15-24`).

Main-hand/off-hand cancellation is independent because each button's internal data contains its own inventory slot. The native implementation eliminates OBB's separate `SecureActionButtonTemplate` overlay and `target-slot` attribute maintenance.

**SOURCE CONCLUSION:** Right-button cancellation is architecturally supported through the native managed button.

**RUNTIME STATUS:** Native `RightButtonDown` cancellation worked for the tested MainHand lifecycle. OffHand, dual-wield, and combat cancellation remain unvalidated. Generated restrictions and the lack of an explicit combat branch do not by themselves prove every tainted/restricted combat scenario.

## 10. Sorting

Item enchantments have their own sort enum:

```text
AuraContainerItemEnchantmentSortMethod.Slot
AuraContainerItemEnchantmentSortMethod.Duration
```

Both accept `AuraContainerSortDirection.Normal` or `Reverse` through `SetItemEnchantmentSortMethod` (`Blizzard_AuraContainerShared.lua:30-38,53-57`; `Blizzard_CustomAuraContainer.lua:471-476`).

| Sort | Normal | Reverse |
| --- | --- | --- |
| Slot | Main hand, off hand, ranged | Ranged, off hand, main hand |
| Duration | Shortest remaining first; non-expiring last; slot order tie-break | Non-expiring first; longest remaining first; reversed slot tie-break |

Source: `Blizzard_AuraContainerUtil.lua:160-210`.

Ordering is not registration-based after active rows are rebuilt. Default Slot sorting uses Blizzard's fixed slot order. Addon code may select Slot or Duration and direction, but there is no arbitrary comparator or per-provider order field.

`SetAuraGroupSortMethod` does not affect enchantments. Aura sort methods such as Name, Default, and ExpirationOnly do not apply. Enchantment rows cannot be sorted by name because their manager has no name comparator.

Legacy OBB's sort selector orders scanned HELPFUL enhancement auras, then appends synthetic weapon rows in `GetWeaponEnchantInfo` order. It does not sort weapon rows by name or remaining time. `Slot + Normal` preserves the practical main-hand then off-hand weapon-row order. If a future ENCHANTMENTS container also contains an enhancement AuraGroup, `SetItemEnchantmentLayout({ placement = AfterAuraGroups })` preserves the legacy broad placement of weapon rows after the aura-derived rows.

## 11. Filtering

No aura filtering mechanism applies to native item enchantments:

- no filter string;
- no candidate filters;
- no `includeSpellIDs` or `excludeSpellIDs`;
- no source/caster filters;
- no maximum-duration filter;
- no group maximum frame count;
- no addon predicate;
- no slot filter beyond choosing which slots to register.

The only built-in selection option is the per-registration `hidePermanent` boolean. When true, an enchantment with `hasExpirationTime == false` is treated as inactive (`Blizzard_AuraContainerEnchantments.lua:190-200,236-267`). There is no inverse `hideTimed` option.

There is no public per-provider enable/disable or removal setter. Configure only the desired slots up front, or enable/disable the dedicated container as a whole.

**PRODUCT CONSEQUENCE:** Legacy ENCHANTMENTS whitelist/blacklist maps and hidden overrides have no native equivalent for weapon enchantments. The managed row carries an enchantment ID internally, but item entries bypass candidate filters. OBB must preserve saved data without claiming it controls native weapon rows, retire those controls for this slice, or make an explicit non-managed product decision. Restoring a PaperDoll polling/filter layer merely to hide managed rows would defeat the ownership goal.

## 12. Layout and Self-Sizing

Item enchantments participate in the same `CustomAuraContainer` FlowLayout pass through a parallel element list:

```text
description.elements = function()
    return self:GetActiveItemEnchantmentFrames()
end
```

They use the same layout option fields as groups plus `placement`:

- `elementSpacing`
- `lineSpacing`
- `groupSpacing`
- `groupLineSpacing`
- `forceNewLine`
- `elementWidth`
- `elementHeight`
- `layoutIndex`
- `placement = BeforeAuraGroups | AfterAuraGroups`

Source: `Blizzard_AuraContainerShared.lua:214-236`; `Blizzard_CustomAuraContainer.lua:557-630`.

Only active frames enter the element list. Inactive fixed frames remain container-owned and hidden but do not contribute to layout. FlowLayout positions the elements, excludes trailing spacing, and sets the container to the calculated bounds. Empty groups contribute no spacing; with zero active enchantments and zero padding, the container is `1 x 1` because FlowLayout clamps each dimension to at least one pixel (`AnchorUtil.lua:612-746`; `Blizzard_CustomAuraContainer.lua:667-680`).

**CONCLUSION:** A third `CustomAuraContainer` containing only item enchantments independently self-sizes like the validated BUFFS/DEBUFFS containers. It grows to one, two, or three rows and collapses to the one-pixel empty minimum without addon counting or polling.

Adding item enchantments alone does not execute the `AddAuraGroup` branch that applies `UntrustedLayoutScriptExecution` to the container. AuraButtons still carry their own forbidden aspects. A future combined enhancement AuraGroup would apply the group restriction. OBB should retain the already-validated one-directional root/container chaining and use `DisableUntrustedLayoutScriptsTemplate` on ordinary frames that need to opt into restricted anchor propagation.

## 13. Secret and Private Relevance

Temporary item enchantments do not use `C_UnitAuras`, `C_UnitAurasPrivate`, public/private aura source adapters, aura instance IDs, or aura filter strings. They are sourced from `C_PaperDollInfo.GetTemporaryEnchantmentInfo` and represented with `auraType = ItemEnchantment` (`Blizzard_AuraContainerSources.lua`; `Blizzard_AuraContainerEnchantments.lua:337-353`).

The generated temporary-enchantment structure has ordinary numeric/boolean fields and no secret-result annotation. The getter has `SecretArguments = AllowedWhenUntainted` but not `HasRestrictions`; the cancellation function is explicitly restricted. The audited item-name API likewise has no secret-result annotation (`PaperDollInfoDocumentation.lua:217-231,482-490`; `ItemDocumentation.lua:809-836`).

Therefore:

- item-enchantment data is not a private aura;
- the source does not mark enchantment ID, remaining time, charges, or expiration mode secret;
- UnitAura combat restriction rules do not apply to this data path;
- item icon/name are inventory-item presentation, not secret aura identity;
- combat does not select a different enchantment source.

AuraButtons still use the common forbidden template and receive the common conditional access restriction after initialization. This does not convert item-enchantment data into a secret aura. It means OBB should continue using only the inbound presentation surface and should not inspect private button state.

The source presents managed item enchantments primarily as fixed lifecycle/presentation integration. It does not state that this path exists to solve secret/private enchantment data. Its security value for OBB is avoiding a second addon-owned polling/cancellation system, not bypassing secret aura rules.

## 14. Legacy OBB Compatibility

The active OBB legacy implementation was inspected read-only at revision `cbc655d0fbcd0a3727d14952dffa064b3032f187`.

Legacy `ENCHANTMENTS` is a product group containing two different data families:

1. synthetic temporary weapon-enchantment rows from deprecated `GetWeaponEnchantInfo()`;
2. selected player HELPFUL auras classified as enhancements through readable name patterns, one curated spell ID, cached classification, or user overrides.

It stores its own geometry, appearance, sorting, timed/timeless, maximum, filter, and placement settings under `OdysseusBuffBarsDB.groups[3]`. It is chained below DEBUFFS by default (`OdysseusBuffBars.lua:78-108,222-258`).

### Exact legacy weapon-row behavior

- `GetWeaponEnchantInfo()` is read on every ENCHANTMENTS scan.
- OBB builds addon-owned records with synthetic string identity, enchant ID as `spellID`, item-slot icon, charges, expiration, and a local formatted countdown.
- Labels are `Main-hand Enchant` and `Off-hand Enchant`, not enchantment names.
- The local formatter and ordinary bar `OnUpdate` poll every 0.1 seconds.
- Inventory-item tooltips use the synthetic row's `targetSlot`.
- Right-click cancellation uses a separate secure overlay with `target-slot`.
- Synthetic rows enter filter discovery before whitelist/blacklist evaluation and are subject to hidden overrides.
- Weapon rows are appended after sorted HELPFUL enhancement auras; the selected aura sort does not reorder the weapon rows.
- The wrapper for deprecated `GetWeaponEnchantInfo()` returns main hand, off hand, and ranged, but OBB's `enchantSlotNames` contains only main and off hand. A third active entry would receive a generic main-hand label, no target slot, question-mark icon, and no tooltip/cancellation target. Ranged parity is therefore not implemented correctly in legacy OBB.

Source: `OdysseusBuffBars_Auras.lua:10-29,31-45,69-129,306-364,368-465`; `OdysseusBuffBars_Bars.lua:104-190,192-277,477-515`; deprecated wrapper at `Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua:28-65`.

### Compatibility matrix

| Legacy ENCHANTMENTS feature | Native managed equivalent | Assessment | Migration consequence |
| --- | --- | --- | --- |
| Dedicated third product group | Third independent `CustomAuraContainer` under an ordinary OBB root/header | Exact | Preserve independent ownership and position. |
| Dedicated group enable/disable | Legacy has no dedicated enabled field; native container has `SetEnabled` | Partial/product addition | Whole-container enablement is available if OBB later adds a setting. |
| Main-hand discovery | Register `MainHand` | Exact | Remove synthetic scan for this slot. |
| Off-hand discovery | Register `OffHand` | Exact | Remove synthetic scan for this slot. |
| Independent dual-wield rows | Separate registered slot objects/frames | Exact by source; runtime required | Test simultaneous refresh/removal/cancel. |
| Ranged discovery | Register `Ranged` | Native available; legacy unavailable/broken | Defer until a usable Retail runtime proves slot `18`. |
| Synthetic aura records | Native item-enchantment objects and AuraButton data | Exact replacement | Retire addon-owned weapon records. |
| `Main-hand Enchant` / `Off-hand Enchant` name | Addon-owned static slot label | Exact if retained separately | Native `SetSpellName` instead displays item name. |
| Equipped item name | `SetSpellName` | Native improvement/product change | Decide whether item name replaces or accompanies slot label. |
| Enchantment-specific name | None in legacy; none in managed row | Exact absence | Tooltip may show details; do not parse it. |
| Enchant ID | Public PaperDoll result; private managed `itemEnchantmentID` | Partial | No public managed identity binding/filter accessor. |
| Item icon | `SetIcon` -> equipped-slot texture | Exact | Native fallback/reload behavior replaces manual icon lookup. |
| Charges | `SetApplicationCount` / optional ApplicationBar | Exact data; partial default text | Default hides zero/one as legacy does; formatter may show them. |
| Countdown text | `SetDurationText` | Exact intent | Retire 0.1-second addon polling and local formatter. Exact typography/rounding may differ. |
| StatusBar countdown | `SetDurationBar` | Exact intent | Blizzard owns timer progress. |
| Expiration | AuraButton-owned duration object | Exact intent | No addon expiration arithmetic. |
| Non-expiring rows | `hidePermanent = false`; zero duration object | Partial | Legacy can hide/show via timeless setting; exact timeless bar visuals need product/runtime decision. |
| Timed-only selection | `hidePermanent = true` | Partial | Fixed registration option; no runtime setter. |
| Timeless-only selection | No equivalent | Unavailable | Product change required. |
| Time Left sort selector | Item `Duration` sort exists, but legacy did not sort weapon rows | Product change | Use fixed Slot order for parity; add Duration only as a new option. |
| Name sort selector | No item-name sort | Unavailable, but legacy weapon rows were not name-sorted | Keep fixed Slot order; do not claim name sorting. |
| Default main/off order | `Slot + Normal` | Exact | Main hand before off hand. |
| Weapon rows after HELPFUL enhancement rows | Item layout `placement = AfterAuraGroups` | Exact if a future aura group is added | Not needed in the weapon-only first prototype. |
| One combined `maxBars` cap | AuraGroup cap does not include item rows | Unavailable | Combined legacy cap needs product change; weapon-only maximum is naturally three. |
| Whitelist/blacklist by enchant ID | None | Unavailable | Preserve saved maps but do not connect them to native weapon rows. |
| Hidden override by enchant ID | None | Unavailable | Product change; do not add duplicate polling merely to hide a row. |
| Name-pattern HELPFUL enhancement routing | Managed filters have no name predicate | Unavailable | Retire heuristic or replace with curated/manual spell-ID policy. |
| Curated HELPFUL enhancement IDs | Separate HELPFUL AuraGroup with `includeSpellIDs` where eligible | Partial/product change | Add only after the weapon-only slice and its policy are accepted. |
| Enhancement classification cache | No managed identity/history feed | Unavailable | Retire runtime discovery cache for the managed slice. |
| Filter editor discovery/history | No public active enchantment enumerator | Unavailable | Keep saved/manual rows only; label unsupported controls accurately. |
| Independent placement below DEBUFFS | Ordinary root + self-sizing third container | Exact | Reuse validated one-directional chain. |
| Width/height/spacing/grow direction | item layout + container FlowLayout | Exact intent | Map to element and flow options. |
| Font size/icon side | AuraButton descendant styling | Exact | Configure in initializer. |
| Scale/alpha | Ordinary root/container presentation | Exact intent | Runtime-test anchor geometry at non-default scale. |
| Purple fill/background colors | Addon-styled descendant StatusBar/background | Exact | Static color is safe; aura-driven custom color is unnecessary. |
| Inventory-item tooltip | Native AuraButton inventory tooltip | Exact path | Remove addon hover handler for managed rows. |
| Right-click slot cancellation | Native `SetCancelAuraButtons` | Exact architecture; runtime required | Remove secure overlays after validation. |
| `WEAPON_ENCHANT_CHANGED` / `WEAPON_SLOT_CHANGED` refresh | Container-owned events | Exact | Remove addon weapon-event ownership for the migrated slice. |
| SavedVariables geometry/appearance | No Blizzard replacement | Exact addon ownership | Preserve current fields during migration. |

## 15. Recommended OBB Architecture

| Design | Assessment |
| --- | --- |
| A. Third independent `CustomAuraContainer` dedicated to ENCHANTMENTS | **Recommended.** Preserves independent position/configuration, isolates the fixed item-provider path, self-sizes predictably, and can later host one explicit enhancement AuraGroup without mixing BUFFS/DEBUFFS ownership. |
| B. Add enchantment providers to BUFFS | Rejected for OBB. Technically supported, but couples BUFFS and weapon rows to one size/layout/configuration lifecycle and weakens the third-group product boundary. |
| C. Add enchantment providers to DEBUFFS | Rejected. Same coupling problem and no semantic relationship to player HARMFUL data. |
| D. One container for BUFFS, DEBUFFS, and enchantments | Technically possible through multiple AuraGroups plus the item list, but rejected for current OBB. Independent positioning, filter policy, product enablement, and staged migration become harder; group maximum counts still do not govern item rows. |
| E. Native rows under a separate ordinary wrapper/group | Required as presentation structure, but not a standalone data design. Native rows must still belong to a `CustomAuraContainer`; an ordinary frame cannot own or mirror managed item data. Combine this wrapper with design A. |

Recommended topology:

```text
ordinary BUFFS root/header
-> self-sizing BUFFS CustomAuraContainer
-> ordinary DEBUFFS host/header
-> self-sizing DEBUFFS CustomAuraContainer
-> ordinary ENCHANTMENTS host/header
-> self-sizing ENCHANTMENTS CustomAuraContainer
   -> fixed MainHand item-enchantment frame
   -> fixed OffHand item-enchantment frame
   -> optional future Ranged frame
   -> optional future curated HELPFUL AuraGroup
```

The first implementation should keep the ENCHANTMENTS container weapon-only. If a later product decision restores consumable enhancement auras, add one explicitly filtered HELPFUL AuraGroup to this third container and place item rows after it. Do not restore name heuristics or direct aura scans.

## 16. First Prototype Scope

The smallest useful first Live ENCHANTMENTS prototype should include:

1. A third isolated ordinary host/header anchored one-way below the validated DEBUFFS container.
2. One `CustomAuraContainerTemplate`, configured early and kept long-lived.
3. `AddItemEnchantment(MainHand, options)`.
4. `AddItemEnchantment(OffHand, options)`.
5. Fixed `AuraContainerItemEnchantmentSortMethod.Slot` plus `AuraContainerSortDirection.Normal`; no selector.
6. `SetIcon` for equipped-item icon.
7. `SetSpellName` for the verified equipped-item name.
8. `SetApplicationCount` for charges.
9. `SetDurationText` and `SetDurationBar`.
10. Native AuraButton tooltip.
11. `SetCancelAuraButtons("RightButtonDown")`, with explicit combat/runtime validation.
12. Native self-sizing and empty-state collapse.

Use `hidePermanent = false` for this first proof so the prototype does not silently discard a source result. Decide timed-only policy only after observing an actual non-expiring result.

Do not include in the first prototype:

- ranged registration;
- a HELPFUL enhancement AuraGroup;
- name-pattern consumable routing;
- sorting selector;
- whitelist/blacklist or hidden override wiring;
- max-bars wiring;
- legacy filter discovery/history;
- new persistence or SavedVariables;
- legacy configuration connection;
- custom colors beyond simple fixed prototype styling;
- full visual parity;
- an addon timer `OnUpdate`;
- addon-owned tooltip/cancellation overlays;
- production backend cutover.

Use the managed equipped-item name in the first proof. A static slot label may be added later only if dual-wield usability shows it is needed. Do not block the architecture test on an enchantment-specific row name that the native API does not provide.

## 17. Runtime Validation Status

### Validated MainHand lifecycle slice

The managed MainHand/OffHand prototype has passed its Retail Live startup-lifecycle proof with Thalassian Phoenix Oil (`enchantID = 8051`) active on MainHand. Two genuine cold character logins automatically produced one managed Oil row with a working duration/timer. Neither required a manual `UpdateAllAuras()`, produced a stale zero-duration row, nor produced a duplicate row. `/reload` with the Oil already active also produced the correct row and timer. In the tested lifecycle, native right-click cancellation, fresh reapplication after login, and the native inventory tooltip worked; this was not a combat-cancellation validation. Native primary text displayed the equipped weapon name, as predicted by source.

This validates the generation-based quiet-turn recovery architecture and the tested MainHand Phoenix Oil lifecycle. The prototype registers both MainHand and OffHand, but this evidence does not constitute OffHand runtime validation or universal temporary-enchantment coverage.

### Remaining runtime validation

1. Repeat apply/remove/refresh and cold-login testing for OffHand.
2. Test simultaneous MainHand and OffHand enchantments and independent refresh/removal/cancellation.
3. Swap equipped weapons with no enchant, the same enchant ID, and a different enchant ID; confirm item name/icon refresh and no stale values.
4. Confirm duration reset behavior when a same-ID enchant is refreshed and `remainingTimeMs` increases across the broader cases.
5. Confirm zero, one, and multiple charges, including default application-count formatting.
6. Confirm any non-expiring result with `hidePermanent = false`, then separately validate `hidePermanent = true` if OBB wants timed-only policy.
7. Record exact inventory-tooltip contents across enchant types; a working native tooltip does not create an enchant-name resolver.
8. Confirm `RightButtonDown` cancellation in combat and for OffHand, including dual-wield; capture the first taint, blocked-action, or restriction error if any.
9. Confirm zero-active `1 x 1` and simultaneous two-row container sizing.
10. Confirm DEBUFFS-to-ENCHANTMENTS anchor propagation during combat updates, scale changes, and rapid dual-slot churn.
11. Query `C_PaperDollInfo.IsRangedSlotShown()` only as a diagnostic. Register/test Ranged later only in a Retail context that can actually exercise slot `18`.
12. Validate additional temporary-enchantment families before generalizing beyond the tested Phoenix Oil lifecycle.

### Runtime discrepancy: active weapon enchant not displayed by managed provider

**OBSERVED LIVE RESULT:** On Retail `12.1.0.69299`, Thalassian Phoenix Oil (item `243733`) successfully applied a temporary weapon enchant. Legacy OBB displayed its synthetic ENCHANTMENTS row with a duration and an equipped-weapon inventory tooltip. The isolated managed ENCHANTMENTS container displayed no item-enchantment row, with no OBB-attributable Lua error, taint, or blocked action. Food/Flask HELPFUL-aura routing is a separate product-parity question and is not evidence about this fixed-slot provider discrepancy.

**LEGACY PATH:** OBB registers `ADDON_LOADED`, `PLAYER_ENTERING_WORLD`, `UNIT_AURA`, `WEAPON_ENCHANT_CHANGED`, and `WEAPON_SLOT_CHANGED`. `RefreshAll()` rescans every product group. More importantly for cold-login recovery, every qualifying player `UNIT_AURA` callback rescans every group whose configured unit is `player`; the ENCHANTMENTS group is one of those groups. `Engine:Scan()` always calls `ScanWeaponEnchantments()` for that group, even though the triggering event concerned UnitAura data. `ScanWeaponEnchantments()` reads deprecated `GetWeaponEnchantInfo()`, whose Live 12.1 compatibility implementation calls `C_PaperDollInfo.GetTemporaryEnchantmentInfo` for MainHand, OffHand, and Ranged. For each true legacy `hasEnchant` position, OBB creates an addon-owned row: tuple position 1/2 selects `MainHandSlot`/`SecondaryHandSlot`, milliseconds become a local expiration timestamp, charges are copied, and the numeric enchant ID is stored as synthetic `spellID`. The tooltip uses the derived weapon inventory slot (`OdysseusBuffBars.lua:13-108,191-205,208-265,283-353`; `OdysseusBuffBars_Auras.lua:306-364,453-460`; `OdysseusBuffBars_Bars.lua:104-117,138-151,179-189,247-260`; `Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua:28-65`).

**PROTOTYPE REGISTRATION:** The working tree creates a third independent visible host/container, configures it disabled, sets unit `player`, applies vertical FlowLayout and item-enchantment layout, selects Duration/Reverse sorting, and registers exactly `MainHand` and `OffHand` with `hidePermanent = false`. It then shows the host, shows the container, and enables the container. This ordering makes `IsVisible() and IsEnabled()` true at enablement, so the earlier BUFFS failure mode of enabling a hidden container is not present. The initial enable registers `WEAPON_ENCHANT_CHANGED` and `WEAPON_SLOT_CHANGED` and synchronously calls the item manager refresh (`OdysseusBuffBars_ManagedPrototype.lua:403-518`; `Blizzard_AuraContainer.lua:22-33,54-66,107-178`; `Blizzard_ManagedAuraContainer.lua:25-56,246-337`).

**SLOT MAPPING:** Managed enum values are provider-side keys, not PaperDoll array indexes. `AuraContainerItemEnchantmentSlot.MainHand` (`0`) maps through `AuraContainerItemEnchantmentToInventorySlot` to `INVSLOT_MAINHAND` (`16`); `OffHand` (`1`) maps to `INVSLOT_OFFHAND` (`17`). `AuraContainerUtil.GetItemEnchantmentInfo` performs this conversion before calling the PaperDoll API. The prototype uses the correct enum domain (`Blizzard_AuraContainerShared.lua:9-28`; `Blizzard_AuraContainerUtil.lua:146-158`).

**ACTIVATION AND VISIBILITY CONDITIONS:** The PaperDoll API has no `hasEnchant` field. It returns nothing for an inactive slot, or one non-nil `TemporaryItemEnchantInfo` containing non-nil `enchantID`, `remainingTimeMs`, `chargesRemaining`, and `hasExpirationTime` fields. It does not return the queried slot or equipped-item identity; the caller already owns the inventory-slot input, and native presentation later resolves the item from that slot. The manager suppresses a non-nil result only when that registration has `hidePermanent = true` and the result has no expiration time. Otherwise it marks the slot active, creates AuraButton-compatible data, calls `SetAuraInstance`, shows the fixed frame, adds it to the active frame list, and supplies that list to FlowLayout. Zero ID, zero charges, zero remaining time, and `hasExpirationTime = false` do not suppress a registration when `hidePermanent = false`. A malformed timed result would encounter arithmetic/comparison code rather than silently fail. The fixed button is hidden while its aura data is nil or after disappearance/clear; a shown button is still not visible if its container or parent chain is hidden. Disabling the container clears active item data and hides the button (`PaperDollInfoDocumentation.lua:217-231,482-490`; `Blizzard_AuraContainerEnchantments.lua:178-220,234-353`; `Blizzard_ManagedAuraContainer.lua:25-56,246-337`; `Blizzard_CustomAuraButton.lua:576-596`; `Blizzard_CustomAuraContainer.lua:450-468,557-680`).

**LIFECYCLE GAP:** The prototype file executes during addon loading, before OBB's `ADDON_LOADED` and `PLAYER_ENTERING_WORLD` handlers. `AddItemEnchantment` and final `SetEnabled(true)` both query the PaperDoll API synchronously. Item-enchantment queries are not part of the later managed dirty `OnUpdate`; subsequent queries occur only on `WEAPON_ENCHANT_CHANGED`, `WEAPON_SLOT_CHANGED`, another public `UpdateAllAuras()`, or an enable/show/unit lifecycle update. The container itself does not register `PLAYER_ENTERING_WORLD` or `UNIT_INVENTORY_CHANGED`. Managed `UNIT_AURA` processing updates AuraGroups/AuraSlots and does not refresh item enchantments. Legacy OBB has a broader coupling: a later player `UNIT_AURA` rescan of its player ENCHANTMENTS group also reruns `GetWeaponEnchantInfo()`. This broad rescan is why the synthetic legacy row can recover after the early reads, while the managed item provider remains stale when no later native weapon event refreshes it (`OdysseusBuffBars.lua:284-353`; `OdysseusBuffBars_Auras.lua:368-460`; `Blizzard_AuraContainer.lua:81-92,125-144`; `Blizzard_ManagedAuraContainer.lua:304-380`).

**BLIZZARD CONSUMERS:** No Live Blizzard file calls `AddItemEnchantment`; the only match is the method definition. Current BuffFrame uses the PaperDoll getter directly rather than the managed item provider. There is therefore no working Blizzard consumer lifecycle against which to validate registration timing, initial refresh, or event ordering. This absence also prevents source alone from ruling out a Retail provider regression.

**INITIAL ROOT-CAUSE CLASSIFICATION (BEFORE RUNTIME PROBE):** **F — runtime data mismatch not resolvable statically.** Static inspection rules out wrong enum mapping, `hidePermanent`, sort options, registration omission, the hidden-at-enable ordering error, missing provider creation, and missing weapon-event registration. At this stage source could not prove what the PaperDoll getter returned at each managed refresh. The follow-up runtime result below proves that a later public refresh activates the provider and narrows the remaining problem to fresh-login readiness.

**MINIMAL SAFE LIVE PROBE:** With Phoenix Oil active and the managed row absent, run these separately. They print only the documented non-secret PaperDoll fields; `active` is represented by a non-nil structure, not a returned `hasEnchant` field.

```text
/run local e=C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND);print("MH",e and "active" or "none",e and e.enchantID,e and e.remainingTimeMs,e and e.chargesRemaining,e and e.hasExpirationTime)
/run local e=C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_OFFHAND);print("OH",e and "active" or "none",e and e.enchantID,e and e.remainingTimeMs,e and e.chargesRemaining,e and e.hasExpirationTime)
```

If the expected slot prints `active`, run this once out of combat as a lifecycle diagnostic, not as a workaround:

```text
/run _G.OdysseusBuffBars.ManagedPrototype.enchantmentContainer:UpdateAllAuras()
```

- If the row appears, the source-supported conclusion becomes category A: the initial/event refresh occurred before usable data or was otherwise missed. A later implementation task may then add one explicit post-world-entry refresh through the public method.
- If the getter prints `active` and the row still does not appear after that public refresh, stop; capture the printed tuple and treat a Blizzard provider/runtime regression or presentation visibility discrepancy as the next investigation.
- If the getter prints `none` while the legacy row remains visible, capture both observations without changing OBB. The provider cannot activate from nil, and the discrepancy lies below its eligibility code or in stale legacy presentation.

**INITIAL IMPLEMENTATION RECOMMENDATION (BEFORE RUNTIME PROBE):** Make no OBB code change until the probe above is complete. Do not add polling, delayed retries, a PaperDoll mirror, direct frame manipulation, or a fallback synthetic row to the managed prototype. The follow-up below records the completed probe and supersedes the earlier post-world-entry hypothesis.

### Fresh-login readiness / event ordering

**FOLLOW-UP RUNTIME RESULT:** With Thalassian Phoenix Oil already active, the PaperDoll probe returned `MH active 8051 1063382 0 true`; OffHand returned no structure. Calling the public managed-container `UpdateAllAuras()` then displayed the MainHand row. Adding a one-shot `PLAYER_ENTERING_WORLD` refresh made the row appear automatically after `/reload`, but a fresh character login still entered the world with no row. This proves the slot, eligibility, frame, and public refresh paths work. It also proves the first fresh-login `PLAYER_ENTERING_WORLD` callback can run before final temporary-enchantment data is visible to this addon, while reload has it populated by the time its world-entry refresh runs.

**CURRENT PROTOTYPE:** The read-only working tree registers `PLAYER_ENTERING_WORLD`, unregisters it on its first delivery, and calls `ManagedPrototype.enchantmentContainer:UpdateAllAuras()` (`OdysseusBuffBars_ManagedPrototype.lua:267-280`). This is a true one-shot and not polling. Its differing fresh-login and reload result follows the generated event's explicit `isInitialLogin` / `isReloadingUi` distinction, but generated documentation does not promise PaperDoll readiness at either form of the event (`SystemDocumentation.lua:114-143`).

**SOURCE-SUPPORTED ORDERING:** `PLAYER_LOGIN` is not a later alternative. AuraContainer source says configuration is allowed through `PLAYER_LOGIN` and defers access restrictions until `PLAYER_ENTERING_WORLD`, explicitly placing the latter after login signaling (`Blizzard_AuraContainerUtil.lua:285-300`). The generated event declarations provide synchronous/unique classifications and payloads, but no `GetTemporaryEnchantmentInfo` readiness guarantee for any login, equipment, inventory, bag, aura, loading-screen, or weapon event.

**MANAGED PROVIDER EVENTS:** A managed container with item registrations dynamically registers only `WEAPON_ENCHANT_CHANGED` and `WEAPON_SLOT_CHANGED`; either event directly calls `RefreshItemEnchantments()` (`Blizzard_AuraContainer.lua:81-92,125-144`; `Blizzard_ManagedAuraContainer.lua:304-328`). The fresh-login failure despite those registrations shows that this native event set does not naturally guarantee a refresh after a pre-existing enchant becomes readable. Source cannot distinguish whether no post-readiness weapon event fires or the engine exposes the data after the relevant event has already been delivered.

**OTHER BLIZZARD READERS:** BuffFrame registers the same weapon events, but its inherited listener also calls a complete `Update()` at `PLAYER_ENTERING_WORLD` and after qualifying player `UNIT_AURA` updates; every complete update re-reads all temporary-enchantment slots (`Blizzard_BuffFrame/BuffFrame.lua:275-301,448-466,667-702`; `BuffFrameTemplates.xml:130-141`). A later `UNIT_AURA` can therefore incidentally repair BuffFrame's early enchant read, but it is not an item-enchantment readiness contract. The older secure aura header continuously rechecks PaperDoll enchant presence from `OnUpdate` (`Blizzard_RestrictedAddOnEnvironment/SecureAuraHeader.lua:60-90`; `SecureAuraHeader.xml:4-12`); this is evidence that Blizzard's historical consumers did not rely on one enchant-ready event, not a pattern to copy. No current getter consumer uses an equipment event, bag event, loading event, one-shot timer, or bounded retry, and no Live Blizzard code consumes managed `AddItemEnchantment`.

| Candidate | Current 12.1 evidence | Decision |
|---|---|---|
| `PLAYER_LOGIN` | Source places it before `PLAYER_ENTERING_WORLD`. | Reject; it cannot solve a refresh already proven too early at world entry. |
| `PLAYER_ENTERING_WORLD` | Distinguishes initial login from UI reload. Runtime: sufficient on reload, too early on fresh login. | Keep only as an already useful early attempt; it is not the fresh-login completion signal. |
| `WEAPON_ENCHANT_CHANGED` / `WEAPON_SLOT_CHANGED` | The managed provider already registers both. Runtime still misses the pre-existing enchant. | Keep native ownership; do not duplicate them in OBB. They are not a proven initial-readiness guarantee. |
| `PLAYER_EQUIPMENT_CHANGED` | Synchronous event with slot/current-item payload. No PaperDoll enchant reader registers it, and documentation does not say it fires for unchanged login equipment. | Do not adopt without runtime evidence. A real equipment change is semantically different from loading an existing enchant. |
| `UNIT_INVENTORY_CHANGED` | Generated documentation defines a synchronous event with a unit-token payload. Blizzard uses `RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")` on ordinary frames. Repeated cold-login runs delivered an incomplete player callback followed by a timed-ready player callback. | Adopt only as a bounded initial-login recovery trigger. Runtime establishes the observed sequence; the event contract does not guarantee PaperDoll readiness. |
| `BAG_UPDATE_DELAYED` | Unique coalesced bag event; no temporary-enchantment reader uses it. | Reject as unrelated and potentially repeated. |
| `UNIT_AURA` | BuffFrame uses qualifying player updates to rebuild both buffs and enchantments. Managed item-enchantment refresh is not driven by this event. | Do not add as an enchant hook; it is semantically indirect, potentially frequent, and not readiness-guaranteed. |
| `FIRST_FRAME_RENDERED` | Unique event used by Blizzard with `VARIABLES_LOADED` and `PLAYER_ENTERING_WORLD` when work must wait until the first rendered frame; one consumer defers one additional frame with `C_Timer.After(0)` (`SystemDocumentation.lua:50-56`; `AlertFrames.lua:268-281`; `EventScheduler.lua:838-843`). | Narrowest later one-shot candidate to measure. Source does not connect it to PaperDoll readiness, so it is not yet a supported guarantee. |
| `LOADING_SCREEN_DISABLED` | Synchronous loading transition with no PaperDoll contract; it can recur on later loading screens. | Diagnostic candidate only, not the preferred production hook. |

**INTERMEDIATE CLASSIFICATION (SUPERSEDED BY FINAL RUNTIME RESULTS BELOW):** At this stage no deterministic event was source-proven, so a bounded retry remained possible. The subsequent repeated cold-login traces established an event-driven recovery policy without claiming a formal readiness guarantee.

**INTERMEDIATE LIFECYCLE DIRECTION (SUPERSEDED):** The first event-logger pass was used to choose between a later event and a bounded retry. The final result below replaces this provisional direction.

**COMPLETED STARTUP DIAGNOSTIC DESIGN:** A `/run` entered after login could not observe startup ordering, so the research used a temporary standalone diagnostic addon rather than an OBB modification. The original first-pass event logger was:

```text
## Interface: 120100
## Title: Enchant Readiness Probe
EnchantReadinessProbe.lua
```

This historical first pass sampled only the requested MainHand fields, ignored non-player unit events, and stopped when it first observed a non-nil structure:

```lua
local events = {
    "PLAYER_LOGIN",
    "PLAYER_ENTERING_WORLD",
    "FIRST_FRAME_RENDERED",
    "LOADING_SCREEN_DISABLED",
    "PLAYER_EQUIPMENT_CHANGED",
    "WEAPON_ENCHANT_CHANGED",
    "WEAPON_SLOT_CHANGED",
    "BAG_UPDATE_DELAYED",
    "UNIT_INVENTORY_CHANGED",
    "UNIT_AURA",
}

local frame = CreateFrame("Frame")

local function Sample(event, ...)
    if (event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_AURA") and (...) ~= "player" then
        return false
    end

    local info = C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND)
    local initialLogin, reloadingUI
    if event == "PLAYER_ENTERING_WORLD" then
        initialLogin, reloadingUI = ...
    end

    print(
        "EnchantReadiness",
        GetTime(),
        event,
        initialLogin,
        reloadingUI,
        info and "active" or "none",
        info and info.enchantID,
        info and info.remainingTimeMs
    )

    return info ~= nil
end

if not Sample("FILE_LOAD") then
    for _, event in ipairs(events) do
        frame:RegisterEvent(event)
    end

    frame:SetScript("OnEvent", function(self, event, ...)
        if Sample(event, ...) then
            self:UnregisterAllEvents()
        end
    end)
end
```

That first definition of readiness proved too weak because a timed enchant could be present with `remainingTimeMs = 0`. The diagnostic was subsequently extended to distinguish absent, present-incomplete, and timed-ready states and to include a bounded ticker. The accumulated results below complete that diagnostic phase.

### Final cold-login lifecycle conclusion

**FINAL RUNTIME SEQUENCE:** Multiple cold-login runs with Thalassian Phoenix Oil (`enchantID = 8051`) consistently observed:

```text
FILE_LOAD                    -> ABSENT
PLAYER_LOGIN                 -> ABSENT
PLAYER_ENTERING_WORLD        -> ABSENT
UNIT_INVENTORY_CHANGED player -> PRESENT_INCOMPLETE
                                enchantID = 8051
                                remainingTimeMs = 0
                                hasExpirationTime = true
subsequent UNIT_INVENTORY_CHANGED player -> TIMED_READY
                                           enchantID = 8051
                                           remainingTimeMs > 0
                                           hasExpirationTime = true
```

Timed-ready remaining values included `4698000`, `4510000`, and `4349000` milliseconds. Absolute startup timing varied substantially between runs. Later cold logins placed the first present record at inventory callback 1 but did not expose a timed-ready record until callback 430, 69, or 105. Successive callbacks sometimes received the same three-decimal elapsed display value; that formatting collision proves event order, not literally zero elapsed time or a common rendered frame. The ticker was not the first timed-ready source in the final runs.

**SOURCE FACTS:** Generated Retail 12.1 documentation defines `UNIT_INVENTORY_CHANGED` as a synchronous event with one `unitTarget` payload and does not mark it unique. Ordinary Blizzard frames use `RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")`, including MerchantFrame. This establishes that a player-filtered ordinary event-frame registration is supported. It does not promise initial delivery, a callback count, or PaperDoll readiness. Multiple callbacks and their incomplete-to-ready ordering are runtime observations, not API guarantees (`UnitDocumentation.lua:4183-4196`; `MerchantFrame.lua:7-15,108-115`; `FrameUtil.lua:45-49`).

**FINAL CLASSIFICATION:** This is a managed item-enchantment cold-login initialization race/missed-refresh problem. PaperDoll publishes the pre-existing timed-enchantment record in stages after `PLAYER_ENTERING_WORLD`: identity and expiration mode become visible before usable remaining duration. The managed provider's native weapon-event set does not refresh after the observed completion transition, so its earlier incomplete/absent refresh remains stale. A later public `UpdateAllAuras()` succeeds because the slot, registration, provider, frame, and presentation paths are otherwise valid. This is runtime-backed behavior, not a Blizzard-documented readiness contract or confirmed engine bug.

**SUPERSEDED CALLBACK-COUNT POLICY:** The earlier two-callback recovery recommendation is rejected. The 69/105/430 results establish that `UNIT_INVENTORY_CHANGED` is useful as activity evidence but has no stable ordinal meaning for temporary-enchantment readiness. Refreshing the managed container on every callback would turn one cold-login transition into dozens or hundreds of full refresh requests, while selecting any fixed callback number would merely encode one observed run.

### Startup inventory-burst coalescing

**SOURCE-BACKED COALESCING PATTERNS:** Current Blizzard code commonly marks work dirty and schedules only one zero-delay deferred cleanup. `PrivateAuraUnitWatcher:MarkDirty()` and `ZoneAbilityFrameUpdater:AddDirtyFrame()` use an `isDirty` guard plus `C_Timer.After(0, ...)`; Encounter Timeline uses a dirty mask plus a single `C_Timer.NewTimer(0, ...)`; bag, bank, and compact unit-frame code uses dirty state with per-frame `OnUpdate` processing to collapse frequent updates. These establish deferred dirty-work coalescing as an idiomatic pattern, including for inventory and high-frequency unit-frame work (`Blizzard_PrivateAurasUI.lua:1269-1279`; `ZoneAbility.lua:41-60`; `EncounterTimeline.lua:72-80,141-146`; `ContainerFrame.lua:37-59`; `BankFrame.lua:650-674`; `CompactUnitFrame.lua:202-237`).

Blizzard also has a genuine reset-on-event debounce primitive. `TimedCallbackMixin:RunCallbackAsync()` cancels its prior `C_Timer.NewTimer` handle and creates another; Character Create and Guild Rename use it to wait until repeated user input quiets. This verifies that `C_Timer.NewTimer()` handles support `:Cancel()` and that cancel-and-replace is supported current UI behavior, even though the generated `UITimerDocumentation.lua` lists the returned `TickerCallback` object without documenting its methods. Blizzard consumers retain the handle only while pending and clear their field during cancellation or callback cleanup; generated documentation does not promise a reusable post-fire handle (`TimedCallback.lua:1-21`; `Blizzard_CharacterCreate.lua:2087-2127`; `Blizzard_GuildRename.lua:371-390`; `EncounterTimeline.lua:72-80,141-146`).

**TIMER AND HELPER CONTRACT:** Generated Live documentation exposes `C_Timer.After(seconds, callback)`, `C_Timer.NewTimer(seconds, callback)`, and `C_Timer.NewTicker(seconds, callback, iterations)` in `Environment = "All"`; `NewTimer` and `NewTicker` return callback objects. The global `RunNextFrame(callback)` helper is currently defined in SharedXMLBase as exactly `C_Timer.After(0, callback)`. Blizzard itself uses zero-duration `After` and `NewTimer` calls for deferred work. For addon code, the generated `C_Timer.After(0, ...)` API is the narrower dependency; `RunNextFrame` adds no scheduling guarantee and is not a generated API. No current `CallMethodOnNextFrame` equivalent was found. Timer dispatch itself is not a combat deferral or privilege mechanism: its callback is ordinary addon execution, so safety depends on the operation invoked there (`UITimerDocumentation.lua:1-81`; `FunctionUtil.lua:126-128`).

**VALIDATED PROTOTYPE PATTERN:** Keep the early `PLAYER_ENTERING_WORLD -> enchantmentContainer:UpdateAllAuras()` attempt. Only for `isInitialLogin`, temporarily register `UNIT_INVENTORY_CHANGED` with the `player` unit filter. Each callback advances an inventory-activity generation. The first callback schedules one `C_Timer.After(0, ...)` check and later callbacks do not schedule duplicates. At the deferred check, compare the captured generation with the current generation: if it changed, capture the new value and schedule the check for the next frame again; if it remained unchanged across that deferred turn, unregister the temporary listener, clear the startup state, and call `enchantmentContainer:UpdateAllAuras()` exactly once. The registration is removed before invoking the managed refresh. The current prototype implements this exact lifecycle (`OdysseusBuffBars_ManagedPrototype.lua:267-318`).

This is a quiet-frame debounce built from Blizzard's pending-dirty/next-frame pattern. It does not inspect PaperDoll data, scan auras, count callbacks, choose milliseconds, retain a timer handle, or refresh once per event. During the observed 69/105/430 bursts, deferred checks coalesced continued activity and the final check performed one managed refresh only after a quiet turn. If events span multiple rendered frames, the generation continues to move and the check remains deferred. The listener and callbacks are startup-only and self-remove when the finite startup burst settles; steady state returns to the native weapon-event provider.

A simple one-next-frame pending flag might have been sufficient for the recorded diagnostic bursts because their readiness activity was tightly packed, and it is a real Blizzard coalescing pattern. It was not selected: neither the event contract nor three-decimal timestamps guarantee that every callback or the final PaperDoll publication occurs before the first deferred callback. Requiring one unchanged deferred generation adds a quiet-frame boundary without a hard-coded delay.

**UNNEEDED FALLBACK:** Classic reset-on-event debounce with a cancellable positive-delay `C_Timer.NewTimer` remains technically available, but the successful quiet-turn cold-login tests provide no reason to use it and no evidence-based interval. A one-shot positive timer started by the first callback is rejected because it would be a fixed startup delay. `C_Timer.NewTicker` and a permanent `OnUpdate` are unnecessary polling. A permanent inventory registration would retain unnecessary steady-state ownership and could amplify later bursts into full refreshes. None is part of the validated lifecycle.

**NO DELAYED EQUIPMENT EVENT:** `BAG_UPDATE_DELAYED` is a generated bag/container event and Blizzard uses it for bag consumers, but no `UNIT_INVENTORY_CHANGED_DELAYED`, equipment-batch-finished event, or temporary-enchantment-ready event was found. Nothing in its contract ties `BAG_UPDATE_DELAYED` to equipped inventory or staged PaperDoll temporary-enchantment publication, so it is not a replacement readiness signal.

**MANAGED REFRESH SUFFICIENCY:** One late public `UpdateAllAuras()` marks a full managed rebuild and synchronously invokes `RefreshItemEnchantments()`. The item manager re-reads each configured PaperDoll slot, reassigns a timed enchantment when its newly published remaining time exceeds the stored value, reconstructs duration/expiration data, initializes or updates its retained frame, rebuilds the active sorted frame list, and propagates dirty layout flags. The successful manual recovery agrees with that source path. No direct frame, duration, sort, or layout manipulation is required (`Blizzard_ManagedAuraContainer.lua:45-56,304-312`; `Blizzard_AuraContainerEnchantments.lua:160-227,286-323`).

**FINAL LIVE VALIDATION:** The quiet-turn implementation passed two genuine cold character logins with Thalassian Phoenix Oil already active on MainHand. In both, the managed row and timer appeared automatically without a manual refresh, stale zero-duration state, or duplication. Reload, native cancellation in the tested context, fresh post-login application, and native inventory tooltip also passed. Temporarily disabling only legacy OBB's synthetic MainHand/OffHand append path did not change the earlier managed missing-timer behavior, ruling out that legacy path as the cause. The result validates the managed MainHand startup lifecycle and the quiet-turn architecture on Retail Live; it does not validate OffHand, simultaneous slots, Ranged, permanent/zero-duration entries, combat cancellation, every temporary enchant, or enchant-name resolution.

**COMBAT:** `UpdateAllAuras()` is exposed through the container's secure inbound mixin specifically so external events can request a complete refresh. Its managed implementation marks a full rebuild and synchronously refreshes item enchantments when enabled. Neither that method nor `RefreshItemEnchantments()` contains an `InCombatLockdown` branch, and native weapon events invoke the same item-refresh path. The PaperDoll getter is not documented as secret-result data. Structurally, the recovery call is a refresh of an already configured long-lived container rather than combat-time registration or reconfiguration (`Blizzard_AuraContainer.lua:22-56`; `Blizzard_ManagedAuraContainer.lua:45-56,304-328`; `Blizzard_CustomAuraContainer.xml:4-15`).

Source still does not guarantee that a tainted addon call can never encounter a combat-context restriction after login, and a player can plausibly enter combat before delayed startup inventory callbacks. The smallest justified implementation is therefore to call `UpdateAllAuras()` directly without adding `InCombatLockdown`, `PLAYER_REGEN_ENABLED`, or a queue. Validate one fast-combat cold login with the production patch. Add a combat deferral only if that validation produces a concrete access failure; skipping the call would knowingly preserve the stale row.

**WHY LEGACY RECOVERS:** Legacy OBB does not register `UNIT_INVENTORY_CHANGED`. Its ENCHANTMENTS group is configured as a player HELPFUL group, and the general player `UNIT_AURA` handler rescans every player group. `Engine:Scan()` then unconditionally appends `ScanWeaponEnchantments()` for the ENCHANTMENTS kind, so a later unrelated player aura update re-reads `GetWeaponEnchantInfo()` and reconstructs the synthetic MainHand/OffHand row after PaperDoll has completed initialization. Configuration changes and `/obb refresh` can also rescan, while weapon events call `RefreshAll`; however, the automatic architectural recovery absent from the managed provider is the broad player-`UNIT_AURA` rescan. Managed `UNIT_AURA` processing updates AuraGroups/AuraSlots and does not refresh its parallel item-enchantment manager (`OdysseusBuffBars.lua:13-108,191-205,284-353`; `OdysseusBuffBars_Auras.lua:341-364,368-460`; `Blizzard_ManagedAuraContainer.lua:318-380`).

This does not validate the legacy UnitAura architecture. The weapon rows come from ordinary PaperDoll data through the deprecated compatibility wrapper; HELPFUL/HARMFUL identity scanning uses restricted UnitAura APIs and remains the reason for migration to managed AuraContainers. Reliable synthetic weapon recovery and unsafe legacy aura identity ownership are separate findings.

### Resolved research boundary: HELPFUL enhancement auras

Food, Flask/Phial, and Augment-related effects tested in the follow-up experiment were ordinary player HELPFUL aura spell identities. They remain separate from the native MainHand/OffHand PaperDoll provider and from the temporary-enchantment startup lifecycle documented here. Generated `C_Spell` metadata supplied useful readable names and descriptions but no formal Food, Flask, Phial, or Augment Rune categorizer; `IsConsumableSpell` returned false for the tested aura spells. Guarded out-of-combat semantic rediscovery and public candidate-filter reapplication worked for the tested HELPFUL cases, but semantic interpretation and visual routing remain addon policy. See [Aura Filters](AuraFilters.md), [Tooltip Integration](TooltipIntegration.md), and [Combat and Security Restrictions](CombatAndSecurityRestrictions.md).

This finding does not resolve temporary weapon-enchantment display-name lookup. The PaperDoll `enchantID` remains an opaque numeric identity with no verified spell-ID contract or supported name resolver.

**DIAGNOSTIC STATUS:** `OBBEnchantDiag` established staged cold-login publication, variable 69/105/430 inventory-event bursts, rejection of fixed callback ordinals, and the successful quiet-turn architecture. Two genuine cold logins have now validated the resulting lifecycle, so no additional startup timing diagnostics are currently required. The temporary diagnostic addon may be retired after this documentation synchronization.

## 18. Retail Files Inspected

Primary current Live files:

- `Blizzard_AuraContainer/Blizzard_AuraContainerEnchantments.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainer.lua`
- `Blizzard_AuraContainer/Blizzard_ManagedAuraContainer.lua`
- `Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua` / `.xml`
- `Blizzard_AuraContainer/Blizzard_AuraButton.lua` / `.xml`
- `Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua` / `.xml`
- `Blizzard_AuraContainer/Blizzard_AuraContainerFlowLayout.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerSources.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerShared.lua`
- `Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua`
- `Blizzard_SharedXML/EventUtil.lua`
- `Blizzard_SharedXMLBase/FunctionUtil.lua`
- `Blizzard_SharedXMLBase/TimedCallback.lua`
- `Blizzard_SharedXMLBase/AnchorUtil.lua`
- `Blizzard_PrivateAurasUI/Blizzard_PrivateAurasUI.lua`
- `Blizzard_ZoneAbility/ZoneAbility.lua`
- `Blizzard_EncounterTimeline/EncounterTimeline.lua`
- `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua`
- `Blizzard_UIPanels_Game/Mainline/BankFrame.lua`
- `Blizzard_UnitFrame/Shared/CompactUnitFrame.lua`
- `Blizzard_ObjectAPI/Mainline/Item.lua`
- `Blizzard_BuffFrame/BuffFrame.lua`
- `Blizzard_RestrictedAddOnEnvironment/SecureAuraHeader.lua` / `.xml`
- `Blizzard_FrameXML/Mainline/AlertFrames.lua`
- `Blizzard_UIPanels_Game/Mainline/EventScheduler.lua`
- `Blizzard_FrameXML/SecureTemplates.lua`
- `Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua`
- generated `UITimer`, `PaperDollInfo`, `AuraContainerShared`, `AuraContainerUtil`, `Item`, `System`, `Unit`, `UnitAura`, `Container`, and `LoadingScreen` documentation

Read-only active OBB context:

- `OdysseusBuffBars.lua`
- `OdysseusBuffBars_Auras.lua`
- `OdysseusBuffBars_Bars.lua`
- `OdysseusBuffBars_Config.lua`
- `Documentation/ARCHITECTURE.md`
- `Documentation/MANAGED_AURACONTAINER_MIGRATION.md`

## 19. Related Documents

- [Architecture](AuraContainerArchitecture.md)
- [AuraContainers](AuraContainers.md)
- [Filters](AuraFilters.md)
- [Sorting](AuraSorting.md)
- [Tooltip Integration](TooltipIntegration.md)
- [Combat and Security Restrictions](CombatAndSecurityRestrictions.md)
- [Open Questions](OpenQuestions.md)
