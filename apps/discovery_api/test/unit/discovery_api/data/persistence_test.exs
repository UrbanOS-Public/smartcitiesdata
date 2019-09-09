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

  describe "get_many/2" do
    test "doesnt filter nils by default" do
      allow Redix.command!(:redix, ["MGET", any()]), return: ["item a", nil, "item c"]
      assert Persistence.get_many(["redis_key"]) == ["item a", nil, "item c"]
    end

    test "can filter out nils" do
      allow Redix.command!(:redix, ["MGET", any()]), return: ["item a", nil, "item c"]
      assert Persistence.get_many(["redis_key"], true) == ["item a", "item c"]
    end
  end

  describe "get_all/2" do
    test "doesnt filter out nils by default" do
      allow Redix.command!(:redix, ["KEYS", any()]), return: ["key", "keyb"]
      allow Redix.command!(:redix, ["MGET" | any()]), return: [~s|{"item": 1}|, nil, ~s|{"item": 2}|]

      actual = Persistence.get_all("redis_key") |> Enum.map(&safe_json_decode/1)

      assert actual == [%{item: 1}, nil, %{item: 2}]
    end

    test "can filter out nils" do
      allow Redix.command!(:redix, ["KEYS", any()]), return: ["key", "keyb"]
      allow Redix.command!(:redix, ["MGET" | any()]), return: [~s|{"item": 1}|, nil, ~s|{"item": 2}|]

      actual = Persistence.get_all("redis_key", true) |> Enum.map(&safe_json_decode/1)

      assert actual == [%{item: 1}, %{item: 2}]
    end
  end

  defp safe_json_decode(json) do
    case json do
      nil -> nil
      decode -> Jason.decode!(decode, keys: :atoms)
    end
  end
end
