<#
.SYNOPSIS
    Stop hook: in an Uno Platform repo, a "done / shippable / ready to demo" claim needs a current completeness report.

    Fires only when all hold: the session cwd is inside a git repo whose global.json pins Uno.Sdk; the last
    assistant message makes an unnegated readiness claim; and docs/COMPLETENESS.md is missing or older than the
    last commit touching non-doc files. Then it blocks the stop once with a reason (run uno-completeness-audit, or
    restate the claim at its real evidence level). stop_hook_active prevents a loop. Never blocks otherwise.
#>
$ErrorActionPreference = 'SilentlyContinue'

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
$hook = $raw | ConvertFrom-Json
if ($hook.stop_hook_active) { exit 0 }

$cwd = if ($hook.cwd) { [string]$hook.cwd } else { (Get-Location).Path }
$repo = git -C $cwd rev-parse --show-toplevel 2>$null
if (-not $repo) { exit 0 }
$globalJson = Join-Path $repo 'global.json'
if (-not ((Test-Path $globalJson) -and ((Get-Content $globalJson -Raw) -match 'Uno\.Sdk'))) { exit 0 }

# Last assistant text: prefer the field when the host provides it, else read the transcript tail.
$text = [string]$hook.last_assistant_message
if (-not $text -and $hook.transcript_path -and (Test-Path $hook.transcript_path)) {
    foreach ($line in (Get-Content $hook.transcript_path -Tail 60)[-1..-60]) {
        $entry = $line | ConvertFrom-Json
        if ($entry.type -ne 'assistant') { continue }
        $parts = @($entry.message.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text })
        if ($parts.Count) { $text = $parts -join "`n"; break }
    }
}
if (-not $text) { exit 0 }

$claim = '(?i)\b(shippable|ready to (ship|demo|release)|ready for (release|production|the demo|a demo)|release[- ]ready|production[- ]ready|(the app|the build|it) is (complete|done|finished)|v\d+\.\d+(\.\d+)? (is )?(released|shipped|ready))\b'
$hit = $null
foreach ($m in [regex]::Matches($text, $claim)) {
    $before = $text.Substring([Math]::Max(0, $m.Index - 12), [Math]::Min(12, $m.Index))
    if ($before -notmatch "(?i)(\bnot|n't|\bno|\bnever|\byet)\s+(\w+\s+)?$") { $hit = $m.Value; break }
}
if (-not $hit) { exit 0 }

$report = Join-Path $repo 'docs/COMPLETENESS.md'
$lastSource = [long](git -C $repo log -1 --format=%ct -- . ':(exclude)docs' ':(exclude)*.md' 2>$null)
if (Test-Path $report) {
    $reportTime = [DateTimeOffset]::new((Get-Item $report).LastWriteTimeUtc).ToUnixTimeSeconds()
    if ($reportTime -ge $lastSource) { exit 0 }
    $state = 'docs/COMPLETENESS.md is older than the last source commit'
} else {
    $state = 'docs/COMPLETENESS.md does not exist'
}

@{
    decision = 'block'
    reason   = ("uno-done-guard: the last message claims `"$hit`" for an Uno Platform repo ($repo), but $state. " +
                "Either run the uno-completeness-audit skill and save its report to docs/COMPLETENESS.md, then restate " +
                "the verdict it reaches; or rewrite the claim at its real evidence level (what was built, which heads " +
                "were run, that completeness was not audited). (uno-scaffolding skill: references/uno-scaffolding.md, Build gates)")
} | ConvertTo-Json -Compress
exit 0
