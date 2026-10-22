---
name: starter-swift-preflight
description: Dispatch, follow, and verify the manual Swift Preflight workflow for the exact current public Starter NativeSim mirror commit. Use when the user explicitly asks to run or inspect this preflight.
---

# Starter Swift Preflight

Use for an explicit `$starter-swift-preflight` invocation or a direct request to run the Starter Swift Preflight. Skill authoring, review, or validation never dispatches GitHub Actions.

## Fixed target and gates

The workflow runs only in `C:\Projetos\Starter-NativeSim-Public`, repository `LuanRigatti/Starter-NativeSim-Public`, branch `main`. Keep commands within the fixed Starter targets described by this skill.

Run from either Starter project using PowerShell 7 or later:

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\Invoke-StarterSwiftPreflight.ps1
```

The script resolves the fixed public mirror path and refuses the run unless the mirror is clean on `main`, its local SHA equals live `origin/main`, the GitHub repository is public, and the workflow is present. It dispatches at most once, resolves the run ID, and requires the run's branch, event, and `headSha` to match the exact public commit. It waits for completion by default and succeeds only on conclusion `success`.

Use `-NoWait` only when the user asks to dispatch without waiting. Return the direct Actions run link, run ID, exact SHA, and conclusion. A failed, cancelled, timed-out, ambiguous, or mismatched run is a stop condition; do not start NativeSim afterward.
