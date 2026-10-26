# Surface areas - Screens, Navigation, Interactions

These three areas answer "does the thing exist and can the user reach it and use it". They run
first because every later area is checked per screen and per interaction; an inventory gap here
means every later table is short a row.

Each check records: status (`Complete` / `Partial` / `Simulated` / `Missing` / `Broken` / `N/A`),
evidence (`R` / `C` / `I` / `X`), and a location.

---

## Screens

**Complete means:** every intended page, modal, dialog, tab, menu, and overlay exists.

### Inventory

| Source | What it yields |
|---|---|
| Spec / design / artboards | intended screens, including secondary ones the design implies (settings, about, confirm dialogs, empty first-run) |
| `ViewMap` / `DataViewMap` / `RouteMap` registrations | registered screens |
| `*.xaml` with `x:Class` deriving from `Page`, `ContentDialog`, `UserControl` hosted as a page | present screens |
| `NavigationView`, `TabBar`, `MenuFlyout`, `CommandBar` items | screens the shell promises |
| Domain reading | screens the product needs even if nobody drew them (confirm delete, session expired, permission denied, no network) |

Reconcile the lists. Each intended screen ends as `present and reachable`, `present but
unreachable`, or `missing`.

### Static checks

- A registered `ViewMap` whose page file does not exist, or a page file with no registration.
- A page whose XAML is a placeholder: a single `TextBlock` with the page name, a "Coming soon",
  a `Grid` with nothing in it. Grep `Coming soon|TODO|Placeholder|Lorem` in `*.xaml`.
- Dialog and flyout content defined but never opened from anywhere (`ShowAsync`, `Navigation.Request` with a dialog qualifier, `Flyout=`).
- Tabs declared in a `TabBar` with no matching nested route (renders nothing until one nested `RouteMap` is `IsDefault: true`).

### Runtime proofs

- Snapshot each screen once via `uno_app_visualtree_snapshot`; confirm the root is the expected page type and it has non-trivial children.
- Open each dialog and overlay once; confirm it renders and closes.

### Uno traps

- A page whose ViewModel fails DI activation still "exists": navigation swallows the exception and shows the page with a null `DataContext` and empty bindings. Blank page with no error is a `Broken` screen, not a slow one. Check `uno_app_get_element_datacontext` on the page root.
- Debug builds calling `MainWindow.UseStudio()` never create the window without a DevServer; that is a launch condition, not a missing screen. Launch through `uno_app_start`.

---

## Navigation

**Complete means:** every route works; back, deep-linking, tabs, menus, cancel/close flows behave correctly.

### Inventory

Every edge, not just every node:

- forward edges (`uen:Navigation.Request`, `INavigator.NavigateViewModelAsync`, menu items, list item taps)
- back edges (system back, `NavigationBar` back, dialog Cancel/Close, Escape)
- tab switches and their retained state
- deep links / start routes (`CHEFS_START_ROUTE`-style debug hooks count as routes and must not ship enabled)
- result-returning navigations (`ResultDataViewMap`, `NavigateForResultAsync`)

### Static checks

- Route names referenced in XAML that have no registration (case-sensitive string match across `RouteMap`).
- Navigation from code-behind where the project convention is XAML attached properties.
- `Navigation.Data` passed without a `DataViewMap` that accepts that type.
- Dialogs shown with `ShowMessageDialogAsync` whose result is read from the awaited value instead of a `DialogAction` callback: every confirmation silently cancels.
- Nested `TabBar` regions with no `IsDefault` route.
- A back stack that can grow unbounded (list > detail > list > detail via forward edges instead of back).

### Runtime proofs

- Walk every forward edge once and every back edge once, asserting the destination page type from the visual tree.
- Confirm cancel/close on each dialog returns to the caller with state unchanged.
- Navigate list > detail > back and confirm list scroll position and selection survive (or record that they reset, as a `Partial`).
- Deep link: launch straight to an inner route; confirm the shell (tabs, nav) is present, not just the page.
- On Android: system back from the root exits the app once, never twice; back inside a dialog closes the dialog.

### Uno traps

- `IRouteNotifier.RouteChanged` gives the route *path*, not the registered name; anything keyed on names needs template matching.
- A `TabBar` with `TopTabBarStyle` adds its own selection indicator and equalises item widths; tab visuals are a Visual quality note, not a navigation finding.
- Reverse-of-existing-edge navigations are back-navs; do not count them as missing forward routes.

---

## Interactions

**Complete means:** every button, field, gesture, toggle, menu item, link, command, etc. does something intentional.

### Inventory

Grep across `*.xaml` and code-behind for every interactive surface:

```
Button|HyperlinkButton|ToggleButton|ToggleSwitch|CheckBox|RadioButton|Slider|
ComboBox|TextBox|PasswordBox|NumberBox|AutoSuggestBox|DatePicker|TimePicker|
MenuFlyoutItem|AppBarButton|TabBarItem|NavigationViewItem|SwipeControl|
ListView|GridView|ItemsRepeater (item tap)|Flyout|ContextFlyout|
Tapped=|Click=|Command=|uen:Navigation.Request|utu:CommandExtensions
```

One row per instance, with what it is supposed to do (from the spec or its label).

### Static checks

Each interactive element must resolve to a handler, a command, or a navigation request. Flag:

- `Button` with no `Command`, no `Click`, no `Navigation.Request` (dead by construction).
- `Command="{Binding X}"` where no `X` method or command exists on the model or ViewModel.
- Handlers that only log, only show a toast/`InfoBar`, or contain `// TODO`: `Simulated`.
- `IsEnabled="False"` hardcoded on a control the design shows enabled: `Partial` with a reason required.
- Gestures the design implies (swipe to delete, pull to refresh, long-press menu, drag reorder) with no `SwipeControl`, `RefreshContainer`, `ContextFlyout`, or `CanReorderItems`.
- Links (`HyperlinkButton`) with no `NavigateUri` and no command.

### Runtime proofs

Invoking is not proof. Proof is the post-state:

1. `uno_app_visualtree_snapshot`, get the element ref.
2. `uno_app_element_peer_default_action` on it.
3. Assert: navigation happened (page type changed), or DataContext/state changed (`uno_app_get_element_datacontext`), or the service trace shows a call, or a file/store changed.

Retry any Button peer invoke that reports "Failed" once; ToggleButton and CheckBox peers may need a client-coordinate `uno_app_pointer_click` instead. `MenuFlyoutItem` does invoke via client-coordinate clicks.

### Uno traps (each one invisible to build, review and screenshots)

- `{Binding Refresh}` inside `FeedView.ErrorTemplate`: DataContext there is the `Exception`; the button renders enabled and does nothing. Needs `{Binding Refresh, ElementName=TheFeed}`.
- After a C# hot reload, a still-valid automation ref can drive an orphaned pre-reload instance: invoke returns Success, nothing visible happens. Restart the app before MCP-driven proofs after HR.
- Synthesized modifier chords (Ctrl+K) are not visible to `InputKeyboardSource` queries; keyboard shortcuts are `X` unless proven by post-state some other way.
- `Control.CharacterSpacing` on Button and `TextBlock.CharacterSpacing` are no-ops on Skia; a typographic finding, not an interaction one.
