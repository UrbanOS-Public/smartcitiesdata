defmodule Andi.Harvest.HarvesterTest do
  use ExUnit.Case
  use Placebo
  alias Andi.Harvest.Harvester
  alias SmartCity.TestDataGenerator, as: TDG
  import Andi
  import SmartCity.Event, only: [dataset_update: 0]

  describe "data json harvester" do
    setup do
      data_json = get_schema_from_path("./test/integration/schemas/data_json.json")
      org = TDG.create_organization(%{orgTitle: "Awesome Title", orgName: "awesome_title", id: "95254592-d611-4bcb-9478-7fa248f4118d"})
      %{data_json: data_json, org: org}
    end

    test "get_data_json/1", %{data_json: data_json} do
      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      {:ok, actual} = Jason.decode(data_json)
      {:ok, resp} = Harvester.get_data_json("http://localhost:#{bypass.port()}/data.json")

      assert resp == actual
    end

    test "map_data_json_to_dataset/1", %{data_json: data_json, org: org} do
      {:ok, data_json} = Jason.decode(data_json)
      datasets = Harvester.map_data_json_to_dataset(data_json, org)
      assert length(datasets) == 2
    end

    test "dataset_update/1", %{data_json: data_json, org: org} do
      allow(Brook.Event.send(instance_name(), dataset_update(), :andi, any()), return: :ok, meck_options: [:passthrough])

      {:ok, data_json} = Jason.decode(data_json)
      datasets = Harvester.map_data_json_to_dataset(data_json, org)

      Harvester.dataset_update(datasets)

      assert_called(Brook.Event.send(instance_name(), dataset_update(), :andi, any()), times(2))
    end
  end

  defp get_schema_from_path(path) do
    path
    |> File.read!()
  end
end
