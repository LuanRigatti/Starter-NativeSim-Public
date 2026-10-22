[CmdletBinding()]
param([switch]$Publish)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$nl = [Environment]::NewLine
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 or newer is required.' }

$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$destinationRoot = [IO.Path]::GetFullPath((Join-Path $sourceRoot '..\Starter-NativeSim-Public'))
$expectedSource = [IO.Path]::GetFullPath('C:\Projetos\Starter')
$expectedDestination = [IO.Path]::GetFullPath('C:\Projetos\Starter-NativeSim-Public')
if ($sourceRoot -ne $expectedSource -or $destinationRoot -ne $expectedDestination) {
  throw 'Resolved paths are outside the two authorized Starter folders.'
}
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container) -or
    -not (Test-Path -LiteralPath $destinationRoot -PathType Container)) {
  throw 'Both Starter and Starter-NativeSim-Public folders must already exist.'
}

$allowedFiles = @(
  'README.md','AI_CONTEXT.md','AGENTS.md','.gitignore','.nativesim-source',
  'app.config.js','babel.config.js','eas.json','eslint.config.js','expo-env.d.ts',
  'index.ts','jest.config.js','metro.config.js','package.json','package-lock.json','tsconfig.json',
  'plugins/withStarterToolbarSync.js',
  'scripts/patch-expo-ui-bottom-sheet.js','scripts/verify-starter-native.js',
  'scripts/create-provisional-icon.ps1',
  'scripts/mirror-starter.ps1','scripts/Invoke-StarterSwiftPreflight.ps1',
  'scripts/Start-StarterNativeSim.ps1','scripts/Download-StarterSimulatorArchive.ps1',
  '.github/workflows/native-sim.yml','.github/workflows/swift-preflight.yml',
  '.github/workflows/eas-build.yml','.github/native-sim/gate.cjs'
)
$allowedDirectories = @('assets','src','docs','.agents/skills','tests')
$blockedNamePattern = '(?i)(^|/)\.env($|\.)|(^|/)(node_modules|\.expo|\.git|ios|android|build|dist|artifacts)(/|$)|(^|/)(GoogleService-[^/]*|.*\.(p8|p12|pfx|pem|key|jks|keystore|mobileprovision|provisionprofile))$|(^|/).*(secret|credential|private-key).*$'
$secretPatterns = @(
  '-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----',
  '(?:ghp|gho|ghu|ghs|ghr|github_pat)_[A-Za-z0-9_]{20,}',
  '\bAKIA[0-9A-Z]{16}\b','\bAIza[0-9A-Za-z_-]{35}\b','\bsk-[A-Za-z0-9_-]{24,}\b',
  '(?i)(?:password|token|secret|api[_-]?key)\s*[:=]\s*([A-Za-z0-9_./+=-]{24,})'
)
$blockedReferences = @(
  (-join @('ef8d9f2e','7d9e','4333','8295','3ecd545db347')),
  ('GoogleService' + '-Info'),('firestore' + '.rules'),
  ('LuanRigatti/' + 'em' + 'po' + 'rio' + 'ri' + 'gatti'),
  ('LuanRigatti/' + 'pwa' + '-ios' + '-2026'),
  ('LuanRigatti/' + 'Em' + 'po' + 'rio' + '-' + 'Rig' + 'atti' + '-' + 'NativeSim' + '-' + 'Public'),
  ('Emp' + 'orio' + '-' + 'Rigatti'),('Emp' + 'ório Rigatti'),('com.' + 'pareact' + '.mobile')
)

function Invoke-Git {
  param([string]$Repository,[string[]]$GitArguments)
  $result = & git -C $Repository @GitArguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "git $($GitArguments -join ' ') failed in $Repository : $result" }
  return @($result | ForEach-Object { "$_" })
}
function Get-RelativePath {
  param([string]$Base,[string]$FullPath)
  return [IO.Path]::GetRelativePath($Base,$FullPath).Replace('\','/')
}
function Test-AllowedRelativePath {
  param([string]$RelativePath)
  $path = $RelativePath.Replace('\','/')
  if ($allowedFiles -contains $path) { return $true }
  foreach ($directory in $allowedDirectories) {
    if ($path.StartsWith($directory + '/',[StringComparison]::OrdinalIgnoreCase)) { return $true }
  }
  return $false
}
function Get-CandidateFiles {
  $result = [Collections.Generic.List[string]]::new()
  foreach ($relative in $allowedFiles) {
    if ($relative -eq '.nativesim-source') { continue }
    $path = Join-Path $sourceRoot $relative.Replace('/','\')
    if (Test-Path -LiteralPath $path -PathType Leaf) { $result.Add($relative) }
  }
  foreach ($relativeDirectory in $allowedDirectories) {
    $path = Join-Path $sourceRoot $relativeDirectory.Replace('/','\')
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }
    foreach ($item in Get-ChildItem -LiteralPath $path -File -Recurse -Force) {
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Linked/reparse file is excluded from the mirror: $($item.FullName)"
      }
      $result.Add((Get-RelativePath -Base $sourceRoot -FullPath $item.FullName))
    }
    foreach ($item in Get-ChildItem -LiteralPath $path -Directory -Recurse -Force) {
      if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Linked/reparse directory is excluded from the mirror: $($item.FullName)"
      }
    }
  }
  return @($result | Sort-Object -Unique)
}
function Assert-SafeFiles {
  param([string]$Base,[string[]]$RelativePaths)
  foreach ($relative in $RelativePaths) {
    $normalized = $relative.Replace('\','/')
    if (-not (Test-AllowedRelativePath $normalized) -and $normalized -ne '.nativesim-source') {
      throw "File is outside the publication allowlist: $normalized"
    }
    if ($normalized -match $blockedNamePattern) { throw "Blocked file name: $normalized" }
    $fullPath = Join-Path $Base $normalized.Replace('/','\')
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { continue }
    if ([IO.Path]::GetExtension($fullPath) -in @('.png','.jpg','.jpeg','.webp','.pdf','.zip','.tar','.gz')) { continue }
    $text = Get-Content -LiteralPath $fullPath -Raw -ErrorAction Stop
    foreach ($pattern in $secretPatterns) {
      if ([regex]::IsMatch($text,$pattern)) { throw "Credential-like content found in $normalized; publication is blocked." }
    }
    foreach ($reference in $blockedReferences) {
      if ($text.IndexOf($reference,[StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "Reference to the previous application found in $normalized; publication is blocked."
      }
    }
  }
}
function Assert-Remote {
  param([string]$Repository,[string]$ExpectedSlug)
  $remote = (Invoke-Git -Repository $Repository -GitArguments @('remote','get-url','origin')) -join $nl
  if ($remote -notmatch "(?i)(?:github\.com[:/])LuanRigatti/$([regex]::Escape($ExpectedSlug))(?:\.git)?$") {
    throw "origin is not LuanRigatti/$ExpectedSlug : $remote"
  }
}
function Assert-GitRoot {
  param([string]$Repository)
  $actual = [IO.Path]::GetFullPath(((Invoke-Git -Repository $Repository -GitArguments @('rev-parse','--show-toplevel')) -join $nl).Trim())
  if ($actual -ne [IO.Path]::GetFullPath($Repository)) { throw "Unexpected Git root: $actual" }
}

$sourceBranch = ((Invoke-Git $sourceRoot @('branch','--show-current')) -join '').Trim()
if ($sourceBranch -ne 'main') { throw "Starter source must be on main; found $sourceBranch." }
Assert-GitRoot $sourceRoot
Assert-Remote $sourceRoot 'Starter'
$sourceStatus = (Invoke-Git $sourceRoot @('status','--porcelain=v1','--untracked-files=all')) -join $nl
if ($sourceStatus.Trim()) { throw 'Starter source worktree must be clean before mirroring.' }
$sourceSha = ((Invoke-Git $sourceRoot @('rev-parse','HEAD')) -join '').Trim()
$sourceRemote = ((Invoke-Git $sourceRoot @('ls-remote','origin','refs/heads/main')) -join $nl).Trim()
if (-not $sourceRemote -or $sourceRemote.Split()[0] -ne $sourceSha) {
  throw 'The private Starter remote is not exactly at the local source SHA.'
}
$privateVisibility = (& gh repo view LuanRigatti/Starter --json visibility --jq .visibility 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $privateVisibility.ToUpperInvariant() -ne 'PRIVATE') {
  throw 'LuanRigatti/Starter must exist and be PRIVATE.'
}
$publicVisibility = (& gh repo view LuanRigatti/Starter-NativeSim-Public --json visibility --jq .visibility 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $publicVisibility.ToUpperInvariant() -ne 'PUBLIC') {
  throw 'LuanRigatti/Starter-NativeSim-Public must exist and be PUBLIC.'
}

if (-not (Test-Path -LiteralPath (Join-Path $destinationRoot '.git'))) {
  & git -C $destinationRoot init -b main
  if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the mirror Git repository.' }
  & git -C $destinationRoot remote add origin https://github.com/LuanRigatti/Starter-NativeSim-Public.git
  if ($LASTEXITCODE -ne 0) { throw 'Could not configure public mirror origin.' }
}
Assert-GitRoot $destinationRoot
Assert-Remote $destinationRoot 'Starter-NativeSim-Public'
$destinationBranch = ((Invoke-Git $destinationRoot @('branch','--show-current')) -join '').Trim()
if ($destinationBranch -ne 'main') { throw "Public mirror must be on main; found $destinationBranch." }

$candidates = Get-CandidateFiles
if ($candidates.Count -lt 1) { throw 'The mirror allowlist produced no files.' }
Assert-SafeFiles $sourceRoot $candidates
foreach ($relative in $candidates) {
  $sourcePath = Join-Path $sourceRoot $relative.Replace('/','\')
  $destinationPath = Join-Path $destinationRoot $relative.Replace('/','\')
  $parent = Split-Path -Parent $destinationPath
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}
$provenance = @(
  'source_repository=LuanRigatti/Starter'
  'source_branch=main'
  "source_commit=$sourceSha"
) -join $nl
Set-Content -LiteralPath (Join-Path $destinationRoot '.nativesim-source') -Value $provenance -Encoding utf8
$candidates = @($candidates + '.nativesim-source' | Sort-Object -Unique)
Assert-SafeFiles $destinationRoot $candidates

$knownPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($relative in $candidates) { [void]$knownPaths.Add($relative) }
$destinationEntries = Invoke-Git $destinationRoot @('ls-files','-co','--exclude-standard')
$stalePaths = [Collections.Generic.List[string]]::new()
foreach ($entry in $destinationEntries) {
  $relative = $entry.Replace('\','/')
  if ($relative -eq '.nativesim-source') { continue }
  if ((Test-AllowedRelativePath $relative) -and -not $knownPaths.Contains($relative)) { $stalePaths.Add($relative) }
}
foreach ($relative in $stalePaths) {
  $full = [IO.Path]::GetFullPath((Join-Path $destinationRoot $relative.Replace('/','\')))
  if (-not $full.StartsWith($destinationRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing stale path outside the mirror: $relative"
  }
  if (Test-Path -LiteralPath $full -PathType Leaf) { Remove-Item -LiteralPath $full }
}

$stagePaths = @($candidates + $stalePaths | Sort-Object -Unique | ForEach-Object { ':(literal)' + $_ })
& git -C $destinationRoot add -A -- @stagePaths
if ($LASTEXITCODE -ne 0) { throw 'Could not stage the exact allowlist.' }
& git -C $destinationRoot diff --cached --check
if ($LASTEXITCODE -ne 0) { throw 'Staged mirror diff failed git diff --check.' }
$stagedPaths = Invoke-Git $destinationRoot @('diff','--cached','--name-only')
foreach ($relative in $stagedPaths) {
  $normalized = $relative.Replace('\','/')
  if (-not (Test-AllowedRelativePath $normalized) -and $normalized -ne '.nativesim-source') {
    throw "Staged path is outside the mirror allowlist: $normalized"
  }
}
$untrackedPaths = @(Invoke-Git $destinationRoot @('ls-files','--others','--exclude-standard'))
if ($untrackedPaths.Count) { throw "Untracked files exist outside the reviewed mirror snapshot: $($untrackedPaths -join ', ')" }
$unstaged = (Invoke-Git $destinationRoot @('diff','--name-only')) -join $nl
if ($unstaged.Trim()) { throw 'The public mirror has unstaged edits; inspect them before publication.' }

Write-Output "Source SHA: $sourceSha"
Write-Output "Allowlisted files: $($candidates.Count)"
Write-Output "Stale allowlisted files removed: $($stalePaths.Count)"
Write-Output 'Credential and previous-application scan: passed'
Write-Output 'Review the staged diff before using -Publish.'
& git -C $destinationRoot diff --cached --stat
if (-not $Publish) {
  Write-Output 'Preview only: no commit or push was performed.'
  exit 0
}
if (-not $stagedPaths.Count) {
  Write-Output 'The public mirror already matches this source snapshot; no commit or push is needed.'
  exit 0
}

$hasHead = $true
& git -C $destinationRoot rev-parse --verify HEAD *> $null
if ($LASTEXITCODE -ne 0) { $hasHead = $false }
$liveOutput = (& git -C $destinationRoot ls-remote origin refs/heads/main 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw "Could not read live public main: $liveOutput" }
$liveSha = if ($liveOutput) { $liveOutput.Split()[0] } else { '' }
if ($liveSha) {
  & git -C $destinationRoot fetch --no-tags origin main
  if ($LASTEXITCODE -ne 0) { throw 'Could not fetch public main for fast-forward validation.' }
  if (-not $hasHead) { throw 'Public main exists remotely but local history is absent; refusing replacement.' }
  $localHead = ((Invoke-Git $destinationRoot @('rev-parse','HEAD')) -join '').Trim()
  & git -C $destinationRoot merge-base --is-ancestor $liveSha $localHead
  if ($LASTEXITCODE -ne 0) { throw 'Live public main is not an ancestor of local main; no reset or force push will be attempted.' }
} elseif ($hasHead) {
  throw 'Local public history exists but remote main is empty; refusing ambiguous publication.'
}

$identity = & git -C $destinationRoot var GIT_AUTHOR_IDENT 2>$null
if ($LASTEXITCODE -ne 0) {
  & git -C $destinationRoot config user.name 'Starter Mirror'
  & git -C $destinationRoot config user.email 'starter-mirror@users.noreply.github.com'
}
$commitArgs = @(
  'commit',
  '-m',"Mirror Starter source $($sourceSha.Substring(0,12))",
  '-m','Source-Repository: LuanRigatti/Starter',
  '-m',"Source-Commit: $sourceSha",
  '-m','Source-Branch: main'
)
& git -C $destinationRoot @commitArgs
if ($LASTEXITCODE -ne 0) { throw 'Mirror commit failed.' }
& git -C $destinationRoot push --set-upstream origin main
if ($LASTEXITCODE -ne 0) { throw 'Normal fast-forward push failed; no force push was attempted.' }
$publishedSha = ((Invoke-Git $destinationRoot @('rev-parse','HEAD')) -join '').Trim()
$remoteAfter = ((Invoke-Git $destinationRoot @('ls-remote','origin','refs/heads/main')) -join $nl).Trim()
if (-not $remoteAfter -or $remoteAfter.Split()[0] -ne $publishedSha) { throw 'Post-push remote SHA verification failed.' }
Write-Output "Published source $sourceSha as mirror commit $publishedSha."
