defmodule AndiWeb.EditControllerTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  alias Andi.Schemas.AuditEvents
  alias SmartCity.TestDataGenerator, as: TDG

  @url_path "/api/v1/audit"

  describe "Audit Log controller" do
    setup do
      AuditEvents.log_audit_event(:api, :event_type, %{data: "data"})
    end

    test "Returns 200 when for users with curator role", %{curator_conn: curator_conn, andi_dataset: andi_dataset} do
      conn = get(curator_conn, "#{@url_path}/")

      assert response(conn, 200)
      assert redirected_to(conn) =~ "data"
    end

    test "displays error for users without a curator role", %{public_conn: public_conn, andi_dataset: andi_dataset} do
      conn = get(public_conn, "#{@url_path}/")
      assert response(conn, 403)
    end
  end
end
