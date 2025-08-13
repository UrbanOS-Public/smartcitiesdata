defmodule DiscoveryApi.Data.PersistenceTest do
  use ExUnit.Case
  import Mox
  alias DiscoveryApi.Data.Persistence

  setup :verify_on_exit!

  describe "persist/2" do
    test "sets complex objects correctly" do
      stub(RedixMock, :command, fn :redix, ["SET", "redis_key", ~s|{"value":"test_value"}|] -> :does_not_matter end)

      Persistence.persist("redis_key", %{value: "test_value"})

      verify!(RedixMock)
    end

    test "sets strings correctly" do
      stub(RedixMock, :command, fn :redix, ["SET", "redis_key", "test_value"] -> :does_not_matter end)

      Persistence.persist("redis_key", "test_value")

      verify!(RedixMock)
    end
  end

  describe "get_many/2" do
    test "does not filter nils by default" do
      stub(RedixMock, :command!, fn :redix, ["MGET", "a", "b", "c"] -> [1, nil, 3] end)
      assert Persistence.get_many(["a", "b", "c"]) == [1, nil, 3]
    end

    test "can filter out nils" do
      stub(RedixMock, :command!, fn :redix, ["MGET", "a", "b", "c"] -> [1, nil, 3] end)
      assert Persistence.get_many(["a", "b", "c"], true) == [1, 3]
    end
  end

  describe "get_many_with_keys/2" do
    test "returns key value pairs" do
      stub(RedixMock, :command!, fn :redix, ["MGET", "a", "b", "c"] -> ["1", "2", "3"] end)
      assert Persistence.get_many_with_keys(["a", "b", "c"]) == %{"a" => 1, "b" => 2, "c" => 3}
    end

    test "decodes json" do
      stub(RedixMock, :command!, fn :redix, ["MGET", "a"] -> [Jason.encode!(%{id: 1, name: "natty steves"})] end)
      assert Persistence.get_many_with_keys(["a"]) == %{"a" => %{"id" => 1, "name" => "natty steves"}}
    end

    test "handles nils" do
      stub(RedixMock, :command!, fn :redix, ["MGET", "a", "b", "c"] -> ["1", nil, "3"] end)
      assert Persistence.get_many_with_keys(["a", "b", "c"]) == %{"a" => 1, "b" => nil, "c" => 3}
    end
  end

  describe "get_all/2" do
    test "doesnt filter out nils by default" do
      stub(RedixMock, :command!, fn 
        :redix, ["KEYS", "redis_key"] -> ["key", "keyb"]
        :redix, ["MGET", "key", "keyb"] -> [~s|{"item": 1}|, nil, ~s|{"item": 2}|]
      end)

      actual = Persistence.get_all("redis_key") |> Enum.map(&safe_json_decode/1)

      assert actual == [%{item: 1}, nil, %{item: 2}]
    end

    test "can filter out nils" do
      stub(RedixMock, :command!, fn 
        :redix, ["KEYS", "redis_key"] -> ["key", "keyb"]
        :redix, ["MGET", "key", "keyb"] -> [~s|{"item": 1}|, nil, ~s|{"item": 2}|]
      end)

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
