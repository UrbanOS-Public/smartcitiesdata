defmodule Andi.Harvest.HarvesterTest do
  use ExUnit.Case
  use Placebo
  alias Andi.Harvest.Harvester

  describe "data json harvester" do
    setup do
      data_json = get_schema_from_path("./test/integration/schemas/data_json.json")
      %{data_json: data_json}
    end

    test "get_data_json/1", %{data_json: data_json} do
      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      resp = Harvester.get_data_json("http://localhost:#{bypass.port()}/data.json")
      assert %{} == resp
    end

    test "map_data_json_to_dataset/1", %{data_json: data_json} do
      {:ok, data_json} = Jason.decode(data_json)
      datasets = Harvester.map_data_json_to_dataset(data_json)
      assert datasets == %{}
    end
  end

  defp get_schema_from_path(path) do
    path
    |> File.read!()
  end
end
