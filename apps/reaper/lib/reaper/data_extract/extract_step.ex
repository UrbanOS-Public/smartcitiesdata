defmodule Reaper.DataExtract.ExtractStep do
  @moduledoc """
  This module processes extract steps as defined in an ingestion definition.  After
  iterating through the steps, accumulating any destination values in the assigns block
  it is assumed the final step will be http (at this time) which returns a data stream
  """
  require Logger
  alias Reaper.DataSlurper
  alias Reaper.UrlBuilder

  def execute_extract_steps(ingestion, steps) do
    Enum.reduce(steps, %{}, fn step, acc ->
      step = AtomicMap.convert(step, underscore: false)
      execute_extract_step(ingestion, step, acc)
    end)
  end

  defp execute_extract_step(ingestion, step, assigns_accumulator) do
    step = Map.put(step, :assigns, Map.merge(step.assigns, assigns_accumulator))
    process_extract_step(ingestion, step)
  rescue
    error ->
      Logger.error(Exception.format(:error, error, __STACKTRACE__))
      reraise "Unable to process #{step.type} step for ingestion #{ingestion.id}.", __STACKTRACE__
  end

  defp process_extract_step(ingestion, %{type: "http"} = step) do
    {body, headers} = evaluate_body_and_headers(step)

    output_file =
      UrlBuilder.decode_http_extract_step(step)
      |> DataSlurper.slurp(ingestion.id, headers, step.context.protocol, step.context.action, body)

    Map.put(step.assigns, :output_file, output_file)
  end

  defp process_extract_step(ingestion, %{type: "s3"} = step) do
    headers =
      UrlBuilder.safe_evaluate_parameters(step.context.headers, step.assigns)
      |> Enum.into(%{})

    output_file =
      UrlBuilder.build_safe_url_path(step.context.url, step.assigns)
      |> DataSlurper.slurp(ingestion.id, headers)

    Map.put(step.assigns, :output_file, output_file)
  end

  defp process_extract_step(ingestion, %{type: "sftp"} = step) do
    output_file =
      UrlBuilder.build_safe_url_path(step.context.url, step.assigns)
      |> DataSlurper.slurp(ingestion.id)

    Map.put(step.assigns, :output_file, output_file)
  end

  defp process_extract_step(_ingestion, %{type: "date"} = step) do
    date =
      case step.context.deltaTimeUnit do
        nil ->
          Timex.now()

        _ ->
          unit = String.to_atom(step.context.deltaTimeUnit)
          Timex.shift(Timex.now(), [{unit, step.context.deltaTimeValue}])
      end

    formatted_date = Timex.format!(date, step.context.format)
    Map.put(step.assigns, step.context.destination |> String.to_atom(), formatted_date)
  end

  defp process_extract_step(_ingestion, %{type: "secret"} = step) do
    {:ok, cred} = Reaper.SecretRetriever.retrieve_ingestion_credentials(step.context.key)
    secret = Map.get(cred, step.context.sub_key)

    Map.put(step.assigns, step.context.destination |> String.to_atom(), secret)
  end

  defp process_extract_step(ingestion, %{type: "auth"} = step) do
    {body, headers} = evaluate_body_and_headers(step)

    url = UrlBuilder.build_safe_url_path(step.context.url, step.assigns)

    response =
      Reaper.AuthRetriever.authorize(ingestion.id, url, body, step.context.encodeMethod, headers, step.context.cacheTtl)
      |> Jason.decode!()
      |> get_in(step.context.path)

    Map.put(step.assigns, step.context.destination |> String.to_atom(), response)
  end

  defp evaluate_body_and_headers(step) do
    body = process_body(step.context.body, step.assigns)

    headers = UrlBuilder.safe_evaluate_parameters(step.context.headers, step.assigns)

    {body, headers}
  end

  defp process_body(body, _assigns) when body in ["", nil, %{}, []], do: ""

  defp process_body(body, assigns) do
    body |> UrlBuilder.safe_evaluate_body(assigns)
  end
end
