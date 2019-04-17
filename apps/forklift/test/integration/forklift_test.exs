defmodule PersistenceTest do
  use ExUnit.Case
  require Logger
  use Divo

  alias Forklift.DatasetSchema

  alias SmartCity.TestDataGenerator, as: TDG

  @redis Forklift.Application.redis_client()
  @endpoint Application.get_env(:yeet, :endpoint)
  @topic Application.get_env(:yeet, :topic)

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

    data = TDG.create_data(dataset_id: "ds1", payload: %{"id" => 1, "name" => "George"})
    SmartCity.KafkaHelper.send_to_kafka(data, "streaming-transformed")

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

  test "should DLQ records which fail to insert into Presto after a set number of times" do
    system_name = "Organization1__FailingDataset"

    dataset =
      TDG.create_dataset(
        id: "ds2",
        technical: %{
          systemName: system_name,
          schema: [
            %{"name" => "CRAP", "type" => "double"},
            %{"name" => "AGAIN", "type" => "string"},
            %{"name" => "ANOTHER", "type" => "string"}
          ]
        }
      )

    SmartCity.Dataset.write(dataset)

    TDG.create_data(dataset_id: "ds2", payload: %{"id" => 1, "UNKNOWN" => "George"})
    |> SmartCity.KafkaHelper.send_to_kafka("streaming-transformed")

    Patiently.wait_for!(
      fn ->
        {:ok, count} = @redis.command(["XLEN", "forklift:data:ds2"])
        count > 0
      end,
      dwell: 1000,
      max_tries: 30
    )

    Patiently.wait_for!(
      fn ->
        {:ok, messages} = :brod.fetch(@endpoint, @topic, 0, 0)
        length(messages) > 0
      end,
      dwell: 1000,
      max_tries: 30
    )

    Patiently.wait_for!(
      fn ->
        {:ok, count} = @redis.command(["XLEN", "forklift:data:ds2"])
        count == 0
      end,
      dwell: 1000,
      max_tries: 30
    )
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

    data = TDG.create_data(dataset_id: "ds1", payload: get_complex_nested_data())
    SmartCity.KafkaHelper.send_to_kafka(data, "streaming-transformed")

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

      case @redis.command(["GET", "forklift:last_insert_date:" <> dataset_id]) do
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
      actual =
        statement
        |> Prestige.execute()
        |> Prestige.prefetch()

      Logger.info("Waiting for #{inspect(actual)} to equal #{inspect(expected)}")

      try do
        assert actual == expected
        true
      rescue
        _ -> false
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
end
