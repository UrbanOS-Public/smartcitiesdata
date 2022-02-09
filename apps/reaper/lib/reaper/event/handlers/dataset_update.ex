defmodule Reaper.Event.Handlers.DatasetUpdate do
  @moduledoc false
  require Logger

  import SmartCity.Event, only: [data_extract_start: 0, file_ingest_start: 0]

  alias Quantum.Job
  alias Reaper.Collections.Extractions

  @instance_name Reaper.instance_name()

  @cron_conversions %{
    86_400_000 => "0 6 * * *",
    3_600_000 => "0 * * * *",
    30_000 => "*/30 * * * * * *",
    10_000 => "*/10 * * * * * *"
  }

  def handle(%SmartCity.Ingestion{cadence: "never"} = ingestion) do
    delete_job(ingestion)

    if Extractions.get_ingestion!(ingestion.id) != nil do
      Extractions.disable_ingestion(ingestion.id)
    end

    :ok
  end

  def handle(%SmartCity.Ingestion{cadence: "once"} = ingestion) do
    case Extractions.get_last_fetched_timestamp!(ingestion.id) do
      nil ->
        delete_job(ingestion)
        Brook.Event.send(@instance_name, data_extract_start(), :reaper, ingestion)

      _ ->
        :ok
    end
  end

  def handle(%SmartCity.Ingestion{cadence: cadence} = ingestion) do
    with {:ok, _} <- check_job_disabled(ingestion),
         {:ok, cron} <- parse_cron(cadence),
         :ok <- delete_job(ingestion) do
      create_job(cron, ingestion)
    else
      {:error, reason} -> Logger.warn(reason)
    end

    :ok
  end

  defp check_job_disabled(ingestion) do
    case Reaper.Scheduler.find_job(String.to_atom(ingestion.id)) do
      %{state: :inactive} -> {:error, "ingestion #{ingestion.id} is disabled"}
      _ -> {:ok, ingestion}
    end
  end

  defp parse_cron(cron_int) when is_integer(cron_int) do
    case Map.get(@cron_conversions, cron_int) do
      nil ->
        {:error, "#Unable to convert cadence #{cron_int} to a valid cron expression: Ignoring ingestion"}

      expression ->
        parse_cron(expression)
    end
  end

  defp parse_cron(cron_string) do
    extended? = String.split(cron_string, " ") |> length() > 5

    case Crontab.CronExpression.Parser.parse(cron_string, extended?) do
      {:error, reason} ->
        {:error,
         "event(ingestion:update) unable to parse cadence(#{cron_string}) as cron expression, error reason: #{
           inspect(reason)
         }"}

      ok_result ->
        ok_result
    end
  end

  defp delete_job(ingestion) do
    ingestion.id
    |> String.to_atom()
    |> Reaper.Scheduler.delete_job()
  end

  defp create_job(cron_expression, ingestion) do
    {:ok, serialized_ingestion} = Brook.Serializer.serialize(ingestion)

    Reaper.Scheduler.new_job()
    |> Job.set_name(String.to_atom(ingestion.id))
    |> Job.set_schedule(cron_expression)
    |> Job.set_task({__MODULE__, :protected_event_send, [serialized_ingestion]})
    |> Reaper.Scheduler.add_job()
  end

  def protected_event_send(ingestion_json) do
    {:ok, safe_ingestion} = Brook.Deserializer.deserialize(ingestion_json)

    Brook.Event.send(@instance_name, data_extract_start(), :reaper, safe_ingestion)
  end
end
