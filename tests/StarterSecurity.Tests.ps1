Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $repositoryRoot 'scripts\StarterMirrorSecurity.psm1') -Force -DisableNameChecking -ErrorAction Stop
Import-Module (Join-Path $repositoryRoot 'scripts\StarterNativeSimCliGuard.psm1') -Force -DisableNameChecking -ErrorAction Stop

function Assert-True {
  param([bool]$Condition,[string]$Message)
  if (-not $Condition) { throw "FAIL: $Message" }
  Write-Output "PASS: $Message"
}

function Assert-Refused {
  param([scriptblock]$Action,[string]$Message)
  $refused = $false
  try { & $Action | Out-Null } catch { $refused = $true }
  Assert-True $refused $Message
}

function Invoke-GitChecked {
  param([string]$Root,[string[]]$Arguments)
  $result = & git -C $Root @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Test fixture git command failed: git $($Arguments -join ' ') $result" }
}

function Invoke-ScaffoldOnly {
  param([string]$Node,[string]$InitFile,[string]$Root)
  $code = @'
import { pathToFileURL } from 'node:url';
const [, initPath, checkoutRoot] = process.argv;
const { scaffold } = await import(pathToFileURL(initPath).href);
process.stdout.write(JSON.stringify({ changed: scaffold(checkoutRoot) }) + '\n');
'@
  $startInfo = [Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $Node
  $startInfo.WorkingDirectory = $Root
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in @('--input-type=module','--eval',$code,$InitFile,$Root)) { [void]$startInfo.ArgumentList.Add($argument) }
  $process = [Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  try {
    if (-not $process.Start()) { throw 'Could not start the local NativeSim scaffold fixture.' }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "NativeSim scaffold fixture failed: $stderr" }
    $line = @($stdout -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 1)
    if ($line.Count -ne 1) { throw 'NativeSim scaffold fixture returned no result.' }
    return ($line[0] | ConvertFrom-Json -ErrorAction Stop)
  } finally { $process.Dispose() }
}

function New-NativeSimGitFixture {
  param([string]$Root,[string]$Workflow,[string]$Gate)
  New-Item -ItemType Directory -Path (Join-Path $Root '.github\workflows') -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $Root '.github\native-sim') -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $Root '.github\workflows\native-sim.yml'),$Workflow,[Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $Root '.github\native-sim\gate.cjs'),$Gate,[Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $Root '.gitignore'),"node_modules/`n.expo/`n",[Text.UTF8Encoding]::new($false))
  Invoke-GitChecked $Root @('init','-b','main')
  Invoke-GitChecked $Root @('config','user.email','starter-security-tests@example.invalid')
  Invoke-GitChecked $Root @('config','user.name','Starter Security Tests')
  Invoke-GitChecked $Root @('add','-A')
  Invoke-GitChecked $Root @('commit','-m','temporary NativeSim scaffold fixture')
  return ((& git -C $Root rev-parse HEAD 2>&1 | Out-String).Trim())
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('starter-security-tests-' + [guid]::NewGuid().ToString('N'))
$linkPaths = [Collections.Generic.List[string]]::new()
try {
  $source = Join-Path $tempRoot 'source'
  $mirror = Join-Path $tempRoot 'mirror'
  $outside = Join-Path $tempRoot 'outside'
  New-Item -ItemType Directory -Path $source,$mirror,$outside -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $source 'src'),(Join-Path $source 'assets') -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $source 'src\safe.js'),'safe',[Text.UTF8Encoding]::new($false))
  Assert-True ((Resolve-StarterMirrorPath -Base $source -RelativePath 'src\safe.js' -ExpectedType File) -eq (Join-Path $source 'src\safe.js')) 'valid allowlisted source file resolves within root'
  Assert-True ((Resolve-StarterMirrorPath -Base $source -RelativePath 'src' -ExpectedType Directory) -eq (Join-Path $source 'src')) 'valid allowlisted source directory resolves within root'
  Assert-Refused { Resolve-StarterMirrorPath -Base $source -RelativePath '..\outside\safe.js' -ExpectedType File } 'path traversal outside mirror root is rejected'

  $mirrorSecurityModule = Get-Module StarterMirrorSecurity
  $syntheticFileSymlink = [pscustomobject]@{ Attributes = [IO.FileAttributes]::ReparsePoint; PSIsContainer = $false }
  $syntheticDirectorySymlink = [pscustomobject]@{ Attributes = [IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint; PSIsContainer = $true }
  Assert-Refused { & $mirrorSecurityModule { param($item) Assert-StarterPathItem -Item $item -Path 'simulated-file-symlink' -ExpectedType File } $syntheticFileSymlink } 'simulated malicious source file symlink is rejected'
  Assert-Refused { & $mirrorSecurityModule { param($item) Assert-StarterPathItem -Item $item -Path 'simulated-directory-symlink' -ExpectedType Directory } $syntheticDirectorySymlink } 'simulated malicious source directory symlink is rejected'

  $outsideFile = Join-Path $outside 'sentinel.txt'
  [IO.File]::WriteAllText($outsideFile,'external-sentinel',[Text.UTF8Encoding]::new($false))
  $copiedFile = Copy-StarterMirrorFile -SourceRoot $source -MirrorRoot $mirror -RelativePath 'src\safe.js'
  Assert-True ([IO.File]::ReadAllText($copiedFile) -ceq 'safe') 'valid allowlisted file is copied through an in-root temporary file'
  $linkedCopy = Join-Path $mirror 'src\safe.js'
  [IO.File]::Delete($linkedCopy)
  New-Item -ItemType HardLink -Path $linkedCopy -Target $outsideFile -ErrorAction Stop | Out-Null
  $null = Copy-StarterMirrorFile -SourceRoot $source -MirrorRoot $mirror -RelativePath 'src\safe.js'
  Assert-True ([IO.File]::ReadAllText($linkedCopy) -ceq 'safe' -and [IO.File]::ReadAllText($outsideFile) -ceq 'external-sentinel') 'atomic mirror copy replaces a hard-linked destination without overwriting external content'

  $junction = Join-Path $source 'assets\external-junction'
  New-Item -ItemType Junction -Path $junction -Target $outside -ErrorAction Stop | Out-Null
  $linkPaths.Add($junction)
  Assert-Refused { Resolve-StarterMirrorPath -Base $source -RelativePath 'assets\external-junction' -ExpectedType Directory } 'malicious source junction is rejected before enumeration'

  $ancestorLink = Join-Path $tempRoot 'ancestor-junction'
  New-Item -ItemType Junction -Path $ancestorLink -Target $outside -ErrorAction Stop | Out-Null
  $linkPaths.Add($ancestorLink)
  Assert-Refused { Assert-StarterMirrorRoot -Root (Join-Path $ancestorLink 'nested-root') } 'reparse point in an ancestor component is rejected'

  $provenance = "source_repository=LuanRigatti/Starter`nsource_branch=main`nsource_commit=$('a' * 40)"
  $writtenPath = Write-StarterProvenance -MirrorRoot $mirror -Content $provenance
  Assert-True ([IO.File]::ReadAllText($writtenPath) -ceq $provenance) 'provenance writes atomically to a valid mirror root'

  $redirectedMirror = Join-Path $tempRoot 'redirected-mirror'
  New-Item -ItemType Directory -Path $redirectedMirror -Force | Out-Null
  $externalProvenance = Join-Path $outside 'provenance-target.txt'
  [IO.File]::WriteAllText($externalProvenance,'must-remain-unchanged',[Text.UTF8Encoding]::new($false))
  $provenanceLink = Join-Path $redirectedMirror '.nativesim-source'
  New-Item -ItemType HardLink -Path $provenanceLink -Target $externalProvenance -ErrorAction Stop | Out-Null
  $redirectWrite = Write-StarterProvenance -MirrorRoot $redirectedMirror -Content $provenance
  Assert-True ([IO.File]::ReadAllText($redirectWrite) -ceq $provenance -and [IO.File]::ReadAllText($externalProvenance) -ceq 'must-remain-unchanged') 'atomic provenance replacement detaches a linked target without overwriting its external file'

  $junctionMirror = Join-Path $tempRoot 'mirror-junction'
  New-Item -ItemType Junction -Path $junctionMirror -Target $outside -ErrorAction Stop | Out-Null
  $linkPaths.Add($junctionMirror)
  Assert-Refused { Write-StarterProvenance -MirrorRoot $junctionMirror -Content $provenance } 'junction redirected provenance root is rejected'
  Assert-True ([IO.File]::ReadAllText($outsideFile) -ceq 'external-sentinel') 'junction destination did not overwrite external content'

  $cli = Get-Command native-sim.ps1 -ErrorAction Stop
  $package = Join-Path (Split-Path -Parent $cli.Source) 'node_modules\native-sim'
  $node = (Get-Command node.exe -ErrorAction Stop).Source
  $templateWorkflow = Get-Content -LiteralPath (Join-Path $package 'templates\native-sim.yml') -Raw
  $templateGate = Get-Content -LiteralPath (Join-Path $package 'templates\gate.cjs') -Raw
  $approvedGate = [regex]::Replace($templateGate,'(?<![A-Z_])TOKEN(?![A-Z_])','GATE_VALUE')
  $fixture = Join-Path $tempRoot 'cli-valid'
  New-Item -ItemType Directory -Path $fixture -Force | Out-Null
  $fixtureSha = New-NativeSimGitFixture -Root $fixture -Workflow $templateWorkflow -Gate $approvedGate
  $preview = Invoke-StarterNativeSimScaffoldPreview -CliPackageRoot $package -CheckoutRoot $fixture -ExpectedSha $fixtureSha -NodeExecutable $node
  Assert-True (-not $preview.ScaffoldChanged -and $preview.CheckoutSha -eq $fixtureSha) 'actual NativeSim scaffold preserves the approved workflow and normalized gate at the audited SHA'

  $tamperedFixture = Join-Path $tempRoot 'cli-gate-tampered'
  New-Item -ItemType Directory -Path $tamperedFixture -Force | Out-Null
  $tamperedGate = $approvedGate + "`n// unexpected gate change`n"
  $tamperedSha = New-NativeSimGitFixture -Root $tamperedFixture -Workflow $templateWorkflow -Gate $tamperedGate
  Assert-Refused { Invoke-StarterNativeSimScaffoldPreview -CliPackageRoot $package -CheckoutRoot $tamperedFixture -ExpectedSha $tamperedSha -NodeExecutable $node } 'divergent gate.cjs content is rejected before CLI execution'

  $staleFixture = Join-Path $tempRoot 'cli-gate-stale'
  New-Item -ItemType Directory -Path $staleFixture -Force | Out-Null
  $templateGateVersion = [int]([regex]::Match($templateGate,'(?m)^//\s*native-sim-template-version:\s*(?<version>[0-9]+)').Groups['version'].Value)
  $staleGate = [regex]::new('(?m)^(//\s*native-sim-template-version:\s*)[0-9]+').Replace($templateGate,('${1}' + ($templateGateVersion - 1)),1)
  $staleSha = New-NativeSimGitFixture -Root $staleFixture -Workflow $templateWorkflow -Gate $staleGate
  Assert-Refused { Assert-StarterNativeSimCliCompatible -CliPackageRoot $package -WorkflowPath (Join-Path $staleFixture '.github\workflows\native-sim.yml') -GatePath (Join-Path $staleFixture '.github\native-sim\gate.cjs') } 'stale gate is blocked by the compatibility gate before session start'
  $cliChanged = Invoke-ScaffoldOnly -Node $node -InitFile (Join-Path $package 'src\commands\init.js') -Root $staleFixture
  Assert-True ($cliChanged.changed -eq $true -and (Get-FileHash -LiteralPath (Join-Path $staleFixture '.github\native-sim\gate.cjs') -Algorithm SHA256).Hash -eq (Get-FileHash -LiteralPath (Join-Path $package 'templates\gate.cjs') -Algorithm SHA256).Hash) 'installed CLI simulation confirms a stale gate would be rewritten'

  $preflight = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Invoke-StarterSwiftPreflight.ps1') -Raw
  $launcher = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Start-StarterNativeSim.ps1') -Raw
  $workflow = Get-Content -LiteralPath (Join-Path $repositoryRoot '.github\workflows\native-sim.yml') -Raw
  $archiveSkill = Get-Content -LiteralPath (Join-Path $repositoryRoot '.agents\skills\starter-simulator-archive\SKILL.md') -Raw
  $archiveScript = Get-Content -LiteralPath (Join-Path $repositoryRoot 'scripts\Download-StarterSimulatorArchive.ps1') -Raw
  $nativeSimUpText = Get-Content -LiteralPath (Join-Path $package 'src\commands\up.js') -Raw
  Assert-True ($launcher.Contains('StarterNativeSimLaunch') -and $launcher.Contains('Get-ActiveNativeSimRuns') -and $launcher.Contains('No duplicate was started')) 'duplicate-session mutex and active-run guard remain present'
  $activeFixtures = @(
    [pscustomobject]@{ id='42'; path='.github/workflows/native-sim.yml'; event='workflow_dispatch'; head_branch='main'; status='in_progress' },
    [pscustomobject]@{ id='42'; path='.github/workflows/native-sim.yml'; event='workflow_dispatch'; head_branch='main'; status='in_progress' },
    [pscustomobject]@{ id='43'; path='.github/workflows/other.yml'; event='workflow_dispatch'; head_branch='main'; status='in_progress' },
    [pscustomobject]@{ id='44'; path='.github/workflows/native-sim.yml'; event='push'; head_branch='main'; status='in_progress' }
  )
  $activeSelected = @(Select-StarterNativeSimActiveRuns -Runs $activeFixtures)
  Assert-True ($activeSelected.Count -eq 1 -and [string]$activeSelected[0].id -eq '42') 'duplicate NativeSim runs are deduplicated and unrelated runs are ignored'

  $global:StarterTestPreflightMode = 'success'
  $global:StarterTestPreflightSha = ((& git -C 'C:\Projetos\Starter-NativeSim-Public' rev-parse HEAD 2>&1 | Out-String).Trim())
  $global:StarterTestPreflightDispatchCount = 0
  function global:gh {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$GhArgs)
    $global:LASTEXITCODE = 0
    if ($GhArgs[0] -eq 'repo') { return 'PUBLIC' }
    if ($GhArgs[0] -eq 'run' -and $GhArgs[1] -eq 'list') {
      $status = if ($global:StarterTestPreflightMode -eq 'active') { 'in_progress' } else { 'completed' }
      $conclusion = if ($status -eq 'completed') { 'success' } else { '' }
      return ([pscustomobject]@{ databaseId=123456789; headSha=$global:StarterTestPreflightSha; headBranch='main'; status=$status; conclusion=$conclusion; url='https://github.com/LuanRigatti/Starter-NativeSim-Public/actions/runs/123456789'; event='workflow_dispatch' } | ConvertTo-Json -Compress)
    }
    if ($GhArgs[0] -eq 'api') {
      $status = if ($global:StarterTestPreflightMode -eq 'active') { 'in_progress' } else { 'completed' }
      $conclusion = if ($status -eq 'completed') { 'success' } else { '' }
      return ([pscustomobject]@{ id=123456789; path='.github/workflows/swift-preflight.yml'; event='workflow_dispatch'; head_branch='main'; head_sha=$global:StarterTestPreflightSha; status=$status; conclusion=$conclusion; html_url='https://github.com/LuanRigatti/Starter-NativeSim-Public/actions/runs/123456789' } | ConvertTo-Json -Compress)
    }
    if ($GhArgs[0] -eq 'workflow' -and $GhArgs[1] -eq 'run') {
      $global:StarterTestPreflightDispatchCount++
      $global:LASTEXITCODE = 1
      return 'blocked by test mock'
    }
    $global:LASTEXITCODE = 1
    throw "Unexpected GitHub CLI call in test mock: $($GhArgs -join ' ')"
  }
  $preflightScript = Join-Path $repositoryRoot 'scripts\Invoke-StarterSwiftPreflight.ps1'
  $reusedPreflight = @(& $preflightScript -PassThru)
  Assert-True ($reusedPreflight.Count -eq 1 -and $reusedPreflight[0].Passed -and $reusedPreflight[0].Reused -and
    $reusedPreflight[0].Sha -eq $global:StarterTestPreflightSha -and $global:StarterTestPreflightDispatchCount -eq 0) 'successful exact-SHA Preflight is reused without dispatch'
  $global:StarterTestPreflightMode = 'active'
  $activePreflight = @(& $preflightScript -NoWait -PassThru)
  Assert-True ($activePreflight.Count -eq 1 -and -not $activePreflight[0].Passed -and $activePreflight[0].Reused -and $global:StarterTestPreflightDispatchCount -eq 0) 'active exact-SHA Preflight is reused without dispatch or waiting'
  Remove-Item Function:\global:gh -Force

  Assert-True ($launcher.Contains('Authenticated Simulator:') -and $launcher.Contains('$json.Contains($SimulatorUrl)')) 'authenticated link is delivered only after metadata rejects URL persistence'
  $fullSimulatorUrl = 'https://starter.trycloudflare.com/?k=abcdefghijklmnopqrstuvwxyz0123456789&mode=stream'
  Assert-True ((Assert-StarterSimulatorUrl -Url $fullSimulatorUrl) -ceq $fullSimulatorUrl) 'complete authenticated URL with full k value is preserved exactly'
  Assert-Refused { Assert-StarterSimulatorUrl -Url 'https://starter.trycloudflare.com/?k=short' } 'truncated authenticated k value is rejected'
  Assert-Refused { Assert-StarterSimulatorUrl -Url 'https://starter.trycloudflare.com/?mode=stream' } 'URL without authenticated k value is rejected'

  Assert-True (Assert-StarterNativeSimExportBehavior -NativeSimUpText $nativeSimUpText -WorkflowText $workflow) 'installed CLI and workflow preserve export_app, early URL output, and seven-day retention'
  $badExportWorkflow = $workflow.Replace("retention-days: 7",'retention-days: 1')
  Assert-Refused { Assert-StarterNativeSimExportBehavior -NativeSimUpText $nativeSimUpText -WorkflowText $badExportWorkflow } 'archive retention drift is blocked by the export contract'
  Assert-True ($launcher.Contains("'--export'") -and $archiveSkill.Contains('seven days') -and $archiveScript.Contains('workflow_dispatch')) 'archive skills only retrieve an existing qualifying run'

  $eligibleActiveRun = [pscustomobject]@{ id='77'; path='.github/workflows/native-sim.yml'; event='workflow_dispatch'; head_branch='main'; status='in_progress'; head_sha=('b' * 40) }
  Assert-True ((Assert-StarterArchiveRun -Run $eligibleActiveRun -ExpectedId '77').status -eq 'in_progress') 'archive retrieval accepts an active run after its artifact upload'
  $invalidArchiveRun = [pscustomobject]@{ id='77'; path='.github/workflows/native-sim.yml'; event='workflow_dispatch'; head_branch='main'; status='completed'; head_sha='short' }
  Assert-Refused { Assert-StarterArchiveRun -Run $invalidArchiveRun -ExpectedId '77' } 'archive retrieval rejects a run without a full SHA'
  $expectedArtifact = [pscustomobject]@{ name='native-sim-app-1234abcd'; expired=$false; size_in_bytes=256 }
  Assert-True ((Select-StarterArchiveArtifact -Artifacts @($expectedArtifact) -ExpectedName 'native-sim-app-1234abcd').name -eq $expectedArtifact.name) 'archive selector accepts the exact available session artifact'
  $expiredArtifact = [pscustomobject]@{ name='native-sim-app-1234abcd'; expired=$true; size_in_bytes=256 }
  Assert-True ($null -eq (Select-StarterArchiveArtifact -Artifacts @($expiredArtifact) -ExpectedName 'native-sim-app-1234abcd')) 'expired archive artifacts are not selected'
  $successfulArchiveSteps = @(
    [pscustomobject]@{ name='Build unsigned Simulator app'; status='completed'; conclusion='success' },
    [pscustomobject]@{ name='Export the .app archive'; status='completed'; conclusion='success' },
    [pscustomobject]@{ name='Upload Simulator archive'; status='completed'; conclusion='success' }
  )
  Assert-True (Test-StarterArchiveBuildSteps -Steps $successfulArchiveSteps) 'archive retrieval requires successful build, export and upload steps'
  $failedArchiveSteps = @($successfulArchiveSteps[0],$successfulArchiveSteps[1],([pscustomobject]@{ name='Upload Simulator archive'; status='completed'; conclusion='failure' }))
  Assert-True (-not (Test-StarterArchiveBuildSteps -Steps $failedArchiveSteps)) 'archive retrieval blocks an unsuccessful upload step'

  $archiveFixtureRoot = Join-Path $tempRoot 'archive-fixture'
  $appBundle = Join-Path $archiveFixtureRoot 'Starter.app'
  New-Item -ItemType Directory -Path $appBundle -Force | Out-Null
  [IO.File]::WriteAllText((Join-Path $appBundle 'Payload'),'simulator-bundle',[Text.UTF8Encoding]::new($false))
  $validArchive = Join-Path $tempRoot 'Starter.app.tar.gz'
  & tar -czf $validArchive -C $archiveFixtureRoot 'Starter.app'
  if ($LASTEXITCODE -ne 0) { throw 'Could not create the local .app.tar.gz test fixture.' }
  $archiveResult = Assert-StarterSimulatorArchive -Path $validArchive
  Assert-True ($archiveResult.EntryCount -gt 0) 'downloaded .app.tar.gz is readable and contains an app bundle'
  $invalidArchive = Join-Path $tempRoot 'broken.app.tar.gz'
  [IO.File]::WriteAllText($invalidArchive,'not-a-tar',[Text.UTF8Encoding]::new($false))
  Assert-Refused { Assert-StarterSimulatorArchive -Path $invalidArchive } 'corrupt .app.tar.gz is rejected'

  Write-Output 'Starter security simulations completed: Preflight was mocked; no GitHub workflow, NativeSim up, EAS, or mirror publication was invoked.'
} finally {
  foreach ($path in $linkPaths) {
    $link = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if ($link -and ($link.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
      if ($link.PSIsContainer) { [IO.Directory]::Delete($path) } else { [IO.File]::Delete($path) }
    }
  }
  if (Test-Path -LiteralPath $tempRoot) {
    $tempItem = Get-Item -LiteralPath $tempRoot -Force -ErrorAction SilentlyContinue
    if ($tempItem -and ($tempItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}
