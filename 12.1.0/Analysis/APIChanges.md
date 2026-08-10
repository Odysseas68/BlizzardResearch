# API Changes

## Chronology

| Build stage | Added or changed | Removed or superseded | OUS significance |
| --- | --- | --- | --- |
| PTR1 | AuraContainer, AuraButton, forbidden aspects | Direct UnitAura access announced for restriction | New secure ownership model begins |
| PTR2 | Native dispel/tooltip presentation | Addon extraction becomes less necessary | Rendering can stay native |
| PTR3 | ManagedAuraContainer, automatic model preview | Broad direct scans restricted | Managed migration path appears |
| PTR4 | Groups, slots, candidate filters, sort/layout, private auras, enchants | `AddAuraFrame`; Mainline SecureAuraHeader | Framework owns frames and source flow |
| PTR5 | `IMPORTANT`, `DISPELLABLE`, conditional access restrictions | Unrestricted post-init button access | Combat access must be contextual |
| PTR6 | Group frame/filter mutation, ApplicationBar, layoutIndex, access introspection, sounds | Reparenting of buttons/children | Richer declarative display, tighter ownership |
| PTR7 | Flow columns, combat creation, tooltip policy/style, multiple dispel textures, AuraInstanceIDOnly | Earlier row-only layout surface | Presentation/layout API still moving |

## Current CustomAuraContainer Methods

### Lifecycle

- `IsEnabled`, `SetEnabled`
- `GetUnit`, `SetUnit`
- `UpdateAllAuras`

### Groups

- `AddAuraGroup`, `HasAuraGroup`
- `GetAuraGroupFrame`, `GetAuraGroupFrameCount`
- `SetAuraGroupFilterString`
- `SetAuraGroupMaxFrameCount`
- `SetAuraGroupCandidateFilters`
- `SetAuraGroupSortMethod`
- `SetAuraGroupLayout`

### Slots

- `AddAuraSlot`
- `SetAuraSlotFilterString`
- `SetAuraSlotCandidateFilters`
- `SetAuraSlotSortMethod`

### Enchantments

- `AddItemEnchantment`
- `SetItemEnchantmentSortMethod`
- `SetItemEnchantmentLayout`
- `ResetItemEnchantmentLayout`

### Processing

- `GetAuraProcessingPolicy`
- `SetAuraProcessingPolicy`

### Flow Layout

- `Get/SetFlowLayoutAxis`
- `Get/SetFlowLayoutAnchorPoint`
- `Get/SetFlowLayoutGrowthDirection`
- `Get/SetFlowLayoutPadding`
- `Get/SetFlowLayoutMaximumLineSize`
- `ResetFlowLayoutOptions`

## Superseded PTR Names

**FACT:** Current build no longer uses the earlier public names `Get/SetAuraLayoutAnchorPoint`, `Get/SetAuraLayoutGrowthDirection`, `Get/SetAuraLayoutPadding`, `Get/SetAuraLayoutRowWidth`, or `ResetAuraLayoutOptions`.

**FACT:** Current group layout replaces `elementSpacingX/Y`, `gapX/Y`, and `forceNewRow` with `elementSpacing`, `lineSpacing`, `groupSpacing`, `groupLineSpacing`, and `forceNewLine`.

## Current AuraButton Surface

- Cancellation: `SetCancelAuraButtons`
- Tooltip: anchor and combat-hide methods
- Application: count and interpolation bar
- Dispel: multiple textures and text
- Duration: cooldown, text, and bar
- Identity display: icon and spell name

**FACT:** Deprecated `AuraBorder` and `AuraSymbol` aliases remain for 12.1 compatibility but are marked for removal.

## Access and Generic Frame APIs

- `HasAccessConstraints`
- `CanBeAccessedInContext`
- `ResizeToBoundsRect` (generic protected Frame API)

**RECOMMENDATION:** Do not infer that a generic protected method is required or safe for AuraContainer use merely because it exists. Follow actual consumer patterns and runtime tests.

## Stability Classification

| Area | Assessment | Confidence |
| --- | --- | --- |
| Container ownership | Stable direction | High |
| Managed parse/assign pipeline | Stable direction | High |
| Groups/slots/enchantments | Structurally stable | Medium-high |
| Security/access policy | Stable intent, evolving timing | Medium |
| Flow layout names/options | Recently restructured | Medium-low until Live |
| Tooltip/dispel/application options | Expanded recently | Medium-low until Live |

