defmodule Reaper.Event.Handler do
  @moduledoc "This module will process dataset:update events"
  use Brook.Event.Handler
  import SmartCity.Event, only: [dataset_update: 0]
  require Logger
  alias Reaper.ConfigServer
  alias Reaper.ReaperConfig

  def handle_event(%Brook.Event{type: dataset_update(), data: data}) do
    with {:ok, dataset} <- SmartCity.Dataset.new(data),
         {:ok, reaper_config} <- ReaperConfig.from_dataset(dataset) do
      Logger.debug(fn -> "#{__MODULE__}: Got #{dataset_update()} event processing #{reaper_config.dataset_id}" end)

      ConfigServer.process_reaper_config(reaper_config)

      {:merge, :reaper_config, reaper_config.dataset_id, reaper_config}
    else
      {:error, reason} ->
        Logger.error("Failed to process #{dataset_update()} event, reason: #{inspect(reason)}")
        :discard
    end
  end
end
