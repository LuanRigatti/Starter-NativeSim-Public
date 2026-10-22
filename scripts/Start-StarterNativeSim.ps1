[CmdletBinding()]
param(
  [ValidateRange(1, 350)][int]$Minutes = 30,
  [string]$Device = 'iPhone 17 Pro',
  [switch]$ExportArchive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 or newer is required.' }

$publicRoot = [IO.Path]::GetFullPath('C:\Projetos\Starter-NativeSim-Public')
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Starter-NativeSim-Public'))
if ($publicRoot -ne $expectedRoot -or -not (Test-Path -LiteralPath $publicRoot -PathType Container)) {
  throw 'Starter-NativeSim-Public is missing or resolves outside the authorized mirror folder.'
}
$repo = 'LuanRigatti/Starter-NativeSim-Public'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $publicRoot '..\Starter'))
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw 'The private Starter source folder is missing.' }

foreach ($path in @($publicRoot,$sourceRoot)) {
  $root = [IO.Path]::GetFullPath((& git -C $path rev-parse --show-toplevel 2>&1 | Out-String).Trim())
  if ($LASTEXITCODE -ne 0 -or $root -ne $path) { throw "Unexpected Git root: $root" }
  $status = (& git -C $path status --porcelain=v1 --untracked-files=all 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $status) { throw "Worktree must be clean: $path" }
}
$sourceBranch = (& git -C $sourceRoot branch --show-current 2>&1 | Out-String).Trim()
if ($sourceBranch -ne 'main') { throw "Private Starter source must be on main; found '$sourceBranch'." }
$sourceSha = (& git -C $sourceRoot rev-parse HEAD 2>&1 | Out-String).Trim()
$sourceRemote = (& git -C $sourceRoot ls-remote origin refs/heads/main 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $sourceRemote -or $sourceRemote.Split()[0] -ne $sourceSha) {
  throw 'Private Starter main is not exactly synchronized with GitHub.'
}
$sourceVisibility = (& gh repo view LuanRigatti/Starter --json visibility --jq .visibility 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $sourceVisibility.ToUpperInvariant() -ne 'PRIVATE') { throw 'LuanRigatti/Starter must be private.' }

$mirrorBranch = (& git -C $publicRoot branch --show-current 2>&1 | Out-String).Trim()
if ($mirrorBranch -ne 'main') { throw "Public mirror must be on main; found '$mirrorBranch'." }
$mirrorSha = (& git -C $publicRoot rev-parse HEAD 2>&1 | Out-String).Trim()
$mirrorRemote = (& git -C $publicRoot ls-remote origin refs/heads/main 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $mirrorRemote -or $mirrorRemote.Split()[0] -ne $mirrorSha) {
  throw 'Public mirror main is not exactly synchronized with GitHub.'
}
$mirrorVisibility = (& gh repo view $repo --json visibility --jq .visibility 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $mirrorVisibility.ToUpperInvariant() -ne 'PUBLIC') { throw 'Starter-NativeSim-Public must be public.' }
$provenance = Get-Content -LiteralPath (Join-Path $publicRoot '.nativesim-source') -Raw
if ($provenance -notmatch "(?m)^source_repository=LuanRigatti/Starter\r?$" -or
    $provenance -notmatch "(?m)^source_branch=main\r?$" -or
    $provenance -notmatch "(?m)^source_commit=$([regex]::Escape($sourceSha))\r?$") {
  throw 'Public mirror provenance does not identify the exact live private Starter commit.'
}
$latestMessage = (& git -C $publicRoot log -1 --format=%B 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $latestMessage -notmatch "(?m)^Source-Commit: $([regex]::Escape($sourceSha))\r?$") {
  throw 'Public mirror HEAD does not carry the exact private source commit trailer.'
}

$nativeSimCommand = Get-Command native-sim.ps1 -ErrorAction SilentlyContinue
if (-not $nativeSimCommand) { throw 'NativeSim CLI is not installed or native-sim.ps1 is not on PATH.' }
if (-not (Test-Path -LiteralPath (Join-Path $publicRoot '.github\workflows\native-sim.yml')) -or
    -not (Test-Path -LiteralPath (Join-Path $publicRoot '.github\native-sim\gate.cjs'))) {
  throw 'Starter NativeSim workflow or authentication gate is missing.'
}

$latestRunJson = & gh run list --repo $repo --workflow native-sim.yml --branch main --limit 100 --json databaseId,headSha,status,url,createdAt,name 2>&1
if ($LASTEXITCODE -ne 0) { throw "Could not inspect existing NativeSim sessions: $latestRunJson" }
$active = @($latestRunJson | ConvertFrom-Json | Where-Object { $_.headSha -eq $mirrorSha -and $_.status -in @('queued','in_progress','waiting','requested') })
if ($active.Count -gt 0) { throw "An active NativeSim session already targets public SHA ${mirrorSha}: $($active[0].url)" }

$preflight = Join-Path $PSScriptRoot 'Invoke-StarterSwiftPreflight.ps1'
& pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $preflight
if ($LASTEXITCODE -ne 0) { throw 'Exact-SHA Swift Preflight did not pass; NativeSim was not started.' }

$postPreflightSha = (& git -C $publicRoot rev-parse HEAD 2>&1 | Out-String).Trim()
$postPreflightRemote = (& git -C $publicRoot ls-remote origin refs/heads/main 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $postPreflightSha -ne $mirrorSha -or $postPreflightRemote.Split()[0] -ne $mirrorSha) {
  throw 'Public mirror changed during Preflight; NativeSim was not started.'
}
$postStatus = (& git -C $publicRoot status --porcelain=v1 --untracked-files=all 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $postStatus) { throw 'Public mirror became dirty during Preflight; NativeSim was not started.' }

$arguments = @('up','--public','--minutes',[string]$Minutes,'--device',$Device,'--scheme','Starter','--no-open')
if ($ExportArchive) {
  $artifactDirectory = Join-Path $publicRoot 'artifacts'
  New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null
  $arguments += @('--export','--out',$artifactDirectory)
}
Write-Output "Starting NativeSim for public mirror SHA $mirrorSha."
Push-Location $publicRoot
try {
  & $nativeSimCommand.Source @arguments
  if ($LASTEXITCODE -ne 0) { throw "NativeSim exited with code $LASTEXITCODE." }
} finally {
  Pop-Location
}
