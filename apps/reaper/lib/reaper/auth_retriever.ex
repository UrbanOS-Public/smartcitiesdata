defmodule Reaper.AuthRetriever do
  @moduledoc """
  Call the authUrl of a dataset, passing the authHeaders, and returning the response.
  """
  alias Reaper.Collections.Extractions
  alias Reaper.Cache.AuthCache

  def retrieve_step(dataset_id, step, cache_ttl \\ 10_000) do
    encode_method = step.context.encodeMethod
    body = step.context.body |> encode_body(encode_method)
    headers = step.context.headers |> add_content_type(body, encode_method)

    cache_id = hash_config(%{url: step.context.url, body: body, headers: headers})

    case AuthCache.get(cache_id) do
      nil ->
        auth = make_auth_request(dataset_id, step.context.url, body, headers)
        AuthCache.put(cache_id, auth, ttl: cache_ttl)
        auth

      auth ->
        auth
    end
  end

  def retrieve(dataset_id, cache_ttl \\ 10_000) do
    dataset = Extractions.get_dataset!(dataset_id)
    encode_method = get_in(dataset, [:technical, :authBodyEncodeMethod])

    body =
      dataset
      |> get_in([:technical, :authBody])
      |> evaluate_eex_map()
      |> encode_body(encode_method)

    headers =
      dataset.technical.authHeaders
      |> evaluate_eex_map()
      |> add_content_type(body, encode_method)

    cache_id = hash_config(%{url: dataset.technical[:authUrl], body: body, headers: headers})

    case AuthCache.get(cache_id) do
      nil ->
        auth = make_auth_request(dataset_id, dataset.technical.authUrl, body, headers)
        AuthCache.put(cache_id, auth, ttl: cache_ttl)
        auth

      auth ->
        auth
    end
  end

  defp hash_config(auth_params_map) do
    json = Jason.encode!(auth_params_map)
    :crypto.hash(:md5, json)
  end

  defp make_auth_request(dataset_id, url, body, headers) do
    case HTTPoison.post(url, body, headers) do
      {:ok, %{status_code: code, body: body}} when code < 400 ->
        body

      {:ok, %{status_code: code}} ->
        raise "Unable to retrieve auth credentials for dataset #{dataset_id} with status #{code}"

      error ->
        raise "Unable to retrieve auth credentials for dataset #{dataset_id} with error #{inspect(error)}"
    end
  end

  defp evaluate_eex_map(nil), do: %{}

  defp evaluate_eex_map(map) do
    map
    |> Enum.map(&evaluate_eex(&1))
    |> Enum.into(%{})
  end

  defp evaluate_eex({key, value}) do
    {key, EEx.eval_string(value, [])}
  end

  defp encode_body(body, "json"), do: Jason.encode!(body)
  defp encode_body(body, _), do: URI.encode_query(body)

  defp add_content_type(headers, "", _), do: headers
  defp add_content_type(headers, _body, "json"), do: Map.put(headers, "Content-Type", "application/json")
  defp add_content_type(headers, _body, _), do: Map.put(headers, "Content-Type", "application/x-www-form-urlencoded")
end
