<#
	TypeCheck.ps1 - the project's static type check, without Studio (luau-lsp 1.70.1, 2026-11-13).

	Usage (from anywhere):   powershell -File tools\TypeCheck.ps1 [world|default]
	Prints a summary of the warnings by file; the full report is written next to this script's temp folder.

	WHY A JUNCTION. luau-lsp cannot open a path with Greek letters in it, and the project lives in a folder with Greek
	letters ("Έγγραφα"). The script links the project under an ASCII path in %TEMP% and runs from there.

	WHERE THINGS ARE. luau-lsp.exe is in %USERPROFILE%\.luau-lsp (downloaded from the project's GitHub release,
	https://github.com/JohnnyMorganz/luau-lsp/releases, MIT). The Roblox type definitions (globalTypes.d.luau, ~0.9 MB,
	from the luau-lsp repository) are fetched once into the same folder.

	WHAT TO EXPECT. A baseline of ~930 warnings on 2026-11-13, almost all strict-mode noise ("could be nil", "expected X got
	X?", a cast between unrelated types). None of the sites checked in the 0.46 code was a real bug. Use the NUMBER as a
	tripwire: a change that raises it deserves a look at the new lines. Not part of the game; not synced by Rojo.
#>
param([ValidateSet("world", "default")] [string]$Place = "world")

# (not "Stop": luau-lsp writes its [INFO] lines to stderr, which Windows PowerShell 5.1 would turn into an error)
$tool = Join-Path $env:USERPROFILE ".luau-lsp\luau-lsp.exe"
$defs = Join-Path $env:USERPROFILE ".luau-lsp\globalTypes.d.luau"
if (-not (Test-Path $tool)) { throw "luau-lsp is not installed at $tool (see the notes at the top of this script)" }
if (-not (Test-Path $defs)) {
	Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau" -OutFile $defs -UseBasicParsing
}

$project = Split-Path -Parent $PSScriptRoot
$link = Join-Path $env:TEMP "tlk_typecheck_repo"
if (-not (Test-Path $link)) { New-Item -ItemType Junction -Path $link -Target $project | Out-Null }
$map = Join-Path $env:TEMP "tlk_typecheck_sourcemap.json"
$report = Join-Path $env:TEMP "tlk_typecheck_report.txt"

Push-Location $link
try {
	& rojo sourcemap "$Place.project.json" -o $map | Out-Null
	$raw = & $tool analyze --sourcemap $map --defs "@roblox=$defs" --formatter plain scripts configs 2>&1
	$raw | ForEach-Object { "$_" } | Out-File $report -Encoding utf8
} finally {
	Pop-Location
}

$hits = Get-Content $report | Where-Object { $_ -match '\.luau \[' }
"{0} warnings ({1} place). Full report: {2}" -f $hits.Count, $Place, $report
$hits | ForEach-Object { if ($_ -match 'tlk_typecheck_repo\\(.+?\.luau) ') { $Matches[1] } } | Group-Object | Sort-Object Count -Descending | Select-Object -First 12 | ForEach-Object { "{0,5}  {1}" -f $_.Count, $_.Name }
