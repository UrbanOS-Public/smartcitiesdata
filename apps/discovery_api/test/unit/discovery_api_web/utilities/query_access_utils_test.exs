defmodule DiscoveryApiWeb.Utilities.QueryAccessUtilsTest do
  use DiscoveryApiWeb.ConnCase
  import Mox

  alias DiscoveryApiWeb.Utilities.QueryAccessUtils

  # Increase timeout for tests that use Helper.sample_model which can be slow due to Faker/TDG data generation
  @moduletag timeout: 5000

  setup :verify_on_exit!
  setup :set_mox_from_context

  @table "the__table"
  @org_id "the_org"

  describe "get_affected_models/1" do
    test "should allow queries to public tables" do
      stub(PrestoServiceMock, :get_affected_tables, fn _a, _b -> {:ok, [@table]} end)
      stub(PrestoServiceMock, :is_select_statement?, fn _query -> true end)

      model = Helper.sample_model(%{private: false, systemName: @table, organizationDetails: %{id: @org_id}})
      stub(ModelMock, :get_all, fn -> [model] end)

      assert {:ok, _affected_models} = QueryAccessUtils.get_affected_models("select * from #{@table}")
    end

    test "should allow queries to private tables if they are associated with the organization" do
      stub(PrestoServiceMock, :get_affected_tables, fn _a, _b -> {:ok, [@table]} end)
      stub(PrestoServiceMock, :is_select_statement?, fn _query -> true end)

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})
      stub(ModelMock, :get_all, fn -> [model] end)

      assert {:ok, _affected_models} = QueryAccessUtils.get_affected_models("select * from #{@table}")
    end

    test "should not allow queries if the model is missing" do
      stub(PrestoServiceMock, :get_affected_tables, fn _a, _b -> {:ok, [@table]} end)
      stub(PrestoServiceMock, :is_select_statement?, fn _query -> true end)

      stub(ModelMock, :get_all, fn -> [] end)

      {:error, "Query statement is invalid"} = QueryAccessUtils.get_affected_models("select * from #{@table}")
    end

    test "matches tables to models without case sensitivity" do
      stub(PrestoServiceMock, :get_affected_tables, fn _a, _b -> {:ok, [@table]} end)
      stub(PrestoServiceMock, :is_select_statement?, fn _query -> true end)

      model = Helper.sample_model(%{private: true, systemName: "tHe__TaBlE", organizationDetails: %{id: @org_id}})
      stub(ModelMock, :get_all, fn -> [model] end)

      assert {:ok, _affected_models} = QueryAccessUtils.get_affected_models("select * from #{@table}")
    end

    test "should not allow queries when the statement isn't a select statement" do
      stub(PrestoServiceMock, :get_affected_tables, fn _a, _b -> {:ok, [@table]} end)
      stub(PrestoServiceMock, :is_select_statement?, fn _query -> false end)

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})

      stub(ModelMock, :get_all, fn -> [model] end)

      assert {:error, "Query statement is invalid"} = QueryAccessUtils.get_affected_models("describe table blah;")
    end

    test "should not allow queries when get affected tables fails" do
      statement = "INSERT INTO public__one SELECT * FROM public__two"

      stub(PrestoServiceMock, :is_select_statement?, fn ^statement -> true end)
      stub(PrestoServiceMock, :get_affected_tables, fn _a, ^statement -> {:error, :does_not_matter} end)

      assert {:error, "Query statement is invalid"} = QueryAccessUtils.get_affected_models(statement)
    end
  end

  describe "authorized_session/2" do
    test "should not allow queries to private tables if user doesn't have JWT or API_KEY authorization" do
      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})

      conn =
        build_conn()
        |> Map.put(:assigns, %{current_user: "jim bob"})
        |> Map.put(:req_headers, [{"api_key", "sample_api_key"}])

      [expected_api_key] = Plug.Conn.get_req_header(conn, "api_key")

      stub(ModelAccessUtilsMock, :has_access?, fn ^model, _user -> false end)
      stub(RaptorServiceMock, :is_authorized, fn "raptor.url", ^expected_api_key, _system_name -> false end)

      assert {:error, "Session not authorized"} = QueryAccessUtils.authorized_session(conn, [model])
    end

    test "should not allow queries to private tables if user doesn't have a vaild JWT and no api_key is provided" do
      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})

      conn =
        build_conn()
        |> Map.put(:assigns, %{current_user: "jim bob"})

      stub(ModelAccessUtilsMock, :has_access?, fn ^model, _user -> false end)

      assert {:error, "Session not authorized"} = QueryAccessUtils.authorized_session(conn, [model])
    end

    test "should allow queries that include private tables if authorized api_key is provided and a JWT is not" do
      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})

      conn =
        build_conn()
        |> Map.put(:assigns, %{current_user: "jim bob"})
        |> Map.put(:req_headers, [{"api_key", "sample_api_key"}])

      [expected_api_key] = Plug.Conn.get_req_header(conn, "api_key")

      stub(ModelAccessUtilsMock, :has_access?, fn ^model, _user -> false end)
      stub(RaptorServiceMock, :is_authorized, fn "raptor.url", ^expected_api_key, _system_name -> true end)

      assert {:ok, _authorized_session} = QueryAccessUtils.authorized_session(conn, [model])
    end

    test "should allow queries that include private tables if provided JWT has access" do
      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})

      conn =
        build_conn()
        |> Map.put(:assigns, %{current_user: "jim bob"})

      stub(ModelAccessUtilsMock, :has_access?, fn ^model, _user -> true end)

      assert {:ok, _authorized_session} = QueryAccessUtils.authorized_session(conn, [model])
    end

    test "should not allow queries that include private tables if user doesn't have JWT authorization" do
      other_table = "other_table"
      private_model = Helper.sample_model(%{private: true, systemName: other_table, organizationDetails: %{id: @org_id}})
      public_model = Helper.sample_model(%{private: false, systemName: @table, organizationDetails: %{id: @org_id}})

      conn =
        build_conn()
        |> Map.put(:assigns, %{current_user: "jim bob"})

      stub(ModelAccessUtilsMock, :has_access?, fn 
        ^private_model, _user -> false
        ^public_model, _user -> true
      end)

      assert {:error, "Session not authorized"} = QueryAccessUtils.authorized_session(conn, [private_model, public_model])
    end

    test "should not try to query private table with no logged in user" do
      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})

      conn =
        build_conn()
        |> Map.put(:assigns, %{current_user: nil})

      stub(ModelAccessUtilsMock, :has_access?, fn ^model, nil -> false end)

      assert {:error, "Session not authorized"} = QueryAccessUtils.authorized_session(conn, [model])
    end
  end
end
