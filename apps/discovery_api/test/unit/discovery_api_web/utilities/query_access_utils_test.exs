defmodule DiscoveryApiWeb.Utilities.QueryAccessUtilsTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper

  @table "the__table"
  @org_id "good_org_id"
  @user_without_org %{
    user_id: "bob",
    organizations: []
  }
  @user_with_org %{
    user_id: "steve",
    organizations: [%{id: @org_id}]
  }

  describe "authorized_to_query?/2" do
    test "should not try to query private table with no logged in user" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})
      allow Model.get_all(), return: [model]

      {:ok, affected_tables, affected_models} = QueryAccessUtils.authorized_statement_models("select * from #{@table}")

      refute QueryAccessUtils.authorized_to_query?(affected_tables, affected_models, nil)
    end

    test "should allow queries to public tables" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: false, systemName: @table, organizationDetails: %{id: @org_id}})
      allow Model.get_all(), return: [model]

      {:ok, affected_tables, affected_models} = QueryAccessUtils.authorized_statement_models("select * from #{@table}")

      assert QueryAccessUtils.authorized_to_query?(affected_tables, affected_models, @user_without_org)
    end

    test "should allow queries to private tables if they are associated with the organization" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})
      allow Model.get_all(), return: [model]

      {:ok, affected_tables, affected_models} = QueryAccessUtils.authorized_statement_models("select * from #{@table}")

      assert QueryAccessUtils.authorized_to_query?(affected_tables, affected_models, @user_with_org)
    end

    test "should not allow queries to private tables if user doesn't have authorization" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})
      allow Model.get_all(), return: [model]

      {:ok, affected_tables, affected_models} = QueryAccessUtils.authorized_statement_models("select * from #{@table}")

      refute QueryAccessUtils.authorized_to_query?(affected_tables, affected_models, @user_without_org)
    end

    test "should not allow queries that include private tables if user doesn't have authorization" do
      other_table = "other_table"
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table, other_table]}
      allow PrestoService.is_select_statement?(any()), return: true

      private_model = Helper.sample_model(%{private: true, systemName: other_table, organizationDetails: %{id: @org_id}})
      public_model = Helper.sample_model(%{private: false, systemName: @table, organizationDetails: %{id: @org_id}})

      allow Model.get_all(), return: [private_model, public_model]

      {:ok, affected_tables, affected_models} = QueryAccessUtils.authorized_statement_models("select * from #{@table} join #{other_table}")

      refute QueryAccessUtils.authorized_to_query?(affected_tables, affected_models, @user_without_org)
    end

    test "should not allow queries if the model is missing" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      allow Model.get_all(), return: []

      {:ok, affected_tables, affected_models} = QueryAccessUtils.authorized_statement_models("select * from #{@table}")

      refute QueryAccessUtils.authorized_to_query?(affected_tables, affected_models, @user_with_org)
    end

    test "matches tables to models without case sensitivity" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: "tHe__TaBlE", organizationDetails: %{id: @org_id}})
      allow Model.get_all(), return: [model]

      {:ok, affected_tables, affected_models} = QueryAccessUtils.authorized_statement_models("select * from #{@table}")

      assert QueryAccessUtils.authorized_to_query?(affected_tables, affected_models, @user_with_org)
    end
  end

  describe "authorized_statement_models/1" do
    test "only returns models for select statements" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: false

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: @org_id}})

      allow Model.get_all(), return: [model]

      assert {:error, _} = QueryAccessUtils.authorized_statement_models("describe table blah;")
    end
  end
end
