# Lifecycle and recovery

Documented behaviors — implement exactly; change only via [decisions.md](../planning/decisions.md).

## Lock

- Emit `lock` signal; stop counting activeMs
- Remain in logical session; do not screenshot while locked
- On unlock: emit `unlock`; resume sampling if still Tracking/Idle

## Sleep / hibernate

- Emit `sleep`; freeze active accounting
- On wake: emit `wake`; re-evaluate idle from last input; resume per state

## Pause / stop

- User pause: stop sampling and screenshots; accumulate pausedMs
- User stop: finalize session aggregates; engine idle

## Crash / kill / power loss

- Persist `sessions.state` and heartbeat/checkpoint frequently enough for recovery
- On next launch: if open session found → **Recovering**
  - Offer resume (recover) or discard (close as interrupted)
- Never silently invent hours across the gap without marking recovery

## Timezone change

- Store timestamps in UTC; display in local zone
- Aggregations use UTC instants
