defmodule Andi.InputSchemas.CronToolsTest do
  use ExUnit.Case

  import Checkov

  alias Andi.InputSchemas.CronTools

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
        ["repeating extended cron-string with no year", "* * * * * *", %{day: "*", hour: "*", minute: "*", month: "*", week: "*", second: "*"}],
        ["repeating extended cron-string", "* * * * * * *", %{day: "*", hour: "*", minute: "*", month: "*", week: "*", second: "*", year: "*"}],
        ["fixed cron-string (no second or year)", "0 0 1 1 *", %{day: "1", hour: "0", minute: "0", month: "1", week: "*"}],
        ["fixed extended cron-string with no year", "10 10 10 2 2 *", %{day: "2", hour: "10", minute: "10", month: "2", week: "*", second: "10"}],
        ["fixed extended cron-string", "15 15 15 3 3 * 2030", %{day: "3", hour: "15", minute: "15", month: "3", week: "*", second: "15", year: "2030"}]
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
        ["partially filled", %{second: "*"}, "* nil nil nil nil nil nil"],
        ["missing second", %{hour: "*"}, "0 nil * nil nil nil nil"],
        ["properly filled", %{day: "3", hour: "15", minute: "15", month: "3", week: "*", second: "15", year: "2030"}, "15 15 15 3 3 * 2030"],
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
        ["repeating cadence with error", "16 16 16 4 4 s4 *", "repeating"],
      ])
    end
  end

  describe "date_and_time_to_cronstring/2" do
    data_test "for #{case}, #{date}, #{time} returns #{inspect(output)}" do
      result = CronTools.date_and_time_to_cronstring(date, time)

      if output do
        assert {^status, ^output} = result
      else
        assert {^status, _} = result
      end

      where([
        [:case, :date, :time, :status, :output],
        ["empty for both", "", "", :error, nil],
        ["only date", "2020-1-10", "", :error, nil],
        ["only time", "", "00:01:03", :error, nil],
        ["date and time", "2030-2-20", "01:02:03", :ok, "3 2 1 20 2 * 2030"],
        ["bad date", "20b0-2-20", "", :error, nil],
        ["bad time", "", "0901:03", :error, nil],
        ["bad date and time", "20b0-2-20", "0901:03", :error, nil],
      ])
    end
  end

  describe "cronlist_to_future_schedule/1" do
    data_test "for #{case}, #{inspect(input)} returns #{inspect(output)}" do
      assert output == CronTools.cronlist_to_future_schedule(input)

      where([
        [:case, :input, :output],
        ["empty cronlist", %{}, %{"future_date" => nil, "future_time" => nil}],
        ["with only date fields as fixed", %{day: "1", month: "3", year: "2015", second: "*", minute: "*", hour: "*"}, %{"future_date" => ~D[2015-03-01], "future_time" => nil}],
        ["with only time fields as fixed", %{day: "*", month: "*", year: "*", second: "0", minute: "1", hour: "2"}, %{"future_date" => nil, "future_time" => ~T[02:01:00]}],
        ["with both date and time fields as fixed", %{day: "10", month: "11", year: "2010", second: "10", minute: "15", hour: "13"}, %{"future_date" => ~D[2010-11-10], "future_time" => ~T[13:15:10]}],
        ["with both date and tiem fields as variable", %{day: "*", month: "*", year: "*", second: "*", minute: "*", hour: "*"}, %{"future_date" => nil, "future_time" => nil}],
        ["with an incomplete cronlist", %{month: "*", year: "*", second: "*", minute: "*", hour: "*"}, %{"future_date" => nil, "future_time" => nil}],
        ["with an invalid date, but valid time", %{day: "343", month: "smarch", year: "2030", second: "0", minute: "0", hour: "0"}, %{"future_date" => nil, "future_time" => ~T[00:00:00]}],
        ["with an invalid time, but valid date", %{day: "10", month: "5", year: "2020", second: "b0", minute: "0", hour: "0"}, %{"future_date" => ~D[2020-05-10], "future_time" => nil}],
        ["with a missing year in date", %{day: "10", month: "5", second: "b0", minute: "0", hour: "0"}, %{"future_date" => nil, "future_time" => nil}],
        ["with a missing second in time", %{year: "2050", day: "10", month: "5", minute: "0", hour: "1"}, %{"future_date" => ~D[2050-05-10], "future_time" => ~T[01:00:00]}],
      ])
    end
  end
end
