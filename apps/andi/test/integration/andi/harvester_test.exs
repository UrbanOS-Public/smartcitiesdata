defmodule Andi.Harvest.HarvesterTest do
  use ExUnit.Case
  use Andi.DataCase
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations

  import SmartCity.Event, only: [dataset_harvest_start: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  @scos_data_json_uuid "1719bf64-38f5-40bf-9737-45e84f5c8419"
  @dataset_id_1 UUID.uuid5(@scos_data_json_uuid, "http://opendata.columbus.gov/datasets/88d9dd727f3c453793a8871000593bec_30")
  @dataset_id_2 UUID.uuid5(@scos_data_json_uuid, "http://opendata.columbus.gov/datasets/caa012bef21a49c3b3ecea09dca9f96d_2")

  describe "data json harvesting" do
    setup do
      Ecto.Adapters.SQL.Sandbox.checkout(Andi.Repo)
      Ecto.Adapters.SQL.Sandbox.mode(Andi.Repo, {:shared, self()})

      bypass = Bypass.open()
      data_json = get_schema_from_path("./test/integration/schemas/data_json.json")

      org =
        TDG.create_organization(%{
          orgTitle: "Awesome Title",
          orgName: "awesome_title",
          id: "95254592-d611-4bcb-9478-7fa248f4118d",
          dataJsonUrl: "http://localhost:#{bypass.port()}/data.json"
        })

      %{data_json: data_json, org: org, bypass: bypass}
    end

    test "datasets from data_json are added to view state", %{data_json: data_json, org: org, bypass: bypass} do
      Ecto.Adapters.SQL.Sandbox.allow(Andi.Repo, self(), Andi.Harvest.Harvester)

      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      Brook.Event.send(:andi, dataset_harvest_start(), :andi, org)

      eventually(fn ->
        dataset_ids = DatasetStore.get_all() |> elem(1) |> Enum.map(fn dataset -> dataset.id end)
        assert @dataset_id_1 in dataset_ids
        assert @dataset_id_2 in dataset_ids
      end)
    end

    test "datasets from data_json are added to ecto", %{data_json: data_json, org: org, bypass: bypass} do
      Ecto.Adapters.SQL.Sandbox.allow(Andi.Repo, self(), Andi.Harvest.Harvester)

      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      Brook.Event.send(:andi, dataset_harvest_start(), :andi, org)

      eventually(fn ->
        dataset_ids = Datasets.get_all() |> Enum.map(fn dataset -> dataset.id end)
        assert @dataset_id_1 in dataset_ids
        assert @dataset_id_2 in dataset_ids
      end)
    end

    test "harvested datasets from data_json are added to ecto", %{data_json: data_json, org: org, bypass: bypass} do
      Ecto.Adapters.SQL.Sandbox.allow(Andi.Repo, self(), Andi.Harvest.Harvester)

      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      Brook.Event.send(:andi, dataset_harvest_start(), :andi, org)

      eventually(fn ->
        harvested_datasets = Organizations.get_all()
        assert length(harvested_datasets) == 2
      end)
    end

    test "only consume harvested datasets whose include value is true", %{data_json: data_json, org: org, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      Brook.Event.send(:andi, dataset_harvest_start(), :andi, org)
    end
  end

  defp get_schema_from_path(path) do
    path
    |> File.read!()
  end
end
