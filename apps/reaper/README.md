# Reaper

Retrieves data, decodes it, and loads it onto a Kafka topic

## To run the tests

  * Run `mix test` to run the tests a single time
  * Run `mix test.watch` to re-run the tests when a file changes
  * Run `mix test.watch --stale` to only rerun the tests for modules that have changes
  * Run `mix test.integration` to run the integration tests

## To build a reaper docker image:
  * Go up to the smartcitiesdata directory `cd ../../`
  * `./scripts/build.sh reaper 1.0`
  * You should now see smartcitiesdata/reaper in your list of docker images.

## Running Locally

You can use [Divo](https://hexdocs.pm/divo/) to stand up the external dependencies locally using docker and docker-compose.

```bash
MIX_ENV=integration mix docker.start
MIX_ENV=integration iex -S mix
```

## Environment Variables used for configuration

| Variable | Description | Example |
| -------- | ----------- | ------- |
| KAFKA_BROKERS | comma delimited list of kafka brokers | kafka1.com:9092,kafka2.com:9092 |
| TO_TOPIC | topic unto which we do the raw data | raw |
| HOST_IP | local IP address; used for integration tests | 127.0.0.1 |
| REDIS_HOST | IP address or DNS Entry of the redis host | 10.0.0.2 |
| DLQ_TOPIC | Kafka topic name for the dead letter queue | streaming-dlq |
| RUN_IN_KUBERNETES | Set to "true" if running in kubernetes | true |


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

### Example Messages

The following code will create a datafeed which will pull down a sample file on a cadence of 30 seconds. As a result, messages containing the data to be posted to the `raw` topic on the cadence.  The sourceUrl key needs to be a publicly available json file.
```elixir
message = %{
        "id" => "222a39a5-e190-43c9-8c67-2c63885e5d51",
        "name" => "sample_ingestion",
        "allow_duplicates" => true,
        "cadence" => "*/30 * * * * *",
        "extractSteps" => [
            %{
                "type" => "http", 
                "context" => %{
                    "url" => "https://jsonplaceholder.typicode.com/posts/1", 
                  	"body" => %{},
                  	"headers" => %{},
                  	"protocol" => nil,
                  	"queryParams" => %{},
                    "action" => "GET"
                },
                "assigns" => %{},
              	"sequence" => 1
            }
        ],
        "schema" => [
            %{
                "userId" => "integer",
                "id" => "integer",
                "title" => "string",
                "body" => "string"
            }
        ],
        "sourceFormat" => "application/json",
        "targetDataset" => "68995b30-e2d8-4a5e-9951-6dc9e9184d40",
        "topLevelSelector" => nil,
        "transformations" => []
    }

 ingestion = SmartCity.Ingestion.new(message)
 Brook.Event.send(Reaper.instance_name(), "ingestion:update", :reaper, ingestion)
```

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
