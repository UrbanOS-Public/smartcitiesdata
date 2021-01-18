defmodule DiscoveryApiWeb.MultipleDataControllerTest do
  use ExUnit.Case

  use DiscoveryApiWeb.Test.AuthConnCase.IntegrationCase
  alias DiscoveryApi.Test.Helper

  @organization_name "organization_alpha"

  setup_all do
    _ = Helper.create_persisted_organization(%{orgName: @organization_name})

    {table_name, dataset_id} = Helper.create_persisted_dataset("test_data", "test_data", @organization_name)

    %{dataset_table: table_name, dataset_id: dataset_id}
  end

  describe "POST /query" do
    test "something", %{
        authorized_conn: authorized_conn,
        authorized_subject: subject,
        dataset_table: dataset_table
      } do
      _ = Helper.create_persisted_user(subject)
      _ = authorized_conn
          |> put_req_header("content-type", "text/plain")
          |> post("/api/v1/query", "SELECT * FROM #{dataset_table}")
          |> response(200)
    end
  end
end
