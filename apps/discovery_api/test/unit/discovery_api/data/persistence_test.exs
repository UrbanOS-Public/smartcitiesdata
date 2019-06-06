defmodule DiscoveryApi.Data.PersistenceTest do
  use ExUnit.Case
  use Placebo
  alias DiscoveryApi.Data.Persistence

  describe "persist/2" do
    test "sets complex objects correctly" do
      allow Redix.command(:redix, ["SET", any(), any()]), return: :does_not_matter

      Persistence.persist("redis_key", %{value: "test_value"})

      assert_called Redix.command(:redix, ["SET", "redis_key", ~s|{"value":"test_value"}|])
    end

    test "sets strings correctly" do
      allow Redix.command(:redix, ["SET", any(), any()]), return: :does_not_matter

      Persistence.persist("redis_key", "test_value")

      assert_called Redix.command(:redix, ["SET", "redis_key", "test_value"])
    end
  end
end
