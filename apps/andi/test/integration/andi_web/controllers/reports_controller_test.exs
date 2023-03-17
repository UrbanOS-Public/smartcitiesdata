defmodule Andi.ReportsControllerTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  describe "download_report" do
    test "returns csv file when called", %{curator_conn: conn} do
      result = get(conn, "/report")
      assert result.status == 200
      assert result.resp_body == "Dataset ID,Users\r\n12345,\"user1@fakemail.com, user2@fakemail.com\"\r\n"
    end
  end
end
