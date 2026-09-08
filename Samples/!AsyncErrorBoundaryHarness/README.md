# Async Error Boundary Harness

## Purpose

`!AsyncErrorBoundaryHarness` is a standalone, command-driven Retail diagnostic addon. It establishes controlled baselines for `xpcall`, active error-handler delivery, cleanup, harness-owned secure post-hooks, and caller-visible chronology without importing or changing Blizzard's `AsyncCallbackSystem`.

The harness is inert at login apart from retaining native helper identities, installing a secure post-hook on its own private dispatcher method, and registering `/aebh`. It does not install its active error-handler wrapper or run deliberate errors until explicitly commanded.

## Relationship to Logs_18

Logs_18 observed a valid item callback finish, visible `FireCallbacks` cleanup, a secure method post-hook, and then active handler C receiving a line-76 error while AICO's installed global `CallErrorHandler` wrapper recorded zero entries. That evidence does not reveal the actual `xpcall` second-argument object or native error-delivery mechanism.

This harness makes the second argument known by construction and tests ordinary Retail behavior in isolation. It is a synthetic baseline, **not** a reproduction of the 167-addon session and not proof that Blizzard's native/secure boundary behaves identically in every context. A negative result cannot rule out Blizzard-specific binding, native behavior, or a separate tightly correlated error occurrence.

## A / B / C terminology

- **A** is the actual message-handler value passed as `xpcall`'s second argument for a test.
- **B** is the local harness function `HarnessMessageHandler`.
- **C** is the active handler returned by `geterrorhandler()`.

For ordinary cases A is explicitly B. For invalid-handler cases A is explicitly nil or the number `17`. B is local, distinctively named, and is never installed as or assigned to Blizzard's global `CallErrorHandler`.

B records entry, reads the current C, calls it exactly once with the unchanged arguments, records return only if C returns, and preserves the exact returned-value count including trailing nils. B deliberately does not reproduce `CallErrorHandler`'s stack-height adjustment; it isolates protected-call and B/C chronology.

## Stage-1 design audit

The design was checked against LIVE Retail source at Blizzard source HEAD `8ea15b61e45c0ed4eba01439c90757f86eb78d34`.

1. **Files:** the addon consists only of its TOC, `Harness.lua`, and this README.
2. **Dispatcher:** a private table method retains one callback value, records immediately before `xpcall(callback, A)`, captures exact `xpcall` returns, explicitly clears its retained callback/marker, records a final body marker, and is securely post-hooked.
3. **C install/restore:** the getter and setter are captured at file load. Install retains the current function, uses the captured setter, and verifies the active identity with the captured getter. Restore proceeds only while the active handler is still the harness wrapper, restores the retained function once, and verifies its identity. No setter return-value contract is assumed.
4. **B/A selection:** B is a local function. Each run stores A's type, identity, and equality to B before dispatch.
5. **Chronology:** `CALLER_BEFORE`, method events, callback/B/C events, cleanup, `METHOD_BODY_FINAL`, `SECURE_POST_HOOK_ENTRY`, and `CALLER_AFTER` receive per-run event numbers and monotonic deltas.
6. **Expected source behavior:** normal and ordinary protected callback failures should allow `xpcall` to return and source cleanup to continue; malformed first/message-handler arguments are deliberately treated as runtime questions.
7. **Potential uncaught errors:** the invalid first-argument and invalid-message-handler cases can abort the dispatcher if Retail raises outside the tested `xpcall` path.
8. **Containment:** those cases are not enclosed in another `pcall`/`xpcall`. The slash-command invocation is the outer host boundary. An aborted run remains retained and active for `/aebh dump`; use `/aebh clear` before another test.
9. **Secure hook:** `hooksecurefunc` targets only the harness-owned `Dispatcher:Run`. Its before/after method identities and observable security state are reported. The hook is session-local and removable by disabling/reloading the standalone addon.
10. **Composition gate:** install and every run fail closed unless BugGrabber and BugSack are both reported not loaded and not loading. This proves runtime absence only, not configuration-disabled state.
11. **Combat gate:** install, restore, and every test refuse to run in combat.
12. **Output:** at most eight runs, 64 events per run, and 16 ambient C events are retained in memory with explicit eviction/drop counts. `/aebh dump` opens selectable text.
13. **Perturbations:** installing C changes active-handler identity and adds recording/delegation frames. The private secure hook may change the dispatcher method identity. Direct-C cases intentionally send a synthetic error to the retained handler.
14. **Claims:** the harness can establish exact Retail behavior for these constructed calls and their observed ordering. It cannot identify the Logs_18 mechanism or expose native pending-error/trampoline state.

The design does not wrap `_G.xpcall`, replace Blizzard `FireCallbacks`, touch Blizzard callback tables, use debug hooks/locals, or involve Chonky, Zygor, AICO, AICD, RetailUIResearch runtime modules, OUS, or Odysseus BuffBars.

## Active-handler C wrapper

Run `/aebh install` explicitly. Installation requires:

- out of combat;
- BugGrabber and BugSack both runtime-absent;
- `geterrorhandler`, `seterrorhandler`, and `unpack` available;
- current C to be a distinct function;
- post-set identity verification.

The C wrapper records `C_ENTRY`, delegates to the retained original handler exactly once with unchanged arguments, records `C_RETURN` only after normal return, and preserves exact return multiplicity. It does not protect, retry, rewrite, or swallow the retained handler call.

Run `/aebh restore` after testing. Restoration refuses to overwrite a handler that replaced the harness wrapper after installation. If a run aborted, first capture `/aebh dump`, then `/aebh clear`, then restore. The harness cannot automatically restore itself during addon unload/reload, so restoration is an explicit operator responsibility.

## Required state

- Retail LIVE 12.1.0.
- BugGrabber OFF and not runtime-loaded.
- BugSack OFF and not runtime-loaded.
- Out of combat.
- Run only one test at a time.

The harness never disables another addon. Its runtime-loaded checks do not prove configuration-disabled state; confirm the addon profile manually as well.

## Commands

```text
/aebh status
/aebh install
/aebh run normal
/aebh run callback-nil
/aebh run first-nil
/aebh run first-number
/aebh run handler-nil
/aebh run handler-number
/aebh run direct-c-body
/aebh run direct-c-after
/aebh dump
/aebh clear
/aebh restore
```

`dump` opens a bounded multiline window and selects all text for Ctrl+C. `clear` removes retained run/ambient records but preserves monotonically increasing run numbers. It also releases an intentionally retained incomplete-run association after a malformed call aborts.

## Cases and interpretation

### CASE 0 — `normal`

A=B. The callback records entry, performs deterministic arithmetic, records end, and returns three values including a middle nil.

Expected source-level chronology:

```text
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

B and C should not enter. This validates instrumentation and ordinary post-hook-before-caller ordering.

### CASE 1 — `callback-nil`

A=B. The callback attempts to call a local harness-owned nil value at one stable line. If ordinary Retail behavior applies, callback end is absent, B calls C, `xpcall` returns, and cleanup/post-hook/caller markers follow. Capture the exact error text, source line, return values, and ordering rather than assuming them.

### CASE 2 — `first-nil` and `first-number`

A=B, while the first `xpcall` argument is nil or `17`. These are separate tests because Retail may validate or format them differently.

No outer harness `pcall` or `xpcall` contains the tested expression. If Retail raises outside it, `XPCALL_RETURN`, cleanup, post-hook, caller-after, and run-complete may all be absent. C may record the unprotected error. The retained incomplete run is the evidence; dump before clearing it.

### CASE 3 — `handler-nil` and `handler-number`

The callback deliberately uses the CASE-1 nil-call site, while A is nil or `17`. B is not A and must not be credited with any resulting handling. As in CASE 2, the expression is not hidden inside a second protected call and may leave an incomplete run.

### CASE 4 — `direct-c-body` and `direct-c-after`

The direct event uses no inner `xpcall`. Both cases pass this exact synthetic string directly to current C:

```text
[AEBH SYNTHETIC] SomeSyntheticFile.lua:404: attempt to call a nil value
```

`direct-c-body` invokes C inside the method before cleanup and the secure post-hook. `direct-c-after` first performs a normal A=B dispatch through cleanup, post-hook, and `CALLER_AFTER`, then invokes C directly.

These establish whether C receives the preformatted string unchanged and provide explicit before/after chronology baselines. `direct-c-after` is intentionally tautological: it demonstrates that a caller can construct post-hook → C with B=0, not that Retail spontaneously deferred anything.

### CASE 5 — stack-height adjustment

Not implemented. LIVE source demonstrates `SetErrorCallstackHeight` and later reset but provides no finally-style guarantee if C or synchronous downstream work fails to return. A harness that promises restoration would either leave state altered on non-return or protect the call and contaminate the path. Static API signatures also do not establish error-string rewriting. The safer experiment omits this case.

### CASE 6 — spontaneous secure-post-hook delivery

No separate non-tautological case is implemented. CASES 0–3 already expose whether an ordinary constructed `xpcall` sequence naturally places C after cleanup/post-hook with B=0. Making the post-hook call C or deliberately fail would merely manufacture the requested ordering; CASE 4 labels that construction explicitly instead.

## Recommended manual order

For every case, perform a separate capture cycle:

1. Fully exit Retail and verify BugGrabber and BugSack are disabled for the selected character/profile.
2. Install only this standalone addon for review testing; do not replace the project copy.
3. Log in and remain out of combat.
4. Run `/aebh status`; retain the output if any gate is invalid.
5. Run `/aebh install`.
6. Run `/aebh run normal`.
7. Run `/aebh dump`, copy all text, and save it as the CASE-0 capture.
8. Run `/aebh clear`.
9. Run exactly one next case from the order below.
10. Immediately run `/aebh dump` and copy the complete output, including an incomplete run.
11. Run `/aebh clear`.
12. Continue with the next case.
13. At the end, run `/aebh restore` and `/aebh status`; require `handlerInstalled=false` and `handlerStatus="restored and verified"`.

Case order after `normal`:

```text
callback-nil
first-nil
first-number
handler-nil
handler-number
direct-c-body
direct-c-after
```

Do not automatically run the matrix. Each deliberate case must be invoked separately and captured before clearing.

## Output to return

Return one complete `/aebh dump` per case, plus:

- the pre-install `/aebh status` output;
- the post-restore `/aebh status` output;
- any physical Lua error text/window produced by malformed calls;
- whether the user had to dismiss an error UI before `/aebh dump` remained usable;
- the exact addon profile confirmation that BugGrabber and BugSack were disabled.

Event order numbers are authoritative within a run. Monotonic deltas supplement them. Function identity strings are session-local. `C_ENTRY` proves only that the installed active wrapper was invoked; direct-C cases are synthetic and do not attribute Logs_18.

## Known perturbations and boundaries

- Installing C intentionally changes active-handler identity and can affect error handling.
- B and C add Lua frames and bounded recording work.
- The harness-owned `hooksecurefunc` call may change its private dispatcher method identity.
- The C wrapper directly invokes the retained handler without containment. If that handler fails, `C_RETURN` is absent and native dispatch may reenter the active wrapper.
- Invalid first/message-handler cases can abort before cleanup; that absence is a result, not proof of native internals.
- The slash-command host is the outer execution boundary for deliberately unprotected cases.
- A successful secure post-hook observation does not expose pending native state.
- Caller-after establishes ordinary caller-visible chronology only for this harness method.
- The harness does not claim source-location/error-string rewriting from stack-height helpers.

The global `xpcall` function is never wrapped or assigned. Blizzard `FireCallbacks` is never replaced. Blizzard or production addon callback tables are never read or mutated. Chonky, Zygor, AICO, AICD, RetailUIResearch runtime modules, OUS, and Odysseus BuffBars are not referenced or modified by the implementation.
