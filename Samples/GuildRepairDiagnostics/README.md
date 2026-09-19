# GuildRepairDiagnostics

Standalone, evidence-only Retail Guild Bank initialization and later Guild Repair experiment observer. Research baseline: [GuildRepairFunding.md](../../12.1.0/Analysis/GuildRepairFunding.md).

## Purpose and boundaries

The diagnostic records raw observations. It does not infer Guild/personal contributions, repair success/completion, cache validity, funding source, or causation. It never invokes a repair, tab query, merchant/bank transaction, interaction, bank UI loading/showing, or manufactured event. There is no polling, OnUpdate, or settlement timer. No OUS integration or modification is included.

Install this complete directory as `GuildRepairDiagnostics` under Retail `Interface/AddOns`. It is independent of RetailUIResearch and depends only on `Blizzard_SharedXML` for its copyable viewer. There is deliberately no `Blizzard_GuildBankUI` dependency.

## Source and validation status

Design/implementation source: current local `live` HEAD `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`, Retail `12.1.0.69814`. This source provenance is distinct from each run's actual `GetBuildInfo()` returns. Interface `120100` follows the current Retail 12.1 repository convention.

Current-source references: generated PlayerInteractionManager, PlayerInteractionManagerConstants, GuildBank, MerchantFrame, GuildInfo, CurrencyInfo, Os and FrameScript documentation; Guild Bank bootstrap, Mainline Lua/XML, and TOC; Shared player-interaction frame manager; SharedXML `Shared/Scroll/ScrollTemplates.lua` / `.xml` and TOC. The viewer follows the existing Async diagnostic pattern without importing that diagnostic's observers.

Controlled out-of-combat runtime use is recorded in the canonical Logs01–08 series summarized by the linked analysis. The query hook and natural Guild Bank lifecycle observers installed in those runs, the viewer exported the retained evidence, and the PRE marker captured the tested repair boundaries. This remains bounded runtime evidence: query-hook coverage is unverified, callback ordering is not universal, snapshots are sequential rather than atomic, and combat/taint behavior is untested.

## Commands and retention

| Command | Behavior |
| --- | --- |
| `/ousrd start <label>` | After player login, starts a run with a bounded label and START snapshot. Refuses an active run or retained evidence; use `/ousrd clear` first after exporting it. |
| `/ousrd stop` | Records STOP with the final snapshot and preserves the completed run. |
| `/ousrd show` | Lazily opens/refills a scrollable multiline viewer. Click text, Ctrl+A, Ctrl+C. Does not capture a new snapshot or change evidence/collection. |
| `/ousrd clear` | Explicitly clears retained evidence; refuses while a run is active. |

Closing the viewer, Merchant, or Guild Bank does not stop a run. The viewer refreshes only on explicit SHOW, not inside event/hook callbacks. Typing in its copy surface restores the rendered captured text; it never edits the stored evidence.

One SavedVariables table, `GuildRepairDiagnosticsDB`, retains at most one run. A new run never silently overwrites it. Logout/reload during collection records an interrupted terminal observation and does not resume collection. If a saved active run is recovered without an observed terminal event, it is marked interrupted with no fabricated prior-session timestamp or current-session snapshot. Incompatible storage is preserved and refused rather than silently reset. SavedVariables is not a crash-safe journal.

## Evidence schema and bounds

Run metadata contains diagnostic/schema version, bounded label, raw runtime client-build returns, design-source commit/build, collection status, instrumentation state, maximum records, sequence, and dropped-observation information.

| Record field | Meaning |
| --- | --- |
| `seq` | Authoritative monotonically increasing observer order within the run. |
| `elapsed` | Callback-recording time from `GetTimePreciseSec()` minus run start. Recovery instead explicitly reports unavailable prior-session elapsed time. |
| `kind`, `name` | START, EVENT, MARK, QUERY_POST, FRAME_SCRIPT_POST, lifecycle, STOP, or INTERRUPTED; exact observation name. |
| `args` | Explicit `n`, positional encoded `values`, and explicit omitted count if the argument bound is exceeded. Nil positions retain a `valueType="nil"` entry. |
| `snapshot` | Guarded sequential API/UI observations. |
| `fields` | Copied primitive contextual fields on an external marker. |

Maximum **512 retained records**: preserve the earliest 511 observations and reserve one terminal STOP/interruption slot. Later observations increment dropped count and expose first/last dropped sequence and last dropped elapsed time. Retained events are neither overwritten nor aggregated. Export includes the loss information.

Bounds: label 128 bytes (explicit truncation flag); marker name 96 bytes; at most 16 fields; nonempty string keys up to 64 bytes; field strings up to 256 bytes. Marker fields accept ordinary strings, finite numbers, and booleans, without nested tables/metatables. Invalid/oversized markers are refused, not silently truncated. API/event strings over 2,048 bytes become explicit unexportable entries; arguments retain their original count with at most 32 encoded positions. No unbounded strings, caller tables, stack dumps, or historical run list are retained.

Ordinary numeric values remain raw numbers, including large positive withdrawal values. The viewer uses precision-preserving numeric formatting; it never translates a withdrawal value to `unlimited`. Returned false, zero, nil, unavailable APIs/frames, skipped context, call errors, and secret/unexportable values remain distinct. Missing secret-check support fails closed; secret values/error objects are not stringified or persisted.

## Snapshots and events

Snapshots read `GetMoney`, `IsInGuild`, combat state, MerchantFrame/GuildBankFrame existence and shown state, and `IsInteractingWithNpcOfType` for current `Enum.PlayerInteractionType.Merchant` / `GuildBanker` members. Guild-money getters are read only after login for an established guilded player, including the initial pre-bank snapshot. `CanMerchantRepair` requires Merchant context; `GetRepairAllCost` additionally requires repair capability and preserves both returns. `CanGuildBankRepair` requires Merchant or Guild Bank context. Calls are guarded; errors do not become readiness conclusions.

Snapshots are **sequential, not atomic**. Visible getter callers read state; native getter side effects remain unresolved. Observation itself may affect timing. Timestamp/sequence order describes this observer's callbacks, not universal server ordering or causation.

Research events: `PLAYER_MONEY`, `MERCHANT_SHOW`, `MERCHANT_UPDATE`, `MERCHANT_CLOSED`, `GUILDBANK_UPDATE_MONEY`, `GUILDBANK_UPDATE_WITHDRAWMONEY`, `GUILDBANKFRAME_OPENED`, `GUILDBANKFRAME_CLOSED`, `PLAYER_GUILD_UPDATE`, `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`, and `PLAYER_INTERACTION_MANAGER_FRAME_HIDE`. Preserve actual varargs. Current declarations provide `unitTarget` for PLAYER_GUILD_UPDATE and interaction `type` for the manager events; the other listed events declare no payload. Numeric interaction arguments remain raw; snapshot calls use enum members, not hardcoded interaction numbers.

ADDON_LOADED/login/logout handling is lifecycle infrastructure, not an invented research event or data request. Event registration failures appear in instrumentation metadata.

## Passive instrumentation

Attempt `hooksecurefunc("QueryGuildBankTab", callback)` once when the global/hook naturally become available. Availability checks are event-driven during addon loading/login/start; a rejected installation is not repeatedly attempted. The callback is inert without an active run and records original arguments plus a snapshot as **POST-CALL** evidence. It does not call the query or modify its arguments/results. Successful registration does not prove complete coverage, a successful data request, or freshness. Security checks around registration are metadata, not safety certification.

After the real GuildBankFrame naturally exists, attach `HookScript` observers once for OnShow/OnHide, including the already-loaded case. These are **POST-SCRIPT** records. The original OnShow may already have queried a bank tab before its marker. No original script is replaced and the diagnostic never opens/closes/loads the bank UI.

Installed hooks cannot be removed by STOP; their callbacks simply become inert outside collection. If instrumentation is unavailable/fails, retain its status and continue event observation without inventing query/script occurrences. Absence of a marker does not prove absence of a call. Native hook registration may affect observable function identity/security provenance; it is not an addon-written replacement, and stable identity is not promised.

Blizzard's interaction event handler can load/show/query before this observer receives the same event. Events may also occur inside the native query before its post-hook callback. Consequently this instrumentation does not generally provide state immediately before query entry, and an earlier observer record than QUERY_POST is not automatically pre-call evidence.

## External marker API

`GuildRepairDiagnostics.Mark(name, fields)` returns collection status only: `true, "recorded"` or `false, reason`. It never reports transaction success. It copies bounded primitive fields and captures a snapshot only during an active run.

The completed controlled repair runs used a temporary OUS test instrumentation block that placed this marker immediately before its existing repair call:

```lua
GuildRepairDiagnostics.Mark("PRE_GUILD_REPAIR", {cost = cost})
-- The test instrumentation's existing repair call followed here; this addon performed none.
```

No RepairAllItems post-hook was used as a substitute for that explicit pre-call placement. The temporary OUS instrumentation remained outside this sample.

## First controlled experiment (completed out of combat)

1. Enable GuildRepairDiagnostics.
2. Fully exit WoW.
3. Start WoW and log in.
4. Do NOT open Guild Bank before starting the run.
5. Perform no repair.
6. Perform no guild-bank money transaction.
7. `/ousrd start cold-bank-open`
8. Open Guild Bank normally through the player interaction.
9. Wait only for the natural UI/event activity needed to settle visually; do not invoke diagnostic actions that request data.
10. `/ousrd stop`
11. `/ousrd show`
12. Copy the evidence.

If repeating this procedure, export retained evidence and explicitly clear it first. Check reported instrumentation availability and dropped counts in the export. The completed Log01 run narrowed ordering/timing boundaries only; it did not by itself prove causation, cache validity, or any funding conclusion.
