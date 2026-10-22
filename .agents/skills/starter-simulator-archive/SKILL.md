---
name: starter-simulator-archive
description: Download and verify the .app.tar.gz artifact from a successful exact-current-SHA Starter NativeSim GitHub Actions run using GitHub CLI. Use when the user asks to retrieve a Simulator archive.
---

# Download the Starter Simulator archive

Use only for an explicit request to compile and retrieve the `.app.tar.gz`, or `$starter-simulator-archive`. This flow runs the NativeSim build workflow with archive export enabled, then verifies and downloads that same run's artifact through GitHub CLI.

## Download

From `C:\Projetos\Starter-NativeSim-Public`, run PowerShell 7:

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\Start-StarterNativeSim.ps1 -Minutes 30 -ExportArchive
```

Wait for the CLI to return successfully and copy the numeric run ID from its GitHub Actions URL. Then run:

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\Download-StarterSimulatorArchive.ps1 -RunId 1234567890
```

The download script verifies that the run is complete and successful, came from `.github/workflows/native-sim.yml` on `main`, and targets the current live public `main` SHA. It derives the session ID from the workflow run title, downloads only that run's `native-sim-app-<session>` artifact using `gh run download`, and checks that exactly one readable `.app.tar.gz` contains an `.app` bundle. The CLI's `-ExportArchive` also downloads the artifact once to `artifacts`; the direct run-ID script stores a verified copy in its per-run folder.

The verified archive is placed under `C:\Projetos\Starter-NativeSim-Public\artifacts\<run-id>`. The directory is ignored by Git. Stop on a failed, stale, ambiguous, or unreadable artifact. Do not download a different run's artifact or claim the archive was built from the current source unless the SHA check passes.
