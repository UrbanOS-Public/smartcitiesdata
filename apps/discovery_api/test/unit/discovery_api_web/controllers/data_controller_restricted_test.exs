defmodule DiscoveryApiWeb.DataController.RestrictedTest do
  use DiscoveryApiWeb.ConnCase
  import Mox
  import Checkov
  alias DiscoveryApi.Data.SystemNameCache
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Test.Helper
  alias Auth.TestHelper

  # Increase timeout for tests that use Helper.sample_model and complex data operations
  @moduletag timeout: 5000

  setup :verify_on_exit!
  setup :set_mox_from_context

  @dataset_id "1234-4567-89101"
  @system_name "foobar__company_data"
  @org_id "org1_id"
  @org_name "org1"
  @data_name "data1"

  setup do
    # Set up mocks using :meck for modules without dependency injection
    modules_to_mock = [
      SystemNameCache, Users
    ]
    
    Enum.each(modules_to_mock, fn module ->
      try do
        :meck.new(module, [:passthrough])
      catch
        :error, {:already_started, _} -> :ok
      end
    end)

    model =
      Helper.sample_model(%{
        id: @dataset_id,
        systemName: @system_name,
        name: @data_name,
        private: true,
        lastUpdatedDate: nil,
        queries: 7,
        downloads: 9,
        organizationDetails: %{
          id: @org_id,
          orgName: @org_name
        },
        schema: [
          %{name: "id", type: "integer"},
          %{name: "name", type: "string"}
        ]
      })

    # Use Mox for services with dependency injection (from config/test.exs)
    stub(ModelMock, :get, fn _dataset_id -> model end)
    stub(ModelMock, :get_all, fn -> [model] end)
    stub(PrestoServiceMock, :get_column_names, fn _a, _b, _c -> {:ok, ["id", "name"]} end)
    stub(PrestoServiceMock, :preview_columns, fn _schema -> ["id", "name"] end)
    stub(PrestoServiceMock, :preview, fn _session, @system_name, _schema -> [[1, "Joe"], [2, "Robby"]] end)
    stub(PrestoServiceMock, :build_query, fn _a, _b, _c, _d -> {:ok, "select * from #{@system_name}"} end)
    stub(PrestoServiceMock, :is_select_statement?, fn "select * from #{@system_name}" -> true end)
    stub(PrestoServiceMock, :get_affected_tables, fn _a, "select * from #{@system_name}" -> {:ok, [@system_name]} end)
    stub(PrestigeMock, :new_session, fn _opts -> :connection end)
    stub(PrestigeMock, :query!, fn _conn, "select * from #{@system_name}" -> :result end)
    stub(PrestigeMock, :stream!, fn _conn, _query -> [:result] end)
    stub(PrestigeResultMock, :as_maps, fn :result -> 
      [%{"id" => 1, "name" => "Joe"}, %{"id" => 2, "name" => "Robby"}]
    end)
    stub(RaptorServiceMock, :is_authorized_by_user_id, fn _a, _b, _c -> true end)
    
    # Set up other mocks using :meck for modules without DI
    :meck.expect(SystemNameCache, :get, fn @org_name, @data_name -> @dataset_id end)
    
    # Use Mox for services with dependency injection (from config/test.exs)
    stub(ModelAccessUtilsMock, :has_access?, fn _model, _user -> true end)
    stub(MetricsServiceMock, :record_api_hit, fn _type, _dataset_id -> :ok end)

    on_exit(fn ->
      Enum.each(modules_to_mock, fn module ->
        try do
          :meck.unload(module)
        catch
          :error, _ -> :ok
        end
      end)
    end)

    # Create mock connections without complex AuthConnCase setup
    conn = build_conn()
    
    # Create user data for current_user assignment
    user_data = %{
      id: "test_user_id",
      subject_id: TestHelper.valid_jwt_sub(),
      organizations: [%{id: @org_id}]
    }
    
    authorized_conn = build_conn()
      |> put_req_header("authorization", "Bearer #{TestHelper.valid_jwt()}")
      |> put_req_header("content-type", "application/json")
      |> Plug.Conn.assign(:current_user, user_data)
    
    %{
      conn: conn,
      authorized_conn: authorized_conn,
      authorized_subject: TestHelper.valid_jwt_sub(),
      model: model
    }
  end

  describe "accessing restricted datasets" do
    data_test "downloads a restricted dataset if the given user has access to it, via token", %{
      authorized_conn: conn,
      authorized_subject: subject
    } do
      # Set up specific mocks for this test using :meck
      :meck.expect(Users, :get_user_with_organizations, fn ^subject, :subject_id -> 
        {:ok, %User{organizations: [%{id: @org_id}]}} 
      end)

      conn
      |> put_req_header("accept", accepts)
      |> get(url)
      |> json_response(response_code)

      where([
        [:url, :accepts, :response_code],
        # hmac token is datasetid/timestamp encrypted with a key
        # :crypto.hmac(:sha256, "test_presign_key", "1234-4567-89101/2556118800") |> Base.encode16()
        [
          "/api/v1/dataset/1234-4567-89101/download?key=A2C4E59FA2FEDAAA3AB3059DB07C78CDFE61AA5088CE0F07DC4E326D865E593D&expires=2556118800",
          "application/json",
          200
        ],
        ["/api/v1/dataset/1234-4567-89101/query", "application/json", 200],
        ["/api/v1/dataset/1234-4567-89101/preview", "application/json", 200]
      ])
    end
  end
end
