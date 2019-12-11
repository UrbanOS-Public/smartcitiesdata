defmodule DiscoveryStreams.TopicSubscriberTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [data_ingest_start: 0]

  @instance DiscoveryStreamsWeb.instance_name()

  test "subscribes to any non internal use topic" do
    private_dataset = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream", private: true})
    Brook.Event.send(@instance, data_ingest_start(), :author, private_dataset)
    dataset1 = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream", private: false})
    Brook.Event.send(@instance, data_ingest_start(), :author, dataset1)

    expected = ["transformed-#{dataset1.id}"]
    expected_cache = [dataset1.id]
    validate_subscribed_topics(expected)
    validate_caches_exist(expected_cache)

    dataset2 = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream", private: false})
    Brook.Event.send(@instance, data_ingest_start(), :author, dataset2)

    expected = ["transformed-#{dataset1.id}", "transformed-#{dataset2.id}"]
    expected_cache = [dataset1.id, dataset2.id]
    validate_subscribed_topics(expected)
    validate_caches_exist(expected_cache)
  end

  defp validate_subscribed_topics(expected) do
    Patiently.wait_for!(
      fn ->
        MapSet.new(subscribed_topics()) == MapSet.new(expected)
      end,
      dwell: 200,
      max_tries: 50
    )
  end

  defp validate_caches_exist(expected) do
    Patiently.wait_for!(
      fn ->
        Enum.all?(expected, fn topic -> not match?({:error, _}, Cachex.count(String.to_atom(topic))) end)
      end,
      dwell: 200,
      max_tries: 50
    )
  end

  defp subscribed_topics() do
    Kaffe.GroupManager.list_subscribed_topics()
  end
end
