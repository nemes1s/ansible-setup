---
name: consilium-review
description: Review a branch, PR, or diff with two or more outside models through OpenCode, verify each finding against the code, then fix what holds up. Use for "consilium review", "review this with other models", "multi-model code review", "second opinion on this PR", or before merging a non-trivial change that one model wrote.
---

# Consilium review

Outside models each read the repo (read-only) and review the same diff from the same brief. You verify every finding yourself before you act on it. The deliverable is a verified findings list, the fixes you applied, and the ones you rejected with a reason.

Reuses `~/.claude/skills/consilium/scripts/consult.sh`. The review panel is `CONSILIUM_REVIEW_MODELS` in `~/.config/consilium/config`. Never include the model that wrote the code; drop it from the panel for that run if needed.

## Step 1, Write the brief

Write `/tmp/consilium-review-brief.md` with:

- **What to review**: repo path, branch, and the exact diff command (`git diff <base>..HEAD`). Tell them to start with `git log --oneline <base>..HEAD` and the diff, then read surrounding code as needed. Point at CLAUDE.md and any security policy.
- **What the change does**: one paragraph, plus the refusals, guards, and side effects it claims to handle. Reviewers check claims against code.
- **Decisions already made and NOT up for review**: so they don't re-litigate the design.
- **Rules**: read-only, no edits, do not run the test suite if it already ran.
- **Answer in this exact structure**:
  1. Bugs and correctness, each as `path:line — what is wrong — concrete input that triggers it — severity (blocker / should-fix / nit)`; "unverified" if they could not confirm by reading.
  2. Security, same format.
  3. Tests: any added test that passes even if the behaviour it names is broken; any branch with no test.
  4. Simplification: concrete deletions or merges, not "could be simpler".
  5. Verdict: approve / approve with nits / request changes, one sentence why.

## Step 2, Consult

```bash
. ~/.config/consilium/config && CONSILIUM_MODELS="$CONSILIUM_REVIEW_MODELS" \
  ~/.claude/skills/consilium/scripts/consult.sh /tmp/consilium-review-brief.md <repo-dir>
```

Run with a 600000 ms timeout, in the background. One hung model is cut off after `CONSILIUM_TIMEOUT` seconds (default 480) and reported as `## ERROR`; synthesize from the rest and tell the user which model failed.

## Step 3, Verify, then synthesize

A model finding is a claim, not a fact. For each one:

- Open the file at the line. Confirm the code does what the finding says.
- For a bug, reproduce it: a one-off test, a REPL call, or a `git apply --check` probe in a scratch dir. Never in the repo.
- For a test weakness, break the behaviour locally and run the test. If it still passes, the finding holds.
- Mark each finding **confirmed**, **rejected (why)**, or **unverified**.
- Weight by evidence, not by model: a finding that names a concrete triggering input is worth verifying first; a finding that restates what the code does, or a review that is mostly confirmations, is low signal.

Then produce:

- **Confirmed findings**, most severe first, each with how you verified it.
- **Agreement**: findings two models raised independently. Highest signal, but still verified.
- **Rejected**: what a model claimed, and the line that disproves it.
- **Verdict**: yours, not a vote.

## Step 4, Fix and report

Fix confirmed blockers and should-fixes on the branch, each as its own small commit with a test that fails without the fix. Leave nits for the PR unless they are one-liners. Push, then report: what was found, what was fixed, what was rejected and why, which model found what. Post the summary as a PR comment if the user wants the trail on the PR.
