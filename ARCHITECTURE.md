# Architecture

## Design goals

- Touchpad-friendly controls with generous click targets
- Complete keyboard operation and visible focus state
- No wheel, middle-click, right-click, or hidden gesture requirements
- Correct timing across shell reloads and suspend/resume
- Atomic state changes and serialized commands
- No root privileges and no runtime network access

## Planned components

- `BarWidget.qml`: bar label, panel lifecycle, and shell-facing IPC
- `Panel.qml`: accessible controls, timer status, and settings
- `pomarchy`: validated timer actions and persistent state transitions
- `cleanup`: idempotent removal of Pomarchy-owned state and user units

The runtime timer will use an absolute end timestamp instead of decrementing
an in-memory counter. A uniquely named transient systemd user timer will make
phase completion independent of the QML process.

## Planned state

Pomarchy will own only this directory:

```text
~/.local/state/omarchy/io.gitlab.ofilafoo.pomarchy/
```

State writes will be atomic and actions serialized with `flock`. Shared
Omarchy state will not be modified in the initial release.

## Planned phases

```text
focus → short break → focus → short break
      → focus → short break → focus → long break
```

Defaults: 25-minute focus, 5-minute short break, 15-minute long break, and a
long break after four completed focus sessions.
