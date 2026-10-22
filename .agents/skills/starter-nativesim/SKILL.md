---
name: starter-nativesim
description: Run the exact-SHA Swift Preflight and start one authenticated NativeSim iOS Simulator session for the published Starter-NativeSim-Public main commit. Use only for an explicit NativeSim request.
---

# Starter NativeSim session

Use only when the user explicitly asks to start NativeSim or invokes `$starter-nativesim`. Preparing or explaining the skill does not authorize a session. A session dispatch consumes hosted macOS workflow time; start at most one session for the requested SHA.

## Fixed target

- Public build repository: `C:\Projetos\Starter-NativeSim-Public`, `LuanRigatti/Starter-NativeSim-Public`, branch `main`.
- Private source: `C:\Projetos\Starter`, `LuanRigatti/Starter`, branch `main`.
- The public provenance file must name the exact live private source commit. Keep commands within these two fixed Starter roots.

## Run

From `C:\Projetos\Starter-NativeSim-Public`, with PowerShell 7, GitHub CLI authentication, and NativeSim installed:

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\Start-StarterNativeSim.ps1 -Minutes 30
```

The launcher checks both clean `main` checkouts and their live remotes, repository visibility, mirror provenance, NativeSim workflow/gate files, and duplicate runs. It dispatches and waits for Swift Preflight against the exact public mirror SHA. It starts NativeSim only after Preflight succeeds and rechecks that the public SHA did not move. NativeSim is invoked through the installed `native-sim.ps1` CLI with `--public --no-open`; do not run `src/cli.js` directly, edit the workflow, create a session key, or reconstruct a stream URL.

To also have NativeSim download its artifact automatically after the session becomes available, add `-ExportArchive`. For a separate GitHub CLI download and exact-run verification, use the `starter-simulator-archive` skill.

To inspect the recorded session later, run `native-sim.ps1 status` from the public mirror folder. To end a session early, use `native-sim.ps1 down` only when the user explicitly asks to stop it. Never reconstruct or report a keyed stream URL from GitHub status or session metadata.

Return only the full Actions and simulator URLs emitted by this invocation, plus public SHA and Preflight outcome. Never persist the simulator key in files, logs, environment variables, or GitHub status. Do not report a live session until the CLI emits its complete simulator URL.
