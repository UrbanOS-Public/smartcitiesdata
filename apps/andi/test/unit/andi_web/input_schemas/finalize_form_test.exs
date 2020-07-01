defmodule AndiWeb.InputSchemas.FinalizeFormTest do
  use ExUnit.Case

  import Checkov
  use Placebo

  alias Ecto.Changeset

  alias AndiWeb.InputSchemas.FinalizeForm

  describe "changeset/2 given a map with a cadence (the technical form)" do
    data_test "converts and validates the cadence pieces" do
      technical_form = %{
        cadence: cadence
      }
      future_schedule_with_id = Map.put_new(future_schedule, :id, nil)
      repeating_schedule_with_id = Map.put_new(repeating_schedule, :id, nil)

      changeset = FinalizeForm.changeset(%FinalizeForm{}, technical_form)

      assert cadence_type == Changeset.get_field(changeset, :cadence_type)
      assert future_schedule_with_id == Changeset.get_field(changeset, :future_schedule) |> Map.from_struct()
      assert repeating_schedule_with_id == Changeset.get_field(changeset, :repeating_schedule) |> Map.from_struct()

      where([
        [:cadence, :cadence_type, :future_schedule, :repeating_schedule],
        [nil, "repeating", %{date: nil, time: nil}, %{week: nil, month: nil, day: nil, hour: nil, minute: nil, second: nil}],
        ["", "repeating", %{date: nil, time: nil}, %{week: nil, month: nil, day: nil, hour: nil, minute: nil, second: nil}],
        ["* * * * *", "repeating", %{date: nil, time: nil}, cronlist()],
        ["* * * * * *", "repeating", %{date: nil, time: nil}, cronlist(%{second: "*"})],
        ["* * * * * * *", "repeating", %{date: nil, time: nil}, cronlist(%{second: "*"})],
        ["0 0 1 1 *", "repeating", %{date: nil, time: nil}, cronlist(%{month: "1", day: "1", hour: "0", minute: "0"})],
        ["10 10 10 2 2 *", "repeating", %{date: nil, time: nil}, cronlist(%{month: "2", day: "2", hour: "10", minute: "10", second: "10"})],
        ["15 15 15 3 3 * 2030", "future", %{date: ~D[2030-03-03], time: ~T[15:15:15]}, cronlist(%{month: "3", day: "3", hour: "15", minute: "15", second: "15"})],
      ])
    end
  end

  describe "changeset/2 given a scheduler form (from UI)" do
    data_test "validation cases for input" do
      changeset = FinalizeForm.changeset(%FinalizeForm{}, form)

      assert errors == errors_on(changeset)

      where([
        [:form, :errors],
        [finalize_form(%{future_schedule: %{date: "", time: ""}}), %{future_schedule: %{date: ["can't be blank"], time: ["can't be blank"]}}],
        [finalize_form(%{future_schedule: %{time: ""}}), %{future_schedule: %{time: ["can't be blank"]}}],
        [finalize_form(%{future_schedule: %{date: ~D[1900-01-01], time: ~T[00:00:00]}}), %{future_schedule: %{date: ["can't be in past"], time: ["can't be in past"]}}],
        [finalize_form(%{future_schedule: %{date: date_before_test(), time: time_before_test()}}), %{future_schedule: %{date: ["can't be in past"], time: ["can't be in past"]}}],
        [finalize_form(%{future_schedule: %{date: "SDFDS", time: "df3dfd"}}), %{future_schedule: %{date: ["is invalid"], time: ["is invalid"]}}],
        [finalize_form(%{repeating_schedule: %{day: "b*"}}), %{repeating_schedule: %{day: ["has invalid format"]}}],
        [finalize_form(%{repeating_schedule: cronlist(%{second: nil})}), %{repeating_schedule: %{second: ["can't be blank"]}}],
        [finalize_form(), %{}],
      ])
    end
  end

  defp finalize_form(overrides \\ %{}) do
    %{
      cadence_type: "repeating",
      future_schedule: %{
        date: future_date(),
        time: ~T[00:00:00]
      },
      repeating_schedule: cronlist(%{second: "*"})
    } |> SmartCity.Helpers.deep_merge(overrides)
  end

  defp cronlist(overrides \\ %{}) do
    %{
      week: "*",
      month: "*",
      day: "*",
      hour: "*",
      minute: "*",
      second: nil
    } |> Map.merge(overrides)
  end

  defp future_date() do
    Date.utc_today()
    |> Date.add(365)
  end

  defp date_before_test() do
    Date.utc_today()
  end
  defp time_before_test() do
    Time.utc_now()
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

end
