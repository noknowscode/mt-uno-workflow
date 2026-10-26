---
name: uno-component-states
description: Turn an Uno Platform / WinUI component that shows populated data into its Loading, Empty and Error states, preserving its exact structure, spacing, typography, shape and density. Works on a standalone control, one named component inside a page, or a page's components one at a time - with any state mechanism (MVUX FeedView, VisualStateManager, visibility bindings) and any design system (Material, Fluent, Cupertino, custom tokens). Use when the user asks for loading/skeleton/shimmer, empty, error or retry states, or invokes /uno-component-states on a XAML file (optionally with --states loading,empty,error). Also use when asked to build a component or app "with loading/empty/error states" that does not exist yet - it builds the populated component first, then transforms it. Never design the states alongside the component. Do NOT use for component redesign or visual identity, motion polish of states, or theming mechanics (see the Uno Platform Studio `uno-themes-*` skills).
---

# Uno Component State Generator

Generate Loading, Empty, and Error states for an existing Uno Platform
component that is currently shown in its populated/data state.

**The critical rule: do not design three new components. Transform the
existing component into three alternate conditions of itself.**

The populated component is the design specification. Everything you produce
must read as "the same component on a different day" - same footprint, same
design language, same hierarchy - with only the content region changed to
communicate the new condition.

```
INPUT      existing component in its populated/data state
   ↓
ANALYZE    structure · layout · tokens/resources · typography ·
           spacing · shape · existing controls · interaction model
   ↓
GENERATE   Loading · Empty · Error
   ↓
VALIDATE   same footprint · same design language ·
           no unnecessary redesign · valid Uno XAML
```

## Non-negotiables

Each item below has shipped broken at least once in generated output. The
rest of this document explains them; this list is the contract, and it holds
even if nothing else gets read.

1. **All states render inside the component's own shell.** One card, one
   header; states swap only the data region. The `FeedView` (or state host)
   goes *inside* the shell, never around it.
2. **Every action a state offers must be provably wired.** A binding that
   compiles, renders enabled, and advertises invoke can still be dead -
   prove the command fires, whatever the mechanism. Known instance: inside
   MVUX `FeedView.ErrorTemplate`, name the FeedView and bind
   `{Binding Refresh, ElementName=TheFeed}`; bare `{Binding Refresh}` is a
   silently dead button (see the Retry trap, Phase 4).
3. **Loading is a skeleton of the populated layout.** No default spinner,
   no "Loading…" text.
4. **The swap container carries a footprint pin** - `MinHeight` measured
   from the populated state - unless the height provably doesn't change.
5. **Absence is data, never an exception.** The data path reports "no
   data" as a value (null / None / empty collection) so the Empty UI can
   render. Throwing on absence renders Empty as Error and strands the
   empty state as unreachable dead code - in MVUX, return null/None from
   the feed and `NoneTemplate` renders.
6. **Every state must be reachable and driven once.** The service exposes a
   mode it re-reads per call (slow / empty / error) plus a per-call trace.

## Stay in lane

This skill changes a component's *states*, never its *design*:

- No restyling, no "while I'm here" improvements to the populated state.
  If the user also wants a redesign, land it first,
  confirm it, then generate states from the settled version.
- Motion and feel of the states - shimmer curves, transitions between
  states - are a separate polish pass. Build the states
  static-correct first.
- Sibling components with the same missing states get mentioned, never
  fixed unasked.
- A broad production-quality pass over an existing surface (spacing,
  hierarchy, real-data hardening, fit and finish) is out of scope; such a
  pass can invoke this skill to build the states themselves.
- Incremental/paginated list states ("loading more" footer rows, partial
  pages) are out of scope: this skill covers whole-component states. Say
  so when asked, rather than stretching these patterns to fit.

## Invocation

`/uno-component-states <path.xaml>` - generate all three states.

`/uno-component-states <path.xaml> - <which component>` - target one
component inside a larger file. Identify it however is natural: its
`x:Name`, the control type, the property it renders ("the holdings list",
"the ChipGroup over Sectors").

`/uno-component-states <path.xaml> --states loading,empty` - generate only
the listed states (`loading`, `empty`, `error`).

If no file is given, resolve the target from conversation context; if it is
still ambiguous, ask which component before touching anything.

## When the component does not exist yet

"Build a product card with loading, empty and error states" is a normal way to
ask, and it is **two jobs, not one**. Do them in order, never in parallel:

1. **Build the populated component first, and finish it.** Real layout, real
   tokens, real data path. Show it. This is now the design specification.
   While building the data path, give it a **mode the service re-reads on
   every call** (env var, file, debug flag) that forces slow / empty / error.
   Do this without being asked: Phase 5 cannot verify states that cannot be
   reached, and a service that always succeeds makes three of the four
   states unreachable dead code.
2. **Then run this skill on it**, as if someone else had written it - Phase 1
   analysis included, measuring the component you just built.

If you design the states at the same time as the component, there is nothing
to preserve, and "same footprint, same design language" degrades into four
independent screens: a spinner alone on a blank page, a centred icon, a
centred error panel, and the component visible in exactly one of four states.
That is the most common way this skill produces bad output, and it is
invisible unless someone runs all four states.

Symptom to check for in your own output: if the data state contains a card
and the other three do not, you designed screens, not states. Start over from
the populated component.

## Scope: standalone control, component in a page, or a whole page

These three are not interchangeable, and getting the scope wrong is how this
skill damages a file it was only supposed to add states to. Decide which one
you are in before Phase 1, and say so.

**A standalone component file** - a `UserControl`, a templated control, a
`DataTemplate` in a resource dictionary. The component is the file root.
Its outer size is decided by whoever hosts it, so pin the **data region**,
never the root: putting `Width`/`Height`/`MinHeight` on the root overrides
every consumer of the control. If the root is a `ControlTemplate`, the
states belong in its `VisualStateManager`, not in a feed the template
cannot see.

**One component inside a page** - the common case. Name the target back to
the user before editing, then treat everything else in the file as
off-limits (siblings: see Stay in lane). The shell you must preserve is the
target's own container, not the page. Verify the target's footprint **and**
confirm the siblings did not move - wrapping a component in a `FeedView`
changes its layout parent and can silently re-align it. That has happened:
a card that had been left-aligned re-centred and shifted 174px once wrapped,
and nothing about the component itself looked wrong in isolation.

**A whole page** - only when the user actually asked for the page. Work one
component at a time, each with its own invariant list and its own footprint
check. Resist a single page-level Loading that blanks everything: separate
feeds resolve at different moments, and a page-wide skeleton flashes
sections that already had their data.

## The mental model: invariants vs. state variables

This is what separates state generation from UI generation. Before writing
any XAML, explicitly split the component into two lists:

```
COMPONENT INVARIANTS            STATE VARIABLES
────────────────────            ─────────────────────────────────────────
Root container                  Data content  → skeleton / message / message
Outer dimensions                Primary action → hidden / create CTA / retry
Padding                         Semantic accent → neutral / neutral / error
Corner radius
Background & border
Header / title & its typography
Grid structure & alignment
Button treatment
Color resources
Density
```

Invariants are the component's visual identity - they carry across every
state unchanged unless there is a concrete reason not to. State variables
are the only levers you pull. If you find yourself changing something in
the left column, stop and justify it; "it looks nicer" is not a reason.

Worked example - the card shell never gets reinvented:

```
DATA                                    LOADING
┌─────────────────────────────┐         ┌─────────────────────────────┐
│ Portfolio                   │         │ Portfolio                   │
│                             │         │                             │
│ AAPL    $231.42     +1.2%   │         │ █████   ██████      ████    │
│ NVDA    $182.11     +2.8%   │         │ █████   ██████      ████    │
│ MSFT    $519.30     -0.4%   │         │ █████   ██████      ████    │
└─────────────────────────────┘         └─────────────────────────────┘

EMPTY                                   ERROR
┌─────────────────────────────┐         ┌─────────────────────────────┐
│ Portfolio                   │         │ Portfolio                   │
│                             │         │                             │
│       No stocks yet         │         │    Couldn't load stocks     │
│      + Add a ticker         │         │           Retry             │
│                             │         │                             │
└─────────────────────────────┘         └─────────────────────────────┘
```

---

## Phase 0 - Does this component have states at all?

Not every component does, and generating states for one that doesn't is
worse than declining: it invents a data path the app never had. Answer this
before anything else.

**A component has these states only if its content depends on data that can
be absent, in flight, or fail to arrive.** A list of orders, a profile
header fed by a service, a chart over a query - yes. A page title, a
navigation item, a static hero, a decorative card, a local toggle, a button
whose label is a constant - no.

Three outcomes, and say which one you are in:

- **Data-dependent** → continue to Phase 1.
- **Static** → say so and stop. "The section header renders constants; it
  has no loading, empty or error condition." Do not manufacture a service
  call to justify the states.
- **Mixed container** (a static shell wrapping a data-fed region - the
  common case for a page) → the states belong to the data region only. The
  header, title and chrome around it stay put in every state; that is the
  shell the other rules keep talking about.

Partial answers are normal: a component may have a real Loading and Error
but no meaningful Empty (a single record that either exists or fails to
load), or an Empty but no Error (a local collection that cannot fail).
Generate the states the component actually has and name the ones you
skipped, with the reason. `--states` exists for when the user has already
made that call.

## Phase 1 - Analyze the existing component

Read the component and enough of its surroundings (ViewModel/model,
resource dictionaries, app-level styles) to answer all of the following
before modifying code. If the Uno App MCP is available (`mcp__uno*` /
Hot Design tools), also inspect the *running* app: visual tree, data
context, effective control properties, and a screenshot of the populated
state - the rendered truth beats your reading of the markup.

**Structure** - root container; rows/columns; repeated elements (the
`ItemsRepeater`/`ListView`/`ItemsControl` and its item template); headers;
actions; content areas; which dimensions are fixed vs. driven by content.

**Visual language** - typography and font hierarchy; foreground hierarchy;
backgrounds; borders; corner radius; shadows; spacing rhythm; alignment;
icon treatment; button styles; density.

**Resources** - find what the app already defines before introducing any
literal value: `StaticResource`/`ThemeResource` brushes, styles, text
styles, spacing and corner-radius tokens, semantic colors (including an
error brush). Whatever the design system - Material (`SurfaceBrush`,
`OnSurfaceVariantBrush`, `ErrorBrush`, …), Fluent (`TextFillColorSecondaryBrush`,
`SystemFillColorCriticalBrush`, …), Cupertino, or a hand-rolled dictionary -
the app's own resources are the palette. Discover them, reuse them, and
never restate their values as literals or import tokens from a system the
app does not use.

**Meaning** - what does this component *represent*? The states are written
from the answer, so be specific: what data is shown, and which parts are
essential versus decoration; what action normally produces that data (a
search, a purchase, a background sync, a first-run setup); what would
legitimately make it empty, and which kind of empty that is; what could
fail, and whether the user can do anything about it. A cart, a search
result list, a notification feed and a profile header are four different
components even when their markup rhymes - and their Empty states have
almost nothing in common. Do not invent functionality the surrounding
application does not support.

## Phase 2 - Fix the invariants

Write down (in your working notes, or a brief message to the user) the
invariant list for this specific component: outer dimensions, root
container, padding, corner radius, background, border, header placement,
title typography, major alignment, density. These stay stable across all
states. Change the content's condition, not the component's identity.

---

## Phase 3 - Generate the states

### Loading

Represent the component while its data is on the way.

- Prefer a **skeleton** of the existing content structure: mirror the real
  row count (or a plausible page of rows), column positions, text
  hierarchy, and image/avatar placeholders. The goal is near-zero layout
  shift when data arrives - a skeleton that matches the populated layout
  makes the load feel faster and calmer than any spinner.
- Build skeleton blocks from `Border`/`Rectangle` sized like the real
  content (width approximating typical text length, height matching the
  text style's line height), filled with a low-emphasis surface brush the
  app already has (surface-variant / base-low), with a small corner
  radius. A subtle opacity pulse (~0.45→0.9, ~1.8s period) is enough; skip
  shimmer gradients unless the app already uses them. A static skeleton is
  always acceptable - and if the app already has a static skeleton
  somewhere, stay static: matching the existing loading idiom outranks
  adding motion.
- **On Uno Skia desktop, a `RepeatBehavior="Forever"` storyboard is
  expensive, and hiding its target does not stop it.** Minimal repro
  (Uno.Sdk 6.8.0-dev.12, `net10.0-desktop`, Release, one opacity keyframe
  animation on a single 220×24 `Border`): app idle **0.1%** of one core,
  storyboard running **29.4%**, target `Collapsed` while it still runs
  **17.3%**, after `Stop()` **0.3%**. So the cost is real and it keeps
  being paid while the skeleton is invisible - a state layer that hides
  without stopping its animation burns a sixth of a core forever.
  Either **`Stop()` the storyboard whenever the loading state exits**
  (that does fully reclaim it), or drive the pulse from a
  `DispatcherTimer` (~80ms tick writing `Opacity`), which idles at 0-2%
  and cannot be left running by accident.
- Do not replace a structured component with a generic centered
  `ProgressRing` unless a spinner is already the app's established loading
  idiom (check other screens first).
- Avoid "Loading…" text unless the component's design language calls
  for it.
- **Reload is not first load.** Once data has been on screen, a refresh
  (Retry from a transient error, pull-to-refresh, background revalidation)
  keeps the existing data visible, with at most a subtle busy indicator.
  The skeleton is for first load only - blanking populated content on
  every refresh is a regression, not a state.
- **Guard against skeleton flash.** On a fast response the skeleton shows
  for tens of milliseconds and reads as a glitch. Delay showing it
  (~300ms after the load starts); once shown, optionally hold it a
  minimum (~500ms) so it never strobes. With hand-rolled state flags the
  guard lives in the ViewModel; MVUX `FeedView` has no template-level
  hook for it, so either add the delay in the data layer or state the
  gap plainly - do not fake it with template tricks.

### Empty

Represent the **successful absence** of data: the operation worked and
returned nothing. Error means the operation did not produce the expected
result at all. That difference decides the words and whether a Retry
exists:

```
Empty →  "No notifications yet."
Error →  "Couldn't load notifications."   [Retry]
```

Empty is not an error, and must not look or read like one.

**Which kind of empty is it?** "Nothing here" means different things and
they do not share copy or actions. Work out which one the component is
before writing a word of it:

| Kind | Example | What it needs |
|---|---|---|
| Never had any | Cart, first-run project list | The action that creates the first item - this is the one place a CTA usually belongs |
| None matched | Search results, a filtered list | What was searched, and a way back (clear filters); **no** create CTA |
| None right now | Notifications, today's alerts | Reassurance it is working; usually no action at all |
| Cleared out | Inbox after archiving everything | Acknowledge the completed state; do not push a new action |

Getting this wrong is quiet but real: "Create your first order" under a
search that matched nothing is nonsense, and a bare "No results" on a
first-run cart abandons the user at the one moment a CTA would help.

- Keep the shell and contextual elements (title, header actions).
- Replace the data region with a lightweight treatment: a short message in
  the app's existing secondary text style, optionally an icon from the
  app's icon set, optionally one CTA.
- Add a CTA only when the surrounding app actually supports the action
  ("No projects yet" + "Create project"; "No results" with no button).
  Wire it to an existing command - never a dead button.
- Use neutral foreground/secondary emphasis, existing button styles,
  existing spacing. No decorative illustrations unless the design system
  already uses them.
- **In MVUX, absence is a value: return null/None from the feed** so
  `FeedView` renders `NoneTemplate`. Never throw for "no data" - the empty
  condition then renders as Error and the `NoneTemplate` becomes unreachable
  dead code. Observed verbatim in a generated app: the model wrapped the
  service call in `?? throw new InvalidOperationException(...)`, so a null
  product showed "Something went wrong" with a Retry button.

### Error

Represent failure to retrieve or display the data.

- Keep the shell. Communicate two things: something failed, and what the
  user can do next when recovery is possible ("Couldn't load your
  watchlist." + Retry).
- Use the app's semantic error resource as an *accent* - an icon tint, a
  message foreground - not a flood. The component keeps its identity; the
  error styling is emphasis, not a repaint.
- Wire Retry to the existing load/refresh command if one exists; omit the
  button when there is genuinely nothing to retry. A binding that compiles
  is not a wired command - see the Retry trap in Phase 4.
- **Retry must be safe to click twice.** Guard re-entry: disable the
  button while a load is in flight, or cancel the previous load on
  re-invoke. An unguarded `Retry() => _ = LoadAsync()` races two loads
  through the same collection. (MVUX's generated commands and `FeedView`'s
  `Refresh` handle this; hand-rolled MVVM does not get it for free.)
- Never surface raw exception text unless the component is explicitly
  developer-facing.

### Announce the change

- Give the empty and error messages `AutomationProperties.LiveSetting="Polite"`
  so screen readers hear the transition instead of discovering a silently
  changed panel (`Assertive` only if the failure blocks the whole task).
- Keep skeleton blocks out of the automation tree
  (`AutomationProperties.AccessibilityView="Raw"`) - a skeleton that
  narrates as content is noise.

---

## Phase 4 - Implementation

Reuse as much of the existing component as possible; state-specific content
replaces the data region, everything else is shared. Follow the state
mechanism the app already uses - do not introduce a new state-management
architecture for this:

> **Confirm the house pattern actually works before copying it.** "The app
> already does it this way" is a reason to match the shape, not evidence
> that the shape functions. If the existing error state has a Retry button,
> click it before you replicate its binding. Copying a broken pattern
> faithfully still ships a bug, and it ships it in every component you
> touch. This is not hypothetical: a lab app's account-header Retry was
> dead, and generating states for two more components turned one dead
> button into three.

- **Uno Toolkit `FeedView`** - if the project already references Uno
  Toolkit, `FeedView` exists precisely for this: put the states in its
  `ProgressTemplate`, `NoneTemplate`, and `ErrorTemplate` around the
  existing `ValueTemplate`. Put the `FeedView` *inside* the component's
  shell so the container, padding and header stay shared - wrapping the
  whole component in it duplicates the shell four times.
- **`VisualStateManager`** - a `Loading/Empty/Error/Data` state group on
  the component root, toggling visibility of the shared shell's content
  layers. Good default for a card/section inside a page.
- **State-bound visibility / `x:Load`** - bind each layer to ViewModel
  state (e.g. an enum + converters, or `IsLoading`/`HasError` flags),
  matching however the app already expresses state.
- **MVUX feeds** - if the app uses MVUX, `FeedView` over the feed is the
  native answer; its states map 1:1 to this skill's output.

This list is not exhaustive; the governing rule is **match the app's
existing idiom**. A plain MVVM page with no `FeedView` and no state group
gets state-bound visibility over `IsLoading`/`HasError` flags, written the
way the surrounding pages already write them.

Preserve all existing bindings - the data state must keep working exactly
as before. Sample/design-time data may be used only for previewing states,
never left wired into production paths.

### Pin the data region, or the shell collapses

The "same footprint" promise does not hold by itself. A content-sized
component shrinks to fit whatever the state puts in it: a data region of
five 17px rows is ~125px tall, while Empty and Error are a single line of
text. Left alone the whole component loses ~110px the moment data is
absent, which is exactly the layout shift the skeleton was meant to avoid.

Measure the populated data region (from the running app when the App MCP is
available - its arranged bounds beat your reading of the markup) and pin it
on whatever container swaps between states:

```xml
<!-- 5 rows x 17px + 4 x 10px spacing -->
<mvux:FeedView Source="{Binding Holdings}" MinHeight="125">
```

Loading usually matches on its own if the skeleton mirrors the real row
count. Empty and Error need the pin. Centre their content inside the pinned
region rather than letting it sit at the top. If the shell is content-sized
horizontally too (e.g. a left-aligned card with `MaxWidth`), pin `MinWidth`
as well - a one-line Empty message otherwise narrows the whole component.

If the component is already a fixed height, or the data region is a single
line in every state, no pin is needed - check before adding one.

### Check the control can host your states before planning them

Some controls expose **fixed slots that accept strings only** - `utu:Card`'s
`HeaderContent` / `SubHeaderContent` / `SupportingContent` are the common
case. Assigning a `Border` skeleton or a message-plus-Retry panel to such a
slot does not error: the assignment is dropped and the presenter renders its
own DataContext instead. Inside an `ErrorTemplate` that DataContext is the
exception, so the card prints a raw stack trace - and grows to fit it.
Measured once: a 113px card became 590px.

So before designing the states, confirm the shell can actually hold them.
Put a `Border` in the slot, run it, and look at the visual tree. If the
control is slot-limited you have two honest options, and the choice belongs
to the user, not to you:

- keep the control and ship degraded states (no skeleton, no Retry),
  labelling them as degraded; or
- move to a content-hosting equivalent (`utu:CardContentControl` takes a
  full `ContentTemplate`), which is a control swap - a redesign, so ask.

Do not quietly stuff elements into slots and assume they rendered because
the build passed.

### The Retry trap (MVUX `FeedView`)

Inside `FeedView.ErrorTemplate` the DataContext is the **thrown
`Exception`**, not `FeedViewState`. So the obvious binding fails silently:

```xml
<!-- DEAD: resolves to null against the Exception -->
<Button Content="Retry" Command="{Binding Refresh}" />

<!-- WORKS: resolves even from inside a nested ContentTemplate -->
<mvux:FeedView x:Name="HoldingsFeed" Source="{Binding Holdings}">
<Button Content="Retry" Command="{Binding Refresh, ElementName=HoldingsFeed}" />
```

`{Binding Parent.X}` fails there too, for the same reason - `Parent` lives
on `FeedViewState`. `{Binding Refresh}` is fine in `ValueTemplate`, which is
why the mistake survives review.

This one is invisible to every cheap check: the build passes, the button
renders enabled in the accent colour, its automation peer still advertises
invoke, and the screenshot looks perfect. Only clicking it reveals anything.

### When the component has no async data path at all

Two different situations, and only one of them is your problem to fix.

**The data is real but loaded synchronously** - a list built in the
constructor, or from a service that will obviously become async. There is
no state to bind to and no mechanism to follow, so adding the data path
(turning the property into a feed over a service call the app already has)
is the correct move, not a violation of "don't introduce a new
architecture". What that rule forbids is a *parallel* state system: a
bespoke enum plus converters plus a custom control, in an app that already
has a way to do this. Say which mechanism you picked and why.

**The component has no data** - its content is constants, or values a
parent hands it that cannot fail. Then there is nothing to add. Report it
per Phase 0 rather than inventing a service so the states have something to
represent.

Before using an unfamiliar Uno/WinUI API or control, consult the Uno
Platform docs (docs MCP if available). Avoid new dependencies.

---

## Phase 5 - Validate

Validate each state against the original, not against your taste.

**Static self-check first** - five checks against the produced markup and
model, before any runtime work. Each is a grep, not a judgment call:

1. Retry and every state CTA bind to a command that actually resolves in
   that template's DataContext (for `FeedView.ErrorTemplate`: the FeedView
   has an `x:Name` and Retry binds `ElementName` to it).
2. The shell (card, container, header) sits *outside* the state host; every
   state renders inside it.
3. The loading state contains skeleton elements mirroring the populated
   layout, not a lone spinner.
4. The swap container has its `MinHeight` pin (or the height provably
   doesn't change).
5. The data path returns null/None/empty for absence (no `?? throw`), and
   the service has a forced-mode switch covering slow / empty / error.

Any miss is a defect to fix before validating further, not a style note.

**Visual consistency** - same footprint? same outer container, spacing
system, typography, corner treatment, button styling, icon style, color
language? Measure the footprint in every state and compare the numbers.
Equal heights is the pass condition; "looks about right" is not, and a
capture cropped at the component's rounded corner will under-read the
height by the corner radius at both ends.

**Loading** - does the skeleton resemble the actual data layout? Is layout
shift minimized? Does it read as *this component* loading, not a different
screen?

**Empty** - is absence of data clearly communicated, and clearly not an
error? Is any CTA actually supported and wired?

**Error** - is failure obvious without overwhelming the component? Is
recovery offered when possible? Does it use the existing semantic error
resource?

**Retry actually fires** - this is a separate check and it is not optional.
Writing the binding proves nothing. Drive the component into Error, make the
data source healthy while the app is still running, invoke Retry, and assert
the load ran a second time and the component recovered to its data state. A
runtime-rewritable fixture (a mode file the service re-reads per call) plus a
per-call trace makes this a few seconds' work; a service that only reads an
environment variable at startup cannot be tested this way. If the button
cannot be proven to fire, say so plainly rather than reporting it as wired.
When the App MCP is available, `uno_app_get_element_datacontext` on the
Retry button is the fastest dead-binding detector: if the DataContext
serializes as the exception type, the command binding resolved to null.

**Code** - does the project build (`dotnet build` the smallest target that
compiles the XAML)? Are existing bindings preserved, resources reused,
duplication avoided?

**In-app validation** - if the Uno App MCP is available, drive the running
app into each state (set the ViewModel state, or force the visual state),
screenshot all four conditions, and compare: the shell must be
pixel-stable across them. Fix any state that shifts the footprint or
breaks the design language, then re-check.

---

The populated component is always the primary design reference. When
uncertain, preserve rather than invent.
