---
name: consilium
description: Plan a task (usually coding) by consulting a consilium of outside models through OpenCode, then synthesizing one plan. Use for "consilium", "ask the council", "get second opinions on the plan", "plan this with other models", or before a non-trivial change when one model's plan would lock in the wrong shape.
---

# Consilium

The outside models in your configured panel each read the repo (read-only) and answer the same planning brief. You synthesize. The deliverable is a plan for the user to approve, not code.

## Step 1, Write the brief

Write `/tmp/consilium-brief.md` with:

- **Task**: the user's request in one paragraph, plus the acceptance criteria.
- **Context**: repo path, relevant files and functions by path, constraints from CLAUDE.md or the user.
- **Already ruled out**: approaches you or the user rejected, and why.
- **Answer in this exact structure** so answers line up:
  1. Recommended approach, in one paragraph
  2. Steps, as a numbered list with the files each step touches
  3. Risks and what could break elsewhere
  4. What you would push back on in the task as stated
  5. Open questions for the user

Tell them they may read the repository but must not edit it.

## Step 2, Consult

```bash
~/.claude/skills/consilium/scripts/consult.sh /tmp/consilium-brief.md <repo-dir>
```

Run with a 600000 ms timeout. Each model is cut off after `CONSILIUM_TIMEOUT` seconds (default 480) and reported as an error, so one hung model cannot block the others. The panel comes from `CONSILIUM_MODELS` in `~/.config/consilium/config`; override it for one run with `CONSILIUM_MODELS="provider/model ..."` (ids as `opencode models` prints them).

## Step 3, Synthesize

If any model printed an `## ERROR` block (the script also exits with the number of failed models), tell the user which model failed and the message, and synthesize from the ones that answered. Do not drop a failure silently. Common fixes: an auth error means the provider credentials in OpenCode expired; "does not exist" or "Unexpected server error" means a wrong model id, check `opencode models`.

Read the answers and produce:

- **Consensus**: what two or more models agree on. Highest signal.
- **Disagreements**: where they diverge and which side you take, with a one-line reason.
- **Lone findings worth keeping**: risks or pushback only one model raised that still hold up.
- **Recommended plan**: numbered steps with files, merged from the above. You are the lead, not a vote counter.
- **Questions for the user**: deduplicated.

Stop after presenting the plan. Do not start implementing until the user confirms.
