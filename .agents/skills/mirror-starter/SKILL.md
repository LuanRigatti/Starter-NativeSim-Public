---
name: mirror-starter
description: Review and publish the approved Starter main snapshot one way to Starter-NativeSim-Public after the allowlist and security gates pass. Use only when the user asks to mirror or publish Starter to its NativeSim mirror.
---

# Mirror Starter to NativeSim Public

Use this skill only for an explicit request to mirror/publish Starter, or an explicit `$mirror-starter` invocation. Skill inspection, documentation, and preparation do not authorize publication.

## Fixed repositories

- Private source: `C:\Projetos\Starter`, `LuanRigatti/Starter`, branch `main`.
- Public mirror: `C:\Projetos\Starter-NativeSim-Public`, `LuanRigatti/Starter-NativeSim-Public`, branch `main`.
- The direction is always private Starter to public mirror. Never copy or merge from public to private.
- Never operate on any path other than these two fixed Starter folders.

## Publish flow

Run in PowerShell 7 or later from the Starter folder:

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\mirror-starter.ps1
```

The default run copies the explicit allowlist into the public mirror and stages those files as a review preview. Inspect the script's safety result and the complete staged diff before publishing:

```powershell
git -C C:\Projetos\Starter-NativeSim-Public diff --cached --check
git -C C:\Projetos\Starter-NativeSim-Public diff --cached --name-status
git -C C:\Projetos\Starter-NativeSim-Public diff --cached
```

Confirm that the source is clean on `main` and exactly matches the private GitHub remote, the public mirror is `PUBLIC`, every staged file is allowlisted, no credentials or original-application references were found, and only the intended Starter template files are staged. The script blocks `.env`, credentials, Firebase files, certificates, build output, and unapproved paths. It records the source commit in `.nativesim-source` and the mirror commit trailers.

When those checks pass, publish the reviewed snapshot:

```powershell
pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File .\scripts\mirror-starter.ps1 -Publish
```

The script creates a mirror commit and uses a normal fast-forward push. It verifies the source commit, public remote SHA, and visibility. It never force-pushes. Stop if any gate fails; do not work around a failed allowlist or scanner result.

## Report

Return the private source SHA, public mirror commit SHA, changed paths, scan result, branch/remote equality, and whether a commit/push occurred. A preview leaves staged changes in the public mirror and is not a completed publication.
