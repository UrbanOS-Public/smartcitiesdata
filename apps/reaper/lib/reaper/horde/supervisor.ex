defmodule Reaper.Horde.Supervisor do
  @moduledoc """
  Module Based Horde.Supervisor
  """
  use Horde.Supervisor

  import SmartCity.Event, only: [data_extract_end: 0, file_ingest_end: 0]

  def init(options) do
    {:ok, Keyword.put(options, :members, get_members())}
  end

  defp get_members() do
    [Node.self() | Node.list()]
    |> Enum.map(fn node -> {__MODULE__, node} end)
  end

  def start_child(child_spec) do
    Horde.Supervisor.start_child(__MODULE__, child_spec)
  end

  def start_data_extract(%SmartCity.Dataset{} = dataset) do
    send_extract_complete_event = fn ->
      Brook.Event.send(data_extract_end(), :reaper, dataset)
    end

    start_child(
      {Reaper.RunTask,
       name: dataset.id,
       mfa: {Reaper.DataExtract.Processor, :process, [dataset]},
       completion_callback: send_extract_complete_event}
    )
  end

  def start_file_ingest(%SmartCity.Dataset{} = dataset) do
    send_file_ingest_end_event = fn ->
      Brook.Event.send(file_ingest_end(), :reaper, dataset)
    end

    Reaper.Horde.Supervisor.start_child(
      {Reaper.RunTask,
       name: dataset.id,
       mfa: {Reaper.FileIngest.Processor, :process, [dataset]},
       completion_callback: send_file_ingest_end_event}
    )
  end
end
