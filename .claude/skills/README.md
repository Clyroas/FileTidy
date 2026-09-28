# Agent skills for FileTidy

These skills are for coding agents (Claude Code and compatible tools) working *on* this repository. Their only purpose is to make improving FileTidy safer and faster; none of them is needed to use FileTidy.

| Skill | Use it to |
|---|---|
| `security-review` | Review the diff on the current branch for real, exploitable problems. For this repo that mostly means unsafe file operations; the skill carries a FileTidy threat model. |
| `simplify` | Clean up changed code for reuse, simplicity, efficiency and "altitude" before committing. |
| `verify` | Actually run the app against a disposable fixture folder and observe a change end to end (Windows only). Ships `scripts/New-FileTidyFixture.ps1` and a worked GUI example. |
| `init` | Create or refresh `CLAUDE.md`. |
| `wireframe` | Sketch 3–5 layout options for a UI change before touching the WinForms code. |
| `frontend-design` | Aesthetic direction, translated to what WinForms can express; used as written for HTML mock-ups. |

A typical change to `FileTidy.ps1`: edit → `/simplify` → `/security-review` → `/verify` on a Windows machine → commit.

## Provenance

Upstream text was copied from [asgeirtj/system_prompts_leaks](https://github.com/asgeirtj/system_prompts_leaks) at commit `379c908` (2026-09-27):

- `Anthropic/claude-code/skills/{security-review,simplify,verify,init}/`
- `Anthropic/claude-design/skills/{frontend-design,wireframe}/`

Upstream wording is kept intact so the files can be diffed against later captures. Project-specific guidance is added, not substituted:

- every skill ends with a **FileTidy notes** (or **FileTidy recipe**) section;
- `security-review` also gets a `PROJECT CONTEXT (FileTidy)` block and `PROJECT PRECEDENTS` inside the false-positive filter, because that text is what gets handed to sub-tasks; its `<placeholder>` context blocks were replaced with Claude Code `` !`command` `` injections;
- `verify` gains `examples/filetidy-gui.md` and `scripts/New-FileTidyFixture.ps1`.

`frontend-design` previously lived at the repository root as `SKILL.md`; it was moved here (unchanged apart from the appended notes) so Claude Code discovers it.

To diff against upstream again:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/asgeirtj/system_prompts_leaks.git /tmp/spl
git -C /tmp/spl sparse-checkout set Anthropic/claude-code/skills Anthropic/claude-design/skills
diff /tmp/spl/Anthropic/claude-code/skills/simplify/SKILL.md .claude/skills/simplify/SKILL.md
```

## Layout

Claude Code loads `.claude/skills/<name>/SKILL.md`; supporting files sit beside it (`verify/examples/`, `verify/scripts/`). The frontmatter keys (`allowed-tools`, `disable-model-invocation`, `user-invocable`) are upstream's and are ignored by tools that do not know them.
