param([string]$AndroidRoot = 'C:\Users\Selman\Documents\duttarim-app')
$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$targetRoot = (Resolve-Path $AndroidRoot).Path
if (-not (Test-Path (Join-Path $targetRoot 'android\app\build.gradle'))) { throw 'Android project not found.' }

foreach ($name in @('dutar-head.png', 'TamDuttar.png')) {
  Copy-Item -LiteralPath (Join-Path $sourceRoot "www\$name") -Destination (Join-Path $targetRoot "www\$name")
}
foreach ($name in @('layout-polish.css', 'tuner-visuals.css', 'artwork-alignment.js')) {
  Copy-Item -LiteralPath (Join-Path $sourceRoot "www\$name") -Destination (Join-Path $targetRoot "www\$name")
}
$htmlPath = Join-Path $targetRoot 'www\index.html'
$html = [IO.File]::ReadAllText($htmlPath).Replace('width="1130" height="1392"', 'width="1086" height="1448"').Replace('viewBox="0 0 1130 1392"', 'viewBox="0 0 1086 1448"')
$sourceHtml = [IO.File]::ReadAllText((Join-Path $sourceRoot 'www\index.html'))
$overlayPattern = '(?s)<svg class="string-light-overlay".*?</svg>'
$overlay = [regex]::Match($sourceHtml, $overlayPattern).Value
if (-not $overlay) { throw 'String overlay not found.' }
$html = [regex]::Replace($html, $overlayPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $overlay })
if (-not $html.Contains('src="artwork-alignment.js"')) {
  $html = $html.Replace('<script src="appearance.js"></script>', '<script src="appearance.js"></script><script src="artwork-alignment.js" defer></script>')
}
[IO.File]::WriteAllText($htmlPath, $html, [Text.UTF8Encoding]::new($false))

$splash = Join-Path $sourceRoot 'artwork\splash-card\splash-light.png'
foreach ($folder in @('drawable-nodpi', 'drawable-night-nodpi')) {
  Copy-Item -LiteralPath $splash -Destination (Join-Path $targetRoot "android\app\src\main\res\$folder\branded_splash.png")
}
$sharp = 'C:\Users\Selman\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\node_modules\sharp'
if (-not (Test-Path $sharp)) { throw 'Sharp image dependency not found.' }
$env:SHARP_MODULE = $sharp
$env:ANDROID_ROOT = $targetRoot
node (Join-Path $sourceRoot 'tools\export-app-icons.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Icon export failed.' }
node (Join-Path $sourceRoot 'tools\export-splash.cjs')
if ($LASTEXITCODE -ne 0) { throw 'Splash export failed.' }
Push-Location $targetRoot
try { npx --no-install cap copy android; if ($LASTEXITCODE -ne 0) { throw 'Capacitor copy failed.' } }
finally { Pop-Location }
