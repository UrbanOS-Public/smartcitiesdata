defmodule Kafka.Topic do
  @moduledoc """
  Defines a Kafka topic. Kafka topics are used as message buses
  in Hindsight, allowing data to be passed from one service to another
  without directly coupling those services.

  ## Configuration

  * `name` - Required. Topic name.
  * `endpoints` - Required. Keyword list of Kafka brokers.
  * `partitions` - Number of partitions to create the topic with in Kafka. Defaults to 1.
  * `partitioner` - Method for partitioning messages as they're written to Kafka. Must be one of `[:default, :md5, :random]`.
  * `key_path` - String or list of strings used to parse message key from message content. Defaults to empty list, resulting in no message key (`""`).
  """
  use Definition, schema: Kafka.Topic.V1
  use JsonSerde, alias: "kafka_topic"

  @type t :: %__MODULE__{
          version: integer(),
          endpoints: [{atom, pos_integer}],
          name: String.t(),
          partitions: pos_integer,
          partitioner: :default | :md5 | :random,
          key_path: list
        }

  defstruct version: 1,
            endpoints: nil,
            name: nil,
            partitions: 1,
            partitioner: :default,
            key_path: []

  defimpl Source do
    defdelegate start_link(t, context), to: Kafka.Topic.Source
    defdelegate stop(t, server), to: Kafka.Topic.Source
    defdelegate delete(t), to: Kafka.Topic.Source
  end

  defimpl Destination do
    defdelegate start_link(t, context), to: Kafka.Topic.Destination
    defdelegate write(t, server, messages), to: Kafka.Topic.Destination
    defdelegate stop(t, server), to: Kafka.Topic.Destination
    defdelegate delete(t), to: Kafka.Topic.Destination
  end
end

defmodule Kafka.Topic.V1 do
  @moduledoc false
  use Definition.Schema

  def s do
    schema(%Kafka.Topic{
      version: version(1),
      endpoints: spec(is_list()),
      name: required_string(),
      partitions: spec(pos_integer?()),
      partitioner: spec(fn x -> x in [:default, :random, :md5] end),
      key_path: access_path()
    })
  end
end
