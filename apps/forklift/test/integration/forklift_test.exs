defmodule PersistenceTest do
  use ExUnit.Case
  require Logger
  use Divo
  use Placebo
  import Record, only: [defrecord: 2, extract: 2]

  alias SmartCity.TestDataGenerator, as: TDG

  defrecord :kafka_message, extract(:kafka_message, from_lib: "kafka_protocol/include/kpro_public.hrl")

  @redis Forklift.Application.redis_client()
  @endpoint Application.get_env(:yeet, :endpoint)

  test "should insert records into Presto" do
    system_name = "Organization1__Dataset1"

    dataset =
      TDG.create_dataset(
        id: "ds1",
        technical: %{
          systemName: system_name,
          schema: [%{"name" => "id", "type" => "int"}, %{"name" => "name", "type" => "string"}]
        }
      )

    "create table #{system_name} (id integer, name varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()

    SmartCity.Dataset.write(dataset)
    wait_for_topic("integration-ds1")

    data = TDG.create_data(dataset_id: "ds1", payload: %{"id" => 1, "name" => "George"})
    SmartCity.KafkaHelper.send_to_kafka(data, "integration-ds1")

    Patiently.wait_for!(
      prestige_query("select id, name from #{system_name}", [[1, "George"]]),
      dwell: 1000,
      max_tries: 30
    )

    Patiently.wait_for!(
      redis_query(dataset.id),
      dwell: 1000,
      max_tries: 30
    )
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

    SmartCity.Dataset.write(dataset)
    wait_for_topic("integration-ds3")

    data = TDG.create_data(dataset_id: "ds3", payload: %{"id" => 1, "name" => "George"})
    SmartCity.KafkaHelper.send_to_kafka(data, "integration-ds3")

    Patiently.wait_for!(
      fn ->
        {:ok, {_offset, messages}} = :brod.fetch(@endpoint, "streaming-persisted", 0, 0)

        if length(messages) > 0 do
          message =
            messages
            |> Enum.map(fn message -> {kafka_message(message, :key), kafka_message(message, :value)} end)
            |> Enum.map(fn {_key, body} -> Jason.decode!(body, keys: :atoms) end)
            |> List.first()

          length(message.operational.timing) == 3
        else
          false
        end
      end,
      dwell: 1000,
      max_tries: 30
    )
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

    SmartCity.Dataset.write(dataset)
    wait_for_topic("integration-ds2")

    TDG.create_data(dataset_id: "ds2", payload: %{"id" => 1, "name" => "George"})
    |> SmartCity.KafkaHelper.send_to_kafka("integration-ds2")

    Patiently.wait_for!(
      prestige_query("select id, name from #{system_name}", [[1, "George"]]),
      dwell: 1000,
      max_tries: 60
    )

    assert InvocationTracker.count() < 10
  end

  test "should insert nested records into presto" do
    system_name = "Organization2__Dataset2"

    dataset =
      TDG.create_dataset(
        id: "ds1",
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

    SmartCity.Dataset.write(dataset)
    wait_for_topic("integration-ds1")

    data = TDG.create_data(dataset_id: "ds1", payload: get_complex_nested_data())
    SmartCity.KafkaHelper.send_to_kafka(data, "integration-ds1")

    expected_record = [
      "Joe",
      10,
      ["bob", "sally"],
      [["Bill", "Bunco"], ["Sally", "Bosco"]],
      ["Susan", "female", ["Joel", "1941-07-12"]]
    ]

    Patiently.wait_for!(
      prestige_query("select * from #{system_name}", [expected_record]),
      dwell: 1000,
      max_tries: 30
    )

    Patiently.wait_for!(
      redis_query(dataset.id),
      dwell: 1000,
      max_tries: 30
    )
  end

  defp redis_query(dataset_id) do
    fn ->
      Logger.info("Waiting for redis last_insert_date to update for dataset id " <> dataset_id)

      case Redix.command(@redis, ["GET", "forklift:last_insert_date:" <> dataset_id]) do
        {:ok, nil} ->
          false

        {:ok, _result} ->
          true

        {:error, reason} ->
          Logger.warn("Error when talking to redis : REASON - #{inspect(reason)}")
          false
      end
    end
  end

  defp prestige_query(statement, expected) do
    fn ->
      try do
        actual =
          statement
          |> Prestige.execute()
          |> Prestige.prefetch()

        Logger.info("Waiting for #{inspect(actual)} to equal #{inspect(expected)}")

        actual == expected
      rescue
        e ->
          Logger.warn("Failed querying presto : #{Exception.message(e)}")
          false
      end
    end
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

  defp wait_for_topic(topic) do
    Patiently.wait_for!(
      fn ->
        Forklift.TopicManager.is_topic_ready?(topic)
      end,
      dwell: 200,
      max_tries: 20
    )
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
