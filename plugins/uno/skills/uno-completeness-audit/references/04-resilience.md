# Resilience areas - Failure handling, Performance, Security/privacy

These areas separate an app that survives the field from one that survives the demo. Failure
handling and Performance are graded by driving the failure or measuring the number; Security
is graded by reading the repo, the manifests, and the git history.

---

## Failure handling

**Complete means:** network failures, unavailable APIs, malformed responses and unexpected conditions don't leave the app broken.

### Inventory

Per external dependency (API, file store, database, OS service, third-party SDK): what happens
on timeout, refusal (4xx/5xx), malformed payload, empty payload, slow response, and mid-operation
disconnect. One row per (dependency, failure).

### Static checks

- HTTP clients with no timeout, no retry policy (`Polly` or `Uno.Extensions.Http` resilience), and no distinction between "no network" and "server error".
- Deserialization with no guard: a missing field or wrong type throws out of the feed and renders Error for every list.
- `catch (Exception) { }` on the write path: the write fails and the UI reports success.
- Failures that reach the UI only as a generic message with no retry, or a retry that replays a cached failure.
- Exceptions during navigation or DI construction: swallowed by the navigator, page shows blank. No global unhandled-exception logging (`UnhandledException` handler, `AppDomain.UnhandledException`, `TaskScheduler.UnobservedTaskException`).
- Optimistic UI with no rollback on failure.

### Runtime proofs

Requires a service mode the app re-reads per call. Drive, on the desktop head at minimum:

- Network off (or the fake in `offline` mode) on every remote screen: a distinct offline state, retry works after the mode flips back.
- Server 500 on a write: the form keeps the user's input, shows the error, a second submit succeeds after the mode flips.
- Malformed payload (one field removed): the list renders the rows it can, or a clear error; the app does not crash.
- Slow response (5 s): skeleton shows, a navigation away during the wait does not crash on return.
- A crash in one page's ViewModel constructor: the page shows a real error, not a blank screen (or the finding is `Broken` with the blank-page symptom named).

### Uno traps

- `FeedView.Refresh` re-requests the bound feed; a failure cached upstream (in a `SelectAsync` projection off unchanged criteria) replays. Retry must change an upstream value.
- Absence thrown as an exception turns Empty into Error; the empty state becomes unreachable.
- Redirected stdout captures nothing from a desktop Uno app; failure diagnosis needs a file trace, not console.

---

## Performance

**Complete means:** startup, navigation, scrolling and common operations are acceptably responsive.

### Inventory

Numbers to measure, per head where reachable:

| Metric | Target (state the project's own if it has one) |
|---|---|
| Cold start to first interactive frame | desktop < 2 s Release, Android < 3 s |
| Navigation list > detail | < 300 ms |
| Scroll 200 rows | no dropped frames visible; worst frame < 34 ms on Android |
| Idle CPU after settle | < 2% of one core |
| Common write (save) | < 500 ms or a progress state past 400 ms |

### Static checks

- Lists without virtualization: `ItemsRepeater` or `ListView` inside a `StackPanel` in a `ScrollViewer`, or `ItemsControl` for long lists.
- `CompositionTarget.Rendering` subscriptions that never unsubscribe (forces display-rate frames forever at 50-70% of a core).
- `RepeatBehavior="Forever"` storyboards on decorative elements (same permanent pump; keeps costing while collapsed until `Stop()`).
- `Opacity` on a full-screen container (offscreen surface re-composited every frame; put alpha on children).
- Per-frame allocations or Skia filter DAGs rebuilt in `RenderOverride`; `SKRuntimeShaderBuilder` disposed per frame (AV on next invalidate).
- Startup work on the UI path: synchronous file reads, HTTP calls, or large seed generation in `App.OnLaunched` or the shell's constructor.
- Images without decode size (`DecodePixelWidth`) in lists.
- Debug-only diagnostics left on in Release (`UseStudio`, verbose logging).

### Runtime proofs

- Time cold start from process start to the first `uno_app_visualtree_snapshot` that returns the shell, Release build.
- Navigate list > detail five times; record the median.
- Scroll a 200-row list; on Android read `dumpsys SurfaceFlinger --timestats` for the app layer; on desktop watch process CPU while scrolling and after settle.
- Idle: 15 s after launch, read process CPU. Anything above ~2% means a pump is running.

### Uno traps

- An in-app `CompositionTarget.Rendering` monitor pumps the frames it measures; never measure with it.
- Invalidation is per-element on Skia desktop; caching settled content into `SKPicture` buys nothing there.
- Screenshot RPC through the bridge is ~2 s; animations shorter than that always capture settled.

---

## Security/privacy

**Complete means:** secrets aren't shipped incorrectly; sensitive data is handled securely; permissions are justified.

### Inventory

Every secret (API keys, client IDs with secrets, connection strings, tokens), every sensitive
field (PII, credentials, financial data), every permission requested, every outbound endpoint,
every log sink.

### Static checks

- Secrets in `appsettings*.json`, XAML resources, or source: grep `key|secret|token|password|connectionstring` (case-insensitive) across the repo, then `git log -p -S` for anything that was removed but still lives in history.
- `.gitignore` covers `appsettings.Development.json`, `*.user`, keystores, provisioning profiles, `.env`.
- Secrets loaded through `IConfiguration` with user-secrets or environment for local dev, and a stated production mechanism.
- Tokens or PII written to logs (`ILogger` calls that interpolate a request or a user object).
- Sensitive data in `ApplicationData.LocalSettings` or plain files instead of secure storage (`PasswordVault`, Keychain, KeyStore via `Uno.Extensions.Authentication` token cache).
- HTTP endpoints without TLS; certificate validation disabled anywhere.
- Android manifest / iOS plist permissions with no feature behind them.
- Clipboard, share, and export paths that leak more fields than the screen shows.
- Debug hooks (start-route overrides, fake auth acceptance, `APP_*` env switches) reachable in Release.
- WebView with JavaScript enabled and untrusted content.

### Runtime proofs

- Inspect the built output (`bin/Release`, the `.apk`/`.ipa`/`wwwroot`) for the strings found above; a secret in source that also ships in the binary is a Blocker.
- Sign in, then read the token cache location; confirm it is not plaintext in a user-readable file.
- Trigger one logged error; read the log line for PII.

### Uno traps

- `ColorPaletteOverride.xaml` and other generated files can carry copied config; check generated outputs, not just sources.
- The `uno-app` MCP add-in rejects screenshot paths outside the workspace; captures written under the project must be cleaned up before commit (they can contain user data).
