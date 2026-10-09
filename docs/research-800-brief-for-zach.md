# Research pass for #797 (filed as #800)

This is the brief + appendix also posted as two comments on
hf7y-estate/scheduler#797. No code moved, no issue closed, no milestone
touched, no edge drawn — this file only carries the same text for the
record.

## BRIEF FOR ZACH

**Already ruled, so not asked again:**

- "scheduler survives as the dispatcher." — Zach, 2026-10-07
  (realisateur#1379). Supersedes the same day's earlier "I prefer to retire
  scheduler" and voids realisateur#1315's archive act (its dead-cron-row
  act stands).
- Host layer, hooks, commands → senechal. — Zach, 2026-10-06
  (realisateur#1551): "hook files and wiring go to senechal, the judgement
  a hook makes is a verb in etalon."
- Guards → etalon, one row at a time, never ahead of etalon's main. —
  Zach, 2026-10-06 (realisateur#1564).
- Priority is a quality rank that tightens under scarce quota, loosens
  with slack. — Zach, 2026-09-06 (scheduler#585): "there should be a
  priority rank based on quality work... with slack, we loosen up... no
  contradiction, just a lack of nuance in implementation."
- Pace must be a thermostat, not a fixed rule. — Zach, 2026-10-01
  (realisateur#1379): "one per night is still a bogus rule based on
  nothing," and "maybe... what we need is a notion of priority, or order,
  or the ability to just spawn an agent immediately."
- scheduler#585 and #360's own `DECISION:` lines are already answered
  in-thread (per #797's first comment).

**What scheduler already holds that answers "what's the thermostat":**
`bin/tempo.sh` is literally named "the thermostat's setpoint" in its own
header (scheduler#147); `bin/usage-gate.sh` is the quota sensor;
`bin/usage-paced-runner.sh` is the loop that reads both and dispatches;
`bin/thermostat-probe.sh` is a witness checking the setpoint actually
reacts to agent work, not just to a human editing config. None of the four
is ROSTER-specific code to delete — it's the mechanism Zach asked for in
#1379, just never named "thermostat" out loud until now. They do still
read `schedule/ROSTER` / `_paced.*.conf` for which projects to spin, so the
mechanism and the account model are entangled, not layered cleanly — see
appendix §1.

**Three questions, each a one-pass decision:**

1. **Move order for `agent/`.** realisateur#1386 bakes the dispatcher into
   an image+unit on dexter; moving `agent/`'s source into scheduler is a
   separate step. Dexter gets rewired once either way — which goes first?
   - A. Move `agent/` into scheduler first (its own PR), then #1386 builds
     the image from scheduler.
   - B. Land #1386 in realisateur first (image+unit on dexter), then move
     the source into scheduler and repoint the build — two dexter rewires
     instead of one.

2. **The roster service's unidentified caller.** 145 reads/48h come from a
   process on dexter itself that grepping the obvious scripts doesn't
   explain (#797); 11/48h are mandark. The service can't be safely deleted
   until the dexter-side caller is named.
   - A. Decommission the roster service now, and let the unidentified
     caller fail loudly — that failure IS the identification.
   - B. Hold the service running until a dexter session finds the caller
     (e.g. auditd or process inspection), then decommission.

3. **The armed ROSTER accounts during cutover.** `secretaire`, `etalon`,
   `musc-2300` and others are live, armed rows with open bugs against them
   (scheduler#594, #595, #751, #753) even though the account model they
   belong to is retiring.
   - A. Keep servicing those bugs until the cutover is scoped and
     executed — they're in production today.
   - B. Freeze ROSTER-account work now (close those as superseded by the
     retirement) and accept interim breakage.

**What an agent can do tomorrow without him:**

- Apply the per-issue/per-PR triage in appendix §4 (6 KEEP / 14
  CLOSE-ROSTER / 18 UNCLEAR issues, 4 KEEP / 3 CLOSE-ROSTER PRs) once a
  milestone exists for the CLOSE-ROSTER pile to close against.
- Read the ~150 realisateur issues the proposed milestone table (#797
  comment 3) didn't individually assign — that's reading, not a ruling.
- Draft the single-reversible-step move plan for whichever order Q1
  picks, each step with what proves it worked.
- A dexter/mandark session can start hunting the unidentified
  roster-service caller independent of when Q2 gets decided.

---

## APPENDIX: evidence

### 1. What this repo holds

Per top-level directory (`find <dir> -type f | wc -l`, `find <dir> -type f
-exec cat {} + | wc -l`, `git log -1 --format=%cd --date=short -- <dir>`
after `git fetch --unshallow`):

| dir | files | lines | last commit |
|---|---|---|---|
| bin | 56 (incl. nested `bin/lib/`, 3 files) | 13,691 | 2026-10-05 |
| lib | 18 | 3,093 | 2026-10-05 |
| tests | 117 | 14,979 | 2026-10-05 |
| schedule | 46 | 2,583 | 2026-10-05 |
| docs | 3 | 436 | 2026-10-03 |
| examples | 3 | 231 | 2026-09-20 |
| man | 1 | 70 | 2026-08-26 |

`bin/scheduler` (3,055 lines, the main entrypoint) still references four
scripts that no longer exist in `bin/`: `sync-crontab.sh`,
`scheduler-dev-cycle.sh`, `blockers-freshness-check.sh`,
`session-marker.sh` (checked with `[ -e "bin/$f" ]` for each — all
missing). This matches `.scheduler/schedule.conf`'s own comment that
`sync-crontab.sh` was deleted and scheduler moved to the "usage-paced
runner" model.

The thermostat Zach asked for in realisateur#1379 is, concretely:
`bin/tempo.sh` (setpoint: "may this participant dispatch NOW, at the pace
its backlog justifies?", header cites scheduler#147), `bin/usage-gate.sh`
(quota sensor, reads Anthropic's unified rate-limit headers),
`bin/usage-paced-runner.sh` (the tick loop that calls both and dispatches
round-robin), and `bin/thermostat-probe.sh` (witness: does agent work move
the derived pace, or only a human editing config?). `grep -l ROSTER
bin/*.sh lib/*.sh` shows `usage-paced-runner.sh` and `thermostat-probe.sh`
both still read `schedule/ROSTER` / `_paced.*.conf` — the thermostat and
the account-arming model are not cleanly separated in the current code.

### 2. What the running dispatcher uses from here

(`gh repo clone hf7y-estate/realisateur /tmp/realisateur`, read-only.)

`agent/` is actually 9 entries / 1,400 lines (`wc -l agent/*`), not 8/1,279
— `agent/repos` is a plain-text file physically in the directory, which
the 8-file count excludes.

The only genuine scheduler dependency is `agent/usage-gate.sh`, whose
header reads: `PROVENANCE: hf7y-estate/scheduler, its usage-gate.sh under
bin @ 5c48f41. The CODE is verbatim... Edit it there, re-copy here.` —
i.e. a manually-maintained fork, not a shared file. `grep -rni scheduler
agent/` turns up nothing else except a comment citing
`scheduler#733` and a comment in `run-agent.sh:17` citing
`scheduler/lib/sweep-loop-common.sh` as the historical source of a
default string (not a runtime reference).

The three other cross-references named in #797 — `../bin/etiquette.sh`
(nightly.sh:199), `../bin/lib/zaxon.sh` (nightly.sh:231),
`selfdev-gh-app.sh` (run-agent.sh:173ish) — all resolve to **realisateur's
own `bin/`**, not scheduler (`find /tmp/realisateur -iname "etiquette.sh"
-o -iname "zaxon.sh" -o -iname "selfdev-gh-app.sh"`). All three are on the
live path: etiquette.sh unconditionally per repo in `nightly.sh`'s main
loop; zaxon.sh conditionally, on a "no bot token" exit code; the token
minter unconditionally in `run-agent.sh`'s main token-acquisition step.
`agent/usage-gate.sh` itself was not found called from either `nightly.sh`
or `run-agent.sh` in this search — worth confirming on a live host whether
it still runs at all, or is a dead copy.

The image is built by `.github/workflows/agent-image.yml` in realisateur:
triggers on push to `main` touching `agent/Dockerfile` or the workflow
itself (plus manual dispatch), builds `agent/` with
`docker/build-push-action@v6`, pushes `ghcr.io/hf7y-estate/agent:latest`
and `:$sha`.

### 3. What the verb build still carries

`gh search code --repo hf7y-estate/verbs scheduler` shows a `scheduler/`
subtree inside the verbs build containing `bin/scheduler-run`, `bin/dose`,
`bin/verdict.sh`, `bin/dose-project.sh`, `bin/freeze-check.sh`,
`bin/tempo.sh`, `lib/dose-common.sh`, `lib/sprint-common.sh`,
`lib/answer-registry.sh`, ~17 `schedule/*.conf` files, `man/dose.1`,
`README.md`, `CONTRACT.md`. That `README.md` says explicitly: "This is
the **bashified** branch of `scheduler`."

`git fetch origin bashified && git diff main FETCH_HEAD --stat` (latest
commit `103285a`): 199 files changed, 1,008 insertions, 27,112 deletions —
`bashified` deletes nearly everything (tests/, docs/, most of bin/,
tests.yml, CLAUDE.md, `schedule/ROSTER`) and keeps a small set: `bin/dose`
(rewritten, +86), `man/dose.1` (+140), `CONTRACT.md`, `GAPS.md`,
`lib/verb.sh` (+277), `lib/sprint-common.sh`. `bin/scheduler-run`,
`bin/verdict.sh`, and the `schedule/*.conf` files do **not** appear in the
diff stat at all — they're byte-identical to `main`, just carried forward
unchanged.

realisateur#1388, verbatim: "mandark: 16 commands in `~/.local/bin` are
symlinks into `~/.local/share/verb-builds/current` (`ls -l ~/.local/bin |
grep verb-builds`): ausculte check-project-busy consigne consulte cueille
defere dose etiquette fauche fonde garde gh installe notify-senechal
range sonde. `gh` is one of them, so every `gh` call on mandark runs the
build's wrapper." `dose` is in that list; `scheduler-run` and `verdict.sh`
are not named among the 16 symlinks anywhere found. **UNVERIFIED from this
container:** whether that pinned build is still the live one on mandark
today, and whether `scheduler-run`/`verdict.sh` are invoked by anything
other than being carried along — both require a mandark session.

### 4. Open issues (38) and open PRs (7) here

(`gh issue list --repo hf7y-estate/scheduler --state open --limit 200
--json number,title,labels,milestone,body`; `gh pr list --repo
hf7y-estate/scheduler --state open --limit 50 --json number,title,body`.
Title-text classification only — nothing closed or relabeled.)

Issues — KEEP (6): #585, #694, #726, #733, #735, #797.
CLOSE-ROSTER (14): #304, #337, #350, #359, #360, #364, #594, #595, #712,
#749, #751, #753, #765, #793.
UNCLEAR (18): #238, #318, #355, #775, #776, #777, #778, #779, #780, #781,
#782, #783, #784, #785, #786, #787, #799, #800.

PRs — KEEP (4): #741, #744, #762, #796. CLOSE-ROSTER (3): #745, #794,
#795.

Full one-line reasons are in the #797 appendix comment's source (this
pass's working notes); happy to re-post the full table inline if useful —
trimmed here to fit one screen's worth of appendix.

### 5. Zach's words on thermostat / pace / priority / succession

realisateur#1379 (2026-10-01, issue body): "the one per night sounds
limiting, and the one per repo sounds too expansive. Those are arbitrary
numbers a thermostat should address." / "That sounds right. Stops on
attempts and spend are both good. And those numbers should be variable,
set by whatever files the agent pass, and informed by data (we should
track those things)" / "We need to find homes for all this mechanism.
Realisateur has just functioned as a weird catch-all" / "No new small
repo. Senechal doesn't feel right for dispatcher. Maybe for credential.
This might be proper realisateur core that stays." / "I prefer to retire
scheduler and find another already existing home. Consolidate number of
repos AND reduce lines."

realisateur#1379 (2026-10-01, "Pace." comment): "I'm skeptical about this
'night-sized' premise. Why not spawn multiple a night? That should be a
thermostat thing." / "one per night is still a bogus rule based on
nothing." / "maybe the 'first' marking is itself wrong, and what we need
is a notion of priority, or order, or the ability to just spawn an agent
immediately."

realisateur#1379 (2026-10-07, 01:36:28Z): "I'm not sure. Why is it
realisateur right now? That's just default? Is this what scheduler should
become? Retiring realisateur feels good"

realisateur#1379 (2026-10-07, 01:45:27Z): "scheduler survives as the
dispatcher. close tehis session out and land with a handoff to begin the
scheduler question. it will need some investigation"

realisateur#1608 (2026-10-06, issue body): "the milestone closed thing,
seems like it will cause a repo to be stranded until we discover it or
something. the open milestone should end by opening the next one. and
there should be some kind of sensor that checks this kind of thing so it's
not just caught sporadically" / (comment) "cybernetics" / (2026-10-07,
01:38:17Z) "your choice, but can a closing milestone arm the next one?"

realisateur#1476 (2026-10-05): "We're not on track to burn this quota" /
"permission to install it."

realisateur#1635 (2026-10-07, issue body): "keep C running but why
nightly? what's the cost? can't we calculate when to spawn the meal
picker based on grocy data? file a more intelligent spawn for self-dev
work. keep the dumb nightly now"

scheduler#585 (2026-09-06, issue body): "you're just running each account
in parallel which is really goofy. it presumes accounts are equally
important with equal work which is obviously not true" / (comment)
"the problem is that we're being too coarse. there should be a priority
rank based on quality work. When quota is tight, only high quality
dispatches happen. with slack, we loosen up like we are now (nothing to
lose). There's no contradiction, just a lack of nuance in implementation"

scheduler#360: no quote on thermostat/pace/priority/succession found; its
Zach quotes are about measuring fleet output *quality*, a separate axis
("make a plan to measure output quality that can inform the next
milestone", 2026-09-01).

### 6. Proposed order of moves

Each step reversible, with what proves it worked:

1. `agent/` arrives in scheduler (order vs. #1386 is brief Q1) — proof:
   `ghcr.io/hf7y-estate/agent` still builds green from the new path, old
   path's workflow disabled, not deleted, until one more day of green.
2. realisateur#1551 (host/hooks/commands → senechal) and #1564 (guards →
   etalon, one row at a time) close — proof: each is already "ruled,
   worked one row at a time" per their own threads; closing is a
   consequence of the rows actually moving, not a separate act.
3. The old `schedule/ROSTER` / account-mode tree is deleted from scheduler
   once nothing dispatches through it — proof: `grep -rl ROSTER bin/
   lib/` returns nothing outside the thermostat files named in §1, and
   the roster service's caller (brief Q2) is named or decommissioned.
4. realisateur's open issues transfer per the proposed milestone table
   (#797 comment 3) once the ~150 unassigned ones are read (§4 here is a
   start, not that reading).
5. realisateur is archived only once 1-4 are true and `agent/` runs from
   scheduler on dexter (realisateur#1386, #1551, #1564, #1388 all closed).

### 7. What could not be looked at from this container

UNVERIFIED, each with the command a mandark/dexter session should run (all
carried over from #797's own comments, re-confirmed rather than
re-derived, since dexter/mandark are not reachable here):

- Who makes the ~3/hr dexter-local roster-service reads:
  `ssh dexter 'sudo docker logs roster --since 48h | grep -v healthz |
  awk "{print \$2}" | sort | uniq -c'` showed 145 from `172.21.0.1`
  (docker bridge gateway — a process on dexter's own host) and 11 from
  `100.119.125.0` (mandark, via `tailscale status`). Grepping
  `/srv/agent/*.sh`, `bin/estate-watch.sh`, `bin/estate-status-collect.py`
  for `8646`/`/roster` found nothing — the caller is reached through a
  library or env var not yet located. Next step: `strace`/`auditd` on the
  dexter-side process, not another grep.
- Whether mandark's pinned verb build (`~/.local/share/verb-builds/current`,
  2026-09-07T031807Z per issue metadata) is still the live one, and
  whether `dose`/`gh` on mandark actually resolve through it today —
  needs `readlink -f "$(command -v gh)"` run ON mandark.
- Whether the GH App `unattended-monkey`'s `administration: write` is
  still needed by anything: `gh api /apps/unattended-monkey --jq
  .permissions` (already run, still granted) answers *that it's granted*,
  not *whether anything uses it* — needs a workflow-by-workflow read on a
  host session.
- Whether `roster`, `whisper`, `secretaire`, `groc-browser` images can
  still be pushed under `/users/hf7y/packages`: the check needs
  `read:packages`, which this session's token lacks.
