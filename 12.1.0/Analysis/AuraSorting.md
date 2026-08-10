# Aura Sorting

## Current Sort Surface

**FACT:** Current sort rules are `Default`, `BigDefensive`, `UnitFrameDebuff`, `ImportantOnly`, `Expiration`, `ExpirationOnly`, `Name`, `NameOnly`, and `AuraInstanceIDOnly`. Directions are `Normal` and `Reverse`.

## Comparator Behavior

| Rule | Primary behavior | Tie behavior |
| --- | --- | --- |
| Default | Player source, priority, applicability | Aura instance ID |
| BigDefensive | Non-player source first, later expiration | Aura instance ID |
| UnitFrameDebuff | Dispel/debuff type, then Default | Aura instance ID |
| ImportantOnly | Important first | Aura instance ID |
| Expiration | Default-like priorities, then earliest timed; permanent last | Aura instance ID |
| ExpirationOnly | Earliest timed; permanent last | Aura instance ID |
| Name | Default-like priorities, then name | Aura instance ID |
| NameOnly | Name | Aura instance ID |
| AuraInstanceIDOnly | Aura instance ID | None beyond ID |

**FACT:** Reverse direction swaps comparator operands and therefore reverses every criterion, including the instance-ID tie breaker.

**OBSERVATION:** The implementation produces deterministic ordering through explicit tie breaks. It does not establish a general stable-sort guarantee.

## Security Significance

**ANALYSIS:** Native sorting is the safe replacement for Lua comparison of expiration, names, source units, or priority flags that can become secret. `AuraInstanceIDOnly` is a deterministic fallback when semantic ordering is not wanted.

## BuffBars Mapping

| Frozen option | Native mapping | Caveat |
| --- | --- | --- |
| Time left | See [Odysseus BuffBars Compatibility](#odysseus-buffbars-compatibility) | Direction verification completed through the full legacy OBB sorting pipeline |
| Name | `NameOnly` | Native order may differ by locale/collation details |
| Default | `Default` | Blizzard policy is richer than registration order |

**RECOMMENDATION:** Preserve user-visible intent, not the frozen comparator implementation. Confirm each OUS label against in-game examples before migration.

## Legacy Time Left Semantics

**FACT:** The legacy OBB `Time Left` path was verified from configuration and defaults through `OBB:RefreshAll()`, `Engine:GetSortRule()`, `Engine:GetSortedAuraIDs()`, and `Engine:Scan()`.

**FACT:** Its user-visible order is:

1. Timeless or permanent auras first.
2. Timed auras from longest remaining duration to shortest remaining duration.
3. Equal expiration timestamps by descending `auraInstanceID`.
4. Timeless auras share the permanent sentinel and therefore also use descending `auraInstanceID`.

### Expiration, Remaining Time, and Original Duration

**FACT:** The comparator orders absolute expiration timestamps. At a fixed observation time, a later expiration timestamp also has more remaining time, so this appears to users as longest remaining duration first.

**FACT:** Original duration is not the comparison key. Two auras with equal original durations can have different expiration timestamps when they were applied or refreshed at different times.

**ANALYSIS:** Describing this behavior as "Time Left" is accurate for presentation, but implementation work should preserve expiration ordering rather than compare displayed countdown strings or original durations.

## Resort Behavior

**FACT:** Legacy OBB does not continuously reorder merely because countdown text decreases. Ordering is recomputed when aura state is refreshed, including:

- `UNIT_AURA`.
- Login.
- Reload.
- Explicit refresh.
- Configuration changes.
- Weapon-enchantment updates.
- Aura application.
- Aura refresh.
- Aura removal.

**FACT:** Countdown progression alone cannot cause two fixed expiration timestamps to cross. Their relative expiration order remains unchanged until the underlying aura state changes.

## Growth Direction

**FACT:** Grow Up and Grow Down do not alter semantic sorting. Index 1 always represents the first aura in the sorted result.

**FACT:** Growth direction changes only visual placement. Grow Up places successive indices in the opposite screen direction, which visually reverses the reading direction without reversing the sorted data.

**RECOMMENDATION:** A managed implementation should keep sort configuration independent from layout growth direction.

## Odysseus BuffBars Compatibility

**FACT:** The verified native managed configuration that preserves the legacy OBB `Time Left` behavior is:

```text
AuraContainerSortMethod.ExpirationOnly
+
AuraContainerSortDirection.Reverse
```

This preserves timeless auras first, followed by timed auras from longest remaining duration to shortest remaining duration, with descending `auraInstanceID` tie ordering.

**RECOMMENDATION:** Use this managed configuration instead of reproducing Blizzard's comparator in addon code. Sorting must remain inside Blizzard's managed pipeline; do not manually reorder AuraButtons.
