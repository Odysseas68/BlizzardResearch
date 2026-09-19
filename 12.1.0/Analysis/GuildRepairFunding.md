# Retail Guild Repair Funding

## 1. Scope and research question

This is the canonical, incremental BlizzardResearch record for the ongoing Retail Guild Repair funding investigation. The central question is how to establish reliable funding behavior and attribution when `GetGuildBankMoney()` can report 0 after a full client restart even though a native guild-first repair succeeds.

This document consolidates the completed source investigation, previously recorded controlled OUS runtime results, and the standalone diagnostic's completed Logs01–08 initialization and repair series. It does not modify OUS production behavior, implement a diagnostic, or establish a universal funding or cache contract.

| Evidence label | Meaning in this record |
| --- | --- |
| **VERIFIED SOURCE FACT** | Directly established by the inspected Lua/XML, TOC, or generated declaration. |
| **VERIFIED RUNTIME RESULT** | Previously recorded controlled runtime observation supplied by the user; bounded to that test. |
| **SOURCE-SUPPORTED INFERENCE** | Interpretation supported by source, without an explicit native contract. |
| **ASSUMPTION** | An unverified premise, not usable as established behavior. |
| **UNRESOLVED** | Available evidence does not settle the question. |

Runtime test dates, client builds, and complete addon compositions were not established for the earlier OUS observations. Logs01–08 report their client build separately in section 8; their test dates and complete addon compositions remain unspecified. No runtime tests were performed by Codex for this documentation task. Missing provenance remains missing rather than being inferred from the source snapshots.

Keep four roles separate:

| Role | Meaning |
| --- | --- |
| GETTER / READER | Returns client-known state; native side effects require separate evidence. |
| REQUEST / TRIGGER | Causes data to be requested or initialized. |
| NOTIFICATION EVENT | Announces that state changed or became available. |
| TRANSACTION | Performs an operation that may itself cause state to update. |

An event is not a refresh request. `RepairAllItems(true)` is a transaction, not a refresh API.

## 2. Source provenance

**VERIFIED SOURCE FACT — completed investigation provenance:**

| Snapshot | Branch | Commit | Retail build |
| --- | --- | --- | --- |
| Current LIVE inspected | `live` | `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59` | `12.1.0.69814` |
| Historical comparison | Historical commit in the LIVE mirror | `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4` | `12.1.0.69497` |

The mirror inspected was `D:\WowDEV\Reference\Blizzard\wow-ui-source`. The compared Merchant Lua/XML, Guild Bank UI, MoneyFrame, player-interaction manager, and generated Guild Bank documentation were unchanged between these snapshots. The historical comparison commit is not established as the exact revision used by every earlier Merchant investigation.

The completed investigation searched beyond MerchantFrame and walked participating Lua/XML handlers, mixins, inherited templates, helpers, and load boundaries in both directions. Mainline and Retail-relevant Shared code support the findings below. This documentation task does not repeat that broad investigation.

Important source surfaces, relative to `Interface/AddOns/` at the inspected revision:

| Surface | Files / implementation context |
| --- | --- |
| Merchant | `Blizzard_UIPanels_Game/Mainline/MerchantFrame.lua`, `MerchantFrame.xml`; `Blizzard_UIPanels_Game_Mainline.toc` |
| Guild Bank | `Blizzard_GuildBankUI/Mainline/Blizzard_GuildBankUI.lua`, `Blizzard_GuildBankUI.xml`; `Blizzard_GuildBankUI_Bootstrap.lua`; `Blizzard_GuildBankUI_Mainline.toc` |
| Money displays | `Blizzard_MoneyFrame/Shared/MoneyFrame.lua`; `Blizzard_MoneyFrame/Mainline/MoneyFrame.lua`, `MoneyFrame.xml`; `Blizzard_MoneyFrame_Mainline.toc` |
| Interaction lifecycle | `Blizzard_UIPanels_Game/Shared/PlayerInteractionFrameManager.lua` (Lua-created manager, no companion XML); generated `PlayerInteractionManagerDocumentation.lua` |
| Guild Bank declarations | `Blizzard_APIDocumentationGenerated/GuildBankDocumentation.lua` |
| Reached helpers/templates | `Blizzard_SharedXML/AddOnUtil.lua`, `PortraitFrame.lua`, Mainline `SharedUIPanelTemplates.xml`; `Blizzard_UIPanelTemplates/Mainline/UIPanelTemplates.xml` |
| Supplementary callers | `Blizzard_StaticPopup_Game/GameDialogDefs.lua` repair callbacks; `Blizzard_GuildControlUI/Blizzard_GuildControlUI.lua` affordability reader |

Source references below use file/function or XML handler names rather than unverified line numbers. Existing [ButtonsAndFrames.md](ButtonsAndFrames.md) and [Tabs.md](Tabs.md) retain the frame/template and tab-system research; this record addresses funding rather than duplicating those inventories.

## 3. Blizzard native Merchant Guild Repair path

**VERIFIED SOURCE FACT:** `MerchantFrame_OnLoad()` registers `GUILDBANK_UPDATE_MONEY`. `MerchantFrame_OnShow()` and merchant update paths update repair controls. `MerchantFrame_UpdateRepairButtons()` uses `CanGuildBankRepair()` for guild-repair availability; repair-state helpers use `GetRepairAllCost()`.

`MerchantFrame_OnEvent()` has a branch handling both `GUILDBANK_UPDATE_MONEY` and `GUILDBANK_UPDATE_WITHDRAWMONEY`. A corresponding registration for the withdrawal-money event on the main MerchantFrame was not found.

**VERIFIED SOURCE FACT:** the Guild Repair button's XML tooltip `OnEnter` reads both money getters and calculates a displayed available amount:

```lua
local amount = GetGuildBankWithdrawMoney()
local guildBankMoney = GetGuildBankMoney()
if amount == -1 then
    amount = guildBankMoney
else
    amount = min(amount, guildBankMoney)
end
```

The same button's `OnClick` checks `CanGuildBankRepair()` and calls exactly one `RepairAllItems(true)`. It does not require the getters to demonstrate full repair coverage first.

No explicit guild-money refresh/request was found in the inspected merchant load/show, repair-control update, or tooltip path. **UNRESOLVED:** native side effects of called APIs are not exposed by those Lua/XML callers.

## 4. Blizzard developer comments

These are **VERIFIED SOURCE FACTS about comments**, not runtime results.

| Source context | Comment / literal evidence | Interpretation boundary |
| --- | --- | --- |
| `MerchantFrame.xml`, Guild Repair button `OnClick` | `--FIXME!!! Need actual amount of guild money left to withdraw` | Blizzard records missing/insufficient information around the amount available to withdraw at this repair path. It does not explain cold-cache behavior, getter lifetime, the large positive withdrawal value, transaction funding internals, or a refresh mechanism. |
| Same button, tooltip `OnEnter`, `amount == -1` branch | "Guild leader shows full guild bank amount" | Explains that tooltip display branch. It does not document a large positive unlimited sentinel. |
| Same tooltip, insufficient-guild-funds branches | Comments describe repair cost exceeding available guild funds and whether personal money can make up the difference. | Describes tooltip construction, not proof of the native funding algorithm or correctness with uninitialized getter values. |
| Guild Bank Lua, `OnEvent`, rank-change branch | Query for new item data after the specified rank change. | Supports the tab-data request purpose, not a money-refresh guarantee. |
| Guild Bank Lua, `GuildBankTabMixin:OnClick()`, item-log branch | "Need this to get the number of withdrawals left for this tab" | Concerns tab withdrawals, not an established refresh of money-withdrawal allowance. |
| Guild Bank Lua, `Update()` tail | "Update remaining money" precedes `UpdateWithdrawMoney()`. | The implementation reads getters and updates UI; the comment does not establish a server request. |
| Mainline MoneyFrame Lua, event setup and `MoneyFrame_UpdateMoney()` | Comments describe registering relevant events and updating money shown in a frame. | Supports notification/display ownership, not underlying-state refresh. |
| Shared player-interaction manager, registration documentation | Loading may occur before showing a frame that is not yet loaded. | Establishes lifecycle sequencing, not money initialization. |

**SOURCE-SUPPORTED INFERENCE:** display information and native repair execution are separate paths. The FIXME does not settle why their observed information can differ.

## 5. Guild Bank UI initialization path

**VERIFIED SOURCE FACT:** the bootstrap registers `GuildBankFrame` for `Enum.PlayerInteractionType.GuildBanker`. The Guild Bank addon is load-on-demand. The normal opening chain is:

```text
GuildBanker player-interaction show notification
  -> load Guild Bank UI if needed
  -> show GuildBankFrame
  -> OnShow / tab selection
  -> QueryGuildBankTab(currentTab)
```

The XML binds lifecycle scripts to `GuildBankFrameMixin`. `OnShow()` invokes the first bottom tab's handler, which selects bank mode and queries the current bank tab. Selecting an available bank tab can also reach `QueryGuildBankTab()`.

`QueryGuildBankTab()` is an explicit **UI-owned tab-data request**. Other inspected branches query tab text or logs for their respective views; log queries are not a repair-attribution proposal.

Guild Bank UI separately reads both money getters. Bank `Update()` displays `GetGuildBankMoney()`; `UpdateWithdrawMoney()` reads the withdrawal value and, when applicable, bank money. XML money frames select `GUILDBANK` / `GUILDBANKWITHDRAW` types whose helpers subscribe to notifications and update displays.

No explicit money-specific request was established. **UNRESOLVED:** money state may arrive through native GuildBanker interaction, `QueryGuildBankTab`, another native mechanism, or a combination. Source does not establish that the tab query refreshes money, nor its validity at a normal merchant.

## 6. Getter and event findings

| API | VERIFIED SOURCE FACT | UNRESOLVED |
| --- | --- | --- |
| `GetGuildBankMoney()` | Inspected Lua/XML callers use it as a reader. No verified request side effect was found. | Native implementation and any native side effects were not visible. |
| `GetGuildBankWithdrawMoney()` | Inspected callers use it as a reader. Merchant tooltip handles `-1`; bank withdrawal display handles negative values as unlimited. | Native implementation, cold-state meaning, and meaning of the observed large positive value. |
| `CanGuildBankRepair()` | Used as an eligibility predicate. No refresh side effect established. | Native implementation and its relationship to money-state readiness. |

The native getters must not be declared reader-only solely from visible caller behavior.

| Event | Relevant visible consumers | Classification from Lua perspective |
| --- | --- | --- |
| `GUILDBANK_UPDATE_MONEY` | MerchantFrame, GuildBankFrame, `GUILDBANK` MoneyFrame type | Notification; controls/displays update and getters are reread. |
| `GUILDBANK_UPDATE_WITHDRAWMONEY` | GuildBankFrame, `GUILDBANKWITHDRAW` MoneyFrame type; Merchant handler branch without main-frame registration found | Notification; no underlying money request visible in these handlers. |
| `GUILDBANKFRAME_OPENED` / `CLOSED` | Generated declarations; no relevant Mainline Lua consumer found in the completed search | No request mechanism established through these legacy events. |

Current bank UI opening uses `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` with the GuildBanker interaction type. This notification reaches a UI lifecycle that queries tab data; listening for it is not itself a request. Hiding the bank calls `CloseGuildBankFrame()`.

Generated `SynchronousEvent = true` metadata does not establish server-response ordering, getter freshness, or cache lifetime.

## 7. `RepairAllItems(true)` evidence boundary

**VERIFIED SOURCE FACT:** the native Merchant Guild Repair button calls `RepairAllItems(true)` directly after `CanGuildBankRepair()`. No separate money refresh is visible beforehand. Inspected static-popup repair callbacks reveal no additional refresh step.

**UNRESOLVED:** Lua/XML does not expose native authorization, server funding decisions, the Guild/Own split algorithm, client cache sequencing, or event emission timing.

`RepairAllItems(true)` remains a real transaction API. Runtime population accompanying a repair does not establish a separable getter-refresh mechanism.

## 8. Controlled runtime evidence

All entries here are **VERIFIED RUNTIME RESULTS — previously recorded controlled results supplied by the user**, not tests performed by Codex or general API contracts. Exact dates/builds were not supplied for the earlier observations in the following table; Logs01–08 have their own provenance below. The historical observations remain separate from that diagnostic series.

| Scenario | Previously recorded observations |
| --- | --- |
| Cold full-client start; full-guild cases | Before repair, `GetGuildBankMoney()` was 0 and `CanGuildBankRepair()` was true. One `RepairAllItems(true)` successfully repaired; `GUILDBANK_UPDATE_MONEY` occurred and bank money became populated afterward. Personal wallet remained unchanged in the controlled full-guild cases. |
| Cold withdrawal reader | `GetGuildBankWithdrawMoney()` was observed returning a very large positive value. Its meaning remains unresolved. |
| Initialized full-guild repair | Bill **1,049,679 copper**; bank before **198,662,751 copper**; one `RepairAllItems(true)`; bank debit exactly **1,049,679 copper**; wallet unchanged. |
| Mixed limited-rank repair | Bill **513,931 copper**; withdrawal allowance **20,000 copper**; bank before **197,527,048 copper**; observed guild contribution **20,000 copper**, personal contribution **493,931 copper**, total **513,931 copper**. OUS Session Stats Gold Spent recorded **493,931 copper**; repair-specific Repairs remained **0** under the conservative policy. |
| Earlier limited-rank repair | Bill **743,226 copper**; observed guild contribution **10,000 copper**; personal contribution **733,226 copper**. |
| Real Guild Bank opening | Opening the bank populated the relevant data. |
| Character-select persistence | Logout to character select and login did not clear the populated value in the controlled test. |
| Complete client restart | Complete client exit/restart reproduced the cold state. |

These observations do not establish a universal cache lifetime, unlimited-value sentinel, funding algorithm, or event ordering contract. They do not isolate which native mechanism populated the values.

### 8.1 Log01 — cold Guild Bank opening without a transaction

**Experiment identity and provenance:** Log ID `Log01`, label `cold-bank-open`, officer alt. The user reports effectively unrestricted repair/withdraw permissions for this rank; that context is separate from API value semantics. The runtime client reported Retail `12.1.0`, build `69814`, Interface `120100`. Diagnostic version `1` / schema `1` recorded design source `4e3cbb8c5609e4bfc332c0aebbfa4d79731fab59`, build `12.1.0.69814`.

The complete raw evidence remains read-only outside this repository:

`D:\WowDEV\Projects\BlizzardResearch_RuntimeLogs\GuildRepairDiagnostics\Log01_cold-bank-open_Officer_Alt.txt`

It was reviewed without copying the raw log into the repository. The user reports a full client restart before login, no Guild Bank opening before collection, no repair, and no deposit, withdrawal, purchase, or other intentional gold transaction. Guild Bank was opened normally through Blizzard UI; collection was stopped while it remained open.

**VERIFIED RUNTIME RESULT — observer sequence:** relative times below are rounded to six decimal seconds for presentation; sequence numbers retain the recorded ordering.

| Seq | Elapsed seconds | Observation | `GetGuildBankMoney()` | Guild Bank frame / interaction context |
| --- | --- | --- | --- | --- |
| 1 | 0.000069 | START | `0` | Frame did not exist; GuildBanker interaction `false`. |
| 2 | 31.722712 | First `INSTRUMENTATION_STATUS` after initiating the normal bank interaction | `192441419` | Frame existed but was not shown; GuildBanker interaction `true`. |
| 3 | 31.722894 | Second `INSTRUMENTATION_STATUS` | `192441419` | Frame existed but was not shown; interaction `true`. |
| 4 | 31.722991 | Recorded `ADDON_LOADED` observation for `Blizzard_GuildBankUI` | `192441419` | Frame existed but was not shown; interaction `true`. |
| 5 | 31.725361 | First observed `QueryGuildBankTab POST-CALL`, tab argument `1` | `192441419` | Frame shown; interaction `true`. |
| 6 | 31.730339 | `GuildBankFrame OnShow POST-SCRIPT` | `192441419` | Frame shown; interaction `true`. |
| 7 | 31.764864 | `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`, raw interaction argument `10` (GuildBanker) | `192441419` | Frame shown; interaction `true`. |
| 8–14 | 31.765174–31.765884 | Later query POST-CALL records, tab arguments `2, 3, 4, 5, 6, 7, 1` | `192441419` | Frame shown; interaction `true`. |
| 15 | 54.032063 | STOP | `192441419` | Frame still shown; interaction `true`. |

`GetGuildBankWithdrawMoney()` remained **`10000000000`** in every retained snapshot. Preserve this as a raw observed number: neither the rank report nor this run establishes a documented unlimited sentinel. `GetMoney()` remained `64323512` in every snapshot. At START, `CanGuildBankRepair()` was skipped because no relevant interaction context was established; from record 2 onward it returned `true`. This run performed no repair and provides no repair-funding split evidence.

The run retained **15 records with zero dropped observations**. Both guild-money event registrations were reported as registered, but no `GUILDBANK_UPDATE_MONEY` or `GUILDBANK_UPDATE_WITHDRAWMONEY` record was captured anywhere in the run, including between cold START and the first populated observation. Query instrumentation reported `installed-coverage-unverified`; both frame-script observers reported installed. Zero dropped records excludes recorded buffer overflow here, not every possible instrumentation blind spot.

**VERIFIED RUNTIME RESULT:** in this controlled run, `GetGuildBankMoney()` changed from `0` to `192441419` before the first observed query POST-CALL marker. The value was already populated at the earliest observer record after GuildBanker interaction became active, and before the recorded ADDON_LOADED observation and OnShow POST-SCRIPT marker.

**Bounded interpretation:** `QueryGuildBankTab` was not necessary for the already-observed initial money population in this run's normal UI opening sequence. This does not establish that the query can never affect money state, nor complete native-call coverage. No guild-money notification was captured across the observed transition; this does not establish that either notification never occurs during initialization or is universally unnecessary.

**UNRESOLVED — causation and observation boundaries:** the exact native refresh mechanism remains unidentified. GuildBanker interaction being active at record 2 is not proof that the interaction itself caused the population. Native work may precede Lua callbacks/hooks, and snapshots are sequential rather than atomic. Records 2–3 are made during bank-frame hook installation inside the diagnostic's ADDON_LOADED handler, before it emits record 4. Thus "before recorded ADDON_LOADED" does not mean before addon loading or before that event's dispatch. Record 7 likewise marks this observer's callback, not the beginning of native interaction or Blizzard's processing of the event. Query/frame hooks are post-call/post-script, not pre-call/pre-script observations.

No verified public merchant-safe refresh/request API follows from Log01; the source conclusion in section 11 remains unchanged.

### 8.2 Completed diagnostic series — identity and controls

All eight raw files remain read-only in `D:\WowDEV\Projects\BlizzardResearch_RuntimeLogs\GuildRepairDiagnostics\`; none is copied into this repository. Every run reports Retail `12.1.0`, build `69814`, Interface `120100`, diagnostic version `1`, schema `1`, and the section 2 current LIVE design source. The client build date string is not a runtime test date. All report completed collection and zero dropped observations; query coverage remains unverified. Setup, character identity, OUS settings, transaction count, and chat observations below are user-supplied controls, distinguished from the recorded snapshots.

| Log / exact external filename | Internal label | User-reported control | Retained records |
| --- | --- | --- | --- |
| `Log01_cold-bank-open_Officer_Alt.txt` | `cold-bank-open` | Officer alt; full restart; first natural bank opening; no transaction (section 8.1). | 15 |
| `Log02_warm-merchant-no-repair_Officer_Alt.txt` | `warm-merchant-no-repair` | Same officer/session after Log01; bank closed; fully repaired; Auto Repair OFF; no transaction. | 6 |
| `Log03_cold-merchant-damaged-no-repair_Officer_Alt.txt` | `cold-merchant-damaged-no-repair` | Officer alt; full restart; no bank interaction; damaged; no repair. | 6 |
| `Log04_warm-merchant-damaged-no-repair_Officer_Alt.txt` | `warm-merchant-damaged-no-repair` | Same character/damage after naturally opening/closing bank; no repair. | 5 |
| `Log05_warm-full-guild-repair_Officer_Alt.txt` | `warm-full-guild-repair` | Officer alt; bank initialized; Auto Repair ON / Guild Repair First ON; one native `RepairAllItems(true)`. | 8 |
| `Log06_cold-guild-first-repair_Officer_Alt.txt` | `cold-guild-first-repair` | Officer alt; full restart; bank unopened; one guild-first repair; canonical replacement Log06. | 8 |
| `Log07_warm-mixed-guild-repair_Haranidia.txt` | `warm-mixed-guild-repair` | Haranidia; bank warm; 5g (`50000`) allowance remaining; one guild-first repair. | 9 |
| `Log08_cold-mixed-guild-repair_Haranidia.txt` | `cold-mixed-guild-repair` | Haranidia; full exit/restart; bank unopened; daily rank limit raised from 5g to 10g after 5g consumed, leaving `50000`; one guild-first repair. | 9 |

Only the canonical Log06 with internal label `cold-guild-first-repair` is evidence here. Any earlier attempted Log06 with the wrong label is superseded and excluded; it is not used to explain gaps between runs.

**VERIFIED RUNTIME RESULT — non-transaction merchant controls:** Log02 retained bank `192441419`, withdrawal `10000000000`, and wallet `64323512` throughout; repair-capable merchant snapshots returned repair cost `0`. Opening that merchant did not change the warm values. Log03 retained bank `0`, withdrawal `10000000000`, and wallet `64323512`; merchant snapshots returned repair bill `235556` and `CanGuildBankRepair() = true`. Opening a repair-capable merchant did not populate its cold bank getter. Log04 retained bank `192441419`, withdrawal `10000000000`, wallet `64323512`, the same bill `235556`, and eligibility `true`. Logs03/04 therefore compare cold/warm observable bank state without a changed bill or eligibility. Natural bank initialization preceded the populated merchant state; its exact refresh mechanism remains unidentified.

### 8.3 Logs05–08 — PRE boundary and transaction observations

The temporary OUS instrumentation supplied `PRE_GUILD_REPAIR` immediately before the existing `RepairAllItems(true)`, using OUS's existing `cost` local. It added no second repair or post-transaction inference. Calling the marker synchronously reads/records state and may perturb timing; it is an observation boundary, not native transaction identity or an atomic snapshot. The observer alone does not prove attribution.

All amounts below are raw copper. At every PRE marker, `CanGuildBankRepair()` was `true`, and the marker's `cost` equaled the repair getter (`R`). The bank frame was absent in cold Logs06/08.

| Log / PRE seq | R | Bank getter at PRE | Withdrawal at PRE | Wallet at PRE | User-observed OUS chat |
| --- | --- | --- | --- | --- | --- |
| Log05 / 4 | `235556` | `192441419` | `10000000000` | `64323512` | `[OUS]: Guild-first repair requested: 23 55 56` |
| Log06 / 3 | `247954` | `0` | `9999528888` | `64323512` | Not supplied for this run. |
| Log07 / 3 | `513931` | `191722353` | `50000` | `349550283` | `[OUS]: Guild-first repair requested: 51 39 31` |
| Log08 / 3 | `513931` | `0` | `50000` | `348572421` | `[OUS]: Guild-first repair requested: 51 39 31` |

For the following table, M = `GUILDBANK_UPDATE_MONEY`, W = `GUILDBANK_UPDATE_WITHDRAWMONEY`, P = `PLAYER_MONEY`; each cell gives bank / withdrawal / wallet / repair getter, in that order. Sequence numbers order observer callbacks.

| Log | M, seq 6 | Next observation | Following observation |
| --- | --- | --- | --- |
| Log05 | `192205863 / 10000000000 / 64323512 / 235556` | W, seq 7: `192205863 / 9999764444 / 64323512 / 0` | STOP, seq 8: same values; wallet unchanged throughout. |
| Log06 | `191722353 / 9999528888 / 64323512 / 247954` | W, seq 7: `191722353 / 9999280934 / 64323512 / 0` | STOP, seq 8: same values; wallet unchanged throughout. |
| Log07 | `191672353 / 50000 / 349550283 / 513931` | W, seq 7: `191672353 / 0 / 349550283 / 513931` | P, seq 8: `191672353 / 0 / 349086352 / 0`; STOP seq 9 unchanged. |
| Log08 | `191622353 / 50000 / 348572421 / 513931` | P, seq 7: `191622353 / 50000 / 348108490 / 0` | W, seq 8: `191622353 / 0 / 348108490 / 0`; STOP seq 9 unchanged. |

### 8.4 Controlled funding arithmetic and the Log05/06 continuity gap

| Log | Exact observed debit arithmetic | Controlled attribution supported |
| --- | --- | --- |
| Log05 | Bank: `192441419 - 192205863 = 235556`; withdrawal: `10000000000 - 9999764444 = 235556`; wallet debit `0`. | `R = 235556`, `G = 235556`, `P = 0`: strong full-guild evidence. |
| Log06 | Within-run withdrawal: `9999528888 - 9999280934 = 247954`; wallet debit `0`; repair getter becomes `0`. Bank PRE was cold `0`, so no valid within-run bank debit can be computed. | Strongly supports `R = 247954`, `G = 247954`, `P = 0` from PRE plus withdrawal/wallet observations; cross-run bank corroboration is limited by the gap below. |
| Log07 | Bank: `191722353 - 191672353 = 50000`; withdrawal: `50000 - 0 = 50000`; wallet: `349550283 - 349086352 = 463931`; `513931 = 50000 + 463931`. | `R = 513931`, `G = 50000`, `P = 463931`: exact controlled mixed split. |
| Log08 | Withdrawal: `50000 - 0 = 50000`; wallet: `348572421 - 348108490 = 463931`; `513931 = 50000 + 463931`. Prior durable Log07 bank minus populated Log08 bank: `191672353 - 191622353 = 50000`. | Strongly supports `R = 513931`, `G = 50000`, `P = 463931`; cross-run bank difference corroborates under the reported controls, not from cold PRE zero. |

**Contradiction in the supplied cross-run summary / UNRESOLVED continuity:** the actual Log05 final bank `192205863` minus canonical Log06 populated bank `191722353` is **`483510`**, not `247954`. It exceeds Log06's bill by `235556`. Log05 final withdrawal `9999764444` also exceeds canonical Log06 PRE withdrawal `9999528888` by `235556` before this recorded transaction. These differences establish a gap in the eight-run continuity; they do not identify an intervening operation or its cause. Do not silently reconstruct a pre-Log06 bank balance, attribute the entire cross-run bank change to Log06, or use a superseded wrong-label run to fill the gap. This does not negate Log06's exact within-run withdrawal debit and unchanged wallet.

### 8.5 Bounded cross-log conclusions

- **VERIFIED RUNTIME RESULT:** Logs03, 06, and 08 show cold-visible bank `0` alongside merchant-time eligibility `true`. Logs06/08 still support actual guild funding. Cold zero is therefore not proof of unavailable guild funds or a usable pre-transaction balance.
- **Controlled transaction conclusion:** Logs05–08 support the current one-call guild-first policy under the tested conditions. Logs07/08 directly demonstrate available guild allowance consumed and the exact remainder charged personally from one `RepairAllItems(true)`; no second `RepairAllItems()` was required. This is not a documented universal Blizzard funding contract.
- **VERIFIED RUNTIME RESULT:** Log07 observed M → W → P; Log08 observed M → P → W. Attribution cannot depend on a fixed notification order. Several snapshots already showed changed money while the repair getter still held the old bill. Sequence orders callbacks, individual snapshots are sequential/non-atomic, and timestamps do not establish causation.
- Preserve every withdrawal number as observed. These runs do not establish persistence/cache lifetime or undocumented unlimited-sentinel semantics for large positive values.
- PRE plus controlled guild/withdrawal/wallet changes substantially strengthens transaction attribution; exact arithmetic and controlled attribution remain distinct from general API guarantees. No universal public settlement signal was established.
- The inspected-source conclusion remains unchanged: no verified public merchant-safe money refresh/request API was established. Transaction-side population is not such an API; the causal initialization mechanism remains unresolved.

## 9. Current OUS production policy

Production context is limited to why attribution remains conservative. The previously recorded **user-provided OUS 1.0.3 policy** is retained below; the preceding temporary-instrumentation task also inspected the current `Utilities.lua` guild-first branch, without changing its repair or accounting policy:

- When Guild First is enabled and `CanGuildBankRepair()` is true, mark repair funding indeterminate and call `RepairAllItems(true)` exactly once.
- That guild-first branch does not require cached bank balance or full personal affordability first. Logs07/08 directly observed guild resources plus a personal remainder under this policy.
- Otherwise use the explicit personal `RepairAllItems()` path. Known Own-funds repair can be attributed to Repairs.
- For a guild-first transaction, do not speculate about the actual Guild/Own split. Any observed personal wallet debit remains ordinary Gold Spent; speculative guild-first funding does not populate Repairs.
- No visible Guild Repairs counter exists in production.

This research does not authorize or implement a policy change.

## 10. Funding-attribution model

Define `R` as the full repair bill, `G` as the actual guild contribution, and `P` as the actual personal contribution. For a completed mixed repair:

```text
R = G + P
513,931 = 20,000 + 493,931 copper
```

The verified example satisfies the arithmetic identity. That identity alone does not prove transaction attribution under arbitrary event interleaving.

Logs05–08 add the PRE boundary and exact controlled debit arithmetic in section 8.4. Their supported splits remain CONDITIONALLY ATTRIBUTABLE in the general model; the Log05/06 bank continuity gap must not be hidden by matching Log06's within-run allowance arithmetic. Session Stats intentionally does not infer repair-specific funding from the guild-first call alone, and no accounting change is proposed here.

| Certainty | Evidence requirement / boundary |
| --- | --- |
| EXACT | Evidence directly identifies the transaction/funding path sufficiently for exact accounting. Matching arithmetic alone does not qualify. |
| CONDITIONALLY ATTRIBUTABLE | Controlled conditions and corroborating observations strongly attribute the arithmetic, without providing universal transaction identity. The supplied controlled full-guild and mixed results support this bounded interpretation for those runs. |
| INDETERMINATE | Available events/state cannot reliably isolate the split. This remains the production guild-first accounting treatment. |

**ASSUMPTION:** assigning every nearby wallet or bank delta to a repair assumes no overlapping money activity. That assumption is not a general attribution rule. Exact observed copper values do not upgrade a controlled result to universal EXACT attribution.

## 11. Refresh-mechanism findings

| Candidate | Classification | Evidence boundary |
| --- | --- | --- |
| `QueryGuildBankTab()` | UI-OWNED REQUEST PATH | Tab-data request verified; money effect and ordinary merchant use unresolved. |
| GuildBanker opening/native interaction | UNRESOLVED | Runtime opening populates data; responsible native mechanism not isolated. |
| `RepairAllItems(true)` | TRANSACTION SIDE EFFECT | Runtime money state may populate during/after a real repair; not a refresh API. |
| Money-update events | NOTIFICATION ONLY | Visible consumers reread/update UI, not request money state. |
| Money getters | GETTER ONLY at visible Lua/XML caller level | Native implementation unresolved; no verified request side effect. |
| `CanGuildBankRepair()` | Eligibility predicate at visible caller level | No refresh side effect established. |

**No legitimate merchant-safe public guild-bank money refresh/request API was established from the inspected Lua/XML.** No candidate qualified as VERIFIED PUBLIC REFRESH API for this purpose. This is not proof that no internal native mechanism exists.

## 12. Rejected / unsupported shortcuts

Current evidence does not justify production use of:

| Shortcut | Why unsupported by this evidence |
| --- | --- |
| Arbitrary polling/timers | Elapsed time or repeated reads does not establish readiness or transaction identity. |
| Fake event firing | Notifications are not requests for underlying state. |
| Hidden/programmatic Guild Bank UI opening | Normal interaction ownership does not establish a supported merchant refresh workaround. |
| Transaction-log queries as repair attribution | No repair identity solution established; `QueryGuildBankLog()` and `GetGuildBankMoneyTransaction()` are outside the proposed solution. |
| Repeated `RepairAllItems(true)` | Repeats a real transaction API; not a source-backed initialization method. |
| Speculative zero-copper repair | No refresh semantics established for that operation. |
| `QueryGuildBankTab()` at a normal merchant | Bank-owned callers do not establish merchant legality or money-refresh effects. |
| Large positive withdrawal value as unlimited sentinel | The observed positive value is not documented by the inspected source's negative-value display branches. |

These are unsupported/unestablished conclusions, not blanket claims of impossibility.

## 13. Open questions

All remain **UNRESOLVED**:

| Question | Missing evidence |
| --- | --- |
| What populates money/withdrawal state during GuildBanker interaction? | Native request/cache implementation or discriminating runtime observations. |
| What happens between cold pre-interaction state and the earliest populated GuildBanker observation? | Log01 already observed population before its first query POST-CALL marker; the earlier native transition and complete call coverage remain unobserved. |
| Is there a general event/getter ordering or settlement contract? | Logs07/08 already show differing notification order and non-atomic state; no universal contract established. |
| Can allowance changes generally identify a repair? | Logs07/08 corroborate the controlled mixed split; unrelated activity and initialization still require separation in general. |
| What funding attribution is reliable beyond controlled isolated transactions? | Logs05–08 strengthen controlled attribution; a universal transaction identity/settlement signal remains unestablished. |
| What accounts for the Log05/06 continuity gap? | Bank difference `483510`, versus Log06 bill `247954`, and pre-run withdrawal difference `235556`; intervening cause not captured by this series. |

## 14. Next controlled experiment

**Completion checkpoint:** Logs01–08 now complete the recorded initialization, merchant-control, full-guild, and mixed-funding series (section 8). The earlier interaction-boundary target below is retained as unresolved research, not a claim that the later repair experiments were unperformed or a directive to change instrumentation. No additional experiment or production accounting change is authorized by this documentation task.

### 14.1 Initial experiment — completed as Log01

The original timing-only experiment plan is retained below. Log01 completed the normal bank-opening run without a repair or money transaction; section 8.1 records its result and observation limits.

Start with a cold full-client start and do not open Guild Bank beforehand. Perform no repair or money transaction. Then use a real GuildBanker interaction and capture ordered/timestamped observations of:

- Initial `GetGuildBankMoney()` and `GetGuildBankWithdrawMoney()` values.
- GuildBanker interaction show and Guild Bank frame lifecycle.
- The first `QueryGuildBankTab()`.
- `GUILDBANK_UPDATE_MONEY` and `GUILDBANK_UPDATE_WITHDRAWMONEY`.
- Both getter values at each relevant observation point.

This experiment determines timing boundaries only. Values populated before the first tab query would show that query was unnecessary for initial population in that run. Values populated afterward would not necessarily prove causation.

The standalone evidence-only GuildRepairDiagnostics sample has since been implemented and used for Log01. Its implementation was not changed for this documentation update. Prefer passive observation and record any instrumentation-induced timing/security perturbation if unavoidable. No production change follows from this experiment alone.

### 14.2 Next research target — the earlier interaction boundary

**UNRESOLVED:** narrow the interval between Log01's cold START (`GetGuildBankMoney() = 0`, GuildBanker interaction `false`) and its earliest post-initiation observation (`192441419`, interaction `true`, bank frame created but not shown). Repeating the unchanged observer cannot be assumed to expose that boundary more precisely.

The next instrumentation question is whether a passive Lua observation can occur before Blizzard's GuildBanker show handling loads the bank UI, and before the native money state becomes populated. The desired boundary is entry into dispatch/handling of `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` for GuildBanker, ahead of the manager's `ShowFrame` / bank load path. The current diagnostic records its own event callback but cannot guarantee it runs before Blizzard's handler or before native work. A secure post-hook is not an entry marker. A passive Lua mechanism that guarantees the required pre-population observation is **not currently established** by the inspected source/diagnostic architecture.

A smaller, known Lua-visible point would be the very beginning of the diagnostic's existing `ADDON_LOADED("Blizzard_GuildBankUI")` callback, before `InstallBankFrameHooks()` and its instrumentation snapshots. Capturing that point would require additional diagnostic instrumentation in a separately authorized task. It could move the first sample earlier within that callback, but would still follow addon creation/loading and any preceding native work; it is not known to reveal the cold-to-populated transition.

No new controlled runtime experiment is specified until the availability and limits of an earlier observation point are established. Do not substitute polling, timers, event manufacture, function/script replacement, or active bank/repair operations for the missing boundary.
