defmodule PersistenceTest do
  use ExUnit.Case
  require Logger
  use Divo

  alias SmartCity.TestDataGenerator, as: TDG

  test "should insert records into Presto" do
    system_name = "Organization1__Dataset1"

    reg_message =
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

    SmartCity.KafkaHelper.send_to_kafka(reg_message, "dataset-registry")

    data = TDG.create_data(dataset_id: "ds1", payload: %{"id" => 1, "name" => "George"})
    SmartCity.KafkaHelper.send_to_kafka(data, "streaming-transformed")

    Patiently.wait_for!(
      prestige_query("select id, name from #{system_name}", [[1, "George"]]),
      dwell: 1000,
      max_tries: 30
    )
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
end
