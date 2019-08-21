defmodule Reaper.Event.HandlerTest do
  use ExUnit.Case
  use Placebo
  import ExUnit.CaptureLog
  import SmartCity.Event, only: [dataset_update: 0]

  alias Reaper.{ConfigServer, ReaperConfig}
  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    dataset = TDG.create_dataset(%{id: "cool", technical: %{schema: [%{name: "name", type: "string"}]}})

    reaper_config = ReaperConfig.from_dataset(dataset) |> ok()

    allow ConfigServer.process_reaper_config(any()), return: nil

    [dataset: dataset, reaper_config: reaper_config]
  end

  test "happy path", %{dataset: dataset, reaper_config: reaper_config} do
    Reaper.Event.Handler.handle_event(%Brook.Event{
      type: dataset_update(),
      author: "Reaper",
      data: Jason.encode!(dataset)
    })

    assert_called ConfigServer.process_reaper_config(reaper_config)
  end

  test "unable to parse data should log message", %{dataset: dataset} do
    allow SmartCity.Dataset.new(any()), return: {:error, "some failure"}

    log =
      capture_log(fn ->
        Reaper.Event.Handler.handle_event(%Brook.Event{
          type: dataset_update(),
          author: "Reaper",
          data: Jason.encode!(dataset)
        })
      end)

    assert log =~ "Failed to process dataset:update event, reason: \"some failure\""
  end

  def ok({:ok, value}), do: value
end
