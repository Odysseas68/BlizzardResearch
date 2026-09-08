# AsyncCallbackSystem item-load failure for equipped temporary-enchanted weapons

## Scope and baseline

This focused Retail investigation began from the LIVE `12.1.0.69497` source mirror at commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`. The current LIVE reference is Retail `12.1.0.69587`, dated 2026-09-01, at mirror HEAD `8ea15b61e45c0ed4eba01439c90757f86eb78d34`; the directly relevant AsyncCallback, ItemMixin, item-event, error-attribution, AuraContainer, and temporary-enchant API files did not change between those checkpoints. The follow-up phase also performs a read-only audit of the locally supplied Chonky Character Sheet `2.3.16` source. PTR source was not consulted. The final runtime sequence supports OBB's production replacement as a successful mitigation for its affected feature path, while the underlying AsyncCallbackSystem failure remains unresolved.

The investigation separates:

- **VERIFIED LIVE SOURCE BEHAVIOR** — directly established by the current Mainline Lua/XML or generated API documentation;
- **VERIFIED RUNTIME OBSERVATION** — supplied results from the user's Retail LIVE sessions;
- **SOURCE-SUPPORTED INFERENCE** — an explanation consistent with both source and the supplied runtime evidence, but not yet tied to the exact failing callback;
- **UNRESOLVED** — a question the inspected source and current runtime trace do not settle.

## Executive conclusion

The supplied stack does **not** establish that `callbacks[1]` was nil.

`FireCallbacks` uses `ipairs(callbacks)`. With the standard iterator, a nil array slot terminates iteration before the loop body, so line 76 cannot receive a nil `callback` merely because the table contains a hole. Cancellation also does not create a hole: it writes the numeric `CANCELED_SENTINEL` value `-1`, which line 75 skips.

Line 76 runs each callback with `xpcall(callback, CallErrorHandler)`. `CallErrorHandler` deliberately adjusts the reported stack height so the callback's error is attributed to the previous function. A valid callback that attempts to call a nil value can therefore be reported as an `AsyncCallbackSystem.lua:76` error even though the callback-table entry itself is a function.

The newest full-startup failing capture adds a harder constraint. The sole callback immediately before the relevant `FireCallbacks(268203)` delivery was again the exact Chonky `BuildMasterLoot` closure, but target-only instrumentation inside that closure recorded every operation through `CCS.MasterLoot[itemID] = entry` and then recorded `CALLBACK-END`. Under ordinary `xpcall` control flow, that callback returned normally and could not simultaneously have entered `CallErrorHandler` as a callback-body failure in the same invocation. The direct “Chonky callback body called nil” explanation is therefore disproved for this captured execution. The line-76 report now requires either an incompletely correlated separate invocation/error record, execution attached to or substituted for the outer `xpcall` call, or behavior below the inspected Lua source boundary. Root cause remains unknown.

V3 establishes that the callback of interest already exists before RetailUIResearch's first Lua file executes. In the captured sessions it was the sole entry in `ItemEventListener.callbacks[268203]`, and guarded inspection reported `secure=true, taint=nil`. A later same-session observer capture closed the ownership gap: the observer recorded Chonky's `core/gearDB.lua:1416` registration, and its callback identity `function: 0000022B022325A0` exactly matched V3's sole startup/pre-fire callback before a line-76 error was reported in the same delivery window. The address is meaningful only within that client session; the stack and identity match attribute that callback registration to Chonky's `AddItemToMaster` closure, not the reported error to its body.

The controlled runs also establish that temporary Oil does **not** create this callback. The same one-function bucket shape was present with Oil OFF, while a minimal-addon Oil-ON startup contained no pre-bootstrap callbacks at all. Adding Chonky Character Sheet back restored a large pre-bootstrap callback population, including the equipped-weapon bucket, but that session did not error.

The Chonky source audit and observer identify the exact registration path for the `268203` callback present in the captured failing deliveries. During file load, `core/gearDB.lua` traverses the active season's static dungeon, raid, and class-set loot tables and calls `Item:CreateFromItemID(itemID):ContinueOnItemLoad(...)` for each selected entry. Retail 12.1 selects Season 2; the source contains 368 potential calls over 367 unique item IDs, including an explicit raid-loot entry for item `268203`. Earlier uninstrumented captures established registration and bucket identity but did not prove that this body raised the reported error. The newest internal marker sequence proves that the matched body completed in that failing startup. Chonky registration therefore remains established while direct error ownership does not.

The enhanced observer materially revises the earlier dependency ranking. In a representative later failing session, Chonky registered `function: 000001C083C24AE0` for item `268203`; immediately before dispatch the bucket length was one and index one contained that same secure function. At both registration and pre-fire, global `GetItemInfo`, `C_Item.GetItemInfo`, `C_Item.GetItemStats`, `EJ_GetInstanceInfo`, `EJ_GetEncounterInfo`, `select`, and `table.insert` were functions with stable observed identities. `GetCVarBool("loadDeprecationFallbacks")` was true and `Blizzard_DeprecatedItemScript` was loaded. The simple hypothesis that `GetItemInfo` was nil at pre-fire is therefore strongly contradicted, not the leading explanation. The snapshot does not inspect code executed inside those functions, secure post-hooks attached to them, or a mutation caused synchronously by an earlier expression in the callback.

The latest failure also reproduced with Odysseus Utility Suite disabled. OUS is therefore not required for this failure path. A later Zygor registration for item `268203` used a different function identity and must not be conflated with the earlier Chonky callback. Chonky-only remains capable of completing the same callback cleanly, so ownership of the callback is not proof that Chonky alone creates the intermittent precondition.

At an earlier checkpoint, a single A/B pair made enabled BugGrabber and BugSack look like a strong reproduction condition: the visible error disappeared with both disabled and returned with both enabled. In the enabled failing run, a passive secure post-hook recorded zero normally returning `CallErrorHandler` calls. That result did not prove the function was never entered, because a post-hook also remains silent if `CallErrorHandler`, BugGrabber's installed handler, or a synchronous listener fails before returning. The later Logs_17/Logs_18 reproductions with both addons absent supersede the broad requirement inference while preserving the original A/B observation.

Two fresh runs with the temporary BugGrabber-handler wrapper materially narrowed that ambiguity. In the clean-history reproduction, the wrapper received one new current-session `AsyncCallbackSystem.lua:76` nil-call error about 462 microseconds after the target `GetCallbacks(268203)` observation, called the retained BugGrabber handler once, and recorded its normal return. The Chonky callback again recorded `AFTER MasterLoot-publication` and `CALLBACK-END`, while the former passive `CallErrorHandler` post-hook recorded zero normally returning calls. A second run displayed a deduplicated count of two but retained only one current-session wrapper entry/return. Stale BugSack history is therefore disproved for the fresh one-count reproduction, BugGrabber non-return is disproved for that handler invocation, and displayed aggregate count is separated from current-session handler-entry evidence.

The latest Case-3 run resolves the next boundary. AICO observed the untouched `_G.CallErrorHandler` identity remain stable through A-F, successfully installed and verified its direct wrapper at G, and later recorded zero `CALLERROR-ENTRY` events. The line-76 error nevertheless reproduced about `0.463ms` after target `GetCallbacks(268203)`, and the independently verified active-handler wrapper recorded exactly one fresh BugGrabber `ENTRY` and normal `RETURN` for that exact message. Therefore the observed active-handler invocation did not pass through the installed addon-global `CallErrorHandler` wrapper. Mirrored source does not explain the bypass, and this result does not establish whether the occurrence came from the explicit line-76 message-handler argument, unprotected/native error dispatch attributed to line 76, or an incompletely correlated invocation. BugGrabber remains a reproduction/environment correlate and observer, not a proven direct cause.

The subsequent Logs_17 and Logs_18 BugGrabber-off controls reproduced the exact line-76 occurrence with BugGrabber and BugSack runtime-absent and valid AICO controls. Logs_18 further established the observed order: the identified Chonky body reached `CALLBACK-END`, visible `FireCallbacks` cleanup completed, its secure post-hook ran, and only then did the active handler receive the error string while AICO's verified addon-global `CallErrorHandler` wrapper recorded zero entries. BugGrabber and BugSack are therefore not required for this occurrence in the tested full profile. The result still does not identify the exact instruction-time `xpcall` message-handler binding or the mechanism that delivered C after the tracked dispatcher returned.

The controlled ownership reductions in Logs_19 and authoritative Log_20 narrow that conclusion further. Log_19 reproduced with Chonky runtime-absent and Zygor present; authoritative Log_20 reproduced with both Chonky and every Zygor runtime module absent. Log_20 retained valid BugGrabber-off and boundary-provenance controls, recorded zero `268203` registrations, and observed a nil `268203` bucket both immediately before the failure-adjacent `FireCallbacks` call and in its structural open record. That particular tracked invocation therefore skipped the visible `if callbacks then` body containing line 76, returned normally through the secure post-hook, and was followed `0.034ms` later by C receiving the exact line-76 string. This does not establish that line 76 executed nowhere else, that the string belongs one-to-one to the tracked invocation, or that native/runtime behavior is defective. It establishes that neither known direct `268203` owner is required for the observed failure in this tested composition and strengthens the observational split between the tracked visible dispatcher invocation and the later C delivery.

Authoritative Log_21 supplies the first closely matched Oil-OFF control for that owner-reduced composition. Its complete 165-addon loaded inventory matches Log_20 name-for-name; Chonky, Zygor, BugGrabber, BugSack, and the harness remained absent; AICO/AICD remained active; and AICD physically verified main-hand item `268203` with `tempEnchant=false`. Log_21 also contained a nil `268203` target dispatch that returned normally, but it recorded no repeat, no B entry, no C entry, and no AsyncCallbackSystem error. The nil-bucket dispatch is therefore not sufficient by itself for the Log_20 occurrence. The Oil-ON failure versus first matched Oil-OFF clean result strengthens temporary-enchant state as an environmental-trigger correlate in this composition, but one clean control does not prove necessity, causation, enchant-`8052` specificity, or a native defect.

Logs_22 and 23 broaden that correlation beyond Phoenix Oil, enchant `8052`, and physical item `268203`. Log_22 reproduced the Log_20 target-specific shape with Oil of Dawn, independently observed runtime enchant `8053`, a nil `268203` bucket, normal target exit, zero B entries, and C `0.031ms` later. Log_23 reproduced the exact C error with a different main-hand item, `246664`, and runtime temporary-enchant ID `5400`; raw AICD records show the main-hand enchanted and the off-hand `246669` unenchanted. AICO's C entry names `246664` as the immediately preceding GetCallbacks ID, records no active dispatch and no B entry, but retains no `246664` structural open/normal-exit record and therefore does not support `TARGET_NORMAL_EXIT_BEFORE_C`. The log itself does not serialize the class, Flametongue name, or tooltip SpellID `318038`; those remain supplied run/screenshot context distinct from the raw enchant ID.

Authoritative Log_24 completes the matched Shaman OFF control. It retains the exact 165-name runtime inventory and the same physical items `246664`/`246669`, while AICD verifies both weapons unenchanted. Its one `246664` nil-bucket PREFIRE/COMPLETE episode succeeds, and AICO records no B entry, C entry, boundary record, or exact line-76 error. As in Log_23, the corresponding non-fixed-target AICO dispatch open/normal-exit was not retained.

Authoritative Log_25 then repeats the same full-profile Shaman ON condition and reproduces. AICD again verifies main-hand item `246664`, `tempEnchant=true`, runtime enchant `5400`, and unenchanted off-hand item `246669`; AICO places a `246664` GetCallbacks observation `0.349ms` before C receives the exact line-76 string, records no tracked dispatch open at C and zero B entries, and retains no item-specific structural open/normal exit. The three Shaman captures have exactly the same ordered 165-name loaded inventory and the same 181-name addon-load timeline order. The ON -> ERROR / OFF -> CLEAN / ON -> ERROR sequence establishes temporary weapon-enchant/imbue state as a **repeatable reproduction condition in this tested full-profile environment**. It does not establish causation, global necessity or sufficiency, a wall-clock threshold, the unidentified full-profile/runtime cofactor, or a native defect.

Authoritative Log_26 removes exactly the intended six runtime folders—three logical families collectively named the profession/economy continuation group—from the Log_25 parent and reproduces again. AICD verifies the same `246664`/`246669` weapons, active runtime enchant `5400`, and unenchanted off hand. AICO records the exact line-76 string `0.341ms` after a `246664` GetCallbacks observation, with no tracked dispatch open at C and zero B entries; as in Logs_23/25, no `246664` structural open/normal-exit record survives. The ordered loaded inventory is exactly Log_25 minus `CraftSim`, the four Journalator folders, and `ProfessionShoppingList`, with no added or collateral missing runtime names. The addon-load timeline contains the same projected 175-name set but not the same relative order: disabling the group delayed Blizzard professions and TradeSkillMaster milestones. The profession/economy continuation group is therefore **not required as a group for reproduction under the tested configuration**. This does not independently exonerate any member, establish that the ordering change is causal, or identify the remaining full-profile-derived runtime cofactor.

Authoritative Logs_27 and 28 complete the first QuickCrafts ABA branch inside that reduced environment. Both preserve main-hand item `246664`, active runtime enchant `5400`, and unenchanted off-hand item `246669`. Log_27 removes only QuickCrafts from Log_26's ordered runtime inventory (`159 -> 158`) and is clean; Log_28 restores QuickCrafts, returns exactly to Log_26's ordered 159-name inventory, and reproduces. Log_28 again records C with zero B entries and no tracked dispatch open, but does not retain the `246664` structural open/normal-exit needed for post-hook-before-C wording. Thus QuickCrafts state is an **observed selector/reproduction condition in this tested reduced ABA branch so far**, not a proven direct cause, defective callback source, or globally necessary component. Log_27 also proves again that active temporary-enchant state alone is not sufficient.

Authoritative Logs_29 and 32 complete two unchanged repeats of the QuickCrafts-OFF reduced control. Their ordered 158-name loaded inventories and 174-name `ADDON_LOADED` projections exactly match Log_27; all three runs are clean, retain valid BugGrabber-off/B/C controls, and verify item `246664` with temporary enchant `5400`. The reduced sequence is now QuickCrafts ON -> ERROR in Logs_26/28 and QuickCrafts OFF -> CLEAN in Logs_27/29/32. This materially strengthens QuickCrafts state as a repeatable selector **inside this preserved reduced branch**, while still not establishing defect, sufficiency, causality, direct ownership, or global necessity.

The normal-profile Logs_30 and 31 then reproduce with QuickCrafts runtime-absent. Their loaded inventories differ only by CraftSim (`174` versus `175` names), although CraftSim's presence also changes observed addon-load order. Log_30 has CraftSim absent and Log_31 has it present; both retain BugGrabber, BugSack, Chonky, and Zygor, verify item `246664` with enchant `5400`, and capture the line-76 report. Therefore neither QuickCrafts nor CraftSim is globally required for the underlying occurrence. BugGrabber's stored locals select a `FireCallbacks` frame with `id=246664`, `callbacks=<table>`, `(for control)=1`, and `i=1`, but omit the named `callback` and show two anonymous temporaries. Those values establish a non-nil retained callbacks table and first-iteration state; they do **not** establish that the callback value was nil or identify either temporary with a particular source operand/result.

Logs_35-40 then isolate OdysseusBuffBars across three controlled runtime pairs. In every pair, removing `OdysseusBuffBars` from the OBB-ON capture makes both the complete runtime-loaded inventory and the complete `ADDON_LOADED` name order exactly equal to its OBB-OFF partner. The outcomes follow OBB state in all six captures: ON -> ERROR in Logs_35/38/40 and OFF -> CLEAN in Logs_36/37/39. OBB-ON also adds exactly one `GetCallbacks` observation and one additional equipped-main-hand `246664` PREFIRE/COMPLETE episode with a nil mapped bucket in each pair. The OBB source used for those captures contained no direct ItemMixin continuation or listener call, but it unconditionally created Blizzard-managed MainHand/OffHand item-enchantment providers. Blizzard's implementation reads temporary-enchant state, derives the equipped item through `Item:CreateFromEquipmentSlot`, and can register `function() auraButton:UpdateAuraDisplay(); end` through `ContinueWithCancelOnItemLoad` when the item name is uncached. This made OBB a repeatable selector/cofactor and supplied a source-valid item-loading mechanism for the extra `246664` activity; it did not prove that OBB caused the error, that the extra nil-bucket dispatch executed line 76, or that OBB alone was sufficient. A user-supplied uncaptured minimal Chonky+OBB+BugGrabber clean test directly argues against pairwise sufficiency.

Logs_41-44 complete the provider split. Log_41 kept OBB loaded but disabled only its Blizzard-managed MainHand/OffHand `AddItemEnchantment` providers and was clean; Log_42 restored those providers in the same controlled runtime environment and reproduced the line-76 report. OBB then replaced the managed providers with OBB-owned ordinary weapon-enchant rows. Logs_43 and 44 were consecutive clean runs with that production replacement, while ordinary item-loading still traversed `ItemEventListener` for item `246664` and the Chonky `268203` callback remained structurally valid. Registrations stayed `557` in all four runs; GetCallbacks were `1175/1176/1175/1175`; and balanced dispatch totals were `1337/1338/1337/1326`. The lower Log_44 dispatch total is normal runtime-volume variation, not a regression. The old Blizzard-managed weapon-provider branch is therefore the strongest verified feature-level selector for this observed failure. The replacement is a successful mitigation and architectural replacement for OBB's affected feature path in the tested composition; it does not prove a Blizzard defect, an OBB root cause, the exact failing callback, or a universal fix for AsyncCallbackSystem line 76.

The completed standalone `!AsyncErrorBoundaryHarness` matrix supplies the controlled stock-Retail comparison. Ordinary valid-handler callback failure and invalid-first-argument cases delivered B then C before `xpcall` returned, cleanup, and the secure post-hook. Invalid message handlers returned `"error in error handling"` without B or C. No ordinary tested synthetic `xpcall` failure reproduced the Logs_18 shape. Deliberately calling C after dispatcher completion can construct that shape, but is explicitly tautological and does not explain the live event.

Current LIVE source does establish one direct reason that an item callback bucket ID can follow a temporarily enchanted equipped weapon. Native managed item-enchantment display code can:

1. detect the active temporary enchant with `C_PaperDollInfo.GetTemporaryEnchantmentInfo(inventorySlot)`;
2. create an `Item` from that equipment slot when applying native spell/name text;
3. obtain the current equipped item ID from the `ItemLocation`;
4. register an item-data callback under that item ID when the item name is not cached;
5. later run `function() auraButton:UpdateAuraDisplay(); end` after `ITEM_DATA_LOAD_RESULT`.

This is a verified source connection between a temporary weapon-enchantment presentation path and `ItemEventListener`, but it is not the identified `268203` callback in the same-session observer capture. Chonky's matched callback does not query temporary-enchant state, equipped inventory, spell data, tooltips, or `ItemLocation`. The Oil and zero-duration observations are therefore indirect startup/readiness correlations, not direct inputs to this callback body.

## Runtime evidence

### VERIFIED RUNTIME OBSERVATIONS

- A login after fully exiting World of Warcraft and freshly launching the client, with equipped weapon item ID `268203` and temporary weapon Oil active, produced the supplied `AsyncCallbackSystem.lua:76` failure with `id = 268203`.
- Replacing the weapon, applying Oil, and repeating the full-client-exit/fresh-launch test reproduced the same failure with `id = 275218`.
- The failing ID therefore followed the currently equipped temporarily enchanted weapon in those two reproductions.
- The failure has reproduced after a full WoW client exit and fresh game launch. It has not reproduced reliably after ordinary logout/login.
- Earlier comparison logins were clean after removing the temporary Oil or moving the original weapon to bags.
- One all-addons-disabled login with an equipped temporarily enchanted weapon was clean.
- Addon-isolation combinations, including DBM-disabled testing, have produced both failing and clean logins.
- Ordinary logout/login and `/reload` are comparison cases, not the strongest reproduction path.

These early results materially weakened a weapon-specific, literal item-ID, or SavedVariables theory. By themselves they did not identify a registering caller; the later same-session observer did so for the instrumented `268203` failure.

### FIRST DIAGNOSTIC-ENABLED FAILING CAPTURE

The original error reproduced while `AsyncItemCallbacksDiagnostic` v1 was active. The diagnostic did not suppress the failure. This directly weakens the concern that installing its passive `AddCallback` post-hook necessarily prevents reproduction, but does not prove zero timing or observer effect in all sessions.

The failing-session sequence was:

1. `INIT`, `PLAYER_LOGIN`, and `PLAYER_ENTERING_WORLD initialLogin=true` all reported unreadable main/off-hand item IDs.
2. A successful `ITEM_DATA_LOAD_RESULT` for item ID `272275` was the first recorded point at which the main hand resolved to item ID `268203`. The main-hand temporary-enchant result was non-nil with `enchantID=8052` and `remainingTimeMs=0`.
3. Successful completion observations `#005` and `#006` for item ID `268203` retained the same zero duration.
4. Observation `#007`, at the same diagnostic timestamp as `#005`/`#006`, reported the same item/enchant ID with `remainingTimeMs=6809000`; `#008` retained that value and later `#009` reported `6800120`.
5. Roughly nine seconds after the earlier completion activity, a direct registration for item ID `268203` was recorded at `hookOrder=407`, with callback identity `function: 000001C8FCC258C0` and a stack through `ItemMixin:ContinueOnItemLoad` and Zygor item-score code. An equivalent later off-hand registration was also observed.

The original error still reported `id=268203`, loop index `i=1`, and `attempt to call a nil value` at the `FireCallbacks` invocation site. This remains compatible with a valid first callback whose body attempted a nil call because `CallErrorHandler` adjusts attribution. The error does not prove `callbacks[1]` was nil.

Two earlier diagnostic-enabled clean cold logins also contained the later Zygor registrations for item IDs `268203` and `272275`. The observed Zygor registration therefore proves participation in equipped-item async loading, but is not sufficient evidence that it caused the failing callback invocation.

| Observation | Clean diagnostic runs | First failing diagnostic run |
| --- | --- | --- |
| Diagnostic active | Yes | Yes |
| Main-hand item ID | `268203` | `268203` |
| Temporary enchant active | Yes | Yes, `enchantID=8052` |
| Matching item completions | Successful | Multiple successful observations |
| Later Zygor continuation | Observed | Observed at `hookOrder=407` |
| AsyncCallbackSystem error | Not observed | Reproduced for `id=268203` |
| First observed `remainingTimeMs` | Normal nonzero value | `0`, later nonzero |
| Exact pre-fire callback | Not captured in those runs | Later same-session observer evidence identifies Chonky `AddItemToMaster`; still later internal instrumentation proves that body can complete during a failing startup |

The zero-to-nonzero duration transition is a **VERIFIED RUNTIME OBSERVATION**, not a causal conclusion. It has now occurred in two failing full-client-restart sessions, while earlier clean captures first observed a positive duration. That is a repeated runtime correlation, not evidence of causation. Current generated documentation specifies `remainingTimeMs` as a non-nil number but does not require a positive value. Current AuraContainer code treats any non-nil enchant-info table as active, calculates duration directly from the supplied number, and treats a later larger remaining time as a reassignment/refresh condition. A zero value during initialization is therefore a **SOURCE-SUPPORTED POSSIBILITY**. Source does not define zero as a special login sentinel, define zero as expired, explain why the C API returned it in either session, or establish that it caused the failure. No authoritative source inspected here identifies enchant ID `8052` by name.

### SECOND FAILING CAPTURE WITH V2

The next failure reproduced after a full WoW client exit, fresh launch, and direct login to the affected character. Ordinary logout/login had often remained clean. The supplied Lua error again reported `AsyncCallbackSystem.lua:76`, `id=268203`, loop index `i=1`, and `attempt to call a nil value`. As above, `CallErrorHandler` means this does not prove that `callbacks[1]` was nil.

V2 preserved the decisive pre-clear state:

- `PLAYER_LOGIN` and initial `PLAYER_ENTERING_WORLD` still had unreadable main/off-hand item IDs.
- When equipment resolved, the main hand was item ID `268203` with a non-nil temporary enchant, `enchantID=8052`, and `remainingTimeMs=0`; the off hand was item ID `272275` without a temporary enchant.
- `BUFFER_RESOLVED` reported 64 retained registrations, zero matches, 64 discards, and zero registration evictions. It reported two retained pre-fire snapshots, zero matches, two discards, and zero pre-fire evictions.
- Immediately before one `FireCallbacks(268203)` delivery, the bucket was a table of length one whose sole entry was the function identity `0000018C797F6D70`.
- No `REGISTER id=268203` for that identity appeared in V2's visible output.
- A later callback identity, `0000018DF04489D0`, had both a matching pre-fire record and a registration stack through Zygor item-score startup code. Equivalent later registrations occurred in clean runs. It is distinct from `0000018C797F6D70` and does not identify the earlier callback.
- Later observations for the same active temporary enchant showed a normal positive duration, including `remainingTimeMs=6274000`.

The 64/0/0 registration result is strong negative evidence about V2's retained post-hook window: none of the 64 calls observed before equipment identity resolved registered the sole pre-fire function for item ID `268203`, and no buffered registration was lost to capacity. In this capture both weapon IDs became readable together, so V2's partial-equipment resolution rule did not discard this callback. The callback must therefore have entered the mapped bucket outside those 64 successfully observed `AddCallback` post-hooks. Current source alone does not distinguish registration before V2 installed its hook, an original `AddCallback` call that did not return to its post-hook, or a non-source path that bypassed the hooked table method.

### V3 CONTROLLED STARTUP MATRIX

The V3 bootstrap runs as RetailUIResearch's first TOC file. Its startup snapshot therefore separates callbacks already queued by dependencies or earlier addons from callbacks registered later in RetailUIResearch's load.

#### First V3 failing capture

In the normal addon environment with Oil active, V3 retained 512 startup callback entries and counted 94 startup evictions. When equipment resolved, item ID `268203` had one startup callback at bucket index one. Its type was `function`, guarded entry inspection reported `secure=true, taint=nil`, and the pre-fire record matched the startup identity with `origin=present-at-v3-startup`. The main hand had `tempEnchant=true`, `enchantID=8052`, `remainingTimeMs=0`, and `charges=0`. `FireCallbacks(268203)` then produced the line-76 nil-call error at `i=1`. Later observations reported a positive remaining duration. No authoritative inspected source identifies enchant ID `8052` by product name.

#### Zygor-disabled failing capture

With Zygor disabled and Oil active, the same relevant facts remained: a one-entry startup bucket for item ID `268203`, a non-nil temporary-enchant result with `remainingTimeMs=0` at pre-fire, and the line-76 failure. This excludes the later known Zygor continuation as a necessary condition for this reproduction. It does not identify the earlier callback's owner.

#### Oil-OFF clean control

With Zygor still disabled and Oil removed, a one-entry startup bucket for item ID `268203` was still present and fired without a Lua error. The temporary-enchant query returned nothing. This directly establishes that temporary Oil is not what creates the pre-bootstrap callback. It also makes a temporary-enchantment-only registration path insufficient as a general explanation for this callback population.

#### Oil-ON re-test failure

Reapplying Oil restored `tempEnchant=true` with `remainingTimeMs=0` at pre-fire, and the error reproduced while the startup callback was present. Together, the OFF/ON control shows that Oil changes observed startup state while an already-existing item callback is pending. The identified callback does not read that state, and the control does not prove that zero duration causes the callback body to fail.

#### Cache-cleared failure

Renaming or clearing WoW's Cache folder did not prevent the normal-environment Oil-ON failure. This weakens a simple persistent Cache-folder corruption explanation. It does not prove that all in-memory item-data readiness or startup ordering is identical across runs.

#### Minimal-addon clean startup

With only RetailUIResearch, BugGrabber, and BugSack enabled, V3 reported `startupEntries=0`, `startupEvicted=0`, no startup callback for item ID `268203`, and no error. The equipped weapon later resolved with the same active enchant and `remainingTimeMs=0`. Temporary-enchant presence and zero duration are therefore not sufficient to create the pre-bootstrap callback or produce the failure.

#### Chonky-only-additional-addon clean startup

With Chonky Character Sheet as the only additional normal addon, V3 reported 353 startup callback entries, zero evictions, and a one-entry startup bucket for item ID `268203`; guarded entry inspection again reported `secure=true, taint=nil`. Equipment resolution initially observed the active enchant with zero remaining duration, but immediately before callback delivery the duration was already positive (`remainingTimeMs=6064000`). The callback fired without an error.

The later read-only Chonky source audit found a file-load traversal capable of registering 368 item continuations over 367 unique IDs, including item `268203`. This directly explains the category and approximate scale of the population without requiring Chonky to load another Blizzard addon first. It does not make 353 equal to total registrations: the V3 snapshot counts callbacks still outstanding when RetailUIResearch begins, while cached items can complete synchronously during Chonky's loop and the raid traversal is guarded by Encounter Journal availability. The later observer did not retroactively identify callbacks in older sessions, but it did prove the Chonky identity in a subsequent same-session clean capture and a subsequent same-session failing capture.

Across the earlier V3 controls, failure repeatedly coincided with `tempEnchant=true` and `remainingTimeMs=0` at pre-fire, while the clean Chonky control reached a positive duration before pre-fire. The later instrumented failing evidence includes a positive duration, so zero is not a necessary condition. Active temporary enchantment remains a recurring association across many failures, but neither enchant presence nor any particular duration value is established as sufficient or causal.

#### Same-session observer attribution and timing comparison

The early standalone observer subsequently recorded the complete Chonky registration provenance before V3 took its startup snapshot. For item `268203`, the stack was `ItemMixin:ContinueOnItemLoad` -> `core/gearDB.lua:1416` -> enclosing `AddItemToMaster` at line 1412 -> the raid traversal at line 1557 -> file-scope `CCS.BuildMasterLoot()` at line 1590. In the failing capture, callback identity `function: 0000022B022325A0` exactly matched the observer registration and V3's sole startup/pre-fire callback before the line-76 report in the same delivery window. The later Zygor callback had a different identity and completed successfully.

The clean minimal Chonky session and the heavier failing session did not differ merely by callback ownership. In the clean session, observer-to-Chonky loading took about `0.05s`, `PLAYER_LOGIN` occurred around `15s`, pre-fire occurred around `16.8s`, and the temporary enchant had a positive `remainingTimeMs` near `7,092,000`. In the earlier heavier capture, observer-to-Chonky loading took about `3.9s`, `PLAYER_LOGIN` occurred around `22.5s`, pre-fire occurred around `36.9s`, and the temporary enchant still reported `remainingTimeMs=0`; the line-76 error was reported during that delivery window and duration became positive in the same timestamp window. That earlier run had no callback-internal completion marker, so describing the matched body itself as erroring was stronger than the evidence supported. “Late” in elapsed seconds does not imply that every global or subsystem dependency was ready.

`AICD COMPLETE success=true` records successful `ITEM_DATA_LOAD_RESULT` delivery for the item. It does not report that each callback body completed successfully, because `FireCallbacks` catches callback errors independently through `xpcall`.

#### Enhanced callable-state failing capture

The enhanced observer's later full-addon failures reproduced same-session attribution more than once. In the representative capture, the registration identity and the sole pre-fire identity were both `function: 000001C083C24AE0`; the registration stack was `ItemMixin:ContinueOnItemLoad` -> `core/gearDB.lua:1416` -> raid traversal line 1557 -> file-scope build line 1590. The exact hexadecimal identity is session-local; the same-session equality and stack are the evidence.

At Chonky registration and again at the matching failing pre-fire, the observer recorded all of these as functions with unchanged identities: `GetItemInfo`, `C_Item.GetItemInfo`, `C_Item.GetItemStats`, `EJ_GetInstanceInfo`, `EJ_GetEncounterInfo`, `select`, `table.insert`, `GetCVarBool`, and `C_AddOns.IsAddOnLoaded`. It also recorded `loadDeprecationFallbacks=true` and `Blizzard_DeprecatedItemScript loaded=true`. This closes the observer enhancement's pending LIVE-validation item and strongly contradicts the earlier simple missing-`GetItemInfo` theory. It does not prove that every callee's internal state, attached secure hooks, or indirect calls were valid.

The same failure persisted with OUS disabled, so OUS is not necessary. A later Zygor callback for `268203` had a different identity. Neither result assigns the underlying nil call to another addon. The Chonky-only clean control continues to establish that the registered Chonky continuation is not sufficient by itself.

#### Full-path Chonky-instrumented failing capture

A subsequent fresh full-client startup reproduced the line-76 nil-call report with locals `id=268203` and `i=1`. The standalone observer recorded the target registration as cumulative registration order `211` at elapsed `+3.926167s`, with callback identity `function: 000001CCD004BA50` and a stack through `ItemMixin:ContinueOnItemLoad`, installed Chonky `core/gearDB.lua:1452`, the raid traversal at line `1742`, and file-scope build at line `1775`. Immediately before the relevant dispatch, cumulative `GetCallbacks` order `1764` at elapsed `+37.732686s` showed a length-one bucket whose sole entry was that exact function, with `secure=true` and `taint=nil`. The order values are monotonically increasing hook ordinals across all observed item registrations/lookups, not target-only counts.

The target-only Chonky marker log then recorded `CALLBACK-BEGIN`, successful `BEFORE`/`AFTER` completion for both item-info calls, `select`, item stats, every individual stat read and applicable insertion, both Encounter Journal lookups, all entry assignment groups, the equipment-location map read, final `CCS.MasterLoot` publication, and `CALLBACK-END`. No instrumented callback operation lacked its matching completion marker. This is direct runtime evidence that this Chonky closure completed its entire Lua body in this failing startup.

That result changes the interpretation. Identity equality proves that the sole pre-fire entry was the instrumented Chonky function; it does not by itself prove that the subsequently displayed BugGrabber record was produced by an error thrown inside that function. Ordinary `xpcall` does not call its message handler after a protected function returns normally. The direct Chonky-body nil-call hypothesis is therefore contradicted for this execution, not merely downgraded. The report and completion marker can coexist only if their assumed one-to-one correlation is incomplete, additional execution associated with the outer `xpcall` call fails after the callback returns, or native/secure-hook behavior not represented by the inspected Lua source is involved.

This failing evidence also occurred with a positive temporary-enchant duration. It disproves `remainingTimeMs=0` as a necessary condition. Earlier zero-to-positive transitions remain valid observations and may still identify a broader startup-state correlation, but zero must not be used as a defining property of the failure.

## AsyncCallbackSystem lifecycle

### Exact addon-load boundary

`Blizzard_ObjectAPI_Mainline.toc` is default-enabled and depends on `Blizzard_Colors`. Its file order loads `ContinuableContainer.lua`, `ItemLocation.lua`, and then `AsyncCallbackSystem.lua`. At the end of `AsyncCallbackSystem.lua`, `CreateListener(ASYNC_ITEM)` creates and initializes the global `ItemEventListener`, including its empty callback map and `ITEM_DATA_LOAD_RESULT` event registration. `Item.lua` loads afterward and defines the validated `ItemMixin` continuation methods.

RetailUIResearch declares `Blizzard_ObjectAPI` as a required dependency. The addon loader must finish that dependency before executing `Modules/AsyncItemCallbacksDiagnostic/Bootstrap.lua`, the first RetailUIResearch file. V3 can therefore snapshot callbacks created after `ItemEventListener` exists but before RetailUIResearch starts; it cannot observe their original registration calls. `Blizzard_FrameXML` is also marked `LoadFirst: 1` and itself requires `Blizzard_ObjectAPI`, so the listener is part of the normal early Blizzard UI load independently of this diagnostic's explicit dependency.

No item callback is registered while the inspected `Blizzard_ObjectAPI` files themselves execute. The TOC creates the listener and defines the reusable methods, but its file-scope code does not call an item continuation or the item request accessor. Registrations can begin after ObjectAPI has completed, including while another Blizzard addon or third-party addon that depends on it is loading or constructing initial UI.

Removing `## Dependencies: Blizzard_ObjectAPI` from RetailUIResearch would not move Bootstrap ahead of the listener in the current UI: the early `Blizzard_FrameXML` dependency already loads ObjectAPI, and RetailUIResearch's other Blizzard dependencies can also execute before its files. In a hypothetical load in which nothing else had loaded ObjectAPI, removing the dependency would make `ItemEventListener` unavailable rather than expose an earlier callback map; the current Bootstrap assertions would fail. The TOC should not be changed for this purpose.

### Listener construction

`AsyncCallbackSystem.lua` creates three global listener frames:

| Listener | Request accessor | Completion event | ID meaning |
| --- | --- | --- | --- |
| `QuestEventListener` | `C_QuestLog.RequestLoadQuestByID` | `QUEST_DATA_LOAD_RESULT` | quest ID |
| `ItemEventListener` | `C_Item.RequestLoadItemDataByID` | `ITEM_DATA_LOAD_RESULT` | item ID |
| `SpellEventListener` | `C_Spell.RequestLoadSpellData` | `SPELL_DATA_LOAD_RESULT` | spell ID |

Each listener owns `self.callbacks`, a map from ID to a callback array. Its event script reads `id, success`; success calls `FireCallbacks(id)`, while failure only calls `ClearCallbacks(id)`.

Generated item API documentation defines the `ITEM_DATA_LOAD_RESULT` payload as `itemID, success` and marks the event synchronous. `ItemMixin:ContinueOnItemLoad` also passes `self:GetItemID()` directly to `ItemEventListener:AddCallback`.

### Registration

`AddCallback(id, callbackFunction)`:

1. obtains or creates `self.callbacks[id]`;
2. appends `callbackFunction` with `table.insert`;
3. calls the request accessor only when the resulting array length is one;
4. returns both the resulting index and the raw callback table.

The method itself does not validate `callbackFunction`.

The caller-facing item wrappers do validate it. `ItemMixin:ValidateForContinueOnItemLoad` requires `type(callbackFunction) == "function"` and rejects an empty or invalid item before either `ContinueOnItemLoad` or `ContinueWithCancelOnItemLoad` registers it.

A direct call to the global `ItemEventListener:AddCallback` bypasses that validation. Passing a non-function non-nil value can create an entry that `xpcall` cannot invoke. Passing nil to ordinary `table.insert` does not create a stable callable array entry or make standard `ipairs` yield a nil callback.

### Complete legitimate population routes

Current LIVE Lua has one actual item-bucket insertion primitive: `AsyncCallbackSystemMixin:AddCallback`. The legitimate call surfaces leading to it are:

1. `ItemEventListener:AddCallback(itemID, function)` directly;
2. `ItemEventListener:AddCancelableCallback(itemID, function)`, which delegates to `AddCallback`;
3. `ItemMixin:ContinueOnItemLoad(function)`, which validates the item and function, obtains `self:GetItemID()`, and calls the listener's `AddCallback`;
4. `ItemMixin:ContinueWithCancelOnItemLoad(function)`, which performs the same validation and calls `AddCancelableCallback`;
5. `ItemMixin:ContinueWithCancelOnRecordLoad(function)`, the generic alias used by `ContinuableContainer`; and
6. `ContinuableContainer:AddContinuable(item)`, which calls the record-load alias and can register the container's shared completion callback for each not-yet-ready Item.

A complete search found no direct writes to `ItemEventListener.callbacks`, no cached or aliased copy of `ItemEventListener.AddCallback`, no replacement of `ItemEventListener`, no callback-map restore/copy, and no second listener initialization. Every Blizzard `ContinueOnItemLoad`/`ContinueWithCancelOnItemLoad` callsite is inside a function or method rather than a file-scope invocation. Such functions can still run during XML `OnLoad`, addon initialization, or event handling, but merely loading their defining Lua file does not execute the continuation.

### Complete callback-map mutation audit

A current LIVE source search for `ItemEventListener`, `AsyncCallbackSystemMixin`, `callbacks`, `AddCallback`, `GetCallbacks`, `FireCallbacks`, `CancelCallback`, and `CANCELED_SENTINEL` found one normal population path:

1. `CreateListener` mixes `AsyncCallbackSystemMixin` into a new Frame and calls `Init`.
2. `Init` creates the empty `self.callbacks = {}` map.
3. `GetOrCreateCallbacks(id)` creates and assigns a new bucket only when none exists.
4. `AddCallback(id, callbackFunction)` appends the supplied value to that bucket with `table.insert`.
5. `AddCancelableCallback` delegates to `self:AddCallback`; it does not populate the map independently.
6. `ItemMixin:ContinueOnItemLoad` calls `ItemEventListener:AddCallback`, while `ContinueWithCancelOnItemLoad` calls `ItemEventListener:AddCancelableCallback`.

No current Blizzard Lua source directly writes `ItemEventListener.callbacks`, aliases or caches `ItemEventListener.AddCallback`, initializes the listener a second time, copies/restores callback state, or replaces one registered function with a different function. Normal cancellation is the only supported entry replacement and changes a function to `-1`. `ClearCallbacks` removes a mapped bucket, and `FireCallbacks` later empties the detached old bucket; neither populates state. The listener and buckets remain globally reachable Lua tables, so external direct mutation is technically possible, but no such mutation is established by this capture.

There is no `CancelCallback` method in this system. Cancellation is implemented only by the closure returned from `AddCancelableCallback`, using the local `CANCELED_SENTINEL` value.

Because `Item.lua` performs dynamic colon calls through `ItemEventListener` or `self`, calls following the inspected Blizzard wrapper path do not use a source-visible cached pre-hook function reference. Whether a call from a separate secure execution environment invokes an insecure post-hook is not defined by the inspected Lua source and must not be assumed from the TOC flag alone.

### Cancellation and `CANCELED_SENTINEL`

`AddCancelableCallback` calls `AddCallback`, retains the returned array index and raw table, and returns a closure. When invoked while the referenced array remains non-empty, the closure replaces its indexed function with `CANCELED_SENTINEL`, whose value is `-1`.

Cancellation therefore:

- replaces a function with `-1`;
- does not call `table.remove`;
- does not shift later entries;
- does not create an array hole;
- returns true only when it changes a non-canceled live entry;
- leaves `#callbacks` unchanged in the normal dense-array case.

`FireCallbacks` explicitly skips `-1`. The sentinel exists so cancellation can safely mutate the live array before or during delivery without changing its indices.

The managed item-enchantment name path calls `ContinueWithCancelOnItemLoad` but discards the returned cancellation closure. That particular source-visible registration is therefore not canceled through the supported handle.

Within the supported lifecycle, a callback function's identity is stable from insertion until delivery unless it is canceled, in which case the indexed entry becomes the numeric sentinel rather than another function. After `ClearCallbacks`, later same-ID registration creates a new bucket; retained cancellation closures still point to the detached old table and cannot repopulate the listener map. No source-visible bucket reuse, callback-function substitution, or state restoration explains the unidentified V2 entry.

### Firing, cleanup, mutation, and duplicate completion

`FireCallbacks(id)`:

1. reads the current callback array;
2. immediately removes `self.callbacks[id]` from the listener map;
3. iterates the original live array with `ipairs`;
4. skips `CANCELED_SENTINEL` and runs every other value through `xpcall`;
5. after iteration, clears the original array from the last numeric index down to one because cancellation closures may still reference it.

It does not copy the callback array.

Supported cancellation can mutate entries in that live array while an earlier callback runs, but only by replacing them with the sentinel. A callback that registers new work for the same ID after step 2 obtains a new array in `self.callbacks[id]`; it does not append to the array currently being fired.

After successful delivery, later duplicate completion finds no old mapped array. There is no explicit request token or generation, but the map-first clearing prevents the same old array from being fired twice through normal sequential event handling.

On `success = false`, the event path calls only `ClearCallbacks(id)`. It removes the map entry and does not invoke the callbacks or clear an old array still referenced by returned cancellation closures.

### Synchronous completion

The source comment on `AddCancelableCallback` explicitly says already-available data can execute and clear callbacks immediately. Because the accessor is called inside `AddCallback`, a synchronous `ITEM_DATA_LOAD_RESULT` can run `FireCallbacks` before `AddCallback` returns. The cleared array then has length zero, and the returned cancellation function has nothing to cancel.

This is supported lifecycle behavior, not an invalid state.

## What line 76 actually establishes

### VERIFIED LIVE SOURCE BEHAVIOR

The expression is:

```lua
xpcall(callback, CallErrorHandler);
```

The source-level evaluation and invocation sequence is exact:

1. Lua resolves the global value `xpcall` as the callee value for the outer call.
2. It evaluates the two argument expressions, which are simple reads of the loop-local `callback` and global `CallErrorHandler`. Their relative read order has no observable source effect here; all three values are obtained before the outer call begins.
3. It invokes the resolved `xpcall` value with those two arguments. There is no `unpack`, `select`, callback-return consumer, or third helper in this expression.
4. Normal `xpcall` invokes the supplied `callback` once. If that function returns, `xpcall` returns success plus any callback returns and does not invoke its message handler. This statement discards all returned values.
5. Only if the protected execution errors does normal `xpcall` invoke the supplied `CallErrorHandler` value with the error arguments. If that handler returns, `xpcall` returns failure plus the handler result; this statement again discards those values.

The semicolon adds no operation. After a normal successful callback return, the only remaining work represented by the Lua statement is completion of the `xpcall` invocation itself and discarding its returns. A callback return value is never treated as a function.

`CallErrorHandler` has five relevant call boundaries. For `SetErrorCallstackHeight(GetCallstackHeight() - 1)`, Lua first resolves the outer `SetErrorCallstackHeight` callee, then evaluates its argument by resolving and invoking `GetCallstackHeight`, subtracts one from that return, and invokes the already-resolved setter. For `geterrorhandler()(...)`, it resolves and invokes `geterrorhandler`, evaluates the forwarded varargs, and invokes the returned handler with those original error arguments. It stores that handler's first return value in `result`, then resolves and invokes `SetErrorCallstackHeight(nil)`, and returns `result`. Its source comment says the first adjustment reports the error from the previous function. On this path that deliberately directs Blizzard/BugGrabber stack and local selection to the outer `xpcall(callback, CallErrorHandler)` frame at line 76 rather than preserving the callback-internal frame.

The handler has no `pcall`, `xpcall`, or finally-style cleanup of its own. A failure in `GetCallstackHeight`, the first `SetErrorCallstackHeight`, `geterrorhandler`, the returned error handler, or the final `SetErrorCallstackHeight(nil)` can therefore prevent later handler statements and may obscure the original protected error. If failure occurs after the stack-height override is installed, the override can still point reporting at the line-76 frame. The inspected Lua source does not define how the native `xpcall` implementation formats a second error raised by its message handler, so it cannot prove whether such a failure would retain the raw second message or become an “error in error handling” result. Crucially, none of this handler path runs after an ordinary successful callback return.

Blizzard's default `HandleLuaError` uses the same height arithmetic: `GetErrorData` reads current and error call-stack heights, calculates `currentStackHeight - (errorCallStackHeight - 1)`, and obtains `debugstack`/`debuglocals` for that selected frame. It then formats and logs the result, invokes registered Lua-error display handlers under individual `pcall` calls, and optionally forwards to `ProcessExceptionClient`. Those display callbacks run after the source frame has already been selected. They can fail independently without replacing the captured source selection because each is protected, but they cannot make a successful `xpcall` invoke `CallErrorHandler`.

The installed BugGrabber handler preserves Blizzard's attribution choice rather than reconstructing the callback frame. `!BugGrabber/BugGrabber.lua:271-297` reads `GetErrorCallstackHeight()`, computes `currentStackHeight - (errorCallStackHeight - 1)`, and calls `debugstack` at that calculated level; it uses level three only when Blizzard supplied no error-stack height. It calls `debuglocals` for the same chosen level. BugGrabber installs its captured `grabError` function with the original `seterrorhandler`, then replaces the exposed `seterrorhandler` with a no-op. BugSack does not become the Lua error handler: it receives BugGrabber's later `BugGrabber.BugGrabbed` event and formats the already-stored message, stack, and locals for display.

BugGrabber also introduces an important correlation limit. It deduplicates by exact error-message string. For a repeat in the same BugGrabber session it increments the existing record and updates its wall-clock time, but ordinarily does not refresh that record's stored stack or locals. The first repeat in a later BugGrabber session does refresh them. A displayed record can therefore combine a current repeat count/time with stack and locals from the first identical error in that same session. This does not create the error, but it means the displayed record alone is not a precise one-to-one timestamped trace of a particular pre-fire snapshot.

### Exact line-76 failure model after Case 3

| Operation or boundary | Does `attempt to call a nil value` fit under ordinary Lua? | Current evidence |
| --- | --- | --- |
| Resolve global `xpcall` | A lookup itself does not call anything. If it produces nil, the subsequent outer call naturally attempts to call nil at line 76. | AICD observed addon-global `xpcall` as a function at the target pre-fire boundary, and the installed-source scan found no literal global replacement. A transient change or a different native execution environment remains unobserved. This branch would naturally bypass `CallErrorHandler` and reach the active handler as an unprotected call error. |
| Read loop-local `callback` | Reading the local cannot fail. Passing nil/non-callable to native `xpcall` can fail or can create a protected call failure depending on the host implementation. Standard `ipairs` never enters the body with a nil value. | The sole pre-fire entry was a secure/untainted function with matching Chonky provenance, and the instrumented body reached `CALLBACK-END`. This rules out a direct nil call inside that completed body, not every separately correlated invocation. |
| Resolve global `CallErrorHandler` | The lookup itself cannot call nil. A nil/non-function second argument would normally produce an `xpcall` argument/message-handler failure rather than the simple callback-body path; exact host formatting is native. | AICO verified its wrapper as addon-global at G. No wrapper entry occurred. Ordinary same-environment lookup therefore does not reconcile the capture. A separate environment/binding or native bypass is possible but not source-demonstrated. |
| Invoke `xpcall` and execute the callback | A nil call inside the callback fits the message, and Blizzard's handler intentionally attributes it to line 76. | For the paired instrumented Chonky execution this is contradicted by `CALLBACK-END`. If this ordinary branch had used the verified current global handler, AICO's direct wrapper should have recorded `CALLERROR-ENTRY`; it did not. |
| Execute the explicit message handler | `CallErrorHandler` itself contains several calls that could fail if a resolved callee/returned handler were nil, and a handler failure can obscure an earlier protected error. | The direct wrapper did not enter. The active BugGrabber wrapper did enter once and its retained handler returned normally. This disproves BugGrabber non-return for that invocation, but not an alternate invocation of the active handler or native error delivery that bypassed the global wrapper. |
| Complete the native protected call after the callback returns | No further Lua call is written in the statement, so ordinary Lua provides no source-level nil-call site here. | The successful callback plus active-handler bypass makes this native boundary a live hypothesis. The mirror cannot show whether the client performs additional protected-call, secure-hook, or error-dispatch work here. |
| Later loop iteration/array cleanup | Those operations can fail only at their own reads/writes/metamethods under ordinary Lua and would not naturally be attributed to line 76. | No callback-array metatable or source-visible mutation was found. Tight timing does not prove that the BugGrabber record belongs one-to-one to this exact iteration. |

`CallErrorHandler` is a global definition in `Blizzard_SharedXMLBase/ErrorUtil.lua`. `AsyncCallbackSystem.lua` does not declare a local of that name, capture it as an upvalue, alias it, import it, or use an explicit alternate environment. `Blizzard_ObjectAPI_Mainline.toc` also has no `UseSecureEnvironment` directive or per-file alternate-environment annotation. Under ordinary Lua chunk-environment semantics, the name in `xpcall(callback, CallErrorHandler)` is therefore read from the chunk's global environment each time line 76 executes. If that environment is the same global table AICO modified, the verified G wrapper is the value that should have been passed. The runtime contradiction must not be explained by inventing a hidden local. It instead establishes that addon-observed `_G` identity is insufficient to characterize the client-native execution/binding path in this capture.

For the newest capture, the source-level categories are now narrower:

1. an independently reported or deduplicated line-76 occurrence was correlated with the completed Chonky invocation even though it came from a different invocation;
2. a replacement/wrapper or secure post-hook associated with the outer `xpcall` call ran additional code after the callback returned and that additional code attempted a nil call;
3. native protected-call or secure-hook behavior not represented in the Lua mirror produced the report while the line-76 call was active; or
4. the supplied observations are missing a temporal distinction necessary to identify which event produced the stored error record.

A focused installed-addon scan found no literal global `xpcall` assignment, `_G.xpcall` write, literal secure hook of `xpcall`, assignment to `ItemEventListener`/`AsyncCallbackSystemMixin` callback methods or tables, or relevant secure hook beyond AICO/AICD's documented `AddCallback` and `GetCallbacks` observations. Excluding the two research diagnostics, it found no literal `CallErrorHandler` assignment; a BlizzMove line only localizes the global. This is strong negative static evidence against a straightforward addon mutation of Blizzard's callback machinery, but cannot exclude dynamically named hooks, generated code, or native/runtime mutation.

### Required callback-table state

With the unmodified standard `ipairs`, merely setting `callbacks[1] = nil` makes iteration stop. It does not enter the body with `i = 1, callback = nil`.

For the loop body itself to receive a nil callback, an iterator would have to return a non-nil control/index value together with a nil callback value. The standard iterator used by unmodified LIVE globals does not do this. No inspected `AsyncCallbackSystem` path installs a metatable or custom iterator on callback arrays.

There is also no normal Lua callback or event yield point between assignment of the loop value and the call to `xpcall`; ordinary sequential mutation cannot turn the already loaded local `callback` into nil in that interval.

Therefore the current evidence does not establish a malformed nil-entry premise. In the newest captured execution it also does not support defaulting to a callback-body nil call: the valid sole callback reached `CALLBACK-END`. The unresolved boundary is now the outer protected-call/reporting correlation rather than an uninstrumented expression inside Chonky.

### Can current Blizzard source create a malformed callback array?

No inspected Blizzard callsite registers nil or another non-function through the item wrapper. All direct `AddCallback` callsites pass function literals or function values. Current source does not remove array elements during firing, install a custom iterator, or expose an internal path that converts a registered function to nil before it is yielded.

That is not proof that every runtime state is correct. It is only a statement that the malformed nil-entry state is not internally reachable through the inspected normal Lua paths.

### Can an addon create invalid state?

The Object API and its listeners are global Lua objects loaded by the default-enabled Mainline `Blizzard_ObjectAPI` addon.

- `Item:CreateFromItemID`, `Item:CreateFromItemLocation`, `Item:CreateFromEquipmentSlot`, and the `ItemMixin` continuation methods are addon-callable Lua surfaces. Their continuation wrappers validate callback type.
- `ItemEventListener` and `AsyncCallbackSystemMixin` are also global and technically reachable, but they are internal-style implementation objects rather than generated `C_` API contracts.
- A direct caller can bypass validation, call `ClearCallbacks`, retrieve a callback table through `GetCallbacks`, or retain the raw table returned by `AddCallback`.

Such direct manipulation can skip callbacks, insert non-callable non-nil values, or otherwise violate implementation invariants. A simple nil hole still makes standard `ipairs` stop rather than call nil. An addon can also register a valid function whose own body later calls nil; that failure is expected to be reported from line 76 by `CallErrorHandler`.

No current evidence shows that any addon performed these actions.

## Equipped item and temporary-enchantment chain

### VERIFIED LIVE SOURCE BEHAVIOR

The managed item-enchantment path is:

1. `CustomAuraContainerSharedMixin:AddItemEnchantment` creates one `CustomAuraButtonTemplate` frame for the configured MainHand, OffHand, or Ranged source and refreshes item enchantments.
2. `AuraContainerItemEnchantmentManagerMixin:RefreshItemEnchantment` calls `AuraContainerUtil.GetItemEnchantmentInfo`.
3. That helper maps the managed enchantment slot to an inventory slot and calls `C_PaperDollInfo.GetTemporaryEnchantmentInfo(inventorySlot)`.
4. An active result produces item-enchantment aura data containing `inventorySlot`.
5. When the custom button has a spell-name FontString, `CustomAuraButtonPrivateMixin:ApplySpellName` calls `AuraContainerUtil.SetSpellNameForAura`.
6. Item-enchantment data has no ordinary aura name, so `SetSpellNameForAura` creates `Item:CreateFromEquipmentSlot(auraData.inventorySlot)` and calls `item:GetItemName()`.
7. If the item name is nil, it registers:

```lua
item:ContinueWithCancelOnItemLoad(function()
    auraButton:UpdateAuraDisplay();
end);
```

8. `ItemMixin:GetItemID` resolves an equipment-backed `ItemLocation` through `C_Item.GetItemID`. `ContinueWithCancelOnItemLoad` uses that item ID as the `ItemEventListener` callback-map key.

Thus, for this path, the numeric callback ID is exactly the currently equipped item ID. Changing the weapon changes the request and event ID without any SavedVariables dependency.

The temporary enchant is required to activate this particular managed item-enchantment presentation branch. The Oil does not become the callback ID; when this branch runs, the callback ID remains the weapon item ID. The V3 controls now prove that some other path can queue the observed equipped-item callback when Oil is absent.

### The source-visible callback body

The temporary-enchantment name callback is a valid function. Its body contains one dynamic method call: `auraButton:UpdateAuraDisplay()`.

If that method lookup were unavailable when the item event completed, the callback body could raise `attempt to call a nil value`, and `CallErrorHandler` could report it from `AsyncCallbackSystem.lua:76`. The custom button source does define `CustomAuraButtonPrivateMixin:UpdateAuraDisplay`, and frames are not destroyed when released; the inspected source does not establish why that method would be nil.

This makes the native callback a concrete source possibility for an Oil-ON bucket. The later same-session observer rules it out as the sole identified bucket entry in the instrumented `268203` captures, which instead contained Chonky's `AddItemToMaster` closure. The newest trace further shows that the Chonky closure completed, so the line-76 report must not be reassigned to this separate native body without its own same-session bucket evidence.

Repeated display refreshes while the item name is still uncached can register more than one valid callback for the same item ID. The helper discards each cancellation handle, so those callbacks remain queued until item-data success/failure. This supports ordering-sensitive behavior but does not by itself create an invalid callback value.

### Blizzard consumer boundary

A complete current LIVE source search found no Blizzard feature callsite for `CustomAuraContainerSharedMixin:AddItemEnchantment`; the only match is its definition. Current BuffFrame reads temporary enchant information directly rather than using this managed provider.

The continuation implementation is Blizzard code, but the managed item-enchantment path is currently activated by an addon-created custom AuraContainer. Using the supported addon-facing container API is not itself misuse. Source alone therefore cannot assign the failure to Blizzard or to the addon that configured the container.

Other Blizzard features or addons can independently request the same equipped item ID through `Item` continuations. `ItemEventListener` coalesces every callback for that ID into one array, so the item ID does not identify which registrant failed.

### Equipped-item startup path audit

The current Blizzard source contains exactly one call to `Item:CreateFromEquipmentSlot`: `AuraContainerUtil.SetSpellNameForAura`. Other equipment-aware code uses `ItemLocation:CreateFromEquipmentSlot`, direct inventory APIs, or tooltip setters, but the inspected paths do not pair the equipped weapon itself with an Item continuation:

- BuffFrame reads `GetTemporaryEnchantmentInfo`, texture, charges, and duration directly. It does not request the equipped item name and does not register `ItemEventListener` callbacks.
- AuraContainer can register the one-line `auraButton:UpdateAuraDisplay()` continuation described above, but only after an addon-configured item-enchantment source has active enchantment data and a spell-name display.
- CooldownViewer can construct an equipment `ItemLocation` for tooltip state, but its equipped-slot path does not call an Item continuation.
- character/equipment, wardrobe, dress-up, tooltip-comparison, and transmog paths found in the equipment-location search use `ItemLocation` or direct item APIs; no inspected path registers a continuation for the equipped weapon during startup.
- PaperDoll's direct item continuation is for a gem item ID obtained from socket data, not the equipped weapon's item ID.

This audit does not exclude a third-party addon calling the global Item API with an equipment slot or with an item ID it obtained from that slot. It also does not exclude a Blizzard function being invoked by addon initialization. It does establish that no second Blizzard-native equipped-weapon continuation body was found in current LIVE Lua.

### AuraContainer attribution after the Oil-OFF control

Within `Blizzard_AuraContainer`, `inventorySlot` is assigned only by the item-enchantment manager's aura-data construction. Ordinary unit-aura data does not acquire this field through the inspected module. `RefreshItemEnchantment` creates or updates that aura data only when `GetTemporaryEnchantmentInfo` returns a non-nil active-enchant table. With Oil OFF on a fresh client start, this branch has no active data to pass to `SetSpellNameForAura`.

Accordingly, AuraContainer attribution is:

- **proven:** the branch is capable of registering a valid one-line callback keyed by the equipped weapon's item ID when an active temporary enchant exists, the item name is uncached, and an addon has configured a spell-name display;
- **plausible:** it could contribute such a callback in an Oil-ON session;
- **unsupported:** it explains the same pre-bootstrap callback population in the Oil-OFF control, or that its callback body is the function that failed;
- **unsupported:** `secure=true, taint=nil` identifies this source body or proves Blizzard ownership.

Before the early observer run, the best-supported category was a pre-RetailUIResearch, addon/loading-environment-triggered item continuation. The observer has now identified Chonky's static-loot `AddItemToMaster` closure as the exact callback in the instrumented `268203` failure. AuraContainer remains a separate source-capable Oil-ON path, not the matched callback body, and its active-enchantment prerequisite cannot explain the Oil-OFF startup callback.

## Full-client restart, ordinary login, reload, and intermittency

### VERIFIED LIVE SOURCE BEHAVIOR

- `ItemMixin:GetItemName` can return nil until item data is loaded.
- The continuation path requests item data only when a caller encounters that missing data and registers the first callback for the ID.
- Already-cached data can complete synchronously during registration.
- Uncached data leaves a callback alive until a later `ITEM_DATA_LOAD_RESULT`.
- Custom AuraButton access restrictions are deliberately deferred until `PLAYER_ENTERING_WORLD` during initial loading, while already-logged-in creation applies them immediately.

### SOURCE-SUPPORTED INFERENCE

A fresh client launch can encounter an uncached equipped-item name. It can therefore create a deferred callback that survives across more login initialization and frame-state transitions. An ordinary logout/login or reload can encounter a different cache and initialization state, avoid the continuation entirely, or complete it synchronously.

This makes item-cache readiness directly relevant and supports an ordering-sensitive explanation for the intermittent fresh-launch symptom. The source does not explain why the full-client-restart distinction matters in the supplied sessions. It does not prove a concurrent race condition. The inspected Lua lifecycle is sequential, and no source-visible array-hole race was found.

Addon enable/disable combinations can also change which consumers request the item, how many callbacks share the bucket, and whether another request warms the cache earlier. That architecture can produce different ordering without identifying one addon as responsible.

### Temporary-enchant presence and duration state

Generated LIVE documentation defines `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)` as returning one non-nil `TemporaryItemEnchantInfo` table when an enchant is active, or returning nothing otherwise. Its `remainingTimeMs` field is a required number, but the contract does not state that it must be positive and does not define zero as a startup sentinel, expired state, or error.

The Lua consumers do not apply a positive-duration guard:

- BuffFrame accepts a non-nil table with `hasExpirationTime`, computes expiration directly from `remainingTimeMs`, and treats zero as an expiration at the current `GetTime()` value.
- AuraContainer also accepts the non-nil table as active, snapshots zero duration/expiration, and creates item-enchantment aura data. If a later refresh returns the same expiring enchant with a larger `remainingTimeMs`, `ShouldReassignForEnchantmentInfo` returns true and the manager reinitializes the assigned frame with the larger duration.
- the restricted secure aura header uses only whether the API returned a table; it does not inspect duration.

Source exposes the presence and duration fields in one returned structure and does not document separate initialization phases. The repeated zero-then-positive transition is therefore runtime evidence, not a source-defined two-phase protocol. Source does show that existing consumers tolerate zero and can refresh later when duration increases.

Item-data completion is independent of temporary-enchant duration readiness. A queued item-name continuation can therefore fire while the PaperDoll API currently reports zero, and `auraButton:UpdateAuraDisplay()` can re-read and reapply the button's current aura data. `CustomAuraButtonPrivateMixin:UpdateAuraDisplay` and its downstream methods are defined in current source; no inspected line proves that the method is temporarily nil or that zero duration makes it call nil. The supported description remains startup ordering/cache/state sensitivity, not a proven race condition or root cause.

### Addon loading implications

Required dependencies are loaded before the dependent addon's files; the ObjectAPI boundary above is a concrete instance. `C_AddOns` separately exposes required and optional dependency metadata, LoadOnDemand status, loaded/loading state, and `C_AddOns.LoadAddOn`. Blizzard's `AddOnUtil.LoadAddOn` recursively loads required dependencies before explicitly loading the requested addon. Current source also uses direct `C_AddOns.LoadAddOn` calls and contains one `LoadWith` TOC relationship.

These are verified ways an enabled addon can alter what has executed before RetailUIResearch:

- declare a required dependency, causing it to complete first;
- declare an optional dependency, allowing an installed/enabled optional integration to be ordered ahead without making absence a load failure;
- explicitly call `C_AddOns.LoadAddOn`, or a Blizzard helper that calls it, for a LoadOnDemand addon;
- invoke already-loaded Blizzard initialization code during the addon's own file/XML loading; or
- load or instantiate code whose own explicit path registers Item continuations.

No current LIVE source definition or use of `UIParentLoadAddOn` was found; the current helpers are `LoadAddOnWithErrorHandling` and `AddOnUtil.LoadAddOn`, both built on `C_AddOns.LoadAddOn`. Merely reading an absent global, calling an unrelated Blizzard API, or naming an inherited XML template is not a source-verified generic auto-load mechanism. A called API or helper can still explicitly load another addon, and an inherited template's defining addon must already have been loaded through metadata or another load path before the template is usable.

The minimal startup (`0` retained entries) versus Chonky-only-additional startup (`353`, no evictions) proves that the enabled-addon/load environment can cause substantial Item continuation population before RetailUIResearch begins. The Chonky audit identifies its file-scope Season 2 gear-database build as a direct registration mechanism of the matching magnitude and containing the target item. The subsequently deployed earlier observer supplied the missing same-session registration stack and identity match.

### Passive function-attribution limits

Retail exposes useful but incomplete passive observations:

- `tostring(function)` supplies a session-local identity string, not a source file or owner;
- `issecurevariable(table, key)` reports security/taint state for the stored table entry, not a function definition location;
- `debugstack` and `debuglocals` inspect the active call stack/locals. They cannot reconstruct the ended registration stack from an arbitrary stored function;
- `securecall`, `securecallfunction`, and `securecallmethod` invoke code across a secure call barrier; they are execution mechanisms, not inspection APIs; and
- `getfenv` is present in current Blizzard Lua usage, but the inspected code demonstrates global-environment access rather than a supported provenance contract for arbitrary secure callback functions. Even standard function-environment access would not provide definition file/line or upvalues and would often identify only a shared environment.

No current LIVE Blizzard source or generated API documentation exposes `debug.getinfo`, `debug.getupvalue`, or an equivalent passive arbitrary-function source/line/upvalue inspector to addons. Invoking the callback to learn more would change behavior; wrapping or replacing it would change identity/timing; neither is justified.

V3 alone captures every source-verified passive fact with clear diagnostic value at its later boundary: identity, bucket position/length, entry security/taint, startup presence, post-hook stacks for later registrations, and pre-fire correlation. The separate early observer supplied the registration provenance that V3 could not. A V4 source-file/line provenance enhancement is therefore not justified. A guarded `getfenv` experiment would add little ownership evidence and has not been proven safe/useful across the observed secure-function boundary.

### Revised exact-location boundary after `CALLBACK-END`

The target-only Chonky instrumentation has now answered the callback-body question for the newest failing startup: no expression inside the instrumented body failed, and the callback reached its final marker after publishing `CCS.MasterLoot[268203]`. The remaining location problem is outside that body. A pre-fire snapshot proves which function was about to be supplied to `xpcall`; it does not prove which later error notification or stored BugGrabber record corresponds one-to-one with that invocation.

The source-supported options have distinct limits:

- `debugstack` through the current BugGrabber/BugSack path follows the adjusted line-76 origin and cannot recover the omitted callback frame after the error;
- `issecurevariable`, taint state, and `tostring(function)` identify value/security state, not a function's internal instruction or attached secure post-hooks;
- a `GetCallbacks` post-hook runs after `GetCallbacks` returns but before `FireCallbacks` clears the map entry; an error inside that hook would occur at line 71, before loop-local `i` exists, so it does not explain a report whose captured locals include `i=1`;
- `hooksecurefunc` on selected dependencies could show which original functions returned far enough to run a post-hook, but it adds code to those hot paths, cannot expose a failing internal line, and can perturb startup timing;
- replacing a global, callback, `FireCallbacks`, or error handler would be materially invasive and could change identity, taint, stack behavior, or ordering; and
- the available addon API surface does not expose a supported passive arbitrary-function upvalue/source-line inspector equivalent to standard Lua's full debug library.

The Chonky marker writes add string construction, table writes, type reads, branches, and one helper call, so they can perturb timing. They do not wrap the closure, mutate the callback bucket, suppress errors, or continue after a failed operation. Because every final marker is present, blaming the instrumentation would require a concrete after-return mechanism; timing effect alone does not make a completed callback throw.

The highest-value next observation from this audit was one bounded, passive post-hook on the global `CallErrorHandler`, installed by the already-early standalone observer. It needed to record only handler-return time, the original error argument text/type, current `GetErrorCallstackHeight`, and the immediately preceding target `GetCallbacks` order/time without replacing the handler, callback, `xpcall`, or `FireCallbacks`. A normally returning handler observation during the target window would establish that a protected execution entered the message-handler path and allow comparison of the raw argument with BugGrabber's stored record. A line-76 report with no such observation would mean either `CallErrorHandler` did not return, the report arose outside the ordinary callback-error branch, or temporal correlation was wrong. This single observation is narrower and more discriminating than another broad callable inventory. It retains a post-hook limitation: no record is emitted if `CallErrorHandler` itself fails before returning.

### Implemented passive `CallErrorHandler` correlation diagnostic

The early standalone observer now installs `hooksecurefunc("CallErrorHandler", CaptureCallErrorHandler)`. This is a post-hook on the global function, not a replacement or wrapper. Current LIVE `Blizzard_Dispatcher` uses the same global `hooksecurefunc(functionName, function(...) ... end)` form to forward the hooked function's original arguments, while `Blizzard_EventTrace` similarly consumes original method arguments in a post-hook. This source usage supports receiving the original error argument in the observer post-hook. The hook runs only after `CallErrorHandler` returns normally; it cannot record a handler invocation that fails before returning.

The observer retains the newest 48 handler observations. Each record contains handler order, monotonic timestamp and observer-relative elapsed time, original error argument type, safely converted escaped single-line error text capped at 512 bytes before the explicit truncation marker, guarded post-return `GetErrorCallstackHeight()` status/type/value, the immediately preceding `GetCallbacks` observation globally, the immediately preceding target lookup for `268203` or `275218`, and the existing addon/lifecycle context. Current LIVE generated `FrameScriptDocumentation.lua` declares `GetErrorCallstackHeight()` as a global function returning a nilable number, and current error-reporting source calls it without mutating state, so guarded observation is source-supported. Because `CallErrorHandler` resets the height to nil before returning, a post-hook value of nil is expected and must not be interpreted as missing earlier attribution.

At this passive checkpoint, `/aico` labeled both preceding lookups as temporal correlation, not causation or callback identity. It printed nothing during startup or error handling. The observer did not replace or invoke `CallErrorHandler`, change `geterrorhandler()`, wrap `xpcall`, `FireCallbacks`, or any callback, mutate callback tables, poll, schedule a timer, or create SavedVariables. The post-hook added bounded work after a normally returning error-handler call and could slightly perturb subsequent timing; it could not observe inside the handler or prove which protected invocation caused the handler call from timing alone.

The interpretations defined before LIVE testing were:

- **A.** No handler observation appears near the successful `268203` Chonky dispatch, but BugSack still shows the same stored error: this strongly supports stale or deduplicated earlier error-record correlation rather than failure from that successful callback invocation.
- **B.** A handler observation appears immediately around the `268203` dispatch despite `CALLBACK-END`: inspect nested/reentrant dispatch or attribution more deeply; do not conclude that the completed Chonky body failed.
- **C.** A handler observation follows another item ID immediately before or near the visible stored `268203` error: this may indicate BugGrabber deduplication or reporting-correlation mismatch; compare exact error text and timings.
- **D.** Runtime evidence shows the secure post-hook cannot receive the arguments demonstrated by current Blizzard source usage: the passive approach is insufficient, and investigation must stop before any wrapper is introduced.

The subsequent BugGrabber-enabled failing run produced zero normally returning `CallErrorHandler` post-hook records. That result exhausted the passive diagnostic without establishing whether no call occurred or a call failed before return, leading to the separately authorized wrapper checkpoint below.

## BugGrabber v12.0.21 reference audit

### Reference baseline and standalone load order

This phase inspected the untouched reference copy at `D:\WowDEV\Reference\ThirdParty\!BugGrabber`. The directory contains four files:

| File | Role | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `!BugGrabber.toc` | Standalone metadata and load order | 1,296 | `F2D8FE799D3D79CAFCAF359DE3362DC96BB693B0EFA6A7F9AD0FC5794F460A9C` |
| `BugGrabber.lua` | Complete implementation | 29,734 | `29CF39BAD79562E75C99625239455276F81D86C86A0238A4793C927A22137C45` |
| `load.xml` | Alternate embedding include for the same Lua file | 211 | `618AFC4543F745CD315455B59C86CE25F9E35BAF0E2D1D96425456C088AFBFF9` |
| `CHANGES.txt` | One TOC-bump history entry; not executable | 274 | `E9DD8DA85AF37C7C8E176D4DFAA55469D7CE79F4186BDB744CDEAC231B469E22` |

The active installed `!BugGrabber` copy matches the reference byte-for-byte for all four files, so the audited implementation is the one present in the tested addon environment.

The TOC declares Retail interface `120100` among its supported interfaces, title `BugGrabber`, version `v12.0.21`, `LoadSavedVariablesFirst: 1`, and account-wide `SavedVariables: BugGrabberDB`. Its only executable entry is `BugGrabber.lua`; `load.xml` is not listed in the standalone TOC. The XML file contains only a script include for `BugGrabber.lua` and is an alternate embedding entry point. `embedding.txt` is not present in the supplied reference copy. No external search was performed and its absence is not an audit blocker.

The standalone file load order is therefore exactly `BugGrabberDB` loading under the TOC's SavedVariables-first directive, followed by `BugGrabber.lua`. There is no bundled CallbackHandler library and no CallbackHandler-1.0 use. The implementation uses Blizzard's global `EventRegistry`.

### VERIFIED REFERENCE SOURCE: startup error-handler architecture

`BugGrabber.lua` performs these relevant startup actions in source order:

1. It localizes selected globals, resolves the current player name, and returns immediately if `_G.BugGrabber` already exists (`lines 2-9`). There is no version comparison on this early return.
2. It disables `!Swatter` and `!ImprovedErrorFrame` (`lines 11-13`).
3. It distinguishes standalone from embedded loading through the addon's varargs; an embedded copy returns when the standalone addon is enabled (`lines 15-26`).
4. It saves the current global setter function itself as `real_seterrorhandler` (`line 28`). It does not call `geterrorhandler()` and does not preserve the previously active handler value.
5. It discovers an enabled display addon through `X-BugGrabber-Display`, registers an `EventRegistry` listener for `BugGrabber.DisplayRegistered`, defines database/error utilities and `grabError`, then defines the public addon methods used by `grabError` (`lines 164-474`).
6. It validates/creates `BugGrabberDB`, increments its session number, binds the file-local `db`, trims it to 500 entries, merges any temporary `loadErrors`, and performs sanitation (`lines 480-533`). With the handler installed only later and BugGrabber's own error-producing events registered after the database is bound, no normal current sequential path found in this file populates `loadErrors`; the array and merge remain legacy accommodation code.
7. It creates its private frame for `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, and `LUA_WARNING`, replaces that frame's registration/script-mutator methods with no-ops, unregisters the protected-action events from `UIParent` and `GameEvent`, and unregisters `LUA_WARNING` from `ScriptErrorsFrame` (`lines 535-571`).
8. It invokes the preserved native setter as `real_seterrorhandler(grabError)` (`line 573`), replacing the active WoW error handler with `grabError` rather than wrapping or chaining the previous handler.
9. It replaces the exposed global `seterrorhandler` name with an empty Lua function (`line 574`). Later ordinary callers of that global cannot change the active handler through it. `geterrorhandler` is neither localized nor replaced, and no `xpcall`, `pcall`, `securecall`, or `securecallfunction` call appears in the BugGrabber implementation.
10. It publishes its slash command and a read-only-style global `BugGrabber` proxy whose `__index` is the private addon table and whose `__newindex` discards writes (`lines 576-579`).

The only preserved handler-related reference is the original `seterrorhandler` function. BugGrabber does not preserve the handler that was active before installation and never forwards an error to that prior handler.

### VERIFIED SOURCE: exact synchronous error path

For an error caught by Blizzard's `CallErrorHandler`, the source-visible path is:

1. `CallErrorHandler` sets the error call-stack height to the previous function, calls `geterrorhandler()`, and invokes the returned value with the original error arguments.
2. After BugGrabber installation, that returned value is `grabError` unless unsupported external mutation changed native handler state.
3. `grabError(errorMessage, isSimple)` updates its rate limiter, may stop early when throttled, converts the error to a string, and may stop early for a secret string or a non-simple error containing `BugGrabber` (`lines 317-343`).
4. It searches the current database backward for exact `err.message == errorMessage` equality (`lines 204-212`, `345-352`).
5. It creates or updates an error object, stores it before potentially fragile stack/locals capture, captures stack/locals when the branch requires it, optionally formats a chat notification, and finally derives a table identity string (`lines 354-421`).
6. It synchronously calls `EventRegistry:TriggerEvent("BugGrabber.BugGrabbed", tableID)` before returning (`line 422`).
7. Only after `grabError` and the enclosing `CallErrorHandler` return can `CallErrorHandler` execute `SetErrorCallstackHeight(nil)` and a `hooksecurefunc` post-hook on `CallErrorHandler` run.

BugGrabber contains no explicit rethrow and no explicit call to Lua `error`. It also contains no protected boundary around `grabError`'s own work. A normal return does not forward to the previous error handler because BugGrabber replaced rather than chained it. An organic error raised by any unguarded operation is a secondary handler failure, not an explicit rethrow.

### VERIFIED SOURCE: stack selection and attribution

`GetErrorStack` captures `GetCallstackHeight`, `GetErrorCallstackHeight`, and `debugstack` into locals (`lines 269-297`). When `GetErrorCallstackHeight()` returns a value, BugGrabber calculates:

```text
errorStackOffset = errorCallStackHeight - 1
debugStackLevel = currentStackHeight - errorStackOffset
```

and calls `debugstack(debugStackLevel)`. Otherwise it falls back to `debugstack(3)`. `GetErrorLocals` calls a localized `debuglocals(level)` for the same selected level (`lines 300-310`). Secret stack/locals results receive fixed substitute strings.

BugGrabber does not set or rewrite the error call-stack height. It deliberately consumes the height selected by Blizzard. For `AsyncCallbackSystem.lua:76`, `CallErrorHandler` has already requested attribution to the previous function, so BugGrabber's captured stack and locals can identify the outer `xpcall(callback, CallErrorHandler)` frame even when the original protected error occurred deeper. If BugGrabber raises a secondary error before returning, `CallErrorHandler`'s final height reset is skipped; the inspected Lua source does not define how native `xpcall` reports an error raised by its message handler, so the final message/attribution format remains runtime-dependent.

### VERIFIED SOURCE: event/callback architecture

The reference defines and fires dot-named EventRegistry events, not underscore globals:

- `BugGrabber.DisplayRegistered`: BugGrabber registers one private listener at line 197 that sets `isDisplayRegistered = true`; a display addon triggers this event.
- `BugGrabber.BugGrabbed`: `grabError` triggers it at line 422 with `tostring(errorObject)` after normal storage/update work.

No `BugGrabber_BugGrabbed`, `BugGrabber.EventGrabbed`, or `BugGrabber_EventGrabbed` implementation occurs in the reference copy.

Current LIVE `CallbackRegistryMixin:TriggerEvent` marks the event executing, iterates closure and function listener tables immediately with `secureexecuterange`, invokes each listener through native `securecallfunction`, then clears the executing marker and reconciles deferred callbacks before returning (`CallbackRegistry.lua:184-223`). This proves that registered listeners execute synchronously during `grabError`'s line-422 call rather than being queued for a later frame. The Lua mirror does not define whether a listener error escapes `securecallfunction`, is reported recursively through the active global error handler, or is isolated while dispatch continues. Those alternatives must remain unresolved rather than assigning undocumented native behavior.

The currently installed BugSack display registers `onError` for `BugGrabber.BugGrabbed`. That callback can synchronously fetch configured media, call `PlaySoundFile`, optionally print, open the sack, and update its display. Those calls are not locally protected inside `onError`; their outer behavior is governed by the same undocumented native `securecallfunction` boundary. This limited listener inspection establishes a possible secondary execution surface, not evidence that BugSack failed.

If a listener error can escape native callback dispatch, it can prevent `grabError` from returning and can skip `CallbackRegistryMixin`'s Lua cleanup of `executingEvents[event]` and deferred callbacks. If native `securecallfunction` isolates it, the original `grabError` can continue and return. If native error reporting recursively invokes the active handler, `grabError` can be re-entered. BugGrabber's only recursion-like filter is the text check for non-simple messages containing `BugGrabber`; a nested error with another message is not rejected by that test. Each outcome is a source-bounded possibility, not a verified runtime behavior.

### VERIFIED SOURCE: exact deduplication and mixed-record behavior

`fetchFromDatabase` scans from newest to oldest and matches only exact string equality between stored `err.message` and the newly stringified `errorMessage`. It does not include stack, locals, session, source addon, item ID, or `isSimple` in the key.

| Occurrence | Message | Counter | Time | Session | Stack/locals | Position |
| --- | --- | --- | --- | --- | --- | --- |
| New non-simple error | New string | `1` | Current | Current | Captured after the object is stored | Appended |
| New simple error | New string | `1` | Current | Current | Not captured | Appended |
| Exact repeat, same session, no gap over 120 seconds | Preserved | Incremented | Updated to latest repeat | Preserved | Preserved from the earlier qualifying capture | Moved only when the immediately previous gap exceeds 10 seconds |
| Exact repeat, same session, immediately previous gap over 120 seconds, non-simple | Preserved | Incremented | Updated | Preserved | Refreshed from the new occurrence | Moved to newest position |
| Exact repeat from an older session | Preserved | Incremented across sessions | Updated | Updated to current | Refreshed for non-simple errors | Moved to newest position |

For same-session repeats, `time` is updated on every accepted repeat even when stack/locals are not refreshed. Stack/locals refresh only when the gap from the immediately previous identical occurrence exceeds 120 seconds; that condition is nested inside the over-10-second reorder and over-30-second notification branches. Thus a displayed record can combine the first/recent qualifying stack and locals with the latest repeat time and an aggregate counter. The counter is not reset when the session changes, so it can span sessions while time/session/stack/locals describe the first occurrence processed in the newer session.

The `isSimple` flag is not part of the deduplication key. An identical warning/protected-event string and full error string can therefore share one object; whether stack/locals exist or refresh depends on the branch taken by the current occurrence.

The temporary `loadErrors` merge has another narrow preservation rule: when a temporary load error matches a persisted database message, initialization removes and re-appends the persisted object rather than copying the temporary object's time/session/stack/locals into it (`lines 497-508`). The current sequential source installs `grabError` only after the database is bound and registers its own error-producing events afterward, so no normal current path found in this file populates `loadErrors` before that merge. The code remains as a legacy accommodation but should not be used to explain the observed startup error without a concrete reentrant path.

BugGrabber also suppresses or transforms reporting in these ways:

- more than the configured rate of ten errors per second makes `grabError` return without storing or firing `BugGrabber.BugGrabbed` while throttled;
- secret strings and non-simple messages containing `BugGrabber` are printed and returned without storage/event dispatch;
- all incoming error values are converted with `tostring`;
- `LUA_WARNING` text is prefixed and stored as simple data without stack/locals;
- protected-action events are converted to a localized formatted message and deduplicated by addon name;
- storage is capped at the newest 500 database entries; and
- display notification printing is separately throttled while `BugGrabber.BugGrabbed` still fires for every normally processed accepted occurrence.

### Secondary-failure audit

All of the following execute synchronously inside `grabError`; none is surrounded by a BugGrabber-owned `pcall` or `xpcall`:

| Operation | External/global dependency or mutable input | Guard/protection | Possible secondary outcome |
| --- | --- | --- | --- |
| Rate limiting | Localized `GetTime`, global numeric throttle constant | No call guard | A missing/non-callable `GetTime` can produce a nil/non-callable call; malformed numeric state produces arithmetic errors. State has already begun updating when later operations fail. |
| Message conversion/filter | Localized `tostring`, localized/fallback `issecretvalue`, string `find`, `print` | `issecretvalue` falls back only when the global is false/nil; other calls are unguarded | A non-function truthy `issecretvalue`, missing string method, or missing localized callable can fail. The text filter can suppress an error rather than throw. |
| Exact database search | `db`/`loadErrors` and every stored entry's `message` field | No structural validation in the handler path | Malformed entries can raise indexing errors. |
| Error-object construction | `addon:GetSessionId`, localized `time` | Methods are defined before handler installation; no invocation guard | A mutated/missing method or callable can produce a nil call. A malformed SavedVariables session can fail later arithmetic during startup. |
| `StoreError` and reorder | Mutable SavedVariables tables and `table.remove` | Database table is sanitized only coarsely; no protected call | Missing `table.remove`, malformed database shape, or mutation can fail after a new error object was already partly stored. |
| Stack capture | Localized `GetCallstackHeight`, `GetErrorCallstackHeight`, `debugstack`, fallback `issecretvalue` | Result values are checked for secret/nil, but callable identities and arithmetic types are not guarded | Any missing/non-callable helper can throw a nil-call; unexpected types can throw arithmetic errors. The new object is deliberately stored before this work. |
| Locals capture | Localized `debuglocals`, fallback `issecretvalue` | Secret result handled; calls unguarded | Missing/non-callable `debuglocals` or `issecretvalue` can fail after message/time/session storage and possibly stack assignment. |
| Optional chat notice | Localized `print`, string `format`, `addon:GetChatLink`, localized `tostring` | Branch guards only display presence/timing, not callability | Missing/mutated methods or format support can fail after database changes. |
| Final event delivery | Global `EventRegistry`, method `TriggerEvent`, registered listeners, native `secureexecuterange`/`securecallfunction` | No BugGrabber-owned protection; listener protection semantics are not defined in inspected Lua | A missing registry/method can directly fail. A listener may add a nested failure surface; whether it escapes or recursively reports is unresolved. |

There is no source line that deterministically calls nil in a normal initialized reference state. The table identifies reachable dependency surfaces, not a claim that any was nil in the failing run. The observed error text could be produced by a missing callable in these paths, but the supplied record does not identify one.

If any secondary failure occurs before line 422, `BugGrabber.BugGrabbed` is not fired for that occurrence. Depending on the branch, the database may already contain a partially initialized object or may already have updated `counter`, `time`, `session`, order, stack, or locals. A failure during/after line 422 may leave EventRegistry execution cleanup incomplete if native secure calls do not isolate it. Any failure that prevents `grabError` from returning also prevents Blizzard `CallErrorHandler` from reaching its final `SetErrorCallstackHeight(nil)` and prevents the observer's `CallErrorHandler` post-hook from running.

### Pre-handler-wrapper relevance assessment (historical)

The latest controlled evidence is: the Chonky `268203` callback reaches `CALLBACK-END`; disabling BugGrabber and BugSack removes the visible reproduction; enabling them restores it; and the observer sees zero normally returning `CallErrorHandler` calls in the failing run. Zero post-hook records does not prove no entry because a post-hook cannot run when `CallErrorHandler` or its installed handler fails before returning.

The following ranking predates the active-handler wrapper runtime result and is retained as investigation history. The fresh reconciliation section below supersedes it.

1. **BugGrabber itself throws a secondary error while processing another protected failure — PLAUSIBLE.** Supporting evidence: BugGrabber presence is a strong reproduction condition, `grabError` has multiple unprotected synchronous dependencies, partial storage is explicitly possible, and a secondary failure explains the absent post-hook return record. Blizzard's preselected error-stack height could retain outer line-76 attribution while cleanup is skipped. Contradicting evidence: no specific dependency has been observed nil or non-callable, no deterministic failing line exists in the normal source state, and the successful Chonky callback cannot itself supply the protected error needed to enter `CallErrorHandler` under normal `xpcall` semantics.
2. **Deduplication makes an older line-76 record appear related to the current successful Chonky callback — PLAUSIBLE.** Supporting evidence: exact-message repeats can combine latest time/count with earlier stack/locals, counters span sessions, and BugSack presents stored objects. This remains the strongest source-supported reporting-correlation mechanism. Contradicting evidence: the first normally processed repeat in a newer session refreshes non-simple stack/locals, so a cross-session stale stack is not expected if `grabError` reaches that branch normally; the zero post-hook result instead suggests either no current handler entry or a non-returning one.
3. **BugGrabber changes the error-handling environment and makes a latent problem reproducible — PLAUSIBLE.** Supporting evidence: it verifiably replaces the active handler, blocks later ordinary setter calls, takes over three error-related events, mutates SavedVariables, and synchronously notifies listeners. The A/B test demonstrates presence correlation. Contradicting evidence: source shows no direct mutation of `AsyncCallbackSystem`, callback tables, Chonky, or `xpcall`, and no exact latent interaction is identified.
4. **BugGrabber merely exposes an error that exists without it — PLAUSIBLE.** Supporting evidence: installing a capture/display pair changes the observation surface, so “no visible error” with both disabled does not by itself prove no underlying protected failure. Contradicting evidence at this checkpoint: the passive `CallErrorHandler` post-hook saw no normally returning invocation, and the enabled-only reproduction could reflect changed execution rather than display alone. This checkpoint did not distinguish visibility from causation.
5. **A `BugGrabber.BugGrabbed` listener introduces the secondary failure — WEAK.** Supporting evidence: listeners execute synchronously; the installed BugSack listener performs several unprotected calls; an escaping or recursively reported listener error could prevent `grabError`/`CallErrorHandler` return. Contradicting evidence: native `securecallfunction` error behavior is not defined in the inspected Lua, no BugSack listener error was captured, and line 422 is reached only after BugGrabber has already processed/stored the original error.
6. **Global setter suppression or error-event ownership indirectly changes another addon's behavior — WEAK.** Supporting evidence: BugGrabber replaces global `seterrorhandler` with a no-op, disables two conflicting addons, and unregisters Blizzard consumers of protected-action/warning events. Contradicting evidence: no inspected source connects these changes to item callback dispatch, and no later handler installer or affected event consumer has been identified in this reproduction.

None of these historical classifications assigned root cause to BugGrabber. The later active-handler wrapper result disproves BugGrabber non-return and stale history as explanations for the clean-history captured occurrence; see the current ranked assessment below.

### Implemented BugGrabber handler entry/return diagnostic — LIVE-validated

The passive `CallErrorHandler` post-hook reached its limit: zero observations could not distinguish “never entered” from “entered but failed before returning.” The authorized next checkpoint implemented one temporary, unpublished entry/return wrapper around BugGrabber's own active handler in the already-early observer. Two fresh-start Retail LIVE runs have now exercised it.

At the start of `Observer.lua`, the observer captures the original native `seterrorhandler` and `geterrorhandler` identities plus only the small native helpers used by the wrapper; it does not call the setter yet. On `ADDON_LOADED` for `!BugGrabber`, it reads and retains the then-active handler, records its type/identity and the observable secure/taint state of the getter and public setter globals, then installs its wrapper through the preserved native setter. The anonymous returned handler has no source table/global slot for a direct `issecurevariable` query, so direct handler security is reported as unavailable rather than inferred from its getter.

Each invocation appends a bounded `ENTRY` record before directly calling the retained handler. If that call returns, the same record receives `RETURN`, `normalReturn=true`, timing, exact return-value count, first-value type, and a short first-value representation only when safe. Results are packed with an explicit count and unpacked over that count, preserving zero values and trailing nils. The wrapper contains no `pcall` or `xpcall`, catches and retries nothing, never calls `geterrorhandler`, `CallErrorHandler`, or Blizzard callbacks, and performs no stack/locals capture, item query, addon scan, or printing. Its circular buffer retains the newest 48 invocations and reports total entries, normal returns, unmatched entries, retained count, and evictions.

Interpretation remains narrow. `ENTRY` plus `RETURN` establishes a normal BugGrabber-handler return. `ENTRY` without `RETURN` establishes abnormal non-return somewhere in BugGrabber or synchronous work it invokes, not which internal function or listener failed. No `ENTRY` with a visible BugGrabber/BugSack record leaves stale/deduplicated display or a path that did not invoke the wrapper as possibilities. `ENTRY` plus `RETURN` without the passive `CallErrorHandler` post-hook shifts attention to occurrence correlation or work outside the observed handler call. The wrapper changes active-handler identity, adds a Lua frame and bounded timing/work, and uses a setter BugGrabber intentionally hides. It is diagnostic-only, must not be treated as a fix, and must not become shipped sample behavior.

The clean-history run produced one `ENTRY` and one `RETURN` for the exact fresh line-76 text, with the target `268203` lookup immediately preceding it. BugGrabber therefore returned normally for the captured current-session handler invocation. The second run retained one current-session entry/return while BugSack displayed a count of two, confirming that BugGrabber/BugSack aggregation can span more than the current wrapper-observed occurrence. Neither result makes BugGrabber the origin of the error or proves that `CallErrorHandler` owned the handler invocation.

## Fresh handler-wrapper control-flow reconciliation

### VERIFIED RUNTIME EVIDENCE: current-session path

The fixed heavy-addon baseline used equipped item `268203`, consumable `243734`, temporary-enchant ID `8052`, enabled BugGrabber/BugSack/+Wowhead_Looter, disabled !KalielsTracker, and unchanged Chonky/AICO diagnostics. The clean-history run establishes all of the following for the captured session:

- a new one-count `AsyncCallbackSystem.lua:76: attempt to call a nil value` record was created; it was not only an older BugSack entry;
- the immediately preceding AICO lookup was target `GetCallbacks(268203)`, whose length-one bucket held the same secure/untainted Chonky callback;
- pre-fire `xpcall`, `ipairs`, and `CallErrorHandler` were functions reported secure/untainted;
- the installed active-handler wrapper received the exact line-76 error roughly 462 microseconds later, called its retained BugGrabber handler once, and recorded one normal return;
- the passive `CallErrorHandler` post-hook recorded zero normally returning invocations; and
- Chonky's target diagnostic again appended `AFTER MasterLoot-publication` and `CALLBACK-END`.

The second run's displayed count of two alongside one current-session wrapper entry/return verifies that stored/displayed deduplication count and current-session handler-invocation count are different measurements. It does not weaken the clean-history one-count result.

### Exact source and standard-Lua control-flow model

LIVE `Blizzard_ObjectAPI/Mainline/AsyncCallbackSystem.lua:70-83` obtains the callback array, clears its map entry, iterates it with `ipairs`, and executes only this statement for each non-canceled entry:

```lua
xpcall(callback, CallErrorHandler);
```

There is no later Lua expression on line 76 and no use of the call's results. The mirrored source contains no Lua implementation or generated API entry for `xpcall`; its protected-call engine is native. The standard Lua 5.1 reference manual describes function and argument expressions as evaluated before a call, a statement-call's results as discarded, and `xpcall` as invoking its supplied function in protected mode and calling the supplied error handler only if that function errors. WoW demonstrably extends the stock 5.1 surface at some callsites by passing extra arguments to `xpcall`, so standard semantics are guidance rather than a complete specification of this client-native implementation: <https://www.lua.org/manual/5.1/manual.html#pdf-xpcall>.

| Boundary | What is visible | Classification |
| --- | --- | --- |
| A. Evaluate `xpcall` | The name is global at line 76 and was a secure/untainted function at pre-fire. A missing/non-callable value at the actual call would make the call expression itself fail, but no such mutation was observed. | Source syntax and runtime snapshot verified; exact native identity/behavior after the snapshot unresolved. |
| B. Evaluate `callback` | `callback` is the local generic-for value from `ipairs(callbacks)`. The observed sole value was the identified secure/untainted Chonky function. | Source and runtime verified. |
| C. Evaluate `CallErrorHandler` | The name is global at line 76 and was a secure/untainted function at pre-fire. It is passed as a value to native `xpcall`. | Source and runtime verified; exact lookup order relative to A/B is not specified by Blizzard source. |
| D. Invoke `xpcall` | All call operands must be available before invocation. The implementation, validation, secure-hook integration, and error-state transitions are not mirrored in Lua. | Standard Lua call rule; client-native details uninspectable. |
| E. Execute `callback` | Standard `xpcall` executes its first argument in protected mode. The installed callback's last diagnostic append occurred. | Standard semantics plus runtime evidence; completion distinctions are below. |
| F. Possibly execute `CallErrorHandler` | Under standard semantics it runs only if the protected callback errors. The handler value passed at C need not equal the active global handler returned by `geterrorhandler()`. | Standard semantics; whether it ran in this occurrence remains unresolved. |
| G. Return from `xpcall` | Standard success returns true plus callback results; handled failure returns false plus the handler result. Because line 76 is a statement, `FireCallbacks` discards every result and performs no success check. | Standard semantics and source use verified; this occurrence's native return not observed. |
| H. Secure post-hook behavior | Blizzard Dispatcher/EventTrace source uses `hooksecurefunc` as an after-call observer receiving original arguments (`Blizzard_Dispatcher.lua:246-275`; `Blizzard_EventTrace.lua:113-115`). No mirrored implementation defines hook ordering, exception propagation, eligibility for native builtins, or behavior when another hook fails. | Usage pattern verified; semantics relevant to the missing post-hook are client-native. |
| I. Reach the active global handler | `CallErrorHandler` explicitly invokes `geterrorhandler()(...)` at `ErrorUtil.lua:3`. Other LIVE Lua paths also invoke the active handler directly, including print-handler and restricted soft-error paths, proving that handler entry is not equivalent in general to `CallErrorHandler` entry. No inspected direct path ties those callsites to this line-76 occurrence. Native unprotected-error dispatch is not mirrored. | Multiple Lua entry paths verified; path for this occurrence unresolved. |

### `CallErrorHandler` statement-by-statement

LIVE `Blizzard_SharedXMLBase/ErrorUtil.lua:1-6` is:

```lua
function CallErrorHandler(...)
    SetErrorCallstackHeight(GetCallstackHeight() - 1);
    local result = geterrorhandler()(...);
    SetErrorCallstackHeight(nil);
    return result;
end
```

Generated `FrameScriptDocumentation.lua:156-162` says `GetCallstackHeight()` returns a non-nil number. Lines 174-180 say `GetErrorCallstackHeight()` returns a nilable number. Lines 456-463 say `SetErrorCallstackHeight` accepts a nilable number and permits secret arguments only when untainted. None has a mirrored Lua body.

| Source operation | Relative to active-handler call | Lua-visible failure condition | Cleanup/post-hook consequence |
| --- | --- | --- | --- |
| `GetCallstackHeight()` | Before | A missing/non-callable global or return value contradicting the documented non-nil number would fail the call/subtraction. No such state was observed, and native internal failure behavior is undocumented. | Initial height is not set; active handler is not reached through this invocation; no normal-return post-hook. |
| subtract `1` | Before | Fails only if the helper result is not arithmetic-compatible; generated documentation says number. | Same as above. |
| `SetErrorCallstackHeight(height)` | Before | A missing/non-callable global, secret/taint restriction, or native rejection could fail. The calculated ordinary number is not known secret, and no failure evidence exists. | Active handler not reached through this invocation; cleanup absent; no post-hook. |
| `geterrorhandler()` | Before | A missing/non-callable getter can fail. | Height remains set; active handler not reached; no cleanup/post-hook. |
| invoke returned handler | The active-handler call | A nil/non-callable returned value can fail, or the handler can fail. In this occurrence the installed wrapper proved that the retained BugGrabber call completed and its `RETURN` record was written, but that does not prove this line was their caller or that the wrapper's final return expression completed. | If this was the caller and the wrapper itself returned, execution advances to cleanup; otherwise this table does not describe the observed handler entry. |
| `SetErrorCallstackHeight(nil)` | After | It can fail only if the global changed/non-callable, nil became disallowed through an undocumented native restriction, or the native call itself failed. BugGrabber source does not mutate this helper, and no such failure was observed directly. | A failure here occurs after BugGrabber return, leaves the selected error height uncleared, prevents `CallErrorHandler` return, and prevents its post-hook. |
| `return result` | After | No Lua call occurs; only normal function return remains. | A normally completed return is the prerequisite for after-call hook dispatch, whose native ordering/failure behavior is undocumented. |

The active-handler wrapper adds one narrower boundary before `CallErrorHandler` can advance to line 4. Current `Observer.lua:616` calls the retained selected handler; in the BugGrabber-on capture that retained value was BugGrabber. Lines 617-630 construct the normal-return record, and only line 631 evaluates `nativeUnpack(results, 1, results.count)` as the wrapper's actual return expression. The observed record therefore proves that BugGrabber returned and the record path completed; it does not independently observe `nativeUnpack` completing or control arriving back at `CallErrorHandler`. The wrapper captured and validated `nativeUnpack` as a function, and BugGrabber source has no value-returning path, so ordinary Lua behavior makes failure here weak and unsupported—but it is source-visible and cannot be erased from the model.

If `CallErrorHandler` owned the observed active-handler invocation and the wrapper's final return completed, line 4 is its only remaining explicit Lua operation after the handler call. A line-4 failure would explain the absent post-hook without contradicting BugGrabber's `RETURN` record. It is only a conditional source-supported explanation: neither the global helper nor its native implementation was observed failing. Because line 2 deliberately sets attribution to the previous function and cleanup would be skipped, a secondary failure in this interval could retain outer-frame attribution consistent with line 76. The exact construction of the displayed error text remains native and cannot be proven from these helpers alone. `CallErrorHandler` line 3 stores only the first active-handler result in local `result`, and line 5 returns that one value.

### What `CALLBACK-END` proves

The installed Chonky diagnostic's `AICDChonkyRecord` appends its constructed line at `core/gearDB.lua:1428` and then reaches its function end. The target callback calls `AICDChonkyRecord("CALLBACK-END")` at line 1701; the callback contains no later statement before its end at line 1703.

- The retained marker proves that the record append at line 1428 executed for the `CALLBACK-END` call.
- The marker alone does not directly observe the recorder helper's implicit return, the outer callback's implicit return, or native `xpcall` return.
- Under ordinary Lua semantics, if the recorder call returns, reaching the end of the outer function returns normally with no results. No later ordinary Chonky statement exists that can throw the captured error.
- `xpcall` return remains a distinct native boundary. The mirrored LIVE source contains no located debug-return hook, secure hook on this anonymous callback, or other after-final-statement mechanism that explains a failure there. Such client-level machinery cannot be excluded, but it must not be asserted merely because it fits the symptoms.

Thus the ordinary instrumented Chonky body remains disproved as the direct nil-call source for this captured invocation. The very small gap between marker append and callback/xpcall completion is real but source-unattributed.

### What the zero `CallErrorHandler` post-hook proves

It proves only that AICO's post-hook callback did not run for a normally completed hooked call in the captured window. Combined with the active-handler `ENTRY`/`RETURN`, it does **not** prove that `CallErrorHandler` was absent. The remaining branches are:

1. `CallErrorHandler` entered and invoked the active wrapper, but the wrapper's final `nativeUnpack` return, `CallErrorHandler` line-4 cleanup, or native after-call/hook processing did not complete before AICO's post-hook.
2. The active global handler was invoked through another Lua/native path, so `CallErrorHandler` was never involved in this occurrence.
3. `CallErrorHandler` returned at the Lua level but native secure-hook dispatch did not invoke AICO's post-hook, or an earlier native hook failure prevented it. The mirrored source neither proves nor rules out this behavior.
4. The wrapper event and nearest target lookup belong to distinct current-session occurrences. Fresh history, exact text, one current handler entry, the sole target callback, and the 462-microsecond interval make this weaker than before, but temporal correlation alone is not identity proof.

### Ranked current explanations

- **VERIFIED:** a fresh line-76 error reached the active wrapper; retained BugGrabber processing returned normally; displayed counts can include deduplicated history; and no AICO `CallErrorHandler` post-hook ran.
- **STRONG CONSTRAINT:** the discontinuity is outside the ordinary instrumented Chonky statements—at callback return, native `xpcall`/error dispatch, `CallErrorHandler` after its handler call, or secure-hook dispatch. This is a bounded location, not a single root cause.
- **PLAUSIBLE:** `CallErrorHandler` called the active wrapper and then did not return. After BugGrabber's recorded return, the wrapper's final `nativeUnpack`, `CallErrorHandler` line-4 `SetErrorCallstackHeight(nil)`, and native after-call hook processing are the remaining ordered boundaries. The captured helper identity and expected zero-result unpack make the wrapper-return failure weak within this branch; no direct evidence identifies any boundary as failing.
- **PLAUSIBLE:** an unprotected call-level/native error associated with invoking `xpcall` at line 76 reached the active global handler without traversing `CallErrorHandler`. The natural source attribution would be the call statement, but no mirrored source identifies such a native failure or attached hook.
- **WEAK:** native secure-hook eligibility/order suppressed only the passive post-hook despite a normal `CallErrorHandler` return. This is unexcluded because `hooksecurefunc` is native, but there is no affirmative evidence.
- **WEAK:** a different current-session line-76 occurrence followed the target lookup closely enough to inherit it as temporal context. The new clean-history exact-text run strongly reduces, but does not logically eliminate, that correlation risk.
- **DISPROVED FOR THIS CAPTURE:** stale BugSack history alone; an ordinary operation before the final Chonky marker throwing the captured error; BugGrabber failing to return; or any of the pre-fire callback/`xpcall`/`CallErrorHandler` values being nil at the observed snapshot. A later transient mutation remains unobserved rather than logically impossible.

### Single highest-value next diagnostic — implemented; first LIVE install rejected by identity guard

The smallest next discriminator is a temporary entry/return wrapper around global `CallErrorHandler`, not around `xpcall`. AICO now captures the original `CallErrorHandler` identity at its earliest file scope, registers the existing passive name-based hook while that original is still global, and installs the new wrapper only after `!BugGrabber` loads and its active-handler wrapper is verified. Installation also requires that the global still equal the captured original; it records the observable global security/taint state before and after assignment and verifies the replacement identity. The replacement is prominently diagnostic-only because it changes global function identity/security state.

For each bounded invocation, the wrapper records `CALLERROR-ENTRY` with sequence/time, exact argument count, original first-argument type/bounded text, and existing target correlation; directly calls the retained original `CallErrorHandler` once with the unchanged arguments; records `CALLERROR-RETURN` only after it returns; and returns an explicitly counted packed/unpacked result list so zero results and trailing nils are preserved. It does not use `pcall`/`xpcall`, catch/retry, call the active handler separately, touch item callbacks, add stack/locals capture, or print from either wrapper.

The observer retains the newest 48 `CallErrorHandler` wrapper invocations and reports entries, normal returns, unmatched entries, evictions, original/replacement identities, and pre/post replacement security state through `/aico`. This implementation does not remove the BugGrabber wrapper's last `nativeUnpack` boundary: preserving an arbitrary complete return list while placing a marker after the actual Lua return is not possible. Instead, `CALLERROR-ENTRY` directly establishes ownership, and `CALLERROR-RETURN` establishes that the retained original plus synchronous after-call processing returned to the outer diagnostic wrapper. The latter wrapper itself also has a final unpack/return expression after its marker; that affects return to native `xpcall`, not whether the retained original returned.

Wrapping `xpcall` is not justified at this checkpoint. It would interpose on a fundamental native protected-call primitive across the entire UI, change the outer callable identity for every caller, and risk altering the exact boundary under investigation. A `CallErrorHandler` wrapper does not prove whether native `xpcall` ultimately returns to `FireCallbacks`, but it directly resolves the highest-value current split with much less interference.

| New `CallErrorHandler` wrapper | Existing BugGrabber wrapper | Existing passive post-hook | Interpretation |
| --- | --- | --- | --- |
| `ENTRY` + `RETURN` | `ENTRY` + `RETURN` | observed | `CallErrorHandler` and BugGrabber returned normally; the line-76/error occurrence or later `xpcall` boundary still needs correlation. |
| `ENTRY`, no `RETURN` | `ENTRY` + `RETURN` | absent | The retained original `CallErrorHandler` did not return after BugGrabber's record; the active wrapper's final return, line-4 cleanup, or native after-call processing is the narrowed interval. |
| `ENTRY`, no `RETURN` | no `ENTRY` | absent | failure occurred before the active-handler call, within line-2/line-3 setup/getter/result-invocation boundaries. |
| no `ENTRY` | `ENTRY` + `RETURN` | absent | active handler was reached through another path, or the replacement was bypassed by an opaque secure/native environment; verify pre-fire global identity before choosing. |
| `ENTRY` + `RETURN` | `ENTRY` + `RETURN` | absent | the original function returned through the wrapper but the earlier secure post-hook did not report; hook binding/order/eligibility becomes the leading blind boundary. |
| no `ENTRY` | no `ENTRY` | absent | no relevant handler path was observed; compare fresh error identity and timing before inferring anything. |

Even after this diagnostic, native `xpcall` success/failure return, the host's unprotected-error dispatch, `SetErrorCallstackHeight` internals, and secure-hook ordering remain below the observable mirrored-Lua boundary. Replacing the global can taint it and can perturb reproduction or attribution. Mirrored source does not establish whether the earlier `hooksecurefunc("CallErrorHandler", ...)` remains attached to the captured original function, follows the global name/replacement, or uses another native binding, nor whether one hook's failure suppresses another. The runtime result must therefore include installation identity/security fields and must treat reproduction or non-reproduction under this wrapper as instrumented evidence, not transparent observation.

### LIVE RESULT: direct-wrapper identity guard rejected installation

The first fresh heavy-profile run with the direct-wrapper checkpoint reproduced the same `AsyncCallbackSystem.lua:76` nil-call report with `id=268203` and `i=1`. AICO again loaded first, `!BugGrabber` loaded immediately afterward, the exact Chonky callback was the sole target callback and reached `CALLBACK-END`, and the active BugGrabber wrapper received the fresh error and returned normally. The passive `CallErrorHandler` post-hook again recorded zero.

The new direct wrapper did not install. AICO reported `wrapperInstalled=false`, `installAttempted=true`, and `installStatus="global CallErrorHandler changed before diagnostic replacement"`. This proves only that `_G.CallErrorHandler` at the guard was not `rawequal` to the function captured at AICO file scope. The prior implementation had no checkpoint between those observations, so the current runtime evidence localizes the transition only to "after initial capture and before the post-`!BugGrabber` guard." It does not attribute the change to BugGrabber.

### Focused identity source audit

- LIVE `Blizzard_SharedXMLBase/ErrorUtil.lua:1-6` contains the sole mirrored definition `function CallErrorHandler(...)`. A complete Retail Lua/XML/TOC search found callsites but no later explicit `CallErrorHandler = ...`, `_G.CallErrorHandler = ...`, `setglobal("CallErrorHandler", ...)`, or name-based hook of this function in Blizzard source.
- Reference BugGrabber performs `real_seterrorhandler(grabError)` at `BugGrabber.lua:573` and replaces the public global `seterrorhandler` with a no-op at line 574. Its Lua/XML/TOC contains no assignment to `_G.CallErrorHandler`, no `CallErrorHandler` assignment, and no secure hook of that name. It changes the active handler returned by `geterrorhandler()`; source does not show it changing the global helper function.
- AICO itself calls `hooksecurefunc("CallErrorHandler", CaptureCallErrorHandler)` after saving the original function and before the later guard. No mirrored Lua implementation or generated API contract for `hooksecurefunc` was located. Blizzard source demonstrates name-based and method-form use as after-call hooks, but does not establish whether name-based registration preserves or replaces the global function identity.

The AICO hook call is therefore the leading source-bounded hypothesis for the observed mismatch: it is the only located operation in the known interval that explicitly targets the `CallErrorHandler` global name. It is not verified as the cause. A different addon/native transition before the `!BugGrabber` event remains possible, and event order alone cannot assign ownership.

### Decisive identity-timeline result

The next fresh heavy-profile run resolved the identity transition. Immediately before AICO's name-based secure-hook registration, checkpoint A observed `_G.CallErrorHandler` as `function: 000001F6291ADFE0`. Immediately after `hooksecurefunc("CallErrorHandler", ...)` returned, checkpoint B observed `function: 000001F6FD3F5720` with `equalsInitial=false`. Only microseconds separated the two observations. The B function then remained identical, secure, and untainted through AICO's own lifecycle observations and checkpoints C through F around `!BugGrabber`, active-handler-wrapper installation, and the direct-wrapper guard.

This verifies that AICO's name-based `hooksecurefunc` call is the exact synchronous observation boundary across which the global function identity changed. It does not expose how the client-native hook machinery produces or binds the new function. The mirrored Lua source still contains no `hooksecurefunc` implementation, so the B function must be described as the post-hook global identity rather than as a source-characterized wrapper.

The same run reproduced the line-76 failure with `id=268203`, `i=1`, the exact sole secure/untainted Chonky callback, and `CALLBACK-END`. BugSack displayed `2x`, while AICO recorded exactly one current-session BugGrabber `ENTRY`/`RETURN`; the retained BugGrabber handler again returned normally. The direct `CallErrorHandler` wrapper correctly remained uninstalled because its original-identity guard compared B against A.

### Corrected direct-entry/return architecture

Three arrangements were compared:

1. **Remove the exhausted name-based post-hook and wrap the untouched A identity — selected.** This preserves the clearest ownership chain: native `xpcall` receives AICO's direct wrapper, which invokes the source-known original `CallErrorHandler` exactly once.
2. **Keep the post-hook and wrap B — rejected.** B is runtime-observed but native/opaque. Delegating through it would mix direct entry/return evidence with undocumented secure-hook binding and failure semantics.
3. **Install the direct wrapper and then secure-hook it — rejected.** The secure-hook call would again change the observed global identity and reintroduce the ambiguity the test is intended to remove.

AICO therefore removes the passive `hooksecurefunc("CallErrorHandler", ...)` registration and its obsolete record/output path. The direct wrapper retains the untouched file-scope function and installs only after `!BugGrabber` loads, the active BugGrabber-handler wrapper is verified, and this exact guard succeeds:

```lua
rawequal(_G.CallErrorHandler, originalCallErrorHandler)
```

The identity timeline remains bounded but now has architecture-correct meanings:

- **A:** untouched initial `CallErrorHandler` before AICO installs any passive item-observer hooks;
- **B:** after the passive `ItemEventListener:AddCallback` and `GetCallbacks` hooks, verifying that unrelated observer setup did not change `CallErrorHandler`;
- **C-E:** the existing `!BugGrabber` lifecycle and active-handler-wrapper boundaries;
- **F:** immediately before the unchanged original-identity guard; and
- **G:** after successful direct-wrapper assignment and identity verification.

Normal `ADDON_LOADED` records remain transition-only. Each checkpoint reports identity/type, equality to A/B/C/E/G reference values, guarded security/taint state, time, and lifecycle context. No polling, timer, `OnUpdate`, or startup printing is added.

For each direct-wrapper call, `CALLERROR-ENTRY` is appended before invoking the retained original `CallErrorHandler` exactly once with the unchanged argument list. `CALLERROR-RETURN` is appended only after that retained function and its synchronous handler work return. Explicit-count pack/unpack preserves zero returns, one nil, multiple returns, and trailing nils. The wrapper contains no `pcall`/`xpcall` and does not separately invoke `geterrorhandler`, BugGrabber, or any item callback.

One unavoidable boundary remains: `CALLERROR-RETURN` is written before the wrapper's final `nativeUnpack(...)/return` expression. It proves that the retained original returned to AICO, not that AICO's own final return completed back into native `xpcall`. Adding another helper would only move this unobservable boundary.

| Next-run case | Interpretation |
| --- | --- |
| Wrapper installed; `CALLERROR-ENTRY`; BugGrabber `ENTRY`/`RETURN`; `CALLERROR-RETURN` | The retained original `CallErrorHandler` was entered and returned to AICO after its synchronous handler work. Any remaining discontinuity is after that retained body or at a later/native boundary. |
| Wrapper installed; `CALLERROR-ENTRY`; BugGrabber `ENTRY`/`RETURN`; no `CALLERROR-RETURN` | `CallErrorHandler` definitely entered but did not return to AICO after BugGrabber's recorded return; the remaining interval is sharply bounded. |
| Wrapper installed; no `CALLERROR-ENTRY`; BugGrabber `ENTRY`/`RETURN` | The observed active-handler invocation bypassed the installed global wrapper, subject to native replacement/bypass limits. |
| Wrapper installed; `CALLERROR-ENTRY`; no BugGrabber `ENTRY` | The retained original entered but did not reach the active BugGrabber handler through the observed path before failure or return. |
| Wrapper not installed | Do not interpret missing entry. Report the exact identity/security guard state first. |
| Failure does not reproduce after installation | Treat non-reproduction as weak observer-effect evidence, not disappearance of the underlying issue. |

Assigning `_G.CallErrorHandler` remains invasive diagnostic instrumentation. It can taint the global, alter native behavior, shift error attribution, or suppress/change reproduction. A reproducing run with coherent entry/return records is high-value; a clean run is not proof of a fix. Native `xpcall` behavior and the wrapper's final return remain below the mirrored-source boundary.

### LIVE RESULT: Case 3, active handler bypassed the installed global wrapper

The next fresh heavy-profile run used weapon `268203`, Phoenix Oil item `243734`, and the same controlled addon environment. AICO observed the original `CallErrorHandler` identity remain stable through A-F and verified its direct wrapper active at G. At target `GetCallbacks(268203)`, the bucket length was one and the sole secure/untainted function was the Chonky callback `function: 0000022BEEE61C10`. Chonky again reached `CALLBACK-END`.

The line-76 error reproduced. The target lookup occurred at `23724.687421`; the active-handler wrapper entered at `23724.687884`, approximately `0.463ms` later, with the exact line-76 nil-call text. It delegated to retained BugGrabber once and recorded normal return at `23724.689801`. AICO's verified direct `CallErrorHandler` wrapper recorded zero entries and zero returns. BugSack's displayed `3x` count is not three fresh occurrences; AICO observed one current-session handler invocation.

This is the documented Case 3. It proves that the observed active-handler invocation did not traverse the installed addon-global wrapper. It does not prove whether native `xpcall` used another environment/binding, whether an unprotected/native failure at the line-76 callsite invoked the active handler directly, or whether a separate occurrence was correlated with the target lookup. It also does not prove that BugGrabber generated the error: its wrapper entry occurred after an error argument already existed, and the retained BugGrabber handler returned normally.

### Source-visible routes to the active error handler

1. **Explicit `xpcall` message handler.** In the written line-76 path, a protected callback error causes `xpcall` to invoke its second argument. The source-written second argument is global `CallErrorHandler`, whose line 3 invokes `geterrorhandler()`. Under ordinary same-environment semantics, AICO's verified wrapper should therefore have entered first. Case 3 contradicts that ordinary chain for the observed handler invocation.
2. **Direct Lua calls to `geterrorhandler()`.** Retail source calls the returned handler from `CallErrorHandler`, `assertsafe`, the print handler's protected-failure branch, and restricted-environment `SoftError` helpers. Any such call can reach the active handler without traversing AICO's global wrapper unless the caller is `CallErrorHandler` itself. No current evidence identifies one of these alternate callers for the target occurrence.
3. **Unprotected Lua error dispatch.** The client installs an active handler through `seterrorhandler`; BugGrabber and Blizzard's default script-error system rely on native host delivery of unprotected errors. The C++/VM dispatch implementation is not mirrored. An unprotected failure while invoking global `xpcall`, or a native failure attributed to its callsite, is compatible with direct active-handler entry and no `CALLERROR-ENTRY`.
4. **Failure inside an `xpcall` message handler.** Ordinary Lua distinguishes a protected-function error from an error raised while handling that error, but the mirror does not define how the WoW VM formats or redispatches the second failure. Case 3 has no direct-wrapper entry, so it does not support a failure inside AICO's retained `CallErrorHandler` body for this invocation. BugGrabber's normal return also disproves non-return inside its retained handler for the one recorded call.
5. **Native/secure execution.** The host can perform error attribution, protected calls, secure-hook dispatch, and active-handler invocation below the Lua mirror. This is the remaining opaque category, not a license to assert a particular implementation.

### Is BugGrabber only the messenger?

Whether BugGrabber was only a messenger in every earlier capture remains unresolved. Source and runtime establish that BugGrabber replaces the default active handler, stores/deduplicates errors, and notifies BugSack; in the captured Case-3 invocation it received an already-formed error string and returned normally. Those facts support **observer/messenger** for that invocation. The earlier OFF-clean/ON-failing pair and the fact that replacing the active handler can perturb native dispatch support **possible contributor or reproduction modifier**. They do not establish **direct cause**. Logs_17 and Logs_18 now establish separately that neither BugGrabber nor BugSack was required for the same observed line-76 occurrence in that tested full-profile configuration.

The shortest discriminator was therefore the same heavy startup with BugGrabber and BugSack disabled while AICO installed one minimal wrapper around the pre-existing/default active handler. Logs_17 and Logs_18 subsequently completed that experiment and captured the same exact line-76 error, proving that BugGrabber is not required for the observed occurrence in that tested configuration. This does not prove that changing the active-handler composition has no observer effect or that BugGrabber was irrelevant in every earlier composition.

### Installed-addon relevance screen

A read-only installed-source scan found no assignment to `ItemEventListener` or the relevant `AsyncCallbackSystemMixin` methods/tables, and no relevant secure hook beyond AICO/AICD's documented observation hooks. It found multiple calls to `seterrorhandler` in installed addon code, notably `!KalielsTracker`, Krowi Achievement Filter diagnostics, TradeSkillMaster diagnostics, and Zygor error logging, plus development/test or embedded-server copies. A literal callsite is not proof that it ran or changed the handler: after standalone BugGrabber loads, its public global setter is a no-op, and the `/aico` loaded timeline remains necessary to identify enabled/runtime candidates.

Static `ContinueOnItemLoad` callsite counts identify volume groups, not failures. The largest installed-source groups include Auctionator, ProfessionShoppingList, CraftSim, ManuscriptsJournal, Journalator, EnhanceQoL, BetterWardrobe, RareScanner, and OUS; OUS is already known not to be required. Synchronous `C_AddOns.LoadAddOn` callers are concentrated separately in ChampionCommander, OrderHallCommander, Krowi Achievement Filter, DBM-Core, BetterWardrobe, TradeSkillMaster, and others. The highest-priority interaction groups are therefore: error-handler modifiers/listeners; addons overlapping item-continuation and LoD startup activity; high-volume continuation producers; LoD-only startup loaders; and finally unrelated addons with no located path. Chonky remains fixed initially because it supplies the attributed target callback; its volume makes it an interaction/exposure candidate, while repeated `CALLBACK-END` makes its instrumented body a weak direct-cause candidate.

### Controlled reduction and launch counts

Use the exact AICO loaded-addon inventory from a reproducing run as the candidate set. Preserve the same character, weapon `268203`, Phoenix Oil item `243734`, cache-clearing policy, AICO/AICD, Chonky, and no-hover/no-panel startup procedure.

1. Establish a current positive baseline with five fresh full-client launches. Require at least two reproductions before treating subsequent clean branches as exclusion evidence.
2. Run the BugGrabber/BugSack-disabled active-handler experiment for five launches. Any exact line-76 handler entry is a positive. If all five are clean, restore BugGrabber/BugSack for three flanking launches; require at least one reproduction, then run three additional OFF launches. Eight clean OFF launches plus a reproducing flank make the handler environment a strong reproduction requirement, not direct-cause proof.
3. For addon reduction, keep the fixed diagnostic/Chonky core and split only the remaining loaded candidates into source-ranked groups. Test both halves rather than randomly disabling individual addons. Each branch gets five fresh launches. A branch with any reproduction remains live. A five-clean branch is provisional until extended to eight clean launches and flanked by a reproducing parent/control branch.
4. If only one half reproduces, recurse within it. If both reproduce, neither half contains a uniquely required addon; look for shared fixed components or independent triggers. If neither reproduces while the full parent still does, test cross-group interaction matrices rather than declaring both halves clean.
5. After a minimal set is found, use explicit `none`, `A`, `B`, and `A+B` profiles. Singles need eight clean launches with positive flanks; `A+B` should reproduce at least twice in five launches in two separate cycles before classifying an interaction as required.

Classification stops are strict:

- **Addon required for reproduction:** removing it yields eight clean launches with reproducing flanks, and restoring it reproduces at least twice in five launches across two cycles. This is not yet direct cause.
- **Addon direct cause:** runtime/source evidence identifies the failing operation in that addon or its concrete mutation of shared callback/error-handler state. Load order, callback ownership, or volume alone is insufficient.
- **Addon interaction:** the `A` and `B` singles meet the clean threshold, `A+B` repeatedly reproduces, and the combined source/runtime path is identified at least to a shared boundary.
- **Blizzard bug exposed by addons:** a minimal supported-API sequence repeatedly reproduces with valid callback/callable state, no addon mutation of shared internals, and the failure localized to Blizzard `AsyncCallbackSystem` or opaque native handling. If native behavior prevents absolute proof, report high-confidence classification and the remaining opaque boundary.

### Implemented BugGrabber-independent active-handler checkpoint

AICO now queries `C_AddOns.GetAddOnEnableState("!BugGrabber", UnitGUID("player"))` during early load. When the result proves BugGrabber disabled, it waits through `PLAYER_LOGIN`, captures the then-active pre-existing handler at the first initial-login `PLAYER_ENTERING_WORLD`, installs one wrapper through the native `seterrorhandler` captured before third-party addons, and verifies it with the captured native getter. It does not install this fallback on a reload or later zone transition. Earlier captures place target pre-fire after world entry; if a future target lookup precedes installation, that run cannot support absence conclusions. If the enable-state query is unavailable, fails, or returns a non-number, installation fails closed. When BugGrabber is enabled, AICO retains the existing behavior of waiting for `!BugGrabber` and wrapping its installed handler; only then is the separate direct `CallErrorHandler` wrapper considered. In the BugGrabber-off branch, `callErrorWrapperInstallAttempted=false` is expected. Because other installed addons contain error-handler setter callsites, `/aico` also queries the current active handler at snapshot time. Its explicit BugGrabber-off validity field is true only when the loaded-addon inventory is complete, BugGrabber and BugSack are absent, the first-world-entry fallback installed successfully, and `equalsWrapper=true`; a later replacement invalidates entry-absence interpretation.

The active-handler wrapper appends bounded `ENTRY`, invokes the retained selected handler exactly once with unchanged arguments, appends `RETURN` only after normal return, and preserves the complete explicit-count result list. It contains no `pcall`/`xpcall`, printing, stack/locals capture, item query, timer, polling, or `OnUpdate`. Replacing the active handler remains invasive and may change reproduction. A clean result under this wrapper is weak without the repeated/flanked controls above.

## Completed BugGrabber-off structural and boundary-provenance controls

### VERIFIED RETAIL RUNTIME OBSERVATIONS: Logs_17 and Logs_18

Logs_17 exercised the BugGrabber-independent active-handler checkpoint in the full normal addon profile with BugGrabber and BugSack absent. The control was valid: the fallback wrapper was installed at first initial-login `PLAYER_ENTERING_WORLD`, remained the active handler through the snapshot, and delegated once to the retained pre-existing handler, which returned normally. The exact `AsyncCallbackSystem.lua:76: attempt to call a nil value` report still occurred for item `268203`. The sole identified Chonky callback reached `CALLBACK-END`; the tracked `FireCallbacks(268203)` invocation then reached its secure `DISPATCH_NORMAL_EXIT`; approximately 37 microseconds later the active handler received the line-76 string when no tracked Item, Quest, or Spell dispatch was open. This proves that BugGrabber and BugSack are not required for the observed line-76 occurrence in that tested configuration. It does not prove that error-handler replacement has no observer effect or identify the occurrence's cause.

Logs_18 added the bounded boundary-provenance probe under the same BugGrabber-off full normal profile. For this live control, terminology is:

- **A** — the actual value supplied as the second argument to the line-76 `xpcall`; addon-level instrumentation did not directly observe this exact instruction-time binding;
- **B** — AICO's verified direct wrapper installed as the addon-global `CallErrorHandler` value; and
- **C** — AICO's independently installed active error-handler wrapper returned by the captured native `geterrorhandler` path.

The Logs_18 validity gates passed: BugGrabber and BugSack were absent, the BugGrabber-off active-handler wrapper remained verified, the direct global B wrapper remained active, and the target boundary records had no drops or snapshot failures. The sole target bucket entry was the valid secure/untainted Chonky callback, and its diagnostic body reached `CALLBACK-END`. The target `FireCallbacks(268203)` body cleared the detached bucket and reached its secure normal-return post-hook. Approximately 72 microseconds later C received the exact line-76 string and delegated to the retained original handler, which returned normally. At C entry, no tracked Item, Quest, or Spell dispatch was open. B recorded zero entries and zero returns. The sampled global `xpcall` remained a secure, untainted function at the recorded boundaries.

The verified broad ordering for Logs_18 is therefore:

```text
identified callback body reaches CALLBACK-END
-> visible FireCallbacks cleanup completes
-> secure FireCallbacks post-hook runs
-> no tracked dispatch remains open
-> C receives the line-76 error string
-> retained active handler returns normally
```

B observed zero entries throughout. This is an observational boundary result, not proof that line 76 did not execute, that the live A differed from B, that native code bypassed `CallErrorHandler`, or that the C event was necessarily generated by the immediately preceding tracked invocation.

## Synthetic `!AsyncErrorBoundaryHarness` runtime experiment

### VERIFIED SOURCE AND HARNESS-DESIGN FACTS

`Samples/!AsyncErrorBoundaryHarness/` is a standalone synthetic baseline. It uses a private dispatcher with an explicit `xpcall(callback, A)` expression, visible cleanup, a secure post-hook on the harness-owned dispatcher method, and caller-before/caller-after markers. It does not replace Blizzard `FireCallbacks`, mutate Blizzard or production callback tables, wrap global `xpcall`, use SavedVariables, or integrate with Chonky, Zygor, AICO, AICD, or RetailUIResearch runtime modules.

In the harness:

- **A** is the explicitly selected second-argument value for the tested `xpcall`;
- **B** is the private local `HarnessMessageHandler`; and
- **C** is the active handler returned by `geterrorhandler()`, observed through the temporarily installed harness wrapper.

The C wrapper records entry, delegates once to the retained original active handler with the unchanged argument list, records return only after a normal return, and preserves exact return multiplicity. Installation and restoration are explicit and identity-verified.

### VERIFIED RETAIL RUNTIME OBSERVATIONS: environment and restoration

The completed controlled session reported BugGrabber and BugSack runtime-absent, a valid composition gate, and out-of-combat execution. Global `xpcall` retained the same observed identity and remained a secure, untainted function during the tested session; `globalXpcallWrapped=false`. Blizzard `FireCallbacks` was not replaced, production callback tables were not mutated, and no SavedVariables were used.

The harness active error-handler wrapper was installed only for the test session and restored successfully. Final state was `handlerInstalled=false` with `handlerStatus="restored and verified"`; the current active handler again equaled the retained original, the harness wrapper was no longer active, and the retained handler reference was cleared.

### VERIFIED RETAIL RUNTIME OBSERVATIONS: test matrix

#### `normal`

The exact event order was:

```text
RUN_BEGIN
CALLER_BEFORE
METHOD_ENTRY
BEFORE_XPCALL
CALLBACK_ENTRY
CALLBACK_END
XPCALL_RETURN
CLEANUP_BEGIN
CLEANUP_END
METHOD_BODY_FINAL
SECURE_POST_HOOK_ENTRY
CALLER_AFTER
RUN_COMPLETE
```

A equaled B. Neither B nor C ran. `xpcall` returned four values: `true`, `"normal-result"`, `nil`, and `10`. The secure post-hook occurred after the method body's final marker and before caller-after.

#### `callback-nil`

A equaled B. The callback entered and the deliberate nil call failed at its stable line inside `Harness.lua`. B entered, C entered while B was active, C returned, B returned, and `xpcall` returned `false, nil`. Only then did cleanup, the method-body final marker, secure post-hook, caller-after, and run completion occur. Both B and C therefore ran before cleanup and before the secure post-hook in this ordinary protected callback-failure control.

#### `first-nil`

The first argument to `xpcall` was nil, the callback did not enter, and A equaled B. B then C received exactly `attempt to call a nil value`, without a file/line prefix. `xpcall` returned `false, nil`; cleanup and the secure post-hook occurred only after B and C completed.

#### `first-number`

The first argument to `xpcall` was a number, the callback did not enter, and A equaled B. B then C again received exactly `attempt to call a nil value`, and `xpcall` returned `false, nil`; cleanup and the secure post-hook followed B/C completion.

For this Retail client and tested session, the text `attempt to call a nil value` therefore does not uniquely prove that an invalid first argument supplied to `xpcall` was literally nil. Both nil and numeric first arguments produced the same text. This is a client/session observation, not a universal Lua-language claim.

#### `handler-nil`

A was nil. The callback entered and deliberately failed, but neither B nor C ran. `xpcall` returned `false, "error in error handling"`; cleanup and the secure post-hook then completed normally.

#### `handler-number`

A was a number. The callback entered and deliberately failed, but neither B nor C ran. `xpcall` again returned `false, "error in error handling"`; cleanup and the secure post-hook then completed normally.

The two malformed-handler controls establish that a simply nil or numeric A did not naturally cause later direct C delivery after cleanup or the post-hook in this harness.

#### `direct-c-body`

This was an intentionally constructed reference control, not a candidate live mechanism. The harness invoked C directly inside the dispatcher method body without an inner `xpcall`. C entered and returned before cleanup, the method-body final marker, secure post-hook, and caller-after. It verifies that direct C delivery can occur without B, but its ordering does not match Logs_18.

#### `direct-c-after`

This case was explicitly tautological and intentionally constructed. A normal callback and `xpcall` return were followed by cleanup, method-body completion, the secure post-hook, and caller-after; only then did the harness deliberately invoke C directly. It produces the broad post-hook-before-C shape solely because the test calls C after the dispatcher has returned. It is a reference for the instrumentation signature of deliberate later C delivery and is not evidence for the Logs_18 mechanism.

### Structured comparison

| Constructed or observed path | Verified ordering | B | C |
| --- | --- | --- | --- |
| Valid A=B plus callback failure | B -> C -> `xpcall` return -> cleanup -> post-hook | Yes | Yes, while B active |
| Invalid first argument plus valid A=B | B -> C -> `xpcall` return -> cleanup -> post-hook | Yes | Yes, while B active |
| Invalid A | `xpcall` returns `"error in error handling"` -> cleanup -> post-hook | No | No |
| Direct C inside dispatcher body | C -> cleanup -> post-hook | No | Yes |
| Deliberate direct C after completion | cleanup -> post-hook -> caller-after -> C | No | Yes, by explicit construction |
| Logs_18 live observation | tracked callback/body completion -> `FireCallbacks` cleanup -> secure post-hook -> C, with no tracked dispatch open at C entry | Zero observed entries | Yes |

### INTERPRETATION

None of the ordinary synthetic `xpcall` failure modes reproduced the Logs_18 ordering. This materially weakens the following as complete explanations of the captured live shape:

- a simple callback failure through the ordinary visible `xpcall(callback, CallErrorHandler)` path;
- a nil or non-function first argument to `xpcall`;
- a nil or non-function message handler A; and
- an ordinary direct-C call made inside the tracked dispatcher body.

The experiment does not prove a Blizzard native bug, that line 76 did not execute, that native/runtime layers bypassed `CallErrorHandler`, that Chonky is uninvolved, that `xpcall` was uninvolved, or that the live error belongs to a separate occurrence. Addon-level instrumentation still cannot directly observe the exact live A binding at the instruction, VM/native protected-call return state, or opaque native error-delivery and secure-hook behavior.

### Remaining hypothesis ranking through authoritative Log_28

| Hypothesis | Current assessment | Evidence through Log_28 |
| --- | --- | --- |
| H1. Simple dispatcher nil callback | Very low; further weakened | Earlier valid-function buckets and the harness already contradicted this. Logs_20–22 observed nil `GetCallbacks(268203)` results; Logs_20/22 delivered C/error and Log_21 did not. AICD records nil `246664` buckets in Logs_23–28; enchanted Log_27 is clean while Logs_23/25/26/28 error. A nil bucket is not sufficient and is not itself a nil loop-local callback. |
| H2. Direct Chonky callback-body/callee failure | Very low as a direct explanation; not required in the tested composition | The instrumented body completed in Logs_18, and the exact occurrence reproduced with Chonky runtime-absent in Logs_19, 20, 22, 23, 25, 26, and 28. |
| H3. The tracked body completes or is skipped, then C is reached by a different/later path or behavior outside the ordinary visible Lua error path | Leading observational model; mechanism still unknown | Logs_20/22 are the strongest measured splits: nil bucket, normal tracked return, then C `0.034ms`/`0.031ms` later. Logs_21/24/27 show that the same broad nil-dispatch shape need not be followed by C. Logs_23/25/26/28 match only at the higher level—C with no B entry and no tracked dispatch open—because the relevant AICO open/exit was not retained. |
| H4. Tracked nested Item/Quest/Spell dispatch | Very low | Logs_17–28 report maximum depth one. Log_28 has no tracked dispatch open at C entry; Log_27 has no C entry. No structural mismatch, drop, or dispatch failure was retained in either run. |
| H5. Installed global B machinery failure or simply malformed message handler | Very low | In Logs_18–28 the installed B wrapper remained the sampled global identity and recorded zero entries in every applicable capture. Log_28 reaches C while Log_27 does not. Invalid-handler harness cases produced `"error in error handling"` without C, unlike the live failure captures. |
| H6. Transient or opaque A/B-binding difference at exact evaluation | Runtime-compatible but unverified | Boundary samples are stable, but instrumentation cannot observe exact A at the instruction or exclude a between-sample change, another environment, or opaque binding behavior. |
| H7. Heavy-composition/startup-runtime cofactor | Moderate; refined to include the QuickCrafts selector, mechanism unresolved | The valid Log_26 ERROR -> Log_27 CLEAN -> Log_28 ERROR branch changes only QuickCrafts runtime membership while preserving projected addon-load order. Source proves QuickCrafts requests 165 unique item IDs in an immediate load pass and a delayed PEW pass; runtime retains a 106-registration tail and aggregate differences align with two such passes. QuickCrafts workload, item readiness, Auctionator interaction, another retained-addon interaction, or scheduling perturbation are plausible cofactors, but one clean OFF run and aggregate counts do not establish causality or a callback-pressure threshold. |
| H8. Temporary weapon-enchant/imbue environmental-state correlation (historically Phoenix Oil/Oil-specific) | Repeatable co-condition in the tested full-profile-derived branch; explicitly insufficient | Logs_26–28 all verify runtime enchant `5400`, but Log_27 is clean while Logs_26/28 error. This directly proves temporary-enchant state alone is insufficient even in the 158/159-name reduced branch. It remains a shared reproduction context, not a proven causal or globally necessary state. |
| H9. Nil-bucket/repeat behavior as a direct cause | Very low; associated timing marker only | Log_27 and Log_28 both have nil `246664` AICD buckets while only Log_28 errors. QuickCrafts does not request `246664`, and its retained batch is not a `246664` repeat. Neither nil state, repetition, nor the batch itself is established as the direct cause. |

This ranking does not invent a native mechanism. H3 is an observational model that preserves the unresolved split among distinct occurrence, later delivery, transient binding, an untracked source path, and opaque runtime behavior.

## Completed controlled reductions and authoritative Logs_20/21

The earlier plan for Log_19 was completed: Chonky was runtime-absent, Zygor remained loaded, and the exact failure reproduced next to a nil target bucket. Authoritative Log_20 then removed Zygor as well while explicitly retaining Phoenix Oil. Authoritative Log_21 kept the observed owner-reduced loaded-addon inventory while removing the temporary enchant and remained clean. Any earlier Oil-state-uncertain file described as Log_20 is discarded and is not evidence in this document; only `Logs_20_BugGrabberChonkyZygorOff_FullNormalProfileOilON.txt` is authoritative.

### Authoritative file identity

| Field | Verified value |
| --- | --- |
| Filename | `Logs_20_BugGrabberChonkyZygorOff_FullNormalProfileOilON.txt` |
| Size | `237141` bytes |
| Physical lines | `2721` |
| SHA-256 | `48B1A4D43886F56D478D9D7288AEB06C9DF7933886828A26BAAF2C023F82E4ED` |

### VERIFIED RUNTIME OBSERVATION: controlled state

The snapshot reports `loadedAddonCount=165` with `loadedInventoryStatus=ok`. This is runtime-loaded state, not a claim about the addon's configured enable flag.

| Control or family | Authoritative Log_20 observation |
| --- | --- |
| Chonky Character Sheet | Runtime-absent: no loaded-inventory entry; `ADDON_LOADED ChonkyCharacterSheet <not observed>`; target contexts say `chonkyLoaded=false`. |
| Zygor | Runtime-absent: no Zygor folder/module occurs in the complete 165-addon loaded inventory. |
| BugGrabber / BugSack | Both runtime-absent. Character enable query returned `enableState=0`. `bugGrabberOffControlValid=true`. |
| Error-boundary harness | Runtime-absent from the complete inventory. |
| AICO | Runtime-loaded as `!AsyncItemCallbackObserver`; observer installed, both diagnostic wrappers verified, and the snapshot was produced. |
| AICD | Active and visible: its log starts with `INIT`, then `ADDON_LOADED addon=AsyncItemCallbacksDiagnostic`, and contains target/equipment records. |
| RetailUIResearch | Runtime-loaded at AICO time `12660.412326` (`+8.930660s`) and listed in the inventory. |
| Login/world | `PLAYER_LOGIN` at `12672.934276` (`+21.452611s`); first `PLAYER_ENTERING_WORLD` at `12676.463876` (`+24.982210s`) with `initialLogin=true`, `reloadingUi=false`. |
| Failure-adjacent load context | Last completed addon was `Blizzard_AuctionHouseUI`. |
| Boundary controls | `boundaryProvenanceControlValid=true`; `directWrapperGlobalActive=true`; BugSack install gate verified not loaded/loading. |
| Active handler | Wrapper installed at first PEW and still active at snapshot as `function: 00000205C7EE0990` with `equalsWrapper=true`. |
| BetterWardrobe family | `BetterWardrobe` loaded; `BetterWardrobe_SourceData` absent from the complete inventory. |
| Baganator family | `Baganator` and `Syndicator` loaded. |
| TSM family | `TradeSkillMaster` and `TradeSkillMaster_AppHelper` loaded. |
| Raider.IO family | `RaiderIO`, `RaiderIO_DB_EU_F`, `RaiderIO_DB_EU_M`, and `RaiderIO_DB_EU_R` loaded. |
| Altoholic/DataStore | `Altoholic`, `DataStore`, and the listed DataStore backend modules loaded; this says nothing about their configuration. |

### VERIFIED RUNTIME OBSERVATION: Phoenix Oil and equipment

AICD's early `INIT`, `PLAYER_LOGIN`, and `PLAYER_ENTERING_WORLD` reads showed `itemID=nil tempEnchant=false`; these are unreadable/early observations and do not prove that Oil was absent. At `BUFFER_RESOLVED`, main-hand slot 16 resolved to item `268203` with `tempEnchant=true`, `enchantID=8052`, `remainingMs=0`, and `charges=0`. Off-hand slot 17 was item `272275` with `tempEnchant=false`.

For target `268203`, AICD then recorded a nil-bucket PREFIRE/COMPLETE pair with the same active enchant and `remainingMs=0`, immediately followed in AICD's own timestamp window by a second nil-bucket PREFIRE/COMPLETE pair with `remainingMs=7192000`. The final equipment record retained that positive duration. Thus the temporary enchant and ID `8052` are independently verified, and the transition from zero to a positive reported duration is real. Neither the zero value nor `7192000` is assigned causal meaning. AICD uses `GetTime()` while AICO prefers `GetTimePreciseSec()`; their absolute timestamps are therefore not treated as one exact cross-diagnostic clock.

### Complete target `268203` chronology

AICO reports `target268203Registrations=0`, `registrationDrops=0`, `prefire=2`, and `prefireDrops=0`; the dedicated registration section says `<none observed>`. There is therefore no callback identity, owner, registration order, stack, bucket generation, or later valid target dispatch to report in authoritative Log_20.

The two AICD target pairs and AICO's two target prefires have a matching two-invocation shape and likely describe the same physical episode, but they use different clocks and independently scoped order counters. They are therefore presented separately without claiming exact cross-diagnostic timestamps or ordering:

| Diagnostic event | Diagnostic time/order | Observed target state |
| --- | --- | --- |
| AICD PREFIRE / COMPLETE | `t=12686.180`, GetCallbacks order `745`, AICD records `#008/#009` | Slot 16 item `268203`; Oil true, enchant `8052`, `remainingMs=0`; callback map table, target bucket nil; no entry origin. |
| AICD PREFIRE / COMPLETE | `t=12686.180`, GetCallbacks order `746`, AICD records `#010/#011` | Same item/enchant; `remainingMs=7192000`; target bucket nil; no entry origin. |

The AICO boundary chronology uses one clock and supports direct deltas:

| AICO event | Absolute / elapsed time | Order or sequence | Bucket and structural state | Sampled callable/boundary state |
| --- | --- | --- | --- | --- |
| Failure-adjacent GetCallbacks/PREFIRE | `12689.208791` / `+37.727125s` | GetCallbacks `748` | Callback map table; target bucket nil. No callback, identity, generation, or owner. Stack confirms `GetCallbacks` from visible `FireCallbacks` line 71. | Callable snapshot includes secure-function globals; context has Chonky false and last addon `Blizzard_AuctionHouseUI`. |
| Structural DISPATCH_OPEN | `12689.209116` / `+37.727451s` | Dispatch `849`, target ordinal 1 | Item `268203`; depth 1; no parent; target ancestor 849; retained bucket nil, no length/generation. | `xpcall` = secure function `0000020428275668`; B = AICO wrapper `00000205C78A3020`, insecure/tainted by AICO, `equalsInstalledWrapper=true`. GetCallbacks -> open: `0.325ms` (`325us`). |
| Structural DISPATCH_NORMAL_EXIT | `12689.209365` / `+37.727699s` | Dispatch `849` | Depth closes to zero; mapped bucket nil; `mappedEqualsRetained=true`; `stackMatch=true`. | Same sampled `xpcall` and B identities. Open -> exit: `0.249ms` (`249us`). |
| Active C ENTRY | `12689.209399` / `+37.727733s` | Active-handler sequence 1; boundary 3 | No tracked dispatch open; depth 0; empty stack. | Exact string `.../Blizzard_ObjectAPI/Mainline/AsyncCallbackSystem.lua:76: attempt to call a nil value`; labels `C_WITHOUT_ACTIVE_B,TARGET_NORMAL_EXIT_BEFORE_C`; same sampled `xpcall` and B identities. Exit -> C: `0.034ms` (`34us`); open -> C: `0.283ms`; GetCallbacks -> C: `0.608ms`. |
| Active C RETURN | `12689.209777` / `+37.728112s` | Active-handler sequence 1 | Retained handler returned normally; zero return values recorded. | C entry -> return: `0.378ms` (`378us`). |
| Repeat GetCallbacks/PREFIRE | `12689.216517` / `+37.734852s` | GetCallbacks `749` | Target bucket nil; no callback/owner. | C return -> repeat lookup: `6.740ms`. |
| Repeat DISPATCH_OPEN | `12689.216560` / `+37.734895s` | Dispatch `850`, target ordinal 2 | Depth 1; no parent; target ancestor 850; bucket nil. | Same sampled `xpcall` and B. Lookup -> open: `0.043ms`; C return -> open: `6.783ms`; original open -> repeat open: `7.444ms`; preceding normal exit -> repeat open: `7.196ms`. |
| Repeat DISPATCH_NORMAL_EXIT | `12689.216822` / `+37.735156s` | Dispatch `850` | Mapped bucket nil; `mappedEqualsRetained=true`; `stackMatch=true`; depth returns to zero. | Same sampled `xpcall` and B. Instrumented open -> exit delta: `0.261ms`; prior normal exit -> this exit: `7.457ms`. |

There is exactly one immediate nil-bucket repeat after C and no subsequent target registration or valid target dispatch in the captured Log_20 window. AICO's session totals were `dispatchOpens=2130`, `normalExits=2130`, `currentOpenDepth=0`, `maxDepth=1`, `stackMismatches=0`, `targetStructuralDrops=0`, and `dispatchFailures=0`.

### SOURCE-VISIBLE IMPLICATION of the nil bucket

For dispatch 849, the `GetCallbacks` post-hook and structural open both observed nil. In the visible source, `GetCallbacks` returns `self.callbacks[id]`; a nil result makes `if callbacks then` false. The body containing `ClearCallbacks`, `ipairs`, line 76, and final array cleanup therefore did not execute for this particular tracked invocation. The secure post-hook proves a normal observed `FireCallbacks` return, not caller-visible completion of every native trampoline or host layer.

This does not show that line 76 executed nowhere else, that the error text names the wrong source line, or that native code is broken. It separates three facts: the tracked invocation visibly skipped the body; C received a string attributing a nil call to line 76; addon instrumentation cannot observe exact A at another instruction, all execution environments, every tightly correlated invocation, or opaque native/error-delivery behavior.

### A/B/C boundary provenance

At target open, normal exit, C entry, repeat open, and repeat exit, sampled `xpcall` was the same secure function `function: 0000020428275668`. Sampled global B was the same `function: 00000205C78A3020`, marked `secure=false`, `taint=!AsyncItemCallbackObserver`, and equal to AICO's installed direct wrapper. The B wrapper totals remained zero entries, zero normal returns, and zero unmatched entries. C recorded one entry and one normal return.

The exact observed order is: target GetCallbacks -> target open -> target normal exit -> C entry -> C normal return -> repeat GetCallbacks -> repeat open -> repeat normal exit. At C entry the structural depth was zero and the open stack empty. The sampled global `CallErrorHandler` wrapper therefore remained the observed global B identity at the target boundaries, but AICO recorded no traversal of that installed wrapper before the active handler received the line-76 string. Stable snapshots do not establish exact A at line 76 or exclude transient changes between samples; `C_WITHOUT_ACTIVE_B` is an observational label, not a claim that native code bypassed B.

### Comparison with Logs_26 through 15

| Capture | Chonky / Zygor runtime | BugGrabber / BugSack | Temporary-enchant state | Target registrations | Failure-adjacent bucket / direct owner | Normal exit before C; open at C | B wrapper | Immediate target pattern | Structural integrity | Exact error |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- |
| Log_26 authoritative | absent / absent | absent / absent | Shaman weapon imbue; runtime enchant `5400` | target `268203`: 0; no retained `246664` registration | AICD `246664` bucket nil / no entry origin; AICO immediately preceding lookup is `246664`, but no corresponding structural record retained | not retained for `246664`; no tracked open at C | installed, 0 entries; C entry yes | no retained post-C `246664` repeat | max depth 1; 0 mismatch/drop/failure | yes |
| Log_25 authoritative | absent / absent | absent / absent | Shaman weapon imbue; runtime enchant `5400` | target `268203`: 0; no retained `246664` registration | AICD `246664` bucket nil / no entry origin; AICO immediately preceding lookup is `246664`, but no corresponding structural record retained | not retained for `246664`; no tracked open at C | installed, 0 entries; C entry yes | no retained post-C `246664` repeat | max depth 1; 0 mismatch/drop/failure | yes |
| Log_24 authoritative | absent / absent | absent / absent | none; both weapons unenchanted | target `268203`: 0; no retained `246664` registration | AICD `246664` bucket nil / no entry origin; no corresponding AICO structural record retained | not retained for `246664`; no C entry | installed, 0 entries; C entries 0 | one AICD nil-bucket `246664` episode; no repeat | max depth 1; 0 mismatch/drop/failure | no |
| Log_23 authoritative | absent / absent | absent / absent | Shaman weapon imbue; runtime enchant `5400` | target `268203`: 0; no retained `246664` registration | AICD `246664` bucket nil / no entry origin; AICO immediately preceding lookup is `246664`, but no corresponding structural record retained | not retained for `246664`; no tracked open at C | installed, 0 entries; C entry yes | no retained post-C `246664` repeat | max depth 1; 0 mismatch/drop/failure | yes |
| Log_22 authoritative | absent / absent | absent / absent | Oil of Dawn; active `8053` | 0 | nil / none observed | yes; no tracked open | installed, 0 entries; C entry yes | original nil + 1 nil repeat | max depth 1; 0 mismatch/drop/failure | yes |
| Log_21 authoritative | absent / absent | absent / absent | no temporary enchant | 0 | nil / none observed | normal exit; no C entry | installed, 0 entries; C entries 0 | one nil dispatch; no repeat or later valid target | max depth 1; 0 mismatch/drop/failure | no |
| Log_20 authoritative | absent / absent | absent / absent | active, `8052` | 0 | nil / none observed | yes; no tracked open | installed, 0 entries; C entry yes | original nil + 1 nil repeat; no later valid dispatch | max depth 1; 0 mismatch/drop/failure | yes |
| Log_19 | absent / loaded | absent / absent | active, `8052` | 1, later Zygor | nil / none at failure | yes; no tracked open | installed, 0 entries; C entry yes | original nil + 2 nil repeats; later valid Zygor dispatch | max depth 1; 0 mismatch/drop/failure | yes |
| Log_18 | loaded / loaded | absent / absent | active, `8052` | 2, Chonky then Zygor | table length 1 / Chonky | yes; no tracked open | installed, 0 entries; C entry yes | original valid + 3 nil repeats; later valid Zygor dispatch | max depth 1; 0 mismatch/drop/failure | yes |
| Log_17 | loaded / loaded | absent / absent | active, `8052` | 2, Chonky then Zygor | table length 1 / Chonky | yes by structural timestamps; no tracked open | not installed, so no-entry count is not interpretable; C entry yes | original valid + 3 nil repeats; later valid Zygor dispatch | max depth 1; 0 mismatch/drop/failure | yes |
| Log_16 | loaded / loaded | absent / absent | active, `8052` | 2, Chonky then Zygor | table length 1 / Chonky | not instrumented | not installed; C entry yes | original valid + 2 nil repeats; later valid Zygor prefire | structural probe unavailable; target drops 0 | yes |
| Log_15 | loaded / loaded | absent / absent | active, `8052` | 2, Chonky then Zygor | table length 1 / Chonky | not instrumented | not installed; C entry yes | original valid + 3 nil repeats; later valid Zygor prefire | structural probe unavailable; target drops 0 | yes |

Across Logs_18/19/20, the historical invariants remain the exact line-76 string, active enchant `8052`, valid BugGrabber-off control, C after the tracked normal-exit marker, no tracked dispatch open at C, zero installed-B entries, sampled secure-function `xpcall`, maximum structural depth one, and zero structural mismatch/drop/failure. The controlled changes were Chonky loaded -> absent -> absent, Zygor loaded -> loaded -> absent, target registrations `2 -> 1 -> 0`, failure-adjacent bucket `valid Chonky table -> nil -> nil`, and immediate nil repeats `3 -> 2 -> 1`.

Logs_20–25 hold the complete 165-name runtime inventory equal. Logs_21 and 24 remove temporary-enchant state in two different weapon/character contexts and are clean; Log_22 substitutes runtime enchant `8053` and reproduces the full Log_20 target-specific ordering; Logs_23/25 change character/weapon context and runtime enchant to `5400` and reproduce only the higher-level exact-C-without-B pattern because no corresponding AICO open/normal-exit record for item `246664` was retained. Log_26 removes the profession/economy continuation group to 159 names and reproduces that same higher-level pattern. Counts and associations describe these snapshots and are not causal proof.

### Chonky and Zygor reassessment

Neither Chonky nor Zygor is required for the observed failure in authoritative Log_20's configuration, and neither is an observed direct target callback owner there because no target registration or callback-bearing bucket exists. This supersedes the earlier possibility that Chonky was a required participant and closes the remaining Zygor requirement question for this controlled composition. It does not establish that either addon can never influence timing, cache state, load order, or another composition, and it does not eliminate unrelated third-party environmental effects.

### Line-76 attribution models after Logs_20–26

| Model | Assessment after authoritative Logs_20–26 |
| --- | --- |
| A. Ordinary valid callback failure through visible `xpcall(callback, CallErrorHandler)` | Further weakened for the tracked Logs_20–22 invocations: each had no callback bucket and skipped the body, yet only Logs_20/22 delivered C/error. Harness ordering also differs. Logs_23/25/26 lack the AICO structural record needed to apply that target-specific conclusion; an ordinary callback failure remains possible only for another/untracked occurrence. |
| B. Invalid/nil loop-local callback | Very low and further weakened. Standard `ipairs` cannot yield a nil hole; the tracked Logs_20–22 invocations did not enter the loop; and Logs_21/24 show nil buckets without C/error. Logs_23–26 AICD nil buckets are not loop-local callback evidence. |
| C. Invalid `xpcall` first argument/type | Further weakened for the tracked Logs_20/22 calls because neither reached `xpcall`; malformed harness first arguments delivered B -> C before cleanup. Logs_23/25/26 cannot resolve exact A or whether another path reached `xpcall`. |
| D. Invalid `xpcall` message handler | Weak. Harness cases returned `"error in error handling"` without C, unlike Logs_20/22/23/25/26. Exact live A remains unobserved. |
| E. Direct `CallErrorHandler`/B-body failure | Very low for the installed wrapper path: B was verified active and recorded no entry in all seven controlled runs. Another binding/path is not excluded. |
| F. Direct C inside the tracked `FireCallbacks` body | Contradicted for Log_20 dispatch 849 and Log_22 dispatch 854: each body was skipped and its normal-exit marker preceded C. Not resolved for Logs_23/25/26 because the corresponding structural records were not retained. |
| G. Direct C or equivalent delivery after/outside the tracked visible body/post-hook boundary | Leading observational fit. Logs_20/22 prove C after their tracked normal-exit markers; Logs_23/25/26 prove only C with no tracked dispatch open at entry. Logs_21/24 show later C is not intrinsic to every nil dispatch. This model states measured visibility/order but does not identify a delivery mechanism. |
| H. Separate tightly correlated occurrence carrying a preformatted line-76 string | Plausible and unresolved; matched nil dispatches with different C/error outcomes keep incomplete one-to-one correlation salient. |
| I. Transient exact-A/global binding difference between samples | Runtime-compatible but unverified. Stable snapshots cannot exclude it. |
| J. Untracked/custom AsyncCallbackSystem-like mixin or other source path | Possible but unsupported by a direct runtime record; the tracked standard Item listener alone cannot explain the string. |
| K. Native/runtime behavior absent from the Lua mirror | Compatible but opaque and unproven; it must not be promoted to a Blizzard/native bug claim. |

The synthetic harness remains a comparison, not proof of production behavior: normal callback and malformed-first-argument failures produced B -> C before cleanup/post-hook; invalid handlers produced no C; direct-C-body produced C before cleanup; and direct-C-after produced the broad live shape only by tautologically calling C after completion.

### Log_20 establishes

- Chonky and all Zygor runtime modules were absent while the exact line-76 error reproduced.
- Main-hand item `268203` carried an active temporary enchant with ID `8052`; `remainingMs` transitioned from zero to `7192000` in AICD observations.
- AICO observed zero target registrations and two target prefires, both with nil buckets and no callback owner.
- The failure-adjacent tracked target call opened with a nil bucket, returned normally through the secure `FireCallbacks` post-hook, and was followed `0.034ms` later by C receiving the exact line-76 string.
- No tracked Item/Quest/Spell dispatch remained open at C entry.
- Sampled global B remained AICO's installed wrapper and recorded zero entries; sampled `xpcall` remained a secure function at every retained target boundary.
- The retained structural data had no drops, stack mismatches, or dispatch failures.

### Log_20 does not establish

- It does not prove a Blizzard or native-runtime bug.
- It does not prove that line 76 never executed in another occurrence or path.
- It does not expose exact A at an `xpcall` instruction.
- It does not exclude transient global/binding changes between discrete samples.
- A secure post-hook normal-exit observation does not prove caller-visible completion of every native trampoline or host layer.
- It does not prove that Phoenix Oil, enchant ID `8052`, or the duration transition is the root cause.
- It does not prove that every third-party addon is irrelevant or that Chonky/Zygor can never influence another timing/composition.
- It does not prove that the line-76 string belongs one-to-one to dispatch 849, nor identify the delivery mechanism.

## Completed matched Oil-OFF control: authoritative Log_21

### File identity and valid-control state

| Field | Verified value |
| --- | --- |
| Filename | `Logs_21_BugGrabberChonkyZygorOff_FullNormalProfileOilOFF.txt` |
| Size | `226827` bytes |
| Physical lines | `2634` |
| SHA-256 | `940A37A244DA35467A111CFD5196685C5F4C9B5C6B1959CDAA1B6595FFE6DD32` |

Log_21 reports `loadedAddonCount=165` and `loadedInventoryStatus=ok`. Its complete loaded-addon name inventory is identical to authoritative Log_20's 165-name inventory. This is stronger than equal counts but still establishes only snapshot-time runtime-loaded names, not identical addon configuration, SavedVariables, cache state, execution timing, or native state.

- Chonky and `!BugGrabber` have no observed `ADDON_LOADED` milestone and are absent from the complete inventory. No Zygor folder/module, BugSack, or `!AsyncErrorBoundaryHarness` appears in that inventory.
- AICO is loaded as `!AsyncItemCallbackObserver`. AICD records its own `INIT` and `ADDON_LOADED addon=AsyncItemCallbacksDiagnostic`; RetailUIResearch loaded at AICO time `3189.197739` (`+8.880583s`).
- AICO recorded `PLAYER_LOGIN` at `3202.188786` (`+21.871630s`) and first `PLAYER_ENTERING_WORLD` at `3205.790600` (`+25.473444s`) with `initialLogin=true`, `reloadingUi=false`.
- `bugGrabberOffControlValid=true`, `boundaryProvenanceControlValid=true`, and `directWrapperGlobalActive=true`. The active-handler wrapper remained active at snapshot as `function: 00000190437B79F0`, `equalsWrapper=true`. The direct B wrapper remained active as `function: 0000019044EA2DE0`.
- The target context's last completed addon was `Blizzard_AuctionHouseUI`.
- BetterWardrobe was loaded while BetterWardrobe_SourceData was absent. Baganator/Syndicator, TradeSkillMaster/AppHelper, RaiderIO plus EU F/M/R databases, Altoholic, DataStore, and the same listed DataStore backend modules were loaded in both Logs_20/21.

The integrity counters support treating this as a valid clean control: `target268203Registrations=0`, registration drops `0`, target prefires `1`, prefire drops `0`, target structural records `2`, structural drops `0`, generation-registration evictions `0`, dispatch failures `0`, failure drops `0`, stack mismatches `0`, maximum depth `1`, and current open depth `0`. The active-handler wrapper recorded `0` entries, `0` normal returns, and `0` unmatched entries. B recorded the same `0/0/0`. Boundary records were `2`, with `0` drops and `0` snapshot failures.

### VERIFIED RUNTIME OBSERVATION: Oil OFF

AICD's early `INIT`, `PLAYER_LOGIN`, and `PLAYER_ENTERING_WORLD` reads show `itemID=nil tempEnchant=false`; those pre-resolution observations are not used as Oil-OFF proof. The resolved evidence begins at `BUFFER_RESOLVED`: main-hand slot 16 is item `268203` with `tempEnchant=false`, and off-hand slot 17 is item `272275` with `tempEnchant=false`.

AICD target record `#008` then observes main-hand item `268203`, `tempEnchant=false`, and a nil bucket; `#009 COMPLETE` retains the same main-hand and full equipment state. No `enchantID` or `remainingMs` is reported because the resolved slot is not temporarily enchanted. The Oil-OFF conclusion rests on the explicit resolved `tempEnchant=false` state, not merely missing duration fields or the filename.

### Complete Log_21 target `268203` chronology

No target registration exists, so registration order, owner stack, callback identity, sole-callback identity, bucket generation, and bucket length are all absent rather than unknown retained values. AICD and AICO use different clocks/order scopes, so their records are shown separately.

| Event | Time / elapsed | Order or sequence | Target and boundary state |
| --- | --- | --- | --- |
| AICD PREFIRE `#008` | `t=3215.707` | AICD GetCallbacks order `751` | Item `268203`, `tempEnchant=false`, callback map table, bucket nil, no entry origin. |
| AICD COMPLETE `#009` | `t=3215.707` | AICD record 9 | Event success true; item `268203`, `tempEnchant=false`; bucket still nil. This is event success, not callback-body evidence. |
| AICO GetCallbacks/PREFIRE | `3218.291431` / `+37.974275s` | AICO order `754` | Bucket nil; no callback, owner, identity, generation, or length. Stack confirms visible `FireCallbacks` -> `GetCallbacks`. Last addon `Blizzard_AuctionHouseUI`. |
| AICO DISPATCH_OPEN | `3218.291496` / `+37.974340s` | sequence `855`, target ordinal 1 | Item listener; depth 1; no parent; target ancestor 855; bucket identity/type nil; no registration/callback. Lookup -> open: `0.065ms` (`65us`). |
| AICO DISPATCH_NORMAL_EXIT | `3218.291747` / `+37.974591s` | sequence `855` | Mapped bucket nil; `mappedEqualsRetained=true`; `stackMatch=true`; depth returns to zero. Open -> exit: `0.251ms` (`251us`). |

There is no subsequent target lookup/open, no nil-bucket repeat, no later valid target registration/dispatch, no B entry/return, and no C entry/return. Consequently no normal-exit-to-C, open-to-C, GetCallbacks-to-C, or normal-exit-to-next-target delta exists.

At target open and normal exit, sampled `xpcall` was the same secure function `function: 0000018E8838B668`; sampled B was the same AICO wrapper `function: 0000019044EA2DE0`, with `secure=false`, `taint=!AsyncItemCallbackObserver`, and `equalsInstalledWrapper=true`. The exact observed target order ends at normal exit.

A full-file search found zero exact `attempt to call a nil value` strings, zero `errorType=` or stored `error="` fields, zero active-handler invocation records, zero `ACTIVE_HANDLER_ENTRY` records, and zero B-entry records. The numerous `AsyncCallbackSystem.lua:76` strings elsewhere are ordinary registration-stack frames for other item callbacks, not error records. No observer snapshot/structural failure or record drop suggests that a target C/B event was hidden. Log_21 is therefore a clean Oil-OFF run for this observation window.

### Direct authoritative Log_20 versus Log_21 comparison

| Field | Log_20: Phoenix Oil ON | Log_21: temporary enchant OFF |
| --- | --- | --- |
| File identity | `Logs_20_BugGrabberChonkyZygorOff_FullNormalProfileOilON.txt`; `237141` bytes; `2721` lines; SHA-256 `48B1A4D43886F56D478D9D7288AEB06C9DF7933886828A26BAAF2C023F82E4ED` | `Logs_21_BugGrabberChonkyZygorOff_FullNormalProfileOilOFF.txt`; `226827` bytes; `2634` lines; SHA-256 `940A37A244DA35467A111CFD5196685C5F4C9B5C6B1959CDAA1B6595FFE6DD32` |
| Loaded inventory | 165, status `ok` | 165, status `ok`; names match Log_20 exactly |
| Chonky / Zygor | absent / absent | absent / absent |
| BugGrabber / BugSack / harness | absent / absent / absent | absent / absent / absent |
| AICO / AICD | active / active | active / active |
| Main-hand item | `268203` | `268203` |
| Temporary enchant | true | false, resolved and retained |
| Enchant ID | `8052` | none reported because `tempEnchant=false` |
| Target registrations / prefires | `0 / 2` | `0 / 1` |
| Failure-adjacent or sole bucket | nil | nil |
| First lookup -> open | `0.325ms` | `0.065ms` |
| First open -> normal exit | `0.249ms` | `0.251ms` |
| Normal exit -> C | `0.034ms` | no C entry |
| B entries / C entries | `0 / 1` | `0 / 0` |
| Exact line-76 error | yes | no |
| Nil-bucket repeats | one after C | none |
| Target structural drops / stack mismatches / dispatch failures | `0 / 0 / 0` | `0 / 0 / 0` |
| Maximum depth / snapshot open depth | `1 / 0` | `1 / 0` |
| Last completed addon at target | `Blizzard_AuctionHouseUI` | `Blizzard_AuctionHouseUI` |

The runs are matched as closely as the retained observations establish, not proven identical in every runtime dimension. The complete addon-name inventories and the requested family states match exactly. Material observed differences are temporary-enchant state, target-event count/repeat, timing, C/error outcome, total event/dispatch counts, and session duration. Unobserved SavedVariables, cache state, native state, and nondeterministic ordering remain possible confounders.

### Oil / temporary-enchant interpretation

Within the Chonky/Zygor-off full-profile composition, the first closely matched Oil-OFF control remained clean while the corresponding Phoenix-Oil/enchant-`8052`-ON control reproduced. This materially strengthens temporary-enchant state as an environmental-trigger candidate in this composition.

It does not establish sufficiency: earlier reduced Oil-active runs were clean. It does not establish necessity from one Oil-OFF session. It does not identify whether any association is specific to Phoenix Oil, enchant `8052`, the generic temporary-enchant state, timing/cache consequences of applying an Oil, or another uncontrolled difference. The causal mechanism and root cause remain unknown. Log_21 also shows that a nil `268203` bucket and normal tracked return are not by themselves sufficient for C/error.

### Log_21 establishes

- Resolved main-hand item `268203` had `tempEnchant=false`; off-hand item `272275` was also unenchanted.
- Chonky, Zygor, BugGrabber, BugSack, and the harness were runtime-absent from the complete inventory; AICO/AICD were active and both validity controls passed.
- The loaded-addon name inventory matched Log_20 exactly.
- Target registrations were zero, and the only AICO target prefire/open observed a nil bucket.
- The target dispatch completed through the normal secure post-hook with no structural drop, mismatch, or failure.
- B recorded no entry, C recorded no entry, no exact line-76 error appeared, and the retained observation window was clean.

### Log_21 does not establish

- It does not prove Phoenix Oil or enchant `8052` is causal, defective, or the root cause.
- It does not prove temporary-enchant state is strictly necessary, that all Oil-OFF sessions are clean, or that all Oil-ON sessions fail.
- It does not identify the missing mechanism or prove a Blizzard/native bug.
- It does not eliminate third-party, cache, timing, SavedVariables, or other environmental influence.
- It does not expose exact A at any line-76 instruction or prove that `xpcall` was uninvolved elsewhere.
- It does not prove that Log_20's nil dispatch and C/error belong one-to-one.
- It does not make `remainingMs=0` causal or prove that enchant ID `8052` specifically is responsible.

## Completed Oil of Dawn, matched Shaman, and first reduction runs: authoritative Logs_22–28

### Authoritative file identities

| Capture | Filename | Bytes | Physical lines | SHA-256 |
| --- | --- | ---: | ---: | --- |
| Log_22 | `Logs_22_BugGrabberChonkyZygorOff_FullNormalProfileOilOfDawnON.txt` | `236882` | `2727` | `8A75C7AA3B1846518FF6476AA47CCC03294CA93F61B9C9D29E406D2B7F61BCB2` |
| Log_23 | `Logs_23_BugGrabberChonkyZygorOff_FullNormalProfileShamanBuffON.txt` | `192361` | `2299` | `B3A23824A46F24BEBD1E955DA26954D79154DD18CB7D502904BCC71B937D09CC` |
| Log_24 | `Logs_24_BugGrabberChonkyZygorOff_FullNormalProfileShamanBuffOFF.txt` | `186673` | `2262` | `D37646902EA6FB1A4954E6F0DAAF0C0F11E6734D774ECEC4643D97FE6172E32C` |
| Log_25 | `Logs_25_BugGrabberChonkyZygorOff_FullNormalProfileShamanBuffON_Repeat.txt` | `192833` | `2300` | `A50E372CE8EBAA3354F3D1EE47D481836CE3D30C8A02098CE6281650CE9A33CA` |
| Log_26 | `Logs_26_BugGrabberChonkyZygorOff_FullNormalProfileShamanBuffON_ProfessionEconomyGroupOff.txt` | `191808` | `2289` | `8F886BAA6B30EBC945BDEF9A616D01B7359F1BBB50528952DEBDF4C014BE38A0` |
| Log_27 | `Logs_27_ShamanBuffON_ProfEconOff_QuickCraftsOff.txt` | `216218` | `2456` | `F5BB4EBF68C9476C7385A678D0306C2C23E26EC3B7C188CE5262C62C298B4852` |
| Log_28 | `Logs_28_ShamanBuffON_ProfEconOff_QuickCraftsON.txt` | `191827` | `2288` | `C618EC6AA5CD63A97422E4399426B464BC59CB0768FE06BDA22056792681BE94` |

Together with the authoritative identities already recorded for Logs_20/21, these are the nine canonical latest captures. Logs_27 and 28 are distinct physical files. No previously documented identity changed. The requested Log_25 filename without `_Repeat` is not present in the runtime-log directory; the `_Repeat` file above is the actual capture and its contents verify the intended Shaman/Flametongue-ON repeat. Conclusions use that canonical on-disk identity rather than the requested filename.

### VERIFIED RUNTIME OBSERVATION: exact Log_25 -> Log_26 inventory reduction

Logs_22–25 each report `loadedAddonCount=165` and `loadedInventoryStatus=ok`. Parsing every `LOADED ADDONS` name shows exact set equality across Logs_20–25. Direct comparison of Logs_23/24/25 also shows the same 165 names in the same inventory order and the same 181 observed `ADDON_LOADED` names in the same order.

Log_26 reports `loadedAddonCount=159` and `loadedInventoryStatus=ok`. Its ordered loaded inventory is exactly the Log_25 order after removing these six names, with zero additions and zero other removals:

- `CraftSim`;
- `Journalator`, `Journalator_Display`, `Journalator_OptionsUI`, and `Journalator_Statistics`; and
- `ProfessionShoppingList`.

These are six runtime folders representing three logical families—CraftSim, Journalator, and ProfessionShoppingList—collectively tested as the **profession/economy continuation group**. They are not one family and common causation or ownership is not implied. No dependency, LoadOnDemand, or other side effect changed additional runtime-loaded membership. Runtime-loaded state does not prove the underlying configured enable state.

Log_26's addon-load timeline has 175 names: exactly Log_25's 181-name timeline set minus the same six folders, with no additional missing or new name. Relative load order is not preserved. In Log_25, `Blizzard_ProfessionsTemplates`, `Blizzard_Professions`, `PublicOrdersReagentsColumn`, `Blizzard_ProfessionsBook`, and `TradeSkillMaster` occupied observed positions 61–65 at `+1.887579s` through `+2.097730s`. In Log_26, the first three move to positions 107–109 at `+4.173938s` through `+4.219392s`, while `Blizzard_ProfessionsBook` and `TradeSkillMaster` move to positions 133–134 at `+5.724647s` and `+6.037353s`. This is a measured ordering side effect of the tested composition, not evidence that the moved addons caused or prevented the error.

Across Logs_20–26, ChonkyCharacterSheet, every Zygor folder/module, `!BugGrabber`, BugSack, and `!AsyncErrorBoundaryHarness` are runtime-absent. AICO is runtime-loaded; AICD is active through RetailUIResearch. In Log_26, QuickCrafts remains a separate loaded addon. The SGT family remains loaded under the exact folder names `SGT_Core`, `SGT_CraftCost`, and `SGT_Pricing`; Auctionator and the `TradeSkillMaster`/`TradeSkillMaster_AppHelper` family also remain loaded. BetterWardrobe is loaded while BetterWardrobe_SourceData is absent. Baganator/Syndicator, RaiderIO plus EU F/M/R, and Altoholic/DataStore with the same backend-module names remain loaded. `Blizzard_AuctionHouseUI` is the last completed addon in Log_26's failure-adjacent context.

### Log_22 physical state and complete target chronology

AICD resolves slot 16 to item `268203`, `tempEnchant=true`, runtime `enchantID=8053`, and charges `0`; slot 17 is item `272275`, `tempEnchant=false`. Its first target pair (`#008/#009`, GetCallbacks order `750`) has a nil bucket and `remainingMs=0`; the second (`#010/#011`, order `751`) has a nil bucket and `remainingMs=7188000`. The runtime enchant ID `8053` is therefore independently verified. “Oil of Dawn” and source item `243735` are supplied run/setup identity; they are not inferred from `8053`.

AICO reports target registrations `0`, registration drops `0`, target prefires `2`, and prefire drops `0`. The failure-adjacent chronology is:

| Log_22 AICO event | Absolute / elapsed time | Order / sequence | Verified state and delta |
| --- | --- | --- | --- |
| GetCallbacks/PREFIRE | `6207.761450` / `+37.720349s` | order `753` | Item `268203`; bucket nil; no callback, owner, generation, or length. |
| DISPATCH_OPEN | `6207.761514` / `+37.720412s` | sequence `854` | Depth 1, no parent, bucket nil. Lookup -> open: `0.064ms`. |
| DISPATCH_NORMAL_EXIT | `6207.761762` / `+37.720661s` | sequence `854` | Mapped nil, `mappedEqualsRetained=true`, `stackMatch=true`; depth 0. Open -> exit: `0.249ms`. |
| Active C ENTRY | `6207.761793` / `+37.720692s` | active-handler 1 | Exact line-76 string; no open dispatch; labels `C_WITHOUT_ACTIVE_B,TARGET_NORMAL_EXIT_BEFORE_C`. Exit -> C: `0.031ms`; open -> C: `0.280ms`; lookup -> C: `0.343ms`. |
| Active C RETURN | `6207.762162` / `+37.721061s` | active-handler 1 | Normal return, zero values. C duration: `0.369ms`. |
| Repeat GetCallbacks/PREFIRE | `6207.768745` / `+37.727644s` | order `754` | Item `268203`; bucket nil. C return -> lookup: `6.583ms`. |
| Repeat DISPATCH_OPEN | `6207.768795` / `+37.727693s` | sequence `855` | Bucket nil. Lookup -> open: `0.050ms`; C return -> open: `6.633ms`; original open -> repeat open: `7.281ms`. |
| Repeat DISPATCH_NORMAL_EXIT | `6207.769080` / `+37.727979s` | sequence `855` | Mapped nil, stack match; depth returns to 0. Open -> exit: `0.285ms`; prior exit -> repeat open: `7.032ms`. |

Log_22 records exactly two copies of the error text—the boundary record and invocation record for one active-handler entry—not two failures. Session integrity is `dispatchOpens=2115`, `normalExits=2115`, maximum depth `1`, current depth `0`, stack mismatches `0`, target structural drops `0`, generation evictions `0`, dispatch failures `0`, and failure drops `0`.

### Log_23 physical state and failure-adjacent chronology

AICD resolves main-hand slot 16 to item `246664`, `tempEnchant=true`, runtime `enchantID=5400`, `remainingMs=0`, and charges `0`; off-hand slot 17 is item `246669`, `tempEnchant=false`. Later AICD records show main-hand `remainingMs=3068000`, then `3063986`, with enchant `5400` and charges `0` unchanged. The raw file contains neither `318038` nor a serialized Flametongue/class label. Therefore runtime enchant ID `5400` and the equipment state are raw-log facts; Shaman, Flametongue Weapon, and tooltip SpellID `318038` are supplied run/screenshot context. Tooltip SpellID `318038` is not the runtime enchant ID.

AICD records two `246664` PREFIRE/COMPLETE episodes: `#006/#007` at `t=6737.477`, order `62`, and `#010/#011` at `t=6741.491`, order `796`, `4.014s` later. Both have nil buckets and no entry origins. The second carries the active enchant state nearest the failure. Because AICD and AICO use different clocks and order scopes, it is described as likely the same physical episode, not mechanically joined to AICO's records.

AICO's active C entry is at `6741.566454` (`+29.253369s`) and receives the exact line-76 string. The immediately preceding retained GetCallbacks event is item `246664` at `6741.566127` (`+29.253041s`), order `799`, `0.327ms` before C; it is not target `268203`. The AICO record says `isTarget=false`, so the fixed-target structural retention does not contain its dispatch open/normal exit. The generic recent-dispatch window begins later than C after earlier entries were evicted. Consequently AICO does not prove a nil bucket, normal exit, or secure post-hook-before-C for item `246664`; the nil bucket is proved only by AICD.

At C entry, AICO reports depth `0`, no active dispatch sequence, and an empty stack. The sole boundary label is `C_WITHOUT_ACTIVE_B`; `TARGET_NORMAL_EXIT_BEFORE_C` is absent. C returns normally at `6741.566791` (`+29.253705s`), giving a `0.337ms` handler duration. No retained post-C repeat for `246664` exists. There is no retained `246664` registration; because the generic registration window evicted `415` records and AICD reports only no entry origin, this must not be restated as proven lifetime registrations `0`. Fixed target `268203` has registrations `0` and prefires `0`.

Log_23 records one active-handler entry/return, represented twice textually by boundary and invocation records. Session integrity is `dispatchOpens=1076`, `normalExits=1076`, maximum depth `1`, current depth `0`, stack mismatches `0`, target structural drops `0`, generation evictions `0`, dispatch failures `0`, and failure drops `0`.

### Log_24 physical state and complete retained `246664` activity

AICD resolves main-hand slot 16 to item `246664`, `tempEnchant=false`, and off-hand slot 17 to item `246669`, `tempEnchant=false`. No main-hand runtime enchant ID, duration, or charges are present because the resolved state is unenchanted. This matches Log_23's supplied Shaman and physical weapon identities while toggling the retained main-hand state from active runtime enchant `5400` to no temporary enchant. It does not prove every unobserved character/runtime dimension was identical.

AICD records exactly one retained `246664` episode: `#006 PREFIRE` and `#007 COMPLETE` at `t=8687.348`, GetCallbacks order `62`. The callback map is a table, the `246664` bucket is nil before clear and at completion, entry origins are `none`, both weapons remain unenchanted, and `COMPLETE success=true`. At both records, `xpcall` and `ipairs` are secure functions and global B is AICO's installed insecure/tainted wrapper.

AICO does not retain a `246664` registration, GetCallbacks record, dispatch open, or normal exit. Its generic windows each evicted earlier records (`415` generic registration evictions and `1902` dispatch evictions), and fixed-target retention still covers `268203`/`275218`, not `246664`. Thus the AICD nil bucket is proved, but a target-specific AICO normal-exit chronology and lifetime-zero registration claim are not available. No second `246664` AICD PREFIRE, repeat, B entry, C entry, boundary record, stored error, or exact line-76 string exists.

Log_24's controls pass: `bugGrabberOffControlValid=true`, `boundaryProvenanceControlValid=true`, and `directWrapperGlobalActive=true`. B and C each record `0/0/0` entries/normal returns/unmatched entries. Session totals are `registrations=543`, `getCallbacks=863`, `dispatchOpens=1015`, `normalExits=1015`, maximum depth `1`, current depth `0`, stack mismatches `0`, target structural drops `0`, generation-registration evictions `0`, dispatch failures `0`, failure drops `0`, boundary drops `0`, and boundary snapshot failures `0`.

### Log_25 physical state and failure-adjacent chronology

AICD resolves main-hand slot 16 to item `246664`, `tempEnchant=true`, runtime `enchantID=5400`, `remainingMs=0`, and charges `0`; off-hand slot 17 is item `246669`, `tempEnchant=false`. At the first main-hand PREFIRE/COMPLETE pair (`#006/#007`, `t=11604.241`, order `62`) the main hand remains enchanted with `remainingMs=0`. The intervening off-hand pair (`#008/#009`, order `95`) retains off-hand `tempEnchant=false` and observes main-hand `remainingMs=3567000`. The second main-hand pair (`#010/#011`, `t=11608.227`, order `798`) retains item `246664`, enchant `5400`, `remainingMs=3563014`, charges `0`, and the unenchanted off hand. Both main-hand buckets are nil with entry origins `none`, and both COMPLETE records report event success true. The active state therefore persists across the failure-adjacent episode. The raw file again does not serialize the Shaman class, Flametongue name, or tooltip SpellID `318038`; those are supplied run context, while `5400` is the independently observed runtime enchant ID.

AICO's immediately preceding GetCallbacks observation is item `246664`, order `801`, at `11608.299951` (`+29.023227s`). C enters at `11608.300300` (`+29.023576s`) with the exact line-76 string, a GetCallbacks-to-C delta of `0.349ms`. At C, tracked dispatch depth is `0`, no sequence is active, and the open stack is empty. The sole label is `C_WITHOUT_ACTIVE_B`; C returns normally at `11608.300628` (`+29.023904s`), a `0.328ms` duration. B records zero entries and zero returns. No later retained `246664` repeat exists.

As in Log_23, item `246664` is outside AICO's fixed `268203`/`275218` target retention. No corresponding `246664` AICO registration, DISPATCH_OPEN, DISPATCH_NORMAL_EXIT, retained bucket comparison, or bucket generation survives. The generic windows evicted `415` registration and `2054` dispatch records. AICD proves the nil bucket, but its clock/order scope cannot be mechanically joined to AICO. Log_25 therefore repeats Log_23's higher-level C-without-active-B/no-open-at-C pattern; it does **not** independently re-prove visible target cleanup or secure post-hook before C and does not support `TARGET_NORMAL_EXIT_BEFORE_C`.

### Log_26 physical state and failure-adjacent chronology

AICD resolves main-hand slot 16 to item `246664`, `tempEnchant=true`, runtime `enchantID=5400`, `remainingMs=0`, and charges `0`; off-hand slot 17 is item `246669`, `tempEnchant=false`. The first main-hand PREFIRE/COMPLETE pair (`#006/#007`, `t=15365.175`, order `62`) observes a nil bucket, entry origins `none`, and main-hand `remainingMs=1406000`. The intervening off-hand pair keeps the off hand unenchanted. The second main-hand pair (`#010/#011`, `t=15369.333`, order `803`) again observes a nil bucket and retains enchant `5400`, `remainingMs=1401842`, charges `0`, and the unenchanted off hand. The two main-hand episodes are `4.158s` apart. The active physical state therefore persists through the failure-adjacent episode. The raw log establishes runtime enchant `5400`; Shaman, Flametongue Weapon, and tooltip SpellID `318038` remain supplied run context, with `318038` distinct from `5400`.

AICO's immediately preceding GetCallbacks observation is item `246664`, order `806`, at `15369.401867` (`+29.744543s`). C enters at `15369.402208` (`+29.744884s`) with the exact line-76 string, a GetCallbacks-to-C delta of `0.341ms`. At C, tracked dispatch depth is `0`, no sequence is active, and the open stack is empty. The sole label is `C_WITHOUT_ACTIVE_B`. Sampled `xpcall` is secure function `000001E6117D6668`; sampled global B is AICO's installed wrapper `000001E7C5DACE30`. B records `0/0/0` entries/normal returns/unmatched entries. C records one entry and returns normally at `15369.402540` (`+29.745215s`), a `0.332ms` duration. No later retained `246664` repeat exists.

As in Logs_23/25, item `246664` is outside AICO's fixed targets. No corresponding AICO registration, DISPATCH_OPEN, DISPATCH_NORMAL_EXIT, retained bucket comparison, or generation survives; generic windows evicted `414` registration and `1914` dispatch records. AICD proves the nil bucket, but its clock/order scope cannot be mechanically joined to AICO. Log_26 supports C-without-active-B and no-open-at-C only. It does **not** establish visible target cleanup or secure FireCallbacks post-hook -> C ordering and does not support `TARGET_NORMAL_EXIT_BEFORE_C`.

### Direct matched Log_23 / Log_24 / Log_25 / Log_26 comparison

Logs_23–25 are matched as closely as retained observations establish: same supplied Shaman, same physical weapons, exact same ordered 165-name runtime inventory, exact same ordered 181-name load timeline, and the same valid observer controls. Log_26 retains the same equipment/diagnostics and removes exactly the intended six runtime names to 159, but it also changes relative addon-load timing/order. Unobserved cache/readiness, SavedVariables, native state, and nondeterministic scheduling can still differ.

| Field | Log_23: ON | Log_24: OFF | Log_25: ON repeat | Log_26: ON, group OFF |
| --- | --- | --- | --- | --- |
| Loaded inventory | 165 names, status `ok` | exact ordered 165-name match | exact ordered 165-name match | 159 names; exactly Log_25 minus intended six, no collateral membership change |
| Main / off-hand item | `246664` / `246669` | `246664` / `246669` | `246664` / `246669` | `246664` / `246669` |
| Main / off-hand enchant | true, runtime `5400` / false | false / false; no runtime enchant | true, runtime `5400` / false | true, runtime `5400` / false |
| AICD `246664` episodes | two; orders `62`, `796`; nil bucket | one; order `62`; nil bucket | two; orders `62`, `798`; nil bucket | two; orders `62`, `803`; nil bucket |
| Active-enchant duration | `0`, then `3068000`/`3063986ms` | not applicable | `0`, then `3567000`/`3563014ms` | `0`, then `1406000`/`1401842ms` |
| Retained `246664` owner/generation | none; lifetime-zero not proven | none; lifetime-zero not proven | none; lifetime-zero not proven | none; lifetime-zero not proven |
| AICO `246664` near C | order `799`; lookup -> C `0.327ms` | no C and no retained AICO lookup | order `801`; lookup -> C `0.349ms` | order `806`; lookup -> C `0.341ms` |
| AICO open/normal exit | not retained | not retained | not retained | not retained |
| B entries / C entries | `0 / 1` | `0 / 0` | `0 / 1` | `0 / 1` |
| Exact line-76 result | error | clean | error | error |
| Depth / active sequence at C | `0 / none` | no C | `0 / none` | `0 / none` |
| Boundary label | `C_WITHOUT_ACTIVE_B` | none | `C_WITHOUT_ACTIVE_B` | `C_WITHOUT_ACTIVE_B` |
| Structural drops / mismatches / failures | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` |
| Target structural ordering retained | no | no | no | no |
| RUI / login / PEW elapsed | `8.924746 / 16.617418 / 20.068724s` | `9.033772 / 16.364125 / 19.930094s` | `8.860895 / 16.212960 / 19.805183s` | `5.493684 / 17.001368 / 20.456378s` |
| AuctionHouseUI / snapshot elapsed | `27.392477 / 42.210930s` | `27.856353 / 43.378836s` | `27.067105 / 45.955064s` | `27.784552 / 49.132484s` |
| Registrations / GetCallbacks / dispatches | `543 / 864 / 1076` | `543 / 863 / 1015` | `543 / 864 / 1091` | `542 / 859 / 1021` |

The only calculable AICO item-to-C deltas in the Shaman sequence are the preceding-lookup-to-C intervals (`0.327ms`, `0.349ms`, and `0.341ms`) and C durations (`0.337ms`, `0.328ms`, and `0.332ms`) in Logs_23/25/26. No GetCallbacks-to-open, open-to-exit, exit-to-C, original-dispatch-to-repeat, or C-to-repeat delta can be calculated for `246664` because the corresponding AICO structural records/repeats were not retained. Log_24 likewise has no retained AICO `246664` lookup/open/exit and no C; its clean structural comparison is limited to AICD's nil-bucket PREFIRE/COMPLETE at the same millisecond-resolution timestamp. AICD's two main-hand episodes are `4.014s`, `3.986s`, and `4.158s` apart in Logs_23/25/26; those AICD intervals must not be mixed with AICO's separate clock/order scope.

### Instrumentation-health audit for the Shaman sequence and reduction

All four captures report the Item, Quest, and Spell listeners available with both GetCallbacks and FireCallbacks hooks installed. Both fixed targets (`268203` and `275218`) have zero registration/prefire drops; target structural drops, generation-registration evictions, boundary drops, boundary snapshot failures, stack mismatches, dispatch failures, and failure-retention drops are all zero. Current open depth is zero and maximum depth is one in every run. AICO's inventory status is `ok`; addon-timeline drops are zero. AICD's resolved buffer/registration/prefire summaries report zero evictions, and no diagnostic error or suspicious file truncation was found.

Log_26 specifically reports valid BugGrabber-off and boundary-provenance controls, an active fallback handler wrapper with `1/1/0` entry/normal return/unmatched, an installed and globally verified B wrapper with `0/0/0`, one retained C entry/return, one boundary record with zero drops/failures, `1021` dispatch opens and normal exits, maximum depth one, final depth zero, and zero mismatches or dispatch failures. Its bounded generic windows evicted `414` registration and `1914` dispatch records. That expected capacity behavior prevents a retained `246664` AICO open/exit or lifetime-registration-zero claim, but it does not weaken the physical state, C/B counts, no-open-at-C snapshot, exact inventory reduction, or validity controls. The Log_25 -> Log_26 comparison is technically valid subject to this explicit structural-retention limit.

### B/C boundary comparison for Logs_20–26

| Field | Log_20 | Log_21 | Log_22 | Log_23 | Log_24 | Log_25 | Log_26 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `bugGrabberOffControlValid` | true | true | true | true | true | true | true |
| `boundaryProvenanceControlValid` | true | true | true | true | true | true | true |
| `directWrapperGlobalActive` | true | true | true | true | true | true | true |
| B entries / normal returns / unmatched | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` |
| C entries / normal returns / unmatched | `1 / 1 / 0` | `0 / 0 / 0` | `1 / 1 / 0` | `1 / 1 / 0` | `0 / 0 / 0` | `1 / 1 / 0` | `1 / 1 / 0` |
| Active handler at snapshot | `00000205C7EE0990` | `00000190437B79F0` | `00000194CB5BBEF0` | `0000021248D98A40` | `000001AEC87199D0` | `0000019AC6F9DAF0` | `000001E7C643EAE0` |
| Relevant `xpcall` snapshot | secure `0000020428275668` | secure `0000018E8838B668` | secure `00000193422F3668` | secure `00000210AA6D16A8` | secure function at AICD `246664` boundary; no AICO target/C identity retained | secure `000001993F2BD668` at C | secure `000001E6117D6668` at C |
| Relevant B snapshot | installed AICO `00000205C78A3020` | installed AICO `0000019044EA2DE0` | installed AICO `00000194C9617EF0` | installed AICO `0000021248794E10` | installed AICO `000001AEBB2C8DA0` | installed AICO `0000019AC74CFCD0` | installed AICO `000001E7C5DACE30` |
| Open depth / active sequence at C | `0 / none` | no C | `0 / none` | `0 / none` | no C | `0 / none` | `0 / none` |
| Boundary labels | `C_WITHOUT_ACTIVE_B,TARGET_NORMAL_EXIT_BEFORE_C` | none | `C_WITHOUT_ACTIVE_B,TARGET_NORMAL_EXIT_BEFORE_C` | `C_WITHOUT_ACTIVE_B` only | none | `C_WITHOUT_ACTIVE_B` only | `C_WITHOUT_ACTIVE_B` only |
| Structural drops / mismatches / failures | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` | `0 / 0 / 0` |
| Boundary records / drops / snapshot failures | `5 / 0 / 0` | `2 / 0 / 0` | `5 / 0 / 0` | `1 / 0 / 0` | `0 / 0 / 0` | `1 / 0 / 0` | `1 / 0 / 0` |

These are sampled identities and observer counts. They establish that the installed global B wrapper was active at sampled boundaries but did not record entry before C. They do not reveal exact A at line 76, prove B was bypassed by native code, prove `xpcall` was uninvolved, or make one-to-one attribution between C and a particular source invocation.

### Seven-run temporary-enchant and first cofactor-reduction matrix

| Log | Main hand | Mechanism | Runtime enchant | Result | Relevant target/near-C item | B/C entries | Nil bucket | Secure exit before C | Runtime inventory |
| --- | ---: | --- | ---: | --- | ---: | --- | --- | --- | --- |
| 20 | `268203` | Phoenix Oil | `8052` | error | `268203` | `0/1` | AICD+AICO | yes | 165-name baseline |
| 21 | `268203` | none | none | clean | `268203`; no C | `0/0` | AICD+AICO | normal exit; no C | exact match |
| 22 | `268203` | Oil of Dawn | `8053` | error | `268203` | `0/1` | AICD+AICO | yes | exact match |
| 23 | `246664` | Flametongue context | `5400` | error | preceding lookup `246664` | `0/1` | AICD; AICO bucket not retained | not retained | exact match |
| 24 | `246664` | none | none | clean | no C; AICD `246664` | `0/0` | AICD; AICO bucket not retained | not retained; no C | exact match |
| 25 | `246664` | Flametongue context repeat | `5400` | error | preceding lookup `246664` | `0/1` | AICD; AICO bucket not retained | not retained | exact ordered match |
| 26 | `246664` | Flametongue context; profession/economy continuation group OFF | `5400` | error | preceding lookup `246664` | `0/1` | AICD; AICO bucket not retained | not retained | 159; exact Log_25 minus intended six |

### Interpretation after the matched Shaman ON/OFF/ON sequence

Logs_21–26 substantially weaken Phoenix Oil-, enchant-`8052`-, Oil-family-, and item-`268203`-specific explanations. The matrix contains two observed ON/OFF comparisons: Phoenix Oil Log_20 errors while matched no-enchant Log_21 is clean; Flametongue-context Log_23 errors while the same-Shaman, same-weapons, no-enchant Log_24 is clean. Log_22 supplies a second Oil and runtime enchant `8053` reproduction. Log_25 restores the same Shaman's runtime enchant `5400` and reproduces, completing ON -> ERROR / OFF -> CLEAN / ON -> ERROR. Log_26 then preserves that physical state, removes the six-folder profession/economy continuation group, and reproduces again.

The strongest supported description remains: **within the tested full-profile and first full-profile-derived Shaman configurations, Flametongue/temporary-enchant ON is a repeatable reproduction condition**. Across the broader matrix, active temporary weapon-enchant/imbue state is a strong cross-mechanism environmental correlate. This is not a causal mechanism or root-cause finding. Earlier reduced profiles that were Oil-active and clean disprove global sufficiency. Two clean no-enchant controls do not prove global necessity or show that every Oil/imbue reproduces. Log_26 separately establishes that the profession/economy continuation group is not required as a group under the tested configuration; it does not independently exonerate CraftSim, Journalator, or ProfessionShoppingList.

### Startup/load/runtime cofactor assessment

H7 remains moderate and important rather than proven. The exact 165-name inventory is held constant across Logs_20–25, while Log_26 reproduces after a coherent reduction to 159 names. Earlier reduced Oil-active runs were clean, which supports an interaction with something present in or produced by a still-broader environment than those reductions. Log_26 rules out one six-folder group as collectively required but does not isolate heavy composition, callback volume, item-data or cache readiness, native scheduling, synchronous event timing, addon work after PEW, or a particular ordering relationship.

Total wall-clock load duration is not a demonstrated threshold: Log_23 errors with a `42.210930s` snapshot, Log_24 is clean at `43.378836s`, Log_25 errors at `45.955064s`, and Log_26 errors at `49.132484s`. Dispatch totals (`1076`, `1015`, `1091`, and `1021`) likewise do not establish a threshold. Log_26 moves RetailUIResearch earlier while delaying several professions/TSM milestones, yet still reproduces; this shows startup ordering can change without eliminating the occurrence, not that a specific ordering is causal. `Blizzard_AuctionHouseUI` remains a nearby milestone, not an identified cause. “Slow loading causes the error” is unsupported. The evidence supports only a full-profile-derived runtime cofactor involving some unresolved composition/scheduling/readiness relationship.

### Reassessment of item `268203`

Item `268203` is no longer required for reproduction: Log_23 has no `268203` prefire or registration, uses main-hand item `246664`, and the immediately preceding AICO GetCallbacks event near C is `246664`. Its earlier prominence may reflect its role as the test weapon carrying the temporary enchant. This does not make `268203` irrelevant to historical captures or prove the item had no effect there.

Future experiments should therefore center the **currently equipped temporarily enchanted main-hand item**, with explicit item identity recorded per character, rather than hard-code `268203` as the universal target. Instrumentation's fixed `268203` retention also explains why Log_23 lacks the target-specific structural chronology and must not be over-unified with Logs_20/22.

### Conditions no longer required by Logs_19–26

The observed occurrence does not require Chonky, Zygor, BugGrabber, BugSack, item `268203`, Phoenix Oil specifically, enchant `8052` specifically, the consumable-Oil mechanism class, a nil-bucket repeat, an observed direct target registration, or the six-folder profession/economy continuation group as a group. This conclusion is limited to requirement for reproduction in the tested captures; it does not independently exonerate each group member or prove any component is universally irrelevant or incapable of indirect timing/composition influence.

### Logs_20–26 evidence ceiling

- Logs_20–25 have exactly equal 165-name loaded inventories; Log_26 is the exact ordered Log_25 inventory minus the intended six names, with no collateral membership difference.
- Two different physical main-hand items, three runtime enchant IDs, two mechanism classes, and two clean no-enchant controls are represented.
- Phoenix Oil/`8052`, Oil of Dawn/`8053`, and all three Flametongue-context `5400` runs reproduce; Logs_21/24 are clean without temporary enchants.
- Chonky, all Zygor modules, BugGrabber, BugSack, and the harness are not runtime-required in this tested composition.
- Each failure capture has one C entry/return with zero observed entries through the installed B wrapper; no tracked dispatch is open at C.
- Logs_20/22 specifically have nil target buckets and normal secure post-hook exits immediately before C. Logs_23/25/26 match only the higher-level C-without-active-B pattern because their corresponding `246664` structural dispatch records were not retained.
- Temporary weapon-enchant/imbue state is a repeatable reproduction condition in the tested full-profile-derived Shaman environment and a strong cross-mechanism correlate across the larger matrix.
- The profession/economy continuation group is not required as a group under the tested configuration; individual member necessity was not tested.

The same evidence does not establish:

- temporary-enchant state as causal, globally necessary, or sufficient;
- that every Oil or class imbue reproduces, or that a no-enchant run can never fail;
- that enchant IDs `8052`, `8053`, or `5400`, or item IDs `268203` or `246664`, are defective;
- a specific addon family, slow loading, callback volume, cache state, scheduling behavior, or other broader full-profile/runtime cofactor;
- a Blizzard/native bug, exact A at line 76, native bypass of B, exclusion of `xpcall`, or that line 76 never executed elsewhere; or
- one-to-one ownership between each C entry and the immediately preceding observed lookup/dispatch.

## Completed Logs_26–28 QuickCrafts ABA reduction branch

Log_26 is a valid positive reduction. It preserves the Log_25 Shaman/Flametongue physical condition, removes exactly the intended six runtime folders, and reproduces the exact line-76 occurrence with healthy boundary controls. The profession/economy continuation group is not required as a group for reproduction under the tested configuration. Logs_27 and 28 complete the planned QuickCrafts OFF/ON branch from this 159-name failing parent.

### Historical reduction frontier

All captures below were Oil/temp-enchant active and clean for the exact line-76 occurrence. Runtime-folder counts are physical loaded names, not logical-addon counts.

| Capture | Runtime folders | Relevant reduction result |
| --- | ---: | --- |
| Light Log_05 | 5 | Absolute smallest clean active-enchant profile. It is not close to the current full composition. |
| Log_05 `45AddonsEnabled` | 36 | Closest clean active-enchant inventory by observed name overlap: 34 names overlap Log_25; Chonky and Zygor are its two clean-only names, while 131 Log_25 names are absent. |
| Log_06 | 17 | Combined item/transmog/auction subset clean. |
| Log_07 | 10 | Auctionator + Baganator/Syndicator + TSM/AppHelper subset clean. |
| Logs_08/09 | 12 / 13 | Item/transmog group clean; adding Auctionator remained clean. |
| Logs_10/12/13 | 15 each | Exact same 15-name inventories remained line-76 clean while historical State A/State B callback behavior varied; inventory membership alone did not determine that state. |
| Log_11 | 17 | TSM/AppHelper add-back to the 15-name base remained line-76 clean; historical State B behavior occurred within the Log_11–13 series. |
| Log_14 | 19 | Raider.IO plus its EU M/R/F database folders added to the 15-name base remained line-76 clean. |

These runs weaken Auctionator, the Baganator/Syndicator family, TSM/AppHelper, Raider.IO, the reduced item/transmog set, and the Altoholic/DataStore set as individually or collectively sufficient explanations. Separate full-profile failures already show that OUS, Chonky, Zygor, BugGrabber, and BugSack are not required. They do not prove that any of these families is incapable of contributing to an emergent full-profile timing/composition state.

A blind binary split of the remaining environment is not the first choice: a broad removal could destroy the composition/readiness condition under test, and a clean result would poorly distinguish a particular family from a pressure or ordering effect. Log_26 already supplies a valid six-folder reduction, so Log_27 should remove only `QuickCrafts`.

### Why QuickCrafts is the strongest bounded Log_27 candidate

QuickCrafts is one standalone runtime folder and remained enabled intentionally in Log_26. Its installed TOC declares Auctionator as a dependency. `Core.lua:68-78` schedules `LoadAllItemInfo` two seconds after `PLAYER_ENTERING_WORLD`; `PriceSource.lua:183-216` loops its item IDs and calls `ContinueOnItemLoad`, while `PriceSource.lua:138-142` consumes Auctionator's API. Runtime evidence is stronger than source possibility alone: Logs_25 and 26 each retain exactly `106` consecutive QuickCrafts `ContinueOnItemLoad` registrations over `106` unique item IDs. They occupy AICO registration orders `416-521` in Log_25 and `415-520` in Log_26, spanning `7.327ms` and `7.267ms`. In Log_26, the burst ends `2265.097ms` before C receives the line-76 string.

This is callback-volume and timing correlation, not callback ownership or causal evidence for item `246664`. Removing QuickCrafts also removes its Auctionator-consuming calls, so a clean result could reflect its item-continuation burst, its pricing-consumer interaction, or an indirect timing/readiness change. Auctionator itself remains enabled and available as a provider. The SGT price-consumer family remains enabled under its exact three runtime folders—`SGT_Core`, `SGT_CraftCost`, and `SGT_Pricing`—as do the TSM provider family (`TradeSkillMaster` and `TradeSkillMaster_AppHelper`). No literal `ContinueOnItemLoad` callsite was found in the installed SGT source. Other remaining source candidates have callsites, but QuickCrafts is clearly preferable here because it removes only one folder and has a large, directly observed Log_26 registration burst rather than source potential alone.

### Historical Log_27 plan — completed

- **Recommended capture name:** `Logs_27_BugGrabberChonkyZygorOff_FullNormalProfileShamanBuffON_ProfessionEconomyGroupOff_QuickCraftsOff.txt`.
- **Additional folder disabled:** `QuickCrafts` only. Keep the Log_26 profession/economy continuation group disabled: `CraftSim`; `Journalator`, `Journalator_Display`, `Journalator_OptionsUI`, and `Journalator_Statistics`; and `ProfessionShoppingList`.
- **Required enabled relationships:** retain Auctionator; `TradeSkillMaster` and `TradeSkillMaster_AppHelper`; and all of `SGT_Core`, `SGT_CraftCost`, and `SGT_Pricing`. Retain every other Log_26 runtime-loaded name. This preserves both pricing-provider families and the SGT consumer while directly removing only the QuickCrafts consumer and its own calls.
- **Expected runtime inventory:** `158` loaded names only if exactly `QuickCrafts` disappears from Log_26's 159-name inventory. Treat that count as a prediction. Reject or explain any other removal, addition, or order-sensitive dependency/LoadOnDemand side effect before interpreting the result.
- **Character/equipment:** the same Shaman, main-hand slot 16 item `246664`, and off-hand slot 17 item `246669` used in Logs_23-26.
- **Physical state:** Flametongue Weapon ON. Accept only if AICD resolves main hand `tempEnchant=true`, runtime enchant `5400`, and a coherent positive remaining-duration observation through the relevant `246664` episode, with off hand `tempEnchant=false`. Tooltip SpellID `318038` remains supplied spell context, not the runtime enchant ID.
- **Diagnostics and fixed absences:** AICO and RetailUIResearch/AICD active; valid BugGrabber-off and boundary-provenance controls; active fallback-handler wrapper and globally verified direct `CallErrorHandler` wrapper; healthy B/C entry/return matching, boundary retention, dispatch counters, final depth, mismatch, and failure counters. Keep BugGrabber, BugSack, Chonky, every Zygor folder, and `!AsyncErrorBoundaryHarness` absent. Use the same fresh-client startup and observation procedure, with no deliberate delay or cache-policy change.
- **ERROR:** if the exact line-76 string reaches C after all controls pass, QuickCrafts is not required in that run. This would not prove that QuickCrafts has no indirect influence, exonerate Auctionator/TSM/SGT, or identify a cause; keep QuickCrafts off for the next bounded reduction.
- **CLEAN:** a single clean branch is evidence that removing QuickCrafts or its consumer activity may have changed the reproduction condition, not proof of direct cause. Restore QuickCrafts while keeping the Log_26 six-folder group off, reproduce a flanking Log_26-like parent, and then repeat QuickCrafts OFF. Because removal also eliminates QuickCrafts' Auctionator-consuming calls, even a repeated clean result would require follow-up to distinguish item-callback volume from provider/consumer interaction.
- **INCONCLUSIVE:** wrong/missing enchant or equipment, an unplanned inventory difference, invalid control/wrapper/hook state, boundary or structural drops/mismatches that weaken absence evidence, suspicious truncation, or no accepted `246664` AICD episode. Repeat the exact Log_27 plan without changing another variable.

The actual Log_27 capture used the shorter filename `Logs_27_ShamanBuffON_ProfEconOff_QuickCraftsOff.txt`. It changed one coherent runtime variable and preserved `158/159` observed parent names. Log_28 then restored QuickCrafts under `Logs_28_ShamanBuffON_ProfEconOff_QuickCraftsON.txt`.

### VERIFIED RUNTIME OBSERVATION: exact Log_26 -> Log_27 -> Log_28 ABA branch

| Field | Log_26: QuickCrafts ON | Log_27: QuickCrafts OFF | Log_28: QuickCrafts ON restored |
| --- | --- | --- | --- |
| Runtime inventory | 159, status `ok` | 158, exactly Log_26 minus `QuickCrafts` | 159, exact ordered match to Log_26 |
| Addon-load timeline | 175 names | 174, exact Log_26 order projected without `QuickCrafts` | exact 175-name order match to Log_26 |
| Main / off-hand | `246664` / `246669` | same | same |
| Main / off-hand enchant | true, runtime `5400` / false | true, runtime `5400` / false | true, runtime `5400` / false |
| Exact line-76 result | ERROR | CLEAN | ERROR |
| B entries / C entries | `0 / 1` | `0 / 0` | `0 / 1` |
| `246664` AICD bucket | nil | nil | nil |
| Retained `246664` AICO structural open/exit | no | no | no |
| Valid BugGrabber-off / boundary controls | yes / yes | yes / yes | yes / yes |

The runtime-loaded membership branch is exact. Log_27 removes only QuickCrafts from Log_26. Log_28 adds only QuickCrafts back and restores both the complete inventory order and complete `ADDON_LOADED` timeline order. Configuration choices are the experiment setup; the serialized runtime inventory is the evidence of what actually loaded. Timing differs between runs even though projected ordering does not.

Log_27 is clean by direct raw evidence: the exact line-76 string occurs zero times, B and C each record zero entries, boundary records are zero, and all three Item/Quest/Spell listener hooks report installed. Its controls pass; `945` dispatch opens equal `945` normal exits, final depth is zero, maximum depth one, and mismatch/drop/failure counters are zero. AICD resolves main-hand `246664` with `tempEnchant=true`, runtime enchant `5400`, and off-hand `246669` unenchanted. It first observes `remainingMs=0`, then observes the main hand at `3592000ms` during the off-hand episode. Active enchant `5400` in this clean run proves again that temporary-enchant state alone is not sufficient.

Log_28 reproduces the exact error. AICD resolves the same equipment, first with runtime enchant `5400` and `remainingMs=0`, then at the first `246664` episode with `3257000ms`, and at the second with `3252699ms`; both `246664` buckets are nil and the enchant remains active. AICO's nearest preceding GetCallbacks is item `246664`, order `806`, at `3303.999817` (`+29.129375s`). C receives the exact line-76 string at `3304.000207` (`+29.129765s`), `0.390ms` later, and returns normally at `3304.000540`, a `0.333ms` duration. At C the tracked depth is zero, no dispatch sequence is active, and the stack is empty. Sampled `xpcall` is secure function `0000022AE26D1678`; sampled global B is the installed AICO wrapper `0000022C3A6DCCB0`. B records `0/0/0`; C records `1/1/0`; the sole boundary label is `C_WITHOUT_ACTIVE_B`.

Log_28 reports `1061` opens and normal exits, maximum depth one, final depth zero, and zero structural mismatch/drop/failure counters. Its `414` generic-registration and `1994` dispatch evictions mean absence from the generic windows is not lifetime-absence evidence. No `246664` AICO structural open/normal exit survives, so Log_28 does **not** establish secure FireCallbacks post-hook -> C ordering or support `TARGET_NORMAL_EXIT_BEFORE_C`.

### VERIFIED SOURCE: QuickCrafts purpose and initialization

The reference copy is QuickCrafts `0.0.4`. Its TOC describes a crafting-profit calculator using Auctionator prices, declares Auctionator as a required dependency, and loads recipe, housing-pigment, and dye data before `PriceSource.lua`, calculators, UI, and finally `Core.lua` (`QuickCrafts.toc:1-45`). It contains no TSM integration.

QuickCrafts has two source-visible item-load passes during an initial login:

1. On its own `ADDON_LOADED`, `Core.lua:43-48` initializes SavedVariables and immediately calls `PriceSource:LoadAllItemInfo()`.
2. On `PLAYER_ENTERING_WORLD`, `Core.lua:68-78` schedules a two-second timer. When that timer actually runs, it registers for Auctionator price updates and calls `LoadAllItemInfo` again. After every per-item completion callback has run, it schedules `CalculateAllRecipes()` after another `0.5s`.

`Core.lua` does not unregister its `PLAYER_ENTERING_WORLD` handler, so later PEW events can schedule additional passes. A separate one-shot PEW timer in `UI/PigmentsView.lua:370-379` initializes pigment rows after `2.5s`; it does not call `LoadAllItemInfo`.

The final `GetAllItemIDs` implementation is the override loaded from `Dyes.lua`. It builds a set from every recipe product/material, pigment/herb, and dye. The data files contain 229 item-ID occurrences but the set has exactly **165 unique IDs**; 58 IDs appear more than once in the source data and are deduplicated. Item `246664` is not in the set. Iteration uses `pairs(itemIDs)`, so source does not guarantee a file/data-order traversal even though Logs_26/28 retain an identical observed tail sequence.

For each set member, `PriceSource.lua:183-216` constructs `Item:CreateFromItemID(itemID)` and passes an anonymous function to `ContinueOnItemLoad`. The callback calls `C_Item.GetItemInfo(itemID)`, stores the returned link/name/icon in three addon tables, then invokes the supplied per-item completion function if one exists. Each closure captures its invocation's `itemID` and callback; the batch closures share `loadedCount`, `totalCount`, and the optional all-complete callback. The body does not query pricing, register another item, recurse, or call `ContinueOnItemLoad` again. It uses the non-cancelable continuation API and has no QuickCrafts `pcall`/`xpcall` around its own body. The callback values passed at both callsites are visibly functions; Retail `ValidateForContinueOnItemLoad` also rejects non-functions before `AddCallback`. No source-visible QuickCrafts path writes nil or a number into Blizzard's callback array.

Each `LoadAllItemInfo` invocation is one synchronous Lua `pairs` loop with no explicit timer or yield inside the loop, although the Blizzard accessor can complete item work synchronously during `AddCallback`. Each of the 165 IDs is requested once per pass. The same ID is therefore submitted once during ADDON_LOADED and again during the delayed PEW pass, and can be submitted again after later PEW events because Core does not unregister that event. Traversal order remains unspecified by source because it uses `pairs`.

### VERIFIED SOURCE: Auctionator provider relationship

Auctionator is a separate required dependency and price provider. The dependency declaration makes the client load Auctionator before QuickCrafts; QuickCrafts nevertheless guards the provider table and individual APIs before every use, so an absent/unready API is handled as unavailable. `GetPrice` uses `Auctionator.API.v1.GetAuctionPriceByItemLink` inside `pcall`; recipe and item searches use `MultiSearchExact` inside `pcall` and require the Auction House UI to be open; `RegisterForPriceUpdates` registers an Auctionator database-update callback inside `pcall`. That provider callback recalculates recipes and pigments and refreshes an open QuickCrafts UI.

Auctionator price lookup does **not** occur inside the `ContinueOnItemLoad` callback. The immediate ADDON_LOADED pass only populates QuickCrafts' item metadata. In the delayed PEW branch, Auctionator update registration happens before the second item pass; price calculation begins only after all per-item completions and the additional `0.5s` timer. `GetPrice` may fall back to synchronous `C_Item.GetItemInfo` when metadata is absent, but no Auctionator event or QuickCrafts price function calls `LoadItemInfo` or creates another continuation. Auctionator's own internal behavior is outside this source audit, so provider interaction remains a possible indirect cofactor rather than a demonstrated item-load source.

### VERIFIED SOURCE: operations QuickCrafts does not perform

An exact source-tree search finds no item `246664`; equipped-weapon, inventory-slot, temporary-enchantment, or weapon-enchant API; `AsyncCallbackSystem`, `ItemEventListener`, or direct `C_Item.RequestLoadItemDataByID` reference; replacement/hook of `Item:ContinueOnItemLoad`; `CallErrorHandler`, `geterrorhandler`, `seterrorhandler`, `xpcall`, or secure-global manipulation. Its only `ContinueOnItemLoad` callsite passes an anonymous function. QuickCrafts therefore has no source-visible direct ownership of the equipped-weapon dispatch, no visible bad callback construction, and no concrete malformed callback-bucket behavior.

### VERIFIED RUNTIME OBSERVATION: retained QuickCrafts continuation tail

The generic registration window retains only the last 128 entries, so it does not retain the full 165-ID pass. The QuickCrafts rows below are the exact retained tail, not the complete batch:

| Field | Log_26 | Log_28 |
| --- | ---: | ---: |
| First / last retained order | `415 / 520` | `415 / 520` |
| Retained registrations / unique IDs | `106 / 106` | `106 / 106` |
| First / last time | `15367.129844 / 15367.137111` | `3301.592820 / 3301.600055` |
| First / last observer elapsed | `+27.472520 / +27.479786s` | `+26.722378 / +26.729612s` |
| Retained-tail duration | `7.267ms` | `7.235ms` |
| Tail end -> C | `2265.097ms` | `2400.152ms` |
| Consecutive / interleaved registrations | yes / none | yes / none |
| Bucket nil after return | 33 | 33 |
| Retained index 2 / index 3 | `70 / 3` | `70 / 3` |

Both tails have the exact same item-ID sequence. Callback address strings differ, as expected for separate client processes, while type and source stack agree. The exact stack is `Item.lua:332 ContinueOnItemLoad -> QuickCrafts/PriceSource.lua:185 LoadItemInfo -> PriceSource.lua:210 LoadAllItemInfo -> Core.lua:73` inside the PEW timer callback. Index 2/3 means another callback entry already occupied the bucket when QuickCrafts appended its valid function; it is not a nil/number callback observation.

Source proves 165 unique requests per pass. Runtime totals align closely with that model: QuickCrafts-enabled Logs_26/28 each have `330` more registrations than disabled Log_27, and AICD's bootstrap snapshot has `165` more startup callback entries (`252` versus `87`). This is strong cross-evidence for the immediate and delayed 165-request passes, but the bounded AICO window directly retains only the 106-entry second-pass tail and must not be described as a complete 106-item batch.

### DESCRIPTIVE workload and timing comparison

| Field | Log_26 ON/error | Log_27 OFF/clean | Log_28 ON/error |
| --- | ---: | ---: | ---: |
| Registrations | 542 | 212 | 542 |
| GetCallbacks | 859 | 723 | 859 |
| Dispatch opens / normal exits | `1021 / 1021` | `945 / 945` | `1061 / 1061` |
| Generic registration evictions | 414 | 84 | 414 |
| AICD startup entries | 252 | 87 | 252 |
| Retained QuickCrafts registrations | 106 | 0 | 106 |
| `246664` AICD episodes | 2 | 1 | 2 |
| Target structural retained / boundary records | `1 / 1` | `0 / 0` | `1 / 1` |
| Login elapsed | `17.001368s` | `16.392768s` | `16.290941s` |
| PEW elapsed | `20.456378s` | `19.795966s` | `19.650840s` |
| PlayerChoice elapsed | `25.594244s` | `24.928025s` | `24.831032s` |
| AuctionHouseUI elapsed | `27.784552s` | `26.900343s` | `27.011505s` |
| Snapshot elapsed | `49.132484s` | `42.670870s` | `40.811936s` |

The QuickCrafts-enabled runs have identical total registration/GetCallbacks counts but different dispatch totals and snapshot durations. Log_27's retained registration window includes more later producers because the QuickCrafts tail is absent; its largest visible groups are OUS and TitanCurrenciesMulti, whereas Logs_26/28's retained window is dominated by QuickCrafts. These capacity effects do not establish that those other producers changed activity. Aggregate callback pressure alone is not supported as a cause: clean and failing historical captures already overlap in broad counts, and the same enabled composition still shows run-to-run dispatch/timing variation.

### Log_28 QuickCrafts-to-failure timeline

| Event | Observer elapsed | Relation |
| --- | ---: | --- |
| QuickCrafts `ADDON_LOADED` | `+4.547700s` | Immediate 165-ID source pass occurs here; full AICO rows later evicted. |
| Player login | `+16.290941s` | — |
| PEW | `+19.650840s` | Schedules the two-second QuickCrafts timer. |
| First AICD `246664` episode | approximately `+24.734s` | Nil bucket; enchant `5400`, `3257000ms`. |
| Blizzard_PlayerChoice | `+24.831032s` | Last completed addon during the retained QuickCrafts tail. |
| Retained QuickCrafts tail | `+26.722378` to `+26.729612s` | Starts `7.072s` after PEW; source timer is a minimum delay, not an exact schedule. |
| Blizzard_AuctionHouseUI | `+27.011505s` | `281.892ms` after the retained tail ends. |
| Second AICD `246664` episode | approximately `+29.035s` | Nil bucket; enchant remains `5400`, `3252699ms`. |
| AICO GetCallbacks `246664` | `+29.129375s` | Nearest retained lookup before C. |
| Active handler C | `+29.129765s` | `0.390ms` after lookup; `2.400s` after retained tail end. |
| Snapshot | `+40.811936s` | — |

The retained QuickCrafts registration tail does not overlap the failure-adjacent `246664` episode; it ends materially earlier. Thirty-three retained registrations had already cleared their bucket before the AddCallback post-hook returned, while 73 were at index 2/3 at that instant. Because later generic dispatch history was evicted and there is no callback-map snapshot at C, the logs cannot prove whether any QuickCrafts callbacks remained pending near the failure. None of the 165 source IDs—and none of the 106 retained runtime IDs—is `246664`. There is no QuickCrafts registration, stack, or source path that directly owns the failure-adjacent equipped-weapon dispatch.

### QuickCrafts confidence-tier conclusion

**Source-proven:** QuickCrafts makes two initial-login passes over 165 unique recipe/pigment/dye item IDs, passes valid functions to `ContinueOnItemLoad`, stores item metadata in those callbacks, and queries Auctionator only in later pricing/search/calculation paths. It neither requests `246664` nor touches equipment/enchant/error-handler/callback-system internals.

**Runtime-observed:** With the same reduced profile and enchant `5400`, Logs_26/28 are QuickCrafts-ON errors and Log_27 is a QuickCrafts-OFF clean run. Membership and projected load order differ only by QuickCrafts. Enabled runs retain identical 106-entry second-pass tails and matching aggregate registration/GetCallbacks counts. Log_28 reaches C without B or an open tracked dispatch; Log_27 has neither B nor C.

**Strong inference:** QuickCrafts is an observed selector/reproduction condition **so far in this tested reduced ABA branch**. Its two large item-load passes are a plausible workload/readiness/scheduling cofactor. Its Auctionator dependency and later provider interaction are also possible indirect cofactors, as is interaction with another retained addon. The ABA pattern makes mere coincidence less likely than a single pair would, but one OFF capture does not establish reproducibility of the clean branch or causality.

**Unsupported/speculative:** QuickCrafts is not shown to be defective, sufficient, globally necessary, the direct line-76 source, a bad-callback producer, or the owner of item `246664`. Auctionator is not shown to cause the error. Generic callback volume is not shown to be sufficient. No concrete malformed behavior exists in the inspected QuickCrafts source.

### Next controlled experiment: Log_29 — repeat QuickCrafts OFF

The single most discriminating next step is an unchanged repeat of Log_27 before adding source instrumentation. The present ABA sequence has two ON/error captures but only one OFF/clean capture; repeating OFF directly tests whether QuickCrafts state is a reproducible selector or whether the clean result can occur nondeterministically in the same 158-name branch. A source-level suppression/timing experiment would be premature if the OFF result itself is not reproducible.

- **Recommended filename:** `Logs_29_ShamanBuffON_ProfEconOff_QuickCraftsOff_Repeat.txt`.
- **State:** preserve the Log_27 configuration exactly: profession/economy continuation group OFF, QuickCrafts OFF, Auctionator/TSM/AppHelper/SGT retained, same Shaman and weapons, main-hand runtime enchant `5400` active, and the same AICO/AICD controls. Expected runtime count is 158 only if the exact Log_27 inventory recurs.
- **Changed variable:** none relative to Log_27; this is a reproducibility repeat, not a new reduction.
- **CLEAN:** a second valid clean capture materially strengthens QuickCrafts state as a repeatable selector in this reduced branch. It still does not distinguish QuickCrafts code from its item-load workload/provider/timing effects or establish global necessity/causality.
- **ERROR:** QuickCrafts is not required even in the current reduced branch; the ABA association is not deterministic and another readiness/scheduling cofactor remains active. Do not proceed as though QuickCrafts were necessary.
- **INCONCLUSIVE:** wrong equipment/enchant, inventory drift, invalid B/C controls/hooks, drops/failures that weaken absence evidence, truncation, or no accepted `246664` episode. Repeat unchanged.

This repeat has higher immediate information value than suppressing `LoadAllItemInfo`, shifting timers, or separating Auctionator pricing because it validates the branch premise those mechanistic experiments would rely on.

## Completed reduced-control repeats, normal-profile comparison, and BugGrabber locals: Logs_29-32

### Authoritative file identities

| Capture | Filename | Bytes | Physical lines | SHA-256 |
| --- | --- | ---: | ---: | --- |
| Log_29 | `Logs_29_ShamanBuffON_ProfEconOff_QuickCraftsOff_Repeat.txt` | `216246` | `2456` | `1B35C5B0D9A9C9FADCB216C6307582FBD9E6DF21340B4113B5D080803550F478` |
| Log_30 | `Logs_30_NormalProfile_QuickCraftsCraftSimOff_BugGrabberON.txt` | `251896` | `2878` | `BFCE48FB950C5468642120803823A46873F415F453AF0342566C3D64DB900E9E` |
| Log_31 | `Logs_31_NormalProfile_QuickCraftsOff_CraftSimBugGrabberON.txt` | `250772` | `2864` | `ABEDBD48AD7EC20F04D14A40A090A5BF73256A96577CF7075BB8D2427C551501` |
| Log_32 | `Logs_32_ShamanBuffON_ProfEconOff_QuickCraftsOff_Repeat2.txt` | `216265` | `2456` | `102D7DEF97CE8E38CC562C5A37139C689CCCE1C4AF707D6CC0BFED19F0466096` |

These are distinct physical files. “Physical lines” counts the final unterminated line when present; it is not PowerShell `Measure-Object -Line`'s non-blank-line count.

### VERIFIED RUNTIME OBSERVATION: Log_27 / Log_29 / Log_32 frozen reduced control

The experimental setup labels all three as the same preserved configuration: profession/economy continuation group OFF, QuickCrafts OFF, the same Shaman/equipment context, and Flametongue active. The captures independently establish runtime state rather than deriving it from the physical AddOns directory:

- each reports `loadedAddonCount=158` and `loadedInventoryStatus=ok`;
- all 158 runtime-loaded addon names are identical and occur in the same inventory order;
- all 174 observed `ADDON_LOADED` names are identical and occur in the same order, so the retained LoadOnDemand/startup participation projection also matches;
- QuickCrafts is absent from both runtime lists in all three;
- `CraftSim`, all four Journalator folders, and `ProfessionShoppingList` are absent from both lists in all three;
- BugGrabber, BugSack, ChonkyCharacterSheet, and Zygor are also runtime-absent; and
- the six profession/economy folders remain three logical families, not one addon or one proven causal unit.

The logs do not serialize QuickCrafts's or the profession/economy members' full saved enable-state configuration. Their configured OFF state is the controlled setup; their runtime absence and lack of observed `ADDON_LOADED` participation are independently captured. Likewise, equality of observed runtime names does not prove equality of uncaptured SavedVariables, caches, native readiness, or work performed inside the same addon versions.

| Field | Log_27 clean | Log_29 clean | Log_32 clean |
| --- | ---: | ---: | ---: |
| Registrations / GetCallbacks | `212 / 723` | `212 / 723` | `212 / 723` |
| Dispatch opens / normal exits | `945 / 945` | `925 / 925` | `935 / 935` |
| Final / maximum dispatch depth | `0 / 1` | `0 / 1` | `0 / 1` |
| Stack mismatches / dispatch failures | `0 / 0` | `0 / 0` | `0 / 0` |
| Direct B entries / active-handler C entries | `0 / 0` | `0 / 0` | `0 / 0` |
| AICD startup entries | `87` | `87` | `87` |
| Main-hand state | `246664`, enchant `5400` | `246664`, enchant `5400` | `246664`, enchant `5400` |
| `246664` AICD PREFIRE bucket | nil | nil | nil |
| `246664` item-data completion | success | success | success |

All three pass the BugGrabber-off and boundary-provenance validity gates: the active-handler wrapper remains installed through snapshot, the direct addon-global B wrapper remains active, there are no boundary drops/snapshot failures, and sampled `xpcall`/`ipairs` are secure and untainted. Log_27's first `246664` PREFIRE observes `tempEnchant=true`, enchant `5400`, and a zero remaining-time reading before a later positive reading; Logs_29/32 observe positive `3556000ms`/`3591000ms` readings at their corresponding PREFIREs. This duration variation does not change the shared verified enchant-presence/ID state.

Log_32 therefore is a valid third clean realization of the frozen reduced control. The exact registration/GetCallbacks/startup-entry equality and exact runtime membership/order equality strengthen the control; the `925/935/945` dispatch-count spread also demonstrates that identical captured composition does not imply identical aggregate scheduling or work volume. The reduced matrix is now:

| QuickCrafts runtime state | Captures | Outcome |
| --- | --- | --- |
| ON | Logs_26 and 28 | ERROR, ERROR |
| OFF | Logs_27, 29, and 32 | CLEAN, CLEAN, CLEAN |

This five-run split makes QuickCrafts state a reproducible selector for the tested reduced branch. It still does not distinguish QuickCrafts code from item-readiness, its two 165-ID passes, provider interaction, timing perturbation, or an interaction with another retained component. It also does not make QuickCrafts defective, sufficient, directly causal, the owner of `246664`, or globally necessary.

### VERIFIED RUNTIME OBSERVATION: Log_30 versus Log_31 normal profile

Log_30 reports 174 loaded addons; Log_31 reports 175. Comparing every captured loaded name establishes that CraftSim is the sole set difference, and removing CraftSim from Log_31 makes the complete loaded-inventory order equal to Log_30. QuickCrafts is runtime-absent in both. BugGrabber, BugSack, ChonkyCharacterSheet, ZygorGuidesViewer, all four Journalator folders, and ProfessionShoppingList are runtime-loaded in both.

The observed `ADDON_LOADED` sets likewise differ only by CraftSim (`192` versus `193` names), but their common-name order is not equal. In Log_30, `Blizzard_ProfessionsTemplates`, `Blizzard_Professions`, and `PublicOrdersReagentsColumn` occur at positions 121-123, while `Blizzard_ProfessionsBook` and `TradeSkillMaster` occur at 148-149. In Log_31 those five names move together to positions 66-70, immediately before CraftSim at 71; `DBM-VPVEM` correspondingly moves from 66 to 72. There are 84 position mismatches after projecting both timelines onto their common set. Thus CraftSim is the only established runtime-membership difference, but it is not the only runtime-order/execution difference induced by the tested configuration.

| Field | Log_30 CraftSim OFF | Log_31 CraftSim ON |
| --- | ---: | ---: |
| Outcome | line-76 ERROR | line-76 ERROR |
| BugGrabber displayed count | `1x` | `2x` |
| Current-session active-handler entries / normal returns | `1 / 1` | `1 / 1` |
| Registrations / GetCallbacks | `612 / 1234` | `612 / 1230` |
| Dispatch opens / normal exits | `1386 / 1386` | `1382 / 1382` |
| Final / maximum depth | `0 / 1` | `0 / 1` |
| AICD startup entries | `440` | `441` |
| Main-hand state | `246664`, enchant `5400` | `246664`, enchant `5400` |
| `246664` failure-adjacent mapped bucket | nil | nil |

BugGrabber's `2x` in Log_31 is not proof of two current-session occurrences. BugGrabber deduplicates by exact message, increments a persistent record's counter across sessions, and refreshes stack/locals on the first repeat in a new session; AICO retained exactly one current-session active-handler entry/normal return in each log. Neither capture contains `ADDON_ACTION_BLOCKED` or `OpenRecipe`, so the CraftSim OpenRecipe protected-action error was not captured in either run. Absence from these finite captures does not prove that path cannot occur.

Both runs retain the same structural shape relevant to the prior boundary work. The Chonky-owned `268203` registration is a secure sole function, its dispatch reaches a normal secure post-hook, and C receives the line-76 string about `1.030s`/`1.050s` later. The current line-76 BugGrabber locals instead name `id=246664`. AICD observes successful enchanted-`246664` completion episodes with nil mapped buckets and later observes a secure one-function Zygor bucket for the same item after the failure-adjacent phase. The aggregate depths end at zero with no stack mismatch or dispatch failure.

Unlike the valid BugGrabber-off B controls, AICO intentionally does **not** install its direct global `CallErrorHandler` wrapper when BugGrabber is enabled: both Logs_30/31 state `callErrorWrapperInstalled=false`. Their zero B entries and `C_WITHOUT_ACTIVE_B` label therefore are not evidence that the explicit line-76 message-handler path was bypassed. C is observed and returns normally, but B is simply unavailable as an entry probe in these two runs. The earlier valid BugGrabber-off zero-B observations remain separate evidence and are not superseded.

The matched result proves that CraftSim is not globally required, just as the two normal-profile errors with QuickCrafts absent prove that QuickCrafts is not globally required. It does not prove that CraftSim has no interaction in another composition, that the two captures are execution-identical, or that the normal-profile mechanism necessarily equals the reduced-branch mechanism.

### BugGrabber debug-local forensics

Both normal-profile error records show the same selected line-76 locals:

```text
id=246664
callbacks=<table>
(for state)=<table>
(for control)=1
i=1
(*temporary)=nil
(*temporary)="attempt to call a nil value"
CANCELED_SENTINEL=-1
```

BugGrabber does not reconstruct these from callback registrations. Its `GetErrorStack` calculates a level from `GetCallstackHeight()` and `GetErrorCallstackHeight()`, and `GetErrorLocals` passes that same level to WoW's native `debuglocals(level)`. On the ordinary source-visible callback-error path, `CallErrorHandler` deliberately sets the error call-stack height to report the previous function; the stored record in either case selects the `FireCallbacks` frame at line 76. The record therefore establishes that the selected report frame had `id=246664`, a non-nil local callbacks table, generic-for control value one, and visible loop index one. It does not independently prove that execution traversed the global `CallErrorHandler` value.

The names require a language/debug distinction:

- In the stock Lua 5.1 compiler, a generic `for` creates internal debug locals named `(for generator)`, `(for state)`, and `(for control)`, then the source-declared variables. At an instruction in this loop body, `i` and `callback` are source-level loop locals. The [Lua 5.1 parser source](https://www.lua.org/source/5.1/lparser.c.html) documents those names, while the [generic-for language rule](https://www.lua.org/manual/5.1/manual.html#2.4.5) describes the iterator/state/control model.
- The stock Lua 5.1 debug interface uses names beginning with `(` for internal variables. When a live stack slot has no active source/debug name, its fallback label is `(*temporary)`; that is a slot label, not an expression identity. See the [Lua 5.1 debug-interface source](https://www.lua.org/source/5.1/ldebug.c.html) and [C API description](https://www.lua.org/manual/5.1/manual.html#lua_getlocal).
- WoW Lua exposes a formatted native `debuglocals` string rather than raw `debug.getlocal` results, and its implementation/filtering is not present in the mirrored UI source. The capture omits both `callback` and the normally function-valued `(for generator)`. That paired omission is compatible with formatting/filtering of function-valued slots, liveness/debug-metadata differences, or WoW compiler/runtime differences. It is not evidence that the omitted callback was nil.

`(for control)=1` and `i=1` are consistent with the first yielded iteration. They do not display the second yielded value. Under stock `ipairs`, a nil `callbacks[1]` makes the iterator return no pair and stops the loop; it cannot yield `i=1, callback=nil`. If a valid first value has already been yielded into the loop local, a later write to `callbacks[1]` cannot retroactively change that local, and there is no source-visible callback/yield point between loop-variable assignment and the line-76 call. Direct insertion of a non-nil non-function could enter the body, but no capture identifies such a value and no inspected normal registration path creates one.

Neither anonymous temporary can be mapped safely:

- the nil slot is not uniquely `callback`, `xpcall`, `CallErrorHandler`, an `xpcall` status/result, or any particular compiler/VM intermediate;
- the error-string slot is compatible with an active protected-error/error-handler intermediate, but it cannot be called “the `xpcall` result” from this capture;
- BugGrabber captures while the active error handler is running and the selected `FireCallbacks` frame is suspended at line 76; on the ordinary `CallErrorHandler` route this is before `xpcall(...)` returns, while the capture does not prove that route independently; and
- the source discards all eventual `xpcall` returns, while the VM's unnamed-slot allocation and WoW's formatter are not documented by the mirrored Lua.

The synthetic harness establishes ordinary control-flow signatures, not temporary-slot identities. Its invalid-first-argument cases produce B -> C -> `xpcall` return before cleanup/post-hook; its callback-body failure does the same; and its malformed-handler cases return `"error in error handling"` without B or C. No harness capture maps either live `(*temporary)` value, so it cannot convert these anonymous slots into proof of a malformed callback.

The strongest safe local-level conclusion is therefore: BugGrabber selected a real-looking first-iteration `FireCallbacks(246664)` activation with a retained callbacks table, but did not serialize the callback value itself. This narrows the selected frame and item ID. It does not establish which operation attempted the nil call, whether the first callback was malformed, or whether the stored locals correspond one-to-one to AICD's nearest nil mapped-bucket observation.

### Nil mapped callback bucket after Log_32

A nil `listener.callbacks[246664]` mapping is now directly observed in failing and clean sessions. Log_32 supplies another clean example with successful item-data completion, valid instrumentation, and no B/C/error record.

The mapped table and the retained local table are different observations. `FireCallbacks` first retains `local callbacks = self:GetCallbacks(id)`, then `ClearCallbacks(id)` writes `self.callbacks[id] = nil`, and only then iterates the retained table. A nil mapping after that clear is the expected source-visible state and says nothing about entries in the detached table. AICD's pre-clear/post-hook snapshots are discrete correlations rather than exposure of the loop local or `xpcall` arguments; a nil such snapshot means that observed lookup/map episode did not expose a bucket, not that another selected line-76 frame's loop callback was nil.

Therefore nil mapped state is neither sufficient for the error nor evidence of a malformed callback. The logs do not justify merging every nearby `246664` lookup, item-data event, BugGrabber record, and selected line-76 frame into one invocation.

### Hypothesis reweighting through Log_32

| Hypothesis | Assessment after Logs_29-32 | Exact change |
| --- | --- | --- |
| H1. Simple/malformed nil callback | Remains very low; not promoted by locals | The locals establish first-iteration state but omit `callback`. Anonymous nil is not an operand identity, and stock `ipairs` cannot enter with `i=1, callback=nil` from a nil first array slot. A non-nil malformed value remains logically possible but unobserved. |
| H3. Different/later delivery or incomplete invocation correlation | Remains the leading cross-capture observational model, but narrowed | The BugGrabber records select an actual-looking line-76 `FireCallbacks(246664)` frame, reducing the broad possibility that no such frame existed for those stored records. They do not tie that frame one-to-one to the nearest AICD nil-map episode or explain the earlier BugGrabber-off post-hook-before-C observations. |
| H5. Error-handler-path anomaly | Simple malformed-handler form remains very low; no new positive evidence | Logs_30/31 did not install B, so their C-without-B label cannot test handler bypass. The active BugGrabber handler returned normally. Earlier valid BugGrabber-off B-zero evidence remains unresolved; the anonymous locals do not identify A or B. |
| H6. Transient/opaque protected-call binding or VM state | Runtime-compatible and still unverified | Neither temporary identifies the live `xpcall` callee, callback argument, message-handler argument, or native return state. The new locals neither prove nor remove this category. |
| H7. Composition/startup selector | Strengthened in the reduced branch; explicitly non-global | Three exact QuickCrafts-OFF controls are clean and two ON runs error. Logs_30/31 error with QuickCrafts absent, and with CraftSim respectively absent/present, so neither addon is globally required. |
| H8. Temporary-enchant co-condition | Repeatable but insufficient | All five reduced runs have enchant `5400`; three are clean. Logs_30/31 reproduce in the same broad enchanted-Shaman context without resolving the cofactor. |
| H9. Nil mapped bucket as cause | Very low; further weakened | Log_32 is a third clean OFF run with a nil `246664` mapping and successful completion. Map nil does not expose the retained local array. |

No weighting change establishes a Blizzard native defect or a common mechanism across every composition. The locals improve frame/item specificity, not causal specificity.

### Next controlled experiment: Chonky add-back to the frozen reduced control

The highest-information next composition experiment is to start from the preserved Log_29/32 profile, keep QuickCrafts and the profession/economy group OFF, preserve the same Shaman/equipment/enchant state and diagnostics, and enable only ChonkyCharacterSheet in configuration.

This is a high-value **alternative selector/cofactor** test, not a callback-ownership test:

- Chonky is one normal-startup addon with no declared dependency or LoadOnDemand flag.
- Its file-scope `BuildMasterLoot` path can issue 368 `ContinueOnItemLoad` calls over 367 unique static IDs; a prior Chonky-only-additional-addon control observed 353 outstanding startup entries.
- Chonky source contains `268203` but no `246664`. A resulting Shaman `246664` error therefore would not identify Chonky as the callback owner.
- Earlier instrumented failing sessions show the matched Chonky callback reaching `CALLBACK-END`, and Log_19 reproduced with Chonky runtime-absent. Chonky is already disproved as a globally required direct explanation.
- Chonky's `PLAYER_LOGIN` path explicitly loads six Blizzard addons. Enabling one configured addon can therefore add Chonky plus extra observed LoadOnDemand participation or reorder existing milestones; the next capture must compare both loaded inventory and the full `ADDON_LOADED` projection rather than call the runtime delta “one addon” without verification.

Interpret the outcomes narrowly:

- **Chonky ON -> ERROR:** Chonky's coherent startup package can act as an alternative selector/cofactor in this reduced branch. It would not prove that Chonky is defective, that its callback body raised the error, that its mass continuation pass alone is sufficient, that it owns `246664`, or that the mechanism equals QuickCrafts's.
- **Chonky ON -> CLEAN:** Chonky's package is insufficient to substitute for QuickCrafts in that capture. It would not exonerate Chonky interactions in the normal profile, erase earlier callback ownership for `268203`, or prove that no Chonky-on repeat can reproduce.
- **Invalid control:** inventory drift, wrong item/enchant, QuickCrafts or a profession/economy member loading, failed B/C validity gates, drops/snapshot failures, or missing accepted `246664` activity requires an unchanged repeat rather than interpretation.

Recommended first filename: `Logs_33_ShamanBuffON_ProfEconOff_QuickCraftsOff_ChonkyON.txt`. If it is clean, repeat unchanged because one clean outcome is weaker than the three-run OFF baseline; if it errors, one identical repeat should precede claims of a repeatable alternative selector. Do not assume an exact callback/startup-entry increase, because cache readiness and Chonky's conditional raid gates vary. A 159-name loaded inventory is expected only if Chonky is the sole added runtime-listed folder; its forced Blizzard loads may still expand or reorder the observed timeline.

This test has more immediate information gain than adding back the four-folder Journalator family, the former six-folder group, or another broad normal-profile block. CraftSim is already varied across two normal-profile errors and induces professions/TSM ordering changes; Journalator is four runtime folders; and no alternative candidate has Chonky's already measured, source-localized continuation workload. After the Chonky branch is replicated, a clean result would justify selecting the next single logical family from the normal-profile delta rather than broad add-back.

## Completed Chonky add-back, OBB isolation, and provider replacement: Logs_33-44

Logs_33 and 34 completed the preceding Chonky add-back recommendation: both retained the reduced QuickCrafts-OFF/profession-economy-OFF composition, added Chonky, retained OBB, and reproduced. They established Chonky as an alternative selector in that branch, not direct ownership or sufficiency. Logs_35-40 then exposed OBB as the common controlled selector behind the newer branches and materially reweighted the earlier QuickCrafts/Chonky results.

### Authoritative file identities for the OBB matrix

| Capture | Filename | Bytes | Physical lines | SHA-256 |
| --- | --- | ---: | ---: | --- |
| Log_35 | `Logs_35_ShamanBuffON_ProfEconOff_QuickCraftsOff_ChonkyON_OUS_NewOpenablesOFF.txt` | `188504` | `2189` | `FEECF08EE7A648B6F37047313EBCD72583785CC1FC3839AA0346F9B08B960C8B` |
| Log_36 | `Logs_36_ShamanBuffON_ProfEconOff_QuickCraftsOff_ChonkyON_OUS_OBB_NewOpenablesOFF.txt` | `183453` | `2148` | `98578C48E611A5B746F3B3ED2B5DDD4AD9AF8601276281BC897E9570EB4F9F09` |
| Log_37 | `Logs_37_ShamanBuffON_ProfEconOff_QuickCraftsOff_ChonkyOUSNewOpenablesON_OBB.txt` | `217218` | `2465` | `629C00CE9FAECADB2D7CB734084B5CA99DD5525D0BFECFDD599750423F3549D8` |
| Log_38 | `Logs_38_ShamanBuffON_ProfEconOff_QuickCraftsOff_ChonkyOUSNewOpenablesOBB_ON.txt` | `222257` | `2507` | `38A87E248EAF1D68636F94CA893D1750590F9C3B4EE683BDE0181BDC9488A142` |
| Log_39 | `Logs_39_BugGrabberON_FullNormalProfile_OBB_OFF.txt` | `217636` | `2584` | `31166FBFF190B1C5C5FDFB8F1E3006B13D82703A07BB9F52C2FD01915D1CC2FD` |
| Log_40 | `Logs_40_BugGrabberON_FullNormalProfile_OBB_ON.txt` | `223181` | `2647` | `54D3B0D9843E4C81E00F35CA032B39B82061CF69E083CC4FB597FA042087A38C` |

These are six distinct files. Runtime inventories, not enabled-folder names or physical folders, determine captured participation.

### VERIFIED RUNTIME OBSERVATION: three exact OBB pairs

| Field | Log_35 OBB ON | Log_36 OBB OFF | Log_37 OBB OFF | Log_38 OBB ON | Log_39 OBB OFF | Log_40 OBB ON |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Outcome | ERROR | CLEAN | CLEAN | ERROR | CLEAN | ERROR |
| Loaded inventory | `157` | `156` | `158` | `159` | `174` | `175` |
| `ADDON_LOADED` timeline | `175` | `174` | `176` | `177` | `192` | `193` |
| Registrations | `519` | `519` | `573` | `573` | `942` | `942` |
| GetCallbacks | `1138` | `1137` | `1192` | `1193` | `1361` | `1362` |
| Dispatch opens / normal exits | `1350 / 1350` | `1384 / 1384` | `1399 / 1399` | `1400 / 1400` | `1508 / 1508` | `1514 / 1514` |
| Final / maximum depth | `0 / 1` | `0 / 1` | `0 / 1` | `0 / 1` | `0 / 1` | `0 / 1` |
| Current-session C entries / returns | `1 / 1` | `0 / 0` | `0 / 0` | `1 / 1` | `0 / 0` | `1 / 1` |
| Equipped `246664` PREFIRE/COMPLETE episodes | `2` | `1` | `1` | `2` | `2` | `3` |
| Main-hand runtime enchant | `5400` | `5400` | `5400` | `5400` | `5400` | `5400` |
| `268203` registrations / PREFIRE | `1 / 1` | `1 / 1` | `1 / 1` | `1 / 1` | `1 / 1` | `1 / 1` |

For each pair, OBB is the sole loaded-inventory set difference. Removing `OdysseusBuffBars` from the OBB-ON inventory makes the complete remaining name sequence equal to its OBB-OFF partner. The same is true for every observed `ADDON_LOADED` name and its relative order. This closes hidden runtime package and LoadOnDemand-order differences at the captured name level; it does not prove equality of caches, native readiness, SavedVariables, per-addon internal state, elapsed time, or event scheduling.

The captured family/config boundaries are:

- Logs_35/36 have Chonky and TradeSkillMaster loaded, while QuickCrafts, the selected profession/economy group, OUS, NOP, Zygor, BugGrabber, BugSack, and CraftSim are runtime-absent. OBB is present only in Log_35.
- Logs_37/38 add OUS and NOP to that reduced runtime family; QuickCrafts, the profession/economy group, Zygor, BugGrabber, BugSack, and CraftSim remain absent. OBB is present only in Log_38.
- Logs_39/40 are the full normal profile with BugGrabber, BugSack, QuickCrafts, CraftSim, Chonky, OUS, NOP, Zygor, and the restored profession/economy members loaded. OBB is present only in Log_40.

The aggregate counter differences are descriptive hidden execution differences, not extra configured variables. Registrations are equal within every pair, while OBB-ON has exactly one additional GetCallbacks in all three pairs. Dispatch totals vary by `-34`, `+1`, and `+6` respectively; this disproves a simple fixed scalar-work increment. Snapshot elapsed times also vary. Scalar startup time and raw callback volume are therefore not established causes.

### VERIFIED RUNTIME OBSERVATION: the OBB-associated `246664` episode

AICD records exactly one additional equipped-main-hand `246664` PREFIRE/COMPLETE episode in each OBB-ON capture relative to its exact partner. In all three additional episodes:

- main hand is item `246664` with active runtime enchant `5400`, and off hand is item `246669` without a temporary enchant;
- the pre-clear lookup reports `callbackMapType=table bucketType=nil` and `entryOrigins: none`;
- the stack is `ItemEventListener:GetCallbacks` -> `AsyncCallbackSystemMixin:FireCallbacks` -> the `ITEM_DATA_LOAD_RESULT` handler; and
- AICD later records event completion with the mapped bucket still nil.

The extra episode is AICO's most recent GetCallbacks immediately before C in all three failures. AICO's precise deltas from that observation to active-handler entry are approximately `0.313ms` in Log_35, `0.315ms` in Log_38, and `0.475ms` in Log_40. At C, AICO reports zero open dispatches, an empty open stack, and no active dispatch sequence. The nil mapped bucket means that this observed `FireCallbacks(246664)` invocation skipped the source-visible line-76 loop; it must not be called the invocation that executed line 76. The tight ordering is correlation and an important selector signature, not one-to-one invocation identity.

In full-profile Log_39, the later `246664` episode has a secure one-function Zygor bucket and normal-exits. Log_40 has the same later Zygor registration/dispatch after the error, plus the earlier OBB-associated nil-bucket episode before the error. Reduced Logs_35/38 reproduce with Zygor and QuickCrafts absent, so neither can own the additional episode in those captures.

### VERIFIED RUNTIME OBSERVATION: Log_40 details

Log_40 verifies `loadedAddonCount=175`, inventory status `ok`, OBB present, `942` registrations, `1362` GetCallbacks, and `1514/1514` dispatch opens/normal exits. It has zero stack mismatches, zero dispatch failures, final depth zero, and maximum depth one.

Chonky registers one callback for item `268203` at registration order `222`. Its stack is `ItemMixin:ContinueOnItemLoad` -> installed instrumented `core/gearDB.lua:1452` -> raid traversal line `1742` -> file-scope build line `1775`. At target PREFIRE order `915`, the sole bucket entry is the same function and is `secure=true, taint=nil`. The target dispatch opens and normal-exits `0.147ms` later. The captured Log_40 text does not include the separate `AICD_CHONKY_268203_GetLog()` marker dump, so this log alone does not establish `CALLBACK-END`; the earlier completed instrumentation capture remains the evidence that this callback body can finish in a failing session.

The active BugGrabber handler receives the exact `AsyncCallbackSystem.lua:76: attempt to call a nil value` string `1.035734s` after the `268203` normal exit. At handler entry no tracked dispatch is open. BugGrabber's displayed record says `3x`, but AICO records one current-session active-handler entry and one normal return; the displayed aggregate is not three proven current-session failures. The nearest GetCallbacks is the nil-bucket `246664` episode above, not the older `268203` target. Because BugGrabber is enabled, AICO intentionally did not install its direct global B wrapper; Log_40's B-zero count is therefore unavailable as a bypass test. Valid BugGrabber-off B/C evidence remains in Logs_35/38 and earlier captures.

### VERIFIED INSTALLED SOURCE: OBB weapon-enchantment and item-loading trace

The historical OBB checkout used for Logs_35-42 was commit `af23eee08e83336e6df5196f0cfb4ec094befd54`. Its own first-party Lua contained zero occurrences of `ItemEventListener`, `AsyncCallbackSystem`, `Item:Create`, `ContinueOnItemLoad`, `ContinueWithCancelOnItemLoad`, `RequestLoadItemData`, or `GetItemInfo`. OBB therefore did **not directly** call the item listener or construct an ItemMixin continuation on the old provider path.

It does participate indirectly and deliberately through Blizzard's managed AuraContainer implementation:

1. On OBB's own `ADDON_LOADED`, `OdysseusBuffBars.lua:283-399` initializes the managed renderer immediately.
2. `OdysseusBuffBars_Managed.lua:3386-3444` creates a `CustomAuraContainerTemplate`, sets its unit to `player`, and unconditionally adds MainHand and OffHand item-enchantment providers before adding the separate `HelpfulEnhancements` aura group and fishing row. `Managed:Initialize` calls this infrastructure builder before committing visibility (`:3447-3524`).
3. Blizzard `CustomAuraContainerSharedMixin:AddItemEnchantment` immediately calls `RefreshItemEnchantments` (`Blizzard_CustomAuraContainer.lua:450-464`). The manager reads `C_PaperDollInfo.GetTemporaryEnchantmentInfo` for the mapped inventory slot (`Blizzard_AuraContainerEnchantments.lua:178-219`; `Blizzard_AuraContainerUtil.lua:156-168`).
4. When active-enchant data initializes or updates its aura frame, `AuraContainerUtil.SetSpellNameForAura` derives an Item from the equipment slot and reads its name. If the name is nil, it registers the exact cancelable callback shape `function() auraButton:UpdateAuraDisplay(); end` (`Blizzard_AuraContainerUtil.lua:241-254`). `ItemMixin:ContinueWithCancelOnItemLoad` validates that function and passes it to `ItemEventListener:AddCancelableCallback`, which delegates to `AddCallback` (`Item.lua:309-338`).
5. `CommitManagedPresentation` shows and enables every managed container, and `SetEnabled(true)` invokes `UpdateAllAuras` (`OdysseusBuffBars_Managed.lua:2467-2493`; `Blizzard_AuraContainer.lua:28-33`). OBB's PEW handler explicitly refreshes the enchantment container again, starts an inventory quiet-turn recovery, and responds to later `UNIT_AURA` and `UNIT_INVENTORY_CHANGED` transitions (`OdysseusBuffBars_Managed.lua:3182-3260`). The underlying Blizzard container also handles `WEAPON_ENCHANT_CHANGED` and `WEAPON_SLOT_CHANGED` (`Blizzard_AuraContainer.lua:81-90`).

This path dynamically targets whichever item occupies MainHand or OffHand; it contains no literal `246664`. With the logged Shaman equipment and active enchant, slot 16 legitimately resolves to item `246664`. It can add an item-name request/callback and alter the timing or bucket membership of the shared `ItemEventListener` path even though OBB never names that listener.

OBB's other item/enchant-adjacent paths are separate:

- Automatic `HelpfulEnhancements` discovery reads unit auras and spell APIs, updates candidate descriptors, and can refresh the enchantment container. It does not construct Item objects or request item data.
- The addon-local fishing-lure row resolves a fishing profession-tool slot, optionally checks its inventory type through `C_Item.GetItemInventoryTypeByID`, reads that slot's temporary-enchant table, and reads its inventory texture (`OdysseusBuffBars_Managed.lua:1851-1910`, `:2131-2185`). It reacts to PEW, player inventory, profession-equipment, combat, expiration, and zero-delay quiet-turn work (`:2015-2033`, `:2862-2906`). This is a profession-tool path, not the native MainHand/OffHand provider.
- The fishing row calls `GameTooltip:SetInventoryItem` only on mouse enter (`:2841-2857`). Blizzard's native enchant aura button similarly calls `SetInventoryItem` only while populating its hover tooltip (`Blizzard_AuraButton.lua:177-220`). The startup item continuation comes from name rendering, not from proof that a tooltip was hovered.
- Core timers at zero and `0.25s` reapply Blizzard-frame visibility. They do not inspect equipment or request item data.

### VERIFIED INSTALLED SOURCE: Chonky weapon-enchantment and item-loading trace

The current installed Chonky `2.3.16` copy is the frozen instrumented source used by Logs_35-44. Its target-only marker block remains at `core/gearDB.lua:1412-1446`; no file was changed in this review.

Chonky has three distinct paths that must not be conflated:

1. **Temporary-enchant display.** The slot renderer and one-second Character Frame ticker call deprecated `GetWeaponEnchantInfo`, index Chonky's static enchant-ID-to-spell-ID table, and call `C_Spell.GetSpellName` for display (`core/utils.lua:2163-2188`, `:2670-2715`; `Retail/characterSheet.lua:1133-1137`). Current Blizzard compatibility code derives `GetWeaponEnchantInfo` from `C_PaperDollInfo.GetTemporaryEnchantmentInfo`. This path has no Item object, no ItemMixin continuation, and no item-data callback. It resolves the coating identity rather than using the weapon name as the row label.
2. **Equipped-item startup/display.** On PEW, Chonky loops slots 1-19, calls `GetItemInfo(link)`, obtains each `GetInventoryItemID`, and directly calls `C_Item.RequestLoadItemDataByID(itemID)` (`Retail/characterSheet.lua:1959-1975`). After a `0.2s` delay, `TryLoopItems` retries at `0.1s` until every equipped link has item info, then calls `CCS.updateLocationInfo` for all slots (`:415-438`). The display path uses `C_Item.GetItemInfo`, can issue another direct request if `IsItemDataCachedByID` is false, and scans equipment with both a hidden `GameTooltip:SetHyperlink` and `C_TooltipInfo.GetInventoryItem` (`core/utils.lua:1935-2227`). These are direct item-data requests but not `ContinueOnItemLoad` callbacks. Slot 16 dynamically supplies `246664` in the captured character state.
3. **Master-loot database.** File-scope `CCS.BuildMasterLoot()` traverses static season data and registers valid `ContinueOnItemLoad` functions (`core/gearDB.lua:1448-1703`, `:1710-1775`). Item `268203` is a static raid-loot entry and produces the observed target callback. It is not derived from equipped slot 16, and the callback body does not inspect weapon enchants, equipment, or tooltips. The target-only diagnostic records before/after steps and final publication for `268203`; it does not instrument `246664` or the equipped-item request loop. The second Chonky continuation in `core/core.lua:463-471` runs only for the manual `loot` slash-command branch, not normal startup.

Chonky also parses an equipment tooltip enchant line for its general gear display (`core/utils.lua:2199-2227`), but that is distinct from the temporary-coating name lookup. Neither installed Chonky nor installed OBB contains literal item ID `246664`; both reach it dynamically through equipped MainHand state.

### Comparator: QuickCrafts

Installed QuickCrafts `0.0.4` still performs two 165-ID continuation passes on initial login: one at its own `ADDON_LOADED`, one from a two-second PEW timer. `PriceSource.lua:183-216` creates a valid anonymous `ContinueOnItemLoad` callback for each unique recipe/material ID; `Core.lua:43-78` schedules the passes. Its source contains no `246664`, equipped-slot, weapon-enchant, or temporary-enchant path. It can materially change shared item-load pressure and cache/order timing, but it cannot be assigned direct ownership of the equipped-weapon request from this source. Logs_35/38 reproduce while QuickCrafts is absent, and Log_39 is clean while it is present, so QuickCrafts is neither globally required nor sufficient.

### Source-supported relationship and leading model

OBB and Chonky do not call each other, do not resolve the temporary coating through the same addon code, and do not share a source-local callback. They converge on Blizzard item loading around startup:

- Chonky loads before OBB in every OBB-ON capture, creates its large static database continuation population, and later directly requests all equipped item IDs at PEW.
- OBB initializes a native managed weapon-enchantment provider during its own addon load and refreshes it again at PEW. The native name path can create a cancelable continuation under the current weapon item ID.
- Both operations can issue or affect `ITEM_DATA_LOAD_RESULT` for `246664`; every success event calls the one global ItemEventListener's `FireCallbacks(246664)`, including when its mapped bucket is nil.
- QuickCrafts can add a large independent continuation population without naming the weapon.

The best combined model is now: **OBB activates a specific native managed item-enchantment/name path for the equipped weapon and, within sufficiently complex startup compositions, that path changes item-cache/request/event ordering close to the unresolved line-76 delivery.** This is stronger than “OBB merely adds generic volume” because all three OBB-ON captures add exactly one `246664` event while total registrations remain pairwise equal. It remains a source-supported inference rather than causal attribution: no capture proves that the additional event was initiated by OBB, no error-adjacent callback bucket is exposed, and the source-visible nil-bucket invocation cannot execute line 76.

The uncaptured user-supplied minimal Chonky+OBB+BugGrabber clean startup is important negative evidence. It means Chonky+OBB are not demonstrated sufficient and supports an additional workload/readiness/composition condition. Its faster load is descriptive only; no scalar time threshold is established.

### Completed provider split and production replacement: Logs_41-44

The four authoritative raw captures remain external evidence under `D:\WowDEV\Projects\BlizzardResearch_RuntimeLogs\AsyncCallbackSystem\`; they are intentionally not repository content.

| Capture | Filename | Bytes | Physical lines | SHA-256 |
| --- | --- | ---: | ---: | --- |
| Log_41 | `Logs_41_ShamanBuffON_ProfEconOff_QuickCraftsOff_ChonkyON_OUS_NewOpenablesOFF.txt` | `216006` | `2525` | `0C7154B703545FFD95824CC541E0F26B4AACA0B2B0621A7E87357345D3EEF5DE` |
| Log_42 | `Logs_42_ShamanBuffON_ProfEconOff_QuickCraftsOff_ChonkyON_OUS_NewOpenablesOFF_OBB_Restored.txt` | `220971` | `2563` | `72E6DFDFFAF4774B26D567F56D4AE54B121AE1D2CDAE3CDA1C5AD2BEDDC52B7D` |
| Log_43 | `Logs_43_ShamanBuffON_ProfEconOff_QuickCraftsOff_ChonkyON_OUS_NewOpenablesOFF_OBB_patched.txt` | `215542` | `2532` | `5073D88AE71720672ED9FA6CE531163BB1891A7EA3AB29CA97FEB8178FCA0F0C` |
| Log_44 | `Logs_44_ShamanBuffON_ProfEconOff_QuickCraftsOff_ChonkyON_OUS_NewOpenablesOFF_OBB_patched_Repeat.txt` | `215386` | `2531` | `623C7275A04F79A9A8A156885AF7392D1695B92116CED1F1369006690F455D3D` |

| Capture | Provider state and outcome | Registrations | GetCallbacks | Dispatch opens / exits | Handler entries |
| --- | --- | ---: | ---: | ---: | ---: |
| Log_41 | OBB loaded; managed MainHand/OffHand providers disabled — CLEAN | `557` | `1175` | `1337 / 1337` | `0` |
| Log_42 | same controlled environment; managed providers restored — ERROR | `557` | `1176` | `1338 / 1338` | `1` |
| Log_43 | OBB-owned ordinary weapon-enchant rows — CLEAN | `557` | `1175` | `1337 / 1337` | `0` |
| Log_44 | same production replacement, repeated — CLEAN | `557` | `1175` | `1326 / 1326` | `0` |

Log_41 retained valid BugGrabber-off and direct-global-wrapper controls; BugGrabber and BugSack were absent. Item `246664` still traversed item loading through another addon and completed normally. Log_42 restored only the old managed provider branch and recorded one current-session active-handler entry/normal return for the exact line-76 string. Its Chonky `268203` callback opened and normal-exited before that later report.

Logs_43 and 44 exercised the committed OBB-owned replacement with BugGrabber/BugSack enabled. Both were clean and the BugGrabber handler wrapper recorded zero entries. In each run the Chonky `268203` callback retained a one-function bucket, opened, and normal-exited; item `246664` also continued through the shared listener via another consumer. Log_44 additionally completed the tested combat scenario without an error. All four captures have final dispatch depth zero, maximum depth one, zero stack mismatches, and zero dispatch failures.

The `1337` versus `1326` dispatch difference between Logs_43 and 44 is not evidence of regression: registrations and GetCallbacks remain exactly at the clean provider-disabled level, every observed dispatch normal-exited, and ordinary startup dispatch volume varied in earlier controls as well. The replacement did not merely suppress all weapon item-loading globally.

The controlled conclusion is: **Replacing OBB's Blizzard-managed MainHand/OffHand `AddItemEnchantment` providers with OBB-owned rows reproduced the provider-disabled clean behavior in two consecutive diagnostic runs. The old Blizzard-managed weapon-provider branch remains the strongest verified feature-level selector for the observed AsyncCallbackSystem line-76 failure.** This supports the OBB replacement as a tested mitigation for its affected feature path, not an attribution of the underlying runtime defect.

The current clean installed OBB checkout at commit `2783d38dbebe9843203fb5b5f188d3dedcdb2f11` implements those OBB-owned rows and no longer registers the old managed MainHand/OffHand providers. That implementation is external to this research repository and was not modified during this documentation review.

### Updated hypothesis ranking after Logs_41-44

| Rank | Hypothesis | Current assessment |
| ---: | --- | --- |
| 1 | Old OBB Blizzard-managed MainHand/OffHand provider branch plus a surrounding startup cofactor | Strongest verified feature-level selector. Three exact OBB pairs, the Log_41 disabled/Log_42 restored split, and two clean replacement runs all follow this branch's presence. Minimal Chonky+OBB clean and historical active-enchant clean controls still disprove global sufficiency. |
| 2 | Different/later delivery or incomplete invocation correlation | Still the leading error-delivery constraint. Error-adjacent visible `246664` lookup has a nil mapped bucket and normal event completion, while C is observed after no dispatch remains open. The exact line-76 activation represented by BugGrabber is still not correlated one-to-one. |
| 3 | The old managed provider branch changes another consumer's continuation/cache ordering | Plausible and source-valid. Chonky and another `246664` consumer remain active in clean replacement runs, but no affected callback or ordering edge is identified. |
| 4 | The old native cancelable callback body directly errors | Still weak. The known callback shape calls `auraButton:UpdateAuraDisplay`, but no error-adjacent bucket/callback provenance identifies it, and the previously observed additional bucket was nil. |
| 5 | Raw callback volume or scalar startup duration | Low as a sole model. Registrations are equal within every OBB pair, dispatch deltas vary, and clean/error histories overlap in volume and elapsed time. |
| 6 | Chonky `268203` master-loot callback body | Very low for the underlying occurrence. A prior failing run reached its instrumented `CALLBACK-END`; Chonky-absent runs reproduce; current target callbacks are valid and secure. |
| 7 | Simple nil callback or nil array hole | Very low. No callback value is captured as nil; the error-adjacent mapped bucket is nil, not a retained array with a nil yielded callback; standard `ipairs` would not yield a nil hole. |

#### What we can now say safely

- The old Blizzard-managed MainHand/OffHand provider branch is the strongest verified feature-level selector: provider-disabled Log_41 was clean, restored Log_42 errored, and replacement Logs_43/44 were clean.
- OBB is the only captured addon-name/order difference within each pair after projection, and OBB-ON adds one `246664` GetCallbacks/PREFIRE episode in each.
- OBB has a source-valid indirect route into `ItemEventListener`: its native MainHand/OffHand provider can register an item-name continuation for the equipped weapon when uncached.
- Chonky separately requests the equipped weapon directly at PEW and separately resolves temporary-enchant text without an ItemMixin continuation.
- The visible extra `246664` invocation has a nil mapped bucket and therefore does not execute line 76 in the inspected Lua.
- OBB, Chonky, QuickCrafts, active temporary-enchant state, raw volume, BugGrabber, BugSack, Zygor, CraftSim, OUS, and NOP are each unproven as sufficient or globally required; several are already disproved globally.

#### What is still not proven

- Neither OBB nor Blizzard's provider is proven defective or the root cause; the old branch is not proven globally sufficient or the direct owner of the callback represented by the stored line-76 frame.
- The additional `246664` event is not runtime-attributed to OBB even though it follows OBB state and matches OBB's source path.
- No captured callback value is nil or malformed, and BugGrabber's omitted `callback` local plus anonymous temporary do not prove otherwise.
- The exact instruction-time relationship among the nil-bucket `246664` event, BugGrabber's selected non-nil local callbacks table, and later C delivery is unresolved.
- The needed surrounding cofactor in the clean minimal composition is unknown; startup speed alone is not proven causal.
- No Blizzard/native defect, taint failure, concurrent race, or consumer-visible damage has been established.

### Completed experiment and diagnostic stop point

Logs_41 and 42 completed the previously recommended internal provider split, and Logs_43/44 validated the production replacement twice. No AICO, AICD, harness, or Chonky diagnostic modification is warranted for this checkpoint. Further work would be new experimental research and requires a separate question and authorization; this document does not propose a speculative routing or native-system fix.

## Security, combat, and taint boundaries

- The observed path occurs during login; no combat-dependent branch was found in `AsyncCallbackSystem`, the `ItemMixin` continuation, or the managed item-name helper.
- `C_Item.RequestLoadItemDataByID` is documented with `SecretArguments = AllowedWhenUntainted`, but the supplied error is not a blocked-action or forbidden-action report.
- `Blizzard_AuraContainer.toc` declares `UseSecureEnvironment: 1`, and its comment states that its Lua files load into the secure environment. That makes the native item-name callback a secure-environment source candidate, but the inspected Lua does not document whether an insecure `hooksecurefunc` post-hook must observe that call path. V2's missing registration must not be attributed to this boundary without runtime evidence.
- Custom AuraButtons use secure/private partitions and deferred access restrictions, including `DenyTaintedAccessWhenAurasAreSecret`. The current evidence does not establish that those restrictions or taint caused the nil call.
- No source or runtime evidence ties this failure to combat lockdown.
- A registering addon can be involved without performing a protected gameplay action; callback registration and item-data observation are separate from secure action-button execution.

Do not label this a taint failure, protected-action block, combat-lockdown failure, or universal combat-safety result.

## Impact assessment

`ITEM_DATA_LOAD_RESULT` reaches `FireCallbacks` only on the success branch, so the item-data request itself has completed successfully before callbacks run.

If `xpcall` is intact and one callback body errors, `xpcall` isolates that callback and `FireCallbacks` continues to later entries before clearing the array. The newest instrumented Chonky execution did not take that path: it published the intended `CCS.MasterLoot[itemID]` record and reached `CALLBACK-END`. Earlier uninstrumented captures cannot establish whether their Chonky bodies completed. A separate callback or an error outside the protected callback call could have different consumer impact.

If the global `xpcall` function itself were unavailable, `FireCallbacks` would abort at the first entry after it had already removed the map entry; later callbacks and final array cleanup would not run. Current evidence does not establish this category.

The error is therefore not proven catastrophic item initialization, but it is also not source-supported to dismiss it as harmless. In the newest capture the item data was ready and the identified Chonky consumer completed; which operation, if any, failed to complete remains unresolved.

## Historical passive diagnostic basis

The initial diagnostic deliberately avoided wrapping or replacing callbacks. Its passive, event-driven basis was:

1. Post-hook only `ItemEventListener:AddCallback` with `hooksecurefunc`.
2. Immediately filter to IDs matching the currently equipped MainHand/OffHand/Ranged item IDs, preferably only when `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)` is non-nil.
3. Record:
   - item ID;
   - `type(callbackFunction)` and `tostring(callbackFunction)`;
   - a short `debugstack` showing the registration path;
   - callback-array length and the type of each current entry, read without mutation;
   - `type(xpcall)`, `type(ipairs)`, and `type(CallErrorHandler)`;
   - `issecurevariable` results for those globals if available in the tested client.
4. Register one ordinary frame for `ITEM_DATA_LOAD_RESULT` and log the delivered `itemID`/`success` plus the same global-type checks. Do not poll.
5. Correlate the error with the recorded callback function addresses and registration stacks. A stack through `AuraContainerUtil.SetSpellNameForAura` identifies the native managed item-name candidate; another stack identifies another registrant.

This diagnostic does not modify Blizzard source, does not replace `xpcall` or `CallErrorHandler`, does not wrap callback functions, does not touch protected gameplay actions, and needs no `OnUpdate`.

Because `hooksecurefunc` is a post-hook, synchronous cached completion can occur before the post-hook records the registration. That is acceptable for the fresh-launch target, where the relevant evidence is a deferred item request; the diagnostic should explicitly record this limitation.

At that historical stage, per-callback wrapping was reserved as a possible later escalation. V3 and the current API audit now show that wrapping would change identity/timing without safely recovering the already-ended pre-bootstrap registration stack, so it is not justified.

## Implemented passive runtime diagnostic history

`Samples/RetailUIResearch/Modules/AsyncItemCallbacksDiagnostic/` implements the passive evidence-gathering step. It is deliberately a diagnostic module rather than a reusable control comparison or workaround. V2 corrected the evidence-retention gaps demonstrated by the first failing capture and added one passive pre-clear bucket observation. The second failing capture then demonstrated the remaining attribution gap addressed by V3.

### Current LIVE source comparison

The following files have no content changes between the original research commit `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4` and current LIVE mirror HEAD `8ea15b61e45c0ed4eba01439c90757f86eb78d34`:

- `Blizzard_ObjectAPI/Mainline/AsyncCallbackSystem.lua`;
- `Blizzard_ObjectAPI/Mainline/Item.lua`;
- `Blizzard_ObjectAPI/Mainline/ItemLocation.lua`;
- `Blizzard_SharedXMLBase/ErrorUtil.lua`;
- `Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua`;
- generated `ItemDocumentation.lua`;
- generated `PaperDollInfoDocumentation.lua`.

The prior conclusions about `ipairs`, cancellation, error attribution, supported callback validation, the equipped-item ID key, the `ITEM_DATA_LOAD_RESULT` payload, and the managed temporary-enchantment continuation path therefore remain applicable. This comparison provides no reason to consult PTR.

### V2 early-load architecture

The root RetailUIResearch TOC explicitly depends on `Blizzard_ObjectAPI`. V2 loaded `Core.lua`, then `AsyncItemCallbacksDiagnostic.lua`, then `Launcher.lua` and the existing visual modules. `Blizzard_ObjectAPI` necessarily created `ItemEventListener` before RetailUIResearch could hook it. V2 also had a small same-addon window while `Core.lua` ran before the hooks were installed; Core itself contains no item-continuation call, but the window was not explicitly measured.

V2 could not recover registrations completed before its module loaded. Another addon or Blizzard feature that registered earlier in the session was outside the post-hook's observation window. A missing V2 registration record was therefore not evidence that no registration occurred.

### Why v1 did not preserve the early registration

The `AddCallback` post-hook receives the original `listener, id, callbackFunction` arguments after each normally returning call. V1's later Zygor entry demonstrates that the ID and callback identity were delivered correctly. Synchronous item-data completion can run and clear a callback bucket before this post-hook runs, but if `AddCallback` returns normally the post-hook still receives its original ID and callback arguments.

V1 failed to retain useful early evidence for two implementation reasons:

1. it kept only the newest 40 unmatched registrations, evicting the oldest entry whenever the bound was exceeded;
2. it buffered only while `enteredWorld == false`. The failing capture established that both weapon IDs were still unreadable at `PLAYER_ENTERING_WORLD`, so any later unmatched registration before the first readable equipment snapshot was discarded outright.

The later `hookOrder=407` proves high registration volume but does not reveal the missing registration's order or the registration count at the v1 lifecycle cutoff. It therefore cannot prove which loss path affected a particular callback. It does establish that a 40-entry buffer cannot reliably span the observed login volume. V2 uses a 512-entry unresolved-identity buffer, exceeding the complete registration order observed through the later Zygor entry by 105 entries.

### Registration observation

The diagnostic uses:

```lua
hooksecurefunc(ItemEventListener, "AddCallback", postHook)
```

This is a post-hook of the existing ordinary Lua method. It does not assign to `ItemEventListener.AddCallback`, replace or wrap the supplied callback, change arguments or return values, invoke or cancel callbacks, replace `FireCallbacks`, or mutate `ItemEventListener.callbacks`.

For an ID matching the current main-hand or off-hand item ID, the post-hook records:

- one monotonic log order and `GetTime()` timestamp;
- item ID and the diagnostic's per-ID observed registration count;
- `type(callbackFunction)` and `tostring(callbackFunction)`;
- matching equipment slot plus the current temporary-enchant state and fields;
- callback-map/bucket type, bucket length, and at most 16 callback entry types/identities;
- focused `type` and, when available, `issecurevariable` results for `xpcall`, `ipairs`, and `CallErrorHandler`;
- at most ten lines of `debugstack` from the post-hook context.

V2 caches equipment state from lifecycle, item, equipment, UI-open, and manual-refresh observations. It does not repeat equipment/enchant queries for every unrelated registration. While both equipped weapon IDs remain unreadable, it stores only compact raw evidence: ID, callback type/identity, hook order/time, bucket type/length, focused function types, and a six-line/1,200-character stack.

The unresolved-registration buffer holds 512 entries and counts any eviction. When either weapon ID becomes readable, V2 emits only buffered entries matching the current main/off-hand IDs, reports matched/discarded/evicted totals, and discards unrelated evidence. Multiple matching registrations remain separate numbered entries and increment the per-ID count.

`hooksecurefunc` runs after `AddCallback` returns. If the accessor produces synchronous `ITEM_DATA_LOAD_RESULT`, callback delivery and callback-array clearing can happen before the post-hook records the call. In that case the completion observer can appear before the registration record and `bucketAfterReturn` can be nil. This is an expected instrumentation limitation, not evidence of a missing or malformed callback.

### Passive pre-clear bucket observation

Registration buffering alone cannot prove the callback array present at invocation time. Current source provides a smaller passive observation point than wrapping `FireCallbacks`:

```lua
hooksecurefunc(ItemEventListener, "GetCallbacks", prefirePostHook)
```

The only current Blizzard source callsite for `AsyncCallbackSystemMixin:GetCallbacks` is `FireCallbacks`. The method returns `self.callbacks[id]`; its post-hook runs before `FireCallbacks` advances to `self:ClearCallbacks(id)`. The post-hook can therefore read the still-mapped array and preserve its ordered callback types/identities without changing the return value, callback array, or invocation path.

When equipment identity is unavailable, these observations use a separate 512-entry compact buffer. This matches the registration bound and avoids assuming how many unrelated successful item completions v1 filtered out. An eviction counter makes any loss explicit. Matching pre-clear records retain at most 16 ordered entries plus bounded stack/function state.

This remains callback-bucket attribution, not invocation instrumentation. If the same error again reports `i=1`, a preserved ordered bucket can identify the first callback identity; its registration stack can then be correlated when present. Multiple callbacks, missing pre-addon registrations, an absent `AddCallback` post-hook caused by a non-returning original call, or a changed global dependency can still leave attribution unresolved. No callback is wrapped in v2.

### Equipped and temporary-enchant state

The diagnostic uses the verified `INVSLOT_MAINHAND` and `INVSLOT_OFFHAND` constants. For each slot it creates `Item:CreateFromEquipmentSlot(slot)` and reads `item:GetItemID()`. It calls `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)`, whose current generated signature returns one `TemporaryItemEnchantInfo` table or nothing. When present, only the documented `enchantID`, `remainingTimeMs`, and `chargesRemaining` fields are recorded.

Registration output is limited to IDs equal to the current main-hand or off-hand item ID. Once such an ID is observed, its later completion is retained even if equipment changes before delivery. Unrelated item registrations and completion events are ignored.

The unresolved buffer is governed by equipment readability, not `PLAYER_ENTERING_WORLD`. It therefore continues to preserve compact evidence after world entry until at least one equipped weapon ID becomes readable. Direct observations thereafter use cached equipment identity and record the current temporary-enchant fields.

### Completion and lifecycle observation

One ordinary non-secure frame observes `ITEM_DATA_LOAD_RESULT`. For a currently matching or previously observed weapon ID, it records the documented `itemID, success` payload, current equipment/enchant state, the callback-bucket state visible when this later event listener runs, and the focused function-state facts. It does not invoke, suppress, or reorder Blizzard callbacks.

`PLAYER_LOGIN` and `PLAYER_ENTERING_WORLD` entries provide a session marker and distinguish the supplied `isInitialLogin`/`isReloadingUi` values. `PLAYER_EQUIPMENT_CHANGED` records main-hand/off-hand changes, while `UNIT_INVENTORY_CHANGED` for `player` refreshes the visible status without adding unbounded noise. There is no `OnUpdate` or polling.

### Bounded data and UI

The in-memory visible log retains at most 80 entries and at most 4,000 characters per entry. The unresolved-registration and unresolved pre-clear buffers each retain 512 compact observations. Compact stacks are capped at six lines/1,200 characters, matching stacks at ten lines, and bucket descriptions at 16 entries. The bounded string payload is on the order of a few megabytes rather than an unbounded session history. No SavedVariables are used, so the evidence survives only within the current UI session after the fresh-launch login.

The hidden launcher page shows the current main-hand/off-hand IDs and temporary-enchant state, offers a manual equipment snapshot, provides a copyable scrolling log, and can clear the current entries. Logging remains active while the page is closed.

### Safety assessment

The two post-hooks observe ordinary Lua methods without replacing them. Reading the listener's callback map is ordinary Lua-table inspection and the implementation makes no writes. Equipment/item and temporary-enchant reads use current Retail APIs with fixed non-secret inventory-slot constants. The page and event listener are ordinary non-secure frames and perform no protected action.

These properties make the diagnostic narrowly observation-only. They do not prove universal combat or taint safety: the generated item and PaperDoll APIs carry `AllowedWhenUntainted` secret-argument annotations, and the runtime test target is fresh-launch login rather than combat. No combat-dependent behavior, secure-frame mutation, or protected-action execution is introduced.

### V2 capture interpretation and remaining logic hole

The second failing capture fulfilled V2's bucket-identity goal. The sole callback immediately before `FireCallbacks(268203)` was `0000018C797F6D70`, while the later known callback `0000018DF04489D0` had a separate Zygor registration record. This explicitly separates the two functions and does not assign the earlier one to Zygor.

The 64 buffered registrations had zero matches and zero evictions. Consequently, V2 did not lose the earlier callback through its 512-entry registration capacity, and none of the 64 normally returning `AddCallback` calls observed by its post-hook supplied that callback for item ID `268203`. Synchronous completion can make a pre-fire event precede the post-hook record, but a normally returning `AddCallback` still supplies its original ID and callback arguments to the post-hook; it does not explain a permanently absent record by itself.

V2 did contain a general filtering weakness: it treated equipment identity as resolved as soon as either weapon slot became readable, then discarded unrelated retained records and stopped buffering later unmatched calls. If one slot resolved while the other remained temporarily unreadable, evidence for the later-resolving slot could be lost. That did not explain this supplied session because main hand `268203` and off hand `272275` were both readable at the reported resolution point. V3 nevertheless removes this lifecycle-dependent discard.

### V3 earliest passive capture

V3 adds `Modules/AsyncItemCallbacksDiagnostic/Bootstrap.lua` as the first RetailUIResearch TOC file, before `Core.lua`. `Blizzard_ObjectAPI` remains an explicit dependency and therefore still creates `ItemEventListener` before any RetailUIResearch file can execute. The bootstrap is the earliest point available inside this addon; it cannot run during dependency or earlier-addon loading.

Before installing hooks, the bootstrap takes a bounded read-only snapshot of every callback entry already present in `ItemEventListener.callbacks`. It then installs the same `AddCallback` and `GetCallbacks` post-hooks and retains at most 512 all-ID registration records and 512 all-ID pre-fire records for the whole session. It also retains at most 512 startup entries. Each bound reports evictions.

The bootstrap also records its own installation time and the later `ADDON_LOADED` time for RetailUIResearch. This establishes that the hooks and startup snapshot ran from the first addon file before the addon's load-complete event; it does not move observation into the dependency-loading phase.

For each bucket entry, V3 records type, `tostring` identity, and a guarded `issecurevariable(bucket, index)` result when that API accepts the lookup. At pre-fire it labels each visible identity as one of:

- `present-at-v3-startup` — the same ID/function identity was already in the callback map before V3 installed its hook;
- `AddCallback-observed-by-v3` — the earliest hook observed a normally returning registration with the same ID/function identity;
- `unseen-by-v3` — neither bounded retained set contains the same ID/function identity.

The first label proves only that the callback predates RetailUIResearch's earliest hook. It cannot reconstruct a registration stack that already completed. The security/taint field may distinguish a secure entry from an addon-tainted entry in the tested runtime, but it is diagnostic evidence, not source ownership by itself. The third label requires checking eviction counts and later records before interpretation: synchronous delivery can produce `PREFIRE ... unseen-by-v3` before the same `AddCallback` returns and emits its subsequent `REGISTER`. With zero evictions and no later matching registration, it narrows the remaining possibilities to a non-returning call, a path the post-hook did not observe, or external mutation outside the inspected source lifecycle.

V3 scans retained records again whenever the readable main/off-hand identity signature changes and marks matching records as reported rather than deleting unmatched records. This closes V2's one-slot resolution/discard hole. Direct matches still receive the fuller ten-line registration or pre-fire stack. No callback function is wrapped, replaced, invoked, canceled, or suppressed; neither the callback map nor a bucket is written; `FireCallbacks` remains untouched.

V3 answered the timing category: the relevant callback reports `present-at-v3-startup`. V3 alone could not reconstruct its earlier registration stack, so the separate earlier observer was required; its later same-session identity match now attributes the instrumented `268203` callback to Chonky. Invasive callback wrapping remains unnecessary.

### V3 startup-buffer interpretation

`AppendBounded` appends one record for each callback-array entry visited by the initial `pairs(callbackMap)` / numeric bucket scan. When the retained array grows past 512, it removes exactly one oldest record and increments `startupEvictions` once. Therefore:

```text
retained startup entries + startup evictions = appended startup entry records
512 + 94 = 606
```

The capture proves that V3 encountered exactly 606 appendable callback entries during its sequential startup scan, and therefore at least 606 callback entries were represented by the scanned dense bucket prefixes. An “entry” is one callback-array element, not one item-ID bucket. Non-table map values, indices beyond a bucket's Lua length, or nil holes are not counted, so this is not a claim that the whole map had exactly 606 logically possible values.

The item ID `268203` callback survived in the retained 512 and was correlated at pre-fire. Increasing the startup bound would not add provenance for that callback and is not justified by this capture.

## Chonky Character Sheet read-only source audit

This phase inspected `D:\WowDEV\Reference\ThirdParty\ChonkyCharacterSheet` without modifying it. The audit concerns source capability, load order, callback dependencies, and consistency with the supplied runtime captures. The later observer evidence identifies Chonky's callback only in the instrumented same-session captures; it does not retroactively identify functions in older sessions or authorize copying third-party code or data.

### VERIFIED FROM CHONKY SOURCE: metadata and load order

`ChonkyCharacterSheet.toc` identifies version `2.3.16`, declares `ChonkyCharacterSheetDB`, and does not declare `Dependencies`, `OptionalDeps`, or `LoadOnDemand`. It is a normal startup addon. Bundled `LibSharedMedia-3.0.toc2`, `LibDeflate.toc2`, and `LibStub.toc2` are standalone library manifests rather than entries loaded by Chonky's TOC; LibSharedMedia's standalone `LoadOnDemand: 1` therefore does not make Chonky LoadOnDemand. Chonky's file order is:

1. embedded LibStub, LibDeflate, CallbackHandler-1.0, and LibSharedMedia-3.0 (the TOC includes LibDeflate's XML script and then names `LibDeflate.lua` directly again);
2. `core/localization.lua`, `core/tables.lua`, `core/wrappers.lua`, `core/utils.lua`, `core/styles.lua`, and `core/gearDB.lua`;
3. the Retail files, then the Classic/TBC/MOP files;
4. `core/core.lua`, `core/events.lua`, and `core/options.lua`.

There are no addon-owned XML UI definitions or template-inheritance declarations. The XML files in the TOC are embedded-library script/include files. The earliest addon-owned file is `core/localization.lua`; it creates namespace/localization state. `core/tables.lua` then creates static data, and `core/utils.lua` creates utility/UI state. The first mass item-continuation site is `core/gearDB.lua`.

Chonky does have a `CCS:LoadBlizzardAddOns()` routine for `Blizzard_CharacterFrame`, `Blizzard_TokenUI`, `Blizzard_ChallengesUI`, `Blizzard_WeeklyRewards`, `Blizzard_EncounterJournal`, and `Blizzard_Transmog`. `core/events.lua:338-369` calls it from `PLAYER_LOGIN`, after `CCS:Initialize()` and after every Chonky TOC file has loaded. The matched gear-database callback was registered earlier by the file-scope line-1590 build. Other explicit addon loads are interactive or dormant paths: debug tools from a slash command, Color Picker from a swatch click, and a Weekly Rewards helper whose located caller is commented out. None explains callbacks already present at the V3 startup snapshot.

Inside `LoadBlizzardAddOns`, `safeLoad` checks `C_AddOns.IsAddOnLoaded` and otherwise calls `AddOnUtil.LoadAddOn`. Blizzard's helper recursively discovers required dependencies, enables and synchronously calls `C_AddOns.LoadAddOn` for each missing dependency, then loads the requested addon. Chonky ignores each `safeLoad` return in the loop and sets `self.BlizzardLoaded=true` after the list and follow-up initialization. This is genuine re-entrant addon loading from within Chonky's `PLAYER_LOGIN` handler, but it occurs after the `268203` closure was created.

The forced addons contain item-continuation-capable code. For example, Encounter Journal's Journeys initializer can register an item continuation after a quest callback discovers a reward, its Monthly Activities continuation is entered from `OnEnter`, and Transmog continuations are entered from selection or tooltip paths. These are conditional runtime paths, not file-scope registrations merely caused by parsing those Lua files. The latest observer's later `safeLoad` stacks confirm that nested addon loading can coincide with other registrations, but those later identities/stacks do not replace or re-own the earlier matched Chonky closure.

No Lua assignment to `EJ_GetInstanceInfo` or `EJ_GetEncounterInfo` was found in the LIVE Blizzard source. Both functions already succeeded in Chonky's raid gates before it registered item `268203`, and the enhanced observer saw their function identities unchanged at registration and failing pre-fire. Loading `Blizzard_EncounterJournal` can initialize consumers and shared subsystem state; source does not show it installing or replacing these two globals. A subtler internal-state or nested-callback interaction remains possible, but is not established.

### OBSERVED RUNTIME BEHAVIOR: controlled Chonky comparison

The supplied V3 controls observed zero startup entries in the minimal addon environment. Adding only Chonky produced 353 outstanding startup callback entries and a one-function bucket for item `268203`. In that Chonky-only run, the active enchant initially reported zero remaining time, changed to a positive value before pre-fire, and the callback completed without an error. Oil-OFF testing retained the startup callback and also completed successfully. Fuller environments reproduced the error when the active enchant still reported zero at pre-fire.

The standalone observer then proved same-session provenance in both a clean and a failing run. In the failing run, its `core/gearDB.lua` registration identity exactly matched V3's sole `268203` callback in the delivery window. That establishes Chonky registration and pre-fire bucket ownership, but the later full-path instrumentation shows that identity correlation alone did not establish error ownership: the same kind of sole Chonky callback completed through `CALLBACK-END` while the startup still produced the line-76 report. The unresolved question is now how the stored error correlates with the outer dispatch/error-handler path, not which expression inside this completed Chonky body raised.

### VERIFIED FROM CHONKY SOURCE: direct item continuations

Only two addon-owned `ContinueOnItemLoad` callsites were found:

- `core/core.lua:458-471` creates one continuation inside the `/ccs loot` diagnostic path. It requires a user slash command and is not a startup source.
- `core/gearDB.lua:1412-1518` defines `AddItemToMaster`. For every selected static loot-table item it creates `Item:CreateFromItemID(itemID)` and immediately calls `ContinueOnItemLoad(function() ... end)`. `core/gearDB.lua:1521-1587` traverses the active season's dungeon, raid, and class-set tables, and line 1590 invokes that build at file scope.

The mass callback uses the supported ItemMixin surface, whose current Blizzard path is `ItemMixin:ContinueOnItemLoad` to `ItemEventListener:AddCallback`. It does not write `ItemEventListener.callbacks` directly, use a cancelable continuation, or preserve a cancellation handle. When item data becomes available, the callback reads item information and stats, derives class/subclass and equipment-slot metadata, reads Encounter Journal names as needed, and writes a `CCS.MasterLoot[itemID]` record. It does not query equipped slots or temporary-enchant state. Repeated static IDs can register repeated callbacks; the two occurrences of item `159388` therefore represent two potential callback entries writing the same keyed master-loot record.

Other inspected item/equipment paths do not add an ItemMixin continuation:

| Chonky path | Execution and relevance |
| --- | --- |
| `core/utils.lua:1935-2193` | `CCS.updateLocationInfo` reads a player/inspect inventory link, creates an equipment-slot `ItemLocation` for player slots, reads item/tooltip data, and explicitly requests uncached item data. The local `itemLoc` is not subsequently used. Slot 16 can reach this function with or without a temporary enchant, but the source contains no continuation registration here. |
| `Retail/characterSheet.lua:415-438` | Character-sheet readiness code loops equipped slots and retries by timer until `GetItemInfo` is ready; it then calls `CCS.updateLocationInfo`. This is runtime UI initialization, not a file-scope continuation. |
| `Retail/characterSheet.lua:1952-1977` | On `PLAYER_ENTERING_WORLD`, Chonky reads slots 1-19 and calls `C_Item.RequestLoadItemDataByID` for present items. This can request main-hand item data after login events begin, but it does not add an `ItemEventListener` callback and cannot explain a callback already present before RetailUIResearch loads. |
| `Retail/gearFinder.lua:74-115` and later Gear Finder paths | These request/read item data for the static master-loot UI on demand. They do not call an ItemMixin continuation. |
| `Modules/MOP.lua` and `Modules/TBC.lua` equipment paths | These contain parallel inventory/item-data display logic for non-Retail versions. Their `ItemLocation:CreateFromEquipmentSlot` locals are also unused, and the modules return or remain inactive under the Retail version selection. |
| tooltip/API reads throughout Retail and core files | `C_TooltipInfo.GetInventoryItem`, `GameTooltip:SetInventoryItem`, `GetItemInfo`, `GetItemInfoInstant`, `C_Item` reads, and direct request APIs support equipment display and scanning. No inspected Chonky source chains any of these calls to `ItemEventListener:AddCallback`; only the two explicit ItemMixin continuations above do so. |

Retail 12.1 selects Chonky's Midnight Season 2 data. A static count of the traversed tables gives:

| Source group | Potential `AddItemToMaster` calls |
| --- | ---: |
| Eight dungeons | 210 |
| The Venomous Abyss | 80 |
| The Tidebound Grotto | 13 |
| Season 2 class sets | 65 |
| **Total** | **368** |

The 368 calls contain 367 unique item IDs because item `159388` occurs twice. Raid calls remain conditional on `EJ_GetInstanceInfo` and `EJ_GetEncounterInfo`; dungeon and class-set calls do not have those Encounter Journal gates.

### INFERENCE / WORKING HYPOTHESIS: `startupEntries=353`

The Chonky-only V3 capture observed 353 callbacks still present before RetailUIResearch's first file. Chonky's file-scope mass registration is the direct source mechanism and the correct magnitude to explain that population. The numbers need not be equal:

- Chonky can attempt up to 368 registrations for the selected tables;
- `ContinueOnItemLoad` can complete synchronously for already-cached item data, in which case `AddCallback` fires and clears the bucket before the Chonky file continues;
- raid instance/encounter gates can omit some potential calls; and
- V3 counts callback entries still outstanding at its later startup boundary, not every earlier registration attempt.

The 15-entry difference between 368 potential calls and 353 outstanding entries cannot be assigned to particular cached items or Encounter Journal gates from static source alone. The audit does not support interpreting 353 as a hard-coded table size.

### VERIFIED FROM SOURCE AND RUNTIME: item `268203` attribution

`core/gearDB.lua` explicitly lists item `268203` as loot for encounter `2888` in `CCS.Raid.TheVenomousAbyss`. The Retail 12.1 Season 2 table includes that raid, and the raid traversal passes the item to `AddItemToMaster` when its instance and encounter gates succeed. The Chonky-only runtime snapshot confirmed an outstanding callback for the item; the later early-observer stack and exact same-session function-identity match attributed the instrumented callback to this path.

This is category D: Chonky independently knows the same numeric ID from its static raid-loot database. It does not create the Item from main-hand slot 16, obtain the ID from the equipped weapon, or depend on tooltip side effects. The registration itself occurs with or without a temporary enchant and without an explicit Blizzard-addon load; the deferred body separately assumes that the deprecated `GetItemInfo` compatibility global is available. Slot 16 is relevant only because the equipped weapon happened to share an ID already in Chonky's selected database.

This makes Chonky's `AddItemToMaster` continuation the source- and runtime-identified callback in the instrumented `268203` delivery window:

- **Proven source capability:** Chonky's selected static data contains `268203`, and its file-load traversal normally issues the supported continuation when the raid gates pass.
- **Strong runtime consistency:** adding only Chonky changed the snapshot from zero entries to 353 and restored a one-entry `268203` bucket.
- **Proven same-session identity:** the early observer captured the `core/gearDB.lua:1416` stack, and its function identity matched V3 startup and pre-fire records before the same-window line-76 report.
- **Narrow execution result:** the matched Chonky callback is the body supplied to the observed dispatch. The newest internal marker sequence proves that body completed in a failing startup, so bucket ownership is not error ownership and no Chonky-body fix is justified.
- **No direct enchant dependency:** the body does not read temporary-enchant state. Its presence with Oil OFF and successful delivery in the Chonky-only Oil-ON run rule out registration alone and direct Oil input as complete explanations.

### VERIFIED FROM CHONKY AND BLIZZARD SOURCE: exact callback body and call surface

`AddItemToMaster` first evaluates `CCS.MasterLoot[itemID] or {}`, calls `Item:CreateFromItemID(itemID)`, and calls `item:ContinueOnItemLoad(callback)`. Those two method calls are registration-time operations, not deferred callback-body candidates. The local `item` is not referenced by the closure and is not captured.

The deferred body at `core/gearDB.lua:1416-1518` has nine direct call expressions in source order:

| Order | Exact call expression | Execution for item `268203` |
| ---: | --- | --- |
| 1 | `C_Item.GetItemInfo(itemID)` | Always. Its returned values populate item display fields; several returned locals are not subsequently read. |
| 2 | `GetItemInfo(itemID)` | Always. This is the deprecated compatibility global, resolved at callback execution. |
| 3 | `select(12, GetItemInfo(itemID))` | Always. `select` receives the prior nested call's returns and extracts numeric class/subclass IDs. |
| 4 | `C_Item.GetItemStats(link)` | Only when the first call returned a non-nil `link`. |
| 5 | `table.insert(primary, "STR")` | Only when `stats["ITEM_MOD_STRENGTH"]` is truthy. |
| 6 | `table.insert(primary, "AGI")` | Only when `stats["ITEM_MOD_AGILITY"]` is truthy. |
| 7 | `table.insert(primary, "INT")` | Only when `stats["ITEM_MOD_INTELLECT"]` is truthy. |
| 8 | `EJ_GetInstanceInfo(container.ejID)` | For `268203`, yes: the static Venomous Abyss table has no `instanceName`. |
| 9 | `EJ_GetEncounterInfo(boss.id)` | For `268203`, yes: encounter `2888` has no static `boss.name`. |

No function returned by an earlier call is later invoked. No iteration helper, callback stored in an upvalue, or later-defined Chonky helper executes inside the body. The remaining executable expressions are:

- numeric equality tests for armor class/subclass;
- short-circuit tests for `link`, `stats`, seven stat keys, `container.instanceName`, `boss.name`, `name`, the equipment-location mapping, and `entry.seasons`;
- four writes to a fresh `secondary` table when secondary-stat keys are present;
- writes of item, slot, armor, class, source, season, and placeholder runtime data into `entry`;
- construction of the `primary`, `secondary`, `entry.source`, `entry.runtime`, and nested runtime-stat tables;
- the fallback concatenation `"Item " .. itemID` when `name` is nil;
- `CCS.EQUIPLOC_TO_SLOTID[equipLoc] or 0`;
- `entry.seasons[seasonName] = true`; and
- the final `CCS.MasterLoot[itemID] = entry` publication.

The complete non-call expression walk is:

| Source line(s) | Expression and branch effect |
| --- | --- |
| 1421-1422 | Assign nine locals from the first item-info call. `quality`, `ilvl`, `req`, `classStr`, `subclassStr`, and `stack` are not subsequently read. |
| 1425 | Evaluate the nested compatibility call first, then pass all returns plus literal `12` to `select`; assign the first two selected returns. |
| 1432-1445 | Initialize `armorType=nil`; compare `itemClassID` with `4`, then `itemSubClassID` with `1` through `4`, assigning one armor string on a match. |
| 1451 | If `link` is truthy, evaluate the stats call; otherwise assign nil. |
| 1452-1453 | Construct fresh plain `primary` and `secondary` tables. |
| 1455-1458 | If `stats` is truthy, read each of the three primary-stat keys and conditionally execute the corresponding insertion. |
| 1460-1463 | Read four secondary-stat keys and conditionally write `CRIT`, `HASTE`, `MASTERY`, or `VERS=true` into `secondary`. |
| 1469 | Read `container.instanceName`; if falsy, read `container.ejID` and execute the instance call. |
| 1470 | Read `boss.name`; if falsy, read `boss.id` and execute the encounter call. |
| 1475-1485 | Write captured/result values into `entry`; the name fallback concatenates a fixed string with captured numeric `itemID`, and slot mapping reads `CCS.EQUIPLOC_TO_SLOTID[equipLoc]` before falling back to zero. |
| 1487-1494 | Construct and assign `entry.source` from `container.type`, `container.ejID`, `container.classID`, the resolved names, and `boss.id`. |
| 1496-1497 | Reuse `entry.seasons` if truthy or construct a new table, then write key `seasonName=true`. |
| 1502-1515 | Construct and assign the fixed placeholder `entry.runtime` table and its nested numeric stat table. |
| 1517 | Resolve the captured `CCS` table's current `MasterLoot` field and assign `entry` at numeric key `itemID`. |

### VERIFIED FROM SOURCE: exact lexical captures and mutation window

Under the source's lexical scoping, the continuation captures exactly six outer values. Globals used by the body are resolved through the function environment when it executes; they are not lexical upvalues.

| Captured name | Expected type and initialization | Mutability/exposure between registration and delivery |
| --- | --- | --- |
| `itemID` | Number parameter to `AddItemToMaster`; `268203` comes from the sole literal occurrence at `gearDB.lua:1073`. | Numbers are values and this parameter is never reassigned. |
| `container` | The `CCS.Raid.TheVenomousAbyss` table passed by the raid loop. | Captured by reference. `raid.type="raid"` is set before the item loop. No later Chonky write to this raid table or its fields was found. |
| `boss` | The static encounter-`2888` table within that raid. | Captured by reference. No Chonky write to `boss.id`, `boss.name`, or the loot container was found. |
| `seasonName` | String read from the selected Season 2 `seasonData.seasonName`. | Strings are values and the parameter is never reassigned. A nil key would cause a table-index error at line 1497, not a nil-call error. |
| `entry` | For the first and only `268203` source occurrence, a fresh `{}` from `CCS.MasterLoot[itemID] or {}` while `CCS.MasterLoot` has just been reset. | The reference is held only by the closure until its final publication at line 1517. Normal addon code has no reference to mutate before completion. |
| `CCS` | Local reference to `ns.CCS`, created in `core/localization.lua` and localized at `gearDB.lua:6`. | The namespace table is mutable, but the closure retains the table reference rather than re-resolving a global. The body reads its `EQUIPLOC_TO_SLOTID` and `MasterLoot` fields at execution. |

The closure does not capture `item`, `AddItemToMaster`, `BuildMasterLoot`, `seasonData`, `L`, `ns`, `addonName`, `locale`, `tocversion`, or `playerLevel`. Its late-bound global/table-member call dependencies are `C_Item.GetItemInfo`, `GetItemInfo`, `select`, conditional `C_Item.GetItemStats`, conditional `table.insert`, `EJ_GetInstanceInfo`, and `EJ_GetEncounterInfo`.

The focused mutation audit found `CCS.MasterLoot = {}` only at `gearDB.lua:36`; later source reads it and callback completions add keyed entries, but no Chonky code reassigns the table. `CCS.EQUIPLOC_TO_SLOTID` is assigned once in the earlier-loaded `core/tables.lua:2833-2857` and is not reassigned. Season 2 data is constructed in `gearDB.lua`; `BuildMasterLoot` adds only `type` fields before entering each relevant item loop and adds class-set metadata on the separate class-set tables. `CCS.Season` later receives a reference to the already-selected season table, not a replacement of captured raid/boss objects. The only Chonky `setmetatable` outside embedded libraries is for the localization table `L`; none applies to `CCS`, `MasterLoot`, the equipment-location map, season/raid/boss data, or `entry`.

The callback's elapsed wait therefore does not expose a source-visible Chonky reinitialization of its captured dependencies. `CCS.MasterLoot` contents do change as other item callbacks finish, but that does not change the captured `entry` or create a callable. A foreign mutation would first need access to Chonky's private namespace or captured objects; no such path is established.

### VERIFIED LANGUAGE/SOURCE ANALYSIS: indirect and metamethod call paths

Lua can invoke code indirectly through metatables, but the concrete operands sharply limit that surface:

| Expression class | Possible implicit call | Assessment here |
| --- | --- | --- |
| Global resolution (`C_Item`, `GetItemInfo`, `select`, `table`, `EJ_*`) | A function-environment `__index` could run for a missing key if the environment had such a metatable. | No such environment mutation is established. The observer directly resolved every relevant callable as a function at registration and pre-fire. |
| Member reads (`C_Item.GetItemInfo`, `table.insert`, `CCS.*`, `container.*`, `boss.*`) | `__index` can run only for an absent key on a table with a metatable. | No Chonky metatable is attached to any captured/static table. The callable member reads were valid at pre-fire. |
| Stat reads (`stats[key]`) | A metatable supplied on the API-returned table could provide `__index`. | Generated API documentation establishes a table result or no result, not its metatable internals. No source or runtime evidence shows such a metatable; this is possible in language terms but weak and unproven. |
| Writes to `entry`, `secondary`, `entry.seasons`, or `CCS.MasterLoot` | `__newindex` can run for absent keys on a table with a metatable. | `entry`, `secondary`, and newly created `entry.seasons` are plain constructors; `CCS.MasterLoot` is a plain constructor. No relevant `setmetatable` exists in Chonky source. |
| `"Item " .. itemID` | `__concat` can run when ordinary string/number concatenation cannot handle an operand. | The left operand is a string and captured `itemID` is the numeric literal `268203`; native concatenation applies. |
| Numeric equality tests | `__eq` is relevant only for compatible table/userdata operands. | The API class IDs are expected numbers or nil and are compared with number literals; no realistic metamethod call exists. |
| `and`, `or`, `if`, table constructors, and assignments to existing plain tables | None. | These operations introduce no hidden callable. |

An absent `__index` or `__newindex` metamethod does not itself mean Lua “calls nil”; ordinary indexing simply returns nil and ordinary assignment stores the value. A present metamethod could itself raise a nested nil-call error, but no relevant metatable was found. The callback has no arithmetic expression that could invoke an arithmetic metamethod.

### PRE-HANDLER-WRAPPER RUNTIME ASSESSMENT: callable snapshots and ranked hypotheses (historical)

This ranking predates the fresh active-handler entry/return evidence and is retained as investigation history; the fresh handler-wrapper reconciliation above is current. At both registration and the matching failing pre-fire, every visually obvious callable was a function with the same observed identity. The fallback CVar was true and the deprecated item script was loaded. This strongly contradicts a simple absent or replaced `GetItemInfo`, `C_Item.GetItemInfo`, `C_Item.GetItemStats`, `EJ_GetInstanceInfo`, `EJ_GetEncounterInfo`, `select`, or `table.insert` at those observation points. It does not inspect what those functions call internally or secure post-hooks that execute without changing the observed function identity.

A focused static scan of the installed Retail addon tree covered 13,032 Lua files. It found no explicit `_G` assignment, `rawset`, or matching `setfenv` write to the callback's callable dependencies and no literal `hooksecurefunc` attachment to the specific `GetItemInfo`, `GetItemStats`, `EJ_GetInstanceInfo`, or `EJ_GetEncounterInfo` functions. The follow-up scan also found no literal global `xpcall` assignment, `_G.xpcall` write, literal secure hook of global `xpcall`, or literal hook/assignment of `CallErrorHandler`. This is negative source evidence only: dynamically named hooks, generated/runtime code, native secure hooks, or a different enabled version are not excluded, and no addon is implicated.

After the complete target marker sequence, the remaining categories rank as follows:

1. **Temporal/report correlation is incomplete.** The marker table proves one instrumented `268203` closure completed, while the pre-fire record proves which closure occupied one target bucket immediately before one dispatch. The supplied excerpt does not itself add a timestamped error-handler-entry record tying the stored BugGrabber error to that exact protected call. BugGrabber's source also proves that identical same-session messages reuse the first stored stack/locals rather than refreshing them. A separate line-76 occurrence, repeated error record, or otherwise mispaired display is therefore the strongest source-supported reconciliation, even though the matching pre-fire evidence makes the timing window narrow.
2. **Additional code associated with the outer `xpcall` invocation fails after the callback returns.** A replacement/wrapper around global `xpcall`, or a secure post-hook attached to it, could invoke the real protected call, allow the callback to reach `CALLBACK-END`, and then attempt a nil call before the line-76 call expression finishes. This mechanism exactly fits Lua control flow, but the installed-source scan found no literal implementation and the current snapshot records only `xpcall` type/security, not a baseline/current identity or attached-hook inventory.
3. **Native or secure-hook behavior below the mirrored Lua source boundary.** `xpcall`, `hooksecurefunc`, stack-height APIs, and error-handler installation are native runtime facilities. The Lua mirror does not expose their implementation or enumerate installed secure hooks. This category cannot be eliminated from source, but there is no affirmative evidence for a defect in those facilities.
4. **A secondary failure inside `CallErrorHandler` or BugGrabber obscures an earlier protected error.** The handler performs several unprotected function calls and BugGrabber performs substantial work before returning. Such a secondary error can prevent cleanup and potentially preserve line-76 attribution. It is not a standalone explanation for the completed callback: normal `xpcall` never enters `CallErrorHandler` after a successful protected return. It becomes relevant only if category 1 or an unobserved protected error first caused handler entry.

The complete marker trace eliminates the prior leading categories for this execution: no direct Chonky callee or attached code failed before returning to its matching `AFTER`; no observed data-shape branch failed; the entry and relevant table operations completed; `CCS.MasterLoot` publication completed; and no later Chonky statement remains after `CALLBACK-END`. A nil `xpcall` value is also impossible for this same invocation because it would fail before the callback began. A nil/non-callable callback is contradicted by both the bucket and actual execution. A nil `CallErrorHandler` cannot matter on a successful callback path. Callback return values are discarded and cannot be called. Cleanup of the detached array occurs on later source lines and contains no function call capable of being reported as the line-76 nil call under ordinary flow.

The earlier compatibility-global hypothesis is retained only as historical reasoning: `Blizzard_DeprecatedItemScript/Deprecated_ItemScript.lua:42` conditionally defines `GetItemInfo`, yet the runtime observed the fallback enabled, the addon loaded, the callable present at pre-fire, and the instrumented call returning. Malformed `callbacks[1]`, direct Oil input, zero duration as a requirement, OUS necessity, the later Zygor callback, and a failing Chonky body are contradicted as explanations of this exact completed invocation.

The redundant deprecated call is avoidable in principle: generated documentation for `C_Item.GetItemInfo` includes numeric `classID` and `subclassID` returns, which are the only values Chonky takes from the second call. That is an engineering observation only; this research task does not modify Chonky or assert that removing the call would fix the intermittent failure.

### ESTABLISHED ITEM ID; VERIFIED CHONKY SOURCE BOUNDARY: `275218`

Item `275218` is Mertei's Command Baton. An exact search across the supplied Chonky 2.3.16 Lua, XML, and TOC files found no occurrence of that ID. Chonky's two `ContinueOnItemLoad` callsites therefore provide no static path that registers a startup continuation for it in this source snapshot. The latest OUS-disabled observation found the item in bags, recorded a Zygor bag-upgrade continuation for it, and recorded no Chonky registration. This confirms that multiple independent addons can create item continuations for currently relevant items; it does not attribute the earlier `275218` failure to Zygor or explain why that failure followed the equipped weapon. The earlier reproduction remains unresolved and separate from the proven Chonky `268203` path.

### VERIFIED FROM CHONKY SOURCE: temporary-enchant display

Chonky does not parse an item tooltip to obtain the displayed weapon-coating name. `core/utils.lua:2163-2185` handles the main slot-rendering path, `core/utils.lua:2670-2715` handles later refreshes, and both use this pipeline:

1. call the deprecated global `GetWeaponEnchantInfo()` for main-hand/off-hand state;
2. use the returned numeric enchant ID as a key in the static `CCS.tempenchantLookup` table;
3. obtain the mapped spell ID; and
4. call `C_Spell.GetSpellName(spellID)` for localized display text.

`core/tables.lua:2674-2813` defines the static mapping. Line 2800 explicitly maps enchant ID `8052` to spell ID `1237006` and comments that entry as `Thalassian Phoenix Oil (T2)`. Thus Chonky source directly uses `8052` and can display the localized spell name returned for `1237006`. The user-observed label “Thalassian Phoenix Oil” is consistent with that mechanism. The comment is third-party data, not Blizzard-authoritative proof of a universal enchant-product mapping, and the table itself warns that its mappings are not intended to be completely accurate. Its original data provenance is not documented in the inspected files.

The primary slot rendering path and `CCS:UpdateTempEnchantDisplay()` both use the same lookup. `Retail/characterSheet.lua:1133-1137` starts a one-second ticker while the Character Frame is shown to refresh the temporary-enchant name and remaining time; lines 1296-1305 cancel that ticker when the frame hides. This polling is part of Chonky's display implementation, not part of its gear-database callback registration.

### VERIFIED FROM BLIZZARD SOURCE: deprecated wrapper boundary

The current Retail deprecated `GetWeaponEnchantInfo()` wrapper obtains each slot's state from `C_PaperDollInfo.GetTemporaryEnchantmentInfo(slot)` and returns the documented boolean, remaining milliseconds, charges, and enchant ID values in the older multi-return form. `C_Spell.GetSpellName` supplies a localized name or nil. Chonky therefore owns the static enchant-ID-to-spell-ID association, while Blizzard APIs supply current slot state and localized spell text.

### ENGINEERING ASSESSMENT: conceptual reuse

The pattern is conceptually viable when a consumer needs a friendly localized name and is prepared to maintain an explicit enchant-ID-to-spell-ID mapping. It does not remove the maintenance risk: new, changed, or incorrect mappings can produce missing or wrong names, and no inspected API directly converts every temporary-enchant ID to a canonical spell ID. A future production design should treat the mapping as curated compatibility data, preserve an unknown fallback, and validate target locales. This is an assessment, not a recommendation to copy Chonky's table or implementation.

### VERIFIED FROM CHONKY SOURCE: LibDeflate and WeakAuras ancestry

LibDeflate is used for Chonky profile export/import: serialized profile text is compressed and print-encoded, then decoded and decompressed on import. A test helper checks that round trip. No non-library LibDeflate call is involved in `gearDB.lua`, item continuations, the temporary-enchant lookup, or spell-name display, and no bundled compressed item/enchant payload was found.

The only located WeakAuras references are comments beside a visual texture in `core/utils.lua`, `Modules/MOP.lua`, and `Modules/TBC.lua`: “last remnant from WeakAuras.” No `aura_env`, WeakAuras API, trigger/state system, or compressed WeakAura payload was found. The inspected architecture is an ordinary addon namespace with tables, modules, frames, and event handlers. Source therefore supports limited visual ancestry, not a WeakAura-derived explanation for the mass item callbacks or enchant lookup.

### ENGINEERING ASSESSMENT: earlier observer design

A separate, very small observer addon loaded after `Blizzard_ObjectAPI` but before Chonky can install the existing passive `ItemEventListener:AddCallback` post-hook before `core/gearDB.lua` runs. It prominently reports item `268203`, preserves its registration stack and callback identity, and allows comparison with the later pre-fire bucket. It does not wrap, invoke, replace, cancel, or suppress the callback.

The observer uses current Retail `## Interface` metadata, `## Dependencies: Blizzard_ObjectAPI`, no `LoadOnDemand`, and its hook installer as its first Lua file. The dependency ensures that `ItemEventListener` exists before the observer; the observer must then finish before Chonky reaches `core/gearDB.lua`.

Ordering is the constraint. Chonky declares no dependency on such an observer, so a separate addon's TOC cannot create a hard dependency edge that forces itself before Chonky. An early-sorting folder name may be a practical experiment for otherwise independent enabled addons but is insufficient as proof of guaranteed ordering; the observer must record its own and Chonky's `ADDON_LOADED` sequence. Requiring Chonky to depend on the observer would guarantee the edge but would modify third-party metadata and is outside the authorized boundary. `LoadFirst: 1` exists on Blizzard-owned TOCs, including `Blizzard_FrameXML`, but Chonky does not declare it and the inspected Lua does not define it as a third-party relative-ordering contract. Existing Blizzard early-load behavior helps by making ObjectAPI available; it does not prevent a normal observer from running before Chonky. No V4 change to RetailUIResearch is justified: RetailUIResearch necessarily starts too late for this registration.

### IMPLEMENTED OBSERVER: Case-3 LIVE result and completed BugGrabber-independent checkpoint

`Samples/!AsyncItemCallbackObserver/` contains a separate experimental addon. Its leading `!` is intended to place it before `!BugGrabber` and Chonky among otherwise independent addons, while `## Dependencies: Blizzard_ObjectAPI` ensures that `ItemEventListener` already exists. It is not LoadOnDemand and preserves only the file-scope `AddCallback` and `GetCallbacks` post-hooks. The now-exhausted name-based `CallErrorHandler` post-hook has been removed because LIVE testing proved that registering it was the exact synchronous boundary across which `_G.CallErrorHandler` identity changed. AICO captures the untouched original global before its item-observer hooks and verifies that identity through the revised lifecycle checkpoints. In Case 3 the identity remained stable, the direct wrapper installed at G, and the later active BugGrabber-handler invocation bypassed it. AICO's BugGrabber-off branch wraps the pre-existing active handler at first initial-login `PLAYER_ENTERING_WORLD` only when the current-character enable-state query proves BugGrabber disabled. Logs_17 and Logs_18 subsequently exercised and validated that branch. Alphabetical placement is not treated as a guaranteed dependency edge; the observed event order remains authoritative.

The observer records a sequential registration number, precise/fallback timestamp and observer-relative elapsed time, item ID, callback type and session-local `tostring` identity, guarded security/taint information when the callback remains mapped after return, bounded registration stack, and explicitly labeled load/lifecycle context. A 128-entry generic window rotates, while target IDs `268203` and `275218` each retain their own first 16 registrations and first 32 pre-fire candidates with explicit drop counts.

The enhanced `/aico` snapshot retains the first 512 `ADDON_LOADED` events observed after observer installation, including exact order, timestamp, and elapsed time, and reports any later drops. It separately reports observer installation, the relevant addon-load milestones, `PLAYER_LOGIN`, and the first `PLAYER_ENTERING_WORLD` with `initialLogin`/`reloadingUi` flags. It also enumerates current `C_AddOns` data and lists only addons whose exact `loaded` return is true; that inventory is labeled as snapshot-time state and does not rely on memory-consumption data.

For target registration and `GetCallbacks` pre-fire observations, the observer records guarded type, function identity, and secure/taint state for global `GetItemInfo`, `C_Item.GetItemInfo`, `C_Item.GetItemStats`, `EJ_GetInstanceInfo`, `EJ_GetEncounterInfo`, `select`, `table.insert`, `GetCVarBool`, and `C_AddOns.IsAddOnLoaded`. It also records the result of `GetCVarBool("loadDeprecationFallbacks")` and both loaded/loading results for `Blizzard_DeprecatedItemScript`. Observing `GetItemInfo` is justified by its conditional compatibility definition, but neither presence nor absence at one snapshot by itself proves the root cause.

The supplied runs verified that the observer loaded before Chonky. It recorded `ItemMixin:ContinueOnItemLoad` -> `core/gearDB.lua:1416` -> `AddItemToMaster` line 1412 -> raid traversal line 1557 -> file-scope build line 1590 for item `268203`. The callback identity matched V3's sole startup/pre-fire identity in the same session. In the failing run, `function: 0000022B022325A0` occupied that sole pre-fire slot before the same-window line-76 report. This closes registration attribution for that run without treating the error record as proof that the callback body failed. Function identity strings remain session-local and are expected to change after restarting the client.

The minimal observer/Chonky run was clean, and a minimal Chonky+Zygor run was also clean. Fuller addon startup reproduced the failure while retaining the same Chonky provenance; a later, distinct Zygor callback completed successfully. The enhanced timeline, inventory, lifecycle, registration-time callable, and target pre-fire fields have now also been exercised on Retail LIVE. In a failing run they showed every listed callable still present as a function with stable identity, the fallback CVar true, and `Blizzard_DeprecatedItemScript` loaded. The later target instrumentation showed every Chonky operation completing. Fresh active-handler-wrapper runs recorded retained BugGrabber returning normally while the former passive `CallErrorHandler` post-hook remained silent. The corrected direct wrapper then installed successfully in Case 3 but received no entry, while the active handler received and returned from the exact error. Logs_17 and Logs_18 later reproduced the exact occurrence with BugGrabber and BugSack absent; Logs_18 also placed active-handler delivery after normal tracked `FireCallbacks` exit with no direct global-wrapper entry. Log_19 then reproduced with Chonky absent, and authoritative Log_20 reproduced with both Chonky and Zygor absent, zero target registrations, and a nil failure-adjacent target bucket. Authoritative Log_21 retained the same complete loaded-addon name inventory with the temporary enchant absent; it observed one nil target dispatch and no B, C, repeat, or error. Log_22 reproduced the Log_20 ordering with Oil of Dawn/runtime enchant `8053`. Log_23 reproduced the higher-level C-without-B shape on a different main-hand item with runtime enchant `5400`, but did not retain the corresponding target-specific structural sequence. Log_24 retained that Shaman's weapon IDs and the exact 165-name inventory with both weapons unenchanted; its nil-bucket `246664` episode completed with no B, C, boundary, or error record. Log_25 restored runtime enchant `5400` with the same weapons and exact ordered inventory, reproduced the line-76 occurrence, and again retained only the higher-level C-without-B/no-open-at-C pattern rather than the item-specific structural exit. Log_26 preserved the same enchanted weapons, removed exactly the six-folder profession/economy continuation group to 159 loaded names, and reproduced the same higher-level boundary shape. Log_27 then removed only QuickCrafts, retained enchant `5400`, and was clean; Log_28 restored QuickCrafts and the exact Log_26 inventory/order and reproduced the higher-level C-without-B/no-open-at-C shape. Earlier callback provenance and completion are established for their sessions, but neither known owner, item `268203`, Phoenix Oil, enchant `8052`, the Oil mechanism class, a repeat, direct target registration, nor the profession/economy continuation group as a whole is required for reproduction. Temporary-enchant state is not sufficient. QuickCrafts is an observed selector so far in the tested reduced ABA branch, not a proven cause or globally necessary component. The delivery mechanism and remaining runtime cofactor remain unresolved.

Logs_33/34 subsequently completed the reduced Chonky add-back and reproduced with OBB retained. Logs_35-40 then supplied three exact OBB ON/OFF pairs across two reduced families and the full normal profile: OBB ON reproduced in Logs_35/38/40, while the exact projected OBB-OFF partners Logs_36/37/39 were clean. Each OBB-ON capture also added exactly one equipped-main-hand `246664` nil-bucket PREFIRE/COMPLETE episode. These results supersede QuickCrafts as the leading selector without assigning causation: QuickCrafts is absent from Logs_35/38 and present in clean Log_39, whereas an uncaptured minimal Chonky+OBB+BugGrabber startup was clean and therefore argues against OBB+Chonky sufficiency.

Logs_41-44 completed the provider split and replacement validation. Log_41 kept OBB loaded, disabled only the old managed MainHand/OffHand providers, and was clean with valid BugGrabber-off controls. Log_42 restored those providers and reproduced in the same controlled environment. Logs_43 and 44 replaced them with OBB-owned ordinary rows and were both clean, while Chonky's `268203` callback and another consumer's `246664` item-loading path continued to open and normal-exit. The old managed provider branch is now the strongest verified feature-level selector; the exact failing callback and underlying runtime mechanism remain unidentified.

The observer's two item-listener post-hooks and revised identity timeline remain passive. The active-handler wrapper and guarded direct global `CallErrorHandler` wrapper are deliberate diagnostic replacements. With BugGrabber enabled, the active wrapper retains BugGrabber after it loads; with BugGrabber disabled, it retains the pre-existing handler captured at first initial-login `PLAYER_ENTERING_WORLD`. Each wrapper records entry, delegates exactly once, records only normal return, and preserves an explicitly counted result list. Final unpack/return remains unobserved. Replacing either active handler or global can perturb native behavior, attribution, or reproduction. No item callback is wrapped or invoked, `FireCallbacks` remains untouched, and no callback table is mutated. There are no artificial delays, SavedVariables, timers, `OnUpdate`, or polling. A `GetCallbacks` post-hook record is a pre-fire candidate until its captured stack confirms the `FireCallbacks` caller. The bounded addon timeline starts only after observer installation and reports drops; the loaded inventory reflects `/aico` snapshot time. `ITEM_DATA_LOAD_RESULT success=true` and RetailUIResearch's `COMPLETE success=true` both describe event success, not successful execution of every callback body.

### UNKNOWN after callback attribution and complete callback execution

- Whether the stored BugGrabber line-76 record corresponds one-to-one with the exact pre-fire/`CALLBACK-END` invocation or an identical error occurrence elsewhere in the same session.
- Which composition, cache/readiness, ordering, or scheduling property combines with the old managed weapon-provider branch, given the clean uncaptured minimal Chonky+OBB+BugGrabber startup.
- Whether a runtime replacement, dynamically named secure hook, or native hook associated with the outer `xpcall` invocation executed after the Chonky callback returned.
- Which 15 potential calls had completed synchronously or were excluded by raid gates before the 353-entry Chonky-only snapshot.
- Why an identical line-76 report is produced in heavy startup when the sole instrumented Chonky callback completes, and whether the displayed BugGrabber record corresponds to that exact protected call.
- Why the earlier item `275218` reproduction followed the equipped weapon even though that ID is absent from the supplied Chonky source.
- The provenance and completeness of Chonky's curated temporary-enchant mapping.

## Answers to the focused questions

- **Why can line 76 report “attempt to call a nil value”?** The line evaluates `xpcall`, `callback`, and `CallErrorHandler`, then calls `xpcall`; a callback error is deliberately attributed to that frame by `CallErrorHandler`. The newest marker sequence rules out such an error inside the completed Chonky body for that execution. Remaining line-76 mechanisms are a different/deduplicated occurrence, additional wrapper or secure-hook code around the outer `xpcall` call, secondary handler failure after some other protected error, or native behavior absent from the Lua mirror.
- **What malformed callback-table state is required?** A plain nil hole is insufficient because standard `ipairs` stops. A nil loop value would require nonstandard iterator behavior or mutation outside the normal source lifecycle. No such state is established.
- **Can Blizzard's normal code create that nil-entry state?** No inspected normal path does.
- **How can a callback be present without a V2 `REGISTER` record?** V3 resolves this callback's timing category: it was already present before RetailUIResearch's first file. Current Blizzard source populates an item bucket only through `AddCallback`; the original registration therefore completed during a dependency or earlier addon's loading/initialization unless unsupported external mutation occurred.
- **What do 64 registrations, zero matches, and zero evictions establish?** Every one of those 64 retained V2 observations was inspected when both weapon IDs resolved; none supplied item ID `268203`, and capacity loss did not occur. V2's filter did not discard the unidentified callback in this session.
- **Can callback identity change after registration?** Normal source keeps the function unchanged. Supported cancellation replaces it with `-1`, never another function; clear/fire removes state. No source-visible function substitution, bucket restore, or bucket reuse explains the unidentified function.
- **Can an addon caller create invalid state?** Technically yes through direct internal-listener access, raw table mutation, global replacement, or a callback body that later errors. The validated `ItemMixin` continuation surface rejects non-functions.
- **What does cancellation do?** It writes `CANCELED_SENTINEL` (`-1`) in place. It does not remove entries or create holes.
- **Does the observed ID map to item ID?** In `ItemEventListener` it is exactly the item ID. The equipped temporary-enchantment source path resolves the current equipment-slot item ID, explaining why the candidate bucket follows the weapon. Confirming the failing frame is `ItemEventListener` remains a useful diagnostic field.
- **Is there a source connection to equipped weapons and temporary enchants?** Yes: managed temporary-enchantment name display can request the equipped slot's item name and register a separate item continuation when uncached. The identified Chonky `268203` callback does not use that path or read enchant/equipment state; Oil timing is indirect correlation for this callback.
- **Why can a fresh client launch differ from logout/login or reload?** It can encounter different item-cache and initialization state and defer completion where another path is already warm or synchronous. The source does not establish the mechanism behind the supplied full-client-restart distinction.
- **Is this a race condition?** No such conclusion is supported. The architecture is cache- and ordering-sensitive, but no concurrent mutation or internally reachable nil-array race was found; this document uses initialization-order or transient-state language instead.
- **Can the registrant be identified safely?** Yes for the instrumented `268203` run. The observer captured the Chonky `core/gearDB.lua` stack, and the same-session function identity exactly matched the sole pre-fire entry. This proves registrant and bucket identity, not that the completed callback generated the displayed error. Function addresses cannot be transferred across sessions.
- **Is combat or taint established?** No.
- **Can responsibility be assigned?** Only at the feature-selector level, not as root cause. Chonky registered and completed the sole observed `268203` callback in earlier failing sessions, while other failures reproduced without Chonky and Zygor. QuickCrafts selected one reduced ABA branch but was absent in later failures. Logs_35-40 established OBB as a repeatable selector, and Logs_41-44 localized that selector more narrowly: provider-disabled was clean, provider-restored errored, and two OBB-owned replacement runs were clean while other item-loading remained active. The old Blizzard-managed MainHand/OffHand provider branch is the strongest verified feature-level selector and the OBB replacement is a successful tested mitigation for that feature path. Neither OBB nor Blizzard is proven defective, and the exact failing callback, underlying runtime mechanism, global necessity, sufficiency, and universal line-76 fix remain unproven.
- **What does `512` retained plus `94` evicted mean?** V3 appended 606 startup callback-entry records. These are callback entries rather than item-ID buckets. Because the relevant `268203` entry survived, increasing the bound would not improve its attribution.
- **Does removing RetailUIResearch's ObjectAPI dependency help?** No. ObjectAPI is already an early dependency of `Blizzard_FrameXML`; without some earlier load path the listener would be absent, not newly observable. Bootstrap cannot run inside another addon's dependency-loading phase.
- **What explains the Chonky-only `startupEntries=353`?** Chonky's file-scope Season 2 gear-database build can issue 368 supported continuations over 367 unique IDs. V3 counts only the callbacks still outstanding later; synchronous cached completion and conditional raid gates explain why that count can be lower. Static source cannot allocate the 15-entry difference exactly.
- **Does Chonky use enchant ID `8052`?** Yes. Its static lookup maps `8052` to spell ID `1237006`, then calls `C_Spell.GetSpellName` for localized display text. That third-party mapping is not an authoritative Blizzard identity source.
- **Is LibDeflate involved?** No located usage connects it to items or enchants. It compresses and print-encodes profile exports and reverses that process on import.
- **What does item `275218` establish?** Item `275218` is Mertei's Command Baton and is absent from all supplied Chonky 2.3.16 Lua/XML/TOC text. In the latest OUS-disabled run it was in bags, received a Zygor bag-upgrade continuation, and had no observed Chonky registration. That demonstrates independent item-continuation producers but does not assign the earlier `275218` error to Zygor.

## Unresolved questions

1. Which native/runtime path reached the active handler without entering the verified addon-global `CallErrorHandler` wrapper?
2. What exact callback or runtime interaction beneath the old native MainHand/OffHand provider branch produced the line-76 report?
3. Is global `xpcall` identity-stable in the actual Blizzard execution environment, and does any native/dynamically named secure hook add after-return work not visible to the installed-source scan?
4. Why does the C API sometimes report a non-nil active enchant with zero duration before later returning a positive duration? Current Lua and generated documentation do not define that transition; zero is now proven unnecessary for the line-76 reproduction.
5. Which callback source produced the earlier item `275218` failure, given that ID's absence from the supplied Chonky source?
6. Which additional registrants account for the difference between the 353-entry Chonky-only startup and the 606-entry fuller environment?
7. What visible consumer state, if any, remains incomplete after the isolated line-76 report?
8. Which Chonky gear-database requests completed synchronously or were excluded by Encounter Journal gates before the 353-entry snapshot?

At earlier checkpoints, the recommended experiments were the target-only Chonky marker build and then the OBB MainHand/OffHand-provider split. Both were later authorized and completed. The Oil-of-Dawn, matched Shaman ON/OFF, full-profile Shaman ON repeat, Log_26 profession/economy continuation-group reduction, QuickCrafts ABA, Chonky add-back, three-pair OBB isolation, provider-disabled/restored split, and two production-replacement runs are complete. This checkpoint preserves those results; it does not authorize or propose another experiment.

### INSTALLED DIAGNOSTIC CHECKPOINT: callback completion LIVE-validated

The diagnostic was subsequently authorized and installed on 2026-09-04 in the active Retail Chonky Character Sheet 2.3.16 copy at `core/gearDB.lua`. The separate authoritative reference copy remains unchanged. This is controlled diagnostic instrumentation, not a production fix, workaround, or published Chonky change. A fresh full-startup failing session has now exercised it and produced the complete successful callback sequence through `CALLBACK-END`.

Instrumentation is limited to the existing `AddItemToMaster` deferred callback and activates only when that callback's captured `itemID` is exactly `268203`. Other item callbacks retain the original expressions and assignments, apart from the target comparison used to select the diagnostic path. The target path stores at most 64 ordered, file-local in-memory markers and does not print during callback execution. It marks callback entry and exit; `BEFORE`/`AFTER` boundaries for the modern and deprecated item-info calls, `select`, conditional item-stats call, individual stat-table reads, conditional stat-list inserts, Encounter Journal lookups, container/boss/map reads, entry assignment groups, source/seasons/runtime assignments, and final `MasterLoot` publication; and explicit branch/skip states. Returned values are represented only by their Lua types or relevant branch state. The marker capacity exceeds the deterministic maximum for one target callback execution, so the expected run does not rotate or discard earlier target markers.

The deprecated `GetItemInfo` plus `select(12, ...)` expression requires a small target-only helper boundary so the two nested calls can receive distinct markers without repeating the item query. The helper forwards the original complete return list to the original `select` operation. The callback itself remains the function registered through `ContinueOnItemLoad`; no Blizzard callback infrastructure, callback table, callback identity, return value, delay, retry, or error handler is wrapped or replaced. There is no `pcall` or `xpcall` around any tested expression, so a failure still stops the callback at the failing boundary and propagates to Blizzard's existing protected delivery path. The marker writes and target check add a small timing effect, which must be considered when comparing clean and failing sessions.

After reproducing the login outcome, retrieve the retained sequence with exactly:

```text
/run print(AICD_CHONKY_268203_GetLog())
```

The getter is read-only: it returns the retained markers as newline-separated text and does not clear or mutate them. In the completed run, every `BEFORE` marker had its matching `AFTER` marker and `CALLBACK-END` established that the instrumented Chonky body returned through its last source operation. This result is runtime evidence about one instrumented composition and must not be generalized into a production fix. The standalone observer's direct `CallErrorHandler` test subsequently produced Case 3; Logs_17 and Logs_18 then exercised its BugGrabber-independent first-world-entry handler checkpoint. No additional Chonky-body markers were added.

## Primary LIVE source index

- `Interface/AddOns/Blizzard_ObjectAPI/Blizzard_ObjectAPI_Mainline.toc`
- `Interface/AddOns/Blizzard_ObjectAPI/Mainline/ContinuableContainer.lua`
- `Interface/AddOns/Blizzard_ObjectAPI/Mainline/AsyncCallbackSystem.lua`
- `Interface/AddOns/Blizzard_ObjectAPI/Mainline/Item.lua`
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua`
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua`
- `Interface/AddOns/Blizzard_APIDocumentationGenerated/PaperDollInfoDocumentation.lua`
- `Interface/AddOns/Blizzard_DeprecatedItemScript/Blizzard_DeprecatedItemScript.toc`
- `Interface/AddOns/Blizzard_DeprecatedItemScript/Deprecated_ItemScript.lua`
- `Interface/AddOns/Blizzard_FrameXML/Blizzard_FrameXML.toc`
- `Interface/AddOns/Blizzard_SharedXMLBase/AddOnUtil.lua`
- `Interface/AddOns/Blizzard_SharedXMLBase/ErrorUtil.lua`
- `Interface/AddOns/Blizzard_ScriptErrors/Blizzard_ScriptErrors.lua`
- `Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua`
- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainer.toc`
- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainer.lua`
- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerEnchantments.lua`
- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua`
- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerShared.lua`
- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua`
- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua`
- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.xml`
- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua`
- `Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.xml`

## Read-only Chonky source index

- `ChonkyCharacterSheet.toc`
- `core/localization.lua`
- `core/tables.lua`
- `core/wrappers.lua`
- `core/utils.lua`
- `core/styles.lua`
- `core/gearDB.lua`
- `core/core.lua`
- `core/events.lua`
- `core/options.lua`
- `Retail/characterSheet.lua`
- `Retail/mythicPlusStats.lua`
- `Modules/MOP.lua`
- `Modules/TBC.lua`
- `CREDITS.txt`

## Local error-handler source index

- `Interface/AddOns/Blizzard_SharedXMLBase/ErrorUtil.lua`
- `Interface/AddOns/Blizzard_ScriptErrors/Blizzard_ScriptErrors.lua`
- `Interface/AddOns/Blizzard_PrintHandler/Blizzard_PrintHandler.lua`
- `Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedFrames.lua`
- `Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua`
- `!BugGrabber/BugGrabber.lua`
- `BugSack/core.lua`
