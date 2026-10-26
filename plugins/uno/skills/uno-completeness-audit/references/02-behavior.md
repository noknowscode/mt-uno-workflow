# Behavior areas - Logic, Data, States, Forms

These four answer "does the app do what the product says, or does it draw it". Simulation hides
here more than anywhere else, because a screen with sample data and a working-looking form
screenshots identically to a finished one.

---

## Logic

**Complete means:** business rules are implemented, not simulated or represented only visually.

### Inventory

List every rule the spec, the design, or the domain implies: totals, validation thresholds,
permissions, status transitions, pricing, date math, sorting/filtering semantics, uniqueness,
limits. One row per rule with where it should live (model, service, server).

### Static checks

- Grep the production path (not `*.Tests`, not `Design/`) for `TODO|FIXME|HACK|NotImplemented|throw new NotSupported|Task.Delay\(|Random\(|Sample|Mock|Fake|Stub|Dummy|Lorem`.
- Hardcoded outcomes: a method that returns a constant, a computed field set from a literal, a status derived from the index.
- Rules that exist only in XAML: a `Visibility` converter deciding a permission, a `TextBlock` showing "Total: $1,240" bound to nothing.
- Rules duplicated between client and server with different results (compare formulas).
- Sorting/filtering that reorders the sample list but ignores the bound criteria (filter changes, list does not).
- A design-time or seed data path that also runs in Release (`#if DEBUG` missing around seeds, `SampleData` referenced from a service registration without a condition).

### Runtime proofs

- For each rule, change an input and assert the output through the DataContext: edit a quantity, read the total; set a date in the past, read the validation state.
- Filter and sort on a real list: assert item count and first item change.
- Exercise one boundary per rule (0, max, empty string, duplicate).

### Uno traps

- A feed that builds a record without the refresh revision is deduped: the state "changes" (`Revision = 2`) and the list keeps the stale result. Put the revision in the record.
- Date columns handed to a picker as UTC midnight lose a day west of Greenwich; a rule that reads "closing date" must be checked against the list beside it.
- `activitypointer.statuscode` style union columns label open work "Completed"; a status rule must agree with the filter next to it.

---

## Data

**Complete means:** reads/writes work; changes persist; refresh/update/delete flows work correctly.

### Inventory

Per entity: create, read (list + detail), update, delete, refresh, and where it persists
(`ApplicationData`, `Uno.Extensions.Storage`, `IWritableOptions<T>`, SQLite, a remote API via
`Uno.Extensions.Http`/Kiota/Refit). One row per (entity, operation).

### Static checks

- An operation with UI but no service method (a Delete `MenuFlyoutItem` whose command removes from the in-memory list only).
- A service registered as an in-memory fake with no real implementation behind a switch.
- Writes that never reach storage: an `IListState` updated with no `Messenger`/service call, an `Update` that mutates a copy.
- Reads with no refresh path, or a refresh that re-reads a cache.
- Remote clients constructed with `AddHttpClient<T>((provider, http) => new T(...))`: the constructed instance is discarded and the page renders blank with a null DataContext.
- Missing serialization contracts for AOT/WASM (`JsonSerializerContext`) when `Serialization` is in use.

### Runtime proofs

- Create > kill the app > relaunch > the record is there. (`uno_app_close`, sweep the process, `uno_app_start`.)
- Update a field > navigate away and back > the new value shows in both list and detail.
- Delete > confirm > record gone from list and from storage; a cancel leaves it.
- Refresh after a server-side change (flip the fake or edit the store file) > list reflects it.
- Two-way edits: type into a bound `TextBox`, read the state via `uno_app_get_element_datacontext`. If the box shows new text and the state shows old text, the binding is dead.

### Uno traps

- `{Binding Data.X, Mode=TwoWay}` inside a FeedView template writes to the immutable record and drops silently. Editable fields bind through the generated proxy: `{Binding Parent.Draft.X, Mode=TwoWay}`.
- `FeedView.Refresh` replays a cached upstream failure; a retry must change an upstream value.
- `IListFeed<T>.Selection(state)` throws `ArgumentOutOfRangeException` when the collection changes under it, then renders zero rows on retry.
- `TextBox.Text` commits on LostFocus by default; a save command that reads state before focus leaves saves stale data.
- WebAssembly persistence behaves differently from desktop (validated on quickchefs); `R` on desktop is `X` on WASM.

---

## States

**Complete means:** loading, empty, populated, error, offline, disabled, validation, success, permission-denied, long-content, etc. are handled.

### Inventory

Per data-bearing component, the matrix:

| State | Required when |
|---|---|
| Loading | any async read |
| Empty | any list or optional detail |
| Populated | always |
| Error + retry | any read that can fail |
| Offline | any remote source |
| Disabled | any command with a precondition |
| Validation | any form field |
| Success | any write the user waits for |
| Permission denied | any authorized or OS-permission gated feature |
| Long content | any text field, any list past one screen |
| Stale / partial | any cached remote data |

### Static checks

- `FeedView` with only a `ValueTemplate`: Loading is a default spinner (Partial), Empty and Error unhandled.
- No `NoneTemplate` when the feed can legitimately return nothing; absence thrown as an exception renders Empty as Error.
- Error templates with no retry, or a retry bound to `{Binding Refresh}` (dead).
- Skeletons that do not preserve the populated footprint (no `MinHeight` pin).
- Success feedback missing after a write (no `InfoBar`, no navigation, no changed state).
- Offline: no connectivity check and no distinct message from a generic error.
- Long content: `TextBlock` with no `TextWrapping`/`TextTrimming` on user-supplied text; lists without virtualization (`ItemsRepeater` in a `StackPanel` inside a `ScrollViewer`).

### Runtime proofs

Every state must be reachable through a service mode the app re-reads per call (slow / empty / error / offline). If no such mode exists, that is itself a `Partial` finding for Testing, and every unreached state is `X`.

- Force slow: skeleton renders inside the component shell, not around it.
- Force empty: Empty template renders with a next action.
- Force error: Error renders; invoke Retry; flip healthy; assert the service ran again (trace) and data appears.
- Long content: bind a 400-character string and a 200-row list; nothing clips or overflows horizontally.
- Superseded request: for any surface whose input can change while a load runs (search, filter, selection detail), slow the first request, change the input, and assert the final state belongs to the latest input. Prefer a unit test with a fake service that completes out of order; `uno-break-it` A16 is the runtime version. MVUX re-runs `SelectAsync` when the state changes, but whether a superseded call's result is dropped is not documented, so it is proven per app, never assumed. MVVM needs an explicit check (a request token or `CancellationTokenSource` swap) before assigning results.

### Uno traps

- A `Forever` storyboard on a skeleton keeps costing CPU while collapsed; `Stop()` on state exit. Performance finding if found.
- `StackPanel.Spacing` charges for collapsed children: three hidden `InfoBar`s leave a dead band.
- Building missing states is `uno-component-states` work; this area only grades them.

---

## Forms

**Complete means:** validation, keyboard behavior, submit/cancel/reset, errors and duplicate submissions are handled.

### Inventory

Per form: fields, required set, validation rules, submit, cancel, reset, error display, success
path, and what happens on a double-tap of Submit.

### Static checks

- Required fields with no validation, or validation that only lives in a tooltip.
- Search/filter boxes without `UpdateSourceTrigger=PropertyChanged` (nothing filters until focus leaves).
- Submit commands with no `CanExecute` guard or busy flag: duplicate submissions on double-tap.
- Cancel that does not restore the original values; reset that clears required defaults.
- `InputScope` missing on numeric, email, phone fields (mobile keyboards).
- No Enter-to-submit on single-line forms, no Escape-to-cancel on dialogs (desktop).
- Error messages generic ("Something went wrong") or positioned away from the field.
- `ComboBox` whose bound initial `SelectedIndex` is not 0: renders a blank face on Material while filtering correctly.

### Runtime proofs

- Submit empty: every required field shows its error, nothing is written.
- Submit valid: one write (trace count = 1), success state shown.
- Double-invoke Submit within the busy window: still one write.
- Cancel after edits: reopened form shows original values.
- Type into a search box: results change per keystroke (or record the debounce interval).

### Uno traps

- Android IME: Enter and backspace-at-0 never arrive as `KeyDown`; per-keystroke handling in `TextChanged` reorders rapid input. Structured editing on mobile parses on commit (`InputPane.Hiding` + `LostFocus`).
- A `Grid`/`StackPanel` with non-Stretch alignment sizes to content: a new-record form with empty fields collapses to ~250px. Use a star column with `MaxWidth`.
- Toolkit `InputExtensions` (`AutoFocusNext`, `AutoDismiss`, `ReturnType`) exist; a hand-rolled focus chain is a Toolkit note (Uno Platform Studio `uno-toolkit-*`).
