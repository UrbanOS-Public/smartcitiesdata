defmodule Forklift.CompactDatasetTest do
  use ExUnit.Case
  use Divo
  require Logger

  alias Forklift.Datasets.DatasetCompactor
  alias SmartCity.TestDataGenerator, as: TDG

  test "the compactor can pause a dataset by killing its supervisor" do
    dataset =
      TDG.create_dataset(
        id: "ds1",
        technical: %{
          schema: [%{"name" => "id", "type" => "int"}, %{"name" => "name", "type" => "string"}]
        }
      )

    "create table #{dataset.technical.systemName} (id integer, name varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()

    SmartCity.Dataset.write(dataset)

    assert supervisor_eventually_exists(dataset.id) == :ok

    DatasetCompactor.pause_ingest(dataset.id)

    assert supervisor_eventually_is_gone(dataset.id) == :ok

    data = TDG.create_data(dataset_id: "ds1", payload: %{"id" => 1, "name" => "George"})
    SmartCity.KafkaHelper.send_to_kafka(data, "integration-ds1")

    assert Patiently.wait_for(
             prestige_query("select id, name from #{dataset.technical.systemName}", [
               [1, "George"]
             ]),
             dwell: 100,
             max_tries: 10
           ) == :error
  end

  test "the compactor can resume a dataset by passing it to the handler again" do
    dataset =
      TDG.create_dataset(
        id: "ds2",
        technical: %{
          schema: [%{name: "id", type: "int"}, %{name: "name", type: "string"}]
        }
      )

    "create table #{dataset.technical.systemName} (id integer, name varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()

    SmartCity.Dataset.write(dataset)

    assert supervisor_eventually_exists(dataset.id) == :ok

    DatasetCompactor.pause_ingest(dataset.id)

    assert supervisor_eventually_is_gone(dataset.id) == :ok

    data = TDG.create_data(dataset_id: "ds2", payload: %{"id" => 1, "name" => "George"})
    SmartCity.KafkaHelper.send_to_kafka(data, "integration-ds2")

    DatasetCompactor.resume_ingest(dataset)

    assert supervisor_eventually_exists(dataset.id) == :ok

    Patiently.wait_for!(
      prestige_query("select id, name from #{dataset.technical.systemName}", [[1, "George"]]),
      dwell: 1000,
      max_tries: 60
    )
  end

  test "queries to compact a dataset are sent and valid" do
    dataset =
      TDG.create_dataset(
        id: "ds3",
        technical: %{
          schema: [%{name: "id", type: "int"}, %{name: "name", type: "string"}]
        }
      )

    "create table #{dataset.technical.systemName} (id integer, name varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()

    SmartCity.Dataset.write(dataset)

    supervisor_eventually_exists(dataset.id)

    data = TDG.create_data(dataset_id: "ds3", payload: %{"id" => 1, "name" => "George"})
    SmartCity.KafkaHelper.send_to_kafka(data, "integration-ds3")

    Patiently.wait_for!(
      prestige_query("select id, name from #{dataset.technical.systemName}", [[1, "George"]]),
      dwell: 200,
      max_tries: 10
    )

    assert DatasetCompactor.compact_dataset(dataset) == :ok

    tables =
      "show tables"
      |> Prestige.execute()
      |> Prestige.prefetch()
      |> List.flatten()

    system_name = String.downcase(dataset.technical.systemName)
    assert "#{system_name}" in tables
    assert "#{system_name}_archive" in tables
    refute "#{system_name}_compact" in tables
  end

  defp supervisor_eventually_exists(dataset_id) do
    Patiently.wait_for!(
      fn ->
        Process.whereis(:"elsa_supervisor_name-integration-#{dataset_id}") != nil
      end,
      dwell: 200,
      max_tries: 20
    )
  rescue
    _ -> flunk("Supervisor for #{dataset_id} was never found")
  end

  defp supervisor_eventually_is_gone(dataset_id) do
    Patiently.wait_for!(
      fn ->
        Process.whereis(:"elsa_supervisor_name-integration-#{dataset_id}") == nil
      end,
      dwell: 200,
      max_tries: 20
    )
  rescue
    _ -> flunk("Supervisor for #{dataset_id} remains when it should be gone")
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
end
