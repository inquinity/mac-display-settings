# Research: adding an item to the macOS desktop context menu

**Question:** Can a third-party app add an item (here, **Display Settings…**)
to the menu macOS shows when you Control-click the empty desktop, by any
supported method, or by an unsupported one that holds up?

**Date:** 2026-09-24. Tested on macOS 27.0.

## Verdict

**There is no supported way to do it.** No public extension point gets asked
about the desktop background menu:

- **Finder Sync** is the only extension point with a "background" menu, and
  Finder doesn't call it for the desktop. Our prototype showed this directly
  (see the README's *Result*). Apple's documentation limits that menu to Finder
  windows, and Apple engineers describe the extension point as sync-only with
  locations it has never covered.
- **Services and Quick Actions** need a selection (files or text), so they
  don't appear for a click on empty space.

The only way to get an item into that exact spot is **unsupported**: watch
mouse clicks system-wide and show your own menu over the desktop. That needs
Accessibility or Input Monitoring permission, fights Finder's own menu, and
can break with any macOS update.

**Recommendation:** don't try to use the desktop menu. For the same one-step
access, use a **menu bar item** or a **keyboard shortcut** (see
[Options](#options)).

## Evidence

### 1. Our test (primary evidence)

The Finder Sync prototype on this branch, tested on macOS 27.0:

| Action | Did Finder call `menu(for:)`? |
|---|---|
| Control-click empty space in a Finder window showing `~/Desktop` | Yes: `kind=1`, `isDesktop=true`, item shown |
| Control-click the empty desktop itself | No: nothing logged, though the extension was running |

So the extension, its signing and its path matching all work. Finder just
never asks extensions about the desktop background.

### 2. Apple documentation

The [App Extension Programming Guide: Finder Sync][guide] defines the menu
kinds. The background menu is scoped to Finder windows:

> `FIMenuKindContextualMenuForContainer`: "The user Control-clicked the
> Finder window's background while browsing the monitored folder."

It says nothing about the desktop, and it states the extension point's
purpose:

> "Finder Sync is not intended as a general tool for modifying the Finder's
> user interface."

### 3. Apple engineers on the Developer Forums

- **[FIFinderSyncController for ALL folders/files?][forum-all]** (Oct 2024,
  accepted answer by Kevin Elliott, DTS): Finder Sync "was never designed to
  support this use case". Some locations skip Finder Sync entirely (the
  Applications folder is the example given), and coverage "never worked
  'everywhere' and the list has only grown over time". He also mentions
  interest in "a general mechanism for expanding the Finder's interface like
  this", but no such API exists.
- **[FIFinderSync not working in iCloud Drive][forum-icloud]** (June 2024, Quinn
  "The Eskimo!", DTS): extensions should cover "a specific directory that
  obviously belongs to you". iCloud Drive, including a synced Desktop, isn't
  one, and menus there stopped appearing in Sonoma.
- **[FinderSync menu not appearing inside OneDrive][forum-onedrive]** (June
  2023, Quinn, DTS): when two extensions cover the same folder, "weird things
  will happen"; Finder picks one of them.

None of these threads mentions the desktop background by name. Our test fills
that gap.

### 4. Services and Quick Actions

Services and Quick Actions act on a selection. Apple's
[Quick Actions help page][qa] describes them for selected items. An open-source
project that researched the same Windows feature found no macOS equivalent
([keycuts #102][keycuts], Sept 2026):

> "Windows has `Directory\Background\shell` — right-click on empty space
> _inside_ a folder. macOS has no equivalent."

(Our Finder Sync test does add an item to empty space *inside a Finder window*.
The desktop is the case with no equivalent.) We haven't tried a Service on the
desktop ourselves; everything above points to it not appearing.

### 5. Third-party right-click apps

| App | Mechanism | Desktop background? |
|---|---|---|
| [RClick][rclick] (open source) | Finder Sync extension plus menu bar app | Not documented. Uses the same API we tested. |
| [custom-finder-right-click-menu][cfrcm] (open source) | Finder extension | Finder windows only; the desktop isn't mentioned. |
| iBoysoft MagicMenu, iRightMouse, Service Station, Context Menu | Finder extensions (per their listings) | MagicMenu's marketing says "blank space on your desktop or in an open folder". Unverified, and its help pages mention trouble with the Desktop folder in Sonoma and later. |

We couldn't read the MagicMenu, iRightMouse, Context Menu or App Store pages
directly (this environment's network policy blocks them). Their claims come
from search excerpts only. **If a tool really does put items on the desktop
menu, installing and testing it on your Mac is the fastest way to find out,
and `log stream` would show how it does it.** Nothing public so far describes
a way around what our test found.

## Options

| Option | Where it shows up | Supported? | Effort | Risk |
|---|---|---|---|---|
| **Menu bar item** (status-bar app with a "Display Settings…" item) | Menu bar, 1 click | Yes | Small; can reuse the host app | Low |
| **Keyboard shortcut** (Shortcuts app opening the `x-apple.systempreferences:` link, set as a hotkey) | Anywhere | Yes | No code | Low |
| **Control Center Display module** (built in) | Control Center | Yes | None | None. Worth checking whether its settings button is enough for you. |
| **Desktop click interception** (system-wide mouse event tap, check the click lands on the desktop, show our own menu) | The desktop | **No** | Medium–large | High: needs Accessibility/Input Monitoring permission, runs alongside or replaces Finder's menu, can break across macOS versions, and can't be sold in the Mac App Store |
| **Finder Sync on `~/Desktop`** (this prototype) | Finder windows showing Desktop only | Yes | Done | Doesn't meet the goal |

### About desktop click interception

We found no public write-up of this for Finder's desktop. It's an engineering
assessment, not a documented technique. It would need to:

1. Install a system-wide event tap for right-mouse and Control-click events.
   This needs Input Monitoring or Accessibility permission.
2. Work out whether the click hit empty desktop space (for example, by asking
   Accessibility which element is under the pointer) and not an icon, a
   window, or the menu bar.
3. Either swallow the event and show a full menu of its own, losing Finder's
   own items (New Folder, Change Wallpaper…, and so on), or let Finder's menu
   open and show a second one. Neither lets us *add to* Finder's menu.

It's feasible as a personal tool, but it's fragile and doesn't give the
"extra item in the existing menu" result. We don't recommend it.

## Sources

- Apple, [App Extension Programming Guide: Finder Sync][guide]
- Apple Developer Forums, [FIFinderSyncController for ALL folders/files?][forum-all] (Oct 2024)
- Apple Developer Forums, [FIFinderSync not working in iCloud Drive][forum-icloud] (Sept 2023 – June 2024)
- Apple Developer Forums, [FinderSync extension menu not appearing inside MS OneDrive location][forum-onedrive] (June 2023)
- Apple Support, [Perform quick actions in the Finder on Mac][qa]
- GitHub, [andrewralon/keycuts #102][keycuts] (Sept 2026)
- GitHub, [wflixu/RClick][rclick]
- GitHub, [samiyuru/custom-finder-right-click-menu][cfrcm]

[guide]: https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Finder.html
[forum-all]: https://developer.apple.com/forums/thread/766680
[forum-icloud]: https://developer.apple.com/forums/thread/737283
[forum-onedrive]: https://developer.apple.com/forums/thread/731680
[qa]: https://support.apple.com/guide/mac-help/perform-quick-actions-in-the-finder-on-mac-mchl97ff9142/mac
[keycuts]: https://github.com/andrewralon/keycuts/issues/102
[rclick]: https://github.com/wflixu/RClick
[cfrcm]: https://github.com/samiyuru/custom-finder-right-click-menu
