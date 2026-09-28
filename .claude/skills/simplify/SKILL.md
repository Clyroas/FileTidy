---
name: simplify
description: |-
  Review the changed code for reuse, simplification, efficiency, and altitude cleanups, then apply the fixes. Quality only — it does not hunt for bugs; use /code-review for that.
---

`/simplify → 4 cleanup agents in parallel → apply the fixes`

You are improving the quality of the changed code, not hunting for bugs. Review
it for reuse, simplification, efficiency, and altitude issues, then fix what you
find. Do not look for correctness bugs — that is what `/code-review` is for.

## Phase 0 — Gather the diff

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1`
if there's no upstream) to get the unified diff under review. If there are
uncommitted changes, or the range diff is empty, also run `git diff HEAD` and
include the working-tree changes in scope — the review often runs before the
commit. If a PR number, branch name, or file path was passed as an argument,
review that target instead. Treat this diff as the review scope.

## Phase 1 — Review (4 cleanup agents in parallel)

Launch **4 independent review agents** via the Agent tool, all in a
single message so they run concurrently. Pass each agent the diff and one of
the four angles below. Each returns its findings with `file`, `line`, a
one-line `summary`, and the concrete cost (what is duplicated, wasted, or
harder to maintain).

### Reuse

Flag new code that re-implements something the codebase
already has — Grep shared/utility modules and files adjacent to the change,
and name the existing helper to call instead.

### Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state,
copy-paste with slight variation, deep nesting, dead code left behind. Name
the simpler form that does the same job.

### Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O,
independent operations run sequentially, blocking work added to startup or
hot paths. Also flag long-lived objects built from closures or captured
environments — they keep the entire enclosing scope alive for the object's
lifetime (a memory leak when that scope holds large values); prefer a
class/struct that copies only the fields it needs. Name the cheaper
alternative.

### Altitude

Check that each change fixes the root cause at the right depth rather than
patching a symptom with a fragile bandaid. Special cases layered on shared
infrastructure are a sign the fix isn't deep enough — prefer the simpler, more
general change to the underlying mechanism over adding special cases, and name
that change.

## Phase 2 — Apply the fixes

Wait for all four agents to complete, dedup findings that point at the same
line or mechanism, and fix each remaining one directly. Skip any finding whose
fix would change intended behavior, require changes well outside the reviewed
diff, or that you judge to be a false positive — note the skip rather than
arguing with it. Finish with a brief summary of what was fixed and what was
skipped (or confirm the code was already clean).

## FileTidy notes

- **Scope stays the diff.** `FileTidy.ps1` is written as very long single-line
  statements (some over 1,000 characters). Reformatting the whole file is not a
  simplify task, but when a finding lands on one of those lines, splitting *that
  statement* across lines is a legitimate part of the fix.
- **Reuse: the helpers already exist.** New UI belongs on `New-PathRow`,
  `New-Grid`, `Show-Error` and `Get-UniquePath`, and every tab has the same shape
  (options `Panel` docked `Top`, buttons `Panel` docked `Bottom`, `DataGridView`
  docked `Fill`; a Preview handler fills a `$script:` plan, an Apply handler
  consumes it). A new tool or control that rebuilds any of that by hand is a
  Reuse finding.
- **Efficiency: PowerShell specifics.** `$array += $item` inside a loop copies
  the whole array every iteration; prefer
  `[System.Collections.Generic.List[object]]::new()` and `.Add()` for anything
  that can grow past a few dozen entries (the duplicate scan can see thousands of
  files). Reuse the `FileInfo` you already hold instead of calling `Get-Item`
  again, keep `Add-Type` out of loops, and keep blocking I/O out of event handlers
  where a preview is expected to feel instant.
- **Altitude.** The three tools share one safety mechanism
  (preview → plan → confirm → apply). A fix that adds a special case to one tab
  for a problem that lives in the shared mechanism (target uniqueness, plan
  validation, error reporting) should move into the shared helper instead.
- **No Agent tool?** Run the four review angles yourself, one after another, then
  apply the fixes.
