# E2E

Pulls in the other sub-applications as dependencies, making end-to-end actions across the system easier.

## Testing

From the umbrella root:

```bash
mix test.e2e
```

## Running locally

From `apps/e2e`:

```bash
MIX_ENV=integration mix docker.start
MIX_ENV=integration mix run --no-halt

# teardown
MIX_ENV=integration mix docker.kill
```
