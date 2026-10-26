---
name: uno-audit
description: Full codebase pass for an Uno Platform project - best practices, dead code, comment cleanup, performance, stack currency - with runtime verification. Use whenever asked to audit, review, clean up, optimize, or apply best practices to an Uno Platform codebase, or before pushing a demo/sample repo. Do NOT use for design-quality work on an existing surface (spacing, hierarchy, states, fit and finish), or for judging whether the app is actually complete, shippable, or still stubbed/simulated across screens, routes, data, states and platforms - that is uno-completeness-audit.
---

# Uno Audit

The standard audit pass, so it never has to be dictated again. Guidance from invoked skills is binding: apply it, state in one line per skill which pattern it governs, and rewrite drafts that contradict it.

## Steps

1. **Invoke the relevant skills first** - the Uno Platform Studio skills (`uno-mvux-*`, `uno-navigation-*`, `uno-themes-*`, `uno-toolkit-*`) as the codebase touches each area. State per skill which pattern is being applied. Load `uno-scaffolding/references/uno-scaffolding.md` and `uno-scaffolding/references/uno-runtime-gotchas.md` in the same step; the gotchas file is what the pattern-conformance and runtime passes check against.
2. **Stack currency:** confirm .NET 10 TFMs and latest stable Uno.Sdk (check NuGet, never assume from habit). Flag preview pins that have a stable now. Run `dotnet list package --vulnerable --include-transitive` and `dotnet list package --outdated` against the `.sln` (both restore and rewrite `obj/`, ~3-4 min on a 3-project app); each vulnerable package is a finding, each outdated one a line with the reason it stays or the upgrade plan. List `WORKAROUND(` markers whose `remove when` condition the current versions now meet.
3. **Code hygiene:** remove dead code, unused usings, duplicate/redundant code, narration comments (comments that describe the next line or justify a change). Keep constraint comments.
4. **Pattern conformance:**
   - MVUX surfaces use `{Binding}`, never `x:Bind` (see `uno-scaffolding/references/uno-scaffolding.md`).
   - Toolkit/Extensions components before custom controls or helpers - most "small helper" cases already have one.
   - No hardcoded hex colors or font sizes; Material resources and type-scale styles only. Walk the semantic-first ladder in `uno-scaffolding.md` (role → lightweight key → `BasedOn` style → custom token).
   - **Semantic lint gate (mandatory, mechanical):** run `pwsh -NoProfile -File uno-audit/scripts/xaml-semantic-lint.ps1 -Path <project>` and report every count. Gating rules and XBINDMODE are findings with file:line (`-Json` lists them); the other info rules are reported as counts. Gating rules: **CARD** (hand-drawn card `Border` → `utu:CardContentControl`), **HEX** (literal outside a palette file), **TOKENTHEME** (app brush with one value for both themes), **BACKBAR** (hand-built back button → `utu:NavigationBar`), **CODEBEHIND** (handlers or `Visibility` toggles in code-behind), **OVERLAY** (overlay toggled in code → `!Route` flyout), **RESPONSIVE** (breakpoints in code-behind), **BUILTIN** (custom control shadowing `RatingControl`, `ProgressBar`, `CardContentControl`...), **ICON** (inline path geometry outside `Icons.xaml`: a hand-drawn or unsourced icon), **PLATFORMLEAK** (`#if __ANDROID__`/`OperatingSystem.Is*` in a model or view model → platform service), **SYNCWAIT** (`.Wait()`, `.Result`, `.GetAwaiter().GetResult()` outside tests → `await`). Info: **XBINDMODE** (`x:Bind` with no `Mode`, OneTime by default: confirm each bound value never changes, else `Mode=OneWay`), **TOKEN**, **ADAPTIVE**, **TEMPLATE**, **WORKAROUND**. The replacements are the *Code-behind budget* and *Semantic first* sections of `uno-scaffolding.md`. Report a zero as a zero; a count that was never measured is a finding, never a pass. Every surviving hit is fixed or carries `xaml-lint: allow <rule> - reason` in a comment above it; a hit that exists because a framework mechanism failed follows the *Workaround protocol*. Exit code 1 means gating hits remain.
   - Region-based navigation via XAML attached properties, no code-behind navigation.
   - Check against the Runtime Gotchas list in `uno-scaffolding/references/uno-runtime-gotchas.md`.
5. **Performance pass:** virtualization on lists, per-frame allocations, Skia object caching, startup work off the UI path.
6. **Change-cost probe (maintainability):** read the code only; make no change.
   - **Feature:** the app's main job as the README or spec states it; tiebreak by the route with the most code.
   - **Three changes:** (a) change one business rule; (b) move storage or backend to the next one an owner would plausibly ask for (local file → SQLite or cloud sync; mock → real API), named in the table; (c) error and retry on the riskiest I/O in the feature's main path, the one with no error handling today. If the feature has no data path, (b) and (c) become "adjust shared typography/spacing" and "add a new state to the screen".
   - **For each change**, list the files it would touch, including user-facing copy (resw, UI strings, README) that restates the rule, and name the test that would catch a mistake. If no test could exist yet, name the missing fake or hook (for example a fake store with no write-failure switch).
   - **Verdict scale:** *Contained* (the change lands where the responsibility lives and a test guards it); *Scattered* (the rule or value is repeated, in code, styles or copy); *Unguarded* (contained but nothing would catch a regression). Scattered and Unguarded are findings with file:line.
   - **Evidence:** a behavior claim inferred from code ("the exception escapes, no message shows") is marked *inferred*. Step 7's runtime pass confirms it, or it goes to Unresolved Questions. Dead code found along the way is reported under step 3.
   - **Output:** a table with change, files, test or missing hook, verdict.
7. **Build gate:** zero warnings. Then **runtime verify** the touched surfaces via `uno-verify` - an audit that only compiles is half done.
8. **Ship (only when asked):** conventional commit(s), push to the named repo, refresh README. Never commit or push unprompted.

## Output

Report what changed (with files), why, the build/test result, and open questions. Group findings by category with file:line references.

## Example

> "uno-audit then push to github.com/<you>/<samples-repo>"
→ skills invoked and cited, 14 cleanups across 6 files, Uno.Sdk bumped, build clean, 3 screens re-verified via uno-app, conventional commits, pushed, README updated.

## Anti-pattern

Invoking the skills, then writing code from prior assumptions anyway. Invocation without application is worse than skipping the skill - it creates false confidence that guidance is loaded.
