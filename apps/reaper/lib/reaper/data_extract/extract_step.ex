defmodule Reaper.DataExtract.ExtractStep do
  require Logger
  alias Reaper.DataSlurper
  alias Reaper.UrlBuilder
  alias Reaper.Decoder

  def execute_extract_steps(dataset, steps) do
    Enum.reduce(steps, %{}, fn step, acc ->
      execute_extract_step(dataset, step, acc)
    end)
  end

  defp execute_extract_step(dataset, step, assigns_accumulator) do
    step = Map.put(step, :assigns, Map.merge(step.assigns, assigns_accumulator))
    process_extract_step(dataset, step)
  rescue
    error ->
      Logger.error(Exception.format(:error, error, __STACKTRACE__))
      raise "Unable to process #{step.type} step for dataset #{dataset.id}."
  end

  defp process_extract_step(dataset, %{type: "http"} = step) do
    headers = UrlBuilder.safe_evaluate_parameters(step.context.headers, step.assigns)
    body =
      UrlBuilder.safe_evaluate_parameters(step.context.body, step.assigns)
      |> Enum.into(%{})
      |> Jason.encode!

    UrlBuilder.decode_http_extract_step(step)
    ## TODO: Dataslurper seems to not fail on 401s, you can reproduce by updating the teest that gets a secret and makes bypass 401
    ## TODO: fix protocol not being passed through
    |> DataSlurper.slurp(dataset.id, headers, nil, step.context.action, body)
    |> Decoder.decode(dataset)
    |> Stream.with_index()
  end

  defp process_extract_step(_dataset, %{type: "date"} = step) do
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

  defp process_extract_step(_dataset, %{type: "secret"} = step) do
    {:ok, cred} = Reaper.SecretRetriever.retrieve_dataset_credentials(step.context.key)
    secret = Map.get(cred, step.context.sub_key)

    Map.put(step.assigns, step.context.destination |> String.to_atom(), secret)
  end

  defp process_extract_step(dataset, %{type: "auth"} = step) do
    body =
      step.context.body
      |> UrlBuilder.safe_evaluate_parameters(step.assigns)
      |> Enum.into(%{})

    headers =
      step.context.headers
      |> UrlBuilder.safe_evaluate_parameters(step.assigns)
      |> Enum.into(%{})

    url = UrlBuilder.build_safe_url_path(step.context.url, step.assigns)

    response =
      Reaper.AuthRetriever.authorize(dataset.id, url, body, step.context.encodeMethod, headers, step.context.cacheTtl)
      |> Jason.decode!()
      |> get_in(step.context.path)

    Map.put(step.assigns, step.context.destination |> String.to_atom(), response)
  end
end
