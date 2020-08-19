defmodule DiscoveryStreams.DiscoveryStreamsTest do
  use ExUnit.Case
  use DiscoveryStreamsWeb.ChannelCase
  use Placebo

  use Divo
  alias SmartCity.TestDataGenerator, as: TDG
  alias  DiscoveryStreams.TopicHelper
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_delete: 0]

  @instance :discovery_streams

  test "broadcasts data to end users" do
    dataset1 = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream", private: false})
    Brook.Event.send(@instance, data_ingest_start(), :author, dataset1)
    wait_for_event()

    {:ok, _, socket} =
      DiscoveryStreamsWeb.UserSocket
      |> socket()
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{dataset1.technical.systemName}")

    Elsa.create_topic(TopicHelper.get_endpoints(), TopicHelper.topic_name(dataset1.id))
    Elsa.Producer.produce(TopicHelper.get_endpoints(), TopicHelper.topic_name(dataset1.id), [create_message(%{foo: "bar"}, [topic: dataset1.id])], parition: 0)

    assert_push("update", %{"foo" => "bar"}, 10_000)
  end

  test "doesnt broadcast private datasets" do
    private_dataset = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream", private: true})

    Brook.Event.send(@instance, data_ingest_start(), :author, private_dataset)
    wait_for_event()

    allow(DiscoveryStreams.EventHandler.handle_event(:spy_only), return: :spy_only)

    eventually(
      fn ->
        assert called? DiscoveryStreams.EventHandler.handle_event(any())
      end,
      500,
      10
    )

    assert {:error, _} =
      DiscoveryStreamsWeb.UserSocket
      |> socket()
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{private_dataset.technical.systemName}")
  end

  # test "stops broadcasting after a delete event" do
  #   dataset1 = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream", private: false})
  #   Brook.Event.send(@instance, data_ingest_start(), :author, dataset1)

  #   {:ok, _, socket} =
  #     DiscoveryStreamsWeb.UserSocket
  #     |> socket()
  #     |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{dataset1.technical.systemName}")

  #   Elsa.create_topic(TopicHelper.get_endpoints(), TopicHelper.topic_name(dataset1.id))
  #   Elsa.Producer.produce(TopicHelper.get_endpoints(), TopicHelper.topic_name(dataset1.id), [create_message(%{foo: "bar"}, [topic: dataset1.id])], parition: 0)

  #   assert_push("update", %{"foo" => "bar"})
  # end

  test "should delete all view state for the dataset and the input topic when dataset:delete is called" do
    dataset_id = Faker.UUID.v4()
    system_name = Faker.UUID.v4()
    dataset = TDG.create_dataset(id: dataset_id, technical: %{sourceType: "stream", systemName: system_name})

    Brook.Event.send(@instance, data_ingest_start(), :author, dataset)

    eventually(
      fn ->
        assert {:ok, system_name} == Brook.ViewState.get(@instance, :streaming_datasets_by_id, dataset_id)
        assert {:ok, dataset_id} == Brook.ViewState.get(@instance, :streaming_datasets_by_system_name, system_name)
        assert true == Elsa.Topic.exists?(TopicHelper.get_endpoints(), TopicHelper.topic_name(dataset_id))
      end,
      2_000,
      10
    )

    Brook.Event.send(@instance, dataset_delete(), :author, dataset)

    eventually(
      fn ->
        assert {:ok, nil} == Brook.ViewState.get(@instance, :streaming_datasets_by_id, dataset_id)
        assert {:ok, nil} == Brook.ViewState.get(@instance, :streaming_datasets_by_system_name, system_name)
        assert false == Elsa.Topic.exists?(TopicHelper.get_endpoints(), TopicHelper.topic_name(dataset_id))
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

  defp wait_for_event() do
    allow(DiscoveryStreams.EventHandler.handle_event(:spy_only), return: :spy_only)

    eventually(
      fn ->
        assert called? DiscoveryStreams.EventHandler.handle_event(any())
      end,
      500,
      10
    )
  end
  defp create_message(%{} = data, opts) do
    create_message(TDG.create_data(payload: data) |> Jason.encode!(), opts)
  end

  defp create_message(data, opts) do
    %{
      key: Keyword.get(opts, :key, "some key"),
      topic: Keyword.get(opts, :topic, "transformed-555ea731-d85e-4bd8-b2e4-4017366c24b0"),
      value: data
    }
  end
end
