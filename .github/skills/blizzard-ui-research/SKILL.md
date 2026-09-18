---
name: blizzard-ui-research
description: Research Blizzard UI changes from primary sources such as Blizzard announcements, PTR notes, blue posts, Discord posts, release notes, and API documentation. Use when Codex needs to preserve original source material, identify API and behavior changes, and produce separate engineering analysis, migration notes, or addon-impact observations under D:\WoWDev\Projects without modifying source documents, reference material, addon repositories, or production code.
---

# Blizzard UI Research

Use this skill for research that turns Blizzard UI primary sources into reusable engineering knowledge. Source material is authoritative; preserve it exactly and create analysis separately.

## Boundaries

- Read original source material before analyzing it.
- Never edit, rewrite, summarize, normalize, or annotate source documents in place.
- Always preserve original wording in source material.
- Never modify `BlizzardResearch\<version>\Source` as part of analysis work.
- Treat Blizzard source mirrors and the Reference workspace as read-only unless the task explicitly authorizes changes there. Record the relevant branch, commit, client build, and worktree state before drawing conclusions.
- Do not modify addon code, addon repositories, or production files.
- Do not clean, remove, or modify unfamiliar or pre-existing untracked content, including project-local `.codex/` directories.
- Treat OUS impact notes as observations only unless the user explicitly asks for implementation work elsewhere.

## Retail-first Analysis

- Default to Mainline implementations.
- Prefer Mainline whenever both Mainline and Classic implementations exist.
- Include Shared code when Retail loads, references, inherits from, depends on, or uses it as implementation provenance.
- Do not include Classic files in the primary inspected file list. Consult another product family only when explicitly requested or when minimal inspection is needed to resolve provenance for a symbol demonstrably used by Retail or Shared.
- If Classic is consulted, clearly label it as supplementary and do not infer identical Retail behavior from a matching name.
- Keep engineering analysis focused on Retail.

## Source Material

Primary sources include Blizzard announcements, PTR notes, blue posts, Discord posts, release notes, API documentation, and similar original material.

Store source material under:

```text
D:\WoWDev\Projects\BlizzardResearch\<version>\Source
```

Analysis must live outside `Source`.

## Research Workflow

When researching Blizzard UI changes:

1. Capture the source and client provenance, then read the original material.
2. Establish Retail load and implementation provenance before classifying availability or behavior.
3. Identify API additions, removals, and behavioral or security changes.
4. Use bounded static searches to identify definitions, documentation, and callers.
5. Decide whether source settles the material questions; add a focused runtime test only when it does not.
6. Identify migration implications and opportunities for addon developers.
7. Produce engineering analysis separately from the source.

### FrameXML Source Walk

- Starting from the investigated Lua entry point, locate associated XML and template consumers; a `.lua` file is not necessarily the complete implementation. Inspect participating XML and record the paths checked, or explicitly record that no relevant XML exists.
- Follow the Lua-to-XML chain through templates, inherited templates, `Scripts` blocks, `OnLoad`/`OnShow`/`OnClick`/`OnEvent` handlers, and bindings where applicable. Follow XML calls back into the invoked Lua functions and API implementation/context to complete the reverse trace.
- Read the surrounding function, handler, and lifecycle branches rather than treating a search hit as sufficient context. Include nearby `FIXME`, `TODO`, implementation notes, and comments directly associated with the behavior.
- Capture relevant Blizzard developer comments separately with source locations. Bound interpretation to their literal wording and distinguish stated intent or concerns from established behavior; comments alone do not verify runtime behavior.

### Existing-Research Audit

- Read the existing document as the unchanged baseline, then compare each affected finding against the additional Lua/XML/source evidence and record its supporting locations.
- Classify results as **Confirmed**, **Additional context**, **Omission**, or **Correction required**, using the repository-root `AGENTS.md` definitions.
- Limit justified documentation edits to the affected claims or missing context. Do not reorganize, modernize, rewrite, or stylistically clean up working research during the audit.
- Retain historical runtime observations and controlled-test evidence; revise their interpretation only when specific new evidence invalidates it.

## Evidence Standards

Classify material conclusions explicitly:

- **VERIFIED SOURCE FACT:** directly established by the captured source, TOC, or generated declaration.
- **VERIFIED RUNTIME RESULT:** directly observed in a recorded client/build and exact tested composition.
- **SOURCE-SUPPORTED INFERENCE:** strongly supported interpretation that is not an explicit native or documented contract.
- **ASSUMPTION / UNKNOWN:** not established by the available evidence, including behavior below the observable Lua boundary or not exercised at runtime.

Identify documented API behavior as a declared contract, separately from source implementation findings, runtime observations, and inference.

Do not promote inference, correlation, or a historical runtime observation into a source fact or permanent compatibility rule. A research phase may close with bounded unknowns.

## Source, Load, and Runtime Layers

Keep these layers distinct when determining availability or compatibility:

- physical file or package presence;
- TOC inclusion and load-on-demand status;
- conditional execution and fallback/CVar gates;
- symbol installation;
- generated API documentation;
- static caller presence;
- runtime availability;
- actual runtime behavior.

Classify implementation provenance before making migration claims: Lua implementation, native/global engine function, generated declaration, compatibility wrapper, direct alias, semantic adapter, retained subsystem, or placeholder/no-op. One layer is not proof of another.

Static search is bounded evidence. Qualify textual caller counts as static and approximate. Zero callers does not prove removal or zero runtime use; no Lua definition does not prove absence of a native symbol; generated documentation does not prove runtime presence. Use runtime checks only when source cannot settle a conclusion that materially affects the research.

## Analysis Goals

When appropriate, answer:

- What changed?
- Why did Blizzard likely make this change?
- Is it breaking?
- Is migration required?
- Does it simplify existing addon code?
- Does it replace existing addon implementations?
- Does it create new opportunities?

Distinguish facts from engineering opinions. Cite or reference the source material behind factual claims when practical.

## Migration and Restricted-State Analysis

- Treat matching names as insufficient evidence of matching contracts. Compare identifier domains, argument and return shape, dropped or added fields, nil/default behavior, cache or readiness assumptions, multi-return semantics, and any enum/string/index translation.
- Distinguish a mechanical replacement from a compatibility adapter or an architectural migration.
- Keep taint, secret values, forbidden aspects, protected operations, secure templates or attributes, restricted APIs, combat lockdown, layout propagation, and data/cache readiness separate.
- Bound security and combat conclusions to the exact composition tested. Ordinary-frame success does not prove restricted-frame success, and a synthetic restricted-layout result does not establish a universal production rule.

## Runtime Method

Prefer passive observation before invasive wrappers, monkey-patching, or replacement of global functions. Instrumentation can alter timing, callback scheduling, cache state, error handling, taint, and security provenance; document that perturbation when it cannot be avoided.

When a controlled comparison is justified:

- change one relevant branch or variable at a time while preserving the environment as much as practical;
- record both clean and failing sides and repeat when practical;
- identify the exact build, addon composition, state, inputs, and observation point;
- treat selectors and repeatable correlations as narrowing evidence, not proof of the exact callback, component, or root cause.

## Engineering Focus

Prefer engineering analysis over feature summaries. Identify:

- New APIs.
- Deprecated APIs.
- Removed APIs.
- Security changes.
- Performance implications.
- Framework evolution.
- Migration strategy.

## OUS Considerations

When relevant, document possible impact on OdysseusUtilitySuite areas such as:

- BuffBars.
- XP Bar.
- Edit Mode.
- Settings.
- Utilities.
- Future modules.

Keep these as planning observations. Do not modify addon code.

## Outputs

Prefer creating or updating documents under:

```text
D:\WoWDev\Projects\BlizzardResearch\<version>
+-- Analysis
+-- OUS
+-- SUMMARY.md
```

Prefer updating existing analysis documents over creating duplicates. Preserve engineering history whenever practical.

Final research documentation should identify the captured source snapshot, verified source findings, runtime evidence, inference, engineering guidance, and explicit unknowns without excessive boilerplate. Include useful source paths and build/commit provenance, keep wording bounded to the evidence, and synchronize roadmap or status documents when the task requires it.

## Provenance Separation

- Keep frozen or instrumented third-party references separate from current live addon installations. State which copy and version produced each result.
- Never mix source or runtime evidence across client builds without explicit comparison framing. Later-build changes are future evidence and must not be retroactively attributed to an earlier snapshot or run.

## Validation

After changing research documentation or methodology:

- read every changed document completely;
- search for stale wording or contradicted conclusions where relevant;
- review the complete diff and `git status --short`;
- run `git diff --check` and any focused validation appropriate to the changed artifact;
- verify that source mirrors, reference material, addon repositories, and unrelated project files remain unchanged.

Do not stage, commit, push, or tag unless the user explicitly authorizes that Git action.

## General Rules

- Keep source material intact.
- Keep source, analysis, OUS observations, and summaries separate.
- Use incremental updates.
- Preserve prior notes unless the user explicitly asks to remove or replace them.
- Avoid hardcoded machine-specific assumptions outside the documented `D:\WoWDev` workspace.
