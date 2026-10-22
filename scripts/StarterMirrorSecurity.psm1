Set-StrictMode -Version Latest

function Get-StarterRelativeSegments {
  param([Parameter(Mandatory)][string]$RelativePath)

  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
    throw 'Mirror paths must be non-empty and relative to the authorized repository root.'
  }

  $normalized = $RelativePath.Replace('\','/')
  $segments = @($normalized.Split('/'))
  foreach ($segment in $segments) {
    if ([string]::IsNullOrWhiteSpace($segment) -or $segment -in @('.','..') -or
        $segment -match '[<>:"|?*\x00]' -or $segment.EndsWith('.') -or $segment.EndsWith(' ')) {
      throw "Invalid or unresolved mirror path component: $segment"
    }
  }
  return ,$segments
}

function Get-StarterPathItem {
  param(
    [Parameter(Mandatory)][string]$Path,
    [switch]$AllowMissing
  )

  try {
    return Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  } catch {
    if ($AllowMissing -and $_.CategoryInfo.Category -eq [Management.Automation.ErrorCategory]::ObjectNotFound) {
      return $null
    }
    throw "Could not resolve mirror path safely: $Path. $($_.Exception.Message)"
  }
}

function Assert-StarterPathItem {
  param(
    [Parameter(Mandatory)]$Item,
    [Parameter(Mandatory)][string]$Path,
    [ValidateSet('Any','File','Directory')][string]$ExpectedType = 'Any'
  )

  if (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Refusing a symlink, junction, or other reparse point in a mirror path: $Path"
  }
  if ($ExpectedType -eq 'File' -and $Item.PSIsContainer) {
    throw "Expected a file but resolved a directory: $Path"
  }
  if ($ExpectedType -eq 'Directory' -and -not $Item.PSIsContainer) {
    throw "Expected a directory but resolved a file: $Path"
  }
}

function Assert-StarterMirrorRoot {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Root)

  $fullRoot = [IO.Path]::GetFullPath($Root)
  $pathRoot = [IO.Path]::GetPathRoot($fullRoot)
  if (-not $pathRoot -or $fullRoot.Length -lt $pathRoot.Length) {
    throw "Mirror root is invalid or unresolved: $Root"
  }
  if ($fullRoot.Length -gt $pathRoot.Length) {
    $fullRoot = $fullRoot.TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
  }

  $tail = $fullRoot.Substring($pathRoot.Length)
  $segments = @($tail.Split([char[]]@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),[StringSplitOptions]::RemoveEmptyEntries))
  $current = $pathRoot
  $item = Get-StarterPathItem -Path $current
  Assert-StarterPathItem -Item $item -Path $current -ExpectedType Directory
  foreach ($segment in $segments) {
    $current = [IO.Path]::Combine($current,$segment)
    $item = Get-StarterPathItem -Path $current
    Assert-StarterPathItem -Item $item -Path $current -ExpectedType Directory
  }
  return $fullRoot
}

function Resolve-StarterMirrorPath {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Base,
    [Parameter(Mandatory)][string]$RelativePath,
    [ValidateSet('Any','File','Directory')][string]$ExpectedType = 'Any',
    [switch]$AllowMissingLeaf
  )

  $segments = Get-StarterRelativeSegments -RelativePath $RelativePath
  $baseFull = Assert-StarterMirrorRoot -Root $Base
  $candidate = [IO.Path]::GetFullPath([IO.Path]::Combine($baseFull,($segments -join [IO.Path]::DirectorySeparatorChar)))
  $basePrefix = $baseFull.TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not $candidate.StartsWith($basePrefix,[StringComparison]::OrdinalIgnoreCase)) {
    throw "Resolved mirror path escapes the authorized root: $RelativePath"
  }

  $current = $baseFull
  for ($index = 0; $index -lt $segments.Count; $index++) {
    $current = [IO.Path]::Combine($current,$segments[$index])
    $isLeaf = $index -eq ($segments.Count - 1)
    $item = Get-StarterPathItem -Path $current -AllowMissing:($AllowMissingLeaf -and $isLeaf)
    if ($null -eq $item) {
      if ($isLeaf -and $AllowMissingLeaf) { return $null }
      throw "Mirror path component is missing or unresolved: $current"
    }
    $componentType = if ($isLeaf) { $ExpectedType } else { 'Directory' }
    Assert-StarterPathItem -Item $item -Path $current -ExpectedType $componentType
  }
  return $candidate
}

function Ensure-StarterMirrorDirectory {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Base,
    [Parameter(Mandatory)][string]$RelativePath
  )

  $segments = Get-StarterRelativeSegments -RelativePath $RelativePath
  $built = [Collections.Generic.List[string]]::new()
  foreach ($segment in $segments) {
    $built.Add($segment)
    $relative = $built -join [IO.Path]::DirectorySeparatorChar
    $resolved = Resolve-StarterMirrorPath -Base $Base -RelativePath $relative -ExpectedType Directory -AllowMissingLeaf
    if ($null -eq $resolved) {
      $parentRelative = if ($built.Count -gt 1) { (@($built | Select-Object -SkipLast 1) -join [IO.Path]::DirectorySeparatorChar) } else { $null }
      $parent = if ($parentRelative) { Resolve-StarterMirrorPath -Base $Base -RelativePath $parentRelative -ExpectedType Directory } else { [IO.Path]::GetFullPath($Base) }
      $newDirectory = [IO.Path]::Combine($parent,$segment)
      New-Item -ItemType Directory -Path $newDirectory -ErrorAction Stop | Out-Null
      $null = Resolve-StarterMirrorPath -Base $Base -RelativePath $relative -ExpectedType Directory
    }
  }
  return Resolve-StarterMirrorPath -Base $Base -RelativePath $RelativePath -ExpectedType Directory
}

function Copy-StarterMirrorFile {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$MirrorRoot,
    [Parameter(Mandatory)][string]$RelativePath
  )

  $source = Resolve-StarterMirrorPath -Base $SourceRoot -RelativePath $RelativePath -ExpectedType File
  $parentRelative = Split-Path -Path $RelativePath.Replace('/','\') -Parent
  if ($parentRelative) { $null = Ensure-StarterMirrorDirectory -Base $MirrorRoot -RelativePath $parentRelative }
  $target = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $RelativePath -ExpectedType File -AllowMissingLeaf
  $leaf = Split-Path -Path $RelativePath.Replace('/','\') -Leaf
  $temporaryRelative = if ($parentRelative) {
    Join-Path $parentRelative ('.' + $leaf + '.' + [guid]::NewGuid().ToString('N') + '.mirror-tmp')
  } else {
    '.' + $leaf + '.' + [guid]::NewGuid().ToString('N') + '.mirror-tmp'
  }
  $temporary = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $temporaryRelative -ExpectedType File -AllowMissingLeaf
  if ($null -ne $temporary) { throw 'A mirror copy temporary path unexpectedly already exists.' }

  try {
    $source = Resolve-StarterMirrorPath -Base $SourceRoot -RelativePath $RelativePath -ExpectedType File
    $temporaryFullPath = [IO.Path]::Combine([IO.Path]::GetFullPath($MirrorRoot),$temporaryRelative.Replace('\',[IO.Path]::DirectorySeparatorChar))
    $stream = [IO.File]::Open($temporaryFullPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {
      $bytes = [IO.File]::ReadAllBytes($source)
      $stream.Write($bytes,0,$bytes.Length)
    } finally { $stream.Dispose() }
    $temporary = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $temporaryRelative -ExpectedType File
    $target = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $RelativePath -ExpectedType File -AllowMissingLeaf
    if ($null -eq $target) {
      $target = [IO.Path]::Combine([IO.Path]::GetFullPath($MirrorRoot),$RelativePath.Replace('\',[IO.Path]::DirectorySeparatorChar).Replace('/',[IO.Path]::DirectorySeparatorChar))
      [IO.File]::Move($temporary,$target)
    } else {
      [IO.File]::Move($temporary,$target,$true)
    }
    $verified = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $RelativePath -ExpectedType File
    return $verified
  } finally {
    $remaining = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $temporaryRelative -ExpectedType File -AllowMissingLeaf
    if ($null -ne $remaining) { [IO.File]::Delete($remaining) }
  }
}

function Write-StarterProvenance {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$MirrorRoot,
    [Parameter(Mandatory)][string]$Content
  )

  $relativePath = '.nativesim-source'
  $target = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $relativePath -ExpectedType File -AllowMissingLeaf
  $temporaryRelative = '.nativesim-source.' + [guid]::NewGuid().ToString('N') + '.tmp'
  $temporary = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $temporaryRelative -ExpectedType File -AllowMissingLeaf
  if ($null -ne $temporary) { throw 'A provenance temporary path unexpectedly already exists.' }

  try {
    $temporaryFullPath = [IO.Path]::Combine([IO.Path]::GetFullPath($MirrorRoot),$temporaryRelative)
    $stream = [IO.File]::Open($temporaryFullPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {
      $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Content)
      $stream.Write($bytes,0,$bytes.Length)
    } finally { $stream.Dispose() }
    $temporary = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $temporaryRelative -ExpectedType File
    $target = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $relativePath -ExpectedType File -AllowMissingLeaf
    if ($null -eq $target) {
      $target = [IO.Path]::Combine([IO.Path]::GetFullPath($MirrorRoot),$relativePath)
      [IO.File]::Move($temporary,$target)
    } else {
      [IO.File]::Move($temporary,$target,$true)
    }
    $verified = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $relativePath -ExpectedType File
    if ([IO.File]::ReadAllText($verified) -cne $Content) {
      throw 'The written mirror provenance did not match the expected content.'
    }
    return $verified
  } finally {
    $remaining = Resolve-StarterMirrorPath -Base $MirrorRoot -RelativePath $temporaryRelative -ExpectedType File -AllowMissingLeaf
    if ($null -ne $remaining) { [IO.File]::Delete($remaining) }
  }
}

Export-ModuleMember -Function Assert-StarterMirrorRoot,Resolve-StarterMirrorPath,Ensure-StarterMirrorDirectory,Copy-StarterMirrorFile,Write-StarterProvenance
