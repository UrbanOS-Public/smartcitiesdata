defmodule AndiWeb.Test.CronTestHelpers do
  @moduledoc """
  Helpers for generating the finalize form, cronlists and naivedatetimes
  """

  alias AndiWeb.InputSchemas.FinalizeFormSchema.FutureSchedule

  def finalize_form(overrides \\ %{}, opts \\ []) do
    keys = Keyword.get(opts, :keys, :strings)

    default_form = %{
      "cadence_type" => "once",
      "future_schedule" => %{
        "date" => future_date(keys),
        "time" => whatever_time(keys)
      },
      "repeating_schedule" => cronlist(%{"second" => "*"})
    }

    overridden_form = if overrides != %{} do
      SmartCity.Helpers.deep_merge(default_form, overrides)
    else
      default_form
    end

    format_map(overridden_form, keys)
  end

  def cronlist(overrides \\ %{}, opts \\ []) do
    keys = Keyword.get(opts, :keys, :strings)

    %{
      "week" => "*",
      "month" => "*",
      "day" => "*",
      "hour" => "*",
      "minute" => "*",
      "second" => nil
    }
    |> Map.merge(overrides)
    |> format_map(keys)
  end

  def blank_cronlist(opts \\ []) do
    keys = Keyword.get(opts, :keys, :strings)

    %{
      "day" => "",
      "hour" => "",
      "minute" => "",
      "month" => "",
      "second" => "",
      "week" => "*"
    }
    |> format_map(keys)
  end

  defp format_map(map, :strings), do: map
  defp format_map(map, :atoms) do
    AtomicMap.convert(map, safe: false)
  end

  defp future_date(format \\ :atoms) do
    local_now()
    |> DateTime.to_date()
    |> Date.add(365)
    |> format_date(format)
  end

  def future_year() do
    date = future_date()
    date.year
  end

  def future_month() do
    date = future_date()
    date.month
  end

  def future_day() do
    date = future_date()
    date.day
  end

  defp local_now() do
    {:ok, dt} = DateTime.now(FutureSchedule.local_timezone())
    dt
  end

  defp date_before_test(format \\ :atoms) do
    local_now()
    |> DateTime.to_date()
    |> format_date(format)
  end

  defp whatever_time(format) do
    ~T[00:00:00]
    |> format_time(format)
  end

  defp time_before_test(format \\ :atoms) do
    local_now()
    |> DateTime.to_time()
    |> format_time(format)
  end

  defp format_date(date, :atoms), do: date
  defp format_date(date, :strings), do: Date.to_string(date)
  defp format_time(time, :atoms), do: time
  defp format_time(time, :strings), do: Time.to_string(time)
end
