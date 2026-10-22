[CmdletBinding()]
param(
  [ValidateRange(1, 300)][int]$TimeoutMinutes = 120,
  [switch]$NoWait
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$publicRoot = [IO.Path]::GetFullPath('C:\Projetos\Starter-NativeSim-Public')
$expectedRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Starter-NativeSim-Public'))
if ($publicRoot -ne $expectedRoot -or -not (Test-Path -LiteralPath $publicRoot -PathType Container)) {
  throw 'Starter-NativeSim-Public is missing or resolves outside the authorized mirror folder.'
}
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 or newer is required.' }

$repo = 'LuanRigatti/Starter-NativeSim-Public'
$workflow = 'swift-preflight.yml'
$origin = (& git -C $publicRoot remote get-url origin 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $origin -notmatch '(?i)(?:github\.com[:/])LuanRigatti/Starter-NativeSim-Public(?:\.git)?$') {
  throw 'The public mirror origin does not match LuanRigatti/Starter-NativeSim-Public.'
}
$root = [IO.Path]::GetFullPath((& git -C $publicRoot rev-parse --show-toplevel 2>&1 | Out-String).Trim())
if ($LASTEXITCODE -ne 0 -or $root -ne $publicRoot) { throw 'Unexpected Git root for the NativeSim mirror.' }
$branch = (& git -C $publicRoot branch --show-current 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $branch -ne 'main') { throw "Public mirror must be on main; found '$branch'." }
$status = (& git -C $publicRoot status --porcelain=v1 --untracked-files=all 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $status) { throw 'Public mirror worktree must be clean before Swift Preflight.' }
$sha = (& git -C $publicRoot rev-parse HEAD 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $sha -notmatch '^[0-9a-f]{40}$') { throw 'Could not resolve the public mirror HEAD SHA.' }
$live = (& git -C $publicRoot ls-remote origin refs/heads/main 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $live -or $live.Split()[0] -ne $sha) {
  throw 'Public mirror main is not exactly synchronized with its GitHub remote.'
}
$visibility = (& gh repo view $repo --json visibility --jq .visibility 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $visibility.ToUpperInvariant() -ne 'PUBLIC') { throw 'Starter-NativeSim-Public must exist and be public.' }

function Get-PreflightRuns {
  $json = & gh run list --repo $repo --workflow $workflow --branch main --limit 100 --json databaseId,headSha,status,conclusion,url,createdAt,name 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Could not query Swift Preflight runs: $json" }
  return @($json | ConvertFrom-Json)
}

$startedAt = [DateTimeOffset]::UtcNow
$active = @(Get-PreflightRuns | Where-Object { $_.headSha -eq $sha -and $_.status -in @('queued','in_progress','waiting','requested') })
if ($active.Count -gt 1) { throw 'Multiple active Preflight runs target this exact SHA; refusing an ambiguous result.' }
if ($active.Count -eq 1) {
  $run = $active[0]
  Write-Output "Reusing active Swift Preflight run $($run.databaseId) for $sha."
} else {
  & gh workflow run $workflow --repo $repo --ref main
  if ($LASTEXITCODE -ne 0) { throw 'GitHub rejected Swift Preflight dispatch.' }
  $run = $null
  $discoverUntil = [DateTimeOffset]::UtcNow.AddMinutes(2)
  do {
    $matches = @(Get-PreflightRuns | Where-Object {
      $_.headSha -eq $sha -and [DateTimeOffset]::Parse($_.createdAt).ToUniversalTime() -ge $startedAt.AddSeconds(-2)
    })
    if ($matches.Count -gt 1) { throw 'Dispatch created multiple candidate runs; refusing an ambiguous result.' }
    if ($matches.Count -eq 1) { $run = $matches[0]; break }
    Start-Sleep -Seconds 5
  } while ([DateTimeOffset]::UtcNow -lt $discoverUntil)
  if (-not $run) { throw "No Swift Preflight run appeared for exact SHA $sha after dispatch." }
}

$runId = [string]$run.databaseId
if (-not $runId) { throw 'Swift Preflight run has no GitHub run ID.' }
$deadline = [DateTimeOffset]::UtcNow.AddMinutes($TimeoutMinutes)
do {
  $runJson = & gh run view $runId --repo $repo --json databaseId,headSha,headBranch,status,conclusion,url,event,name 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Could not read Swift Preflight run $runId : $runJson" }
  $current = $runJson | ConvertFrom-Json
  if ($current.headSha -ne $sha -or $current.headBranch -ne 'main' -or $current.event -ne 'workflow_dispatch') {
    throw "Swift Preflight identity mismatch for run $runId; expected main workflow_dispatch at $sha."
  }
  if ($current.status -eq 'completed') { break }
  if ($NoWait) {
    Write-Output "Swift Preflight run: $($current.url)"
    Write-Output "Run ID: $runId | SHA: $sha | Status: $($current.status)"
    exit 0
  }
  Write-Output "Swift Preflight $runId is $($current.status); waiting for $sha."
  Start-Sleep -Seconds 10
} while ([DateTimeOffset]::UtcNow -lt $deadline)

if ($current.status -ne 'completed') { throw "Swift Preflight run $runId did not complete within $TimeoutMinutes minutes: $($current.url)" }
if ($current.conclusion -ne 'success') { throw "Swift Preflight concluded '$($current.conclusion)' for $sha. Run: $($current.url)" }
Write-Output "Swift Preflight passed: $($current.url)"
Write-Output "Run ID: $runId | Branch: main | SHA: $sha | Conclusion: success"
