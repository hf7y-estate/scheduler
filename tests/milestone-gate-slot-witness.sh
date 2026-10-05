#!/usr/bin/env bash
# milestone-gate-slot-witness.sh -- a milestone hold must not spend a dispatch
# slot (#758, DEFAULT-AFTER 2026-10-02 elapsed unreversed: "make a held
# project free ... and does not count against PACED_MAX_PER_TICK"). Proof: a
# 2-row rotation with PACED_MAX_PER_TICK=1, row 1 MILESTONE-HELD and row 2
# live, must dispatch row 2 in the SAME tick -- before the fix the held row's
# `dispatched=$((dispatched+1))` hit the cap and the loop never reached row 2.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
RUNNER="$REPO/bin/usage-paced-runner.sh"
[ -x "$RUNNER" ] || { echo "FAIL: no runner at $RUNNER"; exit 1; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
FAILED=0
fail() { echo "FAIL: $*"; FAILED=1; }

mkdir -p "$T/schedule"
echo "EXEMPT: ecosim@monkey EXEMPT: nine-speakers@monkey" > "$T/schedule/FREEZE"
export SCHEDULER_FREEZE_FILE="$T/schedule/FREEZE"
export SCHEDULER_FREEZE_CACHE="$T/freeze-cache"
ROSTER="$T/schedule/ROSTER"
{
  echo 'ecosim         | ecosim@monkey         | 20m | live'
  echo 'nine-speakers  | nine-speakers@monkey  | 20m | live'
} > "$ROSTER"
export SCHEDULER_ROSTER_FILE="$ROSTER"

H="$T/h"; mkdir -p "$H/.local/share/scheduler-paced-runner" "$H/bin"

# held row's gh call carries its slug (repo_slug_of ecosim.conf's REPO_URL,
# unstripped since it's an ssh-form URL) in the args; the live row's carries
# "nine-speakers" (its REPO_URL is https-form and strips to hf7y/nine-speakers).
# Branching on that substring, not call order, is what lets each row get its
# own fixture regardless of rotation order.
cat > "$H/bin/gh" <<EOF
#!/usr/bin/env bash
jq_issues() {  # <issues-json> <gh-args...> -- applies the real --jq filter gh would run server-side
  local fixture="\$1"; shift
  local argv=("\$@") filter=""
  for i in "\${!argv[@]}"; do [ "\${argv[\$i]}" = "--jq" ] && filter="\${argv[\$((i+1))]}"; done
  jq -r "\$filter" <<<"\$fixture"
}
case "\$*" in
  *ecosim*milestones?state=open*) echo '[]' ;;
  *ecosim*issues?state=open*) jq_issues '[]' "\$@" ;;
  *nine-speakers*milestones?state=open*) echo '[{"number":1,"description":""}]' ;;
  *nine-speakers*issues?state=open*)
    jq_issues '[{"number":10,"milestone":{"number":1,"state":"open"},"labels":[],"assignees":[]}]' "\$@"
    ;;
  *) echo "milestone-gate-slot-witness: unexpected gh call: \$*" >&2; exit 64 ;;
esac
EOF
cat > "$H/gate.sh" <<'EOF'
#!/usr/bin/env bash
echo "verdict=RUN"
exit 0
EOF
cat > "$H/own-run" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$H/bin/gh" "$H/gate.sh" "$H/own-run"

{
  echo "ecosim|1|$H/own-run ecosim batch"
  echo "nine-speakers|1|$H/own-run nine-speakers batch"
} > "$H/paced.conf"
echo -1 > "$H/.local/share/scheduler-paced-runner/rotation.idx"

env HOME="$H" PATH="$H/bin:$PATH" \
  PACED_CONF="$H/paced.conf" PACED_HOST=monkey PACED_MAX_PER_TICK=1 \
  SCHEDULER_FREEZE_FILE="$SCHEDULER_FREEZE_FILE" \
  SCHEDULER_FREEZE_CACHE="$SCHEDULER_FREEZE_CACHE" \
  SCHEDULER_ROSTER_FILE="$SCHEDULER_ROSTER_FILE" \
  TEMPO_ENABLED=0 \
  USAGE_GATE="$H/gate.sh" "$RUNNER" >/dev/null 2>&1

LOG="$H/.local/share/scheduler-paced-runner/run.log"
has() { grep -q "$1" "$LOG" 2>/dev/null; }

has 'MILESTONE-HELD' || fail "ecosim (no open milestone): expected MILESTONE-HELD ($LOG)"
has ' DISPATCH ' || fail "PACED_MAX_PER_TICK=1 with a held row first: expected the live row to still dispatch in the same tick ($LOG)"
has 'PACED_MAX_PER_TICK (1) reached' || fail "the live dispatch should have been the one to hit the cap, not the hold ($LOG)"

[ "$FAILED" -eq 0 ] && echo "PASS: milestone-gate-slot-witness"
exit "$FAILED"
