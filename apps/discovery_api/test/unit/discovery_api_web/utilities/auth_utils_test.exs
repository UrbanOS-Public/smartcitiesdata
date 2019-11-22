defmodule DiscoveryApiWeb.Utilities.AuthUtilsTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApiWeb.Utilities.{AuthUtils, LdapAccessUtils, EctoAccessUtils}
  alias DiscoveryApi.Services.{PrestoService, PaddleService}
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Schemas.Users

  @table "the__table"

  describe "authorized_to_query?/2 with LDAP" do
    test "should not make ldap call when no logged in user" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true
      allow PaddleWrapper.authenticate(any(), any()), return: :doesnt_matter

      model = Helper.sample_model(%{private: true})
      allow Model.get_all(), return: [model]

      refute AuthUtils.authorized_to_query?("select * from #{@table}", nil, LdapAccessUtils)

      refute_called PaddleWrapper.authenticate(any(), any())
    end

    test "should allow queries to public tables" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true
      allow PaddleWrapper.authenticate(any(), any()), return: :doesnt_matter

      model = Helper.sample_model(%{private: false, systemName: @table})
      allow Model.get_all(), return: [model]

      assert AuthUtils.authorized_to_query?("select * from #{@table}", "any_user", LdapAccessUtils)
    end

    test "should allow queries to private tables if they have authorization" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{dn: "some_dn"}})
      allow Model.get_all(), return: [model]

      allow PaddleService.get_members(any()), return: ["some_user"]

      assert AuthUtils.authorized_to_query?("select * from #{@table}", "some_user", LdapAccessUtils)
    end

    test "should not allow queries to private tables if user doesn't have authorization" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{dn: "some_dn"}})
      allow Model.get_all(), return: [model]

      allow PaddleService.get_members(any()), return: ["mama"]

      refute AuthUtils.authorized_to_query?("select * from #{@table}", "not_the_mama", LdapAccessUtils)
    end

    test "should not allow queries that include private tables if user doesn't have authorization" do
      other_table = "other_table"
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table, other_table]}
      allow PrestoService.is_select_statement?(any()), return: true

      private_model = Helper.sample_model(%{private: true, systemName: other_table, organizationDetails: %{dn: "some_dn"}})
      public_model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{dn: "some_dn"}})

      allow Model.get_all(), return: [private_model, public_model]

      allow PaddleService.get_members(any()), return: ["mama"]

      refute AuthUtils.authorized_to_query?("select * from #{@table} join #{other_table}", "not_the_mama", LdapAccessUtils)
    end

    test "should not allow queries that are not select queries" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: false

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{dn: "some_dn"}})
      allow Model.get_all(), return: [model]

      allow PaddleService.get_members(any()), return: ["some_user"]

      refute AuthUtils.authorized_to_query?("select * from #{@table}", "some_user", LdapAccessUtils)
    end

    test "should not allow queries if the model is missing" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      allow Model.get_all(), return: []

      allow PaddleService.get_members(any()), return: ["some_user"]

      refute AuthUtils.authorized_to_query?("select * from #{@table}", "some_user", LdapAccessUtils)
    end

    test "matches tables to models without case sensitivity" do
      allow PrestoService.get_affected_tables(any(), any()), return: {:ok, [@table]}
      allow PrestoService.is_select_statement?(any()), return: true

      model = Helper.sample_model(%{private: true, systemName: "tHe__TaBlE", organizationDetails: %{dn: "some_dn"}})
      allow Model.get_all(), return: [model]

      allow PaddleService.get_members(any()), return: ["some_user"]

      assert AuthUtils.authorized_to_query?("select * from #{@table}", "some_user", LdapAccessUtils)
    end
  end

  describe "authorized_to_query?/2 with Ecto" do
    test "should not allow queries when user is not associated with organization" do
      query = "select * from #{@table}"
      allow(PrestoService.is_select_statement?(query), return: true)
      allow(PrestoService.get_affected_tables(any(), query), return: {:ok, [@table]})

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: "o2yu3akg4whjerzdofyiuz"}})
      allow Model.get_all(), return: [model]

      allow(Users.get_user_with_organizations("subject_id", :subject_id),
        return: {:ok, %{organizations: [%{id: "different_id"}]}}
      )

      refute AuthUtils.authorized_to_query?(query, "subject_id", EctoAccessUtils)
    end

    test "should allow queries when user is associated with organization" do
      query = "select * from #{@table}"
      org_id = "o2yu3akg4whjerzdofyiuz"
      allow(PrestoService.is_select_statement?(query), return: true)
      allow(PrestoService.get_affected_tables(any(), query), return: {:ok, [@table]})

      model = Helper.sample_model(%{private: true, systemName: @table, organizationDetails: %{id: org_id}})
      allow Model.get_all(), return: [model]

      allow(Users.get_user_with_organizations("subject_id", :subject_id),
        return: {:ok, %{organizations: [%{id: org_id}]}}
      )

      assert AuthUtils.authorized_to_query?(query, "subject_id", EctoAccessUtils)
    end
  end
end
