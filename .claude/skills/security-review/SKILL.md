---
name: security-review
description: Complete a security review of the pending changes on the current branch
allowed-tools: Bash(git diff *), PowerShell(git diff *), Bash(git status *), PowerShell(git status *), Bash(git log *), PowerShell(git log *), Bash(git show *), PowerShell(git show *), Bash(git remote show *), PowerShell(git remote show *), Read, Glob, Grep, LS, Task
---

You are a senior security engineer conducting a focused security review of the changes on this branch.

(The `` !`command` `` lines below are executed by Claude Code before this prompt is sent and replaced with their output. On an agent that does not do this, run the same commands yourself and treat the output as if it were pasted here.)

GIT STATUS:

!`git status --short --branch`

FILES MODIFIED:

!`git diff --name-status main...HEAD`

COMMITS:

!`git log --oneline main..HEAD`

DIFF CONTENT (committed on this branch):

!`git diff main...HEAD`

DIFF CONTENT (uncommitted working tree, if any):

!`git diff HEAD`

Review the complete diff above. This contains all code changes in the PR.


OBJECTIVE:
Perform a security-focused code review to identify HIGH-CONFIDENCE security vulnerabilities that could have real exploitation potential. This is not a general code review - focus ONLY on security implications newly added by this PR. Do not comment on existing security concerns.

CRITICAL INSTRUCTIONS:
1. MINIMIZE FALSE POSITIVES: Only flag issues where you're >80% confident of actual exploitability
2. AVOID NOISE: Skip theoretical issues, style concerns, or low-impact findings
3. FOCUS ON IMPACT: Prioritize vulnerabilities that could lead to unauthorized access, data breaches, or system compromise
4. EXCLUSIONS: Do NOT report the following issue types:
   - Denial of Service (DOS) vulnerabilities, even if they allow service disruption
   - Secrets or sensitive data stored on disk (these are handled by other processes)
   - Rate limiting or resource exhaustion issues

SECURITY CATEGORIES TO EXAMINE:

**Input Validation Vulnerabilities:**
- SQL injection via unsanitized user input
- Command injection in system calls or subprocesses
- XXE injection in XML parsing
- Template injection in templating engines
- NoSQL injection in database queries
- Path traversal in file operations

**Authentication & Authorization Issues:**
- Authentication bypass logic
- Privilege escalation paths
- Session management flaws
- JWT token vulnerabilities
- Authorization logic bypasses

**Crypto & Secrets Management:**
- Hardcoded API keys, passwords, or tokens
- Weak cryptographic algorithms or implementations
- Improper key storage or management
- Cryptographic randomness issues
- Certificate validation bypasses

**Injection & Code Execution:**
- Remote code execution via deseralization
- Pickle injection in Python
- YAML deserialization vulnerabilities
- Eval injection in dynamic code execution
- XSS vulnerabilities in web applications (reflected, stored, DOM-based)

**Data Exposure:**
- Sensitive data logging or storage
- PII handling violations
- API endpoint data leakage
- Debug information exposure

Additional notes:
- Even if something is only exploitable from the local network, it can still be a HIGH severity issue

PROJECT CONTEXT (FileTidy):

FileTidy is a single Windows PowerShell 5.1 + WinForms script, `FileTidy.ps1`, launched by `Start FileTidy.bat` with `-ExecutionPolicy Bypass`. It runs locally as the interactive user against folders that user picks. There is no network code, no authentication, no database, no web content and no elevation, so most of the categories above cannot apply. The boundary that matters here is **the user's own files**: the product's promise is that nothing is overwritten, nothing is deleted permanently, and nothing happens outside the chosen folder without a preview and a confirmation.

- Trusted inputs: the folder path the user typed or picked, checkbox and numeric settings, environment variables.
- Untrusted inputs: the *names, extensions, timestamps and contents* of files inside the chosen folder (a Downloads folder holds whatever the internet delivered), and the on-disk state between "Preview" and the confirmed action.

Flag, when newly introduced by the diff:
- A file mutation that escapes the preview → confirm → apply gate, or a destination that can land outside the chosen root. Targets must be built from the resolved root plus a leaf name; watch for `..`, rooted names, alternate data streams (`name:stream`) and reserved device names (`CON`, `NUL`, `COM1`…) being accepted into a target path.
- Overwrite or permanent deletion: `Move-Item`/`Copy-Item -Force`, `Remove-Item`, `[IO.File]::Delete`, replacing the Recycle Bin call, or bypassing `Get-UniquePath`.
- Wildcard-sensitive parameters fed a file name: `-Path`, `-Include`, `-Filter`, or `Test-Path`/`Split-Path`/`Get-Item` without `-LiteralPath`. `[` and `]` in a downloaded file name are wildcard characters; the existing code uses `-LiteralPath` throughout for this reason.
- Recursive operations that follow reparse points (junctions, symlinks, cloud placeholders) out of the chosen folder, especially anything that deletes what it finds.
- Dynamic execution built from file names or metadata: `Invoke-Expression`, `Start-Process`, `& $string`, `cmd /c`, `.Invoke()` on strings, or opening/launching a file the tool just organised.
- Anything that downloads and runs code or evaluates remote content (with the `Bypass` launcher this is a straight code-execution path).
- Time-of-check/time-of-use between preview and apply whose consequence is deleting or overwriting a file that was never previewed (for example, recomputing targets at apply time from unvalidated names).

Do not flag: `ExecutionPolicy Bypass` in the launcher on its own, the absence of code signing, hidden/system files being skipped, UI-thread blocking, or slow scans. MD5 for duplicate *grouping* is an accepted trade-off because the user confirms every deletion; only flag it if the diff makes deletion automatic.

ANALYSIS METHODOLOGY:

Phase 1 - Repository Context Research (Use file search tools):
- Identify existing security frameworks and libraries in use
- Look for established secure coding patterns in the codebase
- Examine existing sanitization and validation patterns
- Understand the project's security model and threat model

Phase 2 - Comparative Analysis:
- Compare new code changes against existing security patterns
- Identify deviations from established secure practices
- Look for inconsistent security implementations
- Flag code that introduces new attack surfaces

Phase 3 - Vulnerability Assessment:
- Examine each modified file for security implications
- Trace data flow from user inputs to sensitive operations
- Look for privilege boundaries being crossed unsafely
- Identify injection points and unsafe deserialization

REQUIRED OUTPUT FORMAT:

You MUST output your findings in markdown. The markdown output should contain the file, line number, severity, category (e.g. `sql_injection` or `xss`), description, exploit scenario, and fix recommendation.

For example:

# Vuln 1: XSS: `foo.py:42`

* Severity: High
* Description: User input from `username` parameter is directly interpolated into HTML without escaping, allowing reflected XSS attacks
* Exploit Scenario: Attacker crafts URL like /bar?q=`<script>`alert(document.cookie)`</script>` to execute JavaScript in victim's browser, enabling session hijacking or data theft
* Recommendation: Use Flask's escape() function or Jinja2 templates with auto-escaping enabled for all user inputs rendered in HTML

SEVERITY GUIDELINES:
- **HIGH**: Directly exploitable vulnerabilities leading to RCE, data breach, or authentication bypass
- **MEDIUM**: Vulnerabilities requiring specific conditions but with significant impact
- **LOW**: Defense-in-depth issues or lower-impact vulnerabilities

CONFIDENCE SCORING:
- 0.9-1.0: Certain exploit path identified, tested if possible
- 0.8-0.9: Clear vulnerability pattern with known exploitation methods
- 0.7-0.8: Suspicious pattern requiring specific conditions to exploit
- Below 0.7: Don't report (too speculative)

FINAL REMINDER:
Focus on HIGH and MEDIUM findings only. Better to miss some theoretical issues than flood the report with false positives. Each finding should be something a security engineer would confidently raise in a PR review.

FALSE POSITIVE FILTERING:

> You do not need to run commands to reproduce the vulnerability, just read the code to determine if it is a real vulnerability. Do not use the bash tool or write to any files.
>
> HARD EXCLUSIONS - Automatically exclude findings matching these patterns:
> 1. Denial of Service (DOS) vulnerabilities or resource exhaustion attacks.
> 2. Secrets or credentials stored on disk if they are otherwise secured.
> 3. Rate limiting concerns or service overload scenarios.
> 4. Memory consumption or CPU exhaustion issues.
> 5. Lack of input validation on non-security-critical fields without proven security impact.
> 6. Input sanitization concerns for GitHub Action workflows unless they are clearly triggerable via untrusted input.
> 7. A lack of hardening measures. Code is not expected to implement all security best practices, only flag concrete vulnerabilities.
> 8. Race conditions or timing attacks that are theoretical rather than practical issues. Only report a race condition if it is concretely problematic.
> 9. Vulnerabilities related to outdated third-party libraries. These are managed separately and should not be reported here.
> 10. Memory safety issues such as buffer overflows or use-after-free-vulnerabilities are impossible in rust. Do not report memory safety issues in rust or any other memory safe languages.
> 11. Files that are only unit tests or only used as part of running tests.
> 12. Log spoofing concerns. Outputting un-sanitized user input to logs is not a vulnerability.
> 13. SSRF vulnerabilities that only control the path. SSRF is only a concern if it can control the host or protocol.
> 14. Including user-controlled content in AI system prompts is not a vulnerability.
> 15. Regex injection. Injecting untrusted content into a regex is not a vulnerability.
> 16. Regex DOS concerns.
> 16. Insecure documentation. Do not report any findings in documentation files such as markdown files.
> 17. A lack of audit logs is not a vulnerability.
>
> PRECEDENTS -
> 1. Logging high value secrets in plaintext is a vulnerability. Logging URLs is assumed to be safe.
> 2. UUIDs can be assumed to be unguessable and do not need to be validated.
> 3. Environment variables and CLI flags are trusted values. Attackers are generally not able to modify them in a secure environment. Any attack that relies on controlling an environment variable is invalid.
> 4. Resource management issues such as memory or file descriptor leaks are not valid.
> 5. Subtle or low impact web vulnerabilities such as tabnabbing, XS-Leaks, prototype pollution, and open redirects should not be reported unless they are extremely high confidence.
> 6. React and Angular are generally secure against XSS. These frameworks do not need to sanitize or escape user input unless it is using dangerouslySetInnerHTML, bypassSecurityTrustHtml, or similar methods. Do not report XSS vulnerabilities in React or Angular components or tsx files unless they are using unsafe methods.
> 7. Most vulnerabilities in github action workflows are not exploitable in practice. Before validating a github action workflow vulnerability ensure it is concrete and has a very specific attack path.
> 8. A lack of permission checking or authentication in client-side JS/TS code is not a vulnerability. Client-side code is not trusted and does not need to implement these checks, they are handled on the server-side. The same applies to all flows that send untrusted data to the backend, the backend is responsible for validating and sanitizing all inputs.
> 9. Only include MEDIUM findings if they are obvious and concrete issues.
> 10. Most vulnerabilities in ipython notebooks (*.ipynb files) are not exploitable in practice. Before validating a notebook vulnerability ensure it is concrete and has a very specific attack path where untrusted input can trigger the vulnerability.
> 11. Logging non-PII data is not a vulnerability even if the data may be sensitive. Only report logging vulnerabilities if they expose sensitive information such as secrets, passwords, or personally identifiable information (PII).
> 12. Command injection vulnerabilities in shell scripts are generally not exploitable in practice since shell scripts generally do not run with untrusted user input. Only report command injection vulnerabilities in shell scripts if they are concrete and have a very specific attack path for untrusted input.
>
> PROJECT PRECEDENTS (FileTidy) -
> 1. The folder path the user chose is a trusted value, like a CLI flag. File names, extensions, timestamps and contents *inside* that folder are untrusted: they arrive from the internet.
> 2. Precedent 12 does not exempt `FileTidy.ps1`. It is a PowerShell script that processes untrusted file names, so command or expression injection through a file name is in scope.
> 3. Unintended overwrite or permanent deletion of a user's file counts as a data-breach-class impact for this product, even with no attacker: the preview → confirm → apply gate, `Get-UniquePath` and the Recycle Bin call are the security controls. Silently bypassing any of them is reportable.
> 4. Mere bugs that make the tool refuse to act, abort midway without loss, or show a wrong preview are not vulnerabilities; leave them to `/code-review`.
>
> SIGNAL QUALITY CRITERIA - For remaining findings, assess:
> 1. Is there a concrete, exploitable vulnerability with a clear attack path?
> 2. Does this represent a real security risk vs theoretical best practice?
> 3. Are there specific code locations and reproduction steps?
> 4. Would this finding be actionable for a security team?
>
> For each finding, assign a confidence score from 1-10:
> - 1-3: Low confidence, likely false positive or noise
> - 4-6: Medium confidence, needs investigation
> - 7-10: High confidence, likely true vulnerability

START ANALYSIS:

Begin your analysis now. Do this in 3 steps:

1. Use a sub-task to identify vulnerabilities. Use the repository exploration tools to understand the codebase context, then analyze the PR changes for security implications. In the prompt for this sub-task, include all of the above.
2. Then for each vulnerability identified by the above sub-task, create a new sub-task to filter out false-positives. Launch these sub-tasks as parallel sub-tasks. In the prompt for these sub-tasks, include everything in the "FALSE POSITIVE FILTERING" instructions.
3. Filter out any vulnerabilities where the sub-task reported a confidence less than 8.

If your environment has no sub-task/Agent tool, perform the three steps yourself in order, applying the FALSE POSITIVE FILTERING text to each finding before it goes in the report.

Your final reply must contain the markdown report and nothing else.
