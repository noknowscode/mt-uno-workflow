# Report template, severity rules, worked example

Read before writing the report. The report is the deliverable; the user reads only this.

---

## Statuses and evidence, restated

| Status | Meaning |
|---|---|
| `Complete` | Exists, does the intended thing, handles its states |
| `Partial` | Exists and works on the main path; a documented sub-case is missing |
| `Simulated` | Looks complete; the behavior is faked, hardcoded, sample-fed, or visual-only |
| `Missing` | Intended (spec, design, or domain) and absent |
| `Broken` | Present and fails at runtime or on build |
| `N/A` | Not applicable, with a product reason the user confirms |

| Evidence | Meaning |
|---|---|
| `R` | Proven at runtime: App MCP post-state, a test run, a device session, a trace line |
| `C` | Read in code; not executed |
| `I` | Inferred from structure or convention |
| `X` | Not checked, with the reason |

`Complete + C` prints as **Complete (unproven)**. On a critical workflow it counts as `X` for
the verdict.

## Severity

- **Blocker**: a critical workflow `Missing` / `Broken` / `Simulated`; any Security finding
  involving a shipped secret or plaintext credential; a supported head that fails to build or
  crashes on launch; UI that impersonates a capability the app lacks.
- **Major**: any other `Missing` / `Broken` / `Simulated`; a `Complete` with `X` on a supported
  head; a data-bearing screen with an unhandled Empty or Error; an `N/A` without a product reason.
- **Minor**: `Partial`; unproven `C` off the critical path; visual residue; missing automation
  names on secondary controls.

## Verdict

- **Complete**: 0 Blockers, 0 Majors, every critical workflow `R` on every supported head.
- **Complete with gaps**: 0 Blockers.
- **Incomplete**: any Blocker.

Never adjust the verdict for a deadline. Add a "Safe to show" line instead.

---

## Template

```markdown
# Completeness audit: <app> (<date>, <Uno.Sdk version>, heads: <list>)

Verdict: <Complete | Complete with gaps | Incomplete>
Safe to show: <workflows that are R on the demo head> / Keep off screen: <the rest>

## Inventory

Screens: <n> intended, <n> present, <n> unreachable, <n> missing   (source: spec | derived)
Routes: <n> registered, <n> triggers, <n> dead references
Interactions: <n> found, <n> dead by construction, <n> simulated
Critical workflows: <list, numbered>

## Completeness by area

| # | Area | Status | Evidence | Blockers | Majors | Minors | Note |
|---|---|---|---|---|---|---|---|
| 1 | Screens | | | | | | |
| 2 | Navigation | | | | | | |
| 3 | Interactions | | | | | | |
| 4 | Logic | | | | | | |
| 5 | Data | | | | | | |
| 6 | States | | | | | | |
| 7 | Forms | | | | | | |
| 8 | Authentication | | | | | | |
| 9 | Responsive/adaptive UI | | | | | | |
| 10 | Platform behavior | | | | | | |
| 11 | Failure handling | | | | | | |
| 12 | Accessibility | | | | | | |
| 13 | Performance | | | | | | |
| 14 | Security/privacy | | | | | | |
| 15 | Visual quality | | | | | | |
| 16 | Testing | | | | | | |

Area status is the worst status among its items; area evidence is the weakest grade on its
critical-path items.

## Critical workflows by head

| Workflow | desktop | android | ios | wasm |
|---|---|---|---|---|
| 1. <name> | R (<proof>) | X (<reason>) | | |

## Findings

### Blockers
- [<area>] <what is wrong> - <file:line or element> - evidence <R/C> - <proof or symptom> - owner: <skill>

### Majors
- ...

### Minors
- ...

## Not checked (X)
- <item> - <reason> - <how to check it>

## Noted for other passes
- uno-audit: <one line>
- Design pass: <one line>

## Unresolved Questions
- Every N/A and its stated product reason, for confirmation
- Every derived inventory item (screens or workflows the spec did not name)
- Every X on a supported head
```

---

## Worked example (abridged)

```markdown
# Completeness audit: SampleCrm (2026-09-20, Uno.Sdk 6.6.42, heads: desktop, android)

Verdict: Incomplete
Safe to show: Accounts list, Account detail, Create account, Deals list / Keep off screen: Deals export, any error recovery

## Inventory

Screens: 11 intended, 9 present, 1 unreachable (SettingsPage: no RouteMap), 1 missing (Session expired)   (source: SPEC.md)
Routes: 14 registered, 19 triggers, 1 dead reference ("Reports" in NavigationView, no ViewMap)
Interactions: 63 found, 2 dead by construction, 3 simulated
Critical workflows: 1 sign in, 2 create account, 3 edit account, 4 list > detail > back, 5 export deals, 6 delete deal

## Completeness by area

| # | Area | Status | Evidence | Blockers | Majors | Minors | Note |
|---|---|---|---|---|---|---|---|
| 1 | Screens | Partial | R | 0 | 2 | 0 | Settings unreachable; Session expired missing |
| 3 | Interactions | Simulated | R | 1 | 1 | 0 | Export shows a toast, writes nothing |
| 5 | Data | Complete | R | 0 | 0 | 1 | Android persistence X |
| 6 | States | Broken | R | 1 | 0 | 2 | Accounts Retry is a dead binding |
| 16 | Testing | Partial | R | 0 | 1 | 0 | android column empty |
| … | | | | | | | |

## Critical workflows by head

| Workflow | desktop | android |
|---|---|---|
| 2. create account | R (AccountsPage list count 8 > 9; store file grew) | X (no device attached) |
| 5. export deals | Broken (toast shown, no file in Documents) | X |

## Findings

### Blockers
- [Interactions] Export writes nothing - `DealsPage.xaml:88` `ExportCommand` - R - handler shows InfoBar only, no file after invoke - owner: Uno Platform Studio `uno-mvux-*`
- [States] Accounts Retry dead - `AccountsPage.xaml:41` `{Binding Refresh}` in ErrorTemplate - R - DataContext is InvalidOperationException, service trace count unchanged after invoke - owner: uno-component-states

### Majors
- [Screens] SettingsPage has no route - `App.xaml.cs:62` RouteMap - C - owner: Uno Platform Studio `uno-navigation-*`
- [Screens] No session-expired screen; 401 renders generic error - `AuthHandler.cs:30` - R - owner: Uno docs MCP (Uno Extensions authentication)
- [Testing] Android never run - X - attach a device and re-run workflows 1-6

## Unresolved Questions
- Authentication marked N/A for "offline demo"? SPEC.md section 3 says MSAL. Confirm which.
- Workflow 6 (delete deal) was derived from the domain; the spec does not name it.
- Android is a supported head with zero R; is it in scope for Thursday?
```
