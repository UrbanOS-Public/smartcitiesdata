defmodule DiscoveryStreams.DiscoveryStreamsTest do
  use ExUnit.Case
  use DiscoveryStreamsWeb.ChannelCase
  use Placebo
  import Checkov

  use Divo
  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryStreams.TopicHelper
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0, dataset_update: 0, dataset_delete: 0]

  @instance_name DiscoveryStreams.instance_name()
  @unauthorized_private_system_name "private__data"

  setup_all do
    bypass = Bypass.open()

    Bypass.stub(bypass, "GET", "/api/authorize", fn conn ->
      system_name =
        conn
        |> Plug.Conn.fetch_query_params()
        |> Map.get(:query_params)
        |> Map.get("systemName")

      if system_name == @unauthorized_private_system_name do
        Plug.Conn.resp(conn, 200, "{\"is_authorized\":false}")
      else
        Plug.Conn.resp(conn, 200, "{\"is_authorized\":true}")
      end
    end)

    Application.put_env(:discovery_streams, :raptor_url, "http://localhost:#{bypass.port}/api/authorize")

    :ok
  end

  test "broadcasts data to end users" do
    dataset1 = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream", private: false})
    Brook.Test.send(@instance_name, data_ingest_start(), :author, dataset1)

    {:ok, _, _socket} =
      DiscoveryStreamsWeb.UserSocket
      |> socket()
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{dataset1.technical.systemName}")

    Process.sleep(10_000)

    Elsa.Producer.produce(
      TopicHelper.get_endpoints(),
      TopicHelper.topic_name(dataset1.id),
      [create_message(%{foo: "bar"}, topic: dataset1.id)],
      parition: 0
    )

    assert_push("update", %{"foo" => "bar"}, 15_000)
  end

  test "broadcasts starting at latest offset" do
    dataset1 = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream", private: false})
    Elsa.create_topic(TopicHelper.get_endpoints(), TopicHelper.topic_name(dataset1.id))

    Process.sleep(10_000)

    Elsa.Producer.produce(
      TopicHelper.get_endpoints(),
      TopicHelper.topic_name(dataset1.id),
      [create_message(%{dont: "readme"}, topic: dataset1.id)],
      parition: 0
    )

    Brook.Test.send(@instance_name, data_ingest_start(), :author, dataset1)

    {:ok, _, _socket} =
      DiscoveryStreamsWeb.UserSocket
      |> socket()
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{dataset1.technical.systemName}")

    refute_push("update", %{"dont" => "readme"}, 15_000)
  end

  test "doesnt broadcast private datasets if unauthorized" do
    private_dataset =
      TDG.create_dataset(
        id: Faker.UUID.v4(),
        technical: %{sourceType: "stream", private: true, systemName: @unauthorized_private_system_name}
      )

    Brook.Test.send(@instance_name, data_ingest_start(), :author, private_dataset)

    assert {:error, _} =
             DiscoveryStreamsWeb.UserSocket
             |> socket()
             |> subscribe_and_join(
               DiscoveryStreamsWeb.StreamingChannel,
               "streaming:#{private_dataset.technical.systemName}"
             )
  end

  data_test "stops broadcasting after #{scenario}" do
    dataset = TDG.create_dataset(id: Faker.UUID.v4(), technical: %{sourceType: "stream", private: false})
    Brook.Test.send(@instance_name, data_ingest_start(), :author, dataset)

    {:ok, _, _socket} =
      DiscoveryStreamsWeb.UserSocket
      |> socket()
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{dataset.technical.systemName}")

    Process.sleep(10_000)

    Elsa.Producer.produce(
      TopicHelper.get_endpoints(),
      TopicHelper.topic_name(dataset.id),
      [create_message(%{foo: "bar"}, topic: dataset.id)],
      parition: 0
    )

    assert_push("update", %{"foo" => "bar"}, 15_000)

    dataset =
      if update_path do
        put_in(dataset, update_path, update_value)
      else
        dataset
      end

    Brook.Test.send(@instance_name, event, :author, dataset)

    # Nothing else was consistent here.  Checking for elsa.topic? will return that its dead before kafka is happy to recreate
    # We probably dont need this actual integration test
    Process.sleep(15_000)

    Elsa.create_topic(TopicHelper.get_endpoints(), TopicHelper.topic_name(dataset.id))

    Elsa.Producer.produce(
      TopicHelper.get_endpoints(),
      TopicHelper.topic_name(dataset.id),
      [create_message(%{dont: "sendme"}, topic: dataset.id)],
      parition: 0
    )

    refute_push("update", %{"dont" => "sendme"}, 10_000)

    where([
      [:scenario, :event, :update_path, :update_value],
      ["dataset deleted", dataset_delete(), nil, nil],
      ["made private by update", dataset_update(), [:technical, :private], true]
    ])
  end

  test "should delete all view state for the dataset and the input topic when dataset:delete is called" do
    dataset_id = Faker.UUID.v4()
    system_name = Faker.UUID.v4()
    dataset = TDG.create_dataset(id: dataset_id, technical: %{sourceType: "stream", systemName: system_name})

    Brook.Test.send(@instance_name, data_ingest_start(), :author, dataset)

    eventually(
      fn ->
        assert {:ok, system_name} == Brook.ViewState.get(@instance_name, :streaming_datasets_by_id, dataset_id)
        assert {:ok, dataset_id} == Brook.ViewState.get(@instance_name, :streaming_datasets_by_system_name, system_name)
        assert true == Elsa.Topic.exists?(TopicHelper.get_endpoints(), TopicHelper.topic_name(dataset_id))
      end,
      2_000,
      10
    )

    Brook.Test.send(@instance_name, dataset_delete(), :author, dataset)

    eventually(
      fn ->
        assert {:ok, nil} == Brook.ViewState.get(@instance_name, :streaming_datasets_by_id, dataset_id)
        assert {:ok, nil} == Brook.ViewState.get(@instance_name, :streaming_datasets_by_system_name, system_name)
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
