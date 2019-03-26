defmodule Reaper.MessageHandler do
  @moduledoc false
  require Logger
  alias Reaper.ConfigServer
  alias Reaper.ReaperConfig
  alias SmartCity.Dataset

  use SmartCity.Registry.MessageHandler

  def handle_dataset(dataset) do
    with {:ok, reaper_config} <- ReaperConfig.from_registry_message(dataset) do
      ConfigServer.process_reaper_config(reaper_config)
    else
      {:error, reason} ->
        Logger.error("Skipping registry message for this reason: #{inspect(reason)}")

      _ ->
        Logger.error("Unexpected response received")
    end
  end
end
