defmodule Forklift.MessageWriter do
  @moduledoc false
  alias Forklift.{RedisClient, PrestoClient}
  alias SCOS.DataMessage
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end

  ## Server Callbacks ##

  def init(_args) do
    schedule_work()
    {:ok, %{}}
  end

  def handle_info(:work, state) do
    RedisClient.read_all_batched_messages()
    |> Enum.map(fn {key, message} ->
      {:ok, value} = DataMessage.new(message)
      {key, value}
    end)
    |> Enum.group_by(&extract_key/1, fn {msg_key, msg} -> msg end)
    |> Enum.each(fn {dataset_id, messages} -> PrestoClient.upload_data(dataset_id, messages) end)

    # RedisClient.delete(dataset_id)
    schedule_work()
    {:noreply, state}
  end

  defp extract_key({key, _}) do
    key |> String.split(":") |> Enum.at(2)
  end

  defp schedule_work do
    Process.send_after(self(), :work, 60_000)
  end
end
