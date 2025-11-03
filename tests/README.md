# Tests Directory

This directory contains test scripts and stores benchmark output results.

## Structure

```
tests/
├── README.md                        # This file
├── run-correlation-benchmark.sh     # Wrapper script for GH-3.1 testing
├── run-log-retrieval-benchmark.sh   # Wrapper script for GH-5.1 testing
├── correlation-results.json         # GH-3.1 benchmark output (gitignored)
└── log-results.json                 # GH-5.1 benchmark output (gitignored)
```

## Usage

### GH-3.1: Correlation Timing Benchmark

```bash
# Set webhook endpoint
export WEBHOOK_URL=https://webhook.site/<your-unique-id>

# Run benchmark (wrapper script)
tests/run-correlation-benchmark.sh

# Or run directly with custom parameters
../scripts/benchmark-correlation.sh \
  --runs 10 \
  --output tests/correlation-results.json
```

Results will be written to `tests/correlation-results.json`.

### GH-5.1: Log Retrieval Timing Benchmark

```bash
# Set webhook endpoint
export WEBHOOK_URL=https://webhook.site/<your-unique-id>

# Run benchmark (wrapper script)
tests/run-log-retrieval-benchmark.sh

# Or run directly with custom parameters
../scripts/benchmark-log-retrieval.sh \
  --runs 10 \
  --output tests/log-results.json
```

Results will be written to `tests/log-results.json`.

## Analyzing Results

View statistics from JSON output:

```bash
# Correlation timing statistics
jq '.statistics' tests/correlation-results.json

# Log retrieval timing statistics
jq '.statistics' tests/log-results.json

# View all measurements
jq '.measurements' tests/correlation-results.json
```

## Notes

- Test output files (*.json) are gitignored to avoid committing large result datasets
- Wrapper scripts provide sensible defaults for running benchmarks
- Both benchmarks require real GitHub infrastructure and authenticated `gh` CLI
- Webhook endpoint must be obtained from https://webhook.site before running tests
