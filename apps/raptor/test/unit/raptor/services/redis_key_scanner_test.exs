defmodule Raptor.Services.RedisKeyScannerTest do
  use RaptorWeb.ConnCase
  import Mock
  alias Raptor.Services.RedisKeyScanner

  @redix Raptor.Application.redis_client()

  describe "scan/2" do
    test "returns an empty list when the first cursor is already 0" do
      with_mock Redix,
        command!: fn _, ["SCAN", "0", "MATCH", "raptor:*", "COUNT", 500] -> ["0", []] end do
        assert [] == RedisKeyScanner.scan(@redix, "raptor:*")
      end
    end

    test "returns all matching keys found on a single page" do
      with_mock Redix,
        command!: fn _, ["SCAN", "0", "MATCH", "raptor:*", "COUNT", 500] ->
          ["0", ["raptor:1", "raptor:2"]]
        end do
        assert ["raptor:1", "raptor:2"] == RedisKeyScanner.scan(@redix, "raptor:*")
      end
    end

    test "follows the cursor across multiple pages and accumulates keys" do
      with_mock Redix,
        command!: fn
          _, ["SCAN", "0", "MATCH", "raptor:*", "COUNT", 500] -> ["17", ["raptor:1"]]
          _, ["SCAN", "17", "MATCH", "raptor:*", "COUNT", 500] -> ["0", ["raptor:2"]]
        end do
        assert ["raptor:1", "raptor:2"] == RedisKeyScanner.scan(@redix, "raptor:*")
      end
    end
  end
end
