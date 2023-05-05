defmodule AndiWeb.AuditLogControllerTest do
  use ExUnit.Case
  use Andi.DataCase

  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  alias Andi.Schemas.AuditEvents
  alias SmartCity.TestDataGenerator, as: TDG

  @url_path "/api/v1/audit"

  describe "Audit Log controller" do
    setup do
      on_exit(fn -> System.put_env("REQUIRE_ADMIN_API_KEY", "false") end)
      AuditEvents.log_audit_event(:api, "some:event:type", %{data: "data"})

      :ok
    end

    test "Returns 200 for all users when no Api Key required", %{public_conn: public_conn} do
      conn = get(public_conn, "#{@url_path}/")

      assert response(conn, 200)
    end

    test "displays error for users without an api key", %{public_conn: public_conn} do
      System.put_env("REQUIRE_ADMIN_API_KEY", "true")
      conn = get(public_conn, "#{@url_path}/")
      assert response(conn, 401)
    end
  end
end
