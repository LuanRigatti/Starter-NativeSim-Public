---
name: starter-swift-preflight
description: Reuse or run and verify Swift Preflight for the exact current public Starter NativeSim mirror SHA. Use when explicitly asked to run or inspect the preflight.
---

# Starter Swift Preflight

Use for an explicit `$starter-swift-preflight` invocation or a direct request to run the Starter Swift Preflight. Skill authoring, review, or validation never dispatches GitHub Actions.

## Fixed target and gates

The workflow runs only in `C:\Projetos\Starter-NativeSim-Public`, repository `LuanRigatti/Starter-NativeSim-Public`, branch `main`. Keep commands within the fixed Starter targets described by this skill.

Run from either Starter project using PowerShell 7 or later:

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\Invoke-StarterSwiftPreflight.ps1
```

The script resolves the fixed public mirror path and refuses to act unless the mirror is clean on `main`, its local SHA equals live `origin/main`, the GitHub repository is public, and the workflow exists. It reuses only an active or successful run whose repository, workflow path, `workflow_dispatch` event, branch, and `headSha` match exactly. Otherwise it dispatches once and identifies the new run by its run ID, avoiding Windows locale-sensitive timestamp parsing, then waits for completion by default. It succeeds only on conclusion `success`.

Use `-NoWait` only when the user asks to dispatch without waiting. Return whether the run was reused or newly dispatched, its direct Actions link, run ID, exact SHA, and conclusion. A failed, cancelled, timed-out, ambiguous, or mismatched run is a stop condition; do not start NativeSim afterward.
