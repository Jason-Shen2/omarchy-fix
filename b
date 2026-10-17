#!/bin/bash
# Quattro bar recovery. Qt compatibility workaround documented in upstream #708:
# https://github.com/omacom/omarchy-mac/issues/708
set -Eeuo pipefail
umask 077
die() { printf 'STOP: %s\n' "$*" >&2; exit 1; }

main() {
  [[ $(uname -s) == Linux ]] || die 'Run inside the installed Linux desktop.'
  (( EUID != 0 )) || die 'Run as your regular desktop user, without sudo bash.'
  local log_file="$HOME/omarchy-bar.log" stage=checks
  exec > >(tee -a "$log_file") 2>&1
  trap 'rc=$?; printf "STOP: stage=%s, exit=%s. Log: %s\n" "$stage" "$rc" "$log_file" >&2; exit "$rc"' ERR
  printf '\nQuattro bar recovery\n'
  local tool shell_dir=/usr/share/omarchy/shell
  for tool in pacman vercmp hyprctl omarchy-toggle omarchy-restart-shell python3; do
    command -v "$tool" >/dev/null || die "Required command missing: $tool"
  done
  [[ -f $shell_dir/shell.qml && -f $shell_dir/Commons/qmldir ]] || die 'Packaged Quattro shell is missing.'
  [[ ! -e /var/lib/pacman/db.lck ]] || die 'Pacman is locked; wait for the package transaction to finish.'
  source /usr/share/omarchy/default/bash/env-bootstrap
  [[ $OMARCHY_PATH == /usr/share/omarchy ]] || die 'This helper does not patch a development checkout.'
  hyprctl -j monitors >/dev/null || die 'Run this from a terminal inside your Hyprland desktop.'

  stage=visibility
  # The upstream flag is named bar-off: disabling that flag SHOWS the bar.
  omarchy-toggle bar-off off

  stage=qt-compatibility
  local qt_info qt_version backup
  qt_info=$(pacman -Q qt6-declarative)
  qt_version=${qt_info##* }
  printf 'Installed: %s\n' "$qt_info"
  if (( $(vercmp "$qt_version" 6.12.0) >= 0 )) &&
      grep -Eq '^singleton[[:space:]]+Color[[:space:]]' "$shell_dir/Commons/qmldir" &&
      grep -rqE '^[[:blank:]]*import QtQuick[[:blank:]]*$' "$shell_dir" --include='*.qml'; then
    backup="/var/tmp/omarchy-shell-before-qt612-$(date +%Y%m%d-%H%M%S)-$$.tar.gz"
    printf 'Qt >= 6.12 and old Color singleton detected. Backing up to: %s\n' "$backup"
    sudo tar -C /usr/share/omarchy -czf "$backup" shell
    printf 'Rollback, if needed: sudo tar -xzf %s -C /usr/share/omarchy\n' "$backup"
    sudo python3 - "$shell_dir" <<'PY_PATCH'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
pattern = re.compile(r'(?m)^([ \t]*)import QtQuick[ \t]*$')
changed = 0
for path in sorted(root.rglob('*.qml')):
    if path.is_symlink() or not path.is_file():
        continue
    old = path.read_text(encoding='utf-8')
    new = pattern.sub(r'\1import QtQuick 6.11', old)
    if new != old:
        path.write_text(new, encoding='utf-8')
        changed += 1
print(f'QtQuick imports pinned in {changed} files.')
PY_PATCH
  else
    printf 'No unpatched Qt 6.12 / Color collision detected; skipping file changes.\n'
  fi

  stage=shell-restart
  if ! omarchy-restart-shell; then
    printf 'Shell restart failed. Recent shell messages:\n'
    journalctl --user -b -t omarchy-shell -n 40 --no-pager || true
    printf 'Log saved to: %s\n' "$log_file"
    exit 1
  fi
  printf '\nShell restart responded. Check whether the bar is now visible.\nLog: %s\n' "$log_file"
}

main "$@" </dev/tty
