defmodule Andi.UrlBuilder do
  @spec decode_http_extract_step(
          atom | %{:context => atom | %{:url => binary, optional(any) => any}, optional(any) => any},
          any
        ) :: binary
  def decode_http_extract_step(%{context: %{query_params: []}} = step, assigns) do
    build_safe_url_path(step.context.url, assigns)
  end

  def decode_http_extract_step(step, assigns) do
    no_param_url =
      step.context.url
      |> String.split("?")
      |> hd()

    build_safe_url_path(no_param_url, assigns)
  end

  def build_safe_url_path(url, bindings) do
    regex = ~r"{{(.+?)}}"

    Regex.replace(regex, url, fn _match, var_name ->
      bindings[String.to_atom(var_name)]
    end)
  end

  def safe_evaluate_parameters(parameters, bindings) do
    Enum.map(
      parameters,
      fn param ->
        {:ok, key} = Map.fetch(param, :key)
        {:ok, value} = Map.fetch(param, :value)
        safe_evaluate_parameter({key, value}, bindings)
      end
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
