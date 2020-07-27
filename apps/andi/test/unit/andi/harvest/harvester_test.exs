defmodule Andi.Harvest.HarvesterTest do
  use ExUnit.Case
  use Placebo

  describe "get_data_json/1" do
    setup do
      data_json = get_schema_from_path("./test/integration/schemas/data_json.json") |> IO.inspect(label: "data json:")
      %{data_json: data_json}
    end

    test "returns data json from requested url", %{data_json: data_json} do
      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, data_json)
      end)

      resp = Andi.Harvest.Harvester.get_data_json("http://localhost:#{bypass.port()}/data.json")
      assert %{} == resp
    end
  end

  defp get_schema_from_path(path) do
    path
    |> File.read!()
  end
end
