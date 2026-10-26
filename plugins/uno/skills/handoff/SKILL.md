---
name: handoff
description: Write session state to a durable HANDOFF.md and generate the fresh-session kickoff prompt. Use when ending a work session, when asked for a "kickoff prompt" or "prompt for the next session", before /clear, and on resume when the user says "we got interrupted", "where do we stand", or "continue from yesterday".
---

# Handoff

Session state lives in a file in the project root, never in the user's clipboard or the tail of a previous answer. Two modes: **write** (ending a session) and **resume** (starting one).

## Write mode

Create or overwrite `HANDOFF.md` in the project root:

```markdown
# HANDOFF - <Session name>
Updated: <date time>

## Where we are
One paragraph: what this session did, current state of the work.

## Last verified state
- Build: <pass/fail, TFM, warnings>
- Runtime: <what was confirmed via uno-app, or "not verified">
- Git: <branch, last commit, uncommitted files>
- Lint (Uno Platform projects): <xaml-semantic-lint gating counts, e.g. CARD 0 · CODEBEHIND 3 (allowed); or "not run">

## Guidance applied (only if the session used skills, rules or plan decisions)
| Skill / rule / decision | Applied at (file:line) |
|---|---|
Read, not applied: <names, or "none">

## Next actions (in order)
1. ...
2. ...
3. ...

## Open questions
- ...

## Relaunch
<exact command(s): cd path, build/run, MCP notes>
```

Then output the paste-ready kickoff line:

> `Session: <name> (resume). Read HANDOFF.md, then the project's CLAUDE.md and SPEC.md if present. Read them cold - written in a prior session, don't assume. Continue from "Next actions".`

For spec-based fresh builds, use the proven fuller form: orient in order (1. the project's CLAUDE.md, 2. SPEC.md, 3. HANDOFF.md), treat the spec as source of truth, verify with uno-app after each phase, run `/handoff` before stopping.

## Resume mode

On "we got interrupted" / "where do we stand" / session start in a project with prior work:

1. Read `HANDOFF.md` if present.
2. `git status` + `git log -3` to catch drift since the handoff.
3. Read `SPEC.md` if the handoff references it.
4. Report where things stand in 3-4 lines, then continue from "Next actions" (or propose them if the handoff is stale).

If no `HANDOFF.md` exists, reconstruct from git + most recently modified files, say so, and write one before proceeding far.

## Rules

- Keep `HANDOFF.md` under a page. It is a pointer, not a transcript.
- Overwrite, don't append - the file is only ever the current state.
- **Every "applied" claim cites evidence.** A skill, rule or plan decision is listed as applied only with a `file:line` where the pattern is in the code, found by grepping for it before writing the row (e.g. `CardContentControl`, `utu:NavigationBar`). Zero hits means it moves to a "Read, not applied" line, never into the applied table, because the next session trusts the table without re-checking.
- **Uno Platform projects: run the lint before writing.** `pwsh -NoProfile -File uno-audit/scripts/xaml-semantic-lint.ps1 -Path <project>`, and copy the gating counts into *Last verified state*. Nonzero counts without `allow` reasons go under *Open questions*.
- **Export evidence for every new gotcha.** If the session added a Runtime Gotcha (to `uno-scaffolding/references/uno-runtime-gotchas.md` or a project note), copy the transcript excerpt behind it into the project repo before the transcript ages out of local retention (`cleanupPeriodDays`, 60). Source: `~/.claude/projects/<cwd-slug>/<session-id>.jsonl`; take the turns that show the symptom, the probe that isolated it, and the fix that held, as readable Markdown (tool output trimmed, no secrets). Save to `docs/evidence/<yyyy-mm-dd>-<gotcha-slug>.md` headed with session id, date, versions and the gotcha's one-line name, commit it with `docs: add evidence for <gotcha>`, and append `Evidence: <repo>/docs/evidence/<file>` to the gotcha bullet. A gotcha added without an exported excerpt goes under *Open questions*.

## Example

> "write me a prompt to kick off the next phase of building, I'll start a new session"
→ write HANDOFF.md capturing phase 1 results + phase 2 steps, output the one-line kickoff.

## Anti-pattern

Pasting the previous session's final answer as the new session's opening message. It carries stale reasoning, misses git drift, and dies with the clipboard.
