# Uno Platform trust workflow for Claude Code

The rules, skills and hooks I use to build Uno Platform apps with an AI agent and still trust the code.

## TL;DR

- Nine Claude Code skills plus two optional hooks, packaged as one plugin.
- They cover the path from spec to "done": define behavior, design states, try to break it, audit it, gate the build, verify it in the running app, prove completeness, measure performance, and hand off the session.
- Install with two commands (below). The hooks are opt-in and need a manual `settings.json` entry.
- They sit on top of Uno Platform's own skills, which install separately as the [`uno-platform-studio` plugin](https://platform.uno/docs/articles/external/studio-docs/Agent/uno-platform-studio-skills.html).

> **This is a personal workflow.** It encodes the mistakes I kept making on my own projects, on my machine (Windows 11, PowerShell 7, .NET 10, the Uno Platform App MCP). It works for me. It may or may not work for you. Treat it as a starting point: keep the checks your own mistakes call for and drop the rest.

## The matrix

| Quality question | Skill or hook | What it does |
|---|---|---|
| Do we know what the feature should do? | `uno-write-spec` | Spec before code: behavior, failure cases, decisions with tradeoffs, unresolved questions |
| Have we accounted for loading and failure? | `uno-component-states` | Loading, empty, error and recovery states for each surface |
| What failures have we missed? | `uno-break-it` | A separate QA agent works an attack catalog in the running app, including a 20x navigation memory loop; each finding gets a severity and a screenshot |
| Does the code follow project conventions? | `xaml-semantic-lint` hook (ships with `uno-audit`) | Flags hand-drawn cards, code-behind handlers, hard-coded colors, platform branches in models and blocking waits after every edit, with a suggested fix |
| Can someone understand and change it? | `uno-audit` | Comment cleanup, structure, stack currency, and a change-cost probe that grades likely changes as Contained, Scattered or Unguarded |
| What checks must pass? | `uno-scaffolding` | Build gates by scope of change, the workaround protocol, scaffolding conventions and measured runtime gotchas |
| Does the workflow work in the app? | `uno-verify` | Debug launch through the Uno Platform App MCP, control interactions, visual tree and state checks |
| Is there evidence behind "done"? | `uno-completeness-audit` + `uno-done-guard` hook | Evidence-graded audit saved to `docs/COMPLETENESS.md`; the hook blocks a "done" claim without a current report |
| Did the performance change help? | `uno-hill-climb` | One metric, one change at a time, kept only if the number improves and screenshots stay within tolerance |
| Will the next session know where we are? | `handoff` | Writes `HANDOFF.md` with state, evidence and next actions |

## Requirements

- Claude Code
- .NET 10 SDK and an Uno Platform app (Uno.Sdk 6.7 or later)
- PowerShell 7 (`pwsh`) for the lint and the hooks
- The Uno Platform App MCP (`uno-app`) for runtime verification, and the Uno Platform docs MCP for documentation lookups

## Install

```bash
claude plugin marketplace add mtmattei/claude-uno-plugins
claude plugin install uno@mtmattei
```

Skills appear namespaced, for example `/uno:uno-verify`.

## Optional hooks

Two hooks enforce what the skills describe. They are not enabled by the plugin. Clone this repo, then add the entries below to your user or project `.claude/settings.json`, replacing `<repo>` with the clone's absolute path.

- **`xaml-semantic-lint`** runs after each edit to a `.xaml` or `.cs` file and reports convention hits back to the agent.
- **`uno-done-guard`** runs when the agent stops. In a repo whose `global.json` pins Uno.Sdk, it blocks a "done / shippable / ready to demo" claim once when `docs/COMPLETENESS.md` is missing or older than the last source commit.

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -NonInteractive -File \"<repo>/plugins/uno/skills/uno-audit/scripts/xaml-semantic-lint.ps1\" -Hook",
            "timeout": 20
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -NonInteractive -File \"<repo>/hooks/uno-done-guard.ps1\"",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

You can also run the lint by hand:

```powershell
pwsh -File plugins/uno/skills/uno-audit/scripts/xaml-semantic-lint.ps1 -Path <your-app>
```

## Layout

```
.claude-plugin/marketplace.json        marketplace manifest
plugins/uno/.claude-plugin/plugin.json plugin manifest
plugins/uno/skills/<name>/SKILL.md     one folder per skill
plugins/uno/skills/uno-scaffolding/references/   shared rules the other skills read
hooks/uno-done-guard.ps1               opt-in Stop hook
```

Skills refer to each other's files with paths relative to `plugins/uno/skills/`, for example `uno-scaffolding/references/uno-runtime-gotchas.md`.

## License

MIT
