---
name: uno-scaffolding
description: Uno Platform / .NET scaffolding and XAML rules hub - SDK versions, `dotnet new unoapp` setup, build gates, MVUX vs MVVM choice, XAML binding style ({Binding} for MVUX, x:Bind otherwise), region-based navigation, code-behind budget, breakpoints, the workaround protocol, styling rules, platform strategy, the Extensions stack, SkiaSharp capability notes and version pinning, capability coverage, and version-stamped runtime gotchas. Use when scaffolding a new Uno app, choosing MVUX vs MVVM, deciding binding style, writing an Uno spec before any project files exist, deciding which checks a change must pass, or diagnosing a runtime behaviour that smells like a known Uno/Skia quirk. Do NOT use for deep MVUX, navigation, Toolkit or theming patterns (see Uno Platform Studio's `uno-mvux-*`, `uno-navigation-*`, `uno-toolkit-*` and `uno-themes-*` skills).
---

# Uno Scaffolding & XAML Rules

This skill is a hub. The rules live in this skill's `references/` folder. Other skills in this plugin point to them as `uno-scaffolding/references/<file>.md`.

**Read `references/uno-scaffolding.md` now** (core conventions). Read `references/uno-runtime-gotchas.md` before writing code for a specific platform head or control, before a spec commits to a library or rendering path, and whenever debugging or verifying an app. Read `references/capability-coverage.md` when building from a design, artboard set, spec, or screenshot.

## What the rules cover

| Section | Use it when |
|---|---|
| SDK Versions, New App Scaffolding | Creating a new Uno app, choosing a TFM, running `uno-check`, adding the `uno-app` MCP entry |
| Build gates | Any Uno build work (fix, screen, feature, app): which skills gate it and what "done" requires |
| MVUX vs MVVM | Deciding app architecture before writing any model |
| XAML Binding | Choosing `{Binding}` vs `x:Bind` (MVUX forces `{Binding}`) |
| Navigation (Region-Based) | Wiring `Navigation.Request` / `Region.Attached`, registering routes |
| Code-behind budget, Breakpoints | Where event handling, visibility, tabs, sheets and width-dependent values belong |
| Workaround protocol | A framework mechanism fails and code-behind looks tempting |
| Styling Rules | Colors, type scale, lightweight styling keys, the semantic-first ladder |
| Platform Strategy, Extensions Stack | Targeting, DI/hosting/auth/HTTP/config/logging choices |
| SkiaSharp | Any SkiaSharp capability claim and SkiaSharp 4 pinning via `SkiaSharpVersion` |
| WinUI type ramp in Material apps | Mixing WinUI style keys into a Material-themed app |
| `uno-runtime-gotchas.md` | Spec-time facts and measured runtime gotchas by area, each stamped with the SDK and host that verified it; ends with the claims the 2026-09-25 audit disproved |
| `capability-coverage.md` | Capability inventory from a design; control ladder: Uno Toolkit and platform controls, then Windows Community Toolkit 8.x, then custom with a written reason |
| Semantic lint | Mechanical check of the ladder: `pwsh -File uno-audit/scripts/xaml-semantic-lint.ps1 -Path <project>` |

## Precedence

The rules win over draft implementation. When a draft contradicts them, rewrite the draft.

Items tagged `[field note]` or "re-verify" were observed once and not reproduced in isolation; confirm on your SDK/host before building around them.
