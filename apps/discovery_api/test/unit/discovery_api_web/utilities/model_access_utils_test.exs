defmodule DiscoveryApiWeb.Utilities.ModelAccessUtilsTest do
  use ExUnit.Case
  import Mox

  alias DiscoveryApiWeb.Utilities.ModelAccessUtils
  alias DiscoveryApi.Test.Helper

  setup :verify_on_exit!
  setup :set_mox_from_context

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

      # Mock RaptorService to return false (user not authorized)
      expect(RaptorServiceMock, :is_authorized_by_user_id, fn _url, "bob", _system_name -> false end)

      assert ModelAccessUtils.has_access?(model, user) == false
    end

    test "returns true for private dataset when user is associated with organization" do
      model = Helper.sample_model(%{private: true})
      user = %{subject_id: "bob", organizations: [%{id: model.organizationDetails.id}]}
      
      # Mock RaptorService to return true (user is authorized)
      expect(RaptorServiceMock, :is_authorized_by_user_id, fn _url, "bob", _system_name -> true end)
      
      assert ModelAccessUtils.has_access?(model, user) == true
    end

    test "returns false for private dataset with no user" do
      model = Helper.sample_model(%{private: true})

      assert ModelAccessUtils.has_access?(model, nil) == false
    end
  end
end
