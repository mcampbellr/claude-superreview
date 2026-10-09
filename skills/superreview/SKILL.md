---
name: superreview
description: "Maximum-rigor parallel branch review. Fans out three static reviewers over the SAME scoped diff, synthesizes deduped severity-ranked findings, applies authorized CRITICAL/MAJOR fixes, and emits a deduplicated verification plan without executing dynamic gates. Use for superreview, super review, thermos-style double/triple review, or deep branch/PR audits."
---

# Superreview

A merged, maximum-rigor review set: thermos-style parallel fan-out + synthesis, fused with
the stack-aware `code-review` agent. You (the parent) gather the diff **once**, run three
reviewers **in parallel** over the exact same context, then synthesize one unified verdict.

Nothing slips through, nobody re-runs git three times, and the final output is deduped and
honestly calibrated.

Before reviewing, read `references/review-policy.md`. It is the canonical source for severities,
review criteria, finding fields, verdicts, and verification-request fields. Do not restate or fork
that policy in lane prompts.

## Phase 0 — Establish a trustworthy base (non-negotiable)

Before diffing, resolve and **fetch** the base branch — never reason off a stale local ref:

1. Resolve the base per repo (`develop` → `main` → `master`; honor CLAUDE.md if it names one).
2. `git fetch origin <base>` and diff against `origin/<base>` (not the local branch) unless
   you've confirmed local == remote. Prefer `git -C <path>` over `cd` so a failed `cd` can't
   silently skip the fetch.
3. **Bare + worktree layouts** (`<repo>/.bare` + `<repo>/<branch>/`): the local `main`/`develop`
   worktree is routinely BEHIND `origin`. Resolve the diff with
   `git --git-dir=<repo>/.bare fetch origin <base>` then diff `origin/<base>...HEAD`. A file
   survey of a worktree is NOT proof of what's on `origin/<base>`.

## Phase 1 — Gather scope ONCE

Determine review scope from the user request, PR, current branch, or changed files. Then, in a
**single message**, collect the context in parallel with two `Task` calls:

- `subagent_type: "Explore"` (or `shell`) → run `git diff origin/<base>...HEAD` (plus
  `git diff` / `git diff --cached` for uncommitted work) and capture the full unified diff.
- `subagent_type: "Explore"` → read the **full contents** of every changed file (not just diff
  hunks — reviewers must evaluate cross-file side effects without guessing).

Assemble two labeled sections you will pass verbatim to each reviewer:
`### Git / diff output` and `### Changed file contents`.

## Phase 2 — Fan out three reviewers IN PARALLEL

In **one message**, launch all three with `run_in_background: true`, passing each the **same**
scoped context (the two labeled sections) plus the resolved base and PR URL if any:

1. `subagent_type: "superreview-correctness-security-subagent"`
   — bugs, breaking changes, security, devex regressions, feature-flag/gate leaks, UI-reachability.
2. `subagent_type: "superreview-code-quality-subagent"`
   — maintainability, code-judo restructurings, >1k-line rule, spaghetti, boundaries, design-fidelity.
3. `subagent_type: "code-review"`
   — stack/framework/ORM/UI detection, CLAUDE.md-as-law, data integrity (N+1, cascades, indexes,
   transactions), frontend state/cache, and the `anti-slop` dimension.

Instruct each reviewer to complete its **independent** audit first (fresh eyes), report only
issues in **ADDED/MODIFIED** code, trace cross-file impact, and return prioritized findings with
`file:line` evidence. No nested subagents unless explicitly asked.

### Static-only boundary for every lane

The parallel lanes are reviewers, never verification runners. Their prompts must explicitly say:

- Do not run tests, lint, typecheck, builds, package installation, migrations, generators, dev
  servers, benchmarks, or any other CPU/RAM-intensive or code-executing command.
- Do not start background processes or services.
- Use only read-only inspection. If dynamic evidence would materially change a finding, emit a
  verification request using the canonical fields in `references/review-policy.md`; do not execute
  it.

This boundary applies even when repository instructions normally require running quality gates.
The parent must preserve which lane requested each verification.

## Phase 3 — Synthesize

After all three finish:

- Merge findings, **deduplicated** across reviewers. Weight findings that **two or more** lanes
  independently raised more heavily — those are your highest-signal blockers.
- Resolve disagreements with your own judgment and in-repo verification. Never present a finding
  with unfinished research when you can check it yourself in the repo.
- Calibrate severity honestly (CRITICAL / MAJOR / MINOR). Do NOT inflate priority — over-reporting
  erodes trust. Respect **intended breakage**: if the branch's clear purpose is to remove/break
  something and the scope is well-constrained, don't flag it as a bug (unless it looks unintended,
  under-weighted, or malicious).
- If background summaries are already visible to the user, don't restate them wholesale — surface
  the **unified verdict**, the highest-signal findings, and any remaining uncertainty.
- Merge equivalent verification requests into one plan entry. Preserve all requesting lanes and
  choose the narrowest command/scope that answers the shared question. Order the plan serially;
  never imply that requests should run in parallel.

Write all review feedback in the **project's primary language** (detect from UI strings, comments,
CLAUDE.md, README).

## Final verdict

```
## Superreview — Summary
- Critical: [n]   Major: [n]   Minor: [n]
- Cross-lane (raised by ≥2 reviewers): [n]
- Result: [BLOCKED | REQUIRES CHANGES | APPROVED]
```

Decision: any CRITICAL → **BLOCKED**; any MAJOR (no CRITICAL) → **REQUIRES CHANGES**; only MINOR
or none → **APPROVED**.

## Phase 4 — Fix immediately when BLOCKED or REQUIRES CHANGES (non-negotiable)

When the verdict is **BLOCKED** or **REQUIRES CHANGES**, do **not** stop to ask "¿aplico los
fixes?". Apply the fixes right away in the same turn:

1. **Scope:** fix every CRITICAL and MAJOR finding. Also fix MINOR findings that were raised by ≥2
   lanes when the fix is local and mechanical. List the other MINORs as follow-ups, but do not
   apply them.
2. **Excluded from auto-fix** (surface them in the report, never guess):
   - Findings that need a product/design decision: the spec and the design disagree, or a
     requirement is ambiguous. Ask one precise question and fix everything else meanwhile.
   - Work items not owned by the logged-in user (ownership guardrail), or files another session
     is editing concurrently. If the working tree changes under you during the review, stop and
     confirm who owns those edits before writing.
3. **Fix discipline:**
   - Respect the repo conventions and CLAUDE.md.
   - Add a regression test for each CRITICAL/MAJOR fix when the stack has tests.
   - Never widen scope beyond the finding.
4. **Verify:**
   - Re-check each fixed finding statically against its original failure scenario.
   - Produce a deduplicated, serial **verification plan** for CI or a future isolated
     `review-verifier`; do not execute it in Superreview.
   - Request only the narrowest necessary checks. A lane may suggest a command, but only the parent
     may include it in the plan. Full suites and e2e are never automatic.
   - Never run tests, lint, typecheck, builds, installs, migrations, generators, or services from
     this skill or any lane. Report dynamic verification as `not run (delegated)`.
5. **Re-issue the verdict:** print the Final verdict block again for the post-fix state, with each
   finding marked fixed / pending decision / follow-up.
6. **Git:** do not commit or push unless the user asked. Leave the working tree for review.

## Verification plan output

When any lane or fixed finding needs dynamic verification, end with one deduplicated table using
the fields defined in `references/review-policy.md`: `key`, `requested_by`, `kind`, `scope`,
`command`, and `reason`. Commands are recommendations for CI/a future isolated verifier, not shell
instructions for the current session. If no dynamic evidence is needed, write
`Dynamic verification: not requested`.

The plan is executed by **one** verifier, serially, never by several agents at once. When the repo
defines a sanctioned serialised entry point for heavy gates (a wrapper script, a `verify` script, a
documented lock), every `command` in the table must use it rather than invoking `jest`, `vitest`,
`turbo` or a package script directly — those default to one worker per CPU and several agents
running them concurrently can exhaust the host's RAM.
