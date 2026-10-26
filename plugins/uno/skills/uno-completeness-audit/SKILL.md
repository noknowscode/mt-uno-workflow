---
name: uno-completeness-audit
description: "Granular completeness audit for an Uno Platform app: checks whether the app is actually done across 16 areas (screens, navigation, interactions, logic, data, states, forms, authentication, responsive/adaptive UI, platform behavior, failure handling, accessibility, performance, security/privacy, visual quality, testing), grading every item by evidence (runtime-proven, code-read, inferred, not checked) and treating absence, stubs and simulation as findings. Use when asked \"is this app complete / done / shippable\", \"what's missing\", \"what's still fake, stubbed or simulated\", \"completeness audit\", \"readiness review\", \"pre-demo or pre-release checklist\", \"does it match the spec\", or to score a generated app against its design. Do NOT use for code hygiene, dead code or stack currency (see uno-audit), building loading/empty/error states (see uno-component-states), or a plain build-and-run check (see uno-verify)."
metadata:
  version: "1.0.0"
  created: "2026-09-20"
  category: "uno"
---

# Uno Completeness Audit

Answer one question with evidence: **is this app complete, or does it only look complete?**

`uno-audit` asks whether the code is clean. This skill asks whether every intended surface exists, every control does something
real, every rule is implemented instead of drawn, and every claim of "done" was proven on the
target platforms. It produces a graded report. It changes code only when told to.

## Non-negotiables

These hold even if no reference file is opened.

1. **Inventory before scoring.** Enumerate what the app is *supposed* to have (from the spec,
   design, route registrations, menus, and the product domain) before checking what it has. A
   missing screen can only be found against a list of intended screens. No spec: derive the
   inventory from `ViewMap`/`RouteMap` registrations, XAML pages, nav menus, and the domain, and
   say the inventory is derived.
2. **Every item carries a status and an evidence grade.** Status is one of `Complete`,
   `Partial`, `Simulated`, `Missing`, `Broken`, or `N/A`. Evidence is one of `R` (proven at
   runtime via the App MCP, a test run, or a device), `C` (read in code), `I` (inferred), `X`
   (not checked). A `Complete` graded `C` is reported as *unproven*; on a critical workflow it
   does not count as complete.
3. **Absence is a finding.** An area is never scored `N/A` because the capability was removed,
   stubbed, or never built. `N/A` requires a stated product reason ("single-user local tool, no
   accounts by design"), and that reason goes under Unresolved Questions so the user confirms it.
   See `uno-scaffolding/references/capability-coverage.md`.
4. **Simulated is not Complete.** Hardcoded results, sample data on the production path, fake
   delays, `TODO`/`NotImplementedException`, a button that only shows a toast, a chart that is
   three static bars, a map that cannot pan, a play button that starts a timer: all `Simulated`.
   UI that impersonates a capability the app lacks is a Blocker, not a cosmetic note.
5. **Runtime proof comes from you, never the user.** Launch through `uno-verify` (App MCP,
   `uno_app_start`, devserver connected). Drive workflows with `uno_app_visualtree_snapshot` and
   `uno_app_element_peer_default_action`. Never ask the user to click something the MCP can click.
   What the MCP cannot drive (drags, modifier chords, a phone) is recorded `X` with the reason,
   never assumed.
6. **Per-platform, never by proxy.** A workflow proven on `net10.0-desktop` is `X` on Android,
   iOS and WebAssembly until it is run there. The report lists each supported head separately.
7. **The three silent-failure classes must be probed, not read.** Each one compiles, renders,
   and screenshots perfectly:
   - a dead binding (`{Binding Refresh}` inside `FeedView.ErrorTemplate`,
     `{Binding Data.X, Mode=TwoWay}`);
   - a swallowed exception (a DI failure during navigation renders a page with a null
     `DataContext` and a blank screen, no error anywhere);
   - a feed that dedupes an unchanged value so refresh never re-fetches.
   Proof is a trace: invoke the control, then confirm the service ran or the state changed
   (`uno_app_get_element_datacontext`, a per-call trace, a file write). See
   `uno-scaffolding/references/uno-runtime-gotchas.md` for the full list.
8. **Report first, fix second.** Default output is the report. With `--fix` or an explicit ask,
   fix in severity order, route each fix to its owning skill (table below), and re-prove at
   runtime. Fixes that add a dependency or change the data model, a service lifetime, or a
   platform fallback pause for the user's decision first.
9. **Numbers, not adjectives.** Counts of screens, routes, dead controls, unchecked heads.
   Measured startup time, worst frame, touch-target sizes. "Feels slow" is not a finding.

## Invocation

```
/uno-completeness-audit [project-dir]
/uno-completeness-audit --areas screens,navigation,states,forms
/uno-completeness-audit --platforms desktop,android
/uno-completeness-audit --workflows "create deal, sign in, export report"
/uno-completeness-audit --fix
```

- No `--areas`: all 16. Scoped areas still get the inventory step and the report shell.
- No `--platforms`: every TFM in the csproj, with heads you cannot run recorded `X`.
- No `--workflows`: derive 3 to 7 critical workflows from the inventory and list them for
  confirmation in the report.

## Procedure

### Step 0 - Orient and load the owners

`HANDOFF.md` first, then git state, then `SPEC.md`/design files, then the csproj (TFMs,
`UnoFeatures`, packages). Load the guidance for the areas the audit will touch and cite it while
checking. Uno Platform Studio skills come from the `uno-platform-studio` plugin; anything not
covered there comes from the Uno docs MCP:

| Area | Guidance for checks and fixes |
|---|---|
| Navigation | Uno Platform Studio `uno-navigation-*` |
| Interactions, Logic, Data, States | Uno Platform Studio `uno-mvux-*` (MVUX apps), `uno-scaffolding` |
| States (building missing ones) | `uno-component-states` |
| Forms, Toolkit controls | Uno Platform Studio `uno-toolkit-*` |
| Authentication, remote data, persistence, DI | Uno docs MCP (Uno Extensions) |
| Responsive/adaptive, Platform behavior | Uno Platform Studio `uno-toolkit-*` (SafeArea, ResponsiveExtension), `uno-scaffolding` |
| Accessibility, Performance, Security/privacy | Uno docs MCP and Microsoft Learn |
| Visual quality, theming | Uno Platform Studio `uno-themes-*` |
| Testing, runtime driving | `uno-verify`, Uno Platform Studio `uno-testing-*` |

### Step 1 - Build the inventory

Produce four lists before any grading:

```
Screens:      every page, dialog, modal, tab, menu, flyout, overlay the design or spec implies
Routes:       every registered route + every navigation trigger (Navigation.Request, menus, back, deep links)
Interactions: every Button, TextBox, toggle, gesture, MenuFlyoutItem, link, command, swipe, long-press
Workflows:    3-7 end-to-end paths a real user completes (sign in > create > edit > save > reopen)
```

Mark each screen and interaction `intended`, `present`, or `present but unreachable`. Grep is
the tool for `present`: `ViewMap`, `RouteMap`, `Navigation.Request`, `Command=`, `Click=`,
`x:Class` across `*.xaml`. The design or spec is the source for `intended`.

### Step 2 - Static sweep, area by area

Run the checklist for each area in scope from the reference files. Every check records
status, evidence grade, and a `file:line` or element name. A check with no location is not a
finding.

- [references/01-surface.md](references/01-surface.md) - Read for Screens, Navigation, Interactions
- [references/02-behavior.md](references/02-behavior.md) - Read for Logic, Data, States, Forms
- [references/03-identity-platform.md](references/03-identity-platform.md) - Read for Authentication, Responsive/adaptive UI, Platform behavior
- [references/04-resilience.md](references/04-resilience.md) - Read for Failure handling, Performance, Security/privacy
- [references/05-quality.md](references/05-quality.md) - Read for Accessibility, Visual quality, Testing
- [references/06-report-template.md](references/06-report-template.md) - Read before writing the report; holds the template, severity rules, and a worked example

### Step 3 - Runtime proof pass

Launch via `uno-verify`. Then, at minimum:

1. Drive every critical workflow end to end on the desktop head. Assert post-state through the
   visual tree or DataContext, never through a screenshot alone.
2. Drive one error and one retry per data-bearing screen: flip the service to fail, invoke Retry,
   confirm the service ran again. (`{Binding Refresh}` in an ErrorTemplate is the known dead
   button; `FeedView.Refresh` does not recover a failure upstream of the bound feed.)
3. Drive one empty state per list. Absence must arrive as data, not as an exception.
4. Resize to two widths and two heights (landscape phone height is where fixed-height rows clip).
5. Kill and relaunch after a write; confirm the write persisted.
6. Run every other supported head you can reach (`uno_app_start` with the TFM, an emulator, a
   browser). Each head gets its own row in the report.

Every item promoted to `R` names the proof (element ref, DataContext value, trace line, file).

### Step 4 - Grade and report

Use the template in [references/06-report-template.md](references/06-report-template.md).
Severity:

- **Blocker**: a critical workflow is `Missing`, `Broken`, or `Simulated`; a security finding;
  a head that crashes on launch.
- **Major**: any other `Missing`/`Broken`/`Simulated`; a `Complete` item with evidence `X` on a
  supported head; an unhandled state on a data-bearing screen.
- **Minor**: `Partial` items, unproven `C`-grade items off the critical path, visual residue.

Verdict is one of: **Complete** (0 Blockers, 0 Majors, every critical workflow `R` on every
supported head), **Complete with gaps** (0 Blockers), **Incomplete** (any Blocker). Do not
soften the verdict for a demo deadline; say what the demo can safely show instead.

### Step 5 - Fix mode (only with `--fix` or an explicit ask)

Blockers first, then Majors. Each fix cites the guidance it follows, lands as its own
conventional commit when the user has asked for commits, and is re-proven at runtime before it
moves from the findings list to the fixed list. After two failed fix cycles on one root cause,
stop and report what was tried, the evidence, the likely cause, and two or three options.

## Stay in lane

- Code hygiene, dead code, stack currency, warnings: `uno-audit`. Note them in one line, do not
  act.
- Spacing, hierarchy, copy, fit and finish are design polish, out of scope. Visual quality here
  means placeholders, debug UI, lorem ipsum, unfinished screens; anything past that is a note
  for a separate design pass.
- A capability the design implies and the app lacks (video, map, chart, localization) is a
  `Missing` finding here and a capability-coverage decision for the user
  (`uno-scaffolding/references/capability-coverage.md`), never something this skill quietly
  substitutes.

## Output

The report from the template, then a short summary of what changed. Always end with
`## Unresolved Questions` listing every `N/A`, every `X` on a supported head, and every derived
inventory item the user should confirm.

Save a full-app audit to `docs/COMPLETENESS.md` in the project, overwriting it: it is the current
verdict. The *Build gates* in `uno-scaffolding/references/uno-scaffolding.md` require it before
any "done / shippable / ready to demo" claim. The optional Stop hook `hooks/uno-done-guard.ps1`
(repo root, opt-in) enforces this. A feature-scoped audit stays in the response.

## Example

> "is the CRM app ready to demo on Thursday?"
→ inventory: 11 screens intended, 9 present, 1 unreachable (no route for `SettingsPage`);
6 critical workflows; desktop `R` on 5, Android `X` (no device attached); 2 Blockers (Retry on
Accounts is a dead binding; Deals export button shows a toast and writes nothing); verdict
Incomplete; "the demo can show create/edit/list safely, keep export and error recovery off
screen". User asks `--fix`: both Blockers fixed, re-proven, two commits.

## Anti-pattern

Scoring 16 green rows from reading XAML, calling the app complete, and finding out on stage that
the Save button never wrote a file. The build, the review, and the screenshots all passed. The
audit had no `R` in it.
