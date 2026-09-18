# Blizzard Research Guidance

These instructions govern the BlizzardResearch repository. Research guidance is maintained here, not in parent workspace files.

## Repository Scope and Skills

This repository contains Blizzard UI/API research, analysis, migration planning, and isolated research samples. It is not a production addon source tree. Production implementation belongs in the appropriate addon repository and requires a separate authorized task.

Use the repository-local skills for the relevant workflow:

- [Blizzard UI Research](.github/skills/blizzard-ui-research/SKILL.md) — source-backed UI/API investigations and engineering analysis.
- [PTR Analysis](.github/skills/ptr-analysis/SKILL.md) — chronological comparisons of two or more PTR builds.

## Source, Analysis, and Reference Boundaries

- Preserve original source material and wording. Never edit, annotate, rewrite, or normalize `<version>/Source` material in place; keep interpretation in separate analysis documents.
- Keep research, analysis, addon-impact observations, and summaries separate. Prefer incremental updates to existing documents, preserve engineering history, and use only the document sections the task needs.
- Mainline is authoritative for Retail research. Keep conclusions Retail-focused; any explicitly requested comparison or necessary Classic provenance context must remain clearly labeled and supplementary, as bounded by the research skill.
- Treat external Blizzard source mirrors, third-party references, and frozen prototypes as read-only unless a separate task explicitly authorizes changes. Do not modify reference material to facilitate research.
- Keep production addon code outside this repository. Treat addon-impact notes as planning observations, not authorization to implement them.
- Project memory provides context, not proof of current behavior. Verify against the relevant captured source or runtime evidence; distinguish committed content from local uncommitted work.
- Do not stage, commit, push, or tag unless explicitly authorized.

## Source-research Completeness

- Do not assume a `.lua` file contains the complete implementation. For FrameXML/UI behavior, inspect relevant associated `.lua` and `.xml` files when both exist or XML templates/scripts may participate. If no relevant XML exists, state that rather than implying it was checked.
- Trace behavior in both directions: Lua functions, callbacks, and events into XML templates, `Scripts`, handlers such as `OnClick`/`OnShow`, inherited templates, and bindings where relevant; and XML handlers/templates back into the Lua functions and APIs they invoke.
- Do not stop at a search hit. Read enough surrounding source to establish control flow and context, including relevant adjacent developer comments, `FIXME`, `TODO`, and implementation notes.
- Report relevant Blizzard developer comments separately. Interpret them only as far as their literal wording supports: a comment may establish developer intent or a known concern, but is not by itself proof of runtime behavior.
- Keep source findings, documented API behavior, and runtime observations clearly distinguished.

## Auditing Existing Research

When auditing existing research against XML or additional Blizzard source, preserve the existing research as the baseline. Do not rewrite, reorganize, or stylistically modernize it merely because additional source was inspected.

Classify audit findings as:

1. **Confirmed** — additional source supports the existing finding.
2. **Additional context** — useful information was missing but does not change the conclusion.
3. **Omission** — relevant behavior or a developer comment should have been captured.
4. **Correction required** — existing research is contradicted or materially incomplete.

Make documentation changes only when justified by the audit, keeping them narrowly additive or corrective. Preserve historical runtime observations and controlled-test evidence unless new evidence specifically invalidates their interpretation.
