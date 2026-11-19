---
name: consilium-review
description: Review a branch, PR, or diff with two or more outside models through OpenCode, verify each finding against the code, then deliver a review. Never edits the branch under review. Use for "consilium review", "review this with other models", "multi-model code review", "second opinion on this PR", or before merging a non-trivial change that one model wrote.
---

# Consilium review

Outside models each read the repo (read-only) and review the same diff from the same brief. You verify every finding yourself before you report it. The deliverable is a review: verified findings with the evidence, suggested patches where you have one, and the claims you rejected with a reason. The branch under review is never changed, committed to, or pushed: a review is advice to the author, not a fix on their behalf.

Reuses `~/.claude/skills/consilium/scripts/consult.sh`. The review panel is `CONSILIUM_REVIEW_MODELS` in `~/.config/consilium/config`. Never include the model that wrote the code; drop it from the panel for that run if needed.

## Step 0, Scratch worktree

Check the branch out in a scratch worktree, never in the user's working copy. Put it under the repo's parent directory (for example `../review-<id>`), not under `/tmp`: OpenCode auto-denies reads outside the directory it is given, and a `/tmp` path is denied even when passed as that directory, so the model returns no answer. Everything you run or write during the review happens in this worktree and is deleted at the end.

## Step 1, Write the brief

Write `/tmp/consilium-review-brief.md` with:

- **What to review**: worktree path, branch, and the exact diff command (`git diff <base>...HEAD`). Tell them to start with `git log --oneline <base>..HEAD` and the diff, then read surrounding code as needed. Point at CLAUDE.md and any security policy.
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
  ~/.claude/skills/consilium/scripts/consult.sh /tmp/consilium-review-brief.md <worktree-dir>
```

Run with a 600000 ms timeout, in the background. One hung model is cut off after `CONSILIUM_TIMEOUT` seconds (default 480) and reported as `## ERROR`; rerun a failed model alone with `CONSILIUM_MODELS=<model>`, and if it fails again synthesize from the rest and tell the user which model failed. Read the code yourself while the panel runs, so verification starts from your own understanding, not from theirs.

## Step 3, Verify, then synthesize

A model finding is a claim, not a fact. For each one:

- Open the file at the line. Confirm the code does what the finding says.
- For a bug, reproduce it: a throwaway test in the scratch worktree, a REPL call, or a `git apply --check` probe. Throwaway tests live outside the suite's normal paths and are deleted before you finish.
- For a test weakness, break the behaviour in the scratch worktree and run the test. If it still passes, the finding holds.
- Mark each finding **confirmed**, **rejected (why)**, or **unverified**.
- Weight by evidence, not by model: a finding that names a concrete triggering input is worth verifying first; a finding that restates what the code does, or a review that is mostly confirmations, is low signal.
- Add your own findings from reading the surrounding code. Comments in the repo that contradict a claim the diff makes are the highest-yield place to look.

Then produce:

- **Confirmed findings**, most severe first, each with how you verified it.
- **Agreement**: findings two models raised independently. Highest signal, but still verified.
- **Rejected**: what a model claimed, and the line that disproves it.
- **Verdict**: yours, not a vote.

## Step 4, Suggest, don't fix

For each confirmed blocker or should-fix, work out the smallest patch and prove it in the scratch worktree: the probe from Step 3 must fail without it and pass with it, and the project's linter must pass on the touched files. Then hand it over as part of the review, not as a commit:

- Put the patch in the review comment as a suggestion block or a short diff, together with the test that proves it.
- A finding the author weighed deliberately (their comment or description shows the trade-off) is reported as "for your call" with the evidence that contradicts their reasoning, not as a patch.
- Never commit to, push to, or rewrite the branch under review, even when the user owns it: the author decides what lands.

## Step 5, Report

Report to the user first: what was found, what was rejected and why, which model found what, which panel member failed. Then post the findings on the PR or MR, following the host project's review skill for inline comments if it has one. Default to the host's draft or pending-review mechanism so the user reads the set before the author is notified; ask before posting anything public. Delete the scratch worktree and its probes when the review is posted.
