defmodule DiscoveryApiWeb.Utilities.QueryAccessUtilsTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils

  @table "the__table"
  @org_id "the_org"

  describe "get_affected_models/1" do
    test "should allow queries to public tables" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: false, systemName: @table, organizationDetails: %{id: @org_id}})
      allow Model.get_all(), return: [model]

      assert {:ok, affected_models} = QueryAccessUtils.get_affected_models("select * from #{@table}")
    end

    test "should allow queries to private tables if they are associated with the organization" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})
      allow Model.get_all(), return: [model]

      assert {:ok, affected_models} = QueryAccessUtils.get_affected_models("select * from #{@table}")
    end

    test "should not allow queries if the model is missing" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      allow Model.get_all(), return: []

      {:error, "Query statement is invalid"} = QueryAccessUtils.get_affected_models("select * from #{@table}")
    end

    test "matches tables to models without case sensitivity" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: "tHe__TaBlE", organizationDetails: %{id: @org_id}})
      allow Model.get_all(), return: [model]

      assert {:ok, affected_models} = QueryAccessUtils.get_affected_models("select * from #{@table}")
    end

    test "should not allow queries when the statement isn't a select statement" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: false

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})

      allow Model.get_all(), return: [model]

      assert {:error, "Query statement is invalid"} = QueryAccessUtils.get_affected_models("describe table blah;")
    end

    test "should not allow queries when get affected tables fails" do
      statement = "INSERT INTO public__one SELECT * FROM public__two"

      allow PrestoService.get_affected_tables(any(), statement), return: {:error, :does_not_matter}

      assert {:error, "Query statement is invalid"} = QueryAccessUtils.get_affected_models(statement)
    end
  end

  describe "authorized_session/2" do
    test "should not allow queries to private tables if user doesn't have authorization" do
      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})
      conn = Phoenix.ConnTest.build_conn()
        |> Map.put(:assigns, %{current_user: "jim bob"})

      allow ModelAccessUtils.has_access?(model, conn.assigns.current_user), return: false

      assert {:error, "Session not authorized"} = QueryAccessUtils.authorized_session(conn, [model])
    end

    test "should not allow queries that include private tables if user doesn't have authorization" do
      other_table = "other_table"
      private_model = Helper.sample_model(%{private: true, systemName: other_table, organizationDetails: %{id: @org_id}})
      public_model = Helper.sample_model(%{private: false, systemName: @table, organizationDetails: %{id: @org_id}})
      conn = Phoenix.ConnTest.build_conn()
        |> Map.put(:assigns, %{current_user: "jim bob"})

      allow ModelAccessUtils.has_access?(private_model, conn.assigns.current_user), return: false
      allow ModelAccessUtils.has_access?(public_model, conn.assigns.current_user), return: true

      assert {:error, "Session not authorized"} = QueryAccessUtils.authorized_session(conn, [private_model, public_model])
    end

    test "should not try to query private table with no logged in user" do
      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})
      conn = Phoenix.ConnTest.build_conn()
        |> Map.put(:assigns, %{current_user: nil})

      allow ModelAccessUtils.has_access?(model, nil), return: false

      assert {:error, "Session not authorized"} = QueryAccessUtils.authorized_session(conn, [model])
    end
  end
end
