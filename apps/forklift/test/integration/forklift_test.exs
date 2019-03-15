defmodule PersistenceTest do
  use ExUnit.Case
  require Logger
  alias Reaper.Persistence
  alias Reaper.ReaperConfig
  use Divo.Integration

  @dataset_id "12345-3323"

  test "should insert records into Presto" do
    Prestige.execute("create table basic (id integer, name varchar)")
    |> Prestige.prefetch()

    Mockaffe.create_message(:registry, :basic) |> Mockaffe.send_to_kafka("dataset-registry")
    Mockaffe.create_message(:data, :basic) |> Mockaffe.send_to_kafka("streaming-transformed")

    Patiently.wait_for!(
      prestige_query("select * from basic", [""]),
      dwell: 1000,
      max_tries: 20
    )
  end

  defp prestige_query(statement, expected) do
    fn ->
      actual =
        statement
        |> Prestige.execute()
        |> Prestige.prefetch()

      Logger.info("Waiting for #{actual} to equal #{expected}")

      try do
        assert actual == expected
        true
      rescue
        _ -> false
      end
    end
  end
end
