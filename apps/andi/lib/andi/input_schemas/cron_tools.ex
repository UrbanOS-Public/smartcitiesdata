defmodule Andi.InputSchemas.CronTools do
  @moduledoc false

  @more_forgiving_iso_date_format "{YYYY}-{M}-{D}"
  @more_forgiving_iso_time_format "{h24}:{m}:{s}"
  @more_forgiving_iso_basic_format "#{@more_forgiving_iso_date_format}T#{@more_forgiving_iso_time_format}"

  def cronstring_to_cronlist!(nil), do: %{}
  def cronstring_to_cronlist!(""), do: %{}
  def cronstring_to_cronlist!("never"), do: %{}
  def cronstring_to_cronlist!("once"), do: %{}
  def cronstring_to_cronlist!(cronstring) do
    cronlist = String.split(cronstring, " ")
    default_keys = [:minute, :hour, :day, :month, :week]

    keys =
      case crontab_length(cronstring) do
        6 -> [:second | default_keys]
        7 -> [:second] ++ default_keys ++ [:year]
        _ -> default_keys
      end

    keys
    |> Enum.zip(cronlist)
    |> Map.new()
  end

  def cronlist_to_cronstring!(nil), do: ""
  def cronlist_to_cronstring!(""), do: ""
  def cronlist_to_cronstring!(%{second: second} = cronlist) when second != "" do
    [:second, :minute, :hour, :day, :month, :week, :year]
    |> Enum.reduce("", fn field, acc ->
      acc <> " " <> to_string(Map.get(cronlist, field, ""))
    end)
    |> String.trim_leading()
    |> String.trim_trailing()
  end
  def cronlist_to_cronstring!(cronlist) do
    cronlist
    |> AtomicMap.convert(safe: false)
    |> Map.put_new(:second, "0")
    |> cronlist_to_cronstring!()
  end

  defp crontab_length(cronstring) do
    cronstring
    |> String.split(" ")
    |> Enum.count()
  end

  def determine_cadence_type(nil), do: determine_cadence_type("")
  def determine_cadence_type(cadence) when cadence in ["once", "never"], do: cadence
  def determine_cadence_type(cadence) do
    with {:ok, parsed_cadence} <- Crontab.CronExpression.Parser.parse(cadence, true),
         [_once] <- Crontab.Scheduler.get_next_run_dates(parsed_cadence) |> Enum.take(2) do
      "future"
    else
      _ -> "repeating"
    end
  end

  def to_repeating(type, nil) when type in ["repeating", "future"], do: %{}
  def to_repeating(type, "") when type in ["repeating", "future"], do: %{}
  def to_repeating(type, cadence) when type in ["repeating", "future"] and cadence not in ["once", "never"], do: cronstring_to_cronlist!(cadence)
  def to_repeating(_type, cadence), do: cronstring_to_cronlist!("0 * * * * *")

  def cronlist_to_future_schedule(%{year: year, month: month, day: day, hour: hour, minute: minute, second: second} = _schedule) do
    date = case Timex.parse("#{year}-#{month}-#{day}", @more_forgiving_iso_date_format) do
      {:error, _} -> nil
      {:ok, nd} -> NaiveDateTime.to_date(nd)
    end

    time = case Timex.parse("#{gee_two_zeroes(hour)}:#{gee_two_zeroes(minute)}:#{gee_two_zeroes(second)}", @more_forgiving_iso_time_format) do
      {:error, _} -> nil
      {:ok, nt} -> NaiveDateTime.to_time(nt)
    end

    %{date: date, time: time}
  end
  def cronlist_to_future_schedule(%{year: _year, month: _month, day: _day, hour: _hour, minute: _minute} = schedule) do
    Map.put_new(schedule, :second, "0")
    |> cronlist_to_future_schedule()
  end
  def cronlist_to_future_schedule(_), do: %{date: nil, time: nil}

  defp gee_two_zeroes(number) do
    String.pad_leading(number, 2, "0")
  end

  def date_and_time_to_cronstring!(date, time) do
    Timex.parse!(date <> "T" <> time, @more_forgiving_iso_basic_format)
    |> Map.from_struct()
    |> Map.merge(%{week: "*"})
    |> cronlist_to_cronstring!()
  end

  defp current_year() do
    Date.utc_today()
    |> Map.get(:year)
  end
end
