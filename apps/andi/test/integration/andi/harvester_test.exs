defmodule Andi.Harvest.HarvesterTest do
  use ExUnit.Case
  use Andi.DataCase
  use Placebo

  @moduletag shared_data_connection: true

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Organizations
  alias Andi.Harvest.Harvester

  import SmartCity.Event, only: [dataset_harvest_start: 0, dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  @instance_name Andi.instance_name()

  @scos_data_json_uuid "1719bf64-38f5-40bf-9737-45e84f5c8419"
  @dataset_id_1 UUID.uuid5(@scos_data_json_uuid, "http://opendata.columbus.gov/datasets/88d9dd727f3c453793a8871000593bec_30")
  @dataset_id_2 UUID.uuid5(@scos_data_json_uuid, "http://opendata.columbus.gov/datasets/caa012bef21a49c3b3ecea09dca9f96d_2")

  describe "data json harvesting" do
    setup do
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
      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org)

      eventually(fn ->
        dataset_ids = DatasetStore.get_all() |> elem(1) |> Enum.map(fn dataset -> dataset.id end)
        assert @dataset_id_1 in dataset_ids
        assert @dataset_id_2 in dataset_ids
      end)
    end

    test "datasets from data_json are added to ecto", %{data_json: data_json, org: org, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org)

      eventually(fn ->
        dataset_ids = Datasets.get_all() |> Enum.map(fn dataset -> dataset.id end)
        assert @dataset_id_1 in dataset_ids
        assert @dataset_id_2 in dataset_ids
      end)
    end

    test "harvested datasets from data_json are added to ecto", %{data_json: data_json, org: org, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org)

      eventually(fn ->
        harvested_datasets = Organizations.get_all_harvested_datasets(org.id)
        assert length(harvested_datasets) == 3
      end)
    end

    test "only consume harvested datasets whose include value is true", %{data_json: data_json, org: org, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      {:ok, data_json} = Jason.decode(data_json)
      Harvester.map_data_json_to_dataset(data_json, org)

      Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org)

      eventually(fn ->
        Organizations.update_harvested_dataset_include(@dataset_id_1, false)
        assert %{datasetId: @dataset_id_1, include: false} = Organizations.get_harvested_dataset(@dataset_id_1)
      end)

      updated_datasets =
        data_json["dataset"]
        |> List.update_at(0, fn dataset -> Map.put(dataset, "modified", "2020-08-10T13:31:42.000Z") end)

      data_json =
        data_json
        |> Map.put("dataset", updated_datasets)
        |> Jason.encode!()

      new_bypass = Bypass.open()

      org =
        TDG.create_organization(%{
          orgTitle: "Awesome Title",
          orgName: "awesome_title",
          id: "95254592-d611-4bcb-9478-7fa248f4118d",
          dataJsonUrl: "http://localhost:#{new_bypass.port()}/data.json"
        })

      Bypass.stub(new_bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org)

      {:ok, date, _} = "2019-08-16T15:11:39.000Z" |> DateTime.from_iso8601()

      eventually(fn ->
        assert %{datasetId: @dataset_id_1, include: false, modifiedDate: date} = Organizations.get_harvested_dataset(@dataset_id_1)
        assert %{business: %{modifiedDate: date}} = Datasets.get(@dataset_id_1)
      end)
    end

    test "datasets that previously existed but no longer do are removed from the system", %{data_json: data_json, org: org, bypass: bypass} do
      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org)

      eventually(fn ->
        assert 3 == length(Organizations.get_all_harvested_datasets("95254592-d611-4bcb-9478-7fa248f4118d"))
      end)

      # create a new dataset
      harvested_dataset_one = %{
        "orgId" => "95254592-d611-4bcb-9478-7fa248f4118d",
        "sourceId" => "45678",
        "datasetId" => "3142a038-e77b-49c9-b800-bd706a7152ef"
      }

      dataset_one = TDG.create_dataset(%{id: "3142a038-e77b-49c9-b800-bd706a7152ef"})

      Organizations.update_harvested_dataset(harvested_dataset_one)

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset_one)
      Brook.Event.send(@instance_name, dataset_harvest_start(), :andi, org)

      eventually(fn ->
        assert 3 == length(Organizations.get_all_harvested_datasets("95254592-d611-4bcb-9478-7fa248f4118d"))
        assert nil == Organizations.get_harvested_dataset("95254592-d611-4bcb-9478-7fa248f4118d")
      end)
    end
  end

  defp get_schema_from_path(path) do
    path
    |> File.read!()
  end
end
