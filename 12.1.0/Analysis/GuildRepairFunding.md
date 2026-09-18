# Retail Guild Repair Funding

## 1. Scope and research question

This is the canonical, incremental BlizzardResearch record for the ongoing Retail Guild Repair funding investigation. The central question is how to establish reliable funding behavior and attribution when `GetGuildBankMoney()` can report 0 after a full client restart even though a native guild-first repair succeeds.

This document consolidates the completed source investigation and previously recorded controlled OUS runtime results. It does not modify OUS production behavior, implement a diagnostic, or establish a universal funding or cache contract.

| Evidence label | Meaning in this record |
| --- | --- |
| **VERIFIED SOURCE FACT** | Directly established by the inspected Lua/XML, TOC, or generated declaration. |
| **VERIFIED RUNTIME RESULT** | Previously recorded controlled runtime observation supplied by the user; bounded to that test. |
| **SOURCE-SUPPORTED INFERENCE** | Interpretation supported by source, without an explicit native contract. |
| **ASSUMPTION** | An unverified premise, not usable as established behavior. |
| **UNRESOLVED** | Available evidence does not settle the question. |

Runtime test dates, client builds, and complete addon compositions were not established in the supplied record. No runtime tests were performed by Codex for this documentation task. Missing provenance remains missing rather than being inferred from the source snapshots.

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

All entries here are **VERIFIED RUNTIME RESULTS — previously recorded controlled results supplied by the user**, not tests performed by Codex or general API contracts. Exact dates/builds were not supplied.

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

## 9. Current OUS production policy

Production context is limited to why attribution remains conservative. **User-provided OUS 1.0.3 policy**, not newly inspected implementation:

- When Guild First is enabled and `CanGuildBankRepair()` is true, mark repair funding indeterminate and call `RepairAllItems(true)` exactly once.
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
| Is money available before the first cold-start `QueryGuildBankTab`? | Ordered observations relative to actual interaction/frame/query execution. |
| What is exact event/getter ordering? | Timestamped observations for the specified run, without promoting ordering to a permanent contract. |
| Can allowance changes corroborate limited-rank mixed repairs for the player? | Controlled observations distinguishing allowance changes from unrelated activity and initialization. |
| What funding attribution is reliable without timers or speculation? | Evidence that isolates a transaction and its contributions under the relevant conditions. |

## 14. Next controlled experiment

Start with a cold full-client start and do not open Guild Bank beforehand. Perform no repair or money transaction. Then use a real GuildBanker interaction and capture ordered/timestamped observations of:

- Initial `GetGuildBankMoney()` and `GetGuildBankWithdrawMoney()` values.
- GuildBanker interaction show and Guild Bank frame lifecycle.
- The first `QueryGuildBankTab()`.
- `GUILDBANK_UPDATE_MONEY` and `GUILDBANK_UPDATE_WITHDRAWMONEY`.
- Both getter values at each relevant observation point.

This experiment determines timing boundaries only. Values populated before the first tab query would show that query was unnecessary for initial population in that run. Values populated afterward would not necessarily prove causation.

A small evidence-only BlizzardResearch diagnostic is planned for this and later repair experiments. It has not been designed or implemented here. Prefer passive observation and record any instrumentation-induced timing/security perturbation if unavoidable. No production change follows from this plan alone.
