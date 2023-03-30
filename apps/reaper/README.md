# Reaper

Retrieves data, decodes it, and loads it onto a Kafka topic

## To run the tests

- Run `mix test` to run the tests a single time
- Run `mix test.watch` to re-run the tests when a file changes
- Run `mix test.watch --stale` to only rerun the tests for modules that have changes
- Run `mix test.integration` to run the integration tests

## To build a reaper docker image:

- Go up to the smartcitiesdata directory `cd ../../`
- `./scripts/build.sh reaper 1.0`
- You should now see smartcitiesdata/reaper in your list of docker images.

## Running Locally

You can use [Divo](https://hexdocs.pm/divo/) to stand up the external dependencies locally using docker and docker-compose.

```bash
MIX_ENV=integration mix docker.start
MIX_ENV=integration iex -S mix
```

## Environment Variables used for configuration

| Variable          | Description                                  | Example                         |
| ----------------- | -------------------------------------------- | ------------------------------- |
| KAFKA_BROKERS     | comma delimited list of kafka brokers        | kafka1.com:9092,kafka2.com:9092 |
| TO_TOPIC          | topic unto which we do the raw data          | raw                             |
| HOST_IP           | local IP address; used for integration tests | 127.0.0.1                       |
| REDIS_HOST        | IP address or DNS Entry of the redis host    | 10.0.0.2                        |
| DLQ_TOPIC         | Kafka topic name for the dead letter queue   | streaming-dlq                   |
| RUN_IN_KUBERNETES | Set to "true" if running in kubernetes       | true                            |

## Running Interactively

First, to startup external dependancies in docker:

```bash
MIX_ENV=integration mix docker.start
```

To run a single instance with no data in it:

```bash
MIX_ENV=integration iex -S mix
```

To run a single instance with test data added to it:

```bash
MIX_ENV=integration iex -S mix test --no-start
```

To run a local cluster, run the following in two different terminals:

```bash
iex --name a@127.0.0.1 -S mix
```

```bash
iex --name b@127.0.0.1 -S mix
```

You can verify offsets on the source and destination topic with the following commands:

```elixir
:brod_utils.resolve_offset([{'localhost', 9092}], "dataset-registry", 0, -1, [])
:brod_utils.resolve_offset([{'localhost', 9092}], "raw", 0, -1, [])
```

### Example Ingestion Messages

The following code will create a datafeed which will pull down a sample file on a cadence of 30 seconds. As a result, messages containing the data to be posted to the `raw` topic on the cadence. The url key under `extractSteps` needs to be a publicly available json file.

<details>
  <summary>Code snippet</summary>

```elixir
ingestion = %SmartCity.Ingestion{
  allow_duplicates: true,
  cadence: "*/30 * * * * *",
  extractSteps: [
    %{
      assigns: %{},
      context: %{
        action: "GET",
        body: "",
        headers: [],
        protocol: nil,
        queryParams: [],
        url: "https://jsonplaceholder.typicode.com/posts/1"
      },
      ingestion_id: "a8416a75-8359-4dd0-8419-c64c85d63772",
      sequence: 52,
      type: "http"
    }
  ],
  id: "a8416a75-8359-4dd0-8419-c64c85d63772",
  name: "JSON Placeholder Posts Ingestion",
  schema: [
    %{
      biased: "No",
      demographic: "None",
      description: "",
      ingestion_id: "a8416a75-8359-4dd0-8419-c64c85d63772",
      masked: "N/A",
      name: "body",
      pii: "None",
      sequence: 197,
      subSchema: [],
      type: "string"
    },
    %{
      biased: "No",
      demographic: "None",
      description: "",
      ingestion_id: "a8416a75-8359-4dd0-8419-c64c85d63772",
      masked: "N/A",
      name: "id",
      pii: "None",
      sequence: 198,
      subSchema: [],
      type: "integer"
    },
    %{
      biased: "No",
      demographic: "None",
      description: "",
      ingestion_id: "a8416a75-8359-4dd0-8419-c64c85d63772",
      masked: "N/A",
      name: "title",
      pii: "None",
      sequence: 199,
      subSchema: [],
      type: "string"
    },
    %{
      biased: "No",
      demographic: "None",
      description: "",
      ingestion_id: "a8416a75-8359-4dd0-8419-c64c85d63772",
      masked: "N/A",
      name: "userId",
      pii: "None",
      sequence: 200,
      subSchema: [],
      type: "integer"
    }
  ],
  sourceFormat: "application/json",
  targetDataset: "af7e0ad6-71d7-4ccb-9bed-56d6e1f91fff",
  topLevelSelector: nil,
  transformations: []
}
 Brook.Event.send(Reaper.instance_name(), "ingestion:update", :reaper, ingestion)
```

</details>

## Clustering

This application uses [Horde](https://hexdocs.pm/horde/api-reference.html) to perform distributed supervison of the data feeds and [libcluster](https://hexdocs.pm/libcluster/readme.html) to dynamically discover other instances of the application running on Kubernetes.

On startup, libcluster connects the erlang vms, then the `Reaper.Horde.Supervisor` is started and added to the Horde. A `Reaper.FeedSupervisor` is responsible its the worker process and cache.

The resulting supervision tree looks roughly like this:

```
+-------------+
| Application |
+------|------+
       |
+------v-------------+
|                    |
| Reaper.Horde.Supervisor |
| +---------------------+
+-|----|-------------+  |
  |    |                |
  |  +-v----------------|---+
  |  | Reaper.ConfigServer |
  |  +----------------------+
  |
  | +------------------------+ +------------------+
  +-> Reaper.FeedSupervisor +-> Reaper.DataFeed |
  | +------------------------+ +------------------+
  | +------------------------+ +------------------+
  +-> Reaper.FeedSupervisor +-> Reaper.DataFeed |
    +------------------------+ +------------------+
```

## License

Released under [Apache 2 license](https://github.com/UrbanOS-Public/reaper/blob/master/LICENSE).
