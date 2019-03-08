defmodule Reaper.MessageHandler do
  @moduledoc false
  require Logger
  alias Reaper.ConfigServer
  alias Reaper.Sickle
  alias SCOS.RegistryMessage

  def handle_message(%{value: registry_message_string}) do
    with {:ok, registry_message} <- RegistryMessage.new(registry_message_string),
         {:ok, sickle} <- Sickle.from_registry_message(registry_message) do
      ConfigServer.send_sickle(sickle)

      :ok
    else
      {:error, reason} -> Logger.error("Skipping dataset message for this reason: #{inspect(reason)}")
      _ -> Logger.error("Unexpected response received")
    end
  end
end
