defmodule Forklift.MessageWriter do
  @moduledoc false
  alias Forklift.{CacheClient, PersistenceClient, DeadLetterQueue}
  use GenServer
  require Logger

  @message_processing_cadence Application.get_env(:forklift, :message_processing_cadence)

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_args) do
    schedule_work()
    {:ok, %{}}
  end

  def handle_info(:work, state) do
    CacheClient.read_all_batched_messages()
    |> Enum.map(&parse_data_message/1)
    |> Enum.filter(&(&1 != :parsing_error))
    |> Enum.group_by(&extract_dataset_id/1)
    |> Enum.each(&start_upload_and_delete_task/1)

    schedule_work()
    {:noreply, state}
  end

  # Handles returns from tasks started in start_upload_and_delete_task
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp parse_data_message({key, message}) do
    case SmartCity.Data.new(message) do
      {:ok, value} ->
        {key, value}

      _ ->
        DeadLetterQueue.enqueue(message)
        CacheClient.delete(key)
        Logger.warn("Failed to parse cached message: #{message}")
        :parsing_error
    end
  end

  defp extract_dataset_id({key, _}) do
    key |> String.split(":") |> Enum.at(2)
  end

  defp start_upload_and_delete_task({dataset_id, key_message_pairs}) do
    Task.Supervisor.async_nolink(Forklift.TaskSupervisor, fn ->
      redis_keys = Enum.map(key_message_pairs, fn {redis_key, _msg} -> redis_key end)
      data = Enum.map(key_message_pairs, fn {_redis_key, msg} -> msg.payload end)

      PersistenceClient.upload_data(dataset_id, data)
      CacheClient.delete(redis_keys)
    end)
  end

  defp schedule_work do
    Process.send_after(self(), :work, @message_processing_cadence)
  end
end
