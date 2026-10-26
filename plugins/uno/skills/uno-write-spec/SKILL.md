---
name: uno-write-spec
description: Write a pre-implementation spec for an Uno Platform app with Architecture, Design, Interaction, and Spec Graph briefs mapped to Navigation Extensions routes and regions, MVUX feeds and states, and XAML resource dictionaries, then run a spec gate before scaffolding. Use whenever the build target is Uno Platform - a new Uno app, screen, page, flow, or feature - or when the user asks for an Uno spec, route tree, page tree, data-flow graph, or design graph. Do NOT use for non-Uno targets, validating whether an idea is worth building, or implementing the spec (a fresh session by default, or this one when the user asked for an end-to-end build; verify with uno-verify).
---

# Write Spec (Uno Platform)

A spec with four briefs, a plan, and a gate, where every graph and check is written in Uno terms: Navigation Extensions routes and regions, MVUX feeds and states, and XAML resource dictionaries. By default, implementation happens in a **fresh session** that reads the spec cold. When the user asked for an end-to-end build, continue into implementation in the same session, reading from the written spec.

## Before Writing

Load these and apply them, in this order. The `uno-*-*` entries are Uno Platform Studio skills from the `uno-platform-studio` plugin:

| Skill | Governs |
|-------|---------|
| `uno-scaffolding` | Project structure, UnoFeatures, XAML rules, spec-time facts |
| `uno-navigation-*` | Route tree: RouteMap, ViewMap, DataViewMap, regions, qualifiers |
| `uno-mvux-*` | Data-flow graph: IFeed, IState, IListFeed, IListState, FeedView |
| `uno-themes-*` | Design graph: token set, palette, typography |

If the Uno docs MCP is available, verify every API the spec names. Anything still unverified goes in Risks.

## Where Specs Live

- Project-scoped: `SPEC.md` in the project root.
- Pre-project (no folder yet): `<NAME>-SPEC.md` in the home directory.

## Required Structure

```markdown
## Architecture Brief

Define:
- Targets (Desktop Skia, Android, iOS, WebAssembly) and Uno.Sdk version
- UnoFeatures list
- MVUX or MVVM, with Decision / Reason / Tradeoff
- Shell and region layout
- Route registration (ViewMap, DataViewMap, RouteMap)
- Services and DI registration (IHostBuilder)
- Models: feeds, states, commands, messaging
- Platform constraints and per-target fallbacks: where platform code lives (a service per capability, `Platforms/` partials); models and view models stay platform-neutral
- Error representation and logging: how a failure reaches the screen (feed error, result type, exception) and what gets logged, with no secrets or personal data in logs
- Testing/validation approach: which rules and state transitions get unit tests, which flows get UI or App MCP proof, and per target what evidence counts before a merge
- Capability inventory: every capability the design implies, marked implemented / substituted / omitted, with the platform or ecosystem choice (see `rules/capability-coverage.md`); substituted and omitted rows are repeated in Unresolved Questions

## Design Brief

Define:
- Visual direction
- Token set: colors, type ramp, spacing, corner radii, motion
- ThemeDictionaries (Light / Dark) and which tokens are theme-aware
- Resource dictionary scopes (App.xaml vs route root vs page)
- Styles (BasedOn chains) and ControlTemplates / DataTemplates
- Fonts: asset files (one static instance per weight), family names, weights
- Layout and adaptive behavior: every width-dependent value is a `{utu:Responsive}` value per breakpoint, structure included (`ResponsiveView` only for layouts that truly differ); see `rules/uno-scaffolding.md`, *Breakpoints*

## Interaction Brief

Define:
- User flows as navigation sequences (route → route)
- Input behavior and keyboard/gamepad/pointer handling
- FeedView states per async node: Value, Progress, None, Error
- Dialogs and flyouts (navigated with the ! qualifier or opened locally)
- VisualStates per control (Normal, PointerOver, Pressed, Disabled, custom)
- Animations: Storyboards or Composition, with duration, easing, and reduced-motion fallback
- Accessibility: AutomationProperties.Name, focus order, contrast, reduced motion
- Runtime verification steps (uno-verify)

## Spec Graph Brief

Define:
- Route tree
- Page trees
- Data-flow graph
- Design graph
- Spec gate results
```

After the four briefs:

```markdown
## Implementation Plan

- ...

## Quality Gates

Copied from *Build gates* in `uno-scaffolding/references/uno-scaffolding.md`: the tiers that apply to this spec's scope, each tied to the phase of the plan where it runs.

| Phase | Gate (skill) | Done when |
|---|---|---|
| <phase from the plan> | <skill> | <evidence> |

## Risks

- API: <what> - spike <5–15 min>

## Unresolved Questions

- ...
```

## Spec Graph Brief

Write it last. It projects the three briefs into the four trees the app actually runs as, then runs the gate.

### The Four Views

1. **Route tree.** It mirrors `RegisterRoutes`. Each node is a `RouteMap`, annotated with its view/model pair, its `DataViewMap` data type, and the region that hosts it. Show the shell and every `Region.Attached` container. Dialogs and flyouts hang off the route that opens them, marked `!`.
2. **Page trees.** One per page, following the XAML visual tree down to meaningful controls. Annotate each node with its binding source, any command it invokes, its FeedView templates, and its resource scope.
3. **Data-flow graph.** Services (DI) → MVUX models (`partial record`) → feeds and states → bound nodes. Mark each `IState` writer: two-way bindings, commands, and messaging (`EntityMessage` updates). Show derived feeds (`.Select`, `.SelectAsync`, `Feed.Combine`) as edges.
4. **Design graph.** Token resources → semantic resources → Styles / ControlTemplates / DataTemplates → page nodes. Group by dictionary scope. Mark each brush `ThemeResource` or `StaticResource`. Under each status role, note the second cue that carries the state alongside color. List motion as resources (`Duration`, `KeySpline`) consumed by Storyboards.

### Notation

Write the trees as plain text in code blocks. The text is the source of truth. A rendered visual is optional and only for review.

```text
Shell [Region.Attached, Navigator=Visibility]
├─ Answer         ViewMap<AnswerPage, AnswerModel>   IsDefault
│  └─ ItemizeList  ← FeedView(AnswerModel.Remaining) {Value, Progress, None, Error}
│     └─ DayChip   → Month/Day (DataViewMap<DayDrawer, DrawerModel, DayKey>)
└─ Month          DataViewMap<CalendarPage, CalendarModel, MonthKey>
   ├─ Day !       flyout · DrawerModel
   │  └─ CheckCircle  ⇒ IState BillsModel.Paid (command TogglePaid)
   └─ AddBill !   dialog · AddBillModel
```

```text
App.xaml @App
├─ Ink.Primary         ThemeResource  #17202A
├─ Status.Overdue      ThemeResource  #C85B5B   cue: color only   ✗ Color cue
│  └─ DayCellTemplate.Numeral          ← Status.Overdue
├─ Status.Paid         ThemeResource  #5D8764   cue: strike
│  └─ DayCellTemplate.Strike           ← Status.Paid
├─ Motion.Settle       Duration 0:0:0.28 · KeySpline 0.2,0,0,1
│  └─ CheckCircle.Storyboard           ← Motion.Settle   reduced: snap to checked
└─ Type.Display        ms-appx:///Assets/Fonts/Newsreader.ttf#Newsreader
OnboardingPage.Resources @onboarding   (merged at route root, never in App.xaml)
```

| Mark | Meaning |
|------|---------|
| `← X` | Binds or reads from X |
| `⇒ X` | Writes X |
| `→ Route` | Navigates to route |
| `!` | Dialog or flyout via navigation qualifier |
| `{…}` | FeedView templates declared, or `n/a: reason` |
| `@scope` | ResourceDictionary scope rooted here |
| `? pending` | Design not decided; named on purpose |

### Spec Gate

Run every check against the four views. Every FAIL moves to Unresolved Questions.

**Routes and regions**

| Check | Rule |
|-------|------|
| Registration | Every page has a ViewMap; every page that receives data has a DataViewMap with the data type named |
| Region host | Every route has a host region; `Region.Name` values match route names exactly |
| Shell safety | No `Region.Attached` inside Shell.xaml or the ExtendedSplashScreen |
| Cross-page links | Every link that lands in a nested region or flyout names the full route path and its data |
| Back stack | Every flow declares where `-` returns and where `-/` clears the stack |

**Data**

| Check | Rule |
|-------|------|
| Sources | Every bound node has a feed, state, or property that exists in the data-flow graph |
| Feed vs state | Read-only data uses IFeed/IListFeed; user-editable data uses IState/IListState |
| Single writer | Each IState has one writer, or the brief states explicit precedence |
| FeedView states | Every async node sits in a FeedView with Progress, None, and Error templates, or `n/a` with a reason |
| Failure paths | Every command that writes declares validation and an Error presentation |
| Data shape | Record shapes satisfy every consumer (undated items, one-offs, variants) |

**Design**

| Check | Rule |
|-------|------|
| Tokens | Every brush, thickness, radius, and font in a page node resolves to a named resource, and every resource has a consumer |
| Theme-awareness | Colors that change with theme are ThemeResource in ThemeDictionaries; StaticResource only for theme-invariant values |
| Scope | Scoped dictionaries merge at their route root; nothing scoped lands in App.xaml |
| Color cue | No state is carried by color alone; each status role names a second cue |
| Contrast | Each role that appears as both fill and small text has a text-safe variant |
| Encodings | Every data-driven visual (size, weight, height ∝ value) names its curve, clamps, and the converter or model property that computes it |
| Motion | Every Storyboard or Composition animation names its Duration and easing resources and a reduced-motion fallback |
| Type assets | Every font file is in Assets/Fonts with an underscore-only filename (Android rewrites hyphens), referenced by ms-appx URI with family name, and verified on each target; weights ship as static instances, because Skia renders a variable font's default instance only (see `rules/uno-runtime-gotchas.md`) |

**Project**

| Check | Rule |
|-------|------|
| UnoFeatures | The feature list covers everything the graphs use (MVUX, Navigation, Toolkit, Material, …) |
| Targets | Every platform-specific node names its targets and its fallback on the others |
| Pending | Undecided designs appear as `? pending` nodes |
| Capabilities | Every capability the design implies has an inventory row; every substituted or omitted row is in Unresolved Questions |

Record results:

```markdown
| Check | Result | Nodes | Resolution |
|-------|--------|-------|------------|
| Single writer | FAIL | BillsModel.Paid, CheckCircle, Clock | → Unresolved Questions |
```

## Rules

- Unresolved questions are resolved, or explicitly accepted as risks, before scaffolding begins.
- When a graph contradicts a brief, fix the brief. The graphs are projections of the briefs.
- Keep the Spec Graph Brief to about one page. If a page tree needs more than about 15 nodes, split the page.
- The route tree is the spec for `RegisterRoutes`. The build session writes `RegisterRoutes` from it directly and diffs the two before the first run.
- **Every spec carries a Quality Gates section, at any size.** The build session reads only the spec and `HANDOFF.md`, so the gates have to be written into the spec to get applied (Patina, 2026-10-03: the completeness audit, component states, break-it and the build log all went unused because nothing named them). Copy the tiers from *Build gates* in `uno-scaffolding.md` that match the scope: one screen gets fewer rows than an app, but never zero. A gate that cannot run is recorded in Unresolved Questions with the reason.
- In the build session, run `uno-verify`. Compare `uno_app_visualtree_snapshot` against the page trees. Confirm that brushes, styles, and fonts on key nodes resolve to the design graph's resources.
- Pin the Uno.Sdk version in `global.json` and package versions in `Directory.Packages.props`. Reference a known-good project instead of rediscovering versions.
- List API verification points as Risks with a time box (5–15 min spikes, then trip the debug-arcs rule).
