defmodule Reaper.IngestionDiagnostic do
  @moduledoc """
  Diagnostic tool that walks an ingestion's extract steps one at a time,
  printing what gets built at each stage (resolved URL, headers, secrets,
  auth responses) and surfacing the full, untruncated exception and
  stacktrace for whichever step fails.

  This exists because ANDI's "test" button collapses every failure into a
  generic "Could not complete request" message, and Reaper's real scheduled
  run wraps the real error in a generic "Unable to process step" message
  before reraising. This module replicates the same per-step dispatch as
  `Reaper.DataExtract.ExtractStep`, but without that wrapping, so the actual
  error (HTTP status, TLS/Mint error, EEx error, etc.) is visible directly
  in the console.

  ## Usage (from an IEx session attached to the running reaper node)

      Reaper.IngestionDiagnostic.run("ingestion-id")
  """

  alias Reaper.Collections.Extractions
  alias Reaper.UrlBuilder
  alias Reaper.DataSlurper

  @doc """
  Runs every extract step for the given ingestion id in sequence order,
  stopping at the first failure and printing the full exception and
  stacktrace for that step.
  """
  def run(ingestion_id) do
    case Extractions.get_ingestion!(ingestion_id) do
      nil ->
        IO.puts("✗ No ingestion found for id #{inspect(ingestion_id)}")
        {:error, :not_found}

      ingestion ->
        IO.puts("=== Ingestion Diagnostic: #{ingestion_id} ===")

        steps =
          ingestion.extractSteps
          |> Enum.map(&AtomicMap.convert(&1, underscore: false))
          |> Enum.sort_by(&(Map.get(&1, :sequence) || 0))

        IO.puts("Found #{length(steps)} extract step(s)\n")

        run_steps(ingestion, steps, %{})
    end
  end

  defp run_steps(_ingestion, [], assigns) do
    IO.puts("\n✓ All steps completed successfully.")
    IO.puts("Final assigns: #{inspect(assigns)}")
    {:ok, assigns}
  end

  defp run_steps(ingestion, [step | rest], assigns) do
    step = Map.put(step, :assigns, Map.merge(Map.get(step, :assigns, %{}), assigns))
    IO.puts("--- Step #{Map.get(step, :sequence, "?")}: #{step.type} ---")

    new_assigns = run_step(ingestion, step)
    IO.puts("  assigns now: #{inspect(new_assigns)}")
    IO.puts("✓ ok\n")
    run_steps(ingestion, rest, new_assigns)
  rescue
    error ->
      print_failure(step, :error, error, __STACKTRACE__)
      {:error, {step.type, Map.get(step, :sequence), error}}
  catch
    kind, reason ->
      print_failure(step, kind, reason, __STACKTRACE__)
      {:error, {step.type, Map.get(step, :sequence), reason}}
  end

  defp print_failure(step, kind, reason, stacktrace) do
    IO.puts("\n✗ FAILED on step #{Map.get(step, :sequence, "?")} (#{step.type})\n")
    IO.puts(Exception.format(kind, reason, stacktrace))
  end

  defp run_step(ingestion, %{type: "http"} = step) do
    {body, headers} = evaluate_body_and_headers(step)
    url = UrlBuilder.decode_http_extract_step(step)

    IO.puts("  url:     #{url}")
    IO.puts("  action:  #{step.context.action}")
    IO.puts("  headers: #{inspect(headers)}")

    output_file =
      DataSlurper.slurp(url, ingestion.id, headers, step.context.protocol, step.context.action, body)

    Map.put(step.assigns, :output_file, output_file)
  end

  defp run_step(ingestion, %{type: "s3"} = step) do
    headers =
      UrlBuilder.safe_evaluate_parameters(step.context.headers, step.assigns)
      |> Enum.into(%{})

    url = UrlBuilder.build_safe_url_path(step.context.url, step.assigns)

    IO.puts("  url:     #{url}")
    IO.puts("  headers: #{inspect(headers)}")

    output_file = DataSlurper.slurp(url, ingestion.id, headers)
    Map.put(step.assigns, :output_file, output_file)
  end

  defp run_step(ingestion, %{type: "sftp"} = step) do
    url = UrlBuilder.build_safe_url_path(step.context.url, step.assigns)
    IO.puts("  url: #{url}")

    output_file = DataSlurper.slurp(url, ingestion.id)
    Map.put(step.assigns, :output_file, output_file)
  end

  defp run_step(_ingestion, %{type: "date"} = step) do
    date =
      case step.context.deltaTimeUnit do
        nil ->
          Timex.now()

        _ ->
          unit = String.to_atom(step.context.deltaTimeUnit)
          Timex.shift(Timex.now(), [{unit, step.context.deltaTimeValue}])
      end

    formatted_date = Timex.format!(date, step.context.format)
    IO.puts("  #{step.context.destination}: #{formatted_date}")

    Map.put(step.assigns, step.context.destination |> String.to_atom(), formatted_date)
  end

  defp run_step(_ingestion, %{type: "secret"} = step) do
    {:ok, cred} = Reaper.SecretRetriever.retrieve_ingestion_credentials(step.context.key)
    secret = Map.get(cred, step.context.sub_key)

    IO.puts("  #{step.context.destination}: #{inspect(secret)}")

    Map.put(step.assigns, step.context.destination |> String.to_atom(), secret)
  end

  defp run_step(ingestion, %{type: "auth"} = step) do
    {body, headers} = evaluate_body_and_headers(step)
    url = UrlBuilder.build_safe_url_path(step.context.url, step.assigns)

    IO.puts("  url:     #{url}")
    IO.puts("  headers: #{inspect(headers)}")

    response =
      Reaper.AuthRetriever.authorize(
        ingestion.id,
        url,
        body,
        step.context.encodeMethod,
        headers,
        step.context.cacheTtl
      )
      |> Jason.decode!()
      |> get_in(step.context.path)

    IO.puts("  response: #{inspect(response)}")

    Map.put(step.assigns, step.context.destination |> String.to_atom(), response)
  end

  defp run_step(_ingestion, %{type: unsupported}) do
    raise "Unsupported extract step type: #{inspect(unsupported)}"
  end

  defp evaluate_body_and_headers(step) do
    body = process_body(step.context.body, step.assigns)
    headers = UrlBuilder.safe_evaluate_parameters(step.context.headers, step.assigns)
    {body, headers}
  end

  defp process_body(body, _assigns) when body in ["", nil, %{}, []], do: ""
  defp process_body(body, assigns), do: UrlBuilder.safe_evaluate_body(body, assigns)
end
