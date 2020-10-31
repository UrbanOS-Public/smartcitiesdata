# Forklift

An application for reading data off kafka topics, batching it up and sending it to Presto. To improve both write and read performance data is written to a temporary table as raw JSON and then migrated to the main table in ORC format.  The process of [compaction](#compaction) is done on a configurable cadence.


## To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests

## To run inside a container(from the root directory):
  * `docker build . -t <image_name:tag>`

### To run locally:
  * To startup external dependancies in docker:
    ```bash
    `MIX_ENV=integration mix docker.start`
    ```
  * To run a single instance with no data in it:
    ```bash
    `MIX_ENV=integration iex -S mix`
    ```
  * To kill the docker:
    ```bash
    `MIX_ENV=integration mix docker.kill`
    ```
```

## Jobs
### Compaction
Compaction is a process that runs that consolidates the data that is being stored in Presto.  This process greatly improves read performance.
```elixir
# Deactive Compaction
Forklift.Quantum.Scheduler.deactivate_job(:compactor)
Forklift.Quantum.Scheduler.deactivate_job(:data_migrator)
Forklift.Quantum.Scheduler.deactivate_job(:partitioned_compactor)

# Active Compaction
Forklift.Quantum.Scheduler.activate_job(:compactor)
Forklift.Quantum.Scheduler.activate_job(:data_migrator)
Forklift.Quantum.Scheduler.activate_job(:partitioned_compactor)
```


## License

Released under [Apache 2 license](https://github.com/Datastillery/smartcitiesdata/blob/master/LICENSE).
