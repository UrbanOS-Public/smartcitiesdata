defmodule Raptor.Services.RedisKeyScannerTest do
  use RaptorWeb.ConnCase
  use Placebo
  alias Raptor.Services.RedisKeyScanner

  @redix Raptor.Application.redis_client()

  describe "scan/2" do
    test "returns an empty list when the first cursor is already 0" do
      allow(Redix.command!(@redix, ["SCAN", "0", "MATCH", "raptor:*", "COUNT", 500]),
        return: ["0", []]
      )

      assert [] == RedisKeyScanner.scan(@redix, "raptor:*")
    end

    test "returns all matching keys found on a single page" do
      allow(Redix.command!(@redix, ["SCAN", "0", "MATCH", "raptor:*", "COUNT", 500]),
        return: ["0", ["raptor:1", "raptor:2"]]
      )

      assert ["raptor:1", "raptor:2"] == RedisKeyScanner.scan(@redix, "raptor:*")
    end

    test "follows the cursor across multiple pages and accumulates keys" do
      allow(Redix.command!(@redix, ["SCAN", "0", "MATCH", "raptor:*", "COUNT", 500]),
        return: ["17", ["raptor:1"]]
      )

      allow(Redix.command!(@redix, ["SCAN", "17", "MATCH", "raptor:*", "COUNT", 500]),
        return: ["0", ["raptor:2"]]
      )

      assert ["raptor:1", "raptor:2"] == RedisKeyScanner.scan(@redix, "raptor:*")
    end
  end
end
