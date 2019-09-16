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
    test "does not filter nils by default" do
      allow Redix.command!(:redix, ["MGET", any(), any(), any()]), return: [1, nil, 3]
      assert Persistence.get_many(["a", "b", "c"]) == [1, nil, 3]
    end

    test "can filter out nils" do
      allow Redix.command!(:redix, ["MGET", any(), any(), any()]), return: [1, nil, 3]
      assert Persistence.get_many(["a", "b", "c"], true) == [1, 3]
    end
  end

  describe "get_many_with_keys/2" do
    test "returns key value pairs" do
      allow Redix.command!(:redix, ["MGET", any(), any(), any()]), return: ["1", "2", "3"]
      assert Persistence.get_many_with_keys(["a", "b", "c"]) == %{"a" => 1, "b" => 2, "c" => 3}
    end

    test "decodes json" do
      allow Redix.command!(:redix, ["MGET", any()]), return: [Jason.encode!(%{id: 1, name: "natty steves"})]
      assert Persistence.get_many_with_keys(["a"]) == %{"a" => %{"id" => 1, "name" => "natty steves"}}
    end

    test "handles nils" do
      allow Redix.command!(:redix, ["MGET", any(), any(), any()]), return: ["1", nil, "3"]
      assert Persistence.get_many_with_keys(["a", "b", "c"]) == %{"a" => 1, "b" => nil, "c" => 3}
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
