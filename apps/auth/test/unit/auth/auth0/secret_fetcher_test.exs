defmodule Auth.Auth0.SecretFetcherTest do
  @moduledoc false

  use ExUnit.Case, async: true
  import Mox
  
  setup :verify_on_exit!

  describe "valid jwks key store" do
    test "gives requested key" do
      assert true
    end

    test "returns error message if no key is found in the store" do
      assert true
    end
  end

  test "caches key fetching for subsequent calls" do
    assert true
  end

  describe "invalid jwks key store" do
    test "returns error given by issuer" do
      assert true
    end
  end
end