defmodule DiscoveryApiWeb.Utilities.EctoAccessUtilsTest do
  use ExUnit.Case
  use Placebo

  import Checkov

  alias DiscoveryApiWeb.Utilities.EctoAccessUtils
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Test.Helper

  @pub_model Helper.sample_model(%{private: false})
  @priv_model Helper.sample_model(%{private: true})

  setup do
    allow(Users.get_user_with_organizations("bob", :subject_id),
      return: {:ok, %{organizations: [%{id: "notrealid"}]}}
    )

    allow(Users.get_user_with_organizations("steve", :subject_id),
      return: {:ok, %{organizations: [%{id: @priv_model.organizationDetails.id}]}}
    )

    :ok
  end

  data_test "has_access?/2 with public datasets" do
    assert EctoAccessUtils.has_access?(@pub_model, user) == expected

    where([
      [:user, :expected],
      [nil, true],
      ["bob", true]
    ])
  end

  data_test "has_access?/2 with private datasets" do
    assert EctoAccessUtils.has_access?(@priv_model, user) == expected

    where([
      [:user, :expected],
      [nil, false],
      ["bob", false],
      ["steve", true]
    ])
  end
end
