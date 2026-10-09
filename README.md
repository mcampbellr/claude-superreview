# superreview

A maximum-rigor branch review skill for [Claude Code](https://claude.com/claude-code).

The parent session gathers the diff **once**, fans out three reviewers **in parallel** over the
exact same context, then synthesizes one deduplicated, severity-ranked verdict. Findings raised
independently by two or more lanes are weighted as the highest-signal blockers.

The three lanes are static reviewers only — they never run tests, lint, typecheck, builds,
installs, migrations, generators or servers. When dynamic evidence is genuinely needed, a lane
emits a *verification request* and the parent merges those into one serial plan for CI or a
separately isolated verifier.

## Contents

| Path | Role |
| --- | --- |
| `skills/superreview/SKILL.md` | The skill: base resolution, scope gathering, fan-out, synthesis, auto-fix phase, verdict format |
| `skills/superreview/references/review-policy.md` | Canonical severities, review criteria, finding fields, verdict rules, verification-request fields — single source of truth, not restated in lane prompts |
| `agents/superreview-correctness-security-subagent.md` | Lane 1 — correctness, breaking changes, security, devex regressions, feature-flag/gate leaks, UI reachability |
| `agents/superreview-code-quality-subagent.md` | Lane 2 — maintainability, restructurings, file-size rule, boundaries, type cleanliness, design fidelity |
| `agents/code-review.md` | Lane 3 — stack/framework detection, CLAUDE.md-as-law, data integrity (N+1, cascades, indexes, transactions), frontend state/cache |
| `skills/superreview/scripts/validate-static-review.sh` | Asserts the bundle is complete and that no lane agent exposes a dynamic or mutating tool |
| `skills/superreview/scripts/sync-mariobot-policy.sh` | Copies the canonical policy into a mariobot checkout (`--check` to detect drift) |

## Install

```sh
git clone https://github.com/mcampbellr/claude-superreview.git
cd claude-superreview
./install.sh            # into ~/.claude
./install.sh /custom/.claude
```

`install.sh` replaces `<target>/skills/superreview`, copies the three agents into
`<target>/agents/`, and runs the validator. It overwrites those paths and touches nothing else in
the config dir.

Installing user-wide (`~/.claude`) makes the skill available in every project. To scope it to a
single repo instead, point the script at that repo's `.claude` directory.

## Layout requirement

The two `superreview-*` agents read the canonical policy at
`~/.claude/skills/superreview/references/review-policy.md`. That path is hardcoded, so a
user-wide install under `~/.claude` works as-is; a project-scoped install needs the policy
reachable at that home path too (or the agent files edited to point elsewhere).

## Usage

```
/superreview
```

Or ask for a "superreview" / "deep branch audit" in a session. It reviews the current branch
against a freshly fetched base (`develop` → `main` → `master`, or whatever CLAUDE.md names), or a
PR / path target you give it.

Verdict: any CRITICAL → `BLOCKED`; any MAJOR without CRITICAL → `REQUIRES CHANGES`; only MINOR or
none → `APPROVED`. On `BLOCKED` or `REQUIRES CHANGES` the skill applies the CRITICAL/MAJOR fixes
in the same turn and re-issues the verdict. It never commits or pushes unless asked.
