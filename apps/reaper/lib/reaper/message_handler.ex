defmodule Reaper.MessageHandler do
  @moduledoc false
  require Logger
  alias Reaper.ConfigServer

  def handle_message(_pid, %{value: dataset}) do
    with {:ok, decoded_dataset} <-
           dataset
           |> Jason.decode!(keys: :atoms)
           |> Dataset.new() do
      ConfigServer.send_dataset(decoded_dataset)
    else
      {:error, reason} -> Logger.error("Skipping dataset message for this reason: #{inspect(reason)}")
    end

    :ok
  end
end
