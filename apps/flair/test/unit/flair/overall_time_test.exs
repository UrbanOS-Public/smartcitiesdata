defmodule Flair.OverallTimeTest do
  use ExUnit.Case

  alias SmartCity.Data
  alias SmartCity.Data.Timing
  alias SmartCity.TestDataGenerator

  alias Flair.OverallTime

  describe "add/1" do
    test "data message is unchanged when timing list is empty" do
      data =
        TestDataGenerator.create_data(
          dataset_ids: ["pirates", "eyepatch"],
          operational: %{timing: []}
        )

      assert OverallTime.add(data) == data
    end

    test "correctly chooses first start and last end" do
      current_time = DateTime.utc_now()

      first_time =
        Data.Timing.new(
          app: "FirstTime",
          label: "the_time",
          start_time: current_time |> DateTime.to_iso8601(),
          end_time: offset_datetime(current_time, 5)
        )

      second_time =
        Data.Timing.new(
          app: "SecondTime",
          label: "the_time",
          start_time: offset_datetime(current_time, 10),
          end_time: offset_datetime(current_time, 15)
        )

      data =
        TestDataGenerator.create_data(
          dataset_ids: ["pirates", "eyepatch"],
          operational: %{timing: []}
        )

      data = data |> Data.add_timing(second_time) |> Data.add_timing(first_time)

      timings = data |> OverallTime.add() |> Data.get_all_timings()

      assert Enum.member?(timings, %Timing{
               app: "SmartCityOS",
               label: "EndToEnd",
               start_time: first_time.start_time,
               end_time: second_time.end_time
             })
    end
  end

  defp offset_datetime(dt, offset), do: dt |> DateTime.add(offset) |> DateTime.to_iso8601()
end
