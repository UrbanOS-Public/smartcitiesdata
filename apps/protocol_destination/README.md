# ProtocolDestination

Defines a protocol for data destinations -- where data is written or loaded into.

## Usage

Implementing this protocol requires four functions: `start_link/2`, `write/3`, 
`stop/2`, and `delete/1`. The difference between `stop/2` and `delete/1` is
nuanced but important. 

You (likely) want to rarely destroy a destination. This is akin to deleting a 
Kafka topic or dropping a table. It's more likely that you want to shutdown the
processes used to manage a table or topic. That's what `stop/2` is for.

See [Kafka.Topic.Destination](../definition_kafka/lib/kafka/topic/destination.ex)
as an example.

## Installation

```elixir
def deps do
  [
    {:protocol_destination, in_umbrella: true}
  ]
end
```
