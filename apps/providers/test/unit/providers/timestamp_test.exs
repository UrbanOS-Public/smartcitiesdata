defmodule Providers.TimestampTest do
  use ExUnit.Case

  describe "v1" do
    test "provides a valid iso8601 timestamp" do
      timestamp = Providers.Timestamp.provide("1", %{})

      assert {:ok, _timestamp} = NaiveDateTime.from_iso8601(timestamp)
    end
  end

  describe "v2" do
    test "provides a valid timestamp, defaulting to iso8601 format" do
      timestamp = Providers.Timestamp.provide("2", %{})

      assert {:ok, _timestamp} = NaiveDateTime.from_iso8601(timestamp)
    end

    test "provides a valid timestamp in the provided timex format" do
      timestamp = Providers.Timestamp.provide("2", %{format: "{ISOtime}"})

      assert {:ok, _timestamp} = Timex.parse(timestamp, "{ISOtime}")
    end

    test "provides a valid timestamp in the provided timezone" do
      timestamp =
        Providers.Timestamp.provide(
          "2",
          %{format: "{ISO:Basic}", timezone: "Asia/Ulaanbaatar"}
        )

      assert String.contains?(timestamp, "+0800")
    end

    test "provides a valid timestamp offset by seconds" do
      format = "{YYYY}-{0M}-{0D}"
      offset_in_days = -1

      timestamp =
        Providers.Timestamp.provide("2", %{
          offset_in_seconds: offset_in_days * 24 * 60 * 60,
          format: format
        })

      assert Timex.now()
             |> Timex.add(Timex.Duration.from_days(offset_in_days))
             |> Timex.format!(format) == timestamp
    end
  end
end
