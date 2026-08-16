# Pomarchy

Pomarchy is a touchpad-friendly, keyboard-first Pomodoro timer for the
Omarchy Quattro bar.

## Features

- Focus sessions, short breaks, and long breaks
- Start, pause, resume, skip, and reset controls
- Large touchpad-friendly controls without wheel or middle-click actions
- Full keyboard navigation with `j`/`k`, `h`/`l`, arrows, Enter, Space, Escape, and Tab
- Persistent timing across shell reloads and suspend/resume
- Desktop notifications and optional sound
- Daily completed-session and focus-time totals

## Requirements

- Omarchy Quattro with `omarchy-shell` and Quickshell
- `bash`, `jq`, `flock`, and a systemd user session
- `systemctl`, `systemd-run`, and `notify-send` (sound additionally uses
  `canberra-gtk-play` when available)
- No root privileges or runtime network access

Pomarchy stores settings and session state below
`~/.local/state/omarchy/io.github.ofilafoo.pomarchy/`. A persistent, empty
coordination lock lives at
`~/.local/state/omarchy/.locks/io.github.ofilafoo.pomarchy.lock`; keeping its
inode stable prevents cleanup from splitting concurrent command execution.
Transient timers alternate between the suffixes `-a` and `-b` (for example,
`omarchy-pomarchy-io-github-ofilafoo-a.timer`). This lets an expiring service
schedule the next phase without colliding with its own still-loaded unit.

## Local development

The functional and quality baseline is defined in
[REQUIREMENTS.md](REQUIREMENTS.md). The planned runtime structure is described
in [ARCHITECTURE.md](ARCHITECTURE.md).

Validate the plugin folder:

```sh
omarchy plugin validate .
```

Install a local development copy under the permanent plugin ID, make
`pomarchy` and `cleanup` executable, then rescan the shell plugins. Do not edit
files under `/usr/share/omarchy/`.

## Installation

Pomarchy is not released yet. Once the first release is ready, install it with:

```sh
omarchy plugin add https://github.com/Ofilafoo/Pomarchy.git --enable
```

## Usage

Left-click the bar widget to open or close its panel. Start, pause, resume,
skip, reset, duration settings, auto-start, notifications, and sound are all
visible and work with both the touchpad and keyboard. No wheel, middle-click,
or hidden pointer gesture is required.

Click a displayed duration to enter a value directly, or type a digit while
its row is selected. Enter commits a valid value and Escape cancels editing.

Disable **Show countdown in bar** to replace the permanent countdown with a
monochrome tomato logo. Its color is taken from the active Omarchy theme:
neutral bar text while no phase is running, the theme's green during focus,
and the theme's red during a running break. The tooltip continues to show the
exact phase, status, and remaining time.

Reset restores a focus phase to its full configured duration. From a short or
long break it returns to a ready focus phase. Only resetting a currently
running timer requires a second confirmation click; a paused timer resets
immediately.

The **Restore Pomodoro defaults** action resets durations to 25/5/15 minutes,
the long-break interval to four focus sessions, countdown display on,
auto-start off, notifications on, and sound off. A running or paused phase
keeps its current duration.

## Removal

Before removing the plugin, stop its transient user timer and delete only its
owned state with:

```sh
~/.config/omarchy/plugins/io.github.ofilafoo.pomarchy/cleanup
omarchy plugin remove io.github.ofilafoo.pomarchy
```

Cleanup is idempotent and does not alter Omarchy idle, lock-screen, or
screensaver settings. It intentionally retains the empty coordination lock so
concurrent or later commands continue to serialize on the same inode.
Upgrades from an earlier development version may also retain an empty
`operation.lock` and therefore its otherwise empty session directory. New
commands lock the stable coordination file first and then this legacy anchor;
neither is unlinked, because an already waiting old process may hold its inode.
All settings and session data are still removed.

## Command line and IPC

The local command supports `status`, `start`, `pause`, `resume`, `skip`,
`reset`, `defaults`, `configure`, and `cleanup`. `status` prints JSON.

The bar widget also exposes Omarchy Shell IPC methods under
`io.github.ofilafoo.pomarchy`: `open`, `close`, `show`, `hide`, `toggle`,
`start`, `pause`, `resume`, `skip`, and `reset`. For example:

```sh
omarchy-shell io.github.ofilafoo.pomarchy toggle
omarchy-shell io.github.ofilafoo.pomarchy start
```

## Plugin identity

- Plugin ID: `io.github.ofilafoo.pomarchy`
- Plugin kind: `bar-widget`
- Default bar section: `right`

## License

Pomarchy is released under the [MIT License](LICENSE).
