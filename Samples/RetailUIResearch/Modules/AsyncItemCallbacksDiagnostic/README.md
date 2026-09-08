# AsyncItemCallbacksDiagnostic

## Purpose and status

This focused Retail LIVE diagnostic observes item-data callback registration, pre-clear callback-bucket state, and completion for the equipped main-hand and off-hand item IDs. It is retained as the reproducible diagnostic used during the completed `AsyncCallbackSystem.lua` investigation of a temporarily enchanted equipped weapon.

Diagnostic v1 was active during the first captured reproduction of the original error. V2 then captured the sole pre-fire callback identity `0000018C797F6D70` in another failing session, but none of its 64 retained `AddCallback` post-hook records matched item ID `268203`; no registration was evicted. V3 addresses that remaining timing/provenance question without wrapping callbacks.

This remains an observation tool, not a workaround, callback wrapper, or production implementation.

## Source / static validation

The design was verified against Retail LIVE source `12.1.0.69497` at `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`. The directly relevant source and generated API files remain unchanged at the Retail `12.1.0.69587` LIVE mirror HEAD `8ea15b61e45c0ed4eba01439c90757f86eb78d34`.

- `ItemEventListener` is the `ASYNC_ITEM` listener and receives `ITEM_DATA_LOAD_RESULT`.
- `ItemMixin:ContinueOnItemLoad` and `ContinueWithCancelOnItemLoad` pass the item's actual item ID to `ItemEventListener:AddCallback`.
- `FireCallbacks` obtains the mapped bucket through `self:GetCallbacks(id)`, then clears the map entry before invoking the returned array.
- The event payload is `itemID, success`.
- `C_PaperDollInfo.GetTemporaryEnchantmentInfo` returns one `TemporaryItemEnchantInfo` table, or nothing when the slot has no active temporary enchant.
- The diagnostic uses `Item:CreateFromEquipmentSlot(...):GetItemID()` for equipped-item identity.
- Current Blizzard Lua populates an item listener bucket only through `AddCallback`; cancellation replaces an entry with `-1`, and clear/fire paths only remove state.
- `Blizzard_AuraContainer` loads its Lua in a secure environment, but current Lua source does not define whether an insecure post-hook observes every secure-environment call path.

## What v1 established

The failing session began with unreadable equipment IDs at initialization, `PLAYER_LOGIN`, and `PLAYER_ENTERING_WORLD`. Equipment identity first became readable during later item-completion activity.

V1 retained at most 40 unmatched registrations only until `PLAYER_ENTERING_WORLD`. Therefore it had two independent loss paths:

1. older registrations could be evicted when more than 40 unmatched registrations arrived;
2. unmatched registrations after `PLAYER_ENTERING_WORLD` were discarded even though this session's equipment IDs were still unreadable.

The later Zygor main-hand registration had `hookOrder=407`. That proves the hook received at least 407 completed `AddCallback` calls by then, but does not reveal the exact hook order of the missing early weapon registration or prove that more than 40 calls occurred before the original v1 cutoff. A 40-entry FIFO was nevertheless too small to cover the observed registration volume reliably.

The later Zygor `ContinueOnItemLoad` registration also appeared in clean diagnostic runs. It proves participation in equipped-item loading, not responsibility for the failure.

## What v2 established

The failure reproduced after a full WoW client exit, fresh launch, and direct character login. It has not reproduced reliably after ordinary logout/login.

Immediately before `FireCallbacks(268203)`, V2 saw one callback function, `0000018C797F6D70`. Its retained buffer reported 64 registrations, zero matches, and zero evictions. Both weapon IDs were readable when the buffer resolved, so neither buffer capacity nor V2's equipment filter discarded this callback in that session. The callback entered the bucket outside the 64 normally returning `AddCallback` calls seen by V2's post-hook.

A later callback, `0000018DF04489D0`, had a matching registration stack through Zygor item-score startup code. It is not the earlier function, and equivalent later registrations appeared in clean sessions. The evidence does not assign the earlier callback or the failure to Zygor.

V2 still had a general one-slot lifecycle hole: after either weapon ID became readable, it discarded unrelated retained records and stopped buffering unmatched calls. That did not explain the supplied failing capture, where both IDs resolved together, but V3 removes the discard.

## V3 instrumentation

`Bootstrap.lua` is the first RetailUIResearch TOC file, before `Core.lua`. The root TOC explicitly depends on `Blizzard_ObjectAPI`, so the listener necessarily exists first. The bootstrap is the earliest observation point available inside RetailUIResearch; it cannot observe a registration stack that completed during dependency or earlier-addon loading.

The bootstrap records its installation time and RetailUIResearch's later `ADDON_LOADED` time so the next log shows the same-addon's early-hook interval directly.

Before installing hooks, V3 takes a bounded read-only snapshot of callback entries already present in `ItemEventListener.callbacks`. It then installs two passive post-hooks:

```lua
hooksecurefunc(ItemEventListener, "AddCallback", registrationPostHook)
hooksecurefunc(ItemEventListener, "GetCallbacks", prefirePostHook)
```

The `AddCallback` hook receives the original listener, ID, and callback arguments after a normally returning registration. The bootstrap retains bounded compact evidence for every item ID. The module records fuller evidence immediately when cached equipment identity matches, without repeatedly querying equipment/enchant APIs for unrelated registrations.

The `GetCallbacks` hook is the smallest passive pre-clear observation point available in current source. `FireCallbacks` calls `GetCallbacks(id)` before its next statement clears `self.callbacks[id]`. The post-hook receives the listener and ID, then reads the still-mapped bucket directly. It does not receive the method's return value and does not alter it.

For matching evidence, V3 records:

- observation order and `GetTime()` timestamp;
- item ID and callback `type`/`tostring` identity;
- matching slot and current temporary-enchant fields;
- callback-map/bucket type and ordered identities for at most 16 entries;
- guarded per-entry `issecurevariable(bucket, index)` results;
- whether each pre-fire identity was already present at V3 startup, observed by V3's `AddCallback` hook, or unseen in either retained set;
- focused function state for `xpcall`, `ipairs`, and `CallErrorHandler`;
- a bounded post-hook stack.

The ordinary `ITEM_DATA_LOAD_RESULT` observer still records matching or previously observed item IDs, `success`, equipment/enchant state, and bucket state visible to that event listener.

No hook replaces `AddCallback`, `GetCallbacks`, or `FireCallbacks`. No supplied callback is wrapped, invoked, canceled, or changed, and `ItemEventListener.callbacks` is never written.

## Bounds and filtering

- Visible log: 80 entries, 4,000 characters per entry.
- Direct matching bucket descriptions: 16 entries maximum.
- Direct matching stacks: ten lines maximum and half an entry's character budget.
- Startup callback snapshot: 512 entries.
- All-ID registration buffer: 512 compact observations.
- All-ID pre-clear snapshot buffer: 512 compact observations.
- Compact stacks: six lines and 1,200 characters maximum.
- Eviction counts are retained and reported when equipment identity resolves.

Each bound reports evictions. Compact stack and bucket caps keep the total string payload bounded rather than creating unbounded session history.

Whenever the readable main/off-hand identity changes, V3 scans the retained records, emits previously unreported matches, and reports totals/matches/evictions. It does not discard unmatched evidence at the first partially readable equipment snapshot. Later observations use cached equipment state and direct ID matching.

## Important limitations

- A callback already present when V3 starts can be identified as pre-hook state, but its completed registration stack cannot be reconstructed.
- A post-hook runs only after the hooked method returns. If `AddCallback` does not return, its registration post-hook cannot record that call.
- Synchronous completion can still precede the `AddCallback` registration record and leave `bucketAfterReturn` absent.
- During that synchronous sequence, a pre-fire entry can initially say `unseen-by-v3` and then be followed by its matching `REGISTER`; interpret the pair together.
- The `GetCallbacks` post-hook preserves the bucket before the current source's following clear, but does not observe individual callback invocation or identify an error by itself.
- If multiple callbacks are present, correlation still depends on the reported loop index, ordered bucket identities, registration stacks, and focused function state.
- More than 512 startup entries, registrations, or pre-clear snapshots can evict older evidence; counts expose that loss.
- Logs are lost on another reload, logout, disconnect, or client exit.
- No conclusion about Blizzard, an addon, a race condition, combat safety, or taint follows from this module.

## Temporary-enchant duration observation

Two failing full-client-restart runs observed a non-nil temporary enchant with `enchantID=8052` and `remainingTimeMs=0`, followed later by the same enchant ID with a normal positive remaining duration. Earlier clean runs first observed a positive duration. This is a repeated verified runtime correlation, not causation.

Current generated API documentation requires `remainingTimeMs` to be a number but does not require it to be greater than zero. Current AuraContainer code treats any non-nil enchant-info table as active and accepts a later increase in remaining time as a reassignment/refresh condition. A zero value during initialization is therefore a source-supported possibility. Source does not define zero as a special login sentinel or as expired, explain why it occurred, or prove that it caused the callback failure. The diagnostic does not assign a name to enchant ID 8052.

## Screenshot

`AsyncItemCallbacksDiagnostic.png` is the user-authored Retail LIVE visual reference from the V2 failing capture. It shows the current diagnostic layout, the resolved equipped weapon/enchant state, and the pre-fire bucket evidence. V3 preserves the same page architecture while adding earlier in-memory capture and provenance fields. The image is not source evidence and was not modified for V3.

## UI and commands

Open the hidden page from the RetailUIResearch launcher or with:

- `/asyncitemcallbacks`
- `/aicd`

The page shows current main/off-hand item IDs and temporary-enchant state. `Refresh Equipment` records a manual snapshot. Click the diagnostic text and use Ctrl+A followed by Ctrl+C to copy it. `Clear Log` discards current visible entries while sequence numbering continues.

## Historical full-client-restart procedure

The following procedure produced the historical evidence. No further run is required for this checkpoint; use it only when a separately authorized experiment needs a comparable fresh-client-launch capture. RetailUIResearch and diagnostic V3 must be enabled before exiting the game.

1. Use the same character and equip the same main-hand weapon, item ID `268203` if still applicable.
2. Apply the same temporary Oil and do not change gear.
3. Open **Async Item Callbacks**, click **Refresh Equipment**, and confirm the weapon ID plus `tempEnchant=true`.
4. Fully exit World of Warcraft.
5. Launch the client again and log directly into the same character.
6. If the error reproduces, copy the complete Lua error including locals.
7. Open **Async Item Callbacks** from the launcher or use `/aicd`.
8. Copy the complete log before reload, logout, another client exit, clearing the log, or changing equipment.
9. Return the diagnostic log and Lua error together.

For a useful clean comparison, return the complete log even when the error does not reproduce. Ordinary logout/login may be tested separately, but it is not the strongest observed reproduction method.

## Safety boundaries

- no callback replacement, wrapping, cancellation, or invocation;
- no writes to `ItemEventListener.callbacks`;
- no `FireCallbacks` replacement or hook;
- no AuraButton hooks;
- no `OnUpdate` or polling;
- no SavedVariables;
- no secure templates, protected frames, or protected action execution;
- no production-addon or third-party integration.

The hooks observe ordinary Lua methods without replacing them. Callback-table inspection is read-only. Equipment and temporary-enchant reads use current Retail APIs with fixed non-secret slot constants. These facts support the narrow observation design, but do not establish universal combat or taint safety.
