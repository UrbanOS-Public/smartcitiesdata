defmodule Raptor.Services.RedisKeyScanner do
  @moduledoc """
  Finds keys matching a pattern using Redis SCAN instead of KEYS.

  KEYS walks the entire keyspace in one blocking pass, holding up every other
  client on the connection until it finishes. SCAN walks the same keyspace
  incrementally via a cursor, so it never blocks Redis for more than a single
  small batch at a time.
  """

  @scan_count 500

  @spec scan(atom() | pid(), String.t()) :: list(String.t())
  def scan(redix, pattern) do
    do_scan(redix, pattern, "0", [])
  end

  defp do_scan(redix, pattern, cursor, acc) do
    case Redix.command!(redix, ["SCAN", cursor, "MATCH", pattern, "COUNT", @scan_count]) do
      ["0", keys] -> acc ++ keys
      [next_cursor, keys] -> do_scan(redix, pattern, next_cursor, acc ++ keys)
    end
  end
end
