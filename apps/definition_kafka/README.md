# DefinitionKafka

This app defines a `Kafka.Topic` struct and implements protocols for
writing to/streaming from Kafka topics.

## Usage

Create a Kafka topic with its `new/1` function:

```elixir
{:ok, topic} = Kafka.Topic.new(name: "topic-name", endpoints: [localhost: 9092])
```

Topic partitioning configuration can optionally be passed during `new/1` too. By default,
topics have 1 partition and messages are not keyed.

```elixir
{:ok, topic} =
  Kafka.Topic.new(
    name: "topic-name",
    endpoints: [localhost: 9092],
    partitions: 2,
    partitioner: :md5,
    key_path: ["foo", "bar", "baz"]
  )
```

### Write

See [destination](../protocol_destination/README.md) protocol for how to write messages to Kafka using `Kafka.Topic` structs.

### Read

See [source](../protocol_source/README.md) protocol for how to receive messages streaming off a Kafka topic using 
`Kafka.Topic` structs.

## Installation

```elixir
def deps do
  [
    {:definition_kafka, in_umbrella: true}
  ]
end
```
