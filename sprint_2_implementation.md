# Sprint 2 - Implementation Notes

## GH-4. Workflow log access realtime access
Status: Progress

- Added `scripts/stream-run-logs.sh` to stream in-flight GitHub Actions logs via `gh api`.
- Script supports `--run-id` (manual run selection) or accepts JSON from `scripts/trigger-and-track.sh` via stdin.
- Incrementally tails gzipped job logs, prefixes each line with the job name, and prints a final conclusion message once the run completes.
- `--summary` shows snapshot of run/job statuses without downloading logs; `--once` performs a single poll.
- Example flows:

```bash
# After triggering and correlating
export WEBHOOK_URL=PASTE # copy "Your unique URL" from https://webhook.site
scripts/trigger-and-track.sh --webhook-url $WEBHOOK_URL$ \
  | scripts/stream-run-logs.sh --interval 2

# Monitor an existing run
scripts/stream-run-logs.sh --run-id <run_id>

# Snapshot statuses once without logs
scripts/stream-run-logs.sh --run-id <run_id> --summary --once
```

## Testing
Status: Progress

- Lint scripts:

```bash
shellcheck scripts/stream-run-logs.sh scripts/trigger-and-track.sh scripts/test-trigger-and-track.sh
actionlint
```

- End-to-end log streaming:

```bash
export WEBHOOK_URL=https://webhook.site/<id>
scripts/test-trigger-and-track.sh --webhook-url "$WEBHOOK_URL" \
  | scripts/stream-run-logs.sh --interval 2
```

- Interrupt the receiver or trigger parallel runs to confirm log tails continue updating and correlation remains unique per run.
