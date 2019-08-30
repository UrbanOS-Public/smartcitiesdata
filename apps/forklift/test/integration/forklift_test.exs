defmodule PersistenceTest do
  use ExUnit.Case
  require Logger
  use Divo
  use Placebo
  import Record, only: [defrecord: 2, extract: 2]
  import SmartCity.Event, only: [dataset_update: 0]

  alias Forklift.TopicManager
  alias SmartCity.TestDataGenerator, as: TDG

  defrecord :kafka_message, extract(:kafka_message, from_lib: "kafka_protocol/include/kpro_public.hrl")

  @redis Forklift.Application.redis_client()
  @endpoints Application.get_env(:forklift, :elsa_brokers)

  test "should insert records into Presto" do
    system_name = "Organization1__Dataset1"

    dataset =
      TDG.create_dataset(
        id: "ds1",
        technical: %{
          systemName: system_name,
          schema: [
            %{"name" => "id", "type" => "int"},
            %{"name" => "name", "type" => "string"}
          ]
        }
      )

    "create table #{system_name} (id integer, name varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()

    Brook.Event.send(dataset_update(), :author, dataset)
    TopicManager.wait_for_topic("integration-ds1")

    data = TDG.create_data(dataset_id: "ds1", payload: %{"id" => 1, "name" => "George"})
    Elsa.produce(@endpoints, "integration-ds1", [{"key", Jason.encode!(data)}])

    eventually(fn ->
      assert [[1, "George"]] == prestige_execute("select id, name from #{system_name}")
    end)

    eventually(fn ->
      assert {:ok, _} = Redix.command(@redis, ["GET", "forklift:last_insert_date:" <> dataset.id])
    end)
  end

  test "sends messsages to streaming-persisted topic with timing information" do
    system_name = "Organization1__TimingDataset"

    dataset =
      TDG.create_dataset(
        id: "ds3",
        technical: %{
          systemName: system_name,
          schema: [%{"name" => "id", "type" => "int"}, %{"name" => "name", "type" => "string"}]
        }
      )

    "create table #{system_name} (id integer, name varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()

    Brook.Event.send(dataset_update(), :author, dataset)
    TopicManager.wait_for_topic("integration-ds3")

    data = TDG.create_data(dataset_id: "ds3", payload: %{"id" => 1, "name" => "George"})
    Elsa.produce(@endpoints, "integration-ds3", [{"key", Jason.encode!(data)}])

    eventually(fn ->
      data_messages = fetch_kafka_messages("streaming-persisted")

      assert [data_message | _] = data_messages
      assert length(data_message.operational.timing) == 3
    end)
  end

  @tag timeout: 120_000
  test "should retry inserting records into Presto until it succeeds" do
    system_name = "Organization1__FailingDataset"
    InvocationTracker.init()

    allow Forklift.Messages.PersistenceClient.upload_data(any(), any()),
      meck_options: [:passthrough],
      exec: fn dataset_id, messages ->
        InvocationTracker.record()

        if InvocationTracker.time_passed() > 5_000 do
          "create table #{system_name} (id integer, name varchar)"
          |> Prestige.execute()
          |> Prestige.prefetch()
        end

        :meck.passthrough([dataset_id, messages])
      end

    dataset =
      TDG.create_dataset(
        id: "ds2",
        technical: %{
          systemName: system_name,
          schema: [%{"name" => "id", "type" => "int"}, %{"name" => "name", "type" => "string"}]
        }
      )

    Brook.Event.send(dataset_update(), :author, dataset)
    TopicManager.wait_for_topic("integration-ds2")

    data = TDG.create_data(dataset_id: "ds2", payload: %{"id" => 1, "name" => "George"})
    Elsa.produce(@endpoints, "integration-ds2", [{"key", Jason.encode!(data)}])

    eventually(fn ->
      assert [[1, "George"]] == prestige_execute("select id, name from #{system_name}")
    end)

    assert InvocationTracker.count() < 10
  end

  test "should insert nested records into presto" do
    system_name = "Organization2__Dataset2"

    dataset =
      TDG.create_dataset(
        id: "ds4",
        technical: %{
          systemName: system_name,
          schema: get_complex_nested_schema()
        }
      )

    ~s|CREATE TABLE IF NOT EXISTS #{system_name} (
      "first_name" varchar,
      "age" bigint,
      "friend_names" array(varchar),
      "friends" array(row("first_name" varchar, "pet" varchar)),
      "spouse" row(
        "first_name" varchar,
        "gender" varchar,
        "next_of_kin" row("first_name" varchar, "date_of_birth" varchar)
      )
    )|
    |> Prestige.execute()
    |> Prestige.prefetch()

    Brook.Event.send(dataset_update(), :author, dataset)
    TopicManager.wait_for_topic("integration-ds4")

    data = TDG.create_data(dataset_id: "ds4", payload: get_complex_nested_data())
    Elsa.produce(@endpoints, "integration-ds4", [{"key", Jason.encode!(data)}])

    expected_record = [
      "Joe",
      10,
      ["bob", "sally"],
      [["Bill", "Bunco"], ["Sally", "Bosco"]],
      ["Susan", "female", ["Joel", "1941-07-12"]]
    ]

    eventually(fn ->
      assert [expected_record] == prestige_execute("select * from #{system_name}")
    end)

    eventually(fn ->
      assert {:ok, _} = Redix.command(@redis, ["GET", "forklift:last_insert_date:" <> dataset.id])
    end)
  end

  defp get_complex_nested_schema() do
    [
      %{name: "first_name", type: "string"},
      %{name: "age", type: "long"},
      %{name: "friend_names", type: "list", itemType: "string"},
      %{
        name: "friends",
        type: "list",
        itemType: "map",
        subSchema: [
          %{name: "first_name", type: "string"},
          %{name: "pet", type: "string"}
        ]
      },
      %{
        name: "spouse",
        type: "map",
        subSchema: [
          %{name: "first_name", type: "string"},
          %{name: "gender", type: "string"},
          %{
            name: "next_of_kin",
            type: "map",
            subSchema: [
              %{name: "first_name", type: "string"},
              %{name: "date_of_birth", type: "string"}
            ]
          }
        ]
      }
    ]
  end

  defp get_complex_nested_data() do
    %{
      first_name: "Joe",
      age: 10,
      friend_names: ["bob", "sally"],
      friends: [
        %{first_name: "Bill", pet: "Bunco"},
        %{first_name: "Sally", pet: "Bosco"}
      ],
      spouse: %{
        first_name: "Susan",
        gender: "female",
        next_of_kin: %{
          first_name: "Joel",
          date_of_birth: "1941-07-12"
        }
      }
    }
  end

  defp prestige_execute(statement) do
    Prestige.execute(statement) |> Prestige.prefetch()
  rescue
    e ->
      Logger.warn("Failed querying presto : #{Exception.message(e)}")
      []
  end

  defp fetch_kafka_messages(topic) do
    case :brod.fetch(@endpoints, topic, 0, 0) do
      {:ok, {_offset, messages = [_ | _]}} ->
        messages
        |> Enum.map(fn message -> {kafka_message(message, :key), kafka_message(message, :value)} end)
        |> Enum.map(fn {_key, body} -> Jason.decode!(body, keys: :atoms) end)

      _ ->
        []
    end
  end

  defp eventually(block) do
    SmartCity.TestHelper.eventually(block, 1000, 30)
  end
end

defmodule InvocationTracker do
  def init() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def record() do
    Agent.update(__MODULE__, fn s -> [Time.utc_now() | s] end)
  end

  def time_passed() do
    Agent.get(__MODULE__, fn s ->
      case length(s) do
        0 -> 0
        _ -> Time.diff(List.first(s), List.last(s), :millisecond)
      end
    end)
  end

  def count() do
    Agent.get(__MODULE__, fn s -> length(s) end)
  end
end
