defmodule DiscoveryApiWeb.Plugs.VerifyTokenTest do
  use ExUnit.Case
  use Placebo

  use DiscoveryApiWeb.ConnCase

  alias DiscoveryApiWeb.Plugs.{VerifyHeaderAuth0, VerifyToken}
  alias Guardian.Plug.{VerifyCookie, VerifyHeader}

  describe "init/1" do
    test "chains to Guardian VerifyHeader then VerifyCookie" do
      allow(VerifyHeader.init(any()), return: :header_init_result)
      allow(VerifyCookie.init(any()), return: :cookie_init_result)

      result = VerifyToken.init(:init_arg)

      assert result == :cookie_init_result
      assert_called(VerifyHeader.init(:init_arg), times(1))
      assert_called(VerifyCookie.init(:header_init_result), times(1))
    end
  end

  describe "call/2" do
    setup do
      allow(VerifyHeader.call(any(), any()), return: :header_conn)
      allow(VerifyCookie.call(any(), any()), return: :cookie_conn)
      allow(VerifyHeaderAuth0.call(any(), any()), return: :auth0_conn)

      original_auth_provider = Application.get_env(:discovery_api, :auth_provider)

      on_exit(fn ->
        Application.put_env(:discovery_api, :auth_provider, original_auth_provider)
      end)
    end

    test "calls Verifies Header then Cookie with default auth provider" do
      Application.put_env(:discovery_api, :auth_provider, "default")

      result = VerifyToken.call(:initial_conn, :opts)

      assert result == :cookie_conn
      assert_called(VerifyHeader.call(:initial_conn, :opts), times(1))
      assert_called(VerifyCookie.call(:header_conn, :opts), times(1))
    end

    test "delegates to VerifyHeaderAuth0 with auth0 auth provider" do
      Application.put_env(:discovery_api, :auth_provider, "auth0")

      result = VerifyToken.call(:conn, :opts)

      assert result == :auth0_conn
      assert_called(VerifyHeaderAuth0.call(:conn, :opts), times(1))
    end
  end
end
