defmodule Andi.InputSchemas.CronTools do
  @moduledoc false

  @more_forgiving_iso_date_format "{YYYY}-{M}-{D}"
  @more_forgiving_iso_time_format "{ISOtime}"
  @more_forgiving_iso_datetime_format "#{@more_forgiving_iso_date_format}T#{@more_forgiving_iso_time_format}"

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

  def cronlist_to_cronstring!(%{"second" => _} = cronlist) do
    AtomicMap.convert(cronlist, safe: false)
    |> cronlist_to_cronstring!()
  end

  def cronlist_to_cronstring!(%{second: second} = cronlist) when is_nil(second) or second == "" do
    cronlist
    |> Map.put(:second, "0")
    |> cronlist_to_cronstring!()
  end

  def cronlist_to_cronstring!(%{second: _second} = cronlist) do
    [:second, :minute, :hour, :day, :month, :week, :year]
    |> Enum.reduce("", fn field, acc ->
      acc <> " " <> to_string(Map.get(cronlist, field, ""))
    end)
    |> String.trim_leading()
    |> String.trim_trailing()
  end

  def cronlist_to_cronstring!(cronlist) do
    cronlist
    |> Map.put(:second, "0")
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

  def cronstring_to_cronlist_with_default!(type, nil) when type in ["repeating", "future"], do: %{}
  def cronstring_to_cronlist_with_default!(type, "") when type in ["repeating", "future"], do: %{}

  def cronstring_to_cronlist_with_default!(type, cadence) when type in ["repeating", "future"] and cadence not in ["once", "never"],
    do: cronstring_to_cronlist!(cadence)

  def cronstring_to_cronlist_with_default!(_type, _cadence), do: cronstring_to_cronlist!("0 * * * * *")

  def cronlist_to_future_schedule(%{year: year, month: month, day: day, hour: hour, minute: minute, second: second} = _schedule) do
    case Timex.parse("#{year}-#{month}-#{day}T#{pad(hour)}:#{pad(minute)}:#{pad(second)}", @more_forgiving_iso_datetime_format) do
      {:error, _} ->
        %{date: nil, time: nil}

      {:ok, dt} ->
        datetime = convert_from_utc(dt)
        %{date: DateTime.to_date(datetime), time: DateTime.to_time(datetime)}
    end
  end

  def cronlist_to_future_schedule(%{year: _year, month: _month, day: _day, hour: _hour, minute: _minute} = schedule) do
    Map.put_new(schedule, :second, "0")
    |> cronlist_to_future_schedule()
  end

  def cronlist_to_future_schedule(_), do: %{date: nil, time: nil}

  defp pad(padee, padding \\ "0", length \\ 2) do
    String.pad_leading(padee, length, padding)
  end

  def date_and_time_to_cronstring!(date, time) do
    time = String.pad_trailing(time, 8, ":00")

    Timex.parse!(date <> "T" <> time, @more_forgiving_iso_datetime_format)
    |> convert_to_utc()
    |> Map.from_struct()
    |> Map.merge(%{week: "*"})
    |> cronlist_to_cronstring!()
  end

  defp convert_to_utc(datetime) do
    datetime
    |> Timex.to_datetime(Andi.timezone())
    |> Timex.to_datetime("UTC")
  end

  defp convert_from_utc(datetime) do
    datetime
    |> Timex.to_datetime("UTC")
    |> Timex.to_datetime(Andi.timezone())
  end
end
