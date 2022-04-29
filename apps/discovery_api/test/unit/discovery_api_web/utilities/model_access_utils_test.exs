defmodule DiscoveryApiWeb.Utilities.ModelAccessUtilsTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApiWeb.Utilities.ModelAccessUtils
  alias DiscoveryApi.Test.Helper

  describe "has_access?/2" do
    test "returns true for public dataset with no user" do
      model = Helper.sample_model(%{private: false})

      assert ModelAccessUtils.has_access?(model, nil) == true
    end

    test "returns true for public dataset with any user" do
      model = Helper.sample_model(%{private: false})
      user = %{subject_id: "bob", organizations: []}

      assert ModelAccessUtils.has_access?(model, user) == true
    end

    test "returns false for private dataset when user is not associated with organization" do
      model = Helper.sample_model(%{private: true})
      user = %{subject_id: "bob", organizations: []}

      assert ModelAccessUtils.has_access?(model, user) == false
    end

    test "returns true for private dataset when user is associated with organization" do
      model = Helper.sample_model(%{private: true})
      user = %{subject_id: "bob", organizations: [%{id: model.organizationDetails.id}]}
      allow(RaptorService.is_authorized_by_user_id(any(), any(), any()), return: true)
      assert ModelAccessUtils.has_access?(model, user) == true
    end

    test "returns false for private dataset with no user" do
      model = Helper.sample_model(%{private: true})

      assert ModelAccessUtils.has_access?(model, nil) == false
    end
  end
end
