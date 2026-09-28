# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

FileTidy is a local Windows utility for organising a folder (usually Downloads), bulk-renaming files, and finding exact duplicates. The whole application is one script, `FileTidy.ps1` (Windows PowerShell 5.1 + WinForms), started by `Start FileTidy.bat`. There is no package manifest, no build step, no test suite, no linter and no CI.

## Commands

```powershell
# Run the app (exactly what the .bat does). Windows only.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\FileTidy.ps1

# Syntax check without running (works with pwsh on any OS)
$t = $null; $e = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path FileTidy.ps1).Path, [ref]$t, [ref]$e) | Out-Null
$e   # no output = no parse errors
```

`System.Windows.Forms` loads only on Windows. From Linux/macOS (including agent sandboxes) you can read, edit and parse-check the script but not launch it; say so rather than claiming a change was tested. For manual end-to-end checks use `/verify`, which has a FileTidy recipe and a fixture-folder script.

## Architecture

`FileTidy.ps1` reads top to bottom:

1. **Helpers**: `New-PathRow` (label + textbox + "Choose folder..." button, returns the textbox), `Choose-Folder` (`FolderBrowserDialog`), `New-Grid` (read-only, full-row-select `DataGridView`), `Get-UniquePath` (appends ` (n)` until a path is free; the reason nothing is ever overwritten), `Show-Error` (message box).
2. **Form**: title, subtitle, and a `TabControl` anchored on all sides.
3. **Three tabs**, each built the same way: a `Panel` docked `Top` with the path row and options, a `Panel` docked `Bottom` with the buttons (and, for duplicates, a status label), and a grid docked `Fill` between them.

Every tool follows **preview → plan → confirm → apply**:

- The *Preview/Scan* handler resolves the folder, rebuilds a plan held in a script-scope variable (`$script:cleanPlan`, `$script:renamePlan`, `$script:dupeGroups`), fills the grid from it, and enables the action button only when the plan is non-empty.
- The *Apply* handler asks for confirmation with a `MessageBox`, executes the stored plan, reports, then re-runs Preview so the grid reflects the disk again.

Safety properties the code relies on; keep them when changing anything:

- Cleaner and Renamer act only on files *directly* in the chosen folder (`Get-ChildItem -File`, no `-Recurse`). The Duplicate Finder is the only recursive tool.
- Destinations always come from `Get-UniquePath`; `Move-Item` is never called with `-Force`.
- The Renamer renames in two phases through `.__filetidy_<n>` temporary names so swaps and chains work.
- Duplicates go to the Recycle Bin via `Microsoft.VisualBasic.FileIO.FileSystem.DeleteFile`, never `Remove-Item`. The first file in each group is tagged `KEEP` and is skipped even if selected.
- Every filesystem cmdlet uses `-LiteralPath`: names in a Downloads folder can contain `[` and `]`, which `-Path` treats as wildcards.

## Pitfalls specific to this script

- **Event handlers are not closures.** A `{ ... }` passed to `Add_Click` runs later in the *script's* scope, not in the function that created it. Handlers written at script level can read script-level variables directly and must write them with `$script:`. A handler created inside a function has to capture the function's locals with `.GetNewClosure()` or it sees `$null`; `New-PathRow` is the one place this pattern occurs.
- **Path comparison is case-insensitive** with `-eq`/`-ne`. Use `-ceq`/`-cne` when a case-only difference matters, such as deciding whether a rename is a no-op.
- **`Get-UniquePath` consults only the disk.** Two planned moves can still resolve to the same free name within one preview; anything that batches moves should also track targets already claimed by the plan.
- **Encoding.** The script is saved without a BOM and Windows PowerShell 5.1 reads BOM-less files as ANSI. Keep new string literals ASCII (build "..." with `[char]0x2026` if you need it) or save the file as UTF-8 *with* BOM.
- **Style.** The file is written as long single-line statements joined with `;`. Splitting a statement you are already changing across lines is fine; do not reformat lines the change does not touch.
- Long-running work inside a handler (hashing thousands of files, for instance) blocks the UI thread; `$form.Refresh()` only repaints once.

## Agent skills

Project skills live in `.claude/skills/` (its README lists provenance): `security-review`, `simplify` and `verify` for changes to `FileTidy.ps1`; `init` to refresh this file; `wireframe` and then `frontend-design` for UI work. Each ends with a "FileTidy notes" section describing how it applies to this repo.
