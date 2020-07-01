defmodule AndiWeb.EditLiveView.FinalizeFormTest do
  use ExUnit.Case

  import Checkov

  alias AndiWeb.EditLiveView.FinalizeForm


  data_test "converts finalize form data to cadence in form data" do
    form_data = FinalizeForm.update_form_with_schedule(finalize_form_data, %{"technical" => %{}})
    assert expected_form_data == form_data

    where([
      [:finalize_form_data, :expected_form_data],
      [finalize_form(), %{"technical" => %{"cadence" => "once"}}],
      [finalize_form(%{"cadence_type" => "never"}), %{"technical" => %{"cadence" => "never"}}],
      [finalize_form(%{"cadence_type" => ""}), %{"technical" => %{}}],
      [finalize_form(%{"cadence_type" => nil}), %{"technical" => %{}}],
      [finalize_form(%{"cadence_type" => "repeating"}), %{"technical" => %{"cadence" => "* * * * * *"}}],
      [finalize_form(%{"cadence_type" => "repeating", "repeating_schedule" => cronlist(%{"second" => 0})}), %{"technical" => %{"cadence" => "0 * * * * *"}}],
      [finalize_form(%{"cadence_type" => "repeating", "repeating_schedule" => cronlist(%{"year" => "*"})}), %{"technical" => %{"cadence" => "0 * * * * * *"}}],
      [finalize_form(%{"cadence_type" => "future"}), %{"technical" => %{"cadence" => "0 0 0 #{future_day()} #{future_month()} * #{future_year()}"}}],
      [finalize_form(%{"cadence_type" => "future", "future_schedule" => %{"date" => "", "time" => ""}}), %{"technical" => %{"cadence" => ""}}],
      [finalize_form(%{"cadence_type" => "future", "future_schedule" => %{"date" => ""}}), %{"technical" => %{"cadence" => ""}}],
      [finalize_form(%{"cadence_type" => "future", "future_schedule" => %{"time" => ""}}), %{"technical" => %{"cadence" => ""}}],
      [finalize_form(%{"cadence_type" => "future", "repeating_schedule" => blank_cronlist()}), %{"technical" => %{"cadence" => "0 0 0 1 7 * 2021"}}],
      [finalize_form(%{"cadence_type" => "future", "future_schedule" => %{"time" => "00:00"}}), %{"technical" => %{"cadence" => "0 0 0 1 7 * 2021"}}],
    ])
  end

  defp finalize_form(overrides \\ %{}) do
    default_form = %{
      "cadence_type" => "once",
      "future_schedule" => %{
        "date" => Date.to_string(future_date()),
        "time" => Time.to_string(~T[00:00:00])
      },
      "repeating_schedule" => cronlist(%{"second" => "*"})
    }

    if overrides != %{} do
      SmartCity.Helpers.deep_merge(default_form, overrides)
    else
      default_form
    end
  end

  defp future_date() do
    Date.utc_today()
    |> Date.add(365)
  end

  defp future_year() do
    date = future_date()
    date.year
  end

  defp future_month() do
    date = future_date()
    date.month
  end

  defp future_day() do
    date = future_date()
    date.day
  end

  defp cronlist(overrides) do
    %{
      "week" => "*",
      "month" => "*",
      "day" => "*",
      "hour" => "*",
      "minute" => "*",
      "second" => nil
    } |> Map.merge(overrides)
  end

  defp blank_cronlist() do
    %{
      "day" => "",
      "hour" => "",
      "minute" => "",
      "month" => "",
      "second" => "",
      "week" => "*"
    }
  end
end
