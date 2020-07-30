# ProtocolSource

Defines a protocol data sources -- where data is coming from.

## Usage

Implementing this protocol requires three functions: `start_link/2`, `stop/2`,
and `delete/1`. The difference between `stop/2` and `delete/1` is nuanced but
important.

You (likely) want to rarely destroy a source. This is akin to deleting a Kafka
topic or dropping a table. It's more likely that you want to shutdown the
processes used to manage a table or topic. That's what `stop/2` is for.

See [Kafka.Topic.Source](../definition_kafka/lib/kafka/topic/source.ex) as an
example.

## Installation

```elixir
def deps do
  [
    {:protocol_source, in_umbrella: true}
  ]
end
```
