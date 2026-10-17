# Omarchy Mac finish helper

Personal recovery helper for an interrupted **Quattro** installation on an Apple Silicon Mac running encrypted Asahi / Arch Linux with a Btrfs `@` root. This is not an upstream Omarchy project or a general installer.

Run as the regular Linux user at the machine console:

```sh
curl -fL https://github.com/Jason-Shen2/omarchy-fix/raw/HEAD/f -o f && bash f
```

It checks the local package database, core programs, user configuration, display manager and installed setup helper. It preserves the user session bus, skips user finalization when upstream's completion marker exists, otherwise runs upstream's `omarchy-provision-user --first-install`. It then checks Asahi initramfs hooks, configures encrypted-system autologin, creates the same read-only `@factory` snapshot used by upstream if absent, verifies upstream's installed-state check, sets graphical boot and removes the completed installer service using upstream's cleanup helper.

It stops on a failed check. It does not run the full installer, a full package upgrade, disk formatting, or create false completion markers. User finalization is one upstream group: if interrupted before its marker was written, that group runs again. Missing packages or an earlier incomplete system setup are outside this helper's scope. An existing `@factory` snapshot is preserved.

Review [the script](f) before use. It changes user settings, login configuration, and boot target; it may rebuild initramfs through upstream's helper. On success, run `sudo reboot`. The script does not reboot automatically. Output is saved to `~/omarchy-finish.log`.

Validated with Bash syntax checks and ten mocked control-flow scenarios. It has not been tested on the target Mac, and successful execution does not verify that the graphical desktop can actually start.

Upstream references: [Quattro installer](https://github.com/omacom/omarchy-mac/blob/quattro/install.sh), [root setup helper](https://github.com/omacom/omarchy-mac/blob/quattro/bin/omarchy-mac-setup), [user finalizer](https://github.com/omacom/omarchy-mac/blob/quattro/bin/omarchy-provision-user).

## Missing Quattro top bar

Run **inside a terminal in the Hyprland desktop**, as the regular user:

```sh
curl -fL https://github.com/Jason-Shen2/omarchy-fix/raw/HEAD/b -o b && bash b
```

The helper clears the `bar-off` user toggle and restarts the Omarchy shell. If the installed Qt declarative version is >= 6.12 and the packaged shell still declares its own `Color` singleton with bare QtQuick imports, it first creates a full shell backup in `/var/tmp/omarchy-shell-before-qt612-*.tar.gz`, then pins bare imports to `QtQuick 6.11`, following the temporary workaround documented in [upstream issue 708](https://github.com/omacom/omarchy-mac/issues/708). Affected files are under `/usr/share/omarchy/shell`; user plugins are not patched. An Omarchy package update can replace the patched files. The helper skips this patch for older Qt or a shell whose singleton has already been renamed.

The backup path and exact rollback command are printed before patching. It does not restart Hyprland, reboot, or run an installer. Restart failures print recent shell journal entries. Output is saved in `~/omarchy-bar.log`. Successful shell IPC/restart does not prove that the bar actually rendered: check the screen afterward.

Validated with controlled tests of import replacement, repeat execution, versioned/import preservation, file modes, symlinks, Qt version guards, renamed singleton guards, and restart-error logging. Not tested on the target Mac.
