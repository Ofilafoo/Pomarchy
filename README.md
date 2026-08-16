# Pomarchy

Pomarchy is a touchpad-friendly, keyboard-first Pomodoro timer for the
Omarchy Quattro bar.

> [!NOTE]
> Pomarchy is currently an early development scaffold. The timer engine and
> controls are not implemented yet.

## Planned features

- Focus sessions, short breaks, and long breaks
- Start, pause, resume, skip, and reset controls
- Large touchpad-friendly controls without wheel or middle-click actions
- Full keyboard navigation
- Persistent timing across shell reloads and suspend/resume
- Desktop notifications and optional sound
- Daily completed-session and focus-time totals

## Requirements

- Omarchy Quattro with `omarchy-shell` and Quickshell
- No root privileges

Runtime dependencies will be documented here before the first release.

## Local development

Validate the plugin folder:

```sh
omarchy plugin validate .
```

Install a local development copy under the permanent plugin ID, then rescan
the shell plugins. Do not edit files under `/usr/share/omarchy/`.

## Installation

The public installation URL will be added after the GitLab repository has
been created and released.

## Usage

Left-click the bar widget to open or close its panel. All timer controls will
be visible in the panel and usable with both the touchpad and keyboard. No
wheel, middle-click, or hidden pointer gestures will be required.

## Removal

Before the first release, Pomarchy will provide an idempotent cleanup command
for any timers and user-owned state it creates. Removal instructions will be
documented here once those resources exist.

## Plugin identity

- Plugin ID: `io.gitlab.ofilafoo.pomarchy`
- Plugin kind: `bar-widget`
- Default bar section: `right`

## Publishing note

The Omarchy Plugin Marketplace currently requires a public GitHub repository.
The primary project may live on GitLab, but marketplace submission will also
require a public GitHub mirror unless that policy changes.

## License

Pomarchy is released under the [MIT License](LICENSE).
