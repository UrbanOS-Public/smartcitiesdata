defmodule DiscoveryApi.Auth.TokenHandlerTest do
  use ExUnit.Case

  alias DiscoveryApiWeb.Auth.TokenHandler

  describe "claims_to_jwtid/1" do
    test "given some very lengthy claims, it gives the same JWTID back" do
      claims_first_try = lengthy_claims()
      claims_second_try = lengthy_claims()

      assert TokenHandler.claims_to_jwtid(claims_first_try) == TokenHandler.claims_to_jwtid(claims_second_try)
    end

    # this is for cases where changes to erlang/elixir might change hashing and we roll the API between token revoke and expiry - how identical token claims are hashed MAY change if things like Map sorting or :erlang.term_to_binary change significantly between versions
    test "given a jwtid that was issued in the past, it calculates the same one across elixir upgrades, etc." do
      jwtid_from_yesteryear = "637F25E22827723DE296BC4F4CE996F520899B8DD57E2E008C20A8F8ACBBC384"

      assert jwtid_from_yesteryear == TokenHandler.claims_to_jwtid(lengthy_claims())
    end
  end

  defp lengthy_claims(overrides \\ %{}) do
    1..1000
    |> Enum.map(fn n -> {"#{n}", n} end)
    |> Map.new()
    |> Map.merge(overrides)
  end
end
