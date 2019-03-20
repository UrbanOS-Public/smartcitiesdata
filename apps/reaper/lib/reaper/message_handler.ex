defmodule Reaper.MessageHandler do
  @moduledoc false
  require Logger
  alias Reaper.ConfigServer
  alias Reaper.ReaperConfig
  alias SmartCity.Dataset

  def handle_message(%{value: registry_message_string}) do
    with {:ok, registry_message} <- Dataset.new(registry_message_string),
         {:ok, reaper_config} <- ReaperConfig.from_registry_message(registry_message) do
      ConfigServer.process_reaper_config(reaper_config)

      :ok
    else
      {:error, reason} -> Logger.error("Skipping registry message for this reason: #{inspect(reason)}")
      _ -> Logger.error("Unexpected response received")
    end
  end
end
