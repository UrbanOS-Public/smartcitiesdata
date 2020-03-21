defmodule Reaper.Event.Handlers.DatasetUpdate do
  @moduledoc false
  require Logger

  import SmartCity.Event, only: [data_extract_start: 0, file_ingest_start: 0]

  alias Quantum.Job
  alias Reaper.Collections.Extractions

  @instance Reaper.Application.instance()

  @cron_conversions %{
    86_400_000 => "0 6 * * *",
    3_600_000 => "0 * * * *",
    30_000 => "*/30 * * * * * *",
    10_000 => "*/10 * * * * * *"
  }

  def handle(%SmartCity.Dataset{technical: %{cadence: "never"}} = dataset) do
    delete_job(dataset)

    if Extractions.get_dataset!(dataset.id) != nil do
      Extractions.disable_dataset(dataset.id)
    end

    :ok
  end

  def handle(%SmartCity.Dataset{technical: %{cadence: "once"}} = dataset) do
    case Extractions.get_last_fetched_timestamp!(dataset.id) do
      nil ->
        delete_job(dataset)
        Brook.Event.send(@instance, determine_event(dataset), :reaper, dataset)

      _ ->
        :ok
    end
  end

  def handle(%SmartCity.Dataset{technical: %{cadence: cadence}} = dataset) do
    with {:ok, _} <- check_job_disabled(dataset),
         {:ok, cron} <- parse_cron(cadence),
         :ok <- delete_job(dataset) do
      create_job(cron, dataset)
    else
      {:error, reason} -> Logger.warn(reason)
    end

    :ok
  end

  defp check_job_disabled(dataset) do
    case Reaper.Scheduler.find_job(String.to_atom(dataset.id)) do
      %{state: :inactive} -> {:error, "dataset #{dataset.id} is disabled"}
      _ -> {:ok, dataset}
    end
  end

  defp parse_cron(cron_int) when is_integer(cron_int) do
    case Map.get(@cron_conversions, cron_int) do
      nil ->
        {:error, "#Unable to convert cadence #{cron_int} to a valid cron expression: Ignoring dataset"}

      expression ->
        parse_cron(expression)
    end
  end

  defp parse_cron(cron_string) do
    extended? = String.split(cron_string, " ") |> length() > 5

    case Crontab.CronExpression.Parser.parse(cron_string, extended?) do
      {:error, reason} ->
        {:error,
         "event(dataset:update) unable to parse cadence(#{cron_string}) as cron expression, error reason: #{
           inspect(reason)
         }"}

      ok_result ->
        ok_result
    end
  end

  defp delete_job(dataset) do
    dataset.id
    |> String.to_atom()
    |> Reaper.Scheduler.delete_job()
  end

  defp create_job(cron_expression, dataset) do
    {:ok, serialized_dataset} = Brook.Serializer.serialize(dataset)

    Reaper.Scheduler.new_job()
    |> Job.set_name(String.to_atom(dataset.id))
    |> Job.set_schedule(cron_expression)
    |> Job.set_task({__MODULE__, :protected_event_send, [serialized_dataset]})
    |> Reaper.Scheduler.add_job()
  end

  def protected_event_send(dataset_json) do
    {:ok, safe_dataset} = Brook.Deserializer.deserialize(dataset_json)

    Brook.Event.send(@instance, determine_event(safe_dataset), :reaper, safe_dataset)
  end

  defp determine_event(%SmartCity.Dataset{technical: %{sourceType: "host"}}) do
    file_ingest_start()
  end

  defp determine_event(%SmartCity.Dataset{
         technical: %{sourceType: "ingest", sourceFormat: "application/zip"}
       }) do
    file_ingest_start()
  end

  defp determine_event(_) do
    data_extract_start()
  end
end
