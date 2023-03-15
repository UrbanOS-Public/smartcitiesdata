defmodule Andi.ReportsControllerTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  describe "download_report" do
    test "returns csv file when called", %{curator_conn: conn} do
      result = get(conn, "/report")
      assert result.status == 200
      assert result.resp_body == "test,csv\r\n"
    end
  end
end
