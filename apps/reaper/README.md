# Reaper

Retrieves streamed data, transforms it, and loads it onto a Kafka topic -- generically

## Environment Variables used for configuration

| Variable | Description | Example |
| -------- | ----------- | ------- |
| KAFKA_BROKERS | comma delimited list of kafka brokers | kafka1.com:9092,kafka2.com:9092 |
| TO_TOPIC | topic unto which we do the raw data | raw |

## Running Tests

```bash
mix test
```

## Running Integration Tests

Make sure you have `docker-compose` installed and then
```bash
MIX_ENV=integration mix test.integration
```

## Running Interactively

To run in series:

```bash
MIX_ENV=integration mix docker.start
MIX_ENV=integration iex -S mix
```

-or- this to check on counts after the tests have run

```bash
MIX_ENV=integration mix docker.start
MIX_ENV=integration iex -S mix test --no-start
```

To run a local cluster

```bash
MIX_ENV=integration mix docker.start
iex --name a@127.0.0.1 -S mix
iex --name b@127.0.0.1 -S mix
```

You can then verify offsets on the source and destination topic with the following commands.

```elixir
:brod_utils.resolve_offset([{'localhost', 9094}], "dataset-registry", 0, -1, [])
:brod_utils.resolve_offset([{'localhost', 9094}], "raw", 0, -1, [])
```

### Example Messages

The following message should create a datafeed which will point at the integration webserver and pull down a sample file on a cadence of 100 seconds.  This message should be posted to the `dataset-registry` topic and will cause messages to be posted to the `streaming-raw` topic on the cadence:
```
{"business":{"contactEmail":"something@email.example","contactName":"Jalson","dataTitle":"Stuff","description":"dataset","homepage":"","keywords":[],"license":"MIT","modifiedDate":"something","orgTitle":"SCOS","rights":""},"id":"Reaper","technical":{"cadence":100000,"dataName":"name","headers":{"Authorization":"Basic xdasdgdasgdsgd"},"orgName":"Sample_Organization","partitioner":{"query":null,"type":null},"queryParams":{},"schema":[],"sourceFormat":"json","sourceUrl":"localhost:7000/vehicle_locations.json","stream": true,"systemName":"scos","transformations":["a_transform"],"validations":[]}}
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


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `reaper` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:reaper, "~> 0.1.4"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/reaper](https://hexdocs.pm/reaper).
