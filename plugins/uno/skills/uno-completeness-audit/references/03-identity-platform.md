# Identity and platform areas - Authentication, Responsive/adaptive UI, Platform behavior

These areas are where "works on my desktop" hides. Each is graded per supported head; a head
that was not run is `X`, never inherited from another head.

---

## Authentication

**Complete means:** sign-in/out, session persistence, expired sessions, unauthorized states, account flows work.

### Inventory

Flows: sign in, sign out, first launch, relaunch with a valid session, relaunch with an expired
session, token refresh mid-session, unauthorized resource, account (profile, password change,
delete account) if the design shows it. Provider: MSAL, OIDC, Web, Custom, or none.

If the app has no accounts by design, the `N/A` needs the product reason stated and confirmed
under Unresolved Questions. A login screen with no backend is `Simulated`, not `N/A`.

### Static checks

- `Uno.Extensions.Authentication` configured (`UseAuthentication`) or a documented reason for a custom flow.
- Token storage: in `ITokenCache`/secure storage, never in `ApplicationData.LocalSettings` plain, never in a static.
- Sign-out clears the cache and navigates to the login route (`Qualifiers.ClearBackStack`).
- HTTP clients wired with the auth handler (`AddAuthenticatedClient` or equivalent) instead of a hand-set header.
- A 401 path: refresh once, then sign-out, then login route. No infinite refresh loop.
- Authorization-gated UI hidden by visibility only, with the command still executable.
- Login page with a hardcoded "demo/demo" acceptance in the production path.

### Runtime proofs

- Sign in > kill > relaunch: lands past login.
- Expire the token (shorten lifetime, or corrupt the cache file) > relaunch: lands on login with a message, no crash, no blank page.
- Sign out > back button: cannot return to an authenticated page.
- Hit a protected resource unauthorized: distinct permission-denied state, not a generic error.

### Uno traps

- App MCP tools need a signed-in Uno Platform account themselves; an empty tool list is not an app auth bug.
- OIDC on WebAssembly needs the redirect URI registered per host; desktop `R` says nothing about WASM.

---

## Responsive/adaptive UI

**Complete means:** supported screen sizes, orientations, densities and form factors work without clipping/overflow.

### Inventory

From the csproj TFMs and the spec: the form factors (phone, tablet, desktop, browser), the
breakpoints the design uses, both orientations on mobile, and the density range (100% to 200%
on Windows, mdpi to xxxhdpi on Android).

### Static checks

- `ResponsiveExtension` / `ResponsiveView` / `VisualStateManager` breakpoints present for any screen the design shows at two widths.
- `{utu:Responsive}` on `ColumnDefinition.Width` / `RowDefinition.Height` (does not switch on Skia heads; columns stay fixed and panel placement is responsive).
- `{utu:Responsive}` on a page with `NavigationCacheMode="Required"` (freezes after Back on Toolkit 9.1; cached pages use `AdaptiveTrigger`).
- Fixed effective-pixel `Height` on rows, cards, or list items (clips in landscape phone height).
- `Grid` or `StackPanel` with non-Stretch alignment holding star columns or empty placeholders (collapse to 0).
- `FlipView` sized to content with items that grow later (clips on Android).
- Text at fixed widths without `TextWrapping`; horizontal `ScrollViewer` absent where a table can exceed width.
- `SafeArea` (Toolkit) or `ApplicationView.VisibleBounds` handling on mobile roots.
- Responsive shell: `TabBar` on narrow, `NavigationView` on wide, or a stated single-form-factor decision.
- Oversized `CornerRadius="999"` pills (render as ovals on Skia; write half the height).

### Runtime proofs

- Resize the desktop window to the narrowest supported width and to a phone-landscape height (≈ 360x640 and 800x360 effective). Snapshot; nothing clips, nothing overflows horizontally.
- Repeat the resize after one detail navigation and Back: every breakpoint band still switches.
- On Android/iOS: rotate once per screen; keyboard up on every form screen (the `InputPane` must not cover the focused field).
- Change display scaling once (Windows 150% or Android font scale 1.3): layout survives.

### Uno traps

- `AppWindow.MoveAndResize` is a no-op on desktop; `AppWindow.Resize` can outrun the Skia surface and render clipped. Pin the content, not the window, for a known size.
- A `Viewbox` scales `SKCanvasElement` together with XAML children correctly; a `ScaleTransform` needs proof.

---

## Platform behavior

**Complete means:** back button, lifecycle, permissions, file pickers, notifications, sharing, keyboard, safe areas, etc. behave appropriately.

### Inventory

Per head, the OS surfaces the app touches: back gesture, suspend/resume, permissions (camera,
location, storage, notifications), file open/save pickers, share sheet, push or local
notifications, hardware keyboard shortcuts, status bar and safe areas, window sizing and
title bar (desktop), browser history and PWA install (WASM).

### Static checks

- Android: manifest permissions match features actually used; each runtime-permission call has a denied path.
- iOS: `Info.plist` usage descriptions present for every permission requested.
- Lifecycle: state saved on `Suspending`/`EnteredBackground`; a form half-filled survives a resume.
- `FileOpenPicker`/`FileSavePicker` called on the UI thread (MVUX commands may run off it; marshal via `DispatcherQueue`); `InitializeWithWindow` on WinAppSDK only.
- Share: `DataTransferManager` or platform share, with a desktop fallback stated.
- Notifications: a permission prompt and a denied state, never assumed granted.
- Keyboard: `KeyboardAccelerator`s for desktop primary actions; Escape closes dialogs.
- Safe areas: Toolkit `SafeArea` on mobile roots, or explicit `VisibleBounds` padding.
- WASM: browser back integrates with navigation; `manifest.json` and service worker present if the spec says PWA.
- Debug-only environment hooks (`APP_NO_HOTDESIGN`, start-route overrides) gated with `#if DEBUG`.

### Runtime proofs

- Desktop: open and cancel each picker; confirm a chosen file is actually read/written.
- Android: back from each screen level; background the app for 30 s during a form edit and resume.
- Deny one permission; confirm the feature degrades with a message instead of crashing.
- WASM: browser back after two in-app navigations lands on the previous page, not off the site.

### Uno traps

- `MainWindow.UseStudio()` blocks window creation with no DevServer (desktop, stable too); gate it or launch via `uno_app_start`.
- `ShadowContainer` with a `LinearGradientBrush` background renders nothing (no shadow, no content); only `SolidColorBrush` backgrounds work.
- `Path.Data` elliptical arcs (`A rx,ry` with rx≠ry) throw at parse on Uno 6.6.x and on native renderers: a startup crash if in initial XAML. Uno 6.7 Skia renders them.
- Creating a secondary `Window` disturbs the main window's FullScreen presenter on desktop; defer presenter work to first `Activated`.
- Android Release restore can fail on the Mono runtime pack version; `dotnet workload update` realigns it. A head that does not build is `Broken` for every area on that head.
