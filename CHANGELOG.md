# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Initial Omarchy bar-widget scaffold.
- Keyboard-first and touchpad-friendly interaction requirements.
- GitHub Actions validation baseline.
- Persistent focus, short-break, and long-break state machine.
- Start, pause, resume, skip, reset, cleanup, and JSON status commands.
- Atomic state/settings writes, serialized operations, and transient systemd timer.
- Live bar countdown, complete panel controls, settings, and daily totals.
- Compact panel styling, horizontal action-row navigation, and restoration of
  standard Pomodoro settings.
- Stable shared-control button geometry and single-pass status updates to
  prevent neighboring controls from flickering.
- Fine-grained setting properties so changing one value does not invalidate
  every control in the panel.
- Non-animated action controls with fixed one-pixel borders for completely
  stable Start, Reset, Restore, and adjustment-button rendering.
- Reliable pointer Reset independent of keyboard cursor position; resetting
  a break returns to a ready focus phase and paused timers reset immediately.
- Optional tomato-logo bar mode tinted with the active theme's neutral, green,
  and red palette colors for idle, focus, and break states.
- Transactional scheduling rollback, strict state invariants, settings
  migration, complete cleanup, direct numeric entry, exitcode diagnostics,
  Shell IPC actions, and automated CLI regression tests.
