
# Uno / .NET Scaffolding & XAML Rules

Load this file when the task touches Uno Platform scaffolding, project setup, MVUX/MVVM choice, XAML binding style, or preview SkiaSharp pinning.

## SDK Versions

- Always use the **latest stable .NET SDK and Uno.Sdk version**. As of 2026-09-25: **Uno.Sdk 6.7.30** (Uno 6.7.135, Extensions 7.3.6, Toolkit 9.1.3, bundled SkiaSharp 3.119.2) on .NET 10; the template offers `net10.0|net9.0`. Compare a project's pins against this line to spot stale ones. *(audit R01)*
- Check Uno Platform docs or NuGet before scaffolding. Never default to an older TFM out of habit.
- Validate the environment with `uno-check` when scaffolding fails or first-run is unstable.
- Treat `Uno0001` ("not implemented in Uno Platform") as an error: `<WarningsAsErrors>$(WarningsAsErrors);Uno0001</WarningsAsErrors>`. At minimum never read an Uno0001 member inside a framework event handler: doing so in `EffectiveViewportChanged` silently stopped later `Loaded`/EVC events (see `uno-runtime-gotchas.md`). `AppWindow.MoveAndResize`, `Control.CharacterSpacing` and `Timeline.AutoReverse` are Uno0001 members. *(audit NEW-01)*

## New App Scaffolding

- Use `dotnet new unoapp -preset recommended`. On 6.7.30 the recommended preset selects **SimpleTheme**, which is our default; add `-theme material` only when the design calls for Material. It merges `utus:SimpleToolkitTheme` in App.xaml, emits `MainWindow.UseStudio()` under `#if DEBUG`, and hard-codes `FontSize="20"` on MainPage. It scaffolds and builds clean (0 warnings, ~51 s cold). *(audit R04)* `[verified: 6.7.30 / CLI]`
- Single Project layout is the default.
- Skia renderer is the default since Uno.Sdk 6.0: a multi-platform scaffold adds `SkiaRenderer` to UnoFeatures (android/ios/wasm), desktop is always Skia, and `-renderer native` is the opt-out. *(audit R06)*
- `UnoFeatures` in csproj controls which Uno packages are included (Uno.Sdk `Uno.Implicit.Packages.ProjectSystem*.targets` keys every implicit package on it). `ShadowContainer` needs the `Skia` feature, which brings Uno.Toolkit.Skia.WinUI. *(audit R07)*
- After `dotnet new unoapp`, add a `.mcp.json` to the new project root (alongside the `.sln`) before the first build, with a `uno-app` server entry: command `dotnet`, args `dnx -y uno.devserver -- --mcp-app --mcp-wait-tools-list`. The Uno Platform template itself creates no `.mcp.json`. *(audit R08)*
- Run `dotnet build` after scaffolding to confirm it compiles before doing anything else.
- **Hand the build to a session started in the project folder.** The `.mcp.json` above only loads when a session *starts* in that folder; a session that scaffolded from a parent folder never gets `uno-app`, and `/mcp` cannot add it (Patina, 2026-10-03: a whole build verified through Win32/Playwright harnesses because of this). Before the first UI work, confirm the `.sln` and `.mcp.json` exist, write `HANDOFF.md` (handoff skill), and start a new session in the project folder that resumes from `HANDOFF.md`. Staying in the original session is acceptable only for scaffold-and-spec work; say so explicitly.
- **Run the release path on day one.** Push to a remote and get CI green on every head (including the iOS job, see the Xcode pairing gotcha) and do one `dotnet publish -c Release` per head before building the second screen. On Patina, Release-only defects (RID publish restore, Android AAB/APK formats, Uno0001 on WASM/Android, iOS Xcode pairing) all surfaced in the last hours.
- Post-scaffold checklist (the template output conflicts with the Styling Rules below): *(audit NEW-06)*
  - `dotnet build`; expect 0 warnings.
  - Replace the template's `FontSize="20"` with a type-ramp style.
  - Confirm the theme matches the design: SimpleTheme (preset default) or Material (`-theme material`).
  - Gate the template's `MainWindow.UseStudio()` for headless runs (see the `UseStudio()` gotcha).
  - Add the `Uno0001` policy above.
- **Analyzer baseline.** The template's `Directory.Build.props` already sets `Nullable` and `ImplicitUsings`; keep both. To add .NET analyzers, build once with `-p:AnalysisLevel=latest-recommended`, record the warning count by ID in the project's build notes, then set `<AnalysisLevel>latest-recommended</AnalysisLevel>` in `Directory.Build.props` and fix or justify each ID. New warnings are blocked by the 0-warnings gate; existing ones are worked down, never bulk-suppressed with `NoWarn`. Not yet measured on an Uno app (2026-10-22): the first app to adopt it records its counts here.

## Build gates (binding)

Applies to **any** Uno Platform build work, from a one-page change to a whole app, with or without a spec. Gates add up: each tier includes the ones above it. Invoke each named skill with the Skill tool when its tier applies. A gate that cannot run (no App MCP, no remote, no device) goes in the build log and Unresolved Questions with the reason; it is never skipped silently. Measured failure (Patina, 2026-10-03): `uno-completeness-audit`, `uno-component-states` and `uno-break-it` all went unused because no step named them.

| Scope of the work | Add these gates | Done when |
|---|---|---|
| Any change (code, XAML, config) | Build + tests; lint hook clean | 0 warnings on the touched head, tests pass |
| Adds or changes a business rule or state transition | Unit test in the test project, run without launching the app (rule in, result out; state in, next state out) | The test fails when the rule is broken |
| Fixes a P1/P2 finding (`FINDINGS.md`, a user report, a crash) | Regression test that fails before the fix, or one line in the finding saying why none can exist (visual-only, platform-only) | Test named in the finding record |
| Touches UI or runtime behavior | `uno-verify` in a session rooted in the project (see *New App Scaffolding*) | Touched states exercised through the App MCP |
| Adds or changes an async/data surface | `uno-component-states` | Loading/Empty/Error exist; Retry proven at runtime |
| New screen, flow or feature | `uno-write-spec` (or a spec section) first; `uno-completeness-audit` scoped to that feature before calling it done | Feature graded by evidence; gaps listed |
| New app, or a multi-screen milestone | Release path before screen 2; at feature-complete `uno-break-it`, then `uno-audit` | Findings fixed or listed in Unresolved Questions |
| Any "done / shippable / released / ready to demo" claim | Full `uno-completeness-audit`, report saved to `docs/COMPLETENESS.md` | No such claim without the saved report |
| Session end | `handoff` | `HANDOFF.md` current |

`uno-break-it` writes its findings to `FINDINGS.md`. A Stop hook (`uno-done-guard.ps1`, in this repo's `hooks/` folder) blocks a "done / shippable / ready to demo" claim in an Uno repo once, until `docs/COMPLETENESS.md` exists and is newer than the last source commit.

## MVUX vs MVVM

Default to **MVUX** for app-level state with async/reactive data flows:
- Feeds from services
- Cached lists
- Paginated data
- Network-bound state

Use **MVVM** (`CommunityToolkit.Mvvm`) only for:
- Samples or demos
- Single-page tools
- Pages whose state is mostly imperative toggles plus a few observable properties

State the choice explicitly when scaffolding and explain why. Do not switch mid-project. This split is a project convention; the recommended preset defaults to `-presentation mvux`. *(audit R10)*

MVUX shape:
- Models are `partial record` (immutable).
- Source generator produces the bindable ViewModel from the Model. Generator v3 (default since Extensions 7.2) names it `{Name}ViewModel` (`MainModel` -> `MainViewModel`) and exposes states as plain `T` properties, record feeds as `Bindable{Record}ViewModel`, public methods as `IAsyncCommand`, and a public `Model` property, so never name a model member `Model` (CS0102). *(audit R11)* `[verified: 6.7.30]`
- `IFeed<T>` for read-only async data, `IState<T>` for mutable, `IListState<T>` for selection-bindable lists.
- `FeedView` handles loading / error / empty / data states.
- Public methods on Models auto-generate commands.
- Data entities are immutable records; use `with` for updates.

## XAML Binding

- **MVUX pages → `{Binding}`.** *(audit R12)* MVUX sets `DataContext` to a source-generated ViewModel that projects `IFeed`/`IState` into bindable values. That ViewModel is strongly typed (INPC `T` properties), but `x:Bind` against it cannot compile: the Uno Platform XAML generator does not see types emitted by the MVUX source generator (`UXAML0001 Unable to find member ... on type MainViewModel?`, `CS0400 MainViewModel could not be found`). Inside `FeedView`, `Data` is `object`, so `{x:Bind Data.X}` fails too (CS1061). `x:Bind` therefore does **not** work for the MVUX data surface. It is fine for item `DataTemplate`s typed with `x:DataType` = an entity record and for plain members of the hand-written model record. `[verified: 6.7.30 / build]`
- Two-way to state is `{Binding State, Mode=TwoWay}` (not `.Value`: `{Binding Name.Value}` shows empty and writes nothing). TextBox pushes on LostFocus by default; add `UpdateSourceTrigger=PropertyChanged` for live input. FeedView content is `{Binding Data.X}` in the ValueTemplate (read-only; see the `Data.X` TwoWay gotcha for editable fields). *(audit R13)* `[verified: 6.6.42 + 6.7.30]`
- **Non-MVUX / MVVM / static XAML → prefer `x:Bind`** (compiled, type-checked, faster). This default holds **only** when the `DataContext` is a plain typed object, not an MVUX proxy.

## Navigation (Region-Based)

- Use XAML attached properties: `Navigation.Request`, `Region.Attached`, `Region.Name`.
- Do not navigate from code-behind.
- Register routes centrally via `ViewMap` / `DataViewMap` / `ResultDataViewMap`.

## Code-behind budget (binding)

Page and control code-behind holds `InitializeComponent` plus platform glue that has no XAML surface. Everything else has a declared home:

| Need | Use | Instead of |
|---|---|---|
| React to an event (click, item click, Enter in a TextBox) | Model method → generated command; `utu:CommandExtensions.Command` for events without a `Command` property | `Click`/`Tapped` handlers that call the model |
| Command from inside a template | `{utu:AncestorBinding AncestorType=Page, Path=DataContext.X}` | Handler on the item that walks to the page |
| Show/hide or restyle by state | `utu:VisualStateManagerExtensions.States` bound to model state; FeedView templates for data states | `.Visibility =` in code-behind |
| Tabs inside a page (recipe Ingredients/Steps/Reviews/Nutrition, All/Unread/Read) | Nested `uen:Region.Navigator="Visibility"` + `utu:TabBar` items with `uen:Region.Name`; routes nested under the page route, one `IsDefault: true` | `SelectionChanged` handler toggling panes |
| Sheet, filter panel, side drawer | `uen:Navigation.Request="!Route"` to a **Page** (opens as a flyout; a `ContentDialog` opens as a modal), styled with a `DrawerFlyoutPresenter` style (`BottomDrawerFlyoutPresenterStyle` on phone); state and Reset/Apply live in the model | An overlay Grid whose Visibility code-behind toggles |
| Back | `utu:NavigationBar` with a `MainCommand` `AppBarButton` (brings the Android back gesture) | A Grid with a `Navigation.Request="-"` Button |
| Theme / language switch | Model command calling `IThemeService` / `ILocalizationService` | Seven click handlers |
| Breakpoints | Always `{utu:Responsive}` on elements (see *Breakpoints* below). Non-string values (`Thickness`, `Grid.Row`/`Column`/`ColumnSpan`, `HorizontalAlignment`) work; on `ColumnDefinition.Width` it does not switch on Skia heads (Patina, 2026-10-03), so keep columns fixed and make the panel placement responsive | `SizeChanged` handlers comparing widths; width flags on a view model |
| A control the platform ships | `RatingControl`, `ProgressBar`, `utu:NavigationBar`, `utu:CardContentControl`, `utu:Chip`, `PipsPager`, `ToggleSwitch` + lightweight styling; then Windows Community Toolkit 8.x (Uno-supported except `Media`; see `capability-coverage.md`) | A custom control with the same job |
| An icon | `SymbolIcon`/`FontIcon` (Fluent symbol font) or keyed path data from one open icon set in `Icons.xaml` via `PathIcon` | `Path`/`Ellipse`/`Line` shapes drawn as an icon, or inline path data in a page |

### Breakpoints (binding)

Breakpoints never live in code-behind or in a view model. Every width-dependent value is a `{utu:Responsive}` in XAML.

- No `SizeChanged` / `ActualWidth` comparisons, no `IsWide`/`IsNarrow` flags on a view model, and no `xaml-lint: allow responsive` exceptions for them. "It also depends on state" is not an exception: split the two. State goes on the model as an ordinary property, and width stays in `{utu:Responsive}` on a wrapping element. For example, a header label that shows for the current item from one width and for every item from a wider one: an outer element with a Responsive `Visibility`, an inner one bound to `IsCurrent`.
- Thresholds other than the defaults go in a `utu:ResponsiveLayout` resource, one per page or one app-wide `DefaultResponsiveLayout`. Pass it explicitly (`Layout={StaticResource ...}`) inside `DataTemplate`s. The defaults are 150/300/600/800/1080 (Narrowest/Narrow/Normal/Wide/Widest; `ResponsiveHelper.DefaultLayout`, verified in the Toolkit docs 2026-09-30).
- Resolution: only the size classes you give a value take part, and the widest one whose threshold the window meets wins. Below the smallest, the first provided value applies. So `Narrow=Collapsed, Wide=Visible` with `Wide=1280` switches exactly at 1280.
- Structure that changes by width is still expressed as Responsive values on elements (`Grid.Row`/`Column`/`ColumnSpan`, `Visibility`, `Orientation`). Not on `ColumnDefinition`/`RowDefinition`: they are not FrameworkElements and do not switch on Skia heads. `utu:ResponsiveView` is the escape hatch for layouts that truly differ, and it recreates its content on switch.
- **One exception: cached pages.** On a page with `NavigationCacheMode="Required"` that leaves the tree (a sibling route replaces it, then Back), Toolkit 9.1 `ResponsiveExtension` never reconnects and the page freezes at its last band. Those pages use `AdaptiveTrigger` states on the root Grid, marked per the workaround protocol below (`WORKAROUND(ResponsiveExtension does not reconnect after Unloaded)` + `xaml-lint: allow responsive`). Remove when the Toolkit fix ships. See `uno-runtime-gotchas.md` (Toolkit & Material controls).
- Verify every band at a width inside it (below, between and above each threshold), resizing twice before capturing (see the resize gotcha in `uno-runtime-gotchas.md`). Repeat the check after one detail navigation and Back.

Measured failure (Cargo, 2026-09-29): header breakpoints lived in `MainViewModel.ApplyWidth` plus a `SizeChanged` handler, carried an `allow responsive` comment "until the Toolkit pass", and survived the whole MVVM refactor. Moving them to three Responsive values removed both code paths.

Legitimate code-behind (media transport, map-control APIs, Skia invalidation, measured platform bugs) carries `// xaml-lint: allow codebehind - reason` above it. The lint (`xaml-semantic-lint.ps1`) enforces this table: CODEBEHIND, OVERLAY, BACKBAR, RESPONSIVE, BUILTIN and ICON are gating rules, and the PostToolUse hook reports them on every `.xaml`, `.xaml.cs` and new `.cs` file.

## Workaround protocol (binding)

When a framework mechanism fails (a `Navigation.Request`, a region, a Toolkit control, a binding path), replacing it with code-behind is a decision, not a fix. Before replacing it:

1. **Stop at the first failure.** The Debug Checkpoint applies from the first failure of a platform mechanism, not after two fix cycles.
2. **Reduce it.** The smallest page that reproduces it, on the failing head, with Uno.Sdk / Toolkit / Extensions versions.
3. **Record it.** Add a Runtime Gotcha to `uno-runtime-gotchas.md`: symptom, repro, versions, and the alternative that worked.
4. **Mark the code.** `// WORKAROUND(<gotcha name>): <one line>; remove when <condition>` at the site (the condition is a version or a fix: `remove when Uno.Sdk > 6.7.30`, `remove when unoplatform/uno#12345 ships`; `remove when unknown` is allowed but is itself an Unresolved Question), plus the matching `xaml-lint: allow <rule> - see WORKAROUND` so the lint stays green and every workaround is greppable.
5. **Keep it local.** Other screens keep the framework mechanism until they hit the same failure. A workaround copied to screens that never failed becomes the app's architecture.
6. **Surface it.** List it under Unresolved Questions in the handoff, and consider filing it upstream.

Measured failure (ChefsNobu, 2026-09): `uen:Navigation.Request` on recipe cards did nothing on Android, a `Tapped` probe proved the input arrived, and the fix became a code-behind handler with no repro, no gotcha and no upstream report. Later screens copied the pattern until the app had 54 code-behind hits, 8 hand-built back bars and a filter overlay toggled from code.

## Styling Rules

- Never hardcode hex colors. Use the app theme's color/brush resources.
- Never set explicit font sizes. Use the app theme's type-scale styles. The 6.7.30 template ships `FontSize="20"` on MainPage; replace it with a type-ramp style. *(audit R18)*
- Use Lightweight Styling resource keys for control-level overrides.
- New styles go in `App.xaml` or under `Themes/`.
- SimpleTheme is the default: it is what `-preset recommended` selects. Use Material (`-theme material`) when the design calls for it. *(audit R20)* `[verified: 6.7.30 / CLI]`

### Semantic first (binding for every color and surface)

Walk this ladder top-down. Stepping down a rung needs a one-line reason written in the plan, spec or commit, naming what the rung above could not do.

The role brush keys below (`PrimaryBrush`, `SurfaceBrush`, `OnSurfaceVariantBrush`, `OutlineBrush`...) are the shared Uno.Themes vocabulary and resolve the same under SimpleTheme and Material (verified in Uno.Themes.WinUI 7.1.1; Simple migrated to the shared brushes). Only rung 1's override mechanism differs: Material uses `ColorPaletteOverride`, Simple uses `SimpleTheme.ColorOverrideDictionary` or a seed color. Rungs 2 to 4 apply unchanged.

1. **Material role** - the brand palette goes into the roles (`Primary`, `Secondary`, `Tertiary`, `Error`, `Background`, `Surface`, `SurfaceVariant`, `On*`, `Outline`, `OutlineVariant`). `ColorPaletteOverride.json` when the `Dsp` UnoFeature is on (the build regenerates the .xaml), else `ColorPaletteOverride.xaml`. Screens bind role brushes (`PrimaryBrush`, `SurfaceBrush`, `OnSurfaceVariantBrush`...).
2. **Lightweight-styling key** - per-control deviations override the control's resource keys at app or page level. Never copy a control template to change a color or radius.
3. **Derived style `BasedOn` a Material/Toolkit style** - for a reusable variant.
4. **Custom token** - only for a value no role covers (chart series, ink pinned to a light map). Lives in a palette/token file, never inline in a screen.

Surfaces follow the same ladder: a rounded, filled or stroked container is `utu:CardContentControl` (`Filled`/`Outlined`/`ElevatedCardContentControlStyle`) tuned by lightweight keys (`CardCornerRadius`, `CardPadding`, `<Variant>CardContentBackground`...; see the Uno Toolkit docs). A bare `Border` is for dividers and image clipping only.

Check it with `uno-audit/scripts/xaml-semantic-lint.ps1 -Path <project>`; deliberate exceptions carry `<!-- xaml-lint: allow card|hex - reason -->`. Gotchas below marked **Fallback** are workarounds for when a rung above has demonstrably failed, not a starting point.

## Platform Strategy

- Early: POC on all targeted platforms.
- Middle: Develop primarily on Windows (best tooling).
- End: Test equally across all platforms.
- Platform-specific code via file suffixes or runtime checks. Uno.Sdk `Uno.CrossTargeting.targets` removes `*.Android.cs`, `*.iOS.cs`, `*.wasm.cs`, `*.desktop.cs` (and more; see that file for the full set) from non-matching TFMs. *(audit R21)*

## Extensions Stack

- Hosting: `IHostBuilder` pattern.
- DI: Microsoft.Extensions.DependencyInjection.
- Configuration: Options pattern (`IOptions<T>` / `IWritableOptions<T>`).
- HTTP: Kiota preferred for OpenAPI clients; Refit acceptable.
- Logging: `Microsoft.Extensions.Logging` (Serilog optional).
- Auth: MSAL / OIDC / Web / Custom - pick by scenario.
- Localization: `.resw` files with runtime culture switching.

## SkiaSharp 4 Capability Note

GA = `4.148.0`, the first 4.x stable, shipped 2026-06-22 (NuGet 2026-06-23; 2026-06-29 was `4.150.0-rc.1`). Latest stable is **`4.152.1`** (2026-09-17). *(audit S01)* Verified against the `v4.148.0` managed binding source on 2026-06-30. Re-checked 2026-09-25 against stable `4.151.1` from the local NuGet cache: still no `SKMesh`/`DrawMesh` and no Graphite symbols in the managed binding (Graphite arrived in 4.152.0; see below). Uno.Sdk 6.7.30 stable still bundles SkiaSharp 3.119.2, and can run 4.x through `SkiaSharpVersion` (see the pinning section). Uno Platform is now a co-maintainer of SkiaSharp.

- Do not describe SkiaSharp 4 as "2D-only" or "a 2.6D canvas drawer." It is a 2D canvas API with GPU acceleration (GL, Direct3D, Metal, Vulkan), runtime SkSL shaders, an image-filter graph, and a mesh primitive.
- **There is no `SKMesh` type in the GA managed binding.** Verified by grep of `binding/` and `source/` at tag `v4.148.0`: no `SKMesh`, no `SKCanvas.DrawMesh`, and zero `mesh` bindings in `SkiaApi.generated.cs`. Reflection over the NuGet binaries finds no mesh types or members in any version through `4.152.1` and `4.154.0-preview.1`. Do not claim `SKMesh` exists in any 4.x release to date. *(audit S02)*
- **The mesh primitive that DOES exist is `SKVertices`** (`SKVertices.CreateCopy(SKVertexMode, positions, texs, colors, ushort[] indices)`; 3 `CreateCopy` and 5 `DrawVertices` overloads, identical in 3.119.2), drawn with `canvas.DrawVertices(...)`. Indices are `ushort[]`, so one call addresses at most 65,536 vertices; split larger meshes. Use it for triangle meshes, gradient meshes, and textured 3D. Projection, lighting, and depth sort happen in user shader/CPU code, then emit triangles through `SKVertices`, or drive a full SkSL shader via `SKRuntimeShaderBuilder`. *(audit S03)*
- The upstream Skia `SkMesh` (custom-mesh-with-SkSL-vertex+fragment) API is not bound through `4.154.0-preview.1`. If a future preview binds it, re-verify before relying on it.
- Wiesław Šoltés's "Mesh Modeler" Uno + SkiaSharp sample almost certainly uses `SKVertices`/`DrawVertices` or a custom P/Invoke, not a GA `SKMesh` binding. Confirm the build before citing it as `SKMesh` proof.
- Preferred phrasing: "SkiaSharp is a 2D canvas API; in v4 you build meshes and 3D with `SKVertices`/`DrawVertices` plus runtime SkSL shaders, on a GPU-accelerated backend."
- Graphite (newer GPU backend): 20 `SKGraphite*` binding types ship in **stable 4.152.0 / 4.152.1** (absent from `4.150.0-preview.2.1` and `4.151.1`). Uno Platform's renderer does not use Graphite. *(audit S04)*
- v4 GA capabilities to lean on instead: variable fonts (`SKFontArguments.VariationDesignPosition`), color font palettes (`PaletteIndex`/`PaletteOverrides`/`SKTypeface.Clone(paletteIndex)`), animated WebP (`SKWebpEncoder.EncodeAnimated`), runtime shaders, and the image-filter graph (`CreateShader`/`CreateDisplacementMapEffect`/`CreateArithmetic`/`CreateBlur`). Only `SKFontArguments` (a ref struct) and `SKWebpEncoder.EncodeAnimated` are v4-only; runtime shaders (`SKRuntimeShaderBuilder`) and those image-filter factories already work on the Uno-bundled 3.119.2. *(audit S05)*

## Preview SkiaSharp + Uno

When running SkiaSharp 4.x while Uno Platform stable still bundles 3.x:

- **Stable Uno.Sdk supports SkiaSharp 4 through the `SkiaSharpVersion` property.** Put `<SkiaSharpVersion>4.152.1</SkiaSharpVersion>` in the app csproj; the SDK restores the managed package and retargets the native asset to match. A dev Uno.Sdk is no longer needed; fall back to a matching dev build only if a native mismatch appears at runtime. *(audit P01, NEW-04)* `[verified: 6.7.30 / desktop / X11: SKCanvasElement, Toolkit Skia ShadowContainer, composition effects; Lottie not exercised; Windows re-verify]`
- `UnoDisableLottieSkiaVersionCheck` lives in the Uno.WinUI.Lottie buildTransitive targets and disables a *presence* check for the `SkiaSharp.Views.Uno.WinUI` + `SkiaSharp.Skottie` NuGet references; it never compares versions. Set it only when those packages come from ProjectReferences or other non-NuGet sources. *(audit P02)*
- Cross-reference the official SkiaSharp Uno gallery sample: `samples/Gallery/Uno/SkiaSharpSample.Uno.csproj` at the SkiaSharp tag (present at v4.148.0 and v4.152.1). It pins Uno.Sdk in the csproj `Sdk=` attribute (`Uno.Sdk/6.6.0-dev.208`), not in `global.json`, and builds SkiaSharp from source. *(audit P03)*
- If a SkiaSharp/native version mismatch hits at runtime, check `SkiaSharpVersion` and the restored native package version before patching managed code.

## Runtime Gotchas & Spec-Time Facts (moved)

Measured runtime gotchas and docs/SDK-verified spec-time facts live in `references/uno-runtime-gotchas.md`.
Load it before writing code for a specific platform head or control, before a spec commits to a library or
rendering path, and whenever debugging or verifying an app.

## WinUI type ramp in Material apps

- **In Material-themed Uno apps, WinUI type-ramp and system brush keys are the wrong design system.** *(audit W01)* WinUI keys (`TitleTextBlockStyle`, `BodyTextBlockStyle`, ...) and system brushes (`ApplicationPageBackgroundThemeBrush`, `TextFillColorPrimaryBrush`, `CardBackgroundFillColorDefaultBrush`, ...) **do resolve** under Uno Material, because the template merges `XamlControlsResources`, but they render Fluent type metrics and colours, not Material ones. Do not mix them into Material UI: use the Material keys (short keys like `TitleLarge`, brushes like `SurfaceBrush`). `[verified: 6.6.42 + 6.7.30]`
