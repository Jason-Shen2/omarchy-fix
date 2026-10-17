#!/bin/bash
# Target: an interrupted Omarchy Mac Quattro install on Asahi / Apple Silicon.
# Uses the installed upstream user finalizer and root setup helpers.
# Does not run install.sh, pacman -Syu, format disks, or manufacture done markers.
set -Eeuo pipefail
umask 077

die() { printf 'STOP: %s\n' "$*" >&2; exit 1; }

main() {
  [[ $(uname -s) == Linux && $(uname -m) == aarch64 ]] ||
    die 'Run this on the Apple Silicon Linux installation.'
  (( EUID != 0 )) || die 'Log in as your regular Linux user; do not use sudo bash.'
  local setup=/usr/local/bin/omarchy-mac-setup install_user stage=checks
  install_user=$(id -un)
  local log_file="$HOME/omarchy-finish.log"
  exec > >(tee -a "$log_file") 2>&1
  trap 'rc=$?; printf "STOP: stage=%s, exit=%s. Log: %s\n" "$stage" "$rc" "$log_file" >&2; exit "$rc"' ERR
  printf '\nOmarchy finish: %s\n' "$(date -Is)"

  # Do not race the boot-time installer or a live package transaction.
  local state
  state=$(systemctl show omarchy-mac-setup.service -p ActiveState --value)
  case "$state" in
    active|activating|deactivating) die 'The original installer is still running. Wait for it to finish.' ;;
  esac
  [[ ! -e /var/lib/pacman/db.lck ]] || die 'Pacman is locked; no lock has been removed.'
  pacman -Q omarchy omarchy-settings sddm
  pacman -Dk
  local tool
  for tool in Hyprland uwsm omarchy-provision-user omarchy-done; do
    command -v "$tool" >/dev/null || die "Required program missing: $tool"
  done
  command -v qs >/dev/null || command -v quickshell >/dev/null || die 'Quickshell is missing.'
  [[ -f /usr/share/omarchy/version ]] || die 'The Omarchy runtime is missing.'
  [[ -f "$HOME/.config/hypr/hyprland.conf" ]] || die 'User desktop configuration is missing.'
  systemctl is-enabled sddm.service >/dev/null || die 'System setup has not enabled SDDM.'
  [[ -L /etc/systemd/system/display-manager.service ]] || die 'The display manager is not configured.'
  [[ -f "$setup" && ! -L "$setup" ]] || die 'The installed root setup helper is missing.'
  [[ $(stat -c %u "$setup") == 0 ]] || die 'The root setup helper is not owned by root.'
  bash -n "$setup"
  # Only source versions that explicitly guard their main entry point.
  grep -Fqx 'if [[ -z ${BASH_SOURCE[0]:-} || ${BASH_SOURCE[0]} == "$0" ]]; then' "$setup" ||
    die 'Unsupported setup helper: its source guard differs; nothing has been changed.'

  sudo -v
  sudo bash -s -- "$setup" "$install_user" <<'ROOT_CHECK'
set -euo pipefail
source "$1"
for fn in load_conf root_is_encrypted omarchy_is_installed verify_initramfs configure_autologin desktop_session cleanup_all; do
  declare -F "$fn" >/dev/null || { echo "Missing setup helper: $fn" >&2; exit 1; }
done
load_conf
[[ -z $username || $username == "$2" ]] || { echo "Log in as the configured user: $username" >&2; exit 1; }
root_is_encrypted || { echo 'This recovery is for the encrypted installation already discussed.' >&2; exit 1; }
[[ $(findmnt -no FSTYPE /) == btrfs ]] || { echo 'Expected a Btrfs root.' >&2; exit 1; }
findmnt -no OPTIONS / | grep -q 'subvol=/@\(,\|$\)' || { echo 'Expected the @ root subvolume.' >&2; exit 1; }
ROOT_CHECK

  stage=user-finalization
  # Preserve a valid user bus for upstream systemctl --user calls.
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  [[ -O $XDG_RUNTIME_DIR && -S $XDG_RUNTIME_DIR/bus ]] ||
    die 'No user session bus. Log in directly at a Linux console as your regular user.'
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
  source /usr/share/omarchy/default/bash/env-bootstrap
  if omarchy-done check finalize-user; then
    printf 'Skipping user finalization: already complete.\n'
  else
    omarchy-provision-user --first-install
  fi
  omarchy-done check finalize-user
  pacman -Dk

  stage=boot-and-desktop-finalization
  sudo bash -s -- "$setup" "$install_user" <<'ROOT_FINISH'
set -euo pipefail
source "$1"
load_conf
[[ -z $username || $username == "$2" ]] || exit 1
username=$2

# Validate the Asahi boot hooks before recording a factory baseline.
verify_initramfs
configure_autologin "$username"
desktop_session >/dev/null
[[ -L /etc/systemd/system/display-manager.service ]]

# Upstream install.sh takes this same read-only top-level @factory snapshot.
# Use a private mount point and always release it, including on an error.
top=$(mktemp -d /run/omarchy-finish.XXXXXX)
mounted=0
release_mount() {
  if (( mounted )); then umount "$top" || return 1; fi
  rmdir "$top"
}
trap release_mount EXIT
device=$(findmnt -no SOURCE / | sed 's/\[.*\]//')
mount -o subvolid=5 "$device" "$top"
mounted=1
if [[ ! -d $top/@factory ]]; then
  btrfs subvolume snapshot -r "$top/@" "$top/@factory"
fi
release_mount
trap - EXIT

# Never bypass upstream's installed-state check or create a fake marker.
omarchy_is_installed || { echo 'Installed-state verification failed; installer service preserved.' >&2; exit 1; }
systemctl set-default graphical.target
cleanup_all
printf 'Boot and desktop finalization passed.\n'
ROOT_FINISH
  stage=complete
  printf '\nFinishing steps passed. Log: %s\nRun: sudo reboot\n' "$log_file"
}

# Keep prompts attached to the console even when downloaded with curl | bash.
main "$@" </dev/tty
