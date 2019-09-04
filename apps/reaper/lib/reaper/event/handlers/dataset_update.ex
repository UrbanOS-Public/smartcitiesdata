defmodule Reaper.Event.Handlers.DatasetUpdate do
  @moduledoc false
  require Logger

  import SmartCity.Event, only: [dataset_extract_start: 0, hosted_file_start: 0]

  alias Quantum.Job
  alias Reaper.Collections.Extractions

  def handle(%SmartCity.Dataset{technical: %{cadence: "never"}}) do
    :ok
  end

  def handle(%SmartCity.Dataset{technical: %{cadence: "once"}} = dataset) do
    case Extractions.get_last_fetched_timestamp!(dataset.id) do
      nil -> Brook.Event.send(determine_event(dataset), :reaper, dataset)
      _ -> :ok
    end
  end

  def handle(%SmartCity.Dataset{technical: %{cadence: cadence}} = dataset) do
    with {:ok, cron} <- parse_cron(cadence),
         :ok <- delete_job(dataset) do
      create_job(cron, dataset)
    else
      {:error, reason} -> Logger.warn(reason)
    end

    :ok
  end

  defp parse_cron(cron_string) do
    case Crontab.CronExpression.Parser.parse(cron_string) do
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
    Reaper.Scheduler.new_job()
    |> Job.set_name(String.to_atom(dataset.id))
    |> Job.set_schedule(cron_expression)
    |> Job.set_task({Brook.Event, :send, [determine_event(dataset), :reaper, dataset]})
    |> Reaper.Scheduler.add_job()
  end

  defp determine_event(%SmartCity.Dataset{technical: %{sourceType: "host"}}) do
    hosted_file_start()
  end

  defp determine_event(_) do
    dataset_extract_start()
  end
end
