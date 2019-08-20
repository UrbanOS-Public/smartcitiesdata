defmodule Forklift.CompactDatasetTest do
  use ExUnit.Case
  use Divo
  require Logger

  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  @module_user "carpenter"

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
    |> Prestige.execute(user: @module_user)
    |> Prestige.prefetch()

    SmartCity.Dataset.write(dataset)

    assert supervisor_eventually_exists(dataset.id) == :ok

    DatasetCompactor.pause_ingest(dataset.id)

    assert supervisor_eventually_is_gone(dataset.id) == :ok
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
    |> Prestige.execute(user: @module_user)
    |> Prestige.prefetch()

    SmartCity.Dataset.write(dataset)

    assert supervisor_eventually_exists(dataset.id) == :ok

    DatasetCompactor.pause_ingest(dataset.id)

    assert supervisor_eventually_is_gone(dataset.id) == :ok

    data = TDG.create_data(dataset_id: "ds2", payload: %{"id" => 1, "name" => "George"})
    SmartCity.KafkaHelper.send_to_kafka(data, "integration-ds2")

    DatasetCompactor.resume_ingest(dataset)

    assert supervisor_eventually_exists(dataset.id) == :ok

    eventually(
      fn ->
        actual =
          "select id, name from #{dataset.technical.systemName}"
          |> Prestige.execute(user: @module_user)
          |> Prestige.prefetch()

        assert actual == [[1, "George"]]
      end,
      1000,
      60
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
    |> Prestige.execute(user: @module_user)
    |> Prestige.prefetch()

    SmartCity.Dataset.write(dataset)

    supervisor_eventually_exists(dataset.id)

    data = TDG.create_data(dataset_id: "ds3", payload: %{"id" => 1, "name" => "George"})
    SmartCity.KafkaHelper.send_to_kafka(data, "integration-ds3")

    eventually(
      fn ->
        actual =
          "select id, name from #{dataset.technical.systemName}"
          |> Prestige.execute(user: @module_user)
          |> Prestige.prefetch()

        assert actual == [[1, "George"]]
      end,
      200,
      10
    )

    assert DatasetCompactor.compact_dataset(dataset) == :ok

    tables =
      "show tables"
      |> Prestige.execute(user: @module_user)
      |> Prestige.prefetch()
      |> List.flatten()

    system_name = String.downcase(dataset.technical.systemName)
    assert "#{system_name}" in tables
    refute "#{system_name}_compact" in tables
  end

  test "non-existing table is handled" do
    dataset =
      TDG.create_dataset(
        id: "ds3",
        technical: %{
          schema: [%{name: "id", type: "int"}, %{name: "name", type: "string"}]
        }
      )

    SmartCity.Dataset.write(dataset)
    supervisor_eventually_exists(dataset.id)

    assert DatasetCompactor.compact_dataset(dataset) == :error
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
end
