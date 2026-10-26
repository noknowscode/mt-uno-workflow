# Quality areas - Accessibility, Visual quality, Testing

These areas are the last three rows of the table and the first three a reviewer notices. Visual
quality here is strictly "is there unfinished residue"; anything past that is a note for
a separate design pass. Testing is graded on what was actually exercised, per head.

---

## Accessibility

**Complete means:** keyboard/focus, screen readers, semantic labels, contrast, scaling and touch targets are usable.

### Inventory

Per screen: the tab order the design implies, every icon-only control, every image conveying
meaning, every status conveyed by color, the smallest touch target, the text-scaling range.

### Static checks

- Icon-only `Button`, `AppBarButton`, `ToggleButton` without `AutomationProperties.Name`.
- `Image` and `PathIcon` conveying meaning without a name; decorative ones not marked `AutomationProperties.AccessibilityView="Raw"`.
- Status by color alone (a red dot with no text or name).
- Custom controls (`SKCanvasElement` surfaces, hand-rolled toggles) with no automation peer: invisible to screen readers and to the App MCP alike.
- Touch targets under 44x44 on touch heads (`MinHeight`/`MinWidth` on icon buttons, chip close buttons, list-row actions).
- Focus visuals removed (`UseSystemFocusVisuals="False"`, `FocusVisualPrimaryBrush` transparent) or focus order broken by `TabIndex` / `IsTabStop="False"` on interactive elements.
- Hardcoded hex colors (Material role brushes carry the contrast pairs; a hex on a `TextBlock` is a contrast risk and a theming finding, see Uno Platform Studio `uno-themes-*`).
- Explicit font sizes (defeats text scaling; use the type scale).
- Reduced-motion preference ignored on decorative animation (`UISettings.AnimationsEnabled`).
- Localization: strings hardcoded in XAML on an app with a `Localization` feature or a bilingual requirement.

### Runtime proofs

- Tab through each screen via `uno_app_key_press`; assert focus lands on every interactive element in a sensible order (read `FocusManager` state or the focused element in the snapshot).
- Escape closes each dialog; Enter activates the default button.
- Snapshot with `justMyCode:false` and read `AutomationProperties.Name` on every button; count the unnamed ones.
- Contrast: measure text/background pairs on the two darkest and two lightest surfaces (WCAG AA 4.5:1 body, 3:1 large). Report the ratios.
- Text scaling: Windows 150% or Android font scale 1.3; nothing clips.

### Uno traps

- Checkbox and ToggleButton peers may not expose a default action through the MCP; that is a tooling gap, not an accessibility pass. Drive with a client-coordinate click and record the peer gap separately.
- Whitespace-only `TextBlock`s measure to zero on Skia; per-glyph layouts lose spaces and screen readers read the joined word.

---

## Visual quality

**Complete means:** no placeholders, debugging UI, unfinished screens, broken layouts, lorem ipsum or obvious inconsistencies.

### Inventory

Every screen at its populated state, plus the residue list below.

### Static checks

Grep `*.xaml`, `*.cs`, `*.resw`, `*.json` (production paths) for:

```
Lorem|ipsum|Placeholder|TODO|FIXME|Coming soon|Test|Sample|Debug|XXX|asdf|foo|bar|
Label|Button|TextBlock|Item 1|Card 1|Title here|Description here|Click here
```

as user-visible text (not identifiers). Then:

- Debug UI: FPS counters, trace panels, "reset data" buttons, environment banners not gated by `#if DEBUG`.
- Unfinished screens: a page with a single `TextBlock`, a `Grid` with one child, a dialog with no buttons.
- Broken layouts: overlapping elements, zero-size containers (the non-Stretch `Grid`/`StackPanel` collapse), clipped text, images stretched off-aspect.
- Inconsistencies visible to a casual reader: two radii families, two icon sets, mixed date formats, mixed capitalization in labels, a screen still on Fluent defaults inside a Material app.
- Default control chrome the design replaced everywhere else (a stock `ContentDialog` subclass that missed the implicit style, a 56px Material `ComboBox` beside 37px fields).
- Sample data on the production path that reads as fake: even-length names, round numbers, one date format, `user@example.com`.
- Image assets missing at any density (Android `drawable-*`, iOS `@2x/@3x`) or a stretched app icon.

### Runtime proofs

- Screenshot every screen populated with realistic data (long names, a zero, a large number, a missing optional field). Anything clipped, overlapping, or placeholder-shaped is a finding with the element name.
- Screenshot the two theme modes if the app supports both; a hardcoded color shows here.

### Hand-off rule

Spacing, hierarchy, copy tone, composition, motion: not this area. List them in one line under
"Noted for a design pass" and move on. This area's findings are things a user would call
*unfinished*, not things a designer would call *unrefined*.

---

## Testing

**Complete means:** critical workflows have actually been exercised on the target platforms.

### Inventory

The critical workflows from Step 1, crossed with every TFM in the csproj. One cell per pair.
Plus: automated tests that exist (`*.Tests`, `.tests/` scenario folders for Uno Platform Studio `uno-testing-*`,
runtime tests), and what they cover.

### Static checks

- A test project that exists but is not in the solution, or has zero tests, or has tests that assert nothing (`Assert.True(true)`, no asserts).
- `.tests/` scenarios present (Uno Platform Studio `uno-testing-*`) and matching the critical workflows.
- A service mode (slow / empty / error / offline) the app re-reads per call: without one, states and failures are untestable and the audit records that as a Testing `Partial`, with every unreached state `X`.
- CI: a workflow that builds every head; one that runs the tests.
- A `HANDOFF.md` or `RUNBOOK.md` naming which flows were run by a human on a device (the only evidence for drags, IME, modifier chords, and haptics).

### Runtime proofs

This area is the sum of the `R` grades everywhere else. Fill the matrix:

| Workflow | desktop | android | ios | wasm |
|---|---|---|---|---|
| … | R / X + reason | … | … | … |

- `R` requires a named proof (element ref, DataContext value, trace line, test name).
- `X` requires a reason (no device, no emulator, MCP cannot inject drag, head does not build).
- Run the existing automated tests once and record pass/fail counts verbatim.

### Uno traps

- `uno_app_start` does not reliably kill the previous instance; sweep the process before rebuilding or `MSB3027` blocks the next head.
- After entering Hot Design once, `uno_app_get_screenshot` returns 0 bytes for the rest of the process; relaunch before capture-based proofs.
- Runtime tests via the MCP prove desktop; Android and iOS need an emulator/device session, WASM needs a browser. Each gets its own column; none inherit.
