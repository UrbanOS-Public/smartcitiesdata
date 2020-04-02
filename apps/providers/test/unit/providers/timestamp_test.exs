defmodule Providers.TimestampTest do
  use ExUnit.Case

  describe "v1" do
    test "provides a valid iso8601 timestamp" do
      timestamp = Providers.Timestamp.provide("1", %{})

      assert {:ok, _timestamp} = NaiveDateTime.from_iso8601(timestamp)
    end
  end

  describe "v2" do
    test "provides a date in iso8601" do
      timestamp = Providers.Timestamp.provide("2", %{})

      assert {:ok, _timestamp} = NaiveDateTime.from_iso8601(timestamp)
    end

    test "provides a date in given timex format" do
      format = "{YYYY}-{0M}-{0D}"

      timestamp = Providers.Timestamp.provide("2", %{format: format})

      assert NaiveDateTime.utc_now() |> Timex.format!(format) == timestamp
    end
  end
end
