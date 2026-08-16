# Architecture

## Design goals

- Touchpad-friendly controls with generous click targets
- Complete keyboard operation and visible focus state
- No wheel, middle-click, right-click, or hidden gesture requirements
- Correct timing across shell reloads and suspend/resume
- Atomic state changes and serialized commands
- No root privileges and no runtime network access

## Components

- `BarWidget.qml`: live bar label, panel lifecycle, and status polling
- `Panel.qml`: touchpad and keyboard controls, timer status, and settings
- `Model.js`: pure phase-label and time-format helpers
- `pomarchy`: validated CLI actions and persistent state transitions
- `cleanup`: idempotent removal of Pomarchy-owned state and user units
- `tests/test-cli.sh`: isolated state-machine regression suite with controlled
  systemd test doubles

The runtime timer uses an absolute end timestamp instead of decrementing an
in-memory counter. Two transient systemd user-unit slots (`-a` and `-b`)
alternate at automatic phase boundaries. The successor therefore never
reuses the name of the service that is still executing the expiry command.

## State

Pomarchy will own only this directory:

```text
~/.local/state/omarchy/io.github.ofilafoo.pomarchy/
```

`settings.json` and `session.json` are written atomically. All actions are
serialized with `flock` on the persistent coordination file
`~/.local/state/omarchy/.locks/io.github.ofilafoo.pomarchy.lock`. Cleanup does
not unlink this file: a waiter may still hold its inode, so replacement would
create a second lock domain. Shared Omarchy state is not modified.

During upgrades, an existing session-local `operation.lock` is acquired after
the stable lock and retained as a compatibility anchor. This fixed
stable-then-legacy order avoids deadlocks between new processes, while old
holders and waiters remain in the same legacy lock domain. Cleanup may leave
the otherwise empty session directory only for this anchor.

Scheduling is transactional from the user's perspective: if `systemd-run`
fails, `start` restores the ready state, `resume` restores the paused state,
and an automatic transition remains safely ready instead of claiming to run.

## Planned phases

```text
focus → short break → focus → short break
      → focus → short break → focus → long break
```

Defaults: 25-minute focus, 5-minute short break, 15-minute long break, and a
long break after four completed focus sessions.
