defmodule Kafka.TopicTest do
  use ExUnit.Case

  test "can be serialized and deserialized by brook" do
    source =
      Kafka.Topic.new!(
        name: "topic",
        endpoints: [localhost: 9092]
      )

    expected = %{
      "__type__" => "kafka_topic",
      "endpoints" => [
        %{
          "__type__" => "tuple",
          "values" => [%{"__type__" => "atom", "value" => "localhost"}, 9092]
        }
      ],
      "key_path" => [],
      "name" => "topic",
      "partitioner" => %{"__type__" => "atom", "value" => "default"},
      "partitions" => 1,
      "version" => 1
    }

    serialized = JsonSerde.serialize!(source)

    assert expected == Jason.decode!(serialized)
    assert source == JsonSerde.deserialize!(serialized)
  end
end
