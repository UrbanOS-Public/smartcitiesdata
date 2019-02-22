defmodule Reaper.MessageHandler do
  @moduledoc false
  require Logger
  alias Reaper.ConfigServer

  def handle_message(_pid, %{value: dataset}) do
    {:ok, decoded_dataset} =
      dataset
      |> Jason.decode!(keys: :atoms)
      |> Dataset.new()

    ConfigServer.send_dataset(decoded_dataset)

    :ok
  end
end
