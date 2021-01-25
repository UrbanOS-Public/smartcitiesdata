defmodule DiscoveryApiWeb.MultipleDataControllerTest do
  use ExUnit.Case
  use DiscoveryApi.DataCase
  use DiscoveryApiWeb.Test.AuthConnCase.IntegrationCase

  import SmartCity.TestHelper, only: [eventually: 1]

  alias DiscoveryApi.Test.Helper

  @organization_name "organization_alpha"

  setup_all do
    Helper.create_persisted_organization(%{orgName: @organization_name})

    {table_name, dataset_id} = Helper.create_persisted_dataset("test_data", "test_data", @organization_name)

    %{dataset_table: table_name, dataset_id: dataset_id}
  end

  describe "POST /query" do
    test "valid query increments api record in redis", %{
      authorized_conn: authorized_conn,
      authorized_subject: subject,
      dataset_table: dataset_table,
      dataset_id: dataset_id
    } do
      Helper.create_persisted_user(subject)

      expected_api_hit_count =
        case Redix.command!(:redix, ["GET", "smart_registry:free_form_query:count:#{dataset_id}"]) do
          nil -> 1
          initial_api_hit_count -> String.to_integer(initial_api_hit_count) + 1
        end

      authorized_conn
      |> put_req_header("content-type", "text/plain")
      |> post("/api/v1/query", "SELECT * FROM #{dataset_table}")
      |> response(200)

      eventually(fn ->
        updated_api_hit_count = Redix.command!(:redix, ["GET", "smart_registry:free_form_query:count:#{dataset_id}"])

        assert updated_api_hit_count != nil
        assert String.to_integer(updated_api_hit_count) == expected_api_hit_count
      end)
    end
  end
end
