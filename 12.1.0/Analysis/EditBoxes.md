# Retail EditBoxes and Input Controls — WoW 12.1.0

## 1. Scope and source baseline

This document investigates standalone text and numeric input controls available to normal third-party Retail addons. It is deliberately narrower than chat input, full search systems, or multiline text editors. Those systems are included only where they establish an architectural boundary.

- BlizzardResearch baseline: `1861e5524f223eac082310e1e271800f74f9a037`
- Retail client/source baseline: `12.1.0.69497`
- LIVE source root: `D:\WowDEV\Reference\Blizzard\wow-ui-source`
- LIVE branch/commit: `live`, `027d26c3406d3de2cbd2b1f67d468fe033a1bcd4`
- Research date: 2026-08-31
- PTR consulted: no. LIVE contained the relevant definitions and current consumers, so no concrete compatibility question required PTR evidence.

Source paths below are relative to `Interface/AddOns/` in that LIVE mirror. Mainline definitions and consumers are primary. No Blizzard source, runtime sample, or production addon was modified.

## 2. Executive summary

### VERIFIED SOURCE FACTS

- `EditBox` is the intrinsic frame type. Its generated `SimpleEditBoxAPI` includes text, number, focus, selection, enabled-state, character/byte-limit, numeric-mode, and multiline methods (`Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua`).
- `InputBoxTemplate` remains the broad current shared single-line template. It combines `InputBoxScriptTemplate` and `InputBoxVisualTemplate`, uses shared border art and `ChatFontNormal`, and is used directly across unrelated current Mainline features (`Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml:4-70`).
- `InputBoxTemplate` does not own a label, width, height, validation rule, semantic value, commit callback, or persistence. Callers supply those pieces.
- `InputBoxScriptTemplate` enables mouse input, supplies `NarrationEditBoxMixin`, moves focus through explicitly linked `previousEditBox`/`nextEditBox` fields on Tab, clears focus on Escape, selects all text on focus gain, and clears selection on focus loss (`InputBoxTemplates.xml:4-11`; `.lua:1-19`).
- `EditBox` XML defaults `autoFocus` to true. `InputBoxTemplate` does not override that default; most ordinary current consumers explicitly use `autoFocus="false"` (`Blizzard_SharedXML/UI.xsd:1053-1064`).
- `InputBoxInstructionsTemplate` is the real shared placeholder/instruction variant. `InputBoxTemplateWithInstructions` and `InputBoxInstructionsMixin` are absent exact identifiers in LIVE.
- `NumericInputBoxTemplate` is a real shared numeric specialization. It inherits `InputBoxTemplate`, sets `numeric="true"`, reports live numeric changes with an `isUserInput` flag, and finalizes on focus loss (`InputBoxTemplates.xml:256-271`; `.lua:241-259`).
- `NumericInputSpinnerTemplate` is a separate shared integer-style spinner with decrement/increment buttons, mouse-wheel handling, optional min/max clamping, and a value callback (`InputBoxTemplates.xml:273-373`; `.lua:261-370`).
- The generated API exposes both `SetNumeric` and `SetNumericFullRange`, but the LIVE Lua/XML source contains no `SetNumericFullRange` consumer and no comment defining its accepted character grammar. Exact sign and decimal acceptance cannot be claimed from this source snapshot alone.
- Blizzard Settings can register string and number setting values, but its native list controls are checkbox, slider, dropdown, button, color swatch, and compound variants. There is no `SettingsEditBoxTemplate`, `SettingsEditBoxControlTemplate`, or public `Settings.CreateEditBox` in LIVE (`Blizzard_Settings_Shared/Blizzard_SettingControls.xml:80-190`; `Blizzard_Settings_Shared/Blizzard_Settings.lua:341-410`).
- `SearchBoxTemplate` is an `InputBoxInstructionsTemplate` specialization with search narration, a magnifying-glass icon, a clear button, search-specific focus visuals, and Enter/Escape focus clearing. It is not a general Config value field (`InputBoxTemplates.xml:205-254`; `.lua:175-235`).
- Multiline input is a composition rather than a differently styled single-line value field. Current shared options include `InputScrollFrameTemplate` and the ScrollBox/EventEditBox-based `ScrollingEditBoxTemplate` (`InputBoxTemplates.xml:72-175`; `Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.xml:21-44`).

### ENGINEERING RECOMMENDATIONS / INFERENCES

- Use `CreateFrame("EditBox", ..., "InputBoxTemplate")` for an ordinary addon-owned single-line value, set a deliberate size, and explicitly call `SetAutoFocus(false)` unless auto-focus is a product requirement.
- Use `InputBoxInstructionsTemplate` when a separate empty-field hint is useful. Keep the label separate from the instructions and keep actual domain state outside the widget.
- For a compact positive-integer field, `NumericInputBoxTemplate` is the strongest shared starting point when its focus-loss finalization model fits. An explicitly sized `InputBoxTemplate` plus `SetNumeric(true)` is also source-supported when the addon wants to own every callback.
- Use `NumericInputSpinnerTemplate` only when step buttons and live min/max clamping are desirable; it is a more opinionated control than a compact text field.
- For straightforward signed/decimal editing, `InputBoxTemplate` plus `SetNumericFullRange(true)` is now a runtime-verified native candidate on the tested Retail client. Application validation, range policy, canonical formatting, persistence, and locale-sensitive expectations remain caller-owned.
- Store the authoritative Config value in addon state. Parse, validate, clamp, and normalize through an explicit commit function; use the EditBox text as an editing buffer.
- The safest conventional policy is Enter = validate/commit/normalize then clear focus, Escape = restore the last accepted display then clear focus, and focus loss = application-specific. If focus loss commits, both Enter and default Escape ordering must be considered.
- Use `SetEnabled(false)`/`Disable()` for disabled input. There is no intrinsic read-only EditBox API in this source snapshot; use a FontString for ordinary display-only text. A selectable/copyable but non-editable field requires an intentional custom interaction design and runtime validation.

### USER-OBSERVED RETAIL LIVE FINDINGS

- `EditBoxComparison` loaded and operated successfully on Retail LIVE `12.1.0.69497`, both out of combat and during the tested actual-combat session. No Lua error or blocked-action report was supplied for the tested interactions.
- Direct typing produced `OnTextChanged(..., isUserInput=true)`. Programmatic refreshes observed during sample root-scale changes produced `isUserInput=false` across the standard, instructions, numeric, and spinner controls.
- In the standard `InputBoxTemplate` composition, Escape was observed as focus lost then the Escape hook (`#81`, `#82`), while Enter was observed as the Enter hook then focus lost (`#86`, `#87`). These hook orders were not symmetrical.
- `NumericInputBoxTemplate` Enter produced finalized value, focus lost, then the diagnostic Enter hook (`#20`-`#22` for value 123). Empty numeric text returned and finalized as `0` in this tested runtime composition, although the generated API signature remains documented as nilable.
- `SetNumeric(true)` accepted digits and empty text and rejected `-`, `.`, and `,`. `SetNumericFullRange(true)` accepted signed and period-decimal editing forms, including useful partial states, while rejecting `.` alone and comma input in the tested environment.
- `SetMaxLetters(5)` limited both tested ASCII and Greek strings to five reported letters. This is narrow evidence for those inputs, not a general Unicode/grapheme claim and not evidence about `SetMaxBytes`.
- Native spinner button changes were observed as value changed followed by text changed with `isUserInput=false`. Root scaling worked repeatedly at 75%, 100%, and 125%.

## 3. System inventory

| Identifier/system | LIVE classification | Definition and ownership | Practical role |
|---|---|---|---|
| `EditBox` | Intrinsic, current | `SimpleEditBoxAPI`; `UI.xsd` | Base editable text frame |
| `InputBoxScriptTemplate` | Shared, current | `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.*` | Focus, selection, Tab, Escape, narration behavior |
| `InputBoxVisualTemplate` | Shared, current | same XML | Standard three-piece border and `ChatFontNormal` |
| `InputBoxTemplate` | Shared, current general-purpose | script + visual templates | Ordinary standalone single-line input |
| `LargeInputBoxTemplate` | Shared, current specialized | same XML | 110x33 auction-style large numeric presentation |
| `InputBoxInstructionsTemplate` | Shared, current general-purpose specialization | same XML | Standard input with separate empty-field instruction overlay |
| `InputBoxTemplateWithInstructions` | **Absent exact identifier** | exact LIVE search | Do not invent this name |
| `InputBoxInstructionsMixin` | **Absent exact identifier** | exact LIVE search | Instruction behavior is supplied by global functions/scripts |
| `NumericInputBoxTemplate` | Shared, current numeric specialization | same XML/Lua | Numeric callbacks and focus-loss finalization |
| `NumericInputSpinnerTemplate` | Shared, current specialized | same XML/Lua | Compact value with step buttons, wheel, min/max, clamp options |
| `LevelRangeEditBoxTemplate` / `LevelRangeFrameTemplate` | Shared, current specialized | same XML/Lua | Paired positive-integer level range |
| `LargeMoneyInputBoxTemplate` / `LargeMoneyInputFrameTemplate` | Current subsystem-specific | `Blizzard_MoneyFrame/Shared/MoneyInputFrame.*` | Gold/silver/copper composition, not general Config input |
| `SharedEditBoxTemplate` | Current narrow specialization | `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.*` | 343x48 gray entry box currently used by Character Create |
| `SearchBoxTemplate` | Shared, current specialized | InputBox templates | Search/filter field with icon, clear button, search narration |
| `SearchBoxNineSliceTemplate` | Shared, current specialized | InputBox templates | NineSlice-search visual variant |
| `InputScrollFrameTemplate` | Shared, current older scroll composition | InputBox templates | Multiline edit box in a classic ScrollFrame |
| `ScrollingEditBoxTemplate` | Shared, current ScrollBox composition | `Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.*` | Multiline EventEditBox with callback-registry events |
| Settings EditBox control/API | **Absent** | Settings XML/Lua exact-name/API review | Settings has no native free-text list control |

`Blizzard_SharedXML.toc` loads both `Shared/InputBox/InputBoxTemplates.lua` and `.xml` and declares its supporting dependencies (`Blizzard_SharedXML/Blizzard_SharedXML.toc:3,184-202`). A standalone addon can declare `## Dependencies: Blizzard_SharedXML` as an explicit load-order contract.

## 4. General-purpose single-line input

### 4.1 `InputBoxTemplate` construction

`InputBoxTemplate` is a virtual `EditBox` inheriting two smaller templates:

- `InputBoxScriptTemplate` provides behavior and `NarrationEditBoxMixin`.
- `InputBoxVisualTemplate` provides `common-search-border-left`, `-right`, and `-middle` artwork plus `ChatFontNormal`.

The visual template's border pieces are 20 pixels high, but `InputBoxTemplate` declares no frame size. Current consumers commonly supply a height of 22 pixels and anchor or size the width themselves. Communities does this for its name and short-name fields; Calendar, Chat Config, Guild Control, and other unrelated features also instantiate `InputBoxTemplate` directly.

The template does not declare text insets. Callers can use the intrinsic `SetTextInsets(left, right, top, bottom)` API when their composition requires it. `LargeInputBoxTemplate` is different: it is 110x33, uses auction input atlases, owns `NumberFont_Normal_Med`, and sets 10-pixel left/right insets plus a 5-pixel bottom inset (`InputBoxTemplates.xml:13-41`).

### 4.2 Focus, mouse, and selection defaults

`InputBoxScriptTemplate` sets `enableMouse="true"`. Its inherited scripts implement:

- Tab: focus `previousEditBox` when Shift is down, otherwise `nextEditBox` when provided;
- Escape: call `ClearFocus()`;
- focus gained: call `HighlightText()` with the default full range;
- focus lost: call `HighlightText(0, 0)` to clear selection.

The intrinsic EditBox XML default is `autoFocus="true"`, not false. Blizzard therefore writes `autoFocus="false"` on most Config-like and dialog fields. New addon Config fields should do the same explicitly to avoid a window claiming keyboard focus merely because it appears.

The generated API exposes `SetFocus`, `ClearFocus`, `HasFocus`, `HighlightText`, `ClearHighlightText`, and `SetCursorPosition`. Focus and cursor APIs carry 12.1 forbidden-aspect checks; text and cursor getters/setters also carry secret-value annotations. These are API safety properties, not evidence that the ordinary shared template is secure or protected (`SimpleEditBoxAPIDocumentation.lua:20-35,87-113,408-455,646-675`).

### 4.3 Caller responsibilities

An addon using `InputBoxTemplate` must still provide:

- size and anchors;
- label, if any;
- initial text from external state;
- Enter behavior;
- any override of Escape behavior;
- validation, parsing, clamping, normalization, error feedback, and empty handling;
- when text becomes authoritative;
- persistence;
- enabled and read-only presentation policy.

The template is therefore a reusable input surface, not a complete setting row.

### 4.4 Other shared visual families

`SharedEditBoxTemplate` is not a replacement for `InputBoxTemplate`. It is a fixed 343x48 gray atlas field using `NumberFont_Shadow_Large`; its only direct LIVE inheritor found is Character Create, which adds an alphabetic-only name-control mixin (`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1348-1374`; `Blizzard_CharacterCreate/Blizzard_CharacterCreate.xml:489`).

`LargeInputBoxTemplate` is current and reusable, but its live consumers are large quantity, money, and transfer inputs. Its size, font, and auction-style art make it specialized rather than the default compact Config field.

## 5. Labels and instruction text

### 5.1 Labels

`InputBoxTemplate` owns no label. Current consumers normally use a sibling or wrapper-owned FontString. Communities places `NameEdit` and `ShortNameEdit` below separate label regions; the Class Talents dialog wrapper owns a `Label` and a child `InputBoxTemplate` (`Blizzard_Communities/CommunitiesSettings.xml:76-105`; `Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentLoadoutDialogTemplates.xml:3-34`).

`NarrationEditBoxMixin` can derive its narrated name from:

1. `narrationLabel`,
2. a region assigned through `SetNarrationLabelRegion`,
3. a `Label` region,
4. instructions when no label is present.

This is another reason to keep visual label ownership explicit (`Blizzard_Narration/Blizzard_NarrationEditBox.lua:6-36,61-89`).

### 5.2 Instructions/placeholders

`InputBoxInstructionsTemplate` inherits `InputBoxTemplate` and overlays an `Instructions` FontString. The overlay is `GameFontDisableSmall`, anchored with room inside the field, and is shown exactly when `GetText() == ""`. The actual EditBox uses `GameFontHighlightSmall` (`InputBoxTemplates.xml:177-203`; `.lua:131-173`).

The instructions are not native EditBox value text:

- `GetText()` returns only the actual value;
- callers set `editBox.Instructions:SetText(...)`;
- `InputBoxInstructions_OnTextChanged` toggles the overlay;
- the FontString declares no mouse scripts and does not own focus;
- instruction visibility is empty-text-dependent, not focus-dependent.

`InputBoxInstructionsTemplate` also reacts to enable/disable, but changes the actual EditBox text color only when the caller supplies `disabledColor` and `enabledColor`. LFG's specialized inheritor supplies `GRAY_FONT_COLOR` and `HIGHLIGHT_FONT_COLOR`; the base template merely documents those optional fields (`LFGList.xml:549-566`).

The Color Picker is a current compact example. Its 73x22 hex field inherits `InputBoxInstructionsTemplate`, sets the instruction to the hex label, adjusts text insets, sanitizes non-hex characters in `OnTextChanged`, and normalizes/apply the value on Enter (`Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.xml:158-177`; `.lua:115-159`).

## 6. Numeric input

### 6.1 Intrinsic numeric API

The intrinsic API exposes:

- `GetNumber()` and `SetNumber(number)`;
- `IsNumeric()` and `SetNumeric(bool)`;
- `IsNumericFullRange()` and `SetNumericFullRange(bool)`.

`GetNumber` is documented as returning a nilable number. `SetNumber` writes the displayed text from a number (`SimpleEditBoxAPIDocumentation.lua:278-290,535-559,789-818`). The generated documentation does not specify how empty text, a minus sign, a decimal separator, exponent syntax, or pasted invalid characters are treated.

Current `numeric="true"` consumers overwhelmingly model non-negative integral quantities: Calendar levels, guild stack/gold values, LFG item levels/ratings, Auction House quantities, money denominations, Professions craft counts, and currency transfer quantities. This establishes a source-supported positive-integer use case, but not the complete engine grammar.

No LIVE Lua/XML callsite of `SetNumericFullRange` was found. Its exact signed/decimal behavior was therefore unresolved by static source inspection; the user-observed runtime characterization is recorded in section 19 without changing that source finding.

### 6.2 `NumericInputBoxTemplate`

`NumericInputBoxTemplate` inherits the standard input visuals and focus behavior, sets `numeric="true"`, and attaches `NumericInputBoxMixin`.

- `OnTextChanged(isUserInput)` calls `valueChangedCallback(self:GetNumber(), isUserInput)`.
- `OnEnterPressed` calls `EditBox_ClearFocus`.
- `OnEditFocusLost` first clears highlight, then calls `valueFinalizedCallback(self:GetNumber())`.
- Callers install callbacks with `SetOnValueChangedCallback` and `SetOnValueFinalizedCallback`.

The callbacks default to `nop`, so initialization is optional. The template declares no size, max letters, auto-focus override, range, clamp, or display formatter.

`SliderAndEditControlTemplate` is the representative current consumer. Its value box is 30x22, three letters, and explicitly `autoFocus="false"`. Setup writes the number and installs a finalize callback; finalization clamps through the slider's min/max and the slider then writes the normalized value back to the box (`Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:1582-1622`; `.lua:1208-1239`).

Important ordering consequence: Enter clears focus, which causes the focus-lost finalization callback. The inherited default Escape also clears focus, so it causes the same focus-lost finalization unless the caller overrides Escape or makes the finalizer distinguish a cancel path. `NumericInputBoxTemplate` does not intrinsically implement Escape-as-restore.

### 6.3 `NumericInputSpinnerTemplate`

`NumericInputSpinnerTemplate` is a 31x20, three-letter, `numeric="true"`, `autoFocus="false"` EditBox with decrement/increment buttons and a wheel catcher. Its mixin owns `currentValue`, optional `min`/`max`, and an `onValueChangedCallback`.

- `SetValue` clamps through `Clamp(value, min, max)` when bounds exist.
- `clampIfInputExceedsRange` controls whether an out-of-range typed value is rewritten even when the stored value did not otherwise change.
- `highlightIfInputExceedsRange` selects a clamped entry for visible feedback.
- `OnTextChanged` immediately calls `SetValue(self:GetNumber())`.
- Shift+wheel steps by 10; ordinary wheel and buttons step by 1.
- Holding a stepper temporarily installs `OnUpdate` for repeat acceleration and removes it on mouse-up. This is event-scoped repeat behavior, not permanent polling.
- `SetEnabled` propagates to both buttons and the base EditBox.

Professions uses it for craft quantity with both clamp and highlight flags enabled, and enables/disables it according to craft availability (`Blizzard_Professions/Blizzard_ProfessionsCrafting.xml:205-223`; `.lua:396-402,722-726`). It is useful when steppers are part of the desired product, not a universal numeric-field default.

### 6.4 Feature-owned numeric controls

- Auction House quantity input inherits `LargeInputBoxTemplate`, uses `numeric="true"`, clears focus on Enter, treats zero as empty during text changes, and resets values below one on focus loss (`Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.xml:89-95`; `.lua:586-612`; `Blizzard_AuctionHouseSellFrame.lua:28-49`).
- Currency Transfer uses a feature-specific large numeric template. It clamps on both `OnTextChanged` and focus loss and writes the normalized number back immediately (`Blizzard_TokenUI/Blizzard_CurrencyTransfer.lua:460-509`).
- LFG's requirement wrapper can call `SetNumeric(self.numeric)`, assign instructions and max letters, validate on every text change, and keep validation state in the parent wrapper (`Blizzard_GroupFinder/Mainline/LFGList.xml:639-751`).
- `LargeMoneyInputFrameTemplate` composes separate numeric gold, silver, and copper fields and aggregates them into copper. Its currency-specific layout, denomination behavior, and addon dependency make it inappropriate for a generic percentage or Spell ID (`Blizzard_MoneyFrame/Shared/MoneyInputFrame.xml:3-76`; `.lua:7-119`).

### 6.5 Integer and decimal conclusions

For positive integral identifiers or counts, `SetNumeric(true)` is directly supported by current Blizzard use. A `NumericInputBoxTemplate` adds useful callback semantics; a plain `InputBoxTemplate` plus `SetNumeric(true)` leaves commit semantics fully addon-owned.

There is no separate general-purpose decimal EditBox template. Static source still provides no inspected `SetNumericFullRange` consumer or descriptive grammar contract, but the completed LIVE test now establishes `InputBoxTemplate` plus `SetNumericFullRange(true)` as a viable native candidate for straightforward signed/period-decimal editing on the tested client. Caller code must still own semantic validation, min/max policy, normalization, canonical formatting, persistence, and any locale-sensitive product requirements.

## 7. Focus and script semantics

| Script | Verified arguments after `self` | Shared default | Engineering meaning |
|---|---|---|---|
| `OnEnterPressed` | none found in current mixin handlers | none on `InputBoxTemplate`; clear focus on numeric/search specializations | Accept/apply remains caller-owned |
| `OnEscapePressed` | none | clear focus | No automatic rollback or parent close |
| `OnEditFocusGained` | none | select all text | Convenient replacement editing behavior |
| `OnEditFocusLost` | none | clear selection | No ordinary-input commit; numeric specialization finalizes |
| `OnTextChanged` | `isUserInput` boolean | none on ordinary input | Distinguishes typing from script-set text when the handler preserves it |
| `OnTextSet` | no general shared handler | absent from InputBox family | Chat uses it for parsing; not a Config commit convention |
| `OnChar` | typed `text` in inspected handlers | absent from InputBox family | Specialized character filtering only |
| `OnTabPressed` | none | linked previous/next focus | Requires caller-assigned neighbors |

`EventEditBoxMixin` independently confirms the `OnTextChanged` callback shape: it receives the intrinsic `userChanged` value and triggers `OnTextChanged(self, userChanged)`. Its Enter, Escape, and focus callbacks pass only the EditBox (`Blizzard_SharedXML/Shared/Frame/EventEditBox.lua:33-80`). Chat source also explicitly notes that programmatic `SetText` clears the user-input flag (`Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua:501-510`).

### 7.1 Enter

There is no one Blizzard-wide Enter policy:

- `NumericInputBoxTemplate`, Auction quantity, and SearchBox clear focus.
- Numeric focus loss then runs the finalize callback.
- Color Picker validates, fills a short hex string, and applies color without explicitly clearing focus.
- Class Talent dialogs forward Enter to the parent Accept operation.

A custom Config should call one explicit commit routine from Enter, then clear focus if the field remains visible. If the commit is wired to focus loss instead, clearing focus should be the only Enter action to avoid applying twice.

### 7.2 Escape

The base shared behavior only clears focus. It does not restore the last value or close the parent. Class Talent dialogs override Escape to invoke parent Cancel, while static popups dispatch a dialog-specific Escape callback (`Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentLoadout*Dialog.lua`; `Blizzard_StaticPopup/SharedTemplates.lua:21-69`).

For an addon Config editing buffer, Escape-as-restore is an engineering recommendation, not template behavior: set the displayed text back to the last accepted value, then clear focus. Override the base Escape script when using focus-loss finalization so Escape does not accidentally commit.

### 7.3 Focus lost

Plain `InputBoxTemplate` only clears highlighting on focus loss. It neither commits nor cancels. Blizzard consumers demonstrate multiple policies:

- `NumericInputBoxTemplate`: finalize current number;
- Auction quantity: reset values below one;
- Currency transfer: clamp and normalize;
- LFG requirement: update a companion checkbox when the field becomes empty;
- ordinary Communities text fields: no focus-loss semantic action.

Focus-loss behavior is therefore application-specific.

## 8. Value ownership and commit models

An ordinary EditBox owns its current presentation text and editing/focus state. It does not automatically own an addon setting, persist data, validate text, or define when the text becomes authoritative.

Representative models are:

### A. Live-update field

Communities name fields validate current text on every `OnTextChanged` to enable or disable the accept button. The actual club update still occurs through the dialog action; the EditBox is not persistent state (`Blizzard_Communities/CommunitiesSettings.xml:76-105`; `.lua:137-167`).

Currency Transfer takes a stronger live-update approach: every text change is parsed, clamped, written back, and propagated to feature state (`Blizzard_TokenUI/Blizzard_CurrencyTransfer.lua:467-505`).

### B. Commit-on-Enter field

Color Picker sanitizes live but normalizes and applies the hex value on Enter. Class Talent name/import controls send Enter to their parent Accept action.

### C. Commit-on-focus-loss field

`NumericInputBoxTemplate` defines this model explicitly through `valueFinalizedCallback`. `SliderAndEditControlTemplate` uses the callback to clamp through the linked slider and update external consumers.

### D. Cancel-on-Escape field

The shared input template does not provide this model. Class Talent dialogs implement it at the parent dialog level. An addon that wants in-place restore must retain a last-accepted external value and restore its formatted text explicitly.

### E. Display-only field

Recruit A Friend disables an EditBox used to show information (`Blizzard_RecruitAFriend/RecruitAFriendFrame.lua:1481-1485`). This is a feature example, not a generic read-only API. For ordinary non-copyable display, a FontString communicates intent more clearly than a disabled EditBox.

For addon Config, authoritative state should remain in the addon model or SavedVariables layer. The EditBox should be refreshed from that state and commit through an explicit parse/validate/apply path.

## 9. Disabled versus read-only

### 9.1 Disabled input

The intrinsic API provides `SetEnabled(bool)`, `Enable()`, `Disable()`, and `IsEnabled()`. Current consumers call these directly; Account Save disables its confirmation EditBox while a save is in progress, and Professions disables its numeric spinner when multiple crafting is unavailable (`SimpleEditBoxAPIDocumentation.lua:45-59,496-507,658-675`; `Blizzard_AccountSaveUI/Blizzard_AccountSaveUI.lua:55-84`).

Plain `InputBoxTemplate` does not automatically set a disabled font color. `InputBoxInstructionsTemplate` can set actual-text colors if optional colors are supplied. More complex wrappers may also show lock icons or tooltips. Disabled visual treatment beyond engine interaction state is caller-owned.

Disabling is not equivalent to calling `SetAutoFocus(false)`: auto-focus controls initial focus acquisition, while enabled state controls whether the field can be edited. `ClearFocus()` is prudent when disabling a currently focused field.

### 9.2 Read-only/display-only

No `SetReadOnly`, `IsReadOnly`, read-only XML attribute, or shared `ReadOnlyEditBoxTemplate` exists in the inspected LIVE source. `EnableMouse(false)` prevents ordinary mouse interaction; it does not establish a standard focusable, selectable, copyable-but-uneditable mode. `SetAutoFocus(false)` likewise does not prevent later edits.

Recommended distinctions:

- disabled form field: EditBox plus `SetEnabled(false)`, with explicit visual treatment where needed;
- ordinary display-only value: FontString;
- copyable display value: a purpose-built EditBox composition whose focus, selection, keyboard filtering, and accessibility are tested in-game.

The third case is not supplied as a general SharedXML template and should not be approximated by assuming that disabled means selectable read-only.

## 10. Validation and text limits

### 10.1 Length and byte APIs

The current intrinsic API exposes:

- `SetMaxLetters` / `GetMaxLetters`;
- `SetMaxBytes` / `GetMaxBytes`;
- `GetNumLetters`;
- `SetVisibleTextByteLimit` / `GetVisibleTextByteLimit`;
- `SetCountInvisibleLetters` / `IsCountInvisibleLetters`.

XML supports `letters`, `bytes`, `visibleBytes`, and `invisibleBytes`. EditBox XML defaults `letters` to zero; current consumers set explicit bounds such as 50-character community names, six-character short names, three-character levels, eight-digit quantities, and seven-digit transfer amounts.

`InputScrollFrameTemplate` displays `GetMaxLetters() - GetNumLetters()` as its remaining-character count. The API source exposes separate letter and byte limits but does not define enough UTF-8 edge behavior to claim how every multibyte or invisible sequence is counted. That boundary belongs in runtime validation if it matters to a product field.

In the completed LIVE sample, `SetMaxLetters(5)` accepted `abcde` and `αβγδε`, reported `GetNumLetters()=5` and `GetMaxLetters()=5`, and did not admit a sixth ASCII or Greek letter. This is user-observed evidence for those specific strings only. It does not establish general grapheme behavior, does not cover every Unicode sequence, and does not make letter limits equivalent to the separately exposed byte-limit APIs.

### 10.2 Validation ownership

There is no generic standalone EditBox validation framework. Current feature code uses several approaches:

- API-backed validation: Communities calls `C_Club.ValidateText`.
- custom sanitization: Color Picker removes non-hex characters on each text change.
- parse/default: LFG uses `tonumber(text) or 0` for requirements.
- range normalization: Slider-and-edit clamps through its slider; Currency Transfer uses `Clamp`; Auction quantity resets values below one.
- enable-only feedback: validation enables or disables the parent Accept button.
- warning UI: LFG's wrapper stores warning text and swaps its checkbox for a warning frame.

The reusable field should therefore expose or call a product-owned validator rather than embed arbitrary domain rules into the shared widget layer.

### 10.3 Normalization timing

Blizzard source supports live, Enter, focus-loss, and parent-accept normalization. None is universal. A practical addon policy is:

1. allow an editing buffer while focused;
2. parse and validate through one commit routine;
3. reject/restore or clamp according to the field's product contract;
4. write canonical formatted text after a successful commit;
5. keep external state unchanged on invalid input unless the product explicitly supports live validation.

## 11. Blizzard Settings integration

`Settings.VarType` includes Boolean, String, Number, and Table, so the setting model can own string or numeric values (`Blizzard_Settings_Shared/Blizzard_Settings.lua:11-16`). That does not imply a native text-entry control.

The current public Settings control constructors and templates cover:

- checkbox;
- slider;
- dropdown;
- color swatch;
- generic button and compound checkbox variants.

`Settings.CreateSliderInitializer` asserts a number setting with slider options. `Settings.CreateCheckboxInitializer` asserts boolean, and dropdown supports caller-defined options. No EditBox initializer or public `Settings.CreateEditBox` exists (`Blizzard_Settings_Shared/Blizzard_Settings.lua:330-410`).

Consequences:

- use `Settings.CreateSlider` for bounded numeric settings that suit a slider;
- use `Settings.CreateDropdown` for constrained discrete values;
- do not instantiate an imagined internal Settings EditBox for a custom Config window;
- a free-text Settings category needs a custom canvas/initializer composition, with the addon owning the EditBox semantics;
- an addon-owned Config window should normally use SharedXML input templates directly and keep persistence in addon state.

## 12. Search-box specialization

`SearchBoxTemplate` inherits `InputBoxInstructionsTemplate` and adds:

- `NarrationSearchBoxMixin` rather than ordinary edit-field narration;
- `instructionText = SEARCH`;
- magnifying-glass art;
- a clear button with its own narration and interaction states;
- left/right text insets for those child elements;
- `autoFocus="false"`;
- Enter and Escape both clearing focus;
- focus-dependent icon and clear-button state.

It remains an EditBox and reuses the instruction overlay, but its semantics are filter/search-specific. Current use across AddOn List, Collections, Group Finder, Settings search, Professions, and other systems demonstrates breadth as a search control, not suitability for Spell IDs, percentages, names, or other Config values. Search behavior warrants separate research only if a production feature needs a search field.

## 13. Multiline input distinction

Multiline input is not the recommended solution for compact Config values.

`InputScrollFrameTemplate` is a classic `ScrollFrameTemplate` composition whose child EditBox has `multiLine="true"`, `countInvisibleLetters="true"`, instructions, character count, cursor-driven scrolling, and an `OnUpdate` used to keep the cursor visible (`InputBoxTemplates.xml:72-175`; `.lua:21-129`).

`ScrollingEditBoxTemplate` is a newer `WowScrollBox` composition around an intrinsic `EventEditBox`. It registers callback events for text, cursor, focus, Enter, Escape, Tab, and key input and supplies optional default-text behavior (`Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.xml:21-44`; `.lua:1-70`).

These systems solve layout, wrapping, scrolling, cursor visibility, and multiline Enter behavior. They are architecturally separate from a 22-pixel single-line Config field. A full editor comparison would be a separate research topic.

## 14. Legacy and older patterns

No shared single-line input template inspected here is source-marked deprecated.

- `InputBoxTemplate` is older-looking infrastructure but remains current, shared, and broadly consumed. It should not be called deprecated.
- `InputScrollFrameTemplate` and `UIPanelInputScrollFrameTemplate` represent older ScrollFrame compositions and remain present/current. Their architecture can be called older, not deprecated.
- `ScrollingEditBoxTemplate` is the current ScrollBox/EventEditBox alternative for multiline compositions.
- `SharedEditBoxTemplate`, money input, Auction quantity, Character Services, Store, chat, autocomplete, and search templates are current but specialized or feature-owned. Their presence does not make them general addon dependencies.
- `Blizzard_DeprecatedChatInfo/Deprecated_ChatFrame.lua` explicitly preserves old chat helper aliases. That compatibility layer is source-marked deprecated, but chat input is outside this task and should not be copied for Config controls.

A Retail-only addon should avoid feature-owned templates merely for their art, avoid chat EditBox architecture for ordinary values, avoid invented Settings EditBox APIs, and avoid treating `LargeMoneyInputFrameTemplate` or `SearchBoxTemplate` as generic numeric/text controls.

## 15. Representative current Blizzard usage

| Feature | Field/template | Ownership and behavior | Classification |
|---|---|---|---|
| Communities Settings | `InputBoxTemplate` name/short name | separate labels, explicit 22px size, max letters, live validity, parent accept owns commit | Strong ordinary text example |
| Calendar | `InputBoxTemplate` and numeric attribute | titles/invites plus three-letter numeric level fields | Broad ordinary/current use |
| Shared slider-and-edit | `NumericInputBoxTemplate` | 30x22 value box, three letters, focus-loss finalize, slider clamp/normalization | Strong compact numeric Config-like example |
| Color Picker | `InputBoxInstructionsTemplate` | instruction overlay, hex sanitization live, normalization/apply on Enter | Strong placeholder/custom-validation example |
| LFG requirements | `LFGListEditBoxTemplate` | instructions, optional numeric mode, max letters, live validation/warning, feature security gates | Useful wrapper pattern; feature-specific |
| Auction House sell | `AuctionHouseQuantityInputEditBoxTemplate` | large positive quantity, live callback, Enter clears focus, focus-loss reset | Feature-specific numeric example |
| Currency Transfer | feature numeric template | live and focus-loss clamping, canonical rewrite, external event update | Strong clamping example |
| Professions crafting | `NumericInputSpinnerTemplate` | min/max, clamp/highlight, step buttons/wheel, enabled-state propagation | Strong spinner example |
| Recruit A Friend | disabled EditBox | display field disabled on load | Read-only-like feature example, not generic API |
| Settings panel | `SearchBoxTemplate`; no EditBox value control | search only; settings values use checkbox/slider/dropdown/etc. | Establishes Settings boundary |
| Character Create | `SharedEditBoxTemplate` | fixed large name field, alphabetic-only feature mixin | Narrow specialized shared template |
| Money frame | `LargeMoneyInputFrameTemplate` | three denomination fields aggregate into copper | Subsystem-specific composition |

## 16. Combat, taint, and API-safety considerations

### VERIFIED SOURCE FACTS

- `InputBoxTemplate`, `InputBoxInstructionsTemplate`, `NumericInputBoxTemplate`, and `NumericInputSpinnerTemplate` inherit ordinary `EditBox` templates, not `SecureActionButtonTemplate`, `SecureHandler` templates, or protected-action infrastructure.
- Their shared scripts perform presentation, focus, callback, numeric, and stepper behavior. No explicit combat-lockdown guard appears in those template definitions.
- The generated 12.1 EditBox API marks text/cursor operations with secret-value annotations and marks `SetFocus`, `ClearFocus`, `SetCursorPosition`, and `HasFocus` with forbidden-aspect checks.
- LFG adds secure references and disables script text mutation/paste for its own protected group-listing path. Those feature-specific restrictions are not properties of `InputBoxTemplate` itself.

### ENGINEERING INFERENCE / POLICY

An isolated addon-owned non-secure EditBox is likely to remain an ordinary input surface in combat, but absence of an explicit lockdown branch is not proof of universal combat safety. A commit callback can still attempt protected frame mutation, secure actions, runtime reconfiguration, or taint-sensitive work. Production code should either keep such callbacks presentation/state-only in combat or defer downstream restricted work according to the owning subsystem's policy.

Runtime validation should separately test the control and the callback it invokes.

### USER-OBSERVED RETAIL LIVE RESULT

Retail LIVE testing confirmed that the isolated addon-owned, non-secure `EditBoxComparison` controls and sample-local diagnostic callbacks remained interactive during actual combat in the tested session. No supplied Lua error or blocked-action report occurred during those interactions. This is a narrow sample PASS only: it does not establish universal combat safety for arbitrary production callbacks, protected-frame operations, secure actions, runtime reconfiguration, or taint-sensitive downstream work. The conservative production policy remains unchanged.

## 17. Third-party addon engineering assessment

1. **Ordinary single-line text:** use `InputBoxTemplate`, caller size/label, and explicit `SetAutoFocus(false)`.
2. **Compact text:** use the same template at a deliberate 22-pixel-style size; no separate compact-text template displaced it.
3. **Compact numeric field:** prefer `NumericInputBoxTemplate` when numeric callbacks/focus-loss finalization fit; otherwise use `InputBoxTemplate` plus explicit numeric mode and scripts.
4. **Integer input:** `SetNumeric(true)` is source-supported for current positive-integer fields. Keep range checks and semantic validation caller-owned.
5. **Decimal/signed input:** `InputBoxTemplate` plus `SetNumericFullRange(true)` is a runtime-verified native candidate for straightforward signed/period-decimal editing on the tested client. Product parsing/validation, range rules, canonical formatting, persistence, and locale-sensitive expectations remain caller-owned.
6. **Validation location:** one addon-owned validator/commit function, outside the generic field constructor.
7. **Validation timing:** application-specific; commit-on-Enter is the clearest default for a standalone field, with optional focus-loss commit for dense Config UX.
8. **Enter:** validate/apply/normalize, then clear focus; or only clear focus when focus loss is the sole commit trigger.
9. **Escape:** restore last accepted formatted value and clear focus when cancellation matters; default template behavior only clears focus.
10. **Focus loss:** choose deliberately. It may commit, clamp, or do nothing; never assume the base template commits.
11. **Placeholder:** use `InputBoxInstructionsTemplate` and set `.Instructions`; never store the hint as EditBox value text.
12. **Label:** use a separate FontString/wrapper and connect it to narration through `Label`, `narrationLabel`, or `SetNarrationLabelRegion` as appropriate.
13. **Disabled input:** use `SetEnabled(false)`/`Disable()`, clear focus, and add explicit visual treatment when the base art is insufficient.
14. **Read-only display:** use a FontString unless selectable/copyable text is a real requirement; then build and test a dedicated composition.
15. **Settings:** use native Settings sliders/dropdowns for bounded/discrete data. There is no native Settings EditBox control; custom free-text Settings UI remains addon-owned.
16. **Avoid:** chat architecture, search templates for non-search values, money/Auction/Store/Character Services templates as visual shortcuts, and invented or feature-internal Settings EditBox APIs.

## 18. Relevance to addon Config work

Without prescribing a production patch, the source-backed mapping is:

- numeric value beside a slider: `NumericInputBoxTemplate` or the complete `SliderAndEditControlTemplate` pattern when its visual/layout contract fits; clamp through the authoritative slider/value model;
- Spell ID: positive-integer `InputBoxTemplate`/`NumericInputBoxTemplate`, explicit max length, caller parse, and validation against the intended spell API before commit;
- whole-number percentage: numeric mode plus a 0-100 clamp and canonical integer formatting;
- decimal percentage or scale: `InputBoxTemplate` plus runtime-verified `SetNumericFullRange(true)` is a native candidate on the tested client; retain caller-owned finite-range validation, clamping, canonical formatting, and locale policy;
- fields that normalize typed values: retain last accepted external state, use one commit routine, and rewrite the display only after validation.

The shared control owns editing presentation. The addon owns domain semantics and persistence.

## 19. Retail LIVE runtime validation

The user tested `EditBoxComparison` on Retail LIVE `12.1.0.69497`. The observations in this section are runtime evidence supplied from that session, not conclusions derived from the static source. The sample loaded and operated out of combat and during actual combat without a supplied Lua error or blocked-action report.

### 19.1 Standard `InputBoxTemplate` and event order

The standard field gained focus, accepted ordinary typing, and lost focus normally. Direct typing, including character-by-character entry of `Config`, produced `OnTextChanged` with `isUserInput=true`. Programmatic refreshes observed during scale changes produced `isUserInput=false`.

The observed hooks were intentionally not symmetrical:

- Escape: `#81 standard focus lost.`, then `#82 standard Escape pressed.`
- Enter: `#86 standard Enter pressed.`, then `#87 standard focus lost.`

This is the order observed in the tested `InputBoxTemplate` plus diagnostic-hook composition. It should not be generalized to every EditBox specialization or caller script arrangement without additional evidence.

### 19.2 Instructions composition

`InputBoxInstructionsTemplate` rendered and accepted normal focus and typing. User entry produced `isUserInput=true`, and the native instruction presentation remained functional. Source inspection remains authoritative that the placeholder is the template-owned `Instructions` FontString rather than actual EditBox value text. Exact instruction-region mouse-hit behavior was not separately reported and remains unclaimed.

### 19.3 `NumericInputBoxTemplate`

Typing `1`, `12`, and `123` produced numeric value changes with `isUserInput=true`. Pressing Enter at 123 produced:

1. `#20 numeric finalized value=123.`
2. `#21 numeric focus lost.`
3. `#22 numeric Enter pressed.`

The tested composition therefore observed finalization before the focus-lost diagnostic hook, followed by the Enter diagnostic hook. Emptying the field produced `text=""` with numeric value `0`; later focus loss produced finalized value `0` then focus lost. A later value 5567 likewise produced finalized value 5567 then focus lost.

The generated API continues to document `GetNumber()` as returning a nilable number. The runtime result does not rewrite that signature: it establishes only that these tested empty numeric fields returned `0` in this client/composition.

### 19.4 `SetNumeric(true)` grammar

The tested ordinary `InputBoxTemplate` with `SetNumeric(true)` accepted digits and empty text. The user could not type `-`, `.`, or `,`. Empty text produced `GetNumber()=0`.

This supports unsigned integer-style editing in the tested Retail runtime. It does not supply semantic validation, min/max validation, clamping, canonical formatting, or persistence; those remain caller responsibilities.

### 19.5 `SetNumericFullRange(true)` grammar and `GetNumber()`

The tested ordinary `InputBoxTemplate` with `SetNumericFullRange(true)` accepted these editable forms:

- `123`
- `-1`
- `1.5`
- `-`
- `1.`
- `-1.`
- `-1.5`
- `00123`
- empty text

Observed rejected behavior:

- `.` alone was rejected.
- `,` alone was rejected.
- Entering `1,5` rejected the comma, leaving text equivalent to `15` and `GetNumber()=15`.

Observed text/value pairs were:

| Editing text | `GetNumber()` |
|---|---:|
| `123` | 123 |
| empty | 0 |
| `-` | 0 |
| `-1` | -1 |
| `1.` | 1 |
| `1.5` | 1.5 |
| `-1.` | -1 |
| `-1.5` | -1.5 |
| `0` | 0 |
| `00` | 0 |
| `001` | 1 |
| `0012` | 12 |
| `00123` | 123 |

The result characterizes a structured signed/period-decimal editing grammar, not unrestricted text. It permits useful partial editing states such as `-`, `1.`, and `-1.`, while the numeric interpretation is distinct from the literal editing buffer. `GetNumber()` does not preserve leading zeroes or incomplete decimal notation.

Period-based decimal input was accepted and comma was rejected on this tested client/runtime. This is not a claim about every WoW locale; locale-sensitive numeric requirements still need appropriate validation.

### 19.6 Max letters, disabled, and display-only

With `SetMaxLetters(5)`, `abcde` and `αβγδε` were accepted and both reported `GetNumLetters()=5` / `GetMaxLetters()=5`. Attempts to enter a sixth ASCII or Greek letter did not increase the field beyond five. This finding is limited to those tested characters and does not establish broad Unicode/grapheme semantics. `SetMaxBytes`/`GetMaxBytes` remained intentionally untested.

The disabled `InputBoxTemplate` and FontString display-only contrast rendered correctly. The sample retains ordinary disabled EditBox behavior for the former and a non-selectable FontString for the latter; no generic read-only EditBox or copy/select behavior is claimed.

### 19.7 Native spinner

`NumericInputSpinnerTemplate` rendered and operated successfully. Button interaction included `5 -> 6 -> 7 -> 8 -> 9` and `9 -> 8 -> 7`. Button-driven changes were observed as value changed followed by text changed with `isUserInput=false`; for example, `#51 spinner value changed to 6.` then `#52 spinner text changed userInput=false text="6".`

This supports the user-input distinction for native/programmatic spinner updates. Min/max overrun and mouse-wheel behavior were not explicitly supplied as tested results and remain open.

### 19.8 Scale and combat

Root-only scaling passed at 75%, 100%, and 125%, including repeated switching. Scale-related refreshes produced `isUserInput=false` updates in the spinner, `NumericInputBoxTemplate`, instructions field, and standard field. Scale and position remain non-persistent; the sample has no SavedVariables.

The isolated non-secure controls remained interactive during actual combat in the tested session. This PASS is limited to the sample controls and sample-local diagnostics. It does not establish that arbitrary production callbacks, protected-frame operations, secure actions, runtime reconfiguration, or taint-sensitive downstream work are combat-safe.

### 19.9 Remaining runtime questions

- spinner min/max overrun behavior in this exact sample;
- spinner mouse-wheel behavior in this exact sample;
- `SetMaxBytes`/`GetMaxBytes` behavior;
- exhaustive keyboard, gamepad, and narration behavior;
- broader locale behavior beyond the tested period-decimal/comma-rejection result;
- exact instruction-region mouse-hit behavior;
- broader Unicode/grapheme and invisible-character behavior.

## 20. Sample decision

**EditBoxComparison was created and completed its supplied Retail LIVE runtime test.**

The non-secure, no-SavedVariables, addon-owned module resolved the principal numeric-grammar, `GetNumber()`, `isUserInput`, event-order, tested letter-limit, scaling, and isolated-combat questions recorded above. It remains a research surface rather than production integration. The narrower unresolved items are listed in section 19.9.

## 21. Verified facts versus engineering inference

### VERIFIED SOURCE FACTS

- exact template inheritance, sizes where declared, fonts, art, scripts, mixins, and dependencies;
- `InputBoxTemplate` breadth and lack of label/validation/persistence;
- instruction overlay implementation;
- numeric mixin callbacks and focus-loss finalization;
- spinner clamping and stepper mechanics;
- current Settings control inventory and absence of a native EditBox control;
- representative caller validation/commit patterns;
- generated API method names and 12.1 safety annotations;
- absence of explicit secure-template inheritance and combat-lockdown branches in the ordinary shared controls.

### USER-OBSERVED RETAIL LIVE RESULTS

- standard Enter/Escape diagnostic-hook ordering in the tested composition;
- direct-user versus programmatic `isUserInput` distinction;
- numeric finalization ordering and empty-field `GetNumber()=0` in the tested fields;
- unsigned-integer behavior for `SetNumeric(true)`;
- structured signed/period-decimal grammar for `SetNumericFullRange(true)` on the tested client;
- five-letter enforcement for the tested ASCII and Greek strings;
- spinner button ordering, root scaling, and isolated combat interaction.

### ENGINEERING RECOMMENDATIONS / INFERENCES

- explicit `SetAutoFocus(false)` as the addon Config default;
- external authoritative state and one commit routine;
- Enter-as-commit, Escape-as-restore, and deliberate focus-loss policy;
- `SetNumericFullRange(true)` as a native signed/decimal candidate, with caller-owned product semantics and locale caution;
- FontString as the default display-only choice;
- conservative combat handling for downstream callbacks;
- continued use of `EditBoxComparison` as research evidence rather than a production prescription.

## 22. Final conclusions

`InputBoxTemplate` remains the strongest current general-purpose standalone single-line control for a Retail addon. It is current SharedXML infrastructure, broadly consumed, visually complete enough for ordinary fields, and deliberately leaves labels and domain behavior to its caller.

`InputBoxInstructionsTemplate` is the source-supported placeholder variant. Its instruction is a separate overlay, not value text. `NumericInputBoxTemplate` is the strongest compact callback-oriented numeric specialization, while `NumericInputSpinnerTemplate` is appropriate when the product specifically wants steppers and live clamping.

Current source supports `SetNumeric(true)` for positive-integer-style fields, and the completed LIVE test observed digits/empty input while rejecting sign and decimal punctuation. Static source still does not define `SetNumericFullRange` grammar, but the tested Retail runtime accepted structured signed/period-decimal forms and useful partial states. `SetNumericFullRange(true)` is therefore a viable native candidate for straightforward signed/decimal editing on the tested client, while validation, range policy, canonical formatting, persistence, and locale-sensitive expectations remain caller-owned.

Plain EditBoxes own temporary text, focus, and selection—not semantic state, validation, or persistence. A modern addon Config should keep authoritative values externally, explicitly define Enter/Escape/focus-loss behavior, clamp and normalize in product code, and use Settings-specific controls only when intentionally participating in Blizzard Settings.

## 23. Source index

Primary definitions and API documentation:

- `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.xml`
- `Blizzard_SharedXML/Shared/InputBox/InputBoxTemplates.lua`
- `Blizzard_SharedXML/Blizzard_SharedXML.toc`
- `Blizzard_SharedXML/UI.xsd`
- `Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua`
- `Blizzard_Narration/Blizzard_NarrationEditBox.lua`
- `Blizzard_SharedXML/Shared/Frame/EventEditBox.xml`
- `Blizzard_SharedXML/Shared/Frame/EventEditBox.lua`
- `Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.xml`
- `Blizzard_SharedXML/Shared/Scroll/ScrollTemplates.lua`
- `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml`
- `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.lua`
- `Blizzard_Settings_Shared/Blizzard_Settings.lua`
- `Blizzard_Settings_Shared/Blizzard_SettingControls.xml`
- `Blizzard_Settings_Shared/Blizzard_SettingControls.lua`

Representative consumers:

- `Blizzard_Communities/CommunitiesSettings.xml`
- `Blizzard_Communities/CommunitiesSettings.lua`
- `Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.xml`
- `Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.lua`
- `Blizzard_GroupFinder/Mainline/LFGList.xml`
- `Blizzard_GroupFinder/Mainline/LFGList.lua`
- `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.xml`
- `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSharedTemplates.lua`
- `Blizzard_AuctionHouseUI/Shared/Blizzard_AuctionHouseSellFrame.lua`
- `Blizzard_TokenUI/Blizzard_CurrencyTransfer.xml`
- `Blizzard_TokenUI/Blizzard_CurrencyTransfer.lua`
- `Blizzard_Professions/Blizzard_ProfessionsCrafting.xml`
- `Blizzard_Professions/Blizzard_ProfessionsCrafting.lua`
- `Blizzard_MoneyFrame/Shared/MoneyInputFrame.xml`
- `Blizzard_MoneyFrame/Shared/MoneyInputFrame.lua`
- `Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentLoadoutDialogTemplates.xml`
- `Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentLoadoutDialogTemplates.lua`
- `Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentLoadoutCreateDialog.lua`
- `Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentLoadoutEditDialog.lua`
- `Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentLoadoutImportDialog.lua`
- `Blizzard_AccountSaveUI/Blizzard_AccountSaveUI.lua`
- `Blizzard_RecruitAFriend/RecruitAFriendFrame.lua`
- `Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua` (script-semantics context only)
- `Blizzard_DeprecatedChatInfo/Deprecated_ChatFrame.lua` (deprecated compatibility classification only)
