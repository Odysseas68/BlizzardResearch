# Async Item Callback Observer

## Purpose

`!AsyncItemCallbackObserver` is a temporary, standalone Retail research addon for the existing `AsyncCallbackSystem` equipped-item investigation. It preserves the passive `ItemEventListener:AddCallback` and `GetCallbacks` post-hooks and uses one bounded active error-handler wrapper in either of two modes: it wraps BugGrabber after that addon loads, or, when `C_AddOns.GetAddOnEnableState` confirms that BugGrabber is disabled for the current character, it wraps the pre-existing handler chain at first `PLAYER_ENTERING_WORLD`. The former name-based `CallErrorHandler` post-hook has been removed because LIVE evidence proved that its native registration changed `_G.CallErrorHandler` identity. For one controlled BugGrabber-off provenance run, AICO now installs its retained direct `CallErrorHandler` entry/return wrapper only after the fallback active-handler wrapper is verified and BugSack is verified not loaded or loading. One `/aico` snapshot combines registration provenance, target pre-fire callable state, target-centered boundary snapshots, identity checkpoints, bounded wrapper records, the bounded post-install addon-load timeline, lifecycle milestones, and the exact currently loaded-addon inventory.

This is diagnostic instrumentation retained as a reproducible research sample, not a workaround or shippable production behavior. Runtime use identified Chonky's callback body in instrumented failing sessions, and target-only markers showed that body completing through `CALLBACK-END`. The displayed line-76 error therefore cannot be assigned to that successful callback body under normal `xpcall` semantics. In Case 3, AICO's direct global `CallErrorHandler` wrapper was verified installed but recorded no entry, while the active BugGrabber-handler wrapper recorded one fresh entry and normal return about `0.463ms` after the target lookup. Later Logs_41-44 used the same observer to complete the OBB provider split: disabled was clean, restored errored, and two runs with OBB-owned replacement rows were clean. This localizes the strongest verified feature-level selector to the old managed provider branch without proving the underlying root cause.

## Load-order design

The leading `!` gives the folder an early alphabetical position among otherwise independent addons. Alphabetical position is an experimental strategy, not a guaranteed dependency edge. The TOC declares:

```text
## Dependencies: Blizzard_ObjectAPI
```

This ensures `ItemEventListener` exists before `Observer.lua` executes. It also means Blizzard ObjectAPI and any earlier dependencies load before the observer can begin recording. Chonky does not depend on this observer, so each test must verify the captured `ADDON_LOADED` timeline rather than assume alphabetical ordering.

For BugGrabber-on runs, the expected tracked order is:

1. `!AsyncItemCallbackObserver`
2. `!BugGrabber`
3. `ChonkyCharacterSheet`
4. `RetailUIResearch`

The observer retains the first 512 `ADDON_LOADED` events it sees after installation, with sequence, absolute timestamp, and observer-relative elapsed time, plus an explicit drop count. The actual captured order is authoritative when the drop count is zero. If `!BugGrabber` is enabled and loads before the observer, the native setter was not captured before BugGrabber's replacement and the wrapper run is invalid. In BugGrabber-off runs, `/aico` must instead report `bugGrabberEnabledForCharacter=false`, target `pre-existing handler at PLAYER_ENTERING_WORLD; !BugGrabber disabled`, `installTrigger="first PLAYER_ENTERING_WORLD"`, and an installed active-handler wrapper. The fallback is attempted only on initial-login world entry, not on a reload or later zone transition. If Chonky appears before the observer, the run cannot attribute Chonky's file-load registration.

## Evidence captured

The observer keeps its existing item registration/pre-fire post-hooks and adds a bounded structural probe to the three concrete listeners created by current Retail source:

```lua
hooksecurefunc(ItemEventListener, "AddCallback", CaptureRegistration)
hooksecurefunc(ItemEventListener, "GetCallbacks", function(listener, itemID)
    -- Passively capture target bucket and callable state.
end)
InstallListenerDispatchProbe("item", ItemEventListener)
InstallListenerDispatchProbe("quest", QuestEventListener)
InstallListenerDispatchProbe("spell", SpellEventListener)
```

Because `FireCallbacks` obtains the bucket through `GetCallbacks` before clearing it, that post-hook can inspect the still-mapped target bucket without replacing dispatch.

For each verified listener, the structural probe securely post-hooks `GetCallbacks` and `FireCallbacks`. `DISPATCH_OPEN` means only that `GetCallbacks` has returned; current source calls it near the start of FireCallbacks, but an unrelated direct caller can also produce this marker, so it is not literal function entry. `DISPATCH_NORMAL_EXIT` means only that the FireCallbacks post-hook ran after normal method return. A single diagnostic open stack derives tracked-listener parent/depth relationships. Raw callback-table references assign per-listener/per-ID bucket generations without modifying Blizzard tables, and detailed bucket snapshots remain limited to item `268203` and structurally related records. Handler records report which tracked dispatches were open when the existing active handler ran; this is correlation, not error ownership.

The probe cannot observe FireCallbacks' loop-local callback or index, individual `xpcall` arguments/results, exact line-76 pre/post state, or continuously watch table mutation. Snapshot comparisons report only changes present at the observed open, handler, and normal-exit points. No Blizzard method, global `xpcall`, callback function, or callback table is replaced. This controlled composition does intentionally replace global `CallErrorHandler` after its strict BugGrabber-off gates pass.

At the start of `Observer.lua`, before any setter call, the observer retains the original `seterrorhandler` and `geterrorhandler` identities plus the small native helpers needed to preserve return values and bound text. It then checks BugGrabber's current-character enable state. If disabled, AICO waits through login-time handler composition, then reads and retains the pre-existing active handler at first `PLAYER_ENTERING_WORLD` and installs one wrapper through the preserved native setter. Earlier captures place the target pre-fire after this milestone; a run in which that order reverses is invalid. If BugGrabber is enabled, AICO leaves the handler untouched until `ADDON_LOADED` reports `!BugGrabber`, then reads and retains BugGrabber's active handler and installs the same wrapper. An unavailable or invalid enable-state result fails closed. An anonymous handler value has no source table/global slot on which `issecurevariable` can report intrinsic security or taint, so `/aico` labels direct handler security as unavailable rather than inferring it from the getter.

The observer also captures the original global `CallErrorHandler` identity at file scope, before replacement. The direct wrapper is never installed in BugGrabber-enabled mode. On an initial-login BugGrabber-off path, AICO first requires the existing fallback active-handler wrapper to be installed and verified, queries BugSack and requires it to be neither loaded nor loading, requires the global still to equal the captured original, records observable security/taint state, assigns the diagnostic wrapper, and verifies the new global identity. The wrapper records `CALLERROR-ENTRY`, directly calls the retained original exactly once with the unchanged argument list, and records `CALLERROR-RETURN` only if that call returns. It does not use `pcall`/`xpcall`, call `geterrorhandler`, call BugGrabber separately, or print. Its explicit-count pack/unpack preserves zero results and trailing nils.

The dedicated boundary-provenance channel retains the first 48 target-centered records. It passively snapshots global `xpcall` and `CallErrorHandler` type, display identity, and guarded secure-variable/taint state at target `268203` dispatch open and normal exit, direct-wrapper entry and return, active-handler entry, nil-bucket repeats, and later target opens retained by the existing structural channel. `CallErrorHandler` snapshots also state equality with the file-scope original, AICO's installed wrapper, or neither. A boundary-visible type or identity difference is labeled only as a difference between samples; stable samples cannot exclude a transient change between them.

`CallErrorHandler` ENTRY proves that AICO's installed global wrapper path was traversed. Active-handler ENTRY proves only that the active handler was invoked. If active-handler ENTRY occurs without a currently active direct-wrapper entry, AICO labels it `ACTIVE HANDLER WITHOUT OBSERVED ACTIVE CALLERRORHANDLER`; it does not label that path native. If the direct wrapper is active, it labels `ACTIVE HANDLER DURING OBSERVED CALLERRORHANDLER` and separately reports error-text equality and timing.

The identity timeline records A before any passive listener-observer hook, B after those hooks, C-E around AICO's `!BugGrabber` lifecycle and active-handler-wrapper installation, and F/G around any successful BugGrabber-off direct-wrapper guard and installation. Normal `ADDON_LOADED` events add a record only if the function identity or observable secure-variable state changes. Each record includes time, type, identity, equality to the initial/post-observer/pre-BugGrabber/post-BugGrabber/direct-wrapper values, guarded `issecurevariable` status and taint source, and the last completed addon. The newest 64 records are retained with an eviction count. This observes bounded lifecycle transitions without polling, timers, or startup printing.

Focused source inspection found no explicit Retail Blizzard or BugGrabber assignment to `_G.CallErrorHandler`. BugGrabber changes the separate active error handler with its retained native `seterrorhandler`, then makes the public setter a no-op. The latest runtime timeline observed `_G.CallErrorHandler` change from `function: 000001F6291ADFE0` at A to `function: 000001F6FD3F5720` immediately after AICO's name-based `hooksecurefunc("CallErrorHandler", ...)` returned at B. B remained stable, secure, and untainted through F. This verifies the synchronous transition boundary, not the native mechanism; `hooksecurefunc` has no mirrored implementation or generated contract.

The active-handler wrapper's semantic path is exactly:

```text
HANDLER-ENTRY plus bounded diagnostic open-stack/bucket snapshot
direct call to the selected retained active handler
HANDLER-RETURN, only if that call returns
return the exact retained results
```

The new diagnostic-context capture alone runs through AICO's retained native `pcall`, so a failed observational read becomes a bounded `HANDLER_DISPATCH_CONTEXT` failure marker. The selected handler itself is still called directly, outside `pcall`/`xpcall`; the wrapper catches nothing from it, retries nothing, does not call `geterrorhandler()` from inside the wrapper, and does not invoke `CallErrorHandler` or any Blizzard callback. Return values are packed with an explicit count and unpacked over that count so zero values and trailing nils remain distinct. If the selected handler or synchronous work it invokes errors, control naturally leaves before `HANDLER-RETURN` is recorded. In BugGrabber mode, such an unmatched entry does not by itself distinguish BugGrabber core, EventRegistry, BugSack, or another listener. In fallback pre-existing-handler mode, it localizes non-return to the retained handler or its synchronous work.

For each wrapper entry, the observer stores a sequence, monotonic timestamp and elapsed time, original argument type, bounded escaped text for safe primitive/string values, preceding global and target `GetCallbacks` correlation, a compact snapshot of AICO's diagnostic dispatch stack, and the requested lifecycle state. A normal return adds its time, elapsed time, exact return-value count, first-value type, and a bounded first-value representation only for safely representable types. It performs no `debugstack`/locals capture, item query, addon scan, or printing in the wrapper.

For every normally returning registration it records:

- sequential registration number;
- `GetTimePreciseSec()` timestamp, falling back to `GetTime()`;
- item ID;
- callback type and session-local `tostring(callback)` identity;
- guarded callback-entry security/taint information when the callback remains in its bucket after `AddCallback` returns;
- the last completed `ADDON_LOADED` name and current Chonky/RetailUIResearch loaded-state booleans, explicitly as context rather than ownership inference;
- a bounded `debugstack` captured from the post-hook.

For target item IDs `268203` and `275218`, registration records also capture guarded callable state for:

- global `GetItemInfo`;
- `C_Item.GetItemInfo`;
- `C_Item.GetItemStats`;
- `EJ_GetInstanceInfo`;
- `EJ_GetEncounterInfo`;
- `select`;
- `table.insert`;
- global `GetCVarBool` and the result of `GetCVarBool("loadDeprecationFallbacks")`;
- `C_AddOns.IsAddOnLoaded` and the loaded/loading result for `Blizzard_DeprecatedItemScript`.

Callable records include type, function identity when applicable, and guarded secure/taint state. All optional tables, functions, and calls are checked before use so missing diagnostic dependencies are recorded rather than invoked blindly.

The `GetCallbacks` post-hook separately retains target pre-fire candidates with timestamp, observer-relative elapsed time, callback-bucket contents and identities, security state, current addon/lifecycle context, callable-state snapshot, and bounded stack. The stack distinguishes the expected `FireCallbacks` use from any unrelated direct `GetCallbacks` caller.

The generic record window retains the newest 128 registrations. Item IDs `268203` and `275218` each have an independent first-16 registration list and first-32 pre-fire list, so ordinary generic rotation or activity for one target cannot discard the other target's earliest entry. The structural probe keeps a newest-128 lightweight dispatch ring plus a dedicated first-128 target/correlation buffer; dispatch evictions, target structural drops, stack mismatches, current/maximum depth, and bounded diagnostic failures are reported separately. Handler entries include a compact snapshot of every currently retained open-stack entry. Separate circular buffers retain the newest 48 active-handler-wrapper invocations and newest 48 direct `CallErrorHandler`-wrapper invocations, including unmatched entries, with total entry/return counts and explicit evictions. A dedicated first-48 boundary buffer reports `boundaryRecordsRetained`, `boundaryRecordDrops`, and `boundarySnapshotFailures`. Each active-handler record identifies whether its retained target was BugGrabber or the pre-existing handler captured at first world entry. Per-target drop counters and the generic eviction counter are included in the output. The addon-load timeline retains its first 512 events and reports any later drops.

The observer also records the first `PLAYER_LOGIN` and `PLAYER_ENTERING_WORLD` timestamps, including the available `initialLogin` and `reloadingUi` flags, plus `ADDON_LOADED` milestones for the observer, `!BugGrabber`, Chonky, and RetailUIResearch. At `/aico` generation it enumerates `C_AddOns.GetNumAddOns`, `GetAddOnInfo`, and both returns from `IsAddOnLoaded`, then lists only addons whose exact `loaded` result is true. This is a snapshot-time inventory, not memory-usage inference and not a claim that every listed addon loaded before `PLAYER_LOGIN`.

The item-listener post-hooks, boundary snapshots, and identity timeline remain passive. The active-handler wrapper and guarded direct `CallErrorHandler` wrapper are deliberate diagnostic replacements. This composition is more invasive than the Logs_17 structural run because global `CallErrorHandler` identity is intentionally replaced. The wrappers change active/global identities, add Lua frames and bounded work, and can alter reproduction or attribution, so observer effect must be considered. The diagnostic does not replace or call `xpcall` for testing; replace `FireCallbacks`; wrap or invoke item callbacks; modify BugGrabber, Chonky, Zygor, or Blizzard source; or write to `ItemEventListener.callbacks`. There are no SavedVariables, artificial delays, timers, `OnUpdate`, or polling. All records are lost when the UI session ends.

## Copying the log

Run:

```text
/aico
```

The command opens a small multiline output window, refreshes its text from the bounded in-memory records, focuses the text, and selects it. Press Ctrl+C to copy. Run `/aico` again to refresh the displayed snapshot.

The copyable output is organized as:

1. `SESSION SUMMARY` — installation/snapshot times, elapsed milestone summaries, loaded count, total registration/GetCallbacks counts, and retention/drop counts;
2. `ADDON LOAD TIMELINE` — the first 512 observed post-install `ADDON_LOADED` events in exact sequence, with a drop count;
3. `LIFECYCLE MILESTONES` — observer installation, relevant addon loads, `PLAYER_LOGIN`, and first `PLAYER_ENTERING_WORLD`;
4. `ASYNC CALLBACK DISPATCH STRUCTURE` — listener hook status, dedicated target/correlation records, recent lightweight open/normal-exit records, stack mismatches, generation identity, snapshot comparisons, and diagnostic failures;
5. `TARGET BOUNDARY PROVENANCE` — bounded target/direct-wrapper/active-handler ordering plus passive `xpcall` and `CallErrorHandler` snapshots;
6. `CALLERRORHANDLER IDENTITY TIMELINE` — bounded lifecycle identity, equality, security, and taint checkpoints;
7. `CALLERRORHANDLER ENTRY/RETURN WRAPPER` — guarded installation status and any paired entry/return records;
8. `ACTIVE ERROR-HANDLER WRAPPER` — enable-state/mode selection, installation verification, retained handler identity, dispatch context, bounded paired entry/return records, and explicit interpretation limits;
9. `LOADED ADDONS` — exact snapshot-time loaded inventory in the API's addon-index order;
10. separate `TARGET 268203 REGISTRATIONS` and `TARGET 275218 REGISTRATIONS` sections;
11. `TARGET CALLABLE SNAPSHOTS / PREFIRE EVIDENCE`; and
12. the retained generic registration window.

The output explicitly states that `ITEM_DATA_LOAD_RESULT success=true` means successful item-data event delivery, not successful execution of every queued callback. RetailUIResearch's separate `COMPLETE success=true` label has the same limited meaning.

## Historical targeted runtime procedure

The next test is exactly one controlled boundary-provenance run:

1. Sync only the updated AICO `Observer.lua` and this README if kept beside the installed diagnostic.
2. Fully exit World of Warcraft.
3. Use the full normal addon profile.
4. Disable BugGrabber for the test character.
5. Disable BugSack.
6. Enable AICO.
7. Keep AICD enabled and unchanged.
8. Keep Chonky unchanged.
9. Keep Zygor unchanged.
10. Use the same character.
11. Keep item `268203` equipped.
12. Keep Phoenix Oil enchant `8052` active if available.
13. Launch fresh directly into that character.
14. Do not hover items or open character panels while startup settles.
15. If line 76 reproduces, do not reload or log out.
16. Capture the complete physical Lua error.
17. Run `/aico` and capture the complete output.
18. Run `/aicd` and capture the complete output.
19. Run `/run print(AICD_CHONKY_268203_GetLog())` and capture the complete output.
20. Save the combined evidence as `Logs_18_BugGrabberOff_FullNormalProfile_BoundaryProvenance.txt`.

Before interpretation, require `bugGrabberOffControlValid=true`, `boundaryProvenanceControlValid=true`, a verified active direct `CallErrorHandler` wrapper, all three listener hooks installed, `targetStructuralDrops=0`, `dispatchFailures=0`, `boundaryRecordDrops=0`, `boundarySnapshotFailures=0`, and no unexpected stack mismatch affecting target chronology. If the failure does not reproduce, treat the intentional global-wrapper replacement as possible perturbation rather than a fix or causal suppression result.

An exact same-session identity match, together with the Chonky `core/gearDB.lua` registration stack, is strong runtime attribution of that callback to the observed Chonky registration. It does not prove that Chonky causes the Lua error, that zero remaining enchant time is causal, or that a callback identity from another client session should match.

The original procedure established callback attribution. This branch tests whether BugGrabber is required for the underlying error rather than merely for its storage/display.

## Retail LIVE runtime result

The observer completed its attribution purpose on Retail LIVE. It loaded before Chonky and recorded the item `268203` registration stack through:

```text
ItemMixin:ContinueOnItemLoad
core/gearDB.lua:1416
AddItemToMaster at core/gearDB.lua:1412
raid traversal at core/gearDB.lua:1557
file-scope CCS.BuildMasterLoot() at core/gearDB.lua:1590
```

In the first instrumented failing session, the observer's callback identity `function: 0000022B022325A0` exactly matched V3's sole startup/pre-fire callback before a line-76 error was reported in the same delivery window. Later failing sessions reproduced the same registration/pre-fire attribution pattern. In a representative enhanced capture, `function: 000001C083C24AE0` was both Chonky's registered callback and the sole real secure function in the length-one bucket immediately before the report. These addresses are session-local; the within-session identity equality and registration stack are the evidence. A later Zygor registration used a different identity and must not be conflated with the early Chonky callback.

A minimal Chonky run was clean, and a minimal Chonky+Zygor run was also clean. The fuller addon startup reproduced the failure. The clean run reached Chonky about `0.05s` after the observer, reached `PLAYER_LOGIN` around `15s`, and fired the callback around `16.8s` with positive temporary-enchant duration near `7,092,000ms`. The fuller failing run reached Chonky about `3.9s` after the observer, reached `PLAYER_LOGIN` around `22.5s`, and fired around `36.9s` while duration still read `0`; the duration became positive in the same timestamp window. The later wall-clock firing still failed, so elapsed time alone is not a readiness guarantee.

The identified Chonky callback does not read equipped slots or temporary-enchant state. The Oil/duration result remains an indirect startup correlation, not a demonstrated callback input or cause. `AICD COMPLETE success=true` means the item-data event reported success; it does not mean every callback body returned successfully.

The enhanced snapshot fields have now been exercised in a failing Retail LIVE session. At both Chonky registration and the matching failing pre-fire, `GetItemInfo`, `C_Item.GetItemInfo`, `C_Item.GetItemStats`, `EJ_GetInstanceInfo`, `EJ_GetEncounterInfo`, `select`, `table.insert`, `GetCVarBool`, and `C_AddOns.IsAddOnLoaded` were functions with stable observed identities. The capture also reported `loadDeprecationFallbacks=true` and `Blizzard_DeprecatedItemScript loaded=true`. The earlier simple theory that `GetItemInfo` was nil at pre-fire is therefore strongly contradicted. Later target-only instrumentation recorded every Chonky callback operation completing through `CALLBACK-END`, disproving direct Chonky-body failure for that execution.

The latest fresh heavy-profile run then exercised the corrected direct-wrapper checkpoint. `_G.CallErrorHandler` retained its untouched identity through A-F, AICO installed and verified its wrapper at G, and the later target lookup again contained the sole secure/untainted Chonky callback. The line-76 error reproduced about `0.463ms` after that lookup. The direct wrapper recorded zero entries, while the installed active-handler wrapper recorded exactly one fresh BugGrabber entry and normal return for the exact message. Under ordinary Lua semantics, `xpcall(callback, CallErrorHandler)` performs a runtime global lookup; `CallErrorHandler` is not local, aliased, or imported in `AsyncCallbackSystem.lua`, and Blizzard_ObjectAPI's Retail TOC declares no secure-environment directive. The active-handler entry therefore bypassed the addon-observed global wrapper through a path not explained by mirrored Lua source. This is runtime evidence of a bypass, not proof of a particular native mechanism.

The same `268203` failure reproduced with Odysseus Utility Suite disabled; OUS is not required for this path. Chonky-only has also completed the same kind of callback cleanly, so Chonky callback existence remains insufficient by itself. In the latest OUS-disabled evidence, item `275218` was in bags, received a separate Zygor bag-upgrade continuation, and had no observed Chonky registration. That secondary observation demonstrates independent continuation producers but does not attribute the earlier `275218` error to Zygor.

Logs_35-40 subsequently isolated OBB across three exact ON/OFF pairs. Logs_41 and 42 then kept the controlled environment fixed while disabling and restoring only OBB's Blizzard-managed MainHand/OffHand providers: disabled was clean and restored reproduced. Logs_43 and 44 exercised OBB-owned ordinary weapon-enchant rows and were both clean, with `557` registrations and `1175` GetCallbacks; all `1337/1337` and `1326/1326` dispatches normal-exited, respectively. The old managed provider branch is the strongest verified feature-level selector in this tested composition. AICO did not identify the exact failing callback or prove a Blizzard or OBB defect.

## Validated enhancement status and limitations

The enhanced observer's timeline, inventory, lifecycle, registration-time callable, and target pre-fire capture are source-reviewed, statically validated, and confirmed by fresh-client Retail LIVE captures. They established stable public callable identities and deprecation state at the two observation points. The former passive `CallErrorHandler` post-hook recorded zero normally returning invocations, and the active BugGrabber-handler wrapper recorded one current-session entry and normal return for the exact error while stored display counts could aggregate across sessions/occurrences. The corrected no-post-hook architecture is LIVE-tested: the direct wrapper installed, but the fresh BugGrabber invocation bypassed it. The BugGrabber-disabled first-world-entry fallback mode is also LIVE-tested; valid controls reproduced without BugGrabber/BugSack, and Log_41 later supplied a valid clean provider-disabled control.

Unavoidable boundaries remain:

- the addon timeline begins only after the observer installs, so required Blizzard dependencies that loaded earlier are outside it;
- `AddCallback` is a post-hook, so a synchronously completed continuation can reach `GetCallbacks` before its registration post-hook record is emitted;
- the `GetCallbacks` hook observes every target lookup; its bounded stack must confirm whether a record is the `FireCallbacks` pre-dispatch path;
- the loaded-addon inventory is generated when `/aico` runs and can include LoadOnDemand addons loaded after startup;
- function identity strings are session-local;
- target registration retention is bounded at 16 per ID and target pre-fire retention at 32 per ID, with explicit drop counts;
- callable/security snapshots show state at the observation point, not which expression subsequently failed;
- neither item-event success nor a pre-fire snapshot proves callback-body success;
- the active-handler wrapper deliberately changes handler identity and adds a Lua frame and bounded recording work; its `RETURN` record precedes its final unpack/return expression, so it does not independently prove the wrapper crossed that last boundary;
- the `CallErrorHandler` wrapper replaces a global, can taint it, and can alter reproduction, attribution, or native secure-hook behavior;
- its `CALLERROR-RETURN` marker precedes its own final unpack/return expression, so return to native `xpcall` remains unobserved;
- identity checkpoints establish when a difference is observed, not how native machinery implements it; and
- correlation with the nearest global or target `GetCallbacks` record is temporal only.

## Expected boundary-provenance outcomes

| Outcome | Observed ordering/state | Bounded interpretation |
| --- | --- | --- |
| A | B ENTRY while target open, then C while B active, B RETURN, target normal exit | The installed global path was traversed during the tracked target dispatch. This does not identify the failing callable. |
| B | Target normal exit, then B ENTRY, C, and B RETURN | The global path was observed only after source-body/post-hook completion; later delivery is supported, but its native mechanism is unresolved. |
| C | Target normal exit, then C with no active B | The active handler was observed without traversing AICO's installed global B frame. Investigate direct or alternate active-handler paths without labeling the observation native. |
| D | B ENTRY, target normal exit, then C | Inspect retained-original timing and other handler paths. Do not assume deferred native behavior. |
| E | Boundary-visible `xpcall` or `CallErrorHandler` type/identity change | A discrete transition interval was captured. Identify the interval or owner before broader experiments. |
| F | Failure reproduces with clean ordering and stable sampled identities, but provenance remains unresolved | This may be the safe addon-observation ceiling; prefer a separate synthetic ordering harness before any global `xpcall` wrapper or `FireCallbacks` replacement. |
| G | Failure does not reproduce | The intentional global wrapper may have perturbed the phenomenon. This is not a fix and one run cannot establish causal suppression. |

## Source anchors

The read-only Chonky 2.3.16 reference establishes:

- `core/gearDB.lua:1073`: item `268203` in The Venomous Abyss loot data;
- `core/gearDB.lua:1412-1518`: `AddItemToMaster` and its `ContinueOnItemLoad` callback;
- `core/gearDB.lua:1521-1587`: `BuildMasterLoot` traversal;
- `core/gearDB.lua:1590`: file-scope `CCS.BuildMasterLoot()` call.

Item `275218` is Mertei's Command Baton. An exact search found no `275218` occurrence in the supplied Chonky 2.3.16 Lua, XML, or TOC files, and the latest OUS-disabled capture observed a Zygor bag-upgrade continuation but no Chonky registration for that bagged item. The earlier `275218` failure therefore cannot be assigned to Chonky's `BuildMasterLoot` path or, without same-session failing attribution, to Zygor. The matched `268203` callback does not inspect temporary-enchant or equipped-weapon state; Oil and `remainingMs=0` remain startup/readiness correlations rather than direct callback dependencies.
