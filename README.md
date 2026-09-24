# Display Settings Menu (prototype)

Adds **Display Settings…** to the menu you get when you Control-click the
empty macOS desktop, using a Finder Sync extension.

This is a feasibility prototype. The open question is whether Finder asks a
Finder Sync extension for a container menu when you click the desktop
background. The extension logs every menu request so you can check.

## Layout

| Path | Purpose |
|---|---|
| `Sources/FinderExtension/FinderSync.swift` | The extension: watches `~/Desktop`, adds the menu item, opens Displays settings |
| `Sources/HostApp/main.swift` | Host app that carries the extension; opens the extension settings and quits |
| `Resources/` | Info.plists and the extension's sandbox entitlement |
| `build.sh` | Compiles with `swiftc`, assembles the bundles, and signs them (no Xcode project) |

## Build

```bash
./build.sh
```

Uses the first `Apple Development` / `Mac Developer` signing identity in your
keychain; pass `--identity <name-or-hash>` to pick another.

## Try it

1. Copy the app to `~/Applications` and launch it once. That registers the extension and opens the extension settings.

   ```bash
   ditto "build/Display Settings Menu.app" "$HOME/Applications/Display Settings Menu.app"
   ```

   ```bash
   open "$HOME/Applications/Display Settings Menu.app"
   ```

2. In the System Settings pane that opens (General → Login Items & Extensions → Finder extensions), turn on **Display Settings Menu**.
3. In a terminal, watch the extension's log:

   ```bash
   log stream --level info --predicate 'subsystem == "com.altmansoftwaredesign.DisplaySettingsMenu"'
   ```

4. Control-click the empty desktop. Finder Sync items appear at the bottom of the menu.

### Reading the result

| What you see | Meaning |
|---|---|
| Menu item appears; log shows `kind=1 target=/Users/…/Desktop` | Works. |
| Log shows `kind=1` with some other target | Finder reports the desktop differently; adjust the `targetedURL == desktopURL` check. |
| Log shows `Extension started` but no `menu(for:)` on desktop clicks | Finder doesn't ask extensions about the desktop background. The approach doesn't work. |
| No log lines at all | Extension isn't running. Check `pluginkit -mv -i com.altmansoftwaredesign.DisplaySettingsMenu.FinderExtension` and that it's enabled. |

`kind` values (from `FinderSync.h`): 0 = items, 1 = container
(window/desktop background), 2 = sidebar, 3 = toolbar button. A desktop
background click should log `kind=1`.

## Remove

1. Turn the extension off in System Settings.
2. Delete the app:

   ```bash
   rm -rf "$HOME/Applications/Display Settings Menu.app"
   ```
