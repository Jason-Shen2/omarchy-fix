# Omarchy Mac finish helper

Personal recovery helper for an interrupted **Quattro** installation on an Apple Silicon Mac running encrypted Asahi / Arch Linux with a Btrfs `@` root. This is not an upstream Omarchy project or a general installer.

Run as the regular Linux user at the machine console:

```sh
curl -fL https://github.com/Jason-Shen2/omarchy-fix/raw/HEAD/f -o f && bash f
```

It checks the local package database, core programs, user configuration, display manager and installed setup helper. It preserves the user session bus, skips user finalization when upstream's completion marker exists, otherwise runs upstream's `omarchy-provision-user --first-install`. It then checks Asahi initramfs hooks, configures encrypted-system autologin, creates the same read-only `@factory` snapshot used by upstream if absent, verifies upstream's installed-state check, sets graphical boot and removes the completed installer service using upstream's cleanup helper.

It stops on a failed check. It does not run the full installer, a full package upgrade, disk formatting, or create false completion markers. User finalization is one upstream group: if interrupted before its marker was written, that group runs again. Missing packages or an earlier incomplete system setup are outside this helper's scope. An existing `@factory` snapshot is preserved.

Review [the script](f) before use. It changes user settings, login configuration, and boot target; it may rebuild initramfs through upstream's helper. On success, run `sudo reboot`. The script does not reboot automatically. Output is saved to `~/omarchy-finish.log`.

Validated with Bash syntax checks and eight mocked control-flow scenarios. It has not been tested on the target Mac, and successful execution does not verify that the graphical desktop can actually start.

Upstream references: [Quattro installer](https://github.com/omacom/omarchy-mac/blob/quattro/install.sh), [root setup helper](https://github.com/omacom/omarchy-mac/blob/quattro/bin/omarchy-mac-setup), [user finalizer](https://github.com/omacom/omarchy-mac/blob/quattro/bin/omarchy-provision-user).
