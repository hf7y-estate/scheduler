#!/usr/bin/env bash
set -uo pipefail
. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/harness.sh"
ROOT="$(cd "$(dirname "$0")/../bin" && pwd)"
SCRIPT="$ROOT/registry-dir-provision.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT not executable"; exit 1; }

harness_tmp

echo "registry-dir-provision.test.sh"

section "A. the argument contract"
"$SCRIPT" --not-a-real-flag >/dev/null 2>&1; eq "A1 unknown flag exits 2" "$?" "2"
"$SCRIPT" --help >/dev/null 2>&1;            eq "A2 --help exits 0" "$?" "0"
OUT="$("$SCRIPT" --help 2>&1)"
has "A3 --help documents the refused-without-root exit" "$OUT" "refused"

DIR="$T/registry"
RULE="$T/tmpfiles.d/scheduler-registry.conf"

section "B. --check on a host with neither the dir nor the rule"
OUT="$("$SCRIPT" --check --dir "$DIR" 2>&1)"; RC=$?
eq  "B1 exits 1 -- findings, not clean" "$RC" "1"
has "B2 reports the dir missing" "$OUT" "MISSING $DIR does not exist"
has "B3 says what to run next" "$OUT" "--apply"
[ ! -e "$DIR" ] && ok "B4 --check wrote nothing" || bad "B4 --check created $DIR"

section "C. --apply without root is refused, --check never needs it"
if [ "$(id -u)" -eq 0 ]; then
  ok "C1 skipped: running as root"
else
  OUT="$("$SCRIPT" --apply --dir "$DIR" 2>&1)"; RC=$?
  eq  "C1 --apply without root exits 5" "$RC" "5"
  has "C1b and says so" "$OUT" "needs root"
fi
grep -q 'rm -rf' "$SCRIPT" && bad "C2 the script contains an rm -rf" || ok "C2 no rm -rf anywhere in the script"

section "D. --apply as root creates the dir 1777 and the matching tmpfiles.d rule"
if [ "$(id -u)" -ne 0 ]; then
  ok "D* skipped: not root"
else
  OUT="$(REGISTRY_DIR_TMPFILES_RULE="$RULE" "$SCRIPT" --apply --dir "$DIR" 2>&1)"; RC=$?
  eq  "D1 --apply exits 0" "$RC" "0"
  [ -d "$DIR" ] && ok "D2 dir created" || bad "D2 dir not created"
  eq "D3 dir mode is 1777" "$(stat -c '%a' "$DIR" 2>/dev/null)" "1777"
  [ -f "$RULE" ] && ok "D4 tmpfiles.d rule written" || bad "D4 rule file missing"
  has "D5 rule names the dir, mode and owner" "$(cat "$RULE" 2>/dev/null)" "d $DIR 1777 root root"

  section "E. idempotent -- a second --apply on a host already at the target changes nothing"
  OUT2="$(REGISTRY_DIR_TMPFILES_RULE="$RULE" "$SCRIPT" --apply --dir "$DIR" 2>&1)"; RC2=$?
  eq  "E1 exits 0 again" "$RC2" "0"
  hasnt "E2 no DO rows -- nothing left to do" "$OUT2" "  DO      "

  section "F. --check after --apply is clean"
  OUT3="$(REGISTRY_DIR_TMPFILES_RULE="$RULE" "$SCRIPT" --check --dir "$DIR" 2>&1)"; RC3=$?
  eq "F1 exits 0" "$RC3" "0"
  hasnt "F2 no MISSING rows" "$OUT3" "MISSING"

  section "G. a dir present with the wrong mode is a finding, and --apply fixes it"
  chmod 0700 "$DIR"
  OUT4="$(REGISTRY_DIR_TMPFILES_RULE="$RULE" "$SCRIPT" --check --dir "$DIR" 2>&1)"; RC4=$?
  eq  "G1 wrong mode exits 1" "$RC4" "1"
  has "G2 reports BAD, not MISSING -- the dir exists, just wrong" "$OUT4" "BAD"
  REGISTRY_DIR_TMPFILES_RULE="$RULE" "$SCRIPT" --apply --dir "$DIR" >/dev/null 2>&1
  eq "G3 mode fixed back to 1777" "$(stat -c '%a' "$DIR" 2>/dev/null)" "1777"
fi

section "H. it is declared, so it reaches a host by a named channel"
. "$ROOT/../lib/provision-set.sh"
ch="$(provision_channel registry-dir-provision.sh 2>/dev/null)" || ch=""
eq "H1 the provision set declares it -- a human runs this once, on nobody's clock" "$ch" "provision"

echo
summary
