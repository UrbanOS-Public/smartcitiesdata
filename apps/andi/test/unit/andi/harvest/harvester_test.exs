defmodule Andi.Harvest.HarvesterTest do
  use ExUnit.Case
  use Placebo

  @data_json_payload Jason.encode!(%{"email" => "x@y.z"})

  describe "get_data_json/1" do
    test "returns data json from requested url" do
      bypass = Bypass.open()

      Bypass.stub(bypass, "GET", "/data.json", fn conn ->
        Plug.Conn.resp(conn, 200, "yes")
      end)

      resp = Andi.Harvest.Harvester.get_data_json("http://localhost:#{bypass.port()}/data.json")

      assert "yes" == resp
    end

  end
end
