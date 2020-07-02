defmodule Andi.InputSchemas.CronToolsTest do
  use ExUnit.Case

  import Checkov

  alias Andi.InputSchemas.CronTools

  import Andi.Test.CronTestHelpers,
    only: [
      cronlist: 2
    ]

  describe "cronstring_to_cronlist!/1" do
    data_test "for #{case}, #{input} returns #{inspect(output)}" do
      assert output == CronTools.cronstring_to_cronlist!(input)

      where([
        [:case, :input, :output],
        ["nil input", nil, %{}],
        ["never input", "never", %{}],
        ["once input", "once", %{}],
        ["empty string input", "", %{}],
        ["repeating cron-string (no second or year)", "* * * * *", %{day: "*", hour: "*", minute: "*", month: "*", week: "*"}],
        [
          "repeating extended cron-string with no year",
          "* * * * * *",
          %{day: "*", hour: "*", minute: "*", month: "*", week: "*", second: "*"}
        ],
        [
          "repeating extended cron-string",
          "* * * * * * *",
          %{day: "*", hour: "*", minute: "*", month: "*", week: "*", second: "*", year: "*"}
        ],
        ["fixed cron-string (no second or year)", "0 0 1 1 *", %{day: "1", hour: "0", minute: "0", month: "1", week: "*"}],
        [
          "fixed extended cron-string with no year",
          "10 10 10 2 2 *",
          %{day: "2", hour: "10", minute: "10", month: "2", week: "*", second: "10"}
        ],
        [
          "fixed extended cron-string",
          "15 15 15 3 3 * 2030",
          %{day: "3", hour: "15", minute: "15", month: "3", week: "*", second: "15", year: "2030"}
        ]
      ])
    end
  end

  describe "cronlist_to_cronstring!/1" do
    data_test "for #{case}, #{inspect(input)} returns #{output}" do
      assert output == CronTools.cronlist_to_cronstring!(input)

      where([
        [:case, :input, :output],
        ["nil input", nil, ""],
        ["empty string input", "", ""],
        ["partially filled", %{second: "*"}, "*"],
        ["missing second", %{hour: "*"}, "0  *"],
        [
          "properly filled",
          %{day: "3", hour: "15", minute: "15", month: "3", week: "*", second: "15", year: "2030"},
          "15 15 15 3 3 * 2030"
        ],
        [
          "handles string keys",
          %{"day" => "3", "hour" => "15", "minute" => "15", "month" => "3", "week" => "*", "second" => "15", "year" => "2030"},
          "15 15 15 3 3 * 2030"
        ],
        [
          "doesn't blow up if some are empty strings",
          %{"day" => "", "hour" => "", "minute" => "15", "month" => "3", "week" => "", "second" => "15"},
          "15 15   3"
        ],
        ["this one weird case", %{"day" => "", "hour" => "", "minute" => "", "month" => "", "second" => "", "week" => "*"}, "0     *"],
        ["deals with partial times", %{"day" => "", "hour" => "", "minute" => "", "month" => "", "second" => "", "week" => "*"}, "0     *"]
      ])
    end
  end

  describe "determine_cadence_type/1" do
    data_test "for #{case}, #{input} returns #{output}" do
      assert output == CronTools.determine_cadence_type(input)

      where([
        [:case, :input, :output],
        ["nil input", nil, "repeating"],
        ["empty string input", "", "repeating"],
        ["once", "once", "once"],
        ["never", "never", "never"],
        ["fixed cadence with error", "16 16 16 4 4 s4 2030", "repeating"],
        ["repearing cadence", "16 16 16 4 4 * *", "repeating"],
        ["repeating cadence with error", "16 16 16 4 4 s4 *", "repeating"]
      ])
    end
  end

  describe "cronstring_to_cronlist_with_default!/2" do
    data_test "for #{case}, #{type} and #{cronstring}" do
      assert output == CronTools.cronstring_to_cronlist_with_default!(type, cronstring)

      where([
        [:case, :type, :cronstring, :output],
        ["once", "once", "once", cronlist(%{second: "0"}, keys: :atoms)],
        ["never", "never", "never", cronlist(%{second: "0"}, keys: :atoms)],
        ["repeating", "repeating", "* * * * * *", cronlist(%{second: "*"}, keys: :atoms)],
        ["future", "future", "* * * * * *", cronlist(%{second: "*"}, keys: :atoms)],
        ["future with previous once", "future", "once", cronlist(%{second: "0"}, keys: :atoms)],
        ["future with previous never", "future", "never", cronlist(%{second: "0"}, keys: :atoms)],
        ["repeating with previous once", "repeating", "once", cronlist(%{second: "0"}, keys: :atoms)],
        ["repeating with previous never", "repeating", "never", cronlist(%{second: "0"}, keys: :atoms)],
        ["future with nil cronstring", "future", nil, %{}],
        ["repeating with nil cronstring", "repeating", nil, %{}],
        ["future with empty cronstring", "future", "", %{}],
        ["repeating with empty cronstring", "repeating", "", %{}],
        ["future with bad cronstring produces goofiness", "future", "brok!", %{minute: "brok!"}],
        ["repeating with bad cronstring produces goofiness", "repeating", "bork!", %{minute: "bork!"}]
      ])
    end
  end

  describe "date_and_time_to_cronstring!/2" do
    data_test "for #{case}, #{date}, #{time} returns #{inspect(output)}" do
      assert output == CronTools.date_and_time_to_cronstring!(date, time)

      where([
        [:case, :date, :time, :output],
        ["date and time convert to UTC", "2030-02-20", "01:02:03", "3 2 6 20 2 * 2030"],
        ["short time converts to UTC", "2030-07-20", "01:02", "0 2 5 20 7 * 2030"]
      ])
    end
  end

  describe "cronlist_to_future_schedule/1" do
    data_test "for #{case}, #{inspect(input)} returns #{inspect(output)}" do
      assert output == CronTools.cronlist_to_future_schedule(input)

      where([
        [:case, :input, :output],
        ["empty cronlist", %{}, %{date: nil, time: nil}],
        [
          "with only date fields as fixed",
          %{day: "1", month: "3", year: "2015", second: "*", minute: "*", hour: "*"},
          %{date: nil, time: nil}
        ],
        [
          "with only time fields as fixed",
          %{day: "*", month: "*", year: "*", second: "0", minute: "1", hour: "2"},
          %{date: nil, time: nil}
        ],
        [
          "with both date and time fields as fixed",
          %{day: "10", month: "11", year: "2010", second: "10", minute: "15", hour: "17"},
          %{date: ~D[2010-11-10], time: ~T[12:15:10]}
        ],
        [
          "with both date and tiem fields as variable",
          %{day: "*", month: "*", year: "*", second: "*", minute: "*", hour: "*"},
          %{date: nil, time: nil}
        ],
        ["with an incomplete cronlist", %{month: "*", year: "*", second: "*", minute: "*", hour: "*"}, %{date: nil, time: nil}],
        [
          "with an invalid date, but valid time",
          %{day: "343", month: "smarch", year: "2030", second: "0", minute: "0", hour: "0"},
          %{date: nil, time: nil}
        ],
        [
          "with an invalid time, but valid date",
          %{day: "10", month: "5", year: "2020", second: "b0", minute: "0", hour: "0"},
          %{date: nil, time: nil}
        ],
        ["with a missing year in date", %{day: "10", month: "5", second: "b0", minute: "0", hour: "0"}, %{date: nil, time: nil}],
        [
          "with a missing second in time",
          %{year: "2050", day: "10", month: "5", minute: "0", hour: "4"},
          %{date: ~D[2050-05-10], time: ~T[00:00:00]}
        ]
      ])
    end
  end
end
