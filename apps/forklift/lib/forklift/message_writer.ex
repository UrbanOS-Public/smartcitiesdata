defmodule Forklift.MessageWriter do
  @moduledoc false
  alias Forklift.DataBuffer
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
    DataBuffer.get_pending_datasets()
    |> Enum.each(&start_task/1)

    schedule_work()

    {:noreply, state}
  end

  # Handles returns from tasks started in start_upload_and_delete_task
  def handle_info(_, state) do
    {:noreply, state}
  end

  defp start_task(dataset_id) do
    Task.Supervisor.async_nolink(Forklift.TaskSupervisor, Forklift.DatasetWriter, :run, [dataset_id])
  end

  defp schedule_work do
    Process.send_after(self(), :work, @message_processing_cadence)
  end
end
