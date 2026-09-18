---
name: ptr-analysis
description: Compare two or more PTR builds over time to identify Blizzard UI evolution, API additions/removals/renames, behavioral and security changes, framework trends, migration paths, and addon-engineering recommendations. Use when Codex is analyzing PTR1 to PTR2, PTR2 to PTR3, PTR1 to PTR4, or an entire expansion lifecycle from preserved source material under D:\WoWDev\Projects without modifying Source, addon repositories, Reference, or production code.
---

# PTR Analysis

Use this skill for analysis across multiple PTR builds. Unlike Blizzard UI Research, which analyzes individual source documents, this skill compares PTR builds over time to identify evolution, migration paths, and engineering trends.

## Scope

Use this skill whenever two or more PTR builds are available, such as:

- PTR1 to PTR2.
- PTR2 to PTR3.
- PTR1 to PTR4.
- An entire expansion lifecycle.

## Retail PTR Scope

- Treat PTR analysis as Retail analysis by default.
- Ignore Classic-specific implementations unless the user explicitly requests them.
- Report inspected Retail files only.
- Mention Classic only when it materially affects the engineering analysis.

## Boundaries

- Follow the repository-root `AGENTS.md`.
- Preserve source material unchanged.
- Never modify `BlizzardResearch\<version>\Source`.
- Do not modify existing analysis documents unless the user explicitly asks to update them.
- Do not modify addon repositories, the Reference workspace, Lua files, or production addon code.
- Treat OUS impact notes as engineering observations only.

## Workflow

When comparing PTR builds:

1. Read all requested PTR source documents.
2. Preserve source material unchanged.
3. Compare builds chronologically.
4. Identify new APIs.
5. Identify removed APIs.
6. Identify renamed APIs.
7. Identify behavioral changes.
8. Identify security changes.
9. Identify framework evolution.
10. Identify migration recommendations.

## Focus

Prefer trends over isolated features. When appropriate, answer:

- What direction is Blizzard moving?
- Which systems are replacing older systems?
- Which APIs appear transitional?
- Which APIs appear stable?
- Which implementation patterns should addon authors adopt?

## Engineering Output

Prefer updating existing documents under:

```text
D:\WoWDev\Projects\BlizzardResearch\<version>\Analysis
```

or updating:

```text
D:\WoWDev\Projects\BlizzardResearch\<version>\SUMMARY.md
```

Avoid creating duplicate documents when an existing analysis or summary can be extended while preserving engineering history.

## Migration Analysis

Identify:

- Breaking changes.
- Migration strategy.
- Deprecated implementations.
- Recommended replacements.

Call out uncertainty when source material does not fully prove a recommendation.

## OUS Considerations

When appropriate, identify possible impact on OdysseusUtilitySuite areas such as:

- BuffBars.
- XP Bar.
- Edit Mode.
- Settings.
- Future modules.

Keep these as engineering observations. Do not implement addon code.

## Evidence Standards

Separate findings into:

- Facts from source material.
- Engineering interpretation.
- Recommendations.

Prefer chronological evidence. Make clear when a trend is inferred from multiple builds rather than explicitly stated by Blizzard.

Record source and runtime provenance for each build independently. Never attribute later-build behavior to an earlier snapshot except in an explicit comparison, and do not retroactively rewrite the earlier evidence set.

## General Rules

- Never modify Source.
- Prefer updating existing analysis over creating duplicates.
- Preserve engineering history whenever practical.
- Keep migration advice tied to observed PTR evolution.
- Keep production implementation work outside this skill.
