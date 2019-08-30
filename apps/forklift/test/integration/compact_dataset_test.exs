defmodule Forklift.CompactDatasetTest do
  use ExUnit.Case
  use Divo
  require Logger

  import SmartCity.Event, only: [dataset_update: 0]

  @module_user "carpenter"

  alias Forklift.Datasets.{DatasetSupervisor, DatasetCompactor, DatasetSchema, DatasetHandler}
  alias SmartCity.TestDataGenerator, as: TDG

  test "the dataset handler kills the appropriate dataset supervisor when told to stop an ingest" do
    dataset =
      TDG.create_dataset(
        id: "ds1",
        technical: %{
          schema: [%{"name" => "id", "type" => "int"}, %{"name" => "name", "type" => "string"}]
        }
      )

    schema = DatasetSchema.from_dataset(dataset)

    "create table #{schema.system_name} (id integer, name varchar)"
    |> Prestige.execute(user: @module_user)
    |> Prestige.prefetch()

    %{active: initial_ingest_count} = DynamicSupervisor.count_children(Forklift.Dynamic.Supervisor)

    Brook.Event.send(dataset_update(), :author, dataset)

    eventually(fn ->
      refute match?(%{active: ^initial_ingest_count}, DynamicSupervisor.count_children(Forklift.Dynamic.Supervisor))
      assert child_pid(DatasetSupervisor, schema) in DynamicSupervisor.which_children(Forklift.Dynamic.Supervisor)
    end)

    DatasetHandler.stop_dataset_ingest(schema)

    eventually(fn ->
      assert %{active: ^initial_ingest_count} = DynamicSupervisor.count_children(Forklift.Dynamic.Supervisor)
    end)
  end

  test "the dataset handler starts the appropriate dataset supervisor when told to start an ingest" do
    dataset =
      TDG.create_dataset(
        id: "ds2",
        technical: %{
          schema: [%{name: "id", type: "int"}, %{name: "name", type: "string"}]
        }
      )

    schema = DatasetSchema.from_dataset(dataset)

    "create table #{schema.system_name} (id integer, name varchar)"
    |> Prestige.execute(user: @module_user)
    |> Prestige.prefetch()

    Brook.Event.send(dataset_update(), :author, dataset)

    eventually(fn ->
      assert child_pid(DatasetSupervisor, schema) in DynamicSupervisor.which_children(Forklift.Dynamic.Supervisor)
    end)

    DatasetHandler.stop_dataset_ingest(schema)

    data = TDG.create_data(dataset_id: "ds2", payload: %{"id" => 1, "name" => "George"}) |> Jason.encode!()
    Elsa.Producer.produce(Application.get_env(:forklift, :elsa_brokers), "integration-ds2", data)

    DatasetHandler.start_dataset_ingest(schema)

    eventually(fn ->
      assert child_pid(DatasetSupervisor, schema) in DynamicSupervisor.which_children(Forklift.Dynamic.Supervisor)
    end)

    eventually(fn ->
      actual =
        "select id, name from #{schema.system_name}"
        |> Prestige.execute(user: @module_user)
        |> Prestige.prefetch()

      assert actual == [[1, "George"]]
    end)
  end

  test "queries to compact a dataset are sent and valid" do
    dataset =
      TDG.create_dataset(
        id: "ds3",
        technical: %{
          schema: [%{name: "id", type: "int"}, %{name: "name", type: "string"}]
        }
      )

    schema = DatasetSchema.from_dataset(dataset)

    "create table #{schema.system_name} (id integer, name varchar)"
    |> Prestige.execute(user: @module_user)
    |> Prestige.prefetch()

    Brook.Event.send(dataset_update(), :author, dataset)

    eventually(fn ->
      assert child_pid(DatasetSupervisor, schema) in DynamicSupervisor.which_children(Forklift.Dynamic.Supervisor)
    end)

    data = TDG.create_data(dataset_id: "ds3", payload: %{"id" => 1, "name" => "George"}) |> Jason.encode!()
    Elsa.Producer.produce(Application.get_env(:forklift, :elsa_brokers), "integration-ds3", data)

    eventually(fn ->
      actual =
        "select id, name from #{schema.system_name}"
        |> Prestige.execute(user: @module_user)
        |> Prestige.prefetch()

      assert actual == [[1, "George"]]
    end)

    assert {:ok, _} = DatasetCompactor.compact_dataset(schema)

    tables =
      "show tables"
      |> Prestige.execute(user: @module_user)
      |> Prestige.prefetch()
      |> List.flatten()

    system_name = String.downcase(schema.system_name)
    assert "#{system_name}" in tables
    refute "#{system_name}_compact" in tables
  end

  test "compaction of all tables does not throw an error" do
    dataset =
      TDG.create_dataset(
        id: "ds4",
        technical: %{
          schema: [%{name: "id", type: "int"}, %{name: "name", type: "string"}]
        }
      )

    schema = DatasetSchema.from_dataset(dataset)

    "create table #{schema.system_name} (id integer, name varchar)"
    |> Prestige.execute(user: @module_user)
    |> Prestige.prefetch()

    Brook.Event.send(dataset_update(), :author, dataset)

    eventually(fn ->
      assert child_pid(DatasetSupervisor, schema) in DynamicSupervisor.which_children(Forklift.Dynamic.Supervisor)
    end)

    data = TDG.create_data(dataset_id: "ds3", payload: %{"id" => 1, "name" => "George"}) |> Jason.encode!()
    Elsa.Producer.produce(Application.get_env(:forklift, :elsa_brokers), "integration-ds4", data)

    eventually(fn ->
      actual =
        "select id, name from #{schema.system_name}"
        |> Prestige.execute(user: @module_user)
        |> Prestige.prefetch()

      assert actual == [[1, "George"]]
    end)

    assert :ok = DatasetCompactor.compact_datasets()
  end

  test "non-existing table is handled" do
    dataset =
      TDG.create_dataset(
        id: "ds3",
        technical: %{
          schema: [%{name: "id", type: "int"}, %{name: "name", type: "string"}]
        }
      )

    schema = DatasetSchema.from_dataset(dataset)

    Brook.Event.send(dataset_update(), :author, dataset)

    eventually(fn ->
      assert child_pid(DatasetSupervisor, schema) in DynamicSupervisor.which_children(Forklift.Dynamic.Supervisor)
    end)

    assert DatasetCompactor.compact_dataset(schema) == :error,
           "Compaction failed to produce an error even when no table was present (due to no data being loaded into the pipeline for the dataset)"
  end

  defp child_pid(module, schema) do
    dataset_supervisor_name = Forklift.Datasets.DatasetSupervisor.name(schema)
    pid = Process.whereis(dataset_supervisor_name)
    {:undefined, pid, :supervisor, [module]}
  end

  defp eventually(block) do
    SmartCity.TestHelper.eventually(block, 1000, 60)
  end
end
