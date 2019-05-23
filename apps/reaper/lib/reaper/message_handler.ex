defmodule Reaper.MessageHandler do
  @moduledoc """
  This module will process messages that are passed into reaper, starting the ingestion process
  """
  require Logger
  alias Reaper.ConfigServer
  alias Reaper.ReaperConfig
  use SmartCity.Registry.MessageHandler

  @doc """
  Processes a `SmartCity.Dataset` to begin the ingestion
  """
  @spec handle_dataset(SmartCity.Dataset.t()) ::
          {:ok, String.t()} | DynamicSupervisor.on_start_child() | nil
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
