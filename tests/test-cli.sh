#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
test_home="$(mktemp -d)"
trap 'rm -rf "$test_home"' EXIT
export HOME="$test_home"
export PATH="${repo_dir}/tests/bin:/usr/bin"
command="${repo_dir}/pomarchy"
state_dir="${HOME}/.local/state/omarchy/io.github.ofilafoo.pomarchy"
lock_file="${HOME}/.local/state/omarchy/.locks/io.github.ofilafoo.pomarchy.lock"

"$command" status | jq -e '.status=="ready" and .phase=="focus" and .unitSlot=="" and .settings.showCountdown==true' >/dev/null

# A scheduling failure must not leave a phantom running state.
POMARCHY_TEST_SCHEDULE_FAIL=true "$command" start >/dev/null 2>&1 && exit 1 || true
"$command" status | jq -e '.status=="ready" and .phase=="focus"' >/dev/null

# A regular expiry runs inside slot A and must schedule its successor in slot B.
"$command" configure autoStart true >/dev/null
run_log="${test_home}/systemd-run.log"
POMARCHY_TEST_RUN_LOG="$run_log" "$command" start >/dev/null
jq '.endsAt=1' "${state_dir}/session.json" >"${state_dir}/session.tmp"
mv "${state_dir}/session.tmp" "${state_dir}/session.json"
transition_id="$(jq -r '.transitionId' "${state_dir}/session.json")"
POMARCHY_TEST_RUN_LOG="$run_log" POMARCHY_TEST_ACTIVE_UNIT=omarchy-pomarchy-io-github-ofilafoo-a \
  "$command" expire "$transition_id" a >/dev/null
"$command" status | jq -e '.status=="running" and .phase=="short-break" and .unitSlot=="b"' >/dev/null
tail -n 1 "$run_log" | grep -Fx 'omarchy-pomarchy-io-github-ofilafoo-b' >/dev/null

# A stale or forged expiry invocation with the wrong slot must be a no-op.
running_transition="$(jq -r '.transitionId' "${state_dir}/session.json")"
before_state="$(cat "${state_dir}/session.json")"
"$command" expire "$running_transition" a >/dev/null
test "$(cat "${state_dir}/session.json")" = "$before_state"

# Reconciliation derives the successor from persisted state, even when it is
# initiated by status rather than by the systemd expiry argv.
jq '.endsAt=1' "${state_dir}/session.json" >"${state_dir}/session.tmp"
mv "${state_dir}/session.tmp" "${state_dir}/session.json"
POMARCHY_TEST_RUN_LOG="$run_log" POMARCHY_TEST_ACTIVE_UNIT=omarchy-pomarchy-io-github-ofilafoo-b \
  "$command" status >/dev/null
"$command" status | jq -e '.status=="running" and .phase=="focus" and .unitSlot=="a"' >/dev/null
tail -n 1 "$run_log" | grep -Fx 'omarchy-pomarchy-io-github-ofilafoo-a' >/dev/null
"$command" reset >/dev/null
"$command" configure autoStart false >/dev/null
jq '.daily.focusSessions=0 | .daily.focusSeconds=0' "${state_dir}/session.json" >"${state_dir}/session.tmp"
mv "${state_dir}/session.tmp" "${state_dir}/session.json"

"$command" start >/dev/null
"$command" pause >/dev/null
POMARCHY_TEST_SCHEDULE_FAIL=true "$command" resume >/dev/null 2>&1 && exit 1 || true
"$command" status | jq -e '.status=="paused" and .endsAt==0 and .transitionId==""' >/dev/null

# Skipping focus never increments daily completion totals.
"$command" resume >/dev/null
"$command" skip | jq -e '.phase=="short-break" and .daily.focusSessions==0' >/dev/null
"$command" reset | jq -e '.phase=="focus" and .status=="ready"' >/dev/null

# Missing showCountdown is migrated; another missing required field is rejected.
jq 'del(.showCountdown)' "${state_dir}/settings.json" >"${state_dir}/settings.tmp"
mv "${state_dir}/settings.tmp" "${state_dir}/settings.json"
"$command" status | jq -e '.settings.showCountdown==true' >/dev/null
jq 'del(.sound)' "${state_dir}/settings.json" >"${state_dir}/settings.tmp"
mv "${state_dir}/settings.tmp" "${state_dir}/settings.json"
"$command" status | jq -e '.settings.sound==false and .settings.showCountdown==true' >/dev/null

# A running state without a transition id is invalid and safely recovered.
"$command" start >/dev/null
jq '.transitionId=""' "${state_dir}/session.json" >"${state_dir}/session.tmp"
mv "${state_dir}/session.tmp" "${state_dir}/session.json"
"$command" status | jq -e '.status=="ready" and .phase=="focus"' >/dev/null

# Serialized concurrent reads must all produce valid JSON.
for index in 1 2 3 4 5 6; do
  "$command" status >"${test_home}/status-${index}.json" &
done
wait
for index in 1 2 3 4 5 6; do jq -e . "${test_home}/status-${index}.json" >/dev/null; done

# Concurrent mutations are serialized and never corrupt either JSON file.
for value in 21 22 23 24 25 26; do
  "$command" configure focusMinutes "$value" >/dev/null &
done
wait
jq -e '.focusMinutes >= 21 and .focusMinutes <= 26' "${state_dir}/settings.json" >/dev/null
jq -e . "${state_dir}/session.json" >/dev/null

# Cleanup cannot split the lock domain: its stable inode survives while an old
# waiter and a newly arriving mutator serialize on the same file.
lock_inode="$(stat -c %i "$lock_file")"
flock "$lock_file" -c 'sleep 0.2' &
holder_pid=$!
sleep 0.03
"$command" cleanup &
cleanup_pid=$!
sleep 0.03
"$command" configure focusMinutes 25 >/dev/null &
mutator_pid=$!
wait "$holder_pid" "$cleanup_pid" "$mutator_pid"
test "$(stat -c %i "$lock_file")" = "$lock_inode"
"$command" status | jq -e '.settings.focusMinutes==25' >/dev/null

# Cleanup removes session data and its directory, while the persistent lock
# remains as the synchronization anchor. Cleanup itself is idempotent.
"$command" cleanup
test ! -e "$state_dir"
test -f "$lock_file"
"$command" cleanup
test ! -e "$state_dir"
test -f "$lock_file"

# A legacy operation.lock is a second, potentially live coordination domain.
# New commands join it under the stable lock and never unlink its inode. This
# safely serializes an old holder, cleanup, and a newly arriving mutation.
mkdir -p "$state_dir"
legacy_lock="${state_dir}/operation.lock"
: >"$legacy_lock"
legacy_inode="$(stat -c %i "$legacy_lock")"
flock "$legacy_lock" -c 'sleep 0.2' &
legacy_holder_pid=$!
sleep 0.03
flock "$legacy_lock" -c "printf '%s\\n' old-waiter >'${test_home}/legacy-waiter-ran'" &
legacy_waiter_pid=$!
sleep 0.03
"$command" cleanup &
legacy_cleanup_pid=$!
sleep 0.03
"$command" configure focusMinutes 27 >/dev/null &
legacy_mutator_pid=$!
wait "$legacy_holder_pid" "$legacy_waiter_pid" "$legacy_cleanup_pid" "$legacy_mutator_pid"
grep -Fx old-waiter "${test_home}/legacy-waiter-ran" >/dev/null
test "$(stat -c %i "$legacy_lock")" = "$legacy_inode"
jq -e '.focusMinutes==27' "${state_dir}/settings.json" >/dev/null
"$command" cleanup
test ! -e "${state_dir}/session.json"
test ! -e "${state_dir}/settings.json"
test "$(stat -c %i "$legacy_lock")" = "$legacy_inode"

printf '%s\n' "cli-tests=ok"
