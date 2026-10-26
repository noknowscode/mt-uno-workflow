
# Capability Coverage

Load this file when implementing an app, screen, or feature from a design, artboard set, spec, or
screenshot, and at the start of any build that will be judged on what it demonstrates.

It exists because of a measured failure (quickchefs, 2026-09-09). The build scored well on
correctness and quietly shipped a smaller product than the design implied: a step timer wearing a
video player's chrome instead of `MediaPlayerElement`, a hand-drawn static map instead of a map
control, XAML bars instead of a chart library, and localization deleted instead of implemented.
None of those substitutions was forced. Each was absorbed silently rather than raised as a decision.

## The rule

**A design implies capabilities. Inventory them before writing code, implement them with the real
thing, and raise every substitution as a decision the user makes, not one you absorb.**

## Step 1 - Capability inventory, before any code

From the design and the product domain, list every capability the surface implies. A play button
with a timeline implies video. A map implies a map. A ring with segments implies charting. Content
that changes implies a remote source. Then mark each one:

| Capability | Status | Note |
|---|---|---|
| … | implemented / substituted / omitted | what was chosen, and why |

Put this in the spec (see `uno-write-spec`) and repeat the substituted and omitted rows verbatim under
**Unresolved Questions**. A capability that never reaches Unresolved Questions was never a decision.

## Step 2 - Reach for the platform, then the ecosystem, before hand-rolling

Uno Platform ships or integrates most of what a design implies. Check here before approximating.
Verify the current version and Uno compatibility against the Uno docs MCP and NuGet at adoption
time; the third-party entries are candidates to evaluate, not blanket endorsements.

| Capability | First choice | Alternatives to evaluate |
|---|---|---|
| Video and audio | `MediaPlayerElement` (`MediaPlayerElement` UnoFeature) | platform players via native views |
| Charts and plots | LiveCharts2 | ScottPlot, Syncfusion, Telerik, or SkiaSharp via `SKCanvasElement` when the chart is bespoke |
| Maps | Mapsui | platform-native map controls, or a WebView over a JS map |
| Localization | `Uno.Extensions.Localization` (`Localization` UnoFeature, `.resw` plus runtime culture switching) | - |
| Remote data | `Uno.Extensions.Http` with Kiota, or Refit | - |
| Persistence and settings | `Uno.Extensions.Storage`, `ApplicationData`, `IWritableOptions<T>` | - |
| Authentication | `Uno.Extensions.Authentication` (MSAL, OIDC, Web, Custom) | - |
| Navigation, DI, config, logging | `Uno.Extensions` (see the Uno Extensions docs) | - |
| **Controls the design draws** | Rating → `RatingControl` (implemented on WASM, Skia, Mobile; Material style exists). Progress/macro bars → `ProgressBar`. Back bar → `utu:NavigationBar`. Cards, sheets, panels → `utu:CardContentControl`. Bottom sheets, side drawers, filter panels → a `!` Page route styled with a `DrawerFlyoutPresenter` style. Segmented / in-page tabs → `utu:TabBar` (`SegmentedStyle`, `TopTabBarStyle`) over a Visibility region. Pager dots → `utu:SelectorExtensions.PipsPager`. Chips → `utu:Chip` / `ChipGroup` | Next rung: Windows Community Toolkit 8.x (supports Uno Platform out of the box; e.g. `SettingsCard`/`SettingsExpander`, `Segmented`, `TokenizingTextBox`, `RangeSelector`, converters). Not on Uno: the `Media` package; `Animations` is partial (`AnimationBuilder`/`CustomAnimation` only). `DataGrid` and `Carousel` exist only in WCT 7.x (Uno fork). Then custom, only with a written reason, which goes in Unresolved Questions |
| **Icons** | One icon library app-wide. `SymbolIcon` / `FontIcon` on the Fluent symbol font (`Uno.Fonts.Fluent` ships implicitly since Uno 4.7; implemented on WASM, Skia, Mobile), or an open set's path data (Material Symbols, Fluent System Icons) stored as keyed geometry in one `Icons.xaml` with the set and icon name beside each entry, used via `PathIcon Data="{StaticResource ...}"` | An icon the chosen set lacks: take it from another open set and say so in Unresolved Questions. Never hand-draw icons from `Path` / `Ellipse` / `Line` shapes |

The *Controls* row applies the same rule at a smaller scale: a design that draws a star row implies `RatingControl`, and a hand-built `StarRating` is a substitution to raise, not absorb. The ladder is Uno Toolkit and platform controls, then Windows Community Toolkit, then custom. The lint's BUILTIN, BACKBAR, OVERLAY and CARD rules check this row mechanically.

The *Icons* row: a design that shows an icon implies an icon from a real set, drawn by the set's designers. Hand-assembled geometry reads as off-brand at small sizes, drifts in stroke weight, and cannot be swapped when the set updates. Path data pasted inline in a page is the same problem one step removed: nobody can tell which set it came from. The lint's ICON rule flags inline path geometry outside an `Icons.xaml` file.

Hand-rolling is the last option, not the first. If the ecosystem has it, the reason to build it
yourself has to be stated.

## Step 3 - Never impersonate a capability

Do not build UI that looks like a feature the app does not have. A play button that starts a timer,
a map that cannot pan, a chart that is three static bars: each one reads to a user, a reviewer, or a
demo audience as the real capability. Either implement it, or design the surface to be honest about
what it does (the Near Me screen's "this screen does not use your location" line is the correct
shape).

## Step 4 - Absence is a finding, never a pass

A verification checklist may not score a layer *not applicable* because the capability was removed
or never built. "No network, so network failure handling passes" is a scope reduction wearing a
green tick. Record it as a gap and surface it.

## Step 5 - Sample and demo apps invert the hygiene rule

"Do not overbuild" still governs product code. For anything whose purpose is to
demonstrate the platform (samples, demos, conference apps, evaluation builds), demonstrable
capability **is** the deliverable, so do not strip unused-but-demonstrative features as dead weight.
On quickchefs this went the wrong way: `MediaPlayerElement`, `HttpKiota`, `Serialization`,
`ThemeService`, and `Localization` were removed as scaffold leftovers, and each one was a capability
the reference sample exists to show.

Reconciling the two: **a capability the design implies is a demonstrated need**, so adding the
library or UnoFeature that delivers it is not overbuilding. Overbuilding is abstraction nobody asked
for, not features the design already drew.

## Step 6 - Verification order, so the gaps surface early

- Smoke every target head on day one. Not at the end. On quickchefs the WebAssembly persistence
  bug, the Android back gesture, and a blank-screen Debug build all lived in heads that were not run
  until the third session.
- Drive one error state and one retry before writing the second screen. Doing it after eighteen
  screens turned one wrong binding into eighteen.
- Test two viewport heights, not just two widths. Three separate layout defects came from fixed
  effective-pixel heights that only failed in landscape.

## Related

- `references/uno-scaffolding.md`: SDK, MVUX, XAML binding.
- `references/uno-runtime-gotchas.md`: measured runtime gotchas and spec-time facts.
- `uno-component-states` skill: states and the prove-the-retry rule.
- `uno-write-spec` skill: where the capability inventory and Unresolved Questions live.
