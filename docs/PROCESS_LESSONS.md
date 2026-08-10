# Process lessons (from PENUMBRA)

Scaled package for **Standup Reminder**. Full incident detail: PENUMBRA
`docs/PROCESS_LESSONS.md`. Do not soften a rule without reading the failure.

1. **Claim on your branch is invisible** → claim-first on default branch.
2. **Collisions happen on files** → write surfaces + exclusive hot spots.
3. **Append-only log thrash** → `merge=union` on DECISIONS/SESSION_LOG/OPEN_QUESTIONS.
4. **Empty menu stampede** → ASSIGNMENT only self-serve menu.
5. **`strict: true` thrash** → keep required checks non-strict when multi-agent.
6. **Bookkeeping tax** → claims-only / docs-process fast path.
7. **GITHUB_TOKEN does not trigger workflows** → `REPO_PAT` for bots that open PRs.
8. **Declared surfaces must match diffs** → `check-write-surface.sh` on `agent/*`.
9. **Do not buy PENUMBRA's full process tax early** → this package is the light set.

Adopted here: 2026-08-04.

---

## Guard honesty (added 2026-08-09)

The nine rules above are the **coordination** set, adopted 2026-08-04. They are
sized for more than one agent on a trunk. Everything below is the **guard**
set — lessons PENUMBRA learned as §10–§29 after that adoption, which cost real
time at a fleet of *one*. They are about checks that lie, and a check can lie to
a single developer as easily as to eight agents.

Full incident detail: PENUMBRA `docs/PROCESS_LESSONS.md` §§8–29. Each rule below
carries its failure, because a rule read without its incident looks like overhead
and the reliable way to re-create a solved failure is to delete the guard that
solved it.

**Nothing below claims to be implemented here.** PENUMBRA's §11 spent four days
describing a `pre-commit` hook that had never been written, in the document that
governs changing controls, and an agent auditing coverage from it budgeted no
work for a hole it read as closed. A copied lesson that asserts a local control
is the same defect. Treat these as rules to check this repo against, not as a
description of it.

### The core failure mode: a check that cannot read its input

Four incidents, one shape. A check loses access to its data and reports a
*verdict* instead of reporting that it is blind.

- **Silently green (§8).** A guard listed pull requests to reconcile them against
  a registry. The default workflow token is contents-only, the API answered 403,
  and the guard passed while checking nothing. Grant the permission explicitly,
  and make a guard loud when its data source is unavailable rather than vacuously
  green.
- **Silently red (§12).** A readiness gate called `gh pr checks --json
  name,state,conclusion`. `conclusion` is not a valid field, so the command
  printed an error and emitted no JSON; `|| echo '[]'` swallowed it, every
  required context resolved to `MISSING`, and the gate answered `NOT READY` for
  every PR in the repository for a full day. It was not reporting the state of
  the PR. It was reporting that its own API call was malformed, in the vocabulary
  of a blocked PR.
- **The rule:** an error path and a negative verdict are different results and
  must not share a message. `|| echo '[]'` on a data fetch converts an outage
  into a false finding.
- **Absence is not pending (§18).** GitHub builds `pull_request` runs from the
  computed merge ref; a PR that conflicts with its base cannot produce that ref,
  so it gets **no runs at all** — not queued, not failed, absent. Third-party
  checks still appear, so the PR looks like it is being processed. Absence of a
  required check is a distinct state from a pending one and must be reported as a
  failure, never waited on.
- **A monitor is a guard (§28).** An alerting tool decides whether to raise an
  alarm, so §8's test applies to it unchanged: ask what state makes it stay quiet
  when it should not. One treated GitHub's lazy `UNKNOWN` mergeability as clear,
  called drafts stuck, and called a PR stuck six minutes before it merged. A
  monitor that cries wolf is one its reader learns to ignore, which converts a
  real alarm into noise at exactly the wrong moment.

### A checker cannot catch an error it made on both sides

- **§14.** A claim parser mangled every annotated path declaration into a string
  matching no file. The overlap guard kept passing because it compared two
  mangled strings *to each other*. Garbage versus garbage is indistinguishable
  from no-conflict.
- **§15.** Declared write surfaces were compared only to other declarations, so a
  file nobody declared was outside the universe the guard examined. One PR
  touched 29 files, 15 undeclared, and passed.
- **The general rule, worth more than either incident:** a checker that only
  compares two things it derived the same way cannot detect that it derived them
  wrong — both sides are wrong together and agree. Correctness requires comparing
  against something the checker did not produce. Here: the files a branch
  actually changed.

### If it is not a gate, it must not look like one (§9)

A `dotnet format` job ran `continue-on-error: true` but still rendered red in the
checks UI. Agents burned product PRs fixing format debt they were never assigned,
because a red X reads as a blocker. **Advisory jobs exit 0** — `set +e`, emit
`::warning::`, `exit 0`. The converse holds: if it should gate, make it a
required check rather than a non-required job that renders red.

This one was re-violated within hours by the repository that wrote it, on
reasoning that was locally sound. That is the argument for keeping the failure
next to the rule.

### Credentials and outages

- **A fallback protects against a missing secret, not a wrong one (§7a).**
  `${{ secrets.REPO_PAT || secrets.GITHUB_TOKEN }}` falls back only when the
  secret is **empty**. A present-but-invalid credential satisfies the `||` and
  shadows the working fallback entirely — eight workflow runs failed on
  `404` in eighteen minutes and `GITHUB_TOKEN` was never tried. Degrade on
  *unusable*, not on *absent*.
- **Diagnostic note:** `404` from `repos/{owner}/{repo}/...` means the token
  cannot see the repository at all. `403` means authenticated but
  under-permissioned. The distinction points straight at the cause.
- **An outage is a hypothesis, not a finding (§26).** Every run going to 0 steps
  and ~3s reads as exhausted Actions minutes. It was transient, and bypassing
  checks on that assumption would have merged a 273-test failure. When checks
  cannot run, the substitute is to run them locally, not to skip them.

### Diagnostics and accusations

- **A diagnostic that names a variable will be read as accusing it (§22).** A
  preflight said an error was invalid "model access; verify `claude-opus-4-8`
  availability." The account was out of credits, which returns HTTP 400 for
  *every* model. Three independent readers concluded the model was at fault; one
  13-agent investigation cited that log line as proof. The string was not wrong —
  the model is the only variable in a fixed request — but a diagnostic is read as
  a verdict, and the one thing it names is the one thing people change. Either
  identify the cause or say you cannot. Where a probe distinguishes two causes
  cheaply, run the probe.
- **Print the matched line before publishing (§29).** A substring scan for
  `tests/Foo.Tests` matched both a directory lease and an exact-file declaration
  — the opposite thing. It produced a public comment accusing another agent's PR,
  retracted in full, and work abandoned on a false belief. A pattern match is
  evidence something *might* be true; the line itself is the claim.

### Tooling reads the wrong repository (§24)

A gate resolved a claim by scanning the working tree, and the shared checkout had
drifted onto another branch, so it reported a file missing that existed on the
PR. A check that decides whether a pull request may merge must read the **pull
request**, not the checkout. Where a tool must fall back to local state it has to
say so in its output, because a gate that fails closed *silently* is
indistinguishable from a gate that is correct. Before trusting a local answer
about a remote branch, `git fetch --prune`; before trusting `--delete-branch`,
confirm with `git ls-remote`.

### Two rules about how fixes travel

- **§20 — do not bundle.** A two-line fix to a broken gate was parked inside a
  26-file, +4303/-704 process overhaul. The overhaul was rejected for unrelated
  reasons and took the fix with it; the gate answered `NOT READY` for every PR for
  another day. A small, verified, independently-correct fix does not ride with a
  large contested one.
- **§21 — tests belong to the repository, not to the workflow that introduced
  them.** A test suite ran in exactly one place: a step inside one product
  workflow. When that workflow was disabled, its tests silently stopped running
  everywhere and nothing reported a gap. Anything under `tests/` must be
  reachable from the standard local gate.

### The rule that governs this file (§13)

The incident stays in the repository that had it. **Lessons may be copied out;
they may not be moved out.** PENUMBRA extracted this material to another
repository, kept the rules at home as bare assertions, and re-violated §9 within
a day — the revert comment had to cite a file in a different repository to
explain itself. A bare assertion loses an argument to a plausible local reason,
every time.

Two corollaries for this copy:

1. If something fails *here*, write it *here*. This file is a copy of another
   repository's incidents; it is not a place to record yours. Start your own
   section below.
2. When a control named anywhere is deleted, say so in the same change. PENUMBRA
   added a **Retired controls** section for exactly this: a guard cannot tell a
   retired control from a fabricated one, and it described a removed test in the
   present tense for four days.

### What this repo should not adopt

Rule 9 of the 2026-08-04 package still stands and is worth restating, because it
is the lesson PENUMBRA itself is now trying to act on. Its own assessment grades
the system **process-heavy relative to product throughput**, and its open
question #4 asks what fleet size the machinery should be sized for — noting that
merge-wave integration owners, serial landing and exclusive leases *"cost real
friction and buy nothing at a fleet of one."*

At one agent, do not adopt: claim-first registration, write-surface declarations,
`ASSIGNMENT.md` as a menu, path-label CI tiers, or a reconcile bot. Those solve
collisions between concurrent agents and cost a merge each at a fleet of one.
The guard-honesty rules above are the part that pays for itself immediately.

A document nobody can act on is not documentation — it is a liability with a
filename. PENUMBRA has 69 of them at the top level of `docs/`, and that search
cost is paid by every agent at every session start.
