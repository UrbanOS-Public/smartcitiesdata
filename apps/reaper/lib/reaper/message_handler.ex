defmodule Reaper.MessageHandler do
  @moduledoc false
  require Logger
  alias Reaper.ConfigServer
  alias Reaper.ReaperConfig
  use SmartCity.Registry.MessageHandler

  def handle_dataset(%SmartCity.Dataset{} = dataset) do
    with {:ok, reaper_config} <- ReaperConfig.from_dataset(dataset) do
      ConfigServer.process_reaper_config(reaper_config)
    else
      {:error, reason} ->
        Logger.error("Skipping registry message for this reason: #{inspect(reason)}")

      _ ->
        Logger.error("Unexpected response received")
    end
  end
end
