[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidatePattern('^[0-9]+$')][string]$RunId
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
$gitRoot = [IO.Path]::GetFullPath((& git -C $publicRoot rev-parse --show-toplevel 2>&1 | Out-String).Trim())
if ($LASTEXITCODE -ne 0 -or $gitRoot -ne $publicRoot) { throw 'Unexpected Git root for the NativeSim mirror.' }
$origin = (& git -C $publicRoot remote get-url origin 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $origin -notmatch '(?i)(?:github\.com[:/])LuanRigatti/Starter-NativeSim-Public(?:\.git)?$') {
  throw 'The public mirror origin does not match LuanRigatti/Starter-NativeSim-Public.'
}
$apiJson = & gh api "repos/$repo/actions/runs/$RunId" 2>&1
if ($LASTEXITCODE -ne 0) { throw "Could not read NativeSim run $RunId : $apiJson" }
$run = $apiJson | ConvertFrom-Json
if ($run.path -ne '.github/workflows/native-sim.yml' -or $run.head_branch -ne 'main' -or $run.status -ne 'completed' -or $run.conclusion -ne 'success') {
  throw "Run $RunId is not a successful completed Starter NativeSim run on main."
}
$liveMain = (& git -C $publicRoot ls-remote origin refs/heads/main 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $liveMain) { throw 'Could not resolve the live public main SHA.' }
$liveSha = $liveMain.Split()[0]
if ($run.head_sha -ne $liveSha) {
  throw "Run SHA $($run.head_sha) is not the current public main SHA $liveSha; refusing an outdated artifact."
}

$viewJson = & gh run view $RunId --repo $repo --json displayTitle 2>&1
if ($LASTEXITCODE -ne 0) { throw "Could not read the NativeSim run title for artifact identity: $viewJson" }
$displayTitle = ($viewJson | ConvertFrom-Json).displayTitle
if ($displayTitle -notmatch '^native-sim (?<session>[a-f0-9]{8})\s+') {
  throw "NativeSim run title does not contain the expected 8-character session ID: $displayTitle"
}
$session = $Matches.session

$artifactName = "native-sim-app-$Session"
$artifactRoot = [IO.Path]::GetFullPath((Join-Path $publicRoot "artifacts\$RunId"))
if (-not $artifactRoot.StartsWith($publicRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
  throw 'Resolved artifact directory is outside Starter-NativeSim-Public.'
}
New-Item -ItemType Directory -Force -Path $artifactRoot | Out-Null
& gh run download $RunId --repo $repo --name $artifactName --dir $artifactRoot
if ($LASTEXITCODE -ne 0) { throw "GitHub CLI could not download artifact '$artifactName' from run $RunId." }
$archives = @(Get-ChildItem -LiteralPath $artifactRoot -Filter '*.app.tar.gz' -File -Recurse)
if ($archives.Count -ne 1) { throw "Expected one .app.tar.gz in $artifactRoot; found $($archives.Count)." }
$tarEntries = & tar -tzf $archives[0].FullName 2>&1
if ($LASTEXITCODE -ne 0 -or -not ($tarEntries | Where-Object { $_ -match '\.app/' })) {
  throw "Downloaded archive is not a readable iOS Simulator .app tar.gz: $($archives[0].FullName)"
}
Write-Output "Verified Simulator archive: $($archives[0].FullName)"
Write-Output "Run: $RunId | Commit: $($run.head_sha) | Artifact: $artifactName"
