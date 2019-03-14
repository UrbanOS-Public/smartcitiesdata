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
    |> Enum.group_by(&extract_key/1, fn value -> value end)
    |> Enum.map(fn {dataset_id, messages} ->
      Task.Supervisor.async_nolink(Forklift.TaskSupervisor, fn ->
        PrestoClient.upload_data(dataset_id, Enum.map(messages, fn {redis_key, msg} -> msg end))
        RedisClient.delete(Enum.map(messages, fn {redis_key, msg} -> redis_key end))
      end)
    end)
    |> Enum.each(&Task.await/1)

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
