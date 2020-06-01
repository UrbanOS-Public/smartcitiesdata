defmodule DiscoveryStreams.TopicSubscriberTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_delete: 0]

  @instance :discovery_streams
  @endpoints Application.get_env(:kaffe, :consumer)[:endpoints]
  @input_topic_prefix Application.get_env(:discovery_streams, :topic_prefix, "transformed-")

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

  test "should delete all view state for the dataset and the input topic when dataset:delete is called" do
    dataset_id = Faker.UUID.v4()
    system_name = Faker.UUID.v4()
    input_topic = "#{@input_topic_prefix}#{dataset_id}"
    dataset = TDG.create_dataset(id: dataset_id, technical: %{sourceType: "stream", systemName: system_name})
    Brook.Event.send(@instance, data_ingest_start(), :author, dataset)

    eventually(
      fn ->
        assert {:ok, system_name} == Brook.ViewState.get(@instance, :streaming_datasets_by_id, dataset_id)
        assert {:ok, dataset_id} == Brook.ViewState.get(@instance, :streaming_datasets_by_system_name, system_name)
        assert true == Elsa.Topic.exists?(@endpoints, input_topic)
      end,
      2_000,
      10
    )

    Brook.Event.send(@instance, dataset_delete(), :author, dataset)

    eventually(
      fn ->
        assert {:ok, nil} == Brook.ViewState.get(@instance, :streaming_datasets_by_id, dataset_id)
        assert {:ok, nil} == Brook.ViewState.get(@instance, :streaming_datasets_by_system_name, system_name)
        assert false == Elsa.Topic.exists?(@endpoints, input_topic)
      end,
      2_000,
      10
    )
  end

  test "discovery_streams doesn't return server in response headers" do
    %HTTPoison.Response{status_code: _, headers: headers, body: _} = 
       "http://localhost:4001/socket/nodelist"
       |> HTTPoison.get!()

    refute headers |> Map.new() |> Map.has_key?("server")
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
