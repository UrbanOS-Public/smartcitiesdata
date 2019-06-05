defmodule DiscoveryApiWeb.Services.AuthServiceTest do
  use ExUnit.Case
  use Placebo

  alias DiscoveryApiWeb.Services.AuthService
  alias DiscoveryApi.Test.Helper

  describe "has_access?/2" do
    test "should not make ldap call when no logged in user" do
      allow PaddleWrapper.authenticate(any(), any()), return: :doesnt_matter
      model = Helper.sample_model(%{private: true})

      result = AuthService.has_access?(model, nil)

      assert false == result
      refute_called PaddleWrapper.authenticate(any(), any())
    end
  end
end
