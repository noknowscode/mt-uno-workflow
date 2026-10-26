---
name: uno-break-it
description: Adversarial QA for a running Uno Platform app via the Uno App MCP. A separate breaker subagent works an Uno-specific attack catalog (navigation races, responsive edges, theme flips, placeholder text, hit-test leaks, forced FeedView states, memory growth, Skia text, keyboard-only) and writes each finding, with a severity and a screenshot, to docs/FINDINGS.md. Use before publishing a sample, after a multi-screen milestone, or when the user says "break it", "try to break this", "QA pass", "find bugs", "adversarial test". Do NOT use for grading whether an app is complete or shippable (see uno-completeness-audit) or a plain build-and-run check (see uno-verify).
---

# uno-break-it

The App MCP is the headless browser. The breaker's job is to prove the app is broken; its success
metric is the number of confirmed findings. Fixing is someone else's job.

## Roles

- **Breaker**: a separate subagent spawned by this session. It runs the catalog, writes findings,
  and later verifies fixes. It never edits app code.
- **This session**: spawns the breaker, waits for the run to finish, then fixes findings (or hands
  them out) and asks the breaker to re-verify.

Spawn the breaker as a general-purpose subagent. Its prompt carries: the project path, the
*Setup*, *Attack catalog*, *Finding record* and *Limits* sections below verbatim, and the instruction
"run every attack, write findings, do not fix anything, report the recap line". The breaker needs
the Uno App MCP tools (`uno_app_*`), so the session must be started in the project folder (see
uno-verify).

This skill is a gate for any new app or multi-screen milestone
(`uno-scaffolding/references/uno-scaffolding.md`, *Build gates*).

## Setup (breaker)

1. Confirm the session root contains the `.sln`/`.slnx` and `.mcp.json` (uno-verify rules).
2. `dotnet build -f net10.0-desktop`, then `uno_app_start`; `uno_app_get_runtime_info` to confirm.
   If the app reads `--width/--height` launch args, pass `args:["--width","1280","--height","800"]`;
   otherwise size the window directly (resize twice before capturing; see the resize gotcha in
   `uno-scaffolding/references/uno-runtime-gotchas.md`).
3. Read `docs/FINDINGS.md` for the next ID; create it with the header below if missing.
4. Baseline: `uno_app_visualtree_snapshot(includeBounds:true)` and `uno_app_get_memory_counters`.

Identify elements by `AutomationProperties.AutomationId` or `x:Name`. Prefer
`uno_app_element_peer_default_action` over coordinates. Re-snapshot after every state change.

## Attack catalog (run all; add to it)

| # | Attack | How | Evidence |
|---|---|---|---|
| A1 | Navigation double-fire | trigger the same `Navigation.Request` twice within 200 ms; navigate back immediately | duplicate pages in tree, exception in output, blank frame |
| A2 | Navigate during load | trigger navigation while a `FeedView` shows its loading template | stale data on new page, crash, spinner never ends |
| A3 | Deep-link back-stack | start at a non-root route; press Back | app exits, or lands on wrong page |
| A4 | Responsive edges | relaunch at widths 320, 599, 600, 904, 905 and height 500 | clipped content, overlapping text, horizontal scroll |
| A5 | Theme flip | toggle `RequestedTheme` at runtime (a debug command or settings toggle) | hardcoded colors, invisible text, shadows gone |
| A6 | Content reality | search the visual tree text for `Lorem`, `TODO`, `TextBlock`, `Button`, empty `Text`, mixed EN/FR | placeholder or blank labels |
| A7 | Text scaling and long strings | 200 % text scale; inject a 120-char title through the model | truncation without ellipsis, layout burst |
| A8 | Hit-test leak | open a popup/overlay/expanded card; snapshot with `includeHidden:true`; fire peer actions on elements underneath | action fires behind the overlay |
| A9 | Forced states | put every `FeedView` into empty, error, loading through the model or a debug switch | missing template, raw exception text, no retry |
| A10 | Memory loop | navigate A→B→A 20×; compare `uno_app_get_memory_counters` to baseline | monotonic growth ⇒ Storyboard not stopped / handler not detached |
| A11 | Skia text | scan for tofu glyphs; check variable fonts render more than the default instance | wrong weight, boxes |
| A12 | Keyboard only | `uno_app_key_press` Tab/Shift+Tab/Enter/Space through every screen | focus trap, unreachable control, no focus visual |
| A13 | Rapid input | `uno_app_type_text` with `intervalInMs:5` into search/filter fields; spam a toggle 20× | dropped input, exception, doubled items |
| A14 | Hot reload survival | make a trivial XAML edit while on a deep page | state lost, page reset to root |
| A15 | Automation coverage | list interactive elements without `AutomationId` | each one is a P3 finding |
| A16 | Latency inversion | in a search/filter field, make the first request slow (the app's slow service mode, or a debug delay keyed on the query), type a longer query so the second request returns first, wait for both | results or header belong to the older query; a P1. No slow mode to drive it is a P3 Testing finding, and the attack falls back to a unit test |

Skip an attack only when the app has no surface for it; say so in the run summary.

## Finding record

`docs/FINDINGS.md` is one table with fixed columns:

```
| ID | Sev | Owner | Attack | Repro | Evidence | Area | Status | By |
|---|---|---|---|---|---|---|---|---|
| F-017 | P1 | Presentation/TimelinePage.xaml | A2 | 1. Open Timeline (AutomationId=NavTimeline) 2. Trigger NavSettings before the spinner ends | findings/F-017.png | timeline | new | breaker |
```

- Severity: **P0** crash / data loss · **P1** flow blocked · **P2** wrong or visibly broken · **P3** polish.
- Evidence: `uno_app_get_screenshot(fileType:"png", quality:100, path:"docs/findings/F-017.png")`;
  for P0/P1 also save the tree (`justMyCode:false`) as `F-017.tree.xml`.
- Owner: the page or file path the evidence points at; `shared` for theme, tokens and the navigation shell.
- Status: `new` → `fixed` (by whoever fixed it) → `verified` (breaker only) or back to `new` with a note.

## After the run

1. Fix the findings, highest severity first. Each fix adds a regression line to this catalog
   (as `A<n>.<x>` under the matching attack) and sets the finding to `fixed`. The fixer never
   writes `verified`.
2. Spawn the breaker again on `fixed` items only; it writes `verified` or reopens as `new` with a note.

## Limits

- One running app per MCP session. Parallel breakers need separate git worktrees; default is one
  breaker running the catalog sequentially.
- Coordinate clicks (`uno_app_pointer_click`) tend to miss; use peer actions.
- Do not fix while breaking. A breaker that fixes stops finding.

## Recap line

`🟢|🟡|🔴 break-it round <n> · <p0>/<p1>/<p2>/<p3> new · <k> verified · next: <fix|rerun|done>`
