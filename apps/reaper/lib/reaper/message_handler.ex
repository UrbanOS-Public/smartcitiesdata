defmodule Reaper.MessageHandler do
  @moduledoc false
  require Logger
  alias Reaper.ConfigServer
  alias SCOS.RegistryMessage

  def handle_message(_pid, %{value: dataset}) do
    with {:ok, decoded} <- Jason.decode(dataset, keys: :atoms),
         {:ok, dataset} <- RegistryMessage.new(decoded) do
      ConfigServer.send_dataset(dataset)
      :ok
    else
      {:error, reason} -> Logger.error("Skipping dataset message for this reason: #{inspect(reason)}")
      _ -> Logger.error("Unexpected response received")
    end
  end
end
