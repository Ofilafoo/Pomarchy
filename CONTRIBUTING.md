# Contributing

Keep changes focused, user-owned, and safe for the long-running Omarchy shell
process.

Before submitting a change:

1. Run `omarchy plugin validate .`.
2. Run `qmllint` on every QML file when available.
3. Run `bash -n` on every shell script.
4. Test real start, pause, resume, skip, expiry, reload, and cleanup paths.
5. Restore the original desktop and timer state after testing.
6. Check shell logs for QML and runtime errors.

Never add credentials, personal logs, generated state, or files copied from
`~/.local/state/` to the repository.
