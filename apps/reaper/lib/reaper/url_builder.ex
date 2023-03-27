defmodule Reaper.UrlBuilder do
  alias Reaper.Collections.Extractions

  @moduledoc """
  This module builds a URL to download a source file
  """

  @spec decode_http_extract_step(%{assigns: any, context: %{queryParams: any, url: binary}}) ::
          binary
  def decode_http_extract_step(%{context: %{url: url, queryParams: query_params}, assigns: assigns})
      when query_params == %{} do
    build_safe_url_path(url, assigns)
  end

  def decode_http_extract_step(%{context: %{url: url, queryParams: query_params}, assigns: assigns}) do
    string_params =
      query_params
      |> safe_evaluate_parameters(assigns)
      |> URI.encode_query()

    "#{build_safe_url_path(url, assigns)}?#{string_params}"
  end

  def build_safe_url_path(url, bindings) do
    regex = ~r"{{(.+?)}}"

    Regex.replace(regex, url, fn _match, var_name ->
      bindings[String.to_atom(var_name)]
    end)
  end

  def safe_evaluate_body(body, bindings) when is_binary(body) do
    regex = ~r"{{(.+?)}}"
    replacements = Regex.scan(regex, body)

    value =
      Enum.reduce(replacements, body, fn replacement, new_body ->
        Regex.replace(
          ~r"#{List.first(replacement)}",
          new_body,
          bindings[String.to_atom(List.last(replacement))]
        )
      end)

    value
  end

  def safe_evaluate_parameters(parameters, bindings) do
    Enum.map(
      parameters,
      &safe_evaluate_parameter(&1, bindings)
    )
  end

  defp safe_evaluate_parameter({key, %{} = param_map}, bindings) do
    evaluated_map =
      Enum.map(param_map, fn param ->
        safe_evaluate_parameter(param, bindings)
      end)
      |> Enum.into(%{})

    {key, evaluated_map}
  end

  defp safe_evaluate_parameter({key, value}, bindings) do
    regex = ~r"{{(.+?)}}"

    value =
      Regex.replace(regex, to_string(value), fn _match, var_name ->
        bindings[String.to_atom(var_name)]
      end)

    {key, value}
  end
end
