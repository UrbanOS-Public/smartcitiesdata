defmodule Reaper.Horde.Supervisor do
  @moduledoc """
  Module Based Horde.Supervisor
  """
  use Horde.DynamicSupervisor
  require Logger

  import SmartCity.Event, only: [data_extract_end: 0, file_ingest_end: 0]

  @instance_name Reaper.instance_name()

  def start_link(init_args \\ []) do
    Horde.DynamicSupervisor.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @impl Horde.DynamicSupervisor
  def init(init_args) do
    [members: get_members(), strategy: :one_for_one]
    |> Keyword.merge(init_args)
    |> Horde.DynamicSupervisor.init()
  end

  defp get_members() do
    [Node.self() | Node.list()]
    |> Enum.map(fn node -> {__MODULE__, node} end)
  end

  def start_child(child_spec) do
    Horde.DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def terminate_child(pid) do
    Horde.DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def start_data_extract(%SmartCity.Ingestion{} = ingestion) do
    Logger.debug(fn -> "#{__MODULE__} Start data extract process for ingestion #{ingestion.id}" end)

    extract_start = DateTime.utc_now()
    IO.inspect(extract_start, label: "start data extract")

    send_extract_complete_event = fn processor_result ->
      message = %{
        ingestion_id: ingestion.id,
        dataset_ids: ingestion.targetDatasets,
        msgs_extracted: processor_result,
        extract_start_unix: extract_start |> DateTime.to_unix()
      }

      Brook.Event.send(@instance_name, data_extract_end(), :reaper, message)
    end

    start_child(
      {Reaper.RunTask,
       name: ingestion.id,
       mfa: {Reaper.DataExtract.Processor, :process, [ingestion, extract_start]},
       completion_callback: send_extract_complete_event}
    )
  end
end
