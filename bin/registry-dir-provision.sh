#!/usr/bin/env bash
# registry-dir-provision.sh -- own /run/scheduler-registry and the
# tmpfiles.d rule that recreates it on every boot.
#
# WHY THIS EXISTS (#589): half 2 of lib/registry-lock.sh's two-half lockout
# only works if a human's own session (writer) and a project's job (reader)
# resolve the SAME marker path. They run as different unix accounts, so
# anything under either account's $HOME fails that by construction -- the
# measured failure was exactly this: the marker a human wrote was at a path
# the runner never looked at. The fix is a fixed, shared, world-writable
# location; this script is what puts it there and keeps it there.
#
# /run, not /srv or /var: a stale marker must not survive a reboot (a human
# who was mid-session before a reboot is not mid-session after one), and
# /run is wiped on every boot for exactly that reason -- which is also why
# a plain `mkdir` the first time is not enough and this installs a
# tmpfiles.d rule rather than only creating the directory once.
set -uo pipefail

CLI_NAME='registry-dir-provision.sh'
CLI_SUMMARY='create /run/scheduler-registry (1777) and the tmpfiles.d rule that recreates it every boot -- the shared marker directory half 2 of the registry lockout needs (#589)'
CLI_USAGE='  registry-dir-provision.sh            --check (default): report, write nothing
  registry-dir-provision.sh --apply    create the dir and install the tmpfiles.d rule
  (idempotent -- an --apply on a host already at the target changes nothing and says so)'
CLI_FLAGS='--check --apply --dir'
CLI_POSITIONAL=any
CLI_EXITS='  0  the host is at the target (or --check found it so)
  1  findings: the dir or the tmpfiles.d rule is missing or wrong -- read the rows
  5  refused: --apply without root'
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/cli-guard.sh"
cli_guard "$@"

MODE=--check
DIR="${REGISTRY_DIR:-/run/scheduler-registry}"
TMPFILES_RULE="${REGISTRY_DIR_TMPFILES_RULE:-/etc/tmpfiles.d/scheduler-registry.conf}"
while [ $# -gt 0 ]; do
  case "$1" in
    --check|--apply) MODE="$1" ;;
    --dir) shift; DIR="${1:-}" ;;
    *) cli_die "unexpected argument: $1" ;;
  esac
  shift
done
WANT_LINE="d $DIR 1777 root root -"

PW_OK_FMT='  OK      %s\n'
PW_GAP_FMT='  MISSING %s\n'
PW_BAD_FMT='  BAD     %s\n'
PW_ACT_FMT='  DO      %s\n'
. "$HERE/../lib/provision-witness.sh"
die() { printf '\n%s: %s\n' "$CLI_NAME" "$*" >&2; exit "${2:-5}"; }

echo "== registry-dir-provision ($MODE) -- $(hostname -s 2>/dev/null || echo unknown), dir $DIR =="

[ "$MODE" = --check ] || [ "$(id -u)" -eq 0 ] || die "$MODE needs root (sudo $CLI_NAME $MODE)" 5

if [ ! -d "$DIR" ]; then
  if [ "$MODE" = --apply ]; then
    install -d -m 1777 -o root -g root "$DIR" && act "created $DIR (1777 root:root)"
  else
    gap "$DIR does not exist"
  fi
fi
if [ -d "$DIR" ]; then
  m="$(stat -c '%a %U:%G' "$DIR" 2>/dev/null)"
  if [ "$m" = "1777 root:root" ]; then
    ok "$DIR is $m"
  elif [ "$MODE" = --apply ]; then
    chown root:root "$DIR" && chmod 1777 "$DIR" && act "$DIR was '$m' -- set to 1777 root:root"
  else
    bad "$DIR is '$m', expected '1777 root:root'"
  fi
fi

if [ -f "$TMPFILES_RULE" ] && [ "$(cat "$TMPFILES_RULE" 2>/dev/null)" = "$WANT_LINE" ]; then
  ok "$TMPFILES_RULE matches ($WANT_LINE)"
elif [ "$MODE" = --apply ]; then
  mkdir -p "$(dirname "$TMPFILES_RULE")" \
    && printf '%s\n' "$WANT_LINE" > "$TMPFILES_RULE" && act "wrote $TMPFILES_RULE"
  if command -v systemd-tmpfiles >/dev/null 2>&1; then
    systemd-tmpfiles --create "$TMPFILES_RULE" >/dev/null 2>&1 \
      && act "systemd-tmpfiles --create applied it immediately" \
      || echo "  ..      systemd-tmpfiles --create failed or is not usable here -- $DIR above was still created directly"
  fi
else
  gap "$TMPFILES_RULE missing or stale (want: $WANT_LINE)"
fi

echo
printf '%s (%s): %d ok, %d missing, %d bad\n' "$CLI_NAME" "$MODE" "$PASS" "$GAPS" "$BAD"
if [ "$MODE" = --check ]; then
  [ "$GAPS" -eq 0 ] && [ "$BAD" -eq 0 ] && exit 0
  echo "Next: sudo $CLI_NAME --apply"
  exit 1
fi
[ "$GAPS" -eq 0 ] && [ "$BAD" -eq 0 ] && exit 0
exit 1
