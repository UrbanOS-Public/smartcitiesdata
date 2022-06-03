defmodule Flair.DurationsTest do
  use ExUnit.Case

  alias SmartCity.Data
  alias SmartCity.Data.Timing

  alias Flair.Durations

  describe "reducer/2" do
    test "with empty accumulator" do
      message =
        make_data_message()
        |> Data.add_timing(make_timing())

      assert %{"some_id" => [%Timing{}]} = Durations.reducer(message, %{})
    end

    test "with existing accumulator" do
      message =
        make_data_message()
        |> Data.add_timing(make_timing())

      assert %{"some_id" => [%Timing{}, %Timing{}]} =
               Durations.reducer(message, Durations.reducer(message, %{}))
    end

    test "three messages" do
      messages =
        1..3
        |> Enum.map(fn _ -> make_data_message() end)
        |> Enum.map(&Data.add_timing(&1, make_timing()))

      assert %{"some_id" => [%Timing{}, %Timing{}, %Timing{}]} =
               Enum.reduce(messages, %{}, &Durations.reducer/2)
    end

    test "different dataset_ids" do
      messages =
        1..3
        |> Enum.map(&Integer.to_string/1)
        |> Enum.map(&make_data_message(dataset_id: &1))
        |> Enum.map(&Data.add_timing(&1, make_timing()))

      assert %{"1" => [%Timing{}], "2" => [%Timing{}], "3" => [%Timing{}]} =
               Enum.reduce(messages, %{}, &Durations.reducer/2)
    end
  end

  describe "calculates durations" do
    test "aggregates by app and label" do
      input = {"dataset 1", [make_timing(), make_timing(), make_timing(label: "label_2")]}

      assert {_,
              %{
                {"app_1", "label_1"} => %{
                  count: 2
                },
                {"app_1", "label_2"} => %{
                  count: 1
                }
              }} = Durations.calculate_durations(input)
    end

    test "has expected keys in the durations" do
      input = {"dataset 1", [make_timing(), make_timing()]}

      assert {_,
              %{
                {"app_1", "label_1"} => %{
                  count: _,
                  max: _,
                  min: _,
                  average: _,
                  stdev: _
                }
              }} = Durations.calculate_durations(input)
    end

    test "computes correct durations" do
      input = {"dataset 1", [make_timing(offset: 1), make_timing(offset: 2)]}

      assert {_,
              %{
                {"app_1", "label_1"} => %{
                  count: 2,
                  max: 2000,
                  min: 1000,
                  average: 1.5e3,
                  stdev: 500.0
                }
              }} = Durations.calculate_durations(input)
    end
  end

  defp make_data_message(opts \\ []) do
    dataset_id = Keyword.get(opts, :dataset_id, "some_id")
    timing = Keyword.get(opts, :timing, [])

    {:ok, data} =
      Data.new(%{
        dataset_id: dataset_id,
        ingestion_id: "some_ingestion",
        extraction_start_time: DateTime.utc_now() |> DateTime.to_iso8601(),
        payload: "dont_care",
        _metadata: "dont_care",
        operational: %{
          timing: timing
        }
      })

    data
  end

  defp make_timing(opts \\ []) do
    app = Keyword.get(opts, :app, "app_1")
    label = Keyword.get(opts, :label, "label_1")

    offset = Keyword.get(opts, :offset, 5)

    {default_start, default_end} = make_times(offset)

    start_time = Keyword.get(opts, :start_time, default_start)
    end_time = Keyword.get(opts, :end_time, default_end)

    %Timing{
      app: app,
      label: label,
      start_time: start_time,
      end_time: end_time
    }
  end

  defp make_times(offset) do
    start_time = DateTime.utc_now()
    end_time = start_time |> DateTime.add(offset, :second)
    {DateTime.to_iso8601(start_time), DateTime.to_iso8601(end_time)}
  end
end
