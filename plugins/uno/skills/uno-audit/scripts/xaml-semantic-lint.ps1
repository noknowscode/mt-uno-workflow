<#
.SYNOPSIS
  Semantic-first lint for Uno Platform projects: XAML and page code-behind.

.DESCRIPTION
  Gating rules (any hit = exit 1):
    CARD        <Border> with CornerRadius plus Background, BorderBrush or Padding.
                -> utu:CardContentControl + lightweight keys.
    HEX         Hex colour literal in XAML outside a palette/token file.
                -> theme role brush (shared Uno.Themes keys, same under Material and
                   Simple), or a token in a palette file.
    TOKENTHEME  App-defined *Brush key outside ThemeDictionaries with no invariant
                marker, in any XAML except ColorPaletteOverride*. It will not follow
                light/dark. -> theme role, or define it per theme, or name it
                *Invariant/*OnDark/*OnLight/*Fixed when its ground is fixed.
    BACKBAR     Navigation.Request="-" in a XAML file with no NavigationBar.
                -> utu:NavigationBar with a MainCommand AppBarButton.
    CODEBEHIND  Event handler (object sender, ...) or .Visibility assignment in
                page/control code-behind (*.xaml.cs).
                -> utu:CommandExtensions, model commands, VisualStateManagerExtensions,
                   nested Visibility regions.
    OVERLAY     Code-behind toggling Visibility of an element named *Overlay, *Sheet,
                *Scrim, *Drawer, *Popup or *Panel.
                -> uen:Navigation.Request="!Route" to a Page (opens as a flyout),
                   DrawerFlyoutPresenter styles for sheets and side drawers.
    RESPONSIVE  Size comparison in code-behind (NewSize.Width >= x, ActualWidth < x).
                -> {utu:Responsive} for every width-dependent value; never code-behind or view-model width flags.
    BUILTIN     Custom control whose name matches a platform/Toolkit control
                (StarRating -> RatingControl, MacroBar -> ProgressBar, *Card -> CardContentControl).
    ICON        Icon geometry outside an Icons*.xaml file: inline Path/PathIcon Data
                mini-language, an inline PathGeometry/GeometryGroup, or basic shapes
                (Ellipse, Rectangle, Line, Polyline, Polygon) composed inside a Viewbox.
                -> SymbolIcon/FontIcon, or keyed path data from one open icon set in
                   Icons.xaml used via PathIcon Data="{StaticResource ...}".
                ControlTemplates are skipped (template parts, counted as TEMPLATE info).
    PLATFORMLEAK  Platform branch (#if __ANDROID__/__IOS__/__WASM__/HAS_UNO*/WINDOWS,
                OperatingSystem.Is*(), RuntimeInformation.IsOSPlatform) in a *Model.cs or
                *ViewModel.cs. -> a platform service behind an interface, or a Platforms/
                partial; the model stays platform-neutral.
    SYNCWAIT    Blocking wait on a task in app code: .Wait(), .GetAwaiter().GetResult(),
                SomethingAsync(...).Result, task.Result. -> await it; blocking the UI
                thread freezes the app and can deadlock. Test projects are skipped.
  Info (reported, never gating):
    XBINDMODE   {x:Bind a.b} with no Mode outside a DataTemplate. x:Bind defaults to
                OneTime, so a value that changes later never shows. Event and Command
                attributes, DataContext and CommandParameter are skipped. Getter-only
                computed properties are OneTime by design, so this stays info. -> Mode=OneWay, or a comment that OneTime is meant.
    TOKEN       References to app-defined *Brush keys (each skipped the role ladder).
    ADAPTIVE    AdaptiveTrigger vs {utu:Responsive} counts.
    TEMPLATE    App-authored ControlTemplates (Borders inside them are not CARD hits).

  Dev/harness files (a Dev, Harness, Probe or Tests path segment, or *Harness*/*Probe* in
  the name) are skipped unless -IncludeDev.

  Suppress one deliberate hit with a comment within the 3 lines above it, reason required:
    <!-- xaml-lint: allow card - image clip with a placeholder fill -->
    // xaml-lint: allow codebehind - video transport glue, no Toolkit equivalent
  Rule names in suppressions are lowercase: card, hex, tokentheme, backbar, codebehind,
  overlay, responsive, builtin, icon, platformleak, syncwait, xbindmode.

.EXAMPLE
  xaml-semantic-lint.ps1 -Path C:\src\MyUnoApp
  xaml-semantic-lint.ps1 -Path . -Json
  <hook JSON on stdin> | xaml-semantic-lint.ps1 -Hook

.NOTES
  Exit code (Path mode): 0 = clean, 1 = gating findings, 2 = bad input.
  Hook mode always exits 0 and reports only findings inside the text the edit added.
#>
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(ParameterSetName = 'Path', Position = 0)]
    [string] $Path = '.',
    [Parameter(ParameterSetName = 'Path')]
    [switch] $Json,
    [Parameter(ParameterSetName = 'Path')]
    [int] $Top = 12,
    [Parameter(ParameterSetName = 'Path')]
    [switch] $IncludeDev,
    [Parameter(ParameterSetName = 'Hook')]
    [switch] $Hook
)

$ErrorActionPreference = 'Stop'

$Gating      = 'CARD', 'HEX', 'TOKENTHEME', 'BACKBAR', 'CODEBEHIND', 'OVERLAY', 'RESPONSIVE', 'BUILTIN', 'ICON', 'PLATFORMLEAK', 'SYNCWAIT'
$InfoRules   = 'XBINDMODE'
$PaletteName = '(?i)(palette|colou?rs?|tokens?)[^\\/]*\.xaml$'
$IconName    = '(?i)icons?[^\\/]*\.xaml$'
$InlineDataRx = [regex]::new('<(Path|PathIcon)\b[^>]*?\bData\s*=\s*"\s*(?:F[01]\s*)?[Mm]', 'Singleline')
$GeometryRx   = [regex]::new('<(PathGeometry|GeometryGroup)\b')
$ViewboxRx    = [regex]::new('<Viewbox\b.*?</Viewbox>', 'Singleline')
$ShapeRx      = [regex]::new('<(Ellipse|Rectangle|Line|Polyline|Polygon)\b')
# Theme palette override files (Material ColorPaletteOverride, Simple ColorOverrideDictionary files).
$MaterialPal = '(?i)Colou?r(Palette)?Override[^\\/]*\.xaml$'
$DevPath     = '(?i)[\\/](Dev|Harness|Probes?|Tests?)[\\/]|Harness|Probe'
$BorderRx    = [regex]::new('<Border\b[^>]*>', 'Singleline')
$HexRx       = [regex]::new('(?:=\s*"|>)\s*(#(?:[0-9A-Fa-f]{8}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{3,4}))\s*(?:"|<)')
$BrushKeyRx  = [regex]::new('x:Key\s*=\s*"([A-Za-z0-9_.]+Brush)"')
$TemplateRx  = [regex]::new('<ControlTemplate\b.*?</ControlTemplate>', 'Singleline')
$ShadowRx    = [regex]::new('<utu:ShadowContainer\b.*?</utu:ShadowContainer>', 'Singleline')
$ThemeDictRx = [regex]::new('<ResourceDictionary\.ThemeDictionaries>.*?</ResourceDictionary\.ThemeDictionaries>', 'Singleline')
$BackRx      = [regex]::new('Navigation\.Request\s*=\s*"-"')
$HandlerRx   = [regex]::new('void\s+(\w+)\s*\(\s*object\??\s+sender\s*,')
$VisRx       = [regex]::new('\b(\w+)\s*\.\s*Visibility\s*=')
$SizeRx      = [regex]::new('\b(NewSize\.(?:Width|Height)|ActualWidth|ActualHeight|Bounds\.(?:Width|Height))\s*(<=|>=|<|>)')
$ClassRx     = [regex]::new('class\s+(\w+)\s*:\s*(?:[\w.]+\.)?(Control|ContentControl|UserControl|Panel|Button|ToggleButton|FrameworkElement|Grid|StackPanel|Canvas|Border|ItemsControl|SKCanvasElement)\b')
$OverlayName = '(?i)(overlay|sheet|scrim|drawer|popup|panel)$'
$InvariantKey = '(?i)invariant|ondark|onlight|fixed'
$XBindRx     = [regex]::new('(\w+)\s*=\s*"\{x:Bind\s+([\w.]+\.[\w.]+)\s*(,[^}]*)?\}"')
$XBindSkip   = '(?i)^(Click|Tapped|DoubleTapped|Loaded|Unloaded|Toggled|ItemClick|\w*Changed|\w*Pressed|\w*Released|\w*Requested|\w*Invoked|\w*Command|CommandParameter|DataContext)$'
$DataTplRx   = [regex]::new('<DataTemplateb.*?</DataTemplate>', 'Singleline')
$ModelName   = '(?i)(View)?Model\.cs$'
$PlatIfRx    = [regex]::new('(?m)^\s*#(?:el)?if\b.*\b(__[A-Z]+__|HAS_UNO\w*|WINDOWS|WINAPPSDK)\b')
$PlatApiRx   = [regex]::new('b(OperatingSystem\.Is\w+|RuntimeInformation\.IsOSPlatform)\s*\(')
$TestFile    = '(?i)\.Tests?[\\/]|Tests?\.cs$'
$SyncWaitRx  = [regex]::new('\.Wait\(\s*\)|\.GetAwaiter\(\)\s*\.GetResult\(\)|Async\([^;{}]*?\)\s*\.Result\b|\b\w*[Tt]ask\.Result\b')

# Name pattern -> (suggested control, token whose presence in the companion XAML means it is already used)
$BuiltinMap = @(
    @('(?i)rating|stars?$',                     'RatingControl',                                   'RatingControl'),
    @('(?i)progress|meter|gauge|macro\w*bar',   'ProgressBar (lightweight keys)',                  'ProgressBar'),
    @('(?i)tabbar|tabs$|segment',               'utu:TabBar (SegmentedStyle / TopTabBarStyle)',    'TabBar'),
    @('(?i)(nav|app|top|title|header)bar',      'utu:NavigationBar',                               'NavigationBar'),
    @('(?i)card',                               'utu:CardContentControl + lightweight keys',       'CardContentControl'),
    @('(?i)chip',                               'utu:Chip / utu:ChipGroup',                        'Chip'),
    @('(?i)drawer|sheet',                       'Flyout + DrawerFlyoutPresenter style via a ! route', 'Flyout'),
    @('(?i)pips|dots|pager',                    'PipsPager / utu:SelectorExtensions.PipsPager',    'Pips'),
    @('(?i)toggle|switch',                      'ToggleSwitch / ToggleButton',                     'Toggle'),
    @('(?i)spinner|loader|busy',                'ProgressRing / utu:LoadingView',                  'Progress'),
    @('(?i)bar$',                               'ProgressBar or utu:NavigationBar',                'Bar')
)

function New-Finding($rule, $text, $index, $detail) {
    [pscustomobject]@{ Rule = $rule; Index = $index; Line = ([regex]::Matches($text.Substring(0, $index), "`n")).Count + 1; Detail = $detail }
}

function Test-Suppressed([string] $text, [int] $index, [string] $rule) {
    $lineStart = $text.LastIndexOf("`n", [Math]::Max(0, $index - 1)) + 1
    $before = $text.Substring(0, $lineStart) -split "`n" | Where-Object { $_.Trim() } | Select-Object -Last 3
    ($before -join "`n") -match ("xaml-lint:\s*allow\s+{0}\s*-\s*\S" -f $rule)
}

function Get-XamlIssues([string] $text, [string] $name) {
    $out = [System.Collections.Generic.List[object]]::new()
    # Borders inside a ControlTemplate are template parts; re-templating is counted as TEMPLATE info.
    $templates = @($TemplateRx.Matches($text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
    # A Border inside a ShadowContainer with no Background only shapes the shadow (Toolkit rule:
    # Background belongs on the container), so it is not a card.
    $shadows = @($ShadowRx.Matches($text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
    foreach ($m in $BorderRx.Matches($text)) {
        $tag = $m.Value
        if ($tag -notmatch '\bCornerRadius\s*=' -or $tag -notmatch '\b(Background|BorderBrush|Padding)\s*=') { continue }
        if ($templates | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] }) { continue }
        if ($tag -notmatch '\bBackground\s*=' -and ($shadows | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] })) { continue }
        if (Test-Suppressed $text $m.Index 'card') { continue }
        $n = if ($tag -match 'x:Name\s*=\s*"([^"]+)"') { " x:Name=`"$($Matches[1])`"" } else { '' }
        $out.Add((New-Finding 'CARD' $text $m.Index "<Border$n> drawn as a card"))
    }
    if ($name -notmatch $PaletteName) {
        foreach ($m in $HexRx.Matches($text)) {
            if (Test-Suppressed $text $m.Index 'hex') { continue }
            $out.Add((New-Finding 'HEX' $text $m.Index "literal $($m.Groups[1].Value)"))
        }
    }
    if ($name -notmatch $MaterialPal) {
        $spans = @($ThemeDictRx.Matches($text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
        foreach ($m in $BrushKeyRx.Matches($text)) {
            $key = $m.Groups[1].Value
            if ($key -match $InvariantKey) { continue }
            if ($spans | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] }) { continue }
            if (Test-Suppressed $text $m.Index 'tokentheme') { continue }
            $out.Add((New-Finding 'TOKENTHEME' $text $m.Index "$key has one value for both themes"))
        }
    }
    if ($text -notmatch 'NavigationBar') {
        foreach ($m in $BackRx.Matches($text)) {
            if (Test-Suppressed $text $m.Index 'backbar') { continue }
            $out.Add((New-Finding 'BACKBAR' $text $m.Index 'hand-built back button; no NavigationBar on this page'))
        }
    }
    if ($name -notmatch $IconName) {
        $inTemplate = { param($i) $templates | Where-Object { $i -ge $_[0] -and $i -lt $_[1] } }
        foreach ($m in $InlineDataRx.Matches($text)) {
            if (& $inTemplate $m.Index) { continue }
            if (Test-Suppressed $text $m.Index 'icon') { continue }
            $out.Add((New-Finding 'ICON' $text $m.Index "inline <$($m.Groups[1].Value) Data> path geometry"))
        }
        foreach ($m in $GeometryRx.Matches($text)) {
            if (& $inTemplate $m.Index) { continue }
            if (Test-Suppressed $text $m.Index 'icon') { continue }
            $out.Add((New-Finding 'ICON' $text $m.Index "inline <$($m.Groups[1].Value)>"))
        }
        foreach ($m in $ViewboxRx.Matches($text)) {
            if (& $inTemplate $m.Index) { continue }
            $shapes = $ShapeRx.Matches($m.Value)
            if ($shapes.Count -eq 0) { continue }
            if (Test-Suppressed $text $m.Index 'icon') { continue }
            $kinds = ($shapes | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique) -join '/'
            $out.Add((New-Finding 'ICON' $text $m.Index "Viewbox composed of $($shapes.Count) shape(s) ($kinds)"))
        }
    }
    # Item templates usually bind immutable records, where OneTime is right.
    $dataTpls = @($DataTplRx.Matches($text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
    foreach ($m in $XBindRx.Matches($text)) {
        if ($m.Groups[1].Value -match $XBindSkip) { continue }
        if ($m.Groups[3].Value -match '\bMode\s*=') { continue }
        if ($dataTpls | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] }) { continue }
        if (Test-Suppressed $text $m.Index 'xbindmode') { continue }
        $out.Add((New-Finding 'XBINDMODE' $text $m.Index "$($m.Groups[1].Value)=`"{x:Bind $($m.Groups[2].Value)}`" is OneTime"))
    }
    $out
}

function Get-CsIssues([string] $text, [string] $name, [string] $companionXaml, [string] $fullPath) {
    $out = [System.Collections.Generic.List[object]]::new()
    if ($name -match '(?i)\.xaml\.cs$') {
        foreach ($m in $HandlerRx.Matches($text)) {
            if (Test-Suppressed $text $m.Index 'codebehind') { continue }
            $out.Add((New-Finding 'CODEBEHIND' $text $m.Index "handler $($m.Groups[1].Value)"))
        }
        foreach ($m in $VisRx.Matches($text)) {
            $target = $m.Groups[1].Value
            if ($target -match $OverlayName) {
                if (Test-Suppressed $text $m.Index 'overlay') { continue }
                $out.Add((New-Finding 'OVERLAY' $text $m.Index "$target.Visibility set in code-behind"))
            } else {
                if (Test-Suppressed $text $m.Index 'codebehind') { continue }
                $out.Add((New-Finding 'CODEBEHIND' $text $m.Index "$target.Visibility set in code-behind"))
            }
        }
        foreach ($m in $SizeRx.Matches($text)) {
            if (Test-Suppressed $text $m.Index 'responsive') { continue }
            $out.Add((New-Finding 'RESPONSIVE' $text $m.Index "breakpoint on $($m.Groups[1].Value) in code-behind"))
        }
    }
    if ($name -match $ModelName -and $name -notmatch '(?i)\.xaml\.cs$') {
        foreach ($m in @($PlatIfRx.Matches($text)) + @($PlatApiRx.Matches($text))) {
            if (Test-Suppressed $text $m.Index 'platformleak') { continue }
            $out.Add((New-Finding 'PLATFORMLEAK' $text $m.Index "platform branch on $($m.Groups[1].Value) in a model"))
        }
    }
    # Tests may block on purpose; dev-path skipping misses Foo.Tests\ project folders.
    $syncMatches = if ($fullPath -match $TestFile) { @() } else { $SyncWaitRx.Matches($text) }
    foreach ($m in $syncMatches) {
        if (Test-Suppressed $text $m.Index 'syncwait') { continue }
        $out.Add((New-Finding 'SYNCWAIT' $text $m.Index "blocking wait: $($m.Value.Trim())"))
    }
    foreach ($m in $ClassRx.Matches($text)) {
        $cls = $m.Groups[1].Value
        foreach ($entry in $BuiltinMap) {
            if ($cls -notmatch $entry[0]) { continue }
            if ($companionXaml -and $companionXaml -match [regex]::Escape($entry[2])) { break }
            if (-not (Test-Suppressed $text $m.Index 'builtin')) {
                $out.Add((New-Finding 'BUILTIN' $text $m.Index "$cls : $($m.Groups[2].Value) -> $($entry[1])"))
            }
            break
        }
    }
    $out
}

function Get-FileIssues([string] $file, [string] $text) {
    $leaf = Split-Path $file -Leaf
    if ($leaf -match '(?i)\.xaml$') { return Get-XamlIssues $text $leaf }
    if ($leaf -match '(?i)\.cs$') {
        $companion = if ($file -match '(?i)\.xaml\.cs$') { $file -replace '(?i)\.cs$', '' } else { $null }
        $cx = if ($companion -and (Test-Path $companion)) { Get-Content $companion -Raw } else { $null }
        return Get-CsIssues $text $leaf $cx $file
    }
    @()
}

# ---------------------------------------------------------------- hook mode
if ($Hook) {
    try {
        $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
        $file = $payload.tool_input.file_path
        if (-not $file -or $file -notmatch '(?i)\.(xaml|cs)$') { exit 0 }
        $added = if ($payload.tool_input.PSObject.Properties['new_string']) { $payload.tool_input.new_string } else { $payload.tool_input.content }
        if (-not $added) { exit 0 }

        # Lint the file as saved so context rules (ThemeDictionaries, NavigationBar, suppressions)
        # see the whole file, then keep only findings inside the added text.
        $full = if (Test-Path $file) { Get-Content $file -Raw } else { $null }
        $start = if ($full) { $full.IndexOf($added) } else { -1 }
        if ($start -ge 0) {
            $end = $start + $added.Length
            $issues = @(Get-FileIssues $file $full | Where-Object { $_.Index -ge $start -and $_.Index -lt $end })
        } else {
            $issues = @(Get-FileIssues $file $added)
        }
        if ($issues.Count -eq 0) { exit 0 }

        $leaf = Split-Path $file -Leaf
        $fix = @{
            CARD       = 'utu:CardContentControl (Filled/Outlined/ElevatedCardContentControlStyle) + lightweight keys (CardCornerRadius, CardPadding, <Variant>CardContentBackground/BorderBrush).'
            HEX        = 'a theme role brush (PrimaryBrush, SurfaceBrush, OnSurfaceVariantBrush, OutlineBrush...; shared Uno.Themes keys, valid under both SimpleTheme and Material) or a palette-file token. Brand colours go into the palette override: ColorPaletteOverride for Material, SimpleTheme.ColorOverrideDictionary or a seed colour for Simple.'
            TOKENTHEME = 'use a theme role brush; else define the key per theme in ThemeDictionaries; name it *Invariant/*OnDark/*OnLight/*Fixed only when its ground is fixed in both themes.'
            BACKBAR    = 'utu:NavigationBar with a MainCommand AppBarButton; back navigation and the Android back gesture come with it.'
            CODEBEHIND = 'utu:CommandExtensions.Command / model commands / utu:VisualStateManagerExtensions.States bound to state / nested Visibility region for tabs. See "Code-behind budget" in uno-scaffolding/references/uno-scaffolding.md.'
            OVERLAY    = 'uen:Navigation.Request="!Route" to a Page (opens as a flyout) with a DrawerFlyoutPresenter style; filter state lives in the model.'
            RESPONSIVE = 'breakpoints are always {utu:Responsive} in XAML (custom thresholds via a utu:ResponsiveLayout resource); never code-behind, never width flags on a view model. Split state from width instead of allowing it.'
            BUILTIN    = 'use the platform/Toolkit control named above with lightweight styling before writing a custom control; then Windows Community Toolkit 8.x.'
            PLATFORMLEAK = 'move the branch into a platform service (interface in shared code, implementation per head or in a Platforms/ partial) and inject it; models stay platform-neutral.'
            SYNCWAIT   = 'await the task. If the caller cannot be async (constructor, property), start the load from a command or MVUX feed instead of blocking.'
            XBINDMODE  = 'x:Bind is OneTime by default: add Mode=OneWay for values that change, or a comment saying OneTime is intended.'
            ICON       = 'SymbolIcon/FontIcon on the Fluent symbol font, or keyed path data from one open icon set (Material Symbols, Fluent System Icons) in Icons.xaml via PathIcon Data="{StaticResource ...}". Never hand-draw icons. Illustrations get "xaml-lint: allow icon - illustration".'
        }
        $rules = $issues | Select-Object -ExpandProperty Rule -Unique
        $context = @(
            "xaml-semantic-lint: this edit to $leaf added $($issues.Count) semantic-bypass pattern(s):"
            ($issues | ForEach-Object { "- $($_.Rule): $($_.Detail)" })
            ($rules | ForEach-Object { "$_ fix: $($fix[$_])" })
            'If a framework mechanism failed, follow the workaround protocol in uno-scaffolding/references/uno-scaffolding.md. A deliberate exception gets "xaml-lint: allow <rule> - reason" in a comment above it.'
        ) -join "`n"
        @{
            systemMessage      = "xaml-semantic-lint: $($issues.Count) hit(s) in $leaf ($($rules -join ', '))"
            hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = $context }
        } | ConvertTo-Json -Depth 4 -Compress
    } catch {
        # A lint must never break an edit.
    }
    exit 0
}

# ---------------------------------------------------------------- path mode
if (-not (Test-Path $Path)) { Write-Error "Path not found: $Path"; exit 2 }
$root = (Resolve-Path $Path).Path

$candidates = if ((Get-Item $root).PSIsContainer) {
    Get-ChildItem $root -Recurse -File -Include *.xaml, *.cs |
        Where-Object { $_.FullName -notmatch '\\(bin|obj|node_modules|\.git)\\' -and $_.Name -notmatch '(?i)\.g(\.i)?\.cs$' }
} else { Get-Item $root }
$skipped = @($candidates | Where-Object { -not $IncludeDev -and $_.FullName.Substring($root.Length) -match $DevPath })
$files   = @($candidates | Where-Object { $skipped -notcontains $_ })

$all = [System.Collections.Generic.List[object]]::new()
$xamlTexts = @{}
foreach ($f in $files) {
    $text = Get-Content $f.FullName -Raw
    if (-not $text) { continue }
    if ($f.Name -match '(?i)\.xaml$') { $xamlTexts[$f.FullName] = $text }
    foreach ($i in (Get-FileIssues $f.FullName $text)) {
        $i | Add-Member File ($f.FullName.Substring($root.Length).TrimStart('\'))
        $all.Add($i)
    }
}

# Info: TOKEN references and responsive mechanism mix.
$defined = [System.Collections.Generic.HashSet[string]]::new()
foreach ($t in $xamlTexts.Values) { foreach ($m in $BrushKeyRx.Matches($t)) { [void]$defined.Add($m.Groups[1].Value) } }
$tokenRefs = 0; $tokenKeys = @{}; $adaptive = 0; $responsive = 0; $retemplated = 0
foreach ($kv in $xamlTexts.GetEnumerator()) {
    $adaptive    += ([regex]::Matches($kv.Value, '<AdaptiveTrigger\b')).Count
    $retemplated += ([regex]::Matches($kv.Value, '<ControlTemplate\b')).Count
    $responsive += ([regex]::Matches($kv.Value, '\{utu:Responsive\b')).Count
    if ($kv.Key -match $PaletteName) { continue }
    foreach ($m in [regex]::Matches($kv.Value, '\{(?:ThemeResource|StaticResource)\s+([A-Za-z0-9_.]+Brush)\}')) {
        if ($defined.Contains($m.Groups[1].Value)) { $tokenRefs++; $tokenKeys[$m.Groups[1].Value] = 1 }
    }
}

$workarounds = 0
foreach ($f in $files) { $workarounds += @(Select-String -LiteralPath $f.FullName -Pattern 'WORKAROUND\(' -SimpleMatch:$false).Count }

$counts = [ordered]@{}
foreach ($r in $Gating) { $counts[$r] = @($all | Where-Object Rule -eq $r).Count }
$gatingTotal = ($counts.Values | Measure-Object -Sum).Sum

if ($Json) {
    [pscustomobject]@{
        root = $root; files = $files.Count; skippedDev = $skipped.Count
        counts = $counts; tokenRefs = $tokenRefs; tokenKeys = $tokenKeys.Count
        adaptiveTriggers = $adaptive; utuResponsive = $responsive; controlTemplates = $retemplated; workarounds = $workarounds
        findings = @($all | Select-Object Rule, File, Line, Detail)
    } | ConvertTo-Json -Depth 4
} else {
    $meaning = [ordered]@{
        CARD       = 'Border with CornerRadius + fill/stroke/padding -> CardContentControl'
        HEX        = 'hex literal outside a palette file -> theme role brush or token'
        TOKENTHEME = 'app brush with one value for both themes -> role, ThemeDictionaries, or *Invariant name'
        BACKBAR    = 'hand-built back button -> utu:NavigationBar'
        CODEBEHIND = 'event handler or Visibility toggle in code-behind -> commands, VSM extensions, regions'
        OVERLAY    = 'overlay/sheet toggled in code-behind -> "!Route" flyout'
        RESPONSIVE = 'breakpoint logic in code-behind -> utu:Responsive / VSM'
        BUILTIN    = 'custom control shadowing a platform/Toolkit control'
        ICON       = 'inline or shape-built icon geometry -> icon font or keyed set data in Icons.xaml'
        PLATFORMLEAK = 'platform branch in a model/view model -> platform service or Platforms/ partial'
        SYNCWAIT   = 'blocking .Wait()/.Result/GetResult() -> await'
    }
    "xaml-semantic-lint  $root  ($($files.Count) files, $($skipped.Count) dev/harness skipped)"
    ''
    'Rule          Count  Meaning'
    '------------  -----  -------'
    foreach ($r in $Gating) { '{0,-12}  {1,5}  {2}' -f $r, $counts[$r], $meaning[$r] }
    '{0,-12}  {1,5}  {2}' -f 'XBINDMODE', @($all | Where-Object Rule -eq 'XBINDMODE').Count, 'info: x:Bind with no Mode outside item templates (OneTime default)'
    '{0,-12}  {1,5}  {2}' -f 'TOKEN', $tokenRefs, "info: refs to $($tokenKeys.Count) app-defined brush keys"
    '{0,-12}  {1,5}  {2}' -f 'ADAPTIVE', $adaptive, "info: AdaptiveTrigger count (utu:Responsive: $responsive)"
    '{0,-12}  {1,5}  {2}' -f 'TEMPLATE', $retemplated, 'info: app ControlTemplates (each should say why lightweight styling or BasedOn could not do it)'
    '{0,-12}  {1,5}  {2}' -f 'WORKAROUND', $workarounds, 'info: WORKAROUND(...) markers (each needs a gotcha entry with a repro)'
    foreach ($r in @($Gating) + @($InfoRules)) {
        $hits = @($all | Where-Object Rule -eq $r)
        if ($hits.Count -eq 0) { continue }
        ''
        "$r (top $Top files):"
        $hits | Group-Object File | Sort-Object Count -Descending | Select-Object -First $Top | ForEach-Object {
            $sample = ($_.Group | Select-Object -First 3 | ForEach-Object { "L$($_.Line) $($_.Detail)" }) -join '; '
            '  {0,4}  {1}  {2}' -f $_.Count, $_.Name, $sample
        }
    }
}

if ($gatingTotal -gt 0) { exit 1 }
exit 0
