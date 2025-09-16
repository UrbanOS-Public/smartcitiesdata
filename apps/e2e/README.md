# E2E

Pulls in the other sub-applications as dependencies, making end-to-end actions across the system easier.

## Running locally

From `apps/e2e`:

```bash
MIX_ENV=integration mix docker.start
MIX_ENV=integration mix test.integration --max-failures 1

# teardown
MIX_ENV=integration mix docker.kill
```

`test.integration` will run the single e2e_test with a seed of 0, ensuring they're run in the order
they're written. --max-failures can be removed but it's recommended to be left in
to find a specific point of failure.

At time of writing, containers need to be destroyed in between test attempts.

## Containers E2E should start with a clean state

  - [ ] init
  - [X] metastore
  - [X] postgres
  - [X] ecto-postgres
  - [X] minio
  - [X] presto
  - [X] zookeeper
  - [X] kafka
  - [X] redis
  - [X] elasticsearch
