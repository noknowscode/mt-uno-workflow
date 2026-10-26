---
name: uno-hill-climb
description: Metric-driven performance hill-climbing for an Uno Platform app with pixel-diff guards - pick one measurable target (first frame, interactive, memory, frame time, visual-tree size, publish size), change one lever at a time, and accept a change only when the number improves and screenshots at fixed "angles" stay within tolerance. Use when the user says "make it faster", "hill climb", "startup time", "frame rate", "memory is growing", "smaller publish", or names a numeric perf target. Do NOT use for code hygiene or stack currency (see uno-audit).
---

# uno-hill-climb

Models are good at climbing toward a number. This skill makes sure the number is real and the
climb does not trade quality for it.

## Step 0 - pick the metric and its source

| Metric | Source | Notes |
|---|---|---|
| First frame / interactive (ms) | fresh-process launch runner; discard run 0; median of ≥10 | all runs are cold processes with a warm file cache |
| Working set / managed heap (MB) | `uno_app_get_memory_counters` after a fixed scenario | run the scenario 3×, take the last |
| Frame time avg / p95 (ms) | in-app sampler (below) over a scripted 5 s window | only meaningful on Skia heads |
| GC gen0/1/2, alloc rate | `dotnet-counters monitor -p <pid> --counters System.Runtime` | pid from `uno_app_get_runtime_info` |
| Visual tree elements / depth | count nodes in `uno_app_visualtree_snapshot(justMyCode:false)` | the nearest proxy to "draw calls" |
| Publish size (MB), publish time (s) | `dotnet publish -c Release` output | per TFM; note AOT on/off |

State the target as an exit condition before touching code:
`interactive ≤ 800 ms on net10.0-desktop, median of 10, angles within 0.5 %`.

### Frame-time sampler (opt-in, DEBUG only)

Add once, behind an env var so it never ships:

```csharp
// App.xaml.cs, after the window is activated
if (Environment.GetEnvironmentVariable("UNO_PERF_METRICS") == "1")
{
    var frames = new List<double>(4096); var last = Stopwatch.GetTimestamp();
    CompositionTarget.Rendering += (_, _) =>
    {
        var now = Stopwatch.GetTimestamp();
        frames.Add((now - last) * 1000.0 / Stopwatch.Frequency); last = now;
        if (frames.Count == 4096) { Write(); frames.Clear(); }
    };
    void Write()
    {
        var s = frames.OrderBy(x => x).ToArray();
        var json = $"{{\"avg\":{s.Average():F2},\"p95\":{s[(int)(s.Length * 0.95)]:F2},\"n\":{s.Length}}}";
        File.WriteAllText(Path.Combine(ApplicationData.Current.LocalFolder.Path, "perf-metrics.json"), json);
    }
}
```

Pass the env var through the MCP launch or set it in the session before `uno_app_start`.

The sampler's `CompositionTarget.Rendering` subscription forces the compositor to produce frames continuously, which costs CPU (see `uno-scaffolding/references/uno-runtime-gotchas.md`, *Performance & frame pacing*). Measure frame time only over a window where frames render anyway (a scripted scroll or animation), never in the same run as CPU, memory, or idle measurements. On Android, measure with `dumpsys SurfaceFlinger --timestats` for the app's SurfaceView layer instead.

## Files

Results go to `docs/PERF.md`, created on first use with a one-line target, the angle list, and the
table header from *PERF.md row* below. Angle screenshots go under `docs/perf/`. If the app does not
read `--width/--height` launch args, size the window yourself (resize twice before capturing; see
the resize gotcha in `uno-scaffolding/references/uno-runtime-gotchas.md`) and record the real
capture size in `PERF.md`.

## Step 1 - baseline

1. Build, launch with `uno_app_start` (`args:["--width","1280","--height","800"]` when the app reads them).
2. Measure the metric per its source. Record as row 0 in `docs/PERF.md`.
3. Capture **angles**: 3–6 named app states reached by peer actions, each screenshot saved as
   `docs/perf/baseline/<angle>.png` at 1280×800, plus the same at 390×844 if the app is
   responsive. Angles are listed in `PERF.md` so later runs reproduce them exactly.
4. Commit the baseline row: `perf: baseline <metric> <value>`.

## Step 2 - levers (one per attempt)

From the Uno performance guidance, in the order that usually pays:

1. Visual tree: fewer panels-in-panels, Grid over nested StackPanels, `Collapsed` for unused branches.
2. `x:Load="False"` on rarely shown subtrees; `x:Load={x:Bind ...}` for toggled ones.
3. `ItemsRepeater` over `ItemsControl`; simpler `ListViewItem` style when selection is unused; `x:Phase`.
4. Animations: Opacity over Visibility; stop manual Storyboards on unload; determinate `ProgressRing` when hidden.
5. Images: explicit `Width`/`Height`; DPI-appropriate assets.
6. Paths: reuse; fonts over paths for glyphs.
7. Bindings: `x:Bind` (non-MVUX surfaces), short paths, `[Bindable]` on non-DependencyObject models.
8. Skia scenes: reuse `SKPaint`/`SKPath`, no per-frame allocations, compute in `Update`, draw in `Render`.
9. Startup: move work off `OnLaunched`; lazy services; Native AOT when publish-time cost is acceptable.

## Step 3 - the loop

```
for lever in levers:
    for attempt in 1..4:
        apply one change → build → relaunch → measure → capture angles
        diff each angle:  dotnet run <skill>/scripts/pixel-diff.cs -- baseline/<angle>.png run/<angle>.png
        accept if: metric improves ≥ the step you declared AND every angle ≤ tolerance
        on accept: commit "perf(<lever>): <metric> <before>→<after>", PERF.md row, new baseline angles
        on reject: git checkout -- . ; note the reason in PERF.md
    two rejects on the same root cause → stop this lever, report what was tried and the evidence
```

Defaults: tolerance **0.5 %** of pixels differing beyond a per-channel delta of 8; masks for
regions that are legitimately dynamic (clocks, live data). A diff over tolerance is a rejection
even when the metric improved. That is the whole point.

## pixel-diff usage

`scripts/pixel-diff.cs` ships in this skill's folder (`<skill>` above). Run it from anywhere:

```
dotnet run <skill>/scripts/pixel-diff.cs -- <baseline.png> <candidate.png> [--tolerance 0.5] [--delta 8] [--mask x,y,w,h ...] [--out diff.png]
```

Exit code 0 = within tolerance, 1 = over, 2 = size mismatch. Prints `changed=<pct> maxDelta=<n>`.
Requires .NET 10 SDK (file-based app with an ImageSharp package directive).

## PERF.md row

```
| 3 | 2026-09-28 14:10 | x:Load on SettingsPane | interactive ms | 1120 | 905 | 0.12 % | accept | a1b2c3d |
```

## Recap line

`🟢|🟡|🔴 <metric> <baseline>→<current> (<target>) · <accepted>/<attempts> levers · angles ok`
