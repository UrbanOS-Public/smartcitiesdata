defmodule DiscoveryApiWeb.Utilities.AuthUtilsTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApiWeb.Utilities.AuthUtils
  alias DiscoveryApi.Services.{PrestoService, PaddleService}
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper

  describe "has_access?/2" do
    test "should not make ldap call when no logged in user" do
      allow PaddleWrapper.authenticate(any(), any()), return: :doesnt_matter
      model = Helper.sample_model(%{private: true})

      result = AuthUtils.has_access?(model, nil)

      assert false == result
      refute_called PaddleWrapper.authenticate(any(), any())
    end
  end

  describe "can_query/2" do
    test "should allow queries to public tables" do
      allow PrestoService.get_affected_tables(any()), return: {:ok, ["public_table"]}
      allow PrestoService.is_select_statement?(any()), return: true
      allow PaddleWrapper.authenticate(any(), any()), return: :doesnt_matter

      model = Helper.sample_model(%{private: false, systemName: "public_table"})
      allow Model.get_all(), return: [model]

      assert AuthUtils.authorized_to_query?("select * from public_table", "any_user")
    end

    test "should allow queries to private tables if they have authorization" do
      allow PrestoService.get_affected_tables(any()), return: {:ok, ["private_table"]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: "private_table", organizationDetails: %{dn: "some_dn"}})
      allow Model.get_all(), return: [model]

      allow PaddleService.get_members(any()), return: ["some_user"]

      assert AuthUtils.authorized_to_query?("select * from private_table", "some_user")
    end

    test "should not allow queries to private tables if user doesn't have authorization" do
      allow PrestoService.get_affected_tables(any()), return: {:ok, ["private_table"]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: "private_table", organizationDetails: %{dn: "some_dn"}})
      allow Model.get_all(), return: [model]

      allow PaddleService.get_members(any()), return: ["mama"]

      refute AuthUtils.authorized_to_query?("select * from private_table", "not_the_mama")
    end

    test "should not allow queries that include private tables if user doesn't have authorization" do
      allow PrestoService.get_affected_tables(any()), return: {:ok, ["private_table", "public_table"]}
      allow PrestoService.is_select_statement?(any()), return: true

      private_model = Helper.sample_model(%{private: true, systemName: "private_table", organizationDetails: %{dn: "some_dn"}})
      public_model = Helper.sample_model(%{private: true, systemName: "public_table", organizationDetails: %{dn: "some_dn"}})

      allow Model.get_all(), return: [private_model, public_model]

      allow PaddleService.get_members(any()), return: ["mama"]

      refute AuthUtils.authorized_to_query?("select * from public_table join private_table", "not_the_mama")
    end

    test "should not allow queries that are not select queries" do
      allow PrestoService.get_affected_tables(any()), return: {:ok, ["public_table"]}
      allow PrestoService.is_select_statement?(any()), return: false

      model = Helper.sample_model(%{private: true, systemName: "public_table", organizationDetails: %{dn: "some_dn"}})
      allow Model.get_all(), return: [model]

      allow PaddleService.get_members(any()), return: ["some_user"]

      refute AuthUtils.authorized_to_query?("select * from public_table", "some_user")
    end

    test "should not allow queries if the model is missing" do
      allow PrestoService.get_affected_tables(any()), return: {:ok, ["public_table"]}
      allow PrestoService.is_select_statement?(any()), return: true

      allow Model.get_all(), return: []

      allow PaddleService.get_members(any()), return: ["some_user"]

      refute AuthUtils.authorized_to_query?("select * from public_table", "some_user")
    end

    test "matches tables to models without case sensitivity" do
      allow PrestoService.get_affected_tables(any()), return: {:ok, ["public_table"]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: "PuBliC_TaBlE", organizationDetails: %{dn: "some_dn"}})
      allow Model.get_all(), return: [model]

      allow PaddleService.get_members(any()), return: ["some_user"]

      assert AuthUtils.authorized_to_query?("select * from public_table", "some_user")
    end
  end
end
